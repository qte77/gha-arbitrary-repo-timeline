#!/usr/bin/env bash
# Collect open PRs from a repo via GitHub API.
# Args: $1 = owner/repo, $2 = since date (YYYY-MM-DD)
set -euo pipefail

REPO="${1:?Usage: collect-prs.sh owner/repo since-date}"
SINCE="${2:?Missing since date}"

gh api "repos/$REPO/pulls?state=open&per_page=100" \
    --jq '.[] | select(.created_at >= "'"${SINCE}"'") | {date: .created_at[:10], repo: "'"$REPO"'", type: "pr", number: .number, title: .title, url: .html_url}'
