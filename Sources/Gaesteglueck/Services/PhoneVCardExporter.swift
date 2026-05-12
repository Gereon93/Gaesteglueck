import Foundation

/// Exportiert Gäste mit hinterlegter Telefonnummer als vCard 3.0-Sammlung.
/// Eine .vcf-Datei mit mehreren Karten kann in iCloud-Kontakte importiert
/// werden — die Trauzeugin erstellt dann in WhatsApp/iMessage in einem Rutsch
/// eine Gruppe aus den Kontakten.
enum PhoneVCardExporter {
    static func generate(guests: [Guest], eventName: String) -> Data {
        let groupName = "Gäste \(eventName)"
        let withPhone = guests
            .filter { !$0.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }

        var output = ""
        for guest in withPhone {
            output += vcard(for: guest, groupName: groupName)
        }
        return Data(output.utf8)
    }

    private static func vcard(for guest: Guest, groupName: String) -> String {
        let last = escape(guest.lastName)
        let first = escape(guest.firstName)
        let fn = escape(guest.fullName)
        let tel = PhoneFormatter.display(guest.phoneNumber)
        let group = escape(groupName)
        let lines: [String] = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "N:\(last);\(first);;;",
            "FN:\(fn)",
            "TEL;TYPE=CELL:\(tel)",
            "CATEGORIES:\(group)",
            "END:VCARD"
        ]
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
