#!/usr/bin/env bash
# Render a mermaid `gantt` block showing account-level repo lifespans
# (#109 Tier 1).
#
# Per issue #83's decision: mermaid has a native `gantt` diagram type, so
# this renders a fenced mermaid block directly instead of building Gantt
# layout math by hand — unlike scripts/render-activity-svg.sh's awk
# renderer, which hand-rolls a stacked bar chart because mermaid has no
# native primitive for that shape.
#
# Usage: render-account-gantt.sh <account> < repos.jsonl
#   repos.jsonl = concatenated JSON objects, one per repo (the exact stdout
#   format scripts/collect-account-repos.sh emits), each needing at least
#   name/created_at/pushed_at.
#
# Always emits a structurally valid gantt block, even for zero repos —
# generate-timeline.sh's collect_account() does a full rewrite of
# timelines/<account>/_account.md every run, so "no repos" must still be
# valid output, never an error.
set -euo pipefail

ACCOUNT="${1:?Usage: render-account-gantt.sh account}"

INPUT="$(cat)"

echo '```mermaid'
echo "gantt"
echo "    title ${ACCOUNT} — Repository Lifespans"
echo "    dateFormat  YYYY-MM-DD"
echo "    section Repos"

if [[ -n "${INPUT// /}" ]]; then
    printf '%s' "$INPUT" | jq -r '
        (.name | gsub("[^A-Za-z0-9_-]"; "_")) as $id |
        (.pushed_at // .created_at) as $end |
        "    \(.name) :\($id), \(.created_at[:10]), \($end[:10])"
    '
fi

echo '```'
