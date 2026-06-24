import AppKit
import Foundation

enum CopilotOAuthError: Error, LocalizedError {
    case invalidClientID
    case deviceFlowFailed(String)
    case tokenExchangeFailed(String)
    case subscriptionCheckFailed
    case tokenExpired
    case accessDenied
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidClientID:
            return "GitHub OAuth client ID is not configured."
        case .deviceFlowFailed(let message):
            return "Device flow failed: \(message)"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .subscriptionCheckFailed:
            return "GitHub Copilot subscription check failed."
        case .tokenExpired:
            return "Copilot token expired. Please sign in again."
        case .accessDenied:
            return "GitHub authorization was denied."
        case .invalidResponse:
            return "Invalid response from GitHub."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct DeviceFlowResponse: Codable, Equatable {
    var deviceCode: String
    var userCode: String
    var verificationUri: String
    var expiresIn: Int
    var interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct CopilotTokenResponse: Codable, Equatable {
    var accessToken: String
    var tokenType: String
    var scope: String
    var refreshToken: String?
    var expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

final class CopilotOAuthClient {
    static var configuredClientID: String? {
        if let bundleValue = Bundle.main.object(forInfoDictionaryKey: "GitHubOAuthClientID") as? String,
           !bundleValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleValue
        }
        let envValue = ProcessInfo.processInfo.environment["WARPCLONE_GITHUB_CLIENT_ID"] ?? ""
        let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private let clientID: String
    private let session: URLSession
    private let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    private let copilotSubscriptionURL = URL(string: "https://api.github.com/user/copilot")!

    init(clientID: String? = CopilotOAuthClient.configuredClientID, session: URLSession = .shared) {
        self.clientID = clientID ?? ""
        self.session = session
    }

    func initiateDeviceFlow() async throws -> DeviceFlowResponse {
        guard !clientID.isEmpty else { throw CopilotOAuthError.invalidClientID }

        var request = URLRequest(url: deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": clientID,
            "scope": "read:user"
        ])

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            if let json = try? JSONDecoder().decode(DeviceFlowResponse.self, from: data) {
                return json
            }
            return try parseDeviceFlowResponse(String(data: data, encoding: .utf8) ?? "")
        } catch let error as CopilotOAuthError {
            throw error
        } catch {
            throw CopilotOAuthError.networkError(error)
        }
    }

    func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> CopilotTokenResponse {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        var pollInterval = max(interval, 1)

        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)

            do {
                if let token = try await exchangeToken(deviceCode: deviceCode) {
                    return token
                }
            } catch CopilotOAuthError.deviceFlowFailed(let message) where message == "slow_down" {
                pollInterval += 5
            } catch CopilotOAuthError.deviceFlowFailed(let message) where message == "authorization_pending" {
                continue
            }
        }

        throw CopilotOAuthError.tokenExpired
    }

    func exchangeToken(deviceCode: String) async throws -> CopilotTokenResponse? {
        guard !clientID.isEmpty else { throw CopilotOAuthError.invalidClientID }

        var request = URLRequest(url: accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": clientID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let token = try? JSONDecoder().decode(CopilotTokenResponse.self, from: data) {
            return token
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        let params = parseURLEncoded(body)
        if let error = params["error"] {
            switch error {
            case "authorization_pending":
                return nil
            case "slow_down":
                throw CopilotOAuthError.deviceFlowFailed("slow_down")
            case "expired_token":
                throw CopilotOAuthError.tokenExpired
            case "access_denied":
                throw CopilotOAuthError.accessDenied
            default:
                throw CopilotOAuthError.tokenExchangeFailed(error)
            }
        }

        return try parseTokenResponse(body)
    }

    func checkSubscription(accessToken: String) async throws -> Bool {
        var request = URLRequest(url: copilotSubscriptionURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotOAuthError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return true
        case 401:
            throw CopilotOAuthError.tokenExpired
        case 404:
            return false
        default:
            throw CopilotOAuthError.subscriptionCheckFailed
        }
    }

    private func parseDeviceFlowResponse(_ body: String) throws -> DeviceFlowResponse {
        let params = parseURLEncoded(body)
        guard let deviceCode = params["device_code"],
              let userCode = params["user_code"],
              let verificationUri = params["verification_uri"] else {
            throw CopilotOAuthError.invalidResponse
        }
        return DeviceFlowResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationUri: verificationUri,
            expiresIn: Int(params["expires_in"] ?? "900") ?? 900,
            interval: Int(params["interval"] ?? "5") ?? 5
        )
    }

    private func parseTokenResponse(_ body: String) throws -> CopilotTokenResponse {
        let params = parseURLEncoded(body)
        guard let accessToken = params["access_token"] else {
            throw CopilotOAuthError.invalidResponse
        }
        return CopilotTokenResponse(
            accessToken: accessToken,
            tokenType: params["token_type"] ?? "bearer",
            scope: params["scope"] ?? "",
            refreshToken: params["refresh_token"],
            expiresIn: Int(params["expires_in"] ?? "")
        )
    }

    private func parseURLEncoded(_ body: String) -> [String: String] {
        body.split(separator: "&").reduce(into: [String: String]()) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return }
            result[parts[0].removingPercentEncoding ?? parts[0]] = parts[1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? parts[1]
        }
    }

    private func formBody(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotOAuthError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CopilotOAuthError.deviceFlowFailed(message)
        }
    }
}
