#!/usr/bin/env bash
# Render a themed SVG bar chart from daily activity TSV.
#
# Usage:
#   render-activity-svg.sh [owner/repo] < activity.tsv > activity.svg
#
# Input (stdin): TSV with columns date<TAB>event<TAB>count
#   date: YYYY-MM-DD
#   event: pr-opened | pr-merged | pr-closed |
#          issue-opened | issue-resolved | issue-closed |
#          commit
#   count: positive integer
#
# Output (stdout): SVG mirroring qte77/qte77/assets/images styling —
#   inline <style> with @media (prefers-color-scheme: dark),
#   GitHub palette, system fonts. If owner/repo is given the chart is
#   wrapped in <a xlink:href="https://github.com/<owner>/<repo>">.
set -euo pipefail

REPO="${1:-}"

W=760
H=240
LEFT=30
RIGHT=10
TOP=40
BOTTOM=60
CHART_H=$((H - TOP - BOTTOM))
CHART_W=$((W - LEFT - RIGHT))
GAP=2

emit_style_block() {
    cat <<'EOF'
  <style>
    .page-bg { fill: #ffffff; }
    .title { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 13px; font-weight: 600; fill: #1f2328; }
    .axis-label { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 9px; fill: #656d76; }
    .legend-label { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 9px; fill: #656d76; }
    .axis { stroke: #d0d7de; stroke-width: 1; fill: none; }
    .bar-pr-opened { fill: #3fb950; }
    .bar-pr-merged { fill: #a371f7; }
    .bar-pr-closed { fill: #f85149; }
    .bar-issue-opened { fill: #1f6feb; }
    .bar-issue-resolved { fill: #56d364; }
    .bar-issue-closed { fill: #8b949e; }
    .bar-commit { fill: #d29922; }
    a:hover .day rect { opacity: 0.85; }
    @media (prefers-color-scheme: dark) {
      .page-bg { fill: #0d1117; }
      .title { fill: #e6edf3; }
      .axis-label { fill: #8b949e; }
      .legend-label { fill: #8b949e; }
      .axis { stroke: #30363d; }
    }
  </style>
EOF
}

emit_empty_svg() {
    printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 %d %d" width="%d" height="%d">\n' "$W" "$H" "$W" "$H"
    emit_style_block
    printf '  <rect class="page-bg" width="%d" height="%d" rx="6"/>\n' "$W" "$H"
    printf '  <text class="title" x="%d" y="%d" text-anchor="middle">no activity in window</text>\n' "$((W / 2))" "$((H / 2))"
    printf '</svg>\n'
}

emit_legend() {
    local y=$((H - 16))
    local sw=8 ty=$((H - 8))
    local i=0
    local entry
    # Order matches typical stack: PR opened/merged/closed, Issue opened/resolved/closed
    for entry in \
        "bar-pr-opened|PR opened" \
        "bar-pr-merged|PR merged" \
        "bar-pr-closed|PR closed" \
        "bar-issue-opened|Issue opened" \
        "bar-issue-resolved|Issue resolved" \
        "bar-issue-closed|Issue closed"; do
        local cls="${entry%%|*}" label="${entry##*|}"
        local x=$((LEFT + i * 120))
        printf '    <rect class="%s" x="%d" y="%d" width="%d" height="%d"/>\n' "$cls" "$x" "$y" "$sw" "$sw"
        printf '    <text class="legend-label" x="%d" y="%d">%s</text>\n' "$((x + 12))" "$ty" "$label"
        i=$((i + 1))
    done
}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
cat >"$TMP"

if ! [ -s "$TMP" ]; then
    emit_empty_svg
    exit 0
fi

N_DATES=$(awk -F'\t' '{print $1}' "$TMP" | sort -u | wc -l)
MAX_STACK=$(awk -F'\t' '{a[$1]+=$3} END {m=0; for (k in a) if (a[k]>m) m=a[k]; print m+0}' "$TMP")
[ "$MAX_STACK" -lt 1 ] && MAX_STACK=1

BAR_W=$(awk -v w="$CHART_W" -v n="$N_DATES" -v g="$GAP" 'BEGIN { v = (w - g*(n-1)) / n; if (v < 1) v = 1; printf "%d", v }')
BASELINE=$((TOP + CHART_H))

FIRST_DATE=$(awk -F'\t' '{print $1}' "$TMP" | sort -u | head -1)
LAST_DATE=$(awk -F'\t' '{print $1}' "$TMP" | sort -u | tail -1)

printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 %d %d" width="%d" height="%d">\n' "$W" "$H" "$W" "$H"
emit_style_block
printf '  <rect class="page-bg" width="%d" height="%d" rx="6"/>\n' "$W" "$H"
printf '  <text class="title" x="%d" y="24">Activity</text>\n' "$LEFT"

if [ -n "$REPO" ]; then
    printf '  <a xlink:href="https://github.com/%s">\n' "$REPO"
fi

printf '    <line class="axis" x1="%d" y1="%d" x2="%d" y2="%d"/>\n' "$LEFT" "$BASELINE" "$((W - RIGHT))" "$BASELINE"

awk -F'\t' -v left="$LEFT" -v top="$TOP" -v ch="$CHART_H" -v bw="$BAR_W" -v gap="$GAP" -v maxH="$MAX_STACK" '
function order(t) {
    # Stack order from bottom up: closures first, fresh on top
    if (t == "pr-closed") return 1
    if (t == "pr-merged") return 2
    if (t == "pr-opened") return 3
    if (t == "issue-closed") return 4
    if (t == "issue-resolved") return 5
    if (t == "issue-opened") return 6
    if (t == "commit") return 7
    return 9
}
function class_for(t) {
    if (t == "pr-opened") return "bar-pr-opened"
    if (t == "pr-merged") return "bar-pr-merged"
    if (t == "pr-closed") return "bar-pr-closed"
    if (t == "issue-opened") return "bar-issue-opened"
    if (t == "issue-resolved") return "bar-issue-resolved"
    if (t == "issue-closed") return "bar-issue-closed"
    if (t == "commit") return "bar-commit"
    return "bar-pr-opened"
}
{
    counts[$1, $2] = $3 + 0
    dates[$1] = 1
    types[$2] = 1
}
END {
    n = 0
    for (d in dates) { n++; sd[n] = d }
    for (i = 1; i < n; i++)
        for (j = i+1; j <= n; j++)
            if (sd[i] > sd[j]) { tmp = sd[i]; sd[i] = sd[j]; sd[j] = tmp }
    nt = 0
    for (t in types) { nt++; tl[nt] = t }
    for (i = 1; i < nt; i++)
        for (j = i+1; j <= nt; j++)
            if (order(tl[i]) > order(tl[j])) { tmp = tl[i]; tl[i] = tl[j]; tl[j] = tmp }
    for (i = 1; i <= n; i++) {
        d = sd[i]
        x = left + (i-1) * (bw + gap)
        printf "    <g class=\"day\" transform=\"translate(%d,0)\">\n", x
        ystack = top + ch
        total = 0
        for (k = 1; k <= nt; k++) {
            t = tl[k]
            if ((d, t) in counts) {
                c = counts[d, t]
                total += c
                bh = c * ch / maxH
                ystack -= bh
                printf "      <rect class=\"%s\" x=\"0\" y=\"%.1f\" width=\"%d\" height=\"%.1f\"><title>%s %s: %d</title></rect>\n", class_for(t), ystack, bw, bh, d, t, c
            }
        }
        printf "      <title>%s total: %d</title>\n", d, total
        print "    </g>"
    }
}
' "$TMP"

if [ -n "$REPO" ]; then
    printf '  </a>\n'
fi

printf '  <text class="axis-label" x="%d" y="%d">%s</text>\n' "$LEFT" "$((BASELINE + 14))" "$FIRST_DATE"
printf '  <text class="axis-label" x="%d" y="%d" text-anchor="end">%s</text>\n' "$((W - RIGHT))" "$((BASELINE + 14))" "$LAST_DATE"
emit_legend
printf '</svg>\n'
