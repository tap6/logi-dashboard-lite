# Logi Dashboard Lite App Icon

## Current approved icon

The app uses menu-symbol-preview.png: the native macOS computermouse symbol in charcoal on a flat warm off-white rounded square, without battery elements. All 10 AppIcon renditions (16–1024 px) have been replaced with this approved design. LogiDashboardLite.icns is the matching compiled export. The asset catalog passed Xcode actool compilation.

## Reproduce the source

On macOS, run `swift Design/AppIcon/render-menu-symbol.swift` from the repository root. This renders the native `computermouse` symbol and saves `menu-symbol-preview.png` alongside the script. The production AppIcon asset catalog contains the resized versions.
