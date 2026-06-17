อ่าน project memory + verify กับ code state จริง ก่อน trust

ทำตามขั้นตอนนี้:

1. **Detect project** — อ่าน `cwd` ปัจจุบัน เทียบ canonical mapping ใน `~/.claude/CLAUDE.md` Memory Update Protocol. ถ้าไม่ match → แจ้ง user ว่าอยู่นอก mapped projects

2. **Read project memory file** — `~/.claude/projects/C--Users-you/memory/project-*.md` (ตาม mapping)

3. **Check `**Last verified:**` field** ที่ส่วนบนของ file
   - ถ้า > 5 วัน หรือไม่มี → **บังคับ run verify recipe** จาก project's own `CLAUDE.md` (section "Memory Persistence → Verify recipe")
   - Verify recipe ต่าง project ต่างกัน — เช่น `git log -10`, `git status`, อ่าน `src/lib/modules.ts`, list `supabase/migrations/`, etc.
   - ถ้า ≤ 5 วัน → skip verify ได้ (แต่ user สามารถขอให้ verify ได้)

4. **Report structured recall** ให้ user (Thai):
   - **Project:** ชื่อ project
   - **Last verified:** วันที่ + warning ถ้า stale
   - **Memory summary:** highlights ที่ curated แล้ว (current status, key decisions, completed milestones) — ไม่ใช่ full dump
   - **Pending work:** รายการที่ค้างอยู่
   - **Stale claims found:** (ถ้ามี) — สิ่งที่ memory บอกแต่ verify recipe พบว่าไม่ตรงกับ code จริง

5. **ถาม user:** "ทำต่อจากตรงไหนดี?"

**Quality bar:** ห้ามรายงานว่า "memory ตรงกับ code" โดยไม่ได้ verify จริง — ถ้าไม่ verify ให้บอกชัดเจนว่ายังไม่ verify
