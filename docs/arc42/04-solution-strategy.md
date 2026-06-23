# 4. Lösungsstrategie

## Grundlegende Entscheidungen

### 1. Native macOS-App mit SwiftUI

**Entscheidung:** Vollständig native App mit SwiftUI, keine Electron- oder Web-basierte Lösung.

**Begründung:** Die Zielgruppe (Mac-besitzende DIY-Hochzeitsplaner) erwartet eine native App.
SwiftUI ermöglicht das warme, persönliche Design nach Apple-HIG mit minimalem Aufwand.
Native Integration von Contacts, Keychain und PDF-Rendering.

### 2. Local-first, Privacy-by-Design

**Entscheidung:** Alle Daten in SwiftData lokal auf dem Mac. Keine Cloud, kein Sync, kein Account.

**Begründung:** Gästelisten sind intim. Das Kernversprechen „Privat by default" erfordert,
dass Daten den Mac nie verlassen. KI ist optional und läuft bevorzugt lokal.

### 3. Optionale KI mit Fallback-Strategie

**Entscheidung:** Jedes KI-Feature hat einen deterministischen Fallback.

| Feature | KI-Pfad | Fallback |
|---------|---------|----------|
| Gast-Parsing | LLM (strukturierte Extraktion) | Regex/heuristischer Parser |
| Tag-Vorschläge | LLM (Beziehungs-Analyse) | `LocalTagDeriver` (Keyword-Heuristik) |
| Sitzplan | LLM (kontextueller Vorschlag) | `SeatingOptimizer` (Simulated Annealing) |
| Fun-Fact-Validierung | LLM (good/generic) | Manuelle Prüfung |
| Co-Pilot-Chat | LLM (interaktiv) | — (kein Fallback) |

**Begründung:** KI ist ein Feature, keine Voraussetzung. Die App muss ohne KI voll funktionsfähig sein.

### 4. Provider-Abstraktion für KI

**Entscheidung:** `LLMClient`-Protocol mit drei Implementierungen (LMStudio, OpenRouter, FoundationModels).

**Begründung:** Ermöglicht pro Feature einen eigenen Provider. Fallback-Ketten
(OpenRouter ohne Key → LM Studio). Einfaches Hinzufügen neuer Provider.

### 5. Versioned Schema mit Pre-Launch-Backups

**Entscheidung:** `VersionedSchema` (V1–V5) mit automatischen Backups vor jeder Migration.

**Begründung:** Schema-Änderungen dürfen nie Datenverlust verursachen. Pre-Launch-Backups
mit Retention 3 als Sicherheitsnetz. Manual Restore via Settings möglich.

### 6. Algorithmischer Solver als Rückgrat

**Entscheidung:** 2-Phasen-Algorithmus (Greedy + Simulated Annealing) für automatische Sitzverteilung.

**Begründung:** Funktioniert deterministisch, ohne KI, testbar. Graph-basiertes Scoring
mit gewichteten Kanten für Familien, Tags, Constraints, Brücken-Personen.

### 7. MV-Architektur (Model-View, ohne ViewModel)

**Entscheidung:** Views queryn SwiftData direkt via `@Query`, Services sind reine Swift-Types.

**Begründung:** SwiftUI + SwiftData machen ViewModels überflüssig. `@Query` reagiert
automatisch auf Datenänderungen. Services sind als `enum`/`struct`/`actor` realisiert —
kein DI-Framework nötig.

### 8. Token-effiziente LLM-Prompts

**Entscheidung:** Stabile Kurz-IDs (G1, G2, T1, T2) statt UUIDs in Prompts.

**Begründung:** Spart Token, verhindert Copy-Fehler des Modells bei UUIDs.
JSON-Extraktion mit mehreren Fallback-Strategien für robuste LLM-Auswertung.
