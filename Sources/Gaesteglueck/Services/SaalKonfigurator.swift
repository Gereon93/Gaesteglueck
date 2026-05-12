import Foundation

struct SaalInventar: Sendable, Equatable {
    var roundMaxCount: Int = 10
    var roundDiameterCM: Double = 160
    var rectangularMaxCount: Int = 8
    var rectangularWidthCM: Double = 200
    var rectangularDepthCM: Double = 90
    var rectangularMaxTafelLength: Int = 1   // 1 = nur Solo; >1 = Tafeln aus bis zu N Tischen
    var withSeparateBridalTable: Bool = true
    var bridalTableWidthCM: Double = 320
    var bridalTableDepthCM: Double = 90
    var withChildTable: Bool = false
    var childTableWidthCM: Double = 100

    var roundCapacityEach: Int {
        Int(Double.pi * roundDiameterCM / GuestTable.activeRules.seatWidthCm)
    }

    var rectCapacityEach: Int {
        Self.rectangularSeats(width: rectangularWidthCM, depth: rectangularDepthCM)
    }

    var bridalCapacity: Int {
        Self.rectangularSeats(width: bridalTableWidthCM, depth: bridalTableDepthCM)
    }

    var childCapacity: Int {
        Self.rectangularSeats(width: childTableWidthCM, depth: childTableWidthCM)
    }

    private static func rectangularSeats(width: Double, depth: Double) -> Int {
        let seatWidth = GuestTable.activeRules.seatWidthCm
        let longSeats  = 2 * Int(width / seatWidth)
        let shortSeats = 2 * (depth >= seatWidth ? 1 : 0)
        return longSeats + shortSeats
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
    var tafelGroup: String?
    var tafelOrder: Int?
}

struct SaalProposal: Sendable, Equatable {
    var tables: [ProposedTable]
    var reasoning: String
    var totalCapacity: Int { tables.reduce(0) { $0 + $1.capacity } }
}

struct SaalKonfigurator {
    let client: LLMClient

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
                LLMMessage(role: "system", content: Self.systemPrompt),
                LLMMessage(role: "user", content: userPrompt)
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
- Wenige große Tafeln + wenige runde Tische sind besser als viele kleine Tische verteilt.

PLATZIERUNGS-PRIORITÄT — Tische in dieser REIHENFOLGE planen:
1. BRAUTTISCH zuerst: Brautpaar + Trauzeugen-Crew (mit Partnern + Kinder von Trauzeugen). Das sind nie aufzubrechende Personen.
2. ELTERN-TISCH(E): Eltern beider Seiten + ggf. Schwiegereltern. Oft an einem Familientisch zusammengeführt, niemals getrennt.
3. GESCHWISTER-TISCH(E): Geschwister + Schwager/Schwägerin + Nichten/Neffen jeder Seite. Eine Sippe nicht aufteilen.
4. FAMILIENTISCH(E) erweitert: Onkel/Tanten + Cousins + ggf. Patenfamilie pro Seite.
5. FREUNDESKREISE-TISCHE: Realschule, Studium, Wohnheim, JGA, Fasching, Sportverein etc. Jeder Cluster bevorzugt zusammen.
6. RESTTISCHE: Einzeln eingeladene + nicht-zuordbare. Mit Brücken-Personen oder geografischer/Hobby-Affinität auffüllen.

UNAUFBRECHBARE GRUPPEN — niemals splitten:
- Anmeldungs-Gruppen (gleiche registrationGroup) müssen IMMER zusammen.
- Eltern-Paare (Mutter + Vater einer Seite) sitzen zusammen am Eltern-Tisch.
- Geschwister-mit-Familie (Schwester + Schwager + Kinder) bleiben als Block zusammen.
- Trauzeugen mit ihren Partnern und Kindern sitzen zusammen am Brauttisch.

CLUSTER-KOMBINATIONEN bei kleinen Resten:
- Kleine thematisch verwandte Cluster (Motorrad + S7-Sanierung + SCF wenn überlappend) zu einem Tisch.
- Brücken-Personen sind die Anker: wenn 3 kleine Cluster eine gemeinsame Brücke haben, sie zusammen platzieren.
- Wenn ein Freundeskreis-Tisch voll ist und Einzelpersonen übrig bleiben:
  • Suche gemeinsame Brücken zur Brautpaar-Crew (Brautpaar selbst ist universelle Brücke)
  • Geografische Nähe (Funfact/Notizen-Hinweise auf Wohnort/Bundesland)
  • Geteilte Hobbys (z.B. zwei „Motorrad"-Tagger an einen Tisch obwohl sonst keine Verbindung)
  • Lebensphase (Berufstätigkeit, Alter)
- Begründe pro Tisch konkret WELCHE Cluster du verschmolzen hast und WARUM.

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
    },
    {
      "shape": "rectangular",
      "widthCM": 140,
      "depthCM": 80,
      "name": "Großfamilie Maier",
      "capacity": 6,
      "isBridal": false,
      "isChild": false,
      "tafelGroup": "G1",
      "tafelOrder": 0,
      "clusters": ["Familie Maier"],
      "reason": "Erster von 3 verbundenen Tischen — ergibt 16 Plätze."
    },
    {
      "shape": "rectangular",
      "widthCM": 140,
      "depthCM": 80,
      "name": "Großfamilie Maier",
      "capacity": 6,
      "isBridal": false,
      "isChild": false,
      "tafelGroup": "G1",
      "tafelOrder": 1,
      "clusters": ["Familie Maier"],
      "reason": "Mittelteil der 16er-Tafel."
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

        let rules = GuestTable.activeRules
        prompt += "\n## Sitzregel\n\nSitzabstand: \(Int(rules.seatWidthCm)) cm pro Person.\n"

        if inventory.rectangularMaxTafelLength > 1 {
            let maxLen = inventory.rectangularMaxTafelLength
            let w = Int(inventory.rectangularWidthCM)
            let d = Int(inventory.rectangularDepthCM)
            let sw = rules.seatWidthCm
            let cap2 = 2 * Int(Double(2 * w) / sw) + 2
            let cap3 = 2 * Int(Double(3 * w) / sw) + 2
            let cap4 = 2 * Int(Double(4 * w) / sw) + 2
            prompt += """

## Tafel-Möglichkeit

Aus den rechteckigen \(w)×\(d) cm Tischen kannst du Tafeln bauen, indem du sie aneinanderschiebst. Erlaubte Tafel-Längen: 2 bis \(maxLen) Tische.

Eine Tafel aus N solchen Tischen hat 2*floor(N*\(w)/\(Int(sw))) + 2 Plätze.
Beispiel-Tafeln (mit Sitzabstand \(Int(sw))cm):
- 2×\(w)×\(d) → \(cap2) Plätze
- 3×\(w)×\(d) → \(cap3) Plätze
- 4×\(w)×\(d) → \(cap4) Plätze

Bevorzuge Tafeln, wenn eine zusammenhängende Gruppe größer ist als ein einzelner Tisch fasst. Markiere Tafel-Mitglieder im Output:
- "tafelGroup": "G1" (oder G2, G3 ...) bei allen Mitgliedern derselben Tafel
- "tafelOrder": 0, 1, 2 ... in Reihenfolge der Tafel
- Alle Mitglieder einer Tafel haben gleiche depthCM

"""
        }

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
        let groupValidated = validateAndFixTafelGroups(parsed_, inventory: inventory)
        let validated = enforceInventoryLimits(groupValidated, inventory: inventory)
        return SaalProposal(tables: validated, reasoning: reasoning)
    }

    private func validateAndFixTafelGroups(_ tables: [ProposedTable], inventory: SaalInventar) -> [ProposedTable] {
        var bySolo: [ProposedTable] = []
        var byGroup: [String: [ProposedTable]] = [:]
        for t in tables {
            if let g = t.tafelGroup {
                byGroup[g, default: []].append(t)
            } else {
                bySolo.append(t)
            }
        }

        var result = bySolo
        for (_, members) in byGroup {
            let sorted = members.sorted { ($0.tafelOrder ?? 0) < ($1.tafelOrder ?? 0) }
            let depths = Set(sorted.map { $0.depthCM })
            let orders = sorted.compactMap { $0.tafelOrder }
            let expectedOrders = Array(0..<sorted.count)
            let withinMax = sorted.count <= inventory.rectangularMaxTafelLength
            let allRect = sorted.allSatisfy { $0.shape == .rectangular }

            let valid = depths.count == 1
                && orders == expectedOrders
                && withinMax
                && allRect
                && sorted.count >= 2

            if valid {
                result.append(contentsOf: sorted)
            } else {
                for var m in sorted {
                    m.tafelGroup = nil
                    m.tafelOrder = nil
                    result.append(m)
                }
            }
        }
        return result
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
        let tafelGroup = entry["tafelGroup"] as? String
        let tafelOrder = entry["tafelOrder"] as? Int
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
            reason: reason,
            tafelGroup: tafelGroup,
            tafelOrder: tafelOrder
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

    private func computeCapacity(
        shape: TableShape,
        widthCM: Double,
        depthCM: Double,
        diameterCM: Double,
        seatWidth: Double = 60
    ) -> Int {
        switch shape {
        case .round:
            return Int(Double.pi * diameterCM / seatWidth)
        case .rectangular:
            let longSeats  = 2 * Int(widthCM / seatWidth)
            let shortSeats = 2 * (depthCM >= seatWidth ? 1 : 0)
            return longSeats + shortSeats
        case .square:
            let longSeats  = 2 * Int(widthCM / seatWidth)
            let shortSeats = 2 * (widthCM >= seatWidth ? 1 : 0)
            return longSeats + shortSeats
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
