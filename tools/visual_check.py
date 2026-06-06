#!/usr/bin/env python3
"""Fuzzy visual QA for the Sims clone via a local oMLX vision model.

Renders are produced by tests/screenshot.tscn; this script sends one to a
local vision model and prints its judgement. Used both interactively and as a
gated visual test (see tools/visual_test.sh).

Usage:
    python3 tools/visual_check.py --image /tmp/sims_shot.png \
        --prompt "Is this a top-down view of a furnished house with no glitches?"

It auto-selects an available Gemma vision model from the oMLX server, so it
keeps working as models are added/removed.
"""
import argparse
import base64
import json
import sys
import urllib.request

BASE = "http://localhost:8000/v1"
KEY = "0000"


def _get(path):
    req = urllib.request.Request(BASE + path, headers={"Authorization": f"Bearer {KEY}"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def pick_model(preferred=None):
    data = _get("/models").get("data", [])
    ids = [m["id"] for m in data]
    if preferred and preferred in ids:
        return preferred
    # Prefer Gemma instruction-tuned vision models; avoid audio/embedding models.
    bad = ("parakeet", "embedding", "embed")
    gemmas = [i for i in ids if "gemma" in i.lower() and not any(b in i.lower() for b in bad)]
    # Prefer a mid-size 4bit/8bit "it" model for speed.
    for key in ("gemma-4-31b-it-4bit", "31b", "12b", "e2b"):
        for i in gemmas:
            if key.lower() in i.lower():
                return i
    if gemmas:
        return gemmas[0]
    raise SystemExit(f"No Gemma vision model available. Models: {ids}")


def check(image_path, prompt, model=None):
    model = pick_model(model)
    with open(image_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    payload = {
        "model": model,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
            ],
        }],
        "max_tokens": 1024,
        "temperature": 0.2,
    }
    req = urllib.request.Request(
        BASE + "/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=300) as r:
        resp = json.load(r)
    msg = resp["choices"][0]["message"]
    # Some local models stream their answer in `reasoning_content`.
    answer = (msg.get("content") or "").strip()
    if not answer:
        answer = (msg.get("reasoning_content") or "").strip()
    return model, answer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--model", default=None)
    args = ap.parse_args()
    model, answer = check(args.image, args.prompt, args.model)
    print(f"[model: {model}]\n")
    print(answer)


if __name__ == "__main__":
    main()
