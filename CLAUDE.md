# CLAUDE.md (Global Standard)

## 🤖 Claude Modus & Mindset
- **Rolle:** Senior Software Architect & Enterprise Professional.
- **Prinzip:** Erst Discovery (VISION.md/SPEC.md), dann Planung (PROJECT_STATE.md), dann Execution.
- **Qualität:** DDD, TDD, Clean Architecture, SOLID.
- **Handover:** Aktualisiere `PROJECT_STATE.md` vor JEDEM Session-Ende.

## 🛠️ Global Tooling & Orchestration (Mandatory)
### 1. Multi-Agent Flow (Octopus/Maestro)
- **Lead:** Claude Code (Execution).
- **Auditor:** Gemini (via Maestro CLI) für Code-Reviews und Architektur-Checks.
- **Rule:** Nutze Gemini für Research-Tasks mit großem Kontext (>100k Tokens).

### 2. Knowledge Graphen (LSP & Graph)
- **GitNexus:** Nutze `query` und `impact` Tools für High-Level Flows.
- **Codegraph:** Nutze `codegraph diff-impact --staged` vor jedem Commit.
- **LSP:** Nutze immer `kotlin-lsp` oder `csharp-lsp` für Typsicherheit.

## 🔄 Standard Workflow
1. **Sync:** Führe `npx gitnexus analyze` oder `codegraph build` aus, wenn der Index stale ist.
2. **Plan:** Dokumentiere den nächsten Schritt in `PROJECT_STATE.md`.
3. **Review:** Nach dem Coden `gemini maestro:review` triggern (via Maestro Hook).

## 📂 Projekt-Spezifisches (Hier anpassen)
- **Stack:** Swift/iOS
- **GitNexus ID:** Gaesteglueck
- **Tests:** swift test

<!-- gitnexus:start -->
# GitNexus MCP

This project is indexed by GitNexus as **Gaesteglueck** (39 symbols, 30 relationships, 0 execution flows).

GitNexus provides a knowledge graph over this codebase — call chains, blast radius, execution flows, and semantic search.

## Always Start Here

For any task involving code understanding, debugging, impact analysis, or refactoring, you must:

1. **Read `gitnexus://repo/{name}/context`** — codebase overview + check index freshness
2. **Match your task to a skill below** and **read that skill file**
3. **Follow the skill's workflow and checklist**

> If step 1 warns the index is stale, run `npx gitnexus analyze` in the terminal first.

## Skills

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/refactoring/SKILL.md` |

## Tools Reference

| Tool | What it gives you |
|------|-------------------|
| `query` | Process-grouped code intelligence — execution flows related to a concept |
| `context` | 360-degree symbol view — categorized refs, processes it participates in |
| `impact` | Symbol blast radius — what breaks at depth 1/2/3 with confidence |
| `detect_changes` | Git-diff impact — what do your current changes affect |
| `rename` | Multi-file coordinated rename with confidence-tagged edits |
| `cypher` | Raw graph queries (read `gitnexus://repo/{name}/schema` first) |
| `list_repos` | Discover indexed repos |

## Resources Reference

Lightweight reads (~100-500 tokens) for navigation:

| Resource | Content |
|----------|---------|
| `gitnexus://repo/{name}/context` | Stats, staleness check |
| `gitnexus://repo/{name}/clusters` | All functional areas with cohesion scores |
| `gitnexus://repo/{name}/cluster/{clusterName}` | Area members |
| `gitnexus://repo/{name}/processes` | All execution flows |
| `gitnexus://repo/{name}/process/{processName}` | Step-by-step trace |
| `gitnexus://repo/{name}/schema` | Graph schema for Cypher |

## Graph Schema

**Nodes:** File, Function, Class, Interface, Method, Community, Process
**Edges (via CodeRelation.type):** CALLS, IMPORTS, EXTENDS, IMPLEMENTS, DEFINES, MEMBER_OF, STEP_IN_PROCESS

```cypher
MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(f:Function {name: "myFunc"})
RETURN caller.name, caller.filePath
```

<!-- gitnexus:end -->
