import AppKit
import Foundation

@MainActor
final class CopilotAuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var showDeviceCode = false
    @Published var userCode = ""
    @Published var verificationUri = ""
    @Published var errorMessage: String?
    @Published var userDisplayName = ""
    @Published var userAvatarURL: URL?

    private let oauthClient: CopilotOAuthClient
    private let tokenStore: CopilotTokenStore
    private var pollingTask: Task<Void, Never>?

    init(
        oauthClient: CopilotOAuthClient = CopilotOAuthClient(),
        tokenStore: CopilotTokenStore = CopilotTokenStore()
    ) {
        self.oauthClient = oauthClient
        self.tokenStore = tokenStore
        checkExistingToken()
    }

    deinit {
        pollingTask?.cancel()
    }

    func checkExistingToken() {
        do {
            guard let token = try tokenStore.load(), !token.isExpired else {
                isLoggedIn = false
                return
            }
            isLoggedIn = true
            Task { await refreshProfile(accessToken: token.accessToken) }
        } catch {
            errorMessage = error.localizedDescription
            isLoggedIn = false
        }
    }

    func login() {
        pollingTask?.cancel()
        errorMessage = nil
        isLoading = true
        showDeviceCode = false

        pollingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let deviceFlow = try await oauthClient.initiateDeviceFlow()
                userCode = deviceFlow.userCode
                verificationUri = deviceFlow.verificationUri
                showDeviceCode = true

                if let url = URL(string: deviceFlow.verificationUri) {
                    NSWorkspace.shared.open(url)
                }

                let token = try await oauthClient.pollForToken(
                    deviceCode: deviceFlow.deviceCode,
                    interval: deviceFlow.interval,
                    expiresIn: deviceFlow.expiresIn
                )

                let hasSubscription = try await oauthClient.checkSubscription(accessToken: token.accessToken)
                guard hasSubscription else {
                    throw CopilotOAuthError.subscriptionCheckFailed
                }

                let expiration = token.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
                try tokenStore.save(CopilotToken(
                    accessToken: token.accessToken,
                    refreshToken: token.refreshToken,
                    expirationDate: expiration,
                    scope: token.scope
                ))

                isLoggedIn = true
                isLoading = false
                showDeviceCode = false
                await refreshProfile(accessToken: token.accessToken)
            } catch is CancellationError {
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                showDeviceCode = false
            }
        }
    }

    func logout() {
        pollingTask?.cancel()
        pollingTask = nil
        do {
            try tokenStore.delete()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoggedIn = false
        isLoading = false
        showDeviceCode = false
        userCode = ""
        verificationUri = ""
        userDisplayName = ""
        userAvatarURL = nil
    }

    func copyUserCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(userCode, forType: .string)
    }

    private func refreshProfile(accessToken: String) async {
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            userDisplayName = json["login"] as? String ?? "GitHub"
            if let avatar = json["avatar_url"] as? String {
                userAvatarURL = URL(string: avatar)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
