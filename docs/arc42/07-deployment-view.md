# 7. Verteilungssicht

## 7.1 Entwicklungs-Setup

```
┌─────────────────────────────────────────────────────────────┐
│                    Entwickler-Mac                           │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Xcode / Swift PM                                     │  │
│  │                                                       │  │
│  │  Package.swift → swift build → swift run              │  │
│  │  oder: Gaesteglueck.xcworkspace                       │  │
│  │    ├── Scheme "Gaesteglueck" → My Mac (SPM)          │  │
│  │    └── Scheme "Gaesteglueck-iPad" → iPad Simulator   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  LM Studio (optional, lokal)                          │  │
│  │  Endpoint: http://localhost:1234/v1                    │  │
│  │  Empfohlen: gemma-3-12b oder gemma-4-26b-a4b         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 7.2 Produktions-Deployment

### Variante A: `swift run` (Entwicklung)

```bash
swift build && swift run
```

Kein `.app`-Bundle. macOS loggt kosmetische Warnungen.

### Variante B: `.app`-Bundle (Alltag)

```bash
./scripts/build-macos-app.sh
open dist/Gaesteglueck.app
```

Erzeugt `dist/Gaesteglueck.app` mit eigener `Info.plist`.

### Variante C: DMG-Release (CI)

```
.github/workflows/ci.yml → Job "release"
    │
    ▼
┌──────────────────────────────────┐
│ 1. swift build -c release        │
│ 2. .app-Bundle bauen             │
│ 3. Ad-hoc Signierung             │
│ 4. DMG erstellen                 │
│    (mit /Applications-Symlink)   │
│ 5. GitHub Release                │
│    Tag: v{version}-build{number} │
└──────────────────────────────────┘
```

## 7.3 Datenablage

```
~/Library/Application Support/Gaesteglueck/
├── Gaesteglueck.store          # SwiftData-Datenbank
├── Gaesteglueck.store-shm      # Shared memory (SQLite)
├── Gaesteglueck.store-wal      # Write-ahead log
└── Backups/                    # Pre-Launch-Snapshots
    ├── pre-launch-1.store      # (Retention: 3)
    ├── pre-launch-2.store
    └── pre-launch-3.store
```

## 7.4 CI/CD-Pipeline

```
.github/workflows/ci.yml
│
├── Job: build-and-test (macos-15)
│   ├── swift-format lint (wenn verfügbar)
│   ├── swift build
│   └── swift test
│
├── Job: ios-build (macos-15)
│   └── xcodebuild (iPad Simulator, compile-only)
│
├── Job: prompt-eval (ubuntu-latest, nur main)
│   ├── Python deps installieren
│   ├── Prompts aus Swift-Quellen extrahieren
│   └── pytest + deepeval (LLM-as-Judge)
│
└── Job: release (macos-15, nur main)
    ├── .app bauen + signieren
    ├── DMG erstellen
    └── GitHub Release veröffentlichen
```

## 7.5 iPad-Target

```
ios/Gaesteglueck-iPad.xcodeproj
│
├── Platform: iPadOS 18+
├── Device: iPad only (TARGETED_DEVICE_FAMILY = 2)
├── Sources: PBXFileSystemSynchronizedRootGroup → ../Sources/Gaesteglueck
│   (gleiche Sources wie macOS, keine Duplikation)
├── Dependency: CoreXLSX via SPM
└── Bundle ID: com.gereon93.Gaesteglueck.ipad
```

Einschränkungen iPad v1:
- Kein PDF-/Bild-Export
- KI-Provider: OpenRouter, Apple Intelligence, LM Studio (via LAN-IP)
