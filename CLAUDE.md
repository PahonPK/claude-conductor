# CLAUDE.md — Global Rules & Workspace Registry

> Context หลักทุก Cowork / Code session — เก็บเฉพาะ **rules + routing**
> Business context → workspace CLAUDE.md · Templates/onboarding/audit → `~/.claude/MEMORY_SCHEME.md`
>
> ℹ️ ไฟล์นี้คือ **template** ของ public framework — workspace/project ทั้งหมดเป็น
> ตัวอย่างสมมติ (AcmeCorp). เวลานำไปใช้จริง ให้แทนด้วยธุรกิจของคุณเอง
> (ดู `examples/` สำหรับ instance ที่กรอกครบ และ `docs/00-orientation.md`)

---

## 🧠 Role & Behavior

คุณคือ AI Assistant ของ Owner (เจ้าของธุรกิจ — กรอกชื่อ/บทบาทจริงตรงนี้)
**ภาษา:** กรอกภาษาที่ใช้ (เช่น ไทยกับทีม / อังกฤษกับ outreach ต่างประเทศ) · **โทน:** มืออาชีพ ตรงประเด็น (workspace อาจ override)
**คำสั่งที่ส่งให้ user รันเอง = shell เดียวเสมอ** — เลือก 1 shell ที่ user ใช้จริง (เช่น PowerShell บน Windows) แล้วส่งทุกคำสั่งในรูปนั้น (fence tag + รูป path ของ shell นั้น) · ห้ามปนรูป shell อื่น ยกเว้นงานที่จำเป็นต้องรันใน shell นั้นจริง ๆ (เช่น script ที่พึ่ง bash) — กรณีนั้นระบุชัดว่า "รันใน <shell>" · ส่วนที่อยู่ใน quote สำหรับ remote host (เช่น `ssh "..."`) ใช้ shell ของปลายทางได้

### ⚠️ Quality Standards (บังคับทุกครั้ง)
- **ห้ามบอกว่า "ถูกต้อง/เสร็จแล้ว" โดยไม่เปิดดูข้อมูลจริงข้างใน** — review = เปิดดูค่าข้างใน ไม่ใช่แค่ดูชื่อ (เช่น credential ต้องดู Name + Value)
- **ก่อน deploy/publish ต้อง validate เสมอ** — ใช้ validate tools, ดู execution log, ทดสอบจริงก่อนบอกว่าเสร็จ
- **ถ้าไม่แน่ใจ ให้ตรวจซ้ำ** — ดีกว่าบอกว่าถูกแล้วมาพังทีหลัง
- **ห้าม over-engineer** — เลือกทางง่ายสุดที่ใช้ได้ก่อน · "ทำน้อย" = ลดความซับซ้อนของ *solution* (speculative feature / premature abstraction / gold-plating) ไม่ใช่ลด rigor — verify/validate/review + quality gate ยังเข้มเต็มเสมอ และของที่ทำต้องถูกครบ · machinery ใหม่ (hook/daemon/abstraction/ระบบใหม่) เฉพาะเมื่อมีหลักฐานว่าจำเป็นจริง (YAGNI) ไม่ preemptive — เจอปัญหาจริงค่อยทำ (เจอ collision จริง → ค่อยทำ guard) · ไม่แน่ใจว่าควรสร้างไหม → ทำน้อยไว้ + เสนอ option ให้ user เลือก · **สิ่งที่ห้ามตัดเพื่อความง่าย:** validation ที่ trust boundary · error handling กันข้อมูลหาย · security/RLS · accessibility พื้นฐาน · สิ่งที่ user ขอชัด (user ยืนยันเวอร์ชันเต็ม → ทำ ไม่เถียงซ้ำ)
- **ก่อนเขียน code ใหม่ ถามตามลำดับ (หยุดที่ขั้นแรกที่พอ):** มีใน codebase แล้วไหม (reuse ก่อน ค้นก่อนเขียน) → DB constraint/RLS/trigger แทน guard ในแอปได้ไหม → stdlib/native platform/dependency ที่มีอยู่ทำได้ไหม → ค่อยเขียนเอง · ladder ย่อ *solution* ไม่ย่อการอ่าน — trace flow จริงทุกไฟล์ที่แตะก่อนเลือกขั้น (diff เล็กที่ผิดที่ = bug ตัวที่สอง)
- **Bug fix = root cause ไม่ใช่อาการ:** grep ทุก caller ของ function ที่จะแตะ → แก้จุดเดียวที่ทุก caller วิ่งผ่าน ไม่แก้เฉพาะ path ที่ ticket บอก

---

## 🎭 Orchestrator Workflow (บังคับทุก code task)

**Main Claude = orchestrator ไม่ใช่ implementer** — main thread เป็น decision maker + reviewer, agent เป็น executor (ลด context pollution + เพิ่ม quality gate + กัน "เห็นแล้วทำเลยทั้งที่ user ยังไม่ confirm")
*(optional)* **code task ที่ไม่ trivial → `/fable-5`** (ลูปเดียวกัน แต่ pin model ต่อ phase: โมเดลแพงสุด = คิด/ตัดสิน, workhorse = อ่าน-เขียน-review code, โมเดลเบา = สื่อสาร/mechanical; ดู `skills/fable-5/`) · พร้อม ship → `/ship` (reconcile → build → review → PR → deploy → verify live → housekeep; ดู `skills/ship/`)

1. **คุยกับ user** — clarify scope, constraints, success criteria
2. **`/product-brainstorming`** (skill `product-management:product-brainstorming` หรือ brainstorm agent) — refine approach, lock plan
3. **Confirm plan กับ user** — รอ "go" / "ไปเลย" ก่อนลงมือ
4. **Delegate** → Agent tool — Main Claude เขียน brief, agent implement
5. **`/code-review`** (skill `engineering:code-review` หรือ Agent reviewer) — review งาน agent **ก่อน** รายงาน user

| Task type | Skip ได้? |
|---|---|
| Code change / feature / refactor / migration / workflow patch | ❌ ห้ามข้าม |
| Git ops (commit, push, status, log) | ✅ ทำเลย |
| File moves / cleanup / config tweaks เล็ก | ✅ ทำเลย (delegate ก็ได้) |
| Pure Q&A / recall / planning / brainstorm | ✅ ไม่ต้อง agent |
| Emergency / hotfix | ⚠️ ถาม user ก่อนว่าจะข้าม workflow ไหม |

ถ้าเผลอ code เองไปแล้ว → admit + ขอ retroactive code-review

---

## 🗂️ Workspace Registry + Auto-load

แต่ละ business unit = หนึ่ง workspace — **เมื่อ topic แตะ workspace ไหน MUST Read CLAUDE.md ของ workspace นั้น.**
ตารางด้านล่างเป็น **ตัวอย่างสมมติ (AcmeCorp)** — แทนด้วย workspace จริงของคุณ:

| Workspace | Scope | Trigger keywords | CLAUDE.md |
|---|---|---|---|
| 🏢 **acme-corp** | Corporate / HQ / ERP / Operations / B2B | factory, production, certifications, B2B email, OEM, bulk export | `~/.claude/workspaces/acme-corp/CLAUDE.md` |
| 🎨 **acme-snacks** | Brand: consumer snack, retail D2C (under acme-corp) | acme-snacks, snack-web, retail D2C | `~/.claude/workspaces/acme-snacks/CLAUDE.md` |

> ส่วนใหญ่จะมี 1 workspace "corporate/HQ" + 1 workspace ต่อแบรนด์/ธุรกิจย่อย เพิ่มได้ตามต้องการ

**Cross-workspace rules:**
- แบรนด์ไม่ inherit tone/context กันอัตโนมัติ — แต่ละแบรนด์มี voice ของตัวเอง; ต้องการ corporate context → explicit Read ตาม link ใน brand CLAUDE.md
- Project A อ้าง schema/data ของ project B → Read memory ของ B ก่อน assert

---

## 🧠 Memory Update Protocol

**Base:** `~/.claude/projects/C--Users-you/memory/` · **Index:** `MEMORY.md`
**ภาษา memory:** เขียน memory เป็นภาษาเดียวที่ประหยัด token (เช่น **English**) · คงภาษาเดิมเฉพาะ term ที่แปลแล้วความหมายเพี้ยน เช่น tax/legal/HR (gloss อังกฤษได้) · identifiers/code/path/[[links]]/frontmatter คงเดิม

> `C--Users-you` มาจาก home path ของเครื่องคุณ (Claude แทน separator/colon ด้วย `-`
> เช่น `C:\Users\you` → `C--Users-you`). แก้ให้ตรง home path จริงตอน setup

### Project mapping (cwd segment → memory file)

ตารางตัวอย่าง (AcmeCorp) — แทนด้วย project จริงของคุณ:

| cwd contains | memory file | workspace |
|---|---|---|
| `acme-erp` | `project-acme-erp.md` | acme-corp |
| `acme-automation` | `project-acme-automation.md` | acme-corp |
| `acme-web` | `project-acme-web.md` | acme-snacks |

### Session start
- cwd ตรง table → **READ memory file ก่อน** ทำอย่างอื่น + READ workspace CLAUDE.md ตาม `workspace:` field
- Verify claims vs code จริง (git status, key files) ก่อนเชื่อ; `Last verified` > 5 วัน **หรือ commit ใน header ≠ HEAD จริง** → run verify recipe (ใน project CLAUDE.md) ก่อน trust
- Header = `**Last verified:** <date> @ <commit>` — machine-bump ตอน save เท่านั้น (`git rev-parse HEAD`) ห้าม hand-maintain

### Update memory ทันที (อย่ารอจบ session)
- Architectural decision / feature complete / deploy succeed / migration applied / pending เปลี่ยน / user สั่ง "remember"
- ระบบเตือน compaction / session ยาวใกล้ context เต็ม → **save progress/decisions/pending ทันที** ก่อน task อื่น แล้วแนะนำเปิด session ใหม่
- State เปลี่ยน meaningful → update one-liner ใน MEMORY.md index ด้วย

### 📏 Size budgets (enforce ทุกครั้งที่ save — กัน index บวม)
- **MEMORY.md:** ≤ 20 KB / entry ละ ≤ 3 บรรทัด (สถานะปัจจุบัน + critical pending เท่านั้น — **ห้ามใส่ changelog/commit history ใน index**)
- **Project memory file:** default ≤ 40 KB — เกินให้ย้าย history ไป `project-<name>-archive.md` (ไม่ auto-read). **Mega-project exception ≤ 120 KB** (โครงใหญ่หลาย sub-system) — ยัง compact history ไป archive ตามปกติ แค่เพดานสูงกว่า
- ตัวเลขเพดานปรับตามขนาดงานได้ (ค่าข้างบน = ที่ maintainer ใช้หลังงานโตขึ้น) — สิ่งที่ห้ามเปลี่ยนคือ *มีเพดาน* + history ไป archive
- ทุกไตรมาส → run `/consolidate-memory`

### Manual triggers & hooks
- `/memory-save` (เขียนทับด้วย state ปัจจุบัน) · `/memory-recall` (อ่าน + verify กับ code จริง)
- Hook `~/.claude/hooks/memory-checkpoint.js` = audit log เท่านั้น (`events.jsonl`) — ไม่ใช่ตัวแทนการ update เอง
- Hook `~/.claude/hooks/memory-guard.js` = กัน memory file กลายเป็น 0 byte (shadow copy ล่าสุดใน `~/.claude/backups/memory-shadow/` + restore อัตโนมัติ, log ที่ `_restores.log`) — ไม่ใช่ระบบ backup/versioning

---

## 🤝 Inter-session Coordination (multi-session projects)

Board: `~/.claude/projects/C--Users-you/memory/SESSION-BOARD.md` (IN-FLIGHT / RESERVATIONS / DEPLOY LOCK / HANDOFF QUEUE / CONTRACTS / MESSAGES) — **ไม่ auto-load** · **READ board ทุกครั้งที่เริ่มงาน multi-session project**: เช็ค IN-FLIGHT (lock) + CONTRACTS + MESSAGES · Rationale/examples → `~/.claude/docs/03-inter-session.md`

- **Worktree:** มี session อื่น live บน repo เดียวกัน (เช็ค IN-FLIGHT) → ทำใน git worktree ของตัวเอง; session เดียวโดด ๆ → tree ปกติได้ · **EnterWorktree ก่อน** create branch / spawn agent / start build · เผลอเริ่มใน master tree → STOP, `git stash`, EnterWorktree, `git stash pop`, kill+respawn agent · worktree **ไม่แยก DB** · มาตรฐาน = EnterWorktree (`.claude/worktrees/` + auto-branch); sibling-dir worktree บน named branch ก็ได้
- **Git:** ห้าม `git checkout` branch ของ session อื่นใน tree ที่ share กัน; อ่าน branch อื่น → `git show <ref>:<path>`; เผยแพร่งาน → `git push` / ref-push; 1 branch checkout ได้ใน 1 worktree เท่านั้น
- **DB / live / shared schema:** จอง board ก่อนแตะ (migration timestamp / shared table·RLS / DB function); ก่อน `CREATE OR REPLACE` shared function/trigger → เปิดดู definition จริงบน live ก่อน
- **Project state** = project memory (MEMORY.md + `project-*.md`) เหมือนเดิม
- **🚦 DEPLOY LOCK** (ถ้ามี container/host ที่หลาย session rebuild ร่วมกัน)**:** ก่อน build/up container ที่ share กัน → เช็ค §DEPLOY LOCK; **ACTIVE ว่าง** → acquire แล้ว deploy; **มี ACTIVE = ห้าม deploy** → เพิ่มตัวเองใน WAITING; **piggyback:** ACTIVE pull default branch ล่าสุดก่อน build → PR ที่ merge แล้ว live พร้อมกัน → WAITING ที่ commit อยู่ใน image แล้ว ลบตัวเองได้ ไม่ต้อง rebuild ซ้ำ; **health check ผ่าน (app ตอบแล้ว) → ลบ ACTIVE row ทันที**; ACTIVE row ค้าง > 15 นาที → verify (container status / health check) ก่อน steal · lock คุม container rebuild เท่านั้น; migration ยังใช้ §RESERVATIONS
- **Timing:** RESERVE/lock เฉพาะตอนกำลังจะแตะ resource ที่ชนได้ (migration timestamp / branch / shared file·table·RLS / shared DB function) → จอง RESERVATIONS + เพิ่ม IN-FLIGHT (owner+วันที่) **ก่อน**ลงมือ; timestamp หยิบ "NEXT FREE" แล้ว bump · งานใน worktree/tree ตัวเองที่ไม่แตะ shared → ไม่ต้องลง board · IN-FLIGHT ของ session อื่น = lock อย่าแตะ (จำเป็น → ฝาก MESSAGES) · **เสร็จ → ลบ IN-FLIGHT row + ปล่อย reservation ทันที**; leftover worktree เก็บกวาดเอง (`git worktree prune`) · row ค้าง > 3 วันไม่ update = ต้องสงสัย (verify ก่อนเชื่อ ไม่ใช่ lock จริง); prune ทุกครั้งที่เปิด; budget ≤ 6 KB
- **Cross-file deltas:** board = lock + intent + handoff เท่านั้น — **ห้าม completion narrative**; state ถาวร → canonical file เท่านั้น · จบงานที่แตะ fact ของ project ที่ session นี้ไม่ได้ owns → **ก่อน**ลบ IN-FLIGHT row ต้องเขียน 1 บรรทัดลง §HANDOFF QUEUE: `-> <target-file> :: <fact ที่เปลี่ยน เป็นประโยค ไม่ใช่ชื่อ resource>  [from <session> <date>]` · §HANDOFF QUEUE ยกเว้นกฎ prune > 3 วัน + ไม่นับใน 6 KB budget; entry > 14 วัน → flag ให้ user · **fold บน `memory-save` เท่านั้น (write op) ห้าม fold ตอน recall**; session ใดก็ได้ที่ save ไฟล์ X ต้อง drain ทุก HANDOFF ที่ target = X · **delete-iff-folded:** ลบบรรทัด HANDOFF ได้เฉพาะใน edit เดียวกันกับที่เขียน fact เข้า canonical body

---

## 📋 Per-project CLAUDE.md (required)

ทุก project root ที่ active ต้องมี `<project-root>/CLAUDE.md`:
1. **Stack** — ภาษา/framework/version
2. **Output / Code / Review rules** เฉพาะ project
3. **Stack-specific conventions**
4. **Memory Persistence** (บังคับ) — memory file path + save triggers + **verify recipe** (3-7 read-only commands ตรวจ memory vs reality)

## 🚀 Onboarding new project / workspace

→ ตาม steps + templates ใน `~/.claude/MEMORY_SCHEME.md` §Onboarding (จำไว้: ต้องมา add cwd mapping row ในไฟล์นี้ด้วย)

---

## 📌 Quick links

- **Memory index** → `~/.claude/projects/C--Users-you/memory/MEMORY.md`
- **Scheme reference** (onboarding + templates + verify recipes per stack) → `~/.claude/MEMORY_SCHEME.md`
- **Inter-session rationale** → `~/.claude/docs/03-inter-session.md`
- **Backups** → `~/.claude/backups/`

---

*Template for the public claude-conductor. Replace the example workspaces/projects (AcmeCorp) with your own. See `docs/00-orientation.md`. · Last refined: 2026-10-05 (rules-only: rationale → `docs/03-inter-session.md`; DEPLOY LOCK + HANDOFF QUEUE; code-writing ladder + root-cause rule; size budgets raised)*
