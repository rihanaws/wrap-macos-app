import SwiftUI

struct ModelPickerMenu: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var ai: AIProviderManager
    @State private var showingCustomModel = false
    @State private var customModel = ""
    @State private var attemptedAutoLoad = false

    var compactLabel = false
    private let keychain = KeychainManager()

    var body: some View {
        Menu {
            if ai.isLoadingModels {
                ProgressView()
            }

            ForEach(groupedModelKeys, id: \.self) { provider in
                Section(provider) {
                    ForEach(groupedModels[provider] ?? []) { model in
                        Button {
                            preferences.selectedAIModel = model.id
                        } label: {
                            HStack {
                                Text(model.id)
                                if model.supportsVision {
                                    Image(systemName: "eye.fill")
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                Task { await refreshModels() }
            } label: {
                Label("Refresh Models", systemImage: "arrow.clockwise")
            }

            Button {
                customModel = preferences.selectedAIModel
                showingCustomModel = true
            } label: {
                Label("Custom...", systemImage: "pencil")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .medium))
                Text(compactLabel ? displayName : "Model: \(displayName)")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if ai.isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .alert("Custom Model", isPresented: $showingCustomModel) {
            TextField("provider/model-id", text: $customModel)
            Button("Use Model") {
                let trimmed = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    preferences.selectedAIModel = trimmed
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a provider-prefixed model ID.")
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
        let loaded = ai.models.isEmpty ? preferences.cachedModels() : ai.models
        return loaded.isEmpty ? [
            AIModel(id: preferences.selectedAIModel, name: preferences.selectedAIModel, supportsVision: ai.visionSupported(modelID: preferences.selectedAIModel), contextWindow: 0)
        ] : loaded
    }

    private var displayName: String {
        models.first(where: { $0.id == preferences.selectedAIModel })?.name ?? preferences.selectedAIModel
    }

    private var groupedModels: [String: [AIModel]] {
        Dictionary(grouping: models) { model in
            model.id.split(separator: "/").first.map(String.init) ?? "custom"
        }
    }

    private var groupedModelKeys: [String] {
        groupedModels.keys.sorted()
    }

    private func refreshModels() async {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else { return }
        await ai.loadModels(kind: kind)
        if ai.lastError == nil, !ai.models.isEmpty {
            preferences.cache(models: ai.models)
        }
    }

    private func hasSavedKey() -> Bool {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else { return false }
        return (try? keychain.read(service: kind.keychainServiceName, account: "apiKey")) != nil
    }
}
