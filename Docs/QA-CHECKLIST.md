# Phase 10 — QA Checklist (must pass before pilot)

## Devices (Android-first)
- [ ] Tecno Spark, Infinix Hot, Samsung A0x · Android 10–14 · 1GB RAM
- [ ] APK <25MB (`flutter build apk --analyze-size`)

## Flows
- [ ] J1 Pay Now: search → detail (verified driver) → paystack test init → verify → slip → scan VALID → arrived count+1
- [ ] J2 Reserve: book → slip offline → airplane mode → slip opens → scan queues → online sync → VALID
- [ ] Double-scan same QR → ALREADY USED (2nd phone, also race: parallel calls, one wins via `uniq_one_valid_scan`)
- [ ] Cancel: >6h full-minus-charge / 1–6h half / <1h none; capacity released; re-bookable
- [ ] No-show: booking past `expires_at` → verify returns EXPIRED; `expireNoShows` marks batch
- [ ] Trip transitions: scheduled→boarding→ready→departed→completed; illegal jump rejected
- [ ] Cash: worker same-park marks received → paid; wrong-park worker denied
- [ ] Rating only after completed; one per booking; complaint creates inbox row

## Non-functional
- [ ] Slip opens <1s offline; scan→result <2s online; 2G throttling tested
- [ ] Sunlight: slip + Park Mode readable at 50% brightness
- [ ] Long names (Yoruba/Hausa/Igbo) don't break slip layout; font scale 1.3× ok
- [ ] Security: replay QR fails 2nd time; App Check enforced; wrong-park denied; webhook bad-sig → 401
- [ ] Tracking (Phase 12): two passenger phones on same trip show identical danfo position; stale >60s greys + freezes marker; completed hides location; non-booked user denied
- [ ] Cost: Postgres pool max 5; FCM only critical 4; no Firestore usage

## Regression command
`cd app && flutter analyze && flutter test` · `cd functions && npm run lint` (if configured)
