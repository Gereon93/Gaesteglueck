# 5. Bausteinsicht

## 5.1 Gesamtsystem — Paketstruktur

```
Sources/Gaesteglueck/
├── GaesteglueckApp.swift          # App-Entry-Point (@main)
├── ContentView.swift              # Root-View (NavigationSplitView)
│
├── Models/                        # SwiftData @Model + Enums/Structs
│   ├── Event.swift                # Root-Entity (Hochzeit)
│   ├── Guest.swift                # Gast mit allen Eigenschaften
│   ├── GuestTable.swift           # Tisch im Sitzplan
│   ├── Tag.swift                  # Beziehungs-Tag (Freundeskreis, Familie, ...)
│   ├── Constraint.swift           # Harte Sitz-Regeln (zusammen/getrennt)
│   ├── RoomPlan.swift             # Raum-Hintergrund + Skalierung
│   ├── TableInventoryItem.swift   # Verfügbares Tisch-Inventar
│   ├── CanvasLabel.swift          # Freie Text-Labels im Raum
│   ├── LayoutVersion.swift        # Snapshot-Versionierung des Layouts
│   ├── Schemas/                   # VersionedSchema V1–V5 + Migration
│   └── (Enums: DietaryPreference, FamilyRole, TagCategory, ...)
│
├── Services/                      # Geschäftslogik, Import, Export, KI
│   ├── LLM*.swift                 # KI-Client-Abstraktion
│   ├── CSVParser.swift            # RFC-4180 CSV-Parser
│   ├── ExcelParser.swift          # XLSX-Parser (CoreXLSX)
│   ├── GuestImporter.swift        # Import-Pipeline
│   ├── SeatingOptimizer.swift     # Algorithmischer Solver
│   ├── SeatingGraph.swift         # Beziehungs-Graph (gewichtet)
│   ├── HappinessScorer.swift      # Tisch-Qualitäts-Scoring
│   ├── PDFExporter.swift          # Text-basierte PDFs
│   ├── VisualSeatingPlanExporter.swift  # Visueller Sitzplan (A3)
│   └── (weitere Exporter, Services)
│
└── Views/                         # SwiftUI Views
    ├── DesignSystem/              # Wiederverwendbare UI-Komponenten
    ├── Canvas/                    # Raumplan-Canvas-Views
    └── (Feature-Views)
```

## 5.2 Datenmodell (SwiftData)

```
┌─────────────────────────────────────────────────────────────┐
│                          Event                              │
│  name, partnerNames, date, venue, roomDimensions            │
│  seatingRules (JSON), googleSheetURL, skippedSourceIDs      │
│                                                             │
│  ┌──────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │ labels   │  │ versions     │  │ roomPlan            │   │
│  │ [Canvas  │  │ [Layout      │  │ (RoomPlan)          │   │
│  │  Label]  │  │  Version]    │  │                     │   │
│  └──────────┘  └──────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌──────────────────┐  ┌──────────────────────────────────────┐
│    Guest         │  │    LayoutVersion                     │
│  firstName,      │  │  name, createdAt, isDirty            │
│  lastName,       │  │                                      │
│  dietary,        │  │  ┌──────────────┐ ┌──────────────┐  │
│  intolerances,   │  │  │ tables       │ │ seats        │  │
│  funFact,        │  │  │ [LayoutTable │ │ [LayoutSeat  │  │
│  familyRole,     │  │  │  Snapshot]   │ │  Snapshot]   │  │
│  partnerAssign,  │  │  └──────────────┘ └──────────────┘  │
│  rsvpStatus,     │  └──────────────────────────────────────┘
│  phone, seatIndex│
│  table ──────────────────────────────────────┐
└──────────────────┘                           │
         │                                     ▼
         │  (0..1)                    ┌──────────────────┐
         └───────────────────────────▶│   GuestTable     │
                                      │  shape, width,   │
                                      │  height, posX,   │
                                      │  posY, rotation, │
                                      │  combinationGroup│
                                      │  disabledSeats   │
                                      │  guests: [Guest] │
                                      └──────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐
│     Tag          │  │   Constraint     │  │ TableInventory│
│  name, category, │  │  type,           │  │  Item        │
│  color,          │  │  guestIDs,       │  │  shape,      │
│  guestIDs,       │  │  reason          │  │  dimensions, │
│  partnerAssign,  │  │                  │  │  count       │
│  isActive        │  │                  │  │              │
└──────────────────┘  └──────────────────┘  └──────────────┘
```

## 5.3 Service-Schicht

### KI-Services

```
┌─────────────────────────────────────────────────────────┐
│                    LLMClient (Protocol)                 │
│  chat(messages:temperature:maxTokens:jsonMode:)         │
│  prompt(system:user:temperature:jsonMode:)              │
└─────────────────────────────────────────────────────────┘
         ▲                  ▲                  ▲
         │                  │                  │
┌────────────────┐ ┌────────────────┐ ┌────────────────────┐
│ LMStudioClient │ │ OpenRouter     │ │ FoundationModels   │
│ (Actor, lokal) │ │ Client (Actor) │ │ Client (macOS 26+) │
└────────────────┘ └────────────────┘ └────────────────────┘
         ▲                  ▲                  ▲
         └──────────────────┼──────────────────┘
                            │
                  ┌────────────────────┐
                  │ LLMClientFactory   │
                  │ (Provider-Routing) │
                  └────────────────────┘
                            │
                  ┌────────────────────┐
                  │ LoggingLLMClient   │
                  │ (Decorator)        │
                  └────────────────────┘
```

### KI-Feature-Services

| Service | Provider-Feature | Aufgabe |
|---------|-----------------|---------|
| `LLMGuestParser` | `.importParse` | Unstrukturierte Anmeldungen → strukturierte Gäste |
| `TagSuggestionService` | `.tags` | Tags aus Beziehungs-Beschreibungen ableiten |
| `LLMSeatingPlanner` | `.seating` | Sitzplan-Vorschlag generieren |
| `SaalKonfigurator` | `.seating` | Tisch-Konfiguration aus Inventar vorschlagen |
| `SitzplanCoPilot` | `.chat` | Interaktiver Chat für Sitzplan-Manipulation |
| `FunFactValidator` | `.funfact` | Fun-Facts auf Qualität prüfen (good/generic) |
| `FunFactNormalizer` | `.funfact` | Fun-Facts in 1. Person normalisieren |
| `FunFactReminderGenerator` | `.funfact` | Persönliche Erinnerungen generieren |

### Import-Pipeline

```
Datei (CSV/XLSX) oder Google Sheets URL
    │
    ▼
┌─────────────────────────────────┐
│ CSVParser / ExcelParser /       │
│ GoogleSheetsImporter            │
│ → [RegistrationRow]             │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│ LLMGuestParser (KI)             │
│ oder fallbackParse (heuristisch)│
│ → [ImportedGuest]               │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│ ImportMatcher                   │
│ (sourceID-basiertes Matching)   │
│ → new / update / skip           │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│ ImportPreviewView               │
│ (User prüft, übernimmt, korrig.)│
│ → Guest-Modelle in SwiftData    │
└─────────────────────────────────┘
```

### Solver-Architektur

```
┌─────────────────────────────────┐
│       SeatingOptimizer          │
│                                 │
│  Phase 1: Greedy                │
│  ├── Pinned guests platzieren   │
│  ├── Constraint-Cluster (BFS)   │
│  ├── Cluster atomar zuweisen    │
│  └── Rest nach Affinität        │
│                                 │
│  Phase 2: Simulated Annealing   │
│  ├── 6000 Iterationen           │
│  ├── Temp: 60 → 0.05           │
│  ├── Swap / Move-Operationen    │
│  └── Hard-Constraint-Gate       │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│       SeatingGraph              │
│  Gewichtetes Beziehungs-Graph   │
│                                 │
│  Kanten:                        │
│  ├── Constraint: +100 / -500   │
│  ├── Familie: +70              │
│  ├── Tag: +40                  │
│  ├── Partner-Paar: +150        │
│  ├── Kind-Elternteil: +100/+30 │
│  ├── Brücken-Person: +10       │
│  └── Kindertisch-Bonus: ±200   │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│      HappinessScorer            │
│  Tisch-Qualitäts-Scoring:       │
│  Tag-Kohäsion, Partner-Mix,     │
│  Füllgrad, Generationen, Diet   │
└─────────────────────────────────┘
```

### Export-Services

| Service | Format | Inhalt |
|---------|--------|--------|
| `PDFExporter` | PDF (A4) | Tischlisten + Caterer-Zusammenfassung |
| `VisualSeatingPlanExporter` | PDF (A3) / PNG | Visueller Raumplan mit Tischen, Sitzen, Namen |
| `PosterExporter` | PDF (A3) | Delegiert an VisualSeatingPlanExporter |
| `TableCardExporter` | PDF (A4) | Tischkarten (4/A4, gefaltet) |
| `FunFactGameCardsExporter` | PDF (A4) | Fun-Fact-Spielkarten (8/A4 + Lösung) |
| `SpeechGuestExporter` | Markdown | Rede-Gastliste nach Partner/Tag sortiert |
| `PhoneVCardExporter` | vCard 3.0 | Telefonnummern für iCloud-Import |
| `CanvasImageExporter` | PNG | Canvas-Render als Bild |

## 5.4 View-Hierarchie

```
GaesteglueckApp (@main)
└── ContentView
    ├── (keine Events) → OnboardingWizardView
    └── (Events vorhanden) → NavigationSplitView
        ├── Sidebar: AppSidebar
        │   ├── Event-Header (Namen, Datum, Location)
        │   ├── Navigation:
        │   │   ├── Dashboard
        │   │   ├── Gästeliste
        │   │   ├── Beziehungen (Tags)
        │   │   ├── Sitzplan
        │   │   ├── Export
        │   │   └── Einstellungen
        │   └── KI-Status-Footer
        │
        └── Detail (Switch auf AppSection):
            ├── DashboardView
            ├── GuestListView → GuestFormView (Sheet)
            ├── RoomCanvasView
            │   ├── SeatingPlanRenderView (Canvas)
            │   │   ├── TableCanvasItemView
            │   │   ├── SeatChipView
            │   │   ├── CanvasLabelsLayer
            │   │   └── ViolationBannerView
            │   ├── SitzplanCoPilotPanel
            │   └── FloorPlanSetupView
            ├── TagListView → TagDetailView → TagGeneratorView
            ├── KIWizardView → KIChatView → AISuggestionSheet
            ├── ExportView (nur macOS)
            └── SettingsView
```

## 5.5 Design-System

```
DesignSystem/
├── Tokens.swift           # Zentrale Design-Tokens (Farben, Typo, Spacing)
├── Card.swift             # Karten-Container
├── Avatar.swift           # Initialen-Avatar
├── TagChip.swift          # Tag-Pill mit Farb-Punkt
├── StatCard.swift         # Statistik-Karte
├── AISuggestionCard.swift # KI-Vorschlags-Karte
├── ConflictBanner.swift   # Konflikt-Warnung
├── EmptyStateCard.swift   # Empty-State mit CTA
├── WarmButtonStyle.swift  # Warmer Button-Stil
├── ScreenToolbar.swift    # Konsistenter Toolbar
└── WavePattern.swift      # Deko-Hintergrund-Muster
```
