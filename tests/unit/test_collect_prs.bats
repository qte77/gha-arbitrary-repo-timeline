#!/usr/bin/env bats
# Tests for scripts/collect-prs.sh, focused on the --state open flag.
# Mocks `gh` via a PATH shim so no network calls happen.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/collect-prs.sh"
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
    *"state=open"*) FX="$FIXTURE_DIR/gh-mock-prs-open.json" ;;
    *"/pulls?"*) FX="$FIXTURE_DIR/gh-mock-prs-since.json" ;;
    *) echo "[]"; exit 0 ;;
esac
if [[ -n "\$JQ" ]]; then
    jq "\$JQ" "\$FX"
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

@test "default (since-date) behavior is unchanged: queries state=all and filters by updated_at >= since" {
    run "$SCRIPT" qte77/example 2026-04-07
    [ "$status" -eq 0 ]
    grep -q 'state=all' "$MOCK_LOG"
    ! grep -q 'state=open' "$MOCK_LOG"
    # Fixture: only PR #302 has updated_at (2026-04-08) >= since (2026-04-07);
    # #301 (2026-04-06) and #303 (2026-04-05) are updated before the bound.
    n=$(jq -s 'length' <<< "$output")
    [ "$n" -eq 1 ]
    number=$(jq -r '.number' <<< "$output")
    [ "$number" -eq 302 ]
}

@test "--state open switches to a live, unbounded query (no since bound)" {
    run "$SCRIPT" qte77/example --state open
    [ "$status" -eq 0 ]
    grep -q 'state=open' "$MOCK_LOG"
    ! grep -q 'since=' "$MOCK_LOG"
}

@test "--state open paginates" {
    run "$SCRIPT" qte77/example --state open
    [ "$status" -eq 0 ]
    grep -q '^PAGINATE=1 .*state=open' "$MOCK_LOG"
}

@test "--state open returns currently-open items without time-bound filtering" {
    run "$SCRIPT" qte77/example --state open
    [ "$status" -eq 0 ]
    n=$(jq -s 'length' <<< "$output")
    [ "$n" -eq 1 ]
    date=$(jq -r '.date' <<< "$output")
    [ "$date" = "2020-01-01" ]
}

@test "errors when REPO arg missing" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "errors when neither since-date nor --state open is given" {
    run "$SCRIPT" qte77/example
    [ "$status" -ne 0 ]
}
