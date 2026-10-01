# 9JA Transport — Pilot Runbook (1 city: Lagos · Ikeja + CMS)

## Week before
1. `psql $DATABASE_URL -f database/schema.sql -f database/seed.sql` — confirm 5 trips visible via `searchTrips`
2. Firebase: test OTP numbers, App Distribution group `pilot`, FCM topic check
3. Functions secrets set: `DATABASE_URL`, `PAYSTACK_SECRET_KEY` (test), `FLW_SECRET_HASH`
4. Print: QR fallback sheets (trip codes), 1-pager worker training, cash reconciliation sheet
5. Support line live; rollback = paper manifest (keep paper alongside for week 1)

## Launch day (1 park first)
- Worker phone: dual SIM, logged into Park Mode, torch tested, manual code entry rehearsed
- Each departure: worker opens trip → SCAN → green VALID → direct; counts checked (Booked/Arrived/Left)
- Cash bookings: worker taps Cash received only after physical payment; end-of-day close vs cash sheet
- Issues: offline → provisional + Needs sync badge; sync when back online; double-scan → USED (deny)

## Daily review (first 2 weeks)
- SQL: bookings/day, % arrived, cancels, no-shows, avg scan→board time (target <15s/pax)
- Complaints inbox (admin) triaged; fare disputes → check `fare_history`
- Success gates per PRD §41: repeat passengers rising, ratings ≥4.5, complaints falling

## Expand
1 park → 2–3 parks only after: double-scan never passes twice, refunds correct, offline sync clean, APK stable on Tecno/Infinix.
Then V2 candidates: bike hail, fare alerts, Lost&Found, owner analytics, languages, SMS provider, wallet.
