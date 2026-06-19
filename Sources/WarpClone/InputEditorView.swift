import SwiftUI

struct InputEditorView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var ai: AIProviderManager
    @EnvironmentObject private var images: ImageAttachmentManager

    @Binding var text: String
    @Binding var isAIMode: Bool

    var onSubmit: () -> Void
    var onPickImage: () -> Void
    var onPasteImage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbelt
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isAIMode.toggle()
                    }
                } label: {
                    Image(systemName: "number")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(isAIMode ? Color.accentColor : Color.secondary.opacity(0.38)))
                }
                .buttonStyle(.plain)
                .help("Toggle AI mode")

                TextField(isAIMode ? "Ask AI about this terminal context…" : "Run command in active pane…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: preferences.fontSize, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.separator, lineWidth: 1)
                    )
                    .onSubmit(onSubmit)

                Button {
                    onSubmit()
                } label: {
                    Image(systemName: isAIMode ? "sparkles" : "return")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 42, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            attachmentStrip
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    private var toolbelt: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PremiumMenuChip(isActive: true) {
                    ModelPickerMenu()
                        .environmentObject(preferences)
                        .environmentObject(ai)
                }
                PremiumToolbeltChip(
                    label: "Auto-detect: \(preferences.autoDetectModel ? "On" : "Off")",
                    icon: preferences.autoDetectModel ? "checkmark.circle.fill" : "circle",
                    isActive: preferences.autoDetectModel
                ) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        preferences.autoDetectModel.toggle()
                    }
                }
                PremiumToolbeltChip(
                    label: "Voice",
                    icon: preferences.voiceInputEnabled ? "mic.fill" : "mic",
                    isActive: preferences.voiceInputEnabled
                ) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        preferences.voiceInputEnabled.toggle()
                    }
                }
                PremiumToolbeltChip(label: "Image", icon: "photo", isActive: !images.attachments.isEmpty, action: onPickImage)
                PremiumToolbeltChip(label: "Context 68%", icon: "chart.pie", isActive: false, action: {})
                PremiumToolbeltChip(label: "File", icon: "paperclip", isActive: false, action: onPasteImage)
            }
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 36)
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
                        .overlay(alignment: .bottomTrailing) {
                            if attachment.detectedVisionCompatible {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(4)
                                    .background(.thinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                }
            }
            Spacer()
        }
        .frame(minHeight: images.attachments.isEmpty ? 0 : 52)
    }
}

struct PremiumToolbeltChip: View {
    var label: String
    var icon: String
    var isActive: Bool
    var action: () -> Void
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
    var isActive: Bool
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
    }
}
