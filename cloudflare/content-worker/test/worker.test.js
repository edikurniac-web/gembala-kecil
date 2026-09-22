import assert from 'node:assert/strict';
import test from 'node:test';

import worker from '../src/index.js';

function environment() {
  const objects = new Map();
  return {
    objects,
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
          // R2 can expose full-object range metadata even when the request did
          // not include a Range header. HTTP status must follow the request.
          range: {offset: 0, length: stored.bytes.length},
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

test('privacy and deletion pages are publicly available', async () => {
  const env = environment();
  const privacy = await worker.fetch(
    new Request('https://content.example/privacy'),
    env,
  );
  assert.equal(privacy.status, 200);
  assert.match(await privacy.text(), /Kebijakan Privasi/);

  const deletion = await worker.fetch(
    new Request('https://content.example/account-deletion'),
    env,
  );
  assert.equal(deletion.status, 200);
  assert.match(await deletion.text(), /Kirim permintaan penghapusan/);

  const contact = await worker.fetch(
    new Request('https://content.example/contact'),
    env,
  );
  assert.equal(contact.status, 200);
  assert.match(await contact.text(), /Hubungi Gembala Kecil/);
});

test('account deletion requests are stored privately', async () => {
  const env = environment();
  const form = new FormData();
  form.set('email', 'parent@example.com');
  form.set('confirm', 'yes');
  const response = await worker.fetch(
    new Request('https://content.example/account-deletion', {
      method: 'POST',
      body: form,
    }),
    env,
  );
  assert.equal(response.status, 200);
  assert.match(await response.text(), /Permintaan diterima/);
  const storedKey = [...env.objects.keys()].find((key) =>
    key.startsWith('private/deletion-requests/'),
  );
  assert.ok(storedKey);

  const leaked = await worker.fetch(
    new Request(`https://content.example/v1/assets/${storedKey}`),
    env,
  );
  assert.equal(leaked.status, 400);
});
