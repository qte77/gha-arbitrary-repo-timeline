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

@test "issue template directory exists" {
    skip "not implemented"
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
