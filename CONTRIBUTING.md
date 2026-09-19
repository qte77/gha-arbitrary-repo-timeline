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

## Git & CI conventions

### Branch protection on `main`

`main` is protected by a repository ruleset requiring all changes to land
through a pull request. A direct push (observed 2026-09-19) is rejected with
`GH013: Repository rule violations found: Changes must be made through a
pull request` — this applies even to the repo owner.

Check the live ruleset:

```bash
gh api repos/qte77/gha-arbitrary-repo-timeline/rules/branches/main
```

As of 2026-09-19 it enforces (confirm before relying on this — the rule set
has changed before):

- `deletion` — the branch cannot be deleted.
- `non_fast_forward` — no force-pushes.
- `required_linear_history` — no merge commits on `main`; combined with
  `allowed_merge_methods` below, this rules out "Create a merge commit" in
  practice, leaving squash or rebase.
- `required_signatures` — commits must be signed.
- `pull_request` — changes must go through a PR.
  `required_approving_review_count` is currently `0` (no human review is
  required — only the PR mechanism itself), and
  `require_extra_approval_for_unattributed_changes` is `true`.
  `allowed_merge_methods` is `["merge", "squash", "rebase"]` — the ruleset
  does not itself force squash; squash-over-rebase is project convention
  (next section), not an enforced rule.
- `required_status_checks` — the `CodeFactor` check must pass.
- `code_quality` — enforced at `warnings` severity.

### Workflow convention: branch, validate, squash, delete

This repo has been following (only part of this is ruleset-enforced, see
above):

1. New topic branch per change.
2. Conventional Commits messages (see [Commits](#commits)).
3. `make validate` clean locally before opening a PR.
4. Squash-merge the PR once CI passes.
5. Delete the branch, both remote and local, after merge.

### SHA-pinning is required — a bare version tag stops the run before it starts

This repo's Actions settings have `sha_pinning_required: true`. Check:

```bash
gh api repos/qte77/gha-arbitrary-repo-timeline/actions/permissions
```

Every `uses:` line in every workflow file **and** in `action.yaml` must be a
full 40-character commit SHA, with a version or date comment for
readability, e.g. `uses: actions/checkout@<40-char-sha>  # v7`.

A bare tag (e.g. `actions/checkout@v7`) is not a lint nit — GitHub refuses to
even start the run: it shows `conclusion: startup_failure` with zero jobs,
regardless of the trigger event. This caused a full CI outage on this repo
before (see PRs #240–#245 in the git history).

### The Actions allow-list covers the whole resolved job graph

Actions permissions are set to `"selected"`, not "all": only GitHub-owned
actions, verified-publisher actions, and an explicit `patterns_allowed` list
may run. Check the current list:

```bash
gh api repos/qte77/gha-arbitrary-repo-timeline/actions/permissions/selected-actions
```

As of 2026-09-19 it is:

```json
[
  "qte77/.github/.github/workflows/lint-md-links.yml@*",
  "qte77/.github/.github/workflows/bump-version.yml@*",
  "qte77/.github/.github/workflows/tag-release.yml@*",
  "qte77/.github/.github/workflows/publish-release.yml@*",
  "DavidAnson/markdownlint-cli2-action@*",
  "lycheeverse/lychee-action@*"
]
```

The last two entries matter: this repo's own workflows never reference
`DavidAnson/markdownlint-cli2-action` or `lycheeverse/lychee-action`
directly. They run *inside* the `lint-md-links.yml` reusable workflow
(defined in `qte77/.github`) that this repo calls. The allow-list covers the
**entire resolved job graph**, including third-party actions pulled in
transitively by a called reusable workflow — not just this repo's own
direct `uses:` lines.

If you add a new reusable-workflow call, or any new third-party action
anywhere in the graph (including inside a reusable workflow you call), add
its pattern to the allow-list first, or the run will silently
`startup_failure`. The `PUT` replaces the whole list, so re-send every
existing pattern plus the new one:

```bash
gh api -X PUT repos/qte77/gha-arbitrary-repo-timeline/actions/permissions/selected-actions \
  -F github_owned_allowed=true \
  -F verified_allowed=true \
  -f 'patterns_allowed[]=qte77/.github/.github/workflows/lint-md-links.yml@*' \
  -f 'patterns_allowed[]=qte77/.github/.github/workflows/bump-version.yml@*' \
  -f 'patterns_allowed[]=qte77/.github/.github/workflows/tag-release.yml@*' \
  -f 'patterns_allowed[]=qte77/.github/.github/workflows/publish-release.yml@*' \
  -f 'patterns_allowed[]=DavidAnson/markdownlint-cli2-action@*' \
  -f 'patterns_allowed[]=lycheeverse/lychee-action@*' \
  -f 'patterns_allowed[]=<new-owner>/<new-action>@*'
```
