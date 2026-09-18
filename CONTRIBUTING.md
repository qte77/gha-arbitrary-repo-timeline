# Contributing

Thanks for your interest in contributing to `gha-arbitrary-repo-timeline`.

## Local development

### Prerequisites

- [bats-core](https://github.com/bats-core/bats-core) — test runner
- [shellcheck](https://www.shellcheck.net/) — shell linter
- [shfmt](https://github.com/mvdan/sh) — shell formatter
- `jq` and `gh` (GitHub CLI) — used by the action scripts

Install them all via:

```bash
make setup_dev
```

### Common tasks

| Command | Purpose |
|---------|---------|
| `make test` | Run BATS test suite under `tests/` |
| `make lint_sh` | Lint shell scripts with shellcheck |
| `make format_sh` | Format shell scripts in place with shfmt |
| `make format_sh_check` | Check formatting without modifying files (CI) |
| `make validate` | `lint_sh` + `format_sh_check` + `test` |
| `make help` | List all recipes grouped by section |

## Testing

This project follows test-driven development. Tests live under `tests/unit/` as
BATS files. New behavior should start with a failing test (RED), then minimal
code to pass (GREEN), then refactor.

See `tests/unit/test_infra_files.bats` and `tests/unit/test_generate_timeline.bats`
for patterns.

## Right to erasure (contributor intelligence, #110 + #4)

When `INCLUDE_CONTRIBUTORS` is enabled, the action collects aggregated,
windowed contributor activity (login, event counts, and — only when
`INCLUDE_CONTRIBUTOR_PROFILE_DETAILS` is also set — self-reported profile
fields such as location, company, and bio) into
`timelines/<owner>/<repo>.md` and `assets/<owner>/<repo>-contributors.json`.
Emails are never read or stored by any script in this pipeline.

This data is **re-derived fresh on every run** — never carried forward —
which gives contributors two ways to stop future inclusion:

1. **Clearing GitHub profile fields.** A contributor who clears their
   location/company/bio on their GitHub profile stops future runs from
   emitting those fields, because each run re-fetches the current profile
   rather than reusing a prior snapshot.
2. **The `.timeline-no-contributors` opt-out file.** Adding a file at that
   path in the monitored repo makes future runs skip contributor collection
   for that repo entirely, and removes any previously emitted MD block and
   JSON asset (as does turning `INCLUDE_CONTRIBUTORS` back off).

**What this does *not* do — stated plainly, not papered over:** neither
mechanism erases data already committed to this repository's git history.
A `-contributors.json` asset or MD block from a past run remains readable
in every commit that included it, and in any fork or clone made before the
removal. Undoing that requires a maintainer to make a manual commit
removing the file(s), or to rewrite git history (e.g. via
`git filter-repo`) and force-push — both are maintainer actions outside
what this action can do on its own, since it only ever operates on the
working tree of the run that invokes it.

## Commits

Follow the [Conventional Commits](https://www.conventionalcommits.org/) style.
The repository's `.gitmessage` template covers the expected prefixes (`feat:`,
`fix:`, `chore:`, `docs:`, `refactor:`, etc.). Configure git to use it:

```bash
git config commit.template .gitmessage
```
