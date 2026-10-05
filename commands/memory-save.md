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

5. **Pre-curate: drain HANDOFF + degenerate-C canary** (ก่อน curate body)
   - **Fold-on-save (drain HANDOFF):** อ่าน §HANDOFF QUEUE ใน `SESSION-BOARD.md` — หาบรรทัดที่ `<target-file>` = ไฟล์ที่กำลัง save (รูปแบบ `-> <target-file> :: <fact>  [from <session> <date>]`). drain ทุกบรรทัดที่ match ด้วย **targeted edit** (fold fact เข้า body — **ไม่ re-curate ทั้งไฟล์**)
     - **delete-iff-folded (idempotent):** ลบบรรทัด HANDOFF ได้**เฉพาะใน edit เดียวกัน**กับที่เขียน fact เข้า canonical body — ห้ามลบก่อน fold (กัน partial-fold + double-drain). fold เกิดบน save นี้เท่านั้น — recall ห้าม fold
   - **degenerate-C canary (flag-only):** run `git log --name-only <Last-verified-commit>..HEAD` — ถ้ามีไฟล์อยู่ใน path domain ของ project อื่น (เทียบ cwd→project mapping ใน `~/.claude/CLAUDE.md`) → **flag ให้ user:** "งานนี้แตะ <files> ซึ่งอยู่ domain <project> — ต้องเขียน HANDOFF ไหม?" (ไม่ auto-fold; flag-only; **ไม่ block การ save**)

6. **ถ้า y:**
   - อัปเดต memory file ให้สะท้อน state ปัจจุบัน (targeted edit เฉพาะส่วนที่เปลี่ยน/stale — **ไม่ใช่ rewrite ทั้งไฟล์**; เหมือน step 5, mega-file ใกล้ budget → surgical กัน error/bloat) — เนื้อหา **เขียนเป็น English** (faithful; คงไทยเฉพาะ term ที่แปลแล้วความหมาย/เจตนาเพี้ยน หรือแปลไม่ได้) ตาม `~/.claude/CLAUDE.md` §Memory "ภาษา memory"
   - **บังคับ machine-bump:** เขียนทับ `**Last verified:** <date> @ <commit>` ที่บนสุด ด้วยค่าจริง — `<commit>` = `git rev-parse HEAD`, `<date>` = วันนี้ — **ห้าม hand-maintain** (ทุก save ต้องมีทั้ง date + commit จริง)
   - ถ้า one-liner description (header `name:` ใน frontmatter หรือใน `MEMORY.md` index) เปลี่ยน → update `~/.claude/projects/C--Users-you/memory/MEMORY.md` ด้วย
   - Confirm ด้วย one-line summary ของสิ่งที่เขียน (file path + key changes + จำนวน HANDOFF ที่ drain)

7. **ถ้า n:** ถาม user ว่าจะเก็บ/ทิ้งอันไหน แล้วทำใหม่

**Quality bar:** อย่าเขียนทับด้วย state เก่า — ถ้าไม่แน่ใจว่าข้อมูลใหม่ถูกต้อง ให้ verify (อ่าน code/git log) ก่อน แล้วค่อยเขียน
