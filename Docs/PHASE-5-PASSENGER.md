# Phase 5 — Passenger MVP (done)

## Flow
Search (Phase 4) → tap trip → `TripDetailScreen` (`tripDetail` fn: fare + charge + cancel rules + `DriverCard` verified/rating) → enter name → **Pay Now** / **Reserve & Pay at Park** (`createBooking` tx) → `SlipScreen` (QR `qr_flutter` + trip code, auto-saved to Hive `slips`) → tabs: Book a Ride / My Bookings.

## Files
- `functions`: `tripDetail`, `myBookings` (+ existing `createBooking`, `cancelBooking`, `verifyPaystack`)
- `app/lib/widgets/driver_card.dart`
- `app/lib/features/booking/trip_detail_screen.dart` (charge ₦100 flat, refund text pre-confirm)
- `app/lib/features/booking/slip_screen.dart` (offline-first)
- `app/lib/features/booking/my_bookings_screen.dart` (online list + Hive fallback + cancel w/ refund preview)
- `app/lib/main.dart` → `HomeShell` bottom tabs; `search_screen` navigates to detail

## Gate test
1. Search → tap trip → driver verified card visible
2. Book reserve → slip shows QR + code → kill app → reopen My Bookings offline → saved slip visible
3. Cancel → refund preview (>6h full / 1-6h 50% / <1h none) → server applies + releases capacity
4. Pay Now (test): complete Paystack inline → `verifyPaystack` → booking `paid` (webhook path in live)

## Deferred to Phase 8
Paystack inline UI wiring (currently lands on slip as reserved; verify/webhook already server-ready), FCM notifications, fare-lock edge copy check.
