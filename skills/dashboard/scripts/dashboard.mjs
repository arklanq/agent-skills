#!/usr/bin/env node
// Local, dependency-free dashboard runtime. Requires Node.js 18+ on macOS/Linux.
import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const SKILL = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const BASE = path.join(os.tmpdir(), "agent-dashboard-" + process.getuid());
const STATUSES = new Set(["todo", "doing", "done", "blocked", "unknown"]);
const FIELDS = ["title", "goal", "now", "next", "tasks", "milestones", "decisions", "events", "ui"];
const LANGUAGE = /^[A-Za-z]{2,3}(-[A-Za-z0-9]{1,8})*$/;
const sleeper = new Int32Array(new SharedArrayBuffer(4));
// The dashboard agent's activity lease; it expires on its own if the agent stops without clearing it.
const LEASE_MS = 180000;
// A content or layout write counts as visible activity for this long.
const RECENT_CHANGE_MS = 4000;
// An untouched layout counts as the first draft in progress for this long after start.
const DRAFT_MS = 600000;

export function now() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "+00:00");
}

export function atomic(file, value) {
  const temporary = path.join(path.dirname(file), ".write-" + randomBytes(6).toString("hex"));
  try {
    fs.writeFileSync(temporary, typeof value === "string" ? value : JSON.stringify(value, null, 2));
    fs.renameSync(temporary, file);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
}

// A directory is created atomically, so it serves as a cross-process lock; a lock older than
// 30 seconds belongs to a crashed process and is taken over.
export function lock(lockPath, work) {
  const deadline = Date.now() + 15000;
  for (;;) {
    try {
      fs.mkdirSync(lockPath);
      break;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      try {
        if (Date.now() - fs.statSync(lockPath).mtimeMs > 30000) fs.rmSync(lockPath, { recursive: true, force: true });
      } catch {}
      if (Date.now() > deadline) throw new Error("Timed out waiting for " + lockPath);
      Atomics.wait(sleeper, 0, 0, 10);
    }
  }
  try {
    return work();
  } finally {
    fs.rmSync(lockPath, { recursive: true, force: true });
  }
}

export function read(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

export function session(value) {
  fs.mkdirSync(BASE, { mode: 0o700, recursive: true });
  const base = fs.lstatSync(BASE);
  if (base.isSymbolicLink() || base.uid !== process.getuid()) throw new Error("Unsafe temporary dashboard root.");
  fs.chmodSync(BASE, 0o700);
  let directory;
  if (path.isAbsolute(value)) {
    directory = path.resolve(value);
    if (path.dirname(directory) !== fs.realpathSync(BASE) && path.dirname(directory) !== path.resolve(BASE)) {
      throw new Error("Session must be inside " + BASE);
    }
  } else {
    if (!/^[a-zA-Z0-9_-]{1,100}$/.test(value)) {
      throw new Error("Use a session key of 1–100 letters, digits, underscores or hyphens.");
    }
    directory = path.join(BASE, value);
  }
  try {
    if (fs.lstatSync(directory).isSymbolicLink()) throw new Error("Session cannot be a symlink.");
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  return directory;
}

const isObject = (value) => typeof value === "object" && value !== null && !Array.isArray(value);

export function validate(state) {
  for (const key of ["title", "goal", "now", "next"]) {
    if (typeof state[key] !== "string") throw new Error(key + " must be text.");
  }
  for (const key of ["tasks", "milestones", "decisions", "events"]) {
    if (!Array.isArray(state[key]) || state[key].length > 1000) throw new Error(key + " must be an array of at most 1000 items.");
  }
  for (const group of ["tasks", "milestones", "decisions"]) {
    const seen = new Set();
    for (const item of state[group]) {
      if (!isObject(item) || typeof item.id !== "string" || !item.id) throw new Error(group + " items need a nonempty string id.");
      if (seen.has(item.id)) throw new Error("Duplicate id in " + group);
      seen.add(item.id);
      if (typeof item.title !== "string") throw new Error(group + " items need a title.");
      for (const field of ["panel", "milestone", "evidence", "blocker", "default"]) {
        if (field in item && typeof item[field] !== "string") throw new Error(field + " must be text.");
      }
      for (const field of ["blocking", "proposed"]) {
        if (field in item && typeof item[field] !== "boolean") throw new Error(field + " must be boolean.");
      }
    }
  }
  const ids = new Set(state.tasks.map((task) => task.id));
  for (const task of state.tasks) {
    if (!STATUSES.has(task.status)) throw new Error("Unknown task status.");
    if (task.status === "blocked" && !(task.blocker ?? "").trim()) throw new Error("Blocked tasks need a blocker.");
    if (task.status === "done" && !(task.evidence ?? "").trim()) throw new Error("Done tasks need evidence or an explicit confirmation.");
  }
  for (const milestone of state.milestones) {
    const refs = milestone.taskIds;
    if (!Array.isArray(refs) || !refs.every((ref) => typeof ref === "string")) throw new Error("Milestones need taskIds.");
    if (new Set(refs).size !== refs.length || !refs.every((ref) => ids.has(ref))) {
      throw new Error("Milestone taskIds must be unique and reference existing tasks.");
    }
  }
  for (const event of state.events) {
    if (!isObject(event) || typeof event.text !== "string" || typeof event.at !== "string") throw new Error("Events need at and text strings.");
  }
  if ("ui" in state) {
    const { ui } = state;
    if (!isObject(ui) || Object.keys(ui).some((key) => key !== "lang" && key !== "strings")) throw new Error("ui accepts only lang and strings.");
    if ("lang" in ui && !(typeof ui.lang === "string" && LANGUAGE.test(ui.lang))) throw new Error("ui.lang must be a language tag such as en or pt-BR.");
    if ("strings" in ui) {
      const entries = isObject(ui.strings) ? Object.entries(ui.strings) : null;
      if (!entries || entries.length > 300 || !entries.every(([, text]) => typeof text === "string" && text.length <= 1000)) {
        throw new Error("ui.strings must map at most 300 keys to text.");
      }
    }
  }
  return state;
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

export function update(directory, patch) {
  if (!isObject(patch) || Object.keys(patch).some((key) => !FIELDS.includes(key) && key !== "removeTasks")) {
    throw new Error("Unknown update field. See references/protocol.md.");
  }
  return lock(path.join(directory, ".state.lock"), () => {
    const old = read(path.join(directory, "state.json"));
    const state = structuredClone(old);
    for (const [key, value] of Object.entries(patch)) {
      if (FIELDS.includes(key) && !["tasks", "events", "ui"].includes(key)) state[key] = value;
    }
    if ("ui" in patch) {
      if (!isObject(patch.ui) || ("strings" in patch.ui && !isObject(patch.ui.strings))) throw new Error("ui and ui.strings must be objects.");
      // lang replaces the previous value; strings merge by key.
      const strings = { ...state.ui?.strings, ...patch.ui.strings };
      state.ui = { ...state.ui, ...patch.ui, ...(Object.keys(strings).length ? { strings } : {}) };
    }
    if ("tasks" in patch) {
      if (!Array.isArray(patch.tasks)) throw new Error("tasks must be an array.");
      const tasks = new Map(state.tasks.map((task) => [task.id, task]));
      const seen = new Set();
      for (const task of patch.tasks) {
        if (!isObject(task) || typeof task.id !== "string") throw new Error("Each task patch needs an id.");
        if (seen.has(task.id)) throw new Error("Duplicate task patch id.");
        seen.add(task.id);
        tasks.set(task.id, { ...tasks.get(task.id), ...task });
      }
      state.tasks = [...tasks.values()];
    }
    const remove = patch.removeTasks ?? [];
    if (!Array.isArray(remove) || !remove.every((id) => typeof id === "string")) throw new Error("removeTasks must be an array of ids.");
    state.tasks = state.tasks.filter((task) => !remove.includes(task.id));
    if ("events" in patch) {
      if (!Array.isArray(patch.events)) throw new Error("events must be an array.");
      state.events = [...state.events, ...patch.events].slice(-100);
    }
    validate(state);
    if (FIELDS.every((key) => same(state[key], old[key]))) return old;
    const previous = new Map(old.tasks.map((task) => [task.id, task]));
    state.changedIds = state.tasks.filter((task) => !same(previous.get(task.id), task)).map((task) => task.id);
    state.revision += 1;
    state.updatedAt = now();
    atomic(path.join(directory, "state.json"), state);
    return state;
  });
}

function componentFiles(directory) {
  const components = path.join(directory, "components");
  return fs.readdirSync(components).filter((name) => name.endsWith(".js")).sort().map((name) => path.join(components, name));
}

export function render(directory) {
  const state = read(path.join(directory, "state.json"));
  const html = fs.readFileSync(path.join(directory, "template.html"), "utf8");
  const components = componentFiles(directory).map((file) => fs.readFileSync(file, "utf8")).join("\n");
  const custom = fs.readFileSync(path.join(directory, "custom.js"), "utf8");
  // Escape script-closing strings even in trusted authored JS; state is always data.
  const values = {
    "/*__COMPONENTS__*/": components.replaceAll("</script", "<\\/script"),
    "/*__CUSTOM__*/": custom.replaceAll("</script", "<\\/script"),
    "/*__STATE__*/": JSON.stringify(state).replace(/[\u007f-\uffff]/g, (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0")).replaceAll("<", "\\u003c"),
  };
  if (html.includes("/*__FONT_FACE__*/")) values["/*__FONT_FACE__*/"] = fs.readFileSync(path.join(directory, "font.css"), "utf8");
  for (const marker of Object.keys(values)) {
    if (html.split(marker).length !== 2) throw new Error("Template must contain exactly one " + marker);
  }
  return html.replace(/\/\*__(?:COMPONENTS|CUSTOM|STATE|FONT_FACE)__\*\//g, (marker) => values[marker]);
}

function signature(directory) {
  const files = [path.join(directory, "template.html"), path.join(directory, "custom.js"), ...componentFiles(directory)];
  if (fs.existsSync(path.join(directory, "font.css"))) files.push(path.join(directory, "font.css"));
  const hash = createHash("sha256");
  for (const file of files) hash.update(fs.readFileSync(file));
  return hash.digest("hex");
}

/** Starts or renews the activity lease, or clears it and ends the first draft when done is true. */
export function activity(directory, done = false) {
  read(path.join(directory, "state.json"));
  const file = path.join(directory, "activity.json");
  if (done) {
    fs.rmSync(file, { force: true });
    const originPath = path.join(directory, "origin.json");
    const origin = readOptional(originPath);
    if (origin && !origin.drafted) atomic(originPath, { ...origin, drafted: true });
    return { busy: false };
  }
  const until = Date.now() + LEASE_MS;
  atomic(file, { until });
  return { busy: true, until: new Date(until).toISOString() };
}

function readOptional(file) {
  try {
    return read(file);
  } catch {
    return null;
  }
}

/** Returns idle, draft (the first design is still in progress), or work. */
function phase(directory, layout, changedAt) {
  const time = Date.now();
  const origin = readOptional(path.join(directory, "origin.json"));
  // The first draft ends with the first `activity --done`, or after DRAFT_MS without a lease.
  const firstDraft = Boolean(origin) && !origin.drafted;
  const young = firstDraft && time - origin.at < DRAFT_MS;
  const lease = readOptional(path.join(directory, "activity.json"))?.until > time;
  const busy = lease || time - changedAt < RECENT_CHANGE_MS || (young && origin.signature === layout);
  return busy ? (firstDraft && (lease || young) ? "draft" : "work") : "idle";
}

export async function probe(directory) {
  try {
    const info = read(path.join(directory, "server.json"));
    const response = await fetch(info.url + "health", { signal: AbortSignal.timeout(600) });
    const health = await response.json();
    return health.instance === info.instance ? info : null;
  } catch {
    return null;
  }
}

function serve(directory) {
  const instance = randomBytes(16).toString("hex");
  const token = randomBytes(24).toString("hex");
  // One watcher feeds every open event stream.
  const watch = { revision: read(path.join(directory, "state.json")).revision, layout: signature(directory), changedAt: 0, phase: "idle" };
  const clients = new Set();
  watch.phase = phase(directory, watch.layout, 0);
  setInterval(() => {
    try {
      const revision = read(path.join(directory, "state.json")).revision;
      const layout = signature(directory);
      if (revision !== watch.revision || layout !== watch.layout) watch.changedAt = Date.now();
      Object.assign(watch, { revision, layout, phase: phase(directory, layout, watch.changedAt) });
      for (const client of clients) client();
    } catch (error) {
      console.error(String(error.message ?? error));
    }
  }, 350);
  const server = http.createServer((request, response) => {
    const expected = "127.0.0.1:" + server.address().port;
    const reply = (payload, status = 200, contentType = "application/json") => {
      const body = Buffer.from(typeof payload === "string" ? payload : JSON.stringify(payload));
      response.writeHead(status, {
        "Content-Type": contentType + "; charset=utf-8",
        "Content-Length": body.length,
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
      });
      response.end(body);
    };
    if (request.headers.host !== expected || (request.headers.origin ?? "http://" + expected) !== "http://" + expected) {
      return reply({ error: "Origin or host rejected." }, 403);
    }
    if (request.method === "POST") {
      const chunks = [];
      let size = 0;
      request.on("data", (chunk) => {
        size += chunk.length;
        if (size <= 4096) chunks.push(chunk);
      });
      request.on("end", () => {
        if (!(size > 0 && size <= 4096)) return reply({ error: "Invalid body size." }, 400);
        let data;
        try {
          data = JSON.parse(Buffer.concat(chunks).toString("utf8"));
        } catch {
          return reply({ error: "Invalid request." }, 400);
        }
        if (request.url === "/shutdown" && isObject(data) && data.token === token) {
          response.on("finish", () => process.exit(0));
          reply({ ok: true });
          return;
        }
        reply({ error: "Not found or unauthorized." }, 403);
      });
      return;
    }
    const route = request.url.split("?")[0];
    try {
      if (route === "/") return reply(render(directory), 200, "text/html");
      if (route === "/health") return reply({ instance });
      if (route === "/state") return reply(read(path.join(directory, "state.json")));
      if (route !== "/events") return reply({ error: "Not found." }, 404);
    } catch (error) {
      console.error(String(error.message ?? error));
      return reply({ error: String(error.message ?? error) }, 500);
    }
    response.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", Connection: "keep-alive" });
    let revision = null;
    let layout = watch.layout;
    let sentPhase = null;
    let heartbeat = 0;
    const client = () => {
      let wrote = false;
      if (sentPhase !== watch.phase) {
        response.write("event: activity\ndata: " + watch.phase + "\n\n");
        sentPhase = watch.phase;
        wrote = true;
      }
      const event = watch.layout !== layout ? "layout" : revision !== watch.revision ? "update" : null;
      if (event) {
        response.write("event: " + event + "\ndata: " + watch.revision + "\n\n");
        revision = watch.revision;
        layout = watch.layout;
        wrote = true;
      }
      if (wrote) heartbeat = Date.now();
      else if (Date.now() - heartbeat > 10000) {
        response.write(": heartbeat\n\n");
        heartbeat = Date.now();
      }
    };
    clients.add(client);
    client();
    response.on("close", () => {
      clients.delete(client);
    });
  });
  server.listen(0, "127.0.0.1", () => {
    atomic(path.join(directory, "server.json"), {
      pid: process.pid,
      url: "http://127.0.0.1:" + server.address().port + "/",
      instance,
      token,
    });
  });
}

function openBrowser(url) {
  const command = process.platform === "darwin" ? "open" : "xdg-open";
  spawn(command, [url], { stdio: "ignore", detached: true }).on("error", () => {}).unref();
}

export async function start({ session: key, title = "Dashboard", goal = "", lang, open = false }) {
  const directory = session(key);
  fs.mkdirSync(directory, { mode: 0o700, recursive: true });
  const statePath = path.join(directory, "state.json");
  lock(path.join(directory, ".start.lock"), () => {
    if (fs.existsSync(statePath)) return;
    const state = { title, goal, now: "", next: "", tasks: [], milestones: [], decisions: [], events: [], ...(lang ? { ui: { lang } } : {}), revision: 0, updatedAt: now(), changedIds: [] };
    validate(state);
    fs.copyFileSync(path.join(SKILL, "assets", "dashboard.html"), path.join(directory, "template.html"));
    if (fs.existsSync(path.join(SKILL, "assets", "font.css"))) {
      fs.copyFileSync(path.join(SKILL, "assets", "font.css"), path.join(directory, "font.css"));
    }
    lock(libraryLockPath(), () => fs.cpSync(path.join(SKILL, "components"), path.join(directory, "components"), { recursive: true }));
    atomic(path.join(directory, "custom.js"), "// Optional session-specific rendering.\n");
    atomic(statePath, state);
    atomic(path.join(directory, "origin.json"), { signature: signature(directory), at: Date.now() });
  });
  let info = await probe(directory);
  if (!info) {
    const log = fs.openSync(path.join(directory, "server.log"), "a");
    const child = spawn(process.execPath, [fileURLToPath(import.meta.url), "serve", "--session", directory], {
      stdio: ["ignore", log, log],
      detached: true,
    });
    fs.closeSync(log);
    let exited = false;
    child.on("exit", () => (exited = true));
    child.unref();
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      info = await probe(directory);
      if (info) break;
      if (exited) throw new Error("Server failed. Inspect " + path.join(directory, "server.log"));
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    if (!info) {
      child.kill();
      throw new Error("Server startup timed out.");
    }
  }
  if (open) openBrowser(info.url);
  return { session: directory, url: info.url, revision: read(statePath).revision };
}

export async function stop(directory) {
  const info = await probe(directory);
  if (!info) return { stopped: true, alreadyStopped: true };
  const response = await fetch(info.url + "shutdown", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: info.token }),
    signal: AbortSignal.timeout(2000),
  });
  await response.json();
  for (let attempt = 0; attempt < 30; attempt += 1) {
    if (!(await probe(directory))) return { stopped: true };
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Server did not stop in time.");
}

/** True when the module at this URL is the script Node was started with. */
export function isMain(url) {
  return Boolean(process.argv[1]) && url === pathToFileURL(fs.realpathSync(process.argv[1])).href;
}

/** The shared component library is locked per user, outside the skill directory. */
export function libraryLockPath() {
  fs.mkdirSync(BASE, { mode: 0o700, recursive: true });
  return path.join(BASE, ".library-" + createHash("sha256").update(SKILL).digest("hex").slice(0, 16) + ".lock");
}

const usage = `Usage: node dashboard.mjs <command> --session <key-or-directory> [options]

Commands:
  start    [--title <text>] [--goal <text>] [--lang <tag>] [--open]
                                                       Create or resume a session and its server.
  update   [--file <patch.json>]                       Apply a JSON patch from a file or stdin.
  activity [--done]                                    Mark the dashboard agent as working, or done.
  status                                               Show the state and server health.
  stop                                                 Stop this session's server.
  export   --output <new-file.html>                    Write a standalone offline snapshot.

--session takes a stable chat key or the absolute session directory returned by start.`;

function parseArguments(argv) {
  const [command, ...rest] = argv;
  const options = {};
  for (let index = 0; index < rest.length; index += 1) {
    const name = rest[index];
    if (name === "--open" || name === "--done") {
      options[name.slice(2)] = true;
    } else if (["--session", "--title", "--goal", "--lang", "--file", "--output"].includes(name) && index + 1 < rest.length) {
      options[name.slice(2)] = rest[++index];
    } else {
      throw new Error("Unknown or incomplete option: " + name + "\n" + usage);
    }
  }
  if (!["start", "serve", "update", "activity", "status", "stop", "export"].includes(command)) throw new Error(usage);
  if (!options.session) throw new Error("--session is required.\n" + usage);
  return { command, options };
}

async function main() {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    console.log(usage);
    return;
  }
  const { command, options } = parseArguments(process.argv.slice(2));
  let result;
  if (command === "start") {
    result = await start(options);
  } else {
    const directory = session(options.session);
    if (command === "serve") return serve(directory);
    if (command === "update") {
      const source = !options.file || options.file === "-" ? fs.readFileSync(0, "utf8") : fs.readFileSync(options.file, "utf8");
      result = update(directory, JSON.parse(source));
    } else if (command === "activity") {
      result = activity(directory, options.done);
    } else if (command === "status") {
      const info = await probe(directory);
      result = { session: directory, running: Boolean(info), url: info ? info.url : null, state: read(path.join(directory, "state.json")) };
    } else if (command === "stop") {
      result = await stop(directory);
    } else {
      if (!options.output) throw new Error("--output is required.");
      const output = path.resolve(options.output.replace(/^~(?=\/)/, os.homedir()));
      if (fs.existsSync(output)) throw new Error("Export already exists; choose a new filename.");
      fs.mkdirSync(path.dirname(output), { recursive: true });
      atomic(output, render(directory));
      result = { output };
    }
  }
  console.log(JSON.stringify(result));
}

if (isMain(import.meta.url)) {
  main().catch((error) => {
    console.error("dashboard: " + (error.message ?? error));
    process.exit(1);
  });
}
