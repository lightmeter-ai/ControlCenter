#!/bin/sh

set -eu

task_tmp=$(mktemp -d)
cleanup() {
  find "$task_tmp" -mindepth 1 -delete
  rmdir "$task_tmp"
}
trap cleanup EXIT HUP INT TERM

audit_report="$task_tmp/npm-audit.json"
lockfile="$task_tmp/package-lock.json"
baseline="$task_tmp/npm-audit-baseline.json"

printf '%s\n' '{"lockfileVersion":2}' > "$lockfile"
printf '%s\n' '{"metadata":{"vulnerabilities":{"info":0,"low":0,"moderate":0,"high":1,"critical":1,"total":2}},"vulnerabilities":{"legacy-high":{"severity":"high","isDirect":true,"via":[{"source":101,"name":"legacy-high","severity":"high","range":"<2"}],"range":"<2"},"legacy-critical":{"severity":"critical","isDirect":false,"via":["legacy-high",{"source":202,"name":"legacy-critical","severity":"critical","range":"<3"}],"range":"<3"}}}' > "$audit_report"
cp "$audit_report" "$task_tmp/original-npm-audit.json"

node ci/check_npm_audit_baseline.js snapshot "$audit_report" "$lockfile" > "$baseline"
node ci/check_npm_audit_baseline.js check "$audit_report" "$lockfile" "$baseline"

printf '%s\n' '{"metadata":{"vulnerabilities":{"info":0,"low":0,"moderate":0,"high":2,"critical":1,"total":3}},"vulnerabilities":{"legacy-high":{"severity":"high","isDirect":true,"via":[{"source":101,"name":"legacy-high","severity":"high","range":"<2"}],"range":"<2"},"legacy-critical":{"severity":"critical","isDirect":false,"via":["legacy-high",{"source":202,"name":"legacy-critical","severity":"critical","range":"<3"}],"range":"<3"},"new-high":{"severity":"high","isDirect":false,"via":[{"source":303,"name":"new-high","severity":"high","range":"<4"}],"range":"<4"}}}' > "$audit_report"

if node ci/check_npm_audit_baseline.js check "$audit_report" "$lockfile" "$baseline" >/dev/null 2>&1; then
  echo 'npm audit baseline accepted a new high-severity finding' >&2
  exit 1
fi

printf '%s\n' '{"metadata":{"vulnerabilities":{"info":0,"low":0,"moderate":0,"high":1,"critical":1,"total":2}},"vulnerabilities":{"broken":null}}' > "$audit_report"
if invalid_output=$(node ci/check_npm_audit_baseline.js check \
  "$audit_report" "$lockfile" "$baseline" 2>&1); then
  echo 'npm audit baseline accepted a null vulnerability entry' >&2
  exit 1
fi
printf '%s\n' "$invalid_output" \
  | grep -F 'npm audit baseline error: invalid vulnerability entry for broken' >/dev/null

cp "$task_tmp/original-npm-audit.json" "$audit_report"
printf '%s\n' '{"lockfileVersion":3}' > "$lockfile"
if node ci/check_npm_audit_baseline.js check "$audit_report" "$lockfile" "$baseline" >/dev/null 2>&1; then
  echo 'npm audit baseline accepted an unreviewed lockfile change' >&2
  exit 1
fi

printf '%s\n' 'PASS: npm audit baseline blocks unreviewed dependency and advisory changes'
