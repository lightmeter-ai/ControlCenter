#!/usr/bin/env node

const fs = require("fs");

if (process.argv.length !== 3) {
  console.error(`usage: ${process.argv[1]} <package-lock.json>`);
  process.exit(2);
}

const lockPath = process.argv[2];
const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
let replacements = 0;

function visit(value) {
  if (Array.isArray(value)) {
    value.forEach(visit);
    return;
  }

  if (value === null || typeof value !== "object") {
    return;
  }

  if (typeof value.resolved === "string") {
    const match = value.resolved.match(
      /^https?:\/\/registry\.npm\.taobao\.org\/(.+?)\/download\/(?:@[^/]+\/)?([^/?]+\.tgz)(?:\?.*)?$/,
    );

    if (match) {
      value.resolved = `https://registry.npmjs.org/${match[1]}/-/${match[2]}`;
      replacements += 1;
    }
  }

  Object.values(value).forEach(visit);
}

visit(lock);

if (replacements === 0) {
  console.error(`${lockPath}: no Taobao registry URLs found`);
  process.exit(1);
}

fs.writeFileSync(lockPath, `${JSON.stringify(lock, null, 2)}\n`);
console.log(`${lockPath}: replaced ${replacements} expired registry URLs`);
