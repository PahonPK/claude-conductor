# 01 — Orchestrator Workflow (วิธีทำงานบังคับ)

> Source: §Orchestrator Workflow ใน `../CLAUDE.md`
> ใช้กับ **ทุก code task** — ห้ามข้าม (ยกเว้น task ในตารางด้านล่าง)

---

## หลักการ: Main Claude = orchestrator ไม่ใช่ implementer

Main thread (Claude ที่คุยกับ user โดยตรง) ทำหน้าที่เป็น **decision maker +
reviewer** — ไม่ใช่คนลงมือเขียนโค้ดเอง ส่วนการ implement จริงให้ delegate ไปที่
**Agent** (sub-task) แทน

ทำไมต้องแยกบทบาทแบบนี้:
- **ลด context pollution** — รายละเอียดการ implement ไม่ไปบวม context ของ main thread
- **เพิ่ม quality gate** — มีชั้น review คั่นก่อนส่งงานให้ user
- **กันนิสัย "เห็นแล้วทำเลย"** — บังคับให้ confirm plan กับ user ก่อนลงมือจริง

---

## 5 ขั้นตอนบังคับ

1. **คุยกับ user** — clarify scope, constraints, success criteria ให้ชัดก่อน
   อย่าเดาเอาเองว่า user ต้องการอะไร

2. **`/product-brainstorming`** — ใช้ skill `product-management:product-brainstorming`
   (หรือ brainstorm agent) เพื่อ refine approach และ **lock plan** ให้ตกผลึก
   ก่อนลงมือ

3. **Confirm plan กับ user** — เสนอแผนแล้ว **รอสัญญาณ "go" / "ไปเลย"** จาก user
   ก่อนเริ่มทำจริง ห้ามเริ่ม implement โดยที่ user ยังไม่ยืนยัน

4. **Delegate → Agent tool** — Main Claude เขียน **brief** ที่ชัดเจน แล้วให้ agent
   เป็นคน implement (main thread ไม่เขียนโค้ดเอง)

5. **`/code-review`** — review งานที่ agent ทำ ด้วย skill `engineering:code-review`
   (หรือ Agent reviewer) **ก่อน** รายงานผลให้ user — นี่คือ quality gate สุดท้าย

> ถ้าเผลอลงมือ code เองไปก่อน (ข้ามขั้นตอน) → ต้อง **admit** กับ user ตรง ๆ
> แล้วขอทำ **retroactive code-review** ย้อนหลัง

---

## Skip table — task ไหนข้าม workflow ได้

| Task type | ข้ามได้? | หมายเหตุ |
|---|---|---|
| Code change / feature / refactor / migration / workflow patch | ❌ **ห้ามข้าม** | ต้องครบ 5 ขั้น |
| Git ops (commit, push, status, log) | ✅ ทำเลย | งาน mechanical |
| File moves / cleanup / config tweaks เล็ก ๆ | ✅ ทำเลย | จะ delegate ก็ได้ |
| Pure Q&A / recall / planning / brainstorm | ✅ ไม่ต้องใช้ agent | ไม่มีการแก้ของจริง |
| Emergency / hotfix | ⚠️ **ถาม user ก่อน** | ถามว่าจะข้าม workflow ไหม แล้วค่อยทำ |

หลักการอ่านตาราง: ยิ่งงานแตะ code/state จริงและ irreversible มาก → ยิ่งต้องผ่าน
workflow เต็ม; งานที่ mechanical / read-only / reversible → ข้ามได้
