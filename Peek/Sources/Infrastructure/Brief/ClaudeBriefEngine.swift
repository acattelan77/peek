import Foundation
import Security

/// Stores the user's Anthropic API key in the login keychain. The key never
/// goes into UserDefaults, logs or the brief cache.
enum AnthropicKeyStore {
    private static let service = "Peek Anthropic API key"
    private static let account = "default"

    static var hasKey: Bool { read() != nil }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        delete()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(trimmed.utf8)
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Claude through the Messages API with the user's own key (PEEK-222). Used
/// only after the user picked it and accepted the consent screen (PEEK-223).
final class ClaudeBriefEngine: BriefEngine {
    let source: BriefSource = .cloud

    static let model = "claude-opus-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private let session: URLSession
    private let apiKey: () -> String?

    init(session: URLSession = .shared, apiKey: @escaping () -> String? = AnthropicKeyStore.read) {
        self.session = session
        self.apiKey = apiKey
    }

    func availability() -> BriefEngineAvailability {
        apiKey() == nil
            ? .unavailable(NSLocalizedString("Add your Anthropic API key to use Claude.", comment: "Cloud brief: no key"))
            : .available
    }

    func generate(instructions: String, prompt: String) async throws -> String {
        guard let key = apiKey() else { throw BriefError.missingAPIKey }
        let request = try Self.makeRequest(apiKey: key, instructions: instructions, prompt: prompt)
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw BriefError.network
        }
        let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.parse(status: status, body: result.0)
    }

    static func makeRequest(apiKey: String, instructions: String, prompt: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // On a policy decline the API reruns the request on a fallback model.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": instructions,
            "output_config": ["effort": "low"],
            "fallbacks": "default",
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Maps the Messages API response to the brief text, or a typed error.
    static func parse(status: Int, body: Data) throws -> String {
        switch status {
        case 200:
            break
        case 401, 403:
            throw BriefError.invalidAPIKey
        case 429:
            throw BriefError.rateLimited
        default:
            throw BriefError.service(status)
        }
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw BriefError.emptyResponse
        }
        if json["stop_reason"] as? String == "refusal" { throw BriefError.refused }
        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BriefError.emptyResponse }
        return text
    }
}
