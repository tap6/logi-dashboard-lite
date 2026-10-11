#!/usr/bin/env python3
"""Check files staged for publication. Report locations, never secret values."""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "private key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
    "GitHub token": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b"),
    "AWS access key": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "API secret": re.compile(rb"\bsk-(?:proj-)?[A-Za-z0-9_-]{30,}\b"),
    "personal absolute path": re.compile(rb"/" + rb"Users/[^/\s\"'<>]+/"),
    "Apple development team": re.compile(rb"DEVELOPMENT_TEAM\s*=\s*\w+"),
    "private contact email": re.compile(rb"[A-Za-z0-9._%+-]+@(?:qq\.com|gmail\.com|icloud\.com|outlook\.com|hotmail\.com)\b"),
}


def main():
    names = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    issues = []
    for name in filter(None, names):
        path = ROOT / name
        parts = Path(name).parts
        if "xcuserdata" in parts or name.endswith(".xcuserstate") or Path(name).name.startswith(".env"):
            issues.append((name, "local-only file", 0))
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b"\0" in data or path.suffix.lower() in {".png", ".icns", ".zip"}:
            continue
        for label, pattern in PATTERNS.items():
            for match in pattern.finditer(data):
                issues.append((name, label, data[:match.start()].count(b"\n") + 1))
    for path, category, line in issues:
        print(f"{path}:{line}: {category}")
    if issues:
        print(f"Publication check failed: {len(issues)} finding(s). Values have not been printed.")
        sys.exit(1)
    print(f"Publication check passed: {sum(bool(n) for n in names)} tracked files checked. This is a pattern check, not a guarantee against every possible secret.")


if __name__ == "__main__":
    main()
