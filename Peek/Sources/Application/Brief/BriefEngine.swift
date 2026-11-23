import Foundation

/// A model that turns a brief prompt into text. Implementations: Apple's
/// on-device model (PEEK-221) and Claude with the user's API key (PEEK-222).
protocol BriefEngine {
    var source: BriefSource { get }
    func availability() -> BriefEngineAvailability
    func generate(instructions: String, prompt: String) async throws -> String
}

enum BriefEngineAvailability: Equatable {
    case available
    case unavailable(String)

    var isAvailable: Bool { self == .available }

    var message: String? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

enum BriefError: Error, Equatable {
    case engineUnavailable
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case refused
    case emptyResponse
    case service(Int)
    case network

    var message: String {
        switch self {
        case .engineUnavailable:
            return NSLocalizedString("The brief engine isn't available on this Mac.", comment: "Brief error: engine unavailable")
        case .missingAPIKey:
            return NSLocalizedString("Add your Anthropic API key in Preferences.", comment: "Brief error: no API key")
        case .invalidAPIKey:
            return NSLocalizedString("Anthropic rejected the API key. Check it in Preferences.", comment: "Brief error: invalid API key")
        case .rateLimited:
            return NSLocalizedString("Too many requests right now. Peek will try again later.", comment: "Brief error: rate limited")
        case .refused:
            return NSLocalizedString("The model declined to write a brief for this meeting.", comment: "Brief error: refusal")
        case .emptyResponse:
            return NSLocalizedString("The model returned no usable points.", comment: "Brief error: empty response")
        case .service(let status):
            return String(format: NSLocalizedString("The brief service returned an error (%d).", comment: "Brief error: HTTP status"), status)
        case .network:
            return NSLocalizedString("Couldn't reach the brief service. Check your connection.", comment: "Brief error: network")
        }
    }
}
