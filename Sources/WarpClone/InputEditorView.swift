import AppKit
import SwiftUI

struct InputEditorView: View {
    @Binding var text: String
    @Binding var isAIMode: Bool
    let onSubmit: () -> Void
    let onPickImage: () -> Void
    let onPasteImage: () -> Void

    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var images: ImageAttachmentManager
    @EnvironmentObject private var sessions: SessionStore

    @StateObject private var completionStore = CompletionStore()

    private var workingDirectory: String {
        sessions.selectedSession?.workingDirectory ?? FileManager.default.currentDirectoryPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if completionStore.isVisible {
                CompletionDropdownView(
                    store: completionStore,
                    onSelect: applyCompletion,
                    onDismiss: completionStore.hide
                )
                .padding(.leading, 48)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isAIMode.toggle()
                            completionStore.hide()
                        }
                    } label: {
                        Image(systemName: isAIMode ? "number.circle.fill" : "number.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(isAIMode ? Color.accentColor : Color.secondary.opacity(0.38)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help(isAIMode ? "AI mode enabled" : "Terminal mode")

                    CompletionTextField(
                        text: $text,
                        placeholder: isAIMode ? "Ask AI or type a terminal command..." : "Type a command...",
                        fontSize: preferences.fontSize,
                        onKeyCommand: handleCompletionKey,
                        onTextChange: handleTextChange,
                        onSubmit: submit
                    )
                    .frame(minHeight: 38)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.separator, lineWidth: 1)
                    )

                    Button(action: submit) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 42, height: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                }

                HStack(spacing: 10) {
                    PremiumMenuChip(isActive: false) {
                        ModelPickerMenu()
                    }
                    PremiumToolbeltChip(label: "Auto", icon: "sparkles", isActive: preferences.autoDetectModel) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            preferences.autoDetectModel.toggle()
                        }
                    }
                    PremiumToolbeltChip(label: "Voice", icon: preferences.voiceInputEnabled ? "mic.fill" : "mic", isActive: preferences.voiceInputEnabled) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            preferences.voiceInputEnabled.toggle()
                        }
                    }
                    PremiumToolbeltChip(label: "Image", icon: "photo", isActive: !images.attachments.isEmpty, action: onPickImage)
                    PremiumToolbeltChip(label: "Context 68%", icon: "chart.pie", isActive: false) {}
                    PremiumMenuChip(isActive: false) {
                        PasteImageMenuButton(action: onPasteImage)
                    }
                }
                .padding(.vertical, 1)

                attachmentStrip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .animation(.easeOut(duration: 0.15), value: completionStore.isVisible)
    }

    private var attachmentStrip: some View {
        HStack(spacing: 8) {
            ForEach(images.attachments) { attachment in
                if let image = NSImage(data: attachment.thumbnailData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.separator, lineWidth: 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            Button {
                                images.remove(attachment.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if attachment.detectedVisionCompatible {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(4)
                                    .background(.thinMaterial)
                                    .clipShape(Circle())
                                    .padding(3)
                            }
                        }
                }
            }
        }
        .frame(minHeight: images.attachments.isEmpty ? 0 : 52)
    }

    private func handleTextChange(_ newText: String) {
        guard !isAIMode else {
            completionStore.hide()
            return
        }
        completionStore.updateSuggestions(for: newText, workingDirectory: workingDirectory)
    }

    private func handleCompletionKey(_ key: CompletionKey) -> Bool {
        switch key {
        case .up:
            guard completionStore.isVisible else { return false }
            completionStore.selectPrevious()
            return true
        case .down:
            guard completionStore.isVisible else { return false }
            completionStore.selectNext()
            return true
        case .tab:
            guard completionStore.isVisible else { return false }
            applyCompletion(completionStore.selectedItem())
            return true
        case .escape:
            guard completionStore.isVisible else { return false }
            completionStore.hide()
            return true
        }
    }

    private func applyCompletion(_ item: CompletionItem?) {
        guard let item else { return }
        text = completionStore.applyCompletion(to: text, item: item)
    }

    private func submit() {
        completionStore.addToHistory(text)
        completionStore.hide()
        onSubmit()
    }
}

enum CompletionKey {
    case up
    case down
    case tab
    case escape
}

struct CompletionTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let fontSize: Double
    let onKeyCommand: (CompletionKey) -> Bool
    let onTextChange: (String) -> Void
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.lineBreakMode = .byTruncatingTail
        textField.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textField.placeholderString = placeholder
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CompletionTextField

        init(parent: CompletionTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
            parent.onTextChange(textField.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                return parent.onKeyCommand(.up)
            case #selector(NSResponder.moveDown(_:)):
                return parent.onKeyCommand(.down)
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)):
                return parent.onKeyCommand(.tab)
            case #selector(NSResponder.cancelOperation(_:)):
                return parent.onKeyCommand(.escape)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            default:
                return false
            }
        }
    }
}

struct PremiumToolbeltChip: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.3) : Color.separator, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .opacity(hovered ? 1.0 : 0.86)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.1), value: hovered)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

struct PremiumMenuChip<Content: View>: View {
    let isActive: Bool
    @ViewBuilder var content: () -> Content
    @State private var hovered = false

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.3) : Color.separator, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .opacity(hovered ? 1.0 : 0.86)
            .onHover { hovered = $0 }
            .animation(.easeOut(duration: 0.1), value: hovered)
            .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

struct PasteImageMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
                Text("Paste Image")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }
}
