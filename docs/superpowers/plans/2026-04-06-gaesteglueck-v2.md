# Gästeglück v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Gästeglück as a macOS-first SwiftUI app with multi-tag relationship system, LM Studio AI integration, and intelligent seating planning.

**Architecture:** SwiftUI + SwiftData on macOS 15+. Tag-based social graph replaces rigid relationship types. LM Studio (OpenAI-compatible REST API on localhost) handles unstructured data parsing and seating suggestions. Three-phase UX: Import → Enrich → AI-assisted Plan.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, CoreXLSX, PDFKit (AppKit), LM Studio REST API

**Spec:** `docs/superpowers/specs/2026-04-06-gaesteglueck-v2-design.md`

---

## File Structure

### Files to DELETE (replaced by new models)

- `Sources/Gaesteglueck/Models/Side.swift` → replaced by `PartnerAssignment.swift`
- `Sources/Gaesteglueck/Models/RelationshipType.swift` → replaced by `ConstraintType.swift`
- `Sources/Gaesteglueck/Models/Relationship.swift` → replaced by `Constraint.swift` + `Tag.swift`
- `Sources/Gaesteglueck/Models/GroupType.swift` → replaced by `TagCategory.swift`
- `Sources/Gaesteglueck/Services/OpenRouterClient.swift` → replaced by `LMStudioClient.swift`
- `Sources/Gaesteglueck/Services/AIAssistant.swift` → replaced by `LLMGuestParser.swift` + `GroupAnalyzer.swift`
- `Sources/Gaesteglueck/Services/OnboardingEngine.swift` → replaced by enrichment wizard views
- `Sources/Gaesteglueck/Views/RelationshipFormView.swift` → replaced by tag views
- `Sources/Gaesteglueck/Views/RelationshipListView.swift` → replaced by tag views
- `Sources/Gaesteglueck/Views/RelationshipRowView.swift` → replaced by tag views
- `Sources/Gaesteglueck/Views/Onboarding/OnboardingWizardView.swift` → replaced by enrichment wizard
- `Sources/Gaesteglueck/Views/AISuggestionView.swift` → replaced by KI wizard + chat
- `Sources/Gaesteglueck/Views/AutoAssignButton.swift` → integrated into KI flow

### Files to CREATE

**Models:**
- `Sources/Gaesteglueck/Models/PartnerAssignment.swift`
- `Sources/Gaesteglueck/Models/AgeCategory.swift`
- `Sources/Gaesteglueck/Models/TagCategory.swift`
- `Sources/Gaesteglueck/Models/ConstraintType.swift`
- `Sources/Gaesteglueck/Models/CombinationRole.swift`
- `Sources/Gaesteglueck/Models/Tag.swift`
- `Sources/Gaesteglueck/Models/Constraint.swift`
- `Sources/Gaesteglueck/Models/TableInventoryItem.swift`

**Services:**
- `Sources/Gaesteglueck/Services/LMStudioClient.swift`
- `Sources/Gaesteglueck/Services/LLMGuestParser.swift`
- `Sources/Gaesteglueck/Services/GroupAnalyzer.swift`

**Views:**
- `Sources/Gaesteglueck/Views/DashboardView.swift`
- `Sources/Gaesteglueck/Views/EventSetupView.swift`
- `Sources/Gaesteglueck/Views/TagListView.swift`
- `Sources/Gaesteglueck/Views/TagDetailView.swift`
- `Sources/Gaesteglueck/Views/EnrichmentWizardView.swift`
- `Sources/Gaesteglueck/Views/KIWizardView.swift`
- `Sources/Gaesteglueck/Views/KIChatView.swift`
- `Sources/Gaesteglueck/Views/TableInventoryView.swift`

**Tests:**
- `Tests/GaesteglueckTests/Models/TagTests.swift`
- `Tests/GaesteglueckTests/Models/ConstraintTests.swift`
- `Tests/GaesteglueckTests/Services/LMStudioClientTests.swift`
- `Tests/GaesteglueckTests/Services/LLMGuestParserTests.swift`
- `Tests/GaesteglueckTests/Services/GroupAnalyzerTests.swift`

### Files to MODIFY

- `Package.swift` — platform focus
- `Sources/Gaesteglueck/Models/Event.swift` — partner names, menu, room
- `Sources/Gaesteglueck/Models/Guest.swift` — new fields, remove old
- `Sources/Gaesteglueck/Models/GuestTable.swift` — combination, child table
- `Sources/Gaesteglueck/Models/FamilyRole.swift` — split cousin into cousin/cousine
- `Sources/Gaesteglueck/Models/TableShape.swift` — add square, remove brideTable
- `Sources/Gaesteglueck/Models/DietaryPreference.swift` — keep but minor update
- `Sources/Gaesteglueck/Services/CSVParser.swift` — wedding form format
- `Sources/Gaesteglueck/Services/ExcelParser.swift` — wedding form format
- `Sources/Gaesteglueck/Services/GuestImporter.swift` — new model types
- `Sources/Gaesteglueck/Services/SeatingGraph.swift` — tag-based edges
- `Sources/Gaesteglueck/Services/HappinessScorer.swift` — constraint-based
- `Sources/Gaesteglueck/Services/SeatingOptimizer.swift` — constraint-based
- `Sources/Gaesteglueck/Services/PDFExporter.swift` — macOS AppKit
- `Sources/Gaesteglueck/GaesteglueckApp.swift` — new model container
- `Sources/Gaesteglueck/ContentView.swift` — new navigation
- `Sources/Gaesteglueck/Views/AppSidebar.swift` — new sections
- `Sources/Gaesteglueck/Views/GuestListView.swift` — tags, partnerAssignment
- `Sources/Gaesteglueck/Views/GuestFormView.swift` — new fields
- `Sources/Gaesteglueck/Views/GuestRowView.swift` — tags display
- `Sources/Gaesteglueck/Views/ImportButton.swift` — LLM flow
- `Sources/Gaesteglueck/Views/ImportPreviewView.swift` — LLM parsed preview
- `Sources/Gaesteglueck/Views/RoomCanvasView.swift` — three-panel + chat
- `Sources/Gaesteglueck/Views/StatisticsView.swift` → becomes DashboardView
- `Sources/Gaesteglueck/Views/SettingsView.swift` — LM Studio config
- `Sources/Gaesteglueck/Views/TableListView.swift` — inventory
- `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift` — dietary display
- `Sources/Gaesteglueck/Views/Canvas/ViolationBannerView.swift` — constraint-based
- `Sources/Gaesteglueck/Views/ModelExtensions+UI.swift` — new model extensions

---

## Phase 1: Data Layer (Enums, Models, Tests)

### Task 1: Platform Setup & Delete Old Files

**Files:**
- Modify: `Package.swift`
- Delete: `Sources/Gaesteglueck/Models/Side.swift`
- Delete: `Sources/Gaesteglueck/Models/RelationshipType.swift`
- Delete: `Sources/Gaesteglueck/Models/Relationship.swift`
- Delete: `Sources/Gaesteglueck/Models/GroupType.swift`
- Delete: `Sources/Gaesteglueck/Services/OpenRouterClient.swift`
- Delete: `Sources/Gaesteglueck/Services/AIAssistant.swift`
- Delete: `Sources/Gaesteglueck/Services/OnboardingEngine.swift`
- Delete: `Sources/Gaesteglueck/Views/RelationshipFormView.swift`
- Delete: `Sources/Gaesteglueck/Views/RelationshipListView.swift`
- Delete: `Sources/Gaesteglueck/Views/RelationshipRowView.swift`
- Delete: `Sources/Gaesteglueck/Views/Onboarding/OnboardingWizardView.swift`
- Delete: `Sources/Gaesteglueck/Views/AISuggestionView.swift`
- Delete: `Sources/Gaesteglueck/Views/AutoAssignButton.swift`
- Delete: `Tests/GaesteglueckTests/Models/RelationshipTests.swift`
- Delete: `Tests/GaesteglueckTests/Services/OnboardingEngineTests.swift`

- [ ] **Step 1: Update Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gaesteglueck",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "Gaesteglueck", targets: ["Gaesteglueck"])
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX", from: "0.14.0")
    ],
    targets: [
        .target(name: "Gaesteglueck", dependencies: ["CoreXLSX"]),
        .testTarget(name: "GaesteglueckTests", dependencies: ["Gaesteglueck"])
    ]
)
```

Remove `.iOS(.v18)` — macOS only for now.

- [ ] **Step 2: Delete old model files**

```bash
cd /Users/gereon/Code/worktrees/famous-planes-slide-8x7
rm Sources/Gaesteglueck/Models/Side.swift
rm Sources/Gaesteglueck/Models/RelationshipType.swift
rm Sources/Gaesteglueck/Models/Relationship.swift
rm Sources/Gaesteglueck/Models/GroupType.swift
```

- [ ] **Step 3: Delete old service files**

```bash
rm Sources/Gaesteglueck/Services/OpenRouterClient.swift
rm Sources/Gaesteglueck/Services/AIAssistant.swift
rm Sources/Gaesteglueck/Services/OnboardingEngine.swift
```

- [ ] **Step 4: Delete old view files**

```bash
rm Sources/Gaesteglueck/Views/RelationshipFormView.swift
rm Sources/Gaesteglueck/Views/RelationshipListView.swift
rm Sources/Gaesteglueck/Views/RelationshipRowView.swift
rm Sources/Gaesteglueck/Views/Onboarding/OnboardingWizardView.swift
rm Sources/Gaesteglueck/Views/AISuggestionView.swift
rm Sources/Gaesteglueck/Views/AutoAssignButton.swift
```

- [ ] **Step 5: Delete old test files**

```bash
rm Tests/GaesteglueckTests/Models/RelationshipTests.swift
rm Tests/GaesteglueckTests/Services/OnboardingEngineTests.swift
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: remove old model files and set macOS-only platform"
```

---

### Task 2: New Core Enums

**Files:**
- Create: `Sources/Gaesteglueck/Models/PartnerAssignment.swift`
- Create: `Sources/Gaesteglueck/Models/AgeCategory.swift`
- Create: `Sources/Gaesteglueck/Models/TagCategory.swift`
- Create: `Sources/Gaesteglueck/Models/ConstraintType.swift`
- Create: `Sources/Gaesteglueck/Models/CombinationRole.swift`
- Modify: `Sources/Gaesteglueck/Models/TableShape.swift`
- Modify: `Sources/Gaesteglueck/Models/FamilyRole.swift`

- [ ] **Step 1: Create PartnerAssignment.swift**

```swift
import Foundation

enum PartnerAssignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case partner1 = "Partner 1"
    case partner2 = "Partner 2"
    case both = "Beide"
    var id: String { rawValue }
}
```

- [ ] **Step 2: Create AgeCategory.swift**

```swift
import Foundation

enum AgeCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case adult = "Erwachsener"
    case child = "Kind"
    case toddler = "Kleinkind"
    case baby = "Baby"
    var id: String { rawValue }

    var needsSeat: Bool {
        switch self {
        case .adult, .child, .toddler: true
        case .baby: false
        }
    }
}
```

- [ ] **Step 3: Create TagCategory.swift**

```swift
import Foundation

enum TagCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case family = "Familie"
    case friendGroup = "Freundesgruppe"
    case role = "Hochzeitsrolle"
    case activity = "Aktivität"
    case work = "Arbeitskontext"
    case custom = "Eigene"
    var id: String { rawValue }

    var defaultColor: String {
        switch self {
        case .family: "#E74C3C"
        case .friendGroup: "#2ECC71"
        case .role: "#F1C40F"
        case .activity: "#9B59B6"
        case .work: "#3498DB"
        case .custom: "#95A5A6"
        }
    }
}
```

- [ ] **Step 4: Create ConstraintType.swift**

```swift
import Foundation

enum ConstraintType: String, Codable, CaseIterable, Identifiable, Sendable {
    case mustSitTogether = "Muss zusammen sitzen"
    case mustNotSitTogether = "Darf nicht zusammen sitzen"
    var id: String { rawValue }
}
```

- [ ] **Step 5: Create CombinationRole.swift**

```swift
import Foundation

enum CombinationRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case head = "Kopf"
    case middle = "Mitte"
    case end = "Ende"
    case corner = "Ecke"
    var id: String { rawValue }
}
```

- [ ] **Step 6: Update TableShape.swift**

Replace the entire file:

```swift
import Foundation

enum TableShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case round = "Rund"
    case rectangular = "Rechteckig"
    case square = "Quadratisch"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .round: "circle"
        case .rectangular: "rectangle"
        case .square: "square"
        }
    }
}
```

- [ ] **Step 7: Update FamilyRole.swift**

Split cousin into cousin/cousine, remove friend/witness/partner (those are tags now):

```swift
import Foundation

enum FamilyRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case mother = "Mutter"
    case father = "Vater"
    case sister = "Schwester"
    case brother = "Bruder"
    case grandmother = "Oma"
    case grandfather = "Opa"
    case sisterInLaw = "Schwägerin"
    case brotherInLaw = "Schwager"
    case motherInLaw = "Schwiegermutter"
    case fatherInLaw = "Schwiegervater"
    case aunt = "Tante"
    case uncle = "Onkel"
    case cousin = "Cousin"
    case cousine = "Cousine"
    case niece = "Nichte"
    case nephew = "Neffe"
    case child = "Kind"
    case other = "Sonstige"
    var id: String { rawValue }
}
```

- [ ] **Step 8: Verify enums compile**

```bash
cd /Users/gereon/Code/worktrees/famous-planes-slide-8x7
swift build 2>&1 | head -20
```

Expected: Compilation errors from files referencing deleted types (`Side`, `Relationship`, `GroupType`, etc.). This is expected — we fix those in the next tasks.

- [ ] **Step 9: Commit**

```bash
git add Sources/Gaesteglueck/Models/PartnerAssignment.swift \
       Sources/Gaesteglueck/Models/AgeCategory.swift \
       Sources/Gaesteglueck/Models/TagCategory.swift \
       Sources/Gaesteglueck/Models/ConstraintType.swift \
       Sources/Gaesteglueck/Models/CombinationRole.swift \
       Sources/Gaesteglueck/Models/TableShape.swift \
       Sources/Gaesteglueck/Models/FamilyRole.swift
git commit -m "feat: add new core enums for v2 data model"
```

---

### Task 3: Update Event Model

**Files:**
- Modify: `Sources/Gaesteglueck/Models/Event.swift`

- [ ] **Step 1: Rewrite Event.swift**

```swift
import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Event {
    var id: UUID
    var name: String
    var date: Date?
    var venue: String
    var partner1Name: String
    var partner2Name: String
    var partner1PreMarriageName: String
    var partner2PreMarriageName: String
    var menuOptions: [String]
    var roomWidthCM: Double?
    var roomLengthCM: Double?
    var roomPlanImageData: Data?
    var createdAt: Date

    init(
        name: String,
        date: Date? = nil,
        venue: String = "",
        partner1Name: String = "",
        partner2Name: String = "",
        partner1PreMarriageName: String = "",
        partner2PreMarriageName: String = "",
        menuOptions: [String] = ["Fleisch", "Vegetarisch", "Vegan"]
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.venue = venue
        self.partner1Name = partner1Name
        self.partner2Name = partner2Name
        self.partner1PreMarriageName = partner1PreMarriageName
        self.partner2PreMarriageName = partner2PreMarriageName
        self.menuOptions = menuOptions
        self.roomWidthCM = nil
        self.roomLengthCM = nil
        self.roomPlanImageData = nil
        self.createdAt = .now
    }

    var partnerDisplayName1: String {
        partner1Name.isEmpty ? "Partner 1" : partner1Name
    }

    var partnerDisplayName2: String {
        partner2Name.isEmpty ? "Partner 2" : partner2Name
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Gaesteglueck/Models/Event.swift
git commit -m "feat: update Event model with partner names, menu, room dimensions"
```

---

### Task 4: Update Guest Model

**Files:**
- Modify: `Sources/Gaesteglueck/Models/Guest.swift`

- [ ] **Step 1: Rewrite Guest.swift**

```swift
import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

enum RSVPStatus: String, Codable, CaseIterable, Sendable {
    case pending = "Ausstehend"
    case confirmed = "Zugesagt"
    case declined = "Abgesagt"
}

#if canImport(SwiftData)
@Model
#endif
final class Guest {
    var id: UUID
    var firstName: String
    var lastName: String
    var partnerAssignment: PartnerAssignment
    var ageCategory: AgeCategory
    var age: Int?
    var familyID: UUID?
    var familyRole: FamilyRole?
    var familyRolePartner: PartnerAssignment?
    var dietaryChoice: String
    var intolerances: [String]
    var funFact: String
    var notes: String
    var employer: String
    var profession: String
    var hobbies: [String]
    var languages: [String]
    var registrationGroup: UUID?
    var rsvpStatus: RSVPStatus
    var isPinned: Bool
    var table: GuestTable?

    init(
        firstName: String,
        lastName: String = "",
        partnerAssignment: PartnerAssignment = .both,
        ageCategory: AgeCategory = .adult,
        age: Int? = nil,
        familyID: UUID? = nil,
        familyRole: FamilyRole? = nil,
        familyRolePartner: PartnerAssignment? = nil,
        dietaryChoice: String = "Fleisch",
        intolerances: [String] = [],
        funFact: String = "",
        notes: String = "",
        rsvpStatus: RSVPStatus = .confirmed,
        registrationGroup: UUID? = nil
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.partnerAssignment = partnerAssignment
        self.ageCategory = ageCategory
        self.age = age
        self.familyID = familyID
        self.familyRole = familyRole
        self.familyRolePartner = familyRolePartner
        self.dietaryChoice = dietaryChoice
        self.intolerances = intolerances
        self.funFact = funFact
        self.notes = notes
        self.employer = ""
        self.profession = ""
        self.hobbies = []
        self.languages = []
        self.registrationGroup = registrationGroup
        self.rsvpStatus = rsvpStatus
        self.isPinned = false
    }

    var fullName: String {
        lastName.isEmpty ? firstName : "\(firstName) \(lastName)"
    }

    var hasIntolerances: Bool {
        !intolerances.isEmpty
    }

    var dietarySummary: String {
        var parts: [String] = []
        if dietaryChoice != "Fleisch" {
            parts.append(dietaryChoice)
        }
        if hasIntolerances {
            parts.append("⚠️ \(intolerances.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    var needsSeat: Bool {
        ageCategory.needsSeat
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Gaesteglueck/Models/Guest.swift
git commit -m "feat: rewrite Guest model with multi-field enrichment support"
```

---

### Task 5: Tag & Constraint Models

**Files:**
- Create: `Sources/Gaesteglueck/Models/Tag.swift`
- Create: `Sources/Gaesteglueck/Models/Constraint.swift`
- Test: `Tests/GaesteglueckTests/Models/TagTests.swift`
- Test: `Tests/GaesteglueckTests/Models/ConstraintTests.swift`

- [ ] **Step 1: Write Tag tests**

```swift
import Testing
@testable import Gaesteglueck

@Suite("Tag Model")
struct TagTests {
    @Test("Tag creation with defaults")
    func tagCreation() {
        let tag = Tag(name: "Studienfreunde Alice", category: .friendGroup)
        #expect(tag.name == "Studienfreunde Alice")
        #expect(tag.category == .friendGroup)
        #expect(tag.color == TagCategory.friendGroup.defaultColor)
        #expect(tag.guestIDs.isEmpty)
    }

    @Test("Tag with custom color and partner")
    func tagWithCustomColor() {
        let tag = Tag(
            name: "JGA Bob",
            category: .activity,
            color: "#FF5733",
            partnerAssignment: .partner1
        )
        #expect(tag.color == "#FF5733")
        #expect(tag.partnerAssignment == .partner1)
    }

    @Test("Add and remove guest IDs")
    func guestManagement() {
        let tag = Tag(name: "Test", category: .custom)
        let guestID = UUID()
        tag.guestIDs.append(guestID)
        #expect(tag.guestIDs.count == 1)
        #expect(tag.guestIDs.contains(guestID))
    }
}
```

- [ ] **Step 2: Write Constraint tests**

```swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Constraint Model")
struct ConstraintTests {
    @Test("Must sit together constraint")
    func mustSitTogether() {
        let idA = UUID()
        let idB = UUID()
        let constraint = Constraint(
            type: .mustSitTogether,
            guestIDs: [idA, idB],
            reason: "Ehepaar"
        )
        #expect(constraint.type == .mustSitTogether)
        #expect(constraint.guestIDs.count == 2)
        #expect(constraint.involves(idA))
        #expect(constraint.involves(idB))
        #expect(!constraint.involves(UUID()))
    }

    @Test("Must not sit together constraint")
    func mustNotSitTogether() {
        let constraint = Constraint(
            type: .mustNotSitTogether,
            guestIDs: [UUID(), UUID()],
            reason: "Konflikt"
        )
        #expect(constraint.type == .mustNotSitTogether)
        #expect(constraint.reason == "Konflikt")
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
swift test --filter "TagTests|ConstraintTests" 2>&1 | tail -10
```

Expected: FAIL — `Tag` and `Constraint` types don't exist yet.

- [ ] **Step 4: Create Tag.swift**

```swift
import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Tag {
    var id: UUID
    var name: String
    var category: TagCategory
    var color: String
    var partnerAssignment: PartnerAssignment?
    var guestIDs: [UUID]

    init(
        name: String,
        category: TagCategory,
        color: String? = nil,
        partnerAssignment: PartnerAssignment? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.color = color ?? category.defaultColor
        self.partnerAssignment = partnerAssignment
        self.guestIDs = []
    }

    func involves(_ guestID: UUID) -> Bool {
        guestIDs.contains(guestID)
    }

    var guestCount: Int { guestIDs.count }
}
```

- [ ] **Step 5: Create Constraint.swift**

```swift
import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Constraint {
    var id: UUID
    var type: ConstraintType
    var guestIDs: [UUID]
    var reason: String

    init(type: ConstraintType, guestIDs: [UUID], reason: String = "") {
        self.id = UUID()
        self.type = type
        self.guestIDs = guestIDs
        self.reason = reason
    }

    func involves(_ guestID: UUID) -> Bool {
        guestIDs.contains(guestID)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
swift test --filter "TagTests|ConstraintTests" 2>&1 | tail -10
```

Expected: PASS (may still fail due to other files with compile errors referencing deleted types — that's fine, we fix those later)

- [ ] **Step 7: Commit**

```bash
git add Sources/Gaesteglueck/Models/Tag.swift \
       Sources/Gaesteglueck/Models/Constraint.swift \
       Tests/GaesteglueckTests/Models/TagTests.swift \
       Tests/GaesteglueckTests/Models/ConstraintTests.swift
git commit -m "feat: add Tag and Constraint models with tests"
```

---

### Task 6: Update GuestTable & Add TableInventoryItem

**Files:**
- Modify: `Sources/Gaesteglueck/Models/GuestTable.swift`
- Create: `Sources/Gaesteglueck/Models/TableInventoryItem.swift`

- [ ] **Step 1: Rewrite GuestTable.swift**

```swift
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
    var guests: [Guest]

    var capacity: Int {
        let seatWidth: Double = 60
        switch shape {
        case .round:
            let circumference = Double.pi * diameter
            return Int(circumference / seatWidth)
        case .rectangular:
            let perimeter = 2 * (width + depth)
            let rawSeats = Int(perimeter / seatWidth)
            return max(rawSeats - 2, 4)
        case .square:
            let perimeter = 4 * width
            return Int(perimeter / seatWidth)
        }
    }

    var remainingSeats: Int { capacity - guests.count }
    var isFull: Bool { guests.count >= capacity }

    init(
        name: String,
        shape: TableShape,
        diameter: Double = 180,
        width: Double = 200,
        depth: Double = 100,
        positionX: Double = 0,
        positionY: Double = 0,
        rotation: Double = 0,
        isChildTable: Bool = false
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
        self.combinationGroup = nil
        self.combinationRole = nil
        self.guests = []
    }
}
```

- [ ] **Step 2: Create TableInventoryItem.swift**

```swift
import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class TableInventoryItem {
    var id: UUID
    var shape: TableShape
    var width: Double
    var depth: Double
    var diameter: Double
    var availableCount: Int
    var label: String

    init(
        shape: TableShape,
        width: Double = 200,
        depth: Double = 100,
        diameter: Double = 180,
        availableCount: Int = 1,
        label: String = ""
    ) {
        self.id = UUID()
        self.shape = shape
        self.width = width
        self.depth = depth
        self.diameter = diameter
        self.availableCount = availableCount
        self.label = label.isEmpty ? "\(shape.rawValue) \(Int(shape == .round ? diameter : width))cm" : label
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/Gaesteglueck/Models/GuestTable.swift \
       Sources/Gaesteglueck/Models/TableInventoryItem.swift
git commit -m "feat: update GuestTable with combinations, add TableInventoryItem"
```

---

### Task 7: Fix Compilation — Update All References to Deleted Types

This task updates every file that references `Side`, `Relationship`, `RelationshipType`, or `GroupType` to use the new types. Also updates the SwiftData container and removes `#if canImport(UIKit)` guards for iOS-only code.

**Files:**
- Modify: `Sources/Gaesteglueck/GaesteglueckApp.swift`
- Modify: `Sources/Gaesteglueck/ContentView.swift`
- Modify: `Sources/Gaesteglueck/Views/AppSidebar.swift`
- Modify: `Sources/Gaesteglueck/Services/CSVParser.swift`
- Modify: `Sources/Gaesteglueck/Services/ExcelParser.swift`
- Modify: `Sources/Gaesteglueck/Services/GuestImporter.swift`
- Modify: `Sources/Gaesteglueck/Services/SeatingGraph.swift`
- Modify: `Sources/Gaesteglueck/Services/HappinessScorer.swift`
- Modify: `Sources/Gaesteglueck/Services/SeatingOptimizer.swift`
- Modify: `Sources/Gaesteglueck/Services/FamilyGrouper.swift`
- Modify: `Sources/Gaesteglueck/Services/PDFExporter.swift`
- Modify: Multiple view files
- Modify: Multiple test files

This is a large task focused on making the project compile again. Work through compile errors file by file.

- [ ] **Step 1: Update GaesteglueckApp.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

@main
struct GaesteglueckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Event.self,
            Guest.self,
            GuestTable.self,
            Tag.self,
            Constraint.self,
            RoomPlan.self,
            TableInventoryItem.self,
        ])
    }
}
#endif
```

- [ ] **Step 2: Update AppSidebar.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case guests = "Gäste"
    case tables = "Tische & Raum"
    case tags = "Gruppen & Tags"
    case assistant = "KI-Assistent"
    case settings = "Einstellungen"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "house"
        case .guests: "person.3"
        case .tables: "tablecells"
        case .tags: "tag"
        case .assistant: "sparkles"
        case .settings: "gear"
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
#endif
```

- [ ] **Step 3: Update ContentView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI

struct ContentView: View {
    @State private var selectedSection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .dashboard:
                Text("Dashboard — kommt in Task 12")
            case .guests:
                Text("Gäste — kommt in Task 13")
            case .tables:
                Text("Tische — kommt in Task 14")
            case .tags:
                Text("Tags — kommt in Task 13")
            case .assistant:
                Text("KI-Assistent — kommt in Task 15")
            case .settings:
                Text("Einstellungen — kommt in Task 12")
            case nil:
                ContentUnavailableView(
                    "Bereich wählen",
                    systemImage: "sidebar.left",
                    description: Text("Wähle einen Bereich aus der Seitenleiste.")
                )
            }
        }
    }
}
#endif
```

- [ ] **Step 4: Update GuestImporter.swift**

```swift
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

struct ImportedFamily: Sendable {
    let sharedFamilyID: UUID?
    var members: [ImportedGuest]
}

struct ImportedGuest: Sendable {
    let firstName: String
    let lastName: String
    let dietaryChoice: String
    let intolerances: [String]
    let ageCategory: AgeCategory
    let funFact: String
    let notes: String
}
```

- [ ] **Step 5: Update CSVParser.swift for new ImportedGuest**

The CSVParser needs a significant rewrite to handle the wedding form format (Familienname, Anzahl, Freitext guests column). However, the primary parsing of the unstructured guest text will be done by the LLM (Task 9). The CSVParser's job becomes: parse the CSV structure, extract columns, and pass the guest-detail freetext to the LLM parser.

```swift
import Foundation

enum CSVParser {
    /// Parse the wedding registration form CSV into raw registration rows.
    /// Each row represents one family/group registration.
    static func parseRegistrations(_ content: String) throws -> [RegistrationRow] {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else { throw ImportError.emptyFile }

        let delimiter: Character = headerLine.contains("\t") ? "\t" :
                                   headerLine.contains(";") ? ";" : ","
        let headers = headerLine.split(separator: delimiter, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        // Find columns by fuzzy matching
        let familyIdx = headers.firstIndex { $0.contains("familie") || $0.contains("name") }
        let attendIdx = headers.firstIndex { $0.contains("teilnehm") || $0.contains("attend") }
        let countIdx = headers.firstIndex { $0.contains("anzahl") || $0.contains("gesamt") || $0.contains("count") }
        let guestsIdx = headers.firstIndex { $0.contains("gast") || $0.contains("gib") || $0.contains("jeden") }
        let funFactIdx = headers.firstIndex { $0.contains("fun") || $0.contains("fact") }
        let notesIdx = headers.lastIndex { $0.contains("anmerkung") || $0.contains("wünsch") || $0.contains("notes") }

        var rows: [RegistrationRow] = []

        for line in lines.dropFirst() {
            let fields = line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Skip non-attending
            if let aIdx = attendIdx, fields.indices.contains(aIdx) {
                let attendance = fields[aIdx].lowercased()
                if attendance.contains("nein") || attendance.contains("no") || attendance.contains("nicht") {
                    continue
                }
            }

            let familyName = familyIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            guard !familyName.isEmpty else { continue }

            let guestCount = countIdx.flatMap { fields.indices.contains($0) ? Int(Double(fields[$0]) ?? 0) : nil } ?? 1
            let guestDetails = guestsIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            let funFacts = funFactIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            let notes = notesIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""

            rows.append(RegistrationRow(
                familyName: familyName,
                guestCount: guestCount,
                guestDetails: guestDetails,
                funFacts: funFacts,
                notes: notes
            ))
        }

        return rows
    }
}

struct RegistrationRow: Sendable {
    let familyName: String
    let guestCount: Int
    let guestDetails: String
    let funFacts: String
    let notes: String
}
```

- [ ] **Step 6: Stub remaining services to compile**

Update `SeatingGraph.swift` — change `Relationship` references to `Constraint` + `Tag`:

```swift
import Foundation

struct SeatingGraph: Sendable {
    struct Edge: Sendable {
        let from: UUID
        let to: UUID
        let weight: Double
        let isHardConstraint: Bool
    }

    let nodes: [UUID]
    let edges: [Edge]

    init(guests: [Guest], tags: [Tag], constraints: [Constraint]) {
        self.nodes = guests.map(\.id)
        var edges: [Edge] = []

        // 1. Hard constraints
        for constraint in constraints {
            let ids = constraint.guestIDs
            for i in ids.indices {
                for j in (i+1)..<ids.count {
                    let weight: Double = constraint.type == .mustSitTogether ? 100 : -500
                    edges.append(Edge(
                        from: ids[i], to: ids[j],
                        weight: weight,
                        isHardConstraint: true
                    ))
                }
            }
        }

        // 2. Tag-based cohesion
        for tag in tags {
            let ids = tag.guestIDs
            let weight: Double = tag.category == .family ? 70 : 40
            for i in ids.indices {
                for j in (i+1)..<ids.count {
                    let alreadyExists = edges.contains {
                        ($0.from == ids[i] && $0.to == ids[j]) ||
                        ($0.from == ids[j] && $0.to == ids[i])
                    }
                    if !alreadyExists {
                        edges.append(Edge(
                            from: ids[i], to: ids[j],
                            weight: weight,
                            isHardConstraint: false
                        ))
                    }
                }
            }
        }

        // 3. Family bonds (children with parents)
        let families = Dictionary(grouping: guests.filter { $0.familyID != nil }, by: { $0.familyID! })
        for (_, members) in families {
            for i in members.indices {
                for j in (i+1)..<members.count {
                    let alreadyExists = edges.contains {
                        ($0.from == members[i].id && $0.to == members[j].id) ||
                        ($0.from == members[j].id && $0.to == members[i].id)
                    }
                    if !alreadyExists {
                        let isChildPair = members[i].ageCategory != .adult || members[j].ageCategory != .adult
                        edges.append(Edge(
                            from: members[i].id, to: members[j].id,
                            weight: isChildPair ? 100 : 70,
                            isHardConstraint: isChildPair
                        ))
                    }
                }
            }
        }

        self.edges = edges
    }

    func edges(for nodeID: UUID) -> [Edge] {
        edges.filter { $0.from == nodeID || $0.to == nodeID }
    }

    func weight(between a: UUID, and b: UUID) -> Double {
        edges.first { ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a) }?.weight ?? 0
    }
}
```

- [ ] **Step 7: Update HappinessScorer.swift**

```swift
import Foundation

enum HappinessScorer {
    static func scoreTable(_ table: GuestTable, tags: [Tag], constraints: [Constraint]) -> Double {
        let guestIDs = Set(table.guests.map(\.id))
        guard !guestIDs.isEmpty else { return 0 }

        var score: Double = 0

        // Tag cohesion: guests from same tag at same table = bonus
        for tag in tags {
            let tagGuestsAtTable = tag.guestIDs.filter { guestIDs.contains($0) }
            if tagGuestsAtTable.count >= 2 {
                let weight: Double = tag.category == .family ? 70 : 40
                score += Double(tagGuestsAtTable.count) * weight
            }
        }

        // Mixed partner assignment bonus
        let assignments = Set(table.guests.map(\.partnerAssignment))
        if assignments.count > 1 {
            score += 10
        }

        return score
    }

    static func scoreAllTables(_ tables: [GuestTable], tags: [Tag], constraints: [Constraint]) -> Double {
        tables.reduce(0) { $0 + scoreTable($1, tags: tags, constraints: constraints) }
    }

    static func findViolations(tables: [GuestTable], constraints: [Constraint]) -> [Violation] {
        var violations: [Violation] = []

        var guestToTable: [UUID: UUID] = [:]
        for table in tables {
            for guest in table.guests {
                guestToTable[guest.id] = table.id
            }
        }

        for constraint in constraints {
            let ids = constraint.guestIDs
            guard ids.count >= 2 else { continue }

            let tables = ids.compactMap { guestToTable[$0] }
            let uniqueTables = Set(tables)

            switch constraint.type {
            case .mustSitTogether:
                if uniqueTables.count > 1 {
                    violations.append(Violation(
                        type: .constraintViolated,
                        guestIDs: ids,
                        description: "Müssen zusammen sitzen: \(constraint.reason)"
                    ))
                }
            case .mustNotSitTogether:
                if uniqueTables.count == 1 && !tables.isEmpty {
                    violations.append(Violation(
                        type: .constraintViolated,
                        guestIDs: ids,
                        description: "Dürfen nicht zusammen sitzen: \(constraint.reason)"
                    ))
                }
            }
        }

        return violations
    }
}

struct Violation: Identifiable, Equatable {
    let id = UUID()
    let type: ViolationType
    let guestIDs: [UUID]
    let description: String

    static func == (lhs: Violation, rhs: Violation) -> Bool {
        lhs.type == rhs.type && lhs.guestIDs == rhs.guestIDs
    }
}

enum ViolationType: Equatable {
    case constraintViolated
    case tableOverCapacity
}
```

- [ ] **Step 8: Update SeatingOptimizer.swift**

Change the `solve` signature to accept tags and constraints:

```swift
import Foundation

enum SeatingOptimizer {
    static func solve(
        guests: [Guest],
        tables: [GuestTable],
        tags: [Tag],
        constraints: [Constraint],
        iterations: Int = 5000
    ) -> [UUID: UUID] {
        guard !guests.isEmpty, !tables.isEmpty else { return [:] }

        let graph = SeatingGraph(guests: guests, tags: tags, constraints: constraints)
        let tableIDs = tables.map(\.id)
        let tableCapacities = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0.capacity) })

        var assignment: [UUID: UUID] = [:]

        // Pinned guests
        let pinnedGuests = guests.filter { $0.isPinned && $0.table != nil }
        for guest in pinnedGuests {
            assignment[guest.id] = guest.table!.id
        }

        // Hard clusters
        let hardClusters = buildHardClusters(guests: guests, graph: graph)

        for cluster in hardClusters {
            if cluster.allSatisfy({ assignment[$0] != nil }) { continue }

            let bestTable = tableIDs.max { a, b in
                affinityScore(cluster: cluster, table: a, assignment: assignment, graph: graph) <
                affinityScore(cluster: cluster, table: b, assignment: assignment, graph: graph)
            } ?? tableIDs[0]

            let currentCount = assignment.values.filter { $0 == bestTable }.count
            let clusterSize = cluster.filter { assignment[$0] == nil }.count
            if currentCount + clusterSize <= (tableCapacities[bestTable] ?? 0) {
                for guestID in cluster where assignment[guestID] == nil {
                    assignment[guestID] = bestTable
                }
            } else {
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

        // Unassigned
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

        // Simulated annealing
        let pinnedIDs = Set(pinnedGuests.map(\.id))
        var bestAssignment = assignment
        var bestScore = totalScore(assignment: assignment, graph: graph)
        var temperature = 1.0

        for _ in 0..<iterations {
            var candidate = bestAssignment
            let movableGuests = guests.filter { !pinnedIDs.contains($0.id) }
            guard let guest = movableGuests.randomElement(),
                  let currentTable = candidate[guest.id] else { continue }

            let otherTables = tableIDs.filter { $0 != currentTable }
            guard let newTable = otherTables.randomElement() else { continue }

            let newTableCount = candidate.values.filter { $0 == newTable }.count
            guard newTableCount < (tableCapacities[newTable] ?? 0) else { continue }

            let hardEdges = graph.edges(for: guest.id).filter(\.isHardConstraint)
            let wouldViolate = hardEdges.contains { edge in
                let otherID = edge.from == guest.id ? edge.to : edge.from
                guard let otherTable = candidate[otherID] else { return false }
                return edge.weight > 0 ? otherTable != newTable : otherTable == newTable
            }
            guard !wouldViolate else { continue }

            candidate[guest.id] = newTable
            let candidateScore = totalScore(assignment: candidate, graph: graph)
            let delta = candidateScore - bestScore
            if delta > 0 || Double.random(in: 0...1) < exp(delta / temperature) {
                bestAssignment = candidate
                bestScore = candidateScore
            }
            temperature *= 0.999
        }

        return bestAssignment
    }

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

        return clusters.sorted { $0.count > $1.count }
    }

    private static func affinityScore(cluster: [UUID], table: UUID, assignment: [UUID: UUID], graph: SeatingGraph) -> Double {
        let tableGuests = assignment.filter { $0.value == table }.map(\.key)
        var score: Double = 0
        for guestID in cluster {
            for tableGuestID in tableGuests {
                score += graph.weight(between: guestID, and: tableGuestID)
            }
        }
        return score
    }

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

- [ ] **Step 9: Update FamilyGrouper.swift**

```swift
import Foundation

enum FamilyGrouper {
    static func group(_ guests: [Guest]) -> [[Guest]] {
        let withFamily = guests.filter { $0.familyID != nil }
        let grouped = Dictionary(grouping: withFamily, by: { $0.familyID! })
        let solos = guests.filter { $0.familyID == nil }.map { [$0] }
        return Array(grouped.values) + solos
    }
}
```

- [ ] **Step 10: Update PDFExporter.swift for macOS**

```swift
#if canImport(AppKit)
import Foundation
import AppKit
import PDFKit

enum PDFExporter {
    static func generatePDF(
        tables: [GuestTable],
        eventName: String,
        date: Date?
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        func beginPage() {
            var mediaBox = pageRect
            context.beginPage(mediaBox: &mediaBox)
            // Flip coordinate system (CGContext is bottom-up, we want top-down)
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)
        }

        func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = .black) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let nsString = text as NSString
            nsString.draw(at: point, withAttributes: attributes)
        }

        beginPage()
        var y: CGFloat = 40

        // Title
        drawText("Sitzplan: \(eventName)", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 24))
        y += 35

        // Date
        if let date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.locale = Locale(identifier: "de_DE")
            drawText(formatter.string(from: date), at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
            y += 25
        }
        y += 15

        // Tables
        for table in tables.sorted(by: { $0.name < $1.name }) {
            if y > pageRect.height - 100 {
                context.endPage()
                beginPage()
                y = 40
            }

            let header = "\(table.name) (\(table.shape.rawValue), \(table.guests.count)/\(table.capacity) Plätze)"
            drawText(header, at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
            y += 22

            if table.guests.isEmpty {
                drawText("Keine Gäste zugewiesen", at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12))
                y += 18
            } else {
                for guest in table.guests.sorted(by: { $0.fullName < $1.fullName }) {
                    var line = "• \(guest.fullName)"
                    if guest.dietaryChoice != "Fleisch" {
                        line += " \(guest.dietaryChoice)"
                    }
                    if guest.hasIntolerances {
                        line += " ⚠️ \(guest.intolerances.joined(separator: ", "))"
                    }
                    if guest.ageCategory != .adult {
                        line += " [\(guest.ageCategory.rawValue)]"
                    }
                    drawText(line, at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12))
                    y += 18
                }
            }
            y += 10
        }

        // Summary page
        context.endPage()
        beginPage()
        y = 40

        drawText("Übersicht für den Caterer", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 24))
        y += 35

        let allGuests = tables.flatMap(\.guests)
        let dietaryCounts = Dictionary(grouping: allGuests, by: \.dietaryChoice).mapValues(\.count)

        for (choice, count) in dietaryCounts.sorted(by: { $0.key < $1.key }) {
            drawText("\(choice): \(count)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12))
            y += 20
        }

        let childCount = allGuests.filter { $0.ageCategory != .adult }.count
        drawText("Kinder: \(childCount)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12))
        y += 30

        let guestsWithIntolerances = allGuests.filter(\.hasIntolerances)
        if !guestsWithIntolerances.isEmpty {
            drawText("Unverträglichkeiten:", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
            y += 22
            for guest in guestsWithIntolerances.sorted(by: { $0.fullName < $1.fullName }) {
                drawText("  \(guest.fullName): \(guest.intolerances.joined(separator: ", "))", at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12))
                y += 18
            }
        }

        context.endPage()
        context.closePDF()

        return pdfData as Data
    }
}
#endif
```

- [ ] **Step 11: Stub all view files that reference deleted types**

For each view file that references `Side`, `Relationship`, `GroupType`, etc., add a minimal stub that compiles. The full view rewrites happen in Phase 3. The key approach:

- `GuestListView.swift`: Replace `.side` references with `.partnerAssignment`, `.name` with `.fullName`
- `GuestFormView.swift`: Replace Side picker with PartnerAssignment picker, remove relationship fields
- `GuestRowView.swift`: Replace `.side` with `.partnerAssignment`, `.name` with `.fullName`
- `ImportButton.swift`: Keep the file picker, adapt to new import types
- `ImportPreviewView.swift`: Adapt to new `ImportedGuest` fields
- `RoomCanvasView.swift`: Replace `relationships` queries with `tags` + `constraints`
- `StatisticsView.swift`: Replace `Side` references
- `SettingsView.swift`: Adapt to new settings structure
- `TableListView.swift`: Keep mostly as-is
- `ModelExtensions+UI.swift`: Replace all old type extensions
- `Canvas/ViolationBannerView.swift`: Update Violation type references
- `Canvas/ScoreBadgeView.swift`: Keep as-is
- `ExportButton.swift`: Keep structure, update import

Work through the compiler errors — each file will need targeted edits to replace references to `Side` → `PartnerAssignment`, `Relationship` → `Constraint`/`Tag`, `.name` → `.fullName`, `dietaryPreference` → `dietaryChoice`, `allergies: String` → `intolerances: [String]`, `isChild: Bool` → `ageCategory: AgeCategory`.

Also remove `#if canImport(UIKit)` guards and replace with `#if canImport(AppKit)` where needed. Most SwiftUI code needs no platform guards.

- [ ] **Step 12: Update test files**

Update existing tests (`GuestTests`, `GuestTableTests`, `GuestTransferTests`, `HappinessScorerTests`, `SeatingOptimizerTests`, `FamilyGrouperTests`, `GuestImporterTests`, `PDFExporterTests`, `TablePlacerTests`) to use new types.

Key changes in all test files:
- `Guest(name:, side:)` → `Guest(firstName:, partnerAssignment:)`
- `.bride` → `.partner1`, `.groom` → `.partner2`
- `Relationship(personAID:, personBID:, type:)` → `Constraint(type:, guestIDs:)`
- `.partner` → `.mustSitTogether`, `.toxic` → `.mustNotSitTogether`
- `dietaryPreference:` → `dietaryChoice:`
- `isChild: true` → `ageCategory: .child`
- `allergies: "X"` → `intolerances: ["X"]`
- `scoreTable(table, relationships:)` → `scoreTable(table, tags:, constraints:)`
- `solve(guests:, tables:, relationships:)` → `solve(guests:, tables:, tags:, constraints:)`

- [ ] **Step 13: Build and fix remaining errors**

```bash
swift build 2>&1 | grep "error:" | head -30
```

Fix all remaining compile errors iteratively until:

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 14: Run all tests**

```bash
swift test 2>&1 | tail -20
```

Expected: All tests pass (some may need adjustment for new model fields)

- [ ] **Step 15: Commit**

```bash
git add -A
git commit -m "feat: migrate all code to v2 data model (tags, constraints, macOS)"
```

---

## Phase 2: Services (LM Studio, Import, Analysis)

### Task 8: LM Studio Client

**Files:**
- Create: `Sources/Gaesteglueck/Services/LMStudioClient.swift`
- Test: `Tests/GaesteglueckTests/Services/LMStudioClientTests.swift`

- [ ] **Step 1: Write LMStudioClient tests**

```swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("LMStudioClient")
struct LMStudioClientTests {
    @Test("Default endpoint is localhost:1234")
    func defaultEndpoint() async {
        let client = LMStudioClient()
        let endpoint = await client.endpoint
        #expect(endpoint == "http://localhost:1234")
    }

    @Test("Custom endpoint")
    func customEndpoint() async {
        let client = LMStudioClient(endpoint: "http://macmini.local:1234")
        let endpoint = await client.endpoint
        #expect(endpoint == "http://macmini.local:1234")
    }

    @Test("Request body encoding")
    func requestEncoding() throws {
        let request = LMStudioClient.ChatRequest(
            model: "gemma-4-12b",
            messages: [
                LMStudioClient.Message(role: "system", content: "Du bist ein Assistent."),
                LMStudioClient.Message(role: "user", content: "Hallo")
            ],
            temperature: 0.3,
            max_tokens: 4096
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode(LMStudioClient.ChatRequest.self, from: data)
        #expect(json.model == "gemma-4-12b")
        #expect(json.messages.count == 2)
        #expect(json.temperature == 0.3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter "LMStudioClientTests" 2>&1 | tail -10
```

Expected: FAIL — `LMStudioClient` doesn't exist.

- [ ] **Step 3: Implement LMStudioClient.swift**

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor LMStudioClient {
    let endpoint: String
    private var modelOverride: String?

    init(endpoint: String = "http://localhost:1234", model: String? = nil) {
        self.endpoint = endpoint
        self.modelOverride = model
    }

    struct Message: Codable, Sendable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable, Sendable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    struct ChatResponse: Codable, Sendable {
        struct Choice: Codable, Sendable {
            struct Message: Codable, Sendable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
        let model: String?
    }

    struct ModelList: Codable, Sendable {
        struct Model: Codable, Sendable {
            let id: String
        }
        let data: [Model]
    }

    enum LMStudioError: Error, LocalizedError {
        case connectionFailed
        case noModelsLoaded
        case emptyResponse
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed: "Keine Verbindung zu LM Studio. Ist es gestartet?"
            case .noModelsLoaded: "Kein Modell in LM Studio geladen."
            case .emptyResponse: "Leere Antwort vom Modell."
            case .invalidJSON(let detail): "Ungültige JSON-Antwort: \(detail)"
            }
        }
    }

    /// Check if LM Studio is reachable and has a model loaded.
    func checkConnection() async throws -> String {
        let url = URL(string: "\(endpoint)/v1/models")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let models = try JSONDecoder().decode(ModelList.self, from: data)
        guard let first = models.data.first else {
            throw LMStudioError.noModelsLoaded
        }
        return first.id
    }

    /// Send a chat completion request.
    func chat(
        messages: [Message],
        temperature: Double = 0.3,
        maxTokens: Int = 4096
    ) async throws -> String {
        let model = try modelOverride ?? (await checkConnection())

        let url = URL(string: "\(endpoint)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = response.choices.first?.message.content, !content.isEmpty else {
            throw LMStudioError.emptyResponse
        }

        return content
    }

    /// Convenience: single-shot prompt with system message.
    func prompt(system: String, user: String, temperature: Double = 0.3) async throws -> String {
        try await chat(
            messages: [
                Message(role: "system", content: system),
                Message(role: "user", content: user)
            ],
            temperature: temperature
        )
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter "LMStudioClientTests" 2>&1 | tail -10
```

Expected: PASS (unit tests don't hit the network — they test configuration and encoding)

- [ ] **Step 5: Commit**

```bash
git add Sources/Gaesteglueck/Services/LMStudioClient.swift \
       Tests/GaesteglueckTests/Services/LMStudioClientTests.swift
git commit -m "feat: add LMStudioClient for local LLM integration"
```

---

### Task 9: LLM Guest Parser

**Files:**
- Create: `Sources/Gaesteglueck/Services/LLMGuestParser.swift`
- Test: `Tests/GaesteglueckTests/Services/LLMGuestParserTests.swift`

- [ ] **Step 1: Write LLMGuestParser tests**

```swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("LLMGuestParser")
struct LLMGuestParserTests {
    @Test("Parse structured JSON response into ImportedGuests")
    func parseValidJSON() throws {
        let json = """
        [
          {"firstName": "Peter", "lastName": "Sommer", "dietary": "Fleisch", "intolerances": [], "isChild": false, "funFact": "fährt gern Rennrad"},
          {"firstName": "Johannes", "lastName": "Sommer", "dietary": "Fleisch", "intolerances": [], "isChild": true, "funFact": "spielt Schach"}
        ]
        """

        let guests = try LLMGuestParser.parseResponse(json)
        #expect(guests.count == 2)
        #expect(guests[0].firstName == "Peter")
        #expect(guests[0].lastName == "Sommer")
        #expect(guests[0].ageCategory == .adult)
        #expect(guests[1].firstName == "Johannes")
        #expect(guests[1].ageCategory == .child)
    }

    @Test("Build prompt from registration row")
    func buildPrompt() {
        let row = RegistrationRow(
            familyName: "Sommer",
            guestCount: 5,
            guestDetails: "Peter, Fleisch, Marlene, Fleisch, Johannes, Fleisch, Kind",
            funFacts: "Peter: fährt gern Rennrad",
            notes: ""
        )

        let prompt = LLMGuestParser.buildPrompt(for: row)
        #expect(prompt.contains("Sommer"))
        #expect(prompt.contains("5"))
        #expect(prompt.contains("Peter"))
        #expect(prompt.contains("JSON"))
    }

    @Test("Parse response with markdown code fences")
    func parseWithCodeFences() throws {
        let response = """
        Hier sind die extrahierten Gäste:

        ```json
        [{"firstName": "Kai", "lastName": "Hofer", "dietary": "Fleisch", "intolerances": [], "isChild": false, "funFact": ""}]
        ```
        """

        let guests = try LLMGuestParser.parseResponse(response)
        #expect(guests.count == 1)
        #expect(guests[0].firstName == "Kai")
    }

    @Test("Fallback regex parser for simple cases")
    func fallbackParser() {
        let row = RegistrationRow(
            familyName: "Brandt und Dallmann",
            guestCount: 2,
            guestDetails: "Nils Brandt, Fleisch\nMartha Dallmann, Fleisch",
            funFacts: "",
            notes: ""
        )

        let guests = LLMGuestParser.fallbackParse(row)
        #expect(guests.count == 2)
        #expect(guests[0].firstName == "Nils")
        #expect(guests[0].lastName == "Brandt")
        #expect(guests[1].firstName == "Martha")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter "LLMGuestParserTests" 2>&1 | tail -10
```

Expected: FAIL

- [ ] **Step 3: Implement LLMGuestParser.swift**

```swift
import Foundation

enum LLMGuestParser {
    struct ParsedGuest: Codable, Sendable {
        let firstName: String
        let lastName: String
        let dietary: String
        let intolerances: [String]
        let isChild: Bool
        let funFact: String
    }

    static let systemPrompt = """
        Du bist ein Daten-Parser für Hochzeitsanmeldungen. Extrahiere aus dem Freitext \
        alle einzelnen Gäste als JSON-Array.

        Pro Gast folgende Felder:
        - firstName: Vorname
        - lastName: Nachname (aus Familienname ableiten falls nicht angegeben)
        - dietary: Essenswahl ("Fleisch", "Vegetarisch", "Vegan") — "alles" oder unklar = "Fleisch"
        - intolerances: Array von Unverträglichkeiten (leer wenn keine)
        - isChild: true wenn explizit als Kind markiert
        - funFact: Fun Fact falls vorhanden (sonst "")

        Antworte NUR mit dem JSON-Array, keine Erklärungen.
        """

    static func buildPrompt(for row: RegistrationRow) -> String {
        """
        Familienname: "\(row.familyName)"
        Anzahl Gäste: \(row.guestCount)
        Gäste-Details: "\(row.guestDetails)"
        Fun Facts: "\(row.funFacts)"
        Anmerkungen: "\(row.notes)"

        Extrahiere alle \(row.guestCount) Gäste als JSON-Array.
        """
    }

    /// Parse LLM response text into ImportedGuests.
    static func parseResponse(_ text: String) throws -> [ImportedGuest] {
        let jsonString = extractJSON(from: text)

        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidFormat("Konnte Antwort nicht als Text lesen")
        }

        let parsed = try JSONDecoder().decode([ParsedGuest].self, from: data)

        return parsed.map { p in
            ImportedGuest(
                firstName: p.firstName,
                lastName: p.lastName,
                dietaryChoice: normalizeDietary(p.dietary),
                intolerances: p.intolerances,
                ageCategory: p.isChild ? .child : .adult,
                funFact: p.funFact,
                notes: ""
            )
        }
    }

    /// Extract JSON array from LLM response (handles markdown code fences).
    static func extractJSON(from text: String) -> String {
        // Try to find ```json ... ``` block
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Try to find ``` ... ``` block
        if let start = text.range(of: "```"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Try to find raw JSON array
        if let start = text.firstIndex(of: "["),
           let end = text.lastIndex(of: "]") {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalize dietary choice string.
    static func normalizeDietary(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "vegan": return "Vegan"
        case "vegetarisch", "vegetarian", "veggie": return "Vegetarisch"
        default: return "Fleisch"
        }
    }

    /// Regex-based fallback for when LLM is not available.
    static func fallbackParse(_ row: RegistrationRow) -> [ImportedGuest] {
        let text = row.guestDetails
        guard !text.isEmpty else {
            // No details — create placeholder guests from family name
            return [ImportedGuest(
                firstName: row.familyName,
                lastName: "",
                dietaryChoice: "Fleisch",
                intolerances: [],
                ageCategory: .adult,
                funFact: "",
                notes: ""
            )]
        }

        // Split on common delimiters: newlines, //, ;
        let separators = ["\n", "//", ";"]
        var lines = [text]
        for sep in separators {
            lines = lines.flatMap { $0.components(separatedBy: sep) }
        }

        // Also split comma-separated if it looks like "Name, Essen, Name, Essen"
        if lines.count == 1 && row.guestCount > 1 {
            let commaParts = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if commaParts.count >= row.guestCount * 2 {
                // Likely "Name, Essen, Name, Essen" pattern
                var guests: [ImportedGuest] = []
                var i = 0
                while i < commaParts.count - 1 {
                    let namePart = commaParts[i]
                    let dietPart = commaParts[i + 1]
                    let dietary = normalizeDietary(dietPart)
                    let isChild = dietPart.lowercased().contains("kind")
                    let names = splitName(namePart, familyName: row.familyName)
                    guests.append(ImportedGuest(
                        firstName: names.first,
                        lastName: names.last,
                        dietaryChoice: dietary,
                        intolerances: [],
                        ageCategory: isChild ? .child : .adult,
                        funFact: "",
                        notes: ""
                    ))
                    i += 2
                }
                if !guests.isEmpty { return guests }
            }
        }

        return lines.compactMap { line -> ImportedGuest? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let parts = trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let namePart = parts.first ?? trimmed
            let names = splitName(namePart, familyName: row.familyName)
            let dietary = parts.count > 1 ? normalizeDietary(parts[1]) : "Fleisch"
            let isChild = trimmed.lowercased().contains("kind")

            return ImportedGuest(
                firstName: names.first,
                lastName: names.last,
                dietaryChoice: dietary,
                intolerances: [],
                ageCategory: isChild ? .child : .adult,
                funFact: "",
                notes: ""
            )
        }
    }

    private static func splitName(_ name: String, familyName: String) -> (first: String, last: String) {
        let words = name.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        if words.count >= 2 {
            return (words[0], words.dropFirst().joined(separator: " "))
        } else if words.count == 1 {
            // Use family name as last name
            let lastName = familyName
                .components(separatedBy: CharacterSet(charactersIn: ",/&"))
                .first?
                .trimmingCharacters(in: .whitespaces) ?? ""
            return (words[0], lastName)
        }
        return (name, "")
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter "LLMGuestParserTests" 2>&1 | tail -10
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Gaesteglueck/Services/LLMGuestParser.swift \
       Tests/GaesteglueckTests/Services/LLMGuestParserTests.swift
git commit -m "feat: add LLM-based guest parser with regex fallback"
```

---

### Task 10: Group Analyzer Service

**Files:**
- Create: `Sources/Gaesteglueck/Services/GroupAnalyzer.swift`
- Test: `Tests/GaesteglueckTests/Services/GroupAnalyzerTests.swift`

- [ ] **Step 1: Write GroupAnalyzer tests**

```swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("GroupAnalyzer")
struct GroupAnalyzerTests {
    @Test("Detect clusters from tags")
    func detectClusters() {
        let guest1 = Guest(firstName: "Alice")
        let guest2 = Guest(firstName: "Bob")
        let guest3 = Guest(firstName: "Charlie")
        let guest4 = Guest(firstName: "Diana")

        let tag1 = Tag(name: "Studienfreunde", category: .friendGroup)
        tag1.guestIDs = [guest1.id, guest2.id, guest3.id]

        let tag2 = Tag(name: "Arbeitskollegen", category: .work)
        tag2.guestIDs = [guest4.id]

        let clusters = GroupAnalyzer.detectClusters(
            guests: [guest1, guest2, guest3, guest4],
            tags: [tag1, tag2]
        )

        #expect(clusters.count == 2)
        let large = clusters.first { $0.guestIDs.count == 3 }
        #expect(large != nil)
        #expect(large?.tagName == "Studienfreunde")
    }

    @Test("Find bridge persons (shared between tags)")
    func findBridgePersons() {
        let guest1 = Guest(firstName: "Alice")

        let tag1 = Tag(name: "Studienfreunde", category: .friendGroup)
        tag1.guestIDs = [guest1.id, UUID()]

        let tag2 = Tag(name: "Siemens", category: .work)
        tag2.guestIDs = [guest1.id, UUID()]

        let bridges = GroupAnalyzer.findBridgePersons(
            guests: [guest1],
            tags: [tag1, tag2]
        )

        #expect(bridges.count == 1)
        #expect(bridges[0].guestID == guest1.id)
        #expect(bridges[0].sharedTags.count == 2)
    }

    @Test("Build context summary for LLM")
    func buildContext() {
        let guest = Guest(firstName: "Test", lastName: "User", partnerAssignment: .partner1)
        let tag = Tag(name: "WG", category: .friendGroup, partnerAssignment: .partner1)
        tag.guestIDs = [guest.id]

        let context = GroupAnalyzer.buildLLMContext(
            guests: [guest],
            tags: [tag],
            constraints: [],
            tables: []
        )

        #expect(context.contains("Test User"))
        #expect(context.contains("WG"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter "GroupAnalyzerTests" 2>&1 | tail -10
```

Expected: FAIL

- [ ] **Step 3: Implement GroupAnalyzer.swift**

```swift
import Foundation

enum GroupAnalyzer {
    struct Cluster: Sendable {
        let tagName: String
        let tagCategory: TagCategory
        let guestIDs: [UUID]
        let partnerAssignment: PartnerAssignment?
    }

    struct BridgePerson: Sendable {
        let guestID: UUID
        let guestName: String
        let sharedTags: [String]
    }

    /// Detect natural clusters from tags.
    static func detectClusters(guests: [Guest], tags: [Tag]) -> [Cluster] {
        tags
            .filter { !$0.guestIDs.isEmpty }
            .map { tag in
                Cluster(
                    tagName: tag.name,
                    tagCategory: tag.category,
                    guestIDs: tag.guestIDs,
                    partnerAssignment: tag.partnerAssignment
                )
            }
            .sorted { $0.guestIDs.count > $1.guestIDs.count }
    }

    /// Find guests that appear in multiple tags (bridge persons).
    static func findBridgePersons(guests: [Guest], tags: [Tag]) -> [BridgePerson] {
        var guestTagMap: [UUID: [String]] = [:]

        for tag in tags {
            for guestID in tag.guestIDs {
                guestTagMap[guestID, default: []].append(tag.name)
            }
        }

        return guestTagMap
            .filter { $0.value.count >= 2 }
            .compactMap { (guestID, tagNames) in
                guard let guest = guests.first(where: { $0.id == guestID }) else { return nil }
                return BridgePerson(
                    guestID: guestID,
                    guestName: guest.fullName,
                    sharedTags: tagNames
                )
            }
            .sorted { $0.sharedTags.count > $1.sharedTags.count }
    }

    /// Build a structured context string for the LLM.
    static func buildLLMContext(
        guests: [Guest],
        tags: [Tag],
        constraints: [Constraint],
        tables: [GuestTable]
    ) -> String {
        var context = "# Gästeliste\n\n"
        context += "Gesamt: \(guests.count) Gäste\n"
        context += "Erwachsene: \(guests.filter { $0.ageCategory == .adult }.count)\n"
        context += "Kinder: \(guests.filter { $0.ageCategory != .adult }.count)\n\n"

        // Guest list
        context += "## Gäste\n\n"
        for guest in guests.sorted(by: { $0.fullName < $1.fullName }) {
            var line = "- \(guest.fullName) (\(guest.partnerAssignment.rawValue))"
            if guest.ageCategory != .adult { line += " [\(guest.ageCategory.rawValue)]" }
            if guest.dietaryChoice != "Fleisch" { line += " \(guest.dietaryChoice)" }
            if guest.hasIntolerances { line += " ⚠️\(guest.intolerances.joined(separator: ","))" }

            let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }.map(\.name)
            if !guestTags.isEmpty { line += " Tags: \(guestTags.joined(separator: ", "))" }

            context += line + "\n"
        }

        // Clusters
        let clusters = detectClusters(guests: guests, tags: tags)
        if !clusters.isEmpty {
            context += "\n## Gruppen\n\n"
            for cluster in clusters {
                let names = cluster.guestIDs.compactMap { id in
                    guests.first { $0.id == id }?.fullName
                }
                context += "- \(cluster.tagName) (\(cluster.guestIDs.count)): \(names.joined(separator: ", "))\n"
            }
        }

        // Bridge persons
        let bridges = findBridgePersons(guests: guests, tags: tags)
        if !bridges.isEmpty {
            context += "\n## Brücken-Personen\n\n"
            for bridge in bridges {
                context += "- \(bridge.guestName): verbindet \(bridge.sharedTags.joined(separator: " + "))\n"
            }
        }

        // Constraints
        if !constraints.isEmpty {
            context += "\n## Einschränkungen\n\n"
            for constraint in constraints {
                let names = constraint.guestIDs.compactMap { id in
                    guests.first { $0.id == id }?.fullName
                }
                context += "- \(constraint.type.rawValue): \(names.joined(separator: ", "))"
                if !constraint.reason.isEmpty { context += " (\(constraint.reason))" }
                context += "\n"
            }
        }

        // Tables
        if !tables.isEmpty {
            context += "\n## Verfügbare Tische\n\n"
            for table in tables.sorted(by: { $0.name < $1.name }) {
                context += "- \(table.name): \(table.shape.rawValue), \(table.capacity) Plätze"
                if table.isChildTable { context += " [Kindertisch]" }
                context += " (\(table.guests.count) zugewiesen)\n"
            }
        }

        return context
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter "GroupAnalyzerTests" 2>&1 | tail -10
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Gaesteglueck/Services/GroupAnalyzer.swift \
       Tests/GaesteglueckTests/Services/GroupAnalyzerTests.swift
git commit -m "feat: add GroupAnalyzer for cluster detection and LLM context"
```

---

### Task 11: Update ExcelParser for Wedding Form Format

**Files:**
- Modify: `Sources/Gaesteglueck/Services/ExcelParser.swift`

- [ ] **Step 1: Rewrite ExcelParser.swift**

The Excel parser now outputs `[RegistrationRow]` (same as CSVParser) since the actual guest parsing is done by the LLM.

```swift
import Foundation
import CoreXLSX

enum ExcelParser {
    static func parseRegistrations(_ data: Data) throws -> [RegistrationRow] {
        guard let file = try? XLSXFile(data: data) else {
            throw ImportError.invalidFormat("Kann XLSX nicht lesen")
        }

        let sharedStrings = try file.parseSharedStrings()

        for workbook in try file.parseWorkbooks() {
            for (_, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let worksheet = try file.parseWorksheet(at: path)
                guard let rows = worksheet.data?.rows, rows.count > 1 else { continue }

                let headerRow = rows[0]
                let headers = headerRow.cells.map { cell -> String in
                    cell.stringValue(sharedStrings) ?? ""
                }.map { $0.lowercased() }

                let familyIdx = headers.firstIndex { $0.contains("familie") || $0.contains("name") }
                let attendIdx = headers.firstIndex { $0.contains("teilnehm") || $0.contains("attend") }
                let countIdx = headers.firstIndex { $0.contains("anzahl") || $0.contains("gesamt") }
                let guestsIdx = headers.firstIndex { $0.contains("gast") || $0.contains("gib") || $0.contains("jeden") }
                let funFactIdx = headers.firstIndex { $0.contains("fun") || $0.contains("fact") }
                let notesIdx = headers.lastIndex { $0.contains("anmerkung") || $0.contains("wünsch") }

                var registrations: [RegistrationRow] = []

                for row in rows.dropFirst() {
                    let cells = row.cells
                    func cellValue(_ idx: Int?) -> String {
                        guard let idx, idx < cells.count else { return "" }
                        return cells[idx].stringValue(sharedStrings) ?? ""
                    }

                    // Skip non-attending
                    if let aIdx = attendIdx {
                        let attendance = cellValue(aIdx).lowercased()
                        if attendance.contains("nein") || attendance.contains("nicht") { continue }
                    }

                    let familyName = cellValue(familyIdx)
                    guard !familyName.isEmpty else { continue }

                    let countStr = cellValue(countIdx)
                    let guestCount = Int(Double(countStr) ?? 1)

                    registrations.append(RegistrationRow(
                        familyName: familyName,
                        guestCount: guestCount,
                        guestDetails: cellValue(guestsIdx),
                        funFacts: cellValue(funFactIdx),
                        notes: cellValue(notesIdx)
                    ))
                }

                if !registrations.isEmpty { return registrations }
            }
        }

        throw ImportError.emptyFile
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Gaesteglueck/Services/ExcelParser.swift
git commit -m "feat: update ExcelParser for wedding registration form format"
```

---

## Phase 3: Views (UI Layer)

### Task 12: Dashboard & Event Setup Views

**Files:**
- Create: `Sources/Gaesteglueck/Views/DashboardView.swift`
- Create: `Sources/Gaesteglueck/Views/EventSetupView.swift`
- Modify: `Sources/Gaesteglueck/Views/SettingsView.swift`
- Modify: `Sources/Gaesteglueck/ContentView.swift`

- [ ] **Step 1: Create DashboardView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var tags: [Tag]
    @Query private var events: [Event]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Event header
                if let event = events.first {
                    VStack(alignment: .leading) {
                        Text(event.name)
                            .font(.largeTitle.bold())
                        if let date = event.date {
                            Text(date, style: .date)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(event.partnerDisplayName1) & \(event.partnerDisplayName2)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView(
                        "Kein Event angelegt",
                        systemImage: "heart",
                        description: Text("Erstelle zuerst ein Event in den Einstellungen.")
                    )
                }

                // Stats cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                    StatCard(title: "Erwachsene", value: "\(adults)", icon: "person.2", color: .blue)
                    StatCard(title: "Kinder", value: "\(children)", icon: "figure.child", color: .green)
                    StatCard(title: "Gesamt", value: "\(guests.count)", icon: "person.3", color: .purple)
                    StatCard(title: "Tische", value: "\(tables.count)", icon: "tablecells", color: .orange)
                    StatCard(title: "Gruppen", value: "\(tags.count)", icon: "tag", color: .teal)
                    if intoleranceCount > 0 {
                        StatCard(title: "Unverträglichkeiten", value: "\(intoleranceCount)", icon: "exclamationmark.triangle", color: .red)
                    }
                }

                // Dietary breakdown
                if !guests.isEmpty {
                    GroupBox("Essenswahl") {
                        let counts = Dictionary(grouping: guests, by: \.dietaryChoice).mapValues(\.count)
                        ForEach(counts.sorted(by: { $0.key < $1.key }), id: \.key) { choice, count in
                            HStack {
                                Text(choice)
                                Spacer()
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    private var adults: Int { guests.filter { $0.ageCategory == .adult }.count }
    private var children: Int { guests.filter { $0.ageCategory != .adult }.count }
    private var intoleranceCount: Int { guests.filter(\.hasIntolerances).count }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
#endif
```

- [ ] **Step 2: Create EventSetupView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

struct EventSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]

    @State private var name = ""
    @State private var date = Date()
    @State private var venue = ""
    @State private var partner1Name = ""
    @State private var partner2Name = ""
    @State private var partner1PreMarriageName = ""
    @State private var partner2PreMarriageName = ""
    @State private var menuOptions = "Fleisch, Vegetarisch, Vegan"
    @State private var roomWidth = ""
    @State private var roomLength = ""

    var body: some View {
        Form {
            Section("Event") {
                TextField("Event-Name", text: $name)
                DatePicker("Datum", selection: $date, displayedComponents: .date)
                TextField("Venue / Location", text: $venue)
            }

            Section("Partner") {
                TextField("Partner 1 — Vorname", text: $partner1Name)
                TextField("Partner 1 — Nachname (vor Hochzeit)", text: $partner1PreMarriageName)
                TextField("Partner 2 — Vorname", text: $partner2Name)
                TextField("Partner 2 — Nachname (vor Hochzeit)", text: $partner2PreMarriageName)
            }

            Section("Menü") {
                TextField("Optionen (kommagetrennt)", text: $menuOptions)
                    .help("z.B. Fleisch, Vegetarisch, Vegan")
            }

            Section("Raum") {
                TextField("Breite (cm)", text: $roomWidth)
                TextField("Länge (cm)", text: $roomLength)
            }

            Button("Speichern") {
                saveEvent()
            }
            .buttonStyle(.borderedProminent)
        }
        .formStyle(.grouped)
        .navigationTitle("Event Einrichten")
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        guard let event = events.first else { return }
        name = event.name
        date = event.date ?? Date()
        venue = event.venue
        partner1Name = event.partner1Name
        partner2Name = event.partner2Name
        partner1PreMarriageName = event.partner1PreMarriageName
        partner2PreMarriageName = event.partner2PreMarriageName
        menuOptions = event.menuOptions.joined(separator: ", ")
        roomWidth = event.roomWidthCM.map { String(Int($0)) } ?? ""
        roomLength = event.roomLengthCM.map { String(Int($0)) } ?? ""
    }

    private func saveEvent() {
        let event = events.first ?? Event(name: name)
        event.name = name
        event.date = date
        event.venue = venue
        event.partner1Name = partner1Name
        event.partner2Name = partner2Name
        event.partner1PreMarriageName = partner1PreMarriageName
        event.partner2PreMarriageName = partner2PreMarriageName
        event.menuOptions = menuOptions.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        event.roomWidthCM = Double(roomWidth)
        event.roomLengthCM = Double(roomLength)

        if events.isEmpty {
            modelContext.insert(event)
        }
        try? modelContext.save()
    }
}
#endif
```

- [ ] **Step 3: Update SettingsView.swift**

Add LM Studio connection settings:

```swift
#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @AppStorage("lmStudioEndpoint") private var endpoint = "http://localhost:1234"
    @State private var connectionStatus: String?
    @State private var isChecking = false

    var body: some View {
        Form {
            Section("LM Studio") {
                TextField("Endpoint", text: $endpoint)
                    .help("z.B. http://localhost:1234 oder http://macmini.local:1234")

                HStack {
                    Button("Verbindung testen") {
                        checkConnection()
                    }
                    .disabled(isChecking)

                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let status = connectionStatus {
                        Text(status)
                            .foregroundStyle(status.contains("✓") ? .green : .red)
                            .font(.caption)
                    }
                }
            }

            Section("Event") {
                NavigationLink("Event einrichten") {
                    EventSetupView()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
    }

    private func checkConnection() {
        isChecking = true
        connectionStatus = nil
        Task {
            do {
                let client = LMStudioClient(endpoint: endpoint)
                let model = try await client.checkConnection()
                connectionStatus = "✓ Verbunden — Modell: \(model)"
            } catch {
                connectionStatus = "✗ \(error.localizedDescription)"
            }
            isChecking = false
        }
    }
}
#endif
```

- [ ] **Step 4: Wire up ContentView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI

struct ContentView: View {
    @State private var selectedSection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView()
            case .guests:
                GuestListView()
            case .tables:
                RoomCanvasView()
            case .tags:
                TagListView()
            case .assistant:
                KIWizardView()
            case .settings:
                SettingsView()
            case nil:
                ContentUnavailableView(
                    "Bereich wählen",
                    systemImage: "sidebar.left",
                    description: Text("Wähle einen Bereich aus der Seitenleiste.")
                )
            }
        }
    }
}
#endif
```

Note: `TagListView` and `KIWizardView` don't exist yet — create stubs:

- [ ] **Step 5: Create stub views for TagListView and KIWizardView**

`Sources/Gaesteglueck/Views/TagListView.swift`:
```swift
#if canImport(SwiftUI)
import SwiftUI

struct TagListView: View {
    var body: some View {
        Text("Tags & Gruppen — wird in Task 13 implementiert")
            .navigationTitle("Gruppen & Tags")
    }
}
#endif
```

`Sources/Gaesteglueck/Views/KIWizardView.swift`:
```swift
#if canImport(SwiftUI)
import SwiftUI

struct KIWizardView: View {
    var body: some View {
        Text("KI-Assistent — wird in Task 15 implementiert")
            .navigationTitle("KI-Assistent")
    }
}
#endif
```

- [ ] **Step 6: Build and verify**

```bash
swift build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Dashboard, EventSetup, Settings views with LM Studio config"
```

---

### Task 13: Guest List, Import, Tags & Enrichment Views

**Files:**
- Modify: `Sources/Gaesteglueck/Views/GuestListView.swift`
- Modify: `Sources/Gaesteglueck/Views/GuestFormView.swift`
- Modify: `Sources/Gaesteglueck/Views/GuestRowView.swift`
- Modify: `Sources/Gaesteglueck/Views/ImportButton.swift`
- Modify: `Sources/Gaesteglueck/Views/ImportPreviewView.swift`
- Rewrite: `Sources/Gaesteglueck/Views/TagListView.swift`
- Create: `Sources/Gaesteglueck/Views/TagDetailView.swift`
- Create: `Sources/Gaesteglueck/Views/EnrichmentWizardView.swift`
- Modify: `Sources/Gaesteglueck/Views/ModelExtensions+UI.swift`

This is the largest view task. The key changes:

- [ ] **Step 1: Update GuestRowView for new model**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

struct GuestRowView: View {
    let guest: Guest
    @Query private var tags: [Tag]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(guest.fullName)
                    .font(.body)

                HStack(spacing: 4) {
                    Text(guest.partnerAssignment.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(partnerColor.opacity(0.2))
                        .clipShape(Capsule())

                    if guest.ageCategory != .adult {
                        Text(guest.ageCategory.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    ForEach(guestTags, id: \.id) { tag in
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: tag.color).opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Dietary
            Text(guest.dietaryChoice)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Intolerance warning
            if guest.hasIntolerances {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(guest.intolerances.joined(separator: ", "))
            }
        }
        .padding(.vertical, 2)
    }

    private var partnerColor: Color {
        switch guest.partnerAssignment {
        case .partner1: .blue
        case .partner2: .pink
        case .both: .purple
        }
    }

    private var guestTags: [Tag] {
        tags.filter { $0.guestIDs.contains(guest.id) }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
#endif
```

- [ ] **Step 2: Update GuestListView with search, filter, import**

Update the guest list to use the new model, add filtering by PartnerAssignment and search. Include the ImportButton and link to enrichment wizard. Use `@Query` for guests and display them grouped or flat.

Key changes vs old version:
- Filter by PartnerAssignment instead of Side
- Show tags as pills
- Add "Anreichern" button that opens the EnrichmentWizardView
- `.name` → `.fullName` everywhere

- [ ] **Step 3: Update GuestFormView**

Replace the old form with new fields:
- firstName, lastName (separate fields)
- PartnerAssignment picker
- AgeCategory picker
- DietaryChoice picker (from event.menuOptions)
- Intolerances as tag-style input
- FamilyRole picker with familyRolePartner
- Fun Fact text field
- Optional: employer, profession, hobbies (collapsible "Weitere Details" section)

- [ ] **Step 4: Update ImportButton and ImportPreviewView**

Import flow:
1. File picker (CSV/XLSX) → parse into `[RegistrationRow]`
2. For each row, attempt LLM parse (if available) or fallback parse
3. Show preview per registration: original text + parsed guests
4. User confirms/edits each row
5. On confirm: create Guest objects + link via registrationGroup UUID

The ImportPreviewView shows:
- Left: original registration text (grayed)
- Right: parsed guests as editable cards
- Buttons: "Übernehmen", "Korrigieren", "Überspringen"
- Batch: "Alle übernehmen"

- [ ] **Step 5: Implement TagListView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query private var guests: [Guest]
    @State private var selectedTag: Tag?
    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .custom

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTag) {
                ForEach(TagCategory.allCases) { category in
                    let categoryTags = tags.filter { $0.category == category }
                    if !categoryTags.isEmpty {
                        Section(category.rawValue) {
                            ForEach(categoryTags) { tag in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: tag.color))
                                        .frame(width: 10, height: 10)
                                    Text(tag.name)
                                    Spacer()
                                    Text("\(tag.guestCount)")
                                        .foregroundStyle(.secondary)
                                }
                                .tag(tag)
                            }
                            .onDelete { indexSet in
                                for idx in indexSet {
                                    modelContext.delete(categoryTags[idx])
                                }
                            }
                        }
                    }
                }

                Section("Neuer Tag") {
                    HStack {
                        TextField("Tag-Name", text: $newTagName)
                        Picker("", selection: $newTagCategory) {
                            ForEach(TagCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        .frame(width: 150)
                        Button("Erstellen") {
                            guard !newTagName.isEmpty else { return }
                            let tag = Tag(name: newTagName, category: newTagCategory)
                            modelContext.insert(tag)
                            newTagName = ""
                        }
                        .disabled(newTagName.isEmpty)
                    }
                }
            }
            .navigationTitle("Gruppen & Tags")
        } detail: {
            if let tag = selectedTag {
                TagDetailView(tag: tag)
            } else {
                ContentUnavailableView(
                    "Tag wählen",
                    systemImage: "tag",
                    description: Text("Wähle einen Tag um die zugehörigen Gäste zu sehen.")
                )
            }
        }
    }
}
#endif
```

- [ ] **Step 6: Create TagDetailView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

struct TagDetailView: View {
    @Bindable var tag: Tag
    @Query private var guests: [Guest]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tag header
            HStack {
                Circle()
                    .fill(Color(hex: tag.color))
                    .frame(width: 16, height: 16)
                TextField("Tag-Name", text: $tag.name)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)

                Spacer()

                Picker("Kategorie", selection: $tag.category) {
                    ForEach(TagCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .frame(width: 180)

                if let pa = Binding($tag.partnerAssignment) {
                    Picker("Zuordnung", selection: pa) {
                        ForEach(PartnerAssignment.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .frame(width: 120)
                }
            }
            .padding(.horizontal)

            Divider()

            // Members list
            List {
                Section("Mitglieder (\(tag.guestCount))") {
                    ForEach(tagGuests) { guest in
                        HStack {
                            Text(guest.fullName)
                            Spacer()
                            Text(guest.partnerAssignment.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            let guest = tagGuests[idx]
                            tag.guestIDs.removeAll { $0 == guest.id }
                        }
                    }
                }

                Section("Gast hinzufügen") {
                    ForEach(availableGuests) { guest in
                        Button {
                            tag.guestIDs.append(guest.id)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text(guest.fullName)
                                Spacer()
                                Text(guest.partnerAssignment.rawValue)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(tag.name)
    }

    private var tagGuests: [Guest] {
        guests.filter { tag.guestIDs.contains($0.id) }
            .sorted { $0.fullName < $1.fullName }
    }

    private var availableGuests: [Guest] {
        guests.filter { !tag.guestIDs.contains($0.id) }
            .sorted { $0.fullName < $1.fullName }
    }
}
#endif
```

- [ ] **Step 7: Create EnrichmentWizardView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

struct EnrichmentWizardView: View {
    @Query private var guests: [Guest]
    @Query private var tags: [Tag]
    @Environment(\.modelContext) private var modelContext
    @State private var currentIndex = 0
    @State private var newTagName = ""

    var body: some View {
        if let group = registrationGroups[safe: currentIndex] {
            VStack(spacing: 0) {
                // Progress
                ProgressView(value: Double(currentIndex), total: Double(registrationGroups.count))
                    .padding()

                Text("Anmeldung \(currentIndex + 1) von \(registrationGroups.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(group) { guest in
                            GroupBox(guest.fullName) {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Partner assignment
                                    Picker("Zuordnung", selection: Binding(
                                        get: { guest.partnerAssignment },
                                        set: { guest.partnerAssignment = $0 }
                                    )) {
                                        ForEach(PartnerAssignment.allCases) { p in
                                            Text(p.rawValue).tag(p)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    // Age category
                                    Picker("Alter", selection: Binding(
                                        get: { guest.ageCategory },
                                        set: { guest.ageCategory = $0 }
                                    )) {
                                        ForEach(AgeCategory.allCases) { a in
                                            Text(a.rawValue).tag(a)
                                        }
                                    }

                                    // Family role
                                    Picker("Familienrolle", selection: Binding(
                                        get: { guest.familyRole ?? .other },
                                        set: { guest.familyRole = $0 }
                                    )) {
                                        Text("Keine").tag(FamilyRole.other)
                                        ForEach(FamilyRole.allCases) { r in
                                            Text(r.rawValue).tag(r)
                                        }
                                    }

                                    // Tags
                                    Text("Tags:")
                                        .font(.caption.bold())
                                    FlowLayout(spacing: 4) {
                                        ForEach(guestTags(for: guest)) { tag in
                                            HStack(spacing: 2) {
                                                Text(tag.name)
                                                Button {
                                                    tag.guestIDs.removeAll { $0 == guest.id }
                                                } label: {
                                                    Image(systemName: "xmark")
                                                }
                                            }
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: tag.color).opacity(0.2))
                                            .clipShape(Capsule())
                                        }

                                        // Add tag inline
                                        HStack(spacing: 2) {
                                            TextField("+ Tag", text: $newTagName)
                                                .textFieldStyle(.plain)
                                                .frame(width: 100)
                                                .onSubmit {
                                                    addTag(to: guest)
                                                }
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.gray.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                // Navigation
                HStack {
                    Button("Zurück") { currentIndex -= 1 }
                        .disabled(currentIndex == 0)
                    Spacer()
                    Button("Weiter") { currentIndex += 1 }
                        .buttonStyle(.borderedProminent)
                        .disabled(currentIndex >= registrationGroups.count - 1)
                }
                .padding()
            }
            .navigationTitle("Gäste Anreichern")
        } else {
            ContentUnavailableView(
                "Fertig!",
                systemImage: "checkmark.circle",
                description: Text("Alle Anmeldungen durchgearbeitet.")
            )
        }
    }

    private var registrationGroups: [[Guest]] {
        let grouped = Dictionary(grouping: guests.filter { $0.registrationGroup != nil }, by: { $0.registrationGroup! })
        let solos = guests.filter { $0.registrationGroup == nil }.map { [$0] }
        return Array(grouped.values.sorted { $0.first?.fullName ?? "" < $1.first?.fullName ?? "" }) + solos
    }

    private func guestTags(for guest: Guest) -> [Tag] {
        tags.filter { $0.guestIDs.contains(guest.id) }
    }

    private func addTag(to guest: Guest) {
        guard !newTagName.isEmpty else { return }
        // Find existing tag or create new
        let tag = tags.first { $0.name.lowercased() == newTagName.lowercased() }
            ?? {
                let t = Tag(name: newTagName, category: .custom)
                modelContext.insert(t)
                return t
            }()
        if !tag.guestIDs.contains(guest.id) {
            tag.guestIDs.append(guest.id)
        }
        newTagName = ""
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
```

- [ ] **Step 8: Update ModelExtensions+UI.swift**

Remove all references to old types and add extensions for new types:

```swift
#if canImport(SwiftUI)
import SwiftUI

extension PartnerAssignment {
    var color: Color {
        switch self {
        case .partner1: .blue
        case .partner2: .pink
        case .both: .purple
        }
    }
}

extension AgeCategory {
    var icon: String {
        switch self {
        case .adult: "person"
        case .child: "figure.child"
        case .toddler: "figure.child"
        case .baby: "figure.child.and.lock"
        }
    }
}

extension DietaryPreference {
    var color: Color {
        switch self {
        case .meat: .brown
        case .vegetarian: .green
        case .vegan: .mint
        }
    }
}
#endif
```

- [ ] **Step 9: Build and verify**

```bash
swift build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: add guest list, import flow, tags, and enrichment wizard views"
```

---

### Task 14: Room Canvas & Table Management

**Files:**
- Modify: `Sources/Gaesteglueck/Views/RoomCanvasView.swift`
- Modify: `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift`
- Modify: `Sources/Gaesteglueck/Views/Canvas/ViolationBannerView.swift`
- Modify: `Sources/Gaesteglueck/Views/TableListView.swift`
- Modify: `Sources/Gaesteglueck/Views/TableFormView.swift`
- Create: `Sources/Gaesteglueck/Views/TableInventoryView.swift`
- Modify: `Sources/Gaesteglueck/Views/ExportButton.swift`

The canvas needs the three-panel layout (inbox | canvas | right panel). The right panel shows either table details or the KI chat (Task 15).

- [ ] **Step 1: Update RoomCanvasView for three-panel layout**

Key changes vs old:
- Replace `@Query private var relationships: [Relationship]` with `@Query private var tags: [Tag]` and `@Query private var constraints: [Constraint]`
- Left panel groups unassigned guests by tags instead of by side
- Pass `tags:` and `constraints:` to HappinessScorer and SeatingOptimizer
- Right panel shows selected table details
- Replace `.name` → `.fullName`, `.side` → `.partnerAssignment` in all guest displays
- Replace `Violation.personAID/personBID` with `Violation.guestIDs`

- [ ] **Step 2: Update ViolationBannerView**

Change from `personAID/personBID` pair lookups to `guestIDs` array:

```swift
#if canImport(SwiftUI)
import SwiftUI

struct ViolationBannerView: View {
    let violations: [Violation]
    let guests: [Guest]

    var body: some View {
        if !violations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(violations) { violation in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(violationText(violation))
                            .font(.caption)
                    }
                }
            }
            .padding(8)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func violationText(_ violation: Violation) -> String {
        let names = violation.guestIDs.compactMap { id in
            guests.first { $0.id == id }?.fullName
        }
        return "\(violation.description): \(names.joined(separator: ", "))"
    }
}
#endif
```

- [ ] **Step 3: Create TableInventoryView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

struct TableInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var inventory: [TableInventoryItem]

    var body: some View {
        List {
            ForEach(inventory) { item in
                HStack {
                    Image(systemName: item.shape.icon)
                    Text(item.label)
                    Spacer()
                    Text("\(item.availableCount)x")
                        .foregroundStyle(.secondary)
                    Stepper("", value: Binding(
                        get: { item.availableCount },
                        set: { item.availableCount = $0 }
                    ), in: 0...50)
                    .labelsHidden()
                }
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    modelContext.delete(inventory[idx])
                }
            }

            Section("Tisch-Typ hinzufügen") {
                Button("Runder Tisch (∅180cm)") {
                    modelContext.insert(TableInventoryItem(shape: .round, diameter: 180, availableCount: 1))
                }
                Button("Rechteckiger Tisch (200x100cm)") {
                    modelContext.insert(TableInventoryItem(shape: .rectangular, width: 200, depth: 100, availableCount: 1))
                }
                Button("Quadratischer Tisch (120x120cm)") {
                    modelContext.insert(TableInventoryItem(shape: .square, width: 120, availableCount: 1))
                }
            }
        }
        .navigationTitle("Tisch-Inventar")
    }
}
#endif
```

- [ ] **Step 4: Update ExportButton for macOS**

Replace UIKit file export with NSSavePanel:

```swift
#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

struct ExportButton: View {
    let tables: [GuestTable]
    let eventName: String
    let date: Date?

    var body: some View {
        Button {
            exportPDF()
        } label: {
            Label("PDF Export", systemImage: "square.and.arrow.up")
        }
    }

    private func exportPDF() {
        let data = PDFExporter.generatePDF(tables: tables, eventName: eventName, date: date)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Sitzplan-\(eventName).pdf"

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
#endif
```

- [ ] **Step 5: Build and verify**

```bash
swift build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: update room canvas, table management, and PDF export for macOS"
```

---

### Task 15: KI Wizard & Chat Views

**Files:**
- Rewrite: `Sources/Gaesteglueck/Views/KIWizardView.swift`
- Create: `Sources/Gaesteglueck/Views/KIChatView.swift`

- [ ] **Step 1: Implement KIWizardView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI
import SwiftData

enum WizardPhase: String, CaseIterable {
    case clusters = "Gruppen erkennen"
    case harmony = "Harmonie prüfen"
    case childTable = "Kindertisch"
    case tableConfig = "Tisch-Konfiguration"
    case seatingPlan = "Sitzplan erstellen"
    case done = "Fertig"
}

struct KIWizardView: View {
    @Query private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var tables: [GuestTable]
    @AppStorage("lmStudioEndpoint") private var endpoint = "http://localhost:1234"

    @State private var phase: WizardPhase = .clusters
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var showChat = false

    var body: some View {
        if showChat {
            KIChatView(
                guests: guests,
                tags: tags,
                constraints: constraints,
                tables: tables,
                endpoint: endpoint,
                initialMessages: messages
            )
        } else {
            VStack(spacing: 0) {
                // Phase progress
                HStack {
                    ForEach(WizardPhase.allCases, id: \.self) { p in
                        VStack {
                            Circle()
                                .fill(p == phase ? .accentColor : .gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text(p.rawValue)
                                .font(.caption2)
                        }
                        if p != .done {
                            Rectangle()
                                .fill(.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                    }
                }
                .padding()

                Divider()

                // Chat messages
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("KI denkt nach...")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading)
                        }
                    }
                    .padding()
                }

                Divider()

                // Actions
                HStack {
                    if phase == .done {
                        Button("Zum Raumplan mit Chat wechseln") {
                            showChat = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Nächster Schritt") {
                            runNextPhase()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)
                    }
                }
                .padding()
            }
            .navigationTitle("KI-Assistent")
            .onAppear {
                if messages.isEmpty {
                    runNextPhase()
                }
            }
        }
    }

    private func runNextPhase() {
        isLoading = true
        Task {
            let client = LMStudioClient(endpoint: endpoint)
            let context = GroupAnalyzer.buildLLMContext(
                guests: guests,
                tags: tags,
                constraints: constraints,
                tables: tables
            )

            let prompt: String
            switch phase {
            case .clusters:
                prompt = """
                \(context)

                Analysiere die Gästeliste und identifiziere natürliche Gruppen/Cluster.
                Welche Gruppen siehst du? Wie groß sind sie?
                Gibt es Brücken-Personen die mehrere Gruppen verbinden?
                """
            case .harmony:
                prompt = """
                \(context)

                Welche Gruppen könnten gut zusammen an einem Tisch sitzen?
                Welche Kombinationen wären problematisch?
                Gibt es Gruppen die zu groß für einen Tisch sind — wie aufteilen?
                """
            case .childTable:
                prompt = """
                \(context)

                Wie sollte der Kindertisch aussehen?
                Welche Kinder kennen sich (über ihre Eltern)?
                Welche Eltern wären gute Aufsichtspersonen am Kindertisch?
                """
            case .tableConfig:
                prompt = """
                \(context)

                Wie viele Tische brauchen wir und in welcher Konfiguration?
                (Rund, Rechteckig, Tafel, U-Form)
                Wie verteilen sich die Gäste auf die Tische?
                """
            case .seatingPlan:
                prompt = """
                \(context)

                Erstelle einen konkreten Sitzplan:
                Welcher Gast sitzt an welchem Tisch?
                Begründe die wichtigsten Entscheidungen.
                """
            case .done:
                isLoading = false
                return
            }

            do {
                let response = try await client.prompt(
                    system: """
                    Du bist ein erfahrener Hochzeitsplaner-Assistent. Analysiere die Gästeliste \
                    und gib konkrete, namentliche Vorschläge. Antworte auf Deutsch. Sei strukturiert \
                    und nenne immer Namen.
                    """,
                    user: prompt
                )

                messages.append(ChatMessage(role: .assistant, content: response))
                advancePhase()
            } catch {
                messages.append(ChatMessage(role: .system, content: "Fehler: \(error.localizedDescription)"))
            }

            isLoading = false
        }
    }

    private func advancePhase() {
        guard let idx = WizardPhase.allCases.firstIndex(of: phase),
              idx + 1 < WizardPhase.allCases.count else { return }
        phase = WizardPhase.allCases[idx + 1]
    }
}

struct ChatMessage: Identifiable, Sendable {
    let id = UUID()
    let role: ChatRole
    let content: String

    enum ChatRole: Sendable {
        case user, assistant, system
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            Text(message.content)
                .padding(10)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 600, alignment: message.role == .user ? .trailing : .leading)

            if message.role != .user { Spacer() }
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: .accentColor.opacity(0.15)
        case .assistant: .secondary.opacity(0.1)
        case .system: .red.opacity(0.1)
        }
    }
}
#endif
```

- [ ] **Step 2: Create KIChatView.swift**

```swift
#if canImport(SwiftUI)
import SwiftUI

struct KIChatView: View {
    let guests: [Guest]
    let tags: [Tag]
    let constraints: [Constraint]
    let tables: [GuestTable]
    let endpoint: String

    @State var initialMessages: [ChatMessage]
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("KI denkt nach...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            HStack {
                TextField("Nachricht an KI...", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { send() }

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(input.isEmpty || isLoading)
                .buttonStyle(.plain)
            }
            .padding()
        }
        .onAppear {
            messages = initialMessages
        }
    }

    private func send() {
        guard !input.isEmpty else { return }
        let userMessage = input
        input = ""

        messages.append(ChatMessage(role: .user, content: userMessage))
        isLoading = true

        Task {
            let client = LMStudioClient(endpoint: endpoint)
            let context = GroupAnalyzer.buildLLMContext(
                guests: guests,
                tags: tags,
                constraints: constraints,
                tables: tables
            )

            // Build full message history for context
            var llmMessages: [LMStudioClient.Message] = [
                LMStudioClient.Message(role: "system", content: """
                    Du bist ein Hochzeitsplaner-Assistent. Hier ist der aktuelle Stand:

                    \(context)

                    Antworte auf Deutsch. Sei konkret, nenne Namen. Wenn der User Änderungen \
                    vorschlägt, erkläre die Konsequenzen.
                    """)
            ]

            for msg in messages {
                let role = msg.role == .user ? "user" : "assistant"
                llmMessages.append(LMStudioClient.Message(role: role, content: msg.content))
            }

            do {
                let response = try await client.chat(messages: llmMessages)
                messages.append(ChatMessage(role: .assistant, content: response))
            } catch {
                messages.append(ChatMessage(role: .system, content: "Fehler: \(error.localizedDescription)"))
            }

            isLoading = false
        }
    }
}
#endif
```

- [ ] **Step 3: Build and verify**

```bash
swift build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests**

```bash
swift test 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add KI wizard and chat views for AI-assisted seating planning"
```

---

## Backlog (iOS/iPad)

These tasks are deferred for when an Apple Developer Account is available:

- [ ] iOS target in Package.swift
- [ ] On-device LLM integration (CoreML/MLX on M-chip iPads)
- [ ] LM Studio over local network (iPad → Mac Mini)
- [ ] Multi-Event UI (event list, event switcher)
- [ ] iCloud Sync (SwiftData + CloudKit)
- [ ] Landscape/portrait adaptive layouts
- [ ] iPad-optimized toolbar and split view
- [ ] App Store submission
