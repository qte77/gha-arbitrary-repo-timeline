#!/usr/bin/env bash
# Per-contributor temporal patterns (#108) from the window's contribution
# events — the JSONL collect-contributor-events.sh emits
# ({"login","type","timestamp"}), so no extra API calls are made.
#
# Privacy posture (#110): only contributors with >= $1 window events (the
# same threshold as the "enriched" tier) get a timing block, and every block
# carries a _note marking it as suggestive inference (#110 req 6). All
# figures are UTC and limited to the window — never lifetime.
#
# Fields: first_activity / last_activity (YYYY-MM-DD), n_active_days,
#   modal_utc_hour (ties -> earliest hour), weekend_pct (Sat+Sun),
#   off_hours_pct (outside 09:00-17:00 UTC), longest_streak_days
#   (consecutive active days). Percentages are rounded integers.
#
# Usage: analyze-contributor-timing.sh <min-events> < events.jsonl
# Output (stdout): JSON object keyed by login, e.g. {"alice": {...}}
set -euo pipefail

MIN_EVENTS="${1:?Usage: analyze-contributor-timing.sh min-events < events.jsonl}"

jq -s --argjson min "$MIN_EVENTS" '
    def epoch_day: .[0:10] + "T00:00:00Z" | fromdateiso8601 / 86400 | floor;
    group_by(.login)
    | map(select(length >= $min))
    | map(
        map(.timestamp) as $ts
        | ($ts | length) as $n
        | ($ts | map(.[0:10]) | unique) as $days
        | ($ts | map(.[11:13] | tonumber)) as $hours
        | {
            key: .[0].login,
            value: {
                first_activity: $days[0],
                last_activity: $days[-1],
                n_active_days: ($days | length),
                modal_utc_hour: ($hours | group_by(.) | map({h: .[0], c: length}) | sort_by(-.c, .h) | .[0].h),
                weekend_pct: (($ts | map(fromdateiso8601 | gmtime | .[6] | select(. == 0 or . == 6)) | length) * 100 / $n | round),
                off_hours_pct: (($hours | map(select(. < 9 or . >= 17)) | length) * 100 / $n | round),
                longest_streak_days: (
                    $days | map(epoch_day)
                    | reduce .[] as $d ({best: 0, run: 0, prev: null};
                        .run = (if .prev != null and $d == .prev + 1 then .run + 1 else 1 end)
                        | .best = ([.best, .run] | max)
                        | .prev = $d)
                    | .best
                ),
                _note: "suggestive, not a timezone or work-pattern claim: derived from public PR/issue/commit timestamps in the window, UTC, work hours taken as 09:00-17:00 UTC"
            }
        }
    )
    | from_entries
'
