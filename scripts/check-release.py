#!/usr/bin/env python3
"""Validate a release bundle and archive before uploading them."""
import plistlib
import re
import subprocess
import sys
import zipfile
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: check-release.py <app-bundle> <zip-archive>")
    app, archive = map(Path, sys.argv[1:])
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise SystemExit("Release is not a universal arm64/x86_64 build")
    # Check the actual loader requirement for each CPU, not just Info.plist.
    declared_minimum = info["LSMinimumSystemVersion"]
    for architecture in architectures:
        build_info = subprocess.check_output(
            ["xcrun", "vtool", "-arch", architecture, "-show-build", str(executable)], text=True
        )
        minimums = re.findall(r"^\s*minos\s+(\S+)", build_info, re.MULTILINE)
        if minimums != [declared_minimum]:
            raise SystemExit(f"{architecture} loader minimum does not match Info.plist")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    signature = subprocess.run(["codesign", "-dvv", str(app)], capture_output=True, text=True, check=True).stderr
    if "Signature=adhoc" not in signature or "TeamIdentifier=not set" not in signature:
        raise SystemExit("Unexpected signing identity; review certificate privacy before publication")
    patterns = {
        "personal home path": re.compile(rb"/" + rb"Users/[^/\s]+/"),
        "private contact email": re.compile(rb"[A-Za-z0-9._%+-]+@(?:qq\.com|gmail\.com|icloud\.com|outlook\.com|hotmail\.com)\b"),
        "credential token": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-(?:proj-)?[A-Za-z0-9_-]{30,})\b"),
        "private key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
    }
    findings = []
    for file in app.rglob("*"):
        if not file.is_file():
            continue
        data = file.read_bytes()
        for category, pattern in patterns.items():
            if pattern.search(data):
                findings.append((file.relative_to(app), category))
    with zipfile.ZipFile(archive) as bundle:
        for name in bundle.namelist():
            if any(part in name for part in ("xcuserdata", ".dSYM", ".DS_Store", "__MACOSX", ".xcuserstate")):
                findings.append((name, "local metadata in archive"))
    if findings:
        for file, category in findings:
            print(f"{file}: {category}")
        raise SystemExit("Release privacy check failed; values were not printed")
    print(f"Release check passed: {info['CFBundleShortVersionString']}, macOS {info['LSMinimumSystemVersion']}+, universal, ad-hoc signed. No matching personal paths/emails/credentials or local metadata.")


if __name__ == "__main__":
    main()
