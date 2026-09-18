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

# --- assert_contributor_gate ---

@test "assert_contributor_gate no-ops when all contributor flags are false" {
    unset INPUT_INCLUDE_CONTRIBUTORS INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS INPUT_INCLUDE_CONTRIBUTOR_TIMING INPUT_REPO_VISIBILITY
    run assert_contributor_gate
    [ "$status" -eq 0 ]
}

@test "assert_contributor_gate passes when CONTRIBUTORS=true and visibility=private" {
    INPUT_INCLUDE_CONTRIBUTORS=true INPUT_REPO_VISIBILITY=private run assert_contributor_gate
    [ "$status" -eq 0 ]
}

@test "assert_contributor_gate passes when CONTRIBUTORS=true and visibility=internal" {
    INPUT_INCLUDE_CONTRIBUTORS=true INPUT_REPO_VISIBILITY=internal run assert_contributor_gate
    [ "$status" -eq 0 ]
}

@test "assert_contributor_gate fails closed when CONTRIBUTORS=true and visibility=public" {
    INPUT_INCLUDE_CONTRIBUTORS=true INPUT_REPO_VISIBILITY=public run assert_contributor_gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires the host repo to be private or internal"* ]]
}

@test "assert_contributor_gate fails closed when visibility is unset" {
    unset INPUT_REPO_VISIBILITY
    INPUT_INCLUDE_CONTRIBUTORS=true run assert_contributor_gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"<unset>"* ]]
}

@test "assert_contributor_gate fails closed when visibility is empty string" {
    INPUT_INCLUDE_CONTRIBUTORS=true INPUT_REPO_VISIBILITY="" run assert_contributor_gate
    [ "$status" -eq 1 ]
}

@test "assert_contributor_gate rejects PROFILE_DETAILS=true with CONTRIBUTORS=false" {
    unset INPUT_INCLUDE_CONTRIBUTORS
    INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true run assert_contributor_gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires INCLUDE_CONTRIBUTORS=true"* ]]
}

@test "assert_contributor_gate rejects TIMING=true with CONTRIBUTORS=false" {
    unset INPUT_INCLUDE_CONTRIBUTORS
    INPUT_INCLUDE_CONTRIBUTOR_TIMING=true run assert_contributor_gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires INCLUDE_CONTRIBUTORS=true"* ]]
}

@test "assert_contributor_gate passes when PROFILE_DETAILS=true, CONTRIBUTORS=true, visibility=private" {
    INPUT_INCLUDE_CONTRIBUTORS=true INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true INPUT_REPO_VISIBILITY=private run assert_contributor_gate
    [ "$status" -eq 0 ]
}

# --- replace_contributors_block ---

@test "replace_contributors_block inserts marker block at end of file" {
    printf '# owner/repo — Timeline\n\n## 2026-04-23\n\n- [ISSUE #1] x (2026-04-23) [open]\n' > "$OUTPUT_FILE"
    replace_contributors_block "$OUTPUT_FILE" "- **alice** — 5 events"
    grep -q '<!-- contributors-begin -->' "$OUTPUT_FILE"
    grep -q '<!-- contributors-end -->' "$OUTPUT_FILE"
    grep -q -- '- \*\*alice\*\* — 5 events' "$OUTPUT_FILE"
    # existing content must remain untouched
    grep -q 'ISSUE #1' "$OUTPUT_FILE"
}

@test "replace_contributors_block is idempotent with identical content" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    replace_contributors_block "$OUTPUT_FILE" "- **alice** — 5 events"
    first=$(cat "$OUTPUT_FILE")
    replace_contributors_block "$OUTPUT_FILE" "- **alice** — 5 events"
    second=$(cat "$OUTPUT_FILE")
    [ "$first" = "$second" ]
    [ "$(grep -c '<!-- contributors-begin -->' "$OUTPUT_FILE")" -eq 1 ]
}

@test "replace_contributors_block replaces stale content with fresh content" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    replace_contributors_block "$OUTPUT_FILE" "- **alice** — 5 events"
    replace_contributors_block "$OUTPUT_FILE" "- **bob** — 9 events"
    [[ "$(cat "$OUTPUT_FILE")" != *"alice"* ]]
    grep -q 'bob' "$OUTPUT_FILE"
    [ "$(grep -c '<!-- contributors-begin -->' "$OUTPUT_FILE")" -eq 1 ]
}

@test "replace_contributors_block removes the block entirely when content is empty" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    replace_contributors_block "$OUTPUT_FILE" "- **alice** — 5 events"
    grep -q 'contributors-begin' "$OUTPUT_FILE"
    replace_contributors_block "$OUTPUT_FILE" ""
    ! grep -q 'contributors-begin' "$OUTPUT_FILE"
    ! grep -q 'contributors-end' "$OUTPUT_FILE"
    ! grep -q 'alice' "$OUTPUT_FILE"
    grep -q '# owner/repo — Timeline' "$OUTPUT_FILE"
}

@test "replace_contributors_block no-ops when file does not exist" {
    rm -f "$OUTPUT_FILE"
    replace_contributors_block "$OUTPUT_FILE" "- **alice** — 5 events"
    [ ! -f "$OUTPUT_FILE" ]
}

@test "replace_contributors_block leaves file unchanged when no block exists and content is empty" {
    printf '# owner/repo — Timeline\n\n## 2026-04-23\n\n- [ISSUE #1] x (2026-04-23) [open]\n' > "$OUTPUT_FILE"
    before=$(cat "$OUTPUT_FILE")
    replace_contributors_block "$OUTPUT_FILE" ""
    after=$(cat "$OUTPUT_FILE")
    [ "$before" = "$after" ]
}

# --- sync_contributors_output / refresh_contributors_section (removal path) ---

@test "refresh_contributors_section removes stale MD block and JSON asset when CONTRIBUTORS=false" {
    unset INPUT_INCLUDE_CONTRIBUTORS
    JSON_FILE="$(mktemp -t contrib.XXXXXX.json)"
    printf '# owner/repo — Timeline\n\n<!-- contributors-begin -->\n- **alice** — 5 events\n<!-- contributors-end -->\n' > "$OUTPUT_FILE"
    printf '{"repo":"owner/repo"}' > "$JSON_FILE"
    refresh_contributors_section "owner/repo" "$OUTPUT_FILE" "$JSON_FILE" "2026-04-01" "7"
    [ ! -f "$JSON_FILE" ]
    ! grep -q 'contributors-begin' "$OUTPUT_FILE"
    ! grep -q 'alice' "$OUTPUT_FILE"
    grep -q '# owner/repo — Timeline' "$OUTPUT_FILE"
}

@test "sync_contributors_output writes JSON asset and MD block from fresh content" {
    JSON_FILE="$(mktemp -u -t contrib.XXXXXX.json)"
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    content='{"window_days":7,"contributors":[{"login":"alice","window_events":5,"tier":"enriched"}],"contribution_concentration":null}'
    sync_contributors_output "$OUTPUT_FILE" "$JSON_FILE" "$content"
    [ -f "$JSON_FILE" ]
    grep -q 'alice' "$JSON_FILE"
    grep -q 'contributors-begin' "$OUTPUT_FILE"
    grep -q 'alice' "$OUTPUT_FILE"
    rm -f "$JSON_FILE"
}

@test "refresh_contributors_section warns and removes stale data when the collector fails (fail-safe for PII)" {
    ORIG_SCRIPT_DIR="$SCRIPT_DIR"
    FAIL_DIR="$(mktemp -d)"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$FAIL_DIR/collect-contributors.sh"
    chmod +x "$FAIL_DIR/collect-contributors.sh"
    SCRIPT_DIR="$FAIL_DIR"
    JSON_FILE="$(mktemp -t contrib.XXXXXX.json)"
    printf '{"stale":true}' > "$JSON_FILE"
    printf '# owner/repo — Timeline\n\n<!-- contributors-begin -->\nstale\n<!-- contributors-end -->\n' > "$OUTPUT_FILE"
    INPUT_INCLUDE_CONTRIBUTORS=true run refresh_contributors_section "owner/repo" "$OUTPUT_FILE" "$JSON_FILE" "2026-04-01" "7"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN: contributor collection failed"* ]]
    [ ! -f "$JSON_FILE" ]
    ! grep -q 'stale' "$OUTPUT_FILE"
    SCRIPT_DIR="$ORIG_SCRIPT_DIR"
    rm -rf "$FAIL_DIR"
}

@test "refresh_contributors_section is a no-op removal when CONTRIBUTORS is unset and no stale data exists" {
    unset INPUT_INCLUDE_CONTRIBUTORS
    JSON_FILE="$(mktemp -u -t contrib.XXXXXX.json)"
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    refresh_contributors_section "owner/repo" "$OUTPUT_FILE" "$JSON_FILE" "2026-04-01" "7"
    [ ! -f "$JSON_FILE" ]
    [ -f "$OUTPUT_FILE" ]
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
