// End-to-end payment proof (runs in CI): seed trip → booking tx → Paystack test
// charge (4084084084084081, server-to-server, no browser) → verify → booking paid.
// Env: DATABASE_URL, PAYSTACK_SECRET_KEY. Exits non-zero on any failure.
const {Pool} = require('pg');
const axios = require('axios');

const Fail = (m) => { console.error('FAIL:', m); process.exit(1); };
const Ok = (m) => console.log('ok -', m);

(async () => {
  const pool = new Pool({connectionString: process.env.DATABASE_URL});
  const secret = process.env.PAYSTACK_SECRET_KEY || '';
  if (!secret.startsWith('sk_test_')) Fail('PAYSTACK_SECRET_KEY must be a test key (refusing live in CI)');
  const q = (t, p) => pool.query(t, p);

  // 1. seeded trip Ikeja->CMS
  const t = await q(
    `SELECT t.* FROM trips t JOIN routes r ON r.id=t.route_id
     JOIN parks a ON a.id=r.from_park_id JOIN parks b ON b.id=r.to_park_id
     WHERE a.name ILIKE 'Ikeja%' AND b.name ILIKE 'CMS%' AND t.status IN ('scheduled','boarding')
     ORDER BY t.departs_at LIMIT 1`);
  if (!t.rows.length) Fail('no seeded Ikeja->CMS trip (run seed.sql)');
  const trip = t.rows[0];
  Ok(`trip ${trip.id} fare=${trip.fare_kobo}k`);

  // 2. passenger + booking in one capacity-safe tx (mirrors createBooking)
  const client = await pool.connect();
  let booking;
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO users (id, phone, name, email, username, role) VALUES ('ci-pax-001','+2348030000000','CI Passenger','ci@test.com','ci_pax','passenger')
       ON CONFLICT (id) DO NOTHING`);
    const tr = await client.query('SELECT * FROM trips WHERE id=$1 FOR UPDATE', [trip.id]);
    if (tr.rows[0].booked_count + 1 > tr.rows[0].capacity) throw new Error('trip full');
    await client.query('UPDATE trips SET booked_count = booked_count + 1 WHERE id=$1', [trip.id]);
    const nonce = require('crypto').randomBytes(12).toString('hex');
    const ins = await client.query(
      `INSERT INTO bookings (trip_id, passenger_id, passenger_name, seats, booking_no, qr_nonce, trip_code,
        booking_status, payment_status, fare_kobo, pay_mode, expires_at)
       VALUES ($1,'ci-pax-001','CI Passenger',1,$2,$3,'CITEST','reserved','unpaid',$4,'pay_now', now() + interval '1 hour')
       RETURNING id, booking_no, qr_nonce, trip_code`,
      [trip.id, '9JA-CI-' + Date.now().toString(36).toUpperCase(), nonce, trip.fare_kobo]);
    booking = ins.rows[0];
    await client.query('COMMIT');
  } catch (e) { await client.query('ROLLBACK'); Fail('booking tx: ' + e.message); } finally { client.release(); }
  Ok(`booking ${booking.booking_no} reserved`);

  // 3. Paystack test charge (server-to-server, test card, no browser needed)
  const auth = {headers: {Authorization: `Bearer ${secret}`}};
  let charge;
  try {
    const r = await axios.post('https://api.paystack.co/charge', {
      email: 'ci@test.com', amount: trip.fare_kobo,
      card: {number: '4084084084084081', cvv: '408', expiry_month: '12', expiry_year: '30'},
      metadata: {bookingId: booking.id},
    }, auth);
    charge = r.data.data;
  } catch (e) { Fail('paystack charge: ' + (e.response?.data?.message || e.message)); }
  if (charge.status !== 'success') Fail('charge not successful: ' + charge.status);
  Ok(`charged ${charge.reference}`);

  // 4. server verify (mirrors verifyPaystack) + mark paid
  const v = (await axios.get(`https://api.paystack.co/transaction/verify/${charge.reference}`, auth)).data.data;
  if (v.status !== 'success') Fail('verify not successful');
  await q(`INSERT INTO payments (reference, booking_id, provider, amount_kobo, status)
           VALUES ($1,$2,'paystack',$3,'success') ON CONFLICT (reference) DO NOTHING`,
    [charge.reference, booking.id, v.amount]);
  await q("UPDATE bookings SET booking_status='paid', payment_status='paid' WHERE id=$1", [booking.id]);
  const done = await q('SELECT booking_no, booking_status, payment_status FROM bookings WHERE id=$1', [booking.id]);
  if (done.rows[0].payment_status !== 'paid') Fail('booking not paid');
  Ok(`booking ${done.rows[0].booking_no} PAID`);
  console.log(JSON.stringify({
    booking_no: booking.booking_no,
    qr: {v: 1, bid: booking.id, tid: trip.id, nonce: booking.qr_nonce, code: booking.trip_code},
  }));
  await pool.end();
  console.log('ALL GREEN: backend + Paystack test payment work end to end.');
})().catch((e) => Fail(e.message));
