#!/bin/sh

set -eu

task_tmp=$(mktemp -d)
cleanup() {
  find "$task_tmp" -mindepth 1 -delete
  rmdir "$task_tmp"
}
trap cleanup EXIT HUP INT TERM

export FAKE_DOCKER_LOG="$task_tmp/docker.log"
PATH="$(pwd)/ci/testdata:$PATH"
export PATH

PUSH_LATEST=true sh ci/publish_docker_image.sh \
  2.0.0 release release/2.0.0 controlcenter-release:local

test "$(grep -c '^tag controlcenter-release:local ' "$FAKE_DOCKER_LOG")" -eq 4
test "$(grep -c '^push ' "$FAKE_DOCKER_LOG")" -eq 4
if grep -F 'buildx build' "$FAKE_DOCKER_LOG" >/dev/null; then
  echo 'release publication rebuilt the validated image' >&2
  exit 1
fi

grep -F 'tag controlcenter-release:local docker.io/lightmeter/controlcenter:2.0.0' \
  "$FAKE_DOCKER_LOG" >/dev/null
grep -F 'tag controlcenter-release:local ghcr.io/lightmeter-ai/controlcenter:latest' \
  "$FAKE_DOCKER_LOG" >/dev/null

: > "$FAKE_DOCKER_LOG"
sh ci/publish_docker_image.sh \
  2.0.0 release release/2.0.0 controlcenter-release:local

test "$(grep -c '^tag controlcenter-release:local ' "$FAKE_DOCKER_LOG")" -eq 2
test "$(grep -c '^push ' "$FAKE_DOCKER_LOG")" -eq 2
if grep -F ':latest' "$FAKE_DOCKER_LOG" >/dev/null; then
  echo 'manual release publication overwrote a latest tag by default' >&2
  exit 1
fi

: > "$FAKE_DOCKER_LOG"
sh ci/publish_docker_image.sh nightly-master nightly master
test "$(grep -c '^buildx build ' "$FAKE_DOCKER_LOG")" -eq 1

if sh ci/publish_docker_image.sh 2.0.0 release release/2.0.0 2>/dev/null; then
  echo 'release publication accepted a missing validated image' >&2
  exit 1
fi

if PUSH_LATEST=sometimes sh ci/publish_docker_image.sh \
  2.0.0 release release/2.0.0 controlcenter-release:local 2>/dev/null; then
  echo 'release publication accepted an invalid PUSH_LATEST value' >&2
  exit 1
fi

printf '%s\n' 'PASS: Docker publication reuses the validated release image'
