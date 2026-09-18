#!/usr/bin/env bash
# Collect PRs from a repo via GitHub API.
# Args: $1 = owner/repo, $2 = since date (YYYY-MM-DD)
#   or: $1 = owner/repo, --state open (live, unbounded query, open items only)
set -euo pipefail

REPO="${1:?Usage: collect-prs.sh owner/repo since-date | collect-prs.sh owner/repo --state open}"

if [[ "${2:-}" == "--state" && "${3:-}" == "open" ]]; then
    # Live, unbounded query: state=open already restricts to currently-open
    # PRs, so no since-bound select is needed. --paginate mirrors
    # collect-issues.sh's open-state query so PR-heavy repos aren't truncated.
    gh api --paginate "repos/$REPO/pulls?state=open&per_page=100" \
        --jq '.[] | {date: .created_at[:10], repo: "'"$REPO"'", type: "pr", number: .number, title: .title, state: .state, url: .html_url}'
else
    SINCE="${2:?Missing since date}"
    gh api "repos/$REPO/pulls?state=all&per_page=100" \
        --jq '.[] | select(.updated_at >= "'"${SINCE}"'") | {date: .created_at[:10], repo: "'"$REPO"'", type: "pr", number: .number, title: .title, state: .state, url: .html_url}'
fi
