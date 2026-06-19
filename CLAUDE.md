# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
  - Git review surfaces (GitService.swift)
  - OpenRouter/BYOK AI provider integration (AIProviders.swift, AIInspectorView.swift)

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

**Permission Approval UI**: `PermissionApprovalView` (Sources/WarpClone) is the reusable SwiftUI sheet for any approval flow — Allow Once / Deny / Edit Command (when a command exists) / Always Allow (only for non-destructive, non-network risk). Used by MCP approval today; designed for future ToolDispatcher approval callbacks via `ToolApprovalHandler`.

**Terminal Hardening**: PTYSession uses a single `DispatchSourceRead` per session (spawn guards against double-start, terminate cancels deterministically — no concurrent readers). Input is sanitized of OSC/DCS sequences before reaching the terminal process.

**AI Output Sanitization**: `AIOutputSanitizer` (wraps `TerminalInputSanitizer`) strips OSC clipboard/window-title/DCS sequences from AI-generated text before it's stored or displayed — applied in `TerminalBlock.init`, not just PTY writes.

**AI Streaming**: AIProviders implements a unified client interface over OpenRouter. Request/response models are in Models.swift. Streaming uses AsyncThrowingStream.

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
| PTYSession.swift | PTY lifecycle, session restore, sequence sanitization |
| TerminalPrimitives.swift | ANSI codes, terminal sizing, raw mode |
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

## Dependencies

- swift-argument-parser (CLI argument parsing)
- Darwin/Foundation (PTY, ANSI, terminal control)
- SwiftUI (app UI)
- Keychain (credential storage, via Security framework)
