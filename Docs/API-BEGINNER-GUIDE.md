# API Integrations — Complete Beginner Guide (9JA Transport)

## The one idea
An **API key is a password your code shows to another company** (Paystack, Google…) to prove "I'm allowed to use this." Your code reads keys from **`functions/.env`** (a file only on your computer, never uploaded to GitHub). You never type keys into chat, email, or screenshots.

## The golden rules
1. Keys live ONLY in `functions/.env` (copied from `functions/.env.example`).
2. Format: `NAME=value` — one per line, no spaces, no quotes. Example: `TERMII_API_KEY=abc123xyz`
3. If a key ever leaks (chat, screenshot, committed file): revoke it on that company's dashboard → generate a new one → replace in `.env`.
4. After editing `.env`, restart the emulator/server so it reloads.

## Where each key comes from and where it goes

### 1. Paystack (collect money) — test now, live at launch
- Get: **dashboard.paystack.com → Settings → API Keys & Webhooks**. Copy **Test Secret Key** (`sk_test_…`).
- Paste: `PAYSTACK_SECRET_KEY=sk_test_…` and `PAYSTACK_PUBLIC_KEY=pk_test_…`.
- Webhook (later, for live): same page → **Add webhook URL** → `https://<your-region>-<project>.cloudfunctions.net/paystackWebhook`, copy its secret to `PAYSTACK_WEBHOOK_SECRET`.
- Test: book a trip → Pay Now → Paystack test card `4084084084084081`, any future expiry/CVV → booking flips to paid.
- Going live: replace both keys with the **Live** ones (`sk_live_…`) and set the live webhook. Nothing else changes.

### 2. Flutterwave (backup payments)
- Get: **app.flutterwave.com → Settings → API Keys** (test mode). Copy Secret, Public, and **Webhook Secret Hash**.
- Paste: `FLW_SECRET_KEY=…`, `FLW_PUBLIC_KEY=…`, `FLW_SECRET_HASH=…`.
- Test: in the app Payment screen, toggle to Flutterwave → pay → Verify.

### 3. Termii (SMS: booking confirm, cancel, receipts)
- Get: **termii.com → Get Started → API Token** on your dashboard. Sender ID: request `9jaTransp` (or use default) in **Sender ID** section.
- Paste: `TERMII_API_KEY=…`, `TERMII_SENDER_ID=9jaTransp`.
- Test: book a trip with a real phone on your account → SMS arrives. No key = SMS silently skipped (app still works).
- Cost: per SMS; only 4 critical messages per passenger max.

### 4. Email SMTP (OTP + receipts)
- Easiest: Gmail **App password** — Google Account → Security → 2-Step Verification → **App passwords** → create one for "Mail".
- Paste: `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587`, `SMTP_USER=you@gmail.com`, `SMTP_PASS=<16-letter app password>`, `SMTP_FROM=9ja Transport <you@gmail.com>`.
- No SMTP? Set `ALLOW_OTP_DEBUG=true` (emulator only): OTP codes print in the Functions log so you can test signup end-to-end free.

### 5. Gemini AI (complaint triage, support drafts, translation)
- Get: **aistudio.google.com → Get API Key → Create API key** (starts with `AIza`, ~39 chars).
- Paste: `GEMINI_API_KEY=AIza…`.
- Test: `python Docs/test_gemini.py` (checks the key without showing it), then file a test complaint → admin inbox gains urgency + summary.
- Never used for: QR codes, payments, OTPs (those are local math / providers).

### 6. Google Maps (optional upgrade over free map)
- Get: **console.cloud.google.com → APIs & Services → Credentials → Create API key**; enable **Maps SDK for Android** + **iOS**; restrict the key to your app.
- Use: `flutter run --dart-define=GOOGLE_MAPS_KEY=AIza…` (plus one-time native setup in `API-INTEGRATIONS.md`). Without it, the app uses free OpenStreetMap automatically.
- Cost: $200/month free credit; pilot stays free either way.

## Order to do it (pilot)
1. Paystack **test** keys → take a test payment today.
2. Gmail SMTP (or `ALLOW_OTP_DEBUG=true`) → signup OTP works.
3. Gemini → complaint triage lights up.
4. Termii → real SMS receipts.
5. Flutterwave test → fallback ready.
6. At launch only: Paystack **live** keys + Google Maps key.
