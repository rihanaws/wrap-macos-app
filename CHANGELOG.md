# Changelog

## 0.2.0 — 2026-06-20

### Added

- Added the `warp` SwiftPM executable product as a Claude Code-style terminal companion.
- Added `WarpCLICore` with command routing, config/session persistence, Keychain-backed provider credentials, provider request builders, SSE response normalization, git review helpers, MCP config discovery, terminal ANSI primitives, block rendering, raw-mode support, permission gating, and tool dispatch.
- Added CLI tests covering command registry, config persistence, session persistence, provider request shape, git status parsing, MCP config parsing, terminal primitives, block rendering, and permission policy.
- Added root `install.sh` for release-artifact `curl | sh` installation and `script/install_cli.sh` for source-checkout installation.

### Changed

- Updated `script/build_and_run.sh` to build the `WarpClone` app product explicitly before creating the app bundle.
- Updated README with app and CLI build, run, install, and verification instructions.

## 0.1.0 — 2026-06-19

### Added

- Initial Mac-native SwiftUI app shell with sidebar, detail pane, inspector, Settings scene, command menus, command palette, split panes, and terminal UI.
- Real PTY lifecycle using `posix_openpt`, `grantpt`, `unlockpt`, `fork`, `setsid`, `dup2`, shell exec, async read loop, resize propagation, and cleanup.
- ANSI parser coverage for 16-color, 256-color, true color, reset, and nested styles.
- 21-theme registry with terminal/detail styling and native sidebar/window materials.
- OpenRouter/BYOK provider wiring, model discovery cache, Keychain credential storage, git review surface, MCP inspector, image attachments, and premium visual redesign.
- MIT license and first GitHub push.
