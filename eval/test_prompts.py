"""CI-Gate: greifen die Produktions-Prompts noch wie erwartet?

Läuft beim Merge auf main. Extrahiert die ECHTEN Swift-System-Prompts,
schickt Golden-Inputs über OpenRouter durch und prüft:
  1. deterministisch (gratis): JSON-Struktur, 1.-Person-Form, Verdict-Werte
  2. semantisch (GEval-Judge): Fakten erhalten, Bewertung plausibel

Schlägt ein Check fehl -> pytest rot -> Merge-Gate blockt.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
from deepeval import assert_test
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCase, SingleTurnParams

from openrouter import OpenRouterJudge, run_system_under_test

PROMPTS = Path(__file__).resolve().parent / "prompts"


def _load(name: str) -> str:
    p = PROMPTS / f"{name}.txt"
    assert p.exists(), f"Prompt {name} fehlt — extract_prompts.py zuerst laufen lassen."
    return p.read_text(encoding="utf-8")


def _extract_json(text: str) -> dict:
    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
    raw = fenced.group(1) if fenced else None
    if raw is None:
        s, e = text.find("{"), text.rfind("}")
        assert s != -1 and e != -1 and s < e, f"Kein JSON in Antwort:\n{text[:300]}"
        raw = text[s : e + 1]
    return json.loads(raw)


# ---------------------------------------------------------------- Normalizer

NORMALIZER_GOLDENS = [
    {
        "user": '## FunFacts\n- G1: "Ist den Jakobsweg rückwärts gelaufen"\n'
                '- G2: "Hat schon über zweihundert Socken gestrickt"',
        "ids": ["G1", "G2"],
        "originals": 'Original-FunFacts:\n'
                     '1) "Ist den Jakobsweg rückwärts gelaufen"\n'
                     '2) "Hat schon über zweihundert Socken gestrickt"',
    },
    {
        "user": '## FunFacts\n- G1: "90min war ich Stadionsprecher"',
        "ids": ["G1"],
        "originals": 'Original-FunFacts:\n1) "90min war ich Stadionsprecher"',
    },
]


@pytest.mark.parametrize("golden", NORMALIZER_GOLDENS)
def test_funfact_normalizer_prompt(golden):
    system = _load("funfact_normalizer")
    output = run_system_under_test(system, golden["user"])
    data = _extract_json(output)

    # 1) Struktur deterministisch
    assert "results" in data and isinstance(data["results"], list)
    got_ids = {r["id"] for r in data["results"]}
    assert set(golden["ids"]).issubset(got_ids), f"IDs fehlen: {got_ids}"

    # 2) 1.-Person-Form deterministisch
    for r in data["results"]:
        text = r["text"].strip()
        assert text.lower().startswith("ich"), f"nicht 1. Person: {text!r}"
        assert text.endswith("."), f"kein Satz-Punkt: {text!r}"

    # 3) Fakten erhalten — semantisch (GEval-Judge).
    #    Referenz = die ECHTEN Original-FunFacts (nicht eine verkürzte Notiz).
    #    Wichtig: Wechsel in 1. Person + Grammatik-Glättung ist GEWOLLT und
    #    darf NICHT bestraft werden — nur inhaltliche Abweichung zählt.
    joined = " | ".join(r["text"] for r in data["results"])
    metric = GEval(
        name="FaktenErhalten",
        criteria=(
            "Im 'input' stehen Original-FunFacts, im 'actual output' die "
            "umgeschriebene Version. Bewerte NUR ob dieselben Fakten erhalten "
            "sind. Der Wechsel in die 1. Person ('Ich ...') und das Glätten "
            "der Grammatik sind ausdrücklich GEWÜNSCHT und dürfen NICHT als "
            "Abweichung gewertet werden. Schlecht ist NUR: ein Fakt wurde "
            "erfunden, weggelassen oder inhaltlich verändert."
        ),
        evaluation_params=[
            SingleTurnParams.INPUT,
            SingleTurnParams.ACTUAL_OUTPUT,
        ],
        threshold=0.7,
        model=OpenRouterJudge(),
    )
    assert_test(
        LLMTestCase(input=golden["originals"], actual_output=joined),
        [metric],
    )


# ---------------------------------------------------------------- Validator

VALIDATOR_GOLDENS = [
    {
        "user": '## Gäste\n- G1: Anna M — "Ist schon mal von einem Tretboot '
                'in den Ententeich gefallen"',
        "expect": {"G1": "good"},
    },
    {
        "user": '## Gäste\n- G1: Bert K — "Hobby"',
        "expect": {"G1": "generic"},
    },
]


@pytest.mark.parametrize("golden", VALIDATOR_GOLDENS)
def test_funfact_validator_prompt(golden):
    system = _load("funfact_validator")
    output = run_system_under_test(system, golden["user"])
    data = _extract_json(output)

    assert "results" in data and isinstance(data["results"], list)
    verdicts = {r["id"]: r["verdict"] for r in data["results"]}
    for gid, expected in golden["expect"].items():
        assert gid in verdicts, f"{gid} fehlt in Antwort"
        assert verdicts[gid] in {"good", "generic"}, f"ungültiges Verdict: {verdicts[gid]}"
        assert verdicts[gid] == expected, (
            f"{gid}: erwartet {expected}, bekam {verdicts[gid]} — "
            f"Prompt greift nicht mehr wie erwartet."
        )
