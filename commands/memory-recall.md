อ่าน project memory + verify กับ code state จริง ก่อน trust

> **recall = pure READ** — ห้าม mutate canonical, ห้าม fold §HANDOFF QUEUE (fold ย้ายไป `memory-save` = write op เท่านั้น). recall แค่ *รายงาน* ว่ามี delta ค้าง ไม่ใช่ลงมือ fold

ทำตามขั้นตอนนี้:

1. **Detect project** — อ่าน `cwd` ปัจจุบัน เทียบ canonical mapping ใน `~/.claude/CLAUDE.md` Memory Update Protocol. ถ้าไม่ match → แจ้ง user ว่าอยู่นอก mapped projects

2. **Read project memory file** — `~/.claude/projects/C--Users-you/memory/project-*.md` (ตาม mapping)

3. **Check `**Last verified:**` field** ที่ส่วนบนของ file
   - **Commit-staleness:** header `**Last verified:** <date> @ <commit>` — ถ้า `<commit>` ใน header ≠ HEAD จริงของ default branch (`git rev-parse HEAD`) หรือ ≠ commit ที่ body อ้าง → **flag staleness, ห้าม trust body จนกว่าจะ verify**
   - ถ้า > 5 วัน หรือไม่มี → **บังคับ run verify recipe** จาก project's own `CLAUDE.md` (section "Memory Persistence → Verify recipe")
   - Verify recipe ต่าง project ต่างกัน — เช่น `git log -10`, `git status`, อ่าน `src/lib/modules.ts`, list `supabase/migrations/`, etc.
   - ถ้า ≤ 5 วัน → skip verify ได้ (แต่ user สามารถขอให้ verify ได้)

4. **Check §HANDOFF QUEUE pending** (read-only) — อ่าน §HANDOFF QUEUE ใน `SESSION-BOARD.md`: มีบรรทัด `<target-file>` = ไฟล์ที่ recall ค้างอยู่ไหม (รูปแบบ `-> <target-file> :: <fact>  [from <session> <date>]`) → ถ้ามี = canonical **ยัง stale**: รายงาน "มี N deltas ค้างยังไม่ fold (จะ fold ตอน save ครั้งหน้า)" + verify ตามปกติ — **ห้าม fold ที่นี่** (recall = pure read)

5. **Report structured recall** ให้ user (Thai):
   - **Project:** ชื่อ project
   - **Last verified:** วันที่ + commit + warning ถ้า stale (commit ≠ HEAD/body, หรือ > 5 วัน)
   - **Memory summary:** highlights ที่ curated แล้ว (current status, key decisions, completed milestones) — ไม่ใช่ full dump
   - **Pending work:** รายการที่ค้างอยู่
   - **HANDOFF deltas ค้าง:** (ถ้ามี) — N บรรทัดใน §HANDOFF QUEUE ที่ target = ไฟล์นี้ ยังไม่ fold (จะ fold ตอน save ครั้งหน้า)
   - **Stale claims found:** (ถ้ามี) — สิ่งที่ memory บอกแต่ verify recipe พบว่าไม่ตรงกับ code จริง

6. **ถาม user:** "ทำต่อจากตรงไหนดี?"

**Quality bar:** ห้ามรายงานว่า "memory ตรงกับ code" โดยไม่ได้ verify จริง — ถ้าไม่ verify ให้บอกชัดเจนว่ายังไม่ verify
