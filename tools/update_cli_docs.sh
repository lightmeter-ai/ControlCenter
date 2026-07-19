#!/bin/sh

# TODO: Generate a format more suitable for being displayed online

set -e

APP_VERSION=$(cat VERSION.txt)

(
  cd tools/cmdline_usage/
  go build -o lightmeter -ldflags "-X gitlab.com/lightmeter/controlcenter/version.Version=$APP_VERSION"
  echo '```'
  ./lightmeter 2>&1
  echo '```'
) | expand -t 8 > cli_usage.md
