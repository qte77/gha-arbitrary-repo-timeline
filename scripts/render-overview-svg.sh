#!/usr/bin/env bash
# Render a themed cross-repo activity heatmap (#87): one row per repo, one
# column per day, cell shade = that repo's total events that day.
#
# Usage:
#   render-overview-svg.sh [--days N] < activity.tsv > overview.svg
#
# Input (stdin): TSV with columns repo<TAB>date<TAB>event<TAB>count — the
#   per-repo assets/<owner>/<repo>-activity.tsv rows prefixed with
#   owner/repo. Rows are drawn in order of each repo's first appearance.
#
# Output (stdout): SVG in the same style family as render-activity-svg.sh
#   (inline <style> with @media (prefers-color-scheme: dark), GitHub
#   palette, system fonts). The window is the N days (default 30) ending at
#   the latest date in the input; levels 1-4 split (0, max] into quarters,
#   like GitHub's contribution graph.
set -euo pipefail

DAYS=30
while [ $# -gt 0 ]; do
    case "$1" in
        --days)
            DAYS="$2"
            shift 2
            ;;
        *)
            echo "Usage: render-overview-svg.sh [--days N] < activity.tsv" >&2
            exit 1
            ;;
    esac
done

W=760
LEFT=230
RIGHT=10
TOP=40
BOTTOM=30
GAP=2

emit_style_block() {
    cat <<'EOF'
  <style>
    .page-bg { fill: #ffffff; }
    .title { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 13px; font-weight: 600; fill: #1f2328; }
    .repo-label { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 10px; fill: #1f2328; }
    .axis-label { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 9px; fill: #656d76; }
    .lv0 { fill: #ebedf0; }
    .lv1 { fill: #9be9a8; }
    .lv2 { fill: #40c463; }
    .lv3 { fill: #30a14e; }
    .lv4 { fill: #216e39; }
    a:hover .repo-label { text-decoration: underline; }
    @media (prefers-color-scheme: dark) {
      .page-bg { fill: #0d1117; }
      .title { fill: #e6edf3; }
      .repo-label { fill: #e6edf3; }
      .axis-label { fill: #8b949e; }
      .lv0 { fill: #161b22; }
      .lv1 { fill: #0e4429; }
      .lv2 { fill: #006d32; }
      .lv3 { fill: #26a641; }
      .lv4 { fill: #39d353; }
    }
  </style>
EOF
}

emit_svg_open() {
    printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 %d %d" width="%d" height="%d">\n' "$W" "$1" "$W" "$1"
    emit_style_block
    printf '  <rect class="page-bg" width="%d" height="%d" rx="6"/>\n' "$W" "$1"
}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
cat >"$TMP"

if ! [ -s "$TMP" ]; then
    emit_svg_open 120
    printf '  <text class="title" x="%d" y="64" text-anchor="middle">no activity in window</text>\n' "$((W / 2))"
    printf '</svg>\n'
    exit 0
fi

MAX_DATE=$(awk -F'\t' '{print $2}' "$TMP" | sort | tail -1)
DAY_LIST=""
for ((i = DAYS - 1; i >= 0; i--)); do
    DAY_LIST+="$(date -u -d "$MAX_DATE - $i days" +%Y-%m-%d 2>/dev/null ||
        date -u -j -v-"$i"d -f "%Y-%m-%d" "$MAX_DATE" +%Y-%m-%d) "
done

N_REPOS=$(awk -F'\t' '!seen[$1]++' "$TMP" | wc -l)
CELL=$(((W - LEFT - RIGHT - GAP * (DAYS - 1)) / DAYS))
[ "$CELL" -lt 1 ] && CELL=1
H=$((TOP + N_REPOS * (CELL + GAP) + BOTTOM))

emit_svg_open "$H"
printf '  <text class="title" x="%d" y="24">Activity across repos (last %d days)</text>\n' "$LEFT" "$DAYS"

awk -F'\t' -v days="$DAY_LIST" -v left="$LEFT" -v top="$TOP" -v cell="$CELL" -v gap="$GAP" '
function level(c) {
    if (c <= 0) return 0
    l = int((4 * c + max - 1) / max)
    return l > 4 ? 4 : l
}
{
    if (!($1 in seen)) { seen[$1] = 1; repos[++nr] = $1 }
    total[$1, $2] += $4
}
END {
    nd = split(days, d, " ")
    max = 0
    for (r = 1; r <= nr; r++)
        for (i = 1; i <= nd; i++)
            if (total[repos[r], d[i]] + 0 > max) max = total[repos[r], d[i]] + 0
    if (max < 1) max = 1
    for (r = 1; r <= nr; r++) {
        y = top + (r - 1) * (cell + gap)
        printf "  <a xlink:href=\"https://github.com/%s\"><text class=\"repo-label\" x=\"%d\" y=\"%d\" text-anchor=\"end\">%s</text></a>\n", repos[r], left - 8, y + cell - 3, repos[r]
        for (i = 1; i <= nd; i++) {
            c = total[repos[r], d[i]] + 0
            printf "  <rect class=\"cell lv%d\" x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"2\"><title>%s %s: %d</title></rect>\n", level(c), left + (i - 1) * (cell + gap), y, cell, cell, repos[r], d[i], c
        }
    }
}
' "$TMP"

FIRST_DATE=${DAY_LIST%% *}
printf '  <text class="axis-label" x="%d" y="%d">%s</text>\n' "$LEFT" "$((H - 12))" "$FIRST_DATE"
printf '  <text class="axis-label" x="%d" y="%d" text-anchor="end">%s</text>\n' "$((W - RIGHT))" "$((H - 12))" "$MAX_DATE"
printf '</svg>\n'
