#!/usr/bin/env node
/**
 * memory-extract.js
 * Stage 2 (cold path / detached worker): parses transcript JSONL,
 * Jaccard-dedups against today's daily log tail, appends an extracted chunk.
 *
 * Spawned by memory-checkpoint.js with:
 *   env.CHECKPOINT_INPUT_JSON = original stdin JSON
 *   env.CLAUDE_INVOKED_BY    = "1"
 *   argv[2]                  = event name (PreCompact | SessionEnd)
 *
 * No 5s budget here — runs detached.
 * Always exit 0; log errors to events.jsonl.
 */

"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");
const readline = require("readline");

const HOME = os.homedir();
const LOG_DIR = path.join(HOME, ".claude", "memory-checkpoints");
const EVENTS_LOG = path.join(LOG_DIR, "events.jsonl");
const DAILY_DIR = path.join(LOG_DIR, "daily");
const STATE_FILE = path.join(LOG_DIR, "state.json");

const MAX_CHUNK_CHARS = 15000;
const MAX_EXCHANGES = 30;
const DEDUP_TAIL_LINES = 100;
const JACCARD_THRESHOLD = 0.7;

function safeAppendEvent(obj) {
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.appendFileSync(EVENTS_LOG, JSON.stringify(obj) + "\n");
  } catch (_) {}
}

function todayStamp() {
  const d = new Date();
  return (
    d.getFullYear() +
    "-" +
    String(d.getMonth() + 1).padStart(2, "0") +
    "-" +
    String(d.getDate()).padStart(2, "0")
  );
}

function todayDailyPath() {
  return path.join(DAILY_DIR, todayStamp() + ".md");
}

function readLastChars(file, charLimit) {
  try {
    const stat = fs.statSync(file);
    const fd = fs.openSync(file, "r");
    const len = Math.min(stat.size, charLimit);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, Math.max(0, stat.size - len));
    fs.closeSync(fd);
    return buf.toString("utf8");
  } catch (_) {
    return "";
  }
}

function readLastLinesOfFile(file, n) {
  try {
    if (!fs.existsSync(file)) return "";
    const tail = readLastChars(file, 200000);
    const lines = tail.split(/\r?\n/);
    return lines.slice(Math.max(0, lines.length - n)).join("\n");
  } catch (_) {
    return "";
  }
}

function tokenize(s) {
  return new Set(
    String(s || "")
      .toLowerCase()
      .split(/\s+/)
      .map((t) => t.replace(/[^\p{L}\p{N}_-]/gu, ""))
      .filter((t) => t.length > 0),
  );
}

function jaccard(a, b) {
  if (a.size === 0 && b.size === 0) return 0;
  let inter = 0;
  for (const t of a) if (b.has(t)) inter++;
  const uni = a.size + b.size - inter;
  return uni === 0 ? 0 : inter / uni;
}

function extractTextFromContent(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  const parts = [];
  for (const block of content) {
    if (!block || typeof block !== "object") continue;
    if (block.type === "text" && typeof block.text === "string") {
      parts.push(block.text);
    }
    // Skip tool_use, tool_result, image, etc. — too noisy
  }
  return parts.join("\n");
}

function parseTranscriptLine(line) {
  // Support both shapes:
  //   {role, content, ...}
  //   {type: "user"|"assistant", message: {role, content}}
  let obj;
  try {
    obj = JSON.parse(line);
  } catch {
    return null;
  }
  if (!obj || typeof obj !== "object") return null;

  let role = null;
  let content = null;

  if (obj.message && typeof obj.message === "object") {
    role = obj.message.role || obj.type || null;
    content = obj.message.content;
  } else if (obj.role) {
    role = obj.role;
    content = obj.content;
  } else if (obj.type === "user" || obj.type === "assistant") {
    role = obj.type;
    content = obj.content;
  }

  if (!role || (role !== "user" && role !== "assistant")) return null;

  const text = extractTextFromContent(content);
  if (!text || !text.trim()) return null;
  return { role: role, text: text };
}

async function readTranscriptMessages(transcriptPath) {
  const messages = [];
  return new Promise((resolve) => {
    let stream;
    try {
      stream = fs.createReadStream(transcriptPath, { encoding: "utf8" });
    } catch (e) {
      safeAppendEvent({
        timestamp: new Date().toISOString(),
        event: "extract_read_error",
        error: String(e && e.message || e),
      });
      return resolve(messages);
    }
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
    rl.on("line", (line) => {
      const m = parseTranscriptLine(line);
      if (m) messages.push(m);
    });
    rl.on("close", () => resolve(messages));
    rl.on("error", () => resolve(messages));
    stream.on("error", () => resolve(messages));
  });
}

function buildExchangesText(messages) {
  // Take last MAX_EXCHANGES messages (user+assistant). One "exchange" = one message.
  const tail = messages.slice(-MAX_EXCHANGES);
  const blocks = tail.map((m) => {
    const tag = m.role === "user" ? "**USER**" : "**ASSISTANT**";
    return tag + "\n" + m.text.trim();
  });
  let combined = blocks.join("\n\n");

  if (combined.length > MAX_CHUNK_CHARS) {
    // Cut on \n\n boundary closest to (but <=) MAX_CHUNK_CHARS, walking from end
    const slice = combined.slice(0, MAX_CHUNK_CHARS);
    const cut = slice.lastIndexOf("\n\n");
    if (cut > 0) combined = slice.slice(0, cut) + "\n\n[... truncated ...]";
    else combined = slice + "\n\n[... truncated ...]";
  }
  return combined;
}

function readState() {
  try {
    if (!fs.existsSync(STATE_FILE)) return { lastHash: {} };
    const j = JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
    if (!j.lastHash) j.lastHash = {};
    return j;
  } catch (_) {
    return { lastHash: {} };
  }
}

function writeState(state) {
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
  } catch (_) {}
}

async function run() {
  const eventName = process.argv[2] || "Unknown";
  let input = {};
  try {
    const raw = process.env.CHECKPOINT_INPUT_JSON || "";
    if (raw) input = JSON.parse(raw);
  } catch (e) {
    safeAppendEvent({
      timestamp: new Date().toISOString(),
      event: "extract_input_parse_error",
      error: String(e && e.message || e),
    });
  }

  const transcriptPath = input.transcript_path || "";
  const sessionId = input.session_id || "unknown";
  const cwd = input.cwd || "";

  if (!transcriptPath || !fs.existsSync(transcriptPath)) {
    safeAppendEvent({
      timestamp: new Date().toISOString(),
      event: "extract_skip_no_transcript",
      sessionId: sessionId,
      cwd: cwd,
      eventTrigger: eventName,
    });
    process.exit(0);
    return;
  }

  let messages = [];
  try {
    messages = await readTranscriptMessages(transcriptPath);
  } catch (e) {
    safeAppendEvent({
      timestamp: new Date().toISOString(),
      event: "extract_parse_error",
      error: String(e && e.message || e),
    });
    process.exit(0);
    return;
  }

  if (messages.length === 0) {
    safeAppendEvent({
      timestamp: new Date().toISOString(),
      event: "extract_skip_empty",
      sessionId: sessionId,
      cwd: cwd,
    });
    process.exit(0);
    return;
  }

  const body = buildExchangesText(messages);
  const ts = new Date().toISOString();

  const chunk = [
    "## Session " + sessionId + " — " + ts + " — " + eventName,
    "cwd: " + cwd,
    "",
    body,
    "",
    "---",
    "",
  ].join("\n");

  const dailyFile = todayDailyPath();
  fs.mkdirSync(DAILY_DIR, { recursive: true });

  // Jaccard dedup
  const existingTail = readLastLinesOfFile(dailyFile, DEDUP_TAIL_LINES);
  const newTokens = tokenize(chunk);
  const tailTokens = tokenize(existingTail);
  const sim = jaccard(newTokens, tailTokens);

  if (sim > JACCARD_THRESHOLD && existingTail.length > 0) {
    safeAppendEvent({
      timestamp: ts,
      event: "extract_dedup_skip",
      sessionId: sessionId,
      cwd: cwd,
      similarity: sim,
      dailyFile: dailyFile,
    });
    process.exit(0);
    return;
  }

  try {
    fs.appendFileSync(dailyFile, chunk);
  } catch (e) {
    safeAppendEvent({
      timestamp: ts,
      event: "extract_append_error",
      error: String(e && e.message || e),
    });
    process.exit(0);
    return;
  }

  const hash = crypto
    .createHash("sha256")
    .update(chunk)
    .digest("hex")
    .slice(0, 16);

  const state = readState();
  state.lastHash[dailyFile] = hash;
  writeState(state);

  safeAppendEvent({
    timestamp: ts,
    event: "extract_flush",
    sessionId: sessionId,
    cwd: cwd,
    eventTrigger: eventName,
    dailyFile: dailyFile,
    chunkChars: chunk.length,
    messages: messages.length,
    similarity: sim,
    hash: hash,
  });

  process.exit(0);
}

run().catch((e) => {
  safeAppendEvent({
    timestamp: new Date().toISOString(),
    event: "extract_unhandled_error",
    error: String(e && e.message || e),
    stack: String(e && e.stack || ""),
  });
  process.exit(0);
});
