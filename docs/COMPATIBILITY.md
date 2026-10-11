# macOS compatibility / macOS 兼容性

v1.0.1 lowers the deployment target from macOS 26.4 to **macOS 14.0 (Sonoma)** for both Apple Silicon and Intel.

v1.0.1 将 Apple Silicon 和 Intel 的最低系统要求从 macOS 26.4 降至 **macOS 14.0（Sonoma）**。

## Why 14.0 / 为什么选择 14.0

The app's `@Observable` data model and SwiftUI observation support require macOS 14. The two-argument `onChange`, `ContentUnavailableView` APIs also require macOS 14. Supporting macOS 13 would require replacing these pieces and validating the resulting data flow and interface behavior.

当前 `@Observable` 数据模型、SwiftUI 观察机制、双参数 `onChange`和 `ContentUnavailableView` 均要求 macOS 14。支持 macOS 13 需要替换这些实现，并重新验证数据更新与界面行为。

- [Apple: Managing model data in your app](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app)
- [Apple: defaultLaunchBehavior](https://developer.apple.com/documentation/SwiftUI/Scene/defaultLaunchBehavior(_:))

The macOS 15-only `defaultLaunchBehavior(.suppressed)` call has been removed. The dashboard is now created on demand using an AppKit window hosting the existing SwiftUI view. This keeps startup limited to the menu bar without depending on a newer window-launch modifier. Since v1.0.2, the status item, mouse panel and settings window are managed through public AppKit APIs while hosting the existing SwiftUI views. Left-click toggles the panel; right-click or Control-click opens only the menu. Popover placement accounts for flipped coordinates, and the system positions the status-item menu.

已移除仅 macOS 15 及以上可用的 `defaultLaunchBehavior(.suppressed)`。仪表盘改为按需创建 AppKit 窗口并承载原有 SwiftUI 界面，保留启动时仅显示菜单栏图标的行为。v1.0.2 起，菜单栏按钮、鼠标面板和设置窗口使用公开 AppKit API 管理，继续承载原有 SwiftUI 界面。左键开关面板，右键或 Control＋左键只显示菜单；面板方向考虑翻转坐标，右键菜单由系统定位。

## Verification and limits / 验证范围与限制

- Universal Release compilation uses a macOS 14.0 deployment target, so unguarded newer APIs are rejected by the compiler.
- Publication checks verify `LSMinimumSystemVersion` and each architecture's Mach-O `LC_BUILD_VERSION` loader requirement, plus architecture, signature and privacy checks.
- HID++ decoding fixtures cover the existing protocol parsing.
- `bash scripts/test-windows.sh` passed on the available newer macOS host: dashboard creation on demand, close and reopen; left/right/Control-click exclusivity; first-show position; dynamic panel sizing; and settings opening. This check needs a graphical desktop session and uses preview data without accessing hardware. **macOS 14/15 runtime and Intel hardware testing remain pending.** A lower deployment target is not proof that every OS/hardware combination has been tested.
- Device compatibility still depends on the mouse, receiver, firmware and exposed HID++ features; lowering the OS requirement does not add new mouse protocol support.

通用 Release 以 macOS 14.0 为部署目标编译；发布检查同时验证应用元数据及两种架构二进制的加载器最低版本。现有 HID++ 解码测试继续执行。运行检查使用当前较新系统；**尚未在 macOS 14/15 或 Intel 实机测试**。降低系统要求并不会自动扩大鼠标协议支持范围。
