# Prompt: Build the Code Review Diff Surface

## Goal
Transform the Inspector's Code Review tab from a single branch label into a fully functional diff review surface: a file list sidebar showing changed files, a scrollable diff view with syntax highlighting (green additions, red deletions), hunk-level actions, and a git diff chip in the terminal input area.

## Current State (What's Broken)

### 1. `InspectorView.codeReviewPanel` (Sources/WarpClone/InspectorView.swift)
Currently shows only:
- Branch name with a refresh button
- Error text (if any)
- A comment box that's just a stub

There is NO diff rendering, NO file list, NO line numbers, NO hunk actions.

### 2. `GitService` (Sources/WarpClone/GitService.swift)
Already provides everything you need:
- `changedFiles: [GitChangedFile]` — array of changed files with `path`, `status` (M/A/D/R), `staged` bool
- `selectedDiff: String` — raw git diff output for the selected file
- `currentBranch: String` — current branch name
- `refresh(repositoryPath:)` — refreshes branch + status
- `loadDiff(repositoryPath:filePath:staged:)` — loads diff for a specific file into `selectedDiff`
- `parseStatus(_:)` — parses `git status --porcelain=v1` output

### 3. `TerminalDetailView` Input Area (Sources/WarpClone/TerminalDetailView.swift)
The `InputEditorView` sits at the bottom of the terminal. No git diff chip exists above it.

## Deliverables

### Deliverable 1: DiffView (New Component)

Create `Sources/WarpClone/DiffView.swift` as a standalone view that renders a raw git diff string:

```swift
import SwiftUI

struct DiffView: View {
    let diffText: String
    
    var body: some View {
        // Render the diff with line numbers and colored lines
    }
}
```

**Parsing logic:** Git diff output has this structure:
```
diff --git a/src/main.swift b/src/main.swift
index abc1234..def5678 100644
--- a/src/main.swift
+++ b/src/main.swift
@@ -10,7 +10,7 @@ import Foundation
     let oldValue = 42
-    let newValue = 43
+    let newValue = 44
     print(newValue)
```

For each diff hunk:
1. Parse the `@@ -oldStart,oldCount +newStart,newCount @@` header
2. Show it as a label row (e.g., "@@ -10,7 +10,7 @@")
3. For each line:
   - `+` (addition) → green background, `+` prefix in green
   - `-` (deletion) → red background, `-` prefix in red
   - ` ` (context) → default background, no prefix
   - `\` (no newline) → show as small gray text

**UI layout per line:**
```swift
HStack(spacing: 0) {
    // Old line number (right-aligned, secondary, 40pt width, monospaced)
    Text(oldLineNumber)
        .frame(width: 40, alignment: .trailing)
    
    // New line number (right-aligned, secondary, 40pt width, monospaced)
    Text(newLineNumber)
        .frame(width: 40, alignment: .trailing)
    
    // The line content with prefix (+/-)
    Text(lineContent)
        .textSelection(.enabled)
}
.font(.system(size: 11, design: .monospaced))
.background(lineBackgroundColor) // green for +, red for -, default for context
```

**Hunk header row:** Show the `@@` header with a slightly different background (e.g., `.secondary.opacity(0.1)`), monospaced, smaller font.

**File header row:** Show the `diff --git a/... b/...` and `---`/`+++` lines as a subtle header with the file path.

**Performance:** Use `LazyVStack` for large diffs. Don't parse the entire diff into a massive array eagerly — parse line by line or use a simple state machine.

### Deliverable 2: Rewrite `InspectorView.codeReviewPanel`

Replace the current `codeReviewPanel` in `InspectorView.swift` with a two-column layout:

```swift
private var codeReviewPanel: some View {
    HStack(spacing: 0) {
        // Left: File sidebar
        fileSidebar
            .frame(width: 180)
        
        // Right: Diff view
        diffContent
    }
}
```

**File sidebar (`fileSidebar`):**
- A `List` showing `git.changedFiles`
- Each row shows:
  - Status icon: `M` = yellow circle, `A` = green plus, `D` = red minus, `R` = blue arrow, `?` = gray questionmark
  - File path (truncated, 12pt, monospaced)
  - Selected file gets a subtle accent background
- Tapping a file calls `git.loadDiff(repositoryPath:currentDirectory, filePath:file.path, staged:file.staged)`
- The selected file's diff is displayed in `diffContent`
- A "Refresh" button at the top (small, toolbar style) calls `git.refresh(repositoryPath:currentDirectory)`
- A "Stage All" button if there are unstaged changes
- A "Discard All" button (with confirmation dialog) to `git checkout -- .`

**Diff content (`diffContent`):**
- A `ScrollView` containing `DiffView(diffText: git.selectedDiff)`
- If `git.selectedDiff` is empty, show an empty state: "Select a file to view its diff"
- Show a loading indicator if `git` is actively refreshing (check `GitService` — you may need to add an `@Published var isLoading: Bool`)

**Bottom action bar:**
- "Submit Review" button (sends diff to AI for review — for now, just show a placeholder alert)
- "Open in Editor" button (opens the selected file in the default editor via `NSWorkspace`)
- "Stage All" / "Discard All" buttons

### Deliverable 3: Hunk Actions

In `DiffView`, add a small action bar above each hunk header:

```swift
HStack {
    Text("@@ -10,7 +10,7 @@")
    Spacer()
    Button("Revert Hunk") { revertHunk(hunk) }
        .font(.system(size: 10))
    Button("Apply Hunk") { applyHunk(hunk) }
        .font(.system(size: 10))
}
```

For now, these can be stubs (print to console or show an alert). The actual implementation requires applying patches, which is complex. Just wire the buttons and show a confirmation dialog.

### Deliverable 4: Git Diff Chip in Terminal Input

In `TerminalDetailView`, between the `SplitPaneContainer` and the `Divider()` above the `InputEditorView`, add a conditional git diff chip:

```swift
// In TerminalDetailView.body, between the terminal area and the input divider:
if git.hasUncommittedChanges {  // you'll need to add this property to GitService
    HStack(spacing: 6) {
        Text("\(git.changedFiles.count) files")
            .font(.system(size: 11, weight: .medium))
        HStack(spacing: 2) {
            Text("+\(git.totalAdditions)")
                .foregroundStyle(.green)
            Text("-\(git.totalDeletions)")
                .foregroundStyle(.red)
        }
        .font(.system(size: 11, weight: .medium))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.1))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.separator, lineWidth: 1)
    )
    .onTapGesture {
        // Switch inspector to Code Review tab and show inspector if hidden
        showInspector = true
        // You'll need to set inspector tab to .codeReview via a binding or notification
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 4)
}
```

**Additions to `GitService`:**
You need to add these computed properties to `GitService`:

```swift
var hasUncommittedChanges: Bool { !changedFiles.isEmpty }

var totalAdditions: Int {
    // Parse diff for + lines (non-+++). This is approximate.
    // Or compute from git diff --stat if you prefer.
    // For now, just count non-empty + lines in selectedDiff.
}

var totalDeletions: Int {
    // Parse diff for - lines (non----).
}
```

**Note:** Accurate line counts require parsing `git diff --stat` or counting actual `+`/`-` lines. For a first pass, approximate by counting lines in `selectedDiff` that start with `+` or `-` (excluding the `+++`/`---` file headers).

### Deliverable 5: Add `isLoading` to GitService

Add `@Published var isLoading: Bool = false` to `GitService` and set it to `true` at the start of `refresh()` and `loadDiff()`, then `false` in the defer.

## Files to Modify

| File | Action |
|---|---|
| `Sources/WarpClone/DiffView.swift` | **NEW** — Diff rendering component |
| `Sources/WarpClone/InspectorView.swift` | **MODIFY** — Rewrite `codeReviewPanel` with file sidebar + diff view |
| `Sources/WarpClone/TerminalDetailView.swift` | **MODIFY** — Add git diff chip above input area |
| `Sources/WarpClone/GitService.swift` | **MODIFY** — Add `isLoading`, `hasUncommittedChanges`, `totalAdditions`, `totalDeletions` |
| `Sources/WarpClone/Models.swift` | **VERIFY** — Ensure `GitChangedFile` has `path`, `status`, `staged` |

## API Contracts to Use

- `GitService.changedFiles: [GitChangedFile]` — `[{path: String, status: String, staged: Bool}]`
- `GitService.selectedDiff: String` — raw git diff output
- `GitService.currentBranch: String` — branch name
- `GitService.refresh(repositoryPath: String)` — refreshes branch + status
- `GitService.loadDiff(repositoryPath: String, filePath: String, staged: Bool)` — loads diff for file
- `GitService.runGit([String], cwd: String) throws -> String` — run git commands
- `NSWorkspace.shared.openFile(path)` — open file in default editor
- `GitService.isLoading: Bool` — **NEW** property you'll add

## Testing Requirements

After implementation:
1. `swift build` compiles with zero errors
2. `swift test` still passes all 23 tests
3. The Code Review tab shows a file list on the left and diff content on the right
4. Clicking a file in the sidebar loads its diff
5. The diff shows green `+` lines and red `-` lines with line numbers
6. Hunk headers show `Revert Hunk` and `Apply Hunk` buttons (stubs are OK)
7. When there are uncommitted changes, a chip appears above the terminal input showing file count and +/- stats
8. Clicking the chip opens the Code Review tab
9. The "Refresh" button in the Code Review tab updates the file list and diff

## Build Verification

```bash
cd /Users/rihan/Documents/MAC-OS-TERMINAL
swift build
swift test
```

## Design Notes

- Use the same `inspectorSection` helper already in `InspectorView` for the top "Repository" section if needed
- File sidebar should use `.listStyle(.plain)` or just a `LazyVStack` with clickable rows
- Selected file row: accent color background, left border accent color, bold text
- Diff line numbers: secondary color, monospaced, 11pt
- Diff content: monospaced, 11pt, full text selection enabled
- Empty diff state: "Select a file to view its diff" with a secondary icon
- Hunk action buttons: small, bordered, gray until hovered
- The diff chip above input: use the same rounded rect style as the input editor but smaller
- Don't over-engineer the diff parser — handle the standard `git diff` format, not every edge case
- The hunk action buttons can be stubs — wire them and show an alert saying "Not yet implemented"

## Constraints

- Do NOT change the `GitService.runGit()` method — it's already working
- Do NOT change the `GitReviewService` — it's for CLI prompts, not the diff view
- Do NOT modify `PermissionGate` or security code
- Focus ONLY on the diff rendering and the file sidebar
- Make reasonable assumptions about `GitChangedFile` — if it doesn't exist in `Models.swift`, add it
- If `InspectorView` uses `@State` for the active tab, you may need to use `NotificationCenter` to switch the inspector tab from the diff chip tap — or add a binding. Choose the simplest approach
- All code must compile
