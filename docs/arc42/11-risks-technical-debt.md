# 11. Risiken und technische Schulden

## 11.1 Große Dateien (Maintainability)

**Problem:** 14 Dateien > 500 Zeilen, davon 4 > 1000 Zeilen.

| Datei | Zeilen | Problem |
|-------|--------|---------|
| `GuestListView.swift` | 1833 | Guest-Liste + Filter + Inspector + FunFact-Check |
| `ImportPreviewView.swift` | 1221 | Import-Preview + Edit-Sheet + Parsing |
| `SettingsView.swift` | 1084 | Alle Settings in einer View |
| `ExportView.swift` | 1054 | Alle Export-Optionen + Preview |
| `VisualSeatingPlanExporter.swift` | 1031 | Komplettes PDF-Rendering in einer Datei |

**Risiko:** Schwierige Navigation, hohe kognitive Last, Merge-Konflikte.

**Empfehlung:** Views in Sub-Views aufteilen. Exporter in spezialisierte Dateien zerlegen.

## 11.2 Duplicierter Code (Wartbarkeit)

**Problem:** Mehrere Copy-Paste-Muster über 5+ Dateien.

### 11.2.1 `drawText`-Helper (5 Dateien)

Identische PDF-Text-Zeichenfunktion in:
- `PDFExporter.swift:65`
- `FunFactWorklistExporter.swift:35`
- `FunFactGameCardsExporter.swift:193`
- `TableCardExporter.swift:166`
- `VisualSeatingPlanExporter.swift:1026`

**Empfehlung:** Extraktion in `PDFDrawingUtils` oder Extension auf `CGContext`.

### 11.2.2 A4-Page-Rect (4 Dateien)

`CGRect(x: 0, y: 0, width: 595, height: 842)` in 4 Dateien.

**Empfehlung:** Konstante in `PDFColors` oder `PDFConstants`.

### 11.2.3 Accent-Color RGB (7 Stellen)

`(0.78, 0.47, 0.55)` wird inline erzeugt statt `PDFColors.accent` zu nutzen.

**Empfehlung:** Konsistent `PDFColors.accent` verwenden.

### 11.2.4 Tag-Weight-Konstanten (2 Dateien)

`family ? 70 : 40` in `SeatingGraph.swift:38` und `HappinessScorer.swift:15`.

**Empfehlung:** Konstanten in `ScoringConstants`-Enum.

## 11.3 Magic Numbers (Lesbarkeit)

**Problem:** ~40+ Magic Numbers, besonders im Scoring und Layout.

### Scoring-Konstanten (nicht benannt)

| Datei | Wert | Bedeutung |
|-------|------|-----------|
| `SeatingGraph.swift` | 100, -500 | Constraint-Gewichte |
| `SeatingGraph.swift` | 70, 40 | Tag-Gewichte |
| `SeatingGraph.swift` | 150 | Partner-Gewicht |
| `SeatingGraph.swift` | 200, -200 | Child-Table-Bonus |
| `HappinessScorer.swift` | 15, 5, 20, 30 | Fill/Bridge/Generation-Boni |
| `SeatingOptimizer.swift` | 6000, 60, 0.05 | SA-Parameter |

**Empfehlung:** Benannte Konstanten in `ScoringConstants` und `SimulatedAnnealingConfig`.

### Layout-Dimensionen (verstreut)

PDF-Seitengrößen, Margins, Font-Größen über Exporter verstreut.

**Empfehlung:** `PDFLayout`-Struct mit benannten Konstanten.

## 11.4 Force Unwraps (Crash-Risiko)

**Problem:** 11 Force-Unwraps, meist guardet durch Logik aber fragil.

| Datei | Zeile | Code |
|-------|-------|------|
| `LayoutVersionStore.swift` | 56 | `g.table!.id` |
| `SeatingOptimizer.swift` | 27 | `guest.table!.id` |
| `TafelLayout.swift` | 65, 80, 86, 90, 91, 95, 96 | `ranges.last!`, `counter[id]!`, `sorted.first!` |
| `SeatingGraph.swift` | 51 | `$0.familyID!` |
| `FunFactNormalizer.swift` | 79 | `idMap[key]!` |

**Risiko:** Crash wenn Invariante sich ändert (z.B. Guest ohne Table in Snapshot).

**Empfehlung:** `guard let` oder `if let` mit sinnvollem Fallback.

## 11.5 `nonisolated(unsafe)` Statics (Concurrency)

**Problem:** 5 mutable static vars umgehen Swift 6 Concurrency-Checks.

| Datei | Variable | Risiko |
|-------|----------|--------|
| `GaesteglueckApp.swift:10` | `didActivate` | Gering (einmalig gesetzt) |
| `VisualSeatingPlanExporter.swift:107-109` | `currentDisplayNames`, `currentRenderScale`, `currentLegend` | **Hoch** (Race bei parallelen Exports) |
| `GuestTable.swift:42` | `_activeRules` | Mittel (könnte bei schnellen Änderungen racen) |

**Risiko:** Data race wenn zwei Exports gleichzeitig laufen.

**Empfehlung:** Render-State als Parameter durchreichen statt static var.

## 11.6 `try?` Error-Silencing (Debuggability)

**Problem:** 66 `try?`-Stellen, viele ohne Logging.

**Kritische Stellen:**
- `LLMDebugLog.swift:61-63`: Drei `try?` auf FileHandle-Operationen
- `GaesteglueckApp.swift:79`: `try? fm.copyItem` bei Legacy-Migration

**Risiko:** Fehler werden verschluckt, Debugging schwierig.

**Empfehlung:** Zumindest `os_log` für kritische `try?`-Stellen.

## 11.7 Fehlende Features (aus VISION.md)

| Feature | Status | Risiko |
|---------|--------|--------|
| FA-2.7: Spalten-Mapping-UI | ⬜ Offen | Andere Formate nicht importierbar |
| FA-7.2: Empty States | ⬜ Teilweise | UX für Erst-Nutzer unklar |
| FA-7.3: In-App-Hilfe | ⬜ Offen | Neue User brauchen Anleitung |
| FA-1.5: Multi-Event-Support | ⬜ Offen | Datenmodell bereit, UI fehlt |

## 11.8 Keine App-Store-Signierung

**Problem:** Ad-hoc signiert, nicht notarisiert. Gatekeeper blockt beim ersten Start.

**Auswirkung:** User muss `xattr -dr com.apple.quarantine` ausführen oder
"Trotzdem öffnen" klicken.

**Risiko:** Nicht-technische User sind überfordert.

**Empfehlung:** Apple Developer Account ($99/Jahr) für Notarisierung.

## 11.9 iPad-Target: Kein PDF-Export

**Problem:** PDF/PNG-Export auf iPad nicht implementiert.

**Auswirkung:** iPad-User können Sitzplan nicht als PDF exportieren.

**Empfehlung:** iPad-spezifische Export-Implementierung (UIKit-basiert).

## 11.10 Keine Integration-Tests für LLM-Clients

**Problem:** `LMStudioClientTests` und `OpenRouterClientTests` existieren,
aber keine Integration-Tests gegen echte API.

**Risiko:** API-Änderungen werden nicht erkannt.

**Empfehlung:** Mock-Server oder VCR-basierte Tests für API-Regression.
