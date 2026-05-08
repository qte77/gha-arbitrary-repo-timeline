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
    [[ "$output" == *'viewBox="0 0 760 220"'* ]]
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

@test "applies bar fill colors per type" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    # PR / issue / commit fills: green / purple / blue (color-blind safe)
    [[ "$output" == *'#3fb950'* ]]
    [[ "$output" == *'#a371f7'* ]]
    [[ "$output" == *'#1f6feb'* ]]
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

@test "uses system font stack" {
    run bash -c "'$SCRIPT' qte77/example < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'-apple-system'* ]]
    [[ "$output" == *'BlinkMacSystemFont'* ]]
}
