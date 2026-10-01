// Termii transactional SMS. Best-effort: returns false (never throws) when
// TERMII_API_KEY is unset or sending fails — pilot must never break on SMS.
const axios = require('axios');

function toLocal(num) {
  let s = String(num || '').replace(/[\s-]/g, '');
  if (s.startsWith('+')) s = s.slice(1);
  if (/^0[789]\d{9}$/.test(s)) s = '234' + s.slice(1);
  return s;
}

async function sendSms(to, message) {
  const key = process.env.TERMII_API_KEY;
  if (!key) return false;
  try {
    await axios.post('https://api.termii.com/api/sms/send', {
      to: toLocal(to),
      from: process.env.TERMII_SENDER_ID || '9jaTransp',
      sms: message,
      type: 'plain',
      channel: 'dnd',
      api_key: key,
    }, {timeout: 10000});
    return true;
  } catch (e) {
    console.log('Termii SMS failed:', e.response?.data || e.message);
    return false;
  }
}

module.exports = {sendSms};
