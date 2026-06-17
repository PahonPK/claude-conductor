# 04 — Onboarding New Project / Workspace

> Source: §Onboarding new project + §Per-project CLAUDE.md ใน `../CLAUDE.md`
> และ §Onboarding ใน `../MEMORY_SCHEME.md`
> Templates พร้อมใช้อยู่ใน `../templates/`

---

## A. Onboard project ใหม่ (4 ขั้น)

```
1. CREATE memory file:
   ~/.claude/projects/C--Users-you/memory/project-<name>.md
   ↳ frontmatter (workspace / name / description / type / originSessionId)
   ↳ + Last verified date + Verify rule pointer
   ↳ + sections: Current Status / Tech Stack / Key Decisions / Done / Pending
   → ใช้ templates/project-memory.md.template

2. ADD เข้า MEMORY.md (ภายใต้ workspace group ที่ถูกต้อง, ≤ 3 บรรทัด)

3. ADD cwd mapping row ใน ~/.claude/CLAUDE.md §Project mapping
   (ถ้า project มี cwd ของตัวเอง) — ข้อนี้ลืมบ่อย!

4. CREATE <project-root>/CLAUDE.md
   → ใช้ templates/project-CLAUDE.md.template
```

### Per-project CLAUDE.md ต้องมี 4 ส่วน (บังคับ)

ทุก project root ที่ active ต้องมีไฟล์ `<project-root>/CLAUDE.md` ประกอบด้วย:

1. **Stack** — ภาษา / framework / version
2. **Output / Code / Review rules** เฉพาะ project นั้น
3. **Stack-specific conventions**
4. **Memory Persistence** (บังคับ) — memory file path + save triggers +
   **verify recipe** (3–7 read-only commands ที่ใช้ตรวจ memory เทียบ reality)

---

## B. Onboard workspace ใหม่ (5 ขั้น)

```
1. mkdir ~/.claude/workspaces/<name>/
2. CREATE ~/.claude/workspaces/<name>/CLAUDE.md
   ↳ Identity / scope
   ↳ Project list (link ไป memory files)
   ↳ Cross-ref rules (ถ้า inherit จาก workspace อื่น)
   → ใช้ templates/workspace-CLAUDE.md.template
3. ADD row (+ trigger keywords) ใน ~/.claude/CLAUDE.md §Workspace Registry + Auto-load
4. ADD section ใน MEMORY.md
5. CREATE project แรก (ตามขั้นตอน A ข้างบน)
```

---

## C. Verify recipe — หัวใจของ "เชื่อ memory ได้ไหม"

ทุก project CLAUDE.md ต้องมี verify recipe = **3–7 read-only commands** ที่ตรวจว่า
memory ตรงกับความจริงหรือยัง รันเมื่อ `Last verified` เก่ากว่า 5 วัน

ตัวอย่างต่อ stack (เต็มอยู่ใน `../MEMORY_SCHEME.md` §Verify recipe examples):

**Next.js + Supabase:**
```bash
git status --short
git log --oneline -10
ls supabase/migrations/ | tail -5
find src/app -name "page.tsx" | wc -l
npx tsc --noEmit 2>&1 | tail -3
```

**Vite + React + Supabase:**
```bash
git status --short
git log --oneline -10
ls src/pages/
ls supabase/migrations/ 2>/dev/null | tail -5
```

**Workflow automation (n8n / Make):** query workflow API + executions เพื่อเช็ค active/version/node count

**WordPress / hosted site:** `curl -sI https://<domain>` + cert expiry + WP version

หลักการ: recipe ต้อง read-only, เร็ว, และตอบคำถามว่า "memory บอกแบบนี้ — code/infra
จริงเป็นแบบนั้นจริงไหม"

---

## Memory hygiene cadence (สรุป)

| ความถี่ | ทำอะไร |
|---|---|
| ทุก session start | auto-load workspace CLAUDE.md (ตาม cwd / topic) |
| ทุก milestone | update project memory + MEMORY.md one-liner |
| ทุก 5–7 วัน | ถ้า `Last verified` stale → run verify recipe ก่อน trust |
| ทุกไตรมาส | run `/consolidate-memory` |
| Multi-session | update SESSION-BOARD.md ตอน claim/finish + prune stale rows |
| ก่อน major refactor | backup `~/.claude/CLAUDE.md` ไป `~/.claude/backups/` |
