# Gäste-Export für die Rede (Speech Guest Export)

**Datum:** 2026-06-01
**Status:** Genehmigt, in Umsetzung

## Problem

Für die Hochzeitsrede sollen die Gäste vorgestellt werden. Die Gäste sind über
**Tags** kategorisiert (Hochzeitsrollen/Jobs, „woher kennen wir die": Familie,
Schule, Studium, Hobby …) und über `partnerAssignment` einer Partnerseite
zugeordnet. Es fehlt ein Export, der dieses Material strukturiert herausgibt,
damit man es in Claude Desktop zu einer Rede verarbeiten kann.

## Output

Eine **Markdown-Datei** `Gaeste-Rede-{Event}.md`, als neue Export-Option
(Checkbox „Gäste für die Rede") in der bestehenden Export-Ansicht. Markdown,
weil ein LLM das verlustfrei liest; PDF wäre für die Weiterverarbeitung
schlechter.

**Nur Anwesende** (`countsForSeating == true`) — abgesagte Gäste tauchen nicht
auf (Verknüpfung zu Feature A). Der Sitzplatz ist irrelevant; alle anwesenden
Gäste kommen rein.

## Gliederung — nach Seite → dann Tag-Kategorie

```
# Gäste – Vorstellung für die Rede
Hochzeit von {Partner1} & {Partner2} · {Datum}
_Kontext: pro Gast Name, Beziehung (Tags), Beruf, FunFact, Hobbys – Material für eine Rede._

## Seite {Partner1}
### Hochzeitsrollen
- **Dr. Max Mustermann** — Trauzeuge
  - Woher wir uns kennen: Studium, Kletter-Crew
  - Beruf: Architekt bei XY · Familie: Cousin · Alter: 34
  - FunFact: …
  - Hobbys: Klettern, Kochen · Sprachen: DE, EN
  - Notizen: …
### Familie
### Freunde (Schule, Studium, Hobby …)
### Arbeit
### Sonstige
### Ohne Tag
## Seite {Partner2}
## Beide
## Ohne Zuordnung
```

## Zuordnungs-Regeln

- **Seite:** `guest.partnerAssignment`; falls `.unassigned`, read-only abgeleitet
  via `PartnerSideDeriver.derive(for:from:)` (ändert keine Daten). Reihenfolge:
  Partner1, Partner2, Beide, Ohne Zuordnung. Leere Seiten werden weggelassen.
- **Kategorie-Bucket** (jeder Gast genau **einmal**, in seinem wichtigsten):
  Priorität `Hochzeitsrolle → Familie → Freunde (Freundesgruppe+Aktivität) →
  Arbeitskontext → Eigene → Ohne Tag`. Nur **aktive** Tags zählen (`isActive`).
- Die **gesamten** aktiven Tags des Gasts werden im Eintrag unter „Woher wir uns
  kennen" gelistet — nichts geht durch die Bucket-Wahl verloren.
- Gäste innerhalb eines Buckets alphabetisch nach `fullName`.

## Pro-Gast-Inhalt (leere Felder weglassen)

`title + fullName` (fett) · Rollen-Tags inline · „Woher wir uns kennen" (alle
Tags) · Beruf (`profession` „bei" `employer`) · `familyRole` · `age` ·
`funFactDisplay` · `hobbies` · `languages` · `notes`.

## Technik

- Reiner `SpeechGuestExporter`:
  - `generateMarkdown(guests:tags:event:) -> String` (testbar)
  - `generate(guests:tags:event:) -> Data` (UTF-8 der Markdown)
- Integration in `ExportView` analog zu den anderen Exportern: `@State
  includeSpeechGuests`, `CheckRow`, `items.append(ExportItem(...))`.
- Gleicher Branch/PR wie Feature A.

## Tests

- Abgesagte werden ausgeschlossen.
- Gast landet auf korrekter Seite (direkt + abgeleitet aus Tag).
- Bucket-Priorität: Rolle schlägt Freund; alle Tags trotzdem gelistet.
- Inhalt: FunFact/Beruf erscheinen, leere Felder fehlen.
- Markdown enthält erwartete Überschriften.

## Bewusst draußen (YAGNI)

Kein PDF, keine KI-Vorformulierung der Rede (macht Claude Desktop), keine Fotos.
