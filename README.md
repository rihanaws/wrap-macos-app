# WarpClone

WarpClone is a Mac-native SwiftUI terminal workspace with command blocks, AI streaming, code review diffs, MCP inspection, and explicit security guardrails.

## Beta Release

Build a local release DMG with an ad-hoc signature:

```bash
./script/build_and_sign.sh
```

Build with a Developer ID certificate:

```bash
SIGNING_ID="Developer ID Application: Your Name (TEAMID)" ./script/build_and_sign.sh
```

Enable notarization after storing a notarytool keychain profile:

```bash
./script/notarize_setup.sh
APPLE_ID="you@example.com" APPLE_TEAM_ID="TEAMID" NOTARIZE=true ./script/build_and_sign.sh
```

Beta testing and release asset docs:

- [Beta testing guide](docs/BETA_TESTING.md)
- [Design assets](docs/DESIGN_ASSETS.md)
- [Privacy policy](PRIVACY_POLICY.md)

Generate icons and screenshots:

```bash
./script/generate_icons.sh path/to/icon_1024.png
./script/screenshot.sh
```

## GitHub Copilot OAuth

WarpClone can use GitHub Copilot as an AI provider through GitHub OAuth device flow. Configure a GitHub OAuth App client ID with one of these options:

```bash
WARPCLONE_GITHUB_CLIENT_ID="your-client-id" ./script/build_and_run.sh
GITHUB_OAUTH_CLIENT_ID="your-client-id" ./script/build_and_sign.sh
```

Then select `GitHub Copilot` in Settings and use the device-code sign-in flow. Tokens are stored in macOS Keychain under the WarpClone Copilot service.

WarpClone is a Mac-native SwiftUI terminal workspace built with SwiftPM. It includes a sidebar/detail/inspector app shell, real PTY-backed terminal panes, command blocks, themes, AI provider wiring, git review surfaces, MCP management, and a terminal-native `warp` CLI companion.

## Products

- `WarpClone` — macOS SwiftUI app.
- `warp` — Claude Code-style terminal CLI companion.
- `WarpCLICore` — testable CLI core library.

## macOS app

The app uses:

- `WindowGroup` for the main window and a dedicated `Settings` scene.
- `NavigationSplitView` with explicit sidebar selection.
- Terminal split panes, command blocks, command palette, 3-tab inspector, and Settings.
- Real PTY lifecycle, ANSI parsing, 21 themes, Keychain-backed BYOK credentials, git review, and MCP views.

Build and run:

```bash
swift build --product WarpClone
./script/build_and_run.sh --build-only
./script/build_and_run.sh
```

The generated app bundle is:

```bash
.build/debug/WarpClone.app
```

## CLI companion

Build:

```bash
swift build --product warp
```

Run locally:

```bash
swift run warp --help
swift run warp config --show
swift run warp config --provider openrouter --model openai/gpt-4o
swift run warp config --provider openrouter --api-key "$OPENROUTER_API_KEY"
swift run warp ask "Summarize the current repo"
swift run warp review --path .
swift run warp mcp list
swift run warp chat
```

Install from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/rihanaws/wrap-macos-app/main/install.sh | sh
```

Install from a local checkout:

```bash
WARPCLONE_REPO_URL="$(pwd)" WARPCLONE_INSTALL_DIR="$HOME/.local/bin" ./script/install_cli.sh
```

Release installer artifacts are expected to be named:

- `warp-macos-arm64.tar.gz`
- `warp-macos-x86_64.tar.gz`
- `warp-linux-x86_64.tar.gz`

The CLI stores non-secret configuration in `~/.warp/config.json`, session transcripts in `~/.warp/sessions`, and API keys in macOS Keychain.

## Security guardrails

WarpClone includes shared app/CLI guardrails for AI and MCP tool execution:

- Permission tiers and tool risk classification for read-only, write, destructive, network, credential, and unknown actions.
- Command sandbox validation that permanently blocks unsafe installer pipes such as `curl ... | sh` and requires approval for destructive shell patterns.
- Append-only JSONL audit logging at `~/.warp/audit.log` with `0600` permissions.
- MCP startup isolation with filtered secret-bearing environment variables and per-server homes under `~/.warp/mcp-sandbox/<server-id>/`.
- Terminal input sanitization that strips OSC/DCS control sequences while preserving normal ANSI color/style output.

## Verification

```bash
swift build --build-tests
swift build
swift build --product warp
./script/build_and_run.sh --build-only
```

`swift test` is expected to run the XCTest bundle in normal signed local environments. If macOS blocks the generated test bundle with “library load denied by system policy,” use `swift build --build-tests` as the non-executing compile validation and resolve local code-signing policy before running tests.

## Requirements

- macOS 13+
- Xcode command line tools / Swift 5.9+
- User-provided AI provider credentials for network AI calls

## License

MIT. See [LICENSE](LICENSE).
