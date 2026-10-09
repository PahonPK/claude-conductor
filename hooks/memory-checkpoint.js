#!/usr/bin/env node
/**
 * memory-checkpoint.js
 * Stage 1 (hot path): sync entry point for SessionStart / PreCompact / SessionEnd hooks.
 *
 * - SessionStart: read project memory file (per cwd mapping), emit additionalContext.
 * - PreCompact / SessionEnd: append events.jsonl, spawn detached memory-extract.js worker
 *   (Claude Code only - Codex wires SessionStart only).
 *
 * Usage: node memory-checkpoint.js <EventName> [--agent claude|codex]   (default: claude)
 *   claude - Feedback lines are skipped when cwd == HOME (Claude auto-loads MEMORY.md there);
 *            the daily-log tail is included.
 *   codex  - Feedback lines are always injected (Codex has no auto-memory); no daily log.
 *
 * Paths: agent home = the dir that holds this hooks/ dir (~/.claude or $CODEX_HOME).
 *        Memory dir = the path setup.ps1 / setup-codex.ps1 baked in below - the same path they
 *        write into AGENTS.md and the skills, so hooks and instructions never disagree.
 *
 * Hard rules:
 *   - Must complete in <5s. Do NOT wait for child.
 *   - Recursion guard via CLAUDE_INVOKED_BY env var.
 *   - Never throw — always exit 0.
 *   - DO NOT use systemMessage in output — use hookSpecificOutput.additionalContext only.
 */

"use strict";

if (process.env.CLAUDE_INVOKED_BY) process.exit(0);

const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawn } = require("child_process");

const HOME = os.homedir();
const ARGS = process.argv.slice(2);
const AGENT_FLAG = ARGS.indexOf("--agent");
const IS_CODEX = AGENT_FLAG >= 0 && ARGS[AGENT_FLAG + 1] === "codex";
const EVENT_NAME =
  ARGS.find((a, i) => !a.startsWith("--") && !(AGENT_FLAG >= 0 && i === AGENT_FLAG + 1)) || "Unknown";
const AGENT_HOME = path.dirname(__dirname);
const LOG_DIR = path.join(AGENT_HOME, "memory-checkpoints");
const EVENTS_LOG = path.join(LOG_DIR, "events.jsonl");
const DAILY_DIR = path.join(LOG_DIR, "daily");
// setup.ps1 / setup-codex.ps1 substitute the token at install time.
const MEMORY_DIR = path.normalize("{{MEMORY_DIR}}");
const EXTRACT_SCRIPT = path.join(__dirname, "memory-extract.js");

// Canonical mapping: cwd segment → memory file.
// EXAMPLE rows — replace with your own projects (keep in sync with the
// §Project mapping table in AGENTS.md). See examples/ for a filled-in instance.
const PROJECT_MEMORY_MAP = {
  "acme-erp": "project-acme-erp.md",
  "acme-web": "project-acme-web.md",
  "acme-automation": "project-acme-automation.md",
};

function safeAppendEvent(obj) {
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.appendFileSync(EVENTS_LOG, JSON.stringify(obj) + "\n");
  } catch (_) {
    // never throw
  }
}

function resolveMemoryFile(cwd) {
  if (!cwd) return null;
  const norm = String(cwd).replace(/\\/g, "/");
  const segments = norm.split("/").filter(Boolean);
  // First matching segment wins (current keys have no overlap, so order is irrelevant in practice).
  for (const seg of segments) {
    if (PROJECT_MEMORY_MAP[seg]) {
      return path.join(MEMORY_DIR, PROJECT_MEMORY_MAP[seg]);
    }
  }
  return null;
}

function readStdinSync() {
  try {
    if (process.stdin.isTTY) return "";
    const buf = fs.readFileSync(0, "utf8");
    return buf;
  } catch (_) {
    return "";
  }
}

function readFirstLines(file, n) {
  try {
    const data = fs.readFileSync(file, "utf8");
    return data.split(/\r?\n/).slice(0, n).join("\n");
  } catch (_) {
    return "";
  }
}

function readLastLines(file, n) {
  try {
    const data = fs.readFileSync(file, "utf8");
    const lines = data.split(/\r?\n/);
    return lines.slice(Math.max(0, lines.length - n)).join("\n");
  } catch (_) {
    return "";
  }
}

function todayDailyPath() {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return path.join(DAILY_DIR, `${yyyy}-${mm}-${dd}.md`);
}

function yesterdayDailyPath() {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return path.join(DAILY_DIR, `${yyyy}-${mm}-${dd}.md`);
}

function extractLastVerified(text) {
  // "**Last verified:** YYYY-MM-DD" — the date may itself be bolded
  const m = text.match(/\*\*Last verified:\*\*\s*\**([0-9]{4}-[0-9]{2}-[0-9]{2})/);
  return m ? m[1] : null;
}

// Feedback lessons are indexed in the global MEMORY.md, which Claude Code only
// auto-loads when the session cwd is HOME — inject them into every other session.
// Codex never auto-loads it, so Codex always gets them.
function feedbackIndexBlock(cwd) {
  try {
    if (!IS_CODEX && path.resolve(cwd).toLowerCase() === path.resolve(HOME).toLowerCase()) return "";
    const lines = fs
      .readFileSync(path.join(MEMORY_DIR, "MEMORY.md"), "utf8")
      .split(/\r?\n/)
      .filter((l) => /\]\(\.\/feedback-[^)]+\.md\)/.test(l));
    if (!lines.length) return "";
    return [
      "",
      "📚 Feedback lessons (global — apply to every project; files in " + MEMORY_DIR + "):",
      ...lines,
    ].join("\n");
  } catch (_) {
    return "";
  }
}

function spawnExtractor(eventName, inputJsonStr) {
  try {
    if (!fs.existsSync(EXTRACT_SCRIPT)) return;
    const env = Object.assign({}, process.env, {
      CHECKPOINT_INPUT_JSON: inputJsonStr,
      CLAUDE_INVOKED_BY: "1",
    });
    const child = spawn(process.execPath, [EXTRACT_SCRIPT, eventName], {
      detached: true,
      stdio: "ignore",
      env,
      windowsHide: true,
    });
    child.unref();
  } catch (e) {
    safeAppendEvent({
      timestamp: new Date().toISOString(),
      event: "spawn_error",
      error: String(e && e.message || e),
    });
  }
}

function handleSessionStart(input) {
  const cwd = input.cwd || process.cwd();
  const sessionId = input.session_id || "unknown";
  const memoryFile = resolveMemoryFile(cwd);

  let additionalContext = "";

  if (memoryFile && fs.existsSync(memoryFile)) {
    const lastVerified = extractLastVerified(readFirstLines(memoryFile, Infinity)) || "unknown";

    let stalenessNote = "";
    if (lastVerified !== "unknown") {
      try {
        const verifiedMs = new Date(lastVerified + "T00:00:00Z").getTime();
        const ageDays = Math.floor((Date.now() - verifiedMs) / (1000 * 60 * 60 * 24));
        if (ageDays > 5) {
          stalenessNote = ` (⚠️ ${ageDays} days old — RUN VERIFY RECIPE before trusting claims)`;
        }
      } catch (_) {}
    } else {
      stalenessNote = " (⚠️ no Last verified field — run verify recipe)";
    }

    const header = [
      "📌 Project memory loaded",
      "File: " + memoryFile,
      "Last verified: " + lastVerified + stalenessNote,
      "⚠️ If Last verified > 5 days old, RUN VERIFY RECIPE (see project AGENTS.md) before trusting claims.",
    ];

    if (IS_CODEX) {
      // No daily log on Codex (memory-extract.js is Claude-only).
      additionalContext = header.join("\n");
    } else {
      const todayLog = todayDailyPath();
      const yLog = yesterdayDailyPath();
      let dailyTail = "";
      if (fs.existsSync(todayLog)) {
        dailyTail = readLastLines(todayLog, 40);
      } else if (fs.existsSync(yLog)) {
        dailyTail = readLastLines(yLog, 40);
      }
      const dailyBlock = dailyTail.trim() ? dailyTail : "(no recent log)";
      additionalContext = header.concat(["", "Recent activity (daily log):", dailyBlock]).join("\n");
    }
  } else {
    additionalContext = [
      "📌 No project memory matched cwd: " + cwd,
      "(canonical mapping in " + path.join(AGENT_HOME, "AGENTS.md") + " → Memory protocol → Project mapping)",
    ].join("\n");
  }
  additionalContext += feedbackIndexBlock(cwd);

  // Emit hookSpecificOutput JSON
  try {
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "SessionStart",
          additionalContext: additionalContext,
        },
      }),
    );
  } catch (_) {}

  safeAppendEvent({
    timestamp: new Date().toISOString(),
    event: "SessionStart",
    sessionId: sessionId,
    cwd: cwd,
    memoryFile: memoryFile,
  });
}

function handleCheckpointEvent(eventName, input, rawJson) {
  const cwd = input.cwd || process.cwd();
  const sessionId = input.session_id || "unknown";
  const transcriptPath = input.transcript_path || "";

  safeAppendEvent({
    timestamp: new Date().toISOString(),
    event: eventName,
    sessionId: sessionId,
    cwd: cwd,
    transcriptPath: transcriptPath,
  });

  if (transcriptPath && fs.existsSync(transcriptPath)) {
    spawnExtractor(eventName, rawJson);
  }
}

function main() {
  const eventName = EVENT_NAME;
  let raw = "";
  let input = {};
  try {
    raw = readStdinSync();
    if (raw) {
      try {
        input = JSON.parse(raw);
      } catch (_) {
        input = {};
      }
    }
  } catch (e) {
    safeAppendEvent({
      timestamp: new Date().toISOString(),
      event: "stdin_error",
      error: String(e && e.message || e),
    });
  }

  try {
    if (eventName === "SessionStart") {
      handleSessionStart(input);
    } else if (eventName === "PreCompact" || eventName === "SessionEnd") {
      handleCheckpointEvent(eventName, input, raw || JSON.stringify(input));
    } else {
      safeAppendEvent({
        timestamp: new Date().toISOString(),
        event: "unknown_event",
        eventName: eventName,
      });
    }
  } catch (e) {
    safeAppendEvent({
      timestamp: new Date().toISOString(),
      event: "main_error",
      error: String(e && e.message || e),
      stack: String(e && e.stack || ""),
    });
  }
  process.exit(0);
}

main();
