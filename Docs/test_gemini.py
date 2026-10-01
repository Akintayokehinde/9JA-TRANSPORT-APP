"""Quick Gemini key check (reads functions/.env, never prints the key).
Run:  python Docs/test_gemini.py
"""
import json
import os
import urllib.request

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = os.path.join(BASE, "functions", ".env")


def load_key():
    if not os.path.exists(ENV):
        return None, "functions/.env not found — copy functions/.env.example to functions/.env first."
    with open(ENV, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("GEMINI_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
                return (key or None), (None if key else "GEMINI_API_KEY is empty.")
    return None, "GEMINI_API_KEY line missing in functions/.env."


def main():
    key, err = load_key()
    if err:
        print("FAIL:", err)
        return
    print(f"Key found (starts {key[:6]}…, length {len(key)}). Calling Gemini…")
    model = "gemini-2.0-flash"
    for line in open(ENV, encoding="utf-8"):
        if line.strip().startswith("GEMINI_MODEL="):
            model = line.strip().split("=", 1)[1].strip() or model
    body = json.dumps({"contents": [{"parts": [{"text": 'Reply with exactly: danfo-ok'}]}]}).encode()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}), timeout=30) as r:
            data = json.load(r)
        text = data["candidates"][0]["content"]["parts"][0]["text"].strip()
        print("Gemini replied:", text)
        print("PASS: key works. Triage/drafts/translation will function once Functions run.")
    except Exception as e:
        print("FAIL:", e)
        print("Check: key copied fully (starts AIza, ~39 chars), no spaces/quotes, internet on.")


if __name__ == "__main__":
    main()
