r"""Zieht die System-Prompts aus den Swift-Quellen — Single Source of Truth.

Kein Duplikat das verrottet: der Eval testet exakt den Prompt der im
Produktionscode steht. Best-effort-Parser für Swift-Multiline-Strings,
inkl. Entfernen der Backslash-Zeilen-Fortsetzungen (Swift hängt solche
Zeilen ohne Newline aneinander).
"""

from __future__ import annotations

import re
import sys
import textwrap
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = Path(__file__).resolve().parent / "prompts"

# (Ziel-Dateiname, Swift-Quelle relativ zum Repo)
TARGETS = {
    "funfact_normalizer": "Sources/Gaesteglueck/Services/FunFactNormalizer.swift",
    "funfact_validator": "Sources/Gaesteglueck/Services/FunFactValidator.swift",
}

# matcht:  (private )?static let systemPrompt = """ ... """
PATTERN = re.compile(
    r'static let systemPrompt\s*=\s*"""(.*?)"""',
    re.DOTALL,
)


def normalize(raw: str) -> str:
    # Swift entfernt bei `\` am Zeilenende den Umbruch -> nachbilden.
    joined = re.sub(r"\\\n", "", raw)
    # Führende/abschließende Leerzeile der Delimiter loswerden, dann dedent.
    joined = joined.strip("\n")
    dedented = textwrap.dedent(joined)
    # Mehrfach-Spaces (entstehen an den \-Joins) auf ein Space kollabieren,
    # Zeilenstruktur aber erhalten.
    lines = [re.sub(r"[ \t]{2,}", " ", ln).rstrip() for ln in dedented.splitlines()]
    return "\n".join(lines).strip()


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    failed = False
    for name, rel in TARGETS.items():
        src = REPO / rel
        text = src.read_text(encoding="utf-8")
        m = PATTERN.search(text)
        if not m:
            print(f"FEHLER: kein systemPrompt in {rel}", file=sys.stderr)
            failed = True
            continue
        prompt = normalize(m.group(1))
        if len(prompt) < 50:
            print(f"FEHLER: Prompt aus {rel} verdächtig kurz ({len(prompt)})",
                  file=sys.stderr)
            failed = True
            continue
        (OUT / f"{name}.txt").write_text(prompt + "\n", encoding="utf-8")
        print(f"OK: {name} ({len(prompt)} Zeichen)")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
