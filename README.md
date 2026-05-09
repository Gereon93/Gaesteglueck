# Gästeglück

Macher-freundlicher Hochzeits-Sitzplaner für macOS — komplett lokal, mit lokaler KI über LM Studio.

## Was kann's

- **Gäste-Import** aus CSV / Excel / Google Sheets, mit RFC-4180-Parser für Multi-Line-Zellen und Auto-Skip unveränderter Re-Imports
- **Tag-Generator** leitet aus der Beziehungs-Beschreibung automatisch Freundeskreise, Hochzeitsrollen und Aktivitäten ab — Familie wird über Familienrollen am Gast modelliert (kein Doppelpflegen)
- **Saal-Konfigurator** nimmt Inventar (max Anzahl + Größen) + Cluster-Kontext und schlägt eine konkrete Tisch-Konfiguration vor — direkt anwendbar plus optionale Auto-Sitzvergabe
- **Sitzplan-Co-Pilot-Chat** im Canvas: „Patrick auf T2", „Tausche Lisa und Anna", „Welche Tische haben Plätze?" → KI führt aus
- **Raumplan-Hintergrund** mit 2-Punkt-Skalierung; Tische skalieren proportional zum Raum
- **VersionedSchema** + Pre-Launch-Backups: Schema-Änderungen brechen keine Daten mehr
- **PDF-Export** für Sitzplan, Caterer-Übersicht, Tischkarten und Plakat

## Voraussetzungen

- macOS 15 (Sequoia) oder neuer
- Swift 6 Toolchain (kommt mit Xcode 16+)
- Optional: [LM Studio](https://lmstudio.ai/) lokal für die KI-Features (Tag-Generator, Saal-Konfigurator, Co-Pilot). Empfohlenes Modell: `google/gemma-3-12b` (non-reasoning, schneller) oder `gemma-4-26b-a4b` (besser, braucht 16k Context).

## Build & Start

### Variante A — Entwicklung mit `swift run`

```bash
swift build
swift run
```

Schnell, aber ohne `.app`-Bundle. macOS protokolliert dann ein paar kosmetische Warnungen (`Cannot index window tabs`, etc.).

### Variante B — Als richtige `.app` für den Alltag

```bash
./scripts/build-macos-app.sh
open dist/Gaesteglueck.app
```

Erzeugt `dist/Gaesteglueck.app` mit eigener `Info.plist`. Kann nach `/Applications/` kopiert oder im Dock abgelegt werden. Saubere Bundle-Identität, keine macOS-Logs mehr.

### Tests

```bash
swift test
```

114 Tests in 22 Suites.

## Wo liegen die Daten

`~/Library/Application Support/Gaesteglueck/`
- `Gaesteglueck.store` (+ `-shm`, `-wal`) — SwiftData-Datenbank
- `Backups/` — automatische Pre-Launch-Snapshots (Retention 3) plus manuelle Backups via Settings

## Lizenz

MIT — siehe LICENSE.

## Status

v1 ist einsatzbereit. Roadmap im `docs/VISION.md`.
