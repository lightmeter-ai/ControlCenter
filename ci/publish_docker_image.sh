#!/bin/sh

set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "usage: $0 <image-tag> <release|nightly> <source-ref> [local-image]" >&2
  exit 2
fi

image_tag=$1
publication_kind=$2
source_ref=$3
local_image=${4:-}
push_latest=${PUSH_LATEST:-false}

case "$push_latest" in
  true|false) ;;
  *)
    echo "PUSH_LATEST must be true or false" >&2
    exit 2
    ;;
esac

case "$image_tag" in
  ''|*[!A-Za-z0-9._-]*)
    echo "invalid image tag: $image_tag" >&2
    exit 2
    ;;
esac

case "$publication_kind" in
  release|nightly) ;;
  *)
    echo "publication kind must be release or nightly" >&2
    exit 2
    ;;
esac

if [ "$publication_kind" = release ] && [ -z "$local_image" ]; then
  echo "release publication requires the already-validated local image" >&2
  exit 2
fi

if [ "$publication_kind" = nightly ] && [ -n "$local_image" ]; then
  echo "nightly publication does not accept a local image" >&2
  exit 2
fi

case "$source_ref" in
  ''|*[!A-Za-z0-9._/-]*)
    echo "invalid source ref: $source_ref" >&2
    exit 2
    ;;
esac

if [ -n "$local_image" ]; then
  docker image inspect "$local_image" >/dev/null
  local_image_id=$(docker image inspect --format '{{.Id}}' "$local_image")

  set -- \
    "docker.io/lightmeter/controlcenter:$image_tag" \
    "ghcr.io/lightmeter-ai/controlcenter:$image_tag"

  if [ "$push_latest" = true ]; then
    set -- \
      "$@" \
      docker.io/lightmeter/controlcenter:latest \
      ghcr.io/lightmeter-ai/controlcenter:latest
  fi

  for target_ref in "$@"; do
    docker tag "$local_image" "$target_ref"
    target_image_id=$(docker image inspect --format '{{.Id}}' "$target_ref")
    test "$target_image_id" = "$local_image_id"
    docker push "$target_ref"
    printf 'PUSHED\t%s\t%s\n' "$target_ref" "$local_image_id"
  done

  exit 0
fi

set -- \
  --file ci/Dockerfile \
  --platform linux/amd64 \
  --push \
  --build-arg "LIGHTMETER_VERSION=$(cat VERSION.txt)" \
  --build-arg "LIGHTMETER_COMMIT=$(git rev-parse HEAD)" \
  --build-arg "LIGHTMETER_REF=$source_ref" \
  --build-arg "IMAGE_TAG=$image_tag" \
  --tag "docker.io/lightmeter/controlcenter:$image_tag" \
  --tag "ghcr.io/lightmeter-ai/controlcenter:$image_tag"

docker buildx build "$@" .
