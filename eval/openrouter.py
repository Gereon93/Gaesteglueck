"""OpenRouter-Anbindung für den Eval.

Zwei Rollen, beide über OpenRouter (OpenAI-kompatibel):
1. System-under-Test: unser extrahierter Swift-System-Prompt + Golden-Input
   -> echte Modell-Antwort die geprüft wird.
2. Judge: deepeval-GEval bewertet die Antwort (eigenes, ggf. stärkeres Modell).

Modelle via ENV, damit Kosten im CI steuerbar bleiben.
"""

from __future__ import annotations

import os

import requests
from deepeval.models import DeepEvalBaseLLM

BASE_URL = "https://openrouter.ai/api/v1/chat/completions"
SUT_MODEL = os.environ.get("EVAL_SUT_MODEL", "openai/gpt-4o-mini")
JUDGE_MODEL = os.environ.get("EVAL_JUDGE_MODEL", "openai/gpt-4o-mini")


def _api_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if not key:
        raise RuntimeError("OPENROUTER_API_KEY ist nicht gesetzt.")
    return key


def chat(system: str, user: str, model: str, temperature: float = 0.2) -> str:
    """Ein einzelner Chat-Completion-Call gegen OpenRouter."""
    resp = requests.post(
        BASE_URL,
        headers={
            "Authorization": f"Bearer {_api_key()}",
            # OpenRouter füllt die "App"-Spalte aus HTTP-Referer; eigener
            # Wert damit Eval-Calls im Dashboard klar unterscheidbar sind.
            "HTTP-Referer": "https://gaesteglueck.app/deepeval-ci",
            "X-Title": "Gästeglück-deepeval-ci",
        },
        json={
            "model": model,
            "temperature": temperature,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        },
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"]


def run_system_under_test(system_prompt: str, user_input: str) -> str:
    """Führt den ECHTEN Swift-System-Prompt aus -> die zu prüfende Antwort."""
    return chat(system_prompt, user_input, SUT_MODEL)


class OpenRouterJudge(DeepEvalBaseLLM):
    """deepeval-Judge-Modell über OpenRouter."""

    def load_model(self):
        return JUDGE_MODEL

    def generate(self, prompt: str) -> str:
        return chat(
            "Du bist ein präziser Evaluator. Antworte exakt im geforderten Format.",
            prompt,
            JUDGE_MODEL,
            temperature=0.0,
        )

    async def a_generate(self, prompt: str) -> str:
        return self.generate(prompt)

    def get_model_name(self) -> str:
        return f"openrouter:{JUDGE_MODEL}"
