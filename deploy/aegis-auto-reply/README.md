# aegis-auto-reply systemd unit

Phase 1 Task 1.3 implementation per ADR-009 Path A2 sub-option (a). The
script polls the founder's primary inbox (163.com) via IMAP for mail
forwarded by ImprovMX to esphome.cloud aliases, then fires byte-equal
auto-replies via Resend SMTP. Runs every 5 minutes on a CN-region host
(163 geo-blocks third-party-client login from outside China).

## Why this lives here, not in `.github/workflows/`

GitHub Actions runners are in non-CN regions (Azure WestCentralUS etc.).
163.com refuses IMAP login from those IPs with a misleading "LOGIN error
or password error" message even with a valid client authorization code.
The auto-reply trigger must run from a CN-region host. 3qMq
(`43.142.121.30`, Tencent Cloud) is the project's existing in-CN host
and runs aegis-control + Caddy + dep-downloader, so adding a small
systemd timer is the lowest-friction placement.

## Install (manual, ~5 min)

Prerequisites:
- 3qMq (or equivalent CN-region Debian/Ubuntu host) with SSH access
- Python 3.11+ (`python3 --version`)
- ImprovMX inbound forwarding configured per ADR-009 Path A2
- Resend SMTP credentials configured per ADR-009 Path A2

```bash
# 1. Stage the script + fixtures on the target host
sudo mkdir -p /opt/aegis-auto-reply/scripts /opt/aegis-auto-reply/tests/fixtures/email_autoreplies
sudo chown -R root:root /opt/aegis-auto-reply

# (from your laptop:)
scp scripts/auto_reply_poll.py <target>:/tmp/
scp tests/fixtures/email_autoreplies/{feedback,security,hello,support}.txt <target>:/tmp/

# (on target:)
sudo install -o root -g root -m 644 /tmp/auto_reply_poll.py /opt/aegis-auto-reply/scripts/
for f in feedback security hello support; do
  sudo install -o root -g root -m 644 /tmp/$f.txt \
    /opt/aegis-auto-reply/tests/fixtures/email_autoreplies/$f.txt
done

# 2. Write the env file (mode 600, root:root)
sudo tee /opt/aegis-auto-reply/auto_reply.env > /dev/null <<'ENV_EOF'
# (copy from auto_reply.env.example in this dir + fill in real values)
ENV_EOF
sudo chmod 600 /opt/aegis-auto-reply/auto_reply.env

# 3. Install systemd unit files
sudo cp deploy/aegis-auto-reply/aegis-auto-reply.service /etc/systemd/system/
sudo cp deploy/aegis-auto-reply/aegis-auto-reply.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now aegis-auto-reply.timer

# 4. First run is a bootstrap (pins last_uid watermark to current INBOX max UID)
sudo systemctl start aegis-auto-reply.service
sudo journalctl -u aegis-auto-reply.service -n 10 --no-pager
```

Expected first-run output: `bootstrap: pinned last_uid to N; processed 0 messages this tick`.

## Verify

```bash
# Timer schedule
sudo systemctl list-timers aegis-auto-reply.timer

# State file
sudo cat /opt/aegis-auto-reply/last_uid.txt    # monotonically-increasing UID

# Latest run
sudo journalctl -u aegis-auto-reply.service -n 20 --no-pager
```

End-to-end smoke: send mail from any non-`@163.com` external mailbox to
`feedback@esphome.cloud`. Within ~5 min (cron lag), the original sender
should receive a byte-equal `tests/fixtures/email_autoreplies/feedback.txt`
auto-reply from `ai-triage@esphome.cloud`.

## Rotation

Quarterly per CLAUDE.md. When `IMAP_PASSWORD` (163 客户端授权码) or
`SMTP_PASSWORD` (Resend API key) rotates: edit
`/opt/aegis-auto-reply/auto_reply.env` and restart the timer:

```bash
sudo systemctl restart aegis-auto-reply.timer
```

(Note: env file is read on each `aegis-auto-reply.service` execution
via `EnvironmentFile=`; no daemon-reload needed for env-only changes.)
