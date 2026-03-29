# gha-arbitrary-repo-timeline

![Version](https://img.shields.io/badge/version-0.1.0-8A2BE2)

Generate a timeline from issues, PRs, and git log across arbitrary repos.

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
