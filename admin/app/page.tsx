import { pg } from "../lib/db";
import { revalidatePath } from "next/cache";

async function approveDriver(form: FormData) {
  "use server";
  const db = pg();
  const userId = String(form.get("userId"));
  const approve = String(form.get("decision")) === "approve";
  await db.query("UPDATE drivers SET verified=$2 WHERE user_id=$1", [userId, approve]);
  await db.query("UPDATE users SET verified=$2 WHERE id=$1", [userId, approve]);
  revalidatePath("/");
}

async function setFare(form: FormData) {
  "use server";
  const db = pg();
  const routeId = String(form.get("routeId"));
  const newKobo = Number(form.get("newKobo"));
  const old = await db.query("SELECT base_fare_kobo FROM routes WHERE id=$1", [routeId]);
  await db.query("UPDATE routes SET base_fare_kobo=$2 WHERE id=$1", [newKobo, routeId]);
  await db.query(
    "INSERT INTO fare_history (route_id, old_kobo, new_kobo, changed_by) VALUES ($1,$2,$3,'admin-001')",
    [routeId, old.rows[0]?.base_fare_kobo ?? 0, newKobo]
  );
  revalidatePath("/");
}

async function resolveComplaint(form: FormData) {
  "use server";
  const db = pg();
  await db.query("UPDATE complaints SET status='resolved' WHERE id=$1", [String(form.get("id"))]);
  revalidatePath("/");
}

export default async function Home() {
  const db = pg();
  const [drivers, trips, complaints, routes, refunds, close, kpi] = await Promise.all([
    db.query("SELECT u.id, u.name, u.phone, d.verified, d.license_no FROM users u JOIN drivers d ON d.user_id=u.id ORDER BY u.created_at DESC LIMIT 20"),
    db.query("SELECT t.id, t.departs_at, t.status, t.booked_count, t.arrived_count FROM trips t ORDER BY t.departs_at DESC LIMIT 20"),
    db.query("SELECT c.id, c.category, c.status, c.created_at FROM complaints c ORDER BY c.created_at DESC LIMIT 20"),
    db.query("SELECT r.id, pf.name AS from_park, pt.name AS to_park, r.base_fare_kobo FROM routes r JOIN parks pf ON pf.id=r.from_park_id JOIN parks pt ON pt.id=r.to_park_id LIMIT 20"),
    db.query("SELECT b.id, b.booking_no, b.passenger_name, b.fare_kobo FROM bookings b WHERE b.payment_status='refund_pending' ORDER BY b.created_at LIMIT 20"),
    db.query(`SELECT COUNT(*) AS n, COALESCE(SUM(b.fare_kobo*b.seats) FILTER (WHERE b.payment_status='paid'),0) AS kobo
              FROM bookings b WHERE b.created_at > date_trunc('day', now())`),
    db.query(`SELECT COUNT(*) AS bookings,
      COUNT(*) FILTER (WHERE b.booking_status IN ('arrived','boarded')) AS arrived,
      COUNT(*) FILTER (WHERE b.booking_status='cancelled') AS cancelled,
      (SELECT ROUND(AVG(score),2) FROM ratings) AS avg_rating,
      (SELECT COUNT(*) FROM (SELECT passenger_id FROM bookings WHERE created_at > now() - interval '14 days' GROUP BY 1 HAVING COUNT(*)>=2) t) AS repeat_pax
      FROM bookings b WHERE b.created_at > now() - interval '14 days'`),
  ]);
  const th: any = { textAlign: "left", background: "#FFC300" };
  return (
    <main style={{ padding: 24, fontFamily: "sans-serif", maxWidth: 1050 }}>
      <h1>🟡 9ja Transport — Admin</h1>
      <p>Today: <b>{close.rows[0].n} bookings · ₦{(Number(close.rows[0].kobo) / 100).toFixed(0)}</b> collected ·
        Refunds pending: <b>{refunds.rows.length}</b> · <a href="#refunds">review below</a></p>
      <p>14-day pilot KPIs — bookings <b>{kpi.rows[0].bookings}</b> · arrived <b>{kpi.rows[0].arrived}</b> ·
        cancelled <b>{kpi.rows[0].cancelled}</b> · avg rating <b>{kpi.rows[0].avg_rating ?? "—"}</b> ·
        repeat pax <b>{kpi.rows[0].repeat_pax}</b> (targets §41: arrival &gt;90%, rating ≥4.5)</p>

      <h2>Pending drivers ({drivers.rows.filter((d: any) => !d.verified).length})</h2>
      <table border={1} cellPadding={6} style={{ borderCollapse: "collapse", width: "100%" }}>
        <thead><tr><th style={th}>Name</th><th style={th}>Phone</th><th style={th}>License</th><th style={th}>Status</th><th style={th}>Action</th></tr></thead>
        <tbody>{drivers.rows.map((d: any) => (
          <tr key={d.id}>
            <td>{d.name}</td><td>{d.phone}</td><td>{d.license_no}</td>
            <td>{d.verified ? "✅ verified" : "⏳ pending"}</td>
            <td><form action={approveDriver} style={{ display: "inline" }}>
              <input type="hidden" name="userId" value={d.id} />
              <button type="submit" name="decision" value={d.verified ? "suspend" : "approve"}>
                {d.verified ? "Suspend" : "Approve"}
              </button>
            </form></td>
          </tr>
        ))}</tbody>
      </table>

      <h2>Fares (locked at booking §16 — change affects new bookings only)</h2>
      <table border={1} cellPadding={6} style={{ borderCollapse: "collapse", width: "100%" }}>
        <thead><tr><th style={th}>Route</th><th style={th}>Current</th><th style={th}>New (kobo)</th></tr></thead>
        <tbody>{routes.rows.map((r: any) => (
          <tr key={r.id}>
            <td>{r.from_park} → {r.to_park}</td><td>₦{(r.base_fare_kobo / 100).toFixed(0)}</td>
            <td><form action={setFare}>
              <input type="hidden" name="routeId" value={r.id} />
              <input type="number" name="newKobo" defaultValue={r.base_fare_kobo} step={5000} style={{ width: 110 }} />
              <button type="submit">Update</button>
            </form></td>
          </tr>
        ))}</tbody>
      </table>

      <h2 id="refunds">Refunds pending ({refunds.rows.length})</h2>
      {refunds.rows.length === 0 ? <p>None — test-mode refunds recorded, process via Paystack dashboard.</p> :
      <table border={1} cellPadding={6} style={{ borderCollapse: "collapse", width: "100%" }}>
        <thead><tr><th style={th}>Booking</th><th style={th}>Passenger</th><th style={th}>Fare</th></tr></thead>
        <tbody>{refunds.rows.map((b: any) => (
          <tr key={b.id}><td>{b.booking_no}</td><td>{b.passenger_name}</td><td>₦{(b.fare_kobo / 100).toFixed(0)}</td></tr>
        ))}</tbody>
      </table>}

      <h2>Recent trips</h2>
      <table border={1} cellPadding={6} style={{ borderCollapse: "collapse", width: "100%" }}>
        <thead><tr><th style={th}>Departs</th><th style={th}>Status</th><th style={th}>Booked</th><th style={th}>Arrived</th></tr></thead>
        <tbody>{trips.rows.map((t: any) => (
          <tr key={t.id}><td>{String(t.departs_at)}</td><td>{t.status}</td><td>{t.booked_count}</td><td>{t.arrived_count}</td></tr>
        ))}</tbody>
      </table>

      <h2>Complaints inbox</h2>
      <table border={1} cellPadding={6} style={{ borderCollapse: "collapse", width: "100%" }}>
        <thead><tr><th style={th}>Category</th><th style={th}>Status</th><th style={th}>At</th><th style={th}>Action</th></tr></thead>
        <tbody>{complaints.rows.map((c: any) => (
          <tr key={c.id}><td>{c.category}</td><td>{c.status}</td><td>{String(c.created_at)}</td>
            <td>{c.status !== "resolved" && <form action={resolveComplaint}>
              <input type="hidden" name="id" value={c.id} /><button type="submit">Resolve</button>
            </form>}</td></tr>
        ))}</tbody>
      </table>
      <p style={{ color: "#666" }}>Suspicious-flag (Phase 9): query bookings &gt;6 seats same phone / 10 min in psql during pilot.</p>
    </main>
  );
}
