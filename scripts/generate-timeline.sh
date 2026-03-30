#!/usr/bin/env bash
# Generate TIMELINE.md from collected issues and PRs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPOS="${INPUT_REPOS:?REPOS input required}"
DAYS="${INPUT_DAYS:-7}"
SINCE=$(days_ago "$DAYS")

IFS=',' read -ra REPO_LIST <<< "$REPOS"
for repo in "${REPO_LIST[@]}"; do
    repo=$(echo "$repo" | xargs) # trim whitespace
    owner="${repo%%/*}"
    name="${repo##*/}"
    mkdir -p "projects/${owner}"
    OUTPUT_FILE="projects/${owner}/${name}_timeline.md"

    echo "Collecting from $repo..."

    echo "# Timeline (last ${DAYS} days)" > "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "## $repo" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Issues
    ISSUES=$("${SCRIPT_DIR}/collect-issues.sh" "$repo" "$SINCE" 2>/dev/null || true)
    if [[ -n "$ISSUES" ]]; then
        echo "$ISSUES" | jq -r '"- [ISSUE #\(.number)] \(.title) (\(.date)) [\(.state)]"' >> "$OUTPUT_FILE"
    fi

    # PRs
    PRS=$("${SCRIPT_DIR}/collect-prs.sh" "$repo" "$SINCE" 2>/dev/null || true)
    if [[ -n "$PRS" ]]; then
        echo "$PRS" | jq -r '"- [PR #\(.number)] \(.title) (\(.date)) [\(.state)]"' >> "$OUTPUT_FILE"
    fi

    # Git log (optional)
    COMMITS=""
    if [[ "${INPUT_INCLUDE_GIT_LOG:-false}" == "true" ]]; then
        COMMITS=$(gh api "repos/$repo/commits?since=${SINCE}T00:00:00Z&per_page=20" \
            --jq '.[] | {date: .commit.author.date[:10], sha: .sha[:7], message: (.commit.message | split("\n")[0])}' 2>/dev/null || true)
        if [[ -n "$COMMITS" ]]; then
            echo "" >> "$OUTPUT_FILE"
            echo "$COMMITS" | jq -r '"- [\(.sha)] \(.message) (\(.date))"' >> "$OUTPUT_FILE"
        fi
    fi

    if [[ -z "$ISSUES" && -z "$PRS" && -z "$COMMITS" ]]; then
        echo "- No activity in the last ${DAYS} days" >> "$OUTPUT_FILE"
    fi

    echo "" >> "$OUTPUT_FILE"
    echo "Timeline written to $OUTPUT_FILE"
done
