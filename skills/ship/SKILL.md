---
name: ship
description: Ship a web feature end-to-end with full verification — reconcile the REAL requirement, verify schema against the live DB, delegate the build, code-review, open a PR, deploy, browser-verify on live prod, then clean up the worktree and update memory. Invoke with /ship when a change is ready to go from "coded" to "live & verified". Bakes in the anti-friction guardrails (stale-memory, wrong-feature, non-existent column, placeholder data, unverified deploy).
---

# /ship — reconcile → build → review → deploy → prove → housekeep

ลูป ship-and-verify มาตรฐาน. ทุก step บังคับ เว้นแต่ user สั่งข้าม.
ยึด global `~/.claude/CLAUDE.md` (orchestrator workflow) + project `CLAUDE.md` (verify recipe + deploy specifics) เป็นหลัก — ไฟล์นี้แค่ทำให้เรียกลูปได้ในคำสั่งเดียวและกัน step หลุดตอน context ใกล้เต็ม.

> **Placeholders** — ค่าจริงอยู่ใน project `CLAUDE.md` ไม่ใช่ในไฟล์นี้:
> `{{DOMAIN}}` = URL ของ prod (เช่น `app.example.com`) · `{{DEPLOY_CMD}}` = deploy recipe/runbook ของ project ·
> `{{DB_INTROSPECT}}` = วิธีอ่าน schema จริงแบบ read-only (เช่น Postgres MCP read-only / `psql \d`)

## 0. Reconcile the REAL requirement (กัน ship ผิดของ)
- ทวนกับ user ว่า "สิ่งที่จะ ship คืออะไร" เป็นประโยค 1 บรรทัด → **รอ confirm ก่อนแตะโค้ด**
- READ project memory + `git status` / `git log` ของ tree จริง — **อย่าเชื่อ memory ที่ stale**; เจอ discrepancy รายงานก่อน
- แตะ shared resource (migration timestamp / branch / shared table·RLS / DB function) → READ `SESSION-BOARD.md`, lock ก่อนลงมือ

## 1. Verify schema vs LIVE DB ก่อนเขียน migration/SQL (กัน column/table ไม่มีจริง)
- ใช้ `{{DB_INTROSPECT}}` (read-only) ดูชื่อ table/column จริง **ก่อน**เขียน DDL/trigger/RPC — ห้ามเดา field
- รูปแบบที่เคยพัง: อ้าง column ที่ไม่มีจริง, ชื่อ column ใกล้เคียงแต่ผิด, table ผิดชื่อ, trigger อ้าง `OLD` ใน INSERT
- `CREATE OR REPLACE` shared function/trigger → เปิดดู definition จริงบน live ก่อน overwrite (กัน DB guard หาย)

## 2. Build (orchestrator — อย่า code เอง)
- เขียน brief → delegate Agent tool (หรือ `/fable-5` ถ้าใช้ model routing). Main thread = reviewer/decision-maker
- multi-agent: run เป็น wave ≤ 3 กัน rate limit + checkpoint หลังแต่ละ wave
- มี session อื่น live บน repo เดียวกัน → EnterWorktree **ก่อน** spawn agent/start build

## 3. Code-review ก่อนรายงาน user (บังคับทุก code change)
- `/code-review` หรือ reviewer agent — ตรวจ bug + schema + RLS scope + type ก่อนถือว่าผ่าน

## 4. PR (ห้าม push ตรงเข้า default branch)
- เปิด PR เสมอ แม้ self-merge งานที่ review แล้ว
- merge base branch เข้า branch ตัวเองก่อนเปิด PR (ดู project `CLAUDE.md` §Merge hygiene ถ้ามี)

## 5. Deploy → prod
- รัน `{{DEPLOY_CMD}}` ตาม deploy recipe ใน project `CLAUDE.md`
- container/host ที่ share กันหลาย session → เช็ค + acquire `SESSION-BOARD.md` §DEPLOY LOCK ก่อน (ดู `docs/03-inter-session.md`)

## 6. Browser-verify on LIVE (ไม่ verify = ยังไม่เสร็จ)
- เปิด `https://{{DOMAIN}}` หน้าที่แก้จริงด้วย Playwright (หรือ browser tool ที่มี), capture proof; UI/hydration bug → diagnose ด้วย browser **อย่าเดา**
- ตรวจ semantic จริง: label/column/data ถูกความหมาย (ไม่ใช่แค่ "หน้าโหลดได้"), **ใช้ real/seeded data ไม่ใช่ placeholder**

## 7. Housekeep
- ปล่อย worktree/lock, ลบ IN-FLIGHT row (+ DEPLOY LOCK ถ้าถือ), fold HANDOFF (delete-iff-folded) ลง canonical file
- update project memory + MEMORY.md one-liner (เฉพาะตอน state เปลี่ยน meaningful; เคารพ size budget)

## รายงาน user (ตรงไปตรงมา)
build อะไร · deploy แล้วหรือยัง · proof จาก browser · pending ที่เหลือ. **ถ้า verify ไม่ครบหรือข้าม step ให้บอกชัด** — ห้ามบอก "เสร็จ" โดยไม่เปิดดูของจริง.
