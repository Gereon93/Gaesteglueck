# AGENTS.md

## Projekt

Gästeglück ist ein macOS-nativer Hochzeits-Sitzplaner mit optionaler lokaler KI
(LM Studio, OpenRouter, Apple Intelligence). Entwickelt für die eigene Hochzeit
und dort produktiv eingesetzt. Komplett lokal, keine Cloud, keine Accounts.

## Tech Stack

- **Swift 6.0** (strikte Concurrency, `swift-tools-version: 6.0`)
- **SwiftUI** (macOS 15+, experimentelles iPad-Target iOS 18+)
- **SwiftData** mit `VersionedSchema` V1–V5 + `SchemaMigrationPlan` (lightweight)
- **Build:** Swift Package Manager (`Package.swift`)
- **Einzige externe Dependency:** CoreXLSX (Excel-Import)
- **Architektur:** MV (Model-View) + Service Layer — **kein** MVVM, **kein** DDD/CQRS
- **Test-Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`)
- **Sprache:** Deutsch in Code, Kommentaren, Commits, Docs und UI

## Architektur-Konventionen

### Services sind `enum` mit `static func`

Stateless Services sind `enum` — keine Instanzen nötig:

```swift
enum SeatingOptimizer {
    static func solve(guests: [Guest], tables: [GuestTable], ...) -> [GuestTable] { ... }
}
```

Services mit Dependency (z.B. `LLMClient`) sind `struct` mit Property:

```swift
struct SitzplanCoPilot {
    let client: LLMClient
    func requestSuggestion(...) async throws -> CoPilotResponse { ... }
}
```

### Views queryn SwiftData via `@Query`

```swift
@Query(sort: \Guest.firstName) private var guests: [Guest]
@Environment(\.modelContext) private var modelContext
```

Views enthalten **keine** Geschäftslogik — die gehört in Services.

### Concurrency

- **Views + Model-Mutationen:** `@MainActor`
- **LLM-Clients:** `actor` (`LMStudioClient`, `OpenRouterClient`)
- **Stateless Services:** `nonisolated` (enum/struct)
- **`LLMClient`-Protocol:** erfordert `Sendable`
- **Actor-Grenzen:** `GuestSnapshot`-Struct statt `@Model`-Objekt überreichen
- **`nonisolated(unsafe)`** nur mit explizitem Lock (`NSLock`, `renderLock`)

### SwiftData

- **12 Models** in SchemaV5: `Event`, `Guest`, `GuestTable`, `Tag`, `Constraint`,
  `RoomPlan`, `TableInventoryItem`, `CanvasLabel`, `LayoutVersion`,
  `LayoutTableSnapshot`, `LayoutLabelSnapshot`, `LayoutSeatSnapshot`
- **Migration:** `AppMigrationPlan` mit 4 lightweight stages (V1→V2→V3→V4→V5)
- **Pre-Launch-Backup** vor `ModelContainer`-Öffnung
- **`#if canImport(SwiftData)`** um `@Model`-Deklaration für Cross-Platform-Kompilierung

### LLM-Integration

- **Protocol:** `LLMClient` mit `chat(messages:temperature:maxTokens:jsonMode:)`
- **3 Implementierungen:** `LMStudioClient` (actor), `OpenRouterClient` (actor),
  `FoundationModelsClient` (struct)
- **Factory:** `LLMClientFactory` routet pro `AIFeature` (chat, tags, seating, funfact, importParse)
- **Decorator:** `LoggingLLMClient` wrapt jeden Client für Debug-Logging
- **API-Keys:** `KeychainStore` (enum), **nicht** UserDefaults

### Plattform-Guards

- **`#if os(macOS)`** um PDF/Canvas-Export (20 Dateien)
- **`#if canImport(AppKit)`** / **`canImport(UIKit)`** mit `PlatformImage`-Typealias
- **`canImport(FoundationModels)`** für Apple Intelligence (macOS 26+)
- **`canImport(Security)`** für Keychain, **`canImport(Contacts)`** für Kontakt-Picker

## Review-Richtlinien

**Grundsatz: Behavior first.** Ein Change der kompiliert und sauber aussieht,
aber einen bestehenden Workflow bricht, ist schlimmer als ein Style-Problem.

### P0 — Block den Merge

- **Behavioral Regression:** Der Change bricht oder verändert still einen
  bestehenden Prozess, UI-Flow oder eine Berechnung.
- **Security:** Hardcoded Secrets, API-Keys in UserDefaults (müssen in Keychain),
  Injection, unsafe Deserialization, PII-Logging.
- **Swift 6 Concurrency:**
  - `nonisolated(unsafe)` mutable statics ohne Lock (Data Race).
  - `@MainActor`-Verletzung: `ModelContext`-Mutation off-main.
  - Actor-Isolation umgangen (sync Zugriff auf actor state).
  - `Sendable`-Violation: non-Sendable über Isolation-Grenzen.
- **SwiftData:**
  - Force unwrap auf Optional-Relationships (`guest.table!.id`) ohne guard.
  - Schema-Änderung ohne `VersionedSchema` + `MigrationStage`.
  - `try?` auf Migration/Backup/Store-Copy ohne Logging.
- **Data Correctness:** Kapazitätsberechnung (60 cm/Person), Füllgrad,
  Constraint-Verletzungen, Off-by-one bei Tisch-Belegung.
- **Resource Leaks:** Offene `FileHandle`, `CGContext`, `ModelContext` ohne save.
- **Untested Behavior:** Neues/geändertes Behavior ohne Test-Coverage.

### P1 — Should Fix

- **Architektur:**
  - View enthält Geschäftslogik statt Service zu callen.
  - Service enthält UI-Code (`View`, `Color`, `Font`).
  - `FetchDescriptor` direkt in View statt `@Query`.
  - `@State` vs `@Binding` vs `@AppStorage` falsch eingesetzt.
- **Clean Code:**
  - Methoden/Types die zu viel machen (SRP-Verletzung).
  - Dateien > 400 Zeilen ohne `// MARK:`-Struktur.
  - Duplicierter Code über 3+ Dateien (z.B. `drawText` in PDF-Exportern).
  - Magic numbers statt benannter Konstanten.
- **Error Handling:**
  - `try?` auf kritischen Operationen (Migration, Backup, Import) ohne Logging.
  - `catch { print(error) }` ohne Kontext oder Recovery.
- **Tests:**
  - Integration-Test fehlt für Boundary-Crossing (SwiftData, HTTP, File I/O).
  - Unit-Test assertiert nichts Sinnvolles oder nur Happy Path.
  - LLM-Test ohne `StubLLM`-Mock (echte API-Calls).
- **Performance:**
  - N+1: `@Query` in Loop statt batch fetch.
  - `Array(guests).filter` statt `#Predicate`.
  - Allocation in Hot Path (SeatingOptimizer: 6000 Iterationen).
  - Missing `async` auf IO-bound work (LLM-Calls, File I/O).
- **Validation:**
  - CSV-Import, LLM-JSON-Response nicht validiert.
  - Keine Kapazitätsprüfung vor `GuestTable.guests.append`.
- **Magic Numbers:**
  - Scoring-Gewichte (`100`, `-500`, `70`, `40` in `SeatingGraph`, `HappinessScorer`).
  - SA-Parameter (`6000` Iterationen, `60.0` Temperatur, `0.05` cooling).
  - PDF-Dimensionen (`595×842` A4, `1191×842` A3).
  - Fix: `enum ScoringConstants { static let mustSitTogether = 100 }`.
- **Plattform-Guards:**
  - macOS-only Code ohne `#if os(macOS)`.
  - AppKit/UIKit direkt statt `PlatformImage`-Alias.

### Nicht flaggen

- Formatting (swift-format enforced in CI).
- `// MARK:`-Sections (Swift-Konvention).
- Deutsche Sprache in Code/Kommentaren (Repo-Konvention).
- `///` Doc-Kommentare auf public API.
- Pre-existing Issues im Diff (außer der Change macht sie schlimmer).

## Test-Konventionen

- **Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`), nicht XCTest.
- **Mock-Pattern:** `StubLLM`-Struct conforming to `LLMClient`.
- **HTTP-Mock:** `HTTPSession`-Protocol mit `StubSession`.
- **Thread-safe Capture:** `actor URLCapture` für async-Test-Assertions.
- **LLM-Tests:** `LLMClient`-Protocol mocken, JSON-Parsing und Fallbacks testen.
- **Prompt-Regression:** `systemPrompt`-Änderung erfordert Update in `eval/test_prompts.py`.
- **Coverage:** Happy Path + Failure + Edge Cases.

## Build & Test

```bash
swift build                                          # Bauen
swift test                                           # ~244 Tests in 45 Suites
swift-format lint --recursive Sources/ Tests/ --strict   # Lint (CI)
./scripts/build-macos-app.sh                         # .app-Bundle nach dist/
```

## CI (`.github/workflows/ci.yml`)

4 Jobs:
1. **build-and-test** (macos-15): swift-format lint + swift build + swift test
2. **ios-build** (macos-15): xcodebuild für iPad-Simulator (compile-only)
3. **prompt-eval** (ubuntu, nur main): Python deepeval gegen OpenRouter API
4. **release** (macos-15, nur main): .app-Bundle + DMG + GitHub Release

`prompt-eval` ist **nicht** prerequisite für release (LLM-Judge ist flaky).

## Conventions

- **Sprache:** Deutsch in Code, Kommentaren, Commits, Docs, UI, Error-Descriptions.
- **Kommentare:** sparsam. Begründungen als Methode/Spec, nicht Inline.
- **Commits:** pro logischem Arbeitspaket.
- **Tests:** Services/Models testbar, Views dünn.
- **Enums:** für namespaced Konstanten (`enum PDFColors`), nicht `class`/`struct`.
- **Error-Types:** `enum FooError: Error, LocalizedError` mit deutschem `errorDescription`.
