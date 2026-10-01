// 9ja Transport Cloud Functions — Postgres primary DB. See database/schema.sql + Docs/API-SPEC.md
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const crypto = require("crypto");
const axios = require("axios");
const admin = require("firebase-admin");
const {db} = require("./db");
const {sendSms} = require("./sms");
const {triageComplaint, draftReply, translate} = require("./ai");
admin.initializeApp();

// Best-effort user notification (SMS via Termii + email via SMTP). Never throws.
async function notifyUser(uid, {sms, subject, email}) {
  try {
    const {rows} = await db().query('SELECT phone, email FROM users WHERE id=$1', [uid]);
    if (!rows.length) return;
    const u = rows[0];
    const jobs = [];
    if (sms && u.phone) jobs.push(sendSms(u.phone, sms));
    if (email && u.email) {
      jobs.push(sendMail(u.email, subject || '9ja Transport update', email)
        .catch((e) => console.log('notify mail failed:', e.message)));
    }
    await Promise.all(jobs);
  } catch (e) {
    console.log('notifyUser failed:', e.message);
  }
}

const rand = (n) => crypto.randomBytes(n).toString("hex").slice(0, n).toUpperCase();

async function requireRole(uid, allowed) {
  const {rows} = await db().query("SELECT role, park_id FROM users WHERE id=$1", [uid]);
  if (!rows.length) throw new HttpsError("permission-denied", "User not registered");
  if (!allowed.includes(rows[0].role)) throw new HttpsError("permission-denied", "Role not allowed");
  return rows[0];
}

// POST /createBooking — capacity-safe tx
exports.createBooking = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {tripId, seats, passengerName, payMode} = req.data;
  if (!tripId || !seats || seats < 1 || seats > 10) throw new HttpsError("invalid-argument", "tripId + seats(1-10) required");
  if (!passengerName || !payMode || !["pay_now", "reserve"].includes(payMode)) throw new HttpsError("invalid-argument", "passengerName + payMode required");
  const pool = db();
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const {rows} = await client.query("SELECT * FROM trips WHERE id=$1 FOR UPDATE", [tripId]);
    if (!rows.length) throw new HttpsError("not-found", "Trip not found");
    const t = rows[0];
    if (!["scheduled", "boarding"].includes(t.status)) throw new HttpsError("failed-precondition", "Trip not bookable");
    if (t.booked_count + seats > t.capacity) throw new HttpsError("resource-exhausted", "Not enough spaces");
    await client.query("UPDATE trips SET booked_count = booked_count + $1 WHERE id=$2", [seats, tripId]);
    const bookingNo = "9JA-" + rand(6);
    const qrNonce = crypto.randomBytes(12).toString("hex");
    const tripCode = rand(6);
    const expiresAt = new Date(new Date(t.departs_at).getTime() + 15 * 60000);
    const ins = await client.query(
      `INSERT INTO bookings (trip_id, passenger_id, passenger_name, seats, booking_no, qr_nonce, trip_code,
        booking_status, payment_status, fare_kobo, pay_mode, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'reserved','unpaid',$8,$9,$10) RETURNING id`,
      [tripId, req.auth.uid, passengerName, seats, bookingNo, qrNonce, tripCode, t.fare_kobo, payMode, expiresAt]
    );
    await client.query("COMMIT");
    const bookingId = ins.rows[0].id;
    // Receipt hooks (best-effort, post-commit): Termii SMS + SMTP email.
    (async () => {
      const info = await db().query(
        `SELECT pf.name AS f, pt.name AS t, tr.departs_at FROM bookings b JOIN trips tr ON tr.id=b.trip_id
         JOIN routes r ON r.id=tr.route_id JOIN parks pf ON pf.id=r.from_park_id JOIN parks pt ON pt.id=r.to_park_id
         WHERE b.id=$1`, [bookingId]).catch(() => null);
      const d = info?.rows?.[0];
      const when = d ? new Date(d.departs_at).toLocaleString() : '';
      await notifyUser(req.auth.uid, {
        sms: `9ja Transport: booking ${bookingNo} confirmed${d ? ` ${d.f}->${d.t} ${when}` : ''}. Show slip at park.`,
        subject: `Booking confirmed ${bookingNo}`,
        email: `Hi ${passengerName},\n\nBooking ${bookingNo} (trip code ${tripCode}) is confirmed${d ? ` for ${d.f} to ${d.t}, departing ${when}` : ''}.\nShow your slip QR at the park.\n\n9ja Transport`,
      });
    })();
    return {bookingId, bookingNo, tripCode, qrNonce, qrPayload: {v: 1, bid: bookingId, tid: tripId, nonce: qrNonce, code: tripCode}};
  } catch (e) {
    await client.query("ROLLBACK");
    throw e instanceof HttpsError ? e : new HttpsError("internal", e.message);
  } finally {
    client.release();
  }
});

// POST /verifyScan — authoritative, race-safe via partial unique index
exports.verifyScan = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const me = await requireRole(req.auth.uid, ["driver", "park_worker", "admin", "owner"]);
  const {bid, tid, nonce, code, offline} = req.data;
  if (!bid) throw new HttpsError("invalid-argument", "bid required");
  const client = await db().connect();
  try {
    await client.query("BEGIN");
    const b = await client.query("SELECT * FROM bookings WHERE id=$1 FOR UPDATE", [bid]);
    if (!b.rows.length) throw new HttpsError("not-found", "Booking not found");
    const bk = b.rows[0];
    if (tid && bk.trip_id !== tid) throw new HttpsError("failed-precondition", "Wrong trip");
    if (nonce && bk.qr_nonce !== nonce) throw new HttpsError("failed-precondition", "Invalid code");
    if (code && bk.trip_code !== code) throw new HttpsError("failed-precondition", "Invalid code");
    const t = await client.query("SELECT * FROM trips WHERE id=$1", [bk.trip_id]);
    const trip = t.rows[0];
    if (me.role !== "admin" && me.park_id && trip && me.park_id !== trip.park_id) throw new HttpsError("permission-denied", "Wrong park");

    const finish = async (result, extra = {}) => {
      await client.query("INSERT INTO scans (booking_id, trip_id, by_uid, result, offline) VALUES ($1,$2,$3,$4,$5)",
        [bid, bk.trip_id, req.auth.uid, result, !!offline]);
      await client.query("COMMIT");
      return {result, booking: {id: bk.id, passengerName: bk.passenger_name, status: extra.status || bk.booking_status}, trip};
    };

    if (["cancelled", "refunded"].includes(bk.booking_status)) return finish("cancelled", {status: bk.booking_status});
    if (bk.booking_status === "expired" || new Date(bk.expires_at) < new Date()) {
      await client.query("UPDATE bookings SET booking_status='expired' WHERE id=$1", [bid]);
      return finish("expired", {status: "expired"});
    }
    if (["arrived", "boarded"].includes(bk.booking_status)) return finish("used", {status: bk.booking_status});
    // First valid: mark arrived (partial unique index blocks concurrent double-valid)
    try {
      await client.query("INSERT INTO scans (booking_id, trip_id, by_uid, result, offline) VALUES ($1,$2,$3,'valid',$4)",
        [bid, bk.trip_id, req.auth.uid, !!offline]);
    } catch (e) {
      if (e.code === "23505") { await client.query("ROLLBACK"); return {result: "used", booking: bk, trip}; }
      throw e;
    }
    await client.query("UPDATE bookings SET booking_status='arrived' WHERE id=$1", [bid]);
    await client.query("UPDATE trips SET arrived_count = arrived_count + 1 WHERE id=$1", [bk.trip_id]);
    await client.query("COMMIT");
    return {result: "valid", booking: {...bk, booking_status: "arrived"}, trip};
  } catch (e) {
    try { await client.query("ROLLBACK"); } catch (_) {}
    throw e instanceof HttpsError ? e : new HttpsError("internal", e.message);
  } finally {
    client.release();
  }
});

// POST /cancelBooking — refund table Phase 0
exports.cancelBooking = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {bookingId} = req.data;
  const client = await db().connect();
  try {
    await client.query("BEGIN");
    const b = await client.query("SELECT b.*, t.departs_at FROM bookings b JOIN trips t ON t.id=b.trip_id WHERE b.id=$1 FOR UPDATE", [bookingId]);
    if (!b.rows.length) throw new HttpsError("not-found", "Booking not found");
    const bk = b.rows[0];
    if (bk.passenger_id !== req.auth.uid) await requireRole(req.auth.uid, ["admin"]);
    if (!["reserved", "paid"].includes(bk.booking_status)) throw new HttpsError("failed-precondition", "Cannot cancel");
    const hrs = (new Date(bk.departs_at) - new Date()) / 3600000;
    let refundKobo = 0;
    let status = "cancelled";
    if (hrs > 6) { refundKobo = bk.fare_kobo; status = "refunded"; }
    else if (hrs >= 1) { refundKobo = Math.floor(bk.fare_kobo / 2); status = "partial_refund"; }
    await client.query("UPDATE bookings SET booking_status='cancelled', payment_status=$2 WHERE id=$1",
      [bookingId, refundKobo === 0 ? "unpaid" : "refund_pending"]);
    await client.query("UPDATE trips SET booked_count = GREATEST(0, booked_count - $1) WHERE id=$2", [bk.seats, bk.trip_id]);
    await client.query("COMMIT");
    notifyUser(bk.passenger_id, {
      sms: `9ja Transport: booking ${bk.booking_no} cancelled. Refund: ${refundKobo} kobo.`,
      subject: `Booking cancelled ${bk.booking_no}`,
      email: `Booking ${bk.booking_no} is cancelled.\nRefund: ${refundKobo} kobo (${status}).\n\n9ja Transport`,
    });
    return {refundKobo, status};
  } catch (e) {
    await client.query("ROLLBACK");
    throw e instanceof HttpsError ? e : new HttpsError("internal", e.message);
  } finally {
    client.release();
  }
});

// POST /markTripStatus
exports.markTripStatus = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const me = await requireRole(req.auth.uid, ["driver", "park_worker", "admin"]);
  const {tripId, to} = req.data;
  const ok = {scheduled: ["boarding", "cancelled"], boarding: ["ready_to_leave", "cancelled"], ready_to_leave: ["departed"], departed: ["completed"]};
  const {rows} = await db().query("SELECT * FROM trips WHERE id=$1", [tripId]);
  if (!rows.length) throw new HttpsError("not-found", "Trip not found");
  const trip = rows[0];
  if (me.role !== "admin" && me.park_id && me.park_id !== trip.park_id) throw new HttpsError("permission-denied", "Wrong park");
  if (!(ok[trip.status] || []).includes(to)) throw new HttpsError("failed-precondition", `Cannot go ${trip.status} → ${to}`);
  await db().query("UPDATE trips SET status=$1 WHERE id=$2", [to, tripId]);
  return {tripId, status: to};
});

// Webhooks — verify signature, upsert payment, mark booking paid
// NOTE: Paystack test→live cutover = swap PAYSTACK_SECRET_KEY sk_test→sk_live +
// set webhook URL in dashboard to https://<region>-<project>.cloudfunctions.net/paystackWebhook.
exports.paystackWebhook = onRequest(async (req, res) => {
  const sig = req.headers["x-paystack-signature"];
  const secret = process.env.PAYSTACK_SECRET_KEY || "";
  const hash = crypto.createHmac("sha512", secret).update(JSON.stringify(req.body)).digest("hex");
  if (sig !== hash) { res.status(401).send("bad sig"); return; }
  const ev = req.body;
  if (ev.event === "charge.success") {
    const ref = ev.data.reference;
    const bookingId = ev.data.metadata && ev.data.metadata.bookingId;
    const amount = ev.data.amount;
    await db().query(
      `INSERT INTO payments (reference, booking_id, provider, amount_kobo, status, raw)
       VALUES ($1,$2,'paystack',$3,'success',$4) ON CONFLICT (reference) DO NOTHING`,
      [ref, bookingId, amount, ev]
    );
    if (bookingId) await db().query("UPDATE bookings SET booking_status='paid', payment_status='paid' WHERE id=$1", [bookingId]);
  }
  res.status(200).send("ok");
});

exports.flutterwaveWebhook = onRequest(async (req, res) => {
  if (req.headers["verif-hash"] !== (process.env.FLW_SECRET_HASH || "")) { res.status(401).send("bad sig"); return; }
  const d = req.body.data || req.body;
  if (d.status === "successful") {
    await db().query(
      `INSERT INTO payments (reference, booking_id, provider, amount_kobo, status, raw)
       VALUES ($1,$2,'flutterwave',$3,'success',$4) ON CONFLICT (reference) DO NOTHING`,
      [d.tx_ref, d.meta && d.meta.bookingId, Math.round((d.amount || 0) * 100), d]
    );
    if (d.meta && d.meta.bookingId) await db().query("UPDATE bookings SET booking_status='paid', payment_status='paid' WHERE id=$1", [d.meta.bookingId]);
  }
  res.status(200).send("ok");
});

// Search trips by route + date (public for pilot; add auth later if abused)
exports.searchTrips = onCall(async (req) => {  const {fromParkId, toParkId, date, seats} = req.data;
  const day = date ? new Date(date) : new Date();
  const start = new Date(day); start.setHours(0, 0, 0, 0);
  const end = new Date(day); end.setHours(23, 59, 59, 999);
  const {rows} = await db().query(
    `SELECT t.id, t.departs_at, t.capacity, t.booked_count, t.status, t.fare_kobo,
            pf.name AS from_park, pt.name AS to_park, v.type AS vehicle_type, v.plate_no
     FROM trips t
     JOIN routes r ON r.id = t.route_id
     JOIN parks pf ON pf.id = r.from_park_id
     JOIN parks pt ON pt.id = r.to_park_id
     LEFT JOIN vehicles v ON v.id = t.vehicle_id
     WHERE r.from_park_id = $1 AND r.to_park_id = $2
       AND t.departs_at BETWEEN $3 AND $4
       AND t.status IN ('scheduled','boarding')
       AND t.capacity - t.booked_count >= $5
     ORDER BY t.departs_at`,
    [fromParkId, toParkId, start.toISOString(), end.toISOString(), seats || 1]
  );
  return {trips: rows};
});

// Trip detail + driver/vehicle (public; fare shown pre-confirm per §16)
exports.tripDetail = onCall(async (req) => {  const {tripId} = req.data;
  const {rows} = await db().query(
    `SELECT t.id, t.departs_at, t.capacity, t.booked_count, t.status, t.fare_kobo,
            pf.name AS from_park, pt.name AS to_park,
            v.type AS vehicle_type, v.vehicle_no, v.plate_no, v.verified AS vehicle_verified,
            u.name AS driver_name, u.phone AS driver_phone,
            d.verified AS driver_verified, d.rating_avg AS driver_rating, d.trips_completed
     FROM trips t
     JOIN routes r ON r.id = t.route_id
     JOIN parks pf ON pf.id = r.from_park_id
     JOIN parks pt ON pt.id = r.to_park_id
     LEFT JOIN vehicles v ON v.id = t.vehicle_id
     LEFT JOIN users u ON u.id = t.driver_id
     LEFT JOIN drivers d ON d.user_id = t.driver_id
     WHERE t.id = $1`,
    [tripId]
  );
  if (!rows.length) throw new HttpsError("not-found", "Trip not found");
  return {trip: rows[0]};
});

// My bookings (owner only)
exports.myBookings = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {rows} = await db().query(
    `SELECT b.*, t.departs_at, t.status AS trip_status, t.last_lat, t.last_lng, t.last_ping_at,
            pf.name AS from_park, pt.name AS to_park
     FROM bookings b JOIN trips t ON t.id = b.trip_id
     JOIN routes r ON r.id = t.route_id
     JOIN parks pf ON pf.id = r.from_park_id
     JOIN parks pt ON pt.id = r.to_park_id
     WHERE b.passenger_id = $1 ORDER BY b.created_at DESC LIMIT 50`,
    [req.auth.uid]
  );
  return {bookings: rows};
});

// Verify Paystack ref server-side (called after inline checkout)
exports.verifyPaystack = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {reference, bookingId} = req.data;
  const secret = process.env.PAYSTACK_SECRET_KEY || "";
  const r = await axios.get(`https://api.paystack.co/transaction/verify/${reference}`, {headers: {Authorization: `Bearer ${secret}`}});
  if (r.data.data.status !== "success") throw new HttpsError("failed-precondition", "Payment not successful");
  await db().query(
    `INSERT INTO payments (reference, booking_id, provider, amount_kobo, status, raw)
     VALUES ($1,$2,'paystack',$3,'success',$4) ON CONFLICT (reference) DO NOTHING`,
    [reference, bookingId, r.data.data.amount, r.data]
  );
  await db().query("UPDATE bookings SET booking_status='paid', payment_status='paid' WHERE id=$1", [bookingId]);
  const bk = await db().query('SELECT booking_no, passenger_id FROM bookings WHERE id=$1', [bookingId]);
  if (bk.rows.length) {
    notifyUser(bk.rows[0].passenger_id, {
      sms: `9ja Transport: payment received for ${bk.rows[0].booking_no}. Show slip at park.`,
      subject: `Payment received ${bk.rows[0].booking_no}`,
      email: `Payment of ${r.data.data.amount} kobo received for booking ${bk.rows[0].booking_no}.\n\n9ja Transport`,
    });
  }
  return {ok: true};
});

// Flutterwave (fallback provider): init returns a payment link; verify confirms server-side.
exports.flutterwaveInit = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {bookingId, email} = req.data;
  const b = await db().query('SELECT * FROM bookings WHERE id=$1', [bookingId]);
  if (!b.rows.length) throw new HttpsError("not-found", "Booking not found");
  const bk = b.rows[0];
  if (bk.passenger_id !== req.auth.uid) await requireRole(req.auth.uid, ['admin']);
  const txRef = `9JA-${Date.now()}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
  const r = await axios.post('https://api.flutterwave.com/v3/payments', {
    tx_ref: txRef, amount: bk.fare_kobo / 100, currency: 'NGN',
    redirect_url: 'https://9ja-transport.web.app/pay/callback',
    meta: {bookingId}, customer: {email: email || 'passenger@9ja.transport'},
  }, {headers: {Authorization: `Bearer ${process.env.FLW_SECRET_KEY || ''}`}});
  await db().query(
    `INSERT INTO payments (reference, booking_id, provider, amount_kobo, status, raw)
     VALUES ($1,$2,'flutterwave',$3,'pending',$4) ON CONFLICT (reference) DO NOTHING`,
    [txRef, bookingId, bk.fare_kobo, r.data]);
  return {link: r.data.data.link, txRef};
});

exports.verifyFlutterwave = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {transactionId, bookingId} = req.data;
  const r = await axios.get(`https://api.flutterwave.com/v3/transactions/${transactionId}/verify`,
    {headers: {Authorization: `Bearer ${process.env.FLW_SECRET_KEY || ''}`}});
  if (r.data.data.status !== 'successful') throw new HttpsError('failed-precondition', 'Payment not successful');
  await db().query(
    `INSERT INTO payments (reference, booking_id, provider, amount_kobo, status, raw)
     VALUES ($1,$2,'flutterwave',$3,'success',$4) ON CONFLICT (reference) DO NOTHING`,
    [r.data.data.tx_ref, bookingId, Math.round(r.data.data.amount * 100), r.data]);
  await db().query("UPDATE bookings SET booking_status='paid', payment_status='paid' WHERE id=$1", [bookingId]);
  return {ok: true};
});

// Gemini: admin support-draft + notification translation (key server-side only).
exports.supportDraft = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  await requireRole(req.auth.uid, ['admin']);
  const {complaintId} = req.data;
  const {rows} = await db().query('SELECT category, message FROM complaints WHERE id=$1', [complaintId]);
  if (!rows.length) throw new HttpsError('not-found', 'Complaint not found');
  const draft = await draftReply(rows[0].category, rows[0].message);
  if (!draft) throw new HttpsError('failed-precondition', 'AI unavailable (GEMINI_API_KEY unset?)');
  return {draft};
});

exports.translateText = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const {text, lang} = req.data;
  return {text: await translate(String(text || '').slice(0, 500), lang)};
});

// Phase 6: park today's trips with live counts (worker/driver/admin, same-park enforced)
exports.parkTrips = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const me = await requireRole(req.auth.uid, ["driver", "park_worker", "admin", "owner"]);
  const day = new Date(); day.setHours(0, 0, 0, 0);
  const end = new Date(); end.setHours(23, 59, 59, 999);
  let q = `SELECT t.id, t.departs_at, t.capacity, t.booked_count, t.arrived_count, t.status,
                  pf.name AS from_park, pt.name AS to_park
           FROM trips t JOIN routes r ON r.id=t.route_id
           JOIN parks pf ON pf.id=r.from_park_id JOIN parks pt ON pt.id=r.to_park_id
           WHERE t.departs_at BETWEEN $1 AND $2`;
  const params = [day.toISOString(), end.toISOString()];
  if (me.role !== "admin" && me.park_id) { q += ` AND t.park_id = $3`; params.push(me.park_id); }
  q += ` ORDER BY t.departs_at`;
  const {rows} = await db().query(q, params);
  return {trips: rows};
});

// Phase 7: driver today's trips + earnings-lite
exports.driverTrips = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  await requireRole(req.auth.uid, ["driver", "admin"]);
  const {rows} = await db().query(
    `SELECT t.id, t.departs_at, t.capacity, t.booked_count, t.arrived_count, t.status, t.fare_kobo,
            pf.name AS from_park, pt.name AS to_park
     FROM trips t JOIN routes r ON r.id=t.route_id
     JOIN parks pf ON pf.id=r.from_park_id JOIN parks pt ON pt.id=r.to_park_id
     WHERE t.driver_id=$1 AND t.departs_at > now() - interval '1 day' ORDER BY t.departs_at`,
    [req.auth.uid]);
  return {trips: rows};
});

exports.driverEarnings = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {rows} = await db().query(
    `SELECT COUNT(*) FILTER (WHERE t.status='completed') AS completed,
            COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE b.payment_status='paid'),0) AS online_kobo,
            COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE p.provider='cash' AND p.status='success'),0) AS cash_kobo,
            COALESCE(SUM(b.seats) FILTER (WHERE b.booking_status IN ('paid','arrived','boarded')),0) AS pax,
            COALESCE(COUNT(b.id) FILTER (WHERE b.booking_status IN ('paid','arrived','boarded')),0) AS bookings
     FROM trips t LEFT JOIN bookings b ON b.trip_id=t.id LEFT JOIN payments p ON p.booking_id=b.id
     WHERE t.driver_id=$1 AND t.departs_at > date_trunc('day', now())`,
    [req.auth.uid]);
  const perTrip = await db().query(
    `SELECT t.id, t.departs_at, t.status, pf.name AS from_park, pt.name AS to_park,
            COALESCE(SUM(b.seats) FILTER (WHERE b.booking_status IN ('paid','arrived','boarded')),0) AS pax,
            COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE b.payment_status='paid'),0) AS gross_kobo,
            COALESCE(COUNT(b.id) FILTER (WHERE b.payment_status='unpaid'),0) AS unpaid_count
     FROM trips t JOIN routes r ON r.id=t.route_id
     JOIN parks pf ON pf.id=r.from_park_id JOIN parks pt ON pt.id=r.to_park_id
     LEFT JOIN bookings b ON b.trip_id=t.id
     WHERE t.driver_id=$1 AND t.departs_at > date_trunc('day', now())
     GROUP BY t.id, pf.name, pt.name ORDER BY t.departs_at`,
    [req.auth.uid]);
  const s = rows[0];
  const gross = Number(s.online_kobo) + Number(s.cash_kobo);
  const chargeRate = 0.03; // 3% platform charge (§38) — confirm at pilot
  const charge = Math.round(gross * chargeRate);
  return {earnings: {...s, gross_kobo: gross, charge_kobo: charge, net_kobo: gross - charge},
    perTrip: perTrip.rows, chargeRate};
});

// Phase 8: Paystack init (returns auth URL) + cash received + notifications inbox
exports.paystackInit = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {bookingId, email} = req.data;
  const b = await db().query("SELECT * FROM bookings WHERE id=$1", [bookingId]);
  if (!b.rows.length) throw new HttpsError("not-found", "Booking not found");
  const bk = b.rows[0];
  const secret = process.env.PAYSTACK_SECRET_KEY || "";
  const r = await axios.post("https://api.paystack.co/transaction/initialize",
    {amount: bk.fare_kobo, email: email || "passenger@9ja.transport", metadata: {bookingId}, callback_url: "https://9ja-transport.web.app/pay/callback"},
    {headers: {Authorization: `Bearer ${secret}`}});
  await db().query(
    `INSERT INTO payments (reference, booking_id, provider, amount_kobo, status, raw)
     VALUES ($1,$2,'paystack',$3,'pending',$4) ON CONFLICT (reference) DO NOTHING`,
    [r.data.data.reference, bookingId, bk.fare_kobo, r.data]);
  return {authorizationUrl: r.data.data.authorization_url, reference: r.data.data.reference};
});

exports.markCashReceived = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const me = await requireRole(req.auth.uid, ["park_worker", "driver", "admin"]);
  const {bookingId} = req.data;
  const client = await db().connect();
  try {
    await client.query("BEGIN");
    const b = await client.query("SELECT b.*, t.park_id FROM bookings b JOIN trips t ON t.id=b.trip_id WHERE b.id=$1 FOR UPDATE", [bookingId]);
    if (!b.rows.length) throw new HttpsError("not-found", "Booking not found");
    const bk = b.rows[0];
    if (me.role !== "admin" && me.park_id && me.park_id !== bk.park_id) throw new HttpsError("permission-denied", "Wrong park");
    if (bk.payment_status === "paid") throw new HttpsError("failed-precondition", "Already paid");
    await client.query("INSERT INTO payments (reference, booking_id, provider, amount_kobo, status) VALUES ($1,$2,'cash',$3,'success') ON CONFLICT DO NOTHING",
      [`CASH-${bookingId.slice(0, 8)}-${Date.now()}`, bookingId, bk.fare_kobo]);
    await client.query("UPDATE bookings SET payment_status='paid', booking_status=CASE WHEN booking_status='reserved' THEN 'paid' ELSE booking_status END WHERE id=$1", [bookingId]);
    await client.query("COMMIT");
    notifyUser(bk.passenger_id, {
      sms: `9ja Transport: cash received for ${bk.booking_no}. Show slip at park.`,
      subject: `Cash received ${bk.booking_no}`,
      email: `Cash payment recorded for booking ${bk.booking_no}.\n\n9ja Transport`,
    });
    return {ok: true};
  } catch (e) { await client.query("ROLLBACK"); throw e; } finally { client.release(); }
});

exports.myNotifications = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {rows} = await db().query("SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 30", [req.auth.uid]);
  return {notifications: rows};
});

// Phase 9: complaints + ratings + admin (approve driver/vehicle, set fare)
exports.createComplaint = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {bookingId, category, message} = req.data;
  const {rows} = await db().query(
    "INSERT INTO complaints (booking_id, reporter_id, category, message) VALUES ($1,$2,$3,$4) RETURNING id",
    [bookingId || null, req.auth.uid, category, message]);
  // Gemini triage (best-effort, post-insert — inbox works with or without AI).
  triageComplaint(category, message).then(async (t) => {
    if (t) await db().query('UPDATE complaints SET ai_urgency=$2, ai_summary=$3 WHERE id=$1', [rows[0].id, t.urgency, t.summary]);
  }).catch(() => {});
  return {id: rows[0].id};
});

exports.createRating = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {tripId, bookingId, score, comment} = req.data;
  if (score < 1 || score > 5) throw new HttpsError("invalid-argument", "score 1-5");
  const t = await db().query("SELECT status FROM trips WHERE id=$1", [tripId]);
  if (!t.rows.length || t.rows[0].status !== "completed") throw new HttpsError("failed-precondition", "Rate only completed trips");
  await db().query(
    "INSERT INTO ratings (trip_id, booking_id, rater_id, score, comment) VALUES ($1,$2,$3,$4,$5) ON CONFLICT (booking_id) DO NOTHING",
    [tripId, bookingId, req.auth.uid, score, comment || null]);
  return {ok: true};
});

exports.adminApproveDriver = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  await requireRole(req.auth.uid, ["admin"]);
  const {userId, approve} = req.data;
  await db().query("UPDATE drivers SET verified=$2 WHERE user_id=$1", [userId, !!approve]);
  await db().query("UPDATE users SET verified=$2 WHERE id=$1", [userId, !!approve]);
  return {ok: true};
});

exports.adminSetFare = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  await requireRole(req.auth.uid, ["admin"]);
  const {routeId, newKobo} = req.data;
  const old = await db().query("SELECT base_fare_kobo FROM routes WHERE id=$1", [routeId]);
  await db().query("UPDATE routes SET base_fare_kobo=$2 WHERE id=$1", [newKobo, routeId]);
  await db().query("INSERT INTO fare_history (route_id, old_kobo, new_kobo, changed_by) VALUES ($1,$2,$3,$4)",
    [routeId, old.rows[0]?.base_fare_kobo || 0, newKobo, req.auth.uid]);
  return {ok: true};
});

// Phase 6: booking queue per trip (§22) — arrived first, then by creation
exports.tripBookings = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const me = await requireRole(req.auth.uid, ["driver", "park_worker", "admin", "owner"]);
  const {tripId} = req.data;
  const t = await db().query("SELECT * FROM trips WHERE id=$1", [tripId]);
  if (!t.rows.length) throw new HttpsError("not-found", "Trip not found");
  if (me.role !== "admin" && me.park_id && me.park_id !== t.rows[0].park_id)
    throw new HttpsError("permission-denied", "Wrong park");
  const {rows} = await db().query(
    `SELECT b.id, b.passenger_name, b.seats, b.booking_no, b.booking_status, b.payment_status, b.created_at,
            s.created_at AS arrived_at
     FROM bookings b LEFT JOIN LATERAL (
       SELECT created_at FROM scans WHERE booking_id=b.id AND result='valid' ORDER BY created_at LIMIT 1
     ) s ON true
     WHERE b.trip_id=$1 AND b.booking_status NOT IN ('cancelled','expired','refunded')
     ORDER BY CASE WHEN b.booking_status IN ('arrived','boarded') THEN 0 ELSE 1 END, s.arrived_at NULLS LAST, b.created_at`,
    [tripId]
  );
  return {bookings: rows, trip: t.rows[0]};
});

// Phase 8: FCM token save + daily cash close + refunds pending (admin)
exports.saveFcmToken = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {token} = req.data;
  if (!token) throw new HttpsError("invalid-argument", "token required");
  await db().query(
    `INSERT INTO users (id, phone, name, role, fcm_tokens) VALUES ($1,'','', 'passenger', ARRAY[$2])
     ON CONFLICT (id) DO UPDATE SET fcm_tokens = (
       SELECT array_agg(DISTINCT t) FROM unnest(array_append(users.fcm_tokens, $2)) t)`,
    [req.auth.uid, token]);
  return {ok: true};
});

exports.dailyClose = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const me = await requireRole(req.auth.uid, ["park_worker", "driver", "admin", "owner"]);
  let parkFilter = "";
  const params = [];
  if (me.role !== "admin" && me.park_id) { parkFilter = "AND t.park_id = $1"; params.push(me.park_id); }
  const {rows} = await db().query(
    `SELECT COUNT(b.id) FILTER (WHERE b.payment_status='paid') AS paid_count,
            COUNT(b.id) FILTER (WHERE b.payment_status='unpaid') AS unpaid_count,
            COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE b.payment_status='paid'),0) AS collected_kobo,
            COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE b.payment_status='unpaid'),0) AS outstanding_kobo,
            COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE p.provider='cash' AND p.status='success'),0) AS cash_kobo
     FROM bookings b JOIN trips t ON t.id=b.trip_id LEFT JOIN payments p ON p.booking_id=b.id
     WHERE b.created_at > date_trunc('day', now()) ${parkFilter}`,
    params);
  return {close: rows[0]};
});

exports.refundsPending = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  await requireRole(req.auth.uid, ["admin"]);
  const {rows} = await db().query(
    "SELECT b.id, b.booking_no, b.passenger_name, b.fare_kobo, b.created_at FROM bookings b WHERE b.payment_status='refund_pending' ORDER BY b.created_at LIMIT 50");
  return {refunds: rows};
});

// Phase 12: live tracking — driver ping, passenger read, proximity alerts
function haversineKm(a, b, c, d) {
  const R = 6371, r = Math.PI / 180;
  const h = Math.sin((c - a) * r / 2) ** 2 + Math.cos(a * r) * Math.cos(c * r) * Math.sin((d - b) * r / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// Driver phone pings every ~10-15s while trip is departed. Stops at completed.
exports.updateTripLocation = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {tripId, lat, lng, speedKmh} = req.data;
  if (typeof lat !== "number" || typeof lng !== "number") throw new HttpsError("invalid-argument", "lat/lng required");
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) throw new HttpsError("invalid-argument", "bad coords");
  const t = await db().query("SELECT * FROM trips WHERE id=$1", [tripId]);
  if (!t.rows.length) throw new HttpsError("not-found", "Trip not found");
  const trip = t.rows[0];
  if (trip.driver_id !== req.auth.uid) {
    const me = await requireRole(req.auth.uid, ["admin"]);
    if (!me) throw new HttpsError("permission-denied", "Only assigned driver");
  }
  if (trip.status !== "departed") throw new HttpsError("failed-precondition", "Trip not active");
  await db().query("UPDATE trips SET last_lat=$2, last_lng=$3, last_ping_at=now() WHERE id=$1", [tripId, lat, lng]);
  await db().query("INSERT INTO trip_locations (trip_id, lat, lng, speed_kmh) VALUES ($1,$2,$3,$4)",
    [tripId, lat, lng, speedKmh || null]);
  return {ok: true};
});

// Booked passenger (or same-park worker/admin) reads live position. Denied once completed.
exports.getTripLocation = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  const {tripId} = req.data;
  const t = await db().query(
    `SELECT t.*, pf.name AS from_park, pt.name AS to_park, pt.lat AS dest_lat, pt.lng AS dest_lng
     FROM trips t JOIN routes r ON r.id=t.route_id
     JOIN parks pf ON pf.id=r.from_park_id JOIN parks pt ON pt.id=r.to_park_id WHERE t.id=$1`,
    [tripId]);
  if (!t.rows.length) throw new HttpsError("not-found", "Trip not found");
  const trip = t.rows[0];
  if (trip.status === "completed" || trip.status === "cancelled")
    throw new HttpsError("failed-precondition", "Trip ended — tracking off");
  const own = await db().query("SELECT 1 FROM bookings WHERE trip_id=$1 AND passenger_id=$2 AND booking_status NOT IN ('cancelled','expired','refunded') LIMIT 1",
    [tripId, req.auth.uid]);
  if (!own.rows.length) await requireRole(req.auth.uid, ["driver", "park_worker", "admin", "owner"]);
  if (trip.last_lat == null) return {trip, position: null, stale: true, etaMin: null};
  const ageSec = (Date.now() - new Date(trip.last_ping_at).getTime()) / 1000;
  const stale = ageSec > 60;
  let etaMin = null;
  if (trip.dest_lat != null && !stale) {
    const km = haversineKm(trip.last_lat, trip.last_lng, trip.dest_lat, trip.dest_lng);
    const sp = await db().query(
      "SELECT AVG(speed_kmh) AS v FROM (SELECT speed_kmh FROM trip_locations WHERE trip_id=$1 AND speed_kmh > 5 ORDER BY at DESC LIMIT 20) s",
      [tripId]);
    const v = Number(sp.rows[0]?.v) || 50; // fallback 50 km/h (expressway)
    etaMin = Math.round((km / v) * 60);
  }
  return {trip: {id: trip.id, status: trip.status, from_park: trip.from_park, to_park: trip.to_park},
    position: {lat: trip.last_lat, lng: trip.last_lng, at: trip.last_ping_at},
    stale, ageSec: Math.round(ageSec), etaMin};
});

// Every 2 min: departed trips within 5 km of destination → "Approaching" push (once per trip).
exports.checkApproaching = onSchedule("every 2 minutes", async () => {
  const {rows} = await db().query(
    `SELECT t.id, t.last_lat, t.last_lng, pt.lat AS dest_lat, pt.lng AS dest_lng
     FROM trips t JOIN routes r ON r.id=t.route_id JOIN parks pt ON pt.id=r.to_park_id
     WHERE t.status='departed' AND t.last_ping_at > now() - interval '5 minutes'
       AND t.last_lat IS NOT NULL AND pt.lat IS NOT NULL`);
  for (const t of rows) {
    const km = haversineKm(t.last_lat, t.last_lng, t.dest_lat, t.dest_lng);
    if (km <= 5) {
      const done = await db().query(
        "UPDATE trips SET approaching_notified=TRUE WHERE id=$1 AND approaching_notified IS NOT TRUE RETURNING id",
        [t.id]);
      if (done.rows.length) {
        await admin.messaging().sendToTopic(`trip_${t.id}`,
          {notification: {title: "Approaching your stop", body: "Your bus is less than 5 km away."}});
      }
    }
  }
});

// ---------- Auth: email/phone + password, signup with email/SMS OTP ----------
// Passwords live ONLY in Firebase Auth. PG users row is keyed by Firebase uid.
function normPhone(p) {
  let s = String(p || '').replace(/[\s-]/g, '');
  if (/^0[789]\d{9}$/.test(s)) s = '+234' + s.slice(1);
  return s;
}
const isPhone = (s) => /^\+234[789]\d{9}$/.test(s);
const isEmail = (s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const otp6 = () => String(Math.floor(100000 + Math.random() * 900000));

async function sendMail(to, subject, text) {
  const {SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM} = process.env;
  if (!SMTP_HOST) return false; // not configured → caller falls back to dev code/log
  const nodemailer = require('nodemailer');
  const tx = nodemailer.createTransport({
    host: SMTP_HOST, port: Number(SMTP_PORT || 587), secure: String(process.env.SMTP_SECURE) === 'true',
    auth: SMTP_USER ? {user: SMTP_USER, pass: SMTP_PASS} : undefined,
  });
  await tx.sendMail({from: SMTP_FROM || '9ja Transport <no-reply@9ja.transport>', to, subject, text});
  return true;
}

// POST /register {phone, email, firstName, lastName, username, password, confirmPassword, otpChannel}
exports.register = onCall(async (req) => {
  const {phone, email, firstName, lastName, username, password, confirmPassword, otpChannel} = req.data || {};
  const em = String(email || '').trim().toLowerCase();
  const ph = normPhone(phone);
  const un = String(username || '').trim();
  if (!firstName?.trim() || !lastName?.trim()) throw new HttpsError('invalid-argument', 'First and last name required');
  if (!isPhone(ph)) throw new HttpsError('invalid-argument', 'Enter a valid Nigerian phone (e.g. 0803… or +234803…)');
  if (!isEmail(em)) throw new HttpsError('invalid-argument', 'Enter a valid email address');
  if (!/^[a-zA-Z0-9._-]{3,20}$/.test(un)) throw new HttpsError('invalid-argument', 'Username: 3–20 letters/numbers/._-');
  if (typeof password !== 'string' || password.length < 8) throw new HttpsError('invalid-argument', 'Password must be 8+ characters');
  if (password !== confirmPassword) throw new HttpsError('invalid-argument', 'Passwords do not match');
  if (!['email', 'sms'].includes(otpChannel)) throw new HttpsError('invalid-argument', 'Choose OTP channel: email or SMS');

  const dup = await db().query(
    'SELECT phone, email, username FROM users WHERE phone=$1 OR email=$2 OR username=$3 LIMIT 1', [ph, em, un]);
  if (dup.rows.length) {
    const d = dup.rows[0];
    throw new HttpsError('already-exists',
      d.phone === ph ? 'Phone number already registered' : d.email === em ? 'Email already registered' : 'Username taken');
  }
  let uid;
  try {
    const u = await admin.auth().createUser({
      email: em, password, displayName: `${firstName.trim()} ${lastName.trim()}`.slice(0, 60), phoneNumber: ph,
    });
    uid = u.uid;
  } catch (e) {
    if (e.code === 'auth/email-already-exists' || e.code === 'auth/phone-number-already-exists')
      throw new HttpsError('already-exists', 'Account already exists — try logging in');
    throw new HttpsError('internal', 'Could not create account');
  }
  await db().query(
    `INSERT INTO users (id, phone, name, email, first_name, last_name, username, role)
     VALUES ($1,$2,$3,$4,$5,$6,$7,'passenger')`,
    [uid, ph, `${firstName.trim()} ${lastName.trim()}`, em, firstName.trim(), lastName.trim(), un]);

  if (otpChannel === 'sms') {
    // SMS OTP is delivered by Firebase client verifyPhoneNumber; app links it, then calls confirmPhoneLink.
    return {uid, email: em, channel: 'sms'};
  }
  const recent = await db().query(
    "SELECT COUNT(*) AS n FROM otp_codes WHERE user_id=$1 AND created_at > now() - interval '1 hour'", [uid]);
  if (Number(recent.rows[0].n) >= 5) throw new HttpsError('resource-exhausted', 'Too many codes — try again later');
  const code = otp6();
  await db().query(
    "INSERT INTO otp_codes (user_id, channel, code_hash, expires_at) VALUES ($1,'email',$2, now() + interval '10 minutes')",
    [uid, sha256(code)]);
  const sent = await sendMail(em, 'Your 9ja Transport code', `Your verification code is ${code}. It expires in 10 minutes.`);
  if (!sent) {
    console.log(`OTP for ${em}: ${code}`);
    if (process.env.ALLOW_OTP_DEBUG === 'true') return {uid, email: em, channel: 'email', devCode: code};
  }
  return {uid, email: em, channel: 'email'};
});

// POST /verifyEmailOtp {code} (authed) — marks email_verified.
exports.verifyEmailOtp = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const code = String(req.data?.code || '').trim();
  if (!/^\d{6}$/.test(code)) throw new HttpsError('invalid-argument', 'Enter the 6-digit code');
  const {rows} = await db().query(
    `SELECT * FROM otp_codes WHERE user_id=$1 AND channel='email' AND consumed=FALSE
     ORDER BY created_at DESC LIMIT 1`, [req.auth.uid]);
  const row = rows[0];
  if (!row || new Date(row.expires_at) < new Date()) throw new HttpsError('failed-precondition', 'Code expired — resend a new one');
  if (row.attempts >= 5) throw new HttpsError('resource-exhausted', 'Too many attempts — resend a new code');
  await db().query('UPDATE otp_codes SET attempts = attempts + 1 WHERE id=$1', [row.id]);
  if (row.code_hash !== sha256(code)) throw new HttpsError('invalid-argument', 'Wrong code — check and try again');
  await db().query('UPDATE otp_codes SET consumed=TRUE WHERE id=$1', [row.id]);
  await db().query('UPDATE users SET email_verified=TRUE WHERE id=$1', [req.auth.uid]);
  return {ok: true};
});

// POST /confirmPhoneLink (authed) — call after linking Firebase phone credential in-app.
exports.confirmPhoneLink = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const me = await db().query('SELECT phone FROM users WHERE id=$1', [req.auth.uid]);
  if (!me.rows.length) throw new HttpsError('not-found', 'Profile not found');
  const fb = await admin.auth().getUser(req.auth.uid).catch(() => null);
  if (!fb?.phoneNumber || fb.phoneNumber !== me.rows[0].phone)
    throw new HttpsError('failed-precondition', 'Phone not verified on this account yet');
  await db().query('UPDATE users SET phone_verified=TRUE WHERE id=$1', [req.auth.uid]);
  return {ok: true};
});

// POST /resendOtp (authed, email channel).
exports.resendOtp = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const me = await db().query('SELECT id, email, email_verified FROM users WHERE id=$1', [req.auth.uid]);
  if (!me.rows.length) throw new HttpsError('not-found', 'Profile not found');
  if (me.rows[0].email_verified) return {ok: true, already: true};
  const recent = await db().query(
    "SELECT COUNT(*) AS n FROM otp_codes WHERE user_id=$1 AND created_at > now() - interval '1 hour'", [req.auth.uid]);
  if (Number(recent.rows[0].n) >= 5) throw new HttpsError('resource-exhausted', 'Too many codes — try again later');
  const code = otp6();
  await db().query(
    "INSERT INTO otp_codes (user_id, channel, code_hash, expires_at) VALUES ($1,'email',$2, now() + interval '10 minutes')",
    [req.auth.uid, sha256(code)]);
  const sent = await sendMail(me.rows[0].email, 'Your 9ja Transport code', `Your verification code is ${code}. It expires in 10 minutes.`);
  if (!sent) {
    console.log(`OTP for ${me.rows[0].email}: ${code}`);
    if (process.env.ALLOW_OTP_DEBUG === 'true') return {ok: true, devCode: code};
  }
  return {ok: true};
});

// POST /loginResolve {identifier} → {email} so the app can sign in with email+password.
// NOTE: reveals whether an identifier is registered (standard for login UX); attempts are
// limited client-side and Firebase throttles password guesses.
exports.loginResolve = onCall(async (req) => {
  let idn = String(req.data?.identifier || '').trim();
  if (!idn) throw new HttpsError('invalid-argument', 'Enter email, phone number or username');
  let rows;
  if (isEmail(idn.toLowerCase())) {
    rows = await db().query('SELECT email FROM users WHERE email=$1 LIMIT 1', [idn.toLowerCase()]);
  } else if (/^[0+]/.test(idn)) {
    rows = await db().query('SELECT email FROM users WHERE phone=$1 LIMIT 1', [normPhone(idn)]);
  } else {
    rows = await db().query('SELECT email FROM users WHERE username=$1 LIMIT 1', [idn]);
  }
  if (!rows.length) throw new HttpsError('not-found', 'No account found — check details or sign up');
  return {email: rows.rows[0].email};
});

exports.expireNoShows = onSchedule("every 5 minutes", async () => {
  await db().query("UPDATE bookings SET booking_status='expired' WHERE expires_at < now() AND booking_status IN ('reserved','paid')");
});

exports.sendReminder = onSchedule("every 10 minutes", async () => {
  const {rows} = await db().query(
    `SELECT t.id, t.departs_at FROM trips t WHERE t.departs_at BETWEEN now() + interval '55 minutes' AND now() + interval '70 minutes' AND t.status IN ('scheduled','boarding')`
  );
  for (const t of rows) {
    await admin.messaging().sendToTopic(`trip_${t.id}`, {notification: {title: "Trip in 1 hour", body: "Your 9ja Transport trip leaves in about 1 hour."}});
  }
});
