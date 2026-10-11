#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build="${LOGI_BUILD_DIR:-$task_root/build/release}"
task_dist="${LOGI_DIST_DIR:-$task_root/dist}"
task_version="$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' "$task_root/Logi Dashboard Lite.xcodeproj/project.pbxproj" | head -1)"
task_archive="Logi-Dashboard-Lite-${task_version}-macOS-universal.zip"

mkdir -p "$task_dist"
xcodebuild -project "$task_root/Logi Dashboard Lite.xcodeproj" \
    -scheme 'Logi Dashboard Lite' -configuration Release \
    -derivedDataPath "$task_build" -destination 'generic/platform=macOS' \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
    "OTHER_SWIFT_FLAGS=\$(inherited) -file-prefix-map \"$task_root=.\" -debug-prefix-map \"$task_root=.\"" build

task_app="$task_build/Build/Products/Release/Logi Dashboard Lite.app"
cp "$task_root/LICENSE" "$task_app/Contents/Resources/LICENSE"
printf 'Corresponding source code (GPL-3.0-only):\nhttps://github.com/tap6/logi-dashboard-lite/tree/v%s\n' "$task_version" > "$task_app/Contents/Resources/Source.txt"
# Ad-hoc signing avoids embedding a developer's personal certificate.
# This is not Developer ID signing or Apple notarization.
codesign --force --sign - --options runtime --timestamp=none "$task_app"
codesign --verify --deep --strict "$task_app"
lipo -archs "$task_app/Contents/MacOS/Logi Dashboard Lite"
ditto -c -k --keepParent --norsrc --noextattr "$task_app" "$task_dist/$task_archive"
python3 "$task_root/scripts/check-release.py" "$task_app" "$task_dist/$task_archive"
(cd "$task_dist" && shasum -a 256 "$task_archive" > SHA256SUMS.txt)
printf 'Release archive: %s\n' "$task_dist/$task_archive"
