#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_temp="$(mktemp -d)"
trap 'rm -rf "$task_temp"' EXIT
task_source="$task_root/Logi Dashboard Lite"
swiftc -D DEBUG -module-cache-path "$task_temp/modules" \
    "$task_source/Support/L10n.swift" \
    "$task_source/Models/DeviceKind.swift" \
    "$task_source/Models/BatteryReading.swift" \
    "$task_source/HID/HIDPPMessage.swift" \
    "$task_source/HID/HIDPPDecoding.swift" \
    "$task_root/tests/main.swift" -o "$task_temp/hidpp-fixtures"
"$task_temp/hidpp-fixtures"
