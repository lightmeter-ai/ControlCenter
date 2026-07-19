#!/bin/sh

set -eu

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing $1"
}

assert_contains() {
  grep -F -- "$2" "$1" >/dev/null || fail "$1 does not contain: $2"
}

assert_not_contains() {
  if grep -F -- "$2" "$1" >/dev/null; then
    fail "$1 still contains: $2"
  fi
}

assert_step_blocking() {
  step_block=$(sed -n "/- name: $2/,+3p" "$1")
  if printf '%s\n' "$step_block" | grep -F 'continue-on-error: true' >/dev/null; then
    fail "$1 leaves the $2 step non-blocking"
  fi
}

assert_file .github/workflows/ci.yml
assert_file .github/workflows/security.yml
assert_file .github/workflows/release.yml
assert_file .github/workflows/nightly.yml
assert_file .github/workflows/migrate-images.yml
assert_file docs/GITHUB_MIGRATION.md

# Every pull request must exercise the migration guard; path-filtered triggers
# let CI disappear precisely when workflow or release files change.
assert_contains .github/workflows/ci.yml "pull_request:"
assert_contains .github/workflows/ci.yml "migration-guard"
assert_contains .github/workflows/ci.yml "acceptance:"
assert_not_contains .github/workflows/ci.yml "paths-ignore:"
assert_not_contains .github/workflows/ci.yml "paths:"

# Default workflow permissions must be read-only. Publishing workflows may
# elevate only the permissions they need at workflow or job scope.
assert_contains .github/workflows/ci.yml "contents: read"
assert_contains .github/workflows/security.yml "contents: read"
assert_contains .github/workflows/release.yml "packages: write"
assert_contains .github/workflows/release.yml "contents: write"

# GitLab must be a zero-writer compatibility/archive surface after cutover.
assert_contains .gitlab-ci.yml "when: never"
assert_not_contains .gitlab-ci.yml "publish-docker-image"
assert_not_contains .gitlab-ci.yml "publish-release"

# The runnable build and release path may not depend on GitLab-hosted images,
# packages, job tokens, or registry variables.
for migration_file in \
  .github/workflows/ci.yml \
  .github/workflows/security.yml \
  .github/workflows/release.yml \
  .github/workflows/nightly.yml \
  .github/workflows/migrate-images.yml \
  ci/Dockerfile \
  ci/publish_docker_image.sh \
  ci/release_on_github.sh
do
  assert_file "$migration_file"
  assert_not_contains "$migration_file" "registry.gitlab.com"
  assert_not_contains "$migration_file" "CI_JOB_TOKEN"
  assert_not_contains "$migration_file" "CI_REGISTRY"
done

# One-shot, manually invoked migration utilities are the only files allowed to
# read historical GitLab release and registry data.
assert_contains ci/migrate_gitlab_images.sh "registry.gitlab.com/lightmeter/controlcenter"
# These are literal shell variables in the migration script.
# shellcheck disable=SC2016
assert_contains ci/migrate_gitlab_images.sh 'crane ls "$source_image" > "$source_tags"'
# shellcheck disable=SC2016
assert_contains ci/migrate_gitlab_images.sh 'done < "$sorted_source_tags"'
assert_contains ci/migrate_gitlab_releases.sh "SOURCE_GITLAB_PROJECT_ID"
assert_contains ci/migrate_gitlab_releases.sh '--paginate'
# These are literal shell variables in the release migration script.
# shellcheck disable=SC2016
assert_contains ci/migrate_gitlab_releases.sh 'done < "$sorted_releases"'
assert_contains tools/go_test.sh '#!/usr/bin/env bash'
assert_contains tools/update_cli_docs.sh '| expand -t 8 > cli_usage.md'
assert_contains Makefile 'BUILD_DEPENDENCIES = go gcc ragel npm bash'
# This is a literal Make variable reference.
# shellcheck disable=SC2016
assert_contains Makefile 'frontend_root: $(FRONTEND_NODE_MODULES)'

assert_contains ci/Dockerfile "https://github.com/lightmeter-ai/ControlCenter"
# These are literal Dockerfile variables.
# shellcheck disable=SC2016
assert_contains ci/Dockerfile 'GIT_COMMIT="$LIGHTMETER_COMMIT"'
# These are literal Dockerfile variables.
# shellcheck disable=SC2016
assert_contains ci/Dockerfile 'GIT_BRANCH="$LIGHTMETER_REF"'
assert_contains ci/Dockerfile '# syntax=docker/dockerfile:1'
assert_contains ci/Dockerfile 'node:16.20.2-alpine3.18@sha256:a1f9d027912b58a7c75be7716c97cfbc6d3099f3a97ed84aa490be9dee20e787'
assert_contains ci/Dockerfile "    bash \\"
assert_not_contains ci/Dockerfile 'NODE_OPTIONS=--openssl-legacy-provider'
# This literal label must follow the actual source ref for both releases and nightlies.
# shellcheck disable=SC2016
assert_contains ci/Dockerfile 'blob/${LIGHTMETER_REF}/README.md'
assert_contains .github/workflows/ci.yml 'docker buildx build'
assert_contains .github/workflows/ci.yml '--load'
assert_contains .github/workflows/release.yml 'docker buildx build'
assert_contains .github/workflows/release.yml '--load'
assert_contains .github/workflows/release.yml "group: release-\${{ github.event_name == 'workflow_dispatch' && inputs.tag || github.ref_name }}"
# These are literal variables in the workflow and publication script.
# shellcheck disable=SC2016
assert_contains .github/workflows/release.yml 'release "${RELEASE_TAG}" controlcenter-release:local'
# shellcheck disable=SC2016
assert_contains ci/publish_docker_image.sh 'docker tag "$local_image" "$target_ref"'
assert_contains .github/workflows/security.yml 'golangci-lint-1.59.1-linux-amd64.tar.gz'
assert_contains .github/workflows/security.yml 'c30696f1292cff8778a495400745f0f9c0406a3f38d8bb12cef48d599f6c7791'
assert_contains .github/workflows/security.yml 'golangci-output-checkstyle.xml'
assert_contains .github/workflows/security.yml "vars.SONAR_HOST_URL || 'https://sonarcloud.io'"
assert_not_contains .github/workflows/security.yml 'golang/govulncheck-action@'
assert_contains .github/workflows/security.yml 'golang.org/x/vuln/cmd/govulncheck@v1.0.4'
assert_contains .github/workflows/security.yml 'set -o pipefail'
# This is a literal Bash PIPESTATUS reference in the workflow.
# shellcheck disable=SC2016
assert_contains .github/workflows/security.yml 'govuln_status=${PIPESTATUS[0]}'
assert_contains .github/workflows/security.yml 'npm-audit.json'
assert_contains .github/workflows/security.yml 'report.metadata.vulnerabilities'
assert_contains .github/workflows/security.yml 'npm audit did not produce a valid vulnerability report'
assert_contains .github/workflows/ci.yml 'npm run lint -- src'
assert_step_blocking .github/workflows/ci.yml 'Lint frontend'
assert_step_blocking .github/workflows/ci.yml 'Verify generated CLI documentation'
assert_contains .github/workflows/ci.yml 'node-version: 18.20.8'
assert_contains .github/workflows/security.yml 'id: sonar-auth'
assert_contains .github/workflows/security.yml "steps.sonar-auth.outputs.enabled == 'true'"
if sed -n '/^  sonarcloud:/,/^  license-compliance:/p' .github/workflows/security.yml \
  | grep -F 'continue-on-error: true' >/dev/null; then
  fail '.github/workflows/security.yml leaves the SonarCloud job non-blocking'
fi
assert_contains .reuse/dep5 'Files: .github/workflows/*'
assert_contains README.md "github.com/lightmeter-ai/ControlCenter/actions"
assert_contains RELEASING.md "GitHub"
assert_contains .github/workflows/migrate-images.yml "packages: write"

# Version tags remain release/<VERSION>, preserving the public tag contract.
assert_contains .github/workflows/release.yml "release/**"
assert_contains ci/release_on_github.sh "release/"

sh ci/test_publish_docker_image.sh

printf '%s\n' 'PASS: GitHub migration contract is satisfied'
