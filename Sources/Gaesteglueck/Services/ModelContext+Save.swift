#if canImport(SwiftData)
import Foundation
import SwiftData

extension ModelContext {
    /// Speichert und protokolliert einen Fehlschlag, statt ihn per `try?`
    /// zu verschlucken. Der Aufrufer bricht bewusst nicht ab: ein
    /// fehlgeschlagenes Save soll die laufende UI-Aktion nicht kippen —
    /// aber es darf auch nicht spurlos verschwinden.
    func saveOrLog(file: StaticString = #fileID, line: UInt = #line) {
        do {
            try save()
        } catch {
            AppLog.persistence.error(
                "Speichern fehlgeschlagen (\(String(describing: file), privacy: .public):\(line, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
#endif
