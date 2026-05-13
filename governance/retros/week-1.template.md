# Week-1 retrospective (template)

> Copy this template to `governance/retros/week-1.md` on Day 9 (Phase 3 Task
> 3.5). The 4 H2 anchors below are required and enforced by
> `tests/repo/retro_sections.sh`. The KNOWN_ISSUES growth count is enforced
> separately by `tests/repo/known_issues_growth.sh`.
>
> Posted as the "Week 1 in numbers" announcement in Discussions/Announcements
> with the same metrics block.

## Metadata

| Field | Value |
|---|---|
| Launch date | _YYYY-MM-DD_ |
| Retro date  | _YYYY-MM-DD (Day 9)_ |
| Author      | founder |
| BETA invitees sent | _N_ |
| Invitees who filed ≥1 issue | _N_ |
| BETA→GA decision (still in Phase 3 → wait, or move to G4 prep?) | _Wait / G4 prep_ |

## G3 metrics snapshot

See `governance/release-gate.md` § G3 metrics row for the canonical table.
Copy the Day-9 column here for permanence:

| Metric | Target | Actual |
|---|---|---|
| AI handle-rate | ≥80% | _N.N%_ |
| Claude API cost (week-1) | ≤$10 | _$X.XX_ |
| Gitee mirror drift (max sample) | ≤6h+10min | _hh:mm_ |
| Spam ratio | ≤5% | _N.N%_ |
| [CRITICAL] pages fired | 0 | _N_ |
| KNOWN_ISSUES grew by | ≥3 | _N_ |

## What worked

(1-3 short paragraphs — what the design got right.)

- _Bullet point 1 — concrete observation, not a vague satisfaction note._
- _Bullet point 2 — ideally a metric or a specific user-quote backing it up._
- _Bullet point 3 — what to keep doing on autopilot._

## What surprised

(1-3 short paragraphs — what happened that wasn't anticipated, both good
and bad.)

- _Positive surprise — capability you didn't realize was load-bearing._
- _Negative surprise — what bit you that you should have predicted._
- _Calibration surprise — where the design's mental model was off._

## AI mis-handles

(Concrete cases where the AI triage got it wrong. 5-10 cases is normal.
This section feeds directly into the KNOWN_ISSUES additions below.)

For each: link to the issue, the AI's classification, what was correct,
root cause (KB miss / prompt ambiguity / category overlap), fix applied.

| Issue # | AI category | Correct category | Root cause | Fix |
|---|---|---|---|---|
| #_NN_ | _e.g. known_issue_ | _e.g. real_bug_ | _e.g. KB entry too broad_ | _e.g. narrowed KB entry_ |
| #_NN_ | ... | ... | ... | ... |

## KNOWN_ISSUES additions

(≥3 new entries this week, per Task 3.5 acceptance + G3 exit criterion.
Each entry must follow the ISSUE #N format in `scripts/triage.py`.)

### ISSUE #5 — _title_

- **Symptom:** _user-side description; matches words a confused user would write_
- **Fix:** _the canned reply the AI will give when this matches_

### ISSUE #6 — _title_

- **Symptom:** _..._
- **Fix:** _..._

### ISSUE #7 — _title_

- **Symptom:** _..._
- **Fix:** _..._

_(Add more as needed. The growth count test asserts ≥3 net-new ISSUE # markers
in scripts/triage.py since the phase-3 start tag.)_

## Decisions made this week

(ADR-worthy changes that came out of the week-1 data. If any, they live as
their own files under `governance/adr-NNN-*.md`, not embedded here.)

- _None_ / _ADR-008: ..._

## Action items for week 2

- [ ] _Action 1 — owner, deadline_
- [ ] _Action 2 — owner, deadline_

---

_Filed by founder. Phase 3 Task 3.5._
