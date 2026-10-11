# Screenshot reproduction / 截图复现

These screenshots show the real application views with a read-only snapshot of a connected PRO X Wireless mouse over Lightspeed. UI labels use the compiled app's own English / Simplified Chinese string resources. No mock hardware values are supplied. The documentation helper never starts the preference/notification loop and never changes mouse settings.

截图展示软件真实界面和已连接鼠标的只读快照；使用应用编译后的中英文资源，没有伪造设备数据。文档辅助程序不会启动偏好/通知循环，也不会修改鼠标设置。

Build the app first with `bash scripts/build-release.sh`. Run on macOS with a connected HID++ device:

```bash
bash scripts/render-screenshots.sh zh-CN
bash scripts/render-screenshots.sh en
```

The helper opens a native dashboard window. Capture only that window as `zh-CN/dashboard.png` or `en/dashboard.png`, then quit the helper before starting the other language. To show the panel content in a separate window, append `--popover`. Capture only its content as `zh-CN/popover.png` or `en/popover.png`.

The published images are cropped to the content area, removing the documentation helper's title bar. The optional `adjust.png` images are captured after selecting Adjust in this read-only helper. The current sensor value and preset selection are not changed.

For the captured 2× windows, `swift scripts/crop-screenshot.swift <window-capture> <content-png>` removes the 64-pixel helper title bar and writes a PNG without carrying over the original screenshot metadata.

The helper replaces device location/pairing identifiers with documentation-only IDs in memory before displaying the snapshot. Before publishing, inspect visible device/profile names and avoid including desktops, unrelated windows, account identifiers or private custom profile names. Battery, DPI and report-rate values in these images are observations from the connected device at capture time.
