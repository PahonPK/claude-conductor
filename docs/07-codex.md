# 07 — ใช้ framework นี้กับ OpenAI Codex

> framework นี้ใช้ได้ทั้ง **Claude Code** และ **OpenAI Codex (CLI)** — แกนกลางที่ agent อ่าน
> (`AGENTS.md`, `skills/`, `codex/agents/*.toml`) เป็นภาษาอังกฤษและใช้ร่วมกันทั้งสองฝั่ง
> เอกสารนี้อธิบาย: Claude ↔ Codex map กันยังไง · Codex ขาดอะไร · ติดตั้งยังไง · smoke test ทีละขั้น
> ข้อเท็จจริงฝั่ง Codex อ้างอิง Codex CLI 0.162 (ต.ค. 2026) — version ใหม่กว่านี้อาจเปลี่ยน

---

## 1. Mapping: Claude Code ↔ Codex

| สิ่งที่ framework ต้องการ | Claude Code | Codex |
|---|---|---|
| Global rules | `~/.claude/CLAUDE.md` (บรรทัดแรก `@AGENTS.md`) + `~/.claude/AGENTS.md` | `$CODEX_HOME/AGENTS.md` (`CODEX_HOME` default `~/.codex`; ถ้ามี `AGENTS.override.md` ตัวนั้นชนะ) |
| Project rules | `<repo>/CLAUDE.md` 1 บรรทัด `@AGENTS.md` + `<repo>/AGENTS.md` | `<repo>/AGENTS.md` (Codex เดินจาก repo root → cwd ทีละ dir แล้วต่อกัน; โปรเจกต์ต้อง **trusted**; รวมไม่เกิน 32 KiB) |
| Workspace context | `~/.claude/workspaces/<name>/AGENTS.md` (agent อ่านเองตาม Workspace registry) | `$CODEX_HOME/workspaces/<name>/AGENTS.md` (เหมือนกัน) |
| Memory dir | `~/.claude/projects/<slug>/memory/` (auto-memory dir ของ home) | `~/.codex/conductor-memory/` — **ไม่ใช่** `~/.codex/memories/` (นั่นคือ memory feature ที่ Codex generate เอง) |
| `MEMORY.md` โหลดอัตโนมัติ | เฉพาะ session ที่ cwd = HOME (auto-memory) | ไม่มี — hook inject บรรทัด Feedback ทุก session + `AGENTS.md` สั่งให้อ่านเอง |
| Hook config | `~/.claude/settings.json` | `~/.codex/hooks.json` (ต้อง **trust** ผ่าน `/hooks` ก่อนรัน; แก้ไฟล์ = hash เปลี่ยน = trust ใหม่) |
| SessionStart memory header | `memory-checkpoint.js SessionStart --agent claude` (header + daily-log tail + feedback; ข้าม feedback เมื่อ cwd = HOME) | `memory-checkpoint.js SessionStart --agent codex` (header + feedback เสมอ; ไม่มี daily log) |
| Daily log | `memory-extract.js` (PreCompact / SessionEnd) | ไม่มี — format session/rollout ของ Codex ยังไม่รู้ จึงไม่ติดตั้ง |
| กัน memory file เหลือ 0 byte | `memory-guard.js` SessionStart + PostToolUse `Write\|Edit\|Bash` (แจ้งเป็น plain text) | `memory-guard.js` SessionStart + PostToolUse **ไม่มี matcher** (= ทุก tool; ชื่อ tool ของ Codex ไม่ได้ document) — แจ้งเป็น JSON `additionalContext` |
| Skills | `~/.claude/skills/<name>/SKILL.md` → เรียก `/name` | `~/.agents/skills/<name>/SKILL.md` (home จริง ไม่ใช่ `CODEX_HOME`) → เรียก `$name` หรือเลือกจาก `/skills` (หรือ Codex เลือกเองจาก description) |
| Slash command เดิม (`commands/`) | ย้ายเป็น skills แล้ว | custom prompts (`~/.codex/prompts`) ถูกถอดออกจาก Codex แล้ว → skills เท่านั้น |
| Subagents | Agent tool + pin `model:` ทุกครั้ง | custom agents ใน `~/.codex/agents/*.toml` — Codex spawn subagent **เมื่อถูกสั่งเท่านั้น** (`AGENTS.md` / skill เป็นคนสั่ง) |
| Role → model | planner = Fable 5 · heavy worker + reviewer = Opus 5.5 · light worker = Sonnet | `planner` + `reviewer` = gpt-6-astra (high, read-only) · `worker-heavy` = gpt-6.1-sol (high) · `worker-light` = gpt-6-luna (medium) |
| Review step | reviewer agent (`model: opus`) ตัวใหม่ | agent `reviewer` หรือ built-in `/review` |
| Worktree | `EnterWorktree` (หลัง `git fetch`) | `git fetch` → `git worktree add ../<repo>-<task> -b <branch> origin/<default>` → เปิด `codex` ใน dir นั้น |
| เขียน memory นอก repo | ผ่าน permission ปกติของ Claude Code | sandbox `workspace-write` เขียนได้แค่ workspace + temp → ต้องเพิ่ม memory dir ใน `writable_roots` (หรือ `codex --add-dir`) |

---

## 2. สิ่งที่ Codex ไม่มี — และ framework ชดเชยยังไง

- **ไม่มี `@import`** → `AGENTS.md` ถูก copy ไปเป็นไฟล์เต็มที่ `$CODEX_HOME/AGENTS.md` (setup แทน path token ให้แล้ว) ไม่ใช่ import
- **ไม่มี auto-memory แบบ Claude** → `AGENTS.md` §Session start สั่งให้ agent อ่าน project memory + Feedback section ของ `MEMORY.md` + workspace file เอง และ SessionStart hook inject header + บรรทัด Feedback ให้ทุก session
- **ไม่มี `EnterWorktree`** → สร้าง worktree เองด้วย `git worktree add` แล้วเปิด codex ใน dir นั้น
- **ไม่มี daily log** → skill `memory-save` ข้าม source นี้ (curate จากบทสนทนา + memory file)
- **per-spawn model override ไม่ reliable** → ผูก model ไว้กับ custom agent TOML 4 ตัวแทน
- **hook ต้อง trust ก่อน** และ trust ผูกกับ hash → แก้ hook/`hooks.json` เมื่อไหร่ต้อง trust ใหม่
- event `Stop` ต้องการ JSON เมื่อ exit 0 → framework ไม่ผูก hook กับ `Stop`

> ทำงานอยู่**ใน repo claude-conductor เอง** → Codex จะอ่าน `AGENTS.md` ของ repo (template ที่ยังมี path token
> ไม่ถูกแทน) เป็น project doc ด้วย — เป็นเรื่องปกติ. โฟลเดอร์ `codex/` ตั้งชื่อไม่มีจุดนำหน้าโดยตั้งใจ
> เพื่อไม่ให้ Codex โหลด `hooks.json`/agents ที่ยังไม่ถูกแทน path เป็น repo config

---

## 3. ติดตั้ง

ต้องมี: Codex CLI, Node.js (hook รันด้วย `node`), git, PowerShell

```powershell
git clone <this-repo-url> claude-conductor
cd claude-conductor
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-codex.ps1 -DryRun   # ดูแผนก่อน ไม่แก้อะไร
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-codex.ps1           # ติดตั้ง (ถามให้พิมพ์ yes ก่อน)
```

> เรียกผ่าน `powershell -ExecutionPolicy Bypass -File` เพื่อให้รันได้บนเครื่องที่ execution policy ยังเป็นค่า default
> โดยไม่ต้องไปเปลี่ยน policy ของเครื่อง

คำสั่งที่เหลือในเอกสารนี้ใช้ตัวแปร 2 ตัว — ตั้งครั้งเดียวใน PowerShell ด้วย path ที่ `setup-codex.ps1` พิมพ์ไว้
(บรรทัด `Codex home` / `Memory dir`) หรือใช้ค่า fallback นี้:

```powershell
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "$env:USERPROFILE\.codex" }   # หรือ path "Codex home" ที่ installer พิมพ์
$Mem = "$CodexHome\conductor-memory"                                                        # หรือ path "Memory dir" ที่ installer พิมพ์ (ถ้าใช้ -MemoryDir)
```

`setup-codex.ps1` ทำ:
- `AGENTS.md` → `$CODEX_HOME\AGENTS.md` · `MEMORY_SCHEME.md`, `docs\`, `templates\` → `$CODEX_HOME\` (AGENTS.md ชี้ไปหา)
- `skills\*` → `$HOME\.agents\skills\` · `codex\agents\*.toml` → `$CODEX_HOME\agents\`
- `hooks\memory-checkpoint.js` + `hooks\memory-guard.js` → `$CODEX_HOME\hooks\` · `codex\hooks.json` → `$CODEX_HOME\hooks.json`
  (`hooks.json` ที่มี conductor hooks อยู่แล้ว = KEEP ไม่แตะ; `hooks.json` ที่มีแต่ hook อื่น **ไม่ทับ** — เขียน
  `hooks.conductor.json` ข้าง ๆ แล้วบอกวิธี merge)
- seed `MEMORY.md` + `SESSION-BOARD.md` (section ว่าง — ตัวอย่างอยู่ใน HTML comment) ลง memory dir เฉพาะเมื่อยังไม่มี
- แทน path token ในทุกไฟล์ที่ copy (path ทั้งหมดถูก normalize เป็น absolute ก่อน, เขียน UTF-8) · ไฟล์ที่มีอยู่แล้ว = skip
  (ใช้ `-Force` เพื่อ backup แล้วทับ; memory file ไม่ถูกทับเด็ดขาด)

`setup-codex.ps1` **ไม่แก้ `config.toml`** — มันพิมพ์ snippet ที่กรอก path จริงให้แล้ว เอาไป paste เอง
(หน้าตาประมาณนี้ แต่ใช้ path ที่ installer พิมพ์):

```toml
[sandbox_workspace_write]
writable_roots = ["C:\\Users\\<you>\\.codex\\conductor-memory"]
```

- ถ้ามี table `[sandbox_workspace_write]` อยู่แล้ว → เพิ่ม path เข้า `writable_roots` เดิม อย่าสร้าง table ซ้ำ (TOML error)
- ใช้กับ sandbox แบบ `workspace-write` · permission profiles (beta) ใช้ร่วมกับ `sandbox_mode` ไม่ได้
- ใน writable root, child dir ชื่อ `.git` `.agents` `.codex` `.aws` เป็น read-only — **ยังไม่ได้ยืนยัน**ว่า root ที่อยู่ใต้
  `~/.codex` เองโดนกฎนี้ไหม → ทดสอบการเขียนจริงใน smoke test ข้อ 8. ถ้าเขียนไม่ได้: (ก) เปิดด้วย
  `codex --add-dir "$Mem"` หรือ (ข) ติดตั้งใหม่ด้วย
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-codex.ps1 -Force -MemoryDir "$env:USERPROFILE\agent-memory"`
  แล้วแก้ `writable_roots` ตาม

**Windows / ภาษาไทย:** Windows PowerShell 5.1 `Get-Content` อ่าน UTF-8 ที่ไม่มี BOM เป็น ANSI code page
(CP874 บน Windows ไทย) → ไทยเพี้ยน. เปิดไฟล์ด้วย `Get-Content -Encoding UTF8` หรือใช้ `pwsh` (PowerShell 7)
— `AGENTS.md` สั่ง agent ไว้แล้วเหมือนกัน

---

## 4. Smoke test (ทำตามลำดับ)

1. **ติดตั้ง:** `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-codex.ps1` → สรุปท้ายต้องบอกจำนวนไฟล์ที่ copy +
   `2 memory seed(s) created` (ครั้งแรก) → ตั้ง `$CodexHome` / `$Mem` ตาม path ที่มันพิมพ์ (ดู §3)
2. **Paste config:** เอา snippet `[sandbox_workspace_write]` ที่ script พิมพ์ไป paste ใน `"$CodexHome\config.toml"` แล้ว save
3. **เตรียมข้อมูลทดสอบ:** เพิ่มบรรทัด Feedback ทดสอบ 1 บรรทัดใต้ `## Feedback` ใน memory index
   (`notepad "$Mem\MEMORY.md"`) ในรูปแบบ
   `- [Smoke test](./feedback-smoke-test.md) — smoke-test line, delete me`
4. **เปิด codex ใน repo ใดก็ได้** ที่เป็น git repo และ trust แล้ว: `cd C:\path\to\some-repo` → `codex`
5. **`/hooks`** → ต้องเห็น conductor hook 3 ตัว (`memory-checkpoint.js SessionStart`, `memory-guard.js SessionStart`,
   `memory-guard.js PostToolUse`) → trust ทั้ง 3 → ปิด codex แล้วเปิดใหม่ (ให้ SessionStart รันหลัง trust)
6. **ถาม:** `list the instruction sources and the memory/feedback injected at session start`
   → ต้องเห็น: global `AGENTS.md` จาก `$CODEX_HOME`, project `AGENTS.md` (ถ้า repo มี), ข้อความจาก hook
   `📌 No project memory matched cwd: ...` (หรือ `📌 Project memory loaded` ถ้า cwd ตรง mapping) และบรรทัด
   `Smoke test` จากข้อ 3 ใต้หัว `📚 Feedback lessons`
7. **`/skills`** → ต้องเห็น `memory-save`, `memory-recall`, `memory-consolidate`, `orchestrated-loop`, `ship`
8. **`$memory-save`** → repo ทดสอบไม่อยู่ใน mapping มันจะถามว่าจะ save ที่ไหน → ตอบให้ save เป็น
   `project-smoke-test.md` ใน memory dir → ตรวจว่าไฟล์เกิดจริง:
   `Get-ChildItem "$Mem"` (ถ้า sandbox ปฏิเสธ → ดู bullet เรื่อง writable root ใน §3)
9. **`/agents`** → ต้องเห็น `planner`, `reviewer`, `worker-heavy`, `worker-light`
10. *(optional)* **guard:**
    - (ก) ให้มี shadow ก่อน: หลัง `project-smoke-test.md` เกิดแล้ว ให้ codex รัน tool อะไรก็ได้อีก 1 ครั้ง (หรือปิดแล้ว
      เปิด codex ใหม่) — guard จะสร้าง shadow ของไฟล์ที่มีเนื้อหาเท่านั้น
    - (ข) ทำให้ไฟล์เหลือ 0 byte: `Clear-Content "$Mem\project-smoke-test.md"` แล้วให้ codex รัน tool อะไรก็ได้
    - (ค) ไฟล์ต้องกลับมา + มีบรรทัดใหม่ใน `Get-Content -Encoding UTF8 "$CodexHome\backups\memory-shadow\_restores.log"`
11. **เก็บกวาด:** ลบ `project-smoke-test.md` และบรรทัด Smoke test ใน `MEMORY.md`

---

## 5. Troubleshooting

- **hook ไม่ทำงาน** → `/hooks` ยังไม่ trust / แก้ไฟล์หลัง trust (ต้อง trust ใหม่) / `node` ไม่อยู่ใน PATH
- **context ที่ inject ถูกตัด** → เพิ่มค่า `additionalContextLimit` ใน `hooks.json` (ตั้งไว้ 16000; หน่วยไม่ได้ document)
  แล้ว trust ใหม่
- **`AGENTS.md` ไม่ถูกอ่าน** → มี `AGENTS.override.md` ใน `$CODEX_HOME` อยู่ (ชนะเสมอ) หรือ project ยังไม่ trusted (project doc ถูกข้าม)
- **เพิ่ม project ใหม่** → เพิ่มแถวใน Project mapping ของ `$CODEX_HOME\AGENTS.md` **และ** `PROJECT_MEMORY_MAP`
  ใน `$CODEX_HOME\hooks\memory-checkpoint.js` (แก้ hook = trust ใหม่)
- **เครื่องเดียวมีทั้ง Claude Code และ Codex** → default แยก memory dir กัน 2 ที่. อยากใช้ชุดเดียว:
  ติดตั้ง Codex ด้วย `-MemoryDir <memory dir ของ Claude>` แล้วเพิ่ม path นั้นใน `writable_roots`
