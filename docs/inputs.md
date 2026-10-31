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
| `INCLUDE_CONTRIBUTOR_TIMING` | No | `false` | Include suggestive per-contributor timing patterns (modal UTC hour, weekend/off-hours share, streak) for contributors at/above the activity threshold. Requires INCLUDE_CONTRIBUTORS=true. |

> Source of truth: [`action.yaml`](../action.yaml). If this table and `action.yaml` ever
> disagree, `action.yaml` wins.

## Privacy requirement for contributor intelligence

`INCLUDE_CONTRIBUTORS`, `INCLUDE_CONTRIBUTOR_PROFILE_DETAILS` and
`INCLUDE_CONTRIBUTOR_TIMING` collect contributor data (logins, event counts,
and — when profile details are on — self-reported location/company/bio; when
timing is on — per-contributor activity timing). Three things to know before
turning any of them on:

- Setting `INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true` or
  `INCLUDE_CONTRIBUTOR_TIMING=true` requires `INCLUDE_CONTRIBUTORS=true` too;
  setting either without also setting `INCLUDE_CONTRIBUTORS` fails the run.
- Timing patterns are **suggestive, not authoritative**: a modal UTC hour is not
  a claim about where someone lives or when they work. They are computed only
  for contributors with at least 5 events in the window, from the timestamps of
  their public PRs, issues and commits in that window (UTC; off-hours = outside
  09:00–17:00 UTC). Every timing block in the JSON carries a `_note` saying so.
- Turning on either flag requires the **host repo** — the repo where this
  action's workflow runs, not the repos listed in `REPOS` — to be private or
  internal. This is checked at runtime against `github.repository_visibility`;
  a public host repo makes the run exit with an error rather than silently
  skipping contributor collection.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for what data is collected and how
contributors can stop future collection.
