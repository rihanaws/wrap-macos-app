# Implementation Changes

## Release Preparation

Added beta release infrastructure for local and Developer ID distribution:

- `script/build_and_sign.sh` builds `WarpClone.app`, signs it ad-hoc or with `SIGNING_ID`, optionally notarizes, and emits a DMG.
- `script/notarize_setup.sh` stores Apple notarization credentials in a keychain profile.
- `script/beta_invite.sh` generates beta invite copy.
- `script/generate_icons.sh` creates AppIcon asset variants from a 1024x1024 PNG.
- `script/screenshot.sh` captures the main app window for release screenshots.
- `Sources/WarpClone/Resources/Info.plist`, `Entitlements.plist`, and `Assets.xcassets` define app bundle metadata and release resources.
- `docs/BETA_TESTING.md`, `docs/DESIGN_ASSETS.md`, `PRIVACY_POLICY.md`, and `CHANGELOG.md` document beta distribution and marketing assets.

## GitHub Copilot OAuth

Added app-side GitHub Copilot OAuth integration:

- `Sources/WarpClone/CopilotOAuthClient.swift` implements GitHub OAuth device flow, token polling, and Copilot subscription checks.
- `Sources/WarpClone/CopilotTokenStore.swift` stores OAuth tokens in macOS Keychain.
- `Sources/WarpClone/CopilotAuthViewModel.swift` drives Settings sign-in/logout state and GitHub profile display.
- `Sources/WarpClone/CopilotAPIClient.swift` streams Copilot chat completions through the existing `AIProviderClient` contract.
- `Sources/WarpClone/AIProviderManager.swift` registers `.copilot` and skips API-key lookup for OAuth-backed Copilot requests.
- `Sources/WarpClone/SettingsView.swift` shows a GitHub Copilot auth card when the provider is selected.

Updated: 2026-06-24

This document summarizes the current uncommitted feature work in the WarpClone macOS app.

## AI Streaming and Conversation Panel

The AI path now streams real provider responses instead of appending a static placeholder.

### Files changed

- `Sources/WarpClone/ConversationStore.swift`
- `Sources/WarpClone/AIInspectorView.swift`
- `Sources/WarpClone/TerminalDetailView.swift`
- `Sources/WarpClone/Stores.swift`
- `Sources/WarpClone/ImageAttachmentManager.swift`
- `Sources/WarpClone/WarpCloneApp.swift`

### Behavior added

- Added `ConversationStore` as shared app state for persistent AI chat history.
- Wired AI-mode terminal input and literal `# prompt` input through `AIProviderManager.complete()`.
- Streamed AI chunks into both:
  - the running terminal block via `SessionStore.updateBlock(...)`
  - the AI Inspector conversation via `ConversationStore`
- Rebuilt the AI Inspector as a conversation panel with:
  - user and assistant message bubbles
  - streaming state
  - error display
  - prompt composer
  - stop button
  - image attachment thumbnails
  - fenced-code rendering with copy actions
- Added `ImageAttachmentManager.clear()` so image attachments can be cleared after AI submission.
- Injected the shared `ConversationStore` from `WarpCloneApp`.

## Code Review Diff Surface

The Code Review inspector tab now renders changed files and raw git diffs instead of showing only a branch label and placeholder text.

### Files changed

- `Sources/WarpClone/DiffView.swift`
- `Sources/WarpClone/InspectorView.swift`
- `Sources/WarpClone/GitService.swift`
- `Sources/WarpClone/TerminalDetailView.swift`
- `Sources/WarpClone/ContentView.swift`
- `Sources/WarpClone/WarpCloneApp.swift`

### Behavior added

- Added `DiffView`, a standalone SwiftUI raw git diff renderer.
- Parsed standard `git diff` output into:
  - file header rows
  - hunk header rows
  - line-numbered context rows
  - green addition rows
  - red deletion rows
  - no-newline marker rows
- Added stub hunk actions:
  - `Revert Hunk`
  - `Apply Hunk`
- Rebuilt `InspectorView` Code Review tab as:
  - left changed-file sidebar
  - right scrollable diff viewer
  - repository refresh state
  - loading indicator
  - selected file state
  - stage-all action
  - discard-all confirmation
  - open-in-editor action
  - submit-review placeholder alert
- Extended `GitService` with:
  - `isLoading`
  - `hasUncommittedChanges`
  - approximate `totalAdditions`
  - approximate `totalDeletions`
- Added a git diff chip above the terminal input when uncommitted changes exist.
- Added a notification route so tapping the chip opens the inspector and selects the Code Review tab.

## Documentation Updates

### Files changed

- `CLAUDE.md`
- `AGENTS.md`
- `docs/implementation-changes.md`

### Behavior documented

- Current AI streaming architecture.
- Current Code Review diff surface architecture.
- Key files involved in AI, terminal, git, and inspector flows.
- Future development touch points for AI conversation behavior and code review UI behavior.

## Verification

The code changes were verified before this documentation pass with:

```bash
swift build
swift test
git diff --check
```

All three commands passed.

Documentation-only edits should not affect Swift compilation, but the project should still be verified again before merging or committing.

## Missing Feature Completion Pass

Additional app features were implemented after the AI streaming and diff-surface work:

- Added native drag-and-drop session reordering in `SidebarView` with `SessionStore.moveSession(from:to:)`.
- Added a hover-only drag handle to `VerticalTabRow`.
- Wired Code Review comments to the selected AI provider. Submissions create a running terminal block, stream response chunks into it, clear comments on success, and replace `git.selectedDiff` when the AI response looks like a unified diff.
- Added terminal block entrance animation: new blocks fade in and slide up slightly.
- Animated inspector visibility changes and added a fallback slide-in transition for older macOS paths.

Verification for this pass:

```bash
swift build
swift test
```
