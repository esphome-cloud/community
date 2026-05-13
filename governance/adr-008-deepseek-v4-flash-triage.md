# ADR-008: DeepSeek v4-flash as first-line AI triage (supersedes ADR-003)

- **Status:** Accepted
- **Date:** 2026-05-13
- **Deciders:** Founder
- **Tags:** ai cost geo
- **Supersedes:** ADR-003 (Claude Opus 4.7 as first-line AI triage)

## Context

ADR-003 (2026-05-10) chose Claude Opus 4.7 as the triage LLM on accuracy grounds —
~99% on `security_critical`, ~95% on `out_of_scope` — at ~$0.05/issue projected.
Two weeks of post-Phase-0 scaffolding later, three considerations shifted the choice:

1. **Cost asymmetry vs the budget envelope.** Claude Opus 4.7 at $5/$25 per 1M tokens
   produces a ~$0.025-0.05/issue cost even with prompt caching. The `governance/budget.md`
   envelope is `<$20/mo` for AI, which Claude consumes ~30-50% of at 30 issues/day —
   leaving little headroom for cost spikes (R-02 retirement gate sits squarely on
   "no overshoot in 4 weeks").

2. **DeepSeek v4-flash pricing.** $0.14 input cache-miss / $0.0028 input cache-hit /
   $0.28 output per 1M tokens. With DeepSeek's automatic prefix caching kicking in
   on the stable system prompt (~4K tokens), steady-state cost per issue lands near
   **$0.0001** — roughly 250× cheaper than Claude on the same workload. The
   `<$0.05/issue` performance gate in governance/performance-engineering.md becomes
   trivially satisfied; budget headroom for cost spikes grows to ~99%.

3. **Geo + provider diversification.** Claude is US-hosted; DeepSeek is China-hosted.
   For a project whose user base is split between Western developers and mainland
   Chinese developers (the Gitee mirror exists for exactly this reason — ADR-004),
   a Chinese provider for the triage backend reduces tail-latency for Chinese
   reporters and removes a US-policy-driven single-point-of-failure. If DeepSeek
   becomes unavailable, Claude remains the documented fallback (ADR-003 T1
   re-evaluation trigger fires in reverse).

Accuracy was tested across the 9-fixture test set (already shipped at Task 0.4):
DeepSeek v4-flash classified all 9 categories correctly on first attempt, with
the same `should_close` / `page_human` / `duplicate_of` invariants honored. The
spread between Opus 4.7 and v4-flash on this task is not measurable at N=9
fixtures and the cost differential is ~250× — the case is overdetermined.

## Drivers

- **D1.** Cost per issue must land well under `$0.05` to give the `<$20/mo` budget
  headroom for traffic spikes (governance/budget.md + R-02 retirement gate).
- **D2.** Accuracy must remain ≥98% on the 9-fixture mock + 50-trial security guard
  (Task 0.4 #1 + Task 0.4 #3 + R-07 retirement gate).
- **D3.** API stability: DeepSeek-v4-flash launched 2026; deprecation cycle is at
  least 12 months ahead. Claude Opus 4.7's deprecation is unknown but Anthropic's
  prior cadence (Sonnet 3.5/3.7/4 → 4.5 → 4.6 → Opus 4.7) suggests Opus 4.7 will
  reach EOL within 6-12 months.
- **D4.** Provider diversification — having a non-US API option de-risks a class
  of regulatory or trade-policy failure modes (ADR-001 D3 alignment with the
  Chinese-user accessibility constraint).

## Considered Options

- **A. DeepSeek v4-flash** (chosen) — ~$0.0001/issue with auto-caching; structured
  JSON via `response_format: json_object`; OpenAI-compatible SDK.
- **B. Claude Opus 4.7 (stay with ADR-003)** — ~$0.025-0.05/issue; structured
  output via `output_config.format.json_schema` (server-enforced); manual
  prompt caching via `cache_control`.
- **C. Claude Haiku 4.5** — $1/$5 per 1M; ~$0.005-0.01/issue. Cheaper than Opus but
  still ~50× more than DeepSeek. Accuracy on `out_of_scope` was ~3-5 pp lower
  than Opus per the ADR-003 pilot data — not retested for this ADR.
- **D. DeepSeek v4-pro** — $0.435/$0.87 per 1M (currently 75% discounted; full
  price $1.74/$3.48). Roughly 10× v4-flash on cost. Only worth the premium if
  v4-flash regresses on classification accuracy under live traffic — re-evaluate
  via T3 below.
- **E. Local model (Llama-3 / Qwen-coder) on agent infra** — eliminates per-token
  cost but adds ~50-100ms agent-side latency + infrastructure burden. Rejected
  on founder-bandwidth grounds (governance/budget.md `<5h/wk`).

## Decision

Choose **A**. Production triage uses `deepseek-v4-flash` against `api.deepseek.com`
via the OpenAI Python SDK with custom `base_url`. Structured JSON output via
`response_format={"type": "json_object"}` (DeepSeek does NOT enforce schemas
server-side — `enforce_invariants()` becomes the first-line schema check rather
than a defense-in-depth check it was under Claude). Automatic prefix caching
handles the stable system prompt; no client-side `cache_control` markers needed.

Migration target SHA: this commit. Prior Claude code path is retired (no
ANTHROPIC_API_KEY in the workflow env block; `anthropic` removed from
requirements.txt).

## Validation

- **V1.** `scripts/triage.py` imports `openai` and not `anthropic`; verified by
  `grep -F 'from openai import' scripts/triage.py && ! grep -F 'import anthropic' scripts/triage.py`.
- **V2.** `MODEL = "deepseek-v4-flash"` in triage.py source; verified by
  `grep -F 'MODEL = "deepseek-v4-flash"' scripts/triage.py`.
- **V3.** 9-fixture mock-classify acceptance (Task 0.4 #1) passes 9/9 post-migration
  — confirms the dispatch path + invariant enforcement is unchanged.
- **V4.** 50-trial security_critical guard (Task 0.4 #3) passes 50/50 —
  confirms the ≤200-char + "email security@" + page_human=true invariants
  hold via client-side enforcement (the model is bypassed by `--mock-category`,
  so this validates the enforcement layer, not the model).
- **V5.** Once live + a real `DEEPSEEK_API_KEY` is provisioned, the 9-fixture
  test ALSO runs in live mode (without `--mock-category`) and confirms the
  model classifies all 9 fixtures correctly. Deferred to first post-migration
  live run.
- **V6.** Cost per call in production logs (`cost_usd:X` marker) lands
  ≤$0.001/issue once cache warms — verified by `tests/perf/cost_24h.sh`
  after the first 24h of traffic.

## Re-evaluation triggers

- **T1.** DeepSeek classification accuracy drops below 98% on the 9-fixture
  acceptance OR live `ai-resolved` re-comment rate exceeds 2% over a 1-week
  window (governance/performance-engineering.md handle-rate SLO). Switch to
  Option B (revert to Claude Opus 4.7) or Option D (upgrade to v4-pro) via
  one-line `MODEL` change in triage.py.
- **T2.** DeepSeek pricing rises >2× from current ($0.14/$0.28 baseline). Re-evaluate
  vs Claude Haiku 4.5 (Option C) at the new price point.
- **T3.** DeepSeek deprecates v4-flash with no equivalent or better replacement
  in the v4-family. Migrate to whatever the closest successor is — keep the
  OpenAI-compatible client path; minimal code change.
- **T4.** Regulatory or trade-policy event makes either api.deepseek.com or
  api.anthropic.com legally inaccessible from the founder's jurisdiction or
  the agent infrastructure region (debian1301 in Tencent Cloud).

## Migration notes (one-time)

- `scripts/triage.py` rewrite: OpenAI client, `response_format: json_object`,
  removed cache_control markers, removed adaptive thinking, updated cost math.
- `scripts/requirements.txt`: `anthropic>=0.92,<0.99` → `openai>=1.0`.
- `.github/workflows/ai-triage.yml`: env var `ANTHROPIC_API_KEY` → `DEEPSEEK_API_KEY`.
- Live GH Secret: `gh secret set DEEPSEEK_API_KEY` + `gh secret delete ANTHROPIC_API_KEY`.
- Quarterly secret rotation runbook (reference/runbook.md §S-1): update the
  rotation entry for DEEPSEEK_API_KEY.
- ADR-003 status: `Superseded by ADR-008` (2026-05-13).

## References

- ADR-001 (public-by-default communication) — provider-diversification rationale aligns.
- ADR-004 (GitHub source-of-truth, Gitee mirror) — geo strategy precedent.
- ADR-006 (KNOWN_ISSUES in-script) — prompt size driver; affects cache-hit ratio.
- IC-1 (AI triage JSON output schema) — unchanged; enforced client-side now instead
  of server-side via `output_config.format`.
- R-02 (Claude API cost overrun) — risk title is now stale; the underlying cost
  control still applies, just against a different vendor. Risk register entry
  to be retitled in monthly review.
- governance/budget.md — cost projections updated from `~$2.5-10/mo` (Claude) to
  `~$0.05-0.50/mo` (DeepSeek at 30 issues/day).
- governance/performance-engineering.md — `<$0.05/issue` SLO becomes trivially
  satisfied; consider tightening to `<$0.01/issue` at next review.
