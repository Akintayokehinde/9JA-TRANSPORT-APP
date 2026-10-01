# 9JA Transport — User Flows (Phase 0 locked)

Only 3 journeys in MVP. All others deferred to v2.

## J1 — Pay Now (passenger)
1. Open app → **Book a Ride** tab
2. Enter From (park list) → To → Date → Time → Pax count → Search
3. Results: `TripCard` list (route, time, fare ₦, vehicle, spaces left, park)
4. Select trip → Detail (fare + booking charge + cancel rules + DriverCard)
5. Choose **Pay Now** → Paystack test checkout → Function verifies → booking `paid`
6. Slip issued: all §7 fields + QR `{bid,tid,nonce,code}` + trip code → saved to Hive offline
7. Go to park → show slip (works offline) → worker scans → VALID → marked arrived → board any free seat
8. Trip departs → completed → rate ★ + comment

## J2 — Reserve + Pay cash at park (passenger)
Steps 1-4 same. Step 5: choose **Reserve & Pay at Park** → booking `reserved/unpaid` (no online charge).
Step 6-7 same, plus worker taps **Cash received** (PIN + same-park check) → payment `cash/success`.
No-show past 15-min grace → expired, space released.

## J3 — Park worker verify (Park Mode)
1. Worker PIN login (stays logged in, black theme, huge SCAN button)
2. Open Today's Trips → select trip (Booked/Arrived/Left counts)
3. Tap SCAN → camera (torch + manual code fallback)
4. Result full-screen:
   - VALID green → auto-mark arrived → direct to vehicle
   - ALREADY USED grey / CANCELLED red / EXPIRED orange → deny boarding
5. Offline: provisional `LIKELY VALID` only if structure+expiry ok + not in local used-cache; queue sync, badge `Needs sync`. Never finalise `used` offline.
6. Mark trip Ready → Departed (driver or same-park worker only)

## Out of MVP
Bike hail, Book-for-Someone, fare alerts/history, Lost&Found, owner analytics, maps SDK, languages beyond Simple English.
