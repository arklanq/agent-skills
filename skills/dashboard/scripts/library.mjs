#!/usr/bin/env node
// Inspect or publish reusable dashboard components without overwriting concurrent work.
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

import { SKILL, atomic, isMain, libraryLockPath, lock } from "./dashboard.mjs";

export function digest(directory) {
  const names = [...fs.readdirSync(directory).filter((name) => name.endsWith(".js")), "CATALOG.md"].sort();
  const hash = createHash("sha256");
  for (const name of names) {
    hash.update(Buffer.concat([Buffer.from(name), Buffer.from([0]), fs.readFileSync(path.join(directory, name)), Buffer.from([0])]));
  }
  return hash.digest("hex");
}

export function inspect(skill = SKILL) {
  const directory = path.join(skill, "components");
  return lock(libraryLockPath(), () => ({
    digest: digest(directory),
    components: fs.readdirSync(directory).filter((name) => name.endsWith(".js")).sort(),
  }));
}

export function publish(source, catalog, expected, skill = SKILL) {
  const name = path.basename(source);
  if (!/^[a-z][a-z0-9-]*\.js$/.test(name)) throw new Error("Component filename must be lowercase kebab-case.js.");
  const code = fs.readFileSync(source, "utf8");
  const docs = fs.readFileSync(catalog, "utf8");
  if (!docs.includes(name) || !docs.trim()) throw new Error("Catalog must document the component filename and its API.");
  try {
    new vm.Script(code, { filename: name });
  } catch (error) {
    throw new Error("JavaScript syntax check failed: " + error.message);
  }
  const directory = path.join(skill, "components");
  return lock(libraryLockPath(), () => {
    if (digest(directory) !== expected) {
      throw new Error("Library changed. Re-read it, reconcile your change, and use the new digest.");
    }
    const target = path.join(directory, name);
    const index = path.join(directory, "CATALOG.md");
    const oldCode = fs.existsSync(target) ? fs.readFileSync(target, "utf8") : null;
    const oldDocs = fs.readFileSync(index, "utf8");
    try {
      atomic(target, code);
      atomic(index, docs);
    } catch (error) {
      if (oldCode === null) fs.rmSync(target, { force: true });
      else atomic(target, oldCode);
      atomic(index, oldDocs);
      throw error;
    }
    return { component: name, digest: digest(directory) };
  });
}

const usage = `Usage:
  node library.mjs inspect
  node library.mjs publish --file <component.js> --catalog <CATALOG.md> --expected <digest>`;

function main() {
  const [command, ...rest] = process.argv.slice(2);
  if (command === "inspect" && rest.length === 0) return inspect();
  const options = {};
  for (let index = 0; index < rest.length; index += 2) {
    if (!["--file", "--catalog", "--expected"].includes(rest[index]) || rest[index + 1] === undefined) throw new Error(usage);
    options[rest[index].slice(2)] = rest[index + 1];
  }
  if (command !== "publish" || !options.file || !options.catalog || !options.expected) throw new Error(usage);
  return publish(options.file, options.catalog, options.expected);
}

if (isMain(import.meta.url)) {
  try {
    console.log(JSON.stringify(main()));
  } catch (error) {
    console.error("dashboard library: " + (error.message ?? error));
    process.exit(1);
  }
}
