#!/usr/bin/env node
// Builds the extension VSIX as `edl-<version>.vsix`.
//
// The version is read from package.json so it remains the single source of
// truth. The archive name follows the repository's `edl-<version>.vsix`
// convention rather than the default `@vscode/vsce` name.
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const { version } = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const out = join(root, `edl-${version}.vsix`);

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