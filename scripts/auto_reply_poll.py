#!/usr/bin/env python3
"""Phase 1 Task 1.3 (ADR-009 Path A2 sub-option a): IMAP-poll-then-reply.

Polls the founder's primary inbox (default: ff4415@163.com on imap.163.com)
via IMAP for new mail forwarded by ImprovMX to one of the 5 esphome.cloud
aliases (feedback/security/hello/support/ai-triage). For each match, sends
the byte-equal auto-reply from tests/fixtures/email_autoreplies/<alias>.txt
via Resend SMTP, then moves the original to INBOX/AutoReplied/ to prevent
double-replies on the next cron tick.

Designed to run as a GH Actions cron job every 5 minutes.

Loop avoidance:
- Skip if sender is in our own @esphome.cloud domain (our outbound).
- Skip if Auto-Submitted header is non-empty / non-"no" (RFC 3834).
- Skip if Precedence is list / junk / bulk / auto_reply.
- Skip if sender local-part looks like a no-reply address.

Required env:
  IMAP_HOST       e.g. imap.163.com
  IMAP_USER       e.g. ff4415@163.com
  IMAP_PASSWORD   163 client authorization code (app-password)
  SMTP_HOST       smtp.resend.com
  SMTP_USER       resend
  SMTP_PASSWORD   Resend API key (re_...)

Exit: 0 = polled OK (any number of replies sent); 2 = setup error;
      1 = IMAP/SMTP partial failure (some messages skipped).
"""

from __future__ import annotations

import email
import email.message
import imaplib
import os
import smtplib
import ssl
import sys
from email.policy import default
from email.utils import parseaddr
from pathlib import Path

ALIASES = ("feedback", "security", "hello", "support", "ai-triage")
DOMAIN = "esphome.cloud"
SMTP_FROM = "ai-triage@esphome.cloud"
PROCESSED_FOLDER = "AutoReplied"  # top-level — 163.com forbids subfolders under INBOX
FIXTURES_DIR = Path(__file__).resolve().parent.parent / "tests" / "fixtures" / "email_autoreplies"


def parse_fixture(path: Path) -> tuple[str, str]:
    """Returns (subject, body) from a 'Subject: X\\n\\n<body>' fixture."""
    lines = path.read_text().splitlines()
    if not lines or not lines[0].startswith("Subject: "):
        raise ValueError(f"{path}: first line must start with 'Subject: '")
    subject = lines[0][len("Subject: "):]
    if len(lines) < 2 or lines[1] != "":
        raise ValueError(f"{path}: second line must be blank")
    body = "\n".join(lines[2:])
    return subject, body


def detect_alias(msg: email.message.Message) -> str | None:
    """Return the matched alias (feedback/security/hello/support) or None.

    Forwarders put the original recipient in different headers (Delivered-To,
    X-Forwarded-To, X-Original-To, X-ImprovMX-Email, Envelope-To, ...). Rather
    than enumerate every variant, we substring-scan ALL recipient-shaped
    headers — explicit `To`/`Cc`/`Delivered-To`/`Envelope-To` plus the broad
    `X-*` namespace (excluding known X-noise headers like X-Mailer/X-Spam).
    ai-triage is intentionally NOT in the PUBLIC set (it's our outbound
    sender), so we don't auto-reply to it.
    """
    PUBLIC = ("feedback", "security", "hello", "support")
    EXACT_RECIPIENT_HEADERS = {"to", "cc", "delivered-to", "envelope-to"}
    X_NOISE_PREFIXES = (
        "x-mailer", "x-priority", "x-spam", "x-msmail", "x-mimeole",
        "x-virus", "x-antiabuse", "x-dcc", "x-uidl", "x-mta",
    )
    for h_name, h_val in msg.items():
        lower_name = h_name.lower()
        is_recipient_header = (
            lower_name in EXACT_RECIPIENT_HEADERS
            or (lower_name.startswith("x-") and not any(lower_name.startswith(p) for p in X_NOISE_PREFIXES))
        )
        if not is_recipient_header:
            continue
        v_lower = h_val.lower()
        for alias in PUBLIC:
            if f"{alias}@{DOMAIN}" in v_lower:
                return alias
    return None


def should_skip(msg: email.message.Message) -> tuple[bool, str]:
    """Loop-avoidance + edge-case checks."""
    sender = parseaddr(msg.get("From", ""))[1].lower()

    if sender.endswith("@" + DOMAIN):
        return True, f"sender in our own domain ({sender})"

    auto_submitted = msg.get("Auto-Submitted", "").strip().lower()
    if auto_submitted and auto_submitted != "no":
        return True, f"Auto-Submitted={auto_submitted}"

    prec = msg.get("Precedence", "").strip().lower()
    if prec in ("list", "junk", "bulk", "auto_reply"):
        return True, f"Precedence={prec}"

    local = sender.split("@", 1)[0] if "@" in sender else sender
    if any(token in local for token in ("noreply", "no-reply", "donotreply", "do-not-reply")):
        return True, f"no-reply sender ({sender})"

    return False, ""


def send_reply(original: email.message.Message, subject: str, body: str,
               smtp_host: str, smtp_user: str, smtp_password: str) -> None:
    """Send the byte-equal auto-reply via Resend SMTP."""
    to_addr = parseaddr(original.get("From", ""))[1]
    if not to_addr or "@" not in to_addr:
        raise ValueError(f"no parseable From: address in {original.get('From')!r}")

    in_reply_to = original.get("Message-ID", "")

    msg = email.message.EmailMessage()
    msg["From"] = SMTP_FROM
    msg["To"] = to_addr
    msg["Subject"] = subject  # byte-equal to fixture; NOT "Re: <original>"
    msg["Auto-Submitted"] = "auto-replied"  # RFC 3834 — recipients can de-loop us
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
        msg["References"] = in_reply_to
    msg.set_content(body)

    ctx = ssl.create_default_context()
    with smtplib.SMTP_SSL(smtp_host, 465, context=ctx, timeout=30) as smtp:
        smtp.login(smtp_user, smtp_password)
        smtp.send_message(msg)


def main() -> int:
    try:
        imap_host = os.environ["IMAP_HOST"]
        imap_user = os.environ["IMAP_USER"]
        imap_pass = os.environ["IMAP_PASSWORD"]
        smtp_host = os.environ["SMTP_HOST"]
        smtp_user = os.environ["SMTP_USER"]
        smtp_pass = os.environ["SMTP_PASSWORD"]
    except KeyError as exc:
        print(f"FAIL: missing env {exc!r}", file=sys.stderr)
        return 2

    fixtures: dict[str, tuple[str, str]] = {}
    for alias in ("feedback", "security", "hello", "support"):
        path = FIXTURES_DIR / f"{alias}.txt"
        if not path.exists():
            print(f"FAIL: missing fixture {path}", file=sys.stderr)
            return 2
        fixtures[alias] = parse_fixture(path)

    try:
        m = imaplib.IMAP4_SSL(imap_host, 993, timeout=30)
        m.login(imap_user, imap_pass)
    except Exception as exc:
        print(f"FAIL: IMAP login failed: {exc}", file=sys.stderr)
        return 2

    # 163.com / NetEase requires the RFC 2971 ID extension before SELECT,
    # else the server returns NO with the misleading message
    # "SELECT Unsafe Login. Please contact kefu@188.com for help".
    # imaplib doesn't ship ID in its Commands table; register it once.
    if "ID" not in imaplib.Commands:
        imaplib.Commands["ID"] = ("AUTH", "NONAUTH", "SELECTED", "LOGOUT")
    try:
        m._simple_command(
            "ID",
            '("name" "esphome-cloud-auto-reply" '
            '"version" "1.0" '
            '"vendor" "esphome-cloud/community" '
            '"contact" "ai-triage@esphome.cloud")',
        )
    except Exception as exc:
        print(f"[warn] IMAP ID extension failed (non-fatal): {exc}", file=sys.stderr)

    partial_failures = 0
    try:
        # Ensure processed folder exists (idempotent).
        try:
            m.create(PROCESSED_FOLDER)
        except Exception:
            pass  # already exists

        typ, _ = m.select("INBOX")
        if typ != "OK":
            print("FAIL: cannot SELECT INBOX", file=sys.stderr)
            return 2

        typ, data = m.search(None, "(UNSEEN)")
        if typ != "OK":
            print(f"FAIL: IMAP search returned {typ}", file=sys.stderr)
            return 2

        ids = data[0].split()
        print(f"polled INBOX: {len(ids)} UNSEEN message(s)")

        replies_sent = 0
        for msg_id in ids:
            mid = msg_id.decode()
            try:
                # BODY.PEEK[] = read without setting \\Seen. Plain RFC822 fetch
                # auto-marks SEEN, which would silently consume non-matching
                # messages and prevent re-processing if detect_alias() ever
                # changes.
                typ, msg_data = m.fetch(msg_id, "(BODY.PEEK[])")
            except Exception as exc:
                print(f"  msg {mid}: fetch failed: {exc}", file=sys.stderr)
                partial_failures += 1
                continue
            if typ != "OK" or not msg_data or not msg_data[0]:
                print(f"  msg {mid}: fetch returned {typ}", file=sys.stderr)
                partial_failures += 1
                continue

            raw = msg_data[0][1]
            msg = email.message_from_bytes(raw, policy=default)

            alias = detect_alias(msg)
            if not alias:
                print(f"  msg {mid}: skip (no esphome.cloud alias in headers)")
                continue

            skip, why = should_skip(msg)
            if skip:
                print(f"  msg {mid} ({alias}@): skip — {why}")
                continue

            subject, body = fixtures[alias]
            sender = parseaddr(msg.get("From", ""))[1] or "<unknown>"
            try:
                send_reply(msg, subject, body, smtp_host, smtp_user, smtp_pass)
                replies_sent += 1
                print(f"  msg {mid} ({alias}@): REPLIED → {sender}")
            except Exception as exc:
                print(f"  msg {mid} ({alias}@): SMTP failed: {exc}", file=sys.stderr)
                partial_failures += 1
                continue  # leave UNSEEN; next cron tick retries

            # Move to processed folder (idempotency belt+suspenders).
            try:
                m.copy(msg_id, PROCESSED_FOLDER)
                m.store(msg_id, "+FLAGS", "\\Deleted")
            except Exception as exc:
                print(f"  msg {mid}: move failed: {exc}; marking SEEN as fallback",
                      file=sys.stderr)
                m.store(msg_id, "+FLAGS", "\\Seen")
                partial_failures += 1

        try:
            m.expunge()
        except Exception:
            pass

        total = len(ids)
        print(f"\nsummary: {replies_sent}/{total} replied, {partial_failures} partial failure(s)")
        return 1 if partial_failures else 0
    finally:
        try:
            m.logout()
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
