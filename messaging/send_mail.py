#!/usr/bin/env python3
"""
Send email via SMTP. Works independently of Mail.app — runs even when
the Mac is headless or the GUI mail client isn't configured.

Usage:
    python3 send_mail.py <recipient> <subject> <body-file>
    python3 send_mail.py <recipient> <subject> --body "inline body"
"""
import sys, subprocess, smtplib
from email.mime.text import MIMEText
from email.header import Header
from email.utils import formataddr

SMTP_SERVER = "smtp.example.com"
SMTP_PORT = 465
SENDER = "your-email@example.com"
SENDER_NAME = "Your Name"
KEYCHAIN_SERVICE = "your-app/smtp"
KEYCHAIN_ACCOUNT = "your-email@example.com"


def get_password():
    """Retrieve SMTP password from macOS Keychain."""
    result = subprocess.run(
        ["security", "find-generic-password",
         "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_ACCOUNT, "-w"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError("Failed to read password from Keychain")
    return result.stdout.strip()


def send(to_addr, subject, body):
    msg = MIMEText(body, "plain", "utf-8")
    msg["From"] = formataddr((str(Header(SENDER_NAME, "utf-8")), SENDER))
    msg["To"] = to_addr
    msg["Subject"] = Header(subject, "utf-8")

    password = get_password()
    with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as s:
        s.login(SENDER, password)
        s.send_message(msg)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <recipient> <subject> <body-file | --body text>")
        sys.exit(1)

    to = sys.argv[1]
    subj = sys.argv[2]

    if sys.argv[3] == "--body":
        body = sys.argv[4] if len(sys.argv) > 4 else ""
    else:
        with open(sys.argv[3], "r", encoding="utf-8") as f:
            body = f.read()

    send(to, subj, body)
    print(f"✓ Sent to {to}")
