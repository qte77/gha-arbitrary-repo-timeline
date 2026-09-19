# Pipeline

What the action does, step by step, on each run:

1. Checks out the calling repository
2. Parses the comma-separated `REPOS` list and iterates over each entry,
   dispatching any entry with no `/` (an account or organization login) to
   account-mode discovery instead of steps 3-8 below
3. Collects recent issues and PRs from the GitHub API (within the configured `DAYS` window)
4. Optionally collects recent git log commits when `INCLUDE_GIT_LOG` is enabled
5. Deduplicates entries against the existing timeline file to avoid repeats
6. Appends new activity as a dated section to `timelines/<owner>/<repo>.md`
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
