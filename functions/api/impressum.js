// POST /api/impressum: the provider identification, only after a passed
// Cloudflare Turnstile check. Both values are secrets on the Pages project's
// Production environment, never in the repository. Nothing here logs.

const VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

function answer(status, body, headers = {}) {
  return new Response(body, {
    status,
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store',
      ...headers,
    },
  });
}

export async function onRequestPost({ request, env }) {
  const secret = env.TURNSTILE_SECRET_KEY;
  if (!secret) return answer(500, 'Not configured.');

  let token;
  try {
    ({ token } = await request.json());
  } catch {
    return answer(403, 'Check failed.');
  }
  if (typeof token !== 'string' || token === '') return answer(403, 'Check failed.');

  let outcome;
  try {
    const verification = await fetch(VERIFY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ secret, response: token }),
    });
    if (verification.status !== 200) return answer(502, 'Check unavailable.');
    outcome = await verification.json();
  } catch {
    return answer(502, 'Check unavailable.');
  }
  if (outcome?.success !== true) return answer(403, 'Check failed.');

  const text = env.IMPRESSUM_TEXT;
  if (!text) return answer(500, 'Not configured.');
  return answer(200, text);
}

// Every other method. Dispatching here keeps POST correct whichever handler
// Pages prefers when both are exported.
export function onRequest(context) {
  if (context.request.method === 'POST') return onRequestPost(context);
  return answer(405, 'Method not allowed.', { Allow: 'POST' });
}
