# Prompt: Implement Missing Features — Code Review Diff, DnD Tabs, Agent Feedback Loop, Premium Visual Design

## Goal
Implement the remaining 3 missing features and 1 partial feature to bring WarpClone from ~70% to ~90% complete. This is a single-pass implementation covering:

1. **Code Review Diff Surface** (#4) — Replace the stub Code Review tab with a full diff view: file sidebar, green/red line rendering, line numbers, hunk actions
2. **Drag-and-Drop Tab Reordering** (#5) — Add `.onDrag` / `.onDrop` to sidebar rows so users can reorder sessions
3. **Agent Feedback Loop** (#8) — Wire the Code Review comment box to submit comments to the AI and receive an updated diff
4. **Premium Visual Design** (#2) — Add block entrance animations, inspector slide-in, sidebar collapse animation, and meaningful typography hierarchy

## Current State (What's Broken / Stubbed)

### Code Review Tab (`InspectorView.swift:64-80`)
```swift
private var codeReviewPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
        inspectorSection("Repository") {
            HStack {
                Label(git.currentBranch, systemImage: "arrow.branch")
                Spacer()
                Button("Refresh") { git.refresh(...) }
            }
            if let error = git.lastError { Text(error).foregroundStyle(.red) }
        }
        // ... comment box stub
    }
}
```
- NO file list sidebar
- NO diff rendering
- NO green/red line highlighting
- NO line numbers
- NO hunk actions
- Comment box is a stub that does nothing

### Sidebar (`SidebarView.swift`)
- NO `.onDrag` / `.onDrop` modifiers
- `SessionStore.sessions` is a plain array — no reordering logic

### Agent Feedback Loop
- NO mechanism to send review comments to the AI
- NO way to get an updated diff back from the AI

### Visual Design
- Blocks have shadows but NO entrance animation
- Inspector has NO slide-in animation
- Sidebar toggle has NO collapse animation
- No purposeful typography hierarchy beyond basic sizing

## Deliverables

---

### Deliverable 1: Code Review Diff Surface (DiffView + FileSidebar)

#### 1.1 Create `DiffView.swift` (NEW FILE)

```swift
import SwiftUI

struct DiffView: View {
    let diffText: String
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(parseDiff(diffText)) { hunk in
                    HunkView(hunk: hunk)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    private func parseDiff(_ text: String) -> [DiffHunk] { ... }
}

struct DiffHunk: Identifiable {
    let id = UUID()
    let header: String           // "@@ -10,7 +10,7 @@"
    let lines: [DiffLine]
}

struct DiffLine: Identifiable {
    let id = UUID()
    let kind: DiffLineKind
    let oldLineNumber: String?
    let newLineNumber: String?
    let content: String
}

enum DiffLineKind {
    case context
    case addition
    case deletion
    case header
    case noNewline
}
```

**Parsing logic for `parseDiff`:**
- Split input by lines
- Detect `diff --git a/... b/...` → file header row
- Detect `--- a/...` / `+++ b/...` → file path row
- Detect `@@ -oldStart,oldCount +newStart,newCount @@` → hunk header
- For each hunk, iterate lines:
  - `+` → `.addition` (green background)
  - `-` → `.deletion` (red background)
  - ` ` → `.context` (default background)
  - `\` → `.noNewline` (small gray text)
- Track line numbers: increment old line for `-` and context, increment new line for `+` and context

**HunkView layout:**
```swift
struct HunkView: View {
    let hunk: DiffHunk
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with actions
            HStack {
                Text(hunk.header)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Revert Hunk") { /* stub: show alert */ }
                    .font(.system(size: 10))
                Button("Apply Hunk") { /* stub: show alert */ }
                    .font(.system(size: 10))
            }
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.06))
            
            // Lines
            ForEach(hunk.lines) { line in
                DiffLineView(line: line)
            }
        }
    }
}

struct DiffLineView: View {
    let line: DiffLine
    
    var body: some View {
        HStack(spacing: 0) {
            Text(line.oldLineNumber ?? "")
                .frame(width: 40, alignment: .trailing)
            Text(line.newLineNumber ?? "")
                .frame(width: 40, alignment: .trailing)
            Text(prefix + line.content)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.system(size: 11, design: .monospaced))
        .background(backgroundColor)
    }
    
    private var prefix: String {
        switch line.kind {
        case .addition: return "+"
        case .deletion: return "-"
        default: return " "
        }
    }
    
    private var backgroundColor: Color {
        switch line.kind {
        case .addition: return Color.green.opacity(0.08)
        case .deletion: return Color.red.opacity(0.08)
        case .context: return Color.clear
        case .header: return Color.secondary.opacity(0.06)
        case .noNewline: return Color.clear
        }
    }
}
```

#### 1.2 Rewrite `InspectorView.codeReviewPanel`

Replace the current `codeReviewPanel` with a two-column layout:

```swift
private var codeReviewPanel: some View {
    HStack(spacing: 0) {
        // Left: File sidebar
        fileSidebar
            .frame(width: 180)
        
        Divider()
        
        // Right: Diff content
        diffContent
    }
}

private var fileSidebar: some View {
    VStack(spacing: 0) {
        // Toolbar
        HStack {
            Text("Changed Files")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button { refreshGit() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Refresh")
        }
        .padding(8)
        
        Divider()
        
        // File list
        List(selection: $selectedFilePath) {
            ForEach(git.changedFiles) { file in
                FileRow(file: file)
                    .tag(file.path)
                    .onTapGesture {
                        selectedFilePath = file.path
                        if let path = sessions.selectedSession?.workingDirectory {
                            git.loadDiff(repositoryPath: path, filePath: file.path, staged: file.staged)
                        }
                    }
            }
        }
        .listStyle(.plain)
        
        Divider()
        
        // Bottom actions
        HStack(spacing: 8) {
            Button("Stage All") { stageAll() }
                .font(.system(size: 10))
            Button("Discard") { confirmDiscard = true }
                .font(.system(size: 10))
                .foregroundStyle(.red)
        }
        .padding(8)
    }
}

private var diffContent: some View {
    VStack(spacing: 0) {
        if git.selectedDiff.isEmpty {
            emptyDiffState
        } else {
            DiffView(diffText: git.selectedDiff)
        }
        
        Divider()
        
        // Bottom action bar
        HStack(spacing: 12) {
            Button("Submit Review") { submitReview() }
            Button("Open in Editor") { openInEditor() }
            Spacer()
        }
        .padding(8)
        .background(.thinMaterial)
    }
}

private struct FileRow: View {
    let file: GitChangedFile
    
    var body: some View {
        HStack(spacing: 6) {
            statusIcon
                .frame(width: 18)
            Text(file.path)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: some View {
        switch file.status {
        case "M": return Image(systemName: "circle.fill").foregroundStyle(.yellow).font(.system(size: 8))
        case "A": return Image(systemName: "plus.circle.fill").foregroundStyle(.green).font(.system(size: 8))
        case "D": return Image(systemName: "minus.circle.fill").foregroundStyle(.red).font(.system(size: 8))
        case "R": return Image(systemName: "arrow.right.circle.fill").foregroundStyle(.blue).font(.system(size: 8))
        default: return Image(systemName: "questionmark.circle").foregroundStyle(.secondary).font(.system(size: 8))
        }
    }
}
```

**State to add in `InspectorView`:**
```swift
@State private var selectedFilePath: String? = nil
@State private var confirmDiscard = false
```

**Methods to add (stubs OK):**
```swift
private func refreshGit() {
    if let path = sessions.selectedSession?.workingDirectory {
        git.refresh(repositoryPath: path)
    }
}

private func stageAll() {
    // Stub: show alert or run git add -A
}

private func openInEditor() {
    guard let path = selectedFilePath else { return }
    let fullPath = (sessions.selectedSession?.workingDirectory ?? "") + "/" + path
    NSWorkspace.shared.openFile(fullPath)
}

private func submitReview() {
    // Stub: show alert "Review submitted to AI" — will be wired in Deliverable 3
}
```

---

### Deliverable 2: Drag-and-Drop Tab Reordering

#### 2.1 Modify `SessionStore` (`Stores.swift`)

Add a method to reorder sessions:

```swift
func moveSession(from source: IndexSet, to destination: Int) {
    sessions.move(fromOffsets: source, toOffset: destination)
}
```

If `sessions` is not directly mutable in `SessionStore`, you may need to expose a binding or make the array reorderable. Check `Stores.swift` for the current `sessions` property definition.

#### 2.2 Modify `SidebarView.swift`

Add `.onDrag` and `.onDrop` to the list rows:

```swift
struct SidebarView: View {
    @EnvironmentObject private var sessions: SessionStore

    var body: some View {
        List(selection: $sessions.selectedSessionID) {
            Section("Sessions") {
                ForEach(sessions.sessions) { session in
                    VerticalTabRow(session: session, isSelected: sessions.selectedSessionID == session.id)
                        .tag(Optional(session.id))
                        .onDrag {
                            NSItemProvider(object: session.id.uuidString as NSString)
                        }
                        .contextMenu { ... }
                }
                .onMove { source, destination in
                    sessions.moveSession(from: source, to: destination)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationTitle("WarpClone")
    }
}
```

**Key points:**
- Use `.onMove` (SwiftUI's built-in list reordering) instead of custom `.onDrag`/`.onDrop` for native feel
- The user should be able to drag the drag handle on the right edge of each row to reorder
- If `VerticalTabRow` doesn't have a drag handle, add one: a small `Image(systemName: "line.3.horizontal")` at the trailing edge of the row

#### 2.3 Add Drag Handle to `VerticalTabRow`

```swift
// In VerticalTabRow body, before the Spacer():
Image(systemName: "line.3.horizontal")
    .font(.system(size: 10))
    .foregroundStyle(.secondary)
    .opacity(hovering ? 1 : 0)
```

---

### Deliverable 3: Agent Feedback Loop (Review → AI Fixes → Updated Diff)

#### 3.1 Modify `InspectorView` Comment Box

The comment box in `InspectorView` is currently a stub. Wire it to:
1. Collect user comments (text input + line number reference)
2. Submit the review as a prompt to the AI
3. Receive the updated diff from the AI
4. Display the updated diff in the diff view

**Add to `InspectorView`:**

```swift
@State private var reviewComments: [ReviewComment] = []
@State private var commentText = ""
@State private var showReviewSubmission = false

struct ReviewComment: Identifiable {
    let id = UUID()
    let lineNumber: Int?
    let text: String
}

// In the comment box section, replace the stub with:
private var commentBox: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Review Comments")
            .font(.system(size: 12, weight: .semibold))
        
        ForEach(reviewComments) { comment in
            HStack {
                Text(comment.text)
                    .font(.system(size: 11))
                Spacer()
                Button { removeComment(comment.id) } label: {
                    Image(systemName: "xmark.circle").font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
            .padding(6)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(6)
        }
        
        HStack {
            TextField("Add a comment...", text: $commentText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
            Button("Add") { addComment() }
                .font(.system(size: 11))
        }
        .padding(6)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
        
        Button("Submit Review to AI") { submitReviewToAI() }
            .buttonStyle(.borderedProminent)
            .disabled(reviewComments.isEmpty)
    }
}

private func addComment() {
    let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    reviewComments.append(ReviewComment(lineNumber: nil, text: trimmed))
    commentText = ""
}

private func removeComment(_ id: UUID) {
    reviewComments.removeAll { $0.id == id }
}
```

#### 3.2 Wire `submitReviewToAI()` to the AI Provider

```swift
private func submitReviewToAI() {
    guard !reviewComments.isEmpty else { return }
    let commentsText = reviewComments.map { "- \($0.text)" }.joined(separator: "\n")
    let prompt = """
    I have the following git diff for review:

    \(git.selectedDiff)

    Review comments:
    \(commentsText)

    Please address these comments and provide an updated diff.
    """
    
    let request = AIRequest(prompt: prompt, model: preferences.selectedAIModel, images: [])
    
    // Create a new block in the terminal showing the AI is working on the review
    let blockID = sessions.appendBlock(command: "# Review: AI fixing code", output: "", status: .running)
    
    Task { @MainActor in
        do {
            let stream = try await ai.complete(kind: .openRouter, request: request)
            var response = ""
            for try await chunk in stream {
                response += chunk.text
                if let blockID {
                    sessions.updateBlock(id: blockID, output: response)
                }
            }
            if let blockID {
                sessions.updateBlock(id: blockID, output: response, status: .succeeded)
            }
            // Optionally: parse the response and update the diff view
            // git.selectedDiff = response  // if the AI returns a full diff
            reviewComments.removeAll()
        } catch {
            if let blockID {
                sessions.updateBlock(id: blockID, output: error.localizedDescription, status: .failed)
            }
        }
    }
}
```

**Note:** The AI may not return a perfectly formatted diff. For a first pass, just display the AI's response in a terminal block. A future iteration could parse the diff and update the file directly.

---

### Deliverable 4: Premium Visual Design (Animations + Typography)

#### 4.1 Block Entrance Animation

Modify `TerminalBlockView.swift` to add an entrance animation when a new block appears:

```swift
// In TerminalBlockView body, add:
.onAppear {
    withAnimation(.easeOut(duration: 0.3)) {
        // The block fades in and slides up slightly
    }
}

// Add a state property:
@State private var appeared = false

// In body, wrap the content:
.opacity(appeared ? 1 : 0)
.offset(y: appeared ? 0 : 8)
.onAppear {
    withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
        appeared = true
    }
}
```

#### 4.2 Inspector Slide-In Animation

Modify `InspectorView` or `ContentView` to animate the inspector appearing/disappearing:

```swift
// In ContentView or wherever the inspector is shown:
.withAnimation(.easeOut(duration: 0.25)) {
    showInspector.toggle()
}
```

If the inspector uses a `.sheet` or `.overlay`, add a slide-in transition:

```swift
.transition(.move(edge: .trailing).combined(with: .opacity))
```

#### 4.3 Sidebar Collapse Animation

The sidebar already has `withAnimation(.snappy(duration: 0.18))` in `ContentView`. Ensure it's smooth and consistent.

Add a subtle scale effect to sidebar rows when the sidebar is collapsing:

```swift
// In VerticalTabRow:
.scaleEffect(columnVisibility == .detailOnly ? 0.9 : 1.0)
.opacity(columnVisibility == .detailOnly ? 0.5 : 1.0)
```

#### 4.4 Typography Hierarchy

Establish consistent typography tokens. Add these to `Theme.swift` or use inline:

| Role | Size | Weight | Font |
|---|---|---|---|
| Headline | 16pt | .semibold | SF Pro |
| Body | 13pt | .regular | SF Pro |
| Caption | 11pt | .medium | SF Pro |
| Code | 12pt | .regular | SF Mono |
| Terminal | preferences.fontSize | .medium | preferences.fontName |
| Block Command | 13pt | .medium | SF Mono |
| Timestamp | 11pt | .regular | SF Pro |
| Duration | 10pt | .medium | SF Pro |

Apply these consistently:
- `TerminalBlockView.header`: Block command = 13pt SF Mono, timestamp = 11pt, duration = 10pt
- `AIInspectorView`: User message = 12pt, assistant message = 12pt, code blocks = 11pt SF Mono
- `SidebarView`: Session name = 13pt .semibold, branch = 11pt, status = 10pt
- `InspectorView`: Tab labels = 12pt .medium, section headers = 13pt .semibold

---

## Files to Modify

| File | Action | Lines of Change |
|---|---|---|
| `Sources/WarpClone/DiffView.swift` | **NEW** — Diff rendering with line numbers, colors, hunk actions | ~200 |
| `Sources/WarpClone/InspectorView.swift` | **REWRITE** `codeReviewPanel` — File sidebar + diff view + comments | ~150 |
| `Sources/WarpClone/SidebarView.swift` | **MODIFY** — Add `.onMove` for drag-and-drop | ~20 |
| `Sources/WarpClone/VerticalTabRow.swift` | **MODIFY** — Add drag handle + hover animation | ~15 |
| `Sources/WarpClone/Stores.swift` | **MODIFY** — Add `moveSession(from:to:)` | ~10 |
| `Sources/WarpClone/TerminalBlockView.swift` | **MODIFY** — Add entrance animation | ~15 |
| `Sources/WarpClone/ContentView.swift` | **MODIFY** — Add inspector transition | ~5 |
| `Sources/WarpClone/Theme.swift` | **VERIFY** — Ensure font sizes are consistent | ~0 (verify only) |

## Testing Requirements

After implementation:
1. `swift build` compiles with zero errors
2. `swift test` passes all 23 tests
3. Code Review tab shows a file list on the left, diff on the right
4. Clicking a file loads its diff with green/red lines and line numbers
5. Hunk headers show "Revert Hunk" and "Apply Hunk" buttons
6. Dragging a sidebar row's drag handle reorders sessions
7. The "Submit Review to AI" button sends comments to the AI and shows the response in a terminal block
8. New terminal blocks fade in and slide up slightly when they appear
9. Typography is consistent across all views (no mix of 11pt/12pt/13pt arbitrarily)

## Build Verification

```bash
cd /Users/rihan/Documents/MAC-OS-TERMINAL
swift build
swift test
```

## Design Notes

- Use the same `.inspectorSection` helper already in `InspectorView` for the top sections
- The diff view should be scrollable horizontally for long lines (use `ScrollView(.horizontal)`)
- File sidebar should be narrow but readable — 180pt is enough for file paths
- Drag handle should appear on hover to avoid clutter
- Keep the existing color scheme for diff lines: green `.opacity(0.08)` for additions, red `.opacity(0.08)` for deletions
- The hunk action buttons should be small and subtle — they are secondary actions
- The comment box should be at the bottom of the diff view, collapsible
- The AI feedback loop response block should have a purple left border (`.purple`) to indicate AI-generated content
- Entrance animation should be subtle — 0.3s fade + 8px slide is enough
- Don't over-engineer the diff parser — handle standard `git diff` format, not every edge case

## Constraints

- Do NOT change the `GitService.runGit()` method
- Do NOT change the `AIProviderManager` streaming implementation
- Do NOT modify `PermissionGate` or security code
- Do NOT change the `PTYSession` or terminal core
- Focus ONLY on the diff surface, DnD, feedback loop, and animations
- Make reasonable assumptions and complete the implementation — don't stop for clarifications unless truly blocked
- All code must compile
- If `GitChangedFile` doesn't have a status property, add it to `Models.swift`
- If `SessionsStore.sessions` is not a plain array, adapt the `moveSession` method accordingly
- Use `NSWorkspace.shared.openFile()` for "Open in Editor" — it opens the file in the default application
