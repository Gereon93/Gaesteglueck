import Foundation

enum CoPilotAction: Sendable, Equatable {
    case moveGuest(guestName: String, toTable: String)
    case swapGuests(guestA: String, guestB: String)
    case unassignGuest(guestName: String)
    case info(String)
}

struct CoPilotResponse: Sendable {
    let text: String
    let actions: [CoPilotAction]
}

struct SitzplanCoPilot {
    let client: LLMClient

    func ask(
        userMessage: String,
        history: [ChatMessage],
        saalContext: String
    ) async throws -> CoPilotResponse {
        var messages: [LLMMessage] = [
            LLMMessage(role: "system", content: Self.systemPrompt + "\n\n" + saalContext)
        ]
        for h in history {
            messages.append(LLMMessage(role: h.role, content: h.content))
        }
        messages.append(LLMMessage(role: "user", content: userMessage))

        let raw = try await client.chat(messages: messages, temperature: 0.2, maxTokens: 4000)
        return parseResponse(raw)
    }

    static let systemPrompt: String = """
Du bist ein Hochzeits-Sitzplan-Co-Pilot. Du siehst den aktuellen Stand des Saals (Tische + zugewiesene Gäste). Du beantwortest Fragen und führst Tisch-Bewegungen aus.

ANTWORT-FORMAT (immer JSON, kein Markdown, kein <think>-Block):
{
  "text": "Kurze Antwort an den User in 1-3 Sätzen.",
  "actions": [
    {"type": "moveGuest", "guestName": "Patrick Nowak", "toTable": "T2"},
    {"type": "swapGuests", "guestA": "Lisa Fritz", "guestB": "Anna Müller"},
    {"type": "unassignGuest", "guestName": "Tina Ochsenreiter"}
  ]
}

Wenn der User nur eine Frage stellt (z.B. "Welche Tische haben noch Plätze?"), gib actions leer zurück und beantworte mit text.
Wenn er einen Auftrag gibt ("Patrick auf T2", "Tausch Lisa mit Anna"), füge die entsprechenden actions hinzu.
Verwende die EXAKTEN Namen aus dem Saal-State. Tische heißen wie sie im State stehen (z.B. "T1", "Brauttafel", "Tafel A").
"""

    func parseResponse(_ raw: String) -> CoPilotResponse {
        guard let jsonString = extractJSONObject(from: raw),
              let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CoPilotResponse(text: raw.trimmingCharacters(in: .whitespacesAndNewlines), actions: [])
        }
        let text = (parsed["text"] as? String) ?? ""
        let actionsRaw = parsed["actions"] as? [[String: Any]] ?? []
        let actions = actionsRaw.compactMap(parseAction)
        return CoPilotResponse(text: text, actions: actions)
    }

    private func parseAction(_ entry: [String: Any]) -> CoPilotAction? {
        guard let type = (entry["type"] as? String)?.lowercased() else { return nil }
        switch type {
        case "moveguest":
            guard let g = entry["guestName"] as? String,
                  let t = entry["toTable"] as? String else { return nil }
            return .moveGuest(guestName: g, toTable: t)
        case "swapguests":
            guard let a = entry["guestA"] as? String,
                  let b = entry["guestB"] as? String else { return nil }
            return .swapGuests(guestA: a, guestB: b)
        case "unassignguest":
            guard let g = entry["guestName"] as? String else { return nil }
            return .unassignGuest(guestName: g)
        case "info":
            guard let t = entry["text"] as? String else { return nil }
            return .info(t)
        default:
            return nil
        }
    }

    private func extractJSONObject(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var idx = start
        while idx < raw.endIndex {
            let ch = raw[idx]
            if escape { escape = false }
            else if ch == "\\" && inString { escape = true }
            else if ch == "\"" { inString.toggle() }
            else if !inString {
                if ch == "{" { depth += 1 }
                else if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(raw[start...idx]) }
                }
            }
            idx = raw.index(after: idx)
        }
        return nil
    }
}

enum SitzplanCoPilotApplier {
    @MainActor
    static func apply(
        action: CoPilotAction,
        guests: [Guest],
        tables: [GuestTable]
    ) -> String {
        switch action {
        case .moveGuest(let guestName, let toTable):
            return performMove(guestName: guestName, toTable: toTable, guests: guests, tables: tables)
        case .swapGuests(let a, let b):
            return performSwap(guestA: a, guestB: b, in: guests)
        case .unassignGuest(let guestName):
            return performUnassign(guestName: guestName, in: guests)
        case .info(let text):
            return text
        }
    }

    @MainActor
    private static func performMove(guestName: String, toTable: String, guests: [Guest], tables: [GuestTable]) -> String {
        guard let guest = matchGuest(guestName, in: guests) else {
            return "✗ Gast '\(guestName)' nicht gefunden"
        }
        guard let table = matchTable(toTable, in: tables) else {
            return "✗ Tisch '\(toTable)' nicht gefunden"
        }
        if guest.isPinned {
            return "🔒 \(guest.fullName) ist gepinnt — Bewegung verweigert"
        }
        if guest.table?.id != table.id {
            let currentSeats = table.guests.filter { $0.id != guest.id }.count
            if currentSeats >= table.capacity {
                return "✗ \(table.name) ist voll (\(table.capacity) Plätze) — \(guest.fullName) bleibt"
            }
        }
        guest.table = table
        return "✓ \(guest.fullName) → \(table.name)"
    }

    @MainActor
    private static func performSwap(guestA: String, guestB: String, in guests: [Guest]) -> String {
        guard let ga = matchGuest(guestA, in: guests),
              let gb = matchGuest(guestB, in: guests) else {
            return "✗ Gast für Tausch nicht gefunden"
        }
        if ga.isPinned || gb.isPinned {
            return "🔒 Mind. einer der Gäste ist gepinnt — Tausch verweigert"
        }
        let tmp = ga.table
        ga.table = gb.table
        gb.table = tmp
        return "✓ \(ga.fullName) ↔ \(gb.fullName)"
    }

    @MainActor
    private static func performUnassign(guestName: String, in guests: [Guest]) -> String {
        guard let guest = matchGuest(guestName, in: guests) else {
            return "✗ Gast '\(guestName)' nicht gefunden"
        }
        if guest.isPinned {
            return "🔒 \(guest.fullName) ist gepinnt — bleibt am Tisch"
        }
        guest.table = nil
        return "✓ \(guest.fullName) vom Tisch genommen"
    }

    private static func matchGuest(_ name: String, in guests: [Guest]) -> Guest? {
        let lower = name.lowercased()
        if let exact = guests.first(where: { $0.fullName.lowercased() == lower }) {
            return exact
        }
        return guests.first { $0.fullName.lowercased().contains(lower) }
    }

    private static func matchTable(_ name: String, in tables: [GuestTable]) -> GuestTable? {
        let lower = name.lowercased()
        if let exact = tables.first(where: { $0.name.lowercased() == lower }) {
            return exact
        }
        return tables.first { $0.name.lowercased().contains(lower) }
    }
}
