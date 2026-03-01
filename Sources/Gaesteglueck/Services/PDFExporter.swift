#if canImport(UIKit)
import Foundation
import PDFKit
import UIKit

enum PDFExporter {
    static func generatePDF(
        tables: [GuestTable],
        eventName: String,
        date: Date?
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16)
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            var y: CGFloat = 40

            // Title
            let title = "Sitzplan: \(eventName)"
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttributes)
            y += 35

            // Date
            if let date {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.locale = Locale(identifier: "de_DE")
                let dateStr = formatter.string(from: date)
                dateStr.draw(at: CGPoint(x: 40, y: y), withAttributes: subtitleAttributes)
                y += 25
            }

            y += 15

            // Tables
            for table in tables.sorted(by: { $0.name < $1.name }) {
                if y > pageRect.height - 100 {
                    context.beginPage()
                    y = 40
                }

                let header = "\(table.name) (\(table.shape.rawValue), \(table.guests.count)/\(table.capacity) Plätze)"
                header.draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttributes)
                y += 22

                if table.guests.isEmpty {
                    "Keine Gäste zugewiesen".draw(at: CGPoint(x: 60, y: y), withAttributes: bodyAttributes)
                    y += 18
                } else {
                    for guest in table.guests.sorted(by: { $0.name < $1.name }) {
                        var line = "\u{2022} \(guest.name) (\(guest.side.rawValue))"
                        if guest.dietaryPreference != .meat {
                            line += " \(guest.dietaryPreference.rawValue)"
                        }
                        if !guest.allergies.isEmpty {
                            line += " \u{26A0}\u{FE0F} \(guest.allergies)"
                        }
                        if guest.isChild {
                            line += " Kind"
                        }
                        line.draw(at: CGPoint(x: 60, y: y), withAttributes: bodyAttributes)
                        y += 18
                    }
                }

                y += 10
            }

            // Summary
            if y > pageRect.height - 60 {
                context.beginPage()
                y = 40
            }
            y += 10
            let totalGuests = tables.reduce(0) { $0 + $1.guests.count }
            let totalCapacity = tables.reduce(0) { $0 + $1.capacity }
            let summary = "Gesamt: \(totalGuests) Gäste an \(tables.count) Tischen (\(totalCapacity) Plätze)"
            summary.draw(at: CGPoint(x: 40, y: y), withAttributes: subtitleAttributes)

            // --- Dietary Summary for Caterer ---
            context.beginPage()
            y = 40
            "Übersicht für den Caterer".draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttributes)
            y += 35

            let allGuests = tables.flatMap(\.guests)
            let meatCount = allGuests.filter { $0.dietaryPreference == .meat }.count
            let vegCount = allGuests.filter { $0.dietaryPreference == .vegetarian }.count
            let veganCount = allGuests.filter { $0.dietaryPreference == .vegan }.count
            let childCount = allGuests.filter(\.isChild).count

            "Fleisch: \(meatCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 20
            "Vegetarisch: \(vegCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 20
            "Vegan: \(veganCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 20
            "Kinder: \(childCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 30

            // List all allergies
            let guestsWithAllergies = allGuests.filter { !$0.allergies.isEmpty }
            if !guestsWithAllergies.isEmpty {
                "Unverträglichkeiten:".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttributes)
                y += 22
                for guest in guestsWithAllergies.sorted(by: { $0.name < $1.name }) {
                    "  \(guest.name): \(guest.allergies)".draw(at: CGPoint(x: 60, y: y), withAttributes: bodyAttributes)
                    y += 18
                }
            }
        }

        return data
    }
}
#endif
