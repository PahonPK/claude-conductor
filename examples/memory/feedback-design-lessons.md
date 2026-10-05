---
name: feedback-design-lessons
description: EXAMPLE (fictional) design-time lessons registry — recurring root-cause classes with the rule that prevents each; read in /fable-5 Phase 2 before designing any feature
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000000
---

# Design lessons — read BEFORE designing, not after shipping

**Why:** the same mistakes ship repeatedly when lessons live scattered across PRs and handoffs. Root cause + preventing rule in ONE place, re-read at design time.
**How:** `/fable-5` Phase 2 reads this before locking any plan that touches UI, document lifecycle, notifications, client writes, schema, money or auth. Add or strengthen an entry only for a *class* of mistake (not a one-off), ≤ 5 lines each, and cite the incident/PR that proved it. Do not prune entries as YAGNI — each one is the evidence of real need; prune only when the mechanism it guards no longer exists.

## A. Forms & vocabulary

**A1. Model the user's real decision, not the schema.** Users think in business choices ("receipt or tax invoice?"), not in columns ("amount + tax field"). Make the everyday choice the control and derive the columns from it. When porting a form to another app, mirror the write payload exactly but re-check every label against this rule. *(example incident: a stray tax field on plain receipts needed a cleanup migration)*

## B. Notifications & idempotency

**B1. Idempotency keys are per business event, not per row write.** A key built from the row id fires again on every retry/edit of the same event. Derive it from (event type + document id + state transition). *(example incident: duplicate notifications shipped three times in different modules before this rule existed)*

## C. Errors & failure paths

**C1. Zero rows affected is not success.** An UPDATE/RPC that matched nothing must surface as an error (or a distinct "nothing to do" state), never as a green toast. *(example incident: an approve button "succeeded" on an already-cancelled document)*

<!--
EXAMPLE FILE — all entries are generic illustrations. In a real instance this file
grows category by category (forms, lifecycle, notifications, errors, shared client
state, schema/migrations/RLS, authorization, money & dates, platform boundaries,
gates & shipped-ness). See docs/06-lessons-learned.md §E2.
-->
