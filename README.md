# gha-arbitrary-repo-timeline

Generate a timeline from issues, PRs, and git log across arbitrary repos.

![Version](https://img.shields.io/badge/version-0.1.0-8A2BE2)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Update Timeline](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/update-timeline.yml/badge.svg)](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/workflows/update-timeline.yml)
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

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `REPOS` | required | Comma-separated list of owner/repo pairs |
| `OUTPUT_FILE` | `TIMELINE.md` | Path to write timeline markdown |
| `TOKEN` | `""` | GitHub token with read access |
| `INCLUDE_GIT_LOG` | `false` | Include git log entries |
| `DAYS` | `7` | Days to look back |
