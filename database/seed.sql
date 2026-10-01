-- Pilot seed — Lagos: Ikeja Park + CMS Park, routes, users, vehicle, driver, trips
-- Run after schema.sql: psql $DATABASE_URL -f database/seed.sql

INSERT INTO parks (id, name, location, lga, contact, active) VALUES
 ('11111111-1111-1111-1111-111111111111','Ikeja Park','Ikeja, Lagos','Ikeja','08030000001',TRUE),
 ('22222222-2222-2222-2222-222222222222','CMS Park','CMS, Lagos Island','Lagos Island','08030000002',TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO routes (id, from_park_id, to_park_id, base_fare_kobo, active) VALUES
 ('a0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',150000,TRUE),
 ('a0000000-0000-0000-0000-000000000002','22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',150000,TRUE),
 ('a0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','11111111-1111-1111-1111-111111111111',80000,TRUE)
ON CONFLICT (id) DO NOTHING;

-- Test users (replace ids with real Firebase uids at pilot)
INSERT INTO users (id, phone, name, role, park_id, verified) VALUES
 ('driver-musa-001','+2348030000001','Musa K.','driver','11111111-1111-1111-1111-111111111111',TRUE),
 ('worker-ikeja-001','+2348030000002','Ikeja Worker','park_worker','11111111-1111-1111-1111-111111111111',TRUE),
 ('admin-001','+2348030000009','Admin','admin',NULL,TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO vehicles (id, type, vehicle_no, plate_no, park_id, driver_id, verification_status, verified) VALUES
 ('b0000000-0000-0000-0000-000000000001','danfo','BUS-042','KTU-123XY','11111111-1111-1111-1111-111111111111','driver-musa-001','approved',TRUE),
 ('b0000000-0000-0000-0000-000000000002','minibus','BUS-017','KTU-456AB','22222222-2222-2222-2222-222222222222',NULL,'approved',TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (user_id, license_no, park_id, verified, rating_avg, trips_completed) VALUES
 ('driver-musa-001','LAG-DRV-88231','11111111-1111-1111-1111-111111111111',TRUE,4.8,312)
ON CONFLICT (user_id) DO NOTHING;

-- 6 trips over next 2 days (Ikeja→CMS 8:30/12:00/16:00, CMS→Ikeja returns)
INSERT INTO trips (route_id, vehicle_id, driver_id, park_id, departs_at, capacity, fare_kobo, status) VALUES
 ('a0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','driver-musa-001','11111111-1111-1111-1111-111111111111', now() + interval '3 hours', 14, 150000, 'scheduled'),
 ('a0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','driver-musa-001','11111111-1111-1111-1111-111111111111', now() + interval '7 hours', 14, 150000, 'scheduled'),
 ('a0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002',NULL,'22222222-2222-2222-2222-222222222222', now() + interval '9 hours', 18, 150000, 'scheduled'),
 ('a0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','driver-musa-001','11111111-1111-1111-1111-111111111111', now() + interval '27 hours', 14, 150000, 'scheduled'),
 ('a0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002',NULL,'22222222-2222-2222-2222-222222222222', now() + interval '30 hours', 18, 150000, 'scheduled')
ON CONFLICT DO NOTHING;
