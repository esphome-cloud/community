#!/usr/bin/env python3
"""Phase 0 Task 0.4 acceptance #5 (Performance):
   triage round-trip (issue.opened -> comment posted) p95 < 90s on
   `ubuntu-latest` runners across 30 dummy issues.

This script files N dummy issues against the live repo, polls each issue
for the first AI-authored comment (the disclosure-footer-bearing reply
from triage.py), and records the time delta between issue creation and
comment posting. After all trials, computes p50/p95/max and asserts that
p95 is below the threshold.

Usage:
  ./tests/perf/triage_latency.py
  REPO=my-org/my-repo TRIALS=10 ./tests/perf/triage_latency.py
  ./tests/perf/triage_latency.py --keep          # leave dummies open

Exit: 0 = p95 below threshold; 1 = exceeded; 2 = setup error.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone

REPO            = os.environ.get("REPO", "esphome-cloud/community")
TRIALS          = int(os.environ.get("TRIALS", "30"))
TIMEOUT_S       = 240
POLL_S          = 5
P95_THRESHOLD_S = 90.0

# The disclosure footer is the unambiguous fingerprint of an AI-authored
# comment. It's appended by scripts/triage.py to every response_to_user.
AI_FOOTER = "— Triaged by AI; reply to reopen for human review"


def gh(*args: str, json_out: bool = True) -> object:
    """Run `gh` and return parsed JSON or raw stdout."""
    proc = subprocess.run(["gh", *args], capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} -> {proc.returncode}: {proc.stderr.strip()[-200:]}")
    return json.loads(proc.stdout) if json_out else proc.stdout


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(ts: str) -> datetime:
    # gh returns ...Z suffix; replace with +00:00 for fromisoformat.
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


def open_dummy(nonce: str, trial: int) -> tuple[int, datetime]:
    title = f"[Bug]: triage_latency smoke {nonce} trial-{trial}"
    body  = f"Latency smoke for Task 0.4 acceptance #5.\n\nnonce={nonce}\ntrial={trial}/{TRIALS}\n"
    url_str = subprocess.run(
        ["gh", "issue", "create", "--repo", REPO,
         "--title", title, "--body", body, "--label", "needs-triage"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    issue_n = int(url_str.rsplit("/", 1)[-1])
    # The issue's `created_at` is authoritative; fetch it back.
    issue = gh("issue", "view", str(issue_n), "--repo", REPO, "--json", "createdAt", json_out=True)
    return issue_n, parse_iso(issue["createdAt"])


def wait_for_ai_comment(issue_n: int) -> datetime | None:
    deadline = time.monotonic() + TIMEOUT_S
    while time.monotonic() < deadline:
        time.sleep(POLL_S)
        try:
            data = gh("issue", "view", str(issue_n), "--repo", REPO,
                      "--json", "comments", json_out=True)
        except RuntimeError:
            continue
        for c in data.get("comments", []):
            if AI_FOOTER in (c.get("body") or ""):
                return parse_iso(c["createdAt"])
    return None


def cleanup(issue_ns: list[int], nonce: str) -> None:
    for n in issue_ns:
        subprocess.run(
            ["gh", "issue", "close", str(n), "--repo", REPO, "--reason", "not planned",
             "--comment", f"Auto-close: Task 0.4 triage_latency dummy (nonce={nonce})."],
            check=False, capture_output=True, text=True,
        )


def p95(samples: list[float]) -> float:
    if not samples:
        return float("nan")
    # Linear interpolation on the sorted array.
    s = sorted(samples)
    if len(s) == 1:
        return s[0]
    idx = 0.95 * (len(s) - 1)
    lo = math.floor(idx)
    hi = math.ceil(idx)
    if lo == hi:
        return s[lo]
    return s[lo] + (s[hi] - s[lo]) * (idx - lo)


def main() -> int:
    parser = argparse.ArgumentParser(description="Task 0.4 triage latency smoke")
    parser.add_argument("--keep", action="store_true",
                        help="Leave dummy issues open after the run.")
    args = parser.parse_args()

    if subprocess.run(["gh", "auth", "status"], capture_output=True).returncode != 0:
        print("FAIL: `gh auth status` reports unauthenticated", file=sys.stderr)
        return 2

    nonce = f"{int(time.time())}-{random.randint(1000, 9999)}"
    print(f"repo={REPO} trials={TRIALS} nonce={nonce}")
    print()

    latencies_s: list[float] = []
    issue_ns:    list[int]   = []
    missed:      list[int]   = []

    for i in range(1, TRIALS + 1):
        try:
            issue_n, created_at = open_dummy(nonce, i)
        except Exception as exc:
            print(f"  trial {i}: FAIL — could not open issue: {exc}")
            continue
        issue_ns.append(issue_n)

        comment_at = wait_for_ai_comment(issue_n)
        if comment_at is None:
            print(f"  trial {i}: FAIL — no AI comment on #{issue_n} within {TIMEOUT_S}s")
            missed.append(issue_n)
            continue

        latency = (comment_at - created_at).total_seconds()
        latencies_s.append(latency)
        print(f"  trial {i}: #{issue_n} round-trip {latency:.1f}s")

    if not args.keep:
        cleanup(issue_ns, nonce)

    print()
    if not latencies_s:
        print("FAIL: 0 trials produced a latency sample")
        return 1

    p50 = statistics.median(latencies_s)
    p95v = p95(latencies_s)
    mx = max(latencies_s)

    print(f"trials with sample: {len(latencies_s)}/{TRIALS}")
    print(f"  p50:  {p50:.1f}s")
    print(f"  p95:  {p95v:.1f}s")
    print(f"  max:  {mx:.1f}s")
    if missed:
        print(f"  missed: {len(missed)} ({missed})")

    if p95v > P95_THRESHOLD_S or missed:
        print()
        print(f"FAIL: Task 0.4 acceptance #5 requires p95 < {P95_THRESHOLD_S}s "
              f"AND every trial to produce a sample.")
        return 1

    print()
    print(f"PASS: p95 {p95v:.1f}s < {P95_THRESHOLD_S}s and {len(latencies_s)}/{TRIALS} trials yielded a comment.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
