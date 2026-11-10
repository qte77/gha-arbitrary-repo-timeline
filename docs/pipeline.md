# Pipeline

What the action does, step by step, on each run:

1. Checks out the calling repository
2. Parses the comma-separated `REPOS` list and iterates over each entry,
   dispatching any entry with no `/` (an account or organization login) to
   account-mode discovery instead of steps 3-8 below
3. Rewrites the `## Open` section of `timelines/<owner>/<repo>.md` from a live
   query of currently open issues and PRs (no `DAYS` bound); files in the
   older date-section layout are converted to `## History` blocks first
4. Collects issues and PRs closed within the `DAYS` window (plus git log
   commits when `INCLUDE_GIT_LOG` is enabled)
5. Deduplicates them against the existing timeline file to avoid repeats
6. Adds them to `## History` as a collapsed `<details>` block for the run date
   (newest day first; repeat runs on one day merge into that day's block)
7. Generates a themed activity SVG at `assets/<owner>/<repo>-activity.svg`
   with auto light/dark mode (`prefers-color-scheme`)
8. Maintains a cumulative event log at `assets/<owner>/<repo>-activity.tsv`
   (deduped by date+event, last-write-wins)
9. After the loop, rewrites the cross-repo overview: `assets/overview.svg`
   (a heatmap with one row per repo over the last 30 days, built from the
   per-repo TSVs) and the `timelines/README.md` index (open PR/issue counts,
   last activity date, and links per repo)

**Account mode:** a `REPOS` entry with no `/` is treated as an account (user or
organization) login instead of an `owner/repo` pair, and account entries can be
mixed with per-repo entries in one comma-separated list. For example,
`REPOS: "qte77,qte77/gha-arbitrary-repo-timeline"`:

- `qte77` (no slash) discovers that account's public, non-fork, non-archived
  repos and writes `timelines/qte77/_account.md` with a repo lifespan Gantt
  chart (a Mermaid `gantt` block)
- `qte77/gha-arbitrary-repo-timeline` (has a slash) produces the normal
  per-repo timeline at `timelines/qte77/gha-arbitrary-repo-timeline.md`

## This repo's scheduled run

[`.github/workflows/update-timeline.yml`](../.github/workflows/update-timeline.yml)
runs the action on this repo itself and publishes the result to
[`timelines/README.md`](../timelines/README.md).

| Setting | Value |
|---|---|
| Schedule | weekly, Monday 06:00 UTC (`cron: '0 6 * * 1'`) |
| `DAYS` | `14`: two weeks back on a weekly run, so one missed run fills itself in; the overlap is deduplicated |
| `REPOS` | the `repos` input of a manual run, else the `TIMELINE_REPOS` repository variable (comma-separated `owner/repo` list), else this repo only |
| Output | a `chore: update timelines` PR from an `auto-timeline-<UTC timestamp>` branch, set to auto-merge once the required `CodeFactor` check passes |
| Cleanup | each run closes older open snapshot PRs and deletes `auto-timeline-*` branches that have no open PR |
| API use | the snapshot commit sends all file contents inline in one "Create a tree" request (no per-file blob calls); the last step logs the remaining REST budget (a 21-repo run on 2026-11-10 left 4,974 of 5,000) |
| Failure | a failed run opens one `Timeline update failed` issue, or comments on it if it is already open; close it once a run succeeds |

To run it by hand for a different repo list:
`gh workflow run update-timeline.yml -f repos="owner/repo1,owner/repo2"`.
