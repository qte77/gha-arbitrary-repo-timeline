#!/usr/bin/env bash
# Collect raw per-contributor events (PR/issue/commit) for the contributor
# aggregation window. Internal helper for collect-contributors.sh — emits
# JSONL, one object per contribution event: {"login","type","timestamp"}.
#
# Separate API calls from collect-prs.sh/collect-issues.sh (does not touch
# their existing contract/tests). Commit rows are sourced ONLY from
# .author.login + .commit.author.date — .commit.author.email and
# .commit.author.name are NEVER read, so PII cannot leak through this path.
#
# Args: $1 = owner/repo, $2 = since date (YYYY-MM-DD)
set -euo pipefail

REPO="${1:?Usage: collect-contributor-events.sh owner/repo since-date}"
SINCE="${2:?Missing since date}"

emit_pr_events() {
    gh api "repos/${REPO}/pulls?state=all&per_page=100" \
        --jq '.[] | select(.updated_at[:10] >= "'"${SINCE}"'") | select(.user.login != null) | {login: .user.login, type: "pr", timestamp: .created_at}'
}

emit_issue_events() {
    # --paginate: /issues mixes issues+PRs ordered by updated_at; on
    # PR-heavy repos issues fall past page 1 if we don't sweep all pages.
    gh api --paginate "repos/${REPO}/issues?state=all&since=${SINCE}T00:00:00Z&per_page=100" \
        --jq '.[] | select(.pull_request == null) | select(.user.login != null) | {login: .user.login, type: "issue", timestamp: .created_at}'
}

emit_commit_events() {
    # Deliberately reads only .author.login + .commit.author.date.
    # .commit.author.email / .commit.author.name are NEVER selected.
    gh api "repos/${REPO}/commits?since=${SINCE}T00:00:00Z&per_page=100" \
        --jq '.[] | select(.author != null) | select(.author.login != null) | {login: .author.login, type: "commit", timestamp: .commit.author.date}'
}

# Normalize to compact JSONL regardless of gh's/jq's internal pretty-print
# formatting, so downstream tallying can rely on one event per line.
{
    emit_pr_events
    emit_issue_events
    emit_commit_events
} | jq -c '.'
