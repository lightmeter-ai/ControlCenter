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

for required_command in awk crane mktemp sort; do
  command -v "$required_command" >/dev/null || {
    echo "missing required command: $required_command" >&2
    exit 1
  }
done

migration_tmp=$(mktemp -d)
cleanup() {
  find "$migration_tmp" -mindepth 1 -delete
  rmdir "$migration_tmp"
}
trap cleanup EXIT HUP INT TERM

source_tags="$migration_tmp/source-tags"
sorted_source_tags="$migration_tmp/source-tags.sorted"
github_tags="$migration_tmp/github-tags"
dockerhub_tags="$migration_tmp/dockerhub-tags"

# Capture each fallible registry listing before processing it. In POSIX sh the
# status of an upstream pipeline command can otherwise be silently lost.
crane ls "$source_image" > "$source_tags"
sort -V "$source_tags" > "$sorted_source_tags"

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
done < "$sorted_source_tags"

source_count=$tag_count

if ! crane ls "$github_image" > "$github_tags" 2>/dev/null; then
  if [ "$apply_migration" = true ]; then
    echo "failed to list migrated GitHub image: $github_image" >&2
    exit 1
  fi
  : > "$github_tags"
fi

if ! crane ls "$dockerhub_image" > "$dockerhub_tags" 2>/dev/null; then
  if [ "$apply_migration" = true ]; then
    echo "failed to list migrated Docker Hub image: $dockerhub_image" >&2
    exit 1
  fi
  : > "$dockerhub_tags"
fi

github_count=$(awk 'END { print NR }' "$github_tags")
dockerhub_count=$(awk 'END { print NR }' "$dockerhub_tags")

printf 'COUNTS\tsource=%s github=%s dockerhub=%s\n' \
  "$source_count" "$github_count" "$dockerhub_count"

if [ "$apply_migration" = true ]; then
  test "$github_count" -ge "$source_count"
  test "$dockerhub_count" -ge "$source_count"
fi
