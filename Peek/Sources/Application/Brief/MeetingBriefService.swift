import Foundation
import EventKit

/// Prepares and remembers meeting briefs (phase 3). A brief from the context
/// folder always wins and calls no model; otherwise the engine the user chose
/// writes one, automatically shortly before the meeting or on request.
final class MeetingBriefService: ObservableObject {
    static let shared = MeetingBriefService()

    enum Keys {
        static let enabled = "briefEnabled"
        static let engine = "briefEngine"
        static let excludedKeywords = "briefExcludedKeywords"
        static let cloudConsentVersion = "briefCloudConsentVersion"
    }

    /// Bump when the fields sent to a cloud model change, so the user consents again.
    static let currentCloudConsentVersion = 1
    /// After a failure, wait this long before trying the same meeting again.
    static let retryDelay: TimeInterval = 10 * 60

    enum EngineChoice: String, CaseIterable {
        case onDevice
        case cloud

        var displayName: String {
            switch self {
            case .onDevice:
                return NSLocalizedString("On this Mac", comment: "Brief engine: Apple on-device model")
            case .cloud:
                return NSLocalizedString("Claude (your API key)", comment: "Brief engine: Claude with the user's key")
            }
        }
    }

    @Published private(set) var briefs: [String: MeetingBrief]
    @Published private(set) var inFlight: Set<String> = []
    @Published private(set) var errors: [String: String] = [:]

    private let defaults: UserDefaults
    private let cache: BriefCacheStore
    private let onDevice: BriefEngine
    private let cloud: BriefEngine
    private var lastFailure: [String: Date] = [:]

    init(
        defaults: UserDefaults = .standard,
        cache: BriefCacheStore = .shared,
        onDevice: BriefEngine = OnDeviceBriefEngine(),
        cloud: BriefEngine = ClaudeBriefEngine()
    ) {
        self.defaults = defaults
        self.cache = cache
        self.onDevice = onDevice
        self.cloud = cloud
        self.briefs = cache.load()
    }

    // MARK: Settings

    var isEnabled: Bool { defaults.bool(forKey: Keys.enabled) }

    var engineChoice: EngineChoice {
        defaults.string(forKey: Keys.engine).flatMap(EngineChoice.init(rawValue:)) ?? .onDevice
    }

    var hasCloudConsent: Bool {
        defaults.integer(forKey: Keys.cloudConsentVersion) >= Self.currentCloudConsentVersion
    }

    var excludedKeywords: [String] {
        EventFilterSettings.parseKeywords(defaults.string(forKey: Keys.excludedKeywords) ?? "")
    }

    /// The engine Peek would use now, or nil when cloud is chosen without consent.
    var activeEngine: BriefEngine? {
        switch engineChoice {
        case .onDevice: return onDevice
        case .cloud: return hasCloudConsent ? cloud : nil
        }
    }

    func availability(of choice: EngineChoice) -> BriefEngineAvailability {
        switch choice {
        case .onDevice: return onDevice.availability()
        case .cloud: return cloud.availability()
        }
    }

    /// Turning briefs off forgets every generated brief.
    func setEnabled(_ enabled: Bool) {
        objectWillChange.send()
        defaults.set(enabled, forKey: Keys.enabled)
        if !enabled { clearGenerated() }
    }

    /// Choosing the cloud engine needs the consent screen first; the caller
    /// shows it and passes the answer.
    func setEngine(_ choice: EngineChoice, consented: Bool = false) {
        objectWillChange.send()
        if choice == .cloud {
            guard consented || hasCloudConsent else { return }
            defaults.set(Self.currentCloudConsentVersion, forKey: Keys.cloudConsentVersion)
        }
        defaults.set(choice.rawValue, forKey: Keys.engine)
        errors = [:]
        lastFailure = [:]
    }

    func setExcludedKeywords(_ value: String) {
        objectWillChange.send()
        defaults.set(value, forKey: Keys.excludedKeywords)
    }

    var excludedKeywordsText: String { defaults.string(forKey: Keys.excludedKeywords) ?? "" }

    /// Call after the API key changes, so the views and the retry timer notice.
    func keyDidChange() {
        objectWillChange.send()
        errors = [:]
        lastFailure = [:]
    }

    func clearGenerated() {
        briefs = [:]
        errors = [:]
        lastFailure = [:]
        cache.clear()
    }

    // MARK: Briefs

    static func key(for event: EKEvent) -> String {
        "\(CalendarExportEventMapper.stableIdentifier(for: event))@\(Int(event.startDate.timeIntervalSince1970))"
    }

    func input(for event: EKEvent) -> BriefInput {
        BriefInput(title: event.title, start: event.startDate, context: MeetingContextProvider.context(for: event))
    }

    /// The brief to show for an event, if any. A brief from the context folder
    /// is shown even with AI briefs off, since no model is involved.
    func brief(for event: EKEvent) -> MeetingBrief? {
        let input = input(for: event)
        if let fromFolder = BriefPolicy.contextFolderBrief(for: input, generatedAt: Date()) {
            return fromFolder
        }
        guard isEnabled, let stored = briefs[Self.key(for: event)] else { return nil }
        // An edited event (new agenda, new people) invalidates its brief.
        return stored.fingerprint == BriefPrompt.fingerprint(for: input, source: stored.source) ? stored : nil
    }

    func isEligible(_ event: EKEvent) -> Bool {
        BriefPolicy.isEligible(
            input: input(for: event),
            notes: event.notes,
            isAllDay: event.isAllDay,
            isDeclined: event.isCurrentUserDeclined,
            excludedKeywords: excludedKeywords
        )
    }

    /// Whether a "Prepare brief" action makes sense for this event right now.
    func canPrepare(_ event: EKEvent) -> Bool {
        guard isEnabled, event.endDate > Date(), let engine = activeEngine, engine.availability().isAvailable else { return false }
        return brief(for: event) == nil && isEligible(event)
    }

    func isPreparing(_ event: EKEvent) -> Bool {
        inFlight.contains(Self.key(for: event))
    }

    func error(for event: EKEvent) -> String? {
        errors[Self.key(for: event)]
    }

    /// Called on every status-bar tick for the next event.
    func prepareIfDue(for event: EKEvent, now: Date = Date()) {
        guard isEnabled, BriefPolicy.isDue(start: event.startDate, now: now) else { return }
        let key = Self.key(for: event)
        if let failed = lastFailure[key], now.timeIntervalSince(failed) < Self.retryDelay { return }
        guard !inFlight.contains(key), canPrepare(event) else { return }
        prepare(event)
    }

    func prepare(_ event: EKEvent) {
        guard let engine = activeEngine else { return }
        let key = Self.key(for: event)
        guard !inFlight.contains(key) else { return }
        let input = input(for: event)
        let instructions = BriefPrompt.instructions(language: Self.briefLanguage())
        let prompt = BriefPrompt.prompt(for: input)
        let fingerprint = BriefPrompt.fingerprint(for: input, source: engine.source)

        inFlight.insert(key)
        errors[key] = nil
        Task {
            let outcome: Result<[String], BriefError>
            do {
                let text = try await engine.generate(instructions: instructions, prompt: prompt)
                let points = BriefParser.points(from: text)
                outcome = points.isEmpty ? .failure(.emptyResponse) : .success(points)
            } catch let error as BriefError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.network)
            }
            await MainActor.run {
                self.finish(key: key, outcome: outcome, source: engine.source, fingerprint: fingerprint)
            }
        }
    }

    private func finish(key: String, outcome: Result<[String], BriefError>, source: BriefSource, fingerprint: String) {
        inFlight.remove(key)
        switch outcome {
        case .success(let points):
            briefs[key] = MeetingBrief(points: points, source: source, generatedAt: Date(), fingerprint: fingerprint)
            lastFailure[key] = nil
            cache.save(briefs)
        case .failure(let error):
            errors[key] = error.message
            lastFailure[key] = Date()
        }
    }

    /// English name of the app's current language, for the model instructions.
    static func briefLanguage(bundle: Bundle = .main) -> String {
        let code = bundle.preferredLocalizations.first ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }
}

private extension EKEvent {
    var isCurrentUserDeclined: Bool {
        attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }
}
