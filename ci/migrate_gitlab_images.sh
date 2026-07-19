#!/bin/sh

set -eu

source_image=${SOURCE_IMAGE:-registry.gitlab.com/lightmeter/controlcenter}
github_image=${GITHUB_IMAGE:-ghcr.io/lightmeter-ai/controlcenter}
dockerhub_image=${DOCKERHUB_IMAGE:-docker.io/lightmeter/controlcenter}
apply_migration=${APPLY_IMAGE_MIGRATION:-false}

case "$apply_migration" in
  true|false) ;;
  *)
    echo "APPLY_IMAGE_MIGRATION must be true or false" >&2
    exit 2
    ;;
esac

command -v crane >/dev/null || {
  echo "missing required command: crane" >&2
  exit 1
}

sync_tag() {
  target_image=$1
  image_tag=$2
  source_ref="$source_image:$image_tag"
  target_ref="$target_image:$image_tag"
  source_digest=$(crane digest "$source_ref")

  if target_digest=$(crane digest "$target_ref" 2>/dev/null); then
    if [ "$target_digest" != "$source_digest" ]; then
      printf 'DIVERGED\t%s\tsource=%s target=%s\n' \
        "$target_ref" "$source_digest" "$target_digest" >&2
      return 1
    fi

    printf 'MATCH\t%s\t%s\n' "$target_ref" "$source_digest"
    return
  fi

  if [ "$apply_migration" = false ]; then
    printf 'MISSING\t%s\t%s\n' "$target_ref" "$source_digest"
    return
  fi

  crane copy "$source_ref" "$target_ref"
  target_digest=$(crane digest "$target_ref")

  if [ "$target_digest" != "$source_digest" ]; then
    printf 'VERIFY-FAILED\t%s\tsource=%s target=%s\n' \
      "$target_ref" "$source_digest" "$target_digest" >&2
    return 1
  fi

  printf 'COPIED\t%s\t%s\n' "$target_ref" "$target_digest"
}

tag_count=0
crane ls "$source_image" | sort -V |
while IFS= read -r image_tag; do
  case "$image_tag" in
    ''|*[!A-Za-z0-9._-]*)
      echo "refusing unexpected registry tag: $image_tag" >&2
      exit 1
      ;;
  esac

  sync_tag "$github_image" "$image_tag"
  sync_tag "$dockerhub_image" "$image_tag"
  tag_count=$((tag_count + 1))
  printf 'TAG\t%s\t%s\n' "$tag_count" "$image_tag"
done

# POSIX pipelines execute the loop in a subshell, so count the source again for
# the final completeness assertion rather than relying on tag_count here.
source_count=$(crane ls "$source_image" | wc -l | tr -d ' ')
github_count=$(crane ls "$github_image" 2>/dev/null | wc -l | tr -d ' ')
dockerhub_count=$(crane ls "$dockerhub_image" 2>/dev/null | wc -l | tr -d ' ')

printf 'COUNTS\tsource=%s github=%s dockerhub=%s\n' \
  "$source_count" "$github_count" "$dockerhub_count"

if [ "$apply_migration" = true ]; then
  test "$github_count" -ge "$source_count"
  test "$dockerhub_count" -ge "$source_count"
fi
