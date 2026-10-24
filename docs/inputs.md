# Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `REPOS` | Yes | | Comma-separated list of owner/repo pairs to monitor. An entry with no '/' is treated as an account (user or organization) login and produces an account-level repo lifespan timeline instead of a per-repo one. |
| `OUTPUT_FILE` | No | `TIMELINE.md` | Path to write timeline markdown. |
| `TOKEN` | No | `""` | GitHub token with read access to monitored repos. |
| `INCLUDE_GIT_LOG` | No | `false` | Include recent git log entries in timeline. |
| `DAYS` | No | `7` | Number of days to look back. |
| `INCLUDE_CONTRIBUTORS` | No | `false` | Include aggregated contributor activity in the timeline. Requires the host repo to be private or internal (enforced at runtime). |
| `INCLUDE_CONTRIBUTOR_PROFILE_DETAILS` | No | `false` | Include self-reported profile fields (location, company, bio) for contributors at/above the activity threshold. Requires INCLUDE_CONTRIBUTORS=true. |

> Source of truth: [`action.yaml`](../action.yaml). If this table and `action.yaml` ever
> disagree, `action.yaml` wins.

## Privacy requirement for contributor intelligence

`INCLUDE_CONTRIBUTORS` and `INCLUDE_CONTRIBUTOR_PROFILE_DETAILS` collect contributor
data (logins, event counts, and — when profile details are on — self-reported
location/company/bio). Two things to know before turning either on:

- Setting `INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true` requires
  `INCLUDE_CONTRIBUTORS=true` too; setting it without also setting
  `INCLUDE_CONTRIBUTORS` fails the run.
- Turning on either flag requires the **host repo** — the repo where this
  action's workflow runs, not the repos listed in `REPOS` — to be private or
  internal. This is checked at runtime against `github.repository_visibility`;
  a public host repo makes the run exit with an error rather than silently
  skipping contributor collection.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for what data is collected and how
contributors can stop future collection.
