-- 9JA Transport — Live Tracking migration (PRD §44, Phase 12). Run after schema.sql.
-- Driver pings only while trip is departed; passengers booked on trip may read.

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS last_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS last_lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS last_ping_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approaching_notified BOOLEAN NOT NULL DEFAULT FALSE;

-- Destination coords for ETA + approaching alerts (pilot parks; extend per park)
ALTER TABLE parks ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
ALTER TABLE parks ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;

UPDATE parks SET lat = 6.6018, lng = 3.3515
  WHERE id = '11111111-1111-1111-1111-111111111111' AND lat IS NULL; -- Ikeja
UPDATE parks SET lat = 6.4458, lng = 3.3958
  WHERE id = '22222222-2222-2222-2222-222222222222' AND lat IS NULL; -- CMS

CREATE TABLE IF NOT EXISTS trip_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  lat DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN -180 AND 180),
  speed_kmh DOUBLE PRECISION,
  at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_trip_locations_trip_time ON trip_locations (trip_id, at DESC);

-- Retention: purge pings older than 30 days (run weekly via scheduler/cron).
-- DELETE FROM trip_locations WHERE at < now() - interval '30 days';
