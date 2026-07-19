#!/bin/sh

set -eu

task_tmp=$(mktemp -d)
cleanup() {
  find "$task_tmp" -mindepth 1 -delete
  rmdir "$task_tmp"
}
trap cleanup EXIT HUP INT TERM

export FAKE_CRANE_LOG="$task_tmp/crane.log"
export FAKE_CRANE_STATE="$task_tmp/crane.state"
: > "$FAKE_CRANE_STATE"
export FAKE_CRANE_FAIL_GITHUB_DIGEST=true
PATH="$(pwd)/ci/testdata:$PATH"
export PATH

migration_status=0
APPLY_IMAGE_MIGRATION=true sh ci/migrate_gitlab_images.sh \
  > "$task_tmp/migration.out" 2> "$task_tmp/migration.err" \
  || migration_status=$?

test "$migration_status" -ne 0
if grep -F 'copy ' "$FAKE_CRANE_LOG" >/dev/null; then
  echo 'image migration copied over a tag after its digest lookup failed' >&2
  exit 1
fi

grep -F 'digest ghcr.io/lightmeter-ai/controlcenter:stable' \
  "$FAKE_CRANE_LOG" >/dev/null

: > "$FAKE_CRANE_LOG"
export FAKE_CRANE_FAIL_GITHUB_DIGEST=false
export FAKE_CRANE_GITHUB_ABSENT=true

APPLY_IMAGE_MIGRATION=true sh ci/migrate_gitlab_images.sh \
  > "$task_tmp/missing.out" 2> "$task_tmp/missing.err"

grep -F 'copy registry.gitlab.com/lightmeter/controlcenter:stable ghcr.io/lightmeter-ai/controlcenter:stable' \
  "$FAKE_CRANE_LOG" >/dev/null
grep -F 'COUNTS' "$task_tmp/missing.out" >/dev/null

: > "$FAKE_CRANE_LOG"
: > "$FAKE_CRANE_STATE"
export FAKE_CRANE_GITHUB_ABSENT=false
export FAKE_CRANE_GITHUB_LIST_DENIED=true

denied_status=0
APPLY_IMAGE_MIGRATION=true sh ci/migrate_gitlab_images.sh \
  > "$task_tmp/denied.out" 2> "$task_tmp/denied.err" \
  || denied_status=$?

test "$denied_status" -ne 0
if grep -F 'copy ' "$FAKE_CRANE_LOG" >/dev/null; then
  echo 'image migration copied after target inventory authentication failed' >&2
  exit 1
fi
grep -F 'failed to inventory target image before migration' \
  "$task_tmp/denied.err" >/dev/null

printf '%s\n' 'PASS: image migration copies only confirmed-missing tags and never overwrites on errors'
