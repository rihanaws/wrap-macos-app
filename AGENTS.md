# AGENTS.md

Guidance for Codex (and other agentic CLIs) working in this repo. Mirrors `CLAUDE.md`; keep both in sync if architecture changes.

## Release Prep

- `script/build_and_sign.sh` builds a release `.app`, signs it ad-hoc by default or with `SIGNING_ID`, optionally notarizes with `NOTARIZE=true`, and emits a DMG.
- `script/notarize_setup.sh` stores Apple notarization credentials in a local keychain profile. Never commit Apple IDs, app-specific passwords, team IDs tied to private accounts, or signing identities as secrets.
- `script/generate_icons.sh` creates macOS icon assets from a 1024x1024 PNG under `Sources/WarpClone/Resources/Assets.xcassets`.
- `script/screenshot.sh` captures release screenshots into `docs/screenshots`.
- Release docs live in `docs/BETA_TESTING.md`, `docs/DESIGN_ASSETS.md`, `PRIVACY_POLICY.md`, and `CHANGELOG.md`.
- App bundle resources live under `Sources/WarpClone/Resources`; keep `Package.swift` resource registration in sync when adding app metadata or assets.
- GitHub Copilot OAuth uses device flow. Configure the public OAuth client ID through `GitHubOAuthClientID` in the app bundle, `GITHUB_OAUTH_CLIENT_ID` during release bundling, or `WARPCLONE_GITHUB_CLIENT_ID` for local runs. Tokens live in Keychain via `CopilotTokenStore`; do not store Copilot OAuth tokens as provider API keys.

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

- `Sources/WarpClone` — SwiftUI macOS terminal app (PTY, ANSI render, themes, MCP inspector, git diff review UI, AI conversation inspector).
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

## Current UI Integration Notes

- **AI streaming path**: `TerminalDetailView.submitInput()` routes AI-mode input and literal `# prompt` input through `AIProviderManager.complete()`. Streamed chunks update both the running terminal block (`SessionStore.updateBlock`) and the shared `ConversationStore`. `AIInspectorView` is the persistent chat panel with user/assistant messages, streaming state, errors, image thumbnails, and fenced-code rendering.
- **Code review surface**: `InspectorView` Code Review tab is a two-column file list + diff viewer backed by `GitService`. `DiffView` parses raw git diff text into file headers, hunk headers, line-numbered context/add/delete rows, and stub hunk actions. `TerminalDetailView` shows a git diff chip above the input when `GitService.hasUncommittedChanges` is true; tapping it opens the inspector on Code Review.
- **Review feedback loop**: Code Review comments stream through the selected AI provider into a terminal block and update `git.selectedDiff` when the response looks like a unified diff.
- **Session tab ordering**: `SidebarView` supports native session reordering via `SessionStore.moveSession(from:to:)`; `VerticalTabRow` keeps the drag handle hover-only.
- **Input autocomplete**: `InputEditorView` uses an AppKit-backed `CompletionTextField` for macOS 13-safe keyboard handling. `CompletionStore` owns common command, git subcommand, filesystem path, and persisted command-history suggestions. `CompletionDropdownView` renders the picker.

## Common Tasks

- **Add AI provider**: extend `AIProviderClient` protocol in `AIProviders.swift`, register in `AIProviderManager.clients`.
- **Add terminal feature**: extend `Screen`/`BlockRenderer` in `TerminalPrimitives.swift`; update `PTYSession` lifecycle if needed.
- **Add AI conversation behavior**: update `ConversationStore.swift`, `AIInspectorView.swift`, and the AI branch of `TerminalDetailView.submitInput()` together so terminal blocks and chat history stay in sync.
- **Add code review UI behavior**: update `GitService.swift`, `InspectorView.swift`, and `DiffView.swift` together; keep `GitReviewService.swift` focused on CLI prompt generation.
- **Add input completion behavior**: update `CompletionStore.swift`, `CompletionDropdownView.swift`, and `InputEditorView.swift` together. Preserve Enter submit, Tab completion, Escape dismissal, Up/Down selection, model picker, image controls, and AI-mode behavior.
- **Add MCP discovery format**: extend `MCPRegistryParser`; new servers still go through descriptor-hash approval.
- **Harden a permission rule**: edit `PermissionGate.evaluateCommand()` / `CommandSandbox` — add a test in `SecurityGuardrailTests` proving both the allow and deny side.

## Before Finishing Any Change

1. `swift build` and `swift test` must pass.
2. If you touched `PermissionGate.swift`, `MCPManager.swift`, or `PTYSession.swift`, run `swift test --filter SecurityGuardrailTests` and `swift test --filter PermissionGateTests` explicitly and confirm pass.
3. Never commit or push unless explicitly asked.
