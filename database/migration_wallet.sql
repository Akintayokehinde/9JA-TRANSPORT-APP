-- 9JA Transport wallet (passenger dashboard). Amounts in kobo. Ledger-style:
-- every kobo movement is a row in wallet_transactions; wallets.balance is the cache.
CREATE TABLE IF NOT EXISTS wallets (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance_kobo BIGINT NOT NULL DEFAULT 0 CHECK (balance_kobo >= 0),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('fund','pay','refund')),
  amount_kobo BIGINT NOT NULL CHECK (amount_kobo > 0),
  reference TEXT UNIQUE NOT NULL,
  booking_id UUID REFERENCES bookings(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_wtx_user ON wallet_transactions (user_id, created_at DESC);
