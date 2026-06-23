# 10. Qualitätsszenarien

## 10.1 Datensicherheit

### Szenario: Crash während Migration

**Ablauf:**
1. App startet, Schema-Migration V4 → V5 beginnt
2. Crash (Stromausfall, Force-Quit)
3. App startet neu

**Erwartung:**
- Pre-Launch-Backup wurde vor Migration erstellt
- Migration wird erneut versucht (SwiftData retry)
- Falls Migration fehlschlägt: Manual Restore aus Backup via Settings

**Status:** ✅ Implementiert (Pre-Launch-Backup + Restore-Mechanismus)

### Szenario: Korrupter Store

**Ablauf:**
1. Store-Datei beschädigt (Disk-Fehler)
2. App startet

**Erwartung:**
- ModelContainer-Erstellung schlägt fehl
- `fatalError()` mit klarer Fehlermeldung
- User kann Backup aus `Backups/` manuell wiederherstellen

**Status:** ✅ Implementiert (fatalError im App-Init)

## 10.2 Performance

### Szenario: 200 Gäste, 30 Tische

**Ablauf:**
1. User importiert 200 Gäste
2. Platziert 30 Tische im Raum
3. Klickt "Auto-Platzierung"

**Erwartung:**
- Import: <5s (ohne KI), <30s (mit KI)
- Auto-Platzierung: <2s (Algorithmus), <30s (KI)
- Canvas: 60fps beim Drag/Resize
- UI bleibt responsiv (async/await, MainActor)

**Status:** ✅ Implementiert (SeatingOptimizer mit 6000 Iterationen in <1s)

### Szenario: Große PDF-Exporte

**Ablauf:**
1. User exportiert visuellen Sitzplan (A3, 200 Gäste, 30 Tische)

**Erwartung:**
- PDF-Generierung: <5s
- Dateigröße: <10MB
- Qualität: Druckfertig (300 DPI)

**Status:** ✅ Implementiert (Core Graphics, Core Text)

## 10.3 KI-Robustheit

### Szenario: LM Studio offline

**Ablauf:**
1. User klickt "Plan vorschlagen"
2. LM Studio läuft nicht

**Erwartung:**
- Fehlermeldung: "LM Studio antwortet gerade nicht"
- Fallback anbieten: "Plan auch ohne KI berechnen"
- Algorithmus als Plan B (SeatingOptimizer)

**Status:** ✅ Implementiert (Fallback-Strategie in allen KI-Services)

### Szenario: LLM liefert ungültiges JSON

**Ablauf:**
1. LLM-Call erfolgreich
2. Antwort ist kein valides JSON

**Erwartung:**
- Mehrere Fallback-Strategien:
  - Fenced code block extrahieren
  - Erstes `{...}` oder `[...]` finden
  - Regex-basierte Extraktion
3. Falls alle fehlschlagen: Fehlermeldung + Retry anbieten

**Status:** ✅ Implementiert (mehrschichtige JSON-Extraktion)

### Szenario: LLM verletzt Hard-Constraints

**Ablauf:**
1. LLM schlägt Sitzplan vor
2. Vorschlag verletzt `mustNotSitTogether`

**Erwartung:**
- Post-Processing erkennt Verstoß
- Constraint wird erzwungen (Gast umsetzen)
- User wird informiert ("X wurde umgesetzt, weil...")

**Status:** ✅ Implementiert (Hard-Constraint-Gate in LLMSeatingPlanner)

## 10.4 Import-Robustheit

### Szenario: Re-Import mit Änderungen

**Ablauf:**
1. User importiert CSV mit 50 Gästen
2. 2 Wochen später: Neue CSV mit 55 Gästen (3 neue, 2 Änderungen)

**Erwartung:**
- sourceID-Matching erkennt 50 bestehende Gäste
- 3 neue Gäste werden erstellt
- 2 Änderungen werden gemergt (nicht dupliziert)
- Unveränderte Gäste werden übersprungen (kein unnötiges Update)

**Status:** ✅ Implementiert (ImportMatcher mit sourceID-Priorität)

### Szenario: Google Sheets mit Sonderzeichen

**Ablauf:**
1. Google Sheet enthält Multi-Line-Zellen (Newlines in Fun Facts)
2. CSV-Export hat Quoting

**Erwartung:**
- RFC-4180-Parser erkennt Quoting korrekt
- Multi-Line-Zellen werden zusammengehalten
- Delimiter-Auto-Detect (Tab > Semikolon > Komma)

**Status:** ✅ Implementiert (CSVParser mit RFC-4180-Support)

## 10.5 Benutzerfreundlichkeit

### Szenario: Erst-Nutzer ohne Anleitung

**Ablauf:**
1. User öffnet App zum ersten Mal
2. Hat keine Erfahrung mit Sitzplanern

**Erwartung:**
- Onboarding-Wizard führt durch Setup (Namen, Datum, Location)
- Empty States erklären nächsten Schritt ("Noch keine Gäste — Datei importieren?")
- Import-Preview zeigt KI-Vorschläge zum Abnicken
- User hat ersten Sitzplan in <30 Minuten

**Status:** 🟡 Teilweise (Onboarding implementiert, Empty States teilweise)

### Szenario: Spätabsage am Tag vor der Hochzeit

**Ablauf:**
1. Gast sagt ab, Caterer kennt Gästezahl bereits
2. User setzt Gast auf "Abgesagt"

**Erwartung:**
- Sitzplatz wird sofort frei (neu vergebbar)
- Tisch-Badge zeigt "N abgemeldet"
- Caterer-Export listet Wegfall mit Name · Tisch · Menü · Allergie
- Service vor Ort weiß: Stuhl bleibt leer, Essen wird nicht abgerufen

**Status:** ✅ Implementiert (Spätabsage-Handling als Erstklass-Workflow)

## 10.6 Plattform-Kompatibilität

### Szenario: iPad-Target kompiliert

**Ablauf:**
1. Entwickler ändert macOS-Code
2. CI baut iPad-Target

**Erwartung:**
- iPad-Build schlägt nicht fehl
- Conditional Compilation (`#if os(macOS)`) schützt macOS-spezifischen Code
- Keine Code-Duplikation (gleiche Sources via PBXFileSystemSynchronizedRootGroup)

**Status:** ✅ Implementiert (CI-Job `ios-build`, compile-only)

### Szenario: Apple Intelligence Fallback

**Ablauf:**
1. User wählt Apple Intelligence als Provider
2. macOS < 26 (nicht unterstützt)

**Erwartung:**
- Factory erkennt fehlende Unterstützung
- Fallback zu LM Studio
- User-Info: "Apple Intelligence benötigt macOS 26"

**Status:** ✅ Implementiert (LLMClientFactory mit Fallback-Chain)
