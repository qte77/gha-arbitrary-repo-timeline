#!/usr/bin/env bash
# Enumerate an account's (user OR organization) non-fork, non-archived repos
# for the account-level lifespan timeline (#109 Tier 1).
#
# Usage: collect-account-repos.sh <account>
#
# GET /users/{login}/repos already returns correct results for organization
# logins too — verified empirically in the implementing session (a live call
# against a known org returned its repos with type:Organization, no 404).
# No separate org/user detection is needed; this always calls users/{account}.
# Note: that endpoint only ever returns PUBLIC repos, for both account types.
#
# Emits one JSON object per surviving repo (concatenated stream, not a JSON
# array — same convention as collect-issues.sh/collect-prs.sh) with exactly
# the 7 fields the account renderer needs: name, description, language,
# created_at, pushed_at, stargazers_count, topics.
set -euo pipefail

ACCOUNT="${1:?Usage: collect-account-repos.sh account}"

# sort=created&direction=asc: a lifespan gantt reads chronologically;
# the API's default order (full_name) would scramble the chart.
gh api --paginate "users/${ACCOUNT}/repos?per_page=100&sort=created&direction=asc" \
    --jq '.[] | select(.fork == false and .archived == false) | {name, description, language, created_at, pushed_at, stargazers_count, topics}'
