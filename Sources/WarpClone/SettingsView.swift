import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var ai: AIProviderManager

    @State private var selectedSection = "Appearance"
    @State private var apiKey = ""
    @State private var showingAPIKey = false
    @State private var hasSavedAPIKey = false
    @State private var keyStatus: APIKeyStatus = .missing
    @State private var isSavingKey = false
    @State private var saveSucceeded = false
    @State private var confirmRemoveKey = false
    @State private var customModel = ""
    @State private var showingCustomModel = false

    private let keychain = KeychainManager()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Text("Appearance").tag("Appearance")
                Text("Terminal").tag("Terminal")
                Text("AI").tag("AI")
                Text("MCP").tag("MCP")
                Text("Security").tag("Security")
            }
            .navigationTitle("Settings")
            .background(.ultraThinMaterial)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedSection {
                    case "Appearance": appearance
                    case "Terminal": terminal
                    case "AI": aiSettings
                    case "MCP": mcpSettings
                    default: security
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(.thinMaterial)
        }
        .onAppear {
            refreshKeyState()
            ai.models = ai.models.isEmpty ? preferences.cachedModels() : ai.models
            Task { await autoFetchOpenRouterModelsIfNeeded() }
        }
        .onChange(of: preferences.aiProviderMode) { _ in
            refreshKeyState()
            Task { await autoFetchOpenRouterModelsIfNeeded() }
        }
        .confirmationDialog("Remove saved API key?", isPresented: $confirmRemoveKey) {
            Button("Remove Key", role: .destructive) {
                removeAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the provider key from Keychain.")
        }
        .alert("Custom Model", isPresented: $showingCustomModel) {
            TextField("provider/model-id", text: $customModel)
            Button("Use Model") {
                let trimmed = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    preferences.selectedAIModel = trimmed
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsCard("Theme") {
                Picker("Theme", selection: $preferences.theme) {
                    ForEach(ThemeRegistry.themes) { theme in
                        Text(theme.displayName).tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
            }
            settingsCard("Typography") {
                TextField("Font", text: $preferences.fontName)
                    .textFieldStyle(.roundedBorder)
                Slider(value: $preferences.fontSize, in: 10...22) {
                    Text("Font Size")
                }
                Text("Font size: \(Int(preferences.fontSize))pt")
                    .foregroundStyle(.secondary)
            }
            settingsCard("Surface") {
                Picker("Block Spacing", selection: $preferences.blockSpacing) {
                    Text("Compact").tag("compact")
                    Text("Normal").tag("normal")
                    Text("Relaxed").tag("relaxed")
                }
                Slider(value: $preferences.windowOpacity, in: 0.6...1.0) {
                    Text("Opacity")
                }
            }
        }
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsCard("Shell") {
                TextField("Shell Path", text: $preferences.ptyShellPath)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
            }
            settingsCard("Cursor") {
                Picker("Cursor Style", selection: $preferences.cursorStyle) {
                    Text("Block").tag("block")
                    Text("Beam").tag("beam")
                    Text("Underline").tag("underline")
                }
                Picker("Cursor Blink", selection: $preferences.cursorBlink) {
                    Text("Never").tag("never")
                    Text("Always").tag("always")
                }
            }
            settingsCard("Session") {
                Toggle("Restore Session", isOn: $preferences.restoreSession)
                Toggle("Vim Mode", isOn: $preferences.vimModeEnabled)
            }
        }
    }

    private var aiSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsCard("Provider") {
                Picker("Provider", selection: $preferences.aiProviderMode) {
                    ForEach(AIProviderKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            settingsCard("API Key") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Group {
                            if showingAPIKey {
                                TextField("", text: $apiKey, prompt: Text("Enter your OpenRouter API key...").foregroundColor(.secondary))
                            } else {
                                SecureField("", text: $apiKey, prompt: Text("Enter your OpenRouter API key...").foregroundColor(.secondary))
                            }
                        }
                        .font(.custom("SF Mono", size: 13))
                        .foregroundStyle(.primary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondarySystemFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.separator, lineWidth: 1)
                        )

                        Button {
                            showingAPIKey.toggle()
                        } label: {
                            Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    keyStatusRow

                    HStack(spacing: 10) {
                        Button {
                            Task { await saveAPIKey() }
                        } label: {
                            HStack(spacing: 6) {
                                if isSavingKey {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(saveButtonTitle)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingKey)

                        if hasSavedAPIKey {
                            Button(role: .destructive) {
                                confirmRemoveKey = true
                            } label: {
                                Label("Remove Key", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            Task { await testConnection() }
                        } label: {
                            Label("Test Connection", systemImage: "network")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasSavedAPIKey || ai.isLoadingModels)
                    }
                }
            }

            settingsCard("Model") {
                VStack(alignment: .leading, spacing: 12) {
                    ModelPickerMenu()
                        .environmentObject(preferences)
                        .environmentObject(ai)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.secondary.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(Color.separator, lineWidth: 1))

                    if ai.isLoadingModels {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Fetching OpenRouter models...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = ai.lastError, !error.isEmpty {
                        Text("Could not fetch models. Check your API key.")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            settingsCard("Capabilities") {
                Toggle("Enable AI", isOn: $preferences.enableAI)
                Toggle("Auto-detect Model", isOn: $preferences.autoDetectModel)
                Toggle("Voice Input", isOn: $preferences.voiceInputEnabled)
            }
        }
    }

    private var mcpSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsCard("MCP") {
                Toggle("Enable MCP", isOn: $preferences.enableMCP)
                Toggle("Auto-discover MCP Configs", isOn: $preferences.mcpAutoDiscover)
                Toggle("Debug Mode", isOn: $preferences.debugMode)
            }
        }
    }

    private var security: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsCard("Agent Permissions") {
                Picker("Default Agent Mode", selection: $preferences.agentModeDefault) {
                    Text("Assist").tag("assist")
                    Text("Review").tag("review")
                    Text("Autonomous Read-only").tag("read_only")
                }
                Toggle("Telemetry Disabled", isOn: $preferences.telemetryDisabled)
                Stepper("Max Image Attachments: \(preferences.maxImageAttachments)", value: $preferences.maxImageAttachments, in: 1...20)
            }
        }
    }

    private var keyStatusRow: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(keyStatus.color)
                .frame(width: 8, height: 8)
            Text(keyStatus.message(hasKey: hasSavedAPIKey))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var saveButtonTitle: String {
        if isSavingKey { return "Saving..." }
        if saveSucceeded { return "Saved ✓" }
        return hasSavedAPIKey ? "Save New Key" : "Save API Key to Keychain"
    }

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            content()
                .font(.system(size: 13))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func refreshKeyState() {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else {
            hasSavedAPIKey = false
            keyStatus = .missing
            return
        }
        let saved = (try? keychain.read(service: kind.keychainServiceName, account: "apiKey")) != nil
        hasSavedAPIKey = saved
        keyStatus = saved ? .saved : .missing
    }

    private func saveAPIKey() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode), !trimmed.isEmpty else { return }
        isSavingKey = true
        saveSucceeded = false
        do {
            try keychain.save(service: kind.keychainServiceName, account: "apiKey", secret: trimmed)
            apiKey = ""
            hasSavedAPIKey = true
            keyStatus = .saved
            isSavingKey = false
            saveSucceeded = true
            await testConnection()
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            saveSucceeded = false
        } catch {
            ai.lastError = error.localizedDescription
            isSavingKey = false
        }
    }

    private func removeAPIKey() {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else { return }
        try? keychain.delete(service: kind.keychainServiceName, account: "apiKey")
        hasSavedAPIKey = false
        keyStatus = .missing
        apiKey = ""
        ai.models = []
        preferences.cache(models: [])
    }

    private func testConnection() async {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else { return }
        await ai.loadModels(kind: kind)
        if ai.lastError == nil, !ai.models.isEmpty {
            preferences.cache(models: ai.models)
            keyStatus = .connected
        } else if hasSavedAPIKey {
            keyStatus = .saved
        }
    }

    private func autoFetchOpenRouterModelsIfNeeded() async {
        guard preferences.aiProviderMode == AIProviderKind.openRouter.rawValue, hasSavedAPIKey else { return }
        let cached = preferences.cachedModels()
        if !cached.isEmpty {
            ai.models = cached
            return
        }
        await testConnection()
    }
}

private enum APIKeyStatus {
    case missing
    case saved
    case connected

    var color: Color {
        switch self {
        case .missing: .red
        case .saved: .yellow
        case .connected: .green
        }
    }

    func message(hasKey: Bool) -> String {
        switch self {
        case .missing:
            return "No API key saved"
        case .saved:
            return hasKey ? "API key saved (click to update)" : "No API key saved"
        case .connected:
            return "Connected"
        }
    }
}
