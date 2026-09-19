#!/usr/bin/env node
// Builds the extension VSIX as `<name>-<version>.vsix`.
//
// The name and version are read from package.json so they remain the single
// source of truth. The archive name follows the package's `name` field, e.g.
// `edl-language-support-0.1.0.vsix`.
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const { name, version } = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const out = join(root, `${name}-${version}.vsix`);

const vsce = process.platform === "win32" ? "vsce.cmd" : "vsce";
const res = spawnSync(vsce, ["package", "--out", out], {
  stdio: "inherit",
  cwd: root,
});

if (res.error) {
  console.error(`Failed to spawn ${vsce}: ${res.error.message}`);
  process.exit(1);
}
process.exit(res.status ?? 1);