-- 9JA Transport — pilot KPI queries (PRD §41). Run in psql: \i database/metrics.sql
-- Targets: arrival% >90 · repeat% rising · ratings >=4.5 · scan-to-board <15s (measured at park)

-- 1. Bookings / completed / cancels per day (last 14 days)
SELECT date_trunc('day', b.created_at)::date AS day,
  COUNT(*) AS bookings,
  COUNT(*) FILTER (WHERE b.booking_status IN ('arrived','boarded')) AS arrived,
  COUNT(*) FILTER (WHERE b.booking_status='cancelled') AS cancelled,
  COUNT(*) FILTER (WHERE b.booking_status='expired') AS no_show
FROM bookings b WHERE b.created_at > now() - interval '14 days'
GROUP BY 1 ORDER BY 1;

-- 2. Arrival % per route (pilot gate >90%)
SELECT pf.name || ' → ' || pt.name AS route,
  COUNT(*) AS bookings,
  ROUND(100.0 * COUNT(*) FILTER (WHERE b.booking_status IN ('arrived','boarded')) / NULLIF(COUNT(*),0),1) AS arrival_pct
FROM bookings b JOIN trips t ON t.id=b.trip_id JOIN routes r ON r.id=t.route_id
JOIN parks pf ON pf.id=r.from_park_id JOIN parks pt ON pt.id=r.to_park_id
WHERE b.created_at > now() - interval '14 days' GROUP BY 1 ORDER BY 2 DESC;

-- 3. Revenue collected today (kobo → ₦ divide by 100)
SELECT COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE b.payment_status='paid'),0)/100 AS naira_collected,
  COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE p.provider='cash' AND p.status='success'),0)/100 AS naira_cash
FROM bookings b LEFT JOIN payments p ON p.booking_id=b.id
WHERE b.created_at > date_trunc('day', now());

-- 4. Ratings avg (target >=4.5)
SELECT COUNT(*) AS ratings, ROUND(AVG(score),2) AS avg_score FROM ratings
WHERE created_at > now() - interval '14 days';

-- 5. Suspicious flags: >6 seats same phone in 10 min (fraud review §31)
SELECT u.phone, COUNT(*) AS quick_books, SUM(b.seats) AS seats
FROM bookings b JOIN users u ON u.id=b.passenger_id
WHERE b.created_at > now() - interval '1 day'
GROUP BY u.phone HAVING SUM(b.seats) > 6;

-- 6. Repeat passengers (booked 2+ times in 14 days)
SELECT COUNT(*) AS repeat_pax FROM (
  SELECT passenger_id FROM bookings WHERE created_at > now() - interval '14 days'
  GROUP BY passenger_id HAVING COUNT(*) >= 2) t;
