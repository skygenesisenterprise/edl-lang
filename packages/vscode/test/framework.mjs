// Minimal, dependency-free test helpers and a small ZIP central-directory
// reader used to inspect the packaged VSIX (a ZIP archive).
import { readFileSync } from "node:fs";

let passCount = 0;
let failCount = 0;
let current = "unknown";

export function group(name) {
  current = name;
  console.log(`\n## ${name}`);
}

export function ok(cond, label) {
  if (cond) {
    passCount++;
    console.log(`  PASS  ${label}`);
  } else {
    failCount++;
    console.log(`  FAIL  ${label}`);
  }
}

export function summary() {
  console.log(`\n${passCount} passed, ${failCount} failed`);
  if (failCount > 0) process.exit(1);
}

export function readJSON(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

// ---- ZIP central-directory listing (works with vsce-produced VSIX) ----
const EOCD_MAGIC = 0x06054b50;
const CENTRAL_MAGIC = 0x02014b50;

export function listZipEntries(file) {
  const buf = readFileSync(file);
  const eocd = findEocd(buf);
  if (eocd < 0) throw new Error("End of central directory not found");

  const count = buf.readUInt16LE(eocd + 10);
  const cdOffset = buf.readUInt32LE(eocd + 16);

  const entries = [];
  let off = cdOffset;
  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(off) !== CENTRAL_MAGIC) break;
    const method = buf.readUInt16LE(off + 10);
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    const name = buf.toString("utf8", off + 46, off + 46 + nameLen);
    entries.push({ name, method });
    off += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

function findEocd(buf) {
  for (let i = buf.length - 22; i >= 0; i--) {
    if (buf.readUInt32LE(i) === EOCD_MAGIC) return i;
  }
  return -1;
}

export { current };