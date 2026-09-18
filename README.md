# gha-arbitrary-repo-timeline

Generate a timeline from issues, PRs, and git log across arbitrary repos.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-blue)](CHANGELOG.md)
[![BATS](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/test.yml/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/test.yml)
[![Update Timeline](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/update-timeline.yml/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/update-timeline.yml)
[![CodeFactor](https://www.codefactor.io/repository/github/qte77/gha-arbitrary-repo-timeline/badge)](https://www.codefactor.io/repository/github/qte77/gha-arbitrary-repo-timeline)
[![CodeQL](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/codeql.yaml/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/codeql.yaml)
[![Dependabot](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/dependabot/dependabot-updates)

## Why

<!-- UNVERIFIED: general-knowledge claim about GitHub Insights/Pulse scope, confirm before merge -->
GitHub's built-in Insights and Pulse views are scoped to a single repository, so keeping tabs
on activity across several repos means opening each one separately. This action generates a
cross-repo activity timeline — as embeddable Markdown and an auto-theming SVG chart — that you
can drop into any README or tracking repo, with no hosted dashboard to run or maintain.

## Usage

```yaml
- uses: qte77/gha-arbitrary-repo-timeline@v0
  with:
    REPOS: "owner/repo1,owner/repo2"
    TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## What it does

- Tracks issue, PR, and (optionally) commit activity across any repos you list, so you don't
  have to watch each one separately
- Maintains a running Markdown timeline per repo, appending new activity on each scheduled run
- Renders a themed activity chart (SVG) that auto-switches between GitHub light and dark mode
- Preserves full event history in a compact TSV file, independent of the rolling chart window
- Works as a drop-in composite GitHub Action — no server, database, or third-party dashboard
  required
- Configurable lookback window and toggles for what to include, so it fits repos of any size

## Inputs

See [`docs/inputs.md`](docs/inputs.md) for the full inputs reference.

## Example output

<details>
<summary>Live SVG and TSV example (click to expand)</summary>

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

<!-- markdownlint-disable MD010 -->
```tsv
2026-05-08	pr-merged	10
2026-05-08	issue-opened	4
2026-05-09	pr-opened	3
```
<!-- markdownlint-enable MD010 -->

</details>

## Refs

- [`docs/pipeline.md`](docs/pipeline.md) — what the action does, step by step
- [`docs/inputs.md`](docs/inputs.md) — full inputs reference
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — local development, testing, and commit conventions
- [`CHANGELOG.md`](CHANGELOG.md) — release history

## License

[Apache-2.0](LICENSE)
