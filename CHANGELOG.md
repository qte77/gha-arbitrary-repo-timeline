<!-- markdownlint-disable MD024 no-duplicate-heading -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Types of changes**: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`

## [Unreleased]

### Added

- Themed activity SVG per repo at `assets/<owner>/<repo>-activity.svg`,
  embedded at the top of each timeline MD with `prefers-color-scheme`
  dark-mode and a clickable repo link (#84)
- Event-based activity categories with color-coded legend:
  `pr-opened`/`pr-merged`/`pr-closed`/`issue-opened`/`issue-resolved`/
  `issue-closed`/`commit` (#90)
- `Makefile` with `lint_sh`, `format_sh`, `format_sh_check`, `setup_dev`,
  `setup_shellcheck`, `setup_shfmt`, `test`, `validate`, `help` recipes
  (#75)
- `CONTRIBUTING.md` documenting prerequisites, make targets, and the
  TDD-with-BATS workflow (#75)
- `scripts/render-activity-svg.sh` and `scripts/collect-activity-counts.sh`
  for SVG rendering and per-day event count collection (#84, #90)
- CI now runs `make validate` (lint + format check + test) instead of
  `bats` directly, with cached `~/.local/bin` install of bats /
  shellcheck / shfmt (#88)

### Changed

- `Lint MD and Links` workflow pin bumped `5dfff1f` → `55ea1a99`; caller
  permissions add `issues: write` to satisfy the reusable workflow's
  `notify` job permission validation introduced server-side on
  2026-05-02 (#82)
- `update-timeline.yml` `permissions:` adds `issues: read` so the
  GITHUB_TOKEN can read `/issues` (#98)
- `scripts/collect-issues.sh` and `scripts/collect-activity-counts.sh`
  now use `gh api --paginate` on `/issues` to handle PR-heavy repos
  where issues fall past page 1 (#95)

### Fixed

- Activity SVG now refreshes every workflow run (was previously gated
  on having new MD items, so the 30-day chart went stale when the
  7-day timeline window was empty) (#95)
- Issue rows and chart bars now appear consistently — root cause was
  the workflow's `permissions:` block omitting `issues: read` (#98);
  the `--paginate` change in #95 was complementary but not the root
  cause

---

## [0.1.0] - 2026-03-29

---

### Added

- Composite action for generating repo activity timelines
- Timeline output to `projects/` directory with signed commit persistence
- 20 BATS infrastructure tests (TDD red-green)
- Repo scaffold: CodeQL, dependabot, bump-and-release, issue/PR templates
- Scheduled workflow for automatic timeline updates

### Fixed

- Handle empty `TIMELINE_REPOS` input gracefully
- Use temp file for tree entries to avoid argument list overflow in signed commits

### Changed

- Bump `callowayproject/bump-my-version` from 1.2.7 to 1.3.0
- Standardize repo scaffold
- Migrate license from MIT to Apache-2.0
