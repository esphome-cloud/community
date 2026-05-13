# ADR-006: KNOWN_ISSUES as in-script Python string (deferred RAG upgrade)

- **Status:** Accepted
- **Date:** 2026-05-10
- **Deciders:** Founder
- **Tags:** ai infra cost

## Context

The AI triage agent needs a knowledge base for the `known_issue` classification (which produces an auto-response with the canned solution). Two viable implementations:

**Option A (this ADR):** Embed `KNOWN_ISSUES` as a Python string constant inside `scripts/triage.py`. Each entry is `~150 tokens` (issue description + solution + docs link). Founder hand-curates weekly; weekly +3-5 entries; 3-month target ~30-50 entries.

**Option B (deferred):** Embeddings + vector retrieval against `docs.esphome.cloud` content. Each call retrieves top-K relevant chunks. Eliminates manual curation but adds a vector store + retrieval service to operate.

For Phase 0 launch, Option A's setup time is ~10 minutes; Option B's setup time is days (vector store, ingestion pipeline, retrieval API). Per-call token budget is dominated by KNOWN_ISSUES at ~30 entries × 150 tokens = 4500 tokens — ABOVE the prompt budget. So Option A has a known scaling limit.

## Drivers

- **D1.** Phase 0 setup time ≤2 days (Option A: minutes; Option B: days).
- **D2.** Per-call token budget <4000 input tokens (both options must respect this; Option A starts comfortable, gets tight at ~25-30 entries).
- **D3.** Founder curation time ≤30 min/month (Option A grows linearly; Option B is mostly automated).
- **D4.** AI handle-rate target ≥80% (both options can hit; Option B has higher ceiling at scale).

## Considered Options

- **A. In-script Python string** (chosen for v1)
- **B. Embeddings + vector RAG over docs.esphome.cloud** — deferred; activate when triggers below fire
- **C. SQLite full-text search over a curated KB** — middle ground; rejected as needless infra for v1

## Decision

Choose **A** for v1 (Phase 0). Embed `KNOWN_ISSUES` as a Python string in `scripts/triage.py` with 4 seeded entries from source plan §四.3 (ESP-IDF venv conflict, WebRTC firewall, ESP32-S3 LVGL OOM, Claude Code MCP setup). Founder grows the string +3-5/week.

Migration to Option B is triggered (not scheduled). Triggers and runbook chapter are documented below.

## Validation

- **V1. (Initial seed)** `KNOWN_ISSUES` Python string in `scripts/triage.py` contains ≥4 entries marked by `ISSUE #` literal; `grep -c 'ISSUE #' scripts/triage.py >= 4`.
- **V2. (Token budget under growth)** Total prompt input tokens (system + KNOWN_ISSUES + 30 recent issues + new issue) <4000 across a 100-issue sample; `tests/perf/prompt_tokens.py` reports the histogram.
- **V3. (Curation cadence)** Git log of `scripts/triage.py` shows ≥3 KNOWN_ISSUES additions per month for the first 3 months post-launch; `tests/repo/known_issues_growth.sh` counts diff-added markers per month.
- **V4. (Handle-rate target)** AI `ai-resolved` rate ≥80% over rolling 200-issue window; `tests/perf/handle_rate.sh` (V-PHASE-04 capacity pattern). This is the dominant signal that the KB is healthy.

## Re-evaluation triggers

- **T1.** AI handle-rate falls below 70% for 14 consecutive days (KB inadequate; vector RAG can retrieve more dynamically).
- **T2.** `KNOWN_ISSUES` string grows past 50 entries (token-budget pressure; V2 will start reporting >4000 tokens).
- **T3.** Founder spends >30 min/week curating `KNOWN_ISSUES` (RAG would automate via doc ingestion).
- **T4.** Per-issue cost > $0.10 for 30 days due to growing prompt size (cost trigger overlaps with ADR-003 T1; same migration target).
- **T5.** Volume exceeds 500 issues/month (manual KB cannot scale; RAG is forced).

## References

- Source: `community-async-plan.md` §四.3 KNOWN_ISSUES initial 4 entries, §四.5 持续优化
- Related ADR: ADR-003 (Claude Opus; cost depends on prompt size which depends on KNOWN_ISSUES size)
- Related risk: R-01 (mis-classification — KB quality drives `known_issue` accuracy specifically), R-02 (cost overrun — token budget pressure)
