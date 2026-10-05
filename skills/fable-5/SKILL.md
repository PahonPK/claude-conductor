---
name: fable-5
description: Model-routed brainstorm→build loop — Fable 5 = the brain/advisor (analyze, design architecture, plan, decide go/no-go), Opus 4.8 = the heavy hands (read complex code, tier-2 coding, final review), Sonnet = the light hands (gather, mechanical ops, comms, tier-1 coding). Invoke /fable-5 for any non-trivial code task so each phase runs on the right model. Built on the standard orchestrator loop, with model pinned per phase.
---

# /fable-5 — Fable 5 คิด · Opus 4.8 ลงมืองานยาก · Sonnet ลงมืองานง่าย

ลูป brainstorm→build มาตรฐาน แต่ **route model ต่อ phase**: ใช้โมเดลฉลาดสุด (Fable 5) เป็น **advisor งานคิดเท่านั้น** (วิเคราะห์ / architecture / plan / ตัดสิน go·no-go) ใช้ workhorse (Opus 4.8) กับงานมือที่ต้องเข้าใจ code ลึก (อ่าน code ซับซ้อน, coding tier 2, review) และใช้ Sonnet กับงานมือเบา (เก็บข้อมูล, mechanical, สื่อสาร, coding tier 1). ยึด global `~/.claude/CLAUDE.md` §Orchestrator Workflow + project `CLAUDE.md` เป็นหลัก — ไฟล์นี้แค่ผูก model routing เข้ากับลูปเดิม ไม่ได้แทนที่มัน.

> ℹ️ ชื่อโมเดลด้านล่างคือชุดที่ maintainer ใช้จริง — เปลี่ยนเป็นรุ่นที่ account คุณมีได้ หลักการคือ **3 ระดับ: สมอง (แพงสุด คิดอย่างเดียว) · มือหนัก · มือเบา**

## หลักการ routing (ห้ามสลับหน้าที่)

| งาน | โมเดล | บทบาท |
|---|---|---|
| อ่าน code ซับซ้อน (trace call graph / RLS / trigger) | **Opus 4.8** (`model: opus`) | มือ (executor) |
| **เก็บข้อมูล/fact-finding ทั่วไป** · ถอดข้อมูลจาก PDF/ภาพ/xlsx · probe DB read-only ตามสูตร · ประกอบรายงาน | **Sonnet** (`model: sonnet`) | มือเบา (executor) |
| วิเคราะห์ · วาง architecture · ทำ plan · ตัดสินใจ (รวม go/no-go จากผล review) | **Fable 5** (brain) | สมอง (advisor/orchestrator) |
| **Coding tier 1 (งานง่าย / มี gate ครอบ)**: FE-only · UI copy · CRUD ธรรมดา · test · migration แบบสูตร (add column/index · comment · enum value) · งานที่ deterministic gate ครอบทั้งชิ้น (type-check / test suite / SQL gates / rolled-back test battery) | **Sonnet** (`model: sonnet`) | มือเบา (executor) |
| **Coding tier 2 (งานยาก)**: DB function · RLS · trigger · money / payroll logic · migration ที่แตะ contract ข้าม branch · refactor ข้ามหลายไฟล์ · **อะไรที่ไม่เข้า tier 1 ชัด ๆ → tier 2 เสมอ** | **Opus 4.8** (`model: opus`) | มือ (executor) |
| Review รอบสุดท้าย — **เต็ม scope เท่ากันทั้งสอง tier** (correctness · security · RLS · type · ตรง plan · convention) ไม่ใช่แค่เช็คว่าตรงแผน; reviewer ต้องแข็งกว่าหรือเท่ากับคนเขียน (judge ≥ answerer) | **Opus 4.8** (`model: opus`) — reviewer agent **คนละตัว**กับคนเขียน code | มือ (reviewer) |
| **งานเบา/สื่อสาร**: สรุปผลมาคุยกับ user · เรียบเรียงรายงาน/status · ถาม user กลับ (clarify) · แปลง findings เป็นตาราง/ข้อความ | **Sonnet** (`model: sonnet`) | ผู้ช่วยสื่อสาร (light) |
| **งาน mechanical ตามสูตร**: รัน script/คำสั่งที่ตัดสินใจเสร็จแล้ว · git ops · update board/memory/plan file ตาม delta ที่สมองกำหนด · เปิด PR · deploy ตาม runbook · verify หลัง deploy | **Sonnet** (`model: sonnet`) | มือเบา (executor) |

- **"สมอง" (Fable 5) = main thread ถ้า session รันบน Fable 5** (แนะนำสุด — orchestrator ควรเป็นคนตัดสินใจ). ถ้า session รันโมเดลอื่น (เช่น Opus) → spawn agent `model: fable` ทำ phase สมอง (Phase 2) แทน โดยส่ง findings เข้าไปใน brief.
- **"มือ" (Opus 4.8) = spawn agent `model: opus` เสมอ** ไม่ว่า session จะเป็นอะไร.
- **Fable = advisor เท่านั้น — ห้ามลงมือ:** main thread (สมอง) ห้ามอ่าน code เอง · ห้าม code เอง · **ห้ามทำงาน execution เอง** (แก้ไฟล์ / รันคำสั่ง / git / board·memory bookkeeping / PR / deploy) — ทุกการลงมือ delegate ตามตาราง routing. สิ่งที่สมองผลิตเองมีแค่: การตัดสินใจ · architecture · plan/PRD/brief · go/no-go จากผล review · บทสนทนากับ user. (อ่านรายงาน/ผล review เพื่อตัดสิน = งานวิเคราะห์ ทำได้ — ส่วนการ review code ละเอียด = งานมือของ Opus, และการแก้ตามผล review = ตีกลับมือ.) อยู่ที่ altitude เสมอ (กัน context pollution + โฟกัสโมเดลฉลาดที่การตัดสินใจ).
- **ข้อยกเว้นของการลงมือ (แคบ ตีความเข้ม):** (1) คำสั่งที่ subagent ถูก permission classifier บล็อก (เช่น COMMIT ลง prod DB) — สมองกด execute ได้ แต่ต้องเป็น script ที่มือเตรียม + ผ่าน review แล้วเท่านั้น (execute, ไม่ compose). (2) edit จิ๋ว 1-2 บรรทัดที่ overhead การ spawn แพงกว่าตัวงาน — ทำเองได้ แต่ถือเป็นข้อยกเว้น ไม่ใช่ default; มีหลายจุดให้รวบเป็นชุดเดียวแล้วส่ง Sonnet.
- **งานเบาห้ามเปลือง Fable/Opus:** งานที่เป็นแค่การสื่อสาร — สรุปผลให้ user อ่าน, เรียบเรียง status/รายงาน, ตั้งคำถามกลับไปหา user, จัด format ตาราง — **ใช้แค่ Sonnet พอ**: spawn agent `model: sonnet` ให้ draft แล้ว relay, หรือถ้า main thread ตอบเองให้ตอบ**สั้นตรงประเด็น** ไม่ยก loop เต็มขึ้นมา. Fable สงวนไว้เฉพาะ Phase 2 และ Opus เฉพาะอ่าน-เขียน-review code จริงเท่านั้น.

## Phase 1 — GATHER (Sonnet = มือเบา; Opus เฉพาะเมื่อต้องอ่าน code ซับซ้อน)
- สมองเขียน brief ชัด ๆ → spawn **Sonnet** agent(s) (`model: sonnet`) ไปเก็บ fact / ถอดข้อมูล / probe DB ตามสูตร; ใช้ Opus เฉพาะ gather ที่ต้อง trace code (call graph / RLS / trigger semantics)
- มือส่งกลับเป็น **structured findings** (ไฟล์ + เลขบรรทัด, behavior ปัจจุบัน, shape ข้อมูล, ชื่อ table/column จริง) — raw data ไม่ใช่ opinion
- งานกว้าง/หลายจุด → fan-out หลาย agent ขนานกัน (Agent tool หลายตัวใน message เดียว)
- สมอง **ไม่เปิด code เอง** — รับแต่ผลสรุปมาคิด

## Phase 2 — ANALYZE + ARCHITECT + PLAN (Fable 5 = สมอง)
- *(แนะนำ)* มี **design-lessons registry** (memory file รวมบทเรียนที่เคยพลาด เช่น copy-paste field ผิด, idempotency key ต่อแถว, zero-row-as-success) → อ่านก่อนออกแบบทุก plan ที่มี UI / ลูปเอกสาร / notification / client-write และแนบไปใน brief ของ agent สมองด้วย
- สมองย่อย findings → หา tension/risk/edge case → ออกแบบ architecture → เขียน plan เป็น phase ที่ scope ชัด
- **Confirm plan กับ user ก่อน build** (orchestrator step 3 — รอ "go" / "ไปเลย")
- แตะ shared resource → READ `SESSION-BOARD.md` แล้ว lock ก่อนลงมือ (migration timestamp / branch / shared table·RLS / DB function)

## Phase 3 — CODE (tier 1 = Sonnet · tier 2 = Opus 4.8)
- สมองแตก plan → **จัด tier ให้ทุกหน่วยงานใน brief** (tier 1 → `model: sonnet`, tier 2 → `model: opus`; ไม่แน่ใจ → tier 2) → spawn agent เขียน code ตาม plan ที่ lock ไว้
- **brief tier 1 ต้องมี:** (a) รายชื่อ gate ที่ agent ต้องรันเองก่อนส่งงาน (type-check · test suite · SQL gates ที่เกี่ยว) (b) design lessons ข้อที่เกี่ยว แนบไปในตัว (c) ขอบเขตไฟล์ที่ห้ามแตะ — สมอง **ไม่**วางแผนละเอียดกว่าเดิมเพื่อชดเชย (แผนระดับบรรทัด = ย้ายงานคิดไปโมเดลที่แพงกว่า)
- multi-agent → run เป็น wave ≤ 3 + checkpoint หลังแต่ละ wave; มี session อื่น live บน repo เดียวกัน → EnterWorktree **ก่อน** spawn agent/start build
- สมอง **ไม่ code เอง** — คุม scope + ตอบคำถาม agent + reconcile ผลเท่านั้น
- งานประกอบรอบ ๆ (push · เปิด PR · board/memory update · deploy ตาม runbook · post-deploy verify) → spawn **Sonnet executor** พร้อม step-by-step ที่สมองเขียนให้

## Phase 4 — FINAL REVIEW (Opus 4.8 = มือ reviewer · Fable = ตัดสินจากผล)
- spawn reviewer agent (`model: opus`) **คนละตัวกับ agent ที่เขียน code** (fresh context — ห้าม review งานตัวเอง) review **ก่อนรายงาน user**: correctness · security · RLS scope · type · ตรง plan ไหม · project convention — หรือใช้ `/code-review` แบบ pin opus
- สมองรับ findings มาตัดสินแบบ advisor: เจอ bug/หลุด scope → ตีกลับ Phase 3 (agent tier เดิมแก้; ถ้า finding ชี้ว่างานจริงเป็น tier 2 → ยกไป Opus แล้วจด "misclassified") แล้ว review ซ้ำ; ผ่าน → รายงาน user
- *(แนะนำตอนเริ่มใช้ tier 1)* จด trial log ของ N งาน tier 1 แรก (จำนวน finding · รอบแก้ · misclassified?) — เฉลี่ยวนแก้เพิ่ม ≥ 1 รอบ หรือ defect หลุดถึง live = ถอย tier 1 กลับไป Opus
- verify ของจริง (Playwright / preview / live) ตามลักษณะงาน — **ห้ามบอก "เสร็จ" โดยไม่เปิดดูของจริง**

## Guardrails ที่ inherit มา (ยังบังคับเต็ม)
- confirm plan ก่อน code · code-review ก่อนรายงาน · เปิด PR ก่อน merge (ห้าม push ตรงเข้า default branch) · verify live ก่อนบอกเสร็จ · save memory ตอน milestone · เคารพ `SESSION-BOARD.md` + size budget
- "ทำน้อย" = ลดความซับซ้อน solution ไม่ใช่ลด rigor — quality gate ทุกด่านยังเข้มเท่าเดิม
