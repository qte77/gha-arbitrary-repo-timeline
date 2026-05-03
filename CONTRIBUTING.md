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

## Commits

Follow the [Conventional Commits](https://www.conventionalcommits.org/) style.
The repository's `.gitmessage` template covers the expected prefixes (`feat:`,
`fix:`, `chore:`, `docs:`, `refactor:`, etc.). Configure git to use it:

```bash
git config commit.template .gitmessage
```
