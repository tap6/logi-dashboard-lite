#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_temp="$(mktemp -d)"
trap 'rm -rf "$task_temp"' EXIT
python3 - "$task_root" "$task_temp" <<'PY'
import platform, subprocess, sys
from pathlib import Path
root, temporary = map(Path, sys.argv[1:])
sources = sorted((root / 'Logi Dashboard Lite').rglob('*.swift'))
sources = [str(p) for p in sources if p.name != 'Logi_Dashboard_LiteApp.swift']
executable = temporary / 'window-smoke'
subprocess.run([
    'swiftc', '-parse-as-library', '-default-isolation', 'MainActor', '-swift-version', '5',
    '-target', f'{platform.machine()}-apple-macos14.0',
    '-module-cache-path', str(temporary / 'modules'),
    *sources, str(root / 'tests/WindowSmoke.swift'), '-o', str(executable)
], check=True)
subprocess.run([str(executable)], check=True, timeout=30)
PY
