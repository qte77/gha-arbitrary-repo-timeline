#!/usr/bin/env bats
# Tests for scripts/render-overview-svg.sh — cross-repo activity heatmap
# (#87). Reads TSV (repo<TAB>date<TAB>event<TAB>count) on stdin, writes a
# themed SVG on stdout: one row per repo, one column per day of the window.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/render-overview-svg.sh"
    INPUT="$(mktemp)"
    # acme/a: 8 events on 04-30 (the max), 1 on 04-29, 3 on 04-28 (2 rows)
    # acme/b: 2 events on 04-30
    printf 'acme/a\t2026-04-30\tpr-opened\t5\nacme/a\t2026-04-30\tcommit\t3\nacme/a\t2026-04-29\tpr-merged\t1\nacme/a\t2026-04-28\tissue-opened\t3\nacme/b\t2026-04-30\tpr-opened\t2\n' >"$INPUT"
}

teardown() {
    rm -f "$INPUT"
}

@test "outputs valid SVG with viewBox and required namespaces" {
    run bash -c "'$SCRIPT' --days 7 < '$INPUT'"
    [ "$status" -eq 0 ]
    [[ "$output" == '<svg'* ]]
    [[ "$output" == *'xmlns="http://www.w3.org/2000/svg"'* ]]
    [[ "$output" == *'xmlns:xlink="http://www.w3.org/1999/xlink"'* ]]
    [[ "$output" == *'viewBox="0 0 760 '* ]]
    [[ "$output" == *'</svg>' ]]
}

@test "embeds light palette and prefers-color-scheme dark overrides" {
    run bash -c "'$SCRIPT' --days 7 < '$INPUT'"
    [[ "$output" == *'.page-bg { fill: #ffffff; }'* ]]
    [[ "$output" == *'@media (prefers-color-scheme: dark)'* ]]
    [[ "$output" == *'.page-bg { fill: #0d1117; }'* ]]
}

@test "renders one labelled, linked row per repo in input order" {
    run bash -c "'$SCRIPT' --days 7 < '$INPUT'"
    [ "$(grep -c 'class="repo-label"' <<<"$output")" -eq 2 ]
    [[ "$output" == *'<a xlink:href="https://github.com/acme/a">'* ]]
    [[ "$output" == *'<a xlink:href="https://github.com/acme/b">'* ]]
    [ "$(grep -n 'acme/a</text>' <<<"$output" | cut -d: -f1)" -lt "$(grep -n 'acme/b</text>' <<<"$output" | cut -d: -f1)" ]
}

@test "renders one cell per repo per day of the window, ending at the latest date" {
    run bash -c "'$SCRIPT' --days 7 < '$INPUT'"
    [ "$(grep -c 'class="cell lv' <<<"$output")" -eq 14 ]
    [[ "$output" == *'<title>acme/a 2026-04-24: 0</title>'* ]]
    [[ "$output" != *'2026-04-23'* ]]
    [[ "$output" == *'>2026-04-24</text>'* ]]
    [[ "$output" == *'>2026-04-30</text>'* ]]
}

@test "sums events per repo and day, and buckets cells into 5 levels relative to the max" {
    run bash -c "'$SCRIPT' --days 7 < '$INPUT'"
    # max = 8 -> level = ceil(4 * count / 8)
    grep -q 'class="cell lv4".*<title>acme/a 2026-04-30: 8</title>' <<<"$output"
    grep -q 'class="cell lv1".*<title>acme/a 2026-04-29: 1</title>' <<<"$output"
    grep -q 'class="cell lv2".*<title>acme/a 2026-04-28: 3</title>' <<<"$output"
    grep -q 'class="cell lv1".*<title>acme/b 2026-04-30: 2</title>' <<<"$output"
    grep -q 'class="cell lv0".*<title>acme/b 2026-04-29: 0</title>' <<<"$output"
}

@test "defines all five level colors for light and dark mode" {
    run bash -c "'$SCRIPT' --days 7 < '$INPUT'"
    for lv in 0 1 2 3 4; do
        [ "$(grep -c "\.lv${lv} {" <<<"$output")" -eq 2 ]
    done
}

@test "empty input renders a placeholder SVG" {
    run bash -c "'$SCRIPT' < /dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *'<svg'* ]]
    [[ "$output" == *'no activity in window'* ]]
    [[ "$output" != *'class="cell'* ]]
}

@test "defaults to a 30-day window" {
    run bash -c "'$SCRIPT' < '$INPUT'"
    [ "$(grep -c 'class="cell lv' <<<"$output")" -eq 60 ]
}

@test "rejects unknown arguments" {
    run bash -c "'$SCRIPT' --bogus < '$INPUT'"
    [ "$status" -ne 0 ]
}
