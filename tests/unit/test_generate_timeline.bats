#!/usr/bin/env bats

# Tests for the timeline MD helpers in generate-timeline.sh (dedup, rolling
# ## Open + collapsed ## History sections, activity embed, contributors).

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
    printf -- '- [ISSUE #1] foo (2026-04-01) [closed]\n' > "$OUTPUT_FILE"
    input=$'- [ISSUE #1] foo (2026-04-10) [closed]\n- [PR #2] bar (2026-04-02) [closed]\n'
    result=$(dedup_items "$input" "$OUTPUT_FILE")
    # ISSUE #1 dropped (closure already recorded); PR #2 kept
    [[ "$result" != *"ISSUE #1"* ]]
    [[ "$result" == *"PR #2"* ]]
}

@test "dedup_items keeps a closure whose ID is only recorded as [open]" {
    # Legacy history lists the item while it was open; its closure is new.
    printf -- '- [ISSUE #1] foo (2026-04-01) [open]\n' > "$OUTPUT_FILE"
    input=$'- [ISSUE #1] foo (2026-04-01) [closed]\n'
    result=$(dedup_items "$input" "$OUTPUT_FILE")
    [[ "$result" == *"ISSUE #1"* ]]
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

# --- collect_account (#109 Tier 1 — account discovery + lifespan timeline) ---

@test "collect_account writes timelines/<account>/_account.md with an H1 and a fenced mermaid block" {
    stub_dir="$(mktemp -d)"
    work_dir="$(mktemp -d)"
    cat >"$stub_dir/collect-account-repos.sh" <<'STUB'
#!/usr/bin/env bash
echo '{"name":"repo-a","created_at":"2020-01-01T00:00:00Z","pushed_at":"2021-01-01T00:00:00Z"}'
STUB
    cat >"$stub_dir/render-account-gantt.sh" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
echo '```mermaid'
echo 'gantt'
echo '```'
STUB
    chmod +x "$stub_dir/collect-account-repos.sh" "$stub_dir/render-account-gantt.sh"

    (
        cd "$work_dir"
        SCRIPT_DIR="$stub_dir"
        collect_account acme
    )

    [ -f "$work_dir/timelines/acme/_account.md" ]
    [ "$(head -n1 "$work_dir/timelines/acme/_account.md")" = "# acme — Repository Lifespans" ]
    grep -q '```mermaid' "$work_dir/timelines/acme/_account.md"
    rm -rf "$stub_dir" "$work_dir"
}

@test "collect_account does not clobber the file when the collector fails" {
    stub_dir="$(mktemp -d)"
    work_dir="$(mktemp -d)"
    cat >"$stub_dir/collect-account-repos.sh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x "$stub_dir/collect-account-repos.sh"

    (
        cd "$work_dir"
        SCRIPT_DIR="$stub_dir"
        collect_account acme
    )

    [ ! -f "$work_dir/timelines/acme/_account.md" ]
    rm -rf "$stub_dir" "$work_dir"
}

@test "collect_account is idempotent: two runs still produce exactly one H1" {
    stub_dir="$(mktemp -d)"
    work_dir="$(mktemp -d)"
    cat >"$stub_dir/collect-account-repos.sh" <<'STUB'
#!/usr/bin/env bash
echo '{"name":"repo-a","created_at":"2020-01-01T00:00:00Z","pushed_at":"2021-01-01T00:00:00Z"}'
STUB
    cat >"$stub_dir/render-account-gantt.sh" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
echo '```mermaid'
echo 'gantt'
echo '```'
STUB
    chmod +x "$stub_dir/collect-account-repos.sh" "$stub_dir/render-account-gantt.sh"

    (
        cd "$work_dir"
        SCRIPT_DIR="$stub_dir"
        collect_account acme
        collect_account acme
    )

    [ "$(grep -c '^# acme — Repository Lifespans$' "$work_dir/timelines/acme/_account.md")" -eq 1 ]
    rm -rf "$stub_dir" "$work_dir"
}

# --- write_open_section / prepend_history_entry / migration (#86) ---

# Prints the lines between the open-section markers of $1.
open_region() {
    awk '/^<!-- open-section-start -->$/ { on = 1; next } /^<!-- open-section-end -->$/ { on = 0 } on' "$1"
}

@test "write_open_section rewrites only the marked region and keeps the contributors block" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    write_open_section "$OUTPUT_FILE" "- [ISSUE #1] a (2026-04-01) [open]"
    replace_contributors_block "$OUTPUT_FILE" "- **alice** — 5 events"
    write_open_section "$OUTPUT_FILE" "- [PR #2] b (2026-04-02) [open]"
    [[ "$(open_region "$OUTPUT_FILE")" != *"ISSUE #1"* ]]
    [[ "$(open_region "$OUTPUT_FILE")" == *"PR #2"* ]]
    [ "$(grep -c '^## Open$' "$OUTPUT_FILE")" -eq 1 ]
    grep -q 'alice' "$OUTPUT_FILE"
    # Open stays above the contributors block
    [ "$(grep -n '^## Open$' "$OUTPUT_FILE" | cut -d: -f1)" -lt "$(grep -n 'contributors-begin' "$OUTPUT_FILE" | cut -d: -f1)" ]
}

@test "write_open_section renders a placeholder when nothing is open" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    write_open_section "$OUTPUT_FILE" ""
    grep -q '^## Open$' "$OUTPUT_FILE"
    grep -q '_No open issues or PRs._' "$OUTPUT_FILE"
}

@test "write_open_section keeps content after an orphan start marker (malformed file)" {
    printf '# owner/repo — Timeline\n\n<!-- open-section-start -->\n## Open\n\n- keep me\n' > "$OUTPUT_FILE"
    write_open_section "$OUTPUT_FILE" "- [PR #2] b (2026-04-02) [open]"
    grep -q 'keep me' "$OUTPUT_FILE"
    [ "$(grep -c 'open-section-start' "$OUTPUT_FILE")" -eq 1 ]
    [ "$(grep -c 'open-section-end' "$OUTPUT_FILE")" -eq 1 ]
}

@test "prepend_history_entry merges two same-day calls into one details block" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    prepend_history_entry "$OUTPUT_FILE" "2026-04-23" "- [ISSUE #1] a (2026-04-01) [closed]"
    prepend_history_entry "$OUTPUT_FILE" "2026-04-23" "- [PR #2] b (2026-04-02) [closed]"
    [ "$(grep -c '^## History$' "$OUTPUT_FILE")" -eq 1 ]
    [ "$(grep -c '<summary>2026-04-23</summary>' "$OUTPUT_FILE")" -eq 1 ]
    [ "$(grep -c '^</details>$' "$OUTPUT_FILE")" -eq 1 ]
    grep -q 'ISSUE #1' "$OUTPUT_FILE"
    grep -q 'PR #2' "$OUTPUT_FILE"
}

@test "prepend_history_entry puts the newest day first" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    prepend_history_entry "$OUTPUT_FILE" "2026-04-22" "- [ISSUE #1] a (2026-04-01) [closed]"
    prepend_history_entry "$OUTPUT_FILE" "2026-04-23" "- [PR #2] b (2026-04-02) [closed]"
    [ "$(grep -n '2026-04-23</summary>' "$OUTPUT_FILE" | cut -d: -f1)" -lt "$(grep -n '2026-04-22</summary>' "$OUTPUT_FILE" | cut -d: -f1)" ]
}

@test "prepend_history_entry is a no-op for empty items" {
    printf '# owner/repo — Timeline\n\n' > "$OUTPUT_FILE"
    prepend_history_entry "$OUTPUT_FILE" "2026-04-23" ""
    ! grep -q '## History' "$OUTPUT_FILE"
}

@test "migrate_legacy_sections_to_history wraps date sections newest-first and keeps the rest" {
    printf '# owner/repo — Timeline\n\n<!-- activity-svg-embed -->\n![activity](x.svg)\n\n## 2026-04-20\n\n- [ISSUE #1] a (2026-04-20) [open]\n\n## 2026-04-21\n\n- [PR #2] b (2026-04-21) [open]\n\n<!-- contributors-begin -->\n- **alice**\n<!-- contributors-end -->\n' > "$OUTPUT_FILE"
    migrate_legacy_sections_to_history "$OUTPUT_FILE"
    ! grep -q '^## 2026-04-2[01]$' "$OUTPUT_FILE"
    [ "$(grep -c '^## History$' "$OUTPUT_FILE")" -eq 1 ]
    [ "$(grep -n '2026-04-21</summary>' "$OUTPUT_FILE" | cut -d: -f1)" -lt "$(grep -n '2026-04-20</summary>' "$OUTPUT_FILE" | cut -d: -f1)" ]
    [ "$(head -1 "$OUTPUT_FILE")" = "# owner/repo — Timeline" ]
    grep -q 'activity-svg-embed' "$OUTPUT_FILE"
    grep -q 'ISSUE #1' "$OUTPUT_FILE"
    grep -q 'PR #2' "$OUTPUT_FILE"
    # contributors block stays outside the History details blocks, at the end
    [ "$(tail -1 "$OUTPUT_FILE")" = "<!-- contributors-end -->" ]
}

@test "migrate_legacy_sections_to_history is a no-op once the Open section exists" {
    printf '# owner/repo — Timeline\n\n<!-- open-section-start -->\n## Open\n\n<!-- open-section-end -->\n\n## 2026-04-20\n\n- x\n' > "$OUTPUT_FILE"
    before=$(cat "$OUTPUT_FILE")
    migrate_legacy_sections_to_history "$OUTPUT_FILE"
    [ "$before" = "$(cat "$OUTPUT_FILE")" ]
}

# --- main() end-to-end with stubbed collectors (#86) ---

# Stub collectors: STUB_OPEN_* answer `--state open`, STUB_WINDOW_* answer the
# windowed query; STUB_FAIL_OPEN makes the open query fail. Activity counts
# fail so the SVG step is skipped.
setup_main_stubs() {
    stub_dir="$(mktemp -d)"
    work_dir="$(mktemp -d)"
    for kind in ISSUES PRS; do
        lower=$(echo "$kind" | tr '[:upper:]' '[:lower:]')
        cat >"$stub_dir/collect-${lower}.sh" <<STUB
#!/usr/bin/env bash
if [[ "\${2:-}" == "--state" ]]; then
    [[ -n "\${STUB_FAIL_OPEN:-}" ]] && exit 1
    printf '%s\n' "\${STUB_OPEN_${kind}:-}"
else
    printf '%s\n' "\${STUB_WINDOW_${kind}:-}"
fi
STUB
    done
    printf '#!/usr/bin/env bash\nexit 1\n' >"$stub_dir/collect-activity-counts.sh"
    chmod +x "$stub_dir"/*.sh
    TIMELINE="$work_dir/timelines/acme/foo.md"
    TODAY=$(date -u +%Y-%m-%d)
    ISSUE1_OPEN='{"date":"2026-04-20","repo":"acme/foo","type":"issue","number":1,"title":"bug","state":"open","url":"u"}'
    ISSUE1_CLOSED='{"date":"2026-04-20","repo":"acme/foo","type":"issue","number":1,"title":"bug","state":"closed","url":"u"}'
    PR2_OPEN='{"date":"2026-04-21","repo":"acme/foo","type":"pr","number":2,"title":"fix","state":"open","url":"u"}'
}

run_main() {
    (
        cd "$work_dir"
        SCRIPT_DIR="$stub_dir"
        INPUT_REPOS="acme/foo" main >/dev/null
    )
}

teardown_main_stubs() {
    rm -rf "$stub_dir" "$work_dir"
    unset STUB_OPEN_ISSUES STUB_OPEN_PRS STUB_WINDOW_ISSUES STUB_WINDOW_PRS STUB_FAIL_OPEN
}

@test "main: open-only first run writes ## Open and no ## History" {
    setup_main_stubs
    export STUB_OPEN_ISSUES="$ISSUE1_OPEN" STUB_OPEN_PRS="$PR2_OPEN" STUB_WINDOW_ISSUES="$ISSUE1_OPEN"
    run_main
    [[ "$(open_region "$TIMELINE")" == *"[ISSUE #1] bug (2026-04-20) [open]"* ]]
    [[ "$(open_region "$TIMELINE")" == *"[PR #2] fix (2026-04-21) [open]"* ]]
    ! grep -q '## History' "$TIMELINE"
    teardown_main_stubs
}

@test "main: a closed item moves from ## Open into today's ## History block" {
    setup_main_stubs
    export STUB_OPEN_ISSUES="$ISSUE1_OPEN" STUB_WINDOW_ISSUES="$ISSUE1_OPEN"
    run_main
    export STUB_OPEN_ISSUES="" STUB_WINDOW_ISSUES="$ISSUE1_CLOSED"
    run_main
    [[ "$(open_region "$TIMELINE")" != *"ISSUE #1"* ]]
    grep -q "^<details><summary>${TODAY}</summary>$" "$TIMELINE"
    grep -q '^- \[ISSUE #1\] bug (2026-04-20) \[closed\]$' "$TIMELINE"
    teardown_main_stubs
}

@test "main: rerunning with unchanged data leaves the file byte-identical" {
    setup_main_stubs
    export STUB_OPEN_PRS="$PR2_OPEN" STUB_WINDOW_ISSUES="$ISSUE1_CLOSED"
    run_main
    first=$(cat "$TIMELINE")
    run_main
    [ "$first" = "$(cat "$TIMELINE")" ]
    [ "$(grep -c 'ISSUE #1' "$TIMELINE")" -eq 1 ]
    teardown_main_stubs
}

@test "main: migrates a legacy file and adds a fresh ## Open" {
    setup_main_stubs
    mkdir -p "$work_dir/timelines/acme"
    printf '# acme/foo — Timeline\n\n## 2026-04-20\n\n- [ISSUE #1] bug (2026-04-20) [open]\n\n' > "$TIMELINE"
    export STUB_OPEN_PRS="$PR2_OPEN" STUB_WINDOW_ISSUES="$ISSUE1_CLOSED"
    run_main
    ! grep -q '^## 2026-04-20$' "$TIMELINE"
    grep -q '<summary>2026-04-20</summary>' "$TIMELINE"
    [[ "$(open_region "$TIMELINE")" == *"PR #2"* ]]
    # the closure is recorded even though the legacy log listed the issue as open
    grep -q '\[ISSUE #1\] bug (2026-04-20) \[closed\]' "$TIMELINE"
    teardown_main_stubs
}

@test "main: keeps the previous ## Open when the open-items query fails" {
    setup_main_stubs
    export STUB_OPEN_PRS="$PR2_OPEN"
    run_main
    export STUB_FAIL_OPEN=1
    run_main
    [[ "$(open_region "$TIMELINE")" == *"PR #2"* ]]
    teardown_main_stubs
}
