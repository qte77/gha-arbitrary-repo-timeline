#!/usr/bin/env bash
# Shared helpers for timeline generation.
set -euo pipefail

# Format ISO date N days ago.
days_ago() {
    date -d "${1:-7} days ago" +%Y-%m-%d 2>/dev/null \
        || date -v-"${1:-7}"d +%Y-%m-%d
}
