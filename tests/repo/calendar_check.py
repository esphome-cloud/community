#!/usr/bin/env python3
"""Phase 3 Task 3.2 acceptance #1 (Function):
   3 calendar entries with correct cadence (Tuesday weekly /
   month-end monthly / Jan 1 yearly).

Parses the .ics file at tests/fixtures/calendar_rituals.ics (or
$CALENDAR_FILE) and asserts:
  - exactly 3 VEVENT blocks
  - each has an RRULE with the expected frequency/byday/bymonth fields
  - SUMMARY contains the expected anchor strings

Per Task 3.2 entry criterion (G1 exit #4), the founder's own calendar
export should be diffable against this fixture for the same 3 events.

Exit: 0 = 3/3 events match; 1 = drift; 2 = setup.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ICS = Path(os.environ.get("CALENDAR_FILE", "tests/fixtures/calendar_rituals.ics"))

EXPECTED = [
    {
        "uid_keyword": "tuesday-office-hours",
        "rrule_must_contain": ["FREQ=WEEKLY", "BYDAY=TU"],
        "summary_anchor": "office hours",
        "description": "weekly Tuesday office hours",
    },
    {
        "uid_keyword": "monthly-review",
        "rrule_must_contain": ["FREQ=MONTHLY", "BYMONTHDAY=-1"],
        "summary_anchor": "monthly review",
        "description": "last day of month monthly review",
    },
    {
        "uid_keyword": "yearly-mission-reread",
        "rrule_must_contain": ["FREQ=YEARLY", "BYMONTH=1", "BYMONTHDAY=1"],
        "summary_anchor": "mission re-read",
        "description": "Jan 1 yearly mission re-read",
    },
]


def parse_vevents(text: str) -> list[dict[str, str]]:
    """Split into VEVENT blocks and parse each as a dict of property-name → first-value."""
    blocks: list[dict[str, str]] = []
    cur: dict[str, str] | None = None
    for raw in text.splitlines():
        ln = raw.rstrip()
        if ln == "BEGIN:VEVENT":
            cur = {}
        elif ln == "END:VEVENT" and cur is not None:
            blocks.append(cur)
            cur = None
        elif cur is not None and ":" in ln:
            # Strip iCalendar property params (e.g. DTSTART;TZID=...:VALUE).
            name_part, _, value = ln.partition(":")
            name = name_part.split(";", 1)[0]
            if name and name not in cur:  # keep first occurrence
                cur[name] = value
    return blocks


def main() -> int:
    if not ICS.exists():
        print(f"FAIL: calendar file not found: {ICS}")
        return 2

    text = ICS.read_text()
    events = parse_vevents(text)
    print(f"VEVENT blocks: {len(events)} (expected 3)")
    if len(events) != 3:
        print(f"FAIL: expected exactly 3 VEVENTs, got {len(events)}")
        return 1

    fails = 0
    matched_idx: set[int] = set()
    for expected in EXPECTED:
        match = None
        for i, ev in enumerate(events):
            if i in matched_idx:
                continue
            uid = ev.get("UID", "")
            if expected["uid_keyword"] in uid:
                match = (i, ev)
                break
        if match is None:
            print(f"  [MISSING] {expected['description']} — no VEVENT with UID containing '{expected['uid_keyword']}'")
            fails += 1
            continue
        idx, ev = match
        matched_idx.add(idx)

        rrule = ev.get("RRULE", "")
        rrule_ok = all(part in rrule for part in expected["rrule_must_contain"])
        summary = ev.get("SUMMARY", "")
        summary_ok = expected["summary_anchor"].lower() in summary.lower()

        if rrule_ok and summary_ok:
            print(f"  [ok] {expected['description']}: RRULE={rrule!r} SUMMARY={summary!r}")
        else:
            if not rrule_ok:
                print(f"  [FAIL] {expected['description']}: RRULE {rrule!r} missing one of {expected['rrule_must_contain']}")
            if not summary_ok:
                print(f"  [FAIL] {expected['description']}: SUMMARY {summary!r} missing anchor '{expected['summary_anchor']}'")
            fails += 1

    print()
    if fails > 0:
        print(f"FAIL: {fails} / 3 calendar entries failed.")
        return 1
    print("PASS: all 3 calendar rituals present with correct RRULE + SUMMARY.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
