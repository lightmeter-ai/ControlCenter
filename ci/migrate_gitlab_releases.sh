#!/bin/sh

set -eu

source_project_id=${SOURCE_GITLAB_PROJECT_ID:-17017123}
target_repository=${TARGET_GITHUB_REPOSITORY:-lightmeter-ai/ControlCenter}
apply_migration=${APPLY_RELEASE_MIGRATION:-false}

case "$apply_migration" in
  true|false) ;;
  *)
    echo "APPLY_RELEASE_MIGRATION must be true or false" >&2
    exit 2
    ;;
esac

for required_command in curl gh glab jq sha256sum; do
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

release_pages_json="$migration_tmp/release-pages.json"
releases_json="$migration_tmp/releases.json"
glab api "projects/$source_project_id/releases?per_page=100" --paginate > "$release_pages_json"

# glab writes one JSON array per exhausted API page. Collapse that JSON stream
# into one array so all later selection and completeness checks see every page.
page_count=$(jq -s 'length' "$release_pages_json")
jq -s 'add // []' "$release_pages_json" > "$releases_json"

release_count=$(jq 'length' "$releases_json")
if [ "$release_count" -eq 0 ]; then
  echo "no GitLab releases found" >&2
  exit 1
fi

printf 'source release pagination exhausted: %s pages, %s releases\n' \
  "$page_count" "$release_count"

sorted_releases="$migration_tmp/releases.sorted.jsonl"
jq -c 'sort_by(.released_at)[]' "$releases_json" > "$sorted_releases"

while IFS= read -r release_json; do
  release_tag=$(printf '%s' "$release_json" | jq -r '.tag_name')
  release_name=$(printf '%s' "$release_json" | jq -r '.name // .tag_name')
  released_at=$(printf '%s' "$release_json" | jq -r '.released_at')
  asset_count=$(printf '%s' "$release_json" | jq '.assets.links | length')

  case "$release_tag" in
    release/*) ;;
    *)
      echo "refusing unexpected release tag: $release_tag" >&2
      exit 1
      ;;
  esac

  if [ "$apply_migration" = false ]; then
    printf 'DRY RUN\t%s\t%s\t%s assets\n' "$release_tag" "$released_at" "$asset_count"
    continue
  fi

  release_dir="$migration_tmp/$(printf '%s' "$release_tag" | tr '/' '_')"
  mkdir "$release_dir"
  notes_file="$release_dir/notes.md"

  printf '%s\n\n---\n\nMigrated from GitLab; originally released %s.\n' \
    "$(printf '%s' "$release_json" | jq -r '.description // ""')" \
    "$released_at" > "$notes_file"

  if gh release view "$release_tag" --repo "$target_repository" >/dev/null 2>&1; then
    gh release edit "$release_tag" \
      --repo "$target_repository" \
      --title "$release_name" \
      --notes-file "$notes_file" \
      --verify-tag \
      --prerelease=false
  else
    gh release create "$release_tag" \
      --repo "$target_repository" \
      --title "$release_name" \
      --notes-file "$notes_file" \
      --verify-tag \
      --prerelease=false
  fi

  asset_urls="$migration_tmp/asset-urls"
  printf '%s' "$release_json" | jq -r '.assets.links[]?.url' > "$asset_urls"

  while IFS= read -r asset_url; do
    case "$asset_url" in
      "https://gitlab.com/api/v4/projects/$source_project_id/packages/generic/lightmeter/"*) ;;
      *)
        printf 'SKIP\t%s\tunsupported historical asset URL: %s\n' "$release_tag" "$asset_url" >&2
        continue
        ;;
    esac

    asset_name=$(basename "${asset_url%%\?*}")
    asset_file="$release_dir/$asset_name"

    if ! curl --fail --location --silent --show-error "$asset_url" --output "$asset_file"; then
      printf 'SKIP\t%s\tunavailable asset: %s\n' "$release_tag" "$asset_url" >&2
      continue
    fi
  done < "$asset_urls"

  if [ -f "$release_dir/sha256.txt" ]; then
    (cd "$release_dir" && sha256sum --check sha256.txt)
  fi

  for asset_file in "$release_dir"/*; do
    [ -f "$asset_file" ] || continue
    [ "$asset_file" = "$notes_file" ] && continue
    gh release upload "$release_tag" "$asset_file" \
      --repo "$target_repository" \
      --clobber
  done

  printf 'MIGRATED\t%s\t%s assets declared\n' "$release_tag" "$asset_count"
done < "$sorted_releases"

if [ "$apply_migration" = true ]; then
  latest_release_tag=$(jq -r 'max_by(.released_at).tag_name' "$releases_json")
  gh release edit "$latest_release_tag" \
    --repo "$target_repository" \
    --latest
  printf 'LATEST\t%s\n' "$latest_release_tag"
fi
