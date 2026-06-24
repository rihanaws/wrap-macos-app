# Prompt: Wire AI Streaming to Terminal Blocks + Build Conversation Panel

## Goal
Make the AI actually work end-to-end. When the user types `# hello` in the input editor, the AI provider should be called and its response should stream token-by-token into a terminal block in real-time. Simultaneously, the AI Inspector panel should display a persistent chat history with user/assistant messages, syntax-highlighted code blocks, and a streaming indicator.

## Current State (What's Broken)

### 1. `TerminalDetailView.submitInput()` (Sources/WarpClone/TerminalDetailView.swift)
Currently it does this:
```swift
if sessions.isAIMode {
    sessions.appendBlock(command: "# \(trimmed)", output: "AI request queued for \(preferences.selectedAIModel).", status: .succeeded)
}
```
It NEVER calls `AIProviderManager.complete()`. It just appends a static placeholder block. The AI streaming backend (`AIProviderManager.complete()` returning `AsyncThrowingStream<AIResponseChunk, Error>`) is fully implemented but completely unused.

### 2. `AIInspectorView` (Sources/WarpClone/AIInspectorView.swift)
Currently shows a model picker, a "Load Models" button, and permission settings. It has NO chat history, NO message bubbles, NO streaming indicator. It's a settings panel, not a conversation panel.

## Deliverables

### Deliverable 1: ConversationStore (New File)

Create `Sources/WarpClone/ConversationStore.swift` as an `ObservableObject`:

```swift
import Foundation
import WarpCLICore

enum MessageRole {
    case user
    case assistant
}

struct AIConversationMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    var content: String          // mutable for streaming
    let timestamp: Date
    let model: String?           // which model generated this
    var isStreaming: Bool = false
    var error: String? = nil
}

final class ConversationStore: ObservableObject {
    @Published var messages: [AIConversationMessage] = []
    @Published var isStreaming: Bool = false
    
    private var activeTask: Task<Void, Never>?
    
    func addUserMessage(_ text: String) -> UUID {
        let msg = AIConversationMessage(id: UUID(), role: .user, content: text, timestamp: Date(), model: nil)
        messages.append(msg)
        return msg.id
    }
    
    func addAssistantMessage(model: String) -> UUID {
        let msg = AIConversationMessage(id: UUID(), role: .assistant, content: "", timestamp: Date(), model: model, isStreaming: true)
        messages.append(msg)
        return msg.id
    }
    
    func appendToMessage(id: UUID, text: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content += text
        }
    }
    
    func finishStreaming(id: UUID) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].isStreaming = false
        }
        isStreaming = false
        activeTask = nil
    }
    
    func setError(id: UUID, error: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].error = error
            messages[index].isStreaming = false
        }
        isStreaming = false
        activeTask = nil
    }
    
    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        isStreaming = false
    }
    
    func setActiveTask(_ task: Task<Void, Never>) {
        activeTask = task
        isStreaming = true
    }
    
    func clear() {
        cancel()
        messages.removeAll()
    }
}
```

### Deliverable 2: Rewrite `AIInspectorView` as a Chat Panel

Replace the entire `AIInspectorView` body to show a chat interface:

**Top section (keep existing):**
- Model picker (keep the existing `ModelPickerMenu`)
- Provider status (keep the existing provider mode + vision indicator)

**Middle section (NEW - chat history):**
- A `ScrollView` with `LazyVStack` containing `AIConversationMessage` bubbles:
  - **User messages**: Right-aligned, accent color background (max-width 80%), rounded corners, show timestamp
  - **Assistant messages**: Left-aligned, secondary background, rounded corners
  - **Code blocks**: Inside assistant messages, detect triple backticks (```), render the code in a monospaced font with a darker background, a "Copy" button (small, top-right), and a language label if present on the first line
  - **Streaming indicator**: When `isStreaming == true`, show animated dots "● ● ●" below the last assistant message
  - **Error state**: Show red text with error message

**Bottom section (NEW - input area):**
- A `TextField` with placeholder "Ask the AI..." and a send button (paper airplane icon)
- When user submits, call a closure that routes to `TerminalDetailView.submitInput()` (see Deliverable 3)
- Show a "Stop" button (square.fill) when `conversationStore.isStreaming` is true
- Show attached image thumbnails (up to `preferences.maxImageAttachments`) if `ImageAttachmentManager` has images

**Key implementation details:**
- Use `@StateObject private var conversation = ConversationStore()` inside `AIInspectorView`
- Expose `conversation` via a `Binding` or pass it as `EnvironmentObject` so `TerminalDetailView` can access it
- Auto-scroll to the bottom when new messages arrive
- Use `.animation(.easeOut(duration: 0.2), value: conversation.messages.count)` for smooth appearance
- The message bubbles should use `markdown` or plain text rendering — no need for a full markdown parser, just handle code blocks via regex

### Deliverable 3: Wire AI Streaming in `TerminalDetailView`

Rewrite `TerminalDetailView.submitInput()` to:

1. **When NOT in AI mode** (`!sessions.isAIMode`):
   - Keep existing behavior: `runtime.send(trimmed, to: sessions.activePaneID)` and append a running block

2. **When IN AI mode** (`sessions.isAIMode`):
   a. Add the user message to the conversation store: `conversation.addUserMessage(trimmed)`
   b. Create a terminal block: `sessions.appendBlock(command: "# \(trimmed)", output: "", status: .running)` — capture the block ID
   c. Add an assistant message to the conversation: `conversation.addAssistantMessage(model: preferences.selectedAIModel)` — capture the message ID
   d. Start a `Task`:
      ```swift
      let task = Task { @MainActor in
          do {
              let request = AIRequest(
                  prompt: trimmed,
                  model: preferences.selectedAIModel,
                  images: images.attachments.map { ImageAttachment(data: $0.data, mimeType: $0.mimeType) }
              )
              let stream = try await ai.complete(kind: preferences.selectedAIProvider, request: request)
              for try await chunk in stream {
                  switch chunk.kind {
                  case .token:
                      conversation.appendToMessage(id: assistantMessageID, text: chunk.text)
                      sessions.updateBlock(id: blockID, output: conversation.messages.last(where: { $0.id == assistantMessageID })?.content ?? "")
                  case .done:
                      break
                  case .error:
                      conversation.setError(id: assistantMessageID, error: chunk.text)
                      sessions.updateBlock(id: blockID, status: .failed)
                  case .toolCall:
                      // For now, just append as text
                      conversation.appendToMessage(id: assistantMessageID, text: chunk.text)
                  }
              }
              conversation.finishStreaming(id: assistantMessageID)
              sessions.updateBlock(id: blockID, status: .succeeded)
          } catch {
              conversation.setError(id: assistantMessageID, error: error.localizedDescription)
              sessions.updateBlock(id: blockID, status: .failed)
          }
      }
      ```
   e. Store the task: `conversation.setActiveTask(task)`
   f. Clear the input field: `input = ""`
   g. Clear image attachments: `images.clear()` (if this method exists; otherwise just clear the array)

3. **Add `updateBlock` to `SessionStore`** (in `Sources/WarpClone/Stores.swift`):
   ```swift
   func updateBlock(id: UUID, output: String? = nil, status: BlockStatus? = nil) {
       guard let sessionIndex = sessions.firstIndex(where: { $0.id == selectedSessionID }) else { return }
       guard let blockIndex = sessions[sessionIndex].blocks.firstIndex(where: { $0.id == id }) else { return }
       if let output = output {
           sessions[sessionIndex].blocks[blockIndex].rawOutput = output
       }
       if let status = status {
           sessions[sessionIndex].blocks[blockIndex].status = status
       }
   }
   ```

4. **Add `ImageAttachment` struct** if it doesn't exist in `Models.swift`:
   ```swift
   struct ImageAttachment: Equatable {
       var data: Data
       var mimeType: String
   }
   ```

### Deliverable 4: Code Block Rendering in AI Messages

In `AIInspectorView`, create a helper that renders assistant message content with inline code blocks:

```swift
struct CodeBlock: Identifiable {
    let id = UUID()
    let language: String?
    let code: String
}

func extractCodeBlocks(from text: String) -> [AttributedTextSegment] {
    // Regex: ```(optional_language)\n(code)\n```
    // Split the text into segments: plain text and code blocks
    // Return an array of segments with associated types
}
```

For the UI:
- Plain text segments: rendered as normal `Text`
- Code blocks: rendered in a `RoundedRectangle` with a darker fill, monospaced font, a small "Copy" button (top-right), and the language label (top-left, if detected)
- Use `NSPasteboard` for the copy action

### Deliverable 5: Auto-Scroll to Bottom

In `AIInspectorView`, when new messages arrive or existing messages are updated during streaming:
```swift
.scrollPosition(id: .bottom)  // or use ScrollViewReader with scrollTo
```

Ensure the view scrolls to the latest message whenever:
- A new message is added
- A message's content is appended during streaming

### Deliverable 6: Stop Button

Add a toolbar button or inline button in `AIInspectorView` that:
- Appears only when `conversation.isStreaming`
- Shows a square.fill icon (Stop)
- Calls `conversation.cancel()` on tap
- Also visually updates the last assistant message to show "Stopped" and the terminal block to `.failed` or `.succeeded` (choose `.succeeded` with partial content)

## Files to Modify

| File | Changes |
|---|---|
| `Sources/WarpClone/ConversationStore.swift` | **NEW** — Create this file with the `ConversationStore` |
| `Sources/WarpClone/AIInspectorView.swift` | **REWRITE** — Replace with chat panel UI |
| `Sources/WarpClone/TerminalDetailView.swift` | **MODIFY** — Rewrite `submitInput()` to stream AI tokens |
| `Sources/WarpClone/Stores.swift` | **MODIFY** — Add `updateBlock(id:output:status:)` method |
| `Sources/WarpClone/Models.swift` | **MODIFY** — Add `ImageAttachment` if missing, verify `BlockStatus` has `.running, .succeeded, .failed` |
| `Sources/WarpClone/WarpCloneApp.swift` | **MODIFY** — Inject `ConversationStore` as `EnvironmentObject` if needed |

## API Contracts to Use

- `AIProviderManager.complete(kind: AIProviderKind, request: AIRequest)` → `AsyncThrowingStream<AIResponseChunk, Error>`
- `AIRequest(prompt: String, model: String, images: [ImageAttachment])`
- `AIResponseChunk(kind: .token | .done | .error | .toolCall, text: String)`
- `SessionStore.appendBlock(command:output:status:)` → creates a `TerminalBlock` and returns it or appends it
- `SessionStore.updateBlock(id:output:status:)` — new method you add
- `preferences.selectedAIModel: String`
- `preferences.selectedAIProvider: AIProviderKind` (or infer from `preferences.aiProviderMode`)
- `images.attachments` or similar — check `ImageAttachmentManager` for the actual property name
- `sessions.isAIMode: Bool`
- `sessions.selectedSessionID: UUID?`

## Testing Requirements

After implementation, verify:
1. `swift build` compiles with zero errors
2. `swift test` still passes all 23 tests
3. Typing `# hello` in the input editor and pressing Enter triggers the AI stream
4. The terminal block shows tokens appearing one by one (or in chunks)
5. The AI Inspector shows the user message and the assistant response streaming in
6. Code blocks (if the AI returns ``` delimiters) are rendered with monospace font and a copy button
7. The "Stop" button appears during streaming and stops the stream when clicked
8. Error handling: if the API key is missing, the block shows the error and the assistant message shows the error

## Build Verification

```bash
cd /Users/rihan/Documents/MAC-OS-TERMINAL
swift build
swift test
```

## Design Notes

- Keep the existing model picker and "Load Models" button at the TOP of the AIInspectorView
- The chat history should scroll beneath it
- The input field should be at the BOTTOM, fixed height
- Use the same `inspectorSection` helper pattern already in `AIInspectorView` for the top settings if you want, but the chat should be the main focus
- User message bubbles: use `Color.accentColor.opacity(0.15)` for background
- Assistant message bubbles: use `Color.secondary.opacity(0.08)` for background
- Code blocks: use `Color.black.opacity(0.3)` for background, `SF Mono` font
- Keep the same `@EnvironmentObject` injection pattern used throughout the app
- The `#` toggle in `InputEditorView` already sets `sessions.isAIMode` — don't change that

## Constraints

- Do NOT change the `AIProviders.swift` streaming implementation — it already works
- Do NOT change `PermissionGate` or security code — it's already complete
- Do NOT change the `PTYSession` or terminal core — it's already working
- Focus ONLY on the UI wire-up and the conversation panel
- If you need to add new methods to `SessionStore`, do so — but don't break existing callers
- If `ImageAttachmentManager` doesn't have a `.clear()` method, just add it or skip clearing images after send
- Make reasonable assumptions and complete the implementation — don't stop for clarifications unless truly blocked
- All code must compile
