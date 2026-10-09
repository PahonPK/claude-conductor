#!/usr/bin/env node
/**
 * memory-guard.js — keep the memory files from silently going to 0 bytes.
 *
 * WHY THIS EXISTS. In the maintainer's private instance, one project memory
 * file was truncated to 0 bytes twice within a week. The first time was a
 * script that opened the file in write mode (`open(path, 'w')`), which
 * truncates BEFORE it writes — the write then threw and left nothing behind.
 * The second had a different (never identified) cause while several sessions
 * were editing the same file. Both were recoverable only because an old
 * hand-made backup happened to exist.
 *
 * WHAT IT DOES, on SessionStart and on every PostToolUse for a tool that can
 * write files (Claude: settings.json, matcher Write|Edit|Bash; Codex: hooks.json,
 * no matcher = every tool):
 *   - any memory *.md with size > 0        -> refresh its shadow copy
 *   - any memory *.md with size 0, whose shadow is non-empty -> RESTORE it
 *     and print one line so the session is told
 *
 * Deliberately NOT a general backup system: one flat shadow dir, last-good
 * copy only, no history, no rotation, no config. Git-style versioning of the
 * memory dir is the thing to build IF this proves insufficient — not before.
 *
 * SAFETY. A restore can only ever overwrite a 0-byte file, so the worst case
 * is resurrecting a file someone meant to empty; nothing else is ever written
 * over. Shadows are refreshed only from non-empty sources, so a truncation can
 * never propagate into the shadow. Every failure is swallowed: a hook that
 * throws must not break the tool call that triggered it.
 *
 * USAGE. node memory-guard.js [<EventName>] [--agent claude|codex]  (default: claude)
 *   claude - a restore notice is printed as plain text (unchanged behaviour).
 *   codex  - a restore notice is emitted as {"hookSpecificOutput":{"hookEventName":
 *            <EventName>,"additionalContext":...}}, valid for SessionStart and PostToolUse.
 *   Silent (no output) when nothing was restored, for both agents.
 * PATHS. Memory dir = $CONDUCTOR_MEMORY_DIR, else the path setup.ps1 / setup-codex.ps1
 * wrote in below. Shadow dir = <agent home>/backups/memory-shadow, where agent home is
 * the dir that holds this hooks/ dir (~/.claude or $CODEX_HOME).
 */

const fs = require("fs");
const path = require("path");

const ARGS = process.argv.slice(2);
const AGENT_FLAG = ARGS.indexOf("--agent");
const IS_CODEX = AGENT_FLAG >= 0 && ARGS[AGENT_FLAG + 1] === "codex";
const EVENT_NAME =
  ARGS.find((a, i) => !a.startsWith("--") && !(AGENT_FLAG >= 0 && i === AGENT_FLAG + 1)) || "SessionStart";

// setup.ps1 / setup-codex.ps1 substitute the token at install time.
const MEM = path.normalize(process.env.CONDUCTOR_MEMORY_DIR || "{{MEMORY_DIR}}");
const SHADOW = path.join(path.dirname(__dirname), "backups", "memory-shadow");

function main() {
  if (!fs.existsSync(MEM)) return;
  fs.mkdirSync(SHADOW, { recursive: true });

  const restored = [];

  for (const name of fs.readdirSync(MEM)) {
    if (!name.endsWith(".md")) continue;
    const live = path.join(MEM, name);
    const shadow = path.join(SHADOW, name);

    let liveStat;
    try {
      liveStat = fs.statSync(live);
    } catch {
      continue;
    }
    if (!liveStat.isFile()) continue;

    if (liveStat.size === 0) {
      // Truncated. Restore only if the shadow actually holds something.
      let shadowStat = null;
      try {
        shadowStat = fs.statSync(shadow);
      } catch {
        /* no shadow yet — nothing we can do for this one */
      }
      if (shadowStat && shadowStat.size > 0) {
        fs.copyFileSync(shadow, live);
        restored.push(`${name} (${shadowStat.size} bytes, shadow from ${shadowStat.mtime.toISOString()})`);
      }
      continue;
    }

    // Healthy: refresh the shadow, but only when the live file is actually
    // newer — this runs on every tool call, so skip the copy in the common
    // case where nothing changed.
    let shadowStat = null;
    try {
      shadowStat = fs.statSync(shadow);
    } catch {
      /* first time */
    }
    if (!shadowStat || liveStat.mtimeMs > shadowStat.mtimeMs) {
      fs.copyFileSync(live, shadow);
    }
  }

  if (restored.length) {
    const msg =
      "MEMORY GUARD: restored " +
      restored.length +
      " truncated memory file(s) from the shadow copy — " +
      restored.join("; ") +
      ". Re-read them before editing; whatever wrote 0 bytes is a bug worth finding.";

    // Two channels on purpose. stdout is the nice one, but a PostToolUse hook's
    // stdout is NOT reliably surfaced to the session (observed in practice: a
    // restore fired on a Bash call and printed nothing visible), so the durable
    // record is the log — that is what makes a silent restore auditable after
    // the fact. Grep it whenever a memory file looks wrong.
    if (IS_CODEX) {
      process.stdout.write(
        JSON.stringify({
          hookSpecificOutput: { hookEventName: EVENT_NAME, additionalContext: msg },
        })
      );
    } else {
      console.log(msg);
    }
    try {
      fs.appendFileSync(
        path.join(SHADOW, "_restores.log"),
        new Date().toISOString() + "  " + msg + "\n"
      );
    } catch {
      /* the restore already happened; losing the log entry must not undo it */
    }
  }
}

try {
  main();
} catch {
  // Never let a bookkeeping hook fail a real tool call.
}
