<!-- markdownlint-disable MD024 no-duplicate-heading -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Types of changes**: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`

## [Unreleased]

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
