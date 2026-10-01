# 9JA TRANSPORT APP — Detailed Implementation Plan

**Version:** v0.4.0 Postgres-locked
**Stack (locked by owner):** Mobile Flutter 3.x · Backend Firebase Functions · DB Postgres (`database/schema.sql`, via `DATABASE_URL`) · Auth Firebase Auth (phone OTP) · Storage Firebase Storage · Notifications FCM · Admin Next.js · Payments Paystack (test mode now) + Flutterwave fallback · Maps static park list + predefined routes · QR booking/trip payload · Offline Hive · Code GitHub · Hosting Firebase free tier
**Source:** `Docs/PRODUCT REQUIREMENTS DOCUMENT (PRD).md` (43 sections) + `README.md`
**PRD MVP scope (§40):** registration, search, booking, online payment, reserve-and-pay-at-park, slip + barcode, barcode checking, driver/vehicle profiles, park management, cancellation, driver trip management, SMS/app notifications, complaints, basic ratings.

---

## Phase 0 — Scope Lock (Week 1)

1. Freeze 3 journeys: J1 Pay Now, J2 Reserve + Pay cash at park, J3 Park worker Scan → VALID/USED/CANCELLED/EXPIRED → Arrived.
2. Lock rules:
   - `Trip.status: scheduled → boarding → ready_to_leave → departed → completed | cancelled`
   - `Booking.bookingStatus: reserved | paid | arrived | boarded | cancelled | expired | refunded | partial_refund`
   - `Booking.paymentStatus: unpaid | paid | refund_pending | refunded | partial_refunded`
   - Cancellation: `>6h = 100% minus charge; 1–6h = 50%; <1h = 0%; no-show = auto-expire 15 min after departure (§10), release space`
   - Booking charge: flat ₦100 or 3% capped ₦300 — decide now, show pre-pay (§16, §38).
   - QR single-use, one trip only, server nonce.
3. Pilot: 2–3 parks, 3–5 routes, 1 city (e.g. Lagos Ikeja ↔ CMS). List real parks/routes/fares/operators.
4. KYC: passenger = Firebase phone OTP only. Driver = OTP + photo + license + vehicle + plate + park letter. Admin manual approve → `Verified Driver` (§12).

## Phase 1 — Design System (Week 1-2)

- 5 tabs (§36): Book a Ride, My Bookings, Nearby Parks, Ride History, Profile. One primary action/screen.
- Tokens: `Danfo Yellow #FFC300` (black text on it), `Park Green #0A7A3B`, `Charcoal #121212`, `Muted #6B7280`, `Paper #FFFFFF`, `Cream #FFF8E1`, `Danger #D92D20`, `Amber #F79009`, `Info #175CD3`. Park Mode: black bg, huge type.
- Type: Inter / Public Sans, tabular numerals for ₦. 48dp targets, 4.5:1 contrast, scale to 1.3x.
- Components: AppButton (+Park Scan 64dp), SearchField, TripCard, SlipCard (all §7 fields + QR + 6-char code + Save Offline), VerificationSheet, DriverCard, TripTimeline (`Booked → Assigned → Arrived → Boarding → Departed → Completed`), StatusBanner (offline/fare/delay), Empty/Error, RatingSheet.
- Figma ~22 frames: passenger (OTP, search, results, detail, pay-or-reserve, slip, bookings, history, profile, support, rating), Park Mode (PIN, today trips, trip detail, scan, result, queue), Driver (today, trip, earnings-lite), Admin web (approvals, parks/routes/fares, bookings, refunds).

## Phase 2 — Architecture (Firebase, locked)

### 2.1 Stack map
- **Mobile `app/`:** Flutter 3.x, Android-first (Tecno/Infinix). Packages: `firebase_core, firebase_auth, cloud_functions, firebase_storage, firebase_messaging, hive, hive_flutter, qr_flutter, mobile_scanner, connectivity_plus`. No direct DB driver — app calls callable Functions only.
- **Backend:** Firebase Cloud Functions for Firebase (Node 20, `functions/`) + **Postgres** (`database/schema.sql`, provider-agnostic: Neon / Supabase Postgres / Cloud SQL via `DATABASE_URL`, `pg` pool in `functions/src/db.js`). Transactions (`SELECT … FOR UPDATE`) for capacity + single-use scan guard (`uniq_one_valid_scan` partial index).
- **Auth:** Firebase Auth phone OTP (no Termii). Test numbers in Firebase Console for dev. `users.id` = Firebase uid.
- **Storage:** Firebase Storage: `drivers/{uid}/photo.jpg`, `vehicles/{id}/docs/`. Rules: public-read driver photo only after verified; write owner/admin only.
- **Notifications:** FCM only in MVP (free). Topics per trip `trip_{id}`, tokens in `users.fcm_tokens`. SMS deferred to v2.
- **Admin `admin/`:** Next.js 14 + Firebase Admin SDK + direct Postgres reads (server-side `DATABASE_URL`). Hosted on Firebase Hosting free tier.
- **Payments:** Paystack test mode now + Flutterwave fallback via `PaymentProvider` interface. Kobo integers. Webhook Functions verify HMAC → UPSERT `payments` + UPDATE `bookings` in one SQL tx (dedupe by reference).
- **Maps:** Static `parks` + `routes` tables, predefined fares. No SDK in MVP.
- **QR:** `qr_flutter` + `mobile_scanner`. Payload `{v:1, bid, tid, nonce, code}` + 6-char fallback. Offline provisional + online authoritative `verifyScan`.
- **Offline:** Hive boxes `slips`, `trips_cache`, `scan_queue`, `outbox`.
- **Code/Hosting/CI:** GitHub + Actions + Firebase Hosting + App Distribution.

```text
9JA Transport APP/
├── Docs/
├── database/             # Postgres schema.sql + seed.sql + .env.example (DATABASE_URL)
├── app/                  # Flutter (calls Functions; Hive offline)
├── admin/                # Next.js (Firebase Hosting)
├── functions/            # Cloud Functions + src/db.js (pg pool)
├── firebase.json (functions+hosting+storage; no Firestore)
├── storage.rules
└── .github/workflows/
```

| Decision | Choice | Why |
|---|---|---|
| Space not seat | Yes | Park reality, simpler |
| QR + 6-char code | Yes | Camera failure fallback |
| Cash optional | Yes | Trust + inclusion |
| No live GPS | Static list | Free-tier + data saving |
| Security | Postgres + App Check + Functions for all writes | AuthZ in Functions via users(role, park_id); Flutter never connects direct to DB |

Exit: Firebase project created, `flutterfire configure` done, Paystack test keys in Functions config, test OTP numbers added.

## Phase 3 — Postgres Model + Functions Contract (Week 2)

Tables in `database/schema.sql` (`Docs/DATA-MODEL.md`): users, parks, routes, vehicles, drivers, trips, bookings, payments, scans (partial unique `uniq_one_valid_scan`), complaints, ratings, fare_history, notifications. Functions in `Docs/API-SPEC.md`: `createBooking` (SQL `FOR UPDATE` tx — done as stub), `verifyScan`, `cancelBooking`, webhooks, crons. Run `psql $DATABASE_URL -f database/schema.sql -f database/seed.sql` (2 parks, 2 routes Ikeja↔CMS).

## Phase 4 — Foundations (Week 3)

- `flutter create` wired + `flutterfire configure`, flavors dev/prod, Hive init, FCM background handler, App Check.
- `storage.rules` + `psql $DATABASE_URL -f database/schema.sql -f database/seed.sql` (2 parks, 2 routes Ikeja↔CMS).
- Auth screen: Firebase `verifyPhoneNumber` OTP, handle auto-retrieval + resend cooldown.
- CI: analyze/test/apk. Branch `main` protected. Firebase App Distribution internal group.
- Gate: register → OTP → search seeded trips works.

## Phase 5 — Passenger MVP (Week 4-5)

Search → Results (spaces left = capacity-bookedCount, poll + FCM invalidate, no sockets) → Pay-or-Reserve (show fare + charge + cancel rules) → Slip (QR + code + Save Offline in Hive) → My Bookings/Cancel (refund preview) → History/Profile → DriverCard before boarding.

## Phase 6 — Park Mode + Verify (Week 5-6, hardest)

PIN worker login, huge Scan, torch + manual code entry, full-screen result + vibration, trip detail `Booked/Arrived/Not arrived` (Function query), queue sorted by scan time, Ready→Departed gated by `park_id` + role in Function. Offline provisional flow + `Needs sync` badge. Two-phone test: airplane + online double-scan → ALREADY USED.

## Phase 7 — Driver/Trips (Week 6)

Role-gated tabs, Today trips by `driverId`, arrived/not-arrived + paid/unpaid, Ready→Departed→Completed via Function, earnings-lite (today, online vs cash, charge, owed).

## Phase 8 — Payments + Notify (Week 6-7)

Paystack test inline → Function verify → booking paid. Reserve → unpaid, worker marks `cash received` (PIN + park scope). Refunds per table (manual in test mode, record statuses). FCM topics + in-app inbox; 4 critical pushes only (booking, 1h reminder opt-in §34, cancelled, refund). Fare-lock guard.

## Phase 9 — Trust/Admin/Support (Week 7-8)

Admin Next.js: driver/vehicle approve/suspend, parks/routes/fares CRUD, bookings view, complaints inbox, refunds, suspicious flag (>6 seats same phone/10min). Safety MVP: Share Trip link+SMS intent, Emergency (112 + support), timeline, complaint quick options (§25). Ratings 5-star post-completed one-per-booking.

## Phase 10 — QA + Pilot (Week 8-10)

Unit (refund, QR, capacity tx), integration (book→pay→verify→depart), devices (Tecno Spark, Infinix Hot, Samsung A0x, Android 10-14, 1GB), 2G/offline, sunlight, long names. Security: replay QR must fail 2nd time (partial unique index) + App Check on Functions. Cost: APK <25MB, slip <1s offline, scan <2s online, Postgres pool max 5 (free tier). Runbook: printed QR fallback, 1-pager training, cash sheet, support number, rollback to paper. Metrics §41 + <15s/pax.

## Phase 11 — V2 (post-pilot)

Bike hail, Book-for-Someone, fare alerts/history, Lost&Found, owner analytics, Pidgin/Hausa/Yoruba/Igbo, SMS provider, wallet, USSD. Plus **Phase 12 Live Bus Tracking** below (major feature, own phase).

## Phase 12 — Live Bus Tracking (major, post-pilot, ~3–4 weeks)

PRD §44. Only for active trips (`departed` → `completed`); booked passengers + driver + same-park worker + admin only.

1. **Driver ping:** `geolocator` + foreground service while trip active, POST `updateTripLocation {tripId, lat, lng, speed}` every ~10–15s (assigned driver only, trip must be `departed`). Stops at `completed`.
2. **Store:** `trip_locations` (trip_id, lat, lng, speed, at; index trip+time, 30-day retention purge) + `trips.last_lat/last_lng/last_ping_at`. Migration: `database/migration_tracking.sql`.
3. **Passenger view:** `getTripLocation {tripId}` (booking check) polled every ~15s + map SDK (`google_maps_flutter` or OSM `flutter_map` to save cost): bus icon, static route polyline (predefined park-to-park shape first, live routing later), ETA = remaining ÷ recent avg speed.
4. **Stale rule:** ping age >60s → grey bus + "last seen N min ago", freeze marker. Never animate on stale data.
5. **Notifications:** departed (on →`departed`), approaching (within X km / Y min of destination), arrived (→`completed` or GPS radius). FCM `trip_{id}` topic (already subscribed at slip).
6. **QA:** low-battery run (2h trip), 2G ping gaps, permission-denied path, completed trip hides location, non-booked user denied.

## Risks

| Risk | Mitigation |
|---|---|
| Firestore free-tier blowout | Postgres free tier (Neon/Supabase) + Hive cache + paginate, no realtime sockets; poll + FCM invalidate |
| Offline double-use | Provisional only offline; authoritative Function online; nonce + scans log |
| OTP SMS cost/limits | Firebase free quota for pilot; test numbers in dev; resend cooldown |
| Paystack test→live gap | Provider interface now; live keys + webhook secret swap at launch |
| Low-end phones | <25MB, Hive, minimal anim, Park Mode black theme |

## Next actions

1. [ ] Create Firebase project + `flutterfire configure` + App Check + test phone numbers
2. [ ] Add Paystack `sk_test` + webhook URL to Functions config; stub Flutterwave impl
3. [ ] Fill pilot parks/routes/fares + charge
4. [ ] Figma tokens + 3 journeys
5. [ ] Scaffold done (this commit) → implement Phase 4 gate

*Estimate: 8–10 weeks, 2 Flutter + 1 Firebase/Functions + 1 designer (part-time) + 1 QA/ops.*
