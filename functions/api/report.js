// POST /api/report: turns a fixed report code from the app into a GitHub
// issue on this repository, or a +1 reaction on the open issue that already
// has it. The request is untrusted: only values from an allow-list or a
// bounded integer reach the issue, through a fixed template. Nothing here
// logs, and no answer carries the token, the request or GitHub's text.
// See docs/reports.md.
import allow from '../report-allowlist.json' with { type: 'json' };

const REPOSITORY = 'https://api.github.com/repos/comdotlinux/simple-math-tester';
const MAX_BYTES = 1024;
const OPEN_LIMIT = 100;
const TIMEOUT_MS = 8000;
const LABELS = { question: 'suspect-question', problem: 'reported-problem' };

const FIELDS = {
  question: ['type', 'kind', 'variant', 'params', 'level', 'reason', 'version', 'platform', 'locale'],
  problem: ['type', 'category', 'version', 'platform', 'locale'],
};
const KINDS = ['algebra', 'geometry'];
const REASONS = ['wrongAnswer', 'unclearQuestion', 'wrongHint', 'wrongDrawing'];
const CATEGORIES = ['crash', 'display', 'sound', 'translation', 'other'];
const PLATFORMS = ['android', 'ios', 'web', 'linux', 'macos', 'windows'];
const VERSION = /^\d{1,4}\.\d{1,4}\.\d{1,4}$/;

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

const invalid = () => answer(400, 'Invalid report.');
const unavailable = () => answer(502, 'Unavailable.');

const oneOf = (list, value) => typeof value === 'string' && list.includes(value);
const intIn = (value, min, max) => Number.isInteger(value) && value >= min && value <= max;

/** The report when [body] is exactly one of the two shapes, otherwise null. */
export function validate(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) return null;
  const fields = body.type === 'question' ? FIELDS.question
    : body.type === 'problem' ? FIELDS.problem
    : null;
  const keys = Object.keys(body);
  if (!fields || keys.length !== fields.length || !fields.every((f) => keys.includes(f))) return null;
  if (!(typeof body.version === 'string' && VERSION.test(body.version))) return null;
  if (!oneOf(PLATFORMS, body.platform) || !oneOf(allow.locales, body.locale)) return null;
  if (body.type === 'problem') return oneOf(CATEGORIES, body.category) ? body : null;
  const { kind, variant, params, level, reason } = body;
  if (!oneOf(KINDS, kind) || !oneOf(allow[kind], variant) || !oneOf(REASONS, reason)) return null;
  if (!intIn(level, 1, 5)) return null;
  if (!Array.isArray(params) || !intIn(params.length, 1, allow.maxParams)) return null;
  if (!params.every((p) => intIn(p, allow.paramMin, allow.paramMax))) return null;
  return body;
}

/** The title, the dedupe key, and the body of the issue for a valid [report]. */
export function issueFor(r) {
  const common = [`- Version: \`${r.version}\``, `- Platform: \`${r.platform}\``, `- Language: \`${r.locale}\``];
  const footer = 'Sent from the app as a fixed report code: no free text, no personal data. ' +
    'Later reports of the same thing add a +1 reaction to this issue.';
  if (r.type === 'problem') {
    return {
      title: `Reported problem: ${r.category} ${r.version} ${r.platform}`,
      body: [`- Category: \`${r.category}\``, ...common, '', footer].join('\n'),
    };
  }
  const params = `[${r.params.map(String).join(',')}]`;
  return {
    title: `Suspect question: ${r.kind} ${r.variant} ${params} L${r.level}`,
    body: [
      `- Kind: \`${r.kind}\``,
      `- Variant: \`${r.variant}\``,
      `- Params: \`${params}\``,
      `- Level: \`${r.level}\``,
      `- Reason: \`${r.reason}\``,
      ...common,
      '',
      footer,
    ].join('\n'),
  };
}

// The body as text, or null when it is larger than MAX_BYTES. Stops reading
// there, so a large body is never held in memory.
async function readCapped(request) {
  if (Number(request.headers.get('Content-Length')) > MAX_BYTES) return null;
  if (!request.body) return '';
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BYTES) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  return new Blob(chunks).text();
}

class GitHubError extends Error {}

async function github({ token, signal }, path, init = {}) {
  let response;
  try {
    response = await fetch(`${REPOSITORY}${path}`, {
      ...init,
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'User-Agent': 'simple-math-tester-report',
        'X-GitHub-Api-Version': '2022-11-28',
        ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      },
      signal,
    });
    if (response.status !== 200 && response.status !== 201) throw new GitHubError();
    return await response.json();
  } catch {
    throw new GitHubError();
  }
}

// Open issues with [label], first page only: the limit is below a page, so
// a label at or past it already fills the page.
async function openIssues(auth, label) {
  const issues = await github(auth, `/issues?state=open&labels=${label}&per_page=100`);
  if (!Array.isArray(issues)) throw new GitHubError();
  return issues.filter((issue) => !issue.pull_request);
}

export async function onRequestPost({ request, env }) {
  if (!/^application\/json\s*(;\s*charset=utf-8\s*)?$/i.test(request.headers.get('Content-Type') ?? '')) {
    return invalid();
  }
  const text = await readCapped(request).catch(() => null);
  if (text === null) return invalid();
  let report;
  try {
    report = validate(JSON.parse(text));
  } catch {
    return invalid();
  }
  if (!report) return invalid();

  const token = env.GITHUB_REPORT_TOKEN;
  if (!token) return answer(500, 'Not configured.');
  // One deadline for all GitHub calls of this request.
  const auth = { token, signal: AbortSignal.timeout(TIMEOUT_MS) };

  const label = LABELS[report.type];
  const { title, body } = issueFor(report);
  try {
    const [questions, problems] = await Promise.all(
      [LABELS.question, LABELS.problem].map((l) => openIssues(auth, l)),
    );
    const existing = (label === LABELS.question ? questions : problems).find((i) => i.title === title);
    if (existing) {
      if (!Number.isInteger(existing.number)) throw new GitHubError();
      await github(auth, `/issues/${existing.number}/reactions`, {
        method: 'POST',
        body: JSON.stringify({ content: '+1' }),
      });
      return answer(200, 'Already reported.');
    }
    if (questions.length + problems.length >= OPEN_LIMIT) return answer(429, 'Too many reports.');
    const created = await github(auth, '/issues', {
      method: 'POST',
      body: JSON.stringify({ title, body, labels: [label] }),
    });
    // GitHub drops labels the token may not set; such an issue would escape
    // the dedupe and the limit, so it is closed and the setup is wrong.
    if (!created?.labels?.some((l) => l?.name === label)) {
      if (Number.isInteger(created?.number)) {
        await github(auth, `/issues/${created.number}`, {
          method: 'PATCH',
          body: JSON.stringify({ state: 'closed', state_reason: 'not_planned' }),
        });
      }
      return answer(500, 'Not configured.');
    }
    return answer(201, 'Reported.');
  } catch {
    return unavailable();
  }
}

// Every other method. Dispatching here keeps POST correct whichever handler
// Pages prefers when both are exported.
export function onRequest(context) {
  if (context.request.method === 'POST') return onRequestPost(context);
  return answer(405, 'Method not allowed.', { Allow: 'POST' });
}
