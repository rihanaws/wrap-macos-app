# wrap-macos-app

WarpClone is a Mac-native SwiftUI terminal workspace built with SwiftPM. It combines real PTY-backed shell sessions, block-based terminal output, split panes, AI provider tooling, OpenRouter model discovery, MCP management, git diff review, and a premium macOS visual system.

## Highlights

- Native `WindowGroup` app with dedicated `Settings` scene.
- `NavigationSplitView` with premium vertical session tabs, detail pane, and inspector.
- Real pseudo-terminal sessions using `posix_openpt`, `fork`, `setsid`, `dup2`, and shell exec.
- ANSI parser with 16-color, 256-color, true-color, and text attribute support.
- Premium terminal block cards with status borders, metadata header, hover toolbar, and icon actions.
- AI toolbelt with model picker, auto-detection, voice, image, context, and file controls.
- OpenRouter/BYOK provider plumbing with Keychain-backed credentials.
- Cached OpenRouter model discovery and grouped model selection.
- 3-tab inspector for AI, Code Review, and MCP.
- 21 typed themes with block background colors.

## Build

```bash
swift test
swift build
./script/build_and_run.sh --build-only
./script/build_and_run.sh
```

The app bundle is generated at:

```bash
.build/debug/WarpClone.app
```

## Requirements

- macOS 13+
- Xcode command line tools
- Swift 5.9+

## Secrets

API keys are stored in macOS Keychain. Do not commit `.env` files, tokens, or generated build artifacts.

## License

MIT. See [LICENSE](LICENSE).
