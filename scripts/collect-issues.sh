#!/usr/bin/env bash
# Collect open issues from a repo via GitHub API.
# Args: $1 = owner/repo, $2 = since date (YYYY-MM-DD)
set -euo pipefail

REPO="${1:?Usage: collect-issues.sh owner/repo since-date}"
SINCE="${2:?Missing since date}"

gh api "repos/$REPO/issues?state=all&since=${SINCE}T00:00:00Z&per_page=100" \
    --jq '.[] | select(.pull_request == null) | {date: .created_at[:10], repo: "'"$REPO"'", type: "issue", number: .number, title: .title, state: .state, url: .html_url}'
