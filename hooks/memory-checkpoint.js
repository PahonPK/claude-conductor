#!/usr/bin/env node
/**
 * memory-checkpoint.js
 * Stage 1 (hot path): sync entry point for SessionStart / PreCompact / SessionEnd hooks.
 *
 * - SessionStart: read project memory file (per cwd mapping), emit additionalContext.
 * - PreCompact / SessionEnd: append events.jsonl, spawn detached memory-extract.js worker.
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
const LOG_DIR = path.join(HOME, ".claude", "memory-checkpoints");
const EVENTS_LOG = path.join(LOG_DIR, "events.jsonl");
const DAILY_DIR = path.join(LOG_DIR, "daily");
// NOTE: the "C--Users-you" segment is derived from your home path
// (Claude replaces separators/colon with '-', e.g. C:\Users\you -> C--Users-you).
// Change it to match YOUR home path on first setup.
const MEMORY_DIR = path.join(
  HOME,
  ".claude",
  "projects",
  "C--Users-you",
  "memory",
);
const EXTRACT_SCRIPT = path.join(HOME, ".claude", "hooks", "memory-extract.js");

// Canonical mapping: cwd segment → memory file.
// EXAMPLE rows — replace with your own projects (keep in sync with the
// §Project mapping table in CLAUDE.md). See examples/ for a filled-in instance.
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

function extractLastVerified(headerText) {
  // Look for "**Last verified:** YYYY-MM-DD" near the top
  const m = headerText.match(/\*\*Last verified:\*\*\s*([0-9]{4}-[0-9]{2}-[0-9]{2})/);
  return m ? m[1] : null;
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
    const headerText = readFirstLines(memoryFile, 80);
    const lastVerified = extractLastVerified(headerText) || "unknown";

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

    const todayLog = todayDailyPath();
    const yLog = yesterdayDailyPath();
    let dailyTail = "";
    if (fs.existsSync(todayLog)) {
      dailyTail = readLastLines(todayLog, 40);
    } else if (fs.existsSync(yLog)) {
      dailyTail = readLastLines(yLog, 40);
    }
    const dailyBlock = dailyTail.trim() ? dailyTail : "(no recent log)";

    additionalContext = [
      "📌 Project memory loaded",
      "File: " + memoryFile,
      "Last verified: " + lastVerified + stalenessNote,
      "⚠️ If Last verified > 5 days old, RUN VERIFY RECIPE (see project CLAUDE.md) before trusting claims.",
      "",
      "Recent activity (daily log):",
      dailyBlock,
    ].join("\n");
  } else {
    additionalContext = [
      "📌 No project memory matched cwd: " + cwd,
      "(canonical mapping in ~/.claude/CLAUDE.md → Memory Update Protocol)",
    ].join("\n");
  }

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
  const eventName = process.argv[2] || "Unknown";
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
