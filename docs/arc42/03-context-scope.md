# 3. Kontextabgrenzung

## Fachlicher Kontext

```
┌─────────────────────────────────────────────────────────┐
│                    Gästeglück                           │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │  Gäste-  │  │  Sitz-   │  │  Export  │             │
│  │  Import  │  │  plan    │  │  & PDF   │             │
│  └──────────┘  └──────────┘  └──────────┘             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │  Tag-    │  │  Raum-   │  │  Fun     │             │
│  │  System  │  │  Canvas  │  │  Facts   │             │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
```

## Technischer Kontext

```
┌─────────────────────────────────────────────────────────────────┐
│                        Gästeglück                               │
│                                                                 │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐  │
│  │  CSV/Excel  │────▶│  Import-     │────▶│  SwiftData      │  │
│  │  Dateien    │     │  Pipeline    │     │  (lokal)        │  │
│  └─────────────┘     └──────────────┘     └─────────────────┘  │
│                                                                 │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐  │
│  │  Google     │────▶│  Google      │     │  PDF / PNG /    │  │
│  │  Sheets     │     │  Sheets API  │     │  CSV / vCard /  │  │
│  └─────────────┘     └──────────────┘     │  Markdown       │  │
│                                            └─────────────────┘  │
│  ┌─────────────┐     ┌──────────────┐                           │
│  │  LM Studio  │◀───▶│  LLM-Client  │                           │
│  │  (lokal)    │     │  (Protocol)  │                           │
│  └─────────────┘     └──────────────┘                           │
│  ┌─────────────┐     ┌──────────────┐                           │
│  │  OpenRouter │◀───▶│  (3 Impl.)   │                           │
│  │  (Cloud)    │     └──────────────┘                           │
│  └─────────────┘                                                │
│  ┌─────────────┐     ┌──────────────┐                           │
│  │  Apple      │◀───▶│  Foundation  │                           │
│  │  Intelligence│    │  Models      │                           │
│  └─────────────┘     └──────────────┘                           │
│                                                                 │
│  ┌─────────────┐     ┌──────────────┐                           │
│  │  macOS      │◀───▶│  Contacts    │                           │
│  │  Contacts   │     │  Service     │                           │
│  └─────────────┘     └──────────────┘                           │
│                                                                 │
│  ┌─────────────┐     ┌──────────────┐                           │
│  │  macOS      │◀───▶│  Keychain    │                           │
│  │  Keychain   │     │  Store       │                           │
│  └─────────────┘     └──────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
```

### Externe Schnittstellen

| System | Art | Richtung | Zweck |
|--------|-----|----------|-------|
| CSV/Excel-Dateien | Datei-Import | Input | Gast-Anmeldungen aus Google Forms, Excel |
| Google Sheets (public CSV) | HTTP GET | Input | Live-Import aus öffentlich geteilten Sheets |
| LM Studio | HTTP REST (OpenAI-kompatibel) | Bidirektional | Lokale KI-Anfragen (Parsing, Tags, Sitzplan, Chat, Fun Facts) |
| OpenRouter | HTTPS REST | Bidirektional | Cloud-KI-Anfragen (alternative zu LM Studio) |
| Apple Intelligence | System framework | Bidirektional | On-Device KI (macOS 26+) |
| macOS Contacts | Contacts.framework | Input | Telefonnummern für Gäste suchen |
| macOS Keychain | Security.framework | Output | API-Keys sicher speichern |
| Dateisystem | Files | Output | PDF/PNG/CSV/vCard/Markdown-Exporte |
