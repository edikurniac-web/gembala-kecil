import assert from 'node:assert/strict';
import test from 'node:test';

import worker from '../src/index.js';

function environment() {
  const objects = new Map();
  return {
    ADMIN_TOKEN: 'test-secret',
    ALLOWED_ORIGINS: 'http://127.0.0.1:57182',
    CONTENT: {
      async put(key, body, options = {}) {
        const bytes = new TextEncoder().encode(
          typeof body === 'string' ? body : await new Response(body).text(),
        );
        objects.set(key, {bytes, options});
      },
      async get(key) {
        const stored = objects.get(key);
        if (!stored) return null;
        return {
          body: stored.bytes,
          size: stored.bytes.length,
          httpEtag: '"test-etag"',
          range: null,
          writeHttpMetadata(headers) {
            headers.set(
              'content-type',
              stored.options.httpMetadata?.contentType || 'application/octet-stream',
            );
          },
        };
      },
      async delete(key) {
        objects.delete(key);
      },
    },
  };
}

test('health endpoint and CORS are available to the app origin', async () => {
  const response = await worker.fetch(
    new Request('https://content.example/health', {
      headers: {origin: 'http://127.0.0.1:57182'},
    }),
    environment(),
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), 'http://127.0.0.1:57182');
  assert.deepEqual(await response.json(), {ok: true});
});

test('catalog writes require the admin secret and become publicly readable', async () => {
  const env = environment();
  const catalog = {schemaVersion: 1, stories: [], verses: []};
  const endpoint = 'https://content.example/v1/admin/catalog';

  const denied = await worker.fetch(
    new Request(endpoint, {method: 'PUT', body: JSON.stringify(catalog)}),
    env,
  );
  assert.equal(denied.status, 401);

  const saved = await worker.fetch(
    new Request(endpoint, {
      method: 'PUT',
      headers: {authorization: 'Bearer test-secret'},
      body: JSON.stringify(catalog),
    }),
    env,
  );
  assert.equal(saved.status, 200);

  const fetched = await worker.fetch(
    new Request('https://content.example/v1/catalog'),
    env,
  );
  assert.equal(fetched.status, 200);
  assert.deepEqual(await fetched.json(), catalog);
});

test('unsafe object keys are rejected', async () => {
  const response = await worker.fetch(
    new Request('https://content.example/v1/assets/%2E%2E%2Fsecret'),
    environment(),
  );
  assert.equal(response.status, 400);
});
