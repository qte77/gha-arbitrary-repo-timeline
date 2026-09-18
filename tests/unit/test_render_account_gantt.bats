#!/usr/bin/env bats
# Tests for scripts/render-account-gantt.sh — renders a mermaid `gantt`
# block for account-level repo lifespan timelines (#109 Tier 1).
#
# Per issue #83's decision: mermaid has a native `gantt` diagram type, so
# this is a fenced mermaid block, not hand-rolled SVG (unlike
# scripts/render-activity-svg.sh's awk renderer, which has no native
# mermaid primitive to lean on for its stacked bar chart).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/render-account-gantt.sh"
}

@test "emits a structurally valid mermaid gantt block for empty input" {
    run bash -c "printf '' | \"$SCRIPT\" qte77"
    [ "$status" -eq 0 ]
    [[ "$output" == *'```mermaid'* ]]
    [[ "$output" == *"gantt"* ]]
    [[ "$output" == *"dateFormat"* ]]
    [[ "$output" == *"section Repos"* ]]
    # closing fence present (opening + closing = 2 occurrences of the marker)
    n=$(printf '%s' "$output" | grep -c '```')
    [ "$n" -eq 2 ]
}

@test "emits one task line per repo for non-empty input, with its dates" {
    input='{"name":"repo-a","description":"x","language":"Python","created_at":"2020-01-15T00:00:00Z","pushed_at":"2024-06-01T00:00:00Z","stargazers_count":42,"topics":["cli"]}'
    run bash -c "printf '%s' '$input' | \"$SCRIPT\" qte77"
    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-a"* ]]
    [[ "$output" == *"2020-01-15"* ]]
    [[ "$output" == *"2024-06-01"* ]]
}

@test "handles multiple repos, one task line each" {
    input=$'{"name":"repo-a","created_at":"2020-01-15T00:00:00Z","pushed_at":"2024-06-01T00:00:00Z"}\n{"name":"repo-b","created_at":"2021-02-01T00:00:00Z","pushed_at":"2022-03-01T00:00:00Z"}'
    run bash -c "printf '%s' '$input' | \"$SCRIPT\" qte77"
    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-a"* ]]
    [[ "$output" == *"repo-b"* ]]
}

@test "falls back to created_at when pushed_at is null (never-pushed repo)" {
    input='{"name":"repo-fresh","created_at":"2026-01-01T00:00:00Z","pushed_at":null}'
    run bash -c "printf '%s' '$input' | \"$SCRIPT\" qte77"
    [ "$status" -eq 0 ]
    [[ "$output" != *"null"* ]]
    [[ "$output" == *"2026-01-01"* ]]
}

@test "sanitizes the repo name for the mermaid task id but keeps the display label intact" {
    input='{"name":"my.repo","created_at":"2020-01-01T00:00:00Z","pushed_at":"2021-01-01T00:00:00Z"}'
    run bash -c "printf '%s' '$input' | \"$SCRIPT\" qte77"
    [ "$status" -eq 0 ]
    [[ "$output" == *"my.repo :"* ]]
    [[ "$output" != *":my.repo,"* ]]
}

@test "includes the account name in the title" {
    run bash -c "printf '' | \"$SCRIPT\" acme-corp"
    [ "$status" -eq 0 ]
    [[ "$output" == *"acme-corp"* ]]
}

@test "errors when account arg missing" {
    run bash -c "printf '' | \"$SCRIPT\""
    [ "$status" -ne 0 ]
}
