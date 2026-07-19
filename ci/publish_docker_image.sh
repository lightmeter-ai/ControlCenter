#!/bin/sh

set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <image-tag> <release|nightly> <source-ref>" >&2
  exit 2
fi

image_tag=$1
publication_kind=$2
source_ref=$3

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

case "$source_ref" in
  ''|*[!A-Za-z0-9._/-]*)
    echo "invalid source ref: $source_ref" >&2
    exit 2
    ;;
esac

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

if [ "$publication_kind" = release ]; then
  set -- "$@" \
    --tag docker.io/lightmeter/controlcenter:latest \
    --tag ghcr.io/lightmeter-ai/controlcenter:latest
fi

docker buildx build "$@" .
