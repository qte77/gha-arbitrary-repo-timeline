#!/usr/bin/env bats
# Tests for the merge_activity_tsv function in generate-timeline.sh.
# Function reads two TSVs (existing + new) and emits a unioned, deduped
# TSV on stdout with new rows overriding existing rows on (date, event)
# collisions and sorted by (date, event) ascending.

setup() {
    HISTORY_FIXTURE="$BATS_TEST_DIRNAME/../fixtures/activity-history.tsv"
    EXISTING="$(mktemp)"
    NEW="$(mktemp)"
    source "$BATS_TEST_DIRNAME/../../scripts/generate-timeline.sh"
}

teardown() {
    rm -f "$EXISTING" "$NEW"
}

@test "merge yields new file content when existing is missing" {
    rm -f "$EXISTING"
    printf '2026-04-09\tpr-opened\t1\n2026-04-09\tpr-merged\t1\n' > "$NEW"
    result=$(merge_activity_tsv "$EXISTING" "$NEW")
    [ "$(printf '%s\n' "$result" | wc -l)" -eq 2 ]
    [[ "$result" == *"2026-04-09"$'\t'"pr-opened"$'\t'"1"* ]]
    [[ "$result" == *"2026-04-09"$'\t'"pr-merged"$'\t'"1"* ]]
}

@test "merge unions distinct (date, event) rows from both files" {
    cp "$HISTORY_FIXTURE" "$EXISTING"
    printf '2026-05-01\tpr-opened\t2\n2026-05-03\tissue-resolved\t1\n' > "$NEW"
    result=$(merge_activity_tsv "$EXISTING" "$NEW")
    # 4 from history + 2 from new = 6 distinct rows
    [ "$(printf '%s\n' "$result" | wc -l)" -eq 6 ]
    [[ "$result" == *"2026-04-01"$'\t'"pr-opened"$'\t'"2"* ]]
    [[ "$result" == *"2026-05-01"$'\t'"pr-opened"$'\t'"2"* ]]
    [[ "$result" == *"2026-05-03"$'\t'"issue-resolved"$'\t'"1"* ]]
}

@test "merge resolves (date, event) collisions with new winning (last-write-wins)" {
    cp "$HISTORY_FIXTURE" "$EXISTING"
    # Override (2026-04-01, pr-opened) which existed in history with count=2
    printf '2026-04-01\tpr-opened\t9\n' > "$NEW"
    result=$(merge_activity_tsv "$EXISTING" "$NEW")
    # Find the row, parse count
    count=$(printf '%s\n' "$result" | awk -F'\t' '$1=="2026-04-01" && $2=="pr-opened" {print $3}')
    [ "$count" = "9" ]
    # Other rows from history must remain
    [[ "$result" == *"2026-04-05"$'\t'"issue-opened"$'\t'"3"* ]]
}

@test "merge output is sorted ascending by date then event" {
    : > "$EXISTING"
    printf '2026-05-03\tcommit\t1\n2026-04-01\tpr-merged\t1\n2026-04-01\tpr-opened\t1\n' > "$NEW"
    result=$(merge_activity_tsv "$EXISTING" "$NEW")
    first=$(printf '%s\n' "$result" | head -1)
    last=$(printf '%s\n' "$result" | tail -1)
    [[ "$first" == "2026-04-01"$'\t'"pr-merged"* ]]
    [[ "$last" == "2026-05-03"$'\t'"commit"* ]]
}
