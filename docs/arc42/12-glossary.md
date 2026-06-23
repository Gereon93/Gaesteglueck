# 12. Glossar

## Domänen-Begriffe

| Begriff | Definition |
|---------|------------|
| **Anmeldung** | Die Antwort eines Gastes auf die Einladung (Zusage/Absage/Offen) |
| **Absage (früh)** | Gast wird gelöscht, bevor der Caterer die Gästezahl kennt |
| **Absage (spät)** | Gast wird auf "Abgesagt" gesetzt, Caterer kennt Zahl bereits |
| **Caterer-Export** | PDF mit Menü-Zählungen, Allergien, Spätabsage-Vermerk |
| **Co-Pilot** | Interaktiver KI-Chat für Sitzplan-Manipulation |
| **Constraint** | Harte Sitz-Regel: `mustSitTogether` oder `mustNotSitTogether` |
| **Fun Fact** | Lustige Anekdote pro Gast für Tischkarten und Rede |
| **Gast** | Eingeladene Person mit Namen, Menü, Allergien, Tags, Tisch-Zuordnung |
| **Harmonie-Heuristik** | Algorithmus zur Bewertung der Tisch-Zusammensetzung |
| **Import-Preview** | UI zum Prüfen und Bestätigen der KI-Import-Vorschläge |
| **Kindertisch** | Spezieller Tisch für Kinder (Alters-Bonus im Scoring) |
| **Menüoption** | Catering-Auswahl: Fleisch, Vegetarisch, Vegan |
| **Partner-Zuordnung** | Gast gehört zu Partner 1, Partner 2, beiden, oder keinem |
| **Pinning** | Gast am zugewiesenen Tisch fixieren (wird vom Solver nicht verschoben) |
| **Raumplan** | Visueller Canvas mit Tischen, Stühlen, Grundriss-Foto |
| **Skalierung** | 2-Punkt-Kalibrierung: Pixel → Zentimeter für Raumplan |
| **Sitzplan** | Zuordnung von Gästen zu Tischen mit Position im Raum |
| **Solver** | Algorithmus (Greedy + Simulated Annealing) für automatische Sitzverteilung |
| **Spätabsage** | Absage nach Caterer-Frist → Gast bleibt als Vermerk am Tisch |
| **Tag** | Beziehungs-Label: Freundeskreis, Familie, Rolle, Aktivität, Arbeit |
| **Tag-Kategorie** | Oberkategorie: family, friendGroup, role, activity, work, custom |
| **Tafel** | Kombination mehrerer rechteckiger Tische zu einer langen Tafel |
| **Tischkarte** | Gefaltete Karte pro Gast: Name + Fun Fact (4/A4) |
| **Unverträglichkeit** | Allergie oder Diät-Wunsch (Laktose, Gluten, Nüsse, etc.) |
| **Version** | Snapshot des Sitzplans (Save/Restore/A/B-Vergleich) |

## Technische Begriffe

| Begriff | Definition |
|---------|------------|
| **Actor** | Swift 6 Concurrency-Feature: Thread-safe durch Isolation |
| **CoreXLSX** | Externe Dependency für Excel-Import (XLSX-Format) |
| **FoundationModels** | Apple Intelligence Framework (macOS 26+) |
| **Lightweight Migration** | Automatische SwiftData-Schema-Migration |
| **LM Studio** | Lokale LLM-Runtime (OpenAI-kompatible API) |
| **ModelContainer** | SwiftData-Container für Datenbank-Verbindung |
| **nonisolated(unsafe)** | Swift 6: Bypass für Concurrency-Checks (unsafe) |
| **OpenRouter** | Cloud-LLM-Provider (API-Aggregator) |
| **Pre-Launch-Backup** | Automatische Store-Kopie vor jeder Migration |
| **RFC 4180** | CSV-Standard (Quoting, Multi-Line-Zellen) |
| **Sendable** | Swift 6: Type-safe für Concurrency (keine Data Races) |
| **sourceID** | Stabile Import-ID (email > phone > timestamp) |
| **VersionedSchema** | SwiftData-Feature für explizite Schema-Versionierung |
| **@Query** | SwiftUI-Property für reaktive SwiftData-Queries |

## Abkürzungen

| Abkürzung | Bedeutung |
|-----------|-----------|
| **A3/A4** | Papierformate (ISO 216) |
| **BFS** | Breadth-First Search (Graph-Traversal) |
| **CI/CD** | Continuous Integration / Continuous Deployment |
| **DI** | Dependency Injection |
| **DMG** | Apple Disk Image |
| **DPI** | Dots Per Inch (Druckauflösung) |
| **FA** | Funktionale Anforderung (aus VISION.md) |
| **HIG** | Human Interface Guidelines (Apple) |
| **KI** | Künstliche Intelligenz (Deutsch für AI) |
| **LLM** | Large Language Model |
| **MV** | Model-View (Architektur-Pattern) |
| **MVVM** | Model-View-ViewModel (Architektur-Pattern) |
| **NFA** | Nicht-funktionale Anforderung (aus VISION.md) |
| **PDF** | Portable Document Format |
| **PNG** | Portable Network Graphics |
| **SA** | Simulated Annealing (Optimierungs-Algorithmus) |
| **SUT** | System Under Test |
| **UUID** | Universally Unique Identifier |
| **vCard** | Elektronische Visitenkarte (RFC 6350) |
| **WAL** | Write-Ahead Log (SQLite) |
