// `npm run test` — runs the full test suite: manifest validation followed by
// packaging and VSIX archive inspection.
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { readJSON } from "./framework.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const { version } = readJSON(join(root, "package.json"));

function run(script) {
  const res = spawnSync(process.execPath, [script], { stdio: "inherit", cwd: root });
  return res.status ?? 1;
}

let failed = false;

console.log("== check ==");
if (run(join(root, "test/check.mjs")) !== 0) failed = true;

console.log("\n== build VSIX ==");
const vsce = process.platform === "win32" ? "vsce.cmd" : "vsce";
const build = spawnSync(vsce, ["package", "--out", join(root, `edl-${version}.vsix`)], {
  stdio: "inherit",
  cwd: root,
});
if ((build.status ?? 1) !== 0) failed = true;

console.log("\n== packaging test ==");
if (run(join(root, "test/package.test.mjs")) !== 0) failed = true;

process.exit(failed ? 1 : 0);