#!/usr/bin/env bats
# Tests for scripts/analyze-contributor-timing.sh (#108) and the timing
# fragment in generate-timeline.sh's contributor MD section.
#
# Fixture contributor-events-timing.jsonl (hand-computed, all UTC):
#   dave  6 events over 3 weeks: 04-03 Fri 14h, 04-04 Sat 14h, 04-05 Sun 22h,
#         04-06 Mon 14h, 04-13 Mon 08h, 04-20 Mon 10h
#         -> 6 active days, modal hour 14, weekend 2/6=33%, off-hours
#            (22h, 08h) 2/6=33%, longest streak 04-03..04-06 = 4 days
#   erin  5 events, UTC+9-like: 04-07 Tue 01h+02h, 04-08 Wed 01h,
#         04-09 Thu 23h, 04-11 Sat 01h
#         -> 4 active days, modal hour 1, weekend 1/5=20%, off-hours 100%,
#            longest streak 04-07..04-09 = 3 days
#   frank 2 events -> below the threshold of 5, no timing

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/analyze-contributor-timing.sh"
    FIXTURE="$BATS_TEST_DIRNAME/../fixtures/contributor-events-timing.jsonl"
}

@test "computes hand-checked timing for a contributor active over several weeks" {
    run bash -c "'$SCRIPT' 5 < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -c '.dave | del(._note)')" = '{"first_activity":"2026-04-03","last_activity":"2026-04-20","n_active_days":6,"modal_utc_hour":14,"weekend_pct":33,"off_hours_pct":33,"longest_streak_days":4}' ]
}

@test "computes hand-checked timing for an off-hours (other-timezone) contributor" {
    run bash -c "'$SCRIPT' 5 < '$FIXTURE'"
    [ "$(echo "$output" | jq -c '.erin | del(._note)')" = '{"first_activity":"2026-04-07","last_activity":"2026-04-11","n_active_days":4,"modal_utc_hour":1,"weekend_pct":20,"off_hours_pct":100,"longest_streak_days":3}' ]
}

@test "omits contributors below the event threshold" {
    run bash -c "'$SCRIPT' 5 < '$FIXTURE'"
    [ "$(echo "$output" | jq 'has("frank")')" = "false" ]
    run bash -c "'$SCRIPT' 2 < '$FIXTURE'"
    [ "$(echo "$output" | jq 'has("frank")')" = "true" ]
}

@test "every timing object carries a suggestive-inference _note" {
    run bash -c "'$SCRIPT' 5 < '$FIXTURE'"
    [ "$(echo "$output" | jq '[.[] | ._note | test("suggestive")] | all')" = "true" ]
    [ "$(echo "$output" | jq 'length')" -eq 2 ]
}

@test "breaks a modal-hour tie toward the earliest hour" {
    run bash -c "printf '%s\n' '{\"login\":\"g\",\"timestamp\":\"2026-04-07T15:00:00Z\"}' '{\"login\":\"g\",\"timestamp\":\"2026-04-07T09:00:00Z\"}' | '$SCRIPT' 1"
    [ "$(echo "$output" | jq '.g.modal_utc_hour')" -eq 9 ]
}

@test "empty input yields an empty object" {
    run bash -c "'$SCRIPT' 5 < /dev/null"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "errors when the threshold argument is missing" {
    run bash -c "'$SCRIPT' < /dev/null"
    [ "$status" -ne 0 ]
}

# --- contributor MD fragment (generate-timeline.sh) ---

@test "contributors_md_fragment appends a suggestive timing summary when present" {
    source "$BATS_TEST_DIRNAME/../../scripts/generate-timeline.sh"
    content='{"window_days":7,"contributors":[{"login":"alice","window_events":6,"tier":"enriched","timing":{"modal_utc_hour":9,"weekend_pct":11,"off_hours_pct":40}},{"login":"bob","window_events":2,"tier":"login-only"}],"contribution_concentration":null}'
    run contributors_md_fragment "$content"
    [[ "$output" == *"- **alice** — 6 events (enriched; peak ~09:00 UTC, 11% weekend, 40% off-hours)"* ]]
    [[ "$output" == *"- **bob** — 2 events"* ]]
    [[ "$output" != *"bob** — 2 events ("* ]]
    [[ "$output" == *"suggestive"* ]]
}

@test "contributors_md_fragment adds no timing note when no contributor has timing" {
    source "$BATS_TEST_DIRNAME/../../scripts/generate-timeline.sh"
    content='{"window_days":7,"contributors":[{"login":"alice","window_events":6,"tier":"enriched"}],"contribution_concentration":null}'
    run contributors_md_fragment "$content"
    [[ "$output" == *"- **alice** — 6 events (enriched)"* ]]
    [[ "$output" != *"suggestive"* ]]
}
