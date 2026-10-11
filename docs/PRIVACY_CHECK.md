# Publication privacy review / 发布隐私检查

Reviewed on 2026-10-11 for v1.0.0 and rechecked for v1.0.1 and v1.0.2. This review covers the files intended for the public repository and the compiled release archive; it is not a guarantee against every possible sensitive value.

2026-10-11，对 v1.0.0、v1.0.1 及 v1.0.2 公开文件和编译安装包进行检查。此检查不等同于保证任何可能的敏感信息都能被识别。

## Changes made before publication

- Excluded personal Xcode `xcuserdata`, workspace UI state, `.DS_Store`, build outputs, certificates and local design drafts.
- Removed project development-team identifiers. No signing private key or developer certificate is distributed; the app is ad-hoc signed with no team identity.
- Preserved the original private local initial Git history in a local-only backup branch. The public source commit descends from the existing GitHub repository history instead of publishing the private local root commit. Only `main` and the release tag are pushed.
- Remapped compiler source/debug paths to relative paths. The first compiled candidate contained absolute home/workspace paths; that candidate was not published. The final app bundle is scanned again before uploading.
- Used GitHub's public noreply address for publication commits.
- Inspected separate Chinese and English app-window captures. Images include the approved mouse model, battery, DPI and report rate, but no desktop, username, file path, serial number or connection-location identifier.
- Compatibility wording distinguishes the one hardware-verified device from untested model references.

## App data handling

The app uses local HID++ reads and explicit device-control commands. It has no analytics SDK, account system or background network requests. It reads manufacturer/model/protocol information, not hardware serial numbers. Notification deduplication stores a local identifier made from connection location and pairing slot. Local system logs contain scan counts and some control state; Debug builds additionally log device name, battery and DPI.

Check for Updates opens the GitHub Releases page in the default browser when clicked. The previous unconditional “up to date” alert was replaced, so the app does not imply an update check has happened when it has not.

## Checks

- `scripts/check-publication.py`: scans tracked publication files for common tokens, private keys, personal home paths, private contact emails, development-team IDs and local user-setting files. It prints locations/categories instead of sensitive values.
- `scripts/check-release.py`: verifies both CPU architectures, their minimum macOS loader versions, and the ad-hoc signature; scans all bundle files for matching personal paths/emails/credentials; checks the ZIP for local metadata and debug-symbol bundles.
- Human visual review checks the screenshots and the documentation's claims.

README badge requests go to GitHub / Shields.io. The Stars workflow requests only the repository's total star count, stores daily aggregate observations, and does not export account tokens or collect stargazers' identities.
