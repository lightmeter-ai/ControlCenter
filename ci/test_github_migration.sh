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
  grep -F "$2" "$1" >/dev/null || fail "$1 does not contain: $2"
}

assert_not_contains() {
  if grep -F "$2" "$1" >/dev/null; then
    fail "$1 still contains: $2"
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
assert_contains ci/migrate_gitlab_releases.sh "SOURCE_GITLAB_PROJECT_ID"

assert_contains ci/Dockerfile "https://github.com/lightmeter-ai/ControlCenter"
# These are literal Dockerfile variables.
# shellcheck disable=SC2016
assert_contains ci/Dockerfile 'GIT_COMMIT="$LIGHTMETER_COMMIT"'
# These are literal Dockerfile variables.
# shellcheck disable=SC2016
assert_contains ci/Dockerfile 'GIT_BRANCH="$LIGHTMETER_REF"'
assert_contains README.md "github.com/lightmeter-ai/ControlCenter/actions"
assert_contains RELEASING.md "GitHub"
assert_contains .github/workflows/migrate-images.yml "packages: write"

# Version tags remain release/<VERSION>, preserving the public tag contract.
assert_contains .github/workflows/release.yml "release/**"
assert_contains ci/release_on_github.sh "release/"

printf '%s\n' 'PASS: GitHub migration contract is satisfied'
