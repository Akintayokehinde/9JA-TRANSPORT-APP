# 9JA Transport — Business Rules (Phase 0 locked)

## States
- `trips.status`: scheduled → boarding → ready_to_leave → departed → completed | cancelled
- `bookings.booking_status`: reserved | paid | arrived | boarded | cancelled | expired | refunded | partial_refund
- `bookings.payment_status`: unpaid | paid | refund_pending | refunded | partial_refunded
- `payments.status`: pending | success | failed | refunded

## Cancellation + refund (PRD §10)
| When | Refund |
|---|---|
| >6h before departure | 100% minus booking charge |
| 1–6h before | 50% |
| <1h before | 0% |
| No-show (15 min after departure) | auto-expire, 0%, space released |

Cancel rules shown pre-pay. Refund recorded in `payments` + `bookings`, notified via FCM.

## Money
- Amounts BIGINT kobo. Booking charge: flat ₦100 (or 3% capped ₦300 — confirm at pilot).
- Fare locked at booking (`trips.fare_kobo` copied to `bookings.fare_kobo`). Fare change pre-confirm blocks with `Fare changed — confirm`.
- Paystack test now, Flutterwave fallback interface. Webhook dedupe by `payments.reference`.

## QR / verification (PRD §8, §31)
- Payload `{v:1, bid, tid, nonce, code}`. One booking = one trip, single-use.
- Authoritative check = `verifyScan` Function + `uniq_one_valid_scan` index. Double scan → `used`.
- Vehicle swap requires admin re-issue (push `Vehicle changed`).

## KYC (PRD §12)
- Passenger: Firebase phone OTP only.
- Driver: OTP + photo + license + vehicle + plate + park letter. Admin approves → `Verified` badge.
- Worker: PIN + `park_id` scope. Admin/owner roles manual.

## Pilot scope (confirm real names)
- City: Lagos. Parks: Ikeja Park, CMS Park. Routes: Ikeja↔CMS (₦1,500), Ikeja→Oshodi (₦800, optional 3rd).
- Targets: <15s/pax scan, >90% arrival on booked trips, APK <25MB, scan <2s online.

## AuthZ
Flutter never talks to Postgres directly — callable Functions only. Functions check `users(role, park_id)`. Admin Next.js reads Postgres server-side only.
