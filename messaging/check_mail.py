#!/usr/bin/env python3
"""
Check for new emails via IMAP. Read-only (BODY.PEEK), never marks as read.

Usage:
    python3 check_mail.py            # New mail since last check
    python3 check_mail.py --body     # Include body text (first 1500 chars)
    python3 check_mail.py --all N    # Show last N messages regardless

Exit codes: 0 = new mail found, 1 = no new mail, 2 = error
(Useful for scheduled tasks that decide whether to wake the AI.)

State file tracks the last-seen UID to avoid re-reporting.
"""
import sys, os, imaplib, subprocess, email
from email.header import decode_header, make_header

IMAP_SERVER = "imap.example.com"
ACCOUNT = "your-email@example.com"
KEYCHAIN_SERVICE = "your-app/smtp"
STATE = os.path.expanduser("~/wake/.check-mail-last-uid")

# Noise filter: skip automated/system mail
NOISE = ("apple", "noreply", "no-reply", "newsletter", "service@")


def password():
    r = subprocess.run(
        ["security", "find-generic-password",
         "-s", KEYCHAIN_SERVICE, "-a", ACCOUNT, "-w"],
        capture_output=True, text=True
    )
    if r.returncode != 0:
        raise RuntimeError("Failed to read password from Keychain")
    return r.stdout.strip()


def dec(s):
    try:
        return str(make_header(decode_header(s or "")))
    except Exception:
        return s or ""


def body_of(msg, limit=1500):
    for part in msg.walk():
        if part.get_content_type() == "text/plain" and not part.get_filename():
            raw = part.get_payload(decode=True) or b""
            cs = part.get_content_charset() or "utf-8"
            return raw.decode(cs, errors="replace").strip()[:limit]
    return "(no plaintext body)"


def main():
    show_body = "--body" in sys.argv
    last = 0
    if "--all" in sys.argv:
        n = int(sys.argv[sys.argv.index("--all") + 1])
    else:
        n = None
        if os.path.exists(STATE):
            last = int(open(STATE).read().strip() or 0)

    m = imaplib.IMAP4_SSL(IMAP_SERVER, 993)
    m.login(ACCOUNT, password())
    m.select("INBOX", readonly=True)
    typ, data = m.uid("search", None, "ALL")
    uids = [int(u) for u in data[0].split()]
    picked = uids[-n:] if n else [u for u in uids if u > last]

    found = 0
    for uid in picked:
        part = "(BODY.PEEK[])" if show_body else \
               "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])"
        typ, d = m.uid("fetch", str(uid), part)
        msg = email.message_from_bytes(d[0][1])
        frm = dec(msg.get("From"))
        if n is None and any(k in frm.lower() for k in NOISE):
            continue
        found += 1
        print(f"[{uid}] {dec(msg.get('Date'))}")
        print(f"  From: {frm}")
        print(f"  Subject: {dec(msg.get('Subject'))}")
        if show_body:
            print("  ----")
            print("  " + body_of(msg).replace("\n", "\n  ") + "\n")

    if uids and n is None:
        with open(STATE, "w") as f:
            f.write(str(max(uids)))
    m.logout()

    if found == 0:
        print("No new mail.")
    return 0 if found else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(2)
