# Claude Memory — (your handle)

> EXAMPLE memory index (100% fictional). Shows what a filled-in
> `~/.claude/projects/C--Users-you/memory/MEMORY.md` looks like.
>
> Index of all project memory files, grouped by **workspace**.
> 📏 กฎ index: entry ละ ≤ 3 บรรทัด (สถานะปัจจุบัน + critical pending เท่านั้น) —
> changelog/commit history อยู่ใน project file **ห้ามอยู่ที่นี่**
> Workspace CLAUDE.md: `~/.claude/workspaces/<name>/CLAUDE.md` · Global rules: `~/.claude/CLAUDE.md`
>
> ℹ️ ในตัวอย่างนี้มี sample memory file จริงให้ดูแค่ไฟล์เดียว — `project-acme-web.md`
> (entry ที่มี link). entry อื่น ๆ เป็น plain text เพื่อโชว์ว่า index หน้าตาเป็นยังไง
> เวลากรอกครบ — ใน instance จริงทุก entry จะ link ไป `project-*.md` ของตัวเอง

---

## 🏢 acme-corp workspace (Corporate / HQ / Operations)

- **Acme ERP** (`project-acme-erp.md`) — Next.js + self-hosted Supabase, internal ops; live app.example.com; 5 modules. **Pending:** finish HR module RBAC.
- **Acme Automation** (`project-acme-automation.md`) — workflow automation; 4 flows active (verified YYYY-MM-DD).

## 🎨 acme-snacks workspace (Brand — consumer retail)

- [Acme Snacks Website](./project-acme-web.md) — **LIVE ✅ https://snacks.example.com** (Next.js + headless CMS), verified YYYY-MM-DD; repo `acme-web/` main clean. *(← the one sample file included in this repo)*

## 🤝 Shared / cross-workspace

- (none yet)

## 👤 User

- **System Info** (`user-system-info.md`) — OS, shell, tools available, working directory

## 📚 Feedback (global lessons — apply ทุก project)

- **Testing Standard** (`feedback-testing-standard.md`) — ห้าม mark auth/login test passed โดยไม่ e2e จริงกับ DB

---

*EXAMPLE / fictional · Last consolidated: YYYY-MM-DD*
