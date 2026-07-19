#!/bin/sh

# TODO: Generate a format more suitable for being displayed online

set -e

APP_VERSION=$(cat VERSION.txt)
raw_output=$(mktemp)
formatted_output=$(mktemp)

cleanup() {
  rm -f "$raw_output" "$formatted_output"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

(
  cd tools/cmdline_usage/
  go build -o lightmeter -ldflags "-X gitlab.com/lightmeter/controlcenter/version.Version=$APP_VERSION"
  echo '```'
  ./lightmeter 2>&1
  echo '```'
) > "$raw_output"

expand -t 8 "$raw_output" > "$formatted_output"
chmod 644 "$formatted_output"
mv "$formatted_output" cli_usage.md
