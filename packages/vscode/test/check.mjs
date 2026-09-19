// `npm run check` — validates the extension manifest and the files it
// references, without producing a VSIX. Fast, CI-safe.
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { group, ok, readJSON, summary } from "./framework.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));

group("manifest (package.json)");
const pkg = readJSON(join(root, "package.json"));
ok(typeof pkg.name === "string" && pkg.name.length > 0, "has a name");
ok(typeof pkg.displayName === "string" && pkg.displayName.length > 0, "has a displayName");
ok(typeof pkg.description === "string" && pkg.description.length > 0, "has a description");
ok(/^\d+\.\d+\.\d+(-.+)?$/.test(pkg.version ?? ""), `version is SemVer (${pkg.version})`);
ok(typeof pkg.publisher === "string" && pkg.publisher.length > 0, "has a publisher");
ok(typeof pkg.engines?.vscode === "string", "has engines.vscode");
ok(/^Programming Languages$/.test((pkg.categories ?? []).join(",")), "categorised as a programming language");
ok(pkg.repository?.type === "git" && /^https:\/\/github\.com\/skygenesisenterprise\/edl-lang/.test(pkg.repository.url ?? ""), "repository points at edl-lang");
ok(typeof pkg.icon === "string" && existsSync(join(root, pkg.icon)), `icon exists (${pkg.icon})`);
ok(Array.isArray(pkg.contributes?.languages), "contributes.languages is an array");

group("language contribution");
const lang = (pkg.contributes?.languages ?? []).find((l) => l.id === "edl");
ok(!!lang, "language id is 'edl'");
ok((lang?.extensions ?? []).includes(".edl"), "associates the .edl extension");
ok(typeof lang?.configuration === "string", "references a language-configuration file");
ok(existsSync(join(root, lang.configuration)), `language-configuration exists (${lang.configuration})`);

group("grammar");
const grammar = (pkg.contributes?.grammars ?? []).find((g) => g.language === "edl");
ok(!!grammar, "a grammar is contributed for edl");
ok(grammar?.scopeName === "source.edl", "grammar scope is source.edl");
ok(typeof grammar?.path === "string" && existsSync(join(root, grammar.path)), `grammar file exists (${grammar.path})`);
if (grammar?.path) {
  const g = readJSON(join(root, grammar.path));
  ok(g.scopeName === "source.edl", "grammar scopeName matches");
  ok(g.name === "EDL", "grammar name is EDL");
  ok(typeof g.repository === "object" && g.repository !== null, "grammar has patterns repository");
}

group("snippets");
const snippets = (pkg.contributes?.snippets ?? []).find((s) => s.language === "edl");
ok(!!snippets && typeof snippets?.path === "string", "snippets are contributed for edl");
if (snippets?.path) {
  const s = readJSON(join(root, snippets.path));
  ok(Object.keys(s).length > 0, "snippets file is non-empty");
}

group("files");
for (const f of ["LICENSE", "README.md", "CHANGELOG.md"]) {
  ok(existsSync(join(root, f)), `${f} present`);
}
const rc = readJSON(join(root, "language-configuration.json"));
ok(typeof rc.comments?.lineComment === "string", "line comment configured");
ok(Array.isArray(rc.brackets) && rc.brackets.length >= 3, "bracket pairs configured");
ok(Array.isArray(rc.autoClosingPairs) && rc.autoClosingPairs.length > 0, "auto-closing pairs configured");

summary();