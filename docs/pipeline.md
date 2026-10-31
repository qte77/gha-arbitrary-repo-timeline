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

**Account mode:** a `REPOS` entry with no `/` is treated as an account (user or
organization) login instead of an `owner/repo` pair, and account entries can be
mixed with per-repo entries in one comma-separated list. For example,
`REPOS: "qte77,qte77/gha-arbitrary-repo-timeline"`:

- `qte77` (no slash) discovers that account's public, non-fork, non-archived
  repos and writes `timelines/qte77/_account.md` with a repo lifespan Gantt
  chart (a Mermaid `gantt` block)
- `qte77/gha-arbitrary-repo-timeline` (has a slash) produces the normal
  per-repo timeline at `timelines/qte77/gha-arbitrary-repo-timeline.md`
