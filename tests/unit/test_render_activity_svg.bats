#!/usr/bin/env bats
# Tests for scripts/render-activity-svg.sh — themed SVG bar chart of daily
# activity counts. Mirror the qte77/qte77/assets/images/*.svg style:
# inline <style> with @media (prefers-color-scheme: dark), GitHub palette,
# system fonts. Reads TSV (date<TAB>type<TAB>count) on stdin, writes SVG
# on stdout. Optional first arg: owner/repo for the click-through link.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/render-activity-svg.sh"
    FIXTURE="$BATS_TEST_DIRNAME/../fixtures/activity-30d.tsv"
}

# --- structural invariants ---

@test "outputs valid SVG with viewBox and required namespaces" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'<svg'* ]]
    [[ "$output" == *'xmlns="http://www.w3.org/2000/svg"'* ]]
    [[ "$output" == *'xmlns:xlink="http://www.w3.org/1999/xlink"'* ]]
    [[ "$output" == *'viewBox="0 0 760 240"'* ]]
}

@test "embeds prefers-color-scheme dark media query" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'@media (prefers-color-scheme: dark)'* ]]
}

@test "uses GitHub light-mode palette" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    # page-bg, axis/border, primary text colors from qte77/qte77 assets
    [[ "$output" == *'#ffffff'* ]]
    [[ "$output" == *'#1f2328'* ]]
    [[ "$output" == *'#d0d7de'* ]]
}

@test "uses GitHub dark-mode palette" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'#0d1117'* ]]
    [[ "$output" == *'#e6edf3'* ]]
    [[ "$output" == *'#30363d'* ]]
}

@test "applies distinct fill colors per event token" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    # PR events
    [[ "$output" == *'.bar-pr-opened'* && "$output" == *'#3fb950'* ]]      # green
    [[ "$output" == *'.bar-pr-merged'* && "$output" == *'#a371f7'* ]]      # purple
    [[ "$output" == *'.bar-pr-closed'* && "$output" == *'#f85149'* ]]      # red
    # Issue events
    [[ "$output" == *'.bar-issue-opened'* && "$output" == *'#1f6feb'* ]]   # blue
    [[ "$output" == *'.bar-issue-resolved'* && "$output" == *'#56d364'* ]] # light green
    [[ "$output" == *'.bar-issue-closed'* && "$output" == *'#8b949e'* ]]   # gray
}

@test "renders legend with PR and Issue event labels" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'PR opened'* ]]
    [[ "$output" == *'PR merged'* ]]
    [[ "$output" == *'PR closed'* ]]
    [[ "$output" == *'Issue opened'* ]]
    [[ "$output" == *'Issue resolved'* ]]
    [[ "$output" == *'Issue closed'* ]]
}

@test "renders one column group per distinct date in fixture" {
    expected=$(awk -F'\t' '{print $1}' "$FIXTURE" | sort -u | wc -l)
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    actual=$(printf '%s\n' "$output" | grep -cE '<g class="day"')
    [ "$actual" -eq "$expected" ]
}

@test "wraps chart in clickable repo link when owner/repo provided" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'<a xlink:href="https://github.com/qte77/example"'* ]]
}

@test "produces valid SVG on empty input (placeholder text)" {
    run bash -c "'$SCRIPT' qte77/example < /dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *'<svg'* ]]
    [[ "$output" == *'</svg>'* ]]
    [[ "$output" == *'no activity'* ]]
}

@test "--days N slices input to last N days from latest date in TSV" {
    # Fixture spans 2026-04-04 to 2026-05-03. Slicing last 7 days from
    # 2026-05-03 keeps only rows with date >= 2026-04-26.
    run bash -c "'$SCRIPT' --days 7 qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    expected=$(awk -F'\t' '$1 >= "2026-04-26" {print $1}' "$FIXTURE" | sort -u | wc -l)
    actual=$(printf '%s\n' "$output" | grep -cE '<g class="day"')
    [ "$actual" -eq "$expected" ]
    # Dates outside the window must NOT appear as data columns
    ! printf '%s\n' "$output" | grep -qE '<g class="day"[^>]*>.*2026-04-04'
}

@test "uses system font stack" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'-apple-system'* ]]
    [[ "$output" == *'BlinkMacSystemFont'* ]]
}
