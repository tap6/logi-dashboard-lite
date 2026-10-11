#!/usr/bin/env python3
"""Mount the final DMG, verify its payload and inspect Finder metadata."""
import hashlib
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile

from ds_store import DSStore
PATTERNS = runpy.run_path(str(Path(__file__).with_name("check-publication.py")))["PATTERNS"]


def files_in(root):
    for directory, folders, files in os.walk(root, followlinks=False):
        folders[:] = [name for name in folders if not (Path(directory) / name).is_symlink()]
        for name in files:
            path = Path(directory) / name
            if not path.is_symlink():
                yield path


def bundle_hashes(root):
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in files_in(root)}


def main():
    image, original = map(Path, sys.argv[1:])
    subprocess.run(["hdiutil", "verify", str(image)], check=True)
    with tempfile.TemporaryDirectory(prefix="logi-dmg-check-") as directory:
        mount = Path(directory) / "volume"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-noautoopen",
                        "-mountpoint", str(mount), str(image)], check=True)
        try:
            application = mount / original.name
            if bundle_hashes(application) != bundle_hashes(original):
                raise SystemExit("DMG application differs from the verified release bundle")
            if os.readlink(mount / "Applications") != "/Applications":
                raise SystemExit("DMG Applications link has an unexpected destination")
            subprocess.run(["codesign", "--verify", "--deep", "--strict", str(application)], check=True)
            with DSStore.open(str(mount / ".DS_Store"), "r") as layout:
                if layout[original.name]["Iloc"] != (140, 120) or layout["Applications"]["Iloc"] != (500, 120):
                    raise SystemExit("DMG does not contain the expected drag-install layout")
                if layout["."]["icvp"]["backgroundType"] != 2:
                    raise SystemExit("DMG arrow background is missing")
            for path in files_in(mount):
                data = path.read_bytes()
                # Finder aliases can also contain UTF-16 strings.
                for label, pattern in PATTERNS.items():
                    if pattern.search(data) or pattern.search(data.replace(b"\x00", b"")):
                        raise SystemExit(f"DMG privacy check: {path.relative_to(mount)}: {label}")
            # Simulate a drag copy without changing the user's installed app.
            copied = Path(directory) / "Applications" / original.name
            subprocess.run(["ditto", str(application), str(copied)], check=True)
            subprocess.run(["codesign", "--verify", "--deep", "--strict", str(copied)], check=True)
            print("DMG check passed: identical universal app, Applications link, Finder layout, privacy scan and copied-app signature.")
        finally:
            subprocess.run(["hdiutil", "detach", str(mount)], check=True)


if __name__ == "__main__":
    main()
