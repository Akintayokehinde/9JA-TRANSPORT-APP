# 9JA Transport — Local-Only Implementation Plan (STAGE 1)

**Constraint (locked by owner):** App + DB run locally only. No cloud deployment, no hosted DB (Neon/Supabase/Cloud SQL), no external auth provider (Firebase Auth), no live payments/SMS/FCM unless explicitly requested later.
**Source:** `Docs/PRODUCT REQUIREMENTS DOCUMENT (PRD).md` (43 sections, 846 lines)
**Existing scaffold reused:** `database/schema.sql`, `database/seed.sql`, `functions/src/index.js` (business logic to port), `app/lib/**`, `admin/**`

---

## 1. PRD Goals — Understanding (confirm)

- **Digitize the park without replacing it:** Search → Choose trip → Book a space (not a seat) → Pay Now / Reserve & Pay at Park / Cash → digital slip with barcode → park scan → board any free seat → Ready → Departed → Completed.
- **Trust + safety before boarding:** Verified Driver/vehicle profiles (photo, plate, park, rating), single-use barcode verification (VALID / ALREADY USED / CANCELLED / EXPIRED), trip code fallback, Share Trip / Emergency / complaints, fare locked at booking and shown pre-pay.
- **Work with Nigerian realities:** Cash optional, low-data + offline slip, 15-min no-show grace with space release, simple cancellation/refund rules, Park Mode ultra-simple scan screen, pilot one city / few parks then expand.
- **Organize parks/drivers/owners:** Arrival tracking (Booked/Arrived/Not-arrived), booking queue, trip management, driver earnings, owner dashboard, admin approvals (drivers, vehicles, parks, routes, fares, refunds, complaints).
- **MVP = PRD §40 (16 items):** registration, search, booking, online payment (mocked locally), reserve-and-pay-at-park, slip, barcode, barcode checking, driver profiles, vehicle details, park management, cancellation, driver trip management, notifications (local), complaints, basic ratings. Everything else (bike hail, Book-for-Someone, fare alerts/history, Lost&Found, maps SDK, local languages, SMS, wallet, USSD) is v2.

---

## 2. Local Stack Decision (replaces cloud scaffold)

| Concern | Local choice | Replaces |
|---|---|---|
| DB | Local Postgres via Docker (`postgres:16`, port 5432, db `nineja`) | `DATABASE_URL` to Neon/Supabase |
| Backend | Local Node 20 + Express on `http://localhost:8080`, `pg` pool, JWT sessions | Firebase Cloud Functions + `firebase-admin` |
| Auth | Local phone + name + 4-digit PIN, JWT; OTP mocked (code printed to console/seeded `000000` in dev) | Firebase Auth phone OTP |
| App | Flutter 3.x, `http` to local API + existing `hive`, `qr_flutter`, `mobile_scanner`; remove `firebase_*` calls | `firebase_core/auth/functions/messaging/app_check/storage` |
| Admin | Next.js 14 `npm run dev` on `http://localhost:3000`, server-side direct `pg` reads | Firebase Hosting |
| Payments | Mock provider: `POST /payments/mock-confirm` simulates Paystack success/fail; cash path real; amounts in kobo | Paystack/Flutterwave live API + webhooks + HMAC |
| Notifications | Local in-app inbox (`notifications` table) + backend console log; no FCM/SMS | FCM topics + SMS |
| Files | Local `uploads/` folder served by Express | Firebase Storage |
| Config | `server/.env` with `DATABASE_URL=postgresql://nineja:nineja@localhost:5432/nineja`, `JWT_SECRET=dev-only` | `.env.example` cloud keys |

No new cloud accounts, secrets, or deploys in any phase.

---

## 3. Phases

### Phase 0 — Local Setup + Scope Lock
- **Deliverables:**
  - `docker-compose.yml` (local postgres service)
  - `server/.env.example` (local-only vars), `server/README-LOCAL.md` (how to run)
  - `Docs/PILOT-SCOPE.md` (2 parks, 3 routes Ikeja↔CMS + Ikeja→Oshodi, fares, booking charge decision ₦100 flat vs 3% capped ₦300)
  - Branch `local-only` + confirm v2-deferred list (bike, Book-for-Someone, fare alerts/history, Lost&Found, owner analytics, maps, languages)
- **Dependencies:** none (PRD already read)
- **Estimate:** Small — 0.5–1 day

### Phase 1 — Data Layer (local Postgres)
- **Deliverables:**
  - Reuse `database/schema.sql` unchanged (parks, users, routes, vehicles, drivers, trips, bookings, payments, scans + `uniq_one_valid_scan`, complaints, ratings, fare_history, notifications)
  - Migration: `database/migrations/001_local_auth.sql` (add `users.pin_hash TEXT`, `users.sms_mock_code TEXT`; make `users.id` UUID default — drop Firebase-uid assumption)
  - `database/seed.sql` refreshed for local UUID users (passenger + Musa driver + Ikeja worker + admin with PINs, 2 parks, 3 routes, 6 trips next 48h)
  - Verified by: `psql $LOCAL_DATABASE_URL -f database/schema.sql -f database/migrations/001_local_auth.sql -f database/seed.sql`
- **Dependencies:** Phase 0 (compose + scope)
- **Estimate:** Small — 1 day

### Phase 2 — Local Backend API (port Functions logic, no Firebase)
- **Deliverables (Express `server/src/`):**
  - `server/src/db.js` (local `pg` pool, max 5), `server/src/auth.js` (JWT middleware + role/park scope)
  - Endpoints (ported 1:1 from `functions/src/index.js` + `Docs/API-SPEC.md`): `POST /auth/register`, `POST /auth/login`, `GET /trips/search?from&to&date&seats`, `GET /trips/:id`, `POST /bookings`, `GET /bookings/mine`, `POST /bookings/:id/cancel`, `POST /scans/verify` (FOR UPDATE + single-use guard), `POST /trips/:id/status`, `GET /parks/today`, `GET /driver/trips`, `GET /driver/earnings`, `POST /payments/mock-confirm`, `POST /payments/cash-received`, `GET /notifications/mine`, `POST /complaints`, `POST /ratings`, `POST /admin/drivers/approve`, `POST /admin/fares`, `POST /cron/expire-noshows` (called by local timer, replaces `onSchedule`)
  - `server/package.json`, `server/Dockerfile` (optional), Postman/`.http` smoke file `server/smoke.http`
- **Dependencies:** Phase 1 (tables + seed)
- **Estimate:** Large — 4–6 days (hardest logic: capacity tx, verifyScan race guard, cancel/refund table, park-scope AuthZ)

### Phase 3 — Local Auth (no external provider)
- **Deliverables:**
  - Backend: PIN hashing (bcrypt), JWT issue/verify, mock OTP endpoint returning code in dev response (never SMS)
  - Flutter: `app/lib/features/auth/` — Register (phone+name+PIN), Login (phone+PIN), session persist, logout; remove `firebase_auth` stream gate in `main.dart`
  - Seed test accounts documented in `Docs/PILOT-SCOPE.md`
- **Dependencies:** Phase 2 (auth endpoints)
- **Estimate:** Medium — 1–2 days

### Phase 4 — Passenger Core (J1 Pay-mock + J2 Reserve/Cash)
- **Deliverables / screens (`app/lib/features/`):**
  - `search/` SearchScreen (From park list → To → Date → Time → Pax) + results TripCard (route, time, fare ₦, vehicle, spaces left = capacity − booked_count)
  - `booking/` TripDetail (fare + charge + cancel rules + DriverCard) → Pay-or-Reserve choice → SlipScreen (all PRD §7 fields + QR `{v,bid,tid,nonce,code}` + 6-char trip code + Save Offline via Hive)
  - `booking/` MyBookings + Cancel with refund preview, Ride History, Profile
  - `core/storage/hive_boxes.dart` reuse: `slips`, `trips_cache`, `scan_queue`, `outbox` (slip opens offline)
- **Dependencies:** Phases 2 + 3 (search/booking/cancel APIs + login)
- **Estimate:** Large — 4–5 days

### Phase 5 — Park Mode Verify (J3) + Driver/Trips
- **Deliverables:**
  - `verify/` ParkModeScreen (worker PIN stays logged in, black theme, huge SCAN, torch + manual code entry), VerifyResult full-screen (VALID green / USED grey / CANCELLED red / EXPIRED orange + vibration), trip detail Booked/Arrived/Not-arrived, queue sorted by scan time, Ready → Departed gated by `park_id`+role
  - Offline rule: provisional `LIKELY VALID` only (structure+expiry+local used-cache check), queued sync with `Needs sync` badge; never finalize `used` offline
  - `driver/` DriverTripsScreen (today by driverId, arrived/not-arrived + paid/unpaid), Ready → Departed → Completed, earnings-lite (today, online vs cash, charge, owed)
- **Dependencies:** Phase 2 (`/scans/verify`, `/parks/today`, `/trips/:id/status`) + Phase 3 (worker/driver roles)
- **Estimate:** Large — 3–4 days (hardest UX + two-phone double-scan test)

### Phase 6 — Mock Payments + Local Notifications + Trust/Admin/Support
- **Deliverables:**
  - `payments/` PaymentScreen wired to mock-confirm (success/fail toggle) + Reserve path + worker `Cash received` (PIN + same-park check)
  - `payments/` NotificationsScreen reading `GET /notifications/mine`; only 4 critical pushes seeded locally (booking, 1h reminder opt-in, cancelled, refund); reminder via local polling timer
  - `support/` SupportScreen (Call/Message/Report with §25 quick options), createComplaint, post-completed 5-star RatingSheet (one per booking)
  - Admin (local Next.js `admin/app/`): approvals (drivers/vehicles), parks/routes/fares CRUD, bookings view, complaints inbox, refunds view, suspicious flag (>6 seats same phone/10min); Safety MVP: Share Trip (local link + SMS intent), Emergency (112 + support number), TripTimeline
- **Dependencies:** Phases 2–5 (all booking/scan/trip flows)
- **Estimate:** Medium — 3 days

### Phase 7 — UI Polish / Offline / Low-Data
- **Deliverables:**
  - `core/theme/app_theme.dart` tokens (Danfo Yellow #FFC300, Park Green #0A7A3B, Charcoal, Paper/Cream, Danger/Amber/Info), 5 tabs per PRD §36, 48dp targets, tabular ₦ numerals
  - Slip <1s offline, scan <2s on LAN, APK <25MB, minimal animations, Park Mode sunlight contrast pass
  - `uploads/` local driver-photo flow replaces Storage rules
- **Dependencies:** Phases 4–6 (screens exist)
- **Estimate:** Small–Medium — 2 days

### Phase 8 — Local Testing + Pilot Runbook
- **Deliverables:**
  - `app/test/` unit (refund table, QR payload, capacity guard) + integration (book → mock-pay → verify → depart → rate) + two-phone double-scan (airplane + LAN → ALREADY USED)
  - `Docs/QA-CHECKLIST-LOCAL.md` (devices Tecno/Infinix low-end, 2G/offline, long names, sunlight) + `Docs/PILOT-RUNBOOK-LOCAL.md` (printed QR fallback, 1-pager training, cash sheet, support number, rollback to paper)
  - Metrics per PRD §41 + <15s/pax scan target; `server/smoke.http` green on fresh `docker compose up`
- **Dependencies:** All prior phases
- **Estimate:** Medium — 2–3 days

---

## 4. Out of Scope (v2, post-pilot)

Bike hail, Book-for-Someone, fare alerts/history UI, Lost&Found, owner analytics, maps SDK, Pidgin/Hausa/Yoruba/Igbo, SMS provider, wallet, USSD, live Paystack/Flutterwave, FCM — only on explicit request.

## 5. Total Estimate

~16–23 working days solo (~3.5–5 weeks); 8–10 weeks at pilot pace with 1 Flutter + 1 backend + part-time QA. Riskiest: Phase 2 verifyScan race-safety + Phase 5 Park Mode offline queue.

---

## 6. Tooling Decisions (STAGE 2 — local-only)

**1. Framework/language (frontend + backend):** Flutter 3.x (Dart) for the mobile app plus Node 20 + Express (JavaScript) for the local API, with the existing Next.js 14 admin run via `npm run dev`. This keeps the current `app/lib/` screens, Hive offline boxes, and `qr_flutter`/`mobile_scanner` intact while the proven booking/scan/cancel logic in `functions/src/index.js` is ported 1:1 to Express routes, avoiding a rewrite in a new language and keeping one JS backend the team can run with a single `node` process on localhost.

**2. Database (and ORM/query layer):** Local Postgres 16 via Docker Compose with raw SQL through the `pg` pool and no ORM. This reuses `database/schema.sql` unchanged, preserving the load-bearing guarantees the PRD depends on — `SELECT … FOR UPDATE` capacity checks, the `uniq_one_valid_scan` partial unique index for single-use barcodes, BIGINT kobo amounts, and the 15-minute grace `expires_at` — which an ORM would obscure without adding value at pilot scale.

**3. Authentication approach:** Local phone + name + 4-digit PIN with bcrypt `pin_hash` and short-lived JWT sessions, plus a dev-only mock OTP code returned in the API response (never via SMS). This removes the Firebase Auth dependency entirely, works offline on LAN, and still enforces the existing `users(role, park_id)` park-scope authorization for worker/driver/admin actions.

**4. File storage approach:** Local `uploads/` directory served statically by Express (e.g. `uploads/drivers/{uid}/photo.jpg`) instead of a storage bucket. Pilot file needs are only driver photos and vehicle documents, so a local folder avoids all credential, bucket-rule, and network complexity while leaving a clean swap point to any later provider via stored file paths.

App and database will run locally for development; no cloud services are being provisioned at this stage.
