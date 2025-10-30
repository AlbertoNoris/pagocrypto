// /api/bscscan-proxy.ts  (Edge Runtime)
// Proxy for Etherscan V2 API to hide API key server-side
// Etherscan V2 API supports multiple chains (BSC via chainId 56, Ethereum via chainId 1, etc.)
declare const process: { env: Record<string, string | undefined> };

export const config = { runtime: 'edge' };

function cors(origin: string): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin'
  };
}

// --- Telegram helpers (optional) ---
const TG_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const TG_CHAT_ID = process.env.TELEGRAM_CHAT_ID;
const PROJECT = process.env.APP_PROJECT || 'Pagocrypto';

function escapeHtml(s: string) {
  return s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
function redactSecrets(v: unknown): unknown {
  if (typeof v === 'string' && v.length > 24) return v.slice(0, 6) + '…' + v.slice(-4);
  if (Array.isArray(v)) return v.map(redactSecrets);
  if (v && typeof v === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
      if (k.toLowerCase().includes('key') || k.toLowerCase().includes('token') || k.toLowerCase().includes('secret')) out[k] = '[redacted]';
      else out[k] = redactSecrets(val);
    }
    return out;
  }
  return v;
}
function buildMessage(params: {
  title: string; brief: string; detail: string; source?: string; solution?: string; meta?: Record<string, unknown>;
}) {
  const { title, brief, detail, source, solution, meta } = params;
  const lines: string[] = [];
  lines.push(`<b>${escapeHtml(`${PROJECT} · ${title}`)}</b>`);
  lines.push(`<b>Brief:</b> ${escapeHtml(brief)}`);
  lines.push(`<b>Details:</b>\n${escapeHtml(detail)}`);
  if (source) lines.push(`<b>Source:</b> ${escapeHtml(source)}`);
  if (solution) lines.push(`<b>Proposed fix:</b> ${escapeHtml(solution)}`);
  if (meta && Object.keys(meta).length) {
    const pretty = escapeHtml(JSON.stringify(redactSecrets(meta), null, 2));
    lines.push(`<b>Meta:</b>\n<pre>${pretty}</pre>`);
  }
  return lines.join('\n\n');
}
async function sendTelegram(text: string) {
  if (!TG_TOKEN || !TG_CHAT_ID) return;
  const url = `https://api.telegram.org/bot${TG_TOKEN}/sendMessage`;
  const payload = { chat_id: TG_CHAT_ID, text, parse_mode: 'HTML', disable_web_page_preview: true };
  try {
    const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    if (!r.ok) console.warn('Telegram send failed', await r.text());
  } catch { /* ignore */ }
}

// --- Error helper with optional alerting ---
async function respondError(
  req: Request,
  status: number,
  publicBody: Record<string, unknown>,
  bug?: { title: string; brief: string; detail: string; source?: string; solution?: string; meta?: Record<string, unknown>; cause?: unknown; }
): Promise<Response> {
  const serious = status >= 500 || (bug && /config|upstream|invalid json from upstream/i.test(bug.title));
  if (serious && bug) {
    const text = buildMessage({
      title: bug.title, brief: bug.brief, detail: bug.detail, source: bug.source,
      solution: bug.solution, meta: { status, url: req.url, method: req.method, ...(bug.meta ?? {}) }
    });
    await sendTelegram(text);
  }
  return new Response(JSON.stringify(publicBody), { status, headers: { ...cors(req.headers.get('origin') || '*'), 'Content-Type': 'application/json' } });
}

export default async function handler(req: Request): Promise<Response> {
  const origin = req.headers.get('origin') || '*';

  if (req.method === 'OPTIONS') return new Response(null, { headers: cors(origin) });
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405, headers: cors(origin) });

  let body: any;
  try { body = await req.json(); }
  catch { return new Response('Invalid JSON', { status: 400, headers: cors(origin) }); }

  // Extract parameters from client request
  const { chainId, queryParams } = body;

  if (!chainId || typeof chainId !== 'number') {
    return respondError(req, 400, { error: 'Missing or invalid chainId' });
  }

  if (!queryParams || typeof queryParams !== 'object') {
    return respondError(req, 400, { error: 'Missing or invalid queryParams' });
  }

  // Get Etherscan API key from environment
  const apiKey = process.env.ETHERSCAN_API_KEY;

  if (!apiKey) {
    return respondError(req, 500, { error: 'API key not configured on server' }, {
      title: 'Configuration error: API key missing',
      brief: 'No Etherscan API key configured',
      detail: 'ETHERSCAN_API_KEY environment variable not set',
      source: '/api/bscscan-proxy.ts:getApiKey',
      solution: 'Set ETHERSCAN_API_KEY in Vercel environment variables.',
      meta: { chainId }
    });
  }

  // Etherscan V2 API supports multiple chains (BSC, Ethereum, etc.) via chainId parameter
  const apiBaseUrl = 'https://api.etherscan.io';

  // Build the upstream URL with client params + server API key
  const upstreamParams = {
    ...queryParams,
    apikey: apiKey,
    chainid: chainId.toString(),
  };

  const upstreamUrl = new URL(`${apiBaseUrl}/v2/api`);
  Object.entries(upstreamParams).forEach(([key, value]) => {
    upstreamUrl.searchParams.append(key, String(value));
  });

  // Call upstream Etherscan API
  let upstream: Response;
  try {
    upstream = await fetch(upstreamUrl.toString(), {
      method: 'GET',
      headers: { 'Accept': 'application/json' },
    });
  } catch (e) {
    return respondError(req, 502, { error: 'Failed to reach upstream API' }, {
      title: 'Upstream request failed',
      brief: 'Network error calling Etherscan API.',
      detail: 'fetch(upstream) threw before response.',
      source: '/api/bscscan-proxy.ts:fetch(upstream)',
      solution: 'Check egress and Etherscan availability.',
      meta: { upstreamUrl: upstreamUrl.toString(), queryParams: redactSecrets(queryParams) },
      cause: e
    });
  }

  if (!upstream.ok) {
    const errorText = await upstream.text();
    return respondError(req, upstream.status, { error: errorText }, {
      title: `Upstream HTTP ${upstream.status}`,
      brief: 'Etherscan API returned non-2xx.',
      detail: `Body: ${errorText.slice(0, 2000)}`,
      source: '/api/bscscan-proxy.ts:fetch(upstream)',
      solution: 'Inspect query params and API key validity.',
      meta: { upstreamStatus: upstream.status, headers: Object.fromEntries(upstream.headers.entries()) }
    });
  }

  // Parse and return the upstream JSON response
  let upstreamJson: any;
  try { upstreamJson = await upstream.json(); }
  catch (e) {
    return respondError(req, 502, { error: 'Upstream API returned invalid JSON' }, {
      title: 'Invalid JSON from upstream',
      brief: 'Parsing upstream JSON failed.',
      detail: 'Expected valid JSON from Etherscan.',
      source: '/api/bscscan-proxy.ts:upstream.json',
      solution: 'Check upstream content-type and response format.',
      meta: { upstreamContentType: upstream.headers.get('content-type') },
      cause: e
    });
  }

  // Return the upstream response as-is
  return new Response(JSON.stringify(upstreamJson), {
    status: 200,
    headers: {
      ...cors(origin),
      'Content-Type': 'application/json',
      'Cache-Control': upstream.headers.get('Cache-Control') || 'no-cache',
    }
  });
}
