import Foundation

enum MessageRole: Equatable {
    case user
    case assistant
}

struct AIConversationMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    let model: String?
    var isStreaming: Bool
    var error: String?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        model: String? = nil,
        isStreaming: Bool = false,
        error: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.model = model
        self.isStreaming = isStreaming
        self.error = error
    }
}

@MainActor
final class ConversationStore: ObservableObject {
    @Published var messages: [AIConversationMessage] = []
    @Published var isStreaming = false

    private var activeTask: Task<Void, Never>?

    func addUserMessage(_ text: String) -> UUID {
        let message = AIConversationMessage(role: .user, content: text)
        messages.append(message)
        return message.id
    }

    func addAssistantMessage(model: String) -> UUID {
        let message = AIConversationMessage(
            role: .assistant,
            content: "",
            model: model,
            isStreaming: true
        )
        messages.append(message)
        return message.id
    }

    func appendToMessage(id: UUID, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content += text
    }

    func content(for id: UUID) -> String {
        messages.first(where: { $0.id == id })?.content ?? ""
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

    func markStopped() {
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
            if !messages[index].content.isEmpty {
                messages[index].content += "\n\nStopped."
            } else {
                messages[index].content = "Stopped."
            }
            messages[index].isStreaming = false
        }
        isStreaming = false
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        markStopped()
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
