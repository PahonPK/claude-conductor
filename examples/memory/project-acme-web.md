---
workspace: acme-snacks
name: Acme Snacks Website
description: EXAMPLE (fictional) — brand site for Acme Snacks; 12 products + brand story + SEO + blog CMS; Next.js + headless CMS + serverless host
type: project
originSessionId: 00000000-0000-0000-0000-000000000000
---
**Last verified:** YYYY-MM-DD
**Verify rule:** Re-verify if older than 5 days. Recipe in project CLAUDE.md.

## Project: Acme Snacks Website

**Started:** YYYY-MM-DD
**Local repo:** `C:\Users\you\code\acme-web\` — main clean
**Goal:** Brand website where customers can browse all products, read the brand story, find buying channels, and where marketing can add blog posts via a GUI CMS. SEO + AEO optimized.

> EXAMPLE FILE — all content is fictional. Use as a shape reference for a real
> `~/.claude/projects/C--Users-you/memory/project-<name>.md`.

### Current Status (as of YYYY-MM-DD)
- **LIVE ✅** at https://snacks.example.com
- Build green: typecheck=0, lint=0, build=0
- Security pass: CSP + HSTS headers, rate-limited revalidate endpoint, deps audited clean
- Last code-review verdict: GREEN

### Tech Stack
| Layer | Tech |
|---|---|
| Framework | Next.js (App Router) |
| CMS | Headless CMS (e.g. Sanity / Contentful) |
| Hosting | Serverless host (e.g. Vercel) |
| Styling | Tailwind CSS |

### Key Architectural Decisions
- Content in headless CMS so marketing edits without deploys
- `import "server-only"` guards on all server data-fetch modules
- JSON-LD product schema for SEO/AEO; `safeJson` helper escapes `</script>` + U+2028/2029

### Done
- ✅ Scaffold + 12 product pages (YYYY-MM-DD)
- ✅ Security hardening — 4 HIGH + 2 MED fixes applied (YYYY-MM-DD)
- ✅ Deployed to production (YYYY-MM-DD)

### Pending Work
1. Wire up the blog CMS preview mode
2. Add hreflang for the second-language storefront
3. Connect analytics + conversion events
