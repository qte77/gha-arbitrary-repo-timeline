# gha-arbitrary-repo-timeline

Generate a timeline from issues, PRs, and git log across arbitrary repos.

![Version](https://img.shields.io/badge/version-0.1.0-8A2BE2)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Update Timeline](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/update-timeline.yml/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/update-timeline.yml)
[![BATS](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/test.yml/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/test.yml)
[![CodeFactor](https://www.codefactor.io/repository/github/qte77/gha-arbitrary-repo-timeline/badge)](https://www.codefactor.io/repository/github/qte77/gha-arbitrary-repo-timeline)
[![CodeQL](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/codeql.yaml/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/codeql.yaml)
[![Dependabot](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/dependabot/dependabot-updates)

## Usage

```yaml
- uses: qte77/gha-arbitrary-repo-timeline@v0
  with:
    REPOS: "owner/repo1,owner/repo2"
    TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## What it does

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

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `REPOS` | Yes | | Comma-separated list of owner/repo pairs to monitor |
| `OUTPUT_FILE` | No | `TIMELINE.md` | Path to write timeline markdown |
| `TOKEN` | No | `""` | GitHub token with read access to monitored repos |
| `INCLUDE_GIT_LOG` | No | `false` | Include recent git log entries in timeline |
| `DAYS` | No | `7` | Number of days to look back |

## Example output

This repo's own timeline is regenerated on every workflow run. See
[`timelines/qte77/gha-arbitrary-repo-timeline.md`](timelines/qte77/gha-arbitrary-repo-timeline.md)
for the live MD and the chart below for the live SVG (auto-themes
in both GitHub light and dark modes):

![Activity](https://raw.githubusercontent.com/qte77/gha-arbitrary-repo-timeline/main/assets/qte77/gha-arbitrary-repo-timeline-activity.svg)

Color legend: PR opened/merged/closed (green/purple/red), issue
opened/resolved/closed (blue/light-green/gray), commit (orange).

The cumulative event TSV
([`assets/qte77/gha-arbitrary-repo-timeline-activity.tsv`](assets/qte77/gha-arbitrary-repo-timeline-activity.tsv))
preserves history beyond the rolling 30-day chart window:

```tsv
2026-05-08	pr-merged	10
2026-05-08	issue-opened	4
2026-05-09	pr-opened	3
```

## License

[Apache-2.0](LICENSE)
