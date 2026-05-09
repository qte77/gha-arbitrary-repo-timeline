#!/usr/bin/env bash
# Emit daily activity counts as TSV (date<TAB>event<TAB>count) for one repo.
#
# Usage: collect-activity-counts.sh owner/repo [days]
#
# Each PR/issue contributes one row per state-transition event whose date
# falls in the [days-ago, today] window. Event tokens:
#   pr-opened     — PR created
#   pr-merged     — PR merged (any merge method)
#   pr-closed     — PR closed without merge
#   issue-opened  — issue created
#   issue-resolved — issue closed with state_reason=completed
#   issue-closed  — issue closed with state_reason != completed
#   commit        — commit recorded (only when INPUT_INCLUDE_GIT_LOG=true)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

REPO="${1:?Usage: collect-activity-counts.sh owner/repo [days]}"
DAYS="${2:-30}"
SINCE=$(days_ago "$DAYS")

# Group lines (each "date<TAB>event") into "date<TAB>event<TAB>count" rows.
bucket() {
    sort | uniq -c | awk -v OFS='\t' '$1 > 0 { print $2, $3, $1 }'
}

emit_pr_events() {
    local filter
    filter=$(
        cat <<EOF
.[] |
  (if .created_at[:10] >= "$SINCE" then "\(.created_at[:10])\tpr-opened" else empty end),
  (if .merged_at != null and .merged_at[:10] >= "$SINCE" then "\(.merged_at[:10])\tpr-merged" else empty end),
  (if .merged_at == null and .closed_at != null and .closed_at[:10] >= "$SINCE" then "\(.closed_at[:10])\tpr-closed" else empty end)
EOF
    )
    gh api "repos/${REPO}/pulls?state=all&per_page=100" --jq "$filter" | bucket
}

emit_issue_events() {
    local filter
    filter=$(
        cat <<EOF
.[] | select(.pull_request == null) |
  (if .created_at[:10] >= "$SINCE" then "\(.created_at[:10])\tissue-opened" else empty end),
  (if .closed_at != null and .state_reason == "completed" and .closed_at[:10] >= "$SINCE" then "\(.closed_at[:10])\tissue-resolved" else empty end),
  (if .closed_at != null and (.state_reason != "completed") and .closed_at[:10] >= "$SINCE" then "\(.closed_at[:10])\tissue-closed" else empty end)
EOF
    )
    # --paginate: /issues mixes issues+PRs ordered by updated_at; on PR-heavy
    # repos issues fall past page 1 if we don't sweep all pages.
    gh api --paginate "repos/${REPO}/issues?state=all&since=${SINCE}T00:00:00Z&per_page=100" --jq "$filter" | bucket
}

emit_commits() {
    gh api "repos/${REPO}/commits?since=${SINCE}T00:00:00Z&per_page=100" \
        --jq '.[] | "\(.commit.author.date[:10])\tcommit"' |
        bucket
}

emit_pr_events
emit_issue_events
[[ "${INPUT_INCLUDE_GIT_LOG:-false}" == "true" ]] && emit_commits
exit 0
