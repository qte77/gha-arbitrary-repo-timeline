#!/usr/bin/env bats
# Tests for scripts/collect-activity-counts.sh.
# Mocks `gh` via a PATH shim so no network calls happen.
# Emits one row per state-transition event:
#   pr-opened / pr-merged / pr-closed
#   issue-opened / issue-resolved / issue-closed
#   commit (gated on INPUT_INCLUDE_GIT_LOG=true)

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/collect-activity-counts.sh"
    FIXTURE_DIR="$BATS_TEST_DIRNAME/../fixtures"
    MOCK_DIR="$(mktemp -d)"
    MOCK_LOG="$MOCK_DIR/calls.log"

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

# Helper: count rows for a (date, type) pair
count_for() {
    printf '%s\n' "$output" | awk -F'\t' -v d="$1" -v t="$2" '$1==d && $2==t {print $3}'
}

@test "emits TSV with date<TAB>type<TAB>count rows" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        cols=$(printf '%s' "$line" | awk -F'\t' '{print NF}')
        [ "$cols" -eq 3 ]
    done <<< "$output"
}

# --- PR events ---

@test "emits pr-opened on creation date" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture: 3 PRs created 2026-04-05
    [ "$(count_for 2026-04-05 pr-opened)" = "3" ]
    [ "$(count_for 2026-04-15 pr-opened)" = "1" ]
}

@test "emits pr-merged on merged_at date" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture: 1 PR merged 2026-04-06, 1 merged 2026-04-15 (same day as opened)
    [ "$(count_for 2026-04-06 pr-merged)" = "1" ]
    [ "$(count_for 2026-04-15 pr-merged)" = "1" ]
}

@test "emits pr-closed only when closed without merge" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture: PR closed 2026-04-08 with merged_at=null
    [ "$(count_for 2026-04-08 pr-closed)" = "1" ]
    # Merged PRs (closed_at == merged_at) must NOT appear as pr-closed
    [ -z "$(count_for 2026-04-06 pr-closed)" ]
    [ -z "$(count_for 2026-04-15 pr-closed)" ]
}

# --- Issue events ---

@test "emits issue-opened on creation date" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture: 2 issues created 2026-04-04 (3rd entry is PR, filtered)
    [ "$(count_for 2026-04-04 issue-opened)" = "2" ]
    [ "$(count_for 2026-04-10 issue-opened)" = "1" ]
}

@test "emits issue-resolved when state_reason is completed" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    [ "$(count_for 2026-04-09 issue-resolved)" = "1" ]
}

@test "emits issue-closed when state_reason is not completed" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture: issue closed 2026-04-11 with state_reason=not_planned
    [ "$(count_for 2026-04-11 issue-closed)" = "1" ]
    # Resolved issues must NOT appear as issue-closed
    [ -z "$(count_for 2026-04-09 issue-closed)" ]
}

# --- Cross-cutting filters ---

@test "filters PRs out of issues endpoint via .pull_request null check" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # The issue-as-PR (4th fixture entry on 2026-04-04) must NOT inflate count
    [ "$(count_for 2026-04-04 issue-opened)" = "2" ]
}

@test "respects days argument by including it in API since= URL" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    grep -q 'since=' "$MOCK_LOG"
}

@test "skips commits unless INPUT_INCLUDE_GIT_LOG=true" {
    run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    n=$(printf '%s\n' "$output" | awk -F'\t' '$2=="commit"' | wc -l)
    [ "$n" -eq 0 ]
}

@test "includes commits when INPUT_INCLUDE_GIT_LOG=true" {
    INPUT_INCLUDE_GIT_LOG=true run "$SCRIPT" qte77/example 9999
    [ "$status" -eq 0 ]
    # Fixture has 2 commits on 2026-04-08, 1 on 2026-04-12
    [ "$(count_for 2026-04-08 commit)" = "2" ]
}

@test "errors when REPO arg missing" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}
