#!/usr/bin/env bats
# Tests for scripts/collect-activity-counts.sh.
# Mocks `gh` via a PATH shim so no network calls happen.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/collect-activity-counts.sh"
    FIXTURE_DIR="$BATS_TEST_DIRNAME/../fixtures"
    MOCK_DIR="$(mktemp -d)"
    MOCK_LOG="$MOCK_DIR/calls.log"

    # Mock gh: dispatch by URL pattern, apply --jq filter via real jq.
    cat > "$MOCK_DIR/gh" <<MOCK
#!/usr/bin/env bash
set -e
JQ=""
URL=""
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        --jq) JQ="\$2"; shift 2 ;;
        api) shift ;;
        *) [[ -z "\$URL" ]] && URL="\$1"; shift ;;
    esac
done
echo "\$URL" >> "$MOCK_LOG"
case "\$URL" in
    *"/issues?"*) FX="$FIXTURE_DIR/gh-mock-issues.json" ;;
    *"/pulls?"*) FX="$FIXTURE_DIR/gh-mock-prs.json" ;;
    *"/commits?"*) FX="$FIXTURE_DIR/gh-mock-commits.json" ;;
    *) echo "[]"; exit 0 ;;
esac
if [[ -n "\$JQ" ]]; then
    jq -r "\$JQ" "\$FX"
else
    cat "\$FX"
fi
MOCK
    chmod +x "$MOCK_DIR/gh"
    PATH="$MOCK_DIR:$PATH"
    export PATH
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "emits TSV with date<TAB>type<TAB>count rows" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Each line has exactly two tab-separated fields (3 columns)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        cols=$(printf '%s' "$line" | awk -F'\t' '{print NF}')
        [ "$cols" -eq 3 ]
    done <<< "$output"
}

@test "groups same-date issues into a single row with count" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture: 2 issues on 2026-04-04 (third entry is a PR, must be filtered)
    count=$(printf '%s\n' "$output" | awk -F'\t' '$1=="2026-04-04" && $2=="issue" {print $3}')
    [ "$count" = "2" ]
}

@test "groups same-date PRs into a single row with count" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture: 3 PRs on 2026-04-05
    count=$(printf '%s\n' "$output" | awk -F'\t' '$1=="2026-04-05" && $2=="pr" {print $3}')
    [ "$count" = "3" ]
}

@test "filters PRs out of issues endpoint via .pull_request null check" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture issue-as-PR has created_at 2026-04-04T12:00:00Z. The two real
    # issues on 2026-04-04 must yield count=2, NOT 3.
    count=$(printf '%s\n' "$output" | awk -F'\t' '$1=="2026-04-04" && $2=="issue" {print $3}')
    [ "$count" = "2" ]
}

@test "respects days argument by including it in API since= URL" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Issues endpoint takes since= directly
    grep -q 'since=' "$MOCK_LOG"
}

@test "skips commits unless INPUT_INCLUDE_GIT_LOG=true" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # No commit rows by default
    n=$(printf '%s\n' "$output" | awk -F'\t' '$2=="commit"' | wc -l)
    [ "$n" -eq 0 ]
}

@test "includes commits when INPUT_INCLUDE_GIT_LOG=true" {
    INPUT_INCLUDE_GIT_LOG=true run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture has commits on 2026-04-08 (x2) and 2026-04-12 (x1)
    count=$(printf '%s\n' "$output" | awk -F'\t' '$1=="2026-04-08" && $2=="commit" {print $3}')
    [ "$count" = "2" ]
}

@test "errors when REPO arg missing" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}
