import Foundation
import Contacts

/// Contacts adapter for meeting context (PEEK-211). Lookups never prompt:
/// they return `nil` until the user grants access from Preferences.
final class SystemContactsDirectory: ContactLookup {
    static let shared = SystemContactsDirectory()

    private let store = CNContactStore()
    private let lock = NSLock()
    private var cache: [String: ContactCard?] = [:]

    private static let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    var isDenied: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        return status == .denied || status == .restricted
    }

    /// Asks for Contacts access; call only from an explicit user action.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestAccess(for: .contacts) { [weak self] granted, _ in
            self?.clearCache()
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    func card(forEmail email: String) -> ContactCard? {
        guard isAuthorized else { return nil }
        let key = email.lowercased()
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let predicate = CNContact.predicateForContacts(matchingEmailAddress: key)
        let contact = (try? store.unifiedContacts(matching: predicate, keysToFetch: Self.keys))?.first
        let card = contact.map {
            ContactCard(
                givenName: $0.givenName,
                fullName: CNContactFormatter.string(from: $0, style: .fullName),
                jobTitle: $0.jobTitle,
                organization: $0.organizationName
            )
        }

        lock.lock()
        cache[key] = .some(card)
        lock.unlock()
        return card
    }
}
