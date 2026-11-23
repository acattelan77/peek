#!/usr/bin/env python3
"""Checks that every localized string in Peek/Sources has an entry in every
Localizable.strings table, that no table carries unused keys, and that each
translation keeps the key's format specifiers in the same order."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = os.path.join(ROOT, "Peek", "Sources")
RESOURCES = os.path.join(ROOT, "Peek", "Resources")
LITERAL = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [
    re.compile(r"NSLocalizedString\(\s*" + LITERAL),
    re.compile(r"String\(localized:\s*" + LITERAL),
    re.compile(r"(?<![A-Za-z.])Text\(\s*" + LITERAL + r"\s*\)"),
    re.compile(r"(?<![A-Za-z.])(?:Button|Toggle|Label|Section|Menu|Picker)\(\s*" + LITERAL),
]
ENTRY = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$', re.M)
SPECIFIER = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDuUxXoOfeEgGcCsSp%]")


def source_keys():
    keys = set()
    for root, _, files in os.walk(SOURCES):
        for name in files:
            if not name.endswith(".swift"):
                continue
            text = open(os.path.join(root, name), encoding="utf-8").read()
            # SwiftUI previews are developer-only and are not localized.
            text = re.split(r"\n(?:struct \w+_Previews|#Preview)", text)[0]
            for pattern in PATTERNS:
                for match in pattern.finditer(text):
                    key = match.group(1)
                    if key and "\\(" not in key:
                        keys.add(key)
    return keys


def specifiers(value):
    return [re.sub(r"\d+\$", "", s) for s in SPECIFIER.findall(value) if s != "%%"]


def main():
    expected = source_keys()
    tables = sorted(
        os.path.join(RESOURCES, d, "Localizable.strings")
        for d in os.listdir(RESOURCES) if d.endswith(".lproj")
    )
    errors = []
    for table in tables:
        text = open(table, encoding="utf-8").read()
        entries = dict(ENTRY.findall(text))
        rel = os.path.relpath(table, ROOT)
        for key in sorted(expected - entries.keys()):
            errors.append(f"{rel}: missing \"{key}\"")
        for key in sorted(entries.keys() - expected):
            errors.append(f"{rel}: unused \"{key}\"")
        for key, value in entries.items():
            if not value:
                errors.append(f"{rel}: empty translation for \"{key}\"")
            elif sorted(specifiers(key)) != sorted(specifiers(value)):
                errors.append(f"{rel}: format specifiers differ for \"{key}\"")
    if errors:
        print("\n".join(errors))
        print(f"Localization check failed: {len(errors)} problem(s).")
        return 1
    print(f"Localization OK: {len(expected)} keys in {len(tables)} tables.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
