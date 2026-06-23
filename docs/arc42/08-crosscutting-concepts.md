# 8. Querschnittliche Konzepte

## 8.1 Persistenz

### SwiftData mit VersionedSchema

Das Datenmodell wird über `VersionedSchema` versioniert. Jede Schema-Änderung
erzeugt eine neue Version (V1 → V5). SwiftData führt lightweight migrations
automatisch durch.

**Speicherort:** `~/Library/Application Support/Gaesteglueck/Gaesteglueck.store`

**Safety-Net:**
- Pre-Launch-Backup: Kopie des Stores vor jeder Migration (Retention 3)
- Manual Restore: Über Settings → Daten → Backup wiederherstellen
- Legacy-Migration: `default.store` wird an neuen Standort kopiert

### Backup-Strategie

```
Backups/
├── yyyy-MM-dd_HH-pre-launch.store       # Automatisch vor Launch (max. 1 pro Stunde)
├── yyyy-MM-dd_HH-pre-launch.store-shm
├── yyyy-MM-dd_HH-pre-launch.store-wal
├── yyyy-MM-dd_HH-mm-ss-Gaesteglueck.store  # Manuell via Settings
├── yyyy-MM-dd_HH-mm-ss-Gaesteglueck.store-shm
└── yyyy-MM-dd_HH-mm-ss-Gaesteglueck.store-wal
```

## 8.2 Sicherheit

### API-Keys

API-Keys (OpenRouter) werden im **macOS Keychain** gespeichert
(`kSecClassGenericPassword`). Migration von UserDefaults → Keychain beim
ersten Launch nach dem Upgrade.

### Datenschutz

- Keine Daten verlassen den Mac (außer optionale OpenRouter-API-Calls)
- Keine Telemetrie, kein Analytics, kein Crash-Reporting
- LM Studio läuft komplett lokal
- Google-Sheets-Import nur über öffentliche CSV-URL (kein OAuth)

### Contacts-Zugriff

Die App nutzt den eingeschränkten Kontaktzugriff (`.limited`) — der User
kann der App einzelne Kontakte freigeben statt des ganzen Adressbuchs.

## 8.3 Concurrency

### Swift 6 Strikte Concurrency

- **Views:** `@MainActor` — alle UI-Updates auf dem Main-Thread
- **LLM-Clients:** `actor` — thread-safe durch Actor-Isolation
- **Services:** `enum`/`struct` mit `static func` — stateless, Sendable
- **Model-Mutationen:** `@MainActor` — SwiftData-Operationen auf Main
- **Snapshots:** `GuestSnapshot` (Sendable struct) für Off-Main-Verarbeitung

### Actor-Hierarchie

```
@MainActor
├── Views (alle)
├── Model-Mutationen
└── SwiftData ModelContext

Actor
├── LMStudioClient
├── OpenRouterClient
└── GoogleSheetsImportFlow

Struct / Decorator (keine Actor-Isolation)
├── LoggingLLMClient (Wrapper-Struct, leitet Calls durch)
└── Services (enum/struct, stateless)

nonisolated
├── SeatingOptimizer
├── SeatingGraph
└── HappinessScorer
```

## 8.4 Fehlerbehandlung

### Strategie

- **`try?` für nicht-kritische Operationen:** PDF-Export, Logging, UI-Animationen
- **`do/catch` für kritische Operationen:** Import, LLM-Calls, Datei-I/O
- **`fatalError()` nur im App-Init:** ModelContainer-Erstellung (App ohne DB nutzlos)
- **Keine `try!` oder `as!`:** Codebase nutzt ausschließlich sicheres Unwrapping

### LLM-Fehlerbehandlung

```
LLM-Call
    │
    ├── Erfolg → JSON parsen → Validieren → Anwenden
    │
    ├── Netzwerk-Fehler → User-Info + Fallback anbieten
    │
    ├── JSON-Parse-Fehler → Fallback-Strategien:
    │   ├── Fenced code block extrahieren
    │   ├── Erstes {...} finden
    │   ├── Erstes [...] finden
    │   └── Regex-basierte Extraktion
    │
    └── Validierungs-Fehler → Teil-Ergebnis + Warnung anzeigen
```

## 8.5 Design-System

### Farbpalette

| Token | Light | Dark | Verwendung |
|-------|-------|------|------------|
| Akzent (Rose) | `#C8788C` | `#E0A0B2` | Buttons, aktive Items |
| Sekundär (Sage) | `#7A8B6C` | `#9DAE8E` | Erfolgs-States |
| Vegan | Gold | Gold | Diet-Indikator |
| Vegetarisch | Grün | Grün | Diet-Indikator |
| Allergie | Rot | Rot | Allergie-Markierung |

### Typografie

- **UI-Standard:** SF Pro
- **Headlines:** SF Pro Rounded (Persönlichkeit)
- **Display:** New York (Serif, für Hero-Elemente)
- **Dynamic Type:** SwiftUI-Defaults respektiert

### Komponenten

Card, Avatar, TagChip, StatCard, AISuggestionCard, ConflictBanner,
EmptyStateCard, WarmButtonStyle, WavePattern, ScreenToolbar

## 8.6 Plattform-Abstraktion

```swift
// Conditional Compilation für macOS / iPadOS
#if canImport(SwiftUI)
// SwiftUI-Views
#endif

#if os(macOS)
// AppKit-spezifisch: PDF-Export, Contacts, Keychain
#endif

#if canImport(AppKit)
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
typealias PlatformImage = UIImage
#endif
```

## 8.7 Testing

### Test-Struktur

- **225 Tests in 44 Suites** (`swift test`)
- **Model-Tests:** SwiftData-Modelle, Constraints, Kapazitäten
- **Service-Tests:** Parser, Solver, Exporter, LLM-Clients
- **View-Tests:** Layout-Berechnungen (SeatLayout, Name-Offset)

### Prompt-Evaluation (CI)

```
eval/
├── extract_prompts.py    # Prompts aus Swift-Quellen extrahieren
├── openrouter.py         # API-Client (SUT + Judge)
├── test_prompts.py       # pytest + deepeval GEval
└── golden cases          # Kuratierte Test-Inputs/Outputs
```

Getestet werden: Fun-Fact-Normalizer (JSON, 1. Person, Semantik) und
Fun-Fact-Validator (good/generic-Verdict).

## 8.8 Spätabsage-Handling

Ein Gast der absagt, nachdem der Caterer die Gästezahl kennt, wird nicht
gelöscht sondern auf „Abgesagt" gesetzt:

```
Gast (confirmed, table assigned)
    │
    ▼ Absage
    │
Gast (declined, table bleibt zugewiesen)
    │
    ├── Sitzplatz wird frei (neu vergebbar)
    ├── Tisch-Badge: "N abgemeldet"
    └── Caterer-Export: Wegfall mit Name · Tisch · Menü · Allergie
```

Technisch: Abgeleiteter Zustand aus `rsvpStatus == .declined && table != nil`.
Kein separates Datenbank-Feld.
