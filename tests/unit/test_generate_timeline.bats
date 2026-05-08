#!/usr/bin/env bats

# Tests for dedup_items and append_section helpers in generate-timeline.sh.

setup() {
    OUTPUT_FILE="$(mktemp -t timeline.XXXXXX)"
    # Source the script without triggering main()
    source "$BATS_TEST_DIRNAME/../../scripts/generate-timeline.sh"
}

teardown() {
    rm -f "$OUTPUT_FILE"
}

# --- dedup_items ---

@test "dedup_items returns input unchanged when file does not exist" {
    rm -f "$OUTPUT_FILE"
    input=$'- [ISSUE #1] foo (2026-04-01) [open]\n- [PR #2] bar (2026-04-02) [open]\n'
    result=$(dedup_items "$input" "$OUTPUT_FILE")
    # command substitution strips trailing newlines; compare without them
    [ "$result" = "${input%$'\n'}" ]
}

@test "dedup_items filters lines whose ID token already appears in file" {
    printf -- '- [ISSUE #1] foo (2026-04-01) [open]\n' > "$OUTPUT_FILE"
    input=$'- [ISSUE #1] foo (2026-04-10) [closed]\n- [PR #2] bar (2026-04-02) [open]\n'
    result=$(dedup_items "$input" "$OUTPUT_FILE")
    # ISSUE #1 dropped (state changed but ID exists); PR #2 kept
    [[ "$result" != *"ISSUE #1"* ]]
    [[ "$result" == *"PR #2"* ]]
}

@test "dedup_items dedups by short SHA token" {
    printf -- '- [a1b2c3d] msg (2026-04-01)\n' > "$OUTPUT_FILE"
    input=$'- [a1b2c3d] msg (2026-04-01)\n- [deadbee] other (2026-04-02)\n'
    result=$(dedup_items "$input" "$OUTPUT_FILE")
    [[ "$result" != *"a1b2c3d"* ]]
    [[ "$result" == *"deadbee"* ]]
}

@test "dedup_items keeps lines with no recognizable ID token" {
    printf -- '- existing\n' > "$OUTPUT_FILE"
    input=$'- plain line without id\n'
    result=$(dedup_items "$input" "$OUTPUT_FILE")
    [[ "$result" == *"plain line without id"* ]]
}

# --- append_section ---

@test "append_section creates new date header when absent" {
    : > "$OUTPUT_FILE"
    items=$'- [ISSUE #1] foo (2026-04-23) [open]\n'
    append_section "$OUTPUT_FILE" "2026-04-23" "$items"
    [ "$(grep -c '^## 2026-04-23$' "$OUTPUT_FILE")" -eq 1 ]
    grep -q 'ISSUE #1' "$OUTPUT_FILE"
}

@test "append_section does not duplicate date header when present" {
    printf '## 2026-04-23\n\n- [ISSUE #1] foo (2026-04-23) [open]\n\n' > "$OUTPUT_FILE"
    items=$'- [PR #2] bar (2026-04-23) [open]\n'
    append_section "$OUTPUT_FILE" "2026-04-23" "$items"
    # Still exactly one date header; both items present
    [ "$(grep -c '^## 2026-04-23$' "$OUTPUT_FILE")" -eq 1 ]
    grep -q 'ISSUE #1' "$OUTPUT_FILE"
    grep -q 'PR #2' "$OUTPUT_FILE"
}

# --- Integration: dedup + append together ---

@test "dedup + append: state transition does not duplicate entry" {
    # Seed: issue #42 was open on an earlier run
    printf '# repo — Timeline\n\n## 2026-04-20\n\n- [ISSUE #42] fix bug (2026-04-20) [open]\n\n' > "$OUTPUT_FILE"
    # Same issue now closed
    incoming=$'- [ISSUE #42] fix bug (2026-04-23) [closed]\n'
    filtered=$(dedup_items "$incoming" "$OUTPUT_FILE")
    # Nothing to append
    [ -z "$filtered" ]
    # File still has exactly one [ISSUE #42]
    [ "$(grep -c 'ISSUE #42' "$OUTPUT_FILE")" -eq 1 ]
}

@test "prepend_activity_embed inserts marker and image after H1" {
    printf '# qte77/foo — Timeline\n\n## 2026-04-23\n\n- [PR #1] x (2026-04-23) [open]\n' > "$OUTPUT_FILE"
    prepend_activity_embed "$OUTPUT_FILE" "../../assets/qte77/foo-activity.svg"
    grep -q '<!-- activity-svg-embed -->' "$OUTPUT_FILE"
    grep -q '!\[activity\](\.\./\.\./assets/qte77/foo-activity\.svg)' "$OUTPUT_FILE"
    # H1 must remain on line 1
    [ "$(head -1 "$OUTPUT_FILE")" = "# qte77/foo — Timeline" ]
    # Date header must still be present
    grep -q '^## 2026-04-23$' "$OUTPUT_FILE"
}

@test "prepend_activity_embed is idempotent (no double insert)" {
    printf '# qte77/foo — Timeline\n\n' > "$OUTPUT_FILE"
    prepend_activity_embed "$OUTPUT_FILE" "../../assets/qte77/foo-activity.svg"
    prepend_activity_embed "$OUTPUT_FILE" "../../assets/qte77/foo-activity.svg"
    [ "$(grep -c '<!-- activity-svg-embed -->' "$OUTPUT_FILE")" -eq 1 ]
    [ "$(grep -c '!\[activity\]' "$OUTPUT_FILE")" -eq 1 ]
}

@test "dedup + append: two runs same day produce single date header" {
    printf '# repo — Timeline\n\n' > "$OUTPUT_FILE"
    # Run 1
    items_a=$'- [ISSUE #1] a (2026-04-23) [open]\n'
    filtered_a=$(dedup_items "$items_a" "$OUTPUT_FILE")
    append_section "$OUTPUT_FILE" "2026-04-23" "$filtered_a"
    # Run 2, same day, different item
    items_b=$'- [PR #2] b (2026-04-23) [open]\n'
    filtered_b=$(dedup_items "$items_b" "$OUTPUT_FILE")
    append_section "$OUTPUT_FILE" "2026-04-23" "$filtered_b"
    # Single date header, both items present
    [ "$(grep -c '^## 2026-04-23$' "$OUTPUT_FILE")" -eq 1 ]
    grep -q 'ISSUE #1' "$OUTPUT_FILE"
    grep -q 'PR #2' "$OUTPUT_FILE"
}
