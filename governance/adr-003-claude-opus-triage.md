# ADR-003: Claude Opus 4.7 as first-line AI triage

- **Status:** Superseded by [ADR-008](adr-008-deepseek-v4-flash-triage.md) (2026-05-13)
- **Original status:** Accepted (2026-05-10 → 2026-05-13)
- **Date:** 2026-05-10
- **Deciders:** Founder
- **Tags:** ai cost accuracy

## Context

The AI triage agent must classify every inbound issue / discussion into one of 9 mutually-exclusive categories (per ADR-002 and `community-ai-triage-policy.md`). Two categories carry asymmetric costs: `security_critical` false-negatives are dangerous (real security issue mis-routed to public response), and `out_of_scope` errors invite mission-drift requests to escalate.

Pilot testing across 50 hand-labeled fixtures showed ~99% accuracy for Claude Opus 4.7 on the `security_critical` boundary and ~95% on the `out_of_scope` distinction. Sonnet 4.6 was ~3-5 percentage points lower on `out_of_scope` (the harder category — it requires understanding nuanced mission scope vs platform-feature creep).

Per-issue cost is dominated by ~3000 input tokens × Opus pricing. At ~$0.05/issue and 50-200 issues/month projected for BETA, monthly cost lands in $2.50-$10.00 — well within the <$20/mo budget.

## Drivers

- **D1.** Triage accuracy on `out_of_scope` ≥95% across labeled corpus.
- **D2.** Triage detection of `security_critical` ≥99% (false-negative cost is high).
- **D3.** Per-issue cost <$0.10 averaged.
- **D4.** Multilingual fluency — Chinese + English inputs handled with comparable accuracy.

## Considered Options

- **A. Claude Opus 4.7** (chosen) — highest accuracy headroom; ~$0.05/issue
- **B. Claude Sonnet 4.6** — ~$0.01/issue but ~3-5% lower accuracy on `out_of_scope`; viable fallback
- **C. Claude Haiku 4.5** — ~$0.002/issue but accuracy drops to ~85% on `out_of_scope`; rejected for v1
- **D. Local Llama 70B** — zero per-call cost but inference infra burden + power cost on debian1301 not justified at this volume
- **E. Mixed routing** (Haiku → Opus on uncertain cases) — clever but adds dispatch complexity; deferred

## Decision

Choose **A** for v1 BETA. Use the latest available `claude-opus-4-7` model id. Trigger to revisit (option B as Sonnet matures, or option E as volume grows) is documented below.

## Validation

- **V1. (Cost)** Per-issue Claude API cost <$0.10 averaged over a rolling 200-issue window; `tests/perf/triage_cost.py` reads `triage.classified{cost_usd}` log lines and computes the rolling mean.
- **V2. (Accuracy — out_of_scope)** Classification accuracy ≥95% on the 50-fixture labeled corpus `tests/fixtures/out_of_scope_eval.json`; `tests/eval/out_of_scope_accuracy.py` runs all 50 fixtures and asserts.
- **V3. (Accuracy — security_critical)** Detection sensitivity ≥99% on the 20 known-security + 20 security-adjacent-but-not corpus `tests/fixtures/security_eval.json`; 0 false negatives required (block on any), false positives ≤5%.
- **V4. (Multilingual)** Accuracy gap between Chinese-input fixtures and English-input fixtures ≤5 percentage points across all 9 categories; `tests/eval/multilingual_accuracy.py` reports per-language confusion matrix.
- **V5. (Token budget)** Total prompt input tokens <4000 per call across 100-issue sample (system + KNOWN_ISSUES + recent issues + new issue); `tests/perf/prompt_tokens.py`.

## Re-evaluation triggers

- **T1.** Per-issue cost > $0.10 for 30 consecutive days (cost-overshoot trigger; consider Sonnet route).
- **T2.** AI handle-rate <70% for 14 consecutive days (accuracy degrading; KNOWN_ISSUES → RAG migration per ADR-006 may be needed first).
- **T3.** Anthropic deprecates `claude-opus-4-7` with no equivalent or better replacement available.
- **T4.** New Claude model released with ≥5% accuracy improvement on `out_of_scope` at lower or equal cost.
- **T5.** Volume scales to >500/month and mixed Haiku→Opus routing has ≥3× ROI in measured monthly cost.

## References

- Source: `community-async-plan.md` §四.3 (model choice), §四.6 (cost), `community-ai-triage-policy.md` (9-category contract)
- Related ADR: ADR-006 (KNOWN_ISSUES; reduces cost via prompt size), ADR-002 (the 9-category contract this model implements)
- Related risk: R-01 (mis-classification — V2 / V3 are direct mitigations), R-02 (cost overrun — V1 is the direct mitigation)
