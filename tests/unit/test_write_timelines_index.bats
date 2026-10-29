#!/usr/bin/env bats
# Tests for write_timelines_index in generate-timeline.sh (#87): the
# cross-repo timelines/README.md index + assets/overview.svg, fully
# rewritten after the per-repo loop.

setup() {
    source "$BATS_TEST_DIRNAME/../../scripts/generate-timeline.sh"
    stub_dir="$(mktemp -d)"
    work_dir="$(mktemp -d)"
    # Open-items stubs: STUB_OPEN_<ISSUES|PRS>_<name> holds JSON lines for
    # repo acme/<name>; STUB_FAIL_OPEN makes the query fail.
    for kind in ISSUES PRS; do
        lower=$(echo "$kind" | tr '[:upper:]' '[:lower:]')
        cat >"$stub_dir/collect-${lower}.sh" <<STUB
#!/usr/bin/env bash
[[ "\${2:-}" == "--state" && "\${3:-}" == "open" ]] || exit 2
[[ -n "\${STUB_FAIL_OPEN:-}" ]] && exit 1
var="STUB_OPEN_${kind}_\${1##*/}"
printf '%s\n' "\${!var:-}"
STUB
    done
    # Renderer stub records its stdin so the combined TSV can be asserted.
    cat >"$stub_dir/render-overview-svg.sh" <<'STUB'
#!/usr/bin/env bash
cat >"$RENDER_INPUT"
echo '<svg>overview</svg>'
STUB
    chmod +x "$stub_dir"/*.sh
    export RENDER_INPUT="$work_dir/render-input.tsv"
    mkdir -p "$work_dir/assets/acme"
    printf '2026-04-20\tpr-opened\t2\n2026-04-22\tcommit\t1\n' >"$work_dir/assets/acme/a-activity.tsv"
    printf '2026-04-21\tissue-opened\t1\n' >"$work_dir/assets/acme/b-activity.tsv"
    ISSUE='{"type":"issue","number":1}'
    PR='{"type":"pr","number":2}'
}

teardown() {
    rm -rf "$stub_dir" "$work_dir"
    unset STUB_FAIL_OPEN STUB_OPEN_ISSUES_a STUB_OPEN_PRS_a STUB_OPEN_ISSUES_b STUB_OPEN_PRS_b
}

run_index() {
    (
        cd "$work_dir"
        SCRIPT_DIR="$stub_dir"
        write_timelines_index "$@"
    )
}

@test "writes one table row per repo with open counts, last activity and links" {
    export STUB_OPEN_ISSUES_a="$ISSUE" STUB_OPEN_PRS_a="$PR"$'\n'"$PR"
    run_index acme/a acme/b
    index="$work_dir/timelines/README.md"
    grep -qxF '| [acme/a](acme/a.md) | 2 | 1 | 2026-04-22 | [activity](../assets/acme/a-activity.svg) |' "$index"
    grep -qxF '| [acme/b](acme/b.md) | 0 | 0 | 2026-04-21 | [activity](../assets/acme/b-activity.svg) |' "$index"
}

@test "embeds the overview SVG and an auto-generated disclaimer at the top" {
    run_index acme/a
    index="$work_dir/timelines/README.md"
    [ "$(head -1 "$index")" = "# Timelines" ]
    grep -q 'Auto-generated' "$index"
    grep -qF '![Cross-repo activity](../assets/overview.svg)' "$index"
    [ "$(cat "$work_dir/assets/overview.svg")" = '<svg>overview</svg>' ]
}

@test "feeds the renderer every repo's activity TSV prefixed with owner/repo" {
    run_index acme/a acme/b
    grep -qxF $'acme/a\t2026-04-20\tpr-opened\t2' "$RENDER_INPUT"
    grep -qxF $'acme/b\t2026-04-21\tissue-opened\t1' "$RENDER_INPUT"
}

@test "shows ? for open counts and - for last activity when data is unavailable" {
    export STUB_FAIL_OPEN=1
    run_index acme/c
    grep -qxF '| [acme/c](acme/c.md) | ? | ? | - | [activity](../assets/acme/c-activity.svg) |' "$work_dir/timelines/README.md"
}

@test "skips account entries and trims whitespace" {
    run_index acme " acme/a "
    index="$work_dir/timelines/README.md"
    [ "$(grep -c '^| \[' "$index")" -eq 1 ]
    grep -qF '[acme/a](acme/a.md)' "$index"
}

@test "writes nothing when there are no owner/repo entries" {
    run_index acme
    [ ! -f "$work_dir/timelines/README.md" ]
    [ ! -f "$work_dir/assets/overview.svg" ]
}

@test "is a full rewrite: rerunning with the same data is byte-identical" {
    export STUB_OPEN_PRS_a="$PR"
    run_index acme/a acme/b
    first=$(cat "$work_dir/timelines/README.md")
    run_index acme/a acme/b
    [ "$first" = "$(cat "$work_dir/timelines/README.md")" ]
}
