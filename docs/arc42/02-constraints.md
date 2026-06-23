# 2. Randbedingungen

## Technische Randbedingungen

| Randbedingung | Ausprägung |
|---------------|------------|
| Plattform | macOS 15+ (Sequoia), experimentelles iPad-Target (iPadOS 18+) |
| Sprache | Swift 6 mit strikter Concurrency |
| UI-Framework | SwiftUI |
| Persistenz | SwiftData mit `VersionedSchema` + manuellen Migrationen (V1–V5) |
| Build | Swift Package Manager (`Package.swift`); iPad-Target als Xcode-Projekt |
| Externe Abhängigkeit | CoreXLSX (Excel-Import) — einzige externe Dependency |
| KI-Provider | LM Studio (lokal, OpenAI-kompatibel), OpenRouter (Cloud), Apple Intelligence (on-device, macOS 26+) |
| Signierung | Ad-hoc, nicht notarisiert (kein bezahlter Apple Developer Account) |

## Organisatorische Randbedingungen

| Randbedingung | Ausprägung |
|---------------|------------|
| Teamgröße | 1 Entwickler + KI-Assistenz (Claude Code) |
| Lizenz | GPL v3.0 |
| Sprache im Code | Deutsch (Kommentare, Commits, Docs, UI) |
| Budget | Kein Apple Developer Account, keine Cloud-Infrastruktur |

## Konventionen

- **Keine Cloud:** Alle Daten bleiben lokal. Keine Server, keine Accounts.
- **Optionale KI:** Jedes KI-Feature hat einen nicht-KI-Fallback (heuristische Parser, lokaler Tag-Deriver).
- **Views dünn:** Logik in Services/Models testbar halten.
- **German-first:** Alle UI-Strings, Fehlermeldungen und Logs auf Deutsch.
