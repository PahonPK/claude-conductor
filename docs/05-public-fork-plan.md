# 05 — Public Fork / Sanitization Approach (meta-doc)

> เอกสารนี้อธิบาย **วิธี** แปลง private instance ของ claude-conductor ให้เป็น public fork
> ที่แชร์ได้ปลอดภัย (sanitized). **repo ที่คุณกำลังอ่านอยู่นี้ = ผลลัพธ์ของกระบวนการนี้**
> — Layer 1 (System) + docs + templates เท่านั้น โดยถอด business data ออกหมดแล้ว

---

## เป้าหมาย

แยก **System layer (กลไก)** ออกจาก **Knowledge layer (business data)** เพื่อให้:
- คนอื่นเอา *framework* ไปใช้กับธุรกิจตัวเองได้ โดยไม่เห็นข้อมูลส่วนตัวของ maintainer
- maintainer ยังเก็บ private instance (พร้อม `memory/` + `workspaces/` จริง) ไว้ใช้งานต่อ

> หลักการ: **public fork ไม่มี Layer 2/3 เลย** — มีแค่ Layer 1 + docs + templates +
> `examples/` ที่เป็นข้อมูลสมมติล้วน

---

## (a) เลือกอะไรเข้า / ตัดอะไรออก

**เก็บ (include) — Layer 1 + docs + templates:**
- `CLAUDE.md` (genericized), `MEMORY_SCHEME.md`, `commands/`, `hooks/`, `settings.json`
- `docs/` ทั้งหมด (genericize ตัวอย่างที่อ้างธุรกิจจริง)
- `templates/` ทั้งหมด
- `examples/` (สร้างใหม่ — instance สมมติที่กรอกครบ)

**ตัดทิ้ง (drop) — Layer 2/3:**
- `memory/` ทั้งโฟลเดอร์ (business state ล้วน)
- `workspaces/` ทั้งโฟลเดอร์ (business context ล้วน)
- `.env` / credentials / `.git` ของ private repo
- README เดิม (เขียนใหม่สำหรับ public audience)

---

## (b) Sanitize replacement table (รูปแบบทั่วไป)

ก่อน publish ต้อง replace ทุก reference ที่ระบุตัวธุรกิจได้ — ตารางนี้เป็น **รูปแบบ**
(กรอก "ของจริง" จาก private instance ฝั่งซ้ายตอนทำจริง อย่า commit ค่าจริงลง public):

| ประเภทข้อมูลจริง | แทนด้วย |
|---|---|
| VPS / server IP (`\d+.\d+.\d+.\d+`) | `{{VPS_IP}}` |
| domains จริง | `{{DOMAIN}}` หรือ `app.example.com` |
| brand / company names (ทุกการสะกด ทั้งไทย/อังกฤษ) | `{{WORKSPACE}}` / `AcmeCorp` / `Acme` |
| person names | generic role เช่น `Owner` |
| OS username / home path (เช่น path segment ที่ derive จาก home) | `<YOUR_HOME>` / `C--Users-you` |
| commit hashes / email / API tokens / keys | ลบ หรือ `<placeholder>` |

> ⚠️ regex อย่างเดียวไม่พอ — ชื่อแบรนด์สะกดได้หลายแบบ (ไทย/อังกฤษ/ตัวพิมพ์เล็กใหญ่)
> ต้อง **manual review ทุกไฟล์** ที่ copy + เขียนส่วนที่อ้าง business จริงใหม่ให้ generic

---

## (c) โฟลเดอร์ `examples/`

แทนที่ workspace/memory จริงด้วย **instance สมมติที่กรอกครบ** เพื่อให้คนอ่านเห็นว่า
เวลาใช้จริงหน้าตาเป็นยังไง — ใช้ค่า fictional ล้วน (AcmeCorp, example.com, `{{...}}`):
- `examples/workspaces/acme-corp/CLAUDE.md` — workspace ตัวอย่าง
- `examples/memory/MEMORY.md` — index ตัวอย่าง
- `examples/memory/project-acme-web.md` — memory file ตัวอย่างที่กรอกครบ

---

## (d) Final allowlist scan (gate ก่อน publish)

ก่อน push สาธารณะ ต้อง grep ทั้ง repo (case-insensitive) หา **ค่าจริงทุกตัว** จาก
ตาราง (b): brand/company names, domains, IP จริง (regex `\d+.\d+.\d+.\d+` ที่ไม่ใช่
placeholder), email/token/commit-hash, OS username / home-path segment. **ต้องได้ 0 hit**
— เจอแม้แต่ตัวเดียว = หยุด แล้วแก้ก่อน. แนะนำทำเป็น CI check / pre-push hook

---

## สรุป checklist

- [x] สร้าง repo แยกสำหรับ public fork
- [x] copy เฉพาะ System + docs + templates
- [x] genericize ทุกไฟล์ (ตาราง b) + manual review
- [x] สร้าง `examples/` (fictional AcmeCorp)
- [x] เขียน README ใหม่สำหรับ public audience
- [x] รัน final allowlist scan (d) — 0 hit
