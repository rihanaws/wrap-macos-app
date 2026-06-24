# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Release Prep

- `script/build_and_sign.sh` builds a release `.app`, signs it ad-hoc by default or with `SIGNING_ID`, optionally notarizes with `NOTARIZE=true`, and emits a DMG.
- `script/notarize_setup.sh` stores Apple notarization credentials in a local keychain profile. Never commit Apple IDs, app-specific passwords, team IDs tied to private accounts, or signing identities as secrets.
- `script/generate_icons.sh` creates macOS icon assets from a 1024x1024 PNG under `Sources/WarpClone/Resources/Assets.xcassets`.
- `script/screenshot.sh` captures release screenshots into `docs/screenshots`.
- Release docs live in `docs/BETA_TESTING.md`, `docs/DESIGN_ASSETS.md`, `PRIVACY_POLICY.md`, and `CHANGELOG.md`.
- App bundle resources live under `Sources/WarpClone/Resources`; keep `Package.swift` resource registration in sync when adding app metadata or assets.
- GitHub Copilot OAuth uses device flow. Configure the public OAuth client ID through `GitHubOAuthClientID` in the app bundle, `GITHUB_OAUTH_CLIENT_ID` during release bundling, or `WARPCLONE_GITHUB_CLIENT_ID` for local runs. Tokens live in Keychain via `CopilotTokenStore`; do not store Copilot OAuth tokens as provider API keys.

## Build & Test Commands

```bash
# Build all targets
swift build

# Run app (macOS)
swift run WarpClone

# Run CLI companion
swift run warp

# Run tests
swift test

# Run specific test
swift test WarpCLITests.PermissionGateTests

# Build release binary
swift build -c release

# Install CLI to $HOME/.local/bin
script/install.sh
```

## Architecture Overview

WarpClone is a dual-product Swift project: a native macOS terminal app + CLI companion tool sharing security primitives.

### Product Structure

- **WarpClone** (executable): SwiftUI-based terminal emulator with:
  - PTY session management (PTYSession.swift)
  - ANSI rendering (ANSIParser.swift)
  - 21 themes (ThemeRegistry.swift)
  - MCP inspector UI (MCPManager.swift)
  - Git review surfaces (GitService.swift, InspectorView.swift, DiffView.swift)
  - OpenRouter/BYOK AI provider integration (AIProviders.swift, ConversationStore.swift, AIInspectorView.swift)

- **WarpCLI** (executable): Command-line companion with subcommands:
  - `ask` / `chat` / `agent` — AI requests via OpenRouter
  - `review` — Git-aware code review prompts
  - `mcp` — MCP server discovery/config management
  - `config` — CLI settings

- **WarpCLICore** (library): Shared security & infra layer:
  - `PermissionGate.swift` — Tool risk classification, command sandbox validation, JSONL audit logging
  - `MCPRegistry.swift` — Claude/Codex config parsing (claude_settings.json, settings.toml)
  - `AIProviders.swift` — OpenRouter-compatible streaming client
  - `GitReviewService.swift` — Prompt templating for code reviews
  - `TerminalPrimitives.swift` — ANSI codes, terminal I/O, raw mode control
  - `CLISessionStore.swift`, `CLIConfig.swift`, `CLIKeychainStore.swift` — State & credential persistence

### Key Design Decisions

**Permission Gating**: PermissionGate is the central enforcement point. All tool/command/network/credential actions route through `PermissionGate.evaluate` → `ToolDispatcher.dispatch`. Mode `.ask` requires user approval for every action, including read-only. `allowRead` auto-allows read-only only; `allowWrite` auto-allows read+write. Permanently blocked commands (e.g. `rm -rf /`, `rm -rf ~`, `$HOME`/`${HOME}` destructive variants, `curl | sh`) are denied under every mode, including `allowAll` — that check runs before the mode switch. Decisions are JSONL-audited.

**MCP Sandbox + Approval**: Each MCP server gets a restricted per-server `HOME` with inherited secrets filtered at startup. Discovered servers also require explicit SHA256 descriptor-hash approval (`MCPManager.approve`/`approvedDescriptorHashes`) before `Process.run()` — Inspector's Start button routes unapproved servers through `PermissionApprovalView` instead of starting directly. MCPRegistry parses both claude_settings.json and .cursorrules/settings.toml for auto-discovery.

**Permission Approval UI**: `PermissionApprovalView` (Sources/WarpClone) is the reusable SwiftUI sheet for any approval flow — Allow Once / Deny / Edit Command (only rendered when `onEditCommand` is non-nil) / Always Allow (only for `.readOnly`/`.write` risk — gated off for `.destructive`/`.network`/`.credential`/`.unknown`). Risk is conveyed via icon, color, visible text badge, and a combined VoiceOver label (not color/icon alone). `.destructive`/`.network`/`.credential`/`.unknown` also drop the default-Return-key shortcut on Allow Once, requiring explicit confirmation — `.unknown` covers MCP approval (InspectorView), so a stray Enter cannot launch an unverified MCP process. Long commands show a horizontal-scroll hint. Used by MCP approval today; designed for future ToolDispatcher approval callbacks via `ToolApprovalHandler`.

**Terminal Hardening**: PTYSession uses a single `DispatchSourceRead` per session (spawn guards against double-start, terminate cancels deterministically — no concurrent readers). Input is sanitized of OSC/DCS sequences before reaching the terminal process.

**AI Output Sanitization**: `AIOutputSanitizer` (wraps `TerminalInputSanitizer`) strips OSC clipboard/window-title/DCS sequences from AI-generated text before it's stored or displayed — applied in `TerminalBlock.init`, not just PTY writes.

**AI Streaming**: AIProviders implements a unified client interface over OpenRouter. Request/response models are in Models.swift. Streaming uses AsyncThrowingStream. TerminalDetailView routes AI-mode prompts (including literal `# prompt` input) through AIProviderManager.complete(), appending streamed tokens to both the active terminal block and ConversationStore. AIInspectorView is now a conversation panel with persistent user/assistant messages, streaming state, error display, image attachments, and fenced-code rendering/copy actions.

**Code Review Diff Surface**: InspectorView's Code Review tab is a two-column review surface backed by GitService. The sidebar lists changed files, loads per-file diffs, and exposes refresh/stage/discard/open actions. DiffView renders raw git diff text with file headers, hunk headers, line numbers, green additions, red deletions, and stub hunk action buttons. TerminalDetailView shows a git diff chip above the input when GitService has uncommitted changes; tapping it opens the inspector on the Code Review tab.

**Input Autocomplete**: InputEditorView uses an AppKit-backed CompletionTextField for macOS 13-safe key handling. CompletionStore owns common command, git subcommand, filesystem path, and persisted command-history suggestions. CompletionDropdownView renders the picker. Preserve Enter submit, Tab completion, Escape dismissal, Up/Down selection, model picker, image controls, and AI-mode behavior.

### Testing

Tests are in `Tests/WarpCLITests` (core) and `Tests/WarpCloneTests` (UI). Focus areas:
- PermissionGateTests: sandbox escapes, risk classification edge cases
- MCPRegistryTests: config parsing correctness
- GitReviewServiceTests: prompt templating
- IntegrationTests: app startup, terminal I/O

## Key Files & Symbols

| File | Purpose |
|------|---------|
| PermissionGate.swift | Central enforcement for tool/command safety, audit logging |
| MCPRegistry.swift | Parses claude_settings.json and settings.toml, discovers MCP servers |
| AIProviders.swift | OpenRouter client + request streaming |
| ConversationStore.swift | App-wide AI chat history and active streaming task state |
| AIInspectorView.swift | AI conversation panel, composer, streaming indicator, code block rendering |
| PTYSession.swift | PTY lifecycle, session restore, sequence sanitization |
| TerminalPrimitives.swift | ANSI codes, terminal sizing, raw mode |
| TerminalDetailView.swift | Terminal panes, input editor, AI streaming submission, git diff chip |
| CompletionStore.swift | Command/git/path/history suggestion state |
| CompletionDropdownView.swift | Autocomplete popup UI |
| InputEditorView.swift | Completion-aware terminal input and toolbelt |
| GitService.swift | Git branch/status/diff loading and diff summary state |
| InspectorView.swift | AI/MCP/Code Review inspector shell and git diff review surface |
| DiffView.swift | Raw git diff renderer with line numbers, hunk headers, and colored changes |
| GitReviewService.swift | Review prompt generation from git context |
| PermissionApprovalView.swift | Reusable SwiftUI approval sheet (Allow Once/Deny/Edit/Always Allow) |

## Security Guardrails

- **Risk Classification**: `ToolRisk` cases (`readOnly`, `write`, `destructive`, `network`, `credential`, `unknown`). `.ask` mode requires approval for all of them; `allowRead`/`allowWrite` auto-allow within scope only.
- **Permanent Command Blocklist**: `rm -rf /`, `rm -rf ~`, `$HOME`/`${HOME}` destructive variants, `curl | sh` denied under every mode, including `allowAll`. Less-absolute destructive commands (`sudo`, `git push`, `chmod -R`, scoped `rm -rf <path>`) require approval instead.
- **MCP Approval Gate**: Discovered servers cannot `Process.run()` without an approved descriptor hash (persisted in `UserDefaults`). Unapproved Start clicks open `PermissionApprovalView`.
- **Sandbox Homes**: Each MCP server runs with restricted HOME, no inherited token/secret/api-key env vars.
- **PTY Single-Reader**: `spawn()` guards against double-start; `DispatchSourceRead` is canceled deterministically on terminate — never two readers on one fd.
- **AI Output Sanitization**: `AIOutputSanitizer.sanitize()` strips OSC/DCS sequences from AI-generated text before storage/display.
- **Audit Logging**: All permission decisions, MCP approve/deny/start/stop/failed-start events recorded to audit.jsonl.

See `AGENTS.md` for the non-negotiable rule list (same content, Codex-oriented). Keep both in sync.

## Common Tasks

**Add AI Provider**: Extend AIProviderClient protocol in AIProviders.swift, register in AIProviderManager.clients.

**Add Terminal Feature**: Extend Screen or BlockRenderer in TerminalPrimitives.swift for ANSI codes; update PTYSession for session lifecycle if needed.

**Add MCP Discovery**: MCPRegistryParser already handles claude_settings.json and settings.toml. Add parsing logic for new config formats here.

**Harden Permission Rule**: Update PermissionGate risk classification and decision logic. New rules go through `evaluateCommand()`. Add a paired allow/deny test in `SecurityGuardrailTests`.

## Subagents

Project-specific subagents in `.claude/agents/`:
- `codereviewer` — security/correctness diff review, flags PermissionGate/MCP/PTY/sanitizer regressions.
- `swift-uidesignreviewer` — SwiftUI layout, accessibility, macOS HIG, approval-UI clarity review.
- `codebase-doc-writer` — generates/refreshes architecture docs, verifies claims against source before writing.

**Note**: custom agents in `.claude/agents/` may not be registered in an already-running session (observed: `swift-uidesignreviewer` absent from `Agent` tool's available list mid-session despite the file existing). If a custom agent name fails with "not found," do not silently skip the review — either start a new session to re-register agents, or fall back to a manual review against that agent's spec file and say so explicitly in the response.

## Session Start

At the start of a new session (or after `/clear`), run the `mem-search` skill (or claude-mem's cross-session search) before reading project files, to recall prior decisions/rationale from past sessions on this repo. Use memory only for *why* something was done — always verify current code/config state directly rather than trusting memory for *what currently exists*, since memory can go stale.

## Dependencies

- swift-argument-parser (CLI argument parsing)
- Darwin/Foundation (PTY, ANSI, terminal control)
- SwiftUI (app UI)
- Keychain (credential storage, via Security framework)

## Recent UI Implementation Notes

- Code Review comments now stream through the selected AI provider into a terminal block. When the response looks like a unified diff, `InspectorView` replaces `git.selectedDiff` so the proposed diff can be reviewed in-place.
- Sidebar session rows support native drag reordering through `SessionStore.moveSession(from:to:)`; `VerticalTabRow` exposes a hover-only drag handle.
- Terminal blocks fade and slide in on first appearance. Inspector toggles are wrapped in animation, and the fallback inspector uses a trailing slide transition.
