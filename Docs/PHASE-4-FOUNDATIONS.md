# Phase 4 — Foundations checklist (gate: register → OTP → search)

## Provision
- [ ] Create Firebase project → `cd app && flutterfire configure` (replaces `lib/firebase_options.dart` stub)
- [ ] Firebase Auth: enable Phone provider, add test numbers (e.g. +2348030000000 → 123456)
- [ ] App Check: enable Play Integrity; FCM enabled (default)
- [ ] Postgres: create DB (Neon/Supabase free), `psql $DATABASE_URL -f database/schema.sql -f database/seed.sql`
- [ ] Functions: `firebase functions:secrets:set DATABASE_URL / PAYSTACK_SECRET_KEY / FLW_SECRET_HASH`, `cd functions && npm install`
- [ ] Deploy or emulate: `firebase emulators:start --only functions` (set `FirebaseFunctions.instance.useFunctionsEmulator('localhost',5001)` in dev)

## Gate test (2 phones or emulator + seed)
1. `flutter run` → AuthScreen → enter test phone → OTP → lands on SearchScreen
2. Tap Search Ikeja → CMS → seeded trips appear (fare ₦1,500, spaces left)
3. Airplane mode → search again → cached results + `Offline — showing saved results` banner
4. `flutter analyze && flutter test` green, CI builds debug APK

## Files added
`lib/firebase_options.dart` (stub), `core/firebase/firebase_init.dart`, `core/storage/hive_boxes.dart`,
`core/network/functions_client.dart`, `features/auth/auth_screen.dart`, `features/search/search_screen.dart`,
`functions searchTrips`, CI `build apk`.
