# Prompt-Eval (CI-Gate)

Prüft beim **Merge auf `main`** ob die KI-Produktions-Prompts noch greifen
wie erwartet. Kein Runtime-Code — reines CI-Sicherheitsnetz.

## Was passiert

1. `extract_prompts.py` zieht die `systemPrompt`-Strings **direkt aus den
   Swift-Quellen** (`FunFactNormalizer.swift`, `FunFactValidator.swift`).
   Single Source of Truth — kein Prompt-Duplikat das verrottet.
2. `test_prompts.py` schickt feste Golden-Inputs mit dem echten Prompt über
   **OpenRouter** und prüft:
   - deterministisch (gratis): JSON-Struktur, 1.-Person-Form, Verdict-Werte
   - semantisch (deepeval `GEval`, OpenRouter als Judge): Fakten erhalten
3. Schlägt ein Check fehl → pytest rot → Merge-Gate blockt.

## CI

Job `prompt-eval` in `.github/workflows/ci.yml`, läuft nur bei Push auf
`main`. Ohne Secret wird **sauber übersprungen** (Warnung statt rot).

**Einmalig einrichten:** GitHub → Repo → Settings → Secrets and variables →
Actions → New repository secret:

- `OPENROUTER_API_KEY` = dein OpenRouter-Key (Pflicht, sonst skip)
- optional Variables: `EVAL_SUT_MODEL`, `EVAL_JUDGE_MODEL`
  (Default je `openai/gpt-4o-mini` — günstig)

Kosten pro Lauf: ~6 kleine Calls (4 System-under-Test + 2 Judge). Mit
gpt-4o-mini grob < 1 Cent.

## Lokal laufen lassen

```bash
cd eval
pip install -r requirements.txt
python extract_prompts.py
OPENROUTER_API_KEY=sk-or-... python -m pytest -v
```

## Golden-Cases erweitern

`NORMALIZER_GOLDENS` / `VALIDATOR_GOLDENS` in `test_prompts.py`. Klein
halten — jeder Case kostet echte API-Calls pro CI-Lauf.

## Prompt bewusst geändert?

Wenn ein Test rot wird **weil** du den Prompt absichtlich geändert hast:
Golden-Cases/Erwartungen mit anpassen. Der Test schützt vor *versehentlicher*
Prompt-Regression, nicht vor bewussten Änderungen.
