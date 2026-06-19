# AGENTS.md

Guidance for Codex (and other agentic CLIs) working in this repo. Mirrors `CLAUDE.md`; keep both in sync if architecture changes.

## Build & Test

```bash
swift build                              # build all targets
swift run WarpClone                      # run macOS app
swift run warp                           # run CLI companion
swift test                               # run all tests
swift test --filter PermissionGateTests  # run one test class
swift build -c release                   # release binary
script/install.sh                        # install CLI to $HOME/.local/bin
```

## Project Structure

- `Sources/WarpClone` — SwiftUI macOS terminal app (PTY, ANSI render, themes, MCP inspector, git review UI, AI inspector).
- `Sources/WarpCLI` — CLI companion (`ask`/`chat`/`agent`/`review`/`mcp`/`config` subcommands).
- `Sources/WarpCLICore` — shared library: `PermissionGate.swift` (risk classification, command sandbox, audit log), `MCPRegistry.swift`, `AIProviders.swift`, `GitReviewService.swift`, `TerminalPrimitives.swift`, `CLISessionStore.swift`/`CLIConfig.swift`/`CLIKeychainStore.swift`.
- `Tests/WarpCLITests`, `Tests/WarpCloneTests` — core and UI tests.

## Non-Negotiable Rules

1. **PermissionGate is the only enforcement point.** Every tool/command/network/credential action routes through `PermissionGate.evaluate` → `ToolDispatcher.dispatch`. Never bypass it with direct `Process.run()` or raw shell exec.
2. **`.ask` mode requires approval for everything, including read-only.** Only `allowRead`/`allowWrite` tiers auto-allow within their scope. Never weaken this without explicit user sign-off.
3. **Permanent blocklist commands deny under every mode, including `allowAll`** (e.g. `rm -rf /`, `rm -rf ~`, `$HOME`/`${HOME}` destructive variants, `curl | sh`). These checks run before the mode switch — keep them there.
4. **MCP servers require descriptor-hash approval before `Process.run()`.** Never start a discovered server without checking `hasApprovedDescriptor`. New approval/start UI paths must route through `PermissionApprovalView`, not a direct start call.
5. **PTY has exactly one reader.** `spawn()` must guard against double-start; use `DispatchSourceRead`, not a polling loop. Never add a second concurrent reader on the same fd.
6. **AI-generated text is sanitized before storage/display** via `AIOutputSanitizer` (wraps `TerminalInputSanitizer`). Any new code path that stores or renders AI output must call it — OSC clipboard/window-title/DCS sequences must never reach the terminal or persisted block state unsanitized.
7. **No secrets in MCP child environments.** Each server gets a restricted `HOME`; token/secret/api-key env vars are stripped at launch, not inherited.

## Common Tasks

- **Add AI provider**: extend `AIProviderClient` protocol in `AIProviders.swift`, register in `AIProviderManager.clients`.
- **Add terminal feature**: extend `Screen`/`BlockRenderer` in `TerminalPrimitives.swift`; update `PTYSession` lifecycle if needed.
- **Add MCP discovery format**: extend `MCPRegistryParser`; new servers still go through descriptor-hash approval.
- **Harden a permission rule**: edit `PermissionGate.evaluateCommand()` / `CommandSandbox` — add a test in `SecurityGuardrailTests` proving both the allow and deny side.

## Before Finishing Any Change

1. `swift build` and `swift test` must pass.
2. If you touched `PermissionGate.swift`, `MCPManager.swift`, or `PTYSession.swift`, run `swift test --filter SecurityGuardrailTests` and `swift test --filter PermissionGateTests` explicitly and confirm pass.
3. Never commit or push unless explicitly asked.
