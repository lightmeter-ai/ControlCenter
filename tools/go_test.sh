#!/usr/bin/env bash

set -euo pipefail

# workaround SQLite warning reported at:
# https://github.com/mattn/go-sqlite3/issues/803
export CGO_CFLAGS="-g -O2 -Wno-return-local-addr"

export CGO_ENABLED=1

make mocks > /dev/null

# test everything except mocks and the main package
COVERPKG="$(go list ./... | grep -Ev '(/examples/|/po/|/tools|mock)' | tr '\n' ',')"

go test ./... -coverpkg="$COVERPKG" "$@"
