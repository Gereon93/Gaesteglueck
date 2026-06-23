# AGENTS.md

> Drop this at the repository root. Codex applies the closest `AGENTS.md` to each
> changed file, so you can place a more specific one deeper in the tree if a
> package needs extra scrutiny. Edit the Project context / Tech stack per repo.

## Project context

<!-- One or two lines: what this repo does, who/what consumes it. Edit per repo. -->
Gästeglück ist ein macOS-nativer Hochzeits-Sitzplaner mit optionaler lokaler KI
(LM Studio, OpenRouter, Apple Intelligence). Entwickelt für die eigene Hochzeit
und dort produktiv eingesetzt. Komplett lokal, keine Cloud, keine Accounts.

## Tech stack

- Swift 6 (strikte Concurrency, `@MainActor`, `actor`, `Sendable`)
- SwiftUI (macOS 15+, experimentelles iPad-Target)
- SwiftData mit `VersionedSchema` + manuellen Migrationen (V1–V5)
- Build: Swift Package Manager (`Package.swift`)
- Architektur: MV (Model-View) + Service Layer, **kein** MVVM, **kein** DDD/CQRS
- Sprache: Deutsch in Code, Kommentaren, Commits, Docs und UI

## Review guidelines

Codex surfaced nur **P0** und **P1** findings on GitHub pull requests. Anything
lower will not appear, so everything worth a human's attention belongs in one of
these two buckets.

**Guiding principle: behavior first.** A change that compiles and reads cleanly
but breaks or silently alters an intended process or UI/UX flow is worse than a
style issue. Verify the code does what it is supposed to do before commenting on
how it is written. Function follows design.

### P0 — block the merge

- **Behavioral regressions:** the change breaks or silently alters an existing
  process, workflow, or UI/UX behavior, or the implemented behavior does not
  match the apparent intent of the PR.
- **Security:** hardcoded secrets / keys / connection strings, missing auth or
  authorization checks, injection (SQL, command, path), unsafe deserialization,
  logging of PII or credentials. API-Keys müssen im Keychain, nicht in
  UserDefaults.
- **Swift 6 Concurrency:**
  - `nonisolated(unsafe)` mutable statics ohne Synchronisation (Data Race).
  - `@MainActor`-Verletzung: SwiftData `ModelContext`-Mutationen off-main.
  - Actor-Isolation umgangen (z.B. sync Zugriff auf actor state).
  - `Sendable`-Violations: non-Sendable types über Isolation-Grenzen.
- **SwiftData correctness:**
  - Force unwrap auf Optional-Relationships (`guest.table!.id`) ohne guard.
  - Schema-Migration ohne Pre-Launch-Backup-Test.
  - `try?` auf kritischen Operationen (Migration, Backup, Store-Copy) ohne
    Logging — Fehler werden verschluckt.
- **Data correctness:** money / decimal rounding errors, off-by-one, null or
  empty edge cases that change results. Bei Gästeglück: Kapazitätsberechnung
  (60 cm pro Person), Füllgrad-Berechnung, Constraint-Verletzungen.
- **Resource leaks:** undisposed `IDisposable`, unclosed streams / connections,
  mishandled `CancellationToken`. In Swift: offene `FileHandle`, `CGContext`,
  `ModelContext` ohne save.
- **Untested behavior:** new or changed behavior shipped without test coverage
  (see Testing expectations).

### P1 — should fix

- **Architecture (MV + Service Layer):**
  - View enthält Geschäftslogik statt Service zu callen.
  - Service hat UI-Code (`View`, `Color`, `Font`).
  - SwiftData-Query direkt in View statt über `@Query` (reaktiv).
  - State management: `@State` vs `@Binding` vs `@Observable` falsch eingesetzt.
- **Clean Code:**
  - Single-responsibility violations: Methods oder Types doing too much.
  - Dateien > 500 Zeilen ohne klare `// MARK:`-Section-Struktur.
  - Duplicierter Code über 3+ Dateien (z.B. `drawText`-Helper in 5 PDF-Exportern).
  - Primitive obsession: Magic numbers statt benannter Konstanten.
- **Error handling:**
  - Swallowed exceptions: `try?` ohne Logging oder Fallback.
  - Catch-all ohne Kontext: `catch { print(error) }`.
  - Control flow driven by exceptions statt Result-Types.
- **Test gaps:**
  - Missing integration test for changes that cross a boundary (SwiftData, HTTP,
    File I/O).
  - Unit tests that assert nothing meaningful or only cover the happy path.
  - LLM-Client-Tests ohne Mock (Integration-Tests gegen echte API).
- **Performance:**
  - N+1 queries: SwiftData `@Query` in Loop statt batch fetch.
  - Materializing before filtering: `Array(guests).filter` statt `#Predicate`.
  - Avoidable allocations in hot paths (z.B. SeatingOptimizer mit 6000 Iterationen).
  - Missing `async` on IO-bound work (LLM-Calls, File I/O, HTTP).
- **Contract changes:**
  - Public API, Events, oder DTOs changed without updated docs / changelog or a
    migration note.
  - SwiftData-Schema geändert ohne `VersionedSchema` + Migration.
  - LLM-Prompt geändert ohne `eval/`-Test-Update.
- **Validation:**
  - Missing input validation at trust boundaries (CSV-Import, LLM-JSON-Response).
  - Keine Kapazitätsprüfung vor `GuestTable.guests.append`.
- **Explanatory comments are a smell:**
  - Flag any comment that describes *what* the code does or *how* it works.
  - The fix is not a better comment but clearer code: extract a well-named
    method, rename variables, simplify control flow so the intent is obvious
    without prose. Recommend the refactor, never a reworded comment.
  - Ausnahme: `// MARK:`-Sections sind Konvention in Swift, kein Smell.
- **Magic numbers and unexplained literals:**
  - Flag them. They must become named constants whose name carries the meaning.
  - Beispiele: Scoring-Gewichte (`100`, `-500`, `70`, `40`), SA-Parameter
    (`6000`, `60`, `0.05`), PDF-Dimensionen (`595`, `842`).
  - Fix: `enum ScoringConstants { static let mustSitTogether = 100 }`.
  - This is a pure refactor, unrelated to ADRs.
- **Plattform-Guards:**
  - macOS-only Code ohne `#if os(macOS)` Guard.
  - AppKit/UIKit-Typen direkt statt `PlatformImage`-Alias.
  - Conditional compilation für iPad-Target (`#if canImport(SwiftUI)`).

### Testing expectations

- New behavior needs unit tests. Behavior that crosses a boundary (SwiftData,
  HTTP, File I/O) needs an integration test as well.
- Tests must cover failure and edge cases, not only the happy path.
- Flag assertions that do not actually verify the intended outcome.
- LLM-Feature-Tests: Mock `LLMClient`-Protocol, teste JSON-Parsing und
  Fallback-Strategien, nicht echte API-Calls.
- Prompt-Regression: Änderungen an `systemPrompt`-Strings erfordern Update in
  `eval/test_prompts.py`.

### What NOT to flag

- Formatting, whitespace, import ordering, and casing already enforced by the
  analyzers / formatter and the build (`swift-format`). Do not duplicate tooling.
- Subjective style preferences with no maintainability impact.
- Pre-existing issues unrelated to the diff, unless the change makes them
  materially worse.
- A comment that *only* references an ADR (e.g. `// rationale: ADR-0012`). It
  explains nothing inline; it points to where the decision lives. That is the
  intended way to keep the "why" without explanatory comments.
- `// MARK:`-Sections — Swift-Konvention für Strukturierung, kein Smell.
- XML doc comments (`///`) on public / published API surface, where they drive
  IntelliSense or generated docs. (Remove this carve-out if you want zero
  comments of any kind, including on internal code.)
- Deutsche Sprache in Code/Kommentaren — ist Konvention für dieses Repo, nicht
  flaggen.

Keep comments specific and actionable: state the risk, point to the line,
suggest the fix. If an assumption in the code is not guaranteed to hold, say so
rather than letting it pass.

## Build & Test commands

```bash
swift build                       # Bauen
swift test                        # Tests (225 Tests in 44 Suites)
swift-format lint --recursive Sources/ Tests/ --strict   # Lint (CI)
./scripts/build-macos-app.sh      # .app-Bundle nach dist/
```

## Conventions

- **Sprache:** Deutsch in Code-Kommentaren, Commits, Docs und UI.
- **Kommentare:** sparsam. Nicht-triviale Begründungen als erklärende Methode
  oder Spec, nicht als Inline-Kommentar.
- **Commits:** pro logischem Arbeitspaket, kein Sammel-Commit.
- **Tests:** Logik in Services/Models testbar halten; Views dünn.
- **Architecture:** MV + Service Layer. Views queryn SwiftData via `@Query`,
  Services sind stateless (`enum`/`struct` mit `static func`).
- **Concurrency:** `@MainActor` auf Views und Model-Mutationen. LLM-Clients
  sind `actor`. Services sind `nonisolated` (stateless).
- **Error handling:** `try?` nur für nicht-kritische Operationen. Kritische
  Operationen (Migration, Backup, Import) mit `do/catch` + Logging.
