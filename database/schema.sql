-- 9JA Transport — Postgres schema (primary DB) — Phase 3 hardened, idempotent
-- Run: psql $DATABASE_URL -f database/schema.sql
-- Firebase Auth uid stored as TEXT. Amounts BIGINT kobo.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS parks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location TEXT NOT NULL,
  lga TEXT,
  contact TEXT,
  hours_open TIME,
  hours_close TIME,
  active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  email TEXT,
  role TEXT NOT NULL CHECK (role IN ('passenger','driver','park_worker','owner','admin')),
  park_id UUID REFERENCES parks(id),
  verified BOOLEAN DEFAULT FALSE,
  rating_avg NUMERIC(3,2) DEFAULT 0,
  trips_completed INT DEFAULT 0,
  fcm_tokens TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_park_id UUID REFERENCES parks(id),
  to_park_id UUID REFERENCES parks(id),
  base_fare_kobo BIGINT NOT NULL CHECK (base_fare_kobo >= 0),
  active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT CHECK (type IN ('danfo','minibus','bus','bike')),
  vehicle_no TEXT,
  plate_no TEXT UNIQUE NOT NULL,
  park_id UUID REFERENCES parks(id),
  owner_id TEXT REFERENCES users(id),
  driver_id TEXT REFERENCES users(id),
  verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending','approved','suspended')),
  verified BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS drivers (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  photo_url TEXT,
  license_no TEXT,
  park_id UUID REFERENCES parks(id),
  verified BOOLEAN DEFAULT FALSE,
  rating_avg NUMERIC(3,2) DEFAULT 0,
  trips_completed INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID REFERENCES routes(id),
  vehicle_id UUID REFERENCES vehicles(id),
  driver_id TEXT REFERENCES users(id),
  park_id UUID REFERENCES parks(id),
  departs_at TIMESTAMPTZ NOT NULL,
  capacity INT NOT NULL CHECK (capacity > 0 AND capacity <= 100),
  booked_count INT NOT NULL DEFAULT 0 CHECK (booked_count >= 0),
  arrived_count INT NOT NULL DEFAULT 0 CHECK (arrived_count >= 0),
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','boarding','ready_to_leave','departed','completed','cancelled')),
  fare_kobo BIGINT NOT NULL CHECK (fare_kobo >= 0),
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_counts CHECK (arrived_count <= booked_count AND booked_count <= capacity)
);

CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id),
  passenger_id TEXT REFERENCES users(id),
  passenger_name TEXT NOT NULL,
  seats INT NOT NULL CHECK (seats > 0 AND seats <= 10),
  booking_no TEXT UNIQUE NOT NULL,
  qr_nonce TEXT UNIQUE NOT NULL,
  trip_code VARCHAR(6) NOT NULL,
  booking_status TEXT NOT NULL DEFAULT 'reserved' CHECK (booking_status IN ('reserved','paid','arrived','boarded','cancelled','expired','refunded','partial_refund')),
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid','paid','refund_pending','refunded','partial_refunded')),
  fare_kobo BIGINT NOT NULL CHECK (fare_kobo >= 0),
  pay_mode TEXT CHECK (pay_mode IN ('pay_now','reserve')),
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS payments (
  reference TEXT PRIMARY KEY,
  booking_id UUID REFERENCES bookings(id),
  provider TEXT CHECK (provider IN ('paystack','flutterwave','cash')),
  amount_kobo BIGINT NOT NULL CHECK (amount_kobo >= 0),
  status TEXT CHECK (status IN ('pending','success','failed','refunded')),
  raw JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES bookings(id),
  trip_id UUID REFERENCES trips(id),
  by_uid TEXT REFERENCES users(id),
  result TEXT CHECK (result IN ('valid','used','cancelled','expired')),
  offline BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES bookings(id),
  reporter_id TEXT REFERENCES users(id),
  category TEXT,
  message TEXT,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id),
  booking_id UUID REFERENCES bookings(id) UNIQUE,
  rater_id TEXT REFERENCES users(id),
  score INT CHECK (score BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fare_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID REFERENCES routes(id),
  old_kobo BIGINT, new_kobo BIGINT,
  changed_by TEXT REFERENCES users(id),
  at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES users(id),
  title TEXT, body TEXT, trip_id UUID,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes (idempotent)
CREATE INDEX IF NOT EXISTS idx_trips_route_date ON trips (route_id, departs_at, status);
CREATE INDEX IF NOT EXISTS idx_trips_park_date ON trips (park_id, departs_at);
CREATE INDEX IF NOT EXISTS idx_bookings_trip_status ON bookings (trip_id, booking_status);
CREATE INDEX IF NOT EXISTS idx_bookings_pax ON bookings (passenger_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_nonce ON bookings (qr_nonce);
CREATE INDEX IF NOT EXISTS idx_scans_booking ON scans (booking_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments (booking_id);
-- Single-use guard: only one 'valid' scan per booking (race-safe)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_one_valid_scan ON scans (booking_id) WHERE result = 'valid';
