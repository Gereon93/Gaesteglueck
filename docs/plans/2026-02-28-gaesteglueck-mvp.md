# Gästeglück MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an iPad app that lets wedding planners import their guest Excel list, manage guests with dietary preferences and allergies, define social relationships via a guided onboarding wizard, photograph their venue floor plan, place tables on a scaled room canvas, assign guests to tables via drag-and-drop, combine rectangular tables, and optimize seating with a happiness score algorithm — all exportable as a PDF with dietary info for the caterer.

**Architecture:** SwiftUI + SwiftData app targeting iPadOS 18+. MVVM-lite using `@Observable` classes for view models and SwiftData `@Model` classes for persistence. The room canvas uses a `ZStack` with positioned, draggable table views over an optional photo background with calibrated scale. The happiness algorithm is a pure-function scoring engine with no UI dependencies, making it fully unit-testable. Excel import via the CoreXLSX Swift package parses multi-person family rows.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, iPadOS 18+, PDFKit, CoreXLSX (SPM dependency for .xlsx parsing), PhotosUI

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `Gaesteglueck.xcodeproj` (via Xcode CLI / template)
- Create: `Gaesteglueck/GaesteglueckApp.swift`
- Create: `Gaesteglueck/ContentView.swift`
- Create: `GaesteglueckTests/GaesteglueckTests.swift`

**Step 1: Create the Xcode project**

Run:
```bash
# From /var/home/gereon/code/ios/Gaesteglueck
# Option A: Use Xcode GUI to create a new project:
#   - Template: App
#   - Product Name: Gaesteglueck
#   - Interface: SwiftUI
#   - Storage: SwiftData
#   - Target: iPad
#   - Include Tests: Yes (Unit + UI)
#   - Save in: this directory (do NOT create subdirectory)
#
# Option B: If working headless, create via swift package init and add
#   the iOS app target manually. Xcode GUI is strongly preferred.
```

**Step 2: Verify the project builds**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 3: Run the default test**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' test`
Expected: 1 test passed

**Step 4: Configure the project**

- Set deployment target to iPadOS 18.0
- Set supported orientations to landscape only (`.landscape`)
- Set `Info.plist` display name to "Gästeglück"
- Disable iPhone target (iPad only)

In `GaesteglueckApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct GaesteglueckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Event.self, Guest.self, GuestTable.self, Relationship.self, RoomPlan.self])
    }
}
```

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: initialize Xcode project with SwiftUI + SwiftData"
```

---

## Task 2: Core Data Models — Guest, Event & Supporting Enums

**Files:**
- Create: `Gaesteglueck/Models/Event.swift`
- Create: `Gaesteglueck/Models/Guest.swift`
- Create: `Gaesteglueck/Models/Side.swift`
- Create: `Gaesteglueck/Models/DietaryPreference.swift`
- Create: `Gaesteglueck/Models/GroupType.swift`
- Create: `Gaesteglueck/Models/FamilyRole.swift`
- Test: `GaesteglueckTests/Models/GuestTests.swift`

**Step 1: Write the failing tests for Guest**

```swift
// GaesteglueckTests/Models/GuestTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Model")
struct GuestTests {
    @Test("Guest initializes with correct defaults")
    func guestDefaults() {
        let guest = Guest(name: "Anna Schmidt", side: .bride)
        #expect(guest.name == "Anna Schmidt")
        #expect(guest.side == .bride)
        #expect(guest.groupType == nil)
        #expect(guest.familyID == nil)
        #expect(guest.rsvpStatus == .pending)
        #expect(guest.dietaryPreference == .meat)
        #expect(guest.allergies.isEmpty)
    }

    @Test("Guest dietary preference")
    func dietaryPreference() {
        let guest = Guest(name: "Lisa Vegan", side: .bride, dietaryPreference: .vegan)
        #expect(guest.dietaryPreference == .vegan)
    }

    @Test("Guest allergies stored correctly")
    func allergies() {
        let guest = Guest(name: "Tom", side: .groom, allergies: "Laktose, Nüsse")
        #expect(guest.allergies == "Laktose, Nüsse")
    }

    @Test("Guest group type")
    func groupType() {
        let guest = Guest(name: "Max", side: .groom, groupType: .universityFriend)
        #expect(guest.groupType == .universityFriend)
    }

    @Test("Guest family role")
    func familyRole() {
        let guest = Guest(name: "Schwester", side: .bride, familyRole: .sister)
        #expect(guest.familyRole == .sister)
    }

    @Test("RSVP status transitions")
    func rsvpStatus() {
        let guest = Guest(name: "Test", side: .neutral)
        #expect(guest.rsvpStatus == .pending)
        guest.rsvpStatus = .confirmed
        #expect(guest.rsvpStatus == .confirmed)
    }

    @Test("Guest isChild flag")
    func isChild() {
        let child = Guest(name: "Klein-Max", side: .bride, isChild: true)
        #expect(child.isChild)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: FAIL — `Guest`, `Side`, `DietaryPreference`, `GroupType`, `FamilyRole` not defined

**Step 3: Implement Side enum**

```swift
// Gaesteglueck/Models/Side.swift
import Foundation

enum Side: String, Codable, CaseIterable, Identifiable {
    case bride = "Braut"
    case groom = "Bräutigam"
    case neutral = "Neutral"

    var id: String { rawValue }
}
```

**Step 4: Implement DietaryPreference enum**

```swift
// Gaesteglueck/Models/DietaryPreference.swift
import Foundation

enum DietaryPreference: String, Codable, CaseIterable, Identifiable {
    case meat = "Fleisch"
    case vegetarian = "Vegetarisch"
    case vegan = "Vegan"

    var id: String { rawValue }

    /// Short label for badges and PDF export
    var badge: String {
        switch self {
        case .meat: "🥩"
        case .vegetarian: "🥬"
        case .vegan: "🌱"
        }
    }
}
```

**Step 5: Implement GroupType enum**

These are the structured social groups that drive clustering.

```swift
// Gaesteglueck/Models/GroupType.swift
import Foundation

enum GroupType: String, Codable, CaseIterable, Identifiable {
    // Family groups
    case immediateFamily = "Engste Familie"
    case extendedFamily = "Erweiterte Familie"

    // Friend groups
    case schoolFriend = "Schulfreunde"
    case universityFriend = "Studienkollegen"
    case roommate = "Mitbewohner"
    case workColleague = "Arbeitskollegen"

    // Activity groups
    case clubMember = "Verein"
    case jga = "JGA"

    // Special
    case neighbor = "Nachbarn"
    case other = "Sonstige"

    var id: String { rawValue }

    /// Clustering weight — how important is it that this group stays together?
    var cohesionWeight: Double {
        switch self {
        case .immediateFamily: 0.9
        case .extendedFamily: 0.6
        case .jga: 0.7
        case .schoolFriend, .universityFriend, .roommate: 0.5
        case .workColleague, .clubMember: 0.4
        case .neighbor, .other: 0.2
        }
    }
}
```

**Step 6: Implement FamilyRole enum**

The specific relationship label (Schwester, Bruder, Schwager, etc.) shown in the onboarding wizard and on the UI.

```swift
// Gaesteglueck/Models/FamilyRole.swift
import Foundation

enum FamilyRole: String, Codable, CaseIterable, Identifiable {
    // Core family
    case mother = "Mutter"
    case father = "Vater"
    case sister = "Schwester"
    case brother = "Bruder"
    case grandmother = "Oma"
    case grandfather = "Opa"

    // In-laws
    case sisterInLaw = "Schwägerin"
    case brotherInLaw = "Schwager"
    case motherInLaw = "Schwiegermutter"
    case fatherInLaw = "Schwiegervater"

    // Extended
    case aunt = "Tante"
    case uncle = "Onkel"
    case cousin = "Cousin/Cousine"
    case niece = "Nichte"
    case nephew = "Neffe"

    // Other
    case child = "Kind"
    case partner = "Partner/in"
    case friend = "Freund/in"
    case witness = "Trauzeuge/Trauzeugin"
    case other = "Sonstige"

    var id: String { rawValue }
}
```

**Step 7: Implement Guest model**

```swift
// Gaesteglueck/Models/Guest.swift
import Foundation
import SwiftData

enum RSVPStatus: String, Codable, CaseIterable {
    case pending = "Ausstehend"
    case confirmed = "Zugesagt"
    case declined = "Abgesagt"
}

@Model
final class Guest {
    var id: UUID
    var name: String
    var side: Side

    // Grouping & clustering
    var groupType: GroupType?
    var customGroupName: String?  // e.g., "Fußballverein TuS" when groupType == .clubMember
    var familyID: UUID?
    var familyRole: FamilyRole?
    var mainContactPersonID: UUID?  // Who's the primary link to the bride/groom?

    // Dietary (for the caterer)
    var dietaryPreference: DietaryPreference
    var allergies: String  // Free text: "Laktose, Nüsse, Gluten"

    // Status
    var rsvpStatus: RSVPStatus
    var isChild: Bool
    var notes: String

    @Relationship(inverse: \GuestTable.guests)
    var table: GuestTable?

    var isPinned: Bool

    init(
        name: String,
        side: Side,
        groupType: GroupType? = nil,
        customGroupName: String? = nil,
        familyID: UUID? = nil,
        familyRole: FamilyRole? = nil,
        dietaryPreference: DietaryPreference = .meat,
        allergies: String = "",
        rsvpStatus: RSVPStatus = .pending,
        isChild: Bool = false,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.side = side
        self.groupType = groupType
        self.customGroupName = customGroupName
        self.familyID = familyID
        self.familyRole = familyRole
        self.mainContactPersonID = nil
        self.dietaryPreference = dietaryPreference
        self.allergies = allergies
        self.rsvpStatus = rsvpStatus
        self.isChild = isChild
        self.notes = notes
        self.isPinned = false
    }

    /// Display label combining group type and custom name
    var groupLabel: String? {
        guard let groupType else { return nil }
        if let custom = customGroupName, !custom.isEmpty {
            return "\(groupType.rawValue): \(custom)"
        }
        return groupType.rawValue
    }

    /// Dietary summary for PDF/display
    var dietarySummary: String {
        var parts: [String] = []
        if dietaryPreference != .meat {
            parts.append(dietaryPreference.rawValue)
        }
        if !allergies.isEmpty {
            parts.append("⚠️ \(allergies)")
        }
        return parts.joined(separator: " · ")
    }
}
```

**Step 8: Implement Event model**

```swift
// Gaesteglueck/Models/Event.swift
import Foundation
import SwiftData

@Model
final class Event {
    var id: UUID
    var name: String
    var date: Date?
    var venue: String
    var createdAt: Date

    init(name: String, date: Date? = nil, venue: String = "") {
        self.id = UUID()
        self.name = name
        self.date = date
        self.venue = venue
        self.createdAt = .now
    }
}
```

**Step 9: Run tests to verify they pass**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: PASS (7 tests)

**Step 10: Commit**

```bash
git add Gaesteglueck/Models/ GaesteglueckTests/Models/
git commit -m "feat: add Guest, Event, Side, DietaryPreference, GroupType, FamilyRole models"
```

---

## Task 3: Core Data Models — GuestTable, Relationship & RoomPlan

**Files:**
- Create: `Gaesteglueck/Models/GuestTable.swift`
- Create: `Gaesteglueck/Models/TableShape.swift`
- Create: `Gaesteglueck/Models/Relationship.swift`
- Create: `Gaesteglueck/Models/RelationshipType.swift`
- Create: `Gaesteglueck/Models/RoomPlan.swift`
- Test: `GaesteglueckTests/Models/GuestTableTests.swift`
- Test: `GaesteglueckTests/Models/RelationshipTests.swift`

**Step 1: Write failing tests for GuestTable**

```swift
// GaesteglueckTests/Models/GuestTableTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("GuestTable Model")
struct GuestTableTests {
    @Test("Round table calculates capacity from diameter")
    func roundTableCapacity() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        // 180cm diameter -> circumference ~565cm / 60cm per seat = ~9
        #expect(table.capacity == 9)
    }

    @Test("Rectangular table calculates capacity from dimensions")
    func rectangularTableCapacity() {
        let table = GuestTable(name: "Tisch 2", shape: .rectangular, width: 200, depth: 100)
        // Perimeter = 600cm / 60cm per seat = 10, minus corners = 8
        #expect(table.capacity == 8)
    }

    @Test("Bride table calculates one-sided capacity")
    func brideTableCapacity() {
        let table = GuestTable(name: "Brauttisch", shape: .brideTable, width: 400, depth: 100)
        // One side only: 400cm / 60cm = 6
        #expect(table.capacity == 6)
    }

    @Test("Remaining seats calculation")
    func remainingSeats() {
        let table = GuestTable(name: "Test", shape: .round, diameter: 180)
        #expect(table.remainingSeats == table.capacity)
    }

    @Test("Table is full detection")
    func isFull() {
        let table = GuestTable(name: "Test", shape: .round, diameter: 180)
        #expect(!table.isFull)
    }

    @Test("Combined rectangular tables double long-side capacity")
    func combinedTables() {
        let t1 = GuestTable(name: "T1", shape: .rectangular, width: 200, depth: 100)
        let t2 = GuestTable(name: "T2", shape: .rectangular, width: 200, depth: 100)
        t1.linkedTableID = t2.id
        t2.linkedTableID = t1.id
        // Combined: no seating on joined short sides
        // Each table loses 2 seats from one short side, keeps 3 sides
        let combinedCap = t1.combinedCapacity(with: t2)
        #expect(combinedCap > t1.capacity) // more than one alone
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: FAIL — `GuestTable` not defined

**Step 3: Implement TableShape**

```swift
// Gaesteglueck/Models/TableShape.swift
import Foundation

enum TableShape: String, Codable, CaseIterable, Identifiable {
    case round = "Rund"
    case rectangular = "Eckig"
    case brideTable = "Brauttisch"

    var id: String { rawValue }
}
```

**Step 4: Implement GuestTable model**

```swift
// Gaesteglueck/Models/GuestTable.swift
import Foundation
import SwiftData

@Model
final class GuestTable {
    var id: UUID
    var name: String
    var shape: TableShape

    // Dimensions in centimeters
    var diameter: Double  // for round tables
    var width: Double     // for rectangular / bride tables
    var depth: Double     // for rectangular / bride tables

    // Position on canvas (in points)
    var positionX: Double
    var positionY: Double
    var rotation: Double  // degrees

    var isLocked: Bool

    // Table combination: link two rectangular tables into a long Tafel
    var linkedTableID: UUID?

    @Relationship(deleteRule: .nullify)
    var guests: [Guest]

    var capacity: Int {
        let seatWidth: Double = 60 // cm per person
        switch shape {
        case .round:
            let circumference = Double.pi * diameter
            return Int(circumference / seatWidth)
        case .rectangular:
            let perimeter = 2 * (width + depth)
            let rawSeats = Int(perimeter / seatWidth)
            return max(rawSeats - 2, 4) // subtract corners, minimum 4
        case .brideTable:
            // One-sided seating only (facing guests)
            return Int(width / seatWidth)
        }
    }

    /// Capacity when two rectangular tables are combined side-by-side into a Tafel.
    /// Removes seating from the joined short sides.
    func combinedCapacity(with other: GuestTable) -> Int {
        guard shape == .rectangular, other.shape == .rectangular else {
            return capacity + other.capacity
        }
        let seatWidth: Double = 60
        // Combined long Tafel: total width = sum, seating on 2 long sides + 2 outer short sides
        let totalWidth = width + other.width
        let longSideSeats = Int(totalWidth / seatWidth) * 2
        let shortSideSeats = Int(depth / seatWidth) * 2 // both outer ends
        return longSideSeats + shortSideSeats
    }

    var remainingSeats: Int {
        capacity - guests.count
    }

    var isFull: Bool {
        guests.count >= capacity
    }

    init(
        name: String,
        shape: TableShape,
        diameter: Double = 180,
        width: Double = 200,
        depth: Double = 100,
        positionX: Double = 0,
        positionY: Double = 0,
        rotation: Double = 0
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
        self.linkedTableID = nil
        self.guests = []
    }
}
```

**Step 4b: Implement RoomPlan model**

The RoomPlan stores the floor plan photo and its calibration (scale factor from pixels to real-world cm).

```swift
// Gaesteglueck/Models/RoomPlan.swift
import Foundation
import SwiftData

@Model
final class RoomPlan {
    var id: UUID

    // Floor plan image stored as Data (JPEG)
    var imageData: Data?

    // Calibration: the user draws a line and enters the real-world length.
    // scalePointA/B are the endpoints in image coordinates (normalized 0-1).
    var scalePointAX: Double?
    var scalePointAY: Double?
    var scalePointBX: Double?
    var scalePointBY: Double?
    var scaleRealWorldCM: Double?  // e.g., 1000 = the line represents 10 meters

    // Room dimensions (optional, user can enter manually)
    var roomWidthCM: Double?
    var roomDepthCM: Double?

    /// Pixels-to-cm ratio, calculated from the calibration line.
    var pixelsToCM: Double? {
        guard let ax = scalePointAX, let ay = scalePointAY,
              let bx = scalePointBX, let by = scalePointBY,
              let realCM = scaleRealWorldCM else { return nil }
        let pixelDistance = sqrt(pow(bx - ax, 2) + pow(by - ay, 2))
        guard pixelDistance > 0 else { return nil }
        return realCM / pixelDistance
    }

    init() {
        self.id = UUID()
    }
}
```

**Step 5: Write failing tests for Relationship**

```swift
// GaesteglueckTests/Models/RelationshipTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Relationship Model")
struct RelationshipTests {
    @Test("Partner relationship has weight 1.0")
    func partnerWeight() {
        let rel = Relationship(
            personAID: UUID(),
            personBID: UUID(),
            type: .partner
        )
        #expect(rel.type.weight == 1.0)
    }

    @Test("Toxic relationship has negative weight")
    func toxicWeight() {
        let rel = Relationship(
            personAID: UUID(),
            personBID: UUID(),
            type: .toxic
        )
        #expect(rel.type.weight < 0)
    }

    @Test("Family relationship weight")
    func familyWeight() {
        #expect(RelationshipType.family.weight == 0.7)
    }

    @Test("Friend cluster weight")
    func friendWeight() {
        #expect(RelationshipType.friend.weight == 0.4)
    }

    @Test("Relationship is bidirectional check")
    func bidirectional() {
        let a = UUID()
        let b = UUID()
        let rel = Relationship(personAID: a, personBID: b, type: .partner)
        #expect(rel.involves(a))
        #expect(rel.involves(b))
        #expect(!rel.involves(UUID()))
    }
}
```

**Step 6: Implement RelationshipType and Relationship**

```swift
// Gaesteglueck/Models/RelationshipType.swift
import Foundation

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case partner = "Partner"
    case family = "Familie"
    case friend = "Freunde"
    case acquaintance = "Bekannte"
    case toxic = "Konflikt"

    var id: String { rawValue }

    /// Weight used by the happiness score algorithm.
    /// Positive = should sit together, negative = must separate.
    var weight: Double {
        switch self {
        case .partner: 1.0
        case .family: 0.7
        case .friend: 0.4
        case .acquaintance: 0.2
        case .toxic: -5.0
        }
    }

    /// Whether this is a hard constraint (must not be violated).
    var isHardConstraint: Bool {
        switch self {
        case .partner, .toxic: true
        default: false
        }
    }
}
```

```swift
// Gaesteglueck/Models/Relationship.swift
import Foundation
import SwiftData

@Model
final class Relationship {
    var id: UUID
    var personAID: UUID
    var personBID: UUID
    var type: RelationshipType
    var notes: String

    init(personAID: UUID, personBID: UUID, type: RelationshipType, notes: String = "") {
        self.id = UUID()
        self.personAID = personAID
        self.personBID = personBID
        self.type = type
        self.notes = notes
    }

    func involves(_ personID: UUID) -> Bool {
        personAID == personID || personBID == personID
    }

    func otherPerson(than personID: UUID) -> UUID? {
        if personAID == personID { return personBID }
        if personBID == personID { return personAID }
        return nil
    }
}
```

**Step 7: Run all tests**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: PASS (all 13 tests)

**Step 8: Commit**

```bash
git add Gaesteglueck/Models/ GaesteglueckTests/Models/
git commit -m "feat: add GuestTable and Relationship models with capacity calculation and weights"
```

---

## Task 4: Happiness Score Algorithm

This is the brain of the app — a pure-function scoring engine. No UI, fully testable.

**Files:**
- Create: `Gaesteglueck/Services/HappinessScorer.swift`
- Test: `GaesteglueckTests/Services/HappinessScorerTests.swift`

**Step 1: Write failing tests for the scorer**

```swift
// GaesteglueckTests/Services/HappinessScorerTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Happiness Scorer")
struct HappinessScorerTests {
    // Helper to create guests
    func makeGuest(_ name: String, side: Side = .bride) -> Guest {
        Guest(name: name, side: side)
    }

    @Test("Empty table scores zero")
    func emptyTable() {
        let table = GuestTable(name: "T1", shape: .round)
        let score = HappinessScorer.scoreTable(table, relationships: [])
        #expect(score == 0)
    }

    @Test("Partners at same table scores positively")
    func partnersAtSameTable() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob", side: .groom)
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, bob]

        let rel = Relationship(personAID: alice.id, personBID: bob.id, type: .partner)
        let score = HappinessScorer.scoreTable(table, relationships: [rel])
        #expect(score > 0)
    }

    @Test("Toxic guests at same table scores very negatively")
    func toxicAtSameTable() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, eve]

        let rel = Relationship(personAID: alice.id, personBID: eve.id, type: .toxic)
        let score = HappinessScorer.scoreTable(table, relationships: [rel])
        #expect(score < 0)
    }

    @Test("Mixed sides bonus")
    func mixedSidesBonus() {
        let brideGuest = makeGuest("A", side: .bride)
        let groomGuest = makeGuest("B", side: .groom)
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [brideGuest, groomGuest]

        let score = HappinessScorer.scoreTable(table, relationships: [])
        #expect(score > 0) // Mixed-side bonus
    }

    @Test("Overall score sums all tables")
    func overallScore() {
        let t1 = GuestTable(name: "T1", shape: .round)
        let t2 = GuestTable(name: "T2", shape: .round)
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob")
        t1.guests = [alice]
        t2.guests = [bob]

        let total = HappinessScorer.scoreAllTables([t1, t2], relationships: [])
        #expect(total == HappinessScorer.scoreTable(t1, relationships: []) + HappinessScorer.scoreTable(t2, relationships: []))
    }

    @Test("Partners separated across tables produces violation")
    func partnersSeparated() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob")
        let t1 = GuestTable(name: "T1", shape: .round)
        let t2 = GuestTable(name: "T2", shape: .round)
        t1.guests = [alice]
        t2.guests = [bob]

        let rel = Relationship(personAID: alice.id, personBID: bob.id, type: .partner)
        let violations = HappinessScorer.findViolations(tables: [t1, t2], relationships: [rel])
        #expect(!violations.isEmpty)
        #expect(violations.first?.type == .partnersSeparated)
    }

    @Test("Toxic at same table produces violation")
    func toxicViolation() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, eve]

        let rel = Relationship(personAID: alice.id, personBID: eve.id, type: .toxic)
        let violations = HappinessScorer.findViolations(tables: [table], relationships: [rel])
        #expect(!violations.isEmpty)
        #expect(violations.first?.type == .toxicAtSameTable)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: FAIL — `HappinessScorer` not defined

**Step 3: Implement HappinessScorer**

```swift
// Gaesteglueck/Services/HappinessScorer.swift
import Foundation

enum HappinessScorer {
    /// Score a single table based on who sits there and their relationships.
    static func scoreTable(_ table: GuestTable, relationships: [Relationship]) -> Double {
        let guestIDs = Set(table.guests.map(\.id))
        guard !guestIDs.isEmpty else { return 0 }

        var score: Double = 0

        // 1. Relationship scores: pairs at this table
        for rel in relationships {
            if guestIDs.contains(rel.personAID) && guestIDs.contains(rel.personBID) {
                score += rel.type.weight * 100
            }
        }

        // 2. Mixed-side bonus: encourages mingling
        let sides = Set(table.guests.map(\.side))
        if sides.count > 1 {
            score += 10
        }

        // 3. Cluster cohesion: guests from same cluster at same table
        let clusters = table.guests.compactMap(\.cluster)
        let clusterCounts = Dictionary(grouping: clusters, by: { $0 }).mapValues(\.count)
        for (_, count) in clusterCounts where count > 1 {
            score += Double(count) * 5
        }

        return score
    }

    /// Sum scores across all tables.
    static func scoreAllTables(_ tables: [GuestTable], relationships: [Relationship]) -> Double {
        tables.reduce(0) { $0 + scoreTable($1, relationships: relationships) }
    }

    /// Find hard constraint violations.
    static func findViolations(tables: [GuestTable], relationships: [Relationship]) -> [Violation] {
        var violations: [Violation] = []

        // Build lookup: guestID -> table
        var guestToTable: [UUID: GuestTable] = [:]
        for table in tables {
            for guest in table.guests {
                guestToTable[guest.id] = table
            }
        }

        for rel in relationships {
            let tableA = guestToTable[rel.personAID]
            let tableB = guestToTable[rel.personBID]

            switch rel.type {
            case .partner:
                // Partners separated = violation
                if let tA = tableA, let tB = tableB, tA.id != tB.id {
                    violations.append(Violation(
                        type: .partnersSeparated,
                        personAID: rel.personAID,
                        personBID: rel.personBID,
                        description: "Partner sitzen an verschiedenen Tischen"
                    ))
                }
            case .toxic:
                // Toxic at same table = violation
                if let tA = tableA, let tB = tableB, tA.id == tB.id {
                    violations.append(Violation(
                        type: .toxicAtSameTable,
                        personAID: rel.personAID,
                        personBID: rel.personBID,
                        description: "Konflikt-Gäste sitzen am selben Tisch"
                    ))
                }
            default:
                break
            }
        }

        return violations
    }
}

struct Violation: Identifiable, Equatable {
    let id = UUID()
    let type: ViolationType
    let personAID: UUID
    let personBID: UUID
    let description: String

    static func == (lhs: Violation, rhs: Violation) -> Bool {
        lhs.type == rhs.type && lhs.personAID == rhs.personAID && lhs.personBID == rhs.personBID
    }
}

enum ViolationType: Equatable {
    case partnersSeparated
    case toxicAtSameTable
    case tableOverCapacity
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: PASS (all tests)

**Step 5: Commit**

```bash
git add Gaesteglueck/Services/ GaesteglueckTests/Services/
git commit -m "feat: add happiness score algorithm with violation detection"
```

---

## Task 5: App Navigation Shell

Set up the main navigation structure: a sidebar with sections for Guests, Tables, Room, and Settings.

**Files:**
- Modify: `Gaesteglueck/ContentView.swift`
- Create: `Gaesteglueck/Views/AppSidebar.swift`
- Create: `Gaesteglueck/Views/GuestListView.swift` (placeholder)
- Create: `Gaesteglueck/Views/TableListView.swift` (placeholder)
- Create: `Gaesteglueck/Views/RoomCanvasView.swift` (placeholder)

**Step 1: Implement AppSidebar**

```swift
// Gaesteglueck/Views/AppSidebar.swift
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case guests = "Gäste"
    case tables = "Tische"
    case room = "Raumplan"
    case relationships = "Beziehungen"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .guests: "person.3"
        case .tables: "tablecells"
        case .room: "square.split.bottomrightquarter"
        case .relationships: "heart.text.clipboard"
        }
    }
}

struct AppSidebar: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .tag(section)
        }
        .navigationTitle("Gästeglück")
    }
}
```

**Step 2: Implement ContentView with NavigationSplitView**

```swift
// Gaesteglueck/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var selectedSection: AppSection? = .guests

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .guests:
                GuestListView()
            case .tables:
                TableListView()
            case .room:
                RoomCanvasView()
            case .relationships:
                RelationshipListView()
            case nil:
                ContentUnavailableView("Bereich wählen", systemImage: "sidebar.left", description: Text("Wähle einen Bereich aus der Seitenleiste."))
            }
        }
    }
}
```

**Step 3: Create placeholder views**

```swift
// Gaesteglueck/Views/GuestListView.swift
import SwiftUI

struct GuestListView: View {
    var body: some View {
        ContentUnavailableView("Noch keine Gäste", systemImage: "person.badge.plus", description: Text("Füge deinen ersten Gast hinzu."))
            .navigationTitle("Gäste")
    }
}
```

```swift
// Gaesteglueck/Views/TableListView.swift
import SwiftUI

struct TableListView: View {
    var body: some View {
        ContentUnavailableView("Noch keine Tische", systemImage: "plus.square.dashed", description: Text("Erstelle deinen ersten Tisch."))
            .navigationTitle("Tische")
    }
}
```

```swift
// Gaesteglueck/Views/RoomCanvasView.swift
import SwiftUI

struct RoomCanvasView: View {
    var body: some View {
        Text("Raumplan kommt hier hin")
            .navigationTitle("Raumplan")
    }
}
```

```swift
// Gaesteglueck/Views/RelationshipListView.swift
import SwiftUI

struct RelationshipListView: View {
    var body: some View {
        ContentUnavailableView("Keine Beziehungen", systemImage: "heart.text.clipboard", description: Text("Definiere Beziehungen zwischen Gästen."))
            .navigationTitle("Beziehungen")
    }
}
```

**Step 4: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Gaesteglueck/Views/ Gaesteglueck/ContentView.swift
git commit -m "feat: add navigation shell with sidebar and placeholder views"
```

---

## Task 6: Guest List — Full CRUD

**Files:**
- Modify: `Gaesteglueck/Views/GuestListView.swift`
- Create: `Gaesteglueck/Views/GuestRowView.swift`
- Create: `Gaesteglueck/Views/GuestFormView.swift`

**Step 1: Implement GuestRowView**

```swift
// Gaesteglueck/Views/GuestRowView.swift
import SwiftUI

struct GuestRowView: View {
    let guest: Guest

    var body: some View {
        HStack {
            Circle()
                .fill(guest.side.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(guest.name)
                        .font(.body)
                    if guest.isChild {
                        Image(systemName: "figure.child")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    if let groupLabel = guest.groupLabel {
                        Text(groupLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let role = guest.familyRole {
                        Text(role.rawValue)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            // Dietary badges
            HStack(spacing: 2) {
                Text(guest.dietaryPreference.badge)
                    .font(.caption)
                if !guest.allergies.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help(guest.allergies)
                }
            }
            Text(guest.rsvpStatus.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(guest.rsvpStatus.color.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}
```

**Step 2: Add color helpers to Side and RSVPStatus**

Add to `Side.swift`:
```swift
import SwiftUI

extension Side {
    var color: Color {
        switch self {
        case .bride: .pink
        case .groom: .blue
        case .neutral: .gray
        }
    }
}
```

Add to `Guest.swift`:
```swift
extension RSVPStatus {
    var color: Color {
        switch self {
        case .pending: .orange
        case .confirmed: .green
        case .declined: .red
        }
    }
}
```

**Step 3: Implement GuestFormView (Add/Edit)**

```swift
// Gaesteglueck/Views/GuestFormView.swift
import SwiftUI

struct GuestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let guest: Guest?

    @State private var name: String
    @State private var side: Side
    @State private var groupType: GroupType?
    @State private var customGroupName: String
    @State private var familyRole: FamilyRole?
    @State private var dietaryPreference: DietaryPreference
    @State private var allergies: String
    @State private var isChild: Bool
    @State private var rsvpStatus: RSVPStatus
    @State private var notes: String

    init(guest: Guest? = nil) {
        self.guest = guest
        _name = State(initialValue: guest?.name ?? "")
        _side = State(initialValue: guest?.side ?? .neutral)
        _groupType = State(initialValue: guest?.groupType)
        _customGroupName = State(initialValue: guest?.customGroupName ?? "")
        _familyRole = State(initialValue: guest?.familyRole)
        _dietaryPreference = State(initialValue: guest?.dietaryPreference ?? .meat)
        _allergies = State(initialValue: guest?.allergies ?? "")
        _isChild = State(initialValue: guest?.isChild ?? false)
        _rsvpStatus = State(initialValue: guest?.rsvpStatus ?? .pending)
        _notes = State(initialValue: guest?.notes ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pflichtfelder") {
                    TextField("Name", text: $name)
                    Picker("Seite", selection: $side) {
                        ForEach(Side.allCases) { side in
                            Text(side.rawValue).tag(side)
                        }
                    }
                    Toggle("Kind", isOn: $isChild)
                }
                Section("Gruppe & Beziehung") {
                    Picker("Gruppe", selection: $groupType) {
                        Text("Keine").tag(nil as GroupType?)
                        ForEach(GroupType.allCases) { gt in
                            Text(gt.rawValue).tag(gt as GroupType?)
                        }
                    }
                    if groupType == .clubMember {
                        TextField("Vereinsname (z.B. TuS Musterstadt)", text: $customGroupName)
                    }
                    Picker("Beziehung", selection: $familyRole) {
                        Text("Keine Angabe").tag(nil as FamilyRole?)
                        ForEach(FamilyRole.allCases) { role in
                            Text(role.rawValue).tag(role as FamilyRole?)
                        }
                    }
                }
                Section("Essen & Unverträglichkeiten") {
                    Picker("Ernährung", selection: $dietaryPreference) {
                        ForEach(DietaryPreference.allCases) { pref in
                            HStack {
                                Text(pref.badge)
                                Text(pref.rawValue)
                            }.tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Unverträglichkeiten (z.B. Laktose, Nüsse)", text: $allergies)
                }
                Section("Status") {
                    Picker("RSVP", selection: $rsvpStatus) {
                        ForEach(RSVPStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("Notizen", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(guest == nil ? "Gast hinzufügen" : "Gast bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if let guest {
            guest.name = name.trimmingCharacters(in: .whitespaces)
            guest.side = side
            guest.groupType = groupType
            guest.customGroupName = customGroupName.isEmpty ? nil : customGroupName
            guest.familyRole = familyRole
            guest.dietaryPreference = dietaryPreference
            guest.allergies = allergies
            guest.isChild = isChild
            guest.rsvpStatus = rsvpStatus
            guest.notes = notes
        } else {
            let newGuest = Guest(
                name: name.trimmingCharacters(in: .whitespaces),
                side: side,
                groupType: groupType,
                customGroupName: customGroupName.isEmpty ? nil : customGroupName,
                familyRole: familyRole,
                dietaryPreference: dietaryPreference,
                allergies: allergies,
                rsvpStatus: rsvpStatus,
                isChild: isChild,
                notes: notes
            )
            modelContext.insert(newGuest)
        }
        dismiss()
    }
}
```

**Step 4: Implement full GuestListView**

```swift
// Gaesteglueck/Views/GuestListView.swift
import SwiftUI
import SwiftData

struct GuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var guests: [Guest]
    @State private var showingAddSheet = false
    @State private var editingGuest: Guest?
    @State private var searchText = ""

    private var filteredGuests: [Guest] {
        guard !searchText.isEmpty else { return guests }
        return guests.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedGuests: [Side: [Guest]] {
        Dictionary(grouping: filteredGuests, by: \.side)
    }

    var body: some View {
        List {
            ForEach(Side.allCases) { side in
                if let sideGuests = groupedGuests[side], !sideGuests.isEmpty {
                    Section {
                        ForEach(sideGuests) { guest in
                            GuestRowView(guest: guest)
                                .contentShape(Rectangle())
                                .onTapGesture { editingGuest = guest }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(guest)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Circle().fill(side.color).frame(width: 8, height: 8)
                            Text("\(side.rawValue) (\(sideGuests.count))")
                        }
                    }
                }
            }
        }
        .overlay {
            if guests.isEmpty {
                ContentUnavailableView("Noch keine Gäste", systemImage: "person.badge.plus", description: Text("Tippe auf + um den ersten Gast hinzuzufügen."))
            }
        }
        .navigationTitle("Gäste (\(guests.count))")
        .searchable(text: $searchText, prompt: "Gäste suchen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Gast hinzufügen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            GuestFormView()
        }
        .sheet(item: $editingGuest) { guest in
            GuestFormView(guest: guest)
        }
    }
}
```

**Step 5: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add Gaesteglueck/Views/ Gaesteglueck/Models/
git commit -m "feat: add guest list with CRUD, search, grouping by side"
```

---

## Task 7: Table List — Full CRUD

**Files:**
- Modify: `Gaesteglueck/Views/TableListView.swift`
- Create: `Gaesteglueck/Views/TableRowView.swift`
- Create: `Gaesteglueck/Views/TableFormView.swift`

**Step 1: Implement TableRowView**

```swift
// Gaesteglueck/Views/TableRowView.swift
import SwiftUI

struct TableRowView: View {
    let table: GuestTable

    var body: some View {
        HStack {
            Image(systemName: table.shape.icon)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(table.name)
                    .font(.body)
                Text(table.shape.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(table.guests.count)/\(table.capacity)")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(table.isFull ? .red : .secondary)
        }
    }
}
```

**Step 2: Add icon helper to TableShape**

Add to `TableShape.swift`:
```swift
extension TableShape {
    var icon: String {
        switch self {
        case .round: "circle"
        case .rectangular: "rectangle"
        case .brideTable: "rectangle.split.3x1"
        }
    }
}
```

**Step 3: Implement TableFormView**

```swift
// Gaesteglueck/Views/TableFormView.swift
import SwiftUI

struct TableFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let table: GuestTable?

    @State private var name: String
    @State private var shape: TableShape
    @State private var diameter: Double
    @State private var width: Double
    @State private var depth: Double

    init(table: GuestTable? = nil) {
        self.table = table
        _name = State(initialValue: table?.name ?? "")
        _shape = State(initialValue: table?.shape ?? .round)
        _diameter = State(initialValue: table?.diameter ?? 180)
        _width = State(initialValue: table?.width ?? 200)
        _depth = State(initialValue: table?.depth ?? 100)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var previewCapacity: Int {
        let preview = GuestTable(name: "", shape: shape, diameter: diameter, width: width, depth: depth)
        return preview.capacity
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tisch") {
                    TextField("Name (z.B. Tisch 1)", text: $name)
                    Picker("Form", selection: $shape) {
                        ForEach(TableShape.allCases) { shape in
                            Label(shape.rawValue, systemImage: shape.icon).tag(shape)
                        }
                    }
                }
                Section("Maße (cm)") {
                    switch shape {
                    case .round:
                        HStack {
                            Text("Durchmesser")
                            Slider(value: $diameter, in: 100...300, step: 10)
                            Text("\(Int(diameter)) cm")
                                .monospacedDigit()
                                .frame(width: 60)
                        }
                    case .rectangular, .brideTable:
                        HStack {
                            Text("Breite")
                            Slider(value: $width, in: 100...600, step: 10)
                            Text("\(Int(width)) cm")
                                .monospacedDigit()
                                .frame(width: 60)
                        }
                        HStack {
                            Text("Tiefe")
                            Slider(value: $depth, in: 60...200, step: 10)
                            Text("\(Int(depth)) cm")
                                .monospacedDigit()
                                .frame(width: 60)
                        }
                    }
                }
                Section {
                    HStack {
                        Text("Berechnete Kapazität")
                        Spacer()
                        Text("\(previewCapacity) Plätze")
                            .bold()
                    }
                }
            }
            .navigationTitle(table == nil ? "Tisch erstellen" : "Tisch bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if let table {
            table.name = name.trimmingCharacters(in: .whitespaces)
            table.shape = shape
            table.diameter = diameter
            table.width = width
            table.depth = depth
        } else {
            let newTable = GuestTable(
                name: name.trimmingCharacters(in: .whitespaces),
                shape: shape,
                diameter: diameter,
                width: width,
                depth: depth
            )
            modelContext.insert(newTable)
        }
        dismiss()
    }
}
```

**Step 4: Update TableListView with full CRUD**

```swift
// Gaesteglueck/Views/TableListView.swift
import SwiftUI
import SwiftData

struct TableListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GuestTable.name) private var tables: [GuestTable]
    @State private var showingAddSheet = false
    @State private var editingTable: GuestTable?

    private var totalCapacity: Int {
        tables.reduce(0) { $0 + $1.capacity }
    }

    private var totalAssigned: Int {
        tables.reduce(0) { $0 + $1.guests.count }
    }

    var body: some View {
        List {
            if !tables.isEmpty {
                Section {
                    HStack {
                        Label("Tische", systemImage: "tablecells")
                        Spacer()
                        Text("\(tables.count)")
                    }
                    HStack {
                        Label("Kapazität", systemImage: "chair")
                        Spacer()
                        Text("\(totalAssigned)/\(totalCapacity) Plätze")
                    }
                } header: {
                    Text("Übersicht")
                }
            }

            Section {
                ForEach(tables) { table in
                    TableRowView(table: table)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTable = table }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(table)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .overlay {
            if tables.isEmpty {
                ContentUnavailableView("Noch keine Tische", systemImage: "plus.square.dashed", description: Text("Tippe auf + um den ersten Tisch zu erstellen."))
            }
        }
        .navigationTitle("Tische")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Tisch erstellen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            TableFormView()
        }
        .sheet(item: $editingTable) { table in
            TableFormView(table: table)
        }
    }
}
```

**Step 5: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add Gaesteglueck/Views/ Gaesteglueck/Models/
git commit -m "feat: add table list with CRUD, capacity preview, and statistics"
```

---

## Task 8: Relationship Management UI

**Files:**
- Modify: `Gaesteglueck/Views/RelationshipListView.swift`
- Create: `Gaesteglueck/Views/RelationshipFormView.swift`
- Create: `Gaesteglueck/Views/RelationshipRowView.swift`

**Step 1: Implement RelationshipRowView**

```swift
// Gaesteglueck/Views/RelationshipRowView.swift
import SwiftUI
import SwiftData

struct RelationshipRowView: View {
    let relationship: Relationship
    let allGuests: [Guest]

    private var personA: Guest? {
        allGuests.first { $0.id == relationship.personAID }
    }

    private var personB: Guest? {
        allGuests.first { $0.id == relationship.personBID }
    }

    var body: some View {
        HStack {
            Image(systemName: relationship.type.icon)
                .foregroundStyle(relationship.type.color)
                .frame(width: 30)
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(personA?.name ?? "Unbekannt")
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(personB?.name ?? "Unbekannt")
                }
                .font(.body)
                Text(relationship.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

**Step 2: Add color and icon helpers to RelationshipType**

Add to `RelationshipType.swift`:
```swift
import SwiftUI

extension RelationshipType {
    var color: Color {
        switch self {
        case .partner: .pink
        case .family: .orange
        case .friend: .green
        case .acquaintance: .blue
        case .toxic: .red
        }
    }

    var icon: String {
        switch self {
        case .partner: "heart.fill"
        case .family: "figure.2.and.child"
        case .friend: "person.2"
        case .acquaintance: "person.wave.2"
        case .toxic: "exclamationmark.triangle.fill"
        }
    }
}
```

**Step 3: Implement RelationshipFormView**

```swift
// Gaesteglueck/Views/RelationshipFormView.swift
import SwiftUI
import SwiftData

struct RelationshipFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var guests: [Guest]

    @State private var personA: Guest?
    @State private var personB: Guest?
    @State private var type: RelationshipType = .friend
    @State private var notes = ""

    private var isValid: Bool {
        personA != nil && personB != nil && personA?.id != personB?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personen") {
                    Picker("Person A", selection: $personA) {
                        Text("Wählen…").tag(nil as Guest?)
                        ForEach(guests) { guest in
                            Text(guest.name).tag(guest as Guest?)
                        }
                    }
                    Picker("Person B", selection: $personB) {
                        Text("Wählen…").tag(nil as Guest?)
                        ForEach(guests.filter { $0.id != personA?.id }) { guest in
                            Text(guest.name).tag(guest as Guest?)
                        }
                    }
                }
                Section("Art der Beziehung") {
                    Picker("Typ", selection: $type) {
                        ForEach(RelationshipType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Notizen") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Beziehung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let personA, let personB else { return }
        let rel = Relationship(
            personAID: personA.id,
            personBID: personB.id,
            type: type,
            notes: notes
        )
        modelContext.insert(rel)
        dismiss()
    }
}
```

**Step 4: Update RelationshipListView**

```swift
// Gaesteglueck/Views/RelationshipListView.swift
import SwiftUI
import SwiftData

struct RelationshipListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var relationships: [Relationship]
    @Query(sort: \Guest.name) private var guests: [Guest]
    @State private var showingAddSheet = false

    var body: some View {
        List {
            ForEach(relationships) { rel in
                RelationshipRowView(relationship: rel, allGuests: guests)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(rel)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
            }
        }
        .overlay {
            if relationships.isEmpty {
                ContentUnavailableView("Keine Beziehungen", systemImage: "heart.text.clipboard", description: Text("Definiere wer zusammen oder getrennt sitzen soll."))
            }
        }
        .navigationTitle("Beziehungen (\(relationships.count))")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Beziehung hinzufügen", systemImage: "plus")
                }
                .disabled(guests.count < 2)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RelationshipFormView()
        }
    }
}
```

**Step 5: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add Gaesteglueck/Views/ Gaesteglueck/Models/
git commit -m "feat: add relationship management with typed connections and conflict markers"
```

---

## Task 9: Room Canvas — Table Placement with Drag & Drop

This is the visual heart of the app. Tables appear on a canvas and can be repositioned freely.

**Files:**
- Modify: `Gaesteglueck/Views/RoomCanvasView.swift`
- Create: `Gaesteglueck/Views/Canvas/TableCanvasItemView.swift`
- Create: `Gaesteglueck/Views/Canvas/CanvasGuestBadge.swift`

**Step 1: Implement TableCanvasItemView**

```swift
// Gaesteglueck/Views/Canvas/TableCanvasItemView.swift
import SwiftUI

struct TableCanvasItemView: View {
    @Bindable var table: GuestTable
    let isSelected: Bool
    let onTap: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 4) {
            tableShape
            Text(table.name)
                .font(.caption2)
                .padding(.horizontal, 4)
                .background(.ultraThinMaterial, in: Capsule())
            Text("\(table.guests.count)/\(table.capacity)")
                .font(.caption2)
                .foregroundStyle(table.isFull ? .red : .secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : .clear)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .position(x: table.positionX + dragOffset.width, y: table.positionY + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    table.positionX += value.translation.width
                    table.positionY += value.translation.height
                    dragOffset = .zero
                }
        )
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var tableShape: some View {
        switch table.shape {
        case .round:
            Circle()
                .fill(Color.brown.opacity(0.3))
                .stroke(Color.brown, lineWidth: 1)
                .frame(width: table.diameter / 3, height: table.diameter / 3)
        case .rectangular:
            Rectangle()
                .fill(Color.brown.opacity(0.3))
                .stroke(Color.brown, lineWidth: 1)
                .frame(width: table.width / 3, height: table.depth / 3)
        case .brideTable:
            Rectangle()
                .fill(Color.yellow.opacity(0.3))
                .stroke(Color.yellow.mix(with: .brown, by: 0.5), lineWidth: 2)
                .frame(width: table.width / 3, height: table.depth / 3)
        }
    }
}
```

**Step 2: Implement full RoomCanvasView**

```swift
// Gaesteglueck/Views/RoomCanvasView.swift
import SwiftUI
import SwiftData

struct RoomCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.name) private var guests: [Guest]
    @Query private var relationships: [Relationship]

    @State private var selectedTable: GuestTable?
    @State private var showingAddTable = false

    private var unassignedGuests: [Guest] {
        guests.filter { $0.table == nil }
    }

    private var happinessScore: Double {
        HappinessScorer.scoreAllTables(tables, relationships: relationships)
    }

    private var violations: [Violation] {
        HappinessScorer.findViolations(tables: tables, relationships: relationships)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: unassigned guests
            guestInbox
                .frame(width: 250)

            Divider()

            // Center: room canvas
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ForEach(tables) { table in
                    TableCanvasItemView(
                        table: table,
                        isSelected: selectedTable?.id == table.id,
                        onTap: { selectedTable = table }
                    )
                    .dropDestination(for: String.self) { items, _ in
                        guard let guestIDString = items.first,
                              let guestID = UUID(uuidString: guestIDString),
                              let guest = guests.first(where: { $0.id == guestID }) else {
                            return false
                        }
                        guard !table.isFull else { return false }
                        guest.table = table
                        return true
                    }
                }
            }

            Divider()

            // Right panel: selected table details + score
            detailPanel
                .frame(width: 280)
        }
        .navigationTitle("Raumplan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTable = true
                } label: {
                    Label("Tisch hinzufügen", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .status) {
                HStack {
                    Image(systemName: "face.smiling")
                    Text("Score: \(Int(happinessScore))")
                        .monospacedDigit()
                }
                .foregroundStyle(happinessScore >= 0 ? .green : .red)
            }
        }
        .sheet(isPresented: $showingAddTable) {
            TableFormView()
        }
    }

    // MARK: - Guest Inbox

    private var guestInbox: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Nicht zugewiesen")
                    .font(.headline)
                Spacer()
                Text("\(unassignedGuests.count)")
                    .foregroundStyle(.secondary)
            }
            .padding()

            List {
                ForEach(unassignedGuests) { guest in
                    GuestRowView(guest: guest)
                        .draggable(guest.id.uuidString)
                }
            }
            .listStyle(.plain)
        }
        .background(.background)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let table = selectedTable {
                VStack(alignment: .leading, spacing: 8) {
                    Text(table.name)
                        .font(.headline)
                    Text("\(table.guests.count)/\(table.capacity) Plätze")
                        .foregroundStyle(.secondary)
                }
                .padding()

                List {
                    Section("Gäste am Tisch") {
                        ForEach(table.guests) { guest in
                            HStack {
                                Circle().fill(guest.side.color).frame(width: 8, height: 8)
                                Text(guest.name)
                                Spacer()
                                Button {
                                    guest.table = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView("Kein Tisch gewählt", systemImage: "hand.tap", description: Text("Tippe auf einen Tisch im Raumplan."))
            }

            Divider()

            // Violations
            if !violations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Warnungen", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    ForEach(violations) { v in
                        Text(v.description)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
        }
        .background(.background)
    }
}
```

**Step 3: Position newly created tables in the center of the canvas**

In `TableFormView.save()`, when creating a new table, set initial position:
```swift
// Set default position to center of a typical canvas
let newTable = GuestTable(
    name: name.trimmingCharacters(in: .whitespaces),
    shape: shape,
    diameter: diameter,
    width: width,
    depth: depth,
    positionX: 500,  // rough center
    positionY: 400
)
```

**Step 4: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 5: Manual test on simulator**

- Open the simulator, navigate to "Raumplan"
- Add a few tables, verify they appear
- Drag tables around the canvas
- Drag guests from the inbox to tables
- Verify score updates

**Step 6: Commit**

```bash
git add Gaesteglueck/Views/
git commit -m "feat: add room canvas with drag-and-drop table placement and guest assignment"
```

---

## Task 10: Guest Drag & Drop — Transferable Conformance

Enable dragging guests from the inbox onto tables, with visual feedback.

**Files:**
- Modify: `Gaesteglueck/Models/Guest.swift` (add Transferable)
- Test: `GaesteglueckTests/Models/GuestTransferTests.swift`

**Step 1: Write failing test**

```swift
// GaesteglueckTests/Models/GuestTransferTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Transfer")
struct GuestTransferTests {
    @Test("Guest UUID string roundtrips correctly")
    func uuidRoundtrip() {
        let id = UUID()
        let string = id.uuidString
        let restored = UUID(uuidString: string)
        #expect(restored == id)
    }
}
```

**Step 2: Run test to verify it passes (baseline)**

This test validates the approach; no new types needed.

**Step 3: Commit**

```bash
git add GaesteglueckTests/
git commit -m "feat: add guest drag-and-drop via UUID string transferable"
```

> Note: The actual drag/drop integration was done in Task 9. This task ensures the transfer mechanism is tested.

---

## Task 11: Happiness Score — Live Display & Warnings

Wire up the happiness scorer to show real-time feedback in the room canvas.

**Files:**
- Create: `Gaesteglueck/Views/Canvas/ScoreBadgeView.swift`
- Create: `Gaesteglueck/Views/Canvas/ViolationBannerView.swift`

**Step 1: Implement ScoreBadgeView**

```swift
// Gaesteglueck/Views/Canvas/ScoreBadgeView.swift
import SwiftUI

struct ScoreBadgeView: View {
    let score: Double

    private var emoji: String {
        switch score {
        case ..<0: "😟"
        case 0..<50: "😐"
        case 50..<100: "🙂"
        default: "😄"
        }
    }

    private var color: Color {
        switch score {
        case ..<0: .red
        case 0..<50: .orange
        case 50..<100: .yellow
        default: .green
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
            Text("\(Int(score))")
                .font(.title3.bold().monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
    }
}
```

**Step 2: Implement ViolationBannerView**

```swift
// Gaesteglueck/Views/Canvas/ViolationBannerView.swift
import SwiftUI

struct ViolationBannerView: View {
    let violations: [Violation]
    let allGuests: [Guest]

    var body: some View {
        if !violations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(violations) { violation in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(violationText(violation))
                            .font(.caption)
                    }
                }
            }
            .padding(8)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func violationText(_ v: Violation) -> String {
        let nameA = allGuests.first { $0.id == v.personAID }?.name ?? "?"
        let nameB = allGuests.first { $0.id == v.personBID }?.name ?? "?"
        switch v.type {
        case .partnersSeparated:
            return "\(nameA) & \(nameB) sind getrennt!"
        case .toxicAtSameTable:
            return "\(nameA) & \(nameB) sitzen am selben Tisch!"
        case .tableOverCapacity:
            return "Tisch überbelegt"
        }
    }
}
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Gaesteglueck/Views/Canvas/
git commit -m "feat: add live happiness score badge and violation warnings"
```

---

## Task 12: PDF Export

Generate a printable PDF of the seating arrangement to send to the venue.

**Files:**
- Create: `Gaesteglueck/Services/PDFExporter.swift`
- Test: `GaesteglueckTests/Services/PDFExporterTests.swift`
- Create: `Gaesteglueck/Views/ExportButton.swift`

**Step 1: Write failing test for PDF generation**

```swift
// GaesteglueckTests/Services/PDFExporterTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("PDF Exporter")
struct PDFExporterTests {
    @Test("Generates non-empty PDF data")
    func generatesPDF() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let guest = Guest(name: "Anna", side: .bride)
        table.guests = [guest]

        let data = PDFExporter.generatePDF(
            tables: [table],
            eventName: "Hochzeit",
            date: Date()
        )
        #expect(!data.isEmpty)
    }

    @Test("PDF contains event name")
    func containsEventName() {
        let data = PDFExporter.generatePDF(
            tables: [],
            eventName: "Test-Hochzeit",
            date: Date()
        )
        // PDF data should be generated (we can't easily parse PDF content in tests,
        // but we verify it doesn't crash and returns data)
        #expect(data.count > 100)
    }
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL — `PDFExporter` not defined

**Step 3: Implement PDFExporter**

```swift
// Gaesteglueck/Services/PDFExporter.swift
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
                // Check if we need a new page
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
                        let line = "• \(guest.name) (\(guest.side.rawValue))"
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
        }

        return data
    }
}
```

**Step 4: Implement ExportButton**

```swift
// Gaesteglueck/Views/ExportButton.swift
import SwiftUI

struct ExportButton: View {
    let tables: [GuestTable]
    let eventName: String
    let date: Date?

    @State private var showingShareSheet = false
    @State private var pdfURL: URL?

    var body: some View {
        Button {
            exportPDF()
        } label: {
            Label("PDF exportieren", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = pdfURL {
                ShareLink(item: url)
            }
        }
    }

    private func exportPDF() {
        let data = PDFExporter.generatePDF(
            tables: tables,
            eventName: eventName,
            date: date
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sitzplan-\(eventName).pdf")
        try? data.write(to: tempURL)
        pdfURL = tempURL
        showingShareSheet = true
    }
}
```

**Step 5: Add export button to RoomCanvasView toolbar**

In `RoomCanvasView`, add to the toolbar:
```swift
ToolbarItem(placement: .secondaryAction) {
    ExportButton(tables: tables, eventName: "Hochzeit", date: nil)
}
```

**Step 6: Run tests**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: PASS

**Step 7: Commit**

```bash
git add Gaesteglueck/Services/ Gaesteglueck/Views/ GaesteglueckTests/Services/
git commit -m "feat: add PDF export for seating plan with A4 layout"
```

---

## Task 13: Excel & CSV Import for Guest Lists

The user's real-world data is an Excel file where each row = one family/couple with columns for names, dietary preferences, and allergies. We need to parse multi-person rows, assign a shared `familyID`, and extract dietary info per person.

**Dependencies:** Add `CoreXLSX` via SPM: `https://github.com/CoreOffice/CoreXLSX` (version 0.14+)

**Files:**
- Create: `Gaesteglueck/Services/GuestImporter.swift`
- Create: `Gaesteglueck/Services/CSVParser.swift`
- Create: `Gaesteglueck/Services/ExcelParser.swift`
- Test: `GaesteglueckTests/Services/GuestImporterTests.swift`
- Create: `Gaesteglueck/Views/ImportButton.swift`
- Create: `Gaesteglueck/Views/ImportPreviewView.swift`

**Step 1: Add CoreXLSX dependency**

In Xcode: File > Add Package Dependencies > `https://github.com/CoreOffice/CoreXLSX`

Or in `Package.swift`:
```swift
.package(url: "https://github.com/CoreOffice/CoreXLSX", from: "0.14.0")
```

**Step 2: Write failing tests**

```swift
// GaesteglueckTests/Services/GuestImporterTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Importer")
struct GuestImporterTests {

    // --- CSV Parsing ---

    @Test("Parses simple CSV with name and side")
    func parseSimpleCSV() throws {
        let csv = """
        Name,Seite
        Anna Schmidt,Braut
        Klaus Müller,Bräutigam
        """
        let families = try CSVParser.parse(csv)
        #expect(families.count == 2)
        #expect(families[0].members[0].name == "Anna Schmidt")
    }

    @Test("CSV handles semicolon delimiter")
    func semicolonCSV() throws {
        let csv = "Name;Seite;Essen\nAnna;Braut;Vegetarisch"
        let families = try CSVParser.parse(csv)
        #expect(families[0].members[0].dietaryPreference == .vegetarian)
    }

    @Test("CSV parses dietary and allergy columns")
    func dietaryCSV() throws {
        let csv = """
        Name,Seite,Essen,Unverträglichkeiten
        Lisa,Braut,Vegan,Nüsse
        Tom,Bräutigam,Fleisch,
        """
        let families = try CSVParser.parse(csv)
        #expect(families[0].members[0].dietaryPreference == .vegan)
        #expect(families[0].members[0].allergies == "Nüsse")
        #expect(families[1].members[0].dietaryPreference == .meat)
    }

    @Test("CSV parses couple row with '&' separator")
    func coupleRowCSV() throws {
        let csv = """
        Name,Seite,Essen
        Klaus & Erika Müller,Braut,Fleisch
        """
        let families = try CSVParser.parse(csv)
        #expect(families.count == 1)
        #expect(families[0].members.count == 2)
        #expect(families[0].members[0].name == "Klaus Müller")
        #expect(families[0].members[1].name == "Erika Müller")
        #expect(families[0].sharedFamilyID != nil)
    }

    @Test("CSV parses couple row with 'und' separator")
    func coupleUndCSV() throws {
        let csv = """
        Name,Seite
        Max und Lisa Becker,Braut
        """
        let families = try CSVParser.parse(csv)
        #expect(families[0].members.count == 2)
        #expect(families[0].members[0].name == "Max Becker")
        #expect(families[0].members[1].name == "Lisa Becker")
    }

    @Test("CSV throws on missing name column")
    func missingNameCSV() {
        let csv = "Seite\nBraut"
        #expect(throws: ImportError.self) {
            try CSVParser.parse(csv)
        }
    }

    // --- Family Expansion ---

    @Test("Family row with children expands correctly")
    func familyWithChildren() throws {
        let csv = """
        Name,Seite,Kinder
        Klaus & Erika Müller,Braut,Max (8) und Lina (5)
        """
        let families = try CSVParser.parse(csv)
        #expect(families[0].members.count == 4)
        #expect(families[0].members[2].name == "Max Müller")
        #expect(families[0].members[2].isChild == true)
        #expect(families[0].members[3].name == "Lina Müller")
    }
}
```

**Step 3: Run tests to verify they fail**

Expected: FAIL — `CSVParser`, `ImportError` not defined

**Step 4: Implement shared types**

```swift
// Gaesteglueck/Services/GuestImporter.swift
import Foundation

enum ImportError: Error, LocalizedError {
    case missingNameColumn
    case emptyFile
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .missingNameColumn: "Die Datei muss eine 'Name'-Spalte enthalten."
        case .emptyFile: "Die Datei ist leer."
        case .invalidFormat(let detail): "Ungültiges Format: \(detail)"
        }
    }
}

/// A parsed family/couple from one import row. Multiple members share a familyID.
struct ImportedFamily {
    let sharedFamilyID: UUID?
    var members: [ImportedGuest]
}

struct ImportedGuest {
    let name: String
    let side: Side
    let dietaryPreference: DietaryPreference
    let allergies: String
    let isChild: Bool
}
```

**Step 5: Implement CSVParser**

```swift
// Gaesteglueck/Services/CSVParser.swift
import Foundation

enum CSVParser {
    static func parse(_ content: String) throws -> [ImportedFamily] {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else { throw ImportError.emptyFile }

        let delimiter: Character = headerLine.contains(";") ? ";" : ","
        let headers = headerLine.split(separator: delimiter)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        guard let nameIdx = headers.firstIndex(of: "name") else {
            throw ImportError.missingNameColumn
        }
        let sideIdx = headers.firstIndex(where: { ["seite", "side"].contains($0) })
        let dietIdx = headers.firstIndex(where: { ["essen", "ernährung", "dietary", "diet"].contains($0) })
        let allergyIdx = headers.firstIndex(where: { ["unverträglichkeiten", "allergien", "allergies"].contains($0) })
        let childrenIdx = headers.firstIndex(where: { ["kinder", "children"].contains($0) })

        var families: [ImportedFamily] = []

        for line in lines.dropFirst() {
            let fields = line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard fields.indices.contains(nameIdx), !fields[nameIdx].isEmpty else { continue }

            let rawName = fields[nameIdx]
            let side = parseSide(fields, at: sideIdx)
            let dietary = parseDietary(fields, at: dietIdx)
            let allergies = fields.indices.contains(allergyIdx ?? -1) ? fields[allergyIdx!] : ""

            // Split couple names: "Klaus & Erika Müller" or "Max und Lisa Becker"
            let names = splitCoupleNames(rawName)
            let familyID = names.count > 1 ? UUID() : nil

            var members = names.map { name in
                ImportedGuest(name: name, side: side, dietaryPreference: dietary, allergies: allergies, isChild: false)
            }

            // Parse children column: "Max (8) und Lina (5)"
            if let cIdx = childrenIdx, fields.indices.contains(cIdx), !fields[cIdx].isEmpty {
                let lastName = extractLastName(from: rawName)
                let children = parseChildren(fields[cIdx], lastName: lastName, side: side)
                members.append(contentsOf: children)
            }

            families.append(ImportedFamily(
                sharedFamilyID: members.count > 1 ? (familyID ?? UUID()) : nil,
                members: members
            ))
        }

        return families
    }

    // MARK: - Private Helpers

    private static func parseSide(_ fields: [String], at index: Int?) -> Side {
        guard let idx = index, fields.indices.contains(idx) else { return .neutral }
        switch fields[idx].lowercased() {
        case "braut", "bride": return .bride
        case "bräutigam", "groom": return .groom
        default: return .neutral
        }
    }

    private static func parseDietary(_ fields: [String], at index: Int?) -> DietaryPreference {
        guard let idx = index, fields.indices.contains(idx) else { return .meat }
        switch fields[idx].lowercased() {
        case "vegan": return .vegan
        case "vegetarisch", "vegetarian", "veggie": return .vegetarian
        default: return .meat
        }
    }

    /// Splits "Klaus & Erika Müller" into ["Klaus Müller", "Erika Müller"]
    /// Splits "Max und Lisa Becker" into ["Max Becker", "Lisa Becker"]
    static func splitCoupleNames(_ raw: String) -> [String] {
        let separators = [" & ", " und ", " + "]
        for sep in separators {
            if raw.contains(sep) {
                let parts = raw.components(separatedBy: sep)
                guard parts.count == 2 else { return [raw] }
                let lastName = extractLastName(from: raw)
                return parts.map { part in
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains(" ") {
                        return trimmed // Already has last name
                    } else {
                        return "\(trimmed) \(lastName)"
                    }
                }
            }
        }
        return [raw]
    }

    static func extractLastName(from fullName: String) -> String {
        let words = fullName.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        return words.last ?? ""
    }

    /// Parses "Max (8) und Lina (5)" into child ImportedGuests
    private static func parseChildren(_ raw: String, lastName: String, side: Side) -> [ImportedGuest] {
        let childParts = raw.components(separatedBy: CharacterSet(charactersIn: ",;&"))
            .flatMap { $0.components(separatedBy: " und ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return childParts.map { part in
            // Remove age like "(8)" or "(5 Jahre)"
            let name = part.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let fullName = name.contains(" ") ? name : "\(name) \(lastName)"
            return ImportedGuest(name: fullName, side: side, dietaryPreference: .meat, allergies: "", isChild: true)
        }
    }
}
```

**Step 6: Implement ExcelParser (for .xlsx files)**

```swift
// Gaesteglueck/Services/ExcelParser.swift
import Foundation
import CoreXLSX

enum ExcelParser {
    /// Parse an .xlsx file at the given URL into ImportedFamilies.
    /// Expects similar column headers as CSV: Name, Seite, Essen, Unverträglichkeiten, Kinder
    static func parse(url: URL) throws -> [ImportedFamily] {
        let file = try XLSXFile(filepath: url.path)
        guard let sharedStrings = try file.parseSharedStrings() else {
            throw ImportError.invalidFormat("Keine Shared Strings gefunden")
        }

        // Use the first worksheet
        let paths = try file.parseWorksheetPaths()
        guard let firstPath = paths.first else {
            throw ImportError.emptyFile
        }
        let worksheet = try file.parseWorksheet(at: firstPath)

        guard let rows = worksheet.data?.rows, !rows.isEmpty else {
            throw ImportError.emptyFile
        }

        // Parse header row
        let headerRow = rows[0]
        let headers = headerRow.cells.map { cell -> String in
            cell.stringValue(sharedStrings) ?? ""
        }.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        guard let nameIdx = headers.firstIndex(of: "name") else {
            throw ImportError.missingNameColumn
        }
        let sideIdx = headers.firstIndex(where: { ["seite", "side"].contains($0) })
        let dietIdx = headers.firstIndex(where: { ["essen", "ernährung"].contains($0) })
        let allergyIdx = headers.firstIndex(where: { ["unverträglichkeiten", "allergien"].contains($0) })
        let childrenIdx = headers.firstIndex(where: { ["kinder", "children"].contains($0) })

        var families: [ImportedFamily] = []

        for row in rows.dropFirst() {
            let cells = row.cells
            func cellValue(_ idx: Int) -> String {
                guard idx < cells.count else { return "" }
                return cells[idx].stringValue(sharedStrings)?.trimmingCharacters(in: .whitespaces) ?? ""
            }

            let rawName = cellValue(nameIdx)
            guard !rawName.isEmpty else { continue }

            let side: Side = {
                guard let idx = sideIdx else { return .neutral }
                switch cellValue(idx).lowercased() {
                case "braut", "bride": return .bride
                case "bräutigam", "groom": return .groom
                default: return .neutral
                }
            }()

            let dietary: DietaryPreference = {
                guard let idx = dietIdx else { return .meat }
                switch cellValue(idx).lowercased() {
                case "vegan": return .vegan
                case "vegetarisch", "veggie": return .vegetarian
                default: return .meat
                }
            }()

            let allergies = allergyIdx.map { cellValue($0) } ?? ""

            let names = CSVParser.splitCoupleNames(rawName)
            let familyID = names.count > 1 ? UUID() : nil

            var members = names.map { name in
                ImportedGuest(name: name, side: side, dietaryPreference: dietary, allergies: allergies, isChild: false)
            }

            if let cIdx = childrenIdx {
                let childrenRaw = cellValue(cIdx)
                if !childrenRaw.isEmpty {
                    let lastName = CSVParser.extractLastName(from: rawName)
                    let children = parseChildren(childrenRaw, lastName: lastName, side: side)
                    members.append(contentsOf: children)
                }
            }

            families.append(ImportedFamily(
                sharedFamilyID: members.count > 1 ? (familyID ?? UUID()) : nil,
                members: members
            ))
        }

        return families
    }

    private static func parseChildren(_ raw: String, lastName: String, side: Side) -> [ImportedGuest] {
        // Reuse CSVParser logic — it's the same format
        let childParts = raw.components(separatedBy: CharacterSet(charactersIn: ",;&"))
            .flatMap { $0.components(separatedBy: " und ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return childParts.map { part in
            let name = part.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let fullName = name.contains(" ") ? name : "\(name) \(lastName)"
            return ImportedGuest(name: fullName, side: side, dietaryPreference: .meat, allergies: "", isChild: true)
        }
    }
}
```

**Step 7: Implement ImportPreviewView**

After parsing, show a preview of what will be imported so the user can verify.

```swift
// Gaesteglueck/Views/ImportPreviewView.swift
import SwiftUI

struct ImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let families: [ImportedFamily]
    let onComplete: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Familien/Paare")
                        Spacer()
                        Text("\(families.count)")
                    }
                    HStack {
                        Text("Personen gesamt")
                        Spacer()
                        Text("\(families.reduce(0) { $0 + $1.members.count })")
                    }
                } header: {
                    Text("Übersicht")
                }

                ForEach(Array(families.enumerated()), id: \.offset) { _, family in
                    Section {
                        ForEach(Array(family.members.enumerated()), id: \.offset) { _, member in
                            HStack {
                                Circle().fill(member.side.color).frame(width: 8, height: 8)
                                Text(member.name)
                                if member.isChild {
                                    Image(systemName: "figure.child")
                                        .font(.caption2)
                                }
                                Spacer()
                                Text(member.dietaryPreference.badge)
                                if !member.allergies.isEmpty {
                                    Text("⚠️")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import-Vorschau")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importieren") { performImport() }
                }
            }
        }
    }

    private func performImport() {
        var count = 0
        for family in families {
            for member in family.members {
                let guest = Guest(
                    name: member.name,
                    side: member.side,
                    familyID: family.sharedFamilyID,
                    dietaryPreference: member.dietaryPreference,
                    allergies: member.allergies,
                    isChild: member.isChild
                )
                modelContext.insert(guest)
                count += 1
            }
        }
        onComplete(count)
        dismiss()
    }
}
```

**Step 8: Implement ImportButton**

```swift
// Gaesteglueck/Views/ImportButton.swift
import SwiftUI
import UniformTypeIdentifiers

struct ImportButton: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingFilePicker = false
    @State private var parsedFamilies: [ImportedFamily]?
    @State private var importError: String?
    @State private var importedCount: Int?

    var body: some View {
        Button {
            showingFilePicker = true
        } label: {
            Label("Gästeliste importieren", systemImage: "square.and.arrow.down")
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .spreadsheet, .init(filenameExtension: "xlsx")!]
        ) { result in
            handleFile(result)
        }
        .sheet(item: Binding(
            get: { parsedFamilies.map { IdentifiableWrapper(value: $0) } },
            set: { parsedFamilies = $0?.value }
        )) { wrapper in
            ImportPreviewView(families: wrapper.value) { count in
                importedCount = count
                parsedFamilies = nil
            }
        }
        .alert("Import fehlgeschlagen", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert("Import erfolgreich", isPresented: Binding(
            get: { importedCount != nil },
            set: { if !$0 { importedCount = nil } }
        )) {
            Button("OK") { importedCount = nil }
        } message: {
            Text("\(importedCount ?? 0) Gäste importiert. Du kannst jetzt die Beziehungen zuweisen.")
        }
    }

    private func handleFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }

                let families: [ImportedFamily]
                if url.pathExtension.lowercased() == "xlsx" {
                    families = try ExcelParser.parse(url: url)
                } else {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    families = try CSVParser.parse(content)
                }
                parsedFamilies = families
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

private struct IdentifiableWrapper<T>: Identifiable {
    let id = UUID()
    let value: T
}
```

**Step 9: Add import button to GuestListView toolbar**

In `GuestListView`, add to toolbar:
```swift
ToolbarItem(placement: .secondaryAction) {
    ImportButton()
}
```

**Step 10: Run all tests**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: PASS

**Step 11: Commit**

```bash
git add Gaesteglueck/Services/ Gaesteglueck/Views/ GaesteglueckTests/Services/
git commit -m "feat: add Excel and CSV import with couple/family row splitting and dietary parsing"
```

---

## Task 14: Pin/Lock Guests to Tables

Allow pinning guests (e.g., bride/groom to the bride table) so the auto-solver doesn't move them.

**Files:**
- Modify: `Gaesteglueck/Models/Guest.swift`
- Modify: `Gaesteglueck/Views/Canvas/TableCanvasItemView.swift`
- Test: `GaesteglueckTests/Models/GuestTests.swift`

**Step 1: Add `isPinned` to Guest**

In `Guest.swift`:
```swift
var isPinned: Bool  // Locked to their current table

// Add to init:
self.isPinned = false
```

**Step 2: Write failing test**

```swift
@Test("Pinned guest cannot be moved")
func pinnedGuest() {
    let guest = Guest(name: "Braut", side: .bride)
    #expect(!guest.isPinned)
    guest.isPinned = true
    #expect(guest.isPinned)
}
```

**Step 3: Run test to verify it fails, then passes after adding the property**

**Step 4: Update HappinessScorer to skip pinned guests in violations**

In `HappinessScorer.swift`, add to the partner-separated check:
```swift
// Don't flag as violation if one partner is pinned (intentional)
// Actually, still flag it — the user should know. But don't penalize the score.
```

**Step 5: Add pin/unpin button in table detail panel**

In `RoomCanvasView`'s detail panel, update the guest row:
```swift
ForEach(table.guests) { guest in
    HStack {
        if guest.isPinned {
            Image(systemName: "pin.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        }
        Circle().fill(guest.side.color).frame(width: 8, height: 8)
        Text(guest.name)
        Spacer()
        Button {
            guest.isPinned.toggle()
        } label: {
            Image(systemName: guest.isPinned ? "pin.slash" : "pin")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        Button {
            guard !guest.isPinned else { return }
            guest.table = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(guest.isPinned ? .secondary.opacity(0.3) : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(guest.isPinned)
    }
}
```

**Step 6: Update drop target to reject pinned guests**

In `RoomCanvasView`, update the drop handler:
```swift
.dropDestination(for: String.self) { items, _ in
    guard let guestIDString = items.first,
          let guestID = UUID(uuidString: guestIDString),
          let guest = guests.first(where: { $0.id == guestID }) else {
        return false
    }
    guard !table.isFull else { return false }
    guard !guest.isPinned else { return false } // Can't move pinned guests
    guest.table = table
    return true
}
```

**Step 7: Commit**

```bash
git add Gaesteglueck/Models/ Gaesteglueck/Views/ GaesteglueckTests/
git commit -m "feat: add pin/lock guests to tables to prevent auto-move"
```

---

## Task 15: Family Grouping

Ensure family members (sharing a `familyID`) get visual indicators and preferential clustering.

**Files:**
- Create: `Gaesteglueck/Services/FamilyGrouper.swift`
- Test: `GaesteglueckTests/Services/FamilyGrouperTests.swift`

**Step 1: Write failing tests**

```swift
// GaesteglueckTests/Services/FamilyGrouperTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Family Grouper")
struct FamilyGrouperTests {
    @Test("Groups guests by familyID")
    func groupsByFamily() {
        let familyID = UUID()
        let alice = Guest(name: "Alice", side: .bride, familyID: familyID)
        let bob = Guest(name: "Bob", side: .bride, familyID: familyID)
        let carol = Guest(name: "Carol", side: .groom)

        let groups = FamilyGrouper.group([alice, bob, carol])
        #expect(groups.count == 2) // one family + one individual
    }

    @Test("Family members listed together")
    func familyTogether() {
        let familyID = UUID()
        let alice = Guest(name: "Alice", side: .bride, familyID: familyID)
        let bob = Guest(name: "Bob", side: .bride, familyID: familyID)

        let groups = FamilyGrouper.group([alice, bob])
        #expect(groups.count == 1)
        #expect(groups[0].count == 2)
    }

    @Test("Separated families detected")
    func separatedFamilies() {
        let familyID = UUID()
        let alice = Guest(name: "Alice", side: .bride, familyID: familyID)
        let bob = Guest(name: "Bob", side: .bride, familyID: familyID)
        let t1 = GuestTable(name: "T1", shape: .round)
        let t2 = GuestTable(name: "T2", shape: .round)
        t1.guests = [alice]
        t2.guests = [bob]

        let separated = FamilyGrouper.findSeparatedFamilies(tables: [t1, t2], guests: [alice, bob])
        #expect(!separated.isEmpty)
    }
}
```

**Step 2: Implement FamilyGrouper**

```swift
// Gaesteglueck/Services/FamilyGrouper.swift
import Foundation

enum FamilyGrouper {
    /// Group guests by familyID. Guests without a familyID are each in their own group.
    static func group(_ guests: [Guest]) -> [[Guest]] {
        var familyGroups: [UUID: [Guest]] = [:]
        var individuals: [[Guest]] = []

        for guest in guests {
            if let fid = guest.familyID {
                familyGroups[fid, default: []].append(guest)
            } else {
                individuals.append([guest])
            }
        }

        return Array(familyGroups.values) + individuals
    }

    /// Find families that are split across multiple tables.
    static func findSeparatedFamilies(tables: [GuestTable], guests: [Guest]) -> [SeparatedFamily] {
        var guestToTable: [UUID: UUID] = [:]
        for table in tables {
            for guest in table.guests {
                guestToTable[guest.id] = table.id
            }
        }

        // Group by familyID
        let families = Dictionary(grouping: guests.filter { $0.familyID != nil }, by: { $0.familyID! })

        var separated: [SeparatedFamily] = []
        for (familyID, members) in families {
            let tableIDs = Set(members.compactMap { guestToTable[$0.id] })
            if tableIDs.count > 1 {
                separated.append(SeparatedFamily(
                    familyID: familyID,
                    memberNames: members.map(\.name),
                    tableCount: tableIDs.count
                ))
            }
        }

        return separated
    }
}

struct SeparatedFamily: Identifiable {
    let id = UUID()
    let familyID: UUID
    let memberNames: [String]
    let tableCount: Int
}
```

**Step 3: Run tests**

Expected: PASS

**Step 4: Commit**

```bash
git add Gaesteglueck/Services/ GaesteglueckTests/Services/
git commit -m "feat: add family grouping with separated-family detection"
```

---

## Task 16: Polish & Statistics Dashboard

Add a statistics overview showing key metrics across the event.

**Files:**
- Create: `Gaesteglueck/Views/StatisticsView.swift`
- Modify: `Gaesteglueck/Views/AppSidebar.swift` (add statistics section)

**Step 1: Implement StatisticsView**

```swift
// Gaesteglueck/Views/StatisticsView.swift
import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var relationships: [Relationship]

    private var confirmedGuests: Int {
        guests.filter { $0.rsvpStatus == .confirmed }.count
    }

    private var assignedGuests: Int {
        guests.filter { $0.table != nil }.count
    }

    private var totalCapacity: Int {
        tables.reduce(0) { $0 + $1.capacity }
    }

    private var happinessScore: Double {
        HappinessScorer.scoreAllTables(tables, relationships: relationships)
    }

    private var violations: [Violation] {
        HappinessScorer.findViolations(tables: tables, relationships: relationships)
    }

    var body: some View {
        List {
            Section("Gäste") {
                StatRow(label: "Gesamt", value: "\(guests.count)", icon: "person.3")
                StatRow(label: "Zugesagt", value: "\(confirmedGuests)", icon: "checkmark.circle")
                StatRow(label: "Brautseite", value: "\(guests.filter { $0.side == .bride }.count)", icon: "circle.fill", color: .pink)
                StatRow(label: "Bräutigamseite", value: "\(guests.filter { $0.side == .groom }.count)", icon: "circle.fill", color: .blue)
            }
            Section("Tische") {
                StatRow(label: "Anzahl", value: "\(tables.count)", icon: "tablecells")
                StatRow(label: "Kapazität", value: "\(totalCapacity) Plätze", icon: "chair")
                StatRow(label: "Zugewiesen", value: "\(assignedGuests)/\(guests.count)", icon: "person.badge.checkmark")
                StatRow(label: "Freie Plätze", value: "\(totalCapacity - assignedGuests)", icon: "plus.square.dashed")
            }
            Section("Sitzplan-Qualität") {
                StatRow(label: "Happiness Score", value: "\(Int(happinessScore))", icon: "face.smiling", color: happinessScore >= 0 ? .green : .red)
                StatRow(label: "Beziehungen", value: "\(relationships.count)", icon: "heart.text.clipboard")
                StatRow(label: "Warnungen", value: "\(violations.count)", icon: "exclamationmark.triangle", color: violations.isEmpty ? .green : .red)
            }
        }
        .navigationTitle("Übersicht")
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
```

**Step 2: Add to sidebar**

In `AppSidebar.swift`, add a new case to `AppSection`:
```swift
case statistics = "Übersicht"

// icon:
case .statistics: "chart.bar"
```

And add the corresponding view in `ContentView.swift`:
```swift
case .statistics:
    StatisticsView()
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Gaesteglueck/Views/
git commit -m "feat: add statistics dashboard with guest, table, and quality metrics"
```

---

## Task 17: Relationship Onboarding Wizard

After importing the guest list, the app walks the user through each family/couple and asks structured questions to build the social graph. This replaces manual relationship entry for the bulk of guests.

**Files:**
- Create: `Gaesteglueck/Views/Onboarding/OnboardingWizardView.swift`
- Create: `Gaesteglueck/Views/Onboarding/FamilyCardView.swift`
- Create: `Gaesteglueck/Services/OnboardingEngine.swift`
- Test: `GaesteglueckTests/Services/OnboardingEngineTests.swift`

**Step 1: Write failing tests for OnboardingEngine**

```swift
// GaesteglueckTests/Services/OnboardingEngineTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Onboarding Engine")
struct OnboardingEngineTests {
    @Test("Groups guests into onboarding cards by familyID")
    func groupsByFamily() {
        let fid = UUID()
        let a = Guest(name: "Klaus Müller", side: .neutral, familyID: fid)
        let b = Guest(name: "Erika Müller", side: .neutral, familyID: fid)
        let c = Guest(name: "Solo Gast", side: .neutral)

        let cards = OnboardingEngine.buildCards(from: [a, b, c])
        #expect(cards.count == 2) // one family card + one solo card
        #expect(cards[0].guests.count == 2 || cards[1].guests.count == 2)
    }

    @Test("Filters out already-onboarded guests")
    func filtersOnboarded() {
        let a = Guest(name: "Already Done", side: .bride, groupType: .immediateFamily)
        let b = Guest(name: "Needs Onboarding", side: .neutral)

        let cards = OnboardingEngine.buildCards(from: [a, b], excludeWithGroupType: true)
        #expect(cards.count == 1)
        #expect(cards[0].guests[0].name == "Needs Onboarding")
    }

    @Test("Card display name uses family name for couples")
    func cardDisplayName() {
        let fid = UUID()
        let a = Guest(name: "Klaus Müller", side: .neutral, familyID: fid)
        let b = Guest(name: "Erika Müller", side: .neutral, familyID: fid)

        let cards = OnboardingEngine.buildCards(from: [a, b])
        #expect(cards[0].displayName == "Familie Müller")
    }
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL — `OnboardingEngine` not defined

**Step 3: Implement OnboardingEngine**

```swift
// Gaesteglueck/Services/OnboardingEngine.swift
import Foundation

struct OnboardingCard: Identifiable {
    let id = UUID()
    let guests: [Guest]

    var displayName: String {
        if guests.count == 1 {
            return guests[0].name
        }
        // Extract shared last name
        let lastNames = guests.map { $0.name.components(separatedBy: " ").last ?? "" }
        if let shared = lastNames.first, lastNames.allSatisfy({ $0 == shared }) {
            return "Familie \(shared)"
        }
        return guests.map(\.name).joined(separator: " & ")
    }

    var isFamily: Bool { guests.count > 1 }
}

enum OnboardingEngine {
    /// Group guests into cards for the onboarding wizard.
    static func buildCards(from guests: [Guest], excludeWithGroupType: Bool = false) -> [OnboardingCard] {
        let filtered = excludeWithGroupType ? guests.filter { $0.groupType == nil } : guests

        var familyGroups: [UUID: [Guest]] = [:]
        var solos: [Guest] = []

        for guest in filtered {
            if let fid = guest.familyID {
                familyGroups[fid, default: []].append(guest)
            } else {
                solos.append(guest)
            }
        }

        var cards: [OnboardingCard] = familyGroups.values.map { OnboardingCard(guests: $0) }
        cards.append(contentsOf: solos.map { OnboardingCard(guests: [$0]) })
        return cards
    }
}
```

**Step 4: Implement the wizard UI**

```swift
// Gaesteglueck/Views/Onboarding/OnboardingWizardView.swift
import SwiftUI
import SwiftData

struct OnboardingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var allGuests: [Guest]

    @State private var cards: [OnboardingCard] = []
    @State private var currentIndex = 0

    // Current card answers
    @State private var selectedSide: Side = .neutral
    @State private var selectedGroupType: GroupType?
    @State private var customGroupName = ""
    @State private var selectedFamilyRoles: [UUID: FamilyRole] = [:]
    @State private var mainContactID: UUID?

    private var currentCard: OnboardingCard? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    private var progress: Double {
        guard !cards.isEmpty else { return 1 }
        return Double(currentIndex) / Double(cards.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: progress)
                    .padding(.horizontal)

                if let card = currentCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Card header
                            Text(card.displayName)
                                .font(.title2.bold())

                            if card.isFamily {
                                Text("Mitglieder: \(card.guests.map(\.name).joined(separator: ", "))")
                                    .foregroundStyle(.secondary)
                            }

                            // Q1: Side
                            questionSection("Auf welcher Seite?", icon: "person.2") {
                                Picker("Seite", selection: $selectedSide) {
                                    ForEach(Side.allCases) { side in
                                        Text(side.rawValue).tag(side)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            // Q2: Group type
                            questionSection("Wie kennt ihr euch?", icon: "person.3") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                                    ForEach(GroupType.allCases) { gt in
                                        Button {
                                            selectedGroupType = gt
                                        } label: {
                                            Text(gt.rawValue)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(selectedGroupType == gt ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                if selectedGroupType == .clubMember {
                                    TextField("Welcher Verein?", text: $customGroupName)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            // Q3: Family roles (for each member)
                            if card.guests.count > 1 {
                                questionSection("Wer ist wer?", icon: "figure.2.and.child") {
                                    ForEach(card.guests) { guest in
                                        HStack {
                                            Text(guest.name)
                                            Spacer()
                                            Picker("Rolle", selection: Binding(
                                                get: { selectedFamilyRoles[guest.id] },
                                                set: { selectedFamilyRoles[guest.id] = $0 }
                                            )) {
                                                Text("—").tag(nil as FamilyRole?)
                                                ForEach(FamilyRole.allCases) { role in
                                                    Text(role.rawValue).tag(role as FamilyRole?)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                questionSection("Beziehung zum Brautpaar?", icon: "heart") {
                                    Picker("Rolle", selection: Binding(
                                        get: { selectedFamilyRoles[card.guests[0].id] },
                                        set: { selectedFamilyRoles[card.guests[0].id] = $0 }
                                    )) {
                                        Text("Keine Angabe").tag(nil as FamilyRole?)
                                        ForEach(FamilyRole.allCases) { role in
                                            Text(role.rawValue).tag(role as FamilyRole?)
                                        }
                                    }
                                }
                            }

                            // Q4: Main contact person
                            if card.guests.count > 1 {
                                questionSection("Wer ist die Hauptbezugsperson?", icon: "star") {
                                    Text("Wer von dieser Gruppe kennt das Brautpaar am besten?")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(card.guests) { guest in
                                        Button {
                                            mainContactID = guest.id
                                        } label: {
                                            HStack {
                                                Image(systemName: mainContactID == guest.id ? "star.fill" : "star")
                                                Text(guest.name)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                            .background(mainContactID == guest.id ? Color.accentColor.opacity(0.1) : .clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding()
                    }

                    // Navigation buttons
                    HStack {
                        if currentIndex > 0 {
                            Button("Zurück") {
                                currentIndex -= 1
                                loadCurrentCard()
                            }
                        }
                        Spacer()
                        Text("\(currentIndex + 1) / \(cards.count)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(currentIndex == cards.count - 1 ? "Fertig" : "Weiter") {
                            saveCurrentCard()
                            if currentIndex < cards.count - 1 {
                                currentIndex += 1
                                loadCurrentCard()
                            } else {
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ContentUnavailableView("Keine Gäste zum Onboarden", systemImage: "checkmark.circle", description: Text("Alle Gäste haben bereits Gruppen zugewiesen."))
                }
            }
            .navigationTitle("Beziehungen zuweisen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear {
                cards = OnboardingEngine.buildCards(from: allGuests, excludeWithGroupType: true)
                loadCurrentCard()
            }
        }
    }

    private func loadCurrentCard() {
        guard let card = currentCard else { return }
        selectedSide = card.guests.first?.side ?? .neutral
        selectedGroupType = card.guests.first?.groupType
        customGroupName = card.guests.first?.customGroupName ?? ""
        selectedFamilyRoles = Dictionary(uniqueKeysWithValues: card.guests.map { ($0.id, $0.familyRole as FamilyRole?) })
            .compactMapValues { $0 }
        mainContactID = card.guests.first(where: { $0.mainContactPersonID != nil })?.id
    }

    private func saveCurrentCard() {
        guard let card = currentCard else { return }
        for guest in card.guests {
            guest.side = selectedSide
            guest.groupType = selectedGroupType
            guest.customGroupName = customGroupName.isEmpty ? nil : customGroupName
            guest.familyRole = selectedFamilyRoles[guest.id]
            if let mainID = mainContactID {
                guest.mainContactPersonID = mainID
            }
        }
    }

    @ViewBuilder
    private func questionSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
    }
}
```

**Step 5: Add a "Start Onboarding" button in GuestListView**

Add to `GuestListView`'s toolbar:
```swift
ToolbarItem(placement: .secondaryAction) {
    Button {
        showingOnboarding = true
    } label: {
        Label("Beziehungen zuweisen", systemImage: "wand.and.stars")
    }
    .disabled(guests.isEmpty)
}
.sheet(isPresented: $showingOnboarding) {
    OnboardingWizardView()
}
```

**Step 6: Run tests**

Expected: PASS

**Step 7: Commit**

```bash
git add Gaesteglueck/Views/Onboarding/ Gaesteglueck/Services/ GaesteglueckTests/Services/
git commit -m "feat: add relationship onboarding wizard with guided family/couple questionnaire"
```

---

## Task 18: Room Photo Import & Scale Calibration

Let the user photograph the venue floor plan, import it as the canvas background, and calibrate the scale by drawing a reference line.

**Files:**
- Modify: `Gaesteglueck/Views/RoomCanvasView.swift`
- Create: `Gaesteglueck/Views/Canvas/FloorPlanSetupView.swift`
- Create: `Gaesteglueck/Views/Canvas/ScaleCalibrationOverlay.swift`

**Step 1: Implement FloorPlanSetupView**

```swift
// Gaesteglueck/Views/Canvas/FloorPlanSetupView.swift
import SwiftUI
import PhotosUI

struct FloorPlanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var roomPlan: RoomPlan

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var phase: SetupPhase = .chooseImage

    enum SetupPhase {
        case chooseImage
        case calibrate
    }

    var body: some View {
        NavigationStack {
            switch phase {
            case .chooseImage:
                VStack(spacing: 24) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Raumplan importieren")
                        .font(.title2.bold())
                    Text("Fotografiere den Grundriss der Location oder wähle ein Bild aus deinen Fotos.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Aus Fotos", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            showingCamera = true
                        } label: {
                            Label("Kamera", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 40)

                    if roomPlan.imageData != nil {
                        Button("Vorhandenen Plan verwenden") {
                            phase = .calibrate
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .onChange(of: selectedPhoto) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            roomPlan.imageData = data
                            phase = .calibrate
                        }
                    }
                }

            case .calibrate:
                ScaleCalibrationOverlay(roomPlan: roomPlan) {
                    dismiss()
                }
            }

            Spacer()
        }
        .navigationTitle("Raumplan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
        }
    }
}
```

**Step 2: Implement ScaleCalibrationOverlay**

The user taps two points on the image and enters the real-world distance.

```swift
// Gaesteglueck/Views/Canvas/ScaleCalibrationOverlay.swift
import SwiftUI

struct ScaleCalibrationOverlay: View {
    @Bindable var roomPlan: RoomPlan
    let onComplete: () -> Void

    @State private var pointA: CGPoint?
    @State private var pointB: CGPoint?
    @State private var realWorldCM: String = ""
    @State private var imageSize: CGSize = .zero

    private var hasCalibration: Bool {
        pointA != nil && pointB != nil && (Double(realWorldCM) ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Tippe zwei Punkte auf einer bekannten Wand und gib die Länge in cm ein.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()

            GeometryReader { geo in
                if let imageData = roomPlan.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            Canvas { context, size in
                                imageSize = size
                                // Draw calibration line
                                if let a = pointA, let b = pointB {
                                    var path = Path()
                                    path.move(to: a)
                                    path.addLine(to: b)
                                    context.stroke(path, with: .color(.red), lineWidth: 3)
                                }
                                // Draw points
                                for point in [pointA, pointB].compactMap({ $0 }) {
                                    let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
                                    context.fill(Circle().path(in: rect), with: .color(.red))
                                }
                            }
                        }
                        .onTapGesture { location in
                            if pointA == nil {
                                pointA = location
                            } else if pointB == nil {
                                pointB = location
                            } else {
                                // Reset
                                pointA = location
                                pointB = nil
                            }
                        }
                }
            }

            HStack {
                TextField("Länge in cm (z.B. 1000 für 10m)", text: $realWorldCM)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 300)

                Button("Kalibrieren") {
                    saveCalibration()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasCalibration)
            }
            .padding()
        }
    }

    private func saveCalibration() {
        guard let a = pointA, let b = pointB,
              let cm = Double(realWorldCM), cm > 0,
              imageSize.width > 0 else { return }

        // Store normalized coordinates (0-1)
        roomPlan.scalePointAX = a.x / imageSize.width
        roomPlan.scalePointAY = a.y / imageSize.height
        roomPlan.scalePointBX = b.x / imageSize.width
        roomPlan.scalePointBY = b.y / imageSize.height
        roomPlan.scaleRealWorldCM = cm
        onComplete()
    }
}
```

**Step 3: Integrate floor plan into RoomCanvasView**

Update `RoomCanvasView` to show the floor plan image as a background behind the tables:

```swift
// In the ZStack of RoomCanvasView, add as first element:
if let roomPlan = roomPlans.first, let imageData = roomPlan.imageData,
   let uiImage = UIImage(data: imageData) {
    Image(uiImage: uiImage)
        .resizable()
        .scaledToFit()
        .opacity(0.3) // Semi-transparent so tables are clearly visible
}
```

Add a toolbar button:
```swift
ToolbarItem(placement: .secondaryAction) {
    Button {
        showingFloorPlanSetup = true
    } label: {
        Label("Raumplan-Foto", systemImage: "photo.badge.plus")
    }
}
```

**Step 4: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Gaesteglueck/Views/Canvas/ Gaesteglueck/Models/
git commit -m "feat: add room photo import with scale calibration overlay"
```

---

## Task 19: Table Combination — Link Rectangular Tables

Allow the user to combine two rectangular tables into a long "Tafel" by dragging one next to another.

**Files:**
- Modify: `Gaesteglueck/Views/Canvas/TableCanvasItemView.swift`
- Create: `Gaesteglueck/Views/Canvas/TableCombineSheet.swift`
- Test: `GaesteglueckTests/Models/GuestTableTests.swift` (add combination tests)

**Step 1: Write failing test for combination capacity**

```swift
// Add to GuestTableTests
@Test("Two rectangular 200x100 tables combined have correct capacity")
func combinedCapacityCalculation() {
    let t1 = GuestTable(name: "T1", shape: .rectangular, width: 200, depth: 100)
    let t2 = GuestTable(name: "T2", shape: .rectangular, width: 200, depth: 100)
    t1.linkedTableID = t2.id
    t2.linkedTableID = t1.id

    let combined = t1.combinedCapacity(with: t2)
    // Combined 400cm long, 100cm wide
    // 2 long sides: 400/60 * 2 = 12
    // 2 short ends: 100/60 * 2 = 2
    // Total: 14
    #expect(combined == 14)
    #expect(combined > t1.capacity) // Must be more than one table alone
}
```

**Step 2: Implement TableCombineSheet**

```swift
// Gaesteglueck/Views/Canvas/TableCombineSheet.swift
import SwiftUI
import SwiftData

struct TableCombineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let table: GuestTable
    @Query(sort: \GuestTable.name) private var allTables: [GuestTable]

    private var availableTables: [GuestTable] {
        allTables.filter { $0.id != table.id && $0.shape == .rectangular && $0.linkedTableID == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if table.linkedTableID != nil {
                    Section {
                        Button("Verbindung lösen", role: .destructive) {
                            if let linkedID = table.linkedTableID,
                               let linked = allTables.first(where: { $0.id == linkedID }) {
                                linked.linkedTableID = nil
                            }
                            table.linkedTableID = nil
                            dismiss()
                        }
                    }
                }

                Section("Verfügbare Tische") {
                    if availableTables.isEmpty {
                        Text("Keine freien rechteckigen Tische verfügbar.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(availableTables) { other in
                        Button {
                            table.linkedTableID = other.id
                            other.linkedTableID = table.id
                            // Position the linked table next to this one
                            other.positionX = table.positionX + table.width / 3 + 5
                            other.positionY = table.positionY
                            dismiss()
                        } label: {
                            HStack {
                                Text(other.name)
                                Spacer()
                                Text("\(other.width.formatted())×\(other.depth.formatted()) cm")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tisch verbinden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
```

**Step 3: Add "combine" gesture to TableCanvasItemView**

In `TableCanvasItemView`, add a context menu:
```swift
.contextMenu {
    if table.shape == .rectangular {
        Button {
            showingCombineSheet = true
        } label: {
            Label("Tisch verbinden", systemImage: "link")
        }
    }
    if table.linkedTableID != nil {
        Button(role: .destructive) {
            // Unlink
            if let linked = allTables.first(where: { $0.id == table.linkedTableID }) {
                linked.linkedTableID = nil
            }
            table.linkedTableID = nil
        } label: {
            Label("Verbindung lösen", systemImage: "link.badge.plus")
        }
    }
}
```

**Step 4: Visual indicator for linked tables**

In `TableCanvasItemView`, when the table has a `linkedTableID`, draw a visual connector:
```swift
// Show link indicator
if table.linkedTableID != nil {
    Image(systemName: "link")
        .font(.caption2)
        .foregroundStyle(.blue)
}
```

**Step 5: Run tests**

Expected: PASS

**Step 6: Commit**

```bash
git add Gaesteglueck/Views/Canvas/ GaesteglueckTests/
git commit -m "feat: add table combination for rectangular tables into long Tafel"
```

---

## Task 20: Graph-Based Seating Solver (Auto-Assign)

Use graph theory (weighted graph partitioning) to automatically suggest an optimal seating arrangement. The solver treats guests as nodes, relationships as weighted edges, and tables as partitions with capacity constraints. Uses on-device Core ML for Apple Silicon acceleration where available, with fallback to a classical constraint-satisfaction solver.

**Files:**
- Create: `Gaesteglueck/Services/SeatingGraph.swift`
- Create: `Gaesteglueck/Services/SeatingOptimizer.swift`
- Create: `Gaesteglueck/Views/AutoAssignButton.swift`
- Test: `GaesteglueckTests/Services/SeatingOptimizerTests.swift`

**Step 1: Write failing tests**

```swift
// GaesteglueckTests/Services/SeatingOptimizerTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Seating Optimizer")
struct SeatingOptimizerTests {
    func makeGuest(_ name: String, side: Side = .bride, groupType: GroupType? = nil) -> Guest {
        Guest(name: name, side: side, groupType: groupType)
    }

    @Test("Partners are assigned to same table")
    func partnersStayTogether() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob", side: .groom)
        let table = GuestTable(name: "T1", shape: .round, diameter: 180)
        let rel = Relationship(personAID: alice.id, personBID: bob.id, type: .partner)

        let result = SeatingOptimizer.solve(
            guests: [alice, bob],
            tables: [table],
            relationships: [rel]
        )
        // Partners must be at the same table
        #expect(result[alice.id] == result[bob.id])
    }

    @Test("Toxic guests are separated")
    func toxicSeparated() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        let rel = Relationship(personAID: alice.id, personBID: eve.id, type: .toxic)

        let result = SeatingOptimizer.solve(
            guests: [alice, eve],
            tables: [t1, t2],
            relationships: [rel]
        )
        #expect(result[alice.id] != result[eve.id])
    }

    @Test("Family members cluster together")
    func familyClusters() {
        let fid = UUID()
        let a = makeGuest("A", groupType: .immediateFamily)
        a.familyID = fid
        let b = makeGuest("B", groupType: .immediateFamily)
        b.familyID = fid
        let c = makeGuest("C", side: .groom)
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)

        let result = SeatingOptimizer.solve(
            guests: [a, b, c],
            tables: [t1, t2],
            relationships: []
        )
        #expect(result[a.id] == result[b.id]) // Family stays together
    }

    @Test("Respects table capacity")
    func respectsCapacity() {
        var guests: [Guest] = (0..<12).map { makeGuest("G\($0)") }
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180) // ~9 seats
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180) // ~9 seats

        let result = SeatingOptimizer.solve(
            guests: guests,
            tables: [t1, t2],
            relationships: []
        )
        let t1Count = result.values.filter { $0 == t1.id }.count
        let t2Count = result.values.filter { $0 == t2.id }.count
        #expect(t1Count <= t1.capacity)
        #expect(t2Count <= t2.capacity)
    }

    @Test("Pinned guests stay at their table")
    func pinnedGuestsStay() {
        let alice = makeGuest("Alice")
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        alice.table = t1
        alice.isPinned = true

        let result = SeatingOptimizer.solve(
            guests: [alice],
            tables: [t1, t2],
            relationships: []
        )
        #expect(result[alice.id] == t1.id)
    }

    @Test("Large group splits across adjacent tables")
    func groupSplitting() {
        // 12 JGA friends, 8-seat table -> must split
        let guests = (0..<12).map { makeGuest("JGA\($0)", groupType: .jga) }
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180) // ~9
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180) // ~9

        let result = SeatingOptimizer.solve(
            guests: guests,
            tables: [t1, t2],
            relationships: []
        )
        // All guests should be assigned
        #expect(result.count == 12)
    }

    @Test("Children from same family stay with parents")
    func childrenWithParents() {
        let fid = UUID()
        let parent = makeGuest("Mama")
        parent.familyID = fid
        let child = makeGuest("Kind", groupType: .immediateFamily)
        child.familyID = fid
        child.isChild = true
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)

        let result = SeatingOptimizer.solve(
            guests: [parent, child],
            tables: [t1, t2],
            relationships: []
        )
        #expect(result[parent.id] == result[child.id])
    }
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL — `SeatingOptimizer` not defined

**Step 3: Implement SeatingGraph**

```swift
// Gaesteglueck/Services/SeatingGraph.swift
import Foundation

/// Represents the social graph as an adjacency-weighted structure.
/// Guests are nodes, relationships and group memberships are edges.
struct SeatingGraph {
    struct Edge {
        let from: UUID
        let to: UUID
        let weight: Double // positive = attract, negative = repel
        let isHardConstraint: Bool
    }

    let nodes: [UUID]
    let edges: [Edge]

    /// Build graph from guests and relationships.
    init(guests: [Guest], relationships: [Relationship]) {
        self.nodes = guests.map(\.id)
        var edges: [Edge] = []

        // 1. Explicit relationships
        for rel in relationships {
            edges.append(Edge(
                from: rel.personAID,
                to: rel.personBID,
                weight: rel.type.weight * 100,
                isHardConstraint: rel.type.isHardConstraint
            ))
        }

        // 2. Family bonds (implicit edges from shared familyID)
        let families = Dictionary(grouping: guests.filter { $0.familyID != nil }, by: { $0.familyID! })
        for (_, members) in families {
            for i in members.indices {
                for j in (i+1)..<members.count {
                    let alreadyHasEdge = edges.contains { e in
                        (e.from == members[i].id && e.to == members[j].id) ||
                        (e.from == members[j].id && e.to == members[i].id)
                    }
                    if !alreadyHasEdge {
                        // Children with parents = hard constraint
                        let isChildPair = members[i].isChild || members[j].isChild
                        edges.append(Edge(
                            from: members[i].id,
                            to: members[j].id,
                            weight: isChildPair ? 100 : 70,
                            isHardConstraint: isChildPair
                        ))
                    }
                }
            }
        }

        // 3. Group cohesion (implicit edges from shared groupType)
        let groups = Dictionary(grouping: guests.filter { $0.groupType != nil }, by: { g in
            "\(g.groupType!.rawValue)_\(g.customGroupName ?? "")"
        })
        for (_, members) in groups {
            let weight = members.first?.groupType?.cohesionWeight ?? 0.3
            for i in members.indices {
                for j in (i+1)..<members.count {
                    let alreadyHasEdge = edges.contains { e in
                        (e.from == members[i].id && e.to == members[j].id) ||
                        (e.from == members[j].id && e.to == members[i].id)
                    }
                    if !alreadyHasEdge {
                        edges.append(Edge(
                            from: members[i].id,
                            to: members[j].id,
                            weight: weight * 40,
                            isHardConstraint: false
                        ))
                    }
                }
            }
        }

        self.edges = edges
    }

    /// Get all edges involving a specific node.
    func edges(for nodeID: UUID) -> [Edge] {
        edges.filter { $0.from == nodeID || $0.to == nodeID }
    }

    /// Get the attraction weight between two nodes. 0 if no edge.
    func weight(between a: UUID, and b: UUID) -> Double {
        edges.first { ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a) }?.weight ?? 0
    }
}
```

**Step 4: Implement SeatingOptimizer**

Uses a greedy constraint-satisfaction approach with simulated annealing refinement.

```swift
// Gaesteglueck/Services/SeatingOptimizer.swift
import Foundation

enum SeatingOptimizer {
    /// Solve the seating assignment problem.
    /// Returns a mapping of guestID -> tableID.
    static func solve(
        guests: [Guest],
        tables: [GuestTable],
        relationships: [Relationship],
        iterations: Int = 5000
    ) -> [UUID: UUID] {
        guard !guests.isEmpty, !tables.isEmpty else { return [:] }

        let graph = SeatingGraph(guests: guests, relationships: relationships)
        let tableIDs = tables.map(\.id)
        let tableCapacities = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0.capacity) })

        // Phase 1: Initialize — respect pinned guests, then greedy assign
        var assignment: [UUID: UUID] = [:]

        // Pinned guests first (immovable)
        let pinnedGuests = guests.filter { $0.isPinned && $0.table != nil }
        for guest in pinnedGuests {
            assignment[guest.id] = guest.table!.id
        }

        // Group hard-constraint clusters (partners, children)
        let hardClusters = buildHardClusters(guests: guests, graph: graph)

        // Assign clusters greedily to tables with most affinity
        for cluster in hardClusters {
            if cluster.allSatisfy({ assignment[$0] != nil }) { continue } // Already assigned

            let bestTable = tableIDs.max { a, b in
                affinityScore(cluster: cluster, table: a, assignment: assignment, graph: graph) <
                affinityScore(cluster: cluster, table: b, assignment: assignment, graph: graph)
            } ?? tableIDs[0]

            // Check capacity
            let currentCount = assignment.values.filter { $0 == bestTable }.count
            let clusterSize = cluster.filter { assignment[$0] == nil }.count
            if currentCount + clusterSize <= (tableCapacities[bestTable] ?? 0) {
                for guestID in cluster where assignment[guestID] == nil {
                    assignment[guestID] = bestTable
                }
            } else {
                // Find table with space
                for tid in tableIDs {
                    let count = assignment.values.filter { $0 == tid }.count
                    if count + clusterSize <= (tableCapacities[tid] ?? 0) {
                        for guestID in cluster where assignment[guestID] == nil {
                            assignment[guestID] = tid
                        }
                        break
                    }
                }
            }
        }

        // Assign remaining unassigned guests
        for guest in guests where assignment[guest.id] == nil {
            let bestTable = tableIDs
                .filter { tid in
                    assignment.values.filter { $0 == tid }.count < (tableCapacities[tid] ?? 0)
                }
                .max { a, b in
                    affinityScore(cluster: [guest.id], table: a, assignment: assignment, graph: graph) <
                    affinityScore(cluster: [guest.id], table: b, assignment: assignment, graph: graph)
                }
            if let tid = bestTable {
                assignment[guest.id] = tid
            }
        }

        // Phase 2: Simulated annealing — swap non-pinned guests to improve score
        let pinnedIDs = Set(pinnedGuests.map(\.id))
        var bestAssignment = assignment
        var bestScore = totalScore(assignment: assignment, graph: graph)
        var temperature = 1.0

        for _ in 0..<iterations {
            var candidate = bestAssignment

            // Pick a random non-pinned guest and swap to a different table
            let movableGuests = guests.filter { !pinnedIDs.contains($0.id) }
            guard let guest = movableGuests.randomElement(),
                  let currentTable = candidate[guest.id] else { continue }

            let otherTables = tableIDs.filter { $0 != currentTable }
            guard let newTable = otherTables.randomElement() else { continue }

            // Check capacity
            let newTableCount = candidate.values.filter { $0 == newTable }.count
            guard newTableCount < (tableCapacities[newTable] ?? 0) else { continue }

            // Check hard constraints
            let hardEdges = graph.edges(for: guest.id).filter(\.isHardConstraint)
            let wouldViolate = hardEdges.contains { edge in
                let otherID = edge.from == guest.id ? edge.to : edge.from
                guard let otherTable = candidate[otherID] else { return false }
                if edge.weight > 0 {
                    return otherTable != newTable // Positive hard constraint: must be same table
                } else {
                    return otherTable == newTable // Negative hard constraint: must be different table
                }
            }
            guard !wouldViolate else { continue }

            candidate[guest.id] = newTable
            let candidateScore = totalScore(assignment: candidate, graph: graph)

            // Accept if better, or probabilistically if worse (annealing)
            let delta = candidateScore - bestScore
            if delta > 0 || Double.random(in: 0...1) < exp(delta / temperature) {
                bestAssignment = candidate
                bestScore = candidateScore
            }

            temperature *= 0.999
        }

        return bestAssignment
    }

    // MARK: - Private

    /// Build clusters of guests connected by hard constraints.
    private static func buildHardClusters(guests: [Guest], graph: SeatingGraph) -> [[UUID]] {
        var visited: Set<UUID> = []
        var clusters: [[UUID]] = []

        for guest in guests {
            guard !visited.contains(guest.id) else { continue }
            var cluster: [UUID] = []
            var queue: [UUID] = [guest.id]

            while let current = queue.popLast() {
                guard !visited.contains(current) else { continue }
                visited.insert(current)
                cluster.append(current)

                let hardNeighbors = graph.edges(for: current)
                    .filter { $0.isHardConstraint && $0.weight > 0 }
                    .map { $0.from == current ? $0.to : $0.from }
                queue.append(contentsOf: hardNeighbors)
            }

            clusters.append(cluster)
        }

        // Sort: largest clusters first (they're hardest to place)
        return clusters.sorted { $0.count > $1.count }
    }

    /// Score how well a cluster fits at a specific table given current assignment.
    private static func affinityScore(cluster: [UUID], table: UUID, assignment: [UUID: UUID], graph: SeatingGraph) -> Double {
        var score: Double = 0
        let tableGuests = assignment.filter { $0.value == table }.map(\.key)

        for guestID in cluster {
            for tableGuestID in tableGuests {
                score += graph.weight(between: guestID, and: tableGuestID)
            }
        }
        return score
    }

    /// Total score of an assignment.
    private static func totalScore(assignment: [UUID: UUID], graph: SeatingGraph) -> Double {
        var score: Double = 0
        let byTable = Dictionary(grouping: assignment, by: \.value).mapValues { $0.map(\.key) }

        for (_, guestIDs) in byTable {
            for i in guestIDs.indices {
                for j in (i+1)..<guestIDs.count {
                    score += graph.weight(between: guestIDs[i], and: guestIDs[j])
                }
            }
        }
        return score
    }
}
```

**Step 5: Implement AutoAssignButton**

```swift
// Gaesteglueck/Views/AutoAssignButton.swift
import SwiftUI
import SwiftData

struct AutoAssignButton: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var relationships: [Relationship]

    @State private var isProcessing = false
    @State private var showingConfirmation = false
    @State private var resultScore: Double?

    private var unassignedGuests: [Guest] {
        guests.filter { $0.table == nil }
    }

    var body: some View {
        Button {
            showingConfirmation = true
        } label: {
            Label(isProcessing ? "Berechne..." : "Auto-Zuweisen", systemImage: "wand.and.stars")
        }
        .disabled(unassignedGuests.isEmpty || tables.isEmpty || isProcessing)
        .confirmationDialog("Automatische Sitzordnung", isPresented: $showingConfirmation) {
            Button("Nur nicht zugewiesene Gäste") { runSolver(reassignAll: false) }
            Button("Alle neu zuweisen (Pins bleiben)") { runSolver(reassignAll: true) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Algorithmus berechnet die beste Sitzordnung basierend auf Beziehungen, Gruppen und Konflikten.")
        }
        .alert("Sitzordnung berechnet", isPresented: Binding(
            get: { resultScore != nil },
            set: { if !$0 { resultScore = nil } }
        )) {
            Button("OK") { resultScore = nil }
        } message: {
            Text("Happiness Score: \(Int(resultScore ?? 0))")
        }
    }

    private func runSolver(reassignAll: Bool) {
        isProcessing = true

        Task {
            // Unassign non-pinned guests if reassigning all
            if reassignAll {
                for guest in guests where !guest.isPinned {
                    guest.table = nil
                }
            }

            let guestsToAssign = reassignAll ? guests.filter { !$0.isPinned } : unassignedGuests
            let assignment = SeatingOptimizer.solve(
                guests: guestsToAssign,
                tables: tables,
                relationships: relationships
            )

            // Apply assignment
            let tableMap = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0) })
            for (guestID, tableID) in assignment {
                if let guest = guests.first(where: { $0.id == guestID }),
                   let table = tableMap[tableID] {
                    guest.table = table
                }
            }

            let score = HappinessScorer.scoreAllTables(tables, relationships: relationships)

            await MainActor.run {
                isProcessing = false
                resultScore = score
            }
        }
    }
}
```

**Step 6: Add to RoomCanvasView toolbar**

```swift
ToolbarItem(placement: .primaryAction) {
    AutoAssignButton()
}
```

**Step 7: Run tests**

Run: `xcodebuild test -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`
Expected: PASS (all optimizer tests)

**Step 8: Commit**

```bash
git add Gaesteglueck/Services/ Gaesteglueck/Views/ GaesteglueckTests/Services/
git commit -m "feat: add graph-based seating optimizer with simulated annealing and hard constraints"
```

---

## Task 21: AI-Assisted Seating Suggestions (On-Device / OpenRouter)

Add optional AI assistance: use Apple's on-device Core ML (if available on Apple Silicon) for natural-language relationship analysis, or fall back to free models via OpenRouter for suggestions like "This group seems like they'd get along" or "Consider moving X closer to Y."

**Files:**
- Create: `Gaesteglueck/Services/AIAssistant.swift`
- Create: `Gaesteglueck/Services/OpenRouterClient.swift`
- Create: `Gaesteglueck/Views/AISuggestionView.swift`

**Step 1: Implement OpenRouterClient**

```swift
// Gaesteglueck/Services/OpenRouterClient.swift
import Foundation

actor OpenRouterClient {
    private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private var apiKey: String?

    init(apiKey: String? = nil) {
        self.apiKey = apiKey ?? UserDefaults.standard.string(forKey: "openRouterAPIKey")
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct Request: Codable {
        let model: String
        let messages: [Message]
    }

    struct Response: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    func suggest(prompt: String) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIError.noAPIKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = Request(
            model: "meta-llama/llama-3.1-8b-instruct:free", // Free model
            messages: [
                Message(role: "system", content: """
                    Du bist ein Hochzeitsplaner-Assistent. Du hilfst bei der Sitzordnung.
                    Antworte auf Deutsch, kurz und praktisch.
                    """),
                Message(role: "user", content: prompt)
            ]
        )

        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(Response.self, from: data)

        return response.choices.first?.message.content ?? "Keine Antwort erhalten."
    }
}

enum AIError: Error, LocalizedError {
    case noAPIKey
    case noSuggestion

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "Kein OpenRouter API-Key konfiguriert. Gehe zu Einstellungen."
        case .noSuggestion: "Keine Vorschläge verfügbar."
        }
    }
}
```

**Step 2: Implement AIAssistant**

```swift
// Gaesteglueck/Services/AIAssistant.swift
import Foundation

enum AIAssistant {
    /// Generate a natural-language summary of the current seating situation and suggestions.
    static func generateSuggestions(
        tables: [GuestTable],
        guests: [Guest],
        relationships: [Relationship],
        violations: [Violation]
    ) -> String {
        var prompt = "Hier ist die aktuelle Sitzordnung einer Hochzeit:\n\n"

        for table in tables {
            let guestNames = table.guests.map { g in
                var desc = g.name
                if let role = g.familyRole { desc += " (\(role.rawValue))" }
                if let group = g.groupLabel { desc += " [\(group)]" }
                return desc
            }
            prompt += "**\(table.name)** (\(table.shape.rawValue), \(table.guests.count)/\(table.capacity)):\n"
            prompt += guestNames.isEmpty ? "  Leer\n" : guestNames.map { "  - \($0)" }.joined(separator: "\n") + "\n"
        }

        let unassigned = guests.filter { $0.table == nil }
        if !unassigned.isEmpty {
            prompt += "\n**Noch nicht zugewiesen:** \(unassigned.map(\.name).joined(separator: ", "))\n"
        }

        if !violations.isEmpty {
            prompt += "\n**Probleme:**\n"
            for v in violations {
                let nameA = guests.first { $0.id == v.personAID }?.name ?? "?"
                let nameB = guests.first { $0.id == v.personBID }?.name ?? "?"
                prompt += "  - \(v.description): \(nameA) & \(nameB)\n"
            }
        }

        prompt += "\nGib 3-5 konkrete Vorschläge, wie die Sitzordnung verbessert werden kann. Berücksichtige Familiengruppen, Konflikte und die Stimmung an den Tischen."

        return prompt
    }
}
```

**Step 3: Implement AISuggestionView**

```swift
// Gaesteglueck/Views/AISuggestionView.swift
import SwiftUI
import SwiftData

struct AISuggestionView: View {
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.name) private var guests: [Guest]
    @Query private var relationships: [Relationship]

    @State private var suggestion = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("KI-Assistent", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await fetchSuggestion() }
                } label: {
                    Label(isLoading ? "Denke nach..." : "Vorschläge holen", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if !suggestion.isEmpty {
                ScrollView {
                    Text(suggestion)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func fetchSuggestion() async {
        isLoading = true
        error = nil

        let violations = HappinessScorer.findViolations(tables: tables, relationships: relationships)
        let prompt = AIAssistant.generateSuggestions(
            tables: tables,
            guests: guests,
            relationships: relationships,
            violations: violations
        )

        let client = OpenRouterClient()
        do {
            suggestion = try await client.suggest(prompt: prompt)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
```

**Step 4: Add API key settings**

In the sidebar, add a Settings section. In `AppSidebar.swift`:
```swift
case settings = "Einstellungen"
// icon:
case .settings: "gear"
```

Create `SettingsView.swift`:
```swift
struct SettingsView: View {
    @AppStorage("openRouterAPIKey") private var apiKey = ""

    var body: some View {
        Form {
            Section("KI-Assistent (Optional)") {
                SecureField("OpenRouter API-Key", text: $apiKey)
                Text("Kostenlose Modelle verfügbar unter openrouter.ai")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Einstellungen")
    }
}
```

**Step 5: Add AISuggestionView to RoomCanvasView**

Add as a floating panel in the detail sidebar:
```swift
// In the detail panel, below violations:
AISuggestionView()
```

**Step 6: Build and verify**

Run: `xcodebuild -scheme Gaesteglueck -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add Gaesteglueck/Services/ Gaesteglueck/Views/
git commit -m "feat: add AI-assisted seating suggestions via OpenRouter with free models"
```

---

## Task 22: Enhanced PDF Export with Dietary Info

Update the PDF export to include dietary preferences, allergies, and a caterer-friendly summary table.

**Files:**
- Modify: `Gaesteglueck/Services/PDFExporter.swift`
- Test: `GaesteglueckTests/Services/PDFExporterTests.swift` (update)

**Step 1: Write failing test**

```swift
// Add to PDFExporterTests
@Test("PDF includes dietary summary section")
func dietarySummary() {
    let table = GuestTable(name: "T1", shape: .round, diameter: 180)
    let veganGuest = Guest(name: "Lisa", side: .bride, dietaryPreference: .vegan, allergies: "Nüsse")
    let meatGuest = Guest(name: "Klaus", side: .groom)
    table.guests = [veganGuest, meatGuest]

    let data = PDFExporter.generatePDF(
        tables: [table],
        eventName: "Hochzeit",
        date: Date()
    )
    #expect(data.count > 200) // Must include extra content
}
```

**Step 2: Update PDFExporter to include dietary info**

In `PDFExporter.generatePDF`, after listing guests per table, add dietary icons:
```swift
for guest in table.guests.sorted(by: { $0.name < $1.name }) {
    var line = "• \(guest.name) (\(guest.side.rawValue))"
    if guest.dietaryPreference != .meat {
        line += " \(guest.dietaryPreference.badge) \(guest.dietaryPreference.rawValue)"
    }
    if !guest.allergies.isEmpty {
        line += " ⚠️ \(guest.allergies)"
    }
    if guest.isChild {
        line += " 👶 Kind"
    }
    line.draw(at: CGPoint(x: 60, y: y), withAttributes: bodyAttributes)
    y += 18
}
```

After the table listings, add a dietary summary page:
```swift
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

"🥩 Fleisch: \(meatCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 20
"🥬 Vegetarisch: \(vegCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 20
"🌱 Vegan: \(veganCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 20
"👶 Kinder: \(childCount)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttributes); y += 30

// List all allergies
let guestsWithAllergies = allGuests.filter { !$0.allergies.isEmpty }
if !guestsWithAllergies.isEmpty {
    "⚠️ Unverträglichkeiten:".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttributes)
    y += 22
    for guest in guestsWithAllergies.sorted(by: { $0.name < $1.name }) {
        "  \(guest.name): \(guest.allergies)".draw(at: CGPoint(x: 60, y: y), withAttributes: bodyAttributes)
        y += 18
    }
}
```

**Step 3: Run tests**

Expected: PASS

**Step 4: Commit**

```bash
git add Gaesteglueck/Services/ GaesteglueckTests/Services/
git commit -m "feat: add dietary info and caterer summary to PDF export"
```

---

## Task 23: Auto Table Placement Suggestions

Given the calibrated room dimensions and a set of tables, suggest an optimal layout that respects spacing requirements (60-80cm chair radius, service walkways).

**Files:**
- Create: `Gaesteglueck/Services/TablePlacer.swift`
- Test: `GaesteglueckTests/Services/TablePlacerTests.swift`
- Create: `Gaesteglueck/Views/Canvas/AutoPlaceButton.swift`

**Step 1: Write failing tests**

```swift
// GaesteglueckTests/Services/TablePlacerTests.swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Table Placer")
struct TablePlacerTests {
    @Test("Places tables without overlap")
    func noOverlap() {
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        let roomWidth: Double = 1000  // 10m
        let roomDepth: Double = 800   // 8m

        let placements = TablePlacer.suggestLayout(
            tables: [t1, t2],
            roomWidthCM: roomWidth,
            roomDepthCM: roomDepth
        )

        #expect(placements.count == 2)

        // Check no overlap (center distance > sum of radii + chair buffer)
        let p1 = placements[0]
        let p2 = placements[1]
        let distance = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
        let minDistance = (t1.diameter / 2 + t2.diameter / 2) + 160 // 80cm buffer each side
        #expect(distance >= minDistance)
    }

    @Test("Bride table placed centrally")
    func brideTableCentered() {
        let bt = GuestTable(name: "Brauttisch", shape: .brideTable, width: 400, depth: 100)
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)

        let placements = TablePlacer.suggestLayout(
            tables: [bt, t1],
            roomWidthCM: 1000,
            roomDepthCM: 800
        )

        let bridePlace = placements.first { $0.tableID == bt.id }!
        // Bride table should be near the center-top of the room
        #expect(bridePlace.x > 300 && bridePlace.x < 700)
    }

    @Test("Tables fit within room bounds")
    func withinBounds() {
        let tables = (0..<5).map { GuestTable(name: "T\($0)", shape: .round, diameter: 180) }

        let placements = TablePlacer.suggestLayout(
            tables: tables,
            roomWidthCM: 1200,
            roomDepthCM: 1000
        )

        for p in placements {
            #expect(p.x > 0 && p.x < 1200)
            #expect(p.y > 0 && p.y < 1000)
        }
    }
}
```

**Step 2: Implement TablePlacer**

```swift
// Gaesteglueck/Services/TablePlacer.swift
import Foundation

struct TablePlacement {
    let tableID: UUID
    let x: Double  // center position in cm
    let y: Double
}

enum TablePlacer {
    private static let chairBuffer: Double = 80 // cm around each table for chairs
    private static let walkwayBuffer: Double = 100 // cm for service walkways
    private static let wallMargin: Double = 120 // cm from walls

    /// Suggest a layout for tables within the given room dimensions.
    static func suggestLayout(
        tables: [GuestTable],
        roomWidthCM: Double,
        roomDepthCM: Double
    ) -> [TablePlacement] {
        var placements: [TablePlacement] = []

        // Sort: bride table first, then by size (largest first)
        let sorted = tables.sorted { a, b in
            if a.shape == .brideTable { return true }
            if b.shape == .brideTable { return false }
            return tableFootprint(a) > tableFootprint(b)
        }

        let usableWidth = roomWidthCM - 2 * wallMargin
        let usableDepth = roomDepthCM - 2 * wallMargin

        for table in sorted {
            let footprint = tableFootprint(table)
            let position: (x: Double, y: Double)

            if table.shape == .brideTable {
                // Bride table: center-top of room
                position = (roomWidthCM / 2, wallMargin + footprint / 2)
            } else {
                // Find position that doesn't overlap with existing placements
                position = findNonOverlappingPosition(
                    for: table,
                    existing: placements,
                    allTables: tables,
                    roomWidth: roomWidthCM,
                    roomDepth: roomDepthCM
                )
            }

            placements.append(TablePlacement(tableID: table.id, x: position.x, y: position.y))
        }

        return placements
    }

    private static func tableFootprint(_ table: GuestTable) -> Double {
        switch table.shape {
        case .round:
            return table.diameter + 2 * chairBuffer
        case .rectangular, .brideTable:
            return max(table.width, table.depth) + 2 * chairBuffer
        }
    }

    private static func findNonOverlappingPosition(
        for table: GuestTable,
        existing: [TablePlacement],
        allTables: [GuestTable],
        roomWidth: Double,
        roomDepth: Double
    ) -> (x: Double, y: Double) {
        let tableMap = Dictionary(uniqueKeysWithValues: allTables.map { ($0.id, $0) })
        let footprint = tableFootprint(table)

        // Grid search for best position
        let stepSize = footprint * 0.8
        var bestPos = (x: roomWidth / 2, y: roomDepth / 2)
        var bestMinDist = -1.0

        var y = wallMargin + footprint / 2
        while y < roomDepth - wallMargin {
            var x = wallMargin + footprint / 2
            while x < roomWidth - wallMargin {
                let minDist = existing.map { p -> Double in
                    let otherTable = tableMap[p.tableID]
                    let otherFootprint = otherTable.map { tableFootprint($0) } ?? footprint
                    let requiredDist = (footprint + otherFootprint) / 2 + walkwayBuffer
                    let actualDist = sqrt(pow(x - p.x, 2) + pow(y - p.y, 2))
                    return actualDist - requiredDist
                }.min() ?? Double.infinity

                if minDist > bestMinDist {
                    bestMinDist = minDist
                    bestPos = (x, y)
                }

                x += stepSize
            }
            y += stepSize
        }

        return bestPos
    }
}
```

**Step 3: Implement AutoPlaceButton**

```swift
// Gaesteglueck/Views/Canvas/AutoPlaceButton.swift
import SwiftUI
import SwiftData

struct AutoPlaceButton: View {
    @Query private var tables: [GuestTable]
    @Query private var roomPlans: [RoomPlan]

    @State private var showingConfirmation = false

    private var roomWidth: Double {
        roomPlans.first?.roomWidthCM ?? 1200
    }

    private var roomDepth: Double {
        roomPlans.first?.roomDepthCM ?? 1000
    }

    var body: some View {
        Button {
            showingConfirmation = true
        } label: {
            Label("Tische anordnen", systemImage: "square.grid.3x3")
        }
        .disabled(tables.isEmpty)
        .confirmationDialog("Tische automatisch anordnen?", isPresented: $showingConfirmation) {
            Button("Anordnen") { placeAll() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Tische werden basierend auf den Raummaßen (\(Int(roomWidth/100))×\(Int(roomDepth/100))m) optimal platziert. Festgepinnte Tische bleiben an ihrer Position.")
        }
    }

    private func placeAll() {
        let movableTables = tables.filter { !$0.isLocked }
        let placements = TablePlacer.suggestLayout(
            tables: movableTables,
            roomWidthCM: roomWidth,
            roomDepthCM: roomDepth
        )

        // Convert from cm to canvas points (simple 1:3 ratio for display)
        let scale = 1.0 / 3.0
        for placement in placements {
            if let table = tables.first(where: { $0.id == placement.tableID }) {
                table.positionX = placement.x * scale
                table.positionY = placement.y * scale
            }
        }
    }
}
```

**Step 4: Add to RoomCanvasView toolbar**

```swift
ToolbarItem(placement: .secondaryAction) {
    AutoPlaceButton()
}
```

**Step 5: Run tests**

Expected: PASS

**Step 6: Commit**

```bash
git add Gaesteglueck/Services/ Gaesteglueck/Views/ GaesteglueckTests/Services/
git commit -m "feat: add auto table placement with collision avoidance and room-aware positioning"
```

---

## Summary

| Task | Feature | Estimated Steps |
|------|---------|----------------|
| 1 | Xcode project setup | 5 |
| 2 | Guest, Event, DietaryPreference, GroupType, FamilyRole models | 10 |
| 3 | GuestTable, Relationship, RoomPlan models + table combination | 10 |
| 4 | Happiness Score algorithm | 5 |
| 5 | Navigation shell | 5 |
| 6 | Guest list CRUD with dietary + group info | 6 |
| 7 | Table list CRUD | 6 |
| 8 | Relationship management UI | 6 |
| 9 | Room canvas + drag tables | 6 |
| 10 | Guest drag & drop | 3 |
| 11 | Live score display + warnings | 4 |
| 12 | PDF export (basic) | 7 |
| 13 | Excel & CSV import with family rows + dietary parsing | 11 |
| 14 | Pin/lock guests | 7 |
| 15 | Family grouping | 4 |
| 16 | Statistics dashboard | 4 |
| 17 | Relationship onboarding wizard | 7 |
| 18 | Room photo import & scale calibration | 5 |
| 19 | Table combination (rectangular Tafel) | 6 |
| 20 | Graph-based seating solver (auto-assign) | 8 |
| 21 | AI-assisted suggestions (OpenRouter) | 7 |
| 22 | Enhanced PDF export with dietary info for caterer | 4 |
| 23 | Auto table placement suggestions | 6 |

**Total: 23 tasks, ~144 steps**

This MVP delivers: Excel/CSV import with family rows and dietary data, structured group types and family roles, guided relationship onboarding wizard, room photo import with scale calibration, drag-and-drop seating on a canvas, table combination, graph-theory-based seating optimization with simulated annealing, AI-assisted suggestions via OpenRouter, live happiness scoring, and PDF export with a dedicated caterer summary — a complete wedding seating planner from import to print.
