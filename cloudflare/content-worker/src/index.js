const json = (value, status = 200, headers = {}) =>
  new Response(JSON.stringify(value), {
    status,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  });

function corsHeaders(request, env) {
  const origin = request.headers.get('origin');
  const allowed = String(env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  return origin && allowed.includes(origin)
    ? {
        'access-control-allow-origin': origin,
        'access-control-allow-methods': 'GET, HEAD, PUT, DELETE, OPTIONS',
        'access-control-allow-headers': 'authorization, content-type, range',
        'access-control-expose-headers': 'content-length, content-range, etag',
        vary: 'Origin',
      }
    : {};
}

function isAdmin(request, env) {
  const supplied = request.headers.get('authorization') || '';
  return Boolean(env.ADMIN_TOKEN) && supplied === `Bearer ${env.ADMIN_TOKEN}`;
}

function safeKey(value) {
  try {
    const key = decodeURIComponent(value || '').replace(/^\/+/, '');
    if (!key || key.includes('..') || key.includes('\\')) return null;
    return key;
  } catch {
    return null;
  }
}

async function serveObject(request, env, key, cors) {
  const object = await env.CONTENT.get(key, {range: request.headers});
  if (!object) return json({error: 'Not found'}, 404, cors);

  const headers = new Headers(cors);
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('accept-ranges', 'bytes');
  headers.set(
    'cache-control',
    key === 'catalog.json' ? 'public, max-age=60' : 'public, max-age=31536000, immutable',
  );

  let status = 200;
  if (object.range && 'offset' in object.range) {
    const start = object.range.offset;
    const end = start + object.range.length - 1;
    headers.set('content-range', `bytes ${start}-${end}/${object.size}`);
    status = 206;
  }
  return new Response(request.method === 'HEAD' ? null : object.body, {status, headers});
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = corsHeaders(request, env);

    if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers: cors});
    if (url.pathname === '/health') return json({ok: true}, 200, cors);

    if ((request.method === 'GET' || request.method === 'HEAD') && url.pathname === '/v1/catalog') {
      return serveObject(request, env, 'catalog.json', cors);
    }

    if ((request.method === 'GET' || request.method === 'HEAD') && url.pathname.startsWith('/v1/assets/')) {
      const key = safeKey(url.pathname.slice('/v1/assets/'.length));
      return key ? serveObject(request, env, key, cors) : json({error: 'Invalid key'}, 400, cors);
    }

    if (url.pathname.startsWith('/v1/admin/')) {
      if (!isAdmin(request, env)) return json({error: 'Unauthorized'}, 401, cors);

      if (request.method === 'PUT' && url.pathname === '/v1/admin/catalog') {
        const catalog = await request.json();
        if (catalog?.schemaVersion !== 1 || !Array.isArray(catalog.stories) || !Array.isArray(catalog.verses)) {
          return json({error: 'Invalid catalog'}, 400, cors);
        }
        await env.CONTENT.put('catalog.json', JSON.stringify(catalog, null, 2), {
          httpMetadata: {contentType: 'application/json; charset=utf-8'},
        });
        return json({ok: true}, 200, cors);
      }

      const prefix = '/v1/admin/assets/';
      if (url.pathname.startsWith(prefix)) {
        const key = safeKey(url.pathname.slice(prefix.length));
        if (!key) return json({error: 'Invalid key'}, 400, cors);
        if (request.method === 'PUT' && request.body) {
          await env.CONTENT.put(key, request.body, {
            httpMetadata: {
              contentType: request.headers.get('content-type') || 'application/octet-stream',
            },
          });
          return json({ok: true, key}, 201, cors);
        }
        if (request.method === 'DELETE') {
          await env.CONTENT.delete(key);
          return new Response(null, {status: 204, headers: cors});
        }
      }
    }

    return json({error: 'Not found'}, 404, cors);
  },
};
