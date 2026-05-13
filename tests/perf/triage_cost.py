#!/usr/bin/env python3
"""Phase 0 Task 0.6 acceptance #3 (Observability):
   cost per smoke issue logged via `triage.classified{cost_usd:...}`;
   sum across 5 < $0.30.

Two modes:

  --from-state <path>:
    Read the state file written by tests/e2e/phase0_smoke.sh
    (.smoke-state/phase0-<nonce>.json). Sum cost_usd directly without
    re-querying GitHub. The fast path immediately after a smoke run.

  --from-runs N (default 5):
    Scan the last N completed ai-triage.yml runs on the repo, parse cost_usd
    from each run's log, sum, assert. Useful for ongoing monthly cost review
    beyond the Task 0.6 acceptance window.

Either mode reports:
  - per-trial table of (issue_n, category, cost_usd)
  - sum, mean, min, max
  - PASS / FAIL against the threshold (default $0.30; configurable)

Usage:
  python3 tests/perf/triage_cost.py --from-state .smoke-state/phase0-<nonce>.json
  python3 tests/perf/triage_cost.py --from-runs 5
  THRESHOLD=0.50 python3 tests/perf/triage_cost.py --from-runs 30  # monthly review

Exit: 0 = sum below threshold; 1 = exceeded; 2 = setup.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import statistics
import subprocess
import sys
from pathlib import Path

THRESHOLD_USD = float(os.environ.get("THRESHOLD", "0.30"))
REPO          = os.environ.get("REPO", "esphome-cloud/community")
WORKFLOW      = "ai-triage.yml"

# Matches the log line scripts/triage.py emits on every triage call:
#   triage.classified{issue:<N>, category:<C>, cost_usd:<X>}
MARKER_RE = re.compile(
    r"triage\.classified\{issue:(?P<issue>\d+),\s*category:(?P<category>[a-z_]+),\s*cost_usd:(?P<cost_usd>[0-9.]+)\}"
)


def gh_json(*args: str) -> object:
    proc = subprocess.run(["gh", *args], capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} -> {proc.returncode}: {proc.stderr[-150:]}")
    return json.loads(proc.stdout)


def gh_log(run_id: int) -> str:
    proc = subprocess.run(
        ["gh", "run", "view", str(run_id), "--repo", REPO, "--log"],
        capture_output=True, text=True, check=False,
    )
    return proc.stdout if proc.returncode == 0 else ""


def load_from_state(state_path: Path) -> list[dict[str, object]]:
    state = json.loads(state_path.read_text())
    trials: list[dict[str, object]] = []
    for t in state["trials"]:
        if t.get("cost_usd") is None:
            continue  # skipped (workflow run never found)
        trials.append({
            "issue_n":  t["issue_n"],
            "category": t["category"],
            "cost_usd": float(t["cost_usd"]),
        })
    return trials


def load_from_runs(n: int) -> list[dict[str, object]]:
    runs = gh_json("run", "list", "--repo", REPO, "--workflow", WORKFLOW,
                   "--status", "completed", "--limit", str(n),
                   "--json", "databaseId,displayTitle,createdAt")
    if not isinstance(runs, list):
        raise RuntimeError(f"unexpected gh run list payload: {runs!r}")

    trials: list[dict[str, object]] = []
    for run in runs:
        log = gh_log(run["databaseId"])
        m = MARKER_RE.search(log)
        if not m:
            print(f"  WARN: run {run['databaseId']} has no triage.classified marker; skipping")
            continue
        trials.append({
            "issue_n":  int(m.group("issue")),
            "category": m.group("category"),
            "cost_usd": float(m.group("cost_usd")),
            "run_id":   run["databaseId"],
        })
    return trials


def report(trials: list[dict[str, object]]) -> int:
    if not trials:
        print("FAIL: no trials with cost_usd to evaluate.")
        return 2

    costs = [t["cost_usd"] for t in trials]
    total = sum(costs)
    mean = statistics.mean(costs)
    mn = min(costs)
    mx = max(costs)

    print()
    print(f"{'issue':>8}  {'category':<18}  {'cost_usd':>10}")
    print("-" * 42)
    for t in trials:
        print(f"  #{t['issue_n']:<6}  {t['category']:<18}  ${t['cost_usd']:>8.4f}")
    print("-" * 42)
    print(f"  {'TOTAL':<8}  {'':<18}  ${total:>8.4f}")
    print()
    print(f"trials: {len(trials)}")
    print(f"  total:  ${total:.4f}")
    print(f"  mean:   ${mean:.4f}")
    print(f"  min:    ${mn:.4f}")
    print(f"  max:    ${mx:.4f}")
    print(f"  threshold (sum): ${THRESHOLD_USD:.2f}")
    print()

    if total >= THRESHOLD_USD:
        print(f"FAIL: total ${total:.4f} >= threshold ${THRESHOLD_USD:.2f}.")
        return 1
    print(f"PASS: total ${total:.4f} < ${THRESHOLD_USD:.2f}  ({100 * total / THRESHOLD_USD:.0f}% of budget).")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Task 0.6 cost smoke: sum cost_usd < $0.30.")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--from-state", metavar="PATH",
                   help="State JSON written by tests/e2e/phase0_smoke.sh.")
    g.add_argument("--from-runs", type=int, metavar="N", default=None,
                   help="Scan the last N completed ai-triage.yml runs (default 5 when flag given).")
    args = p.parse_args()

    if args.from_state:
        state_path = Path(args.from_state)
        if not state_path.exists():
            print(f"FAIL: state file not found: {state_path}")
            return 2
        trials = load_from_state(state_path)
    else:
        n = args.from_runs if args.from_runs is not None else 5
        if subprocess.run(["gh", "auth", "status"], capture_output=True).returncode != 0:
            print("FAIL: `gh auth status` reports unauthenticated")
            return 2
        trials = load_from_runs(n)

    return report(trials)


if __name__ == "__main__":
    sys.exit(main())
