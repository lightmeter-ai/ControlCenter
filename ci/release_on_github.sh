#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <prepare|publish> <release/VERSION>" >&2
  exit 2
fi

release_action=$1
release_tag=$2
version=$(cat VERSION.txt)
expected_tag="release/$version"
release_notes="release_notes/$version"
binary="lightmeter-linux_amd64-$version"
checksum="$binary.sha256"

if [ "$release_tag" != "$expected_tag" ]; then
  echo "tag $release_tag does not match VERSION.txt ($expected_tag)" >&2
  exit 1
fi

if [ ! -f "$release_notes" ]; then
  echo "missing release notes: $release_notes" >&2
  exit 1
fi

case "$release_action" in
  prepare)
    test -x lightmeter
    cp lightmeter "$binary"
    sha256sum "$binary" > "$checksum"
    ;;
  publish)
    test -f "$binary"
    test -f "$checksum"
    sha256sum --check "$checksum"

    if gh release view "$release_tag" >/dev/null 2>&1; then
      gh release edit "$release_tag" \
        --title "Lightmeter Control Center $version" \
        --notes-file "$release_notes" \
        --verify-tag
    else
      gh release create "$release_tag" \
        --title "Lightmeter Control Center $version" \
        --notes-file "$release_notes" \
        --verify-tag
    fi

    gh release upload "$release_tag" "$binary" "$checksum" --clobber
    ;;
  *)
    echo "action must be prepare or publish" >&2
    exit 2
    ;;
esac
