#!/usr/bin/env node

const crypto = require('crypto')
const fs = require('fs')

function fail(message) {
  console.error(`npm audit baseline error: ${message}`)
  process.exit(1)
}

function readJson(path, description) {
  try {
    return JSON.parse(fs.readFileSync(path, 'utf8'))
  } catch (error) {
    fail(`cannot read ${description} ${path}: ${error.message}`)
  }
}

function sha256(contents) {
  return crypto.createHash('sha256').update(contents).digest('hex')
}

function compareCodeUnits(left, right) {
  if (left < right) return -1
  if (left > right) return 1
  return 0
}

function stableObject(value) {
  if (Array.isArray(value)) {
    return value.map(stableObject)
  }
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value).sort().map(key => [key, stableObject(value[key])])
    )
  }
  return value
}

function normalizeVia(via) {
  if (!Array.isArray(via)) {
    fail('a high or critical vulnerability has no via array')
  }

  return via.map(item => {
    if (typeof item === 'string') {
      return { dependency: item }
    }
    if (item === null || typeof item !== 'object') {
      fail('a high or critical vulnerability has an invalid via entry')
    }

    return stableObject({
      source: item.source,
      name: item.name,
      dependency: item.dependency,
      title: item.title,
      url: item.url,
      severity: item.severity,
      range: item.range
    })
  }).map(item => [JSON.stringify(item), item])
    .sort((left, right) => compareCodeUnits(left[0], right[0]))
    .map(([, item]) => item)
}

function auditSnapshot(report, lockfileContents) {
  const counts = report && report.metadata && report.metadata.vulnerabilities
  if (!counts || !Number.isInteger(counts.high) ||
      !Number.isInteger(counts.critical) || !Number.isInteger(counts.total)) {
    fail('audit report does not contain integer vulnerability counts')
  }
  if (!report.vulnerabilities || typeof report.vulnerabilities !== 'object') {
    fail('audit report does not contain a vulnerabilities object')
  }

  const findings = Object.entries(report.vulnerabilities)
    .filter(([, finding]) => finding.severity === 'high' || finding.severity === 'critical')
    .map(([name, finding]) => stableObject({
      name,
      severity: finding.severity,
      isDirect: finding.isDirect === true,
      via: normalizeVia(finding.via)
    }))
    .sort((left, right) => compareCodeUnits(left.name, right.name))

  if (findings.length !== counts.high + counts.critical) {
    fail(`metadata reports ${counts.high + counts.critical} high/critical packages but normalized ${findings.length}`)
  }

  return {
    schemaVersion: 1,
    lockfileSha256: sha256(lockfileContents),
    findingsSha256: sha256(JSON.stringify(findings)),
    high: counts.high,
    critical: counts.critical,
    highCriticalPackages: findings.length
  }
}

function usage() {
  console.error('usage: check_npm_audit_baseline.js <snapshot|check> <audit-report> <package-lock> [baseline]')
  process.exit(2)
}

const [mode, auditPath, lockfilePath, baselinePath] = process.argv.slice(2)
if (!mode || !auditPath || !lockfilePath) {
  usage()
}

const report = readJson(auditPath, 'audit report')
let lockfileContents
try {
  lockfileContents = fs.readFileSync(lockfilePath)
} catch (error) {
  fail(`cannot read lockfile ${lockfilePath}: ${error.message}`)
}
const snapshot = auditSnapshot(report, lockfileContents)

if (mode === 'snapshot') {
  if (baselinePath) {
    usage()
  }
  process.stdout.write(`${JSON.stringify(snapshot, null, 2)}\n`)
  process.exit(0)
}

if (mode !== 'check' || !baselinePath) {
  usage()
}

const baseline = readJson(baselinePath, 'baseline')
for (const key of Object.keys(snapshot)) {
  if (baseline[key] !== snapshot[key]) {
    fail(`${key} changed: baseline=${baseline[key]} current=${snapshot[key]}; review the audit report before refreshing the baseline`)
  }
}

console.log(
  `npm audit baseline matched: high=${snapshot.high} critical=${snapshot.critical} ` +
  `packages=${snapshot.highCriticalPackages} fingerprint=${snapshot.findingsSha256}`
)
