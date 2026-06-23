# 9. Entwurfsentscheidungen

## DD-1: SwiftData statt Core Data

**Entscheidung:** SwiftData mit `VersionedSchema` für Persistenz.

**Begründung:** SwiftData ist die moderne, SwiftUI-native Persistenzlösung von Apple.
`VersionedSchema` ermöglicht explizite Migrationen. Weniger Boilerplate als Core Data.

**Nachteil:** SwiftData ist jünger und hat weniger Edge-Case-Dokumentation.

## DD-2: Kein ViewModel-Layer (MV statt MVVM)

**Entscheidung:** Views queryn SwiftData direkt via `@Query`, Services sind stateless.

**Begründung:** `@Query` reagiert automatisch auf Datenänderungen — ein ViewModel
würde nur Duplikat-Code erzeugen. Services als `enum`/`struct` mit `static func`
sind testbar ohne Instance-Management.

## DD-3: LLMClient-Protocol statt konkreter Client

**Entscheidung:** Protocol mit 3 Implementierungen + Factory + Decorator.

**Begründung:** Ermöglicht pro Feature einen eigenen Provider (z.B. OpenRouter
für Chat, LM Studio für Parsing). Fallback-Ketten. Einfaches Testen mit
Mock-Implementierung.

## DD-4: Stabile Kurz-IDs in LLM-Prompts

**Entscheidung:** G1, G2, T1, T2 statt UUIDs.

**Begründung:** Spart Token (~70% weniger als UUIDs). Verhindert Copy-Fehler
des LLM bei langen UUIDs. Mapping über Dictionary in der App.

## DD-5: sourceID-basiertes Import-Matching

**Entscheidung:** Stabile `sourceID` (email > phone > timestamp+family) statt Name-Matching.

**Begründung:** Namen sind nicht eindeutig (zwei „Thomas Müller"). sourceID
überlebt Re-Imports und Namensänderungen. Fallback auf Name-Matching wenn
keine stabile ID verfügbar.

## DD-6: 2-Phasen-Solver (Greedy + Simulated Annealing)

**Entscheidung:** Greedy-Initialisierung + Simulated Annealing-Optimierung.

**Begründung:** Greedy liefert schnellen, brauchbaren Start. SA verbessert
lokal ohne kombinatorische Explosion. 6000 Iterationen in <1s auf M-Chip.
Hard-Constraints werden als Gate erzwungen (niemals verletzt).

## DD-7: Graph-basiertes Scoring

**Entscheidung:** `SeatingGraph` mit gewichteten Kanten für alle Beziehungen.

**Begründung:** Einheitliches Scoring-Modell. Gewichte sind einzeln justierbar.
Familie (+70), Tags (+40), Constraints (+100/-500), Partner (+150),
Brücken-Personen (+10) — alle in einem Graph modellierbar.

## DD-8: Pre-Launch-Backups

**Entscheidung:** Automatische Store-Kopie vor jedem Launch, Retention 3.

**Begründung:** Migrationen können schiefgehen. Backups sind die letzte
Verteidigungslinie. 3 Backups = Schutz gegen korrupte Snapshots.

## DD-9: PDF-Rendering mit Core Graphics

**Entscheidung:** `CGContext` für PDF-Generierung, kein Drittanbieter-Library.

**Begründung:** Native macOS-API, keine Dependencies. Volle Kontrolle über
Layout. Core Text für Text-Rendering. Funktioniert für alle Export-Formate
(A4, A3, Tischkarten).

## DD-10: Tag-System statt fester Kategorien

**Entscheidung:** Multi-Tag-System mit Kategorien (family, friendGroup, role, activity, work, custom).

**Begründung:** Flexible Beziehungspflege. Ein Gast kann mehrere Tags haben.
Tags haben Farben und Partner-Zuordnung. Ersetzt starre Kategorien aus V1.

## DD-11: Tafel-Layout als Geometry-Service

**Entscheidung:** `TafelLayout` berechnet Sitzpositionen für kombinierte Tische.

**Begründung:** Trennung von Modell (combinationGroup/Order) und Geometrie.
Tafel = kontinuierliches Rechteck. Sitzverteilung symmetrisch. Berechnung
unabhängig von Rendering.

## DD-12: Pro-Feature KI-Provider

**Entscheidung:** Jeder der 5 KI-Features kann eigenen Provider/Modell haben.

**Begründung:** Unterschiedliche Features haben unterschiedliche Anforderungen.
Chat braucht schnelles Modell. Parsing braucht großes Context-Fenster.
User kann pro Feature optimieren.
