import Foundation

enum SheetBackupStore {
    static func saveCSV(_ csv: String, source: String) -> URL? {
        guard let dir = backupDirectory() else { return nil }
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "GoogleSheet-\(timestamp).csv"
        let url = dir.appendingPathComponent(filename)
        do {
            let header = "# Source: \(source)\n# Saved: \(Date())\n"
            let payload = header + csv
            try payload.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func backupDirectory() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("Gaesteglueck/Sheet-Backups", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }
}
