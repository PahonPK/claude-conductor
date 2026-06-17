# 03 — Inter-session Coordination (SESSION-BOARD.md + worktrees)

> Source: §Inter-session Coordination ใน `../CLAUDE.md`
> ใช้เฉพาะตอนมีหลาย session ทำงาน**คู่ขนาน**บน project เดียวกัน

---

## ปัญหาที่แก้

บางครั้งมีหลาย Claude session ทำงานพร้อมกันบน project เดียว (เช่น 2 session
แก้ codebase/DB เดียวกัน) — เสี่ยงชนกัน

**ศัพท์ git 2 คำที่ต้องเข้าใจก่อน (อธิบายด้วยภาพโต๊ะ/ตู้เอกสาร):**
- **HEAD** = ตัวชี้ว่า "ตอนนี้โต๊ะกำลังโชว์งานเวอร์ชันไหน". `git checkout <branch>` = สลับให้โต๊ะโชว์งานอีกชุด.
- **ref** = ป้ายชื่อที่ git ใช้ชี้ไปยังงานที่ **commit แล้ว** (branch ก็คือ ref ชนิดหนึ่ง). ตราบใดที่งานถูก commit มันมีป้ายชี้อยู่ใน **object DB = คลังเก็บงานทุกเวอร์ชันในตู้เอกสาร** เสมอ — ถึงจะหายจากหน้าโต๊ะก็กู้กลับมาได้

เคยมีเคส session หนึ่งกำลังแก้ migration file อยู่ อีก session `git checkout` อีก
branch ใน working tree เดียวกัน → โต๊ะสลับไปโชว์งานชุดอื่น (HEAD เด้ง) ไฟล์ของ
session แรก**หายไปจากหน้าโต๊ะ** (แต่ไม่ได้ถูกลบจริง — ยังอยู่ในตู้เอกสารบน ref; กู้คืน
ด้วย `git show <ref>:<path>` แล้ว push กลับ ไม่ได้ checkout). อีกเคส: trigger บน live DB
ถูก replace ทับจน guard เก่าหาย เพราะ guard นั้นอยู่ใน DB แต่ไม่ติดบน git ref ใด ๆ

---

## โมเดล: ของ share กัน 4 อย่าง แต่ละอย่างมี "ผู้ดูแล" คนเดียว

คิดเหมือนออฟฟิศที่หลายคนทำงานพร้อมกัน — มีของกลาง 4 ชิ้น:

| ของกลาง (analogy) | ความเสี่ยง | ผู้ดูแล / วิธีกัน |
|---|---|---|
| 🗂️ **Working tree** (โต๊ะทำงาน) | อีกคน checkout แล้ว HEAD เด้ง ไฟล์เราหายจากโต๊ะ | **worktree ของใครของมัน** (เฉพาะตอนมี session อื่น live) — โต๊ะแยก ใช้ตู้เอกสาร (object DB) ก้อนเดียวกัน |
| 🗄️ **Git history** (ตู้เอกสารกลาง) | checkout ทับ HEAD เพื่อน | append-only + วินัย ref (อ่านด้วย `git show`, เผยแพร่ด้วย `push`) |
| 🧱 **DB / live schema** (ไวต์บอร์ดผนัง) | จอง timestamp ชน / replace function ทับ guard | board reservation + **look-before-replace** |
| 📓 **Project state** (สมุดจดกลาง) | จำสถานะไม่ตรงกัน | project memory (MEMORY.md + project-*.md) — เหมือนเดิม |

---

## 1) 🗂️ Working tree → worktree ของใครของมัน

**worktree จำเป็นเฉพาะตอนมี session อื่น live บน repo เดียวกันจริง ๆ** (เช็ค IN-FLIGHT
บนบอร์ดก่อน) — เป็นเครื่องมือกันชน ไม่ใช่พิธีกรรมที่ต้องทำทุกครั้ง. **session เดียว
โดด ๆ ทำใน tree ปกติได้เลย ไม่ต้องตั้ง worktree.**

เมื่อมีหลาย session: แทนที่จะแย่งโต๊ะตัวเดียว (working tree เดียว) แต่ละ session เปิด
**git worktree ของตัวเอง** — ต่างคนต่างมีโต๊ะ แต่ยังใช้ตู้เอกสาร (object DB) ก้อน
เดียวกัน session อื่นจะมา checkout บนโต๊ะเราไม่ได้ ไฟล์ที่เรากำลังแก้เลยไม่หายจากโต๊ะ

**ลำดับสำคัญ — เข้า worktree ก่อน แล้วค่อยทำอย่างอื่น:**
1. `EnterWorktree` (สร้าง worktree ใต้ `.claude/worktrees/` บน branch ใหม่ + ย้าย
   **cwd = โฟลเดอร์ที่ session กำลังทำงานอยู่** เข้าไป)
2. **แล้วค่อย** create branch / สั่งผู้ช่วย (agent) / รัน build

> ⚠️ ถ้าเราสั่งให้ **ผู้ช่วย (agent)** หรือ **คำสั่งที่รันค้างไว้ (background bash)**
> เริ่มทำงาน *ก่อน* ย้ายเข้า worktree พวกมันจะยัง**จ่ออยู่ที่โต๊ะเดิม** ไม่ย้ายตามเรา
> → ไปแก้ผิดโต๊ะ. ดังนั้นเข้า worktree ให้เสร็จก่อน แล้วค่อยสั่งผู้ช่วย/รันคำสั่งยาว ๆ.
> (1 branch checkout ได้ใน worktree เดียวเท่านั้น)

**ถ้าเผลอเริ่มงานใน master tree ไปแล้ว (กฎ enter-first พลาด):**
1. STOP — อย่าสั่ง agent / รัน build เพิ่ม
2. ยังไม่ commit → `git stash` ใน master ก่อน (worktree ใหม่ default `fresh` แตกจาก
   origin/master จะไม่ลากงานที่ยัง uncommitted ติดไป)
3. `EnterWorktree`
4. ใน worktree → `git stash pop` ได้เลย (stash อยู่ใน `.git` ที่ share กัน ข้าม
   worktree ได้). ถ้าเป็นงานที่ commit ไปแล้วใน master → ดึงด้วย `git show <ref>:<path>`
   / cherry-pick ผ่าน object DB ที่ share กันแทน
5. agent / background bash ที่ spawn ไปก่อนเข้า worktree = ยังชี้ master → kill แล้ว
   spawn ใหม่หลังเข้า worktree

**ข้อควรรู้ (อย่าหลงคิดว่า worktree แก้ทุกอย่าง):**
- ไม่ใช่ของฟรี/auto — ต้อง **setup ครั้งเดียวต่อ repo + เป็นนิสัยที่ต้องทำเอง**
  (SessionStart hook เรียก EnterWorktree ไม่ได้)
- **ไม่ได้แยก DB** — migration ยังเป็น global side-effect → ยังต้องจอง board (ดูข้อ 3)
- เก็บกวาด: worktree ค้างลบเองได้ (`git worktree prune` / ลบ dir เก่า) —
  committed work ปลอดภัยบน ref ไม่ว่าจะลบ worktree ทิ้งหรือไม่
- **2 วิธีสร้าง worktree ใช้ได้ทั้งคู่:** มาตรฐาน = `EnterWorktree` (ใต้
  `.claude/worktrees/` + auto-branch ชื่อสุ่ม); ถ้าต้องการ **branch ชื่อเฉพาะ** ใช้
  worktree แบบ sibling directory บน named branch ก็ได้ (เช่น `<repo>-<task>`). ทั้งคู่
  ใช้ object DB เดียวกัน วินัย ref เหมือนกันเป๊ะ

**Setup ครั้งเดียวต่อ repo:**
- เพิ่ม `/.claude/worktrees/` ลง `.gitignore` ของ repo — **ถ้า `.claude/` ถูก track อยู่**
  การไม่ ignore จะทำให้ worktree ไป pollute `git status` / เสี่ยง commit ติดไป.
  (ignore เฉพาะ `/worktrees/` อย่า ignore ทั้ง `/.claude/` ไม่งั้นไฟล์ที่ track หลุด)
- เรื่อง base ของ worktree: `worktree.baseRef` default = `fresh` อยู่แล้ว = แตก branch
  จาก **origin/<default-branch>** (ไม่ใช่ local HEAD). ดังนั้น **`git fetch` ก่อน
  EnterWorktree เสมอ** ไม่งั้นแตกจาก remote-tracking ที่ stale. *(ไม่ต้องไปตั้ง
  baseRef=fresh — เป็น default; ถ้าจงใจอยากแตกจาก local HEAD ที่ยังไม่ push →
  `git config worktree.baseRef head`)*

## 2) 🗄️ Git history → วินัยการอ่าน/เผยแพร่งาน (ref)

ตู้เอกสารกลาง (commit / branch / object DB) เป็น append-only อยู่แล้ว ปลอดภัยโดย
ธรรมชาติ — แต่มีวินัย 3 ข้อ:
- **ห้าม `git checkout` branch ของ session อื่นใน tree ที่ share กัน** (ทำให้ HEAD
  เพื่อนเด้ง = ต้นเหตุ incident ข้างบน)
- อยากอ่าน branch อื่น → `git show <ref>:<path>` (ไม่ต้อง checkout)
- เผยแพร่งาน → `git push` / ref-push

## 3) 🧱 DB / live schema → board + look-before-replace

DB เป็นไวต์บอร์ดบนผนัง — ทุก session เห็นอันเดียวกัน worktree ช่วยไม่ได้:
- **จอง board เหมือนเดิม** สำหรับ migration timestamp / shared table·RLS (ดูหัวข้อ board ด้านล่าง)
- **กฎใหม่ราคาถูก — look before replace:** ก่อน `CREATE OR REPLACE` function/trigger
  ที่ share กัน → **เปิดดู definition จริงบน live DB ก่อน** อย่า overwrite มืด ๆ
  (กันเคส guard เก่าใน DB แต่ไม่ติดบน git ref → ถูกทับหายเงียบ ๆ)

## 4) 📓 Project state → memory เหมือนเดิม

สมุดจดกลาง = `MEMORY.md` + `project-*.md` ตาม Memory Protocol (ดูเอกสาร 02)
ไม่มีอะไรเปลี่ยน

---

## Board: `SESSION-BOARD.md`

board กลาง (`~/.claude/projects/C--Users-you/memory/SESSION-BOARD.md`) ใช้จองของกลาง
ที่ชนกันได้

> **ไม่ auto-load** — อ่านเฉพาะตอนงานแตะ multi-session project

### โครงสร้าง board (5 ส่วน)

| ส่วน | เก็บอะไร |
|---|---|
| **IN-FLIGHT** | งานที่กำลังทำอยู่ (owner + วันที่) — = **lock** |
| **RESERVATIONS** | resource ที่จองไว้ (migration timestamp, branch) |
| **HANDOFF** | งานส่งต่อระหว่าง session |
| **CONTRACTS** | ข้อตกลง interface/contract ระหว่าง session (เช่น schema ที่ตกลงร่วมกัน) |
| **MESSAGES** | ข้อความฝากถึง session อื่น |

> Board เก็บแค่ coordination state ชั่วคราว — **ไม่เก็บ permanent state ซ้ำ**
> (state ถาวรไปอยู่ `MEMORY.md` / project file)

### When to read / lock / release

**เริ่มงาน multi-session — READ board ทุกครั้ง:**
- เช็ค **IN-FLIGHT** (มี lock อะไรค้างไหม + มี session อื่น live ไหม → ตัดสินว่าต้อง
  worktree หรือยัง) + **CONTRACTS** + **MESSAGES** ที่ฝากถึงเรา

**RESERVE/lock เฉพาะตอนกำลังจะแตะ resource ที่ชนกันได้** (migration timestamp /
branch / shared file·table·RLS / shared DB function):
- จอง **RESERVATIONS** + เพิ่ม row ใน **IN-FLIGHT** (owner + วันที่) **ก่อน**ลงมือ
- migration timestamp → หยิบค่า "NEXT FREE" แล้ว bump ค่าถัดไป
- **งานล้วน ๆ ใน worktree/tree ตัวเองที่ไม่แตะของ share → ไม่ต้องลง board** (กัน bureaucracy)

**ระหว่างทำ:**
- **IN-FLIGHT ของ session อื่น = lock — อย่าแตะ** resource นั้น
- จำเป็นต้องแตะจริง ๆ → ฝากไว้ใน **MESSAGES** อย่าลุยทับ

**เสร็จงาน:**
- ลบ IN-FLIGHT row + ปล่อย reservation **ทันที**
- ย้าย state ถาวรไป `MEMORY.md` / project file (board ไม่เก็บซ้ำ)

### Stale-row rules (กัน lock ค้าง)

- Row ค้าง **> 3 วัน** ไม่มี update = **ต้องสงสัย** ว่า lock จริงหรือลืมปล่อย
  → verify ก่อนเชื่อ (อย่าถือว่าเป็น lock จริงอัตโนมัติ)
- **Prune** row เก่าทุกครั้งที่เปิด board
- **Budget ≤ 6 KB** — board ต้องเล็ก อ่านเร็ว

---

## ถ้ายังชนกันบ่อย (optional)

กฎเขียน + นิสัย worktree ข้างบน**พอแล้ว**สำหรับ scale ปกติ — ยังไม่ต้องมี
enforcement daemon / heartbeat GC / migration ledger. ถ้าในอนาคตยังชนกันบ่อยจริง
ค่อยพิจารณา PreToolUse guard hook เพิ่มทีหลัง (เป็น option ไม่ใช่ requirement)
