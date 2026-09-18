#!/usr/bin/env bash
# Collect issues from a repo via GitHub API.
# Args: $1 = owner/repo, $2 = since date (YYYY-MM-DD)
#   or: $1 = owner/repo, --state open (live, unbounded query, open items only)
set -euo pipefail

REPO="${1:?Usage: collect-issues.sh owner/repo since-date | collect-issues.sh owner/repo --state open}"

if [[ "${2:-}" == "--state" && "${3:-}" == "open" ]]; then
    # Live, unbounded query: no since bound, only currently-open items.
    QUERY="repos/$REPO/issues?state=open&per_page=100"
else
    SINCE="${2:?Missing since date}"
    QUERY="repos/$REPO/issues?state=all&since=${SINCE}T00:00:00Z&per_page=100"
fi

# --paginate: /issues mixes issues+PRs ordered by updated_at; on PR-heavy
# repos real issues fall past page 1 if we don't sweep all pages.
gh api --paginate "$QUERY" \
    --jq '.[] | select(.pull_request == null) | {date: .created_at[:10], repo: "'"$REPO"'", type: "issue", number: .number, title: .title, state: .state, url: .html_url}'
