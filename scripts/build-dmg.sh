#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build="${LOGI_BUILD_DIR:-$task_root/build/release}"
task_dist="${LOGI_DIST_DIR:-$task_root/dist}"
task_app="${1:-$task_build/Build/Products/Release/Logi Dashboard Lite.app}"
task_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$task_app/Contents/Info.plist")"
task_basename="Logi-Dashboard-Lite-${task_version}-macOS-universal"
task_python="${LOGI_DMG_PYTHON:-$task_build/dmg-tools/bin/python}"

# Isolate packaging dependencies from the system Python and the app bundle.
if [[ -z "${LOGI_DMG_PYTHON:-}" ]]; then
    if [[ ! -x "$task_python" ]]; then
        python3 -m venv "$task_build/dmg-tools"
    fi
    "$task_python" -m pip install --disable-pip-version-check -r "$task_root/scripts/dmg-requirements.txt"
fi

mkdir -p "$task_dist"
"$task_python" -m dmgbuild -s "$task_root/scripts/dmg-settings.py" -D "app=$task_app" \
    "Logi Dashboard Lite" "$task_dist/$task_basename.dmg"
"$task_python" "$task_root/scripts/check-dmg.py" "$task_dist/$task_basename.dmg" "$task_app"
# Regenerate both entries, preserving the checksum of the existing ZIP.
(cd "$task_dist" && shasum -a 256 "$task_basename.dmg" "$task_basename.zip" > SHA256SUMS.txt)
printf 'Drag-to-Applications installer: %s\n' "$task_dist/$task_basename.dmg"
