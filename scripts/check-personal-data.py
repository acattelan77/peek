#!/usr/bin/env python3
"""Fail when tracked files or new commits carry personal data.

The repository is public. This check looks for the kinds of data that have
leaked before, without naming them in clear:

* email addresses outside fictional or service domains;
* home-directory paths (/Users/<name>, /home/<name>);
* signing material and build outputs (certificates, profiles, .app bundles);
* terms on a private denylist, stored only as SHA-256 hashes in
  scripts/personal-data-denylist.sha256, plus any plain terms in the
  PERSONAL_DATA_DENYLIST environment variable (one per line), which CI can
  fill from a repository secret.

A line that is fictional on purpose but looks real (for example a test
fixture with a consumer email domain) can end with the marker
"personal-data: fictional".

Usage:
  python3 scripts/check-personal-data.py               # tracked files
  python3 scripts/check-personal-data.py --commits BASE  # also BASE..HEAD metadata
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DENYLIST_FILE = ROOT / "scripts" / "personal-data-denylist.sha256"
SKIP_FILES = {"scripts/personal-data-denylist.sha256"}
MARKER = "personal-data: fictional"

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)")
NOT_EMAIL_TLDS = {"png", "jpg", "jpeg", "gif", "pdf", "svg", "json", "swift"}
ALLOWED_EMAIL_DOMAINS = (
    "example.com", "example.org", "example.net",
    "users.noreply.github.com", "anthropic.com", "github.com",
    # Service addresses that appear in calendar invitations.
    "resource.calendar.google.com", "zoomcrc.com",
)
ALLOWED_EMAIL_SUFFIXES = (".example", ".test", ".invalid")

HOME_PATH = re.compile(r"(?<![\w$])/(?:Users|home)/([A-Za-z0-9._-]+)")
ALLOWED_HOMES = {"someone", "you", "owner", "user", "username", "me", "Shared", "runner", "name"}

FORBIDDEN_PATHS = re.compile(
    r"(^|/)(artifacts|DerivedData|build)/"
    r"|\.(app|xcarchive|appex)/"
    r"|\.(p12|pfx|cer|crt|pem|key|keychain|keychain-db|mobileprovision|provisionprofile"
    r"|dmg|ipa|pkg|Rhistory)$"
    r"|(^|/)\.env($|\.)",
    re.IGNORECASE,
)

TOKEN = re.compile(r"[\w.@+-]+", re.UNICODE)


def load_hashes() -> set[str]:
    hashes = set()
    if DENYLIST_FILE.exists():
        for line in DENYLIST_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                hashes.add(line.split()[0].lower())
    for term in os.environ.get("PERSONAL_DATA_DENYLIST", "").splitlines():
        term = term.strip().lower()
        if term:
            hashes.add(hashlib.sha256(term.encode()).hexdigest())
    return hashes


def candidates(text: str):
    """Every token, its pieces and its dotted suffixes, lower-cased."""
    for token in TOKEN.findall(text):
        token = token.strip(".-_+@").lower()
        if not token:
            continue
        yield token
        for piece in re.split(r"[.@/_+-]", token):
            if piece:
                yield piece
        parts = token.split(".")
        for i in range(1, len(parts)):
            yield ".".join(parts[i:])
            yield ".".join(parts[:i])
        # Hyphenated names such as machine names, without the trailing piece.
        hyphen = token.split("-")
        for i in range(2, len(hyphen)):
            yield "-".join(hyphen[:i])


def email_ok(domain: str) -> bool:
    domain = domain.lower()
    if domain.rsplit(".", 1)[-1] in NOT_EMAIL_TLDS:
        return True
    if domain.endswith(ALLOWED_EMAIL_SUFFIXES):
        return True
    return any(domain == d or domain.endswith("." + d) for d in ALLOWED_EMAIL_DOMAINS)


def scan_text(label: str, text: str, hashes: set[str], problems: list[str]) -> None:
    for number, line in enumerate(text.splitlines(), 1):
        if MARKER in line:
            continue
        where = f"{label}:{number}"
        for match in EMAIL.finditer(line):
            if not email_ok(match.group(1)):
                problems.append(f"{where}: email address outside example domains")
        for match in HOME_PATH.finditer(line):
            if match.group(1) not in ALLOWED_HOMES:
                problems.append(f"{where}: home-directory path with a user name")
        seen = set()
        for term in candidates(line):
            if term in seen:
                continue
            seen.add(term)
            if hashlib.sha256(term.encode()).hexdigest() in hashes:
                problems.append(f"{where}: term on the personal-data denylist")
                break


def tracked_files() -> list[str]:
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, check=True,
                         capture_output=True).stdout
    return [p for p in out.decode().split("\0") if p]


def scan_tree(hashes: set[str], problems: list[str]) -> None:
    for path in tracked_files():
        if FORBIDDEN_PATHS.search(path):
            problems.append(f"{path}: signing material, build output or local file must not be committed")
            continue
        if path in SKIP_FILES:
            continue
        data = (ROOT / path).read_bytes() if (ROOT / path).is_file() else b""
        if b"\0" in data[:8192]:
            continue  # binary; covered by the path rule above
        scan_text(path, data.decode("utf-8", errors="replace"), hashes, problems)


def scan_commits(base: str, hashes: set[str], problems: list[str]) -> None:
    fmt = "%H%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1f%B%x1e"
    out = subprocess.run(["git", "log", f"--format={fmt}", f"{base}..HEAD"], cwd=ROOT,
                         check=True, capture_output=True, text=True).stdout
    for record in out.split("\x1e"):
        record = record.strip("\n")
        if not record:
            continue
        sha, an, ae, cn, ce, body = record.split("\x1f", 5)
        label = f"commit {sha[:10]}"
        for role, email in (("author", ae), ("committer", ce)):
            domain = email.rsplit("@", 1)[-1] if "@" in email else ""
            if not email_ok(domain):
                problems.append(f"{label}: {role} email is not a noreply or example address")
        scan_text(f"{label} (names)", f"{an}\n{cn}", hashes, problems)
        scan_text(f"{label} (message)", body, hashes, problems)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--commits", metavar="BASE",
                        help="also check author, committer and message of BASE..HEAD")
    args = parser.parse_args()

    hashes = load_hashes()
    problems: list[str] = []
    scan_tree(hashes, problems)
    if args.commits:
        scan_commits(args.commits, hashes, problems)

    if problems:
        print("Personal-data check failed. The repository is public; use fictional")
        print("names, example.com addresses and generic paths (AGENTS.md, invariants).")
        for problem in problems:
            print(f"  {problem}")
        return 1
    print("Personal-data check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
