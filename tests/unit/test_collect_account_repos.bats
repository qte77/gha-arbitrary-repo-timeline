#!/usr/bin/env bats
# Tests for scripts/collect-account-repos.sh (#109 Tier 1 — account discovery).
# Mocks `gh` via a PATH shim per the pattern in test_collect_activity_counts.bats.
#
# GET /users/{login}/repos returns correct results for organization logins
# too (verified empirically against a live org in the implementing session —
# no 404, no separate org/user detection needed), and only ever returns
# public repos for either account type.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/collect-account-repos.sh"
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
    *"/repos?"*) FX="$FIXTURE_DIR/gh-mock-account-repos.json" ;;
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

@test "filters out forks" {
    run "$SCRIPT" qte77
    [ "$status" -eq 0 ]
    [[ "$output" != *"repo-b-fork"* ]]
}

@test "filters out archived repos" {
    run "$SCRIPT" qte77
    [ "$status" -eq 0 ]
    [[ "$output" != *"repo-c-archived"* ]]
}

@test "keeps non-fork non-archived repos, exactly two survive the fixture" {
    run "$SCRIPT" qte77
    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-a"* ]]
    [[ "$output" == *"repo-d-never-pushed"* ]]
    count=$(printf '%s' "$output" | jq -s 'length')
    [ "$count" -eq 2 ]
}

@test "emits exactly the 7 required fields per repo, no more no less" {
    run "$SCRIPT" qte77
    [ "$status" -eq 0 ]
    ok=$(printf '%s' "$output" | jq -se '
        all(.[]; (keys | sort) == ["created_at","description","language","name","pushed_at","stargazers_count","topics"])
    ')
    [ "$ok" = "true" ]
}

@test "paginates the repos call" {
    run "$SCRIPT" qte77
    [ "$status" -eq 0 ]
    grep -q '^PAGINATE=1 .*/repos?' "$MOCK_LOG"
}

@test "requests repos ordered chronologically for the lifespan timeline" {
    run "$SCRIPT" qte77
    [ "$status" -eq 0 ]
    grep -q 'sort=created' "$MOCK_LOG"
}

@test "calls the users/{account}/repos endpoint (works for orgs too, verified live)" {
    run "$SCRIPT" qte77
    [ "$status" -eq 0 ]
    grep -q 'users/qte77/repos' "$MOCK_LOG"
}

@test "errors when account arg missing" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}
