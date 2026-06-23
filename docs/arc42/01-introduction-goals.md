# 1. Einführung und Ziele

## 1.1 Aufgabenstellung

Gästeglück ist ein macOS-native Hochzeits-Sitzplaner, der Paaren den organisatorischen Aufwand
rund um die Sitzordnung abnimmt: Vom Import der Gästeanmeldungen über die Pflege von Beziehungen
und Tags bis zum KI-gestützten Sitzplan-Vorschlag und dem PDF-Export für den Caterer.

Das System wurde für die eigene Hochzeit des Entwicklers gebaut und dort produktiv eingesetzt.

## 1.2 Qualitätsziele

| Priorität | Ziel | Szenario |
|-----------|------|----------|
| 1 | **Privatsphäre** | By default verlassen keine Gästedaten den Mac. Keine Cloud, kein Account, keine Telemetrie. KI läuft lokal via LM Studio – nur bei expliziter Konfiguration eines Cloud-Providers (z.B. OpenRouter) werden Prompt-Daten übertragen. |
| 1 | **Datensicherheit** | Crash darf nie Daten verlieren. SwiftData persistiert nach jeder Mutation. Pre-Launch-Backups mit Retention 3. |
| 2 | **Benutzbarkeit** | Ein Paar ohne Anleitung kommt vom Excel-Import zum ersten Sitzplan-Vorschlag in unter 30 Minuten. |
| 2 | **Iterierbarkeit** | Der Sitzplan wird über Tage/Wochen immer wieder angepasst (Absagen, Umsetzungen). Diese Änderungen sind Erstklass-Workflows. |
| 3 | **Performance** | UI bleibt responsiv bei 200 Gästen und 30 Tischen. KI-Aufrufe asynchron mit Abbrechen-Möglichkeit. |
| 3 | **Ästhetik** | Die App sieht nicht aus wie ein Entwickler-Tool. Warmes, persönliches Design nach Apple-HIG mit warmem Akzent. |

## 1.3 Stakeholder

| Stakeholder | Erwartungshaltung |
|-------------|-------------------|
| Brautpaar (Endnutzer) | Intuitive Bedienung, schöner Sitzplan, Caterer-Listen ohne Fehler |
| Trauzeugen / Helfer | Einfacher Zugang ohne Einarbeitung |
| Entwickler | Wartbarer Swift-6-Code, strikte Concurrency, gute Testabdeckung |
| Caterer / Service | Korrekte Menü-Zählungen, Allergie-Infos, Spätabsage-Vermerk |
