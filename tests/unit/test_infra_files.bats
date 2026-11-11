#!/usr/bin/env bats
# TDD RED: Infrastructure file checks for gha-arbitrary-repo-timeline

@test "action.yaml exists and has required branding fields" {
    [ -f action.yaml ]
    grep -q 'icon:' action.yaml
    grep -q 'color:' action.yaml
}

@test "action.yaml has repos input" {
    grep -qi 'repos:' action.yaml
}

@test "action.yaml has output_file input" {
    grep -qi 'output_file:' action.yaml
}

@test "action.yaml has token input with empty default" {
    grep -q 'TOKEN:' action.yaml
    grep -q "default: ''" action.yaml || grep -q 'default: ""' action.yaml
}

@test "scripts/collect-issues.sh exists and is executable" {
    [ -x scripts/collect-issues.sh ]
}

@test "scripts/collect-prs.sh exists and is executable" {
    [ -x scripts/collect-prs.sh ]
}

@test "scripts/generate-timeline.sh exists and is executable" {
    [ -x scripts/generate-timeline.sh ]
}

@test "scripts/common.sh exists" {
    [ -f scripts/common.sh ]
}

@test "dependabot.yml covers github-actions ecosystem" {
    [ -f .github/dependabot.yml ]
    grep -q 'github-actions' .github/dependabot.yml
}

@test "bump-and-release workflow removed in favor of reusable release pipeline" {
    [ ! -f .github/workflows/bump-and-release.yaml ]
}

@test "bump-version workflow calls the qte77/.github reusable workflow, SHA-pinned" {
    [ -f .github/workflows/bump-version.yml ]
    grep -qE 'uses: qte77/\.github/\.github/workflows/bump-version\.yml@[0-9a-f]{40}' .github/workflows/bump-version.yml
    grep -q 'collect_scriv: false' .github/workflows/bump-version.yml
}

@test "tag-release workflow calls the qte77/.github reusable workflow, SHA-pinned, and is named for workflow_run matching" {
    [ -f .github/workflows/tag-release.yml ]
    grep -qE 'uses: qte77/\.github/\.github/workflows/tag-release\.yml@[0-9a-f]{40}' .github/workflows/tag-release.yml
    grep -q '^name: Tag Release$' .github/workflows/tag-release.yml
}

@test "publish-release workflow calls the qte77/.github reusable workflow, SHA-pinned, triggered via workflow_run on Tag Release" {
    [ -f .github/workflows/publish-release.yml ]
    grep -qE 'uses: qte77/\.github/\.github/workflows/publish-release\.yml@[0-9a-f]{40}' .github/workflows/publish-release.yml
    grep -q 'workflow_run' .github/workflows/publish-release.yml
    grep -q 'Tag Release' .github/workflows/publish-release.yml
}

@test "publish-release workflow moves the floating major-version tag after publishing" {
    grep -q 'refs/tags/' .github/workflows/publish-release.yml
    grep -q 'force=true' .github/workflows/publish-release.yml
}

@test "all qte77/.github reusable-workflow callers share one pin (no stale-commit drift)" {
    [ -f .github/workflows/lint-md-links.yml ]
    pins=$(grep -ohE 'uses: qte77/\.github/\.github/workflows/[a-z-]+\.yml@[0-9a-f]{40}' .github/workflows/*.yml |
        sed 's/.*@//' | sort -u)
    [ "$(grep -ohE 'uses: qte77/\.github/' .github/workflows/*.yml | wc -l)" -eq 4 ]
    [ "$(printf '%s\n' "$pins" | wc -l)" -eq 1 ]
}

@test "codeql workflow exists with workflow_dispatch" {
    [ -f .github/workflows/codeql.yaml ]
    grep -q 'workflow_dispatch' .github/workflows/codeql.yaml
}

@test "test workflow runs bats" {
    [ -f .github/workflows/test.yml ]
    grep -q 'bats' .github/workflows/test.yml
}

@test "update-timeline workflow exists with schedule trigger" {
    [ -f .github/workflows/update-timeline.yml ]
    grep -q 'schedule' .github/workflows/update-timeline.yml
}

@test "delete_branch_pr_tag.sh cleanup script removed (reusable workflows are abort-on-exists, never delete)" {
    [ ! -f .github/scripts/delete_branch_pr_tag.sh ]
}

@test "pyproject.toml has bumpversion config" {
    [ -f pyproject.toml ]
    grep -q 'tool.bumpversion' pyproject.toml
}

@test ".gitmessage exists with conventional commit hint" {
    [ -f .gitmessage ]
    grep -qi 'conventional\|feat\|fix\|chore' .gitmessage
}

@test "issue templates exist with required top-level keys" {
    [ -d .github/ISSUE_TEMPLATE ]
    [ -f .github/ISSUE_TEMPLATE/config.yml ]
    grep -q '^blank_issues_enabled: true' .github/ISSUE_TEMPLATE/config.yml
    for t in bug_report feature_request; do
        [ -f ".github/ISSUE_TEMPLATE/$t.yml" ]
        grep -q '^name:' ".github/ISSUE_TEMPLATE/$t.yml"
        grep -q '^description:' ".github/ISSUE_TEMPLATE/$t.yml"
        grep -q '^body:' ".github/ISSUE_TEMPLATE/$t.yml"
    done
}

@test "PR template exists" {
    [ -f .github/pull_request_template.md ]
}

@test "LICENSE exists with Apache-2.0" {
    [ -f LICENSE ]
    grep -q 'Apache License' LICENSE
}

@test "update-timeline workflow has a commit step" {
    grep -q 'git/blobs\|Commit.*changed' .github/workflows/update-timeline.yml
}

@test "update-timeline workflow has REPOS fallback" {
    grep -q '||' .github/workflows/update-timeline.yml
}

@test "workflow_dispatch accepts repos input" {
    grep -q 'repos:' .github/workflows/update-timeline.yml
}

@test "update-timeline workflow uses timelines/ path" {
    grep -q 'git add timelines/' .github/workflows/update-timeline.yml
}

@test "update-timeline workflow's API-built commit sets no author or committer (so GitHub signs it)" {
    grep -q 'gh api "repos/$REPO/git/commits"' .github/workflows/update-timeline.yml
    ! grep -q 'author:' .github/workflows/update-timeline.yml || false
    ! grep -q 'committer:' .github/workflows/update-timeline.yml || false
}

@test "update-timeline workflow runs weekly, not daily" {
    grep -qE "cron: '[0-9]+ [0-9]+ \* \* [0-6]'" .github/workflows/update-timeline.yml
    ! grep -q "cron: '0 6 \* \* \*'" .github/workflows/update-timeline.yml || false
    # Reason: a 14-day lookback on a weekly run backfills one missed run; dedup
    # by item ID and the per-day TSV override keep the overlap from duplicating.
    grep -q "DAYS: '14'" .github/workflows/update-timeline.yml
}

# Reason: an immediate merge right after PR creation hits the ruleset's required
# CodeFactor check before it reports (HTTP 405), so snapshot PRs piled up unmerged.
@test "update-timeline workflow queues auto-merge instead of merging immediately" {
    grep -q 'gh pr merge "$PR_NUM" --auto --squash' .github/workflows/update-timeline.yml
    ! grep -q 'pulls/$PR_NUM/merge' .github/workflows/update-timeline.yml || false
    # deleting the head branch right away would close the queued PR
    ! grep -q 'git/refs/heads/$BRANCH" -X DELETE' .github/workflows/update-timeline.yml || false
}

@test "update-timeline workflow closes superseded snapshot PRs" {
    grep -q 'startswith("auto-timeline-")' .github/workflows/update-timeline.yml
    grep -q 'gh pr close' .github/workflows/update-timeline.yml
}

# Reason: delete_branch_on_merge did not remove the branches of the auto-merges
# the workflow queues with GITHUB_TOKEN (#313/#314 left theirs), so each run
# sweeps leftover snapshot branches itself, before the "No changes" early exit.
@test "update-timeline workflow deletes leftover snapshot branches every run" {
    grep -q 'git/matching-refs/heads/auto-timeline-' .github/workflows/update-timeline.yml
    sweep=$(grep -n 'git/matching-refs/heads/auto-timeline-' .github/workflows/update-timeline.yml | cut -d: -f1)
    early_exit=$(grep -n 'echo "No changes"' .github/workflows/update-timeline.yml | cut -d: -f1)
    [ "$sweep" -lt "$early_exit" ]
}

# Reason: one blob POST per changed file (65 for 21 repos) runs into GitHub's
# secondary limit of 80 content-creating requests per minute; inline tree
# content creates every blob in the single "Create a tree" request.
@test "update-timeline workflow sends file contents inline in one tree request" {
    grep -q -- '--rawfile content "$file"' .github/workflows/update-timeline.yml
    ! grep -q 'git/blobs' .github/workflows/update-timeline.yml || false
}

@test "update-timeline workflow logs the remaining API budget on every run" {
    grep -q 'gh api rate_limit' .github/workflows/update-timeline.yml
}

# Reason: the 14-day lookback absorbs one missed weekly run but not two, so a
# failure must be visible: open (or comment on) one tracking issue.
@test "update-timeline workflow opens or updates an issue when a run fails" {
    grep -q 'if: failure()' .github/workflows/update-timeline.yml
    grep -q 'gh issue create' .github/workflows/update-timeline.yml
    grep -q 'gh issue comment' .github/workflows/update-timeline.yml
    grep -q '^  issues: write' .github/workflows/update-timeline.yml
}

@test "collect-issues.sh fetches all states" {
    grep -q 'state=all' scripts/collect-issues.sh
}

@test "collect-prs.sh fetches all states" {
    grep -q 'state=all' scripts/collect-prs.sh
}

@test "generate-timeline.sh supports git log" {
    grep -q 'INCLUDE_GIT_LOG' scripts/generate-timeline.sh
}

@test "generate-timeline.sh outputs to timelines/ directory" {
    grep -q 'timelines/' scripts/generate-timeline.sh
}

@test "Makefile exists with lint_sh recipe" {
    [ -f Makefile ]
    grep -qE '^lint_sh:' Makefile
    grep -q 'shellcheck' Makefile
}

@test "Makefile has format_sh recipe using shfmt" {
    grep -qE '^format_sh:' Makefile
    grep -q 'shfmt' Makefile
}

@test "Makefile has format_sh_check recipe (non-mutating)" {
    grep -qE '^format_sh_check:' Makefile
    grep -qE 'shfmt[^\n]+-d' Makefile
}

@test "Makefile has test recipe invoking bats" {
    grep -qE '^test:' Makefile
    grep -qE 'bats[[:space:]]' Makefile
}

@test "CONTRIBUTING.md exists and documents make lint_sh and format_sh" {
    [ -f CONTRIBUTING.md ]
    grep -q 'make lint_sh' CONTRIBUTING.md
    grep -q 'make format_sh' CONTRIBUTING.md
}

@test "Makefile has setup_shellcheck recipe" {
    grep -qE '^setup_shellcheck:' Makefile
    grep -qE 'shellcheck' Makefile
}

@test "Makefile has setup_shfmt recipe" {
    grep -qE '^setup_shfmt:' Makefile
    grep -q 'shfmt' Makefile
}

@test "scripts/render-activity-svg.sh exists and is executable" {
    [ -x scripts/render-activity-svg.sh ]
}

@test "scripts/collect-activity-counts.sh exists and is executable" {
    [ -x scripts/collect-activity-counts.sh ]
}

@test "tests/fixtures/activity-30d.tsv fixture exists" {
    [ -f tests/fixtures/activity-30d.tsv ]
}

@test "tests/fixtures/activity-history.tsv fixture exists" {
    [ -f tests/fixtures/activity-history.tsv ]
}

@test "generate-timeline.sh defines merge_activity_tsv function" {
    grep -qE '^merge_activity_tsv\(\)' scripts/generate-timeline.sh
}

@test "render-activity-svg.sh accepts --days flag" {
    grep -q '\-\-days' scripts/render-activity-svg.sh
}

@test "pyproject.toml README badge search string matches README.md verbatim" {
    local version search expected
    version=$(sed -nE 's/^current_version = "([^"]+)"$/\1/p' pyproject.toml)
    search=$(sed -n '/filename = "README.md"/,/^replace/p' pyproject.toml | sed -nE 's/^search = "(.*)"$/\1/p')
    [ -n "$version" ]
    [ -n "$search" ]
    expected="${search//\{current_version\}/$version}"
    grep -qF -- "$expected" README.md
}

# --- Contributor intelligence (#110 + #4) ---

@test "action.yaml has INCLUDE_CONTRIBUTORS input defaulting to false" {
    grep -A2 '^  INCLUDE_CONTRIBUTORS:' action.yaml | grep -q 'default: "false"'
}

@test "action.yaml has INCLUDE_CONTRIBUTOR_PROFILE_DETAILS input defaulting to false" {
    grep -A2 '^  INCLUDE_CONTRIBUTOR_PROFILE_DETAILS:' action.yaml | grep -q 'default: "false"'
}

@test "action.yaml has INCLUDE_CONTRIBUTOR_TIMING input defaulting to false" {
    grep -A2 '^  INCLUDE_CONTRIBUTOR_TIMING:' action.yaml | grep -q 'default: "false"'
}

@test "action.yaml wires INCLUDE_CONTRIBUTOR_TIMING input into the generate step env" {
    grep -qE '^\s+INPUT_INCLUDE_CONTRIBUTOR_TIMING: \$\{\{ inputs\.INCLUDE_CONTRIBUTOR_TIMING \}\}' action.yaml
}

@test "action.yaml wires INCLUDE_CONTRIBUTORS input into the generate step env" {
    grep -qE '^\s+INPUT_INCLUDE_CONTRIBUTORS: \$\{\{ inputs\.INCLUDE_CONTRIBUTORS \}\}' action.yaml
}

@test "action.yaml wires INCLUDE_CONTRIBUTOR_PROFILE_DETAILS input into the generate step env" {
    grep -qE '^\s+INPUT_INCLUDE_CONTRIBUTOR_PROFILE_DETAILS: \$\{\{ inputs\.INCLUDE_CONTRIBUTOR_PROFILE_DETAILS \}\}' action.yaml
}

@test "action.yaml exposes github.repository_visibility as INPUT_REPO_VISIBILITY" {
    grep -qE '^\s+INPUT_REPO_VISIBILITY: \$\{\{ github\.repository_visibility \}\}' action.yaml
}

@test "generate-timeline.sh calls assert_contributor_gate before the repo loop" {
    grep -q 'assert_contributor_gate' scripts/generate-timeline.sh
}

@test "scripts/collect-contributor-events.sh exists and is executable" {
    [ -x scripts/collect-contributor-events.sh ]
}

@test "scripts/collect-contributors.sh exists and is executable" {
    [ -x scripts/collect-contributors.sh ]
}

@test "CONTRIBUTING.md documents right to erasure" {
    grep -qi 'right to erasure\|right-to-erasure' CONTRIBUTING.md
}

@test "scripts/collect-account-repos.sh exists and is executable" {
    [ -x scripts/collect-account-repos.sh ]
}

@test "scripts/render-account-gantt.sh exists and is executable" {
    [ -x scripts/render-account-gantt.sh ]
}

@test "generate-timeline.sh dispatches account-only REPOS entries to collect_account" {
    grep -q 'collect_account' scripts/generate-timeline.sh
}

@test "action.yaml documents that a no-slash REPOS entry means an account" {
    grep -q 'account' action.yaml
}

# --- docs/inputs.md stays in sync with action.yaml (#164 doc created before
# #4/#109/#110 inputs landed; went stale) ---

@test "docs/inputs.md lists all 8 action.yaml input names as table rows" {
    [ -f docs/inputs.md ]
    grep -q '`REPOS`' docs/inputs.md
    grep -q '`OUTPUT_FILE`' docs/inputs.md
    grep -q '`TOKEN`' docs/inputs.md
    grep -q '`INCLUDE_GIT_LOG`' docs/inputs.md
    grep -q '`DAYS`' docs/inputs.md
    grep -q '`INCLUDE_CONTRIBUTORS`' docs/inputs.md
    grep -q '`INCLUDE_CONTRIBUTOR_PROFILE_DETAILS`' docs/inputs.md
    grep -q '`INCLUDE_CONTRIBUTOR_TIMING`' docs/inputs.md
}

# --- Dependabot grouping + CodeQL version ---

@test "dependabot.yml groups version updates separately from security updates" {
    grep -qE '^\s+applies-to:\s*version-updates' .github/dependabot.yml
    grep -qE '^\s+applies-to:\s*security-updates' .github/dependabot.yml
}

@test "dependabot.yml groups key exists under the github-actions update entry" {
    grep -qE '^\s+groups:' .github/dependabot.yml
}

@test "codeql workflow pins codeql-action init and analyze to the same SHA-pinned release" {
    grep -qE 'codeql-action/init@[0-9a-f]{40}\s+# v[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/codeql.yaml
    grep -qE 'codeql-action/analyze@[0-9a-f]{40}\s+# v[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/codeql.yaml
    init=$(grep -oE 'codeql-action/init@[0-9a-f]{40}' .github/workflows/codeql.yaml | cut -d@ -f2)
    analyze=$(grep -oE 'codeql-action/analyze@[0-9a-f]{40}' .github/workflows/codeql.yaml | cut -d@ -f2)
    [ "$init" = "$analyze" ]
}

# --- Repo requires sha_pinning_required=true: every `uses:` ref must be a
# full 40-hex-char commit SHA, or GitHub Actions refuses to start the run
# at all (startup_failure, zero jobs) regardless of trigger event. ---

@test "test.yml pins actions/checkout and actions/cache to a commit SHA" {
    grep -qE 'actions/checkout@[0-9a-f]{40}\s+# v7' .github/workflows/test.yml
    grep -qE 'actions/cache@[0-9a-f]{40}\s+# v6' .github/workflows/test.yml
}

@test "codeql.yaml pins actions/checkout to a commit SHA" {
    grep -qE 'actions/checkout@[0-9a-f]{40}\s+# v7' .github/workflows/codeql.yaml
}

@test "update-timeline.yml pins actions/checkout to a commit SHA" {
    grep -qE 'actions/checkout@[0-9a-f]{40}\s+# v7' .github/workflows/update-timeline.yml
}

@test "action.yaml pins actions/checkout to a commit SHA" {
    grep -qE 'actions/checkout@[0-9a-f]{40}\s+# v7' action.yaml
}

@test "publish-release.yml pins actions/checkout to a commit SHA" {
    grep -qE 'actions/checkout@[0-9a-f]{40}\s+# v7' .github/workflows/publish-release.yml
}

@test "no workflow file or action.yaml references an action by a bare version tag" {
    ! grep -rE "uses: actions/(checkout|cache)@v[0-9]" .github/workflows/ action.yaml || false
    ! grep -rE "uses: github/codeql-action/(init|analyze)@v[0-9]" .github/workflows/ || false
}

@test "CONTRIBUTING.md documents Git & CI conventions (branch protection, SHA pinning, allow-list)" {
    grep -q '^## Git & CI conventions$' CONTRIBUTING.md
    grep -q 'sha_pinning_required' CONTRIBUTING.md
}

# Reason: bash's errexit ignores a negated command, so a `! cmd` line that is
# not the last line of a test can never fail it (verified on Bats 1.13).
# Write `! cmd || false` instead.
@test "every negated assertion in the BATS suite can fail its test" {
    run grep -nE '^\s+! ' tests/unit/*.bats
    offenders=$(printf '%s\n' "$output" | grep -v '|| false$' || true)
    [ -z "$offenders" ] || { echo "$offenders"; false; }
}
