#if os(macOS)
#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import SwiftData
import AppKit

/// Telefon-Tab der Export-Vorschau samt Kontakt-Abgleich. Der Verify-Status
/// und die Mismatch-Queue liegen als Binding im Parent (`ExportView`), damit
/// die Abgleich-Ergebnisse einen Tab-Wechsel überleben — der Subview selbst
/// wird beim Tab-Wechsel verworfen.
struct ExportPhonePreview: View {
    @Query(sort: \Guest.firstName) private var guests: [Guest]

    @Binding var phoneVerify: [UUID: PhoneVerifyStatus]
    @Binding var phoneVerifyRunning: Bool
    @Binding var phoneVerifyError: String?
    @Binding var mismatchQueue: [PendingMismatch]
    private var pendingMismatchBinding: Binding<PendingMismatch?> {
        Binding(
            get: { mismatchQueue.first },
            set: { _ in }
        )
    }

    enum PhoneVerifyStatus: Equatable {
        case verified(contactName: String)
        case nameMismatch(contactName: String)
        case notFound
        case failed(String)
    }

    struct PendingMismatch: Identifiable {
        let id: UUID
        let guest: Guest
        let suggestedName: String
    }

    var body: some View {
        let stats = phoneCoverage(for: guests.filter(\.countsForSeating))

        VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Telefonnummern")
                        .font(.title2.bold())
                    Text("**\(stats.coveredRegistrations) von \(stats.totalRegistrations) Anmeldungen** haben mindestens eine Nummer (\(stats.guestsWithPhone) von \(stats.totalGuests) Gaesten).")
                        .foregroundStyle(.secondary)
                    Text("Rechts unter 'Was exportieren' das Haekchen bei 'Telefonnummern (vCard)' setzen und dann auf 'Exportieren'. Die .vcf laesst sich von der Trauzeugin in die Kontakte importieren — daraus dann in einem Rutsch eine WhatsApp-Gruppe.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !stats.openRegistrations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anmeldungen ohne Nummer (\(stats.openRegistrations.count))")
                            .font(.headline)
                        Text("Eine Nummer pro Anmeldung reicht — diese Gruppen brauchen noch jemanden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(stats.openRegistrations, id: \.self) { names in
                            Text(names)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !stats.withPhone.isEmpty {
                    phoneVerifySection(guests: stats.withPhone)
                }
        }
        .padding(24)
        .alert(item: pendingMismatchBinding) { mismatch in
            Alert(
                title: Text("Name aus Kontakten übernehmen?"),
                message: Text("Hier ist '\(mismatch.guest.fullName)' hinterlegt, in deinen Kontakten heisst die Nummer '\(mismatch.suggestedName)'."),
                primaryButton: .default(Text("Übernehmen")) {
                    applySuggestedName(mismatch.suggestedName, to: mismatch.guest)
                    phoneVerify[mismatch.guest.id] = .verified(contactName: mismatch.suggestedName)
                    dequeueMismatch()
                },
                secondaryButton: .cancel(Text("Behalten")) {
                    phoneVerify[mismatch.guest.id] = .nameMismatch(contactName: mismatch.suggestedName)
                    dequeueMismatch()
                }
            )
        }
    }

    @ViewBuilder
    private func phoneVerifySection(guests: [Guest]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mit Nummer (\(guests.count))").font(.headline)
                Spacer()
                Button {
                    Task { await verifyAllPhones(guests) }
                } label: {
                    if phoneVerifyRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Mit Kontakten abgleichen", systemImage: "person.crop.circle.badge.checkmark")
                    }
                }
                .disabled(phoneVerifyRunning)
            }
            if let err = phoneVerifyError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            ForEach(guests) { guest in
                HStack(spacing: 8) {
                    phoneVerifyIcon(for: guest)
                    Text(guest.fullName)
                    Spacer()
                    Text(PhoneFormatter.display(guest.phoneNumber))
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func phoneVerifyIcon(for guest: Guest) -> some View {
        switch phoneVerify[guest.id] {
        case .verified:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .nameMismatch:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .notFound:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "xmark.circle").foregroundStyle(.red)
        case .none:
            Image(systemName: "circle.dashed").foregroundStyle(.secondary.opacity(0.5))
        }
    }

    private func verifyAllPhones(_ guests: [Guest]) async {
        phoneVerifyError = nil
        phoneVerifyRunning = true
        defer { phoneVerifyRunning = false }
        do {
            guard try await ContactsService.requestAccess() else {
                phoneVerifyError = "Kein Zugriff auf Kontakte erteilt."
                return
            }
        } catch {
            phoneVerifyError = error.localizedDescription
            return
        }
        let index: [String: ContactMatch]
        do {
            index = try ContactsService.indexByPhone()
        } catch {
            phoneVerifyError = error.localizedDescription
            return
        }
        var queued: [PendingMismatch] = []
        for guest in guests {
            let result = lookupContact(for: guest, in: index)
            phoneVerify[guest.id] = result
            if case .nameMismatch(let suggested) = result {
                queued.append(PendingMismatch(id: guest.id, guest: guest, suggestedName: suggested))
            }
        }
        mismatchQueue = queued
    }

    private func lookupContact(for guest: Guest, in index: [String: ContactMatch]) -> PhoneVerifyStatus {
        let key = PhoneFormatter.normalize(guest.phoneNumber)
        guard !key.isEmpty, let match = index[key] else { return .notFound }
        return matchesGuestName(guest: guest, contact: match)
            ? .verified(contactName: match.displayName)
            : .nameMismatch(contactName: match.displayName)
    }

    private func dequeueMismatch() {
        if !mismatchQueue.isEmpty { mismatchQueue.removeFirst() }
    }

    private func matchesGuestName(guest: Guest, contact: ContactMatch) -> Bool {
        func fold(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespaces)
        }
        let guestFirst = fold(guest.firstName)
        let firstOK = [contact.givenName, contact.nickname]
            .filter { !$0.isEmpty }
            .contains { fold($0) == guestFirst }
        guard firstOK else { return false }
        if guest.lastName.isEmpty || contact.familyName.isEmpty { return true }
        return fold(contact.familyName) == fold(guest.lastName)
    }

    private func applySuggestedName(_ suggested: String, to guest: Guest) {
        let parts = suggested.split(separator: " ", maxSplits: 1).map(String.init)
        guard let first = parts.first else { return }
        guest.firstName = first
        guest.lastName = parts.count > 1 ? parts[1] : ""
    }

    private struct PhoneCoverage {
        let totalGuests: Int
        let guestsWithPhone: Int
        let totalRegistrations: Int
        let coveredRegistrations: Int
        let openRegistrations: [String]
        let withPhone: [Guest]
    }

    private func phoneCoverage(for guests: [Guest]) -> PhoneCoverage {
        func hasPhone(_ g: Guest) -> Bool {
            !g.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
        }

        // Gruppen-Bucket: registrationGroup oder fallback auf eigene Gast-ID
        // (Einzelpersonen ohne Anmeldungs-Gruppe zaehlen als eigene Anmeldung).
        var buckets: [String: [Guest]] = [:]
        for g in guests {
            let key = g.registrationGroup?.uuidString ?? "single-\(g.id.uuidString)"
            buckets[key, default: []].append(g)
        }

        let total = buckets.count
        var covered = 0
        var open: [String] = []
        for (_, members) in buckets {
            if members.contains(where: hasPhone) {
                covered += 1
            } else {
                let label = members
                    .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
                    .map(\.fullName)
                    .joined(separator: " & ")
                open.append(label)
            }
        }

        return PhoneCoverage(
            totalGuests: guests.count,
            guestsWithPhone: guests.filter(hasPhone).count,
            totalRegistrations: total,
            coveredRegistrations: covered,
            openRegistrations: open.sorted(),
            withPhone: guests.filter(hasPhone).sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
        )
    }
}
#endif
#endif
