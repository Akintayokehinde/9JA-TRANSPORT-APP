-- Profile avatars: preset emoji avatar OR gallery photo URL (Firebase Storage avatars/{uid}).
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_emoji TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
