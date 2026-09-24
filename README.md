# 9JA TRANSPORT APP

## Product Description

9ja Transport is a transportation booking app designed for **Danfo drivers, bus operators, bike riders, and passengers in Nigeria**.

It combines the traditional Nigerian transport-park system with online booking:
**Search → Choose trip → Book → Pay or reserve → Receive slip → Go to park → Verify booking → Board vehicle.**

After booking, the passenger receives a **digital transport slip with a barcode**. At the park, the slip is scanned to confirm the booking. The passenger then boards and chooses **any available seat** (space booking, not seat selection — except bikes, which have no seats).

## Purpose

Solve common park problems:

For passengers:
- Long queues and uncertainty about space
- Arguments over fares
- Not knowing which driver/vehicle to board
- Fake claims of payment/reservation, poor booking records
- Safety concerns entering unfamiliar vehicles

For drivers / park operators:
- Vehicles leaving without enough passengers
- Difficulty tracking reserved passengers and no-shows
- Last-minute cancellations, poor trip/earnings records
- Fare-change communication, lost/disputed bookings

Goal is not to replace parks, but to help parks and drivers **organise passengers, reduce confusion, improve trust, and know how many passengers are coming before departure**.

## Target Users

Based on PRD §4:

- **Passengers** – People travelling within cities or between locations using Danfo, minibuses, buses, and motorcycles.
- **Drivers and Riders** – Approved Danfo drivers, bus drivers, and commercial bike riders.
- **Park Workers** – People responsible for checking passengers, confirming bookings, directing passengers, and managing departures.
- **Transport Business Owners** – Individuals or companies that own vehicles and want to monitor drivers, trips, passengers, and income.
- **Administrator** – The organisation operating 9ja Transport, responsible for verifying users, handling complaints, monitoring activity, and managing the service.

## Main Features

Based on `Docs/PRODUCT REQUIREMENTS DOCUMENT (PRD).md`:

1. **Passenger Account** – Register with phone number + name (optional email), phone verification.
2. **Journey Search** – From, destination, date, departure time, passenger count. e.g. Ikeja → CMS, 8:30 AM, ₦1,500, Danfo, 7 spaces.
3. **Space Booking** – Book a space, choose any available seat at the park.
4. **Payment Options** – Pay Now, Reserve and Pay at Park, Cash Booking. Online payment not compulsory.
5. **Digital Transport Slip** – Name, booking number, route, date/time, fare, driver name/phone, vehicle number/plate, park name, barcode. Savable and viewable offline / low-data.
6. **Barcode Verification** – Park worker scans: VALID / ALREADY USED / CANCELLED / EXPIRED. One-time use per journey. Includes Trip Code for extra confidence.
7. **Trip Management** – Today's trips, booked/arrived/not-arrived counts, payment status, Ready to Leave → Departed → Completed.
8. **Passenger Arrival Tracking** – Scan marks Arrived. e.g. Booked: 14, Arrived: 12, Not arrived: 2.
9. **Driver / Rider Profiles** – Photo, phone, vehicle type/number/plate, park, Verified Driver status, ratings, completed trips. Visible before boarding.
10. **Driver & Vehicle Verification** – Admin verifies identity, phone, vehicle, plate, transport documents, park/operator.
11. **Park Management** – Park profile: name, location, routes, hours, operators, vehicles, contact. Search parks, Booking Queue.
12. **Park Mode** – Ultra-simple screen for workers: Scan → Confirm → Mark arrived → Direct to vehicle.
13. **Bike Rides** – Pickup → destination → available riders → select → rider details (name, photo, phone, bike number, fare).
14. **Fare Management** – Operators update fares, current fare shown before booking, paid fare locked. Fare alerts + price history.
15. **Cancellation / No-Show** – Cancel before departure, early/late refund rules, 15-min grace period after departure, then space re-offered.
16. **Notifications** – App + SMS: booking, payment, reminder (e.g. 1hr before), driver assigned, delay, vehicle/fare change, cancellation, refund.
17. **Safety** – Share Trip, Emergency Button, visible driver/vehicle info, trip status, Complaint Button.
18. **Ratings & Reviews** – Rate driver/journey ★★★★★ + comment. Drivers can report passengers.
19. **Support / Refunds / Lost & Found** – Call Support, Send Message, Report Problem (no-show, wrong vehicle/fare, payment, lost item, safety).
20. **Dashboards** – Driver earnings (today, online/cash, charges), Owner dashboard (vehicles, trips, income, ratings), Admin controls (approve/suspend drivers, parks, routes, charges, complaints, refunds).
21. **Specials** – Book for Someone (Passenger Name + Booked By), Trip Reminder.

Product principles: Simple, Affordable, Trustworthy, Flexible (cash + poor internet), Park-Friendly.

## How to Run It

This is the **initial version (v0.1.0 – docs only)**. No runnable app code yet – only requirements and this README.

To view the project:

1. Clone the repo:
   ```powershell
   git clone https://github.com/Akintayokehinde/9JA-TRANSPORT-APP.git
   ```
2. Open the folder:
   ```powershell
   Set-Location -LiteralPath "9JA Transport APP"
   ```
3. Read the full spec:
   - `Docs/PRODUCT REQUIREMENTS DOCUMENT (PRD).md`
   - `README.md` (this file)

Prerequisites: Git + a Markdown viewer (VS Code, GitHub). No build, no dependencies, no env vars yet.

When app code is added, this section will be updated with:
- stack / setup (`npm install`, `flutter pub get`, etc.)
- `npm start` / `npm run dev` or equivalent
- test / build commands

## Project Structure

```text
9JA Transport APP/
├── Docs/
│   └── PRODUCT REQUIREMENTS DOCUMENT (PRD).md  # Full 43-section spec
└── README.md  # This file
```

## Minimum First Version (MVP)

Per PRD §40:
1. Passenger registration
2. Route search
3. Trip booking
4. Online payment
5. Reserve-and-pay-at-park
6. Digital slip
7. Barcode
8. Barcode checking
9. Driver profiles
10. Vehicle details
11. Park management
12. Booking cancellation
13. Driver trip management
14. SMS/app notifications
15. Customer complaints
16. Basic ratings

Launch strategy: start with a small number of parks/routes in one city, learn, then expand.

## Status

v0.1.0 initial version – PRD + README committed. Implementation to follow.
