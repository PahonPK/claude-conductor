# 02 — Memory Protocol (ระบบ memory ทำงานยังไง)

> Source: §Memory Update Protocol ใน `../CLAUDE.md` + `../MEMORY_SCHEME.md`
> Memory คือวิธีที่ Claude "จำ" สถานะ project ข้าม session

---

## Base path + index

- **Base:** `~/.claude/projects/C--Users-you/memory/`
  (ในเครื่องจริง — ใน public framework นี้ดูตัวอย่างได้ที่ `../examples/memory/`)
  > หมายเหตุ: segment `C--Users-you` ผูกกับ home path ของเครื่องคุณ (เช่น `C:\Users\you`
  > → `C--Users-you`). ย้ายเครื่อง/เปลี่ยน username ต้องปรับ segment นี้ (ในไฟล์ `hooks/memory-checkpoint.js` + `hooks/memory-guard.js` — `setup.ps1` แทนให้อัตโนมัติ)
- **Index:** `MEMORY.md` — สารบัญของ memory file ทั้งหมด จัดกลุ่มตาม workspace
  แต่ละ entry = สถานะปัจจุบัน + critical pending เท่านั้น (≤ 3 บรรทัด)
- **ภาษา memory:** เขียนเนื้อหา memory เป็นภาษาเดียวที่ประหยัด token (เช่น English) แม้จะคุยกับ
  user เป็นภาษาอื่น · คงภาษาเดิมเฉพาะ term ที่แปลแล้วความหมายเพี้ยน (tax/legal/HR — gloss ได้) ·
  identifiers/code/path/links/frontmatter คงเดิม

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

> เพิ่ม project ใหม่ที่มี cwd ต้องมาเพิ่ม row ในตารางนี้ (ใน `../CLAUDE.md`) ด้วย
> — ดู `docs/04-onboarding-new-project.md`

---

## Session-start protocol

เมื่อเริ่ม session:
1. ถ้า cwd ตรงตาราง mapping → **READ memory file นั้นก่อน** ทำอย่างอื่น
   + READ workspace CLAUDE.md ตาม field `workspace:`
2. **Verify ก่อน trust** — เทียบ claim ใน memory กับ code จริง (`git status`,
   key files) อย่าเชื่อ memory ทันที
3. ถ้า field `Last verified` เก่ากว่า **5 วัน** → ต้อง run **verify recipe**
   (อยู่ใน project CLAUDE.md) ก่อนถือว่า memory เชื่อถือได้
4. **Commit-staleness:** header รูปแบบ `**Last verified:** <date> @ <commit>` — ถ้า `<commit>`
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

Manual triggers:
- **`/memory-save`** — อัปเดต memory file ด้วย state ปัจจุบัน (curate จาก daily
  log + context; แสดง diff ให้ confirm) — **targeted edit เฉพาะส่วนที่เปลี่ยน ไม่ rewrite ทั้งไฟล์**;
  drain §HANDOFF QUEUE ที่ target = ไฟล์นี้ (delete-iff-folded); machine-bump
  `**Last verified:** <date> @ <commit>`; flag ถ้า commit ตั้งแต่ save ครั้งก่อนแตะ path ของ project อื่น
  (อาจต้องเขียน HANDOFF — flag-only ไม่ block)
- **`/memory-recall`** — อ่าน memory + verify กับ code จริง ก่อนรายงาน — **pure read**:
  รายงานว่ามี HANDOFF ค้างได้ แต่ห้าม fold

Hooks (ไม่ได้แทนการ save เอง — ต้อง save ด้วยตัวเองตาม trigger ข้างบน):
- `hooks/memory-checkpoint.js` = **audit log เท่านั้น** (เขียน `events.jsonl`) + โหลด memory ตอน SessionStart (project memory ตาม cwd + บรรทัด `feedback-*` จาก global `MEMORY.md` — เพราะ Claude Code auto-load `MEMORY.md` เฉพาะ session ที่ cwd = HOME; session ใน project folder จะไม่เห็นบทเรียน global ถ้า hook ไม่ใส่ให้)
- `hooks/memory-guard.js` = **กัน memory file กลายเป็น 0 byte** — ทุก SessionStart + ทุก
  PostToolUse ของ Write/Edit/Bash: ไฟล์ที่มีเนื้อหา → refresh shadow copy ใน
  `~/.claude/backups/memory-shadow/`; ไฟล์ที่ 0 byte แต่ shadow มีเนื้อหา → restore + log ลง
  `_restores.log`. ที่มา: เคยมี memory file โดน truncate เหลือ 0 byte 2 ครั้ง (ครั้งแรกจาก script ที่
  เปิดไฟล์แบบ write mode ซึ่ง truncate ก่อนเขียน แล้ว write พัง). ตั้งใจให้เล็ก: last-good copy
  อย่างเดียว ไม่มี history/rotation — ถ้าไม่พอค่อยทำ versioning

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

ทุกไตรมาส → run **`/consolidate-memory`** เพื่อ merge ของซ้ำ, แก้ fact ที่ stale, prune index

---

## Memory file structure (สรุปจาก MEMORY_SCHEME.md)

แต่ละ project memory file มี frontmatter (`workspace:`, `name:`, `description:`,
`type:`, `originSessionId:`) + `Last verified: <date> @ <commit>` + `Verify rule` pointer +
sections: Current Status / Tech Stack / Key Decisions / Done / Pending Work
(template เต็มอยู่ใน `templates/project-memory.md.template` และ
`../MEMORY_SCHEME.md` §Templates)
