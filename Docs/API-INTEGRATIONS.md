# 9JA Transport — API Integrations (all keys live in `functions/.env`, never in chat/git)

| # | Integration | Status | Keys | Notes |
|---|---|---|---|---|
| 1 | Paystack (primary) | test now → live at launch | `PAYSTACK_SECRET_KEY`, `PAYSTACK_PUBLIC_KEY`, `PAYSTACK_WEBHOOK_SECRET` | Server-side init+verify+webhook (`sk_*` never in app). Cutover: swap `sk_test`→`sk_live`, set dashboard webhook to `…/paystackWebhook`. |
| 2 | Flutterwave (fallback) | wired | `FLW_SECRET_KEY`, `FLW_PUBLIC_KEY`, `FLW_SECRET_HASH` | `flutterwaveInit` link + `verifyFlutterwave`; app Payment screen has Paystack/Flutterwave toggle. |
| 3 | Termii SMS | wired (best-effort) | `TERMII_API_KEY`, `TERMII_SENDER_ID` | `functions/src/sms.js` (DND route, 10s timeout, never throws). Auto-sends: booking confirm, cancel/refund, payment receipt, cash receipt. Unset = silently skipped. |
| 4 | Email SMTP | wired (best-effort) | `SMTP_HOST/PORT/SECURE/USER/PASS/FROM`, `ALLOW_OTP_DEBUG` | nodemailer: email OTP, booking confirm, cancel, receipts. Gmail app-password or SendGrid. Unset = server log (+ `devCode` only when `ALLOW_OTP_DEBUG=true`). |
| 5 | Gemini AI | wired (server-only) | `GEMINI_API_KEY`, `GEMINI_MODEL` | `functions/src/ai.js`: complaint triage → `complaints.ai_urgency/ai_summary` (`migration_ai.sql`), `supportDraft` (admin), `translateText` (en/pcm/yo/ha/ig). NEVER for QR/payments/OTP. |
| 6 | Google Maps | optional switch | `--dart-define=GOOGLE_MAPS_KEY=…` | Default OSM (`flutter_map`, free, no key). With key, tracking screen uses `google_maps_flutter`. Native setup after `flutter create .`: Android `AndroidManifest.xml` `<meta-data android:name="com.google.android.geo.API_KEY">`, iOS `AppDelegate` + `Info.plist`; restrict key to app + Maps SDK for Android/iOS in Cloud console. |

## Pilot recommendation
Ship pilot on: Paystack **test**, Flutterwave test, Termii **live** (SMS is cheap and trust-critical), SMTP via Gmail app-password, Gemini live (triage only), OSM maps. Flip Paystack to live + add Google key only at launch.

## Costs to watch
Termii per-SMS (≈4 critical/pax max) · SMTP free tier · Gemini Flash pennies per complaint · Google Maps $200/mo free credit (OSM avoids it entirely).
