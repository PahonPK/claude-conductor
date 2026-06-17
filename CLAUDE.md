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

### ⚠️ Quality Standards (บังคับทุกครั้ง)
- **ห้ามบอกว่า "ถูกต้อง/เสร็จแล้ว" โดยไม่เปิดดูข้อมูลจริงข้างใน** — review = เปิดดูค่าข้างใน ไม่ใช่แค่ดูชื่อ (เช่น credential ต้องดู Name + Value)
- **ก่อน deploy/publish ต้อง validate เสมอ** — ใช้ validate tools, ดู execution log, ทดสอบจริงก่อนบอกว่าเสร็จ
- **ถ้าไม่แน่ใจ ให้ตรวจซ้ำ** — ดีกว่าบอกว่าถูกแล้วมาพังทีหลัง
- **Session ยาวใกล้ context เต็ม** → auto-save progress/decisions/pending ลง memory ทันที แล้วแนะนำเปิด session ใหม่
- **ห้าม over-engineer** — เลือกทางที่ง่ายที่สุดที่ใช้ได้ก่อน · "ทำน้อย" = ลดความซับซ้อนของ *solution* (ตัด speculative feature / premature abstraction / gold-plating) ไม่ใช่ลด rigor — verify/validate/review + quality gate ยังเข้มเต็มเสมอ และของที่ทำต้องถูกครบ · เพิ่ม machinery ใหม่ (hook/daemon/abstraction/ระบบใหม่) เฉพาะเมื่อมีหลักฐานว่าจำเป็นจริง ไม่ใช่เดาว่าจะได้ใช้ (YAGNI) · เจอปัญหาจริงค่อยทำ (เจอ collision จริง → ค่อยทำ guard) ไม่ preemptive · ไม่แน่ใจว่าควรสร้างไหม → ทำน้อยไว้ + เสนอ option ให้ user เลือก ดีกว่าสร้างเผื่อ

---

## 🎭 Orchestrator Workflow (บังคับทุก code task)

**Main Claude = orchestrator ไม่ใช่ implementer** — main thread เป็น decision maker + reviewer, agent เป็น executor (ลด context pollution + เพิ่ม quality gate + กัน "เห็นแล้วทำเลยทั้งที่ user ยังไม่ confirm")

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
- Verify claims vs code จริง (git status, key files) ก่อนเชื่อ; `Last verified` > 5 วัน → run verify recipe (ใน project CLAUDE.md) ก่อน trust

### Update memory ทันที (อย่ารอจบ session)
- Architectural decision / feature complete / deploy succeed / migration applied / pending เปลี่ยน / user สั่ง "remember"
- ระบบเตือน compaction ใกล้มา → **save ทันที** ก่อนทำ task อื่น
- State เปลี่ยน meaningful → update one-liner ใน MEMORY.md index ด้วย

### 📏 Size budgets (enforce ทุกครั้งที่ save — กัน index บวม)
- **MEMORY.md:** รวม ≤ 5 KB / entry ละ ≤ 3 บรรทัด (สถานะปัจจุบัน + critical pending เท่านั้น — **ห้ามใส่ changelog/commit history ใน index**)
- **Project memory file:** default ≤ 20 KB — เกินให้ย้าย history ไป `project-<name>-archive.md` (ไม่ auto-read). **Mega-project exception ≤ 40 KB** (โครงใหญ่หลาย sub-system) — ยัง compact history ไป archive ตามปกติ แค่เพดานสูงกว่า
- ทุกไตรมาส → run `/consolidate-memory`

### Manual triggers & hooks
- `/memory-save` (เขียนทับด้วย state ปัจจุบัน) · `/memory-recall` (อ่าน + verify กับ code จริง)
- Hook `~/.claude/hooks/memory-checkpoint.js` = audit log เท่านั้น (`events.jsonl`) — ไม่ใช่ตัวแทนการ update เอง

---

## 🤝 Inter-session Coordination (multi-session projects)

หลาย session ทำคู่ขนานบน project เดียว (เช่น 2 session แก้ codebase/DB เดียวกัน) → กันชน/ส่งต่อผ่าน board **on-demand**:
`~/.claude/projects/C--Users-you/memory/SESSION-BOARD.md` (IN-FLIGHT / RESERVATIONS / HANDOFF / CONTRACTS / MESSAGES) — **ไม่ auto-load** (อ่านเฉพาะตอนงานแตะ multi-session project)

**Resource ที่ share กัน 4 อย่าง (โต๊ะ / ตู้เอกสาร / ไวต์บอร์ดผนัง / สมุดจด) + วิธีกันชน:**
- **🗂️ Working tree (โต๊ะทำงาน):** ถ้ามี session อื่น **live บน repo เดียวกันจริง ๆ** (เช็ค IN-FLIGHT) → แต่ละ session ทำใน **git worktree ของตัวเอง** (โต๊ะแยก ใช้ object DB ก้อนเดียวกัน) กันอีก session มา `git checkout` แล้ว HEAD เด้งจนไฟล์ที่เรากำลังแก้หายจาก path. **session เดียวโดด ๆ ไม่ต้องตั้ง worktree** — ทำใน tree ปกติได้. ถ้าจะใช้ worktree: **เข้า worktree ก่อน** (EnterWorktree) **แล้วค่อย** create branch / spawn agent / start build — เพราะ agent + background bash ที่เปิดไป**ก่อน** switch จะ**ไม่**ตาม cwd ใหม่ (ยังชี้โต๊ะเดิม). *เผลอเริ่มใน master tree ไปแล้ว → STOP, `git stash`, EnterWorktree, `git stash pop` (stash อยู่ใน .git ที่ share กัน ข้าม worktree ได้), kill+respawn agent เก่า.* หมายเหตุ: worktree ต้อง setup + เป็นนิสัยเอง (ไม่ auto, SessionStart hook เรียกไม่ได้) และ**ไม่ได้แยก DB** — migration ยังเป็น global (ดูข้อ DB). มาตรฐาน = EnterWorktree (`.claude/worktrees/` + auto-branch); ถ้าต้องการ branch ชื่อเฉพาะ ใช้ worktree แบบ sibling-dir บน named branch ก็ได้ (`<repo>-<task>`) — ทั้งคู่ใช้ object DB เดียวกัน วินัย ref-space เหมือนกัน
- **🗄️ Git history (ตู้เอกสารกลาง):** append-only ปลอดภัยโดยธรรมชาติ + วินัย: **ห้าม `git checkout` branch ของ session อื่นใน tree ที่ share กัน**; อยากอ่าน branch อื่น → `git show <ref>:<path>`; เผยแพร่งาน → `git push` / ref-push (1 branch checkout ได้ใน worktree เดียวเท่านั้น). งานที่ commit แล้วมี ref ชี้อยู่เสมอ → ถึงหายจากโต๊ะก็กู้คืนได้
- **🧱 DB / live / shared schema (ไวต์บอร์ดผนัง):** worktree ไม่ช่วย — DB เป็น global. จอง board เหมือนเดิม (migration timestamp / shared table·RLS) + กฎใหม่ราคาถูก: **ก่อน `CREATE OR REPLACE` shared function/trigger → เปิดดู definition จริงบน live ก่อน** อย่า overwrite มืด ๆ (กัน guard ใน DB ที่ไม่ติดบน git ref ใด ๆ ถูกทับหายเงียบ)
- **📓 Project state (สมุดจดกลาง):** = project memory (MEMORY.md + project-*.md) เหมือนเดิม ไม่เปลี่ยน

**Board timing (กัน bureaucracy):** **READ board ทุกครั้งที่เริ่มงาน multi-session** — เช็ค IN-FLIGHT (lock) + CONTRACTS + MESSAGES. แต่ **RESERVE/lock เฉพาะตอนกำลังจะแตะ resource ที่ชนได้** (migration timestamp / branch / shared file·table·RLS / shared DB function) → จอง RESERVATIONS + เพิ่ม IN-FLIGHT (owner+วันที่) **ก่อน**ลงมือ; timestamp หยิบ "NEXT FREE" แล้ว bump. งานล้วน ๆ ใน worktree/tree ตัวเองที่ไม่แตะ shared → **ไม่ต้องลง board**
- **IN-FLIGHT ของ session อื่น = lock** — อย่าแตะ; จำเป็นต้องแตะ → ฝาก MESSAGES
- **เสร็จ:** ลบ IN-FLIGHT row + ปล่อย reservation **ทันที** (state ถาวรไป MEMORY.md/project file — board ไม่เก็บ state ซ้ำ); leftover worktree เก็บกวาดเองได้ (`git worktree prune` / ลบ dir เก่า — committed work ปลอดภัยบน ref อยู่แล้ว)
- **กัน stale:** row ค้าง > 3 วันไม่ update = ต้องสงสัย (verify ก่อนเชื่อ ไม่ใช่ lock จริง); prune ทุกครั้งที่เปิด; budget ≤ 6 KB
- *(optional)* ถ้ายังชนกันบ่อยจริง ค่อยพิจารณา PreToolUse guard hook ทีหลัง — ตอนนี้กฎเขียน + นิสัย worktree พอแล้ว

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
- **Backups** → `~/.claude/backups/`

---

*Template for the public claude-conductor. Replace the example workspaces/projects (AcmeCorp) with your own. See `docs/00-orientation.md`.*
