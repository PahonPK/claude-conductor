# 03 — Inter-session Coordination (SESSION-BOARD.md + worktrees)

> Source: §Inter-session coordination ใน `../AGENTS.md`
> ใช้เฉพาะตอนมีหลาย session ทำงาน**คู่ขนาน**บน project เดียวกัน
>
> `AGENTS.md` เก็บแค่ **กฎ** (rules-only, โหลดทุก session) — เอกสารนี้คือ **เหตุผล + ตัวอย่าง +
> incident** เบื้องหลังกฎเหล่านั้น อ่านเมื่อกฎดูไม่มีเหตุผล หรือเจอ edge case ที่กฎไม่ครอบ
> *(Last updated: 2026-10-09)*

---

## ปัญหาที่แก้

บางครั้งมีหลาย agent session ทำงานพร้อมกันบน project เดียว (เช่น 2 session
แก้ codebase/DB เดียวกัน) — เสี่ยงชนกัน

**ศัพท์ git ที่ต้องเข้าใจก่อน:**
- **working tree** = โฟลเดอร์ไฟล์ที่ checkout ออกมาให้แก้ได้จริง (หนึ่ง clone มี main working tree 1 อัน + worktree เพิ่มได้)
- **HEAD** = ตัวชี้ว่า working tree นั้นกำลัง checkout commit/branch ไหนอยู่. `git checkout <branch>` = เปลี่ยน HEAD
  แล้วเขียนไฟล์ทั้ง working tree ใหม่ให้ตรงกับ branch นั้น
- **ref** = ชื่อที่ชี้ไปยัง commit (branch, tag ก็คือ ref). งานที่ **commit แล้ว** อยู่ใน **object DB** (`.git/objects`)
  และมี ref ชี้อยู่ — ต่อให้ไฟล์หายจาก working tree ก็ยังกู้จาก ref ได้เสมอ. งานที่ยัง**ไม่ commit** อยู่แค่ใน working tree

เคยมีเคส session หนึ่งกำลังแก้ migration file อยู่ อีก session `git checkout` อีก
branch ใน working tree เดียวกัน → HEAD เปลี่ยน ไฟล์ใน working tree ถูกเขียนใหม่ตาม branch อื่น ไฟล์ของ
session แรก**หายไปจาก working tree** (แต่ไม่ได้ถูกลบจริง — commit ยังอยู่ใน object DB บน ref; กู้คืน
ด้วย `git show <ref>:<path>` แล้ว push กลับ ไม่ได้ checkout). อีกเคส: trigger บน live database
ถูก replace ทับจน guard เก่าหาย เพราะ guard นั้นอยู่ใน DB แต่ไม่ติดบน git ref ใด ๆ

---

## โมเดล: ของที่ share กัน 4 (+1) อย่าง แต่ละอย่างมีวิธีกันชนของตัวเอง

หลาย session ใช้ของกลางร่วมกัน 4 อย่าง (อย่างที่ 5 เพิ่มทีหลังเมื่อมี deploy target ที่ share กัน):

| ของที่ share | ความเสี่ยง | วิธีกัน |
|---|---|---|
| 🗂️ **Working tree** | อีก session checkout แล้ว HEAD เปลี่ยน ไฟล์เราหายจาก working tree | **worktree ของใครของมัน** (เฉพาะตอนมี session อื่น live) — working tree แยก แต่ใช้ object DB ก้อนเดียวกัน |
| 🗄️ **Git refs / object DB** | checkout ทับ HEAD ของ session อื่น | append-only + วินัย ref (อ่านด้วย `git show`, เผยแพร่ด้วย `push`) |
| 🧱 **Live database / schema** | จอง migration timestamp ชน / replace function ทับ guard | board reservation + **look-before-replace** |
| 📓 **Project memory** | จำสถานะไม่ตรงกัน | project memory (`MEMORY.md` + `project-*.md`) + HANDOFF QUEUE |
| 🚦 **Shared deploy target** (container/host ที่หลาย session rebuild) | 2 session rebuild container เดียวกันพร้อมกัน | **DEPLOY LOCK** บน board (ดูข้อ 5) |

---

## 1) 🗂️ Working tree → worktree ของใครของมัน

**worktree จำเป็นเฉพาะตอนมี session อื่น live บน repo เดียวกันจริง ๆ** (เช็ค IN-FLIGHT
บนบอร์ดก่อน) — เป็นเครื่องมือกันชน ไม่ใช่พิธีกรรมที่ต้องทำทุกครั้ง. **session เดียว
โดด ๆ ทำใน tree ปกติได้เลย ไม่ต้องตั้ง worktree.**

เมื่อมีหลาย session: แทนที่จะแย่ง working tree เดียว แต่ละ session ใช้ **git worktree ของตัวเอง**
— working tree แยกกัน แต่ object DB (commit / branch / ref) ก้อนเดียวกัน. session อื่นจึง checkout
ทับ working tree ของเราไม่ได้ ไฟล์ที่เรากำลังแก้ไม่หาย

**ลำดับสำคัญ — สร้าง/เข้า worktree ก่อน แล้วค่อยทำอย่างอื่น:**
1. สร้าง worktree แล้วย้าย session เข้าไป:
   - ทั่วไป (ทุก agent): `git fetch` → `git worktree add ../<repo>-<task> -b <branch> origin/<default-branch>`
     → เปิด session (เช่น `codex`) ใน dir นั้น
   - Claude Code: `git fetch` → `EnterWorktree` (สร้าง worktree ใต้ `.claude/worktrees/` บน branch ใหม่ + ย้าย cwd ของ session เข้าไป)
2. **แล้วค่อย** create branch / spawn subagent / รัน build

> ⚠️ ถ้าสั่ง **subagent** หรือ **คำสั่งที่รันค้างไว้ (background command)** เริ่มทำงาน *ก่อน* ย้ายเข้า
> worktree พวกมันจะยัง**ทำงานใน working tree เดิม** ไม่ย้ายตาม → ไปแก้ผิดที่. ดังนั้นเข้า worktree
> ให้เสร็จก่อน แล้วค่อยสั่ง subagent/รันคำสั่งยาว ๆ. (1 branch checkout ได้ใน worktree เดียวเท่านั้น)

**ถ้าเผลอเริ่มงานใน main tree ไปแล้ว (กฎ enter-first พลาด):**
1. STOP — อย่าสั่ง subagent / รัน build เพิ่ม
2. ยังไม่ commit → `git stash` ใน main tree ก่อน (worktree ใหม่แตกจาก `origin/<default>`
   จะไม่ลากงานที่ยัง uncommitted ติดไป)
3. สร้าง/เข้า worktree (ข้อ 1 ข้างบน)
4. ใน worktree → `git stash pop` ได้เลย (stash อยู่ใน `.git` ที่ share กัน ข้าม
   worktree ได้). ถ้าเป็นงานที่ commit ไปแล้วใน main tree → ดึงด้วย `git show <ref>:<path>`
   / cherry-pick ผ่าน object DB ที่ share กันแทน
5. subagent / background command ที่ spawn ไปก่อนเข้า worktree = ยังชี้ main tree → kill แล้ว
   spawn ใหม่หลังเข้า worktree

**ข้อควรรู้ (อย่าหลงคิดว่า worktree แก้ทุกอย่าง):**
- ไม่ใช่ของฟรี/auto — ต้อง **setup ครั้งเดียวต่อ repo + เป็นนิสัยที่ต้องทำเอง**
  (hook สร้าง/ย้าย session เข้า worktree ให้ไม่ได้)
- **ไม่ได้แยก database** — migration ยังเป็น global side-effect → ยังต้องจอง board (ดูข้อ 3)
- เก็บกวาด: worktree ค้างลบเองได้ (`git worktree remove` / `git worktree prune`) —
  committed work ปลอดภัยบน ref ไม่ว่าจะลบ worktree ทิ้งหรือไม่
- **2 แบบใช้ได้ทั้งคู่:** sibling directory บน named branch (`git worktree add ../<repo>-<task> -b <branch>`)
  หรือ Claude Code `EnterWorktree` (ใต้ `.claude/worktrees/` + auto-branch). ทั้งคู่ใช้ object DB
  เดียวกัน วินัย ref เหมือนกันเป๊ะ

**Setup ครั้งเดียวต่อ repo:**
- worktree แบบ sibling directory อยู่นอก repo อยู่แล้ว ไม่ต้องทำอะไร
- Claude Code `EnterWorktree`: เพิ่ม `/.claude/worktrees/` ลง `.gitignore` ของ repo — **ถ้า `.claude/` ถูก track อยู่**
  การไม่ ignore จะทำให้ worktree ไป pollute `git status` / เสี่ยง commit ติดไป.
  (ignore เฉพาะ `/worktrees/` อย่า ignore ทั้ง `/.claude/` ไม่งั้นไฟล์ที่ track หลุด)
- base ของ worktree: แตกจาก **`origin/<default-branch>`** เสมอ ดังนั้น **`git fetch` ก่อนสร้าง worktree**
  ไม่งั้นแตกจาก remote-tracking ที่ stale. *(Claude Code: `worktree.baseRef` default = `fresh` อยู่แล้ว =
  แตกจาก origin; ถ้าจงใจอยากแตกจาก local HEAD ที่ยังไม่ push → `git config worktree.baseRef head`)*

## 2) 🗄️ Git refs / object DB → วินัยการอ่าน/เผยแพร่งาน

object DB (commit / branch / ref) เป็น append-only อยู่แล้ว ปลอดภัยโดย
ธรรมชาติ — แต่มีวินัย 3 ข้อ:
- **ห้าม `git checkout` branch ของ session อื่นใน working tree ที่ share กัน** (ทำให้ HEAD
  ของ session อื่นเปลี่ยน = ต้นเหตุ incident ข้างบน)
- อยากอ่าน branch อื่น → `git show <ref>:<path>` (ไม่ต้อง checkout)
- เผยแพร่งาน → `git push` / ref-push

## 3) 🧱 Live database / schema → board + look-before-replace

database ตัวเดียวกันถูกทุก session เห็นและแก้ร่วมกัน — worktree ช่วยไม่ได้:
- **จอง board เหมือนเดิม** สำหรับ migration timestamp / shared table·RLS (ดูหัวข้อ board ด้านล่าง)
- **กฎราคาถูก — look before replace:** ก่อน `CREATE OR REPLACE` function/trigger
  ที่ share กัน → **เปิดดู definition จริงบน live DB ก่อน** อย่า overwrite มืด ๆ
  (กันเคส guard เก่าใน DB แต่ไม่ติดบน git ref → ถูกทับหายเงียบ ๆ)

**ทำไมต้อง look before replace:** guard ที่อยู่แค่ใน live DB ไม่ติดบน git ref ใด ๆ เลย —
replace function ทับแบบมืด ๆ = ลบมันทิ้งโดยไม่มี diff ไม่มี PR ไม่มีร่องรอย. การอ่าน definition
จริงก่อน = code review สำหรับ object ที่ git มองไม่เห็น

## 4) 📓 Project memory → memory + HANDOFF QUEUE

project state = `MEMORY.md` + `project-*.md` ตาม Memory Protocol (ดูเอกสาร 02)
— ถ้า session หนึ่งเปลี่ยน fact ของ project ที่ตัวเองไม่ได้ owns → ส่งผ่าน **HANDOFF QUEUE**
(ดูหัวข้อ board ด้านล่าง) ไม่เขียนทับไฟล์ของคนอื่นตรง ๆ

## 5) 🚦 Shared deploy target → DEPLOY LOCK

**Incident (เกิดจริงใน private instance):** 2 session rebuild frontend container ตัวเดียวกันบน
server พร้อมกัน — คำสั่ง recreate ของ session ที่สองชน **"name already in use"**, container
ไม่กลับขึ้นมา และเว็บ prod ตอบ **502** จนมีคนสังเกตเห็น. ชื่อ container เดียว = rebuild ได้
ทีละครั้ง → mutex คือ §DEPLOY LOCK บน board

| กฎ | ทำไม |
|---|---|
| ก่อน build/up container ที่ share → เช็ค §DEPLOY LOCK; ACTIVE ว่าง → ใส่ตัวเองเป็น ACTIVE แล้ว deploy | 1 container = 1 rebuild ต่อครั้ง |
| มี ACTIVE อยู่ → **ห้าม deploy**, เพิ่มตัวเองใน WAITING | กัน race ข้างบน |
| **Piggyback:** ACTIVE pull default branch ล่าสุดก่อน build → ทุก PR ที่ merge แล้วขึ้น live ใน image เดียว; WAITING ที่ commit อยู่ใน image แล้ว → ลบ row ตัวเองได้เลย | rebuild ซ้ำ = วิ่ง race ใหม่โดยไม่ได้อะไร — WAITING ส่วนใหญ่จึงเป็น no-op |
| health check ผ่าน (app ตอบแล้ว เช่น `curl` ได้ redirect/200) → **ลบ ACTIVE row ทันที** | lock ค้าง = บล็อกคนอื่นฟรี ๆ |
| ACTIVE row ค้าง > 15 นาที → verify (container status / health check) ก่อน steal | row เก่าขนาดนี้น่าจะเป็น session ที่ตายแล้ว มากกว่า build ที่ช้า |
| lock คุมแค่ container rebuild — migration ยังจองผ่าน §RESERVATIONS | คนละ resource |

> ไม่มี deploy target ที่หลาย session ใช้ร่วมกัน (เช่น deploy ผ่าน CI/hosting ที่ queue ให้อยู่แล้ว) → ไม่ต้องมี section นี้

---

## Board: `SESSION-BOARD.md`

board กลาง (`SESSION-BOARD.md` ใน memory dir — Claude: `~/.claude/projects/<slug>/memory/` ·
Codex: `~/.codex/conductor-memory/`) ใช้จองของกลางที่ชนกันได้. setup seed ไฟล์ตั้งต้นให้
จาก `templates/SESSION-BOARD.md.template` (6 section + ตัวอย่าง row ละ 1 บรรทัด)

> **ไม่ auto-load** — อ่านเฉพาะตอนงานแตะ multi-session project

### โครงสร้าง board (6 ส่วน)

| ส่วน | เก็บอะไร |
|---|---|
| **IN-FLIGHT** | งานที่กำลังทำอยู่ (owner + วันที่) — = **lock** |
| **RESERVATIONS** | resource ที่จองไว้ (migration timestamp, branch) |
| **DEPLOY LOCK** | ACTIVE (ใครกำลัง rebuild container ที่ share) + WAITING — ดูข้อ 5 |
| **HANDOFF QUEUE** | fact ที่ session หนึ่งเปลี่ยน แต่ไฟล์ canonical เป็นของ project อื่น — รอ fold |
| **CONTRACTS** | ข้อตกลง interface/contract ระหว่าง session (เช่น schema ที่ตกลงร่วมกัน) |
| **MESSAGES** | ข้อความฝากถึง session อื่น |

> **Board = lock + intent + handoff เท่านั้น — ไม่ใช่ที่เก็บ state.** ห้ามเขียน completion
> narrative ("P2 DONE merged verified …") ลง board: พอ fact อยู่ 2 ที่ มันจะ drift ออกจากกัน —
> และ board ถูก prune ทุก 3 วันแต่ canonical file ไม่ถูก ดังนั้นสำเนาที่รอดคือสำเนาที่ผิด.
> state ถาวรไปอยู่ `MEMORY.md` / `project-*.md` เท่านั้น

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
- งานแตะ fact ของ project ที่ session นี้ไม่ได้ owns → เขียน **HANDOFF QUEUE** 1 บรรทัด **ก่อน**ลบ IN-FLIGHT (ดูด้านล่าง)
- ลบ IN-FLIGHT row + ปล่อย reservation **ทันที**
- ย้าย state ถาวรไป `MEMORY.md` / project file (board ไม่เก็บซ้ำ)

### HANDOFF QUEUE — รูปแบบ + กฎ fold

session ที่เปลี่ยน fact ของ project ที่ตัวเองไม่ได้ owns ต้องทิ้ง fact ไว้ก่อนปล่อย lock:

```
-> <target-file> :: <fact sentence, not a resource label>  [from <session> <date>]
-> project-acme-erp.md :: migration add_invoice_status applied on prod; old status column dropped  [from web-session 2026-10-01]
```

- ต้องเป็น **fact** ("column เก่าถูก drop แล้ว") ไม่ใช่ **resource label** ("แตะ table invoices")
  — เจ้าของไฟล์ต้อง fold ได้โดยไม่ต้องเดา
- เพราะเป็น durable delta → §HANDOFF QUEUE **ยกเว้นกฎ prune 3 วัน + ไม่นับใน 6 KB budget**
  (GC ห้ามกินมัน); entry > 14 วัน = ไม่มีใคร save ไฟล์นั้นมา 2 สัปดาห์ → **flag ให้ user** อย่าลบ
- **fold บน `memory-save` เท่านั้น (write op) — ห้าม fold ตอน `memory-recall`** (recall = pure
  read; ถ้า recall ต้อง drain ก็จะกลายเป็น write ที่ไม่ผ่าน review). recall แค่รายงานว่ามี delta ค้าง
- drain แบบ ambient: session ไหนก็ได้ที่ save ไฟล์ X → drain ทุกบรรทัดที่ target = X
- **delete-iff-folded:** ลบบรรทัด HANDOFF ได้เฉพาะใน **edit เดียวกัน** กับที่เขียน fact เข้า
  canonical body. ถ้าแยก 2 จังหวะแล้ว crash ตรงกลาง: ลบก่อน fold = fact หายจากทั้ง 2 ที่
  (partial fold); fold แล้วไม่ลบ = save ครั้งหน้า fold ซ้ำ (double drain → ข้อความซ้ำ/ขัดกัน).
  ทำใน edit เดียว = idempotent — บรรทัดยังอยู่ให้ fold หรือ fold ไปแล้วอย่างใดอย่างหนึ่ง

### Stale-row rules (กัน lock ค้าง)

- Row ค้าง **> 3 วัน** ไม่มี update = **ต้องสงสัย** ว่า lock จริงหรือลืมปล่อย
  → verify ก่อนเชื่อ (อย่าถือว่าเป็น lock จริงอัตโนมัติ)
- **Prune** row เก่าทุกครั้งที่เปิด board
- **Budget ≤ 6 KB** — board ต้องเล็ก อ่านเร็ว (ยกเว้น §HANDOFF QUEUE — ดูข้างบน)

---

## Merge hygiene สำหรับ repo ที่หลาย session ทำคู่ขนาน

worktree กันชนตอน *ทำงาน* — แต่ตอน *merge* หลาย PR ที่แตกจาก base เดียวกันยังชนกันได้.
บทเรียนจากการ audit conflict จริง (ส่วนใหญ่มาจาก "registry บรรทัดเดียวที่ทุก PR append"):

- **ไฟล์ derived/generated ห้าม hand-merge** — regenerate จาก source หลัง merge แล้ว commit ผล
  (lockfile, generated types, pin/snapshot file ฯลฯ). ถ้าไฟล์ generated เองติด conflict → เอาฝั่ง
  base ก่อน แล้วค่อย regenerate (tool ส่วนใหญ่อ่าน conflict marker ไม่ได้). ไฟล์ที่ต้องรวมทั้งสองฝั่ง
  (เช่น type definitions) → เก็บ addition ของทั้งสองฝั่ง แล้วพิสูจน์ด้วย type-check
- **ตรวจหลัง merge ว่าไม่มี 2 PR redefine ของชิ้นเดียวกัน** (เช่น DB function เดียวกันถูก replace
  ใน 2 migration) — ถ้ามี = หยุดและ reconcile ก่อน ไม่ใช่ปล่อย "ตัวหลังชนะ"
- **Sibling PRs merge ตามลำดับ apply** — แต่ละ PR stack บน head ที่ resolve แล้วของ PR ก่อนหน้า
  (ไม่ resolve conflict เดิมซ้ำ 2 รอบ)
- **merge base branch เข้า branch ตัวเองก่อนเปิด PR** และพยายาม merge ภายใน ~3 วันหลังแตก branch
- **ไม่มี PR ไหน append ลง shared single-line registry** (เช่น บรรทัด `"test": "a && b && c"` ที่ทุก PR
  ต่อท้าย) — ให้ **derive** แทน (เช่น test runner ที่ discover ไฟล์ `*.test.*` เอง) แล้ว PR แค่เพิ่มไฟล์
- เพิ่ม gate ใหม่ = เพิ่มไฟล์ที่ถูก discover อัตโนมัติ ไม่ใช่แก้ list กลาง; legacy exemption list ให้
  freeze — ไฟล์ใหม่ที่ไม่ผ่าน gate = แก้ไฟล์ ไม่ใช่เพิ่ม exemption

> ใส่เป็น section `## Merge hygiene` ใน project `AGENTS.md` (ดู `templates/project-AGENTS.md.template`)
> แล้วแทนด้วยชื่อไฟล์/คำสั่งจริงของ project

---

## ถ้ายังชนกันบ่อย (optional — ตั้งใจไม่สร้าง)

กฎเขียน + นิสัย worktree ข้างบน**พอแล้ว**สำหรับ scale ปกติ — ยังไม่ต้องมี
enforcement daemon / heartbeat GC / migration ledger. ถ้าในอนาคตยังชนกันบ่อยจริง
ค่อยพิจารณา PreToolUse guard hook เพิ่มทีหลัง (เป็น option ไม่ใช่ requirement)
