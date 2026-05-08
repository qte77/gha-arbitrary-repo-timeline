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

@test "bump-and-release workflow exists with bump-my-version" {
    [ -f .github/workflows/bump-and-release.yaml ]
    grep -q 'bump-my-version' .github/workflows/bump-and-release.yaml
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

@test "cleanup script exists and is executable" {
    [ -x .github/scripts/delete_branch_pr_tag.sh ]
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
