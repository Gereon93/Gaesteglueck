# CLAUDE.md

Kontext für KI-Assistenten (Claude Code u. a.), die an diesem Repo arbeiten.

## Projekt

**Gästeglück** — macOS-first Hochzeits-Sitzplaner, komplett lokal, mit optionaler
lokaler KI (LM Studio / OpenRouter / Apple Intelligence). Siehe `README.md` für
Features und `docs/VISION.md` für die Roadmap.

Entwickelt KI-gestützt (Claude Code) als reales Projekt — für die eigene
Hochzeit gebaut und dort eingesetzt. Architektur- und Produktentscheidungen
liegen als Specs unter `docs/superpowers/specs/`.

## Stack

- **Sprache:** Swift 6 (strikte Concurrency)
- **UI:** SwiftUI (macOS 15+, experimentelles iPad-Target)
- **Persistenz:** SwiftData mit `VersionedSchema` + Migrationen
- **Build:** Swift Package Manager (`Package.swift`); iPad-Target als Xcode-Projekt unter `ios/`

## Struktur

- `Sources/Gaesteglueck/{Models,Services,Views}/` — Produktivcode
- `Tests/GaesteglueckTests/` — `swift test`
- `docs/` — VISION, Specs und Pläne
- `eval/` — Prompt-Evaluierung der KI-Features
- `scripts/build-macos-app.sh` — bündelt das SPM-Executable als `.app`

## Befehle

```bash
swift build                       # bauen
swift test                        # Tests
swift-format lint --recursive Sources/ Tests/ --strict   # Lint (läuft in CI, wenn swift-format verfügbar)
./scripts/build-macos-app.sh      # .app-Bundle nach dist/
```

## Konventionen

- **Sprache:** Deutsch in Code-Kommentaren, Commits, Docs und UI.
- **Kommentare:** sparsam. Nicht-triviale Begründungen als erklärende Methode
  oder Spec, nicht als Inline-Kommentar.
- **Commits:** pro logischem Arbeitspaket, kein Sammel-Commit.
- **Tests:** Logik in Services/Models testbar halten; Views dünn.
