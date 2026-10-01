# Phase 10 — Release Checklist (pilot → store)

## Secrets & keys (never commit)
- [ ] `DATABASE_URL` (prod Postgres) in Functions secrets + admin `.env`
- [ ] Paystack **live** `sk_live` + webhook secret; test `sk_test` removed from prod
- [ ] Flutterwave live keys (fallback) or disable provider until needed
- [ ] `google-services.json` / `GoogleService-Info.plist` from Firebase console in place (gitignored)

## Firebase
- [ ] Phone auth enabled, production quotas checked, test numbers removed
- [ ] App Check enforced on all callables; FCM topics `trip_*` receiving
- [ ] Storage rules deployed (`firebase deploy --only storage`)
- [ ] Functions deployed (`firebase deploy --only functions`), cron jobs visible in scheduler

## Data
- [ ] `psql $DATABASE_URL -f database/schema.sql` clean on fresh DB
- [ ] Pilot seed replaced with REAL parks/routes/fares/vehicles/drivers (admin verified)
- [ ] `database/metrics.sql` queries return sane numbers on seed

## App
- [ ] `flutter analyze` + `flutter test` green; release APK/AAB built (`flutter build appbundle`)
- [ ] Version bumped in `pubspec.yaml`; app icon + splash (Danfo Yellow) set
- [ ] Permissions minimal: camera (scan), notifications; no location in MVP
- [ ] Offline verified: slip opens airplane-mode; scan queues + syncs

## Admin
- [ ] `cd admin && npm install && npm run build` passes; `DATABASE_URL` server-side only
- [ ] Deployed to Firebase Hosting; approvals/fares/refunds tested on live URL

## Pilot ops
- [ ] Printed QR fallback + trip codes at park; worker training 1-pager done
- [ ] Cash sheet + support line live; rollback = paper manifest week 1
- [ ] Daily metrics review (arrival %, cancels, revenue, ratings) — see `metrics.sql`

## Go / no-go
Ship to 1 park only when: double-scan always USED · refunds correct · offline sync clean ·
APK stable on Tecno/Infinix · ratings path works. Then expand to 2–3 parks.
