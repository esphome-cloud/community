# ADR-004: GitHub as single source of truth, Gitee read-only mirror only

- **Status:** Accepted
- **Date:** 2026-05-10
- **Deciders:** Founder
- **Tags:** china architecture sustainability

## Context

~30-50% of Chinese developers experience GitHub friction (network instability, corporate firewalls, account-registration risk-control). The naive solution is to provision parallel issue trackers on Gitee, Coding, and GitCode. This *quadruples* the founder's operational surface and produces inconsistent state when sync fails (which it does, regularly).

The asymmetric solution: pick **one** Chinese mirror (Gitee — largest, most independent), make it **read-only**, and provide alternative feedback paths (email, web form, Chinese signup guide) for users who genuinely cannot use GitHub. Gitee covers ~80% of Chinese developers; combined with GitHub's ~65% direct accessibility (among Chinese-accessible developers), coverage reaches ~95%. Marginal gain from adding Coding (~+1%) is not worth the operational cost.

## Drivers

- **D1.** Single founder cannot operate parallel feedback systems (5h/week cap).
- **D2.** Chinese users need at least *read* access to code / docs / releases.
- **D3.** Marginal coverage gain from Coding/GitCode/Atomgit <1% over Gitee+GitHub.
- **D4.** Bidirectional sync is operationally infeasible (always conflicts).
- **D5.** Public Gitee mirror + Chinese signup guide are deliberate Chinese-language GEO assets.

## Considered Options

- **A. Gitee read-only mirror only** (chosen)
- **B. Gitee + Coding parallel issue tracking** — rejected: 4× workload; data fragmentation
- **C. Self-hosted Chinese-region Gitea** — rejected: operational burden exceeds value
- **D. Gitee bidirectional sync** — rejected: conflict-prone; would need conflict-resolution UX
- **E. No Chinese mirror; rely on GitHub-acceleration tools (ghproxy / FastGit)** — rejected: doesn't help users blocked at corporate firewall

## Decision

Choose **A**. GitHub remains single source of truth (`github.com/esphome-cloud/community` + 3 product repos). Gitee is read-only one-way mirror via `Yikun/hub-mirror-action@master` with 6h cron + push triggers + manual dispatch. Static repo list: `community,esphome-cloud,rshome,espctl`. Feedback always goes back to GitHub or email — never accepted on Gitee.

## Validation

- **V1. (Sync drift)** Gitee mirror HEAD commit lags GitHub HEAD by ≤6h+10min (cron interval + workflow runtime) over a 25h soak; `tests/perf/mirror_drift.sh` runs hourly.
- **V2. (Workflow config)** `mirror-to-gitee.yml` declares `force_update: true` and uses `Yikun/hub-mirror-action@master`; `tests/repo/mirror_config.sh` greps for both literals.
- **V3. (Feedback never accepted on Gitee)** Gitee Issues feature DISABLED in repo settings. If platform forces enabled (some Gitee tiers do), exactly 1 pinned Issue exists with title containing "Please use GitHub for issues" + auto-close script for any new issues. `tests/integration/gitee_issues_state.sh` checks via Gitee API or scrape.
- **V4. (Private branches not mirrored)** Mirror excludes any branch named `private/*`; verified by configuring a dummy `private/test` branch on GitHub and asserting it does NOT appear on Gitee. `tests/repo/mirror_private_excluded.sh`.
- **V5. (Chinese guide accessible from Gitee)** `https://gitee.com/esphome-cloud/community/raw/main/docs/github-signup-cn.md` returns HTTP 200; `tests/integration/cn_guide_on_gitee.sh`.

## Re-evaluation triggers

- **T1.** >50/month "I don't have GitHub and won't email either" feedback measured at `feedback@` mailbox (activate the deferred Gitee Issue → GitHub Issue Cloudflare Worker bridge per source plan §四.2).
- **T2.** Coding-specific user inquiries >20/month (consider Coding read-only mirror; Coding remains issue-disabled).
- **T3.** Self-hosted client requires GitLab CI integration as deliverable (consider 极狐 GitLab read-only mirror).
- **T4.** Gitee disrupts service or substantially changes API (>72h outage, or breaking API change without 30-day notice) — consider replacement (CodeChina / Atomgit) or fallback (no mirror, intensify Chinese signup guide promotion).
- **T5.** GitHub becomes accessible to >85% of Chinese developers without acceleration (geopolitical change) — relax mirror priority but retain it as a GEO asset.

## References

- Source: `community-china-mirror.md` §一-§六 (whole document)
- Related ADR: ADR-001 (public-by-default; mirror reinforces), ADR-007 (feedback@ is one of the fallbacks)
- Related risk: R-03 (mirror sync drift > 24h)
