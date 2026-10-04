# 9JA Transport — Postgres Data Model (primary DB)

**DB:** Postgres (Neon / Supabase Postgres / Cloud SQL — via `DATABASE_URL`). Full DDL: `database/schema.sql`. Seed: `database/seed.sql`.
**Firebase:** Auth (phone OTP), Storage, FCM, Hosting, Functions only. Firestore NOT used.

Tables: `users(id=Firebase uid)`, `parks`, `routes`, `vehicles`, `drivers(user_id FK)`, `trips(booked_count, arrived_count, status, fare_kobo)`, `bookings(booking_no/trip_code/qr_nonce unique, booking_status, payment_status)`, `payments(reference PK)`, `scans` (+ partial unique `uniq_one_valid_scan` blocks double-use at DB level), `complaints`, `ratings`, `fare_history`, `notifications`.

Auth (migration `database/migration_auth.sql`): `users` += `first_name/last_name/username` (unique), `email` unique, `email_verified/phone_verified`. Passwords live ONLY in Firebase Auth. `otp_codes(user_id, channel email|sms, code_hash SHA-256, expires 10 min, attempts ≤5, consumed)` — email OTPs; SMS rides Firebase client verify + link.

Wallet (migration `database/migration_wallet.sql`): `wallets(user_id, balance_kobo)` + ledger `wallet_transactions(user_id, kind fund|pay|refund, amount_kobo, reference unique, booking_id)`. Top-ups via Paystack `purpose=topup` (webhook/verify credit idempotently); trip payment via `payWithWallet` atomic tx; cancels of wallet-paid bookings refund to wallet.

Key integrity:
- Anti-overbooking: `SELECT trips … FOR UPDATE` in `createBooking` tx, check `booked_count+seats<=capacity`.
- Single-use QR: `UNIQUE … WHERE result='valid'` on scans + tx check in `verifyScan`.
- Amounts BIGINT kobo. `expires_at = departs_at + 15 min` (§10 grace).
- AuthZ enforced in Functions via `users(role, park_id)`, not Firestore Rules.

Flutter → callable Functions only (never direct Postgres). Admin Next.js → Functions + direct Postgres read via `DATABASE_URL` (server-side only).

## Live tracking (PRD §44, Phase 12 — migration `database/migration_tracking.sql`)
- `trips.last_lat/last_lng/last_ping_at` — latest bus position (written by `updateTripLocation`).
- `trip_locations(trip_id, lat, lng, speed_kmh, at)` — ping history, index `(trip_id, at DESC)`, purged after 30 days. Read access: booked passengers + driver + same-park worker + admin; only while trip `departed`.
