#!/usr/bin/env bats
# Tests for scripts/collect-contributors.sh (aggregation + privacy filters).
# Mocks `gh` via a PATH shim so no network calls happen. Internally this
# script shells out to collect-contributor-events.sh, which is exercised
# here via the same pulls/issues/commits fixtures used by
# test_collect_contributor_events.bats:
#   alice: 5 window events (boundary -> enriched)
#   bob:   3 window events (-> login-only)
#   carol: 9 window events (-> enriched)
#
# gh-mock-contributors.json (lifetime list): alice 50, bob 30, carol 15,
# dave 5 (total 100) -> top_contributor_share=0.50, top_3_share=0.95.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/collect-contributors.sh"
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
        --paginate) shift ;;
        api) shift ;;
        *) [[ -z "\$URL" ]] && URL="\$1"; shift ;;
    esac
done
echo "\$URL" >> "$MOCK_LOG"
case "\$URL" in
    *"/contents/.timeline-no-contributors")
        if [[ "\${MOCK_OPTOUT:-0}" == "1" ]]; then
            echo '{"name": ".timeline-no-contributors"}'
            exit 0
        else
            exit 1
        fi
        ;;
    *"/pulls?"*) FX="$FIXTURE_DIR/gh-mock-contributor-prs.json" ;;
    *"/issues?"*) FX="$FIXTURE_DIR/gh-mock-contributor-issues.json" ;;
    *"/commits?"*) FX="$FIXTURE_DIR/gh-mock-contributor-commits.json" ;;
    *"/contributors")
        if [[ "\${MOCK_EMPTY_CONTRIBUTORS:-0}" == "1" ]]; then
            echo '[]'
        else
            FX="$FIXTURE_DIR/gh-mock-contributors.json"
        fi
        ;;
    orgs/*)
        if [[ "\${MOCK_ORG_404:-0}" == "1" ]]; then
            exit 1
        fi
        FX="$FIXTURE_DIR/gh-mock-org.json"
        ;;
    users/*) FX="$FIXTURE_DIR/gh-mock-user-profile.json" ;;
    *) echo "[]"; exit 0 ;;
esac
if [[ -n "\${FX:-}" ]]; then
    if [[ -n "\$JQ" ]]; then
        jq -r "\$JQ" "\$FX"
    else
        cat "\$FX"
    fi
fi
MOCK
    chmod +x "$MOCK_DIR/gh"
    PATH="$MOCK_DIR:$PATH"
    export PATH
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "opt-out present (200) skips collection entirely and emits nothing" {
    MOCK_OPTOUT=1 run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "opt-out absent (404) proceeds with normal collection" {
    run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | jq -e '.contributors' > /dev/null
}

@test "aggregation threshold: enriched at/above 5, login-only below" {
    INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=false run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    alice_tier=$(echo "$output" | jq -r '.contributors[] | select(.login=="alice") | .tier')
    bob_tier=$(echo "$output" | jq -r '.contributors[] | select(.login=="bob") | .tier')
    carol_tier=$(echo "$output" | jq -r '.contributors[] | select(.login=="carol") | .tier')
    [ "$alice_tier" = "enriched" ]
    [ "$bob_tier" = "login-only" ]
    [ "$carol_tier" = "enriched" ]
    alice_events=$(echo "$output" | jq -r '.contributors[] | select(.login=="alice") | .window_events')
    bob_events=$(echo "$output" | jq -r '.contributors[] | select(.login=="bob") | .window_events')
    carol_events=$(echo "$output" | jq -r '.contributors[] | select(.login=="carol") | .window_events')
    [ "$alice_events" -eq 5 ]
    [ "$bob_events" -eq 3 ]
    [ "$carol_events" -eq 9 ]
}

@test "total_window_events sums all contributors' window events" {
    run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    total=$(echo "$output" | jq -r '.total_window_events')
    [ "$total" -eq 17 ]
}

@test "output never contains the string email, with or without profile details" {
    run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    [[ "$output" != *"email"* ]]

    INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    [[ "$output" != *"email"* ]]
    [[ "$output" != *"@example.com"* ]]
}

@test "profile enrichment fetched only for enriched-tier contributors when PROFILE_DETAILS=true" {
    INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    alice_profile_keys=$(echo "$output" | jq -r '.contributors[] | select(.login=="alice") | .profile | keys | sort | join(",")')
    carol_profile_keys=$(echo "$output" | jq -r '.contributors[] | select(.login=="carol") | .profile | keys | sort | join(",")')
    [ "$alice_profile_keys" = "_source,bio,company,location" ]
    [ "$carol_profile_keys" = "_source,bio,company,location" ]
    bob_has_profile=$(echo "$output" | jq -r '.contributors[] | select(.login=="bob") | has("profile")')
    [ "$bob_has_profile" = "false" ]
}

@test "no users/ API call is made when PROFILE_DETAILS is false (default)" {
    run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    ! grep -q '^users/' "$MOCK_LOG"
    no_profile_keys=$(echo "$output" | jq -r '[.contributors[] | has("profile")] | any')
    [ "$no_profile_keys" = "false" ]
}

@test "org metadata is allowlisted to login/public_repos/created_at/html_url" {
    run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    org_keys=$(echo "$output" | jq -r '.org | keys | sort | join(",")')
    [ "$org_keys" = "created_at,html_url,login,public_repos" ]
    org_login=$(echo "$output" | jq -r '.org.login')
    [ "$org_login" = "qte77" ]
}

@test "org 404 (personal account) yields null org and still exits 0" {
    MOCK_ORG_404=1 run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    org=$(echo "$output" | jq -r '.org')
    [ "$org" = "null" ]
}

@test "contribution_concentration matches hand-computed shares" {
    run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    top1=$(echo "$output" | jq -r '.contribution_concentration.top_contributor_share')
    top3=$(echo "$output" | jq -r '.contribution_concentration.top_3_share')
    [ "$top1" = "0.5" ]
    [ "$top3" = "0.95" ]
}

@test "contribution_concentration is null when lifetime contributors list is empty" {
    MOCK_EMPTY_CONTRIBUTORS=1 run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    concentration=$(echo "$output" | jq -r '.contribution_concentration')
    [ "$concentration" = "null" ]
}

@test "source_urls lists contributors, org, and per-enriched-profile users URLs" {
    INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    n_urls=$(echo "$output" | jq -r '.source_urls | length')
    has_contributors=$(echo "$output" | jq -r '.source_urls | any(endswith("/contributors"))')
    has_org=$(echo "$output" | jq -r '.source_urls | any(startswith("orgs/"))')
    users_count=$(echo "$output" | jq -r '[.source_urls[] | select(startswith("users/"))] | length')
    [ "$has_contributors" = "true" ]
    [ "$has_org" = "true" ]
    [ "$users_count" -eq 2 ]
    [ "$n_urls" -ge 4 ]
}

@test "output carries repo/since/window_days metadata" {
    run "$SCRIPT" qte77/example 2026-04-01 7
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.repo')" = "qte77/example" ]
    [ "$(echo "$output" | jq -r '.since')" = "2026-04-01" ]
    [ "$(echo "$output" | jq -r '.window_days')" -eq 7 ]
}

@test "errors when required args are missing" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}
