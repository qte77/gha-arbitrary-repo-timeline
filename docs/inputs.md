# Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `REPOS` | Yes | | Comma-separated list of owner/repo pairs to monitor |
| `OUTPUT_FILE` | No | `TIMELINE.md` | Path to write timeline markdown |
| `TOKEN` | No | `""` | GitHub token with read access to monitored repos |
| `INCLUDE_GIT_LOG` | No | `false` | Include recent git log entries in timeline |
| `DAYS` | No | `7` | Number of days to look back |

> Source of truth: [`action.yaml`](../action.yaml). If this table and `action.yaml` ever
> disagree, `action.yaml` wins.
