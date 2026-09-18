#!/usr/bin/env bash
# Shared helpers for timeline generation.
set -euo pipefail

# Format ISO date N days ago.
days_ago() {
    date -d "${1:-7} days ago" +%Y-%m-%d 2>/dev/null ||
        date -v-"${1:-7}"d +%Y-%m-%d
}

# Privacy gate for contributor-identifying data collection (#110). Fires on
# any of the three contributor flags (INCLUDE_CONTRIBUTORS, its
# PROFILE_DETAILS sibling, and #108's TIMING flag), fails CLOSED on
# unset/empty repo visibility (never fail-open), and treats
# PROFILE_DETAILS/TIMING=true with CONTRIBUTORS=false as a hard config
# error rather than a silent no-op. Called once, before the repo loop.
assert_contributor_gate() {
    local any_flag="${INPUT_INCLUDE_CONTRIBUTORS:-false}"
    [[ "${INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS:-false}" == "true" ]] && any_flag=true
    [[ "${INPUT_INCLUDE_CONTRIBUTOR_TIMING:-false}" == "true" ]] && any_flag=true # #108's flag, checked here too
    [[ "$any_flag" != "true" ]] && return 0
    if [[ "${INPUT_INCLUDE_CONTRIBUTORS:-false}" != "true" ]]; then
        echo "ERROR: INCLUDE_CONTRIBUTOR_PROFILE_DETAILS/TIMING requires INCLUDE_CONTRIBUTORS=true." >&2
        exit 1
    fi
    case "${INPUT_REPO_VISIBILITY:-}" in
        private | internal) return 0 ;;
        *)
            echo "ERROR: INCLUDE_CONTRIBUTORS=true requires the host repo to be private or internal. Detected: '${INPUT_REPO_VISIBILITY:-<unset>}'." >&2
            exit 1
            ;;
    esac
}
