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
    [[ ! -f "$file" ]] && {
        printf '%s' "$items"
        return
    }
    local filtered="" line id
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        id=$(printf '%s' "$line" | grep -oE '\[(PR|ISSUE) #[0-9]+\]|\[[a-f0-9]{7,}\]' | head -1)
        if [[ -n "$id" ]] && grep -qF "$id" "$file"; then
            continue
        fi
        filtered+="$line"$'\n'
    done <<<"$items"
    printf '%s' "$filtered"
}

# Merge two activity TSVs into a unioned, deduped TSV on stdout.
# Rows from $2 (new) override rows from $1 (existing) on (date, event)
# collisions. Output is sorted ascending by (date, event).
# Args: $1 = existing tsv path (may not exist), $2 = new tsv path
merge_activity_tsv() {
    local existing="$1" new="$2"
    {
        [ -f "$existing" ] && cat "$existing"
        cat "$new"
    } | awk -F'\t' -v OFS='\t' '
        NF == 3 { rows[$1, $2] = $3 }
        END {
            for (k in rows) {
                split(k, parts, SUBSEP)
                print parts[1], parts[2], rows[k]
            }
        }
    ' | sort -t$'\t' -k1,1 -k2,2
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
    ' "$file" >"$tmp"
    mv "$tmp" "$file"
}

# Append items to the output file. If a '## RUN_DATE' header already exists,
# append without a new header; otherwise create a new date section.
# Args: $1 = output file, $2 = run date, $3 = items
append_section() {
    local file="$1" run_date="$2" items="$3"
    if grep -qxF "## $run_date" "$file" 2>/dev/null; then
        printf '%s' "$items" >>"$file"
    else
        {
            echo "## $run_date"
            echo ""
            printf '%s' "$items"
            echo ""
        } >>"$file"
    fi
}

# Delete-and-rewrite the contributors section of a timeline MD file between
# marker comments, so contributor data is REPLACED every run and never
# appended (this repo's other sections are append-only; contributor data
# must be re-derived fresh each run — see CONTRIBUTING.md's right-to-erasure
# section). Passing an empty content string removes the block entirely —
# used when INCLUDE_CONTRIBUTORS flips off or a repo opts out via
# .timeline-no-contributors, so stale contributor data never lingers in the
# working tree after the flag is off.
# Args: $1 = output file, $2 = markdown fragment ("" removes the block)
replace_contributors_block() {
    local file="$1" content="$2"
    [[ ! -f "$file" ]] && return 0
    local body
    body=$(awk '
        /^<!-- contributors-begin -->$/ { skip = 1; next }
        /^<!-- contributors-end -->$/ { skip = 0; next }
        skip { next }
        { print }
    ' "$file")
    if [[ -n "$content" ]]; then
        {
            printf '%s\n' "$body"
            echo ""
            echo "<!-- contributors-begin -->"
            printf '%s\n' "$content"
            echo "<!-- contributors-end -->"
        } >"$file"
    else
        printf '%s\n' "$body" >"$file"
    fi
}

# Build a short markdown fragment summarizing a collect-contributors.sh JSON
# payload, for embedding via replace_contributors_block.
# Args: $1 = collect-contributors.sh JSON output (must be non-empty)
contributors_md_fragment() {
    local json="$1"
    echo "$json" | jq -r '
        "### Contributors (last \(.window_days)d)",
        "",
        (.contributors[] | "- **\(.login)** — \(.window_events) events" + (if .tier == "enriched" then " (enriched)" else "" end)),
        (if .contribution_concentration then
            "\n_Top contributor share: \((.contribution_concentration.top_contributor_share * 100) | floor)%, top 3: \((.contribution_concentration.top_3_share * 100) | floor)%_"
         else empty end)
    '
}

# Writes/removes the per-repo contributor JSON asset + MD block together so
# they can never drift out of sync (req 9: contributor data is REPLACED
# every run, never merged forward).
# Args: $1 = md file, $2 = json asset path, $3 = fresh JSON ("" removes both)
sync_contributors_output() {
    local md_file="$1" json_file="$2" content="$3"
    if [[ -n "$content" ]]; then
        mkdir -p "$(dirname "$json_file")"
        printf '%s\n' "$content" >"$json_file"
        replace_contributors_block "$md_file" "$(contributors_md_fragment "$content")"
    else
        rm -f "$json_file"
        replace_contributors_block "$md_file" ""
    fi
}

# Per-repo contributor collection dispatch, gated on INCLUDE_CONTRIBUTORS.
# Called unconditionally (independent of that run's issue/PR activity) so a
# flag flip back to false, or a .timeline-no-contributors opt-out, is
# honored even when a repo has zero new items this run. Creates the MD
# file's H1 first if contributor data would otherwise be the only content a
# run produces for that repo (main() only creates it today when there is
# new issue/PR activity).
# Args: $1 = owner/repo, $2 = md file, $3 = json asset path, $4 = since,
#       $5 = window days
refresh_contributors_section() {
    local repo="$1" md_file="$2" json_file="$3" since="$4" days="$5"
    local content=""
    if [[ "${INPUT_INCLUDE_CONTRIBUTORS:-false}" == "true" ]]; then
        if ! content=$("${SCRIPT_DIR}/collect-contributors.sh" "$repo" "$since" "$days" 2>/dev/null); then
            echo "WARN: contributor collection failed for $repo (removing any stale contributor data — fail-safe for PII)"
            content=""
        fi
    fi
    if [[ -n "$content" && ! -f "$md_file" ]]; then
        printf '# %s — Timeline\n\n' "$repo" >"$md_file"
    fi
    sync_contributors_output "$md_file" "$json_file" "$content"
}

# Discover and render an account-level (user OR organization) repo lifespan
# timeline (#109 Tier 1). Full rewrite each run, same precedent as
# merge_activity_tsv — no dedup/history concerns for a lifespan chart.
# Args: $1 = account login (a REPOS entry with no "/")
collect_account() {
    local account="$1"
    local OUTPUT_FILE="timelines/${account}/_account.md"

    echo "Discovering repos for account $account..."
    local REPOS_JSON
    if ! REPOS_JSON=$("${SCRIPT_DIR}/collect-account-repos.sh" "$account" 2>/dev/null); then
        echo "WARN: failed to enumerate repos for $account (skipping account timeline)"
        return 0
    fi

    mkdir -p "timelines/${account}"
    {
        echo "# $account — Repository Lifespans"
        echo ""
        printf '%s' "$REPOS_JSON" | "${SCRIPT_DIR}/render-account-gantt.sh" "$account"
    } >"$OUTPUT_FILE"
    echo "Account timeline updated: $OUTPUT_FILE"
}

main() {
    assert_contributor_gate

    local REPOS="${INPUT_REPOS:?REPOS input required}"
    local DAYS="${INPUT_DAYS:-7}"
    local SINCE
    SINCE=$(days_ago "$DAYS")
    local RUN_DATE
    RUN_DATE=$(date -u +%Y-%m-%d)

    IFS=',' read -ra REPO_LIST <<<"$REPOS"
    for repo in "${REPO_LIST[@]}"; do
        repo=$(echo "$repo" | xargs) # trim whitespace
        if [[ "$repo" != */* ]]; then
            collect_account "$repo"
            continue
        fi
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

        # Update the timeline MD if there's anything new (dedup-aware).
        if [[ -n "${NEW_ITEMS// /}" ]]; then
            NEW_ITEMS=$(dedup_items "$NEW_ITEMS" "$OUTPUT_FILE")
            if [[ -n "${NEW_ITEMS// /}" ]]; then
                if [[ ! -f "$OUTPUT_FILE" ]]; then
                    {
                        echo "# $repo — Timeline"
                        echo ""
                    } >"$OUTPUT_FILE"
                fi
                append_section "$OUTPUT_FILE" "$RUN_DATE" "$NEW_ITEMS"
                echo "Timeline updated: $OUTPUT_FILE"
            else
                echo "No new unique items for $repo"
            fi
        else
            echo "No new activity for $repo"
        fi

        # Always refresh the activity SVG via the cumulative TSV history.
        # Each run pulls a short window (INPUT_DAYS, default 7) and merges
        # into assets/<owner>/<repo>-activity.tsv. Renderer slices to last
        # 30 days for the chart but the TSV preserves full history.
        local ASSETS_DIR="assets/${owner}"
        local ASSET_FILE="${ASSETS_DIR}/${name}-activity.svg"
        local HISTORY_TSV="${ASSETS_DIR}/${name}-activity.tsv"
        local NEW_TSV
        NEW_TSV=$(mktemp)
        if "${SCRIPT_DIR}/collect-activity-counts.sh" "$repo" "$DAYS" >"$NEW_TSV" 2>/dev/null; then
            mkdir -p "$ASSETS_DIR"
            local MERGED
            MERGED=$(mktemp)
            merge_activity_tsv "$HISTORY_TSV" "$NEW_TSV" >"$MERGED"
            mv "$MERGED" "$HISTORY_TSV"
            "${SCRIPT_DIR}/render-activity-svg.sh" --days 30 "$repo" <"$HISTORY_TSV" >"$ASSET_FILE"
            prepend_activity_embed "$OUTPUT_FILE" "../../${ASSET_FILE}"
            echo "Activity SVG updated: $ASSET_FILE (history: $HISTORY_TSV)"
        else
            echo "WARN: failed to collect activity counts for $repo (skipping SVG)"
        fi
        rm -f "$NEW_TSV"

        # Contributor intelligence (opt-in, gated by assert_contributor_gate
        # above). Always dispatched — independent of NEW_ITEMS — so a flag
        # flip or .timeline-no-contributors opt-out removes stale data even
        # when a repo has no new issue/PR activity this run.
        local CONTRIB_JSON_FILE="assets/${owner}/${name}-contributors.json"
        refresh_contributors_section "$repo" "$OUTPUT_FILE" "$CONTRIB_JSON_FILE" "$SINCE" "$DAYS"
    done
}

# Run main only when invoked as a script (not when sourced for tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
