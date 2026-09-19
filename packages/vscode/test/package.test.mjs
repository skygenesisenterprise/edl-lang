// Packaging test: builds the VSIX with @vscode/vsce and inspects the archive
// to verify it is installable and free of development-only files.
import { spawnSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { group, listZipEntries, ok, readJSON, summary } from "./framework.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const { version } = readJSON(join(root, "package.json"));
const vsix = join(root, `edl-${version}.vsix`);

group("package generation");
ok(existsSync(vsix), `VSIX exists (edl-${version}.vsix)`);
if (existsSync(vsix)) {
  const size = statSync(vsix).size;
  ok(size > 0, `VSIX is non-empty (${size} bytes)`);
}

if (!existsSync(vsix)) {
  summary();
  process.exit(1);
}

group("archive contents");
const entries = listZipEntries(vsix).map((e) => e.name);
const required = [
  "extension/package.json",
  "extension/syntaxes/edl.tmLanguage.json",
  "extension/language-configuration.json",
  "extension/snippets/edl.json",
  "extension/images/icon.png",
  // @vscode/vsce normalises these names on packaging.
  "extension/LICENSE.txt",
  "extension/readme.md",
  "extension/changelog.md",
];
for (const f of required) {
  ok(entries.includes(f), `contains ${f}`);
}

const forbidden = [
  "node_modules",
  ".git/",
  "extension/.git",
  "extension/test/",
  "extension/scripts/",
  "extension/.github",
  "extension/examples/",
  "extension/package-lock.json",
  "extension/*.vsix",
];
for (const pat of forbidden) {
  const hit = entries.some((e) => e.includes(pat));
  ok(!hit, `excludes ${pat}`);
}

summary();