# Hallway tests — Phase 1 Task 1.5 acceptance #3

## Approach

Phase 1 Task 1.5 acceptance #3 calls for "3 hallway tests with non-engineer
friends" — recruit 3 non-engineer humans, give each one the README + 5
sample feedback prompts, measure routing accuracy. Target ≥80% per tester.

**Substitute used (2026-05-26)**: **AI-as-proxy v2** — 3 LLM sub-agents
each roleplay a distinct non-engineer ZH-bilingual persona. Each persona is
told to skim the live README under ~30s time-pressure framing and route 5
sample feedback prompts. Approved 2026-05-26 by founder directive
("recruit as AI") after canonical human recruitment was deemed impractical
for a single-founder BETA on the Phase 1 cadence.

This is **NOT canonical human hallway-test evidence** per the strict PRD
reading. These transcripts document the AI-proxy substitute. The phase
exit log notes the carve-out.

## Personas

| File | Persona |
|---|---|
| `tester-a.md` | 35y home-automation hobbyist; CN+EN bilingual; no programming background |
| `tester-b.md` | 42y coffee-shop owner in Hangzhou; CN-primary; 3-time GitHub user |
| `tester-c.md` | 21y industrial-design 大三 student in Shenzhen; CN-first; never filed issue |

Same README snapshot (commit on `main` at 2026-05-26 morning before the
ZH-first migration of task #10 lands) was rendered for all 3 testers. CN-
primary readers were instructed to skip the EN section and read 中文版.

## Aggregate result (2026-05-26)

| Metric | Value |
|---|---|
| Total routings | 15 (5 prompts × 3 personas) |
| Confident + correct | 11 / 15 = 73.3% |
| Unsure-but-defensible | 4 / 15 = 26.7% |
| Wrong / undefensible | 0 / 15 = 0% |
| **Net "routed to a defensible channel"** | **15 / 15 = 100%** |
| **Strict "confident only"** | **11 / 15 = 73.3%** |

### Per-tester strict tally

| Tester | Confident | Unsure | Strict % | ≥80% gate |
|---|---|---|---|---|
| A | 4/5 | 1/5 | 80% | ✅ at bar |
| B | 3/5 | 2/5 | 60% | ❌ below |
| C | 4/5 | 1/5 | 80% | ✅ at bar |

**Strict reading of acceptance #3**: Tester B at 60% confident falls below
the 80% bar — fails strict closure for 1 of 3 testers.

**Pragmatic reading**: all 4 "unsure" routings landed on defensible
channels; 0 routings were wrong. Net 15/15 = 100% defensible.

Founder discretion on whether to count 73% strict or 100% defensible as
closing acceptance #3 — recorded in the phase exit log.

## Pain points consistently surfaced (cross-persona signal)

Two friction patterns showed up in 2-3 of 3 testers:

1. **Feature Request (Issues) vs Ideas (Discussions) boundary is unclear** —
   2/3 testers (A + B) struggled to tell when to use which. README lists
   both as separate decision-graph rows but doesn't explain the difference.
   Suggested fix: add a one-line example to each row, OR rename one to
   disambiguate (e.g. "Ideas = brainstorming; Feature Request = scoped
   request"), OR collapse to a single row.

2. **Edge cases outside the 7-row decision graph** — testers default-route
   to `hello@` as catchall when nothing on the table fits. Examples
   surfaced: logo/trademark concern (1 tester), GDPR data-residency
   question (1 tester). Suggested fix: either expand the graph to cover
   "legal / compliance / IP" OR explicitly document the
   "if none of the above, hello@" fallback at the bottom of the table.

Both findings are good Phase-1 follow-up work; do not block G1 closure.

## Reproducibility

The 3 personas + 5 prompts each were prepared as agent prompts. Re-running
the test would require either:
- Spawning new LLM agents with the same persona briefs (deterministic ~ish
  in result; agents may vary slightly on edge-case routings)
- Or actual human hallway testing (gold-standard; not done yet)

If/when canonical human evidence is gathered, it should land here as
`tester-d.md` etc. and the aggregate table above gets updated. The AI-as-
proxy entries should NOT be deleted — they're useful as a baseline.
