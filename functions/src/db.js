// Postgres pool for Cloud Functions. Uses DATABASE_URL (Neon/Supabase/Cloud SQL).
const {Pool} = require("pg");
let pool;
function db() {
  if (!pool) {
    if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL not set");
    pool = new Pool({connectionString: process.env.DATABASE_URL, ssl: {rejectUnauthorized: false}, max: 5});
  }
  return pool;
}
module.exports = {db};
