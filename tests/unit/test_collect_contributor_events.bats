#!/usr/bin/env bats
# Tests for scripts/collect-contributor-events.sh.
# Emits JSONL {"login","type":"pr"|"issue"|"commit","timestamp"} — internal
# helper for collect-contributors.sh. Mocks `gh` via a PATH shim so no
# network calls happen.
#
# Fixture tally (per login, across all 3 fixtures):
#   alice: 2 pr + 2 issue + 1 commit = 5
#   bob:   1 pr + 0 issue + 2 commit = 3
#   carol: 3 pr + 3 issue + 3 commit = 9
#   dave:  0 (fixture row has pull_request set -> filtered as PR-as-issue)
# Plus one null-user PR row and one null-author commit row, both dropped.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/collect-contributor-events.sh"
    FIXTURE_DIR="$BATS_TEST_DIRNAME/../fixtures"
    MOCK_DIR="$(mktemp -d)"
    MOCK_LOG="$MOCK_DIR/calls.log"

    cat > "$MOCK_DIR/gh" <<MOCK
#!/usr/bin/env bash
set -e
JQ=""
URL=""
PAGINATE=0
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        --jq) JQ="\$2"; shift 2 ;;
        --paginate) PAGINATE=1; shift ;;
        api) shift ;;
        *) [[ -z "\$URL" ]] && URL="\$1"; shift ;;
    esac
done
echo "PAGINATE=\$PAGINATE \$URL" >> "$MOCK_LOG"
case "\$URL" in
    *"/pulls?"*) FX="$FIXTURE_DIR/gh-mock-contributor-prs.json" ;;
    *"/issues?"*) FX="$FIXTURE_DIR/gh-mock-contributor-issues.json" ;;
    *"/commits?"*) FX="$FIXTURE_DIR/gh-mock-contributor-commits.json" ;;
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

count_for() {
    printf '%s\n' "$output" | jq -r "select(.login==\"$1\" and .type==\"$2\") | .login" | wc -l | tr -d ' '
}

@test "emits JSONL with login/type/timestamp keys only" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        keys=$(printf '%s' "$line" | jq -r 'keys | sort | join(",")')
        [ "$keys" = "login,timestamp,type" ]
    done <<< "$output"
}

@test "emits pr events with correct logins and drops null user" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    [ "$(count_for alice pr)" = "2" ]
    [ "$(count_for bob pr)" = "1" ]
    [ "$(count_for carol pr)" = "3" ]
    # 7 fixture rows, 1 has user:null -> 6 pr events total
    n=$(printf '%s\n' "$output" | jq -r 'select(.type=="pr")' | jq -s 'length')
    [ "$n" -eq 6 ]
}

@test "emits issue events and filters PR-as-issue rows" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    [ "$(count_for alice issue)" = "2" ]
    [ "$(count_for carol issue)" = "3" ]
    # dave's row has pull_request set -> filtered, never appears as an issue event
    [ "$(count_for dave issue)" = "0" ]
}

@test "emits commit events from .author.login and .commit.author.date only" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    [ "$(count_for alice commit)" = "1" ]
    [ "$(count_for bob commit)" = "2" ]
    [ "$(count_for carol commit)" = "3" ]
}

@test "commit events never expose .commit.author.email or .commit.author.name" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    [[ "$output" != *"email"* ]]
    [[ "$output" != *"@example.com"* ]]
    [[ "$output" != *"Example"* ]]
}

@test "null-author commit row does not appear in output and is dropped silently" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    [[ "$output" != *"ghost"* ]]
    n=$(printf '%s\n' "$output" | jq -r 'select(.type=="commit")' | jq -s 'length')
    # 7 commit fixture rows, 1 null-author -> 6 commit events
    [ "$n" -eq 6 ]
}

@test "paginates the /issues call so issues are not lost behind PRs" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    grep -q '^PAGINATE=1 .*/issues?' "$MOCK_LOG"
}

@test "total window tally across pr+issue+commit matches hand-computed counts" {
    run "$SCRIPT" qte77/example 2026-04-01
    [ "$status" -eq 0 ]
    alice_total=$(printf '%s\n' "$output" | jq -r 'select(.login=="alice")' | jq -s 'length')
    bob_total=$(printf '%s\n' "$output" | jq -r 'select(.login=="bob")' | jq -s 'length')
    carol_total=$(printf '%s\n' "$output" | jq -r 'select(.login=="carol")' | jq -s 'length')
    [ "$alice_total" -eq 5 ]
    [ "$bob_total" -eq 3 ]
    [ "$carol_total" -eq 9 ]
}

@test "errors when REPO arg missing" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "errors when SINCE arg missing" {
    run "$SCRIPT" qte77/example
    [ "$status" -ne 0 ]
}
