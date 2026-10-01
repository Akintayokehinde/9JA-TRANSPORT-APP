-- Gemini triage columns on complaints (best-effort, nullable — inbox works without AI).
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS ai_urgency TEXT CHECK (ai_urgency IN ('low','medium','high','critical'));
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS ai_summary TEXT;
CREATE INDEX IF NOT EXISTS idx_complaints_urgency ON complaints (ai_urgency, status);
