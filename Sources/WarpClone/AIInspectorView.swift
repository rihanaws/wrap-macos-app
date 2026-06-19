import SwiftUI

struct AIInspectorView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var ai: AIProviderManager
    @State private var attemptedAutoLoad = false
    private let keychain = KeychainManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSection("Provider") {
                VStack(alignment: .leading, spacing: 10) {
                    ModelPickerMenu()
                        .environmentObject(preferences)
                        .environmentObject(ai)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.secondary.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(Color.separator, lineWidth: 1))

                    HStack {
                        Text(preferences.aiProviderMode)
                        Spacer()
                        Text(ai.visionSupported(modelID: preferences.selectedAIModel) ? "Vision" : "Text")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
            }

            inspectorSection("Models") {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        Task { await refreshModels() }
                    } label: {
                        HStack {
                            if ai.isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(ai.isLoadingModels ? "Loading Models..." : "Load Models")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(ai.isLoadingModels)

                    if let error = ai.lastError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Could not fetch models. Check your API key.")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await refreshModels() }
                            }
                        }
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(models) { model in
                                modelRow(model)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }

            inspectorSection("Permissions") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default agent mode: \(preferences.agentModeDefault)")
                    Text("Auto-detection: \(preferences.autoDetectModel ? "Enabled" : "Disabled")")
                    Text("Image context: \(preferences.maxImageAttachments) attachments")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if ai.models.isEmpty {
                ai.models = preferences.cachedModels()
            }
            if !attemptedAutoLoad,
               preferences.aiProviderMode == AIProviderKind.openRouter.rawValue,
               ai.models.isEmpty,
               hasSavedKey() {
                attemptedAutoLoad = true
                Task { await refreshModels() }
            }
        }
    }

    private var models: [AIModel] {
        ai.models.isEmpty ? preferences.cachedModels() : ai.models
    }

    private func refreshModels() async {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else { return }
        await ai.loadModels(kind: kind)
        if ai.lastError == nil, !ai.models.isEmpty {
            preferences.cache(models: ai.models)
        }
    }

    private func modelRow(_ model: AIModel) -> some View {
        Button {
            preferences.selectedAIModel = model.id
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(model.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(providerPrefix(model.id))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.10)))
                Text(contextLabel(model.contextWindow))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Image(systemName: model.supportsVision ? "eye.fill" : "text.alignleft")
                    .foregroundStyle(model.supportsVision ? Color.accentColor : Color.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(model.id == preferences.selectedAIModel ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 8)
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.06))
                )
        }
        .padding(.horizontal, 12)
    }

    private func providerPrefix(_ id: String) -> String {
        id.split(separator: "/").first.map(String.init) ?? "custom"
    }

    private func contextLabel(_ window: Int) -> String {
        guard window > 0 else { return "context -" }
        if window >= 1_000_000 { return "\(window / 1_000_000)M" }
        if window >= 1_000 { return "\(window / 1_000)K" }
        return "\(window)"
    }

    private func hasSavedKey() -> Bool {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else { return false }
        return (try? keychain.read(service: kind.keychainServiceName, account: "apiKey")) != nil
    }
}
