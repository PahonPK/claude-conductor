---
name: feedback-testing-standard
description: EXAMPLE (fictional) feedback memory — never mark auth/login tests passed without a real end-to-end sign-in against the DB; always state coverage gaps
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000000
---

When testing features that depend on external services (auth, database), do NOT mark tests as "completed" if only UI rendering was verified.

**Why:** the user was told "login test passed", but only the page render had been checked — the real sign-in call was never exercised. The user found the bug themselves after running the DB migrations, and trust in "done" reports dropped.

**How to apply:**
- Report results in two parts: "verified: …" / "not verified: … (because …)"
- As soon as the DB setup exists, run the real end-to-end test before declaring success
- Never mark auth/login as passing without an actual successful sign-in
- Limited coverage → say so explicitly; never imply full coverage

Related: [[feedback-design-lessons]]

<!--
EXAMPLE FILE — shape of a feedback memory: frontmatter (type: feedback) + the rule
in one or two sentences + **Why:** (the incident, generic) + **How to apply:** (what
to do next time). Keep it under ~3 KB; one lesson per file. The public catalogue of
lessons lives in docs/06-lessons-learned.md.
-->
