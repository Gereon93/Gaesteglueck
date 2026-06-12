# Gästeglück

Macher-freundlicher Hochzeits-Sitzplaner für macOS — komplett lokal, mit lokaler KI über LM Studio.

> Entstanden als echtes Projekt für meine **eigene Hochzeit** — und dort auch
> tatsächlich eingesetzt, nicht nur als Demo gebaut. Entwickelt KI-gestützt mit
> Claude Code; die Produkt- und Architekturentscheidungen sind als Specs unter
> [`docs/`](docs/) dokumentiert.

## Was kann's

- **Gäste-Import** aus CSV / Excel / Google Sheets, mit RFC-4180-Parser für Multi-Line-Zellen und Auto-Skip unveränderter Re-Imports
- **Tag-Generator** leitet aus der Beziehungs-Beschreibung automatisch Freundeskreise, Hochzeitsrollen und Aktivitäten ab — Familie wird über Familienrollen am Gast modelliert (kein Doppelpflegen)
- **Saal-Konfigurator** nimmt Inventar (max Anzahl + Größen) + Cluster-Kontext und schlägt eine konkrete Tisch-Konfiguration vor — direkt anwendbar plus optionale Auto-Sitzvergabe
- **Sitzplan-Co-Pilot-Chat** im Canvas: „Patrick auf T2", „Tausche Lisa und Anna", „Welche Tische haben Plätze?" → KI führt aus
- **Raumplan-Hintergrund** mit 2-Punkt-Skalierung; Tische skalieren proportional zum Raum
- **VersionedSchema** + Pre-Launch-Backups: Schema-Änderungen brechen keine Daten mehr
- **PDF-Export** für Sitzplan, Caterer-Übersicht, Tischkarten und Plakat

## Absagen: löschen oder abmelden?

Ein Gast, der nicht kommt, wird je nach Zeitpunkt unterschiedlich behandelt — danach richtet sich, ob eine Spur bleibt.

**Früh genug — der Caterer kennt die Gästezahl noch nicht → Gast löschen.**
Wer absagt (oder sich nie gemeldet hat), bevor die Mengen beim Caterer durch sind, gehört aus der Liste gelöscht. Kein Sonderzustand, keine Spur — die Person war nie fest eingeplant, also soll sie auch Zählungen, Sitzplan und Exporte nicht verfälschen.

**Zu spät — Essen ist bestellt, Änderung nicht mehr möglich → auf „Abgesagt" stellen.**
Sagt jemand ab, der schon zugesagt *und* an einem Tisch saß, wird er im Tooling auf „Abgesagt" gesetzt statt gelöscht. Dann passiert:

- Der **Sitzplatz wird frei** und ist sofort neu vergebbar.
- Der Gast bleibt seinem Tisch als **Vermerk** zugeordnet: Die Tisch-Badge zeigt „N abgemeldet", und der **Caterer-Export** listet den Wegfall mit Name · Tisch · Menü · Unverträglichkeit („−1 Vegetarisch", „Allergikerin an T2 ist nicht mehr da").
- So weiß der Service vor Ort: Der Stuhl bleibt leer, das **bestellte Essen wird nicht abgerufen** — kein Rätselraten.

Der Status „Abgesagt" ist damit faktisch der *Spätabsage*-Zustand; frühe Fälle löscht man einfach.

**Kommt doch wieder → zurück auf „Zugesagt".**
Setzt man eine späte Absage wieder auf „Zugesagt" (Irrtum, „kommt doch"), verschwindet der Vermerk und der Gast landet wieder in der „Ohne Tisch"-Inbox zum Neu-Platzieren.

> Technischer Hinweis: Der Vermerk hängt an der beibehaltenen Tisch-Zuordnung (Sitz frei, Tisch bleibt), nicht an einem separaten gespeicherten Feld. Er übersteht das Neu-Belegen des Sitzes, aber **nicht** ein komplettes Layout-Restore oder das Löschen des Tisches.

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

### Variante C — Xcode-Workspace (Mac + iPad)

```bash
open Gaesteglueck.xcworkspace
```

Die Workspace bündelt beides (wie eine Visual-Studio-Solution):

| Scheme | Ziel | Was es ist |
|---|---|---|
| `Gaesteglueck` | **My Mac** | das SwiftPM-Executable (wie `swift run`) |
| `Gaesteglueck-iPad` | iPad-Simulator/-Gerät | die iPad-App (experimentell) |

> ⚠️ Das Scheme `Gaesteglueck` nicht auf ein iOS-Ziel stellen — SwiftPM
> baut kein App-Bundle, der Start crasht dann sofort mit
> `missing bundleID`. Für iPad immer `Gaesteglueck-iPad` nehmen.

Die iPad-App kompiliert dieselben Sources (Conditional Compilation —
die Mac-App bleibt unberührt). Einschränkungen der v1: kein PDF-/Bild-
Export auf dem iPad. KI-Provider auf dem iPad: **OpenRouter**,
**Apple Intelligence** (on-device; die App läuft ab iPadOS 18, dieser
Provider erscheint erst ab iPadOS 26 auf fähiger Hardware) — oder
LM Studio über die LAN-IP des Macs als Endpoint.

### Erster Start (Gatekeeper)

Eine aus den [Releases](../../releases) geladene `.dmg` ist **ad-hoc signiert,
nicht notarisiert** (kein bezahlter Apple-Developer-Account). macOS 15 blockt
sie deshalb beim ersten Start mit „Apple konnte nicht überprüfen…". Einmalig
das Quarantäne-Flag entfernen — Pfad ggf. an den tatsächlichen Ablageort der
App anpassen (z. B. noch im gemounteten DMG oder im Download-Ordner):

```bash
xattr -dr com.apple.quarantine /Applications/Gaesteglueck.app
```

Alternativ über **Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem
öffnen"** nach dem ersten Startversuch. Selbst gebaute Apps (Variante A/B)
sind nicht betroffen.

### Tests

```bash
swift test
```

225 Tests in 44 Suites.

## Wo liegen die Daten

`~/Library/Application Support/Gaesteglueck/`
- `Gaesteglueck.store` (+ `-shm`, `-wal`) — SwiftData-Datenbank
- `Backups/` — automatische Pre-Launch-Snapshots (Retention 3) plus manuelle Backups via Settings

## Praxis-Check: was sich im echten Einsatz bewährt hat

Gebaut für die eigene Hochzeit — und dabei auch gelernt, wo Anspruch und Realität auseinandergehen. Ehrlich eingeordnet:

- **Der eigentliche Kern-Use-Case — Gäste *automatisch* auf verschiedene Tisch-Anordnungen verteilen — ist im echten Einsatz nicht erprobt.** Bei uns fiel die Entscheidung auf **5 lange Tafeln**; da mussten wir Leute nur noch platzieren, nicht verteilen lassen. Der Solver samt Harmonie-Heuristik ist unit-getestet und funktioniert, lief aber nie gegen ein echtes, unstrukturiertes Gäste-Set. → [#6](../../issues/6)
- **Klar bewährt haben sich dagegen:**
  - **Familien-Drag** — zieht man eine Person an einen Tisch, kommen alle Familienmitglieder mit und werden um sie herum gesetzt. Spart enorm Klickarbeit.
  - **Diät-/Unverträglichkeits-Übersicht** — farblich codiert auf einen Blick sehen, wo Veggie/Vegan/Allergiker sitzen. Beim Caterer-Abgleich und am Tag selbst Gold wert.
  - **Kategorien-Export als Foto-Gruppen** und der **Markdown-Export für die Rede** — beide direkt nutzbar.
- **Harmonie-Logik ehrlich eingeordnet:** „Wer harmoniert mit wem" lief bei uns gut, bräuchte für verlässliche Ergebnisse aber deutlich mehr strukturierten Input über die Gäste, als man realistisch pflegt.

Unterm Strich: als **Platzier- und Übersichts-Werkzeug** hat es getragen; die voll-automatische Optimierung bleibt der spannendste, aber am wenigsten battle-getestete Teil.

## Lizenz

GNU General Public License v3.0 — siehe [LICENSE](LICENSE). Bei Weitergabe
bzw. Distribution muss der (korrespondierende) Quellcode den Empfängern unter
der GPL bereitgestellt werden; ein privater Fork ohne Weitergabe löst das
nicht aus.

## Status

v1 ist einsatzbereit. Roadmap im `docs/VISION.md`.
