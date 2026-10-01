// Gemini AI helpers — server-side ONLY (key never leaves Functions).
// Used for: complaint triage, support reply drafts, notification translation.
// QR codes, payments and OTPs NEVER touch Gemini (local math / providers).
const axios = require('axios');

function client() {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return null;
  return axios.create({
    baseURL: 'https://generativelanguage.googleapis.com/v1beta',
    params: {key},
    timeout: 20000,
  });
}

async function generate(prompt, json = false) {
  const c = client();
  if (!c) return null;
  const model = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
  const r = await c.post(`/models/${model}:generateContent`, {
    contents: [{parts: [{text: prompt}]}],
    ...(json ? {generationConfig: {responseMimeType: 'application/json'}} : {}),
  });
  return r.data?.candidates?.[0]?.content?.parts?.[0]?.text || null;
}

// Classify a complaint for the admin inbox. Best-effort; returns null on failure.
async function triageComplaint(category, message) {
  try {
    const out = await generate(
      `You triage bus-park customer complaints. Reply ONLY JSON {"urgency":"low|medium|high|critical","summary":"<=20 words"}.\nCategory: ${category}\nMessage: ${message}`,
      true);
    if (!out) return null;
    const j = JSON.parse(out);
    if (!['low', 'medium', 'high', 'critical'].includes(j.urgency)) return null;
    return {urgency: j.urgency, summary: String(j.summary).slice(0, 140)};
  } catch (e) {
    console.log('Gemini triage failed:', e.message);
    return null;
  }
}

async function draftReply(category, message) {
  const out = await generate(
    `Draft a short, polite customer-support reply (<=60 words, Simple English) for a Nigerian bus-park complaint.\nCategory: ${category}\nMessage: ${message}\nReply only with the message text.`);
  return out;
}

const LANGS = {en: 'English', pcm: 'Nigerian Pidgin', yo: 'Yoruba', ha: 'Hausa', ig: 'Igbo'};
async function translate(text, lang) {
  if (!LANGS[lang] || lang === 'en') return text;
  const out = await generate(`Translate to ${LANGS[lang]}, keep it short, keep numbers/place names as-is:\n${text}`);
  return out || text;
}

module.exports = {triageComplaint, draftReply, translate, LANGS};
