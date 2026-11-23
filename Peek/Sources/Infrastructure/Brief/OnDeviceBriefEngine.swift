import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device language model (PEEK-221). Needs macOS 26 on a Mac with
/// Apple Intelligence turned on; elsewhere it reports why it is unavailable.
/// Nothing leaves the Mac.
final class OnDeviceBriefEngine: BriefEngine {
    let source: BriefSource = .onDevice

    func availability() -> BriefEngineAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable(NSLocalizedString("This Mac doesn't support Apple Intelligence.", comment: "On-device brief: device not eligible"))
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(NSLocalizedString("Turn on Apple Intelligence in System Settings to use on-device briefs.", comment: "On-device brief: Apple Intelligence off"))
            case .unavailable(.modelNotReady):
                return .unavailable(NSLocalizedString("Apple Intelligence is still getting ready. Try again later.", comment: "On-device brief: model not ready"))
            default:
                return .unavailable(NSLocalizedString("Apple Intelligence isn't available right now.", comment: "On-device brief: other reason"))
            }
        }
        #endif
        return .unavailable(NSLocalizedString("On-device briefs need macOS 26 with Apple Intelligence.", comment: "On-device brief: OS too old"))
    }

    func generate(instructions: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { throw BriefError.engineUnavailable }
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(to: prompt)
                return response.content
            } catch {
                // Guardrail and context-size failures surface as a refusal to
                // brief this meeting rather than a broken feature.
                throw BriefError.refused
            }
        }
        #endif
        throw BriefError.engineUnavailable
    }
}
