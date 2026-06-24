# Prompt: Release Prep — Beta Testing, Signing, Documentation, Marketing Assets

## Goal
Get WarpClone ready for public beta distribution. Implement four release-prep tasks: beta testing infrastructure, code signing + notarization automation, documentation (README + privacy policy), and app icon/marketing asset generation scripts.

## Deliverables

---

### Deliverable 1: Build & Distribution Scripts (Signing + Notarization + DMG)

Create `script/build_and_sign.sh` — a shell script that automates the entire macOS release build pipeline:

```bash
#!/bin/bash
set -euo pipefail

# Configuration
APP_NAME="WarpClone"
BUNDLE_ID="com.warpclone.app"
TEAM_ID=""        # User will fill this in
SIGNING_ID=""     # "Developer ID Application: ..." or leave empty for ad-hoc
NOTARIZE=false    # Set to true when Apple Developer ID is available
APPLE_ID=""       # Apple ID for notarization
APPLE_TEAM_ID=""  # Apple Team ID
KEYCHAIN_PROFILE="notarytool"  # For stored credentials

VERSION=$(git describe --tags --always --dirty)
BUILD_DIR=".build/release"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

echo "=== WarpClone Release Build ==="
echo "Version: ${VERSION}"

# 1. Clean build
swift package clean

# 2. Build release binary
swift build -c release

# 3. Find the built app
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: Built app not found at ${APP_PATH}"
    exit 1
fi

# 4. Code signing (if signing ID is configured)
if [ -n "${SIGNING_ID}" ]; then
    echo "=== Signing with ${SIGNING_ID} ==="
    codesign --force --options runtime --deep --sign "${SIGNING_ID}" \
        --entitlements Resources/Entitlements.plist \
        "${APP_PATH}"
    codesign -dv --verbose=4 "${APP_PATH}"
else
    echo "=== Ad-hoc signing (no Developer ID) ==="
    codesign --force --deep --sign - "${APP_PATH}"
fi

# 5. Verify signature
codesign --verify --verbose "${APP_PATH}"

# 6. Notarization (if configured)
if [ "${NOTARIZE}" = true ] && [ -n "${APPLE_ID}" ]; then
    echo "=== Notarizing ==="
    
    # Create zip for notarization
    ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
    ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
    
    # Submit for notarization
    xcrun notarytool submit "${ZIP_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --keychain-profile "${KEYCHAIN_PROFILE}" \
        --wait
    
    # Staple the notarization ticket
    xcrun stapler staple "${APP_PATH}"
    
    # Verify stapling
    xcrun stapler validate "${APP_PATH}"
    
    rm "${ZIP_PATH}"
fi

# 7. Build DMG
echo "=== Building DMG ==="
DMG_TEMP="${BUILD_DIR}/dmg_temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Copy app
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create symlink to Applications
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${BUILD_DIR}/${DMG_NAME}"

# Sign DMG if signing ID available
if [ -n "${SIGNING_ID}" ]; then
    codesign --sign "${SIGNING_ID}" "${BUILD_DIR}/${DMG_NAME}"
fi

rm -rf "${DMG_TEMP}"

echo "=== Build Complete ==="
echo "Output: ${BUILD_DIR}/${DMG_NAME}"
if [ -n "${SIGNING_ID}" ]; then
    echo "Signed: Yes"
else
    echo "Signed: Ad-hoc (set SIGNING_ID for Developer ID)"
fi
if [ "${NOTARIZE}" = true ]; then
    echo "Notarized: Yes"
else
    echo "Notarized: No (set NOTARIZE=true and APPLE_ID for notarization)"
fi
```

Also create `Resources/Entitlements.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Allow PTY/shell execution -->
    <key>com.apple.security.automation.apple-events</key>
    <false/>
    
    <!-- Network access for AI providers -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Allow reading user-selected files (MCP configs, etc.) -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    
    <!-- Allow writing user-selected files (file edits) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Allow PTY access -->
    <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
    <array>
        <string>/.warp/</string>
    </array>
</dict>
</plist>
```

Create `script/notarize_setup.sh` to help the user set up notarization credentials:

```bash
#!/bin/bash
# One-time setup for notarization credentials
set -euo pipefail

echo "=== Notarization Setup ==="
echo "This stores your App-Specific Password in the Keychain."
echo ""
read -p "Apple ID (email): " APPLE_ID
read -p "Apple Team ID (e.g., ABCDE12345): " TEAM_ID
read -s -p "App-Specific Password (from appleid.apple.com): " APP_PASSWORD
echo ""

xcrun notarytool store-credentials \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${APP_PASSWORD}" \
    notarytool

echo "Credentials stored in Keychain as 'notarytool'"
echo "Update script/build_and_sign.sh with:"
echo "  APPLE_ID=${APPLE_ID}"
echo "  APPLE_TEAM_ID=${TEAM_ID}"
```

Create `Resources/Info.plist` (if not already present):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>WarpClone</string>
    <key>CFBundleIdentifier</key>
    <string>com.warpclone.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>WarpClone</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 WarpClone Contributors</string>
    
    <!-- URL scheme for OAuth callbacks -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.warpclone.auth</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>warpclone</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Update `Package.swift` to include resources:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WarpClone",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "WarpClone", targets: ["WarpClone"]),
        .executable(name: "warp", targets: ["WarpCLI"]),
        .library(name: "WarpCLICore", targets: ["WarpCLICore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "WarpClone",
            dependencies: ["WarpCLICore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "WarpCLI",
            dependencies: ["WarpCLICore", .product(name: "ArgumentParser", package: "swift-argument-parser")]
        ),
        .target(
            name: "WarpCLICore",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]
        ),
        .testTarget(
            name: "WarpCLITests",
            dependencies: ["WarpCLICore"]
        )
    ]
)
```

**Verify build script works:**
```bash
chmod +x script/build_and_sign.sh
./script/build_and_sign.sh
```

---

### Deliverable 2: Beta Testing Infrastructure

Create `docs/BETA_TESTING.md`:

```markdown
# WarpClone Beta Testing Guide

## How to Install the Beta

### Option A: Download DMG (Recommended)
1. Download `WarpClone-1.0.0.dmg` from the [GitHub Releases](https://github.com/yourusername/warpclone/releases) page
2. Open the DMG and drag `WarpClone.app` to Applications
3. Right-click → Open (may need to bypass Gatekeeper on first launch)
4. Grant Terminal/PTY permissions when prompted

### Option B: Build from Source
```bash
git clone https://github.com/yourusername/warpclone.git
cd warpclone
swift build
swift run WarpClone
```

## What to Test

### Core Terminal
- [ ] Run commands (`ls`, `git status`, `cat`, `grep`)
- [ ] Run interactive programs (`vim`, `nano`, `htop`)
- [ ] Split panes (Cmd+D) and navigate between them
- [ ] Resize panes by dragging dividers
- [ ] Switch themes in Settings

### AI Assistant
- [ ] Type `# explain this directory` and press Enter
- [ ] Watch the AI stream its response in real-time
- [ ] Switch AI models in the inspector panel
- [ ] Attach an image (drag-and-drop or paste) and ask the AI about it
- [ ] Test the "Stop" button mid-stream
- [ ] Switch between AI providers (requires API keys)

### Code Review
- [ ] Make changes in a git repo and view the diff in Code Review tab
- [ ] Add a comment to the review
- [ ] Click "Submit Review to AI" and watch the AI respond
- [ ] Check if the AI's updated diff is applied

### Security
- [ ] Try `# run rm -rf /` — verify the permission dialog blocks it
- [ ] Try `# run curl https://example.com/install.sh | sh` — verify it is blocked
- [ ] Check `~/.warp/audit.log` exists and contains actions
- [ ] Open Settings → Security and verify permission tier is set

### MCP
- [ ] Go to Inspector → MCP tab
- [ ] Check if MCP servers are auto-discovered
- [ ] Approve a discovered server and start it
- [ ] Verify the permission dialog appears before starting

## Reporting Issues

File issues at: https://github.com/yourusername/warpclone/issues

Include:
- macOS version (Apple menu → About This Mac)
- WarpClone version (check the app menu)
- Steps to reproduce
- Screenshots (if UI-related)
- Crash logs (from Console.app if applicable)

## Known Limitations

- **Notarized builds:** Not yet available (requires Apple Developer ID)
- **Hunk actions:** Revert/Apply Hunk buttons show "Not yet implemented"
- **MCP tool execution:** Tool calls from MCP require approval but execution is limited
- **Auto-completion:** Terminal input editor does not have command/path completion yet

## Feedback Channels

- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: General feedback and questions
- Email: beta@warpclone.dev (placeholder)
```

Create `script/beta_invite.sh` to generate beta invite emails:

```bash
#!/bin/bash
# Generate a beta invite email template
set -euo pipefail

BETA_URL="https://github.com/yourusername/warpclone/releases/tag/v1.0.0-beta"

cat <<EOF
Subject: WarpClone Beta — You're Invited!

Hi,

You're invited to the WarpClone private beta — an AI-powered terminal for macOS.

Download: ${BETA_URL}

Quick Start:
1. Download the DMG
2. Drag WarpClone to Applications
3. Open and grant permissions
4. Type "# explain this directory" to try the AI

Test Focus: Terminal commands, AI streaming, code review, security guardrails

Report issues: https://github.com/yourusername/warpclone/issues

Thanks for testing!

— The WarpClone Team
EOF
```

---

### Deliverable 3: Documentation (README + Privacy Policy + CHANGELOG)

#### 3.1 Rewrite `README.md`

Replace the existing README with this comprehensive version:

```markdown
# WarpClone

> AI-powered terminal for macOS. Every command is a visual block. The AI streams its thoughts in real-time.

[![Build](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/yourusername/warpclone)
[![Tests](https://img.shields.io/badge/tests-23%2F23-brightgreen)](https://github.com/yourusername/warpclone)
[![Platform](https://img.shields.io/badge/platform-macOS%2013+-blue)](https://github.com/yourusername/warpclone)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[Download Latest Release](https://github.com/yourusername/warpclone/releases) · [Report Issue](https://github.com/yourusername/warpclone/issues) · [Documentation](docs/)

![Screenshot](docs/screenshot.png)

## Features

- **Real PTY Terminal** — Full zsh/bash shell with ANSI color support, interactive programs (vim, htop, nano)
- **AI Streaming** — Watch the AI think in real-time, token by token. Supports OpenRouter, OpenAI, Anthropic, Google Gemini.
- **Visual Blocks** — Every command and its output is grouped into a discrete visual block with status colors, shadows, and hover actions.
- **Code Review** — View git diffs with syntax highlighting, add inline comments, and submit reviews to the AI for automated fixes.
- **Security Guardrails** — Permission gate for every tool call, command sandbox (blocks `rm -rf /`, `curl | sh`), JSONL audit logging, MCP sandboxing.
- **MCP Integration** — Auto-discover MCP servers, run with restricted environment, human-in-the-loop approval.
- **21 Themes** — From Dracula to Solarized to Catppuccin, with system material support.
- **Split Panes** — Horizontal and vertical splits with keyboard navigation.
- **CLI Companion** — `warp` command-line tool for quick AI queries from any terminal.
- **Drag & Drop Tabs** — Reorder sessions by dragging.
- **Image Attachments** — Attach images to AI prompts (multimodal support).

## Install

### Download (Recommended)

Download the latest DMG from [Releases](https://github.com/yourusername/warpclone/releases).

```bash
# Or install with Homebrew (when available)
brew install --cask warpclone
```

### Build from Source

Requirements: macOS 13+, Xcode 15+, Swift 5.9+

```bash
git clone https://github.com/yourusername/warpclone.git
cd warpclone
swift build
swift run WarpClone
```

## Quick Start

1. **Open WarpClone** — A zsh terminal session starts automatically.
2. **Ask the AI** — Type `# explain this directory` and press Enter. Watch the AI stream its response.
3. **Review Code** — Switch to the Code Review tab to see uncommitted git changes. Add comments and submit to the AI.
4. **Check Security** — Open Settings → Security to see your permission tier and audit log.

## Security Model

WarpClone runs with a strict security-first approach:

| Feature | Description |
|---------|-------------|
| **Permission Gate** | 4-tier system: Ask / Allow Read / Allow Write / Allow All. Default is "Ask" — every tool call requires approval. |
| **Command Sandbox** | Permanently blocks `rm -rf /`, `curl \| sh`, fork bombs. Destructive commands require explicit approval. |
| **Audit Logging** | Every action logged to `~/.warp/audit.log` in JSONL format. |
| **MCP Security** | Discovered servers require SHA256 approval. Restricted HOME, no inherited secrets. |
| **Input Sanitization** | AI responses are sanitized of OSC/DCS escape sequences before display. |

Read the full security documentation: [SECURITY.md](SECURITY.md)

## Configuration

### AI Provider Setup

1. Open Settings → AI
2. Choose a provider: OpenRouter (default), OpenAI, Anthropic, or Google Gemini
3. Enter your API key (stored in macOS Keychain)
4. Click "Load Models" to fetch available models

### MCP Servers

WarpClone auto-discovers MCP configs from:
- `~/.claude.json`
- `.cursorrules/settings.toml`
- `.warp/.mcp.json`

Discovered servers require explicit approval before starting.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New session |
| `Cmd+D` | Split pane right |
| `Cmd+Shift+D` | Split pane down |
| `Cmd+W` | Close session |
| `Cmd+Shift+B` | Toggle sidebar |
| `Cmd+Option+I` | Toggle inspector |
| `Cmd+Shift+K` | Clear session |
| `Cmd+Shift+P` | Command palette |
| `#` | Toggle AI mode in input |
| `Shift+Enter` | New line in input |
| `Enter` | Execute command / send AI prompt |

## CLI Companion

The `warp` CLI is installed alongside the app:

```bash
# Ask the AI
warp ask "explain this function"

# Review git changes
warp review

# List MCP servers
warp mcp list

# Configure settings
warp config --theme dark
```

## Development

```bash
# Build
swift build

# Run app
swift run WarpClone

# Run CLI
swift run warp

# Tests
swift test

# Build release + sign
./script/build_and_sign.sh
```

## Architecture

```
WarpClone/
├── WarpCloneApp.swift          # App entry point
├── ContentView.swift           # NavigationSplitView root
├── Views/
│   ├── TerminalBlockView.swift  # Visual command blocks
│   ├── AIInspectorView.swift    # Chat panel
│   ├── InspectorView.swift      # Code review + MCP
│   ├── SidebarView.swift        # Session tabs
│   └── DiffView.swift           # Git diff rendering
├── Services/
│   ├── PTYSession.swift         # Real PTY shell
│   ├── AIProviderManager.swift # AI streaming
│   ├── GitService.swift         # Git operations
│   ├── MCPManager.swift         # MCP server management
│   └── PermissionGate.swift    # Security enforcement
└── Security/
    ├── AuditLogger.swift       # Action logging
    └── CommandSandbox.swift    # Command validation
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests: `swift test`
5. Submit a pull request

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License. See [LICENSE](LICENSE).

## Acknowledgments

- Inspired by [Warp](https://www.warp.dev/) and [iTerm2](https://iterm2.com/)
- AI streaming via [OpenRouter](https://openrouter.ai/)
- MCP protocol by [Anthropic](https://www.anthropic.com/)
- Swift Argument Parser by Apple
```

#### 3.2 Create `PRIVACY_POLICY.md`

```markdown
# Privacy Policy

**Effective Date:** 2026-06-24

**WarpClone** is an open-source terminal application. This policy explains what data we collect, how we use it, and your rights.

## Data We Collect

### 1. Terminal Data
- **Command history** and **output** are stored locally on your device only.
- We do not upload your terminal history to any server.

### 2. AI Provider Data
- When you use AI features, your prompts are sent to the AI provider you configure (OpenRouter, OpenAI, Anthropic, or Google).
- We do not intercept, store, or analyze your AI prompts.
- Image attachments are sent to the AI provider's API.

### 3. Audit Logs
- All tool actions (shell commands, file writes, MCP calls) are logged to `~/.warp/audit.log` on your local device.
- These logs are for your own security review and are never uploaded.

### 4. MCP Server Data
- MCP servers may access files and tools on your system. Each server runs in a sandboxed environment with restricted permissions.
- You must explicitly approve each discovered MCP server before it can run.

### 5. Telemetry (Optional)
- WarpClone does not collect telemetry by default.
- If you opt in, we may collect anonymous crash reports to improve stability.
- No personal data or command history is included in crash reports.

## Data We Do NOT Collect

- We do not track your usage patterns.
- We do not sell your data.
- We do not share your data with third parties (except the AI provider you choose).

## Your Rights

- **Access:** All your data is stored locally. You can access it at `~/.warp/`.
- **Deletion:** You can delete `~/.warp/` at any time to remove all local data.
- **API Keys:** Stored in macOS Keychain. You can delete them in Settings → AI.

## Changes to This Policy

We may update this policy. Changes will be posted on GitHub.

## Contact

For privacy questions: privacy@warpclone.dev (placeholder)
```

#### 3.3 Update `CHANGELOG.md`

```markdown
# Changelog

## 1.0.0-beta — 2026-06-24

### Added
- AI streaming with real-time token display in terminal blocks and AI inspector
- Conversation panel with user/assistant message bubbles, code blocks, and streaming indicator
- Code review diff surface with file sidebar, syntax highlighting, and hunk actions
- Agent feedback loop — submit review comments to AI and receive updated diffs
- Drag-and-drop tab reordering in sidebar
- Terminal block entrance animations (fade + slide)
- Inspector slide-in animation
- Git branch and status display in sidebar rows
- Image attachment pipeline (pick, paste, resize, send to AI)
- Security guardrails: Permission Gate, Command Sandbox, Audit Logger, Input Sanitizer, MCP Security
- 21 themes with system material support
- CLI companion (`warp` command) with `ask`, `review`, `mcp`, `config` subcommands
- MCP server auto-discovery and approval workflow
- Settings panel with Appearance, Terminal, AI, MCP, and Security sections
- Command palette (Cmd+Shift+P)
- Split panes with keyboard navigation

### Security
- Permission Gate with 4-tier approval system (Ask / Allow Read / Allow Write / Allow All)
- Command Sandbox blocks `rm -rf /`, `curl | sh`, fork bombs permanently
- JSONL audit logging to `~/.warp/audit.log`
- MCP servers require SHA256 descriptor-hash approval before starting
- AI responses sanitized of OSC/DCS escape sequences
- API keys stored in macOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

### Known Issues
- Hunk Revert/Apply buttons show "Not yet implemented" alert
- Notarization not yet configured (requires Apple Developer ID)
- Auto-completion not yet implemented in terminal input editor
- Beta builds are ad-hoc signed
```

---

### Deliverable 4: App Icon & Marketing Assets

#### 4.1 Create Icon Asset Generation Script

Create `script/generate_icons.sh` — this generates all required icon sizes from a base 1024×1024 PNG:

```bash
#!/bin/bash
set -euo pipefail

# Usage: ./script/generate_icons.sh path/to/icon_1024.png

BASE_ICON="${1:-}"
if [ -z "${BASE_ICON}" ] || [ ! -f "${BASE_ICON}" ]; then
    echo "Usage: ./script/generate_icons.sh <path_to_1024x1024_icon.png>"
    echo ""
    echo "Create a 1024x1024 PNG icon first."
    echo "Recommended: design in Figma/Sketch, export as PNG."
    exit 1
fi

OUTPUT_DIR="Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "${OUTPUT_DIR}"

# macOS icon sizes
SIZES=(
    "16 1"
    "32 1"
    "64 1"
    "128 1"
    "256 1"
    "512 1"
    "512 2"
)

for spec in "${SIZES[@]}"; do
    size=$(echo "$spec" | awk '{print $1}')
    scale=$(echo "$spec" | awk '{print $2}')
    px=$((size * scale))
    
    if [ "$scale" = "2" ]; then
        filename="icon_${size}@2x.png"
        idiom="mac"
        size_str="${size}x${size}"
    else
        filename="icon_${size}.png"
        idiom="mac"
        size_str="${size}x${size}"
    fi
    
    sips -z "${px}" "${px}" "${BASE_ICON}" --out "${OUTPUT_DIR}/${filename}"
    echo "Generated ${filename} (${px}x${px})"
done

# Generate Contents.json
cat > "${OUTPUT_DIR}/Contents.json" <<EOF
{
  "images": [
    {
      "filename": "icon_16.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "16x16"
    },
    {
      "filename": "icon_16@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "16x16"
    },
    {
      "filename": "icon_32.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "32x32"
    },
    {
      "filename": "icon_32@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "32x32"
    },
    {
      "filename": "icon_128.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "128x128"
    },
    {
      "filename": "icon_128@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "128x128"
    },
    {
      "filename": "icon_256.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "256x256"
    },
    {
      "filename": "icon_256@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "256x256"
    },
    {
      "filename": "icon_512.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "512x512"
    },
    {
      "filename": "icon_512@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "512x512"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
EOF

echo ""
echo "Icon asset catalog generated in ${OUTPUT_DIR}"
echo "Add ${OUTPUT_DIR} to your Xcode project or Swift Package resources."
```

#### 4.2 Create Screenshot Automation Script

Create `script/screenshot.sh` for taking marketing screenshots:

```bash
#!/bin/bash
set -euo pipefail

# Usage: ./script/screenshot.sh
# Takes screenshots of the app for marketing

APP_NAME="WarpClone"
OUTPUT_DIR="docs/screenshots"
mkdir -p "${OUTPUT_DIR}"

echo "=== Taking screenshots of ${APP_NAME} ==="

# Launch the app in background
swift run WarpClone &
APP_PID=$!
sleep 3

# Find the window ID
WINDOW_ID=$(osascript -e "tell application \"System Events\" to tell process \"${APP_NAME}\" to return id of window 1" 2>/dev/null || echo "")

if [ -z "${WINDOW_ID}" ]; then
    echo "WARNING: Could not find window ID. Manual screenshots may be needed."
    kill $APP_PID 2>/dev/null || true
    exit 1
fi

# Take screenshot via screencapture
echo "Taking main window screenshot..."
screencapture -l "${WINDOW_ID}" "${OUTPUT_DIR}/main_window.png"

# Take screenshot of sidebar only
echo "Taking sidebar screenshot..."
# This would require cropping — for now, just capture the full window

# Take screenshot of AI inspector
echo "Taking inspector screenshot..."
# Would need to toggle inspector first via AppleScript

kill $APP_PID 2>/dev/null || true

echo "Screenshots saved to ${OUTPUT_DIR}/"
```

#### 4.3 Create Marketing Asset Template (Figma/Sketch Guide)

Create `docs/DESIGN_ASSETS.md`:

```markdown
# Design Assets Guide

## App Icon

### Specifications
- **Format:** PNG (1024×1024 base), exported to multiple sizes via `script/generate_icons.sh`
- **Style:** macOS Big Sur+ rounded rectangle (squircle)
- **Colors:** Use the app's accent color (blue/purple gradient recommended)
- **Icon:** A terminal cursor + sparkle symbol (representing AI)
- **Background:** Subtle gradient or solid dark color

### Required Sizes
| Size | Scale | Filename | Usage |
|------|-------|----------|-------|
| 16×16 | 1x, 2x | `icon_16.png`, `icon_16@2x.png` | Menu bar, Finder list |
| 32×32 | 1x, 2x | `icon_32.png`, `icon_32@2x.png` | Finder icons |
| 128×128 | 1x, 2x | `icon_128.png`, `icon_128@2x.png` | Finder, Dock |
| 256×256 | 1x, 2x | `icon_256.png`, `icon_256@2x.png` | About box |
| 512×512 | 1x, 2x | `icon_512.png`, `icon_512@2x.png` | App Store, Launchpad |

## Marketing Screenshots

### Screenshot 1: Main Terminal Window
- Show multiple blocks with different status colors
- Show the AI mode toggle in the input area
- Use a dark theme (Dracula or Tokyo Night)
- Clean terminal with a few commands: `ls`, `git status`, `# explain`

### Screenshot 2: AI Inspector Panel
- Show the chat history with user and assistant messages
- Show a code block with syntax highlighting
- Show the model picker and provider status
- Use a split layout: terminal on left, AI panel on right

### Screenshot 3: Code Review Diff
- Show a git diff with green additions and red deletions
- Show the file sidebar on the left
- Show a comment in the review panel
- Use a light theme for contrast

### Screenshot 4: Settings / Security
- Show the Settings window with the Security tab selected
- Show the Permission Gate tier selector
- Show the audit log section
- Use system materials for visual depth

## App Store Description (Template)

```
WarpClone — AI Terminal for macOS

A terminal that thinks with you. Every command is a visual block. The AI streams its thoughts in real-time.

FEATURES:
• Real PTY shell with ANSI colors and interactive programs
• AI-powered assistant with streaming responses
• Visual command blocks with status indicators
• Code review with inline diff and AI feedback
• 21 themes including Dracula, Solarized, Tokyo Night
• Split panes for multitasking
• Security-first: permission gates, sandboxed commands, audit logs
• MCP server integration for extensible tools
• CLI companion for quick AI queries

Perfect for developers who want AI integrated into their terminal workflow.

Requires macOS 13+ and an AI provider API key (OpenRouter recommended).
```
```

---

## Files to Create / Modify

| File | Action | Purpose |
|---|---|---|
| `script/build_and_sign.sh` | **NEW** | Release build + signing + notarization + DMG |
| `script/notarize_setup.sh` | **NEW** | One-time notarization credential setup |
| `script/beta_invite.sh` | **NEW** | Generate beta invite email template |
| `script/generate_icons.sh` | **NEW** | Generate icon sizes from base PNG |
| `script/screenshot.sh` | **NEW** | Automated marketing screenshots |
| `Resources/Entitlements.plist` | **NEW** | App sandbox entitlements |
| `Resources/Info.plist` | **NEW** | App bundle metadata |
| `Resources/Assets.xcassets/` | **NEW** | App icon asset catalog (generated by script) |
| `README.md` | **REWRITE** | Comprehensive project documentation |
| `PRIVACY_POLICY.md` | **NEW** | Privacy policy |
| `CHANGELOG.md` | **UPDATE** | Version history with beta notes |
| `docs/BETA_TESTING.md` | **NEW** | Beta testing guide for users |
| `docs/DESIGN_ASSETS.md` | **NEW** | Icon + marketing asset specifications |
| `Package.swift` | **MODIFY** | Add resources target configuration |
| `CLAUDE.md` | **UPDATE** | Document build scripts |

## Testing Requirements

1. `swift build` still passes
2. `swift test` still passes all 23 tests
3. `script/build_and_sign.sh` runs without errors (ad-hoc signing is OK if no Developer ID)
4. `script/generate_icons.sh` generates all icon sizes when given a 1024×1024 base PNG
5. README renders correctly on GitHub (check with GitHub preview or Markdown viewer)

## Build Verification

```bash
cd /Users/rihan/Documents/MAC-OS-TERMINAL
swift build
swift test

# Test build script (ad-hoc signing)
chmod +x script/build_and_sign.sh
./script/build_and_sign.sh

# Test icon generation (create a dummy 1024x1024 PNG first)
# sips -s format png -z 1024 1024 /System/Library/CoreServices/DefaultDesktop.heic icon_1024.png
# ./script/generate_icons.sh icon_1024.png
```

## Notes

- The build script defaults to **ad-hoc signing** (`codesign --sign -`) which is fine for local testing and beta distribution among friends. For public distribution, the user needs an **Apple Developer ID** ($99/year) and must set `SIGNING_ID`, `NOTARIZE=true`, `APPLE_ID`, and `APPLE_TEAM_ID`.
- The `Info.plist` must be bundled with the app. In SwiftPM, this is done via the `resources` target configuration in `Package.swift`.
- The `Entitlements.plist` is referenced during code signing. Adjust entitlements as needed based on the app's actual capabilities (PTY access, network, file access).
- For the app icon, the user needs to create a 1024×1024 PNG first. The script handles the rest. Suggest a design: a dark squircle with a terminal cursor (`>_`) and a sparkle overlay.
- Marketing screenshots are best taken manually with the app running. The `screenshot.sh` script is a starting point but may need refinement.
- Make reasonable assumptions and complete the implementation. Don't stop for clarifications unless truly blocked.
- All shell scripts must be executable (`chmod +x`).
- All markdown files must be valid and render correctly.
- The README should be comprehensive enough that someone could clone the repo and run the app without asking questions.
