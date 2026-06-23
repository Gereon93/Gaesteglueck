# 6. Laufzeitsicht

## 6.1 App-Start

```
App Launch
    │
    ▼
┌──────────────────────────────────┐
│ GaesteglueckApp.init()           │
│                                  │
│ 1. API-Key-Migration             │
│    (UserDefaults → Keychain)     │
│                                  │
│ makeContainer():                 │
│ 2. Pending Restore prüfen        │
│    (UserDefaults-Flag) – VOR     │
│    dem Öffnen des Stores         │
│ 3. Legacy-Store migration        │
│    (default.store → neuer Pfad)  │
│ 4. Pre-Launch-Backup             │
│    (store + WAL → Backups/)      │
│ 5. ModelContainer erstellen      │
│    (Schema V5, alle Migrationen) │
│ 6. Legacy-Tag-Fixup              │
│    (falsche Kategorien korr.)    │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ ContentView                      │
│                                  │
│ Event vorhanden?                 │
│ ├── Nein → OnboardingWizardView │
│ └── Ja  → NavigationSplitView   │
└──────────────────────────────────┘
```

## 6.2 Gast-Import (CSV)

```
User wählt Datei
    │
    ▼
┌──────────────────────────────────┐
│ CSVParser.parse(data:)           │
│                                  │
│ 1. Delimiter erkennen            │
│    (Tab > Semikolon > Komma)     │
│ 2. Spalten fuzzy-matchen         │
│    (Familienname, Anzahl, ...)   │
│ 3. RegistrationRows extrahieren  │
│ 4. sourceID generieren           │
│    (email > phone > timestamp)   │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ LLMGuestParser.parse(rows:)      │
│                                  │
│ Pro Batch (20 Gäste):            │
│ 1. Prompt mit Batch bauen        │
│ 2. LLM-Call (JSON-Mode)          │
│ 3. JSON extrahieren (Fallbacks)  │
│ 4. ImportedGuests validieren     │
│                                  │
│ Fallback: heuristicParse(rows:)  │
│    (Regex-basiert, ohne KI)      │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ ImportPreviewView                │
│                                  │
│ Pro Anmeldung:                   │
│ ├── Anzeigen (Original + Gäste)  │
│ ├── Übernehmen / Korrigieren     │
│ └── Überspringen                 │
│                                  │
│ Batch-Action: Alle übernehmen    │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ ImportMatcher                    │
│                                  │
│ Pro ImportedGuest:               │
│ 1. sourceID-Match in DB          │
│ 2. Falls neu: Guest erstellen    │
│ 3. Falls Update: Guest mergen    │
│ 4. modelContext.save()           │
└──────────────────────────────────┘
```

## 6.3 Sitzplan generieren (KI)

```
User klickt "Plan vorschlagen"
    │
    ▼
┌──────────────────────────────────┐
│ GroupAnalyzer                    │
│                                  │
│ 1. Tag-Cluster analysieren       │
│ 2. Brücken-Personen erkennen     │
│ 3. Familien-Gruppen bilden       │
│ 4. Kontext-String aufbauen       │
│    (G/T-IDs, Tags, Constraints)  │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ LLMSeatingPlanner                │
│                                  │
│ 1. System-Prompt + Kontext       │
│ 2. LLM-Call (JSON-Mode)          │
│ 3. JSON: plan[{table,guests,     │
│    reason}] extrahieren          │
│ 4. Post-Processing:              │
│    ├── Überkapazität korrigieren │
│    ├── Duplikate erkennen        │
│    ├── Hard-Constraints prüfen   │
│    └── Unplatzierte melden       │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ AISuggestionSheet                │
│                                  │
│ User:                            │
│ ├── Übernehmen → Sitzplan anwenden│
│ ├── Anpassen → Co-Pilot-Chat     │
│ └── Verwerfen                    │
└──────────────────────────────────┘
```

## 6.4 Sitzplan generieren (Algorithmus)

```
User klickt "Auto-Platzierung"
    │
    ▼
┌──────────────────────────────────┐
│ SeatingOptimizer                 │
│                                  │
│ Phase 1: Greedy                  │
│ 1. Pinned guests fixieren        │
│ 2. Hard-Constraint-Cluster (BFS) │
│ 3. Cluster sortieren (größte z.) │
│ 4. Pro Cluster: best-fit Tisch   │
│    nach Affinität, atomar setzen │
│ 5. Rest-Gäste nach Affinität     │
│                                  │
│ Phase 2: Simulated Annealing     │
│ 1. Start: Phase-1-Ergebnis       │
│ 2. 6000 Iterationen              │
│ 3. Temp: 60 → 0.05 (exponent.)   │
│ 4. Zufällige Operation:          │
│    ├── Swap zweier Gäste         │
│    └── Move eines Gastes         │
│ 5. Akzeptanz: Δ > 0 oder         │
│    random < exp(Δ/T)             │
│ 6. Hard-Constraint-Verstoß →     │
│    Kandidat ablehnen             │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ SeatingGraph.score()             │
│                                  │
│ Pro Tisch:                       │
│ 1. Kanten-Summe aller Gäste      │
│    am Tisch (inner-table)        │
│ 2. Füllgrad-Bonus (80-100%:+15)  │
│ 3. Child-Table-Bonus (±200)      │
│ 4. Constraint-Verstoß → -1000    │
└──────────────────────────────────┘
```

## 6.5 Co-Pilot-Chat

```
User tippt Nachricht ("Patrick auf T2")
    │
    ▼
┌──────────────────────────────────┐
│ SitzplanCoPilot                  │
│                                  │
│ 1. Kontext aufbauen:             │
│    ├── Tischliste (T1, T2, ...)  │
│    ├── Gästeliste (G1, G2, ...)  │
│    ├── Aktuelle Zuordnung        │
│    └── Chat-History              │
│ 2. LLM-Call (JSON-Mode)          │
│ 3. Antwort parsen:               │
│    actions[{type, guest, table}] │
│    ├── moveGuest                 │
│    ├── swapGuests                │
│    └── unassignGuest             │
│ 4. Text-Antwort anzeigen         │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ SitzplanCoPilotApplier           │
│                                  │
│ Pro Action:                      │
│ 1. Guest/Tisch auflösen (G/T→ID) │
│ 2. Aktion auf Model anwenden     │
│ 3. modelContext.save()           │
└──────────────────────────────────┘
```

## 6.6 PDF-Export

```
User klickt "Exportieren"
    │
    ▼
┌──────────────────────────────────┐
│ ExportView                       │
│                                  │
│ Auswahl:                         │
│ ├── Sitzplan-PDF (A4, Text)      │
│ ├── Visueller Sitzplan (A3, PDF) │
│ ├── Poster (A3)                  │
│ ├── Tischkarten (A4, gefaltet)   │
│ ├── Fun-Fact-Spielkarten (A4)    │
│ ├── Caterer-Zusammenfassung      │
│ ├── Rede-Gastliste (Markdown)    │
│ └── Telefonnummern (vCard)       │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ PDFExporter / Visual...Exporter  │
│                                  │
│ 1. CGContext für PDF erstellen   │
│ 2. Pro Seite:                    │
│    ├── Titel / Header            │
│    ├── Content zeichnen          │
│    │   ├── drawText()            │
│    │   ├── drawRect()            │
│    │   └── drawImage()           │
│    └── startNewPage()            │
│ 3. CGContext schließen           │
│ 4. Datei speichern               │
└──────────────────────────────────┘
```

## 6.7 Schema-Migration

```
App Launch
    │
    ▼
┌──────────────────────────────────┐
│ Pre-Launch-Backup                │
│                                  │
│ 1. Backups/ zählen               │
│ 2. Älteste löschen wenn > 3      │
│ 3. Store + WAL kopieren          │
│    → Backups/pre-launch-{n}.store│
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ ModelContainer(schema: V5)       │
│                                  │
│ SwiftData führt automatisch:     │
│ V1 → V2 → V3 → V4 → V5         │
│ (alles lightweight migrations)   │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ Post-Migration Fixup             │
│                                  │
│ fixupLegacyTagCategories():      │
│  "Familienfreunde" etc. von      │
│  .family → .friendGroup          │
└──────────────────────────────────┘
```
