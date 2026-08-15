import Foundation
import OSLog

/// Log-Kanäle der App. Sichtbar in Console.app bzw. via
/// `log stream --predicate 'subsystem == "com.gereon93.Gaesteglueck"'`.
///
/// Zweck: Fehler, die den Ablauf bewusst nicht abbrechen, hinterlassen
/// trotzdem eine Spur — sonst ist ein verlorener Speichervorgang oder eine
/// fehlgeschlagene Backup-Kopie im Nachhinein nicht mehr nachvollziehbar.
///
/// Sichtbarkeit: öffentlich ist nur, was nichts über die Gäste verrät —
/// Quellcode-Ort und Operationsname. Dateinamen tragen den Event-Namen und
/// Fehlertexte den Benutzerpfad, beide bleiben deshalb `private` und werden
/// im Unified Log als `<private>` maskiert.
enum AppLog {
    private static let subsystem = "com.gereon93.Gaesteglueck"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let files = Logger(subsystem: subsystem, category: "files")
    static let llm = Logger(subsystem: subsystem, category: "llm")
}

extension Data {
    /// Schreibt an einen vom User gewählten Pfad und protokolliert einen
    /// Fehlschlag. Der Export bricht nicht ab — im Log steht aber, warum
    /// die Datei fehlt.
    func writeOrLog(to url: URL) {
        do {
            try write(to: url)
        } catch {
            AppLog.files.error(
                "Export fehlgeschlagen: \(url.lastPathComponent, privacy: .private) — \(error.localizedDescription, privacy: .private)"
            )
        }
    }
}
