# Pipeline

What the action does, step by step, on each run:

1. Checks out the calling repository
2. Parses the comma-separated `REPOS` list and iterates over each repo
3. Collects recent issues and PRs from the GitHub API (within the configured `DAYS` window)
4. Optionally collects recent git log commits when `INCLUDE_GIT_LOG` is enabled
5. Deduplicates entries against the existing timeline file to avoid repeats
6. Appends new activity as a dated section to `timelines/<owner>/<repo>.md`
7. Generates a themed activity SVG at `assets/<owner>/<repo>-activity.svg`
   with auto light/dark mode (`prefers-color-scheme`)
8. Maintains a cumulative event log at `assets/<owner>/<repo>-activity.tsv`
   (deduped by date+event, last-write-wins)
