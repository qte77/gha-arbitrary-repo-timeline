#!/usr/bin/env bash
# Generate cumulative timeline from collected issues, PRs, and commits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Dedup by ID token ([PR #N], [ISSUE #N], or [<short-sha>]) so that state/date
# drift on an existing item does not cause a duplicate append.
# Args: $1 = newline-separated items, $2 = existing output file
# Prints: filtered items (only those whose ID is absent from the file)
dedup_items() {
    local items="$1" file="$2"
    [[ ! -f "$file" ]] && { printf '%s' "$items"; return; }
    local filtered="" line id
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        id=$(printf '%s' "$line" | grep -oE '\[(PR|ISSUE) #[0-9]+\]|\[[a-f0-9]{7,}\]' | head -1)
        if [[ -n "$id" ]] && grep -qF "$id" "$file"; then
            continue
        fi
        filtered+="$line"$'\n'
    done <<< "$items"
    printf '%s' "$filtered"
}

# Insert an activity-SVG image reference once after the H1 of the timeline
# file, guarded by a marker comment so re-runs don't duplicate the embed.
# Args: $1 = output file, $2 = relative path to SVG (used in markdown image)
prepend_activity_embed() {
    local file="$1" rel="$2"
    [[ ! -f "$file" ]] && return 0
    grep -qF '<!-- activity-svg-embed -->' "$file" && return 0
    local tmp
    tmp=$(mktemp)
    awk -v rel="$rel" '
        NR == 1 { print; print ""; print "<!-- activity-svg-embed -->"; print "![activity](" rel ")"; next }
        NR == 2 && $0 == "" { next }  # collapse the blank line that originally followed H1
        { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Append items to the output file. If a '## RUN_DATE' header already exists,
# append without a new header; otherwise create a new date section.
# Args: $1 = output file, $2 = run date, $3 = items
append_section() {
    local file="$1" run_date="$2" items="$3"
    if grep -qxF "## $run_date" "$file" 2>/dev/null; then
        printf '%s' "$items" >> "$file"
    else
        {
            echo "## $run_date"
            echo ""
            printf '%s' "$items"
            echo ""
        } >> "$file"
    fi
}

main() {
    local REPOS="${INPUT_REPOS:?REPOS input required}"
    local DAYS="${INPUT_DAYS:-7}"
    local SINCE
    SINCE=$(days_ago "$DAYS")
    local RUN_DATE
    RUN_DATE=$(date -u +%Y-%m-%d)

    IFS=',' read -ra REPO_LIST <<< "$REPOS"
    for repo in "${REPO_LIST[@]}"; do
        repo=$(echo "$repo" | xargs) # trim whitespace
        local owner="${repo%%/*}"
        local name="${repo##*/}"
        mkdir -p "timelines/${owner}"
        local OUTPUT_FILE="timelines/${owner}/${name}.md"

        echo "Collecting from $repo..."

        # Collect new activity
        local NEW_ITEMS=""

        # Issues
        local ISSUES
        ISSUES=$("${SCRIPT_DIR}/collect-issues.sh" "$repo" "$SINCE" 2>/dev/null || true)
        if [[ -n "$ISSUES" ]]; then
            NEW_ITEMS+=$(echo "$ISSUES" | jq -r '"- [ISSUE #\(.number)] \(.title) (\(.date)) [\(.state)]"')
            NEW_ITEMS+=$'\n'
        fi

        # PRs
        local PRS
        PRS=$("${SCRIPT_DIR}/collect-prs.sh" "$repo" "$SINCE" 2>/dev/null || true)
        if [[ -n "$PRS" ]]; then
            NEW_ITEMS+=$(echo "$PRS" | jq -r '"- [PR #\(.number)] \(.title) (\(.date)) [\(.state)]"')
            NEW_ITEMS+=$'\n'
        fi

        # Git log (optional)
        if [[ "${INPUT_INCLUDE_GIT_LOG:-false}" == "true" ]]; then
            local COMMITS
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

        # Dedup against existing file
        NEW_ITEMS=$(dedup_items "$NEW_ITEMS" "$OUTPUT_FILE")

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

        append_section "$OUTPUT_FILE" "$RUN_DATE" "$NEW_ITEMS"

        # Generate / refresh the themed activity SVG and embed once.
        local ASSETS_DIR="assets/${owner}"
        local ASSET_FILE="${ASSETS_DIR}/${name}-activity.svg"
        local TSV
        TSV=$(mktemp)
        if "${SCRIPT_DIR}/collect-activity-counts.sh" "$repo" 30 > "$TSV" 2>/dev/null; then
            mkdir -p "$ASSETS_DIR"
            "${SCRIPT_DIR}/render-activity-svg.sh" "$repo" < "$TSV" > "$ASSET_FILE"
            prepend_activity_embed "$OUTPUT_FILE" "../../${ASSET_FILE}"
            echo "Activity SVG updated: $ASSET_FILE"
        else
            echo "WARN: failed to collect activity counts for $repo (skipping SVG)"
        fi
        rm -f "$TSV"

        echo "Timeline updated: $OUTPUT_FILE"
    done
}

# Run main only when invoked as a script (not when sourced for tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
