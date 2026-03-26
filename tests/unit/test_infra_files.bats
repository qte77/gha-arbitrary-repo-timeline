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
    [ -d .github/ISSUE_TEMPLATE ]
}

@test "PR template exists" {
    [ -f .github/pull_request_template.md ]
}

@test "LICENSE exists with MIT" {
    [ -f LICENSE ]
    grep -q 'MIT' LICENSE
}

@test "update-timeline workflow has a commit step" {
    grep -q 'git/blobs\|Commit.*changed' .github/workflows/update-timeline.yml
}

@test "update-timeline workflow has REPOS fallback" {
    grep -q '||' .github/workflows/update-timeline.yml
}
