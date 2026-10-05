# 06 — Lessons Learned (ปัญหาที่เจอจริง → กฎที่ได้)

> บทเรียนจากการใช้ framework นี้ทำงานจริงหลายเดือนใน private instance ของ maintainer —
> ถอดชื่อ/วันที่/ระบบจริงออกหมด เหลือแค่ **ปัญหา → กฎ → วิธีใช้**
> *(Last updated: 2026-10-05)*
>
> ใน private instance แต่ละข้อคือ **feedback memory file** หนึ่งไฟล์
> (`~/.claude/projects/C--Users-you/memory/feedback-<topic>.md` — ดูรูปแบบที่
> `../examples/memory/feedback-testing-standard.md`). ข้อที่เป็น hard rule จริงถูก promote
> เป็น one-liner ใน `../CLAUDE.md` §Quality Standards แล้ว — ที่เหลืออ่านที่นี่เมื่อเจอสถานการณ์ตรงกัน
>
> **หลักการเพิ่มบทเรียน:** เพิ่มเฉพาะเมื่อมี incident จริง (ไม่เดาล่วงหน้า — ตาม §ห้าม over-engineer) ·
> เขียนเป็น *class* ของปัญหา ไม่ใช่เคสเดียว · ≤ 4 บรรทัดต่อข้อ

---

## A. Verification & testing

**A1. Test honesty — อย่าบอกว่าผ่านถ้าทดสอบแค่ผิว** *(promoted → CLAUDE.md)*
- **ปัญหา:** รายงานว่า "login test ผ่าน" แต่จริง ๆ ทดสอบแค่ว่าหน้า render — การ sign-in จริงกับ DB ไม่เคยถูกเรียก user เจอ bug เองหลังรัน migration → ความเชื่อใจหาย
- **กฎ:** feature ที่พึ่ง service ภายนอก (auth, DB) ห้าม mark ว่าผ่านจนกว่าจะรัน end-to-end จริงสำเร็จ · ระบุเสมอว่า *ทดสอบอะไร และไม่ได้ทดสอบอะไร*
- **วิธีใช้:** รายงานผลเป็น 2 ส่วน "verified: … / not verified: … (เพราะ …)" · setup DB เสร็จ → รัน e2e ทันทีก่อนบอกเสร็จ

**A2. Prod SQL ผ่านหลายชั้น shell = เขียนเป็นไฟล์ ไม่ใช่ string**
- **ปัญหา:** probe `BEGIN; … ROLLBACK;` ถูกส่งเป็น inline string ผ่าน bash → ssh → container → psql; quote พังจน `BEGIN` ไม่ทำงาน คำสั่งแก้ permission วิ่งเข้า live DB จริงหลายนาที
- **กฎ:** SQL ที่ไป prod = เขียนลงไฟล์แล้ว pipe ผ่าน stdin (`… psql -X -v ON_ERROR_STOP=1 < file.sql`) · wrapper transaction สร้างด้วยการต่อไฟล์ แล้วดู `head -1`/`tail -1` ก่อนส่ง
- **วิธีใช้:** prod write รันจาก main thread (เห็น bytes ที่ส่งจริงในที่เดียว) ไม่ delegate ให้ agent ประกอบ string เอง · ดู C1 ด้วย

**A3. ทดสอบ form ที่มี credential/PII ใน browser context แยก**
- **ปัญหา:** reviewer agent เปิดหน้า login ของ dev server (มี network stub ตอบ "รหัสผิด" ทุกครั้ง) ใน browser tab ที่ user ใช้ร่วมอยู่ user นึกว่าเป็นระบบจริง พิมพ์รหัสจริงหลายครั้ง และ accessibility snapshot ของ agent จับรหัสนั้นเข้า transcript → ต้อง rotate รหัส
- **กฎ:** ทดสอบ login/password/payment/PII form ใน **isolated browser context** เท่านั้น · stub/route interception อยู่ใน context นั้นเท่านั้น · ห้าม snapshot/screenshot tab ที่ user อาจกำลังพิมพ์
- **วิธีใช้:** brief ที่อนุญาตให้ verify ผ่าน browser ใส่ประโยค "isolated context only; stubs only there; `about:blank` + stop server หลังเก็บ proof; never snapshot the shared tab" · orchestrator บอก user ล่วงหน้า 1 บรรทัดว่าจะมีหน้า *test* โผล่

**A4. Preview ให้ดูตัวอย่างเต็มก่อน build output ที่คนอ่าน**
- **ปัญหา:** ข้อความสรุปรายวันที่ bot ส่งขึ้น live ไปแล้ว user เพิ่งเห็น layout ที่อ่านยากตอนข้อความจริงเด้ง — แก้ทีหลังต้องวนอีกรอบ build/rehearse/apply
- **กฎ:** ก่อน build/ship output ที่มนุษย์อ่าน (ข้อความ bot, เอกสารพิมพ์, UI copy, layout รายงาน, ข้อความที่ test run จะส่ง) → โชว์ **ตัวอย่างที่ render เต็ม** ด้วยข้อมูลสมจริง ทุก section แล้วรอ OK
- **วิธีใช้:** ทำใน phase design (ก่อน delegate build) · mock ครึ่ง ๆ = ยังไม่เสร็จ · ตัวอย่างใน chat ใช้เวลาไม่กี่นาที layout ที่ ship ไปแล้วใช้ทั้งรอบ

**A5. ตรวจว่า preview server รันจาก tree/branch ไหน ก่อนโชว์ "proof"**
- **ปัญหา:** preview config ระดับ global ชี้ไปที่ main tree ที่ stale (ตามหลังหลายร้อย commit) ไม่ใช่ worktree ที่กำลังทำ — "proof" แรกที่โชว์คือ build error จาก code ที่ถูกลบไปแล้ว
- **กฎ:** proof ที่ render จาก tree ผิด แย่กว่าไม่มี proof
- **วิธีใช้:** ก่อน preview ยืนยัน cwd/branch ของ server (log ของ server + `git log -1` ใน tree นั้น) · หรือทำ launch entry ต่อ worktree ที่มี `cwd` ชัดเจน + port ไม่ซ้ำ

**A6. Claim เรื่อง "process วันนี้ทำงานยังไง" จาก memory = stale ได้**
- **ปัญหา:** เอกสารสรุปเขียนว่าหลาย process ยังทำมือ/อยู่ใน spreadsheet/ไม่มี approval — ดึงมาจาก memory/handoff เก่า แต่ระบบจริงเปลี่ยนไปแล้ว
- **กฎ:** ก่อนเขียนลง deliverable ว่า process ไหน "ยัง manual / ยังไม่มี X" → verify กับระบบ live (DB/UI) หรือตัด claim ทิ้ง
- **วิธีใช้:** บรรทัด process-state ใน memory = *lead ที่ต้องตรวจ* ไม่ใช่ fact (ขยายหลัก verify-before-trust จาก code ไปถึง business process)

**A7. Integration/workflow config ต้อง validate กับ version ของ API ปลายทาง**
- **ปัญหา:** deploy workflow automation ชุดใหญ่พร้อมกัน แล้วเจอ node หลายตัว param ผิด format ของ version นั้น, update ผ่าน API ไปเป็นแค่ draft ไม่ได้ publish, PATCH แล้ว credential binding หลุดเพราะไม่ได้ส่ง field นั้นไป
- **กฎ:** เป็นกรณีเฉพาะของ CLAUDE.md §Quality Standards "ก่อน deploy/publish ต้อง validate เสมอ + ดู execution log" — เพิ่มเติม: เช็ค format ของ config ตาม *version* ของ component นั้น, รู้ว่า API update = draft หรือ live, partial update ต้องส่ง field ที่ไม่อยากให้หาย
- **วิธีใช้:** แก้ทีละชิ้น → validate (tool ของ platform) → ดู execution จริง → ค่อยไปชิ้นถัดไป · node ที่เรียก API ภายนอกใส่ retry

---

## B. Git & publishing

**B1. เปิด PR เสมอ — ห้าม push ตรงเข้า default branch** *(promoted → CLAUDE.md)*
- **ปัญหา:** งาน self-merge ที่ review แล้ว ถูก fast-forward เข้า default branch ตรง ๆ → ไม่มี record, ไม่ผ่าน CI gate
- **กฎ:** push feature branch → เปิด PR → merge → แล้วค่อย deploy · แม้ self-merge งานตัวเอง
- **วิธีใช้:** ใช้ CLI ของ git host ที่มี auth ของตัวเอง (เช่น `gh`) · CLI ยังไม่ login → ขอให้ user รัน login เอง **ห้ามจับ token** (ดู B3)

**B2. ห้ามข้อมูลลับ/ภายในใน PR, commit, หรืออะไรที่ push ออกไป** *(promoted → CLAUDE.md)*
- **ปัญหา:** PR description เล่ารายละเอียดกลไก auth, role ของ DB, จำนวน user, ขั้นตอน apply บน prod — push ขึ้น git host = publish ออกภายนอก และ force-push ไม่ได้ลบ commit เก่าจริง (ยังเข้าถึงได้ด้วย SHA จนกว่าจะ GC) แม้ repo private ก็เห็นโดย collaborator/integration ทุกตัว
- **กฎ:** PR body / commit message = 2-4 บรรทัด บอก *อะไรเปลี่ยน* ระดับสูง + "รายละเอียดใน internal spec" · ห้าม PII, กลไก security/auth, รายละเอียด infra/role/credential, ตัวเลขข้อมูลจริง, runbook ของ prod
- **วิธีใช้:** ของละเอียดอยู่ใน private memory / spec ในเครื่องเท่านั้น · sanitize ย้อนหลัง → แก้ทั้ง PR body + commit message + comment ในโค้ด แล้วบอก user ว่า commit เดิมอาจยังค้างบน host ด้วย SHA

**B3. Token ห้ามผ่านมือ session**
- **ปัญหา:** คำสั่งที่พิมพ์ git credential ออก stdout ถูกรันทุกครั้งที่เปิด PR ผ่าน REST → token เดียวกันรั่วเข้า session transcript นับร้อย ต้อง revoke
- **กฎ:** session ไม่ fetch/พิมพ์ token เอง · ใช้ tool ที่ถือ auth เอง (git credential helper ภายใน `git push`, CLI ที่ login แล้ว) · ปิดคำสั่งที่พ่น secret ด้วย `permissions.deny`
- **วิธีใช้:** ต้องการ secret ใหม่ → ให้ user ใส่เอง (ดู C3)

**B4. เก็บกวาดของเหลือตอน ship ไม่ใช่ "ทีหลัง"**
- **ปัญหา:** worktree ที่จบแล้วค้างเป็นสิบ (แต่ละอันมี dependency folder หลายร้อย MB), image rollback บน server สะสมไม่จำกัดจนเครื่องเต็ม/OOM — "เดี๋ยวค่อยลบ" ไม่เคยเกิด เพราะ session ถัดไปไม่รู้ว่ามีของค้าง
- **กฎ:** session ที่เปิดอะไรไว้ เป็นคนปิดเอง: branch merge + verify แล้ว → `git worktree remove` + `git worktree prune` + ลบ local branch **ก่อน**เขียนสรุป
- **วิธีใช้:** ลบไม่ได้ (เช่น Windows ล็อกไฟล์) → บอกใน summary + ใส่ pending 1 บรรทัดใน project memory · sweep เป็นระยะด้วย `git worktree list` + `git branch --merged` · rollback image เก็บแค่ไม่กี่ตัวล่าสุด · scratchpad ของ session ทิ้งได้ แต่ไฟล์ใน home/repo ไม่ได้

---

## C. Memory & files

**C1. ห้ามเปิด memory file ด้วย truncating write**
- **ปัญหา:** script อัปเดต memory เปิดไฟล์แบบ write mode (`open(path, 'w')` ตัดไฟล์เหลือ 0 *ก่อน* เขียน) แล้ว encode พังกลางทาง → ไฟล์เหลือ 0 byte เนื้อหาเดิมหาย · เกิดซ้ำอีกครั้งตอนหลาย session แก้ไฟล์เดียวกัน
- **กฎ:** เขียนไฟล์ temp ใน directory เดียวกันแล้ว atomic rename (`os.replace`) หรือใช้ Write/Edit tool · ห้าม escape lone surrogate (`\udXXX`) ใน Python — ใช้ `\U0001XXXX`
- **วิธีใช้:** safety net = `hooks/memory-guard.js` (shadow + restore ไฟล์ 0 byte) · stdout ของ PostToolUse hook **ไม่ขึ้นให้ session เห็นเสมอ** → memory file ดูบางผิดปกติ ให้เปิด `~/.claude/backups/memory-shadow/_restores.log` · heredoc ใส่ `python -` พังเรื่อง quote → เขียน script เป็นไฟล์แล้วรัน อย่าสู้กับ quoting

**C2. หา ruling/artifact เก่าก่อน derive ใหม่**
- **ปัญหา:** งาน mapping ที่ user เคยตัดสินไปแล้วถูกทำใหม่จากศูนย์ เพราะไฟล์ ruling เก่าอยู่ใน scratchpad ของ session ก่อน ไม่ใช่ในโฟลเดอร์ project → ถาม user ซ้ำในเรื่องที่ตอบไปแล้ว
- **กฎ:** handoff อ้างไฟล์จาก session ก่อน → หาไฟล์นั้นก่อน (scratchpad ของ session เดิม ซึ่ง id อยู่ใน `originSessionId` ของ frontmatter, โฟลเดอร์ plans) แล้วเริ่มจากมัน · ถาม user เฉพาะ *ส่วนต่าง*
- **วิธีใช้:** artifact ที่ต้องใช้ต่อ (rulings, overrides, mapping) → copy ออกจาก scratchpad ไปไว้ในโฟลเดอร์ข้อมูลของ project ทันทีที่สร้าง

**C3. Global/secret-bearing config — ให้ user แก้เอง**
- **ปัญหา:** แก้ global config ที่มี secret ผ่าน tool → secret ผ่าน chat และ Claude Code ที่กำลังรันเขียนไฟล์นั้นบ่อยจน edit จากภายนอกชน (race / ถูกเขียนทับ)
- **กฎ:** ไฟล์ config ระดับ global ที่มี secret → ส่ง block พร้อม paste ให้ user (secret เป็น placeholder ชัด ๆ) + บอกตำแหน่งที่วาง + ขั้น restart · ไม่ Write/Edit เอง
- **วิธีใช้:** user restart แล้วค่อย verify ให้ · ไฟล์ config ระดับ project ที่ไม่มี secret แก้ตรงได้ตามปกติ

**C4. อ่านไฟล์ตัวอย่าง 1 ไฟล์ก่อนเขียน script กวาดทั้งชุด**
- **ปัญหา:** user ส่งไฟล์ชุดใหม่ที่ไม่ตรงกับที่แผนคาด แต่ถูกเขียน bulk-extraction script กวาดทั้งชุดทันที — ปรากฏว่าเป็นเอกสารคนละประเภท script จะอ่านผิดทั้งหมด
- **กฎ:** ชุดไฟล์ที่ไม่คุ้น → tool call แรก = อ่าน 1 ไฟล์ตัวแทนให้ครบ (sheet, หัวเรื่อง, ตัวเลขหมายถึงอะไร) แล้วสรุปความเข้าใจให้ user 1-2 บรรทัด
- **วิธีใช้:** ยืนยันแล้วค่อย narrow script ไปที่ส่วนที่มีข้อมูลจริง

**C5. Timestamp ต้องติด timezone จริง**
- **ปัญหา:** เวลาจาก clock ในเครื่อง (local timezone) ถูกเขียนลง memory/board/plan เป็น "UTC" → ต้องแก้หลายไฟล์ และ session ถัดไปที่เทียบกับ `created_at` ใน DB (UTC จริง) จะสรุปลำดับเหตุการณ์ผิด
- **กฎ:** ก่อนเขียน timestamp ถามว่ามาจาก clock ไหน · local → เขียนพร้อมชื่อ timezone จริง (`HH:MM UTC (HH:MM <local TZ>)`) · ห้ามเรียกเวลา local ว่า UTC
- **วิธีใช้:** anchor "applied/deployed at" ด้วย clock ของ server/DB (`date -u`, `now() at time zone 'utc'`) ในคำสั่งเดียวกับที่ทำงาน · cross-check: stamp "UTC" ที่ห่างจาก `…Z` ของ git host/server เท่ากับ offset ของ local TZ พอดี = จริง ๆ เป็น local

---

## D. Platform gotchas

**D1. Windows PowerShell → ssh: quote หาย + non-ASCII เพี้ยน**
- **ปัญหา:** (1) PowerShell 5.1 ส่ง argument ให้ native command โดยไม่ escape `"` ข้างใน → คำสั่ง remote ไปถึงปลายทางแบบไม่มี quote · (2) string ที่ pipe เข้า native command ถูก re-encode ผ่าน console codepage → อักษร non-ASCII (เช่น ภาษาไทย) กลายเป็น mojibake หรือแย่กว่านั้นเป็น `?` (กู้จาก live ไม่ได้) · (3) PowerShell ใส่ UTF-8 BOM หน้า stdin ที่ pipe เข้า native command
- **กฎ:** payload ที่มี non-ASCII ห้ามข้าม boundary เป็น text — **base64 ฝั่ง Windows แล้ว decode ฝั่งปลายทาง** (`tr -d '\r' | base64 -di` — `-i` ทิ้ง BOM/byte นอก alphabet) · payload ใส่ assertion ตัวเอง (เช่น checksum หลัง apply) ให้ apply ที่เพี้ยน abort เอง
- **วิธีใช้:** PowerShell 7 (`pwsh`) ส่ง UTF-8 ได้ถูก — บอก user ชัดว่าคำสั่งนี้ใช้ `pwsh` · `ssh -i` ใช้ `$env:USERPROFILE\.ssh\…` (ssh ขยาย `~\` แบบ Windows ไม่ได้) · ทดสอบด้วย function ที่ shadow `ssh` ใน PowerShell พิสูจน์อะไรไม่ได้ ต้องเรียก .exe จริง · หลัง apply ตรวจหา `???` ใน text ที่เขียนลง DB

**D2. PowerShell: output ของ native command เป็น array — operator เปรียบเทียบจะ filter**
- **ปัญหา:** `if ($out -notmatch 'DONE')` บน output หลายบรรทัด คืน *บรรทัดที่ไม่ match* (truthy เกือบเสมอ) ไม่ใช่ boolean → guard ใน deploy script ปฏิเสธทุก deploy จริง
- **กฎ:** `-join "`n"` (หรือ `| Out-String`) ก่อนทดสอบ regex/เทียบค่า
- **วิธีใช้:** ทดสอบ guard ด้วย harness ที่ stub คำสั่งให้คืน array หลายบรรทัด

---

## E. Working style

**E1. ทำต่อเนื่องตามคิวที่ตกลงแล้ว** *(ตัวอย่าง owner preference — ปรับตามคนใช้)*
- **ปัญหา:** จบงาน 1 ชิ้นแล้วปิด turn ด้วยคำถาม "เริ่มชิ้นถัดไปเลยไหม หรือพักก่อน" ทั้งที่คิวตกลงกันไว้แล้ว → user ต้องกลับมาสั่งต่อทุกรอบ
- **กฎ:** คิว/ลำดับตกลงแล้ว → จบชิ้นหนึ่ง รายงานสั้น ๆ แล้วเริ่มชิ้นถัดไปใน turn เดียวกัน · ถามเฉพาะการตัดสินใจที่เป็นของ user จริง (product/บัญชี, action ที่ทำลายข้อมูลหรือเกี่ยวกับเงินที่ยังไม่ได้อนุญาต)
- **วิธีใช้:** เก็บเป็น feedback memory ของ project/user — เป็นความชอบส่วนบุคคล ไม่ใช่กฎสากล

**E2. Design-lessons registry — อ่านก่อนออกแบบ ไม่ใช่หลัง ship**
- **ปัญหา:** ความผิดพลาด *แบบเดียวกัน* ship ซ้ำหลายรอบในหลาย feature/หลาย app เพราะบทเรียนกระจายอยู่ใน PR/handoff
- **กฎ:** รวม root-cause *class* ที่เกิดซ้ำ + กฎที่กันมันไว้ในไฟล์เดียว (`feedback-design-lessons.md`) จัดหมวด (forms, lifecycle, notifications, errors, schema/RLS, authz, money, platform …) · อ่านใน phase design ก่อน lock plan ทุกครั้ง (`/fable-5` Phase 2)
- **วิธีใช้:** เพิ่มเฉพาะเมื่อเป็น *class* และมี incident อ้างอิง · ≤ 5 บรรทัดต่อข้อ · ห้าม prune ว่า YAGNI — ทุกข้อคือหลักฐานของความจำเป็นจริง · ดูรูปแบบที่ `../examples/memory/feedback-design-lessons.md`
