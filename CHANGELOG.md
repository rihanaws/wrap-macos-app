# Changelog

## 0.2.0 — 2026-06-20

### Added

- Added the `warp` CLI companion executable with `ask`, `chat`, `agent`, `review`, `mcp`, and `config` commands.
- Added `WarpCLICore` for CLI configuration, Keychain-backed provider credentials, OpenRouter-compatible streaming, git review prompts, MCP discovery, terminal primitives, and permission gating.
- Added source and release installer scripts for the CLI.
- Added shared security guardrails: tool risk classification, command sandbox validation, JSONL audit logging, MCP sandbox homes, MCP rate limiting, and terminal input sanitization.

### Changed

- Updated the SwiftPM package to build the macOS app and CLI as separate executable products.
- Updated the app product to depend on `WarpCLICore` so the app and CLI use shared security primitives.
- Updated README instructions for building, running, installing, and validating the app and CLI.
- Hardened MCP startup in the macOS app by filtering inherited secrets, assigning a restricted per-server `HOME`, and auditing discover/start/stop/remove events.
- Sanitized text before writing to the PTY so OSC/DCS manipulation sequences do not reach the terminal process.

## 0.1.0 — 2026-06-19

### Added

- Initial SwiftPM macOS app shell with `WindowGroup`, dedicated `Settings` scene, `NavigationSplitView`, inspector, command menus, command palette, split panes, PTY-backed terminal sessions, ANSI parsing, 21 themes, OpenRouter/BYOK settings, MCP inspector, git review surfaces, MIT license, README, and build/run script.
