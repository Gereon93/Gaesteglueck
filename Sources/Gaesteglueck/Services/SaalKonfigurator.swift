import Foundation

struct SaalInventar: Sendable, Equatable {
    var roundMaxCount: Int = 10
    var roundDiameterCM: Double = 160
    var rectangularMaxCount: Int = 8
    var rectangularWidthCM: Double = 200
    var rectangularDepthCM: Double = 90
    var withSeparateBridalTable: Bool = true
    var bridalTableWidthCM: Double = 320
    var bridalTableDepthCM: Double = 90
    var withChildTable: Bool = false
    var childTableWidthCM: Double = 100

    var roundCapacityEach: Int {
        Int(Double.pi * roundDiameterCM / 60)
    }

    var rectCapacityEach: Int {
        max(Int((2 * (rectangularWidthCM + rectangularDepthCM)) / 60) - 2, 4)
    }

    var bridalCapacity: Int {
        max(Int((2 * (bridalTableWidthCM + bridalTableDepthCM)) / 60) - 2, 4)
    }

    var childCapacity: Int {
        Int(4 * childTableWidthCM / 60)
    }

    var maxTotalCapacity: Int {
        roundMaxCount * roundCapacityEach
            + rectangularMaxCount * rectCapacityEach
            + (withSeparateBridalTable ? bridalCapacity : 0)
            + (withChildTable ? childCapacity : 0)
    }
}

struct ProposedTable: Sendable, Identifiable, Equatable {
    var id: UUID = UUID()
    var shape: TableShape
    var name: String
    var widthCM: Double
    var depthCM: Double
    var diameterCM: Double
    var capacity: Int
    var isBridal: Bool
    var isChild: Bool
    var clusters: [String]
    var reason: String
}

struct SaalProposal: Sendable, Equatable {
    var tables: [ProposedTable]
    var reasoning: String
    var totalCapacity: Int { tables.reduce(0) { $0 + $1.capacity } }
}

struct SaalKonfigurator {
    let client: LMStudioClient

    func propose(
        inventory: SaalInventar,
        guestCount: Int,
        seatingNeed: Int,
        clusterContext: String
    ) async throws -> SaalProposal {
        let userPrompt = buildUserPrompt(
            inventory: inventory,
            guestCount: guestCount,
            seatingNeed: seatingNeed,
            clusterContext: clusterContext
        )
        let raw = try await client.chat(
            messages: [
                LMStudioClient.Message(role: "system", content: Self.systemPrompt),
                LMStudioClient.Message(role: "user", content: userPrompt)
            ],
            temperature: 0.3,
            maxTokens: 8000
        )
        return parseResponse(raw, inventory: inventory)
    }

    static let systemPrompt: String = """
Antworte SOFORT mit dem fertigen JSON, keine Vorrede, kein <think>-Block, keine Markdown-Wrapper.

Du bist ein Hochzeits-Saal-Planer. Du bekommst:
1. Verfügbares Tisch-Inventar = MAXIMUM was die Location bereitstellen kann (keine Pflicht-Anzahl!)
2. Gästeliste mit Family-Clustern und Tag-basierten Gruppen
3. Anzahl Sitzplätze die belegt werden müssen

Aufgabe: schlage die KLEINSTMÖGLICHE Tisch-Konfiguration vor die alle Gäste plus 4-6 Plätze Puffer aufnimmt.

KARDINALREGELN — NICHT ÜBERSEHEN:
- Das Inventar ist eine OBERGRENZE, keine Zielzahl. Wenn 88 Sitzplätze gebraucht werden und das Inventar 147 hergibt, NIMM NUR SO VIELE TISCHE WIE NÖTIG. Lass den Rest ungenutzt.
- TISCHE MÜSSEN VOLL SEIN. Maximal 1 leerer Platz pro Tisch ist akzeptabel. Ein 10er-Tisch mit nur 4 Personen ist STRENG VERBOTEN — kombiniere kleinere Cluster oder nimm einen kleineren Tisch.
- Faustregel: Gesamt-Kapazität = SeatingNeed + max 5 Reserveplätze über ALLE Tische verteilt.
- Wenn ein Cluster nicht zur Tisch-Größe passt: kombiniere mit einem nahen Cluster (Brücken-Personen!) oder splittet — aber niemals halb-leere Tische.
- Wenige große Tafeln + wenige runde Tische sind besser als viele kleine Tische verteilt.

WEITERE REGELN:
- Brautpaar bekommt einen prominenten Tisch (entweder separate Brauttafel oder Trauzeugen sitzen mit am Brautpaartisch — je nach Inventar).
- Familien-Cluster (Eltern, Onkel/Tanten, Geschwister) gehören typischerweise an einen Tisch pro Seite.
- Freundeskreise (Realschule, Studium, JGA, Fasching) gehören an eigene Tische, dürfen aber gemischt werden wenn ein Tisch zu klein ist.
- Lange Tafeln (rechteckig) sind gut für 10-14 Personen die gemeinsam essen wollen (z.B. eine große Familie).
- Runde Tische sind gut für 6-8 Personen aus gemischten Kreisen.

OUTPUT (NUR JSON):
{
  "reasoning": "Kurze Begründung der Gesamtaufteilung in 2-3 Sätzen.",
  "tables": [
    {
      "shape": "rectangular",
      "widthCM": 320,
      "depthCM": 90,
      "name": "Brauttafel",
      "isBridal": true,
      "isChild": false,
      "clusters": ["Brautpaar", "Trauzeugen Gereon"],
      "reason": "Brautpaar + Trauzeugen-Crew, 12 Plätze."
    },
    {
      "shape": "round",
      "widthCM": 0,
      "depthCM": 0,
      "diameterCM": 160,
      "name": "T1 — Hü-Fos",
      "isBridal": false,
      "isChild": false,
      "clusters": ["Familie Maier", "Familienfreunde Gereon"],
      "reason": "Großfamilie der Brautmutter, 8 Personen."
    }
  ]
}

Wenn das Inventar nicht reicht: weniger oder kleinere Tische vorschlagen, kein Inventar überschreiten. Wenn Spezial-Tische erlaubt sind (Brauttafel, Kindertisch), diese nutzen.
"""

    private func buildUserPrompt(
        inventory: SaalInventar,
        guestCount: Int,
        seatingNeed: Int,
        clusterContext: String
    ) -> String {
        let targetCapacity = seatingNeed + 5
        var prompt = ""
        prompt += "## Ziel-Kapazität\n\n"
        prompt += "Du SOLLST \(targetCapacity) Plätze planen (= \(seatingNeed) Sitzplätze + 5 Puffer). Mehr ist Verschwendung.\n\n"
        prompt += "## Verfügbares Inventar (Obergrenze, keine Pflicht)\n\n"
        prompt += "Bis zu \(inventory.roundMaxCount) runde Tische à \(Int(inventory.roundDiameterCM)) cm Ø (\(inventory.roundCapacityEach) Plätze)\n"
        prompt += "Bis zu \(inventory.rectangularMaxCount) rechteckige Tafeln à \(Int(inventory.rectangularWidthCM))×\(Int(inventory.rectangularDepthCM)) cm (\(inventory.rectCapacityEach) Plätze)\n"
        if inventory.withSeparateBridalTable {
            prompt += "Optional: 1 Brauttafel \(Int(inventory.bridalTableWidthCM))×\(Int(inventory.bridalTableDepthCM)) cm (\(inventory.bridalCapacity) Plätze) für Brautpaar\n"
        }
        if inventory.withChildTable {
            prompt += "Optional: 1 Kindertisch \(Int(inventory.childTableWidthCM))×\(Int(inventory.childTableWidthCM)) cm (\(inventory.childCapacity) Plätze)\n"
        }
        prompt += "\nMaximum verfügbar wäre \(inventory.maxTotalCapacity) Plätze — aber nimm nur so viele wie nötig!\n\n"
        prompt += "## Gäste\n\n"
        prompt += "Gesamt: \(guestCount) Gäste, \(seatingNeed) brauchen einen Platz (Babys ohne Stuhl)\n\n"
        prompt += clusterContext
        return prompt
    }

    func parseResponse(_ raw: String, inventory: SaalInventar) -> SaalProposal {
        guard let jsonString = extractJSONObject(from: raw),
              let data = jsonString.data(using: .utf8) else {
            return SaalProposal(tables: [], reasoning: "Konnte Antwort nicht parsen — bitte erneut versuchen.")
        }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SaalProposal(tables: [], reasoning: "JSON ungültig.")
        }

        let reasoning = (parsed["reasoning"] as? String) ?? ""
        let tablesRaw = parsed["tables"] as? [[String: Any]] ?? []
        let parsed_ = tablesRaw.compactMap { entry in parseTable(entry, inventory: inventory) }
        let validated = enforceInventoryLimits(parsed_, inventory: inventory)
        return SaalProposal(tables: validated, reasoning: reasoning)
    }

    private func enforceInventoryLimits(_ tables: [ProposedTable], inventory: SaalInventar) -> [ProposedTable] {
        var roundCount = 0
        var rectCount = 0
        var bridalCount = 0
        var childCount = 0
        var result: [ProposedTable] = []
        for table in tables {
            if table.isBridal {
                if !inventory.withSeparateBridalTable || bridalCount >= 1 { continue }
                bridalCount += 1
                result.append(table)
                continue
            }
            if table.isChild {
                if !inventory.withChildTable || childCount >= 1 { continue }
                childCount += 1
                result.append(table)
                continue
            }
            switch table.shape {
            case .round:
                guard roundCount < inventory.roundMaxCount else { continue }
                roundCount += 1
            case .rectangular, .square:
                guard rectCount < inventory.rectangularMaxCount else { continue }
                rectCount += 1
            }
            result.append(table)
        }
        return result
    }

    private func parseTable(_ entry: [String: Any], inventory: SaalInventar) -> ProposedTable? {
        guard let shapeStr = entry["shape"] as? String else { return nil }
        let shape = mapShape(shapeStr)
        let widthCM = (entry["widthCM"] as? Double) ?? Double(entry["widthCM"] as? Int ?? 0)
        let depthCM = (entry["depthCM"] as? Double) ?? Double(entry["depthCM"] as? Int ?? 0)
        let diameterCM = (entry["diameterCM"] as? Double) ?? Double(entry["diameterCM"] as? Int ?? 0)
        let isBridal = (entry["isBridal"] as? Bool) ?? false
        let isChild = (entry["isChild"] as? Bool) ?? false
        let name = (entry["name"] as? String) ?? defaultName(for: shape, isBridal: isBridal, isChild: isChild)
        let clusters = (entry["clusters"] as? [String]) ?? []
        let reason = (entry["reason"] as? String) ?? ""
        let capacity = computeCapacity(shape: shape, widthCM: widthCM, depthCM: depthCM, diameterCM: diameterCM)
        return ProposedTable(
            shape: shape,
            name: name,
            widthCM: widthCM,
            depthCM: depthCM,
            diameterCM: diameterCM,
            capacity: capacity,
            isBridal: isBridal,
            isChild: isChild,
            clusters: clusters,
            reason: reason
        )
    }

    private func mapShape(_ token: String) -> TableShape {
        switch token.lowercased() {
        case "round", "rund": return .round
        case "rectangular", "rectangle", "rechteckig", "tafel": return .rectangular
        case "square", "quadratisch": return .square
        default: return .round
        }
    }

    private func defaultName(for shape: TableShape, isBridal: Bool, isChild: Bool) -> String {
        if isBridal { return "Brauttafel" }
        if isChild { return "Kindertisch" }
        switch shape {
        case .round: return "Tisch"
        case .rectangular: return "Tafel"
        case .square: return "Tisch"
        }
    }

    private func computeCapacity(shape: TableShape, widthCM: Double, depthCM: Double, diameterCM: Double) -> Int {
        let seatWidth: Double = 60
        switch shape {
        case .round:
            return Int(Double.pi * diameterCM / seatWidth)
        case .rectangular:
            return max(Int(2 * (widthCM + depthCM) / seatWidth) - 2, 4)
        case .square:
            return Int(4 * widthCM / seatWidth)
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
