# 9JA Transport — Cloud Functions Contract (Postgres backend)

Callable (Flutter `cloud_functions`): `searchTrips`, `createBooking`, `verifyScan`, `cancelBooking`, `markTripStatus`, `verifyPaystack`.

## Auth (passwords in Firebase Auth only)
- `register({phone, email, firstName, lastName, username, password, confirmPassword, otpChannel})` — validates, uniqueness pre-check, creates Firebase user + PG row, email OTP (SMTP or `devCode` when `ALLOW_OTP_DEBUG=true`) or SMS path.
- `verifyEmailOtp({code})`, `resendOtp()`, `confirmPhoneLink()` (after in-app link), `loginResolve({identifier})` → `{email}`.
Webhooks (https): `paystackWebhook`, `flutterwaveWebhook` — verify HMAC, UPSERT `payments`, UPDATE `bookings`.
Cron: `expireNoShows` (5 min), `sendReminder` (10 min, FCM topic `trip_{id}`).

## createBooking({tripId, seats, passengerName, payMode}) → {bookingId, bookingNo, tripCode, qrNonce, qrPayload}
SQL tx: `SELECT trip FOR UPDATE` → capacity check → `UPDATE trips booked_count` → `INSERT bookings`. QR payload `{v:1, bid, tid, nonce, code}`.

## verifyScan({bid, tid, nonce, code}) → {result, booking?, trip?}
Auth worker/driver/admin + same-park check. Load booking+trip `FOR UPDATE`. cancelled→cancelled; expired→expired+mark; arrived|boarded→used; else `INSERT scans valid` + `UPDATE bookings=arrived, trips.arrived_count++`. Partial unique index guarantees single-use even on race.

## cancelBooking({bookingId}) → {refundKobo, status}
Refund table (>6h full-charge; 1–6h 50%; <1h 0). UPDATE booking cancelled + payment refund_pending (Paystack test = manual).

## paystackWebhook / flutterwaveWebhook
Dedupe by `payments.reference`, tx update payment success + booking paid.

## expireNoShows / sendReminder
Expire past-grace bookings; FCM 1h-before to opted-in.

## Live tracking (PRD §44, Phase 12)
- `updateTripLocation({tripId, lat, lng, speedKmh})` — assigned driver only, trip must be `departed`; upserts `trips.last_*` + inserts `trip_locations` row.
- `getTripLocation({tripId})` — booked passenger / same-park worker / admin only; returns `{lat, lng, at, stale, etaMin}`; denied once trip `completed`.
- Departed/approaching/arrived pushes via existing FCM `trip_{id}` topic.

## Payments (Paystack live-ready + Flutterwave fallback)
- `paystackInit` / `verifyPaystack` / `paystackWebhook` (HMAC-SHA512), `flutterwaveInit` / `verifyFlutterwave` / `flutterwaveWebhook`. Live cutover = `sk_test`→`sk_live` + dashboard webhook URL (see `API-INTEGRATIONS.md`).
- `paystackInit` takes `purpose booking|topup` (+`amountKobo` for top-up) and `channel: 'card'` to lock the Bank Card option to card-only checkout.
- Wallet: `myProfile` (profile + balance), `walletBalance`, `walletHistory`, `payWithWallet({bookingId})` (atomic deduct + ledger + paid), top-up credit via webhook/verify metadata (`type=topup`), idempotent per reference.
- Bank Card: `cardAttempt({bookingId, last4})` (passenger, pending) → `confirmCardPayment({bookingId})` (driver/worker same-park, flips to paid + receipt); queue surfaces pending `card_last4`.

## Messaging (Termii SMS + SMTP, best-effort)
- Auto on booking confirm / cancel+refund / payment receipt / cash receipt. Missing keys = skipped, never blocks.

## Gemini AI (server-side only)
- `supportDraft({complaintId})` (admin), `translateText({text, lang})`; auto-triage writes `complaints.ai_urgency/ai_summary`.
