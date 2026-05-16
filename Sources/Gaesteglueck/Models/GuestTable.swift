import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class GuestTable {
    var id: UUID
    var name: String
    var shape: TableShape
    var diameter: Double
    var width: Double
    var depth: Double
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var isLocked: Bool
    var isChildTable: Bool
    var combinationGroup: UUID?
    var combinationRole: CombinationRole?
    var combinationOrder: Int?
    var disabledSeatIndicesData: Data?
    var guests: [Guest]
    /// Markiert diesen Tisch als Brautpaar-/Brauttafel. Wird visuell hervorgehoben
    /// und das Brautpaar wird vom Auto-Place bevorzugt hier platziert.
    var isBridalTable: Bool = false

    /// Steuert die Seite auf der Gast-Namen gezeichnet werden (bei aktivem
    /// "Namen einblenden"). String-backed mit Default für SwiftData-Auto-Migration.
    var seatNameSideRaw: String = SeatNameSide.auto.rawValue
    var seatNameSide: SeatNameSide {
        get { SeatNameSide(rawValue: seatNameSideRaw) ?? .auto }
        set { seatNameSideRaw = newValue.rawValue }
    }

    /// App-weiter Default für Sitzregeln. Wird von der UI gesetzt, wenn ein
    /// Event geladen ist (siehe `RoomCanvasView`). Tests setzen explizit.
    /// Lock-geschuetzt damit Hintergrund-Tasks (Optimizer, Exporter) nicht
    /// parallel mit der UI in Konflikt geraten.
    nonisolated(unsafe) private static var _activeRules: SeatingRules = .default
    private static let activeRulesLock = NSLock()
    static var activeRules: SeatingRules {
        get { activeRulesLock.lock(); defer { activeRulesLock.unlock() }; return _activeRules }
        set { activeRulesLock.lock(); defer { activeRulesLock.unlock() }; _activeRules = newValue }
    }

    var disabledSeatIndices: Set<Int> {
        get {
            guard let data = disabledSeatIndicesData,
                  let arr = try? JSONDecoder().decode([Int].self, from: data)
            else { return [] }
            return Set(arr)
        }
        set {
            disabledSeatIndicesData = try? JSONEncoder().encode(Array(newValue).sorted())
        }
    }

    func effectiveCapacity(rules: SeatingRules) -> Int {
        let cap = capacity(rules: rules)
        // Disabled-Indices koennen aus alten Sitzregeln stammen — out-of-range
        // Eintraege ignorieren, sonst kann effectiveCapacity negativ werden.
        let validDisabled = disabledSeatIndices.filter { $0 < cap }.count
        return max(0, cap - validDisabled)
    }

    var effectiveCapacity: Int { effectiveCapacity(rules: GuestTable.activeRules) }

    func capacity(rules: SeatingRules) -> Int {
        let seatWidth = rules.seatWidthCm
        switch shape {
        case .round:
            let circumference = Double.pi * diameter
            return Int(circumference / seatWidth)
        case .rectangular:
            let longSeats  = 2 * Int(width / seatWidth)
            let shortSeats = 2 * (depth >= seatWidth ? 1 : 0)
            return longSeats + shortSeats
        case .square:
            let longSeats  = 2 * Int(width / seatWidth)
            let shortSeats = 2 * (width >= seatWidth ? 1 : 0)
            return longSeats + shortSeats
        }
    }

    var capacity: Int { capacity(rules: GuestTable.activeRules) }

    var remainingSeats: Int { capacity - guests.count }
    var isFull: Bool { guests.count >= effectiveCapacity }

    init(
        name: String,
        shape: TableShape,
        diameter: Double = 180,
        width: Double = 200,
        depth: Double = 100,
        positionX: Double = 0,
        positionY: Double = 0,
        rotation: Double = 0,
        isChildTable: Bool = false,
        isBridalTable: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.shape = shape
        self.diameter = diameter
        self.width = width
        self.depth = depth
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.isLocked = false
        self.isChildTable = isChildTable
        self.isBridalTable = isBridalTable
        self.combinationGroup = nil
        self.combinationRole = nil
        self.combinationOrder = nil
        self.disabledSeatIndicesData = nil
        self.guests = []
    }
}
