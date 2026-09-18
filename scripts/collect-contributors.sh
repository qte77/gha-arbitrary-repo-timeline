#!/usr/bin/env bash
# Aggregate windowed contributor activity + lifetime concentration + org
# metadata into a single JSON payload for assets/<owner>/<repo>-contributors.json.
#
# Privacy posture (#110): per-contributor profile enrichment
# (location/company/bio) happens only when
# INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true AND the contributor cleared the
# window-events threshold. Emails are never read anywhere in this script —
# the jq allowlists never select `.email`, so leakage is structurally
# impossible, not just redacted after the fact. Callers MUST have already
# run assert_contributor_gate (scripts/common.sh) before invoking this
# script; it is not re-checked here.
#
# .timeline-no-contributors opt-out: if present (200), this script emits
# NOTHING and exits 0 — the caller (generate-timeline.sh) treats empty
# output the same as INCLUDE_CONTRIBUTORS=false and removes any stale
# MD block / JSON asset from a prior run.
#
# Args: $1 = owner/repo, $2 = since date (YYYY-MM-DD), $3 = window days
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO="${1:?Usage: collect-contributors.sh owner/repo since-date days}"
SINCE="${2:?Missing since date}"
DAYS="${3:?Missing window days}"
OWNER="${REPO%%/*}"

readonly CONTRIBUTOR_MIN_EVENTS=5

if gh api "repos/${REPO}/contents/.timeline-no-contributors" >/dev/null 2>&1; then
    exit 0
fi

SCRAPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Windowed per-login event tally (PR + issue + commit events). Per-login
# rows come exclusively from here — never from the lifetime /contributors
# list below, which feeds only the aggregate concentration bucket.
TALLY_JSON=$(
    "${SCRIPT_DIR}/collect-contributor-events.sh" "$REPO" "$SINCE" 2>/dev/null |
        jq -s 'group_by(.login) | map({login: .[0].login, window_events: length}) | sort_by(-.window_events)'
)
[[ -z "$TALLY_JSON" ]] && TALLY_JSON='[]'

TOTAL_WINDOW_EVENTS=$(echo "$TALLY_JSON" | jq '[.[].window_events] | add // 0')

CONTRIBUTORS_URL="repos/${REPO}/contributors"
LIFETIME_JSON=$(gh api "$CONTRIBUTORS_URL" 2>/dev/null || echo '[]')
CONCENTRATION=$(echo "$LIFETIME_JSON" | jq '
    if length == 0 then null
    else
        ([.[].contributions] | add // 0) as $total |
        if $total == 0 then null
        else
            ([.[].contributions] | sort | reverse) as $sorted |
            {
                top_contributor_share: (($sorted[0] // 0) / $total),
                top_3_share: (([$sorted[0], $sorted[1], $sorted[2]] | map(. // 0) | add) / $total)
            }
        end
    end
')

SOURCE_URLS=$(jq -n --arg u "$CONTRIBUTORS_URL" '[$u]')

# Org metadata is best-effort: /orgs/{login} 404s for a personal-account
# owner, which is not an error.
ORGS_URL="orgs/${OWNER}"
ORG_JSON="null"
if RAW_ORG=$(gh api "$ORGS_URL" 2>/dev/null); then
    ORG_JSON=$(echo "$RAW_ORG" | jq '{login, public_repos, created_at, html_url}')
    SOURCE_URLS=$(echo "$SOURCE_URLS" | jq --arg u "$ORGS_URL" '. + [$u]')
fi

INCLUDE_PROFILES="${INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS:-false}"

CONTRIBUTORS_JSON='[]'
while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    login=$(echo "$row" | jq -r '.login')
    events=$(echo "$row" | jq -r '.window_events')
    tier="login-only"
    [[ "$events" -ge "$CONTRIBUTOR_MIN_EVENTS" ]] && tier="enriched"

    entry=$(jq -n \
        --arg login "$login" \
        --arg url "https://github.com/${login}" \
        --argjson events "$events" \
        --arg tier "$tier" \
        '{login: $login, html_url: $url, window_events: $events, tier: $tier}')

    if [[ "$tier" == "enriched" && "$INCLUDE_PROFILES" == "true" ]]; then
        USERS_URL="users/${login}"
        if RAW_PROFILE=$(gh api "$USERS_URL" 2>/dev/null); then
            PROFILE=$(echo "$RAW_PROFILE" | jq '{location, company, bio, _source: "self-reported GitHub profile field, not verified"}')
            entry=$(echo "$entry" | jq --argjson p "$PROFILE" '. + {profile: $p}')
            SOURCE_URLS=$(echo "$SOURCE_URLS" | jq --arg u "$USERS_URL" '. + [$u]')
        fi
    fi

    CONTRIBUTORS_JSON=$(echo "$CONTRIBUTORS_JSON" | jq --argjson e "$entry" '. + [$e]')
done < <(echo "$TALLY_JSON" | jq -c '.[]')

jq -n \
    --arg repo "$REPO" \
    --arg scraped_at "$SCRAPED_AT" \
    --argjson window_days "$DAYS" \
    --arg since "$SINCE" \
    --argjson source_urls "$SOURCE_URLS" \
    --argjson total_window_events "$TOTAL_WINDOW_EVENTS" \
    --argjson concentration "$CONCENTRATION" \
    --argjson org "$ORG_JSON" \
    --argjson contributors "$CONTRIBUTORS_JSON" \
    '{
        repo: $repo,
        scraped_at: $scraped_at,
        window_days: $window_days,
        since: $since,
        source_urls: $source_urls,
        total_window_events: $total_window_events,
        contribution_concentration: $concentration,
        org: $org,
        contributors: $contributors
    }'
