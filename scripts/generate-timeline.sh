#!/usr/bin/env bash
# Generate per-repo timelines from collected issues, PRs, and commits: a
# rolling "## Open" section rewritten each run, plus a collapsed "## History"
# of items closed per day (#86).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Dedup by ID token ([PR #N], [ISSUE #N], or [<short-sha>]) so that date
# drift on an existing item does not cause a duplicate History entry. A
# [closed] line only counts as a duplicate once the file records that ID as
# [closed] — an earlier [open] line (e.g. a migrated legacy log) must not
# hide the closure.
# Args: $1 = newline-separated items, $2 = existing output file
# Prints: filtered items (only those not yet recorded in the file)
dedup_items() {
    local items="$1" file="$2"
    [[ ! -f "$file" ]] && {
        printf '%s' "$items"
        return
    }
    local filtered="" line id seen
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        id=$(printf '%s' "$line" | grep -oE '\[(PR|ISSUE) #[0-9]+\]|\[[a-f0-9]{7,}\]' | head -1)
        if [[ -n "$id" ]]; then
            seen=$(grep -F "$id" "$file" || true)
            [[ "$line" == *"[closed]" ]] && seen=$(printf '%s' "$seen" | grep -F '[closed]' || true)
            [[ -n "$seen" ]] && continue
        fi
        filtered+="$line"$'\n'
    done <<<"$items"
    printf '%s' "$filtered"
}

# Format collect-issues.sh / collect-prs.sh JSON objects as timeline lines.
# Reads: JSON stream on stdin (may be empty). Prints: one "- [...]" line each.
format_item_lines() {
    jq -r '"- [\(if .type == "pr" then "PR" else "ISSUE" end) #\(.number)] \(.title) (\(.date)) [\(.state)]"'
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

# Delete-and-rewrite the "## Open" section between marker comments, so it
# always mirrors the live state=open query and never stacks across runs.
# Rewritten in place when one well-formed marker pair exists; otherwise any
# stray marker lines are dropped (their content kept — a malformed file must
# never lose text) and a fresh section is inserted before "## History" or the
# contributors block, or appended at the end.
# Args: $1 = output file, $2 = newline-separated items ("" renders a placeholder)
write_open_section() {
    local file="$1" items="${2%$'\n'}"
    [[ ! -f "$file" ]] && return 0
    local tmp
    tmp=$(mktemp)
    OPEN_BLOCK=$(printf '<!-- open-section-start -->\n## Open\n\n%s\n<!-- open-section-end -->' \
        "${items:-_No open issues or PRs._}") awk '
        NR == FNR {
            if ($0 == "<!-- open-section-start -->") { starts++; s = FNR }
            if ($0 == "<!-- open-section-end -->") { ends++; e = FNR }
            next
        }
        FNR == 1 { in_place = (starts == 1 && ends == 1 && s < e) }
        $0 == "<!-- open-section-start -->" {
            if (in_place) { print ENVIRON["OPEN_BLOCK"]; done = 1; skip = 1 }
            next
        }
        $0 == "<!-- open-section-end -->" { skip = 0; next }
        skip { next }
        !done && ($0 == "## History" || $0 == "<!-- contributors-begin -->") {
            print ENVIRON["OPEN_BLOCK"]; print ""; done = 1
        }
        { print; last = $0 }
        END {
            if (!done) {
                if (last != "") print ""
                print ENVIRON["OPEN_BLOCK"]
            }
        }
    ' "$file" "$file" >"$tmp"
    mv "$tmp" "$file"
}

# Record items under "## History" in a collapsed
# <details><summary>RUN_DATE</summary> block, newest day first. A second
# call on the same day merges into that day's block instead of adding one.
# "## History" is created (before the contributors block, else at the end)
# the first time anything closes, so an open-only file has no History.
# Args: $1 = output file, $2 = run date, $3 = newline-separated items
prepend_history_entry() {
    local file="$1" run_date="$2" items="${3%$'\n'}"
    [[ ! -f "$file" || -z "${items//[[:space:]]/}" ]] && return 0
    local tmp
    tmp=$(mktemp)
    HISTORY_ITEMS="$items" awk -v d="$run_date" '
        function block() {
            print "<details><summary>" d "</summary>"; print ""
            print ENVIRON["HISTORY_ITEMS"]; print ""; print "</details>"
        }
        NR == FNR {
            if ($0 == "## History") has_h = 1
            if ($0 == "<details><summary>" d "</summary>") has_day = 1
            next
        }
        has_day && $0 == "<details><summary>" d "</summary>" { print; print ""; in_day = 1; next }
        in_day && $0 == "</details>" { print ENVIRON["HISTORY_ITEMS"]; print ""; print; in_day = 0; next }
        in_day && $0 == "" { next }
        !has_day && has_h && $0 == "## History" { print; print ""; block(); next }
        !has_h && !done && $0 == "<!-- contributors-begin -->" {
            print "## History"; print ""; block(); print ""; done = 1
        }
        { print; last = $0 }
        END {
            if (!has_h && !done) {
                if (last != "") print ""
                print "## History"; print ""; block()
            }
        }
    ' "$file" "$file" >"$tmp"
    mv "$tmp" "$file"
}

# One-time, idempotent conversion of the legacy append-only layout: every
# "## YYYY-MM-DD" section becomes a collapsed History block (newest first,
# matching prepend_history_entry). No-op once the Open markers exist. Content
# before the first date section (H1, activity embed) and the contributors
# block are kept as-is.
# Args: $1 = output file
migrate_legacy_sections_to_history() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0
    grep -qxF '<!-- open-section-start -->' "$file" && return 0
    grep -qE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$file" || return 0
    local tmp
    tmp=$(mktemp)
    awk '
        /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ {
            n++; day[n] = substr($0, 4); lines[n] = 0; in_s = 1; next
        }
        $0 == "<!-- contributors-begin -->" { in_s = 0 }
        in_s {
            if ($0 == "" && lines[n] == 0) next
            body[n, ++lines[n]] = $0; next
        }
        n == 0 { pre[++npre] = $0; next }
        { post[++npost] = $0 }
        END {
            for (i = 1; i <= npre; i++) print pre[i]
            if (npre > 0 && pre[npre] != "") print ""
            print "## History"; print ""
            for (i = n; i >= 1; i--) {
                last = lines[i]
                while (last > 0 && body[i, last] == "") last--
                print "<details><summary>" day[i] "</summary>"; print ""
                for (j = 1; j <= last; j++) print body[i, j]
                print ""; print "</details>"
                if (i > 1 || npost > 0) print ""
            }
            for (i = 1; i <= npost; i++) print post[i]
        }
    ' "$file" >"$tmp"
    mv "$tmp" "$file"
}

# Delete-and-rewrite the contributors section of a timeline MD file between
# marker comments, so contributor data is REPLACED every run and never
# appended (unlike ## History, which only grows; contributor data
# must be re-derived fresh each run — see CONTRIBUTING.md's right-to-erasure
# section; the Open section is likewise rewritten, History only grows). Passing an empty content string removes the block entirely —
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
        (.contributors[] | "- **\(.login)** — \(.window_events) events" + (
            if .timing then
                " (enriched; peak ~\(if .timing.modal_utc_hour < 10 then "0" else "" end)\(.timing.modal_utc_hour):00 UTC, \(.timing.weekend_pct)% weekend, \(.timing.off_hours_pct)% off-hours)"
            elif .tier == "enriched" then " (enriched)"
            else "" end)),
        (if .contribution_concentration then
            "\n_Top contributor share: \((.contribution_concentration.top_contributor_share * 100) | floor)%, top 3: \((.contribution_concentration.top_3_share * 100) | floor)%_"
         else empty end),
        (if any(.contributors[]; .timing) then
            "\n_Timing is suggestive, not a timezone or work-pattern claim: UTC, from public activity in the window; off-hours = outside 09:00-17:00 UTC._"
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

        if [[ ! -f "$OUTPUT_FILE" ]]; then
            printf '# %s — Timeline\n\n' "$repo" >"$OUTPUT_FILE"
        fi
        migrate_legacy_sections_to_history "$OUTPUT_FILE"

        # ## Open: live, unbounded state=open query, rewritten every run and
        # never derived from the file. On API failure keep the previous
        # section rather than blanking it.
        local OPEN_ISSUES OPEN_PRS
        if OPEN_ISSUES=$("${SCRIPT_DIR}/collect-issues.sh" "$repo" --state open 2>/dev/null) &&
            OPEN_PRS=$("${SCRIPT_DIR}/collect-prs.sh" "$repo" --state open 2>/dev/null); then
            write_open_section "$OUTPUT_FILE" "$(printf '%s\n%s\n' "$OPEN_ISSUES" "$OPEN_PRS" | format_item_lines)"
        else
            echo "WARN: failed to collect open items for $repo (keeping previous ## Open)"
        fi

        # ## History: items closed in the lookback window (+ optional commits),
        # bucketed under today's date.
        local HISTORY_ITEMS=""
        local ISSUES PRS
        ISSUES=$("${SCRIPT_DIR}/collect-issues.sh" "$repo" "$SINCE" 2>/dev/null || true)
        PRS=$("${SCRIPT_DIR}/collect-prs.sh" "$repo" "$SINCE" 2>/dev/null || true)
        HISTORY_ITEMS+=$(printf '%s\n%s\n' "$ISSUES" "$PRS" | jq -c 'select(.state == "closed")' | format_item_lines)
        HISTORY_ITEMS+=$'\n'

        # Git log (optional)
        if [[ "${INPUT_INCLUDE_GIT_LOG:-false}" == "true" ]]; then
            local COMMITS
            COMMITS=$(gh api "repos/$repo/commits?since=${SINCE}T00:00:00Z&per_page=20" \
                --jq '.[] | {date: .commit.author.date[:10], sha: .sha[:7], message: (.commit.message | split("\n")[0])}' 2>/dev/null || true)
            if [[ -n "$COMMITS" ]]; then
                HISTORY_ITEMS+=$(echo "$COMMITS" | jq -r '"- [\(.sha)] \(.message) (\(.date))"')
                HISTORY_ITEMS+=$'\n'
            fi
        fi

        HISTORY_ITEMS=$(dedup_items "$HISTORY_ITEMS" "$OUTPUT_FILE")
        if [[ -n "${HISTORY_ITEMS//[[:space:]]/}" ]]; then
            prepend_history_entry "$OUTPUT_FILE" "$RUN_DATE" "$HISTORY_ITEMS"
            echo "History updated: $OUTPUT_FILE"
        else
            echo "No new closed items for $repo"
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
        # above). Always dispatched — independent of HISTORY_ITEMS — so a flag
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
