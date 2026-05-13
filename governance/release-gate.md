# Release Gates — community

Profile triggers (`high_availability=true`) emit a release-gate artifact per `methodology/governance-triggers.md`. This document enumerates the binding criteria for each gate, the slip protocol if a gate cannot close on schedule, and the gate-owner.

## Gate overview

```
G0 (Foundation) ──► G1 (Three Channels Live) ──► G2 (China Fallback) ──► G3 (BETA Public Launch + Week-1)
                                                                                         │
                                                                                         ▼
                                                                                G4 (BETA → GA) — deferred 8-12 weeks post-G3
```

5 gates total: 4 in-phase (G0-G3) + 1 BETA→GA (G4, deferred).

## G0: Foundation

- **Owner:** founder
- **Phase:** 0 exit
- **Target close date:** Day 1, end of morning

### Binding criteria

- [ ] All 6 Phase-0 task acceptance checkboxes ticked with linked evidence
- [ ] AI triage classifies 5 dummy issues with right category in 5/5 trials (Task 0.6 acceptance)
- [ ] SMTP pager smoke-test sends 1 email and respects security-only rule across 45 trials (Task 0.5 acceptance)
- [ ] Cost-per-issue measured at < $0.10 across the 5-issue smoke
- [ ] No secret leaks detected in GH Actions logs (`tests/security/no_smtp_leak.sh` clean)
- [ ] R-04 (SMTP cred leak) status moved to `Mitigating`

### Slip protocol

Slip ≤ 4h: continue same day; document slip in monthly review.
Slip > 4h: stop; founder reviews root cause (likely an Anthropic API quota issue or SMTP misconfiguration); escalate per cause.

### Validation

```bash
PRD_ROOT=$(pwd)/.prd/community tools/prd-lint.sh
[ "$(jq -r '.signals.scale' .prd/community/_profile.json)" = "s" ]
gh issue list --repo esphome-cloud/community --label ai-resolved --limit 5 --state closed --json number | jq 'length == 5'
```

## G1: Three Channels Live

- **Owner:** founder
- **Phase:** 1 exit
- **Target close date:** Day 1, end of afternoon

### Binding criteria

- [ ] All 5 Phase-1 task acceptance checkboxes ticked with linked evidence
- [ ] End-to-end smoke succeeds: open issue → AI replies in <90s; email feedback@ → auto-reply in <60s; start Discussion in Q&A → AI replies in <90s (1 trial each, 3/3)
- [ ] README publicly readable on github.com/esphome-cloud/community with all required sections
- [ ] R-07 (footer disclosure) status moved to `Mitigated` after 50 AI responses verified contain footer

### Slip protocol

Slip ≤ 1 day: continue Day 2; document slip.
Slip > 1 day: phase-1 likely has a configuration issue (Discussions enable, mailbox provisioning). Founder works through issue; phase-2 cannot start until G1 closes.

### Validation

```bash
# All 5 categories present
gh api repos/esphome-cloud/community/discussions/categories | jq '. | length == 5'
# 4 ISSUE_TEMPLATE files
ls .github/ISSUE_TEMPLATE/*.yml | wc -l   # 4
# README sections present
grep -c '^## ' README.md   # >= 5
```

## G2: China Fallback

- **Owner:** founder
- **Phase:** 2 exit
- **Target close date:** Day 2, end of morning

### Binding criteria

- [ ] All 4 Phase-2 task acceptance checkboxes ticked with linked evidence
- [ ] Gitee mirror current: `gitee.com/esphome-cloud/community` HEAD commit matches GitHub HEAD commit (within 10 min of sync trigger)
- [ ] README mirror callout (CN+EN) deployed and rendered correctly on both GitHub and Gitee
- [ ] Chinese signup guide reachable from Gitee
- [ ] R-03 (Gitee sync drift) status moved to `Mitigating`

### Slip protocol

Slip ≤ 1 day: continue Day 2 afternoon; document slip.
Slip > 1 day: Gitee real-name verification or API issue; consider deferring G2 and proceeding to G3 with an explicit "China fallback in progress" note in the launch announcement. Founder revisits within 1 week.

### Validation

```bash
gh workflow run mirror-to-gitee.yml --repo esphome-cloud/community
sleep 600  # workflow runtime
[ "$(git ls-remote https://github.com/esphome-cloud/community refs/heads/main | cut -f1)" = \
  "$(git ls-remote https://gitee.com/esphome-cloud/community refs/heads/main | cut -f1)" ]
curl -fs https://gitee.com/esphome-cloud/community/raw/main/docs/github-signup-cn.md > /dev/null
```

## G3: BETA Public Launch + Week-1

- **Owner:** founder
- **Phase:** 3 exit
- **Target close date:** Day 9 (Day 2 launch + 7 days)

### Binding criteria

- [ ] All 5 Phase-3 task acceptance checkboxes ticked with linked evidence
- [ ] AI handle-rate ≥ 80% over week 1 (`tests/perf/handle_rate.sh`)
- [ ] Claude API cost ≤ $10 over week 1 (`tests/perf/cost_24h.sh THRESHOLD_USD=10 SINCE=<launch-iso>`)
- [ ] No `[CRITICAL]` pages fired (or 1 fired and resolved within 24h SLA)
- [ ] KNOWN_ISSUES grew by ≥ 3 entries
- [ ] R-01 (mis-class) status moved to `Mitigating`; R-05 (spam burst) status `Mitigating`; R-10 (out-of-scope drift) status `Mitigating`

### G3 metrics row (populated at Day 9)

This table is the canonical record of the 24h + week-1 measurements (Task 3.4
acceptance #3). Populate the **Actual** column at Day 1 (24h check) and
again at Day 9 (week-1 close). Leave the **Day 9** row empty until then.

| Metric | Target | Day 1 (24h) actual | Day 9 (week-1) actual | Source |
|---|---|---|---|---|
| AI handle-rate | ≥80% | _populate Day 1_ | _populate Day 9_ | `bash tests/perf/handle_rate.sh SINCE=<launch-iso>` |
| Claude API cost | ≤$2 / 24h · ≤$10 / week | _$X.XX_ | _$X.XX_ | `bash tests/perf/cost_24h.sh THRESHOLD_USD=2 SINCE=<launch-iso>` (24h) + `THRESHOLD_USD=10` (week-1) |
| Gitee mirror drift | ≤6h+10min (max sample) | _hh:mm_ | _hh:mm_ | `.mirror-drift-state/samples.tsv` max column 4 |
| Spam ratio | ≤5% of total | _N.N%_ | _N.N%_ | `gh issue list --label spam --search 'created:>=<launch>' \| wc -l` ÷ total issues |
| [CRITICAL] pages fired | 0 (or 1 resolved within 24h SLA) | _N_ | _N_ | `gh run list --workflow=ai-triage.yml` log grep for `[pager] SMTP send` |
| KNOWN_ISSUES growth | ≥3 entries | _N_ | _N_ | `bash tests/repo/known_issues_growth.sh` |

If any Day 9 row is below target, follow the Slip protocol below.

### Slip protocol

Slip ≤ 3 days: continue monitoring; document slip in week-1 retro.
Slip > 3 days: review which criterion failed; specific responses:
- Handle-rate <80% → trigger ADR-006 T1 review (KB top-up urgency); KB add ≥ 5 entries before re-test
- Cost >$10 → trigger R-02 mitigation (rate limit; possible Sonnet switch)
- Critical page fired → publish post-mortem to Discussions Announcements within 7 days
- KNOWN_ISSUES growth <3 → review past-week issues for missed categorizations; founder writes ≥3 entries

### Validation

```bash
# Handle-rate
TOTAL=$(gh issue list --repo esphome-cloud/community --state all --search "created:>=2026-05-10 created:<=2026-05-17" --limit 1000 --json number | jq 'length')
RESOLVED=$(gh issue list --repo esphome-cloud/community --state closed --label ai-resolved --search "created:>=2026-05-10 created:<=2026-05-17" --limit 1000 --json number | jq 'length')
NEEDS_HUMAN=$(gh issue list --repo esphome-cloud/community --label needs-human --search "created:>=2026-05-10 created:<=2026-05-17" --limit 1000 --json number | jq 'length')
RATE=$(echo "scale=3; $RESOLVED / ($RESOLVED + $NEEDS_HUMAN)" | bc)
echo "handle_rate=$RATE (target ≥0.80)"

# KNOWN_ISSUES growth
git log --since='1 week ago' -p scripts/triage.py | grep -c '^\+.*ISSUE #'
```

## G4: BETA → GA (deferred)

- **Owner:** founder
- **Target close date:** 8-12 weeks post-G3

This gate is deferred — its specific criteria are written when the founder decides to move from BETA to GA. Tentative criteria:

### Tentative binding criteria (subject to revision before opening)

- [ ] AI handle-rate ≥85% sustained over rolling 30-day window
- [ ] Per-issue cost <$0.05 averaged 30-day window (Sonnet migration deferred until cost trigger)
- [ ] R-01 (mis-class) RETIRED (100 `ai-resolved` reviewed, 0 mis-class)
- [ ] R-02 (cost) RETIRED (90 days quota-stable)
- [ ] R-03 (mirror) RETIRED (60 days drift-free)
- [ ] R-05 (spam) RETIRED (100 spam at <$5)
- [ ] R-07 (footer) RETIRED (50 AI responses footer-verified)
- [ ] R-10 (mission drift) RETIRED (50 `out_of_scope` rejections without override)
- [ ] At least 1 paid Self-hosted contract has been onboarded (validates the SLA matrix)
- [ ] At least 1 cycle of action-pinning to commit SHA (TC-2 supply-chain mitigation)

### Slip protocol

Not applicable yet — gate is deferred. Founder reopens this section with a target close date when 4 of the BETA RETIRED criteria are satisfied.

## Cross-cutting gate rules

1. **No skipping.** Each gate must close before the next phase starts.
2. **Evidence linked.** Each binding criterion has a linked test name, log query, or artifact path. "I'm sure it's fine" doesn't close a gate.
3. **Risk status updates.** Risks listed under each gate must show the expected status transition; otherwise the gate is open.
4. **Slip is logged.** Every slip is documented in the monthly review with cause + mitigation, even if minor.

## References

- All 4 phases (`phase-0`..`phase-3`)
- All 10 risks (`risk-register.md`)
- ADR-001..ADR-007 (collectively the architectural commitments these gates protect)
- `governance/performance-engineering.md` (SLO definitions consumed by G3)
- `governance/budget.md` (cost ceilings consumed by G3 + G4)
