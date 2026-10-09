# 02 — Memory Protocol (ระบบ memory ทำงานยังไง)

> Source: §Memory protocol ใน `../AGENTS.md` + `../MEMORY_SCHEME.md`
> Memory คือวิธีที่ agent "จำ" สถานะ project ข้าม session

---

## Memory dir + index

- **Memory dir** (setup ใส่ path จริงแทน token ใน `AGENTS.md` ให้):
  - Claude Code: `~/.claude/projects/<slug>/memory/` — auto-memory dir ของ home folder;
    `<slug>` = home path ที่ทุกตัวอักษรที่ไม่ใช่ A-Z/a-z/0-9 ถูกแทนด้วย `-` (`C:\Users\john.doe` →
    `C--Users-john-doe`), `setup.ps1` คำนวณให้
  - Codex: `~/.codex/conductor-memory/` (ไม่ใช่ `~/.codex/memories/` ซึ่งเป็น memory feature ของ Codex เอง)
  - ใน public framework นี้ดูตัวอย่างได้ที่ `../examples/memory/`
- **Index:** `MEMORY.md` — สารบัญของ memory file ทั้งหมด จัดกลุ่มตาม workspace
  แต่ละ entry = สถานะปัจจุบัน + critical pending เท่านั้น (≤ 3 บรรทัด) · มี section **Feedback**
  ที่ list บทเรียน global (`feedback-*.md`) — setup seed ไฟล์ตั้งต้นให้ (`templates/MEMORY.md.template`)
- **ภาษา memory:** เขียนเนื้อหา memory เป็นภาษาเดียวที่ประหยัด token (English) แม้จะคุยกับ
  user เป็นภาษาอื่น · คงภาษาเดิมเฉพาะ term ที่แปลแล้วความหมายเพี้ยน (tax/legal/HR — gloss ได้) ·
  identifiers/code/path/links/frontmatter คงเดิม
- **Codex sandbox:** memory dir อยู่นอก repo → ต้องอยู่ใน `writable_roots` (หรือ `codex --add-dir`) ไม่งั้นเขียนไม่ได้ —
  ถูกปฏิเสธเมื่อไหร่ agent ต้องหยุดแจ้ง user ห้ามไป save ที่อื่น (ดู `docs/07-codex.md`)

---

## Project mapping (cwd segment → memory file)

เมื่อเปิด session ใน working directory ที่ path **มี segment** ตรงกับตารางนี้
ให้ผูกกับ memory file นั้นทันที:

ตารางตัวอย่าง (AcmeCorp) — แทนด้วย project จริงของคุณ:

| cwd มี segment | memory file | workspace |
|---|---|---|
| `acme-erp` | `project-acme-erp.md` | acme-corp |
| `acme-automation` | `project-acme-automation.md` | acme-corp |
| `acme-web` | `project-acme-web.md` | acme-snacks |

> เพิ่ม project ใหม่ที่มี cwd ต้องเพิ่ม row ใน 2 ที่ให้ตรงกัน: ตารางใน `AGENTS.md` ที่ติดตั้งแล้ว +
> `PROJECT_MEMORY_MAP` ใน `hooks/memory-checkpoint.js` — ดู `docs/04-onboarding-new-project.md`

---

## Session-start protocol

hook inject ได้แค่ "header" — **การอ่านจริงเป็นหน้าที่ของ agent** (`AGENTS.md` สั่งไว้ชัด เพราะ Codex
ไม่มี auto-memory เลย และ Claude auto-load `MEMORY.md` เฉพาะ session ที่ cwd = HOME):

1. ถ้า cwd ตรงตาราง mapping → **READ memory file นั้นก่อน** ทำอย่างอื่น
   + READ workspace file ตาม field `workspace:`
2. **READ section Feedback ของ `MEMORY.md`** (บทเรียน global) แล้วเปิดไฟล์บทเรียนที่เกี่ยวกับงาน
3. **Verify ก่อน trust** — เทียบ claim ใน memory กับ code จริง (`git status`,
   key files) อย่าเชื่อ memory ทันที
4. ถ้า field `Last verified` เก่ากว่า **5 วัน** → ต้อง run **verify recipe**
   (อยู่ใน project `AGENTS.md`) ก่อนถือว่า memory เชื่อถือได้
5. **Commit-staleness:** header รูปแบบ `**Last verified:** <date> @ <commit>` — ถ้า `<commit>`
   ≠ HEAD จริง (`git rev-parse HEAD`) หรือ ≠ commit ที่ body อ้าง → flag stale ห้าม trust body
   จนกว่าจะ verify (วันที่อย่างเดียวจับไม่ได้ว่ามีคน merge งานใหม่เข้ามาแล้ว)

---

## Save triggers — update memory ทันที (อย่ารอจบ session)

บันทึกทันทีเมื่อเกิดเหตุการณ์เหล่านี้:
- Architectural decision เกิดขึ้น
- Feature เสร็จ / deploy สำเร็จ / migration ถูก apply
- รายการ pending เปลี่ยน
- User สั่ง "remember"
- **ระบบเตือนว่า compaction ใกล้มา → save ทันที** ก่อนทำ task อื่น
- State เปลี่ยนแบบ meaningful → update one-liner ใน `MEMORY.md` index ด้วย

Skills (เรียก: Claude `/memory-save` · Codex `$memory-save` หรือเลือกจาก `/skills`):
- **`memory-save`** — อัปเดต memory file ด้วย state ปัจจุบัน (curate จากบทสนทนา + daily log ถ้ามี
  (Claude เท่านั้น); แสดง diff ให้ confirm) — **targeted edit เฉพาะส่วนที่เปลี่ยน ไม่ rewrite ทั้งไฟล์**;
  drain §HANDOFF QUEUE ที่ target = ไฟล์นี้ (delete-iff-folded); machine-bump
  `**Last verified:** <date> @ <commit>`; flag ถ้า commit ตั้งแต่ save ครั้งก่อนแตะ path ของ project อื่น
  (อาจต้องเขียน HANDOFF — flag-only ไม่ block)
- **`memory-recall`** — อ่าน memory + verify กับ code จริง ก่อนรายงาน — **pure read**:
  รายงานว่ามี HANDOFF ค้างได้ แต่ห้าม fold
- **`memory-consolidate`** — hygiene รายไตรมาส (ดูด้านล่าง)

Hooks (ไม่ได้แทนการ save เอง — ต้อง save ด้วยตัวเองตาม trigger ข้างบน):
- `hooks/memory-checkpoint.js` = **audit log** (`events.jsonl`) + inject ตอน SessionStart: header ของ
  project memory ตาม cwd + บรรทัด `feedback-*` จาก `MEMORY.md`
  - Claude (`--agent claude`): + tail ของ daily log; **ข้าม** บรรทัด feedback เมื่อ cwd = HOME (เพราะตรงนั้น
    Claude auto-load `MEMORY.md` อยู่แล้ว — session ใน project folder จะไม่เห็นบทเรียน global ถ้า hook ไม่ใส่ให้)
  - Codex (`--agent codex`): inject บรรทัด feedback **ทุก session** (ไม่มี auto-memory); ไม่มี daily log
- `hooks/memory-extract.js` (**Claude เท่านั้น**) = ตอน PreCompact/SessionEnd อ่าน transcript แล้วต่อท้าย
  daily log `~/.claude/memory-checkpoints/daily/YYYY-MM-DD.md` (source เสริมของ `memory-save`)
- `hooks/memory-guard.js` = **กัน memory file กลายเป็น 0 byte** — ทุก SessionStart + ทุก PostToolUse
  (Claude: Write/Edit/Bash · Codex: ทุก tool): ไฟล์ที่มีเนื้อหา → refresh shadow copy ใน
  `<agent home>/backups/memory-shadow/`; ไฟล์ที่ 0 byte แต่ shadow มีเนื้อหา → restore + log ลง
  `_restores.log` (Codex ได้ notice เป็น `additionalContext`). ที่มา: เคยมี memory file โดน truncate เหลือ
  0 byte 2 ครั้ง (ครั้งแรกจาก script ที่เปิดไฟล์แบบ write mode ซึ่ง truncate ก่อนเขียน แล้ว write พัง).
  ตั้งใจให้เล็ก: last-good copy อย่างเดียว ไม่มี history/rotation — ถ้าไม่พอค่อยทำ versioning
- path ของ memory dir ใน hook = path ที่ setup เขียนลงไปตอนติดตั้ง — ค่าเดียวกับที่เขียนใน `AGENTS.md` และ skills
  (แหล่งเดียว ไม่มี env override) จะย้าย memory dir = ติดตั้งใหม่ (Codex: `-MemoryDir`)

---

## Size budgets (บังคับ enforce ทุกครั้งที่ save — กัน index บวม)

| ไฟล์ | เพดาน | กฎ |
|---|---|---|
| **MEMORY.md** (index) | ≤ 20 KB รวม / **≤ 3 บรรทัดต่อ entry** | ใส่แค่สถานะปัจจุบัน + critical pending — **ห้ามใส่ changelog/commit history** |
| **Project memory file** (default) | ≤ 40 KB | เกิน → ย้าย history ไป `project-<name>-archive.md` (ไม่ auto-read) |
| **Project memory file** (mega-project) | ≤ 120 KB | ข้อยกเว้นสำหรับโครงใหญ่หลาย sub-system — ยัง compact history ไป archive ตามปกติ แค่เพดานสูงกว่า |
| **SESSION-BOARD.md** | ≤ 6 KB | prune row ที่ค้าง > 3 วันทุกครั้งที่เปิด (§HANDOFF QUEUE ยกเว้น) |

> ตัวเลขข้างบน = ค่าที่ maintainer ใช้หลังงานโตขึ้น (เดิม 5 / 20 / 40 KB) — ปรับตามขนาดงานได้
> สิ่งที่ห้ามเปลี่ยนคือ *มีเพดาน* และ history ย้ายไป archive

ทุกไตรมาส → run skill **`memory-consolidate`** เพื่อ merge ของซ้ำ, แก้ fact ที่ stale, prune index

---

## Memory file structure (สรุปจาก MEMORY_SCHEME.md)

แต่ละ project memory file มี frontmatter (`workspace:`, `name:`, `description:`,
`type:`, `originSessionId:`) + `Last verified: <date> @ <commit>` + `Verify rule` pointer +
sections: Current Status / Tech Stack / Key Decisions / Done / Pending Work
(template เต็มอยู่ใน `templates/project-memory.md.template` และ
`../MEMORY_SCHEME.md` §Templates)
