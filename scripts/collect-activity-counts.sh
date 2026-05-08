#!/usr/bin/env bash
# Emit daily activity counts as TSV (date<TAB>type<TAB>count) for one repo.
#
# Usage: collect-activity-counts.sh owner/repo [days]
#
# Pulls issues + PRs (always) and commits (when INPUT_INCLUDE_GIT_LOG=true)
# created since N days ago (default 30), groups by date and type, writes
# one row per (date, type) with count > 0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

REPO="${1:?Usage: collect-activity-counts.sh owner/repo [days]}"
DAYS="${2:-30}"
SINCE=$(days_ago "$DAYS")

emit_issues() {
    gh api "repos/${REPO}/issues?state=all&since=${SINCE}T00:00:00Z&per_page=100" \
        --jq '.[] | select(.pull_request == null) | .created_at[:10]' \
        | sort | uniq -c \
        | awk -v OFS='\t' '$1 > 0 { print $2, "issue", $1 }'
}

emit_prs() {
    gh api "repos/${REPO}/pulls?state=all&per_page=100" \
        --jq ".[] | select(.created_at >= \"${SINCE}\") | .created_at[:10]" \
        | sort | uniq -c \
        | awk -v OFS='\t' '$1 > 0 { print $2, "pr", $1 }'
}

emit_commits() {
    gh api "repos/${REPO}/commits?since=${SINCE}T00:00:00Z&per_page=100" \
        --jq '.[] | .commit.author.date[:10]' \
        | sort | uniq -c \
        | awk -v OFS='\t' '$1 > 0 { print $2, "commit", $1 }'
}

emit_issues
emit_prs
[[ "${INPUT_INCLUDE_GIT_LOG:-false}" == "true" ]] && emit_commits
exit 0
