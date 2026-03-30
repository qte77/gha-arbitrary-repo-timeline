#!/usr/bin/env bash
# Generate cumulative timeline from collected issues, PRs, and commits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPOS="${INPUT_REPOS:?REPOS input required}"
DAYS="${INPUT_DAYS:-7}"
SINCE=$(days_ago "$DAYS")
RUN_DATE=$(date -u +%Y-%m-%d)

IFS=',' read -ra REPO_LIST <<< "$REPOS"
for repo in "${REPO_LIST[@]}"; do
    repo=$(echo "$repo" | xargs) # trim whitespace
    owner="${repo%%/*}"
    name="${repo##*/}"
    mkdir -p "timelines/${owner}"
    OUTPUT_FILE="timelines/${owner}/${name}.md"

    echo "Collecting from $repo..."

    # Collect new activity
    NEW_ITEMS=""

    # Issues
    ISSUES=$("${SCRIPT_DIR}/collect-issues.sh" "$repo" "$SINCE" 2>/dev/null || true)
    if [[ -n "$ISSUES" ]]; then
        NEW_ITEMS+=$(echo "$ISSUES" | jq -r '"- [ISSUE #\(.number)] \(.title) (\(.date)) [\(.state)]"')
        NEW_ITEMS+=$'\n'
    fi

    # PRs
    PRS=$("${SCRIPT_DIR}/collect-prs.sh" "$repo" "$SINCE" 2>/dev/null || true)
    if [[ -n "$PRS" ]]; then
        NEW_ITEMS+=$(echo "$PRS" | jq -r '"- [PR #\(.number)] \(.title) (\(.date)) [\(.state)]"')
        NEW_ITEMS+=$'\n'
    fi

    # Git log (optional)
    if [[ "${INPUT_INCLUDE_GIT_LOG:-false}" == "true" ]]; then
        COMMITS=$(gh api "repos/$repo/commits?since=${SINCE}T00:00:00Z&per_page=20" \
            --jq '.[] | {date: .commit.author.date[:10], sha: .sha[:7], message: (.commit.message | split("\n")[0])}' 2>/dev/null || true)
        if [[ -n "$COMMITS" ]]; then
            NEW_ITEMS+=$(echo "$COMMITS" | jq -r '"- [\(.sha)] \(.message) (\(.date))"')
            NEW_ITEMS+=$'\n'
        fi
    fi

    # Skip if no new activity
    if [[ -z "${NEW_ITEMS// /}" ]]; then
        echo "No new activity for $repo"
        continue
    fi

    # Dedup: filter out lines already in existing file
    if [[ -f "$OUTPUT_FILE" ]]; then
        FILTERED=""
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if ! grep -qF "$line" "$OUTPUT_FILE"; then
                FILTERED+="$line"$'\n'
            fi
        done <<< "$NEW_ITEMS"
        NEW_ITEMS="$FILTERED"
    fi

    # Skip if all items already exist
    if [[ -z "${NEW_ITEMS// /}" ]]; then
        echo "No new unique items for $repo"
        continue
    fi

    # Create header if file doesn't exist
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        {
            echo "# $repo — Timeline"
            echo ""
        } > "$OUTPUT_FILE"
    fi

    # Append new date section
    {
        echo "## $RUN_DATE"
        echo ""
        printf '%s' "$NEW_ITEMS"
        echo ""
    } >> "$OUTPUT_FILE"

    echo "Timeline updated: $OUTPUT_FILE"
done
