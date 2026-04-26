export interface Env {
  MYFIT_LINKS: KVNamespace;
  TELEGRAM_BOT_TOKEN: string;
  APP_API_KEY?: string;
  /** Resend: https://resend.com — для POST /send-email */
  RESEND_API_KEY?: string;
  /** Напр. "My Pro Health <onboarding@resend.dev>" или свой домен в Resend */
  RESEND_FROM?: string;
}

type TelegramUpdate = {
  message?: {
    chat?: { id: number };
    text?: string;
  };
};

function jsonResponse(body: unknown, init?: ResponseInit): Response {
  return new Response(JSON.stringify(body), {
    headers: { 'content-type': 'application/json; charset=utf-8' },
    ...init,
  });
}

function badRequest(message: string, status = 400): Response {
  return jsonResponse({ ok: false, error: message }, { status });
}

function requireApiKey(req: Request, env: Env): Response | null {
  if (!env.APP_API_KEY) return null; // disabled
  const key = req.headers.get('x-api-key');
  if (key !== env.APP_API_KEY) return badRequest('unauthorized', 401);
  return null;
}

function extractStartCode(text: string): string | null {
  // Accept: "/start ABC123" or "ABC123"
  const trimmed = text.trim();
  const m = /^\/start(?:\s+(.+))?$/i.exec(trimmed);
  const candidate = (m ? m[1] : trimmed)?.trim();
  if (!candidate) return null;
  const code = candidate.replace(/[^a-zA-Z0-9_-]/g, '');
  if (code.length < 6 || code.length > 32) return null;
  return code;
}

async function telegramSendMessage(token: string, chatId: number, text: string) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      disable_web_page_preview: true,
    }),
  });
  const data = await res.json().catch(() => null);
  return { res, data };
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    // CORS for Flutter app
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET,POST,OPTIONS',
          'access-control-allow-headers': 'content-type,x-api-key',
        },
      });
    }

    const corsHeaders = { 'access-control-allow-origin': '*' };

    if (url.pathname === '/telegram/webhook' && req.method === 'POST') {
      const update = (await req.json().catch(() => null)) as TelegramUpdate | null;
      const text = update?.message?.text ?? '';
      const chatId = update?.message?.chat?.id;

      if (!chatId) return jsonResponse({ ok: true }, { headers: corsHeaders });

      const code = extractStartCode(text);
      if (!code) return jsonResponse({ ok: true }, { headers: corsHeaders });

      // store mapping for 24h
      await env.MYFIT_LINKS.put(`code:${code}`, String(chatId), {
        expirationTtl: 60 * 60 * 24,
      });

      // confirmation to user
      await telegramSendMessage(
        env.TELEGRAM_BOT_TOKEN,
        chatId,
        'Готово. Привязка выполнена, можно возвращаться в приложение.',
      );

      return jsonResponse({ ok: true }, { headers: corsHeaders });
    }

    if (url.pathname === '/link-status' && req.method === 'GET') {
      const deny = requireApiKey(req, env);
      if (deny) return deny;

      const code = url.searchParams.get('code')?.trim() ?? '';
      if (!code) return badRequest('missing code');

      const chatId = await env.MYFIT_LINKS.get(`code:${code}`);
      return jsonResponse(
        { ok: true, linked: Boolean(chatId) },
        { headers: corsHeaders },
      );
    }

    if (url.pathname === '/send-email' && req.method === 'POST') {
      const deny = requireApiKey(req, env);
      if (deny) return deny;

      if (!env.RESEND_API_KEY) {
        return jsonResponse(
          { ok: false, error: 'email_not_configured' },
          { status: 501, headers: corsHeaders },
        );
      }

      const body = (await req.json().catch(() => null)) as
        | { to?: string; text?: string; subject?: string }
        | null;
      const to = body?.to?.trim() ?? '';
      const text = body?.text ?? '';
      const subject = body?.subject?.trim() || 'План питания';
      if (!to) return badRequest('missing to');
      if (!text) return badRequest('missing text');
      const re = /.+@.+\..+/i;
      if (!re.test(to) || to.length > 256) {
        return badRequest('invalid email', 400);
      }

      const from =
        env.RESEND_FROM?.trim() || 'My Pro Health <onboarding@resend.dev>';

      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${env.RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from,
          to: [to],
          subject,
          text: text.length > 90000 ? text.slice(0, 90000) + '\n…' : text,
        }),
      });
      const raw = await r.text();
      if (!r.ok) {
        return jsonResponse(
          { ok: false, error: 'resend failed', details: raw },
          { status: 502, headers: corsHeaders },
        );
      }
      return jsonResponse({ ok: true }, { headers: corsHeaders });
    }

    if (url.pathname === '/send' && req.method === 'POST') {
      const deny = requireApiKey(req, env);
      if (deny) return deny;

      const body = (await req.json().catch(() => null)) as
        | { code?: string; text?: string }
        | null;
      const code = body?.code?.trim() ?? '';
      const text = body?.text ?? '';
      if (!code) return badRequest('missing code');
      if (!text) return badRequest('missing text');

      const chatIdRaw = await env.MYFIT_LINKS.get(`code:${code}`);
      if (!chatIdRaw) return badRequest('code not linked', 409);

      const chatId = Number(chatIdRaw);
      if (!Number.isFinite(chatId)) return badRequest('invalid chat id', 500);

      const { res, data } = await telegramSendMessage(
        env.TELEGRAM_BOT_TOKEN,
        chatId,
        text.slice(0, 3500), // safe limit
      );

      if (!res.ok) {
        return jsonResponse(
          { ok: false, error: 'telegram send failed', details: data },
          { status: 502, headers: corsHeaders },
        );
      }

      return jsonResponse({ ok: true }, { headers: corsHeaders });
    }

    return new Response('Not found', { status: 404, headers: corsHeaders });
  },
};

