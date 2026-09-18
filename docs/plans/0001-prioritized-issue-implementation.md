# 0001 — Prioritized Issue Implementation (ROI-ranked backlog, tiered)

## Status / handoff — read this first

**Shipped so far: Wave A is fully merged to `main`.** A manual snapshot run was also triggered and
completed successfully —
[run 35298922119](https://github.com/qte77/gha-arbitrary-repo-timeline/actions/runs/35298922119).

| Row | PR | Tests | Notes |
|---|---|---|---|
| W1-1 (#164) | [#230](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/230) merged | 79/79 BATS, all CI green | No MD033 issue confirmed by real CI (no local lint config existed) |
| W1-2 (#174) | [#233](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/233) merged | 82 BATS, `make validate` clean | Both blocking questions resolved by reading actual upstream commit `qte77/.github@4801217`; floating `v0` tag handled via new job; publish wired via `workflow_run` (push:tags would never fire — GITHUB_TOKEN recursion guard, confirmed) |
| W1-3 (#86-prep) | [#231](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/231) merged | 91/91 BATS | `--state open` flag on collect-issues.sh/collect-prs.sh; unblocks W2-1 |
| W3-1 (#110+#4) | [#234](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/234) merged | 130/130 BATS, `make validate` clean | `github.repository_visibility` still unverified against a live run (gate fails closed if wrong, not leaks) — verify before relying on it in production |
| W3-2 (#109 T1) | [#232](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/232) merged | 100/100 BATS | Org-vs-user endpoint question resolved empirically (live `gh api` call); ships without #110's gate per plan default, flagged pending maintainer confirmation. Needed 2 rebases (test_infra_files.bats conflicted with both #230 and #234; generate-timeline.sh conflicted with #234 — both resolved by keeping both sides' additions, verified with `make validate` after each) |
| T0-A (#214) | merged directly (dependabot) | CI green | codeql-action bump, unrelated to the rest |
| T0-B (#226) | auto-closed by GitHub | — | targeted `bump-and-release.yaml`, deleted by #233; closed itself once that landed, no action needed |
| W1-4 (#83) | [issue comment](https://github.com/qte77/gha-arbitrary-repo-timeline/issues/83#issuecomment-5724391792) | — | decision recorded, no PR |

All Wave A/T0 branches (remote + local) and worktrees have been deleted. `main` is at `567657c`.

**What's next, in order:** start Wave B (W2-1 → W2-2, and W4-1) from fresh worktrees off current
`main` — both W1-3 and W3-1's prerequisites are now satisfied. Do not start a Wave B row until its
`depends-on` row is merged (both now are).

**The loop (per row):**

1. Pick the next unblocked row from the table.
2. `git worktree add ../grt-<row-id> -b <row-id>-<slug> main` (fresh worktree per row — see
   "Worktree plan" below for which rows may run concurrently).
3. Implement using the design already written out in this file's per-cluster sections — do not
   re-derive it, it's already fully specified (function names, line ranges, schemas, diffs).
4. Any row marked with an unresolved open question below MUST resolve it first (read the cited
   file/spec) — do not implement past an unresolved blocking question.
5. `make validate` (lint_sh + format_sh_check + test) must pass locally before opening a PR.
6. Conventional Commits message, PR via `gh pr create`. Squash-merge only on green CI.
7. Strike the row in the SAME PR (edit this table's checkbox/status), remove the worktree
   (`git worktree remove`), delete the branch.
8. If a row surfaces new follow-up work, add it as a new row — do not let it disappear silently
   (no-orphans rule).

**Owner-gates in this arc** (agent proceeds with the stated default; owner can override before
that row starts — see "Open decisions" section for full context on each):

- #83 renderer decision — **default: adopt the split recommendation already resolved below**
  (mermaid `gantt` for #109's chart, keep/extend awk for #87's heatmap, don't touch the existing
  bar chart). Treated as resolved in this plan, not re-opened, unless overridden.
- #86 History ordering — **default: newest-first** `<details>` blocks. Not explicitly required by
  the issue text.
- #174 floating `v0` major-tag handling and the `GITHUB_TOKEN` push-recursion trigger chain —
  **default: confirm by reading the three upstream `qte77/.github` workflow files before writing
  final YAML** (see Housekeeping section); if the reusable workflows don't maintain a floating
  major tag, add one explicit step for it; wire `publish-release.yml` via `workflow_run`, not
  `push: tags:`.
- #109 Tier 1 privacy-gate applicability — **default: Tier 1 ships without the #110 gate** (it
  surfaces zero contributor/person-level fields). This is the one item flagged as "confirm with
  maintainer" rather than a closed decision — see Open decisions.
- #108 off-hours window convention — **default: 09:00–17:00 UTC counts as work hours**, everything
  else is off-hours.
- `.timeline-no-contributors` scope — **default: per-repo only**, matching the issue's literal
  wording, no account-wide opt-out in this arc.

**Commands:**

```bash
make setup_dev      # installs bats-core, shellcheck, shfmt, jq, gh
make validate        # lint_sh + format_sh_check + test — run before every PR
make test             # BATS only
gh workflow run update-timeline.yml   # manual snapshot trigger (workflow_dispatch, optional `repos` input)
```

**Watch-outs (do not relearn these the hard way):**

- `scripts/generate-timeline.sh:70-82` (`append_section`) is append-only today. #86 replaces it;
  until #86 lands, do not assume any in-place rewrite semantics exist for the MD body.
- The current release pipeline (`bump-and-release.yaml`) **already violates** its own "never
  delete tags/releases on failure" guardrail via `.github/scripts/delete_branch_pr_tag.sh` — #174
  fixes this as a side effect, it is not a new requirement being introduced.
- `pyproject.toml:31-32`'s bump-my-version README search string is hardcoded to `8A2BE2` (purple).
  #164's badge-color change and this search string **must land in the same PR** or version bumps
  silently stop updating the README badge.
- `github.repository_visibility` (needed for #110's host-visibility gate) is verified as a real
  GitHub Actions context property only via secondary sources in this session — confirm with a
  throwaway `workflow_dispatch` debug step (`echo '${{ toJSON(github) }}' | jq .repository_visibility`)
  before wiring #4's gate to it.
- Contributor data (#4) must be **replaced**, never appended — if `INCLUDE_CONTRIBUTORS` flips back
  to `false`, or `.timeline-no-contributors` appears, a run must delete the stale
  `-contributors.json` and strip the MD block, or PII persists in HEAD after the flag is off.
- `tests/unit/test_infra_files.bats:44-47` and `:64-66` will break under #174 and must be rewritten
  as part of that PR, not left red.
- `docs/` did not exist before this plan file. `docs/inputs.md` and `docs/pipeline.md` (from #164)
  will be the only other files under it in this arc — no actual conflict, just be aware both land
  around the same time.

---

## Source map

| Area | Path | Notes |
|---|---|---|
| Composite action | `action.yaml` (45 lines) | Inputs: `REPOS` (required), `OUTPUT_FILE` (default `TIMELINE.md`), `TOKEN`, `INCLUDE_GIT_LOG`, `DAYS`. No `outputs:` block. Runs: checkout (`actions/checkout@v7`) → `chmod +x scripts/*.sh` → source `common.sh` → exec `generate-timeline.sh` (`action.yaml:33-44`). `action.yaml:40` already does `GH_TOKEN: ${{ inputs.TOKEN \|\| github.token }}` — proof that composite steps can read the `github.*` context directly, no new input plumbing needed for `repository_visibility`. |
| Main pipeline | `scripts/generate-timeline.sh` (179 lines) | `dedup_items()` 12-28 · `merge_activity_tsv()` 34-48 (full-rewrite precedent for TSV) · `prepend_activity_embed()` 53-65 (marker-guarded one-time in-place splice) · `append_section()` 70-82 (**append-only, #86 replaces this**) · `main()` 84-174 (per-repo loop over comma-split `REPOS`) · invocation guard 177-179. |
| SVG renderer | `scripts/render-activity-svg.sh` (210 lines) | The awk renderer from #83. `emit_style_block()` 47-72 (shared CSS/palette — extraction target for #87) · `emit_empty_svg()` 74-80 · `emit_legend()` 82-101 · stdin→tempfile+date-slice 103-120 · layout calc 122-130 · core awk (`order()`, `class_for()`, stacked `<rect>` emission) 143-201 · SVG root/labels 132-141, 203-210. |
| Data collectors | `scripts/collect-activity-counts.sh` (67) · `scripts/collect-issues.sh` (12, already emits `state`) · `scripts/collect-prs.sh` (10, already emits `state`) · `scripts/common.sh` (9, has `days_ago()`) | |
| Tests | `tests/unit/test_generate_timeline.bats`, `test_render_activity_svg.bats`, `test_collect_activity_counts.bats`, `test_infra_files.bats`, `test_merge_activity_tsv.bats` · fixtures in `tests/fixtures/*.json`/`*.tsv` | TDD via BATS, Red→Green (`CONTRIBUTING.md:31-38`). |
| Release pipeline (pre-#174) | `.github/workflows/bump-and-release.yaml` (122 lines, `workflow_dispatch` only) · `.github/scripts/delete_branch_pr_tag.sh` · `pyproject.toml:10-45` (`[tool.bumpversion]`, patches `pyproject.toml`/`README.md`/`CHANGELOG.md`) | No scriv in this repo (`changelog.d/` absent, confirmed). Existing SHA-pin precedent for reusable workflows: `.github/workflows/lint-md-links.yml:17`. |
| Other workflows | `.github/workflows/update-timeline.yml` (`schedule` 06:00 UTC daily + `workflow_dispatch` with optional `repos` input, falls back to `vars.TIMELINE_REPOS`; permissions `contents:write, pull-requests:write, issues:read`; "Commit if changed" step does `git add timelines/ assets/` — **directory-level add, new files under those dirs need no workflow change**) · `test.yml` · `codeql.yaml` · `lint-md-links.yml` | |
| Docs | `README.md` (72 lines, current) · `CONTRIBUTING.md` (1462 bytes: `make` targets, TDD convention, Conventional Commits via `.gitmessage`) · `CHANGELOG.md` · **no `AGENTS.md`** · **`docs/` did not exist before this file** | |
| Output layout | `timelines/qte77/*.md` (self-tracking + other tracked repos) · `assets/qte77/*-activity.{svg,tsv}` | Confirms the action tracks itself. |

External refs (not fetchable from this session — read before implementing #174):
`qte77/.github/.github/workflows/{bump-version,tag-release,publish-release}.yml` (merged
2026-07-17, qte77/.github PR #33, tracking issue qte77/.github#32, both closed/merged — confirmed
via `gh` in this session, contents not read).

---

## Decision record — #83 (resolved, adopted as default)

Verified against mermaid's own diagram-type list and issue tracker: **no native heatmap type
exists**; `gantt` **is** native; `xychart-beta` multi-series bars currently render as
overlay/occlusion, not stacking (open bug mermaid-js/mermaid#7392) — would regress the existing
7-category stacked bar chart.

**Rule applied: use mermaid only where it has a native, stable primitive for the exact shape
needed; keep/extend awk everywhere it doesn't.**

- **#109's Gantt chart → mermaid native `gantt`.** Building Gantt layout in awk from scratch would
  be more code than the current 210-line bar renderer. Use it directly, no new SVG script.
- **#87's heatmap → stays in the awk/SVG family**, as a new *sibling* script
  (`scripts/render-overview-svg.sh`), not an extension of the existing bar-chart awk block.
  Simpler than the bar chart (no stacking, no per-type legend).
- **Existing per-repo bar chart → do not migrate.** Works, tested, mermaid would regress it. No
  forcing function.
- Implication: `emit_style_block()` (`render-activity-svg.sh:47-72`) should be extracted to
  `scripts/common.sh` so the new heatmap renderer reuses it — now justified by a second real call
  site, not speculative (AHA).

---

## Cluster: Housekeeping (#164, #174)

### #164 — README doc-structure canon (S)

Full proposed replacement content (already satisfies every itemized delta from the maintainer's
re-audit comment):

**`README.md`** — badge order fixed to License→Version→CI, Version badge recolored to
shields.io blue and linked to `CHANGELOG.md`, new `## Why` section (2-4 lines, **flagged
UNVERIFIED general-knowledge claim about GitHub Insights/Pulse scope — confirm before merge**),
`## What it does` rewritten as ≤7 reader-value bullets (implementation steps moved to new
`docs/pipeline.md`), live SVG example collapsed into a `<details>` block, `## Inputs` replaced
with a one-line link to new `docs/inputs.md`, new `## Refs` section before `## License`.

**New `docs/inputs.md`** — the existing 5-row inputs table verbatim (verified against
`action.yaml:8-23`, matches exactly), plus a note pointing to `action.yaml` as authoritative.

**New `docs/pipeline.md`** — verbatim relocation of the original 8 numbered pipeline steps from
old `README.md:24-32`. No information lost.

**Required companion diff — `pyproject.toml:29-32`:**
```diff
         [[tool.bumpversion.files]]
         filename = "README.md"
-        search = "![Version](https://img.shields.io/badge/version-{current_version}-8A2BE2)"
-        replace = "![Version](https://img.shields.io/badge/version-{new_version}-8A2BE2)"
+        search = "![Version](https://img.shields.io/badge/version-{current_version}-blue)"
+        replace = "![Version](https://img.shields.io/badge/version-{new_version}-blue)"
```
Must land in the **same PR** as the README badge-color change (see watch-outs above).

**BATS impact:** breaks nothing existing. Recommend adding a new test asserting the
`pyproject.toml` search string literally matches the README badge markup (nothing currently tests
these two files stay in sync — that's exactly how the `8A2BE2` mismatch would go unnoticed).

**Open question:** the `<details>/<summary>` block may trip default markdownlint MD033 (no local
markdownlint config found to confirm an exception) — mirror the existing MD010
disable/enable-comment pattern (`README.md:61,67`) as a hedge; confirm against actual CI lint
output.

### #174 — adopt qte77/.github reusable release workflows (M, conditional)

**Current state:** `bump-and-release.yaml` tags the **pre-merge branch commit** (line 78) and
force-updates a floating `v{MAJOR}` tag before merge (lines 99-110); on failure, it deletes the
PR/branch/Release/tag (`delete_branch_pr_tag.sh`) — this **already violates** the target
guardrail, so migrating away from it is a strict improvement.

**Blocking open questions — resolve by reading the 3 upstream files before writing final YAML:**

1. **Floating `v0` major tag.** `README.md:16` tells every consumer `uses: ...@v0`. Only the
   *current* workflow maintains that floating tag. If none of the three reusable workflows does,
   every `@v0` consumer silently stops receiving updates after the first release under the new
   pipeline. If unsupported upstream, add one explicit `PATCH refs/tags/v{MAJOR} --force` step in
   the local `publish-release.yml` caller (this is the one *intentional* tag mutation to keep,
   distinct from the delete-on-failure behavior being removed).
2. **`GITHUB_TOKEN`-authored pushes don't trigger downstream `push:`-triggered workflows**
   (GitHub's recursion guard). If `tag-release.yml` pushes its tag via `GITHUB_TOKEN`, a
   `publish-release.yml` triggered by `push: tags:` will never fire. Default: wire
   `publish-release.yml` via `workflow_run: { workflows: ["Tag Release"], types: [completed] }`
   instead of `push: tags:`.

**Proposed new files** (SHA-pin per this repo's own precedent at `lint-md-links.yml:17`, not
`@main` as the issue's sketch shows):

- `.github/workflows/bump-version.yml` — `workflow_dispatch` with `bump_type` choice
  (major/minor/patch) → `uses: qte77/.github/.github/workflows/bump-version.yml@<PIN_SHA>` with
  `collect_scriv: false` (confirmed: this repo has no scriv), `use_uv: false`, `sync_lockfile:
  false` — **all three input names UNVERIFIED, taken only from the issue text; confirm against the
  actual upstream file first.**
- `.github/workflows/tag-release.yml` — `push: { branches: [main], paths: [pyproject.toml] }` →
  `uses: .../tag-release.yml@<PIN_SHA>`.
- `.github/workflows/publish-release.yml` — `workflow_run` trigger per open question 2 →
  `uses: .../publish-release.yml@<PIN_SHA>` (+ floating-tag step if open question 1 confirms it's
  needed).
- Delete `bump-and-release.yaml` and `delete_branch_pr_tag.sh` **only if** the reusable workflows
  are confirmed abort-on-exists/idempotent (per the issue's own guardrail requirement) — confirm
  by reading upstream, don't assume.

**BATS impact:** `test_infra_files.bats:44-47` (greps `bump-my-version` string inside the old
workflow file — breaks the moment that string moves into the reusable workflow) and `:64-66`
(asserts `delete_branch_pr_tag.sh` executable — breaks if deleted) **must be rewritten in the same
PR**, e.g.:
```bats
@test "bump-version workflow calls the qte77/.github reusable workflow" {
    [ -f .github/workflows/bump-version.yml ]
    grep -q 'qte77/.github/.github/workflows/bump-version.yml@' .github/workflows/bump-version.yml
}
```
Add equivalent tests for `tag-release.yml` and `publish-release.yml`. Note `make validate` does
not lint workflow YAML at all (no yamllint/actionlint target in `Makefile`) — these grep-based
BATS tests are the only local guard against drift.

**Sequencing:** land #164 before #174 (or at minimum before the next triggered bump) so the
badge-color search string is already correct.

---

## Cluster: Rendering (#86, #87)

### Prep step (do first, unblocks #86) — extract `--state open` collector mode

`collect-issues.sh`/`collect-prs.sh` already emit a `state` field (issues.sh:12, prs.sh:10) but
only via time-boxed `since=...` queries. #86 needs a **live, unbounded, `state=open`** query so an
old open PR doesn't vanish from `## Open` just because it aged out of the `--days` lookback. Add a
`--state open` flag to both scripts (reuses existing jq filters, needs `--paginate` like the
existing issues query to avoid PR-heavy repos burying real issues past page 1). Small, standalone,
no `generate-timeline.sh` changes — this is what makes #86 and #87 buildable without both
reinventing the same capability.

### #86 — rolling Open + collapsed History sections (L)

Function-level redesign of `scripts/generate-timeline.sh`:

- Keep `dedup_items()` (12-28) — still needed for the History-append path only.
- Keep `merge_activity_tsv()` (34-48) and `prepend_activity_embed()` (53-65) — SVG pipeline is
  orthogonal, unchanged.
- **Remove `append_section()` (70-82)**, replace with:
  - `write_open_section(file, open_items)` — full delete+rewrite between sentinel comments
    `<!-- open-section-start -->`/`<!-- open-section-end -->` (marker-based region replacement,
    same family as `prepend_activity_embed`'s single-point insertion but bounded on both ends).
    Always populated from the live unbounded `state=open` query (prep step above) — **never**
    derived from existing file contents.
  - `prepend_history_entry(file, run_date, closed_items)` — inserts a new
    `<details><summary>$run_date</summary>...</details>` block immediately after `## History`,
    **newest-first** (default decision, see handoff — a deliberate change from the old
    chronological-ascending log). Merges into an existing same-day block if present (mirrors old
    `append_section`'s same-day-header merge behavior).
  - `migrate_legacy_sections_to_history(file)` — one-time, idempotent (no-op if
    `<!-- open-section-start -->` already present). Mechanically wraps every existing
    `## YYYY-MM-DD` header as a `<details><summary>` block, in place, no API calls. Called
    unconditionally at the top of `main()`'s per-repo loop before any writes; `## Open` is then
    populated fresh in the same run by `write_open_section`.
- History day-bucketing stays on `RUN_DATE` (today), same convention `append_section` already
  used — no new date field needed from collectors.

**BATS additions** (`test_generate_timeline.bats`): open-only first run (no `## History` emitted);
state-transition open→history (seed Open, close item, assert moved); idempotent rewrite (run
twice, `## Open` unchanged); two same-day closures merge into one `<details>` block; migration
test (legacy fixture with bare `## YYYY-MM-DD` sections → converts to `<details>` + fresh
`## Open`).

**Risks:** doubles API calls per repo per run (windowed + unbounded query) — likely fine at this
project's scale, not blocking. Marker-bounded region rewrite is more failure-prone awk than
anything currently in the file — extra test coverage on malformed/missing-marker files warranted.

### #87 — cross-repo overview SVG + timelines/README.md index (M, assuming #86-prep lands first; L otherwise)

Sequencing reason, precisely: #87's open PR/issue counts should reuse the **same
`--state open` collector flag** #86-prep introduces, called per repo and counted — not parse
#86's rendered markdown (which would couple #87 to #86's markdown formatting, fragile).

- New `scripts/render-overview-svg.sh` (heatmap, per the #83 decision) — reads all
  `assets/*/*-activity.tsv` files (already populated by the existing per-repo TSV pipeline,
  `generate-timeline.sh:155-172`), one row per repo, columns = last N days, cell color =
  sequential intensity scale (GitHub contribution-graph-style green fits the existing palette
  mirroring). Reuses the shared style block extracted per the #83 decision.
- New `write_timelines_index()` function **in `generate-timeline.sh`** (a markdown table, not SVG
  — a full script is unwarranted, KISS). Full rewrite each run — same precedent as
  `merge_activity_tsv`, simplest of the three write patterns (no dedup/history concerns). Per
  repo: name/link, open PR count, open issue count, last-updated (`git log -1 --format=%cd --
  timelines/<owner>/<name>.md`, cheap and precise vs. always stamping today).
- Both called once, after the per-repo loop, at the bottom of `main()` — not per-repo.
- **Workflow change needed: none.** Verified `update-timeline.yml`'s `git add timelines/ assets/`
  is directory-level — new files are picked up automatically.

**BATS additions:** new `tests/unit/test_render_overview_svg.bats` (valid SVG structure, correct
row/column counts, color-scale bucket boundaries, empty-input placeholder, light/dark palette).
Extend `test_generate_timeline.bats` for `write_timelines_index()` (table row per repo, correct
counts, idempotent full-rewrite).

**Risk:** `timelines/README.md` should carry a one-line "auto-generated, not hand-maintained"
disclaimer at the top, since this workspace has its own README/AGENTS/CONTRIBUTING doc-hierarchy
convention that a generated file living at that path could be mistaken for.

**Confirmed NOT parallelizable with #86** — both touch `generate-timeline.sh`'s `main()` (#86
rewrites the per-repo write logic inside the loop; #87 adds calls at the very end) and #87
functionally depends on #86-prep's collector flag. Sequential: prep → #86 → #87.

---

## Cluster: Contributor intelligence (#110+#4, #108, #109 Tier 1)

Verification status going in: `action.yaml:40` already proves composite steps can read the
`github.*` context directly (no new input plumbing pattern needed). `github.repository_visibility`
itself is confirmed only via two secondary sources in this session, not GitHub's own context-table
docs directly (a WebFetch truncation artifact, likely, not evidence it doesn't exist) — **confirm
with a throwaway debug step before wiring the gate** (see watch-outs). Confirmed: existing
`permissions:` block (`contents:write, pull-requests:write, issues:read`) only scopes host-repo
access; it does not gate read-only `gh api` calls against arbitrary other repos/orgs/users, which
already ride the existing `TOKEN` input today via `collect-issues.sh`/`collect-prs.sh` — **no
`permissions:` changes needed.**

### #110 + #4 — contributor collection with privacy gate, built together (L)

**`action.yaml`** — new inputs, default `"false"`: `INCLUDE_CONTRIBUTORS`,
`INCLUDE_CONTRIBUTOR_PROFILE_DETAILS`. New env var in the "Generate timeline" step:
`INPUT_REPO_VISIBILITY: ${{ github.repository_visibility }}` (context value, not a user-facing
input).

**`scripts/common.sh`** — new `assert_contributor_gate()`, called once at the top of
`generate-timeline.sh`'s `main()`, before the repo loop:

```bash
assert_contributor_gate() {
    local any_flag="${INPUT_INCLUDE_CONTRIBUTORS:-false}"
    [[ "${INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS:-false}" == "true" ]] && any_flag=true
    [[ "${INPUT_INCLUDE_CONTRIBUTOR_TIMING:-false}" == "true" ]] && any_flag=true   # #108's flag, checked here too
    [[ "$any_flag" != "true" ]] && return 0
    if [[ "${INPUT_INCLUDE_CONTRIBUTORS:-false}" != "true" ]]; then
        echo "ERROR: INCLUDE_CONTRIBUTOR_PROFILE_DETAILS/TIMING requires INCLUDE_CONTRIBUTORS=true." >&2
        exit 1
    fi
    case "${INPUT_REPO_VISIBILITY:-}" in
        private|internal) return 0 ;;
        *)
            echo "ERROR: INCLUDE_CONTRIBUTORS=true requires the host repo to be private or internal. Detected: '${INPUT_REPO_VISIBILITY:-<unset>}'." >&2
            exit 1
            ;;
    esac
}
```

Fires on any of the three contributor flags, fails **closed** on unset/empty visibility (not
fail-open), treats `PROFILE_DETAILS`/`TIMING=true` with `CONTRIBUTORS=false` as a hard config error
(not a silent no-op).

**New `scripts/collect-contributor-events.sh`** (internal helper) — `<owner/repo> <since>`, emits
JSONL `{"login","type":"pr"|"issue"|"commit","timestamp"}`. Separate API calls from
`collect-prs.sh`/`collect-issues.sh` (doesn't touch their existing contract/tests). For commits:
`.author.login` (nullable, drop null rows) + `.commit.author.date` — **never** touch
`.commit.author.email` or `.commit.author.name`.

**New `scripts/collect-contributors.sh`** — `<owner/repo> <since> <days>`:

1. `.timeline-no-contributors` opt-out: `gh api repos/$REPO/contents/.timeline-no-contributors` —
   200 → skip entirely (and trigger removal path if a prior run had already emitted a block).
2. Tally `collect-contributor-events.sh` output by login → `window_events` count.
   `readonly CONTRIBUTOR_MIN_EVENTS=5` hardcoded, no input (a lowerable threshold weakens the
   policy floor — YAGNI, don't add the knob).
3. `gh api repos/$REPO/contributors` (lifetime list) used **only** for the aggregate
   `contribution_concentration` bucket (top-N share of total). Per-contributor rows come
   exclusively from the windowed tally in step 2.
4. Org metadata: `gh api orgs/$OWNER`, explicit jq field allowlist (`login, public_repos,
   created_at, html_url`) — never pass the object through raw (it also returns `email`,
   `location`, `blog`, `twitter_username` by default).
5. Per contributor with `window_events >= 5` **and** `INCLUDE_CONTRIBUTOR_PROFILE_DETAILS=true`:
   `gh api users/$login`, jq allowlist `location, company, bio` only — the filter itself never
   selects `.email`, so leakage is structurally impossible, not just redacted after the fact.
6. Output `assets/<owner>/<repo>-contributors.json`:
   ```json
   {
     "repo": "owner/repo", "scraped_at": "...", "window_days": 7, "since": "...",
     "source_urls": ["...contributors","...orgs/owner","...users/login1"],
     "total_window_events": 42,
     "contribution_concentration": {"top_contributor_share": 0.35, "top_3_share": 0.68},
     "org": {"login": "owner", "public_repos": 12, "created_at": "...", "html_url": "..."},
     "contributors": [
       {"login":"alice","html_url":"...","window_events":9,"tier":"enriched",
        "profile":{"location":"Berlin, Germany","company":"Acme","_source":"self-reported GitHub profile field, not verified"}},
       {"login":"bob","html_url":"...","window_events":2,"tier":"login-only"}
     ]
   }
   ```

**Correction vs. a naive first pass — req 9 (re-derive fresh, never carry forward) breaks this
repo's append-only MD model.** Contributors must be **replaced** each run, matching the
`prepend_activity_embed` marker pattern. New `replace_contributors_block(file, content)` in
`generate-timeline.sh` strips any existing `<!-- contributors-begin -->...<!-- contributors-end -->`
block and appends the fresh one (or nothing, removing the block entirely). The
`-contributors.json` asset is **overwritten**, not merged, each run. If `INCLUDE_CONTRIBUTORS`
flips to `false` or `.timeline-no-contributors` appears, the run must **delete** the JSON and
strip the MD block (see watch-outs) — needs its own BATS test.

**Right-to-erasure (req 10) — document in `CONTRIBUTING.md`:** (a) re-derivation means a
contributor clearing their GitHub profile fields stops future runs from emitting them; (b)
`.timeline-no-contributors` stops future inclusion; (c) **state plainly, don't paper over**:
already-committed MD/JSON in git history is not erasable by a future run — removing it requires a
manual maintainer commit or history rewrite.

**BATS test plan** (new `tests/unit/test_collect_contributors.bats` + gate tests folded into
`test_infra_files.bats`/`test_generate_timeline.bats`):
- Gate exits 1 on `CONTRIBUTORS=true` + `visibility=public`; exits 1 on **unset** visibility
  (fail closed); passes on private/internal; no-op when all three flags false; exits 1 when
  `PROFILE_DETAILS=true` but `CONTRIBUTORS=false`.
- Aggregation threshold: fixture with logins at 3/5/9 window events → `tier` is `login-only` below
  5, `enriched` at/above.
- Email suppression: fixture with `.commit.author.email` populated + one `.author: null` commit →
  output never contains the string `"email"`; null-author commit doesn't inflate any count.
- `.timeline-no-contributors`: mock 200 → empty contributor set, exit 0; mock 404 → normal
  collection.
- **Removal path**: seed an MD with an existing contributors block + JSON file, run with
  `CONTRIBUTORS=false` → assert both removed.
- `grep -q 'github.repository_visibility' action.yaml`; one test per new input asserting
  `default: "false"`.

**Risks:** org-metadata call assumes `owner` is an org; for a personal account `orgs/{owner}`
404s — handle as best-effort/absent, not fatal.

**File scope:** `action.yaml`, `scripts/common.sh`, `scripts/generate-timeline.sh` (pre-loop gate
call + per-repo dispatch + `replace_contributors_block`), new `scripts/collect-contributors.sh` +
`collect-contributor-events.sh`, new test file(s) + 3 new fixtures
(`gh-mock-contributors.json`, `gh-mock-user-profile.json`, `gh-mock-org.json`),
`README.md`/`CONTRIBUTING.md`.

### #108 — contributor timing (S/M, depends on #4 landing)

New `INCLUDE_CONTRIBUTOR_TIMING` input (default `false`, already wired into
`assert_contributor_gate` above). New `scripts/collect-contributor-timing.sh` reuses
`collect-contributor-events.sh`'s JSONL (no new API endpoints, matches the issue's own
constraint), for the same `tier=="enriched"` cohort (≥5 window events — consistent gating):
modal UTC hour, weekend %, off-hours % (default convention: **09:00–17:00 UTC = work hours**,
everything else off-hours), longest consecutive-day streak, first/last activity **within the
window** (not lifetime, consistent with req 9). Merged into the same JSON under a `timing` key via
`jq -s` keyed on login, with a mandatory `_note` disclaimer (req 6 — this field is genuinely
inferred, unlike #4's self-reported location/company). MD gets a trailing fragment, e.g.
`(peak ~14:00 UTC, 11% weekend)`.

**BATS:** fixture with known timestamps per login → assert modal hour/weekend%/streak/first-last
match hand-computed values; assert `_note` present on every `timing` object; assert sub-threshold
logins get no `timing` key.

**File scope:** new `scripts/collect-contributor-timing.sh`, `action.yaml` (one input),
`generate-timeline.sh` (conditional call + merge), test file. **No overlap with #109.**

### #109 Tier 1 — repo discovery + lifespan timeline (M)

**Privacy-gate assessment (recommendation to confirm, not settled):** Tier 1 touches only
repo-level metadata (name, description, language, created_at, pushed_at, archived, fork,
stargazers_count, topics) — zero logins, zero profiles, zero commit-author data. None of #110's
ten requirements' vocabulary ("contributor-identifying data", "aggregated public profile data")
applies on a plain reading. The maintainer's privacy-prerequisite comment applied the blanket to
issue #109 as a whole, not tier-by-tier, so this is flagged as an explicit owner decision point
(see Open decisions), with **default: ship Tier 1 without the gate.**

**Design:** reuse the existing comma-separated `REPOS` convention (an entry with no `/` = an
account) rather than adding `INPUT_ACCOUNT`. In `generate-timeline.sh`'s existing loop, add an
**early-exit branch at the top**, not a wrap of the whole ~75-line body (wrapping would re-indent
everything and guarantee a merge conflict with #4's insertion into that same body):

```bash
for repo in "${REPO_LIST[@]}"; do
    repo=$(echo "$repo" | xargs)
    if [[ "$repo" != */* ]]; then
        collect_account "$repo"
        continue
    fi
    # ... existing per-repo body, untouched ...
```

New `scripts/collect-account-repos.sh <account>`:
`gh api --paginate "users/${account}/repos?per_page=100" --jq 'select(.fork==false and .archived==false) | {name,description,language,created_at,pushed_at,archived,fork,stargazers_count,topics}'`.
**Verify before implementing:** whether `GET /users/{login}/repos` already handles org logins
correctly too — if so, no shared org/user-detection helper is needed; keep each PR's own minimal
check independent rather than sharing a `common.sh` helper now (AHA — this repo's own
`core-principles.md` states: don't extract a shared abstraction until a second stable caller
proves the pattern).

New `scripts/render-account-gantt-svg.sh` (**not** an extension of `render-activity-svg.sh` — that
renderer is hard-coded for a 7-event stacked bar with a fixed legend; Gantt is a different enough
shape that forcing it in would be the wrong abstraction). Per the #83 decision, this should
actually emit a **mermaid `gantt` block**, not hand-rolled SVG — reconcile this file's role
accordingly when implementing (render a fenced `​```mermaid` block into `_account.md` rather than
generating `_account-repos.svg`). Outputs `timelines/<account>/_account.md`.

**BATS:** mock `gh` PATH-shim per `test_collect_activity_counts.bats`'s pattern — fixture repos
JSON → assert forks/archived filtered, all 7 fields present, pagination flag set. Renderer: assert
valid mermaid gantt block emitted for empty and non-empty input.

**File scope:** `action.yaml` (no new input, auto-detect route), `generate-timeline.sh` (3-line
early-exit + new `collect_account` function), new `scripts/collect-account-repos.sh` +
`render-account-gantt-svg.sh`, test file(s).

**Parallel-worktree assessment vs. #110+#4:** both touch `action.yaml` (additive rows, trivial
merge) and `generate-timeline.sh`'s `main()` in **disjoint regions** (#4: pre-loop gate call +
inside the existing per-repo body; #109: 3 lines at the very top of the loop before that body
runs). **Parallel-safe with a trivial rebase, not zero-conflict.** No `common.sh` overlap if the
org/user-detection helper stays independent per the recommendation above.

---

## Parallel execution groups (worktrees)

Two waves. Everything in Wave A is mutually parallel-safe (minor, mechanical rebase risk noted
inline — not semantic conflicts). Wave B has two independent chains that can run in parallel with
each other, but each chain is internally sequential.

**Wave A — start all of these as separate worktrees immediately:**

| Row | Worktree? | Touches |
|---|---|---|
| T0-A, T0-B (merge dependabot PRs #214, #226) | No — just `gh pr merge` | none (already-open PRs) |
| W1-1 (#164 README canon) | Yes | `README.md`, `docs/inputs.md` (new), `docs/pipeline.md` (new), `pyproject.toml:29-32`, `tests/unit/test_infra_files.bats` (new sync test) |
| W1-2 (#174 CI workflows) | Yes — **first step inside the worktree is reading the 3 upstream files**, not writing YAML | `.github/workflows/{bump-version,tag-release,publish-release}.yml` (new), removes `bump-and-release.yaml` + `delete_branch_pr_tag.sh`, `tests/unit/test_infra_files.bats` |
| W1-3 (#86-prep: `--state open` flag) | Yes | `scripts/collect-issues.sh`, `scripts/collect-prs.sh` only — **does not touch `generate-timeline.sh`** |
| W1-4 (#83 decision) | No — already resolved above; just post the decision as a comment on issue #83 | none |
| W3-1 (#110+#4 contributor bundle) | Yes | `action.yaml`, `scripts/common.sh`, `scripts/generate-timeline.sh` (pre-loop gate + per-repo dispatch), new collector scripts, tests, `CONTRIBUTING.md` |
| W3-2 (#109 Tier 1) | Yes | `action.yaml`, `scripts/generate-timeline.sh` (loop-top early-exit only), new scripts, tests |

Minor rebase points within Wave A (mechanical, not semantic — resolve whoever merges second):
`tests/unit/test_infra_files.bats` (W1-1 and W1-2 both add tests there); `action.yaml` and
`generate-timeline.sh` (W3-1 and W3-2 both touch, disjoint regions).

**Wave B — start only after the named Wave A row is merged to `main`:**

| Row | Worktree? | Depends on | Touches |
|---|---|---|---|
| W2-1 (#86 full MD restructure) | Yes | W1-3 merged | `scripts/generate-timeline.sh` (rewrites per-repo write logic inside the loop body), `tests/unit/test_generate_timeline.bats` |
| W2-2 (#87 overview + index) | Yes | W2-1 merged (**sequential after W2-1, not parallel with it**) | new `scripts/render-overview-svg.sh`, new `write_timelines_index()` in `generate-timeline.sh` |
| W4-1 (#108 timing) | Yes | W3-1 merged | new `scripts/collect-contributor-timing.sh`, `action.yaml` (one input), `generate-timeline.sh` (conditional call) |

The rendering chain (W2-1 → W2-2) and the contributor chain (W4-1) have no file overlap with each
other and can run concurrently once their respective Wave A prerequisites land.

**Deferred, not in this arc:** #109 Tier 2 (theme/goal inference, opt-in LLM) and Tier 3 (external
contributions/events) — file as separate follow-up issues once Tier 1 ships, per the issue's own
suggestion. Do not build speculatively ahead of Tier 1 landing.

---

## Remaining-work table (single source of truth — one row per item)

| ID | Item | Gate | Wave | Depends on | Status |
|---|---|---|---|---|---|
| T0-A | Merge dependabot PR #214 (codeql-action 4→4.37.4) | done | A | — | **merged directly** |
| T0-B | Merge dependabot PR #226 (bump-my-version 1.4.1→1.5.2) | done | A | — | **auto-closed by GitHub** once #233 deleted its target file |
| W1-1 | #164 — README doc-structure canon | done | A | — | **merged: [#230](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/230)** |
| W1-2 | #174 — adopt qte77/.github reusable release workflows | done | A | — | **merged: [#233](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/233)** |
| W1-3 | #86-prep — `--state open` flag on collect-issues.sh/collect-prs.sh | done | A | — | **merged: [#231](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/231)** |
| W1-4 | #83 — renderer decision record | done | A | — | **posted as [issue comment](https://github.com/qte77/gha-arbitrary-repo-timeline/issues/83#issuecomment-5724391792)** |
| W3-1 | #110 + #4 — contributor collection + privacy gate | done (`repository_visibility` still needs a live smoke test before production trust) | A | — | **merged: [#234](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/234)** |
| W3-2 | #109 Tier 1 — account discovery + lifespan Gantt | done (gate-scope default still pending maintainer confirmation) | A | — | **merged: [#232](https://github.com/qte77/gha-arbitrary-repo-timeline/pull/232)** |
| W2-1 | #86 — rolling Open + collapsed History sections | agent | B | W1-3 merged ✅ | **ready to start** |
| W2-2 | #87 — cross-repo overview SVG + timelines/README.md index | agent | B | W2-1 merged | not started |
| W4-1 | #108 — contributor timing analysis | agent | B | W3-1 merged ✅ | **ready to start** |
| — | #109 Tier 2/3 | owner (file as follow-up issues) | deferred | W3-2 | not started in this arc |

---

## Open decisions requiring owner sign-off

1. **#109 Tier 1 privacy-gate applicability** (W3-2). Recommendation: ships without #110's gate
   (zero person-level fields surfaced). This is the one place the maintainer's own comment
   conflicts with a plain reading of the requirements — confirm before starting W3-2, or accept
   the default and proceed.
2. **#174's floating-`v0`-tag and token/trigger-chain questions** are agent-resolvable by reading
   the upstream files — not truly an owner decision, but flagged since if the upstream workflows
   turn out to lack any floating-tag mechanism, adding a custom step is a design choice worth a
   one-line owner FYI before merging, not a silent addition.
3. Everything else in "Owner-gates in this arc" (handoff section) — proceed on the stated default
   unless overridden before that row starts.
