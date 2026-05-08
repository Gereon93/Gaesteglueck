# Gästeglück — Vision & Lastenheft

> Eine kleine App, die Hochzeitspaaren das Stück Planung abnimmt, an dem sie nachts wach liegen: **Wer sitzt neben wem?**

**Status:** v0.x in Entwicklung · **Plattform:** macOS 15+ · **Sprache:** Deutsch · **Stand:** 2026-05-05

Dieses Dokument ist sowohl **Lastenheft** (was muss die Software können, wenn sie fertig ist) als auch **Design-Brief** (welche Stimmung, welche Bildschirme, welche Komponenten). Es kann 1:1 als Briefing für Claude Designer, Stitch oder Figma verwendet werden.

---

## 1. Vision

Eine Hochzeit ist eines der emotionalsten Ereignisse im Leben — und einer der größten organisatorischen Albträume. Allein die Sitzordnung kostet viele Paare wochenlang Nerven: Excel-Tabellen, Post-its an der Wand, ein Familienkonflikt pro Cousine.

**Gästeglück** macht aus diesem Stress ein angenehmes, fast meditatives Stück Hochzeitsplanung. Du fütterst die App mit deinen Anmeldungen, erzählst ihr in zwei, drei Schritten wer mit wem verbandelt ist, und sie schlägt dir einen Sitzplan vor — den du im Raumplan-Canvas verschiebst, korrigierst, bis er sich richtig anfühlt. Eine lokale KI denkt mit, ohne dass deine Gästeliste je deinen Mac verlässt.

**Wenn diese App fertig ist, soll sie sich so anfühlen, wie sich der Hochzeitstag selbst anfühlen sollte: warm, persönlich, ein bisschen feierlich — und am Ende: erledigt.**

### Leitsatz für jede Designentscheidung

> "Das ist eine Hochzeit, kein Excel."

---

## 2. Zielgruppe

### Primär — Heiratende Paare (DIY-Planer)

- 25-45 Jahre, mittlere bis hohe digitale Affinität
- Planen ihre Hochzeit selbst, nicht über Eventagentur
- 60-150 Gäste, ein Hauptraum, manchmal Outdoor-Areal
- Besitzen einen Mac (oder ein Familienmitglied tut's)
- Wollen **kein Abo, keinen Cloud-Account**, keine Daten weggeben — die Gästeliste ist intim

### Sekundär — Hobby-Hochzeitsplaner & Familienmitglieder

- Trauzeugen oder Eltern, die helfen
- Brauchen einen Modus, in dem sie sich nicht erst einlernen müssen

### Anti-Persona

- Profi-Eventagenturen mit 500+ Gästen, mehreren parallelen Events, Team-Collaboration. Das ist nicht unsere Liga — wir bauen kein Notion für Hochzeiten.

---

## 3. Kernversprechen

Vier Versprechen, an denen sich jedes Feature messen lassen muss:

1. **Privat by default.** Die Gästeliste verlässt nie den Mac. Keine Cloud, kein Account, keine Telemetrie. KI läuft lokal (LM Studio).
2. **In einem Nachmittag bedienbar.** Ein Paar ohne Anleitung kommt vom Excel-Export der Anmeldungen zum ersten Sitzplan-Vorschlag in unter 30 Minuten.
3. **Iterierbar bis zur Ruhe.** Die App wird nicht einmal benutzt und vergessen — sie begleitet vom ersten Rücklauf bis zur Caterer-Liste am Tag vor der Hochzeit. Mehrfach-Imports, Plan-Änderungen, "die Cousine hat doch abgesagt"-Fälle sind Erstklass-Workflows.
4. **Schön genug, dass man es zeigt.** Das Paar zeigt der besten Freundin den Sitzplan auf dem Mac. Es darf nicht aussehen wie ein Entwickler-Tool.

---

## 4. User Journey (Storyline)

> Diese Journey ist das Skript für jedes Designkonzept. Jeder Schritt ist ein Screen oder Flow.

**Akt 1 — Ankunft (5 Min)**

Anna und Ben öffnen die App zum ersten Mal. Ein warmer Willkommens-Screen: "Wir helfen euch beim Sitzplan. Wie heißt ihr beide?" Sie geben Namen, Datum, Location ein. Im Hintergrund ein dezentes, abstraktes Hochzeits-Motiv — keine Stockphoto-Tauben.

**Akt 2 — Die Anmeldungen kommen rein (10 Min)**

Anna exportiert das Google-Formular ihrer Anmeldungen als Excel. Drag-and-drop in die App. Eine sanfte Animation, dann eine Liste: "Wir haben 47 Anmeldungen mit 124 Gästen erkannt. Schau mal drüber?" Pro Anmeldung eine Karte mit Original-Text und KI-Vorschlag — Anna nickt zwei mal pro Karte ab oder korrigiert. Sie kann jederzeit **mit einer neuen Datei nachimportieren**, wenn weitere Rücklaufe kommen.

**Akt 3 — Wer kennt wen? (15 Min)**

Ein freundlicher Wizard führt durch die Beziehungspflege. "Familie Müller — gehört das zu Anna oder Ben?" "Wer ist Trauzeuge?" Statt komplexer Beziehungs-Diagramme: einfache Tags ("Studienfreunde Anna", "Onkel von Ben"). Mehrere Tags pro Gast erlaubt. Die App schlägt aus den Anmeldedaten Tags vor, Anna bestätigt mit einem Klick.

**Akt 4 — Der Raum entsteht (10 Min)**

Die App fragt: "Wie viele Tische habt ihr, welcher Raum?" Anna lädt ein Foto vom Grundriss hoch, kalibriert mit zwei Fingern den Maßstab, zieht Tische auf den Plan. Tische lassen sich zu Tafeln kombinieren. Die App zählt mit: "84 Plätze für 124 Gäste — ihr braucht noch zwei Tische."

**Akt 5 — Die KI schlägt vor (5 Min)**

Anna klickt "Plan vorschlagen". Eine kurze Animation, dann ein erster Sitzplan auf dem Canvas. Die KI begründet kurz: "Ich habe Annas Studienfreunde an Tisch 3 zusammengesetzt — sie sind alle zwischen 28 und 32 und haben mehrere gemeinsame Tags." Anna kann jeden Tisch antippen und nachfragen.

**Akt 6 — Iterieren (über Tage/Wochen, 30s pro Anpassung)**

Anna kommt jeden Abend kurz zurück. Sie verschiebt einen Gast. Sie pinnt Tante Helga an Tisch 1 ("die muss da bleiben"). Sie chattet mit der KI: "Onkel Karl ist krank, kann er weg?" Die App rechnet nach, zeigt Konsequenzen.

**Akt 7 — Der Tag rückt näher (10 Min)**

Eine Woche vor der Hochzeit: PDF-Export für den Caterer. Tischliste mit Allergien rot markiert. Tischkarten zum Ausdrucken — pro Gast Name + Fun Fact. Anna druckt, lacht beim Lesen der Fun Facts, klebt sie auf Pappe. **Erledigt.**

---

## 5. Funktionale Anforderungen (SOLL)

> Format: `FA-X.Y` — eindeutig referenzierbar. **Status:** ✅ umgesetzt · 🟡 teilweise · ⬜ offen

### 5.1 Event-Setup
- **FA-1.1** ✅ Frei wählbare Partnernamen (statt "Braut/Bräutigam"), Hochzeitsdatum, Location
- **FA-1.2** ✅ Konfigurierbare Menüoptionen (z.B. Fleisch / Vegetarisch / Vegan)
- **FA-1.3** ✅ Raumdimensionen (Breite × Länge in cm), optionales Grundriss-Foto mit Maßstabskalibrierung
- **FA-1.4** ✅ Tisch-Inventar (welche Tische stehen zur Verfügung, unabhängig von Platzierung)
- **FA-1.5** ⬜ Multi-Event-Support (Datenmodell ja, UI später)

### 5.2 Gäste-Import
- **FA-2.1** ✅ Excel-Import (.xlsx) und CSV-Import
- **FA-2.2** ✅ KI-gestütztes Parsen unstrukturierter Anmeldungs-Freitexte (LM Studio)
- **FA-2.3** ✅ Regex-Fallback wenn keine KI verfügbar
- **FA-2.4** ✅ Import-Preview mit Übernehmen/Korrigieren/Überspringen pro Anmeldung
- **FA-2.5** ✅ Wiederholbarer Import — Duplikat-Erkennung über Vor+Nachname, neue Anmeldungen werden gemergt
- **FA-2.6** ✅ Google-Sheets-Import via öffentlicher CSV-Export-URL (kein OAuth)
- **FA-2.7** ⬜ **Backlog (OS-Release):** Konfigurierbares CSV-/Excel-Spalten-Mapping. Aktuell ist die Spalten-Erkennung auf das Format der Hochzeit Gereon-Maria zugeschnitten (Familienname, Anzahl, Gäste-Details, Fun Facts, Anmerkungen). Andere Paare haben andere Spalten (Heimatort, Liedwunsch, Anreise, Übernachtungsbedarf, Allergiehinweise eigene Spalte, …) und wollen entscheiden welche davon als Gast-Notiz übernommen werden, welche als eigene Tags fungieren, welche ignoriert werden. Lösung: Mapping-UI nach dem Datei-Upload, vor dem KI-Parsing — User markiert pro Spalte: "Familienname / Personenanzahl / Gäste-Freitext / Fun Fact / Notiz / Tag-Quelle / Ignorieren". Mapping wird pro Datei-Header-Signatur gespeichert, beim erneuten Import desselben Schemas vorgeschlagen.

### 5.3 Beziehungen, Tags, Constraints
- **FA-3.1** ✅ Multi-Tag-System pro Gast (Familie, Freundeskreis, Rolle, Aktivität, Arbeit, Custom)
- **FA-3.2** ✅ Tag-Farben & Kategorien
- **FA-3.3** ✅ Familienrollen (Eltern, Geschwister, Onkel/Tante, Cousin/e, Großeltern, Neffe/Nichte) mit Bezug zu Partner 1 oder 2
- **FA-3.4** ✅ Harte Constraints (`mustSitTogether`, `mustNotSitTogether`, `mustSitNear`)
- **FA-3.5** ✅ Anreicherungs-Wizard (Schritt 1-4: Partner-Zuordnung → Familie → Tags → Optional)
- **FA-3.6** ✅ Tag-Gruppenansicht mit Drag-and-Drop

### 5.4 Tische & Raum
- **FA-4.1** ✅ Tisch-Formen: rund, rechteckig, quadratisch
- **FA-4.2** ✅ Berechnete Kapazität (60 cm pro Person)
- **FA-4.3** ✅ Tisch-Kombination zu Tafel, U-Form, L-Form, Schiff
- **FA-4.4** ✅ Auto-Platzierung mit Kollisionsvermeidung
- **FA-4.5** ✅ Drag, Rotate, Resize auf Canvas
- **FA-4.6** ✅ Visuelle Statusanzeige (Kapazität "8/10", Allergie-Indikator, Konfliktbanner)
- **FA-4.7** ✅ Pinning — Gäste am zugewiesenen Tisch fixieren

### 5.5 KI-gestützte Tischplanung
- **FA-5.1** ✅ LM Studio Integration (OpenAI-kompatibel, lokal)
- **FA-5.2** ✅ Cluster-Erkennung & Harmonie-Vorschläge
- **FA-5.3** ✅ Strukturierter Sitzplan-Vorschlag mit Begründung
- **FA-5.4** ✅ Algorithmischer Solver als Fallback (Simulated Annealing, Brücken-Personen-Bonus, Generationsmix, Diet-Cluster)
- **FA-5.5** ✅ Apply-Button für KI-Vorschlag
- **FA-5.6** ✅ Iterativer Chat-Modus mit Verbindungs-Status, Quick Actions, klickbaren Beispielprompts und Abbrechen-Button

### 5.6 Export & Caterer
- **FA-6.1** ✅ PDF-Export pro Tisch mit Gästen, Menüwahl, Allergien-Markierung
- **FA-6.2** ✅ Caterer-Zusammenfassung (X Fleisch, Y Vegetarisch, Z Vegan)
- **FA-6.3** ✅ Tischkarten-Export (Name + Fun Fact, druckfertig)
- **FA-6.4** ✅ Gesamt-Übersicht als Plakat / Poster (A3-Querformat)

### 5.7 Onboarding & Hilfe
- **FA-7.1** ✅ Erst-Onboarding (Wizard mit Welcome → Namen → Datum/Location → Done)
- **FA-7.2** ⬜ Empty States mit nächstem-Schritt-Hinweis (Dashboard zeigt "Du hast noch keine Gäste — Datei importieren?")
- **FA-7.3** ⬜ In-App-Hilfe / Tooltip-Schicht für Erst-Nutzer

---

## 6. Nicht-funktionale Anforderungen

| Code | Anforderung |
|---|---|
| **NFA-1** | **Privacy:** Keine Daten verlassen den Mac. Keine Telemetrie. Kein Account. |
| **NFA-2** | **Offline:** Außer KI-Aufrufen (lokales LM Studio) funktioniert alles offline. |
| **NFA-3** | **Performance:** UI bleibt responsiv bei 200 Gästen, 30 Tischen. KI-Aufrufe asynchron mit Cancel. |
| **NFA-4** | **Robustheit:** Crash darf nie Daten verlieren. SwiftData persistiert nach jeder Mutation. |
| **NFA-5** | **Barrierefreiheit:** VoiceOver-tauglich, Tastatur-navigierbar, dynamische Schriftgrößen. |
| **NFA-6** | **Lokalisierung:** Deutsch zuerst, Strings sauber extrahiert für später (Englisch). |
| **NFA-7** | **App-Store-fähig:** Kein Code, der Sandbox bricht. Keine externen Binaries. |

---

## 7. Designprinzipien

Diese fünf Prinzipien entscheiden bei jedem UI-Tradeoff:

1. **Native Apple Look — aber mit Wärme.** Wir bauen mit SwiftUI-Standards (NavigationSplitView, Toolbar, Inspector, SF Symbols, System-Materials). Wärme entsteht durch **Copy, Spacing und einen warmen Akzent**, nicht durch Custom Controls.
2. **Eine Sache pro Bildschirm.** Kein Dashboard mit 12 Widgets. Der nächste sinnvolle Schritt ist immer der prominenteste.
3. **Empty States sind Begrüßungen.** Eine leere Liste ist nicht peinlich — sie ist ein freundlicher Auftakt mit einem klaren CTA.
4. **Sprache ist Teil des Designs.** Wir schreiben "Wir haben 47 Anmeldungen erkannt", nicht "47 entries imported". Wir duzen. Wir benutzen die Wörter, die im Hochzeitskontext echt sind ("Tafel", "Trauzeugen", "Anmeldung").
5. **Fehler sind beruhigend.** Wenn die KI offline ist, sagen wir das ruhig und bieten den Algorithmus als Plan B. Niemals rote Banner ohne Lösung.

---

## 8. Visuelle Sprache

### Look-and-Feel

**Native macOS in System-optimiert, mit einem warmen Akzent.** Heißt: helle Hintergründe nutzen `.regularMaterial` und `.background`. Karten haben weiche Schatten und 12pt Corner Radius. Spacing großzügig (24pt zwischen Sektionen). Dark Mode wird unterstützt.

### Farbpalette (Vorschlag)

System-Semantic-Colors als Basis, plus ein eigener warmer Akzent:

| Token | Light | Dark | Verwendung |
|---|---|---|---|
| **Akzent (primär)** | `#C8788C` (Dusty Rose) | `#E0A0B2` | Buttons, aktive Sidebar-Items, Akzentlinien |
| **Sekundär-Akzent** | `#7A8B6C` (Sage Green) | `#9DAE8E` | Erfolgs-States, "alles passt"-Indikatoren |
| **Warning** | System-Orange | System-Orange | Allergien-Indikator |
| **Error** | System-Red | System-Red | Konflikte, harte Verstöße |
| **Hintergrund** | System | System | `.background` und `.regularMaterial` |
| **Text** | System-Primary | System-Primary | Native Lesbarkeit |

> **Wichtig:** Akzent kann später per Settings auch auf System-Akzent zurückgestellt werden — Open-Source-Nutzer mit eigener Hochzeitsfarbe können ihre Hex-Werte hinterlegen.

### Typografie

- **UI-Standard:** SF Pro (System-Font) — alles Funktionale
- **Headlines mit Wärme:** SF Pro Rounded für `.largeTitle` und Wizard-Schritte — gibt Persönlichkeit ohne Custom-Font
- **Optional Akzent:** New York (Apple-Serif, system-verfügbar) für ein einzelnes "Hero"-Element pro Bildschirm — z.B. Event-Name auf dem Dashboard
- **Größen:** SwiftUI-Defaults respektieren (`.largeTitle`, `.title`, `.headline`, `.body`, `.callout`, `.caption`) — Dynamic Type bleibt funktional

### Iconografie

**Ausschließlich SF Symbols 6.** Keine Custom-Icons in v1. Multicolor-Varianten wo angebracht (z.B. `tablecells` für Tische, `sparkles` für KI, `person.2.wave.2` für Gruppen).

### Bildsprache

- Kein Stockphoto.
- Maximal **ein** abstraktes Hochzeits-Pattern (z.B. dünne wellige Linien in Akzentfarbe) für Onboarding-Screen und Empty States.
- Foto vom echten Grundriss zeigen wir 1:1 — das ist die einzige Stelle wo "echte" Bilder erscheinen.

---

## 9. Tone of Voice

- **Du, nicht Sie.**
- **"Wir" als App-Stimme** — die App ist ein Helfer, kein anonymes Tool ("Wir haben das geprüft", "Wir empfehlen…").
- **Warm, nie kitschig.** Kein "Ihr großer Tag!" — eher "Wenn alle sitzen, ist das Schwerste geschafft."
- **Konkret statt generisch.** Statt "Daten erfolgreich importiert" → "47 Anmeldungen geladen, davon 3 neue."
- **Hochzeits-Vokabular ist erlaubt.** "Tafel", "Anmeldung", "Trauzeuge", "Brautjungfer" — nicht "Long table", "Entry", "Witness".

### Beispiele

| Kontext | Schlecht | Gut |
|---|---|---|
| Empty Guest List | "No data" | "Noch keine Gäste — sobald die ersten Anmeldungen da sind, fang hier an." |
| KI offline | "Connection failed" | "LM Studio antwortet gerade nicht. Wir können den Plan auch ohne KI berechnen." |
| Erfolgs-Toast | "Saved" | "Gespeichert." (Punkt, kein Ausrufezeichen.) |
| Konflikt | "Constraint violation" | "Tante Helga und Onkel Karl sitzen am selben Tisch — du hattest gesagt, das soll nicht sein." |

---

## 10. Key Screens

> Für Designer: das sind die Screens, die zuerst entworfen werden sollten. Reihenfolge nach User-Journey.

### S1 — Willkommen / Erst-Onboarding
- **Zweck:** Erste Begrüßung, Eckdaten erfassen
- **Inhalt:** Großes Headline ("Willkommen bei Gästeglück"), kurzer Satz, Eingabefelder für Partnernamen / Datum / Location, Button "Loslegen"
- **Vibe:** Wie eine Save-the-Date-Karte digital

### S2 — Dashboard
- **Zweck:** Übersicht & nächster Schritt
- **Inhalt:** Event-Header (Namen, Datum, Location), Stat-Karten (Anmeldungen, Gäste, Tische, Allergien), prominente "Was als nächstes"-Karte mit konkretem CTA
- **Vibe:** Ruhig, aufgeräumt, keine Information-Overload

### S3 — Gästeliste
- **Zweck:** Alle Gäste sehen, suchen, bearbeiten
- **Inhalt:** Sidebar (Filter nach Tag/Partner/Status), Tabelle/Liste mit Avatar-Initialen, Tag-Chips, Diet-Indikator, Pinning-Status. Detail-Inspector rechts.
- **Vibe:** Apple Mail / Notes — vertraute Drei-Spalten-Architektur

### S4 — Import-Preview
- **Zweck:** KI-Vorschläge bestätigen
- **Inhalt:** Pro Anmeldung eine Karte: oben Original-Freitext (gedimmt), unten editierbare Gäste-Karten. Buttons "Übernehmen / Korrigieren / Überspringen". Batch-Action oben.
- **Vibe:** Wie Apple Mail Smart Reply — Vorschläge zum schnellen Abnicken

### S5 — Beziehungs-Wizard
- **Zweck:** Tags und Partnerzuordnung
- **Inhalt:** Vollbild-Modal mit Schritt-Indikator. Pro Schritt eine Frage, darunter Optionen als große Touch-Targets.
- **Vibe:** Wie das macOS-Setup-Assistent — fokussiert, eine Frage pro Bildschirm

### S6 — Tisch- & Raumplan-Canvas
- **Zweck:** Räumliche Anordnung & Sitzplan
- **Inhalt:** Drei Panels: Links Gäste-Inbox (gefilterte Liste unzugewiesener Gäste), Mitte Canvas (Grundriss, Tische, Gäste-Avatare), Rechts Inspector / KI-Chat
- **Vibe:** Sketch / Figma trifft Apple Pages — fließend, direktes Manipulieren

### S7 — KI-Vorschlag-Sheet
- **Zweck:** KI generiert Plan, Nutzer entscheidet
- **Inhalt:** Modal Sheet mit kurzer Begründung pro Tisch, "Übernehmen"-Button, "Anpassen"-Chat-Button
- **Vibe:** Vertrauensvoll — die KI erklärt sich

### S8 — Export
- **Zweck:** PDF für Caterer & Tischkarten
- **Inhalt:** Vorschau links, Optionen rechts (welche Sektionen, Allergien hervorheben ja/nein, Logo)
- **Vibe:** Wie Drucker-Dialog — ruhig, vorhersehbar

### S9 — Einstellungen
- **Zweck:** LM Studio konfigurieren, Akzentfarbe, Event-Daten ändern
- **Inhalt:** Tab-Bar oder Liste, klassische macOS-Settings-Form
- **Vibe:** System Settings.app — keine Überraschungen

---

## 11. Component Inventory

Wiederverwendbare Komponenten, die im Designsystem auftauchen sollten:

| Komponente | Beschreibung |
|---|---|
| **Stat Card** | Großes Symbol oben, Zahl in der Mitte, Label unten. Akzent-Tint pro Card. |
| **Guest Avatar** | Initialen-Kreis mit Akzentfarbe basierend auf primärem Tag. Status-Punkt für Allergie. |
| **Tag Chip** | Pill-Form mit Punkt in Tag-Farbe + Label. Klein, mehrere stapelbar. |
| **Empty State** | Großes Symbol (gedimmt), Headline, ein Satz Erklärung, prominenter CTA. |
| **Wizard Step Header** | Schritt X von Y, Headline, Untertitel. Konsistent über alle Wizards. |
| **AI Suggestion Card** | Sparkles-Icon, KI-Text in Quote-Block, Apply / Refine Buttons. |
| **Conflict Banner** | Subtil orange/rot, ein Satz, "Anzeigen"-Button. |
| **Table Canvas Item** | Tisch-Form mit Kapazität-Badge, Drag-Handle, optional Allergie-Outline. |
| **Inspector Section** | Kollabierbare Sektion mit Headline + Inhalt. Padding konsistent. |
| **File Drop Zone** | Gestrichelter Rand, Icon, Drag-Hint. Hover-State mit Akzentfarbe. |

---

## 12. Definition of Done — v1.0

> Dieses ist der Stand, der eine Public Beta / App Store Submission rechtfertigt.

**Funktional:**
- Alle FA mit ✅ stabil, alle 🟡 → ✅, alle ⬜ in 5.6 (Tischkarten-Export) und 5.7 (Empty States, In-App-Hilfe) → ✅
- FA-2.6 (Google-Sheets-Import) implementiert
- Onboarding führt eine neue Nutzerin in unter 5 Minuten zum ersten KI-Vorschlag

**Qualität:**
- Crash-Free auf Test-Datasets von 50, 150 und 250 Gästen
- VoiceOver-Lauf durch jede Hauptansicht ohne Sackgassen
- Lokalisierung sauber (alle Strings extrahiert)
- App-Icon, Marketing-Screenshots, Datenschutzerklärung vorbereitet

**Design:**
- Alle 9 Key Screens entworfen, in SwiftUI implementiert, mit dem Akzent-System gebrandet
- Empty States für: keine Gäste, kein Tisch, kein Tag, keine KI-Verbindung
- Light + Dark Mode sauber

**Out-of-Scope für v1.0** (explizit nicht):
- iOS / iPad Build (braucht Apple Developer Account)
- Cloud-Sync, Real-Time Collaboration
- Echte Google-Sheets-API mit OAuth (nur Public-CSV-Export-URL)
- Multi-Event-UI
- Foto-basierte Namenserkennung
- Einladungs-Management

---

## 13. Roadmap nach v1.0

| Version | Thema | Highlights |
|---|---|---|
| v1.1 | Polish | Animationen, Sound-Design (dezent, Glas-Klick beim Setzen), Tutorial-Video |
| v1.2 | Multi-Event | Eventliste, Event-Switcher, Vorlagen aus früheren Hochzeiten |
| v2.0 | iPad | iPad-Native UI mit Pencil-Support für Raumplan, On-Device LLM (MLX/CoreML), iCloud-Sync mit CloudKit |
| v2.x | Open Source | Public Repo, README, Contribution Guide, eigene Akzentfarben |
| v3.0 | App Store | Release auf macOS App Store, optional iPad-Pendant |

---

## 14. Abgrenzung — Was Gästeglück bewusst NICHT ist

- **Kein Cloud-Tool.** Keine Server, keine Accounts, keine SaaS.
- **Kein Einladungs-Manager.** Wir machen den Sitzplan, nicht die Save-the-Dates.
- **Keine Profi-Eventsoftware.** Bis 200 Gäste, ein Hauptraum.
- **Kein Real-Time-Collab.** Ein Paar, ein Mac, ein Plan.
- **Keine Stockphoto-Galerie.** Wir liefern keine "Hochzeitstrend 2026"-Inhalte.
- **Keine Cloud-KI.** Wenn das Paar will, soll alles lokal laufen können.

---

## 15. Erfolgsdefinition (qualitativ)

Wir sind erfolgreich, wenn ein Paar uns nach der Hochzeit schreibt:

> "Den Sitzplan haben wir an einem Sonntagnachmittag gemacht. Es hat keinen Streit gegeben. Bis zur Hochzeit haben wir ihn nur noch dreimal angefasst. Eure App hat einfach gemacht."

Daran richten wir alles aus.
