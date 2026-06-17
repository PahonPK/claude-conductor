บันทึก state ปัจจุบันลง project memory file (curate จาก daily log + in-conversation context)

ทำตามขั้นตอนนี้ตามลำดับ:

1. **Detect project** — อ่าน `cwd` ปัจจุบัน เทียบกับ canonical mapping ใน `~/.claude/CLAUDE.md` section "Memory Update Protocol → Project mapping". ถ้าไม่มี match → แจ้ง user ว่าไม่อยู่ใน mapped project แล้วถามว่าจะ save ที่ไหน

2. **อ่าน sources 3 ชั้น:**
   - Project memory file ปัจจุบัน (e.g. `~/.claude/projects/C--Users-you/memory/project-acme-erp.md`)
   - Daily log วันนี้: `~/.claude/memory-checkpoints/daily/YYYY-MM-DD.md` (ถ้าไม่มี ลองเมื่อวาน)
   - In-conversation context (สิ่งที่ทำใน session นี้)

3. **Compute compact diff** vs current memory file ใช้ bullet format:
   - `+ added: <สิ่งที่จะเพิ่ม>`
   - `- removed: <สิ่งที่จะลบ/แทนที่>`
   - `~ changed: <field เดิม → field ใหม่>`

4. **แสดง diff** ให้ user เป็น single block (ไม่ต้องยาว) แล้วถาม `(y/n)` confirm

5. **ถ้า y:**
   - เขียนทับ memory file ด้วย version ใหม่
   - **บังคับ:** bump `**Last verified:**` field ที่บนสุด เป็นวันที่วันนี้
   - ถ้า one-liner description (header `name:` ใน frontmatter หรือใน `MEMORY.md` index) เปลี่ยน → update `~/.claude/projects/C--Users-you/memory/MEMORY.md` ด้วย
   - Confirm ด้วย one-line summary ของสิ่งที่เขียน (file path + key changes)

6. **ถ้า n:** ถาม user ว่าจะเก็บ/ทิ้งอันไหน แล้วทำใหม่

**Quality bar:** อย่าเขียนทับด้วย state เก่า — ถ้าไม่แน่ใจว่าข้อมูลใหม่ถูกต้อง ให้ verify (อ่าน code/git log) ก่อน แล้วค่อยเขียน
