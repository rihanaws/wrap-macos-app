# Prompt: Implement GitHub Copilot OAuth Device Flow

## Goal
Add full GitHub Copilot OAuth authentication to WarpClone. Users can log in with their GitHub account via the device flow (https://github.com/login/device/code), grant access to Copilot, and use Copilot models (gpt-4o-copilot, claude-sonnet-copilot) without needing an API key. The implementation must handle the complete OAuth 2.0 device flow: initiate → show user code → poll → exchange → store → refresh → subscribe check.

## Current State

### What Exists (BYOK)
- `SettingsView.swift` has AI settings with API key input, save/remove/test buttons, model picker
- `KeychainManager.swift` stores raw API keys as `kSecClassGenericPassword` items
- `AIProviderManager.swift` reads keys from Keychain and sends them as `Bearer` tokens in HTTP headers
- `WarpCloneApp.swift` has a `WarpCloneAppDelegate` that handles `warpclone://auth` URLs via `NotificationCenter` — but **nothing listens for this notification**
- `Info.plist` has the `warpclone` URL scheme registered
- The `AIProviderKind` enum supports `.openRouter`, `.openAICompatible`, `.anthropic`, `.googleGemini` — but **no `.copilot` case**

### What's Missing
- OAuth device flow client (initiate, poll, exchange, refresh)
- OAuth token storage (access token, refresh token, expiration) in Keychain
- Subscription check (verify user has active Copilot subscription)
- Copilot model discovery (fetch available Copilot models)
- Copilot API client (chat completions using the Copilot token)
- Settings UI for Copilot login/logout/status
- Integration with `AIProviderManager` so Copilot appears as a provider option
- Notification listener that handles the OAuth callback

## Deliverables

---

### Deliverable 1: OAuth Device Flow Client (NEW FILE)

Create `Sources/WarpClone/CopilotOAuthClient.swift`:

```swift
import Foundation

enum CopilotOAuthError: Error, LocalizedError {
    case invalidClientID
    case deviceFlowFailed(String)
    case tokenExchangeFailed(String)
    case subscriptionCheckFailed
    case tokenExpired
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidClientID: return "GitHub Copilot OAuth client ID not configured."
        case .deviceFlowFailed(let msg): return "Device flow failed: \(msg)"
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        case .subscriptionCheckFailed: return "Failed to verify Copilot subscription."
        case .tokenExpired: return "Copilot token expired. Please log in again."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from GitHub."
        }
    }
}

struct DeviceFlowResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    
    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let refreshToken: String?
    let expiresIn: Int?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

actor CopilotOAuthClient {
    private let clientID: String
    private let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    private let subscriptionURL = URL(string: "https://api.github.com/user/copilot")!
    
    init(clientID: String) {
        self.clientID = clientID
    }
    
    // Step 1: Initiate device flow
    func initiateDeviceFlow() async throws -> DeviceFlowResponse {
        var request = URLRequest(url: deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode([
            "client_id": clientID,
            "scope": "read:user"
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CopilotOAuthError.deviceFlowFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        // Parse form-encoded response (GitHub returns form-encoded, not JSON)
        let body = String(data: data, encoding: .utf8) ?? ""
        return parseDeviceFlowResponse(body)
    }
    
    // Step 2: Poll for access token
    func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> TokenResponse {
        let startTime = Date()
        let deadline = startTime.addingTimeInterval(TimeInterval(expiresIn))
        
        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            
            if let token = try? await exchangeToken(deviceCode: deviceCode) {
                return token
            }
            // If exchange fails with "authorization_pending", continue polling
            // If it fails with "expired_token" or "access_denied", throw
        }
        
        throw CopilotOAuthError.tokenExpired
    }
    
    // Step 3: Exchange device code for token
    private func exchangeToken(deviceCode: String) async throws -> TokenResponse? {
        var request = URLRequest(url: accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode([
            "client_id": clientID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotOAuthError.invalidResponse
        }
        
        let body = String(data: data, encoding: .utf8) ?? ""
        
        // Check for error in form-encoded response
        if body.contains("error=") {
            if body.contains("authorization_pending") {
                return nil // Continue polling
            }
            if body.contains("expired_token") {
                throw CopilotOAuthError.tokenExpired
            }
            if body.contains("access_denied") {
                throw CopilotOAuthError.deviceFlowFailed("User denied access")
            }
            throw CopilotOAuthError.tokenExchangeFailed(body)
        }
        
        return parseTokenResponse(body)
    }
    
    // Step 4: Check Copilot subscription
    func checkSubscription(accessToken: String) async throws -> Bool {
        var request = URLRequest(url: subscriptionURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotOAuthError.invalidResponse
        }
        
        // 200 = has subscription, 404 = no subscription, 401 = bad token
        if httpResponse.statusCode == 200 {
            return true
        } else if httpResponse.statusCode == 404 {
            return false
        } else {
            throw CopilotOAuthError.subscriptionCheckFailed
        }
    }
    
    // Step 5: Refresh token (if GitHub Copilot supports it — many don't)
    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode([
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CopilotOAuthError.tokenExchangeFailed("Refresh failed")
        }
        
        let body = String(data: data, encoding: .utf8) ?? ""
        return parseTokenResponse(body)
    }
    
    // MARK: - Helpers
    
    private func parseDeviceFlowResponse(_ body: String) -> DeviceFlowResponse {
        // Parse form-encoded response: "device_code=abc&user_code=DEF&..."
        var params: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                params[key] = value
            }
        }
        
        return DeviceFlowResponse(
            deviceCode: params["device_code"] ?? "",
            userCode: params["user_code"] ?? "",
            verificationUri: params["verification_uri"] ?? "",
            expiresIn: Int(params["expires_in"] ?? "0") ?? 0,
            interval: Int(params["interval"] ?? "5") ?? 5
        )
    }
    
    private func parseTokenResponse(_ body: String) -> TokenResponse {
        var params: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                params[key] = value
            }
        }
        
        return TokenResponse(
            accessToken: params["access_token"] ?? "",
            tokenType: params["token_type"] ?? "bearer",
            scope: params["scope"] ?? "",
            refreshToken: params["refresh_token"],
            expiresIn: Int(params["expires_in"] ?? "0")
        )
    }
}
```

**Note:** GitHub's device flow returns form-encoded data, not JSON. The parsing above handles this. If GitHub's actual API returns JSON, adjust the parsing logic accordingly.

---

### Deliverable 2: OAuth Token Store (NEW FILE)

Create `Sources/WarpClone/CopilotTokenStore.swift`:

```swift
import Foundation
import Security

struct CopilotToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let expirationDate: Date?
    let scope: String
}

actor CopilotTokenStore {
    private let serviceName = "com.warpclone.copilot"
    private let accountName = "copilot_oauth"
    
    func save(_ token: CopilotToken) throws {
        let data = try JSONEncoder().encode(token)
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Save new
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainManager.KeychainError.unexpectedStatus(status)
        }
    }
    
    func load() throws -> CopilotToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainManager.KeychainError.unexpectedStatus(status)
        }
        
        guard let data = item as? Data else { return nil }
        return try JSONDecoder().decode(CopilotToken.self, from: data)
    }
    
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainManager.KeychainError.unexpectedStatus(status)
        }
    }
    
    var isTokenValid: Bool {
        get async throws {
            guard let token = try load() else { return false }
            if let expiration = token.expirationDate {
                return expiration > Date().addingTimeInterval(300) // 5 min buffer
            }
            return true // No expiration = assume valid
        }
    }
}
```

---

### Deliverable 3: Copilot Auth ViewModel (NEW FILE)

Create `Sources/WarpClone/CopilotAuthViewModel.swift`:

```swift
import Foundation

@MainActor
final class CopilotAuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var userCode: String = ""
    @Published var verificationUri: String = ""
    @Published var showDeviceCode = false
    @Published var errorMessage: String?
    @Published var userDisplayName: String?
    @Published var userAvatarURL: URL?
    @Published var hasSubscription = false
    
    private let oauthClient: CopilotOAuthClient
    private let tokenStore = CopilotTokenStore()
    private var pollingTask: Task<Void, Never>?
    
    // You need a GitHub OAuth app client ID. For development, you can create one at:
    // https://github.com/settings/applications/new
    // For production, use a GitHub App or OAuth App registered to your organization.
    init(clientID: String = "YOUR_CLIENT_ID_HERE") {
        self.oauthClient = CopilotOAuthClient(clientID: clientID)
        Task { await checkExistingToken() }
    }
    
    func login() {
        isLoading = true
        errorMessage = nil
        showDeviceCode = true
        
        pollingTask = Task { @MainActor in
            do {
                let deviceFlow = try await oauthClient.initiateDeviceFlow()
                userCode = deviceFlow.userCode
                verificationUri = deviceFlow.verificationUri
                
                // Open browser for user to enter code
                if let url = URL(string: deviceFlow.verificationUri) {
                    NSWorkspace.shared.open(url)
                }
                
                // Poll for token
                let token = try await oauthClient.pollForToken(
                    deviceCode: deviceFlow.deviceCode,
                    interval: deviceFlow.interval,
                    expiresIn: deviceFlow.expiresIn
                )
                
                // Check subscription
                hasSubscription = try await oauthClient.checkSubscription(accessToken: token.accessToken)
                
                // Save token
                let expiration = token.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
                let copilotToken = CopilotToken(
                    accessToken: token.accessToken,
                    refreshToken: token.refreshToken,
                    expirationDate: expiration,
                    scope: token.scope
                )
                try tokenStore.save(copilotToken)
                
                // Fetch user profile (optional)
                await fetchUserProfile(accessToken: token.accessToken)
                
                isLoggedIn = true
                showDeviceCode = false
                
            } catch {
                errorMessage = error.localizedDescription
                isLoggedIn = false
            }
            isLoading = false
        }
    }
    
    func logout() {
        pollingTask?.cancel()
        pollingTask = nil
        isLoggedIn = false
        userCode = ""
        verificationUri = ""
        userDisplayName = nil
        userAvatarURL = nil
        hasSubscription = false
        errorMessage = nil
        try? tokenStore.delete()
    }
    
    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
        isLoading = false
        showDeviceCode = false
        userCode = ""
        verificationUri = ""
    }
    
    private func checkExistingToken() async {
        do {
            if let token = try tokenStore.load() {
                let isValid = try await tokenStore.isTokenValid
                if isValid {
                    isLoggedIn = true
                    hasSubscription = try await oauthClient.checkSubscription(accessToken: token.accessToken)
                    await fetchUserProfile(accessToken: token.accessToken)
                } else {
                    // Token expired, try refresh
                    if let refreshToken = token.refreshToken {
                        let newToken = try await oauthClient.refreshToken(refreshToken: refreshToken)
                        let expiration = newToken.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
                        let copilotToken = CopilotToken(
                            accessToken: newToken.accessToken,
                            refreshToken: newToken.refreshToken,
                            expirationDate: expiration,
                            scope: newToken.scope
                        )
                        try tokenStore.save(copilotToken)
                        isLoggedIn = true
                        hasSubscription = try await oauthClient.checkSubscription(accessToken: newToken.accessToken)
                    } else {
                        try tokenStore.delete()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchUserProfile(accessToken: String) async {
        // Fetch user profile from GitHub API
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                userDisplayName = json["login"] as? String
                if let avatarUrl = json["avatar_url"] as? String {
                    userAvatarURL = URL(string: avatarUrl)
                }
            }
        } catch {
            // Non-critical
        }
    }
}
```

---

### Deliverable 4: Copilot API Client (NEW FILE)

Create `Sources/WarpClone/CopilotAPIClient.swift`:

```swift
import Foundation
import WarpCLICore

// Copilot uses a custom API endpoint that's not standard OpenAI
// It requires the Copilot token and has specific model names
struct CopilotAPIClient: AIProviderClient {
    let kind: AIProviderKind = .copilot
    
    private let tokenStore = CopilotTokenStore()
    private let baseURL = URL(string: "https://api.githubcopilot.com/chat/completions")!
    
    func availableModels(apiKey: String) async throws -> [AIModel] {
        // Copilot currently supports these models (as of 2024-2025):
        return [
            AIModel(id: "gpt-4o-copilot", name: "GPT-4o Copilot", provider: "copilot", contextWindow: 128000),
            AIModel(id: "claude-sonnet-copilot", name: "Claude Sonnet Copilot", provider: "copilot", contextWindow: 200000)
        ]
    }
    
    func complete(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        // Note: apiKey parameter is ignored for Copilot; we use the stored OAuth token
        guard let token = try tokenStore.load() else {
            throw ProviderError.missingAPIKey("copilot")
        }
        
        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "model": request.model,
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "stream": true
        ] as [String: Any]
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Use the existing SSE streaming function from AIProviders.swift
        return streamSSE(request: urlRequest)
    }
}
```

**Note:** If `streamSSE` is not accessible from `AIProviders.swift` (it's fileprivate), either:
1. Make it `public` in `AIProviders.swift`
2. Copy the SSE streaming logic into `CopilotAPIClient`
3. Or use the existing `OpenAICompatibleClient` with a custom base URL

---

### Deliverable 5: Settings UI for Copilot

Modify `SettingsView.swift` to add a Copilot login section in the AI settings panel.

**Add a new section in `aiSettings` (before or after the API key section):**

```swift
settingsCard("GitHub Copilot") {
    CopilotAuthSection()
        .environmentObject(copilotAuth) // You'll need to inject this
}
```

**Create `CopilotAuthSection` as a new view or inline:**

```swift
struct CopilotAuthSection: View {
    @StateObject private var viewModel = CopilotAuthViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoggedIn {
                // Logged in state
                HStack(spacing: 10) {
                    if let avatarURL = viewModel.userAvatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.secondary.opacity(0.2))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.userDisplayName ?? "GitHub User")
                            .font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.hasSubscription ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(viewModel.hasSubscription ? "Copilot Active" : "No Subscription")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Log Out") {
                        viewModel.logout()
                    }
                    .buttonStyle(.bordered)
                }
            } else if viewModel.showDeviceCode {
                // Device code display
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter this code on GitHub:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Text(viewModel.userCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(viewModel.userCode, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy code")
                    }
                    
                    Text("Waiting for authorization...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    ProgressView()
                        .controlSize(.small)
                    
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Logged out state
                HStack(spacing: 12) {
                    Image(systemName: "github.logo") // or use a custom SF Symbol
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GitHub Copilot")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Sign in with GitHub to use Copilot models.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.login()
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }
}
```

---

### Deliverable 6: Integration with AIProviderManager

#### 6.1 Add `.copilot` to `AIProviderKind`

In `AIProviderManager.swift` or `Models.swift`, add `.copilot` to the `AIProviderKind` enum:

```swift
enum AIProviderKind: String, CaseIterable, Identifiable {
    case openRouter = "openRouter"
    case openAICompatible = "openAI"
    case anthropic = "anthropic"
    case googleGemini = "google"
    case copilot = "copilot"  // NEW
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openRouter: return "OpenRouter"
        case .openAICompatible: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .googleGemini: return "Google Gemini"
        case .copilot: return "GitHub Copilot"  // NEW
        }
    }
    
    var keychainServiceName: String {
        "warpclone_\(rawValue)"
    }
}
```

#### 6.2 Register Copilot Client

In `AIProviderManager.init()`:

```swift
init(keychain: KeychainManager = KeychainManager()) {
    self.keychain = keychain
    self.clients = [
        .openAICompatible: OpenAICompatibleClient(),
        .anthropic: AnthropicClient(),
        .googleGemini: GeminiClient(),
        .openRouter: OpenRouterClient(),
        .copilot: CopilotAPIClient()  // NEW
    ]
}
```

#### 6.3 Handle Copilot in Model Loading

In `AIProviderManager.loadModels()`:

```swift
func loadModels(kind: AIProviderKind) async {
    // For Copilot, models are hardcoded — skip network fetch
    if kind == .copilot {
        await MainActor.run {
            self.selectedKind = kind
            self.models = [
                AIModel(id: "gpt-4o-copilot", name: "GPT-4o Copilot", provider: "copilot", contextWindow: 128000),
                AIModel(id: "claude-sonnet-copilot", name: "Claude Sonnet Copilot", provider: "copilot", contextWindow: 200000)
            ]
            self.isLoadingModels = false
            self.lastError = nil
        }
        return
    }
    
    // Existing code for other providers...
}
```

#### 6.4 Handle Copilot in `complete()`

In `AIProviderManager.complete()`:

```swift
func complete(kind: AIProviderKind, request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
    if kind == .copilot {
        // Copilot uses OAuth token, not API key from Keychain
        guard let client = clients[kind] else {
            throw ProviderError.unsupported(kind.rawValue)
        }
        return try await client.complete(request: request, apiKey: "")
    }
    
    // Existing code for other providers...
    guard let key = try keychain.read(service: serviceName(kind), account: "apiKey") else {
        throw ProviderError.missingAPIKey(kind.rawValue)
    }
    // ...
}
```

---

### Deliverable 7: Wire OAuth Callback

The `WarpCloneAppDelegate` already posts `NotificationCenter` when `warpclone://auth` is received. Wire a listener in `CopilotAuthViewModel` or `WarpCloneApp`:

```swift
// In CopilotAuthViewModel or a dedicated OAuth handler:
private var authCallbackCancellable: AnyCancellable?

init() {
    // ... existing init
    authCallbackCancellable = NotificationCenter.default
        .publisher(for: .warpCloneAuthCallback)
        .sink { [weak self] notification in
            guard let url = notification.object as? URL else { return }
            // The device flow doesn't use the URL callback; the polling handles it
            // But if we ever add web-based OAuth, we would handle it here
            self?.handleAuthCallback(url: url)
        }
}

private func handleAuthCallback(url: URL) {
    // Parse query parameters from the URL
    // For device flow, this is mostly a no-op since polling handles the token
    // But log it for debugging
    print("OAuth callback received: \(url)")
}
```

**Note:** For GitHub device flow, the user opens the browser manually and enters the code. The app doesn't receive a callback URL — it polls the token endpoint. The `warpclone://auth` URL scheme is more useful for web-based OAuth flows (Google, etc.). For Copilot device flow, the URL scheme is not strictly required but keep it for future use.

---

## Files to Create / Modify

| File | Action | Lines |
|---|---|---|
| `Sources/WarpClone/CopilotOAuthClient.swift` | **NEW** | ~250 lines |
| `Sources/WarpClone/CopilotTokenStore.swift` | **NEW** | ~80 lines |
| `Sources/WarpClone/CopilotAuthViewModel.swift` | **NEW** | ~150 lines |
| `Sources/WarpClone/CopilotAPIClient.swift` | **NEW** | ~60 lines |
| `Sources/WarpClone/SettingsView.swift` | **MODIFY** | Add Copilot auth section (~60 lines) |
| `Sources/WarpClone/AIProviderManager.swift` | **MODIFY** | Add `.copilot` case, register client (~20 lines) |
| `Sources/WarpClone/Models.swift` | **MODIFY** | Add `.copilot` to `AIProviderKind` (~5 lines) |
| `Sources/WarpClone/WarpCloneApp.swift` | **VERIFY** | URL scheme handler already exists |
| `Sources/WarpClone/Info.plist` | **VERIFY** | URL scheme already registered |

## Testing Requirements

1. `swift build` compiles with zero errors
2. `swift test` still passes all 23 tests
3. Settings → AI shows a "GitHub Copilot" section with a "Sign In" button
4. Clicking "Sign In" shows a device code and opens the browser
5. Entering the device code on GitHub and authorizing causes the app to receive a token
6. After login, the section shows the GitHub username, avatar, and "Copilot Active" status
7. The model picker shows "GPT-4o Copilot" and "Claude Sonnet Copilot" when Copilot is selected as provider
8. Typing `# hello` with Copilot selected streams a response using the Copilot token
9. Logging out removes the token from Keychain and resets the UI

## Build Verification

```bash
cd /Users/rihan/Documents/MAC-OS-TERMINAL
swift build
swift test
```

## Important Notes

- **You need a GitHub OAuth App client ID** to test this. Create one at https://github.com/settings/applications/new. Set the authorization callback URL to `warpclone://auth`. For the beta, you can use a placeholder client ID and document that users need to create their own.
- **Copilot API endpoint:** The actual Copilot API endpoint may differ from `https://api.githubcopilot.com/chat/completions`. The prompt uses the most common endpoint based on public documentation. Verify the actual endpoint when testing.
- **Device flow vs. web flow:** GitHub device flow is used here because it's the most reliable for native apps. The user opens the browser, enters the code, and authorizes. The app polls for the token in the background.
- **Subscription check:** The Copilot subscription check uses `https://api.github.com/user/copilot`. If this endpoint doesn't exist or returns different status codes, adjust the logic.
- **Token refresh:** GitHub OAuth tokens typically don't expire (or expire after a long time). The refresh logic is included for completeness but may not be triggered often.
- **Form-encoded responses:** GitHub's OAuth device flow returns form-encoded data (`key=value&key=value`), not JSON. The parsing logic in `CopilotOAuthClient` handles this. If GitHub changes the format, adjust accordingly.
- **Make `streamSSE` accessible:** If the SSE streaming function in `AIProviders.swift` is fileprivate, you need to either make it `public` or duplicate the logic in `CopilotAPIClient`. Check `AIProviders.swift` before starting.
- **All code must compile.** Do not leave any placeholder text like `YOUR_CLIENT_ID_HERE` in the final code — use an empty string or a default value, and document that the user needs to set it.

## Constraints

- Do NOT modify the `PermissionGate` or security infrastructure
- Do NOT change the `PTYSession` or terminal core
- Do NOT break existing BYOK providers (OpenRouter, OpenAI, Anthropic, Google)
- Focus ONLY on the Copilot OAuth flow and its integration
- Make reasonable assumptions and complete the implementation
- All code must compile
- If a GitHub OAuth App is not available, use a placeholder client ID and document the setup steps
