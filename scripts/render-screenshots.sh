#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_temp="$(mktemp -d)"
trap 'rm -rf "$task_temp"' EXIT
task_bundle="$task_temp/DocumentationRenderer.app"
mkdir -p "$task_bundle/Contents/MacOS" "$task_bundle/Contents/Resources"

task_resources="${LOGI_APP_RESOURCES:-$task_root/build/release/Build/Products/Release/Logi Dashboard Lite.app/Contents/Resources}"
cp -R "$task_resources/en.lproj" "$task_resources/zh-Hans.lproj" "$task_bundle/Contents/Resources/"
cat > "$task_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>DocumentationRenderer</string><key>CFBundleIdentifier</key><string>org.trustdev.Logi-Dashboard-Lite.DocumentationRenderer</string><key>CFBundleDevelopmentRegion</key><string>en</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/></dict></plist>
PLIST

python3 - "$task_root" "$task_bundle" <<'PY'
import subprocess, sys
from pathlib import Path
root, bundle = map(Path, sys.argv[1:])
sources = sorted((root / 'Logi Dashboard Lite').rglob('*.swift'))
sources = [str(p) for p in sources if p.name != 'Logi_Dashboard_LiteApp.swift']
subprocess.run(['swiftc', '-parse-as-library', '-default-isolation', 'MainActor', '-swift-version', '5', '-module-cache-path', str(bundle.parent / 'modules'), *sources, str(root / 'scripts/render-screenshots.swift'), '-o', str(bundle / 'Contents/MacOS/DocumentationRenderer')], check=True)
PY
codesign --force --sign - --timestamp=none "$task_bundle"
task_language="${1:-zh-CN}"
if [ "$task_language" = en ]; then
    "$task_bundle/Contents/MacOS/DocumentationRenderer" "$task_root/docs/screenshots/en" -AppleLanguages '(en)' -AppleLocale en_US "${@:2}"
else
    "$task_bundle/Contents/MacOS/DocumentationRenderer" "$task_root/docs/screenshots/zh-CN" -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN "${@:2}"
fi
