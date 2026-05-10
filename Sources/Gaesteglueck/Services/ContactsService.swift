#if canImport(Contacts)
import Foundation
import Contacts

struct ContactMatch: Identifiable, Hashable, Sendable {
    let id: String
    let givenName: String
    let familyName: String
    let organization: String
    let phoneNumbers: [String]

    var displayName: String {
        let full = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        if !full.isEmpty { return full }
        if !organization.isEmpty { return organization }
        return "(ohne Namen)"
    }
}

enum ContactsServiceError: Error, LocalizedError {
    case accessDenied
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Kein Zugriff auf Kontakte. In Systemeinstellungen → Datenschutz → Kontakte erlauben."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

enum ContactsService {
    static func requestAccess() async throws -> Bool {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return true
        case .denied, .restricted:
            throw ContactsServiceError.accessDenied
        case .notDetermined:
            do {
                return try await store.requestAccess(for: .contacts)
            } catch {
                throw ContactsServiceError.underlying(error)
            }
        @unknown default:
            return false
        }
    }

    static func search(firstName: String, lastName: String) throws -> [ContactMatch] {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey,
            CNContactMiddleNameKey,
            CNContactFamilyNameKey,
            CNContactNicknameKey,
            CNContactOrganizationNameKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)

        // Strategie: Apples predicateForContacts(matchingName:) tokenisiert
        // streng — "Horst Maier" findet "Horst G. Maier" nicht zuverlaessig.
        // Wir suchen auf dem laengeren Namensteil (Nachname bevorzugt) und
        // filtern client-seitig case-insensitive nach dem anderen Teil.
        let primary = !trimmedLast.isEmpty ? trimmedLast : trimmedFirst
        guard !primary.isEmpty else { return [] }

        do {
            let predicate = CNContact.predicateForContacts(matchingName: primary)
            var contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

            // Fallback: wenn Nachname-Suche nichts liefert, Vornamen probieren.
            if contacts.isEmpty, !trimmedLast.isEmpty, !trimmedFirst.isEmpty {
                let fallback = CNContact.predicateForContacts(matchingName: trimmedFirst)
                contacts = try store.unifiedContacts(matching: fallback, keysToFetch: keys)
            }

            let filtered = contacts.filter { c in
                guard !c.phoneNumbers.isEmpty else { return false }
                if !trimmedFirst.isEmpty, !nameComponentMatches(c, needle: trimmedFirst) {
                    return false
                }
                if !trimmedLast.isEmpty, !nameComponentMatches(c, needle: trimmedLast) {
                    return false
                }
                return true
            }

            return filtered.map { c in
                ContactMatch(
                    id: c.identifier,
                    givenName: c.givenName,
                    familyName: c.familyName,
                    organization: c.organizationName,
                    phoneNumbers: c.phoneNumbers.map { $0.value.stringValue }
                )
            }
        } catch {
            throw ContactsServiceError.underlying(error)
        }
    }

    private static func nameComponentMatches(_ c: CNContact, needle: String) -> Bool {
        let haystack = [c.givenName, c.middleName, c.familyName, c.nickname]
            .joined(separator: " ")
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
#endif
