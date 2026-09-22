const json = (value, status = 200, headers = {}) =>
  new Response(JSON.stringify(value), {
    status,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  });

const html = (body, status = 200) =>
  new Response(body, {
    status,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'public, max-age=300',
      'x-content-type-options': 'nosniff',
      'referrer-policy': 'no-referrer',
      'content-security-policy':
        "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    },
  });

const page = (title, content) => `<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} — Gembala Kecil</title><style>
:root{color-scheme:light}*{box-sizing:border-box}body{margin:0;background:#f4fbff;color:#1e344e;font:17px/1.6 system-ui,-apple-system,sans-serif}main{max-width:760px;margin:0 auto;padding:40px 22px 72px}.brand{font-size:24px;font-weight:800;color:#2782b8}article{margin-top:24px;padding:28px;background:#fffdf7;border:1px solid #d6e8f2;border-radius:24px;box-shadow:0 12px 36px rgba(30,52,78,.09)}h1{font-size:clamp(30px,7vw,46px);line-height:1.08;margin:0 0 12px}h2{font-size:22px;margin:28px 0 6px}p,li{color:#425b70}a{color:#087f83;font-weight:700}label{display:block;font-weight:700;margin:18px 0 6px}input,textarea{width:100%;padding:13px 14px;border:1px solid #9fb9ca;border-radius:12px;font:inherit;background:white}button{margin-top:22px;padding:13px 22px;border:0;border-radius:999px;background:#1d9ea2;color:white;font:inherit;font-weight:800;cursor:pointer}.fine{font-size:14px;color:#657b8c}.check{display:flex;gap:10px;align-items:flex-start}.check input{width:auto;margin-top:7px}.hidden{position:absolute;left:-10000px}
</style></head><body><main><div class="brand">Gembala Kecil</div><article>${content}</article></main></body></html>`;

const privacyPage = page(
  'Kebijakan Privasi',
  `<h1>Kebijakan Privasi</h1><p class="fine">Terakhir diperbarui: 22 September 2026</p>
  <p>Gembala Kecil adalah aplikasi cerita Alkitab untuk anak. Anak tetap dapat membaca konten gratis tanpa membuat akun.</p>
  <h2>Data yang diproses</h2><ul>
  <li>Nama panggilan anak dan progres membaca disimpan lokal. Jika orang tua memilih membuat akun, data tersebut dapat disinkronkan ke Firebase.</li>
  <li>Akun orang tua dapat memproses alamat email, nama tampilan, ID akun, profil anak, progres membaca, dan status hak akses pembelian.</li>
  <li>Google Sign-In bersifat opsional. Autentikasi dikelola oleh Firebase Authentication dan Google.</li>
  <li>Ilustrasi, audio, serta katalog cerita diunduh dari Cloudflare. Seperti layanan internet pada umumnya, metadata teknis seperti alamat IP dan jenis perangkat dapat diproses untuk keamanan dan pengiriman konten.</li></ul>
  <h2>Penggunaan data</h2><p>Data digunakan untuk menjalankan akun orang tua, menyinkronkan profil dan progres, memulihkan pembelian, mengirim verifikasi akun, serta menyediakan konten. Kami tidak menjual data pribadi, tidak menampilkan iklan, dan tidak meminta lokasi presisi, kamera, atau mikrofon.</p>
  <h2>Penyimpanan dan penghapusan</h2><p>Data lokal tetap ada sampai aplikasi dihapus atau datanya dibersihkan. Data akun disimpan selama akun aktif atau selama diperlukan untuk kewajiban hukum dan transaksi. Orang tua dapat <a href="/account-deletion">meminta penghapusan akun dan data</a>. Data yang wajib dipertahankan untuk keamanan, pencegahan penipuan, atau kewajiban transaksi dapat disimpan sesuai hukum.</p>
  <h2>Anak dan kontrol orang tua</h2><p>Pembuatan akun, sinkronisasi, dan pembelian ditujukan untuk orang tua. Nama panggilan anak tidak harus berupa nama lengkap.</p>
  <h2>Layanan pihak ketiga</h2><p>Aplikasi menggunakan Google Firebase untuk autentikasi dan penyimpanan data akun, Cloudflare untuk distribusi konten, serta Google Play untuk distribusi aplikasi dan pembelian.</p>
  <h2>Kontak</h2><p>Untuk pertanyaan tentang privasi atau data, silakan <a href="/contact">hubungi tim Gembala Kecil</a>. Permintaan penghapusan akun harus dikirim melalui <a href="/account-deletion">formulir penghapusan</a>.</p>
  <h2>Perubahan</h2><p>Kebijakan ini dapat diperbarui ketika fitur berubah. Tanggal terbaru selalu ditampilkan di halaman ini.</p>`,
);

const deletionPage = (message = '') => page(
  'Penghapusan Akun',
  `<h1>Hapus akun Gembala Kecil</h1><p>Formulir ini untuk orang tua yang ingin menghapus akun dan data terkait tanpa harus membuka aplikasi.</p>
  ${message}
  <form method="post" action="/account-deletion">
  <label for="email">Email akun orang tua</label><input id="email" name="email" type="email" autocomplete="email" required maxlength="254">
  <label for="note">Catatan (opsional)</label><textarea id="note" name="note" rows="3" maxlength="500" placeholder="Contoh: nama profil anak yang terkait"></textarea>
  <label class="hidden" for="website">Jangan isi kolom ini</label><input class="hidden" id="website" name="website" tabindex="-1" autocomplete="off">
  <label class="check"><input name="confirm" type="checkbox" value="yes" required><span>Saya adalah pemilik akun/orang tua dan meminta akun beserta profil anak dan progres membaca terkait dihapus.</span></label>
  <button type="submit">Kirim permintaan penghapusan</button></form>
  <h2>Apa yang dihapus?</h2><p>Akun autentikasi orang tua, profil anak, dan progres membaca di cloud. Data pembelian yang wajib disimpan untuk kewajiban transaksi atau pencegahan penipuan dapat dipertahankan sesuai hukum. Konten yang sudah diunduh ke perangkat dapat dihapus dengan membersihkan data atau menghapus aplikasi.</p>
  <p class="fine">Permintaan diverifikasi melalui email akun sebelum diproses. Simpan halaman konfirmasi setelah mengirim formulir.</p>`,
);

const contactPage = (message = '') => page(
  'Kontak Privasi',
  `<h1>Hubungi Gembala Kecil</h1><p>Gunakan formulir ini untuk pertanyaan tentang privasi, data, atau keamanan akun.</p>${message}
  <form method="post" action="/contact">
  <label for="email">Email orang tua</label><input id="email" name="email" type="email" autocomplete="email" required maxlength="254">
  <label for="message">Pesan</label><textarea id="message" name="message" rows="5" required maxlength="1000"></textarea>
  <label class="hidden" for="website">Jangan isi kolom ini</label><input class="hidden" id="website" name="website" tabindex="-1" autocomplete="off">
  <button type="submit">Kirim pesan</button></form>
  <p class="fine">Jangan kirim password atau informasi pembayaran melalui formulir ini.</p>`,
);

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;',
  })[character]);
}

function corsHeaders(request, env) {
  const origin = request.headers.get('origin');
  const allowed = String(env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  return origin && allowed.includes(origin)
    ? {
        'access-control-allow-origin': origin,
        'access-control-allow-methods': 'GET, HEAD, POST, PUT, DELETE, OPTIONS',
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
  const rangeRequested = request.headers.has('range');
  const object = rangeRequested
    ? await env.CONTENT.get(key, {range: request.headers})
    : await env.CONTENT.get(key);
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
  if (rangeRequested && object.range && 'offset' in object.range) {
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
    if (request.method === 'GET' && url.pathname === '/privacy') return html(privacyPage);
    if (request.method === 'GET' && url.pathname === '/account-deletion') return html(deletionPage());
    if (request.method === 'GET' && url.pathname === '/contact') return html(contactPage());

    if (request.method === 'POST' && url.pathname === '/contact') {
      const contentLength = Number(request.headers.get('content-length') || 0);
      if (contentLength > 16_384) return html(contactPage('<p>Pesan terlalu besar.</p>'), 413);
      const form = await request.formData();
      const email = String(form.get('email') || '').trim().toLowerCase();
      const message = String(form.get('message') || '').trim().slice(0, 1000);
      const honeypot = String(form.get('website') || '').trim();
      if (honeypot) return html(contactPage('<p>Pesan diterima.</p>'));
      if (!message || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return html(contactPage('<p style="color:#a33"><strong>Periksa email dan pesan, lalu coba lagi.</strong></p>'), 400);
      }
      const requestId = crypto.randomUUID();
      await env.CONTENT.put(`private/contact-requests/${requestId}.json`, JSON.stringify({
        requestId,
        email,
        message,
        requestedAt: new Date().toISOString(),
        status: 'pending',
      }), {httpMetadata: {contentType: 'application/json; charset=utf-8'}});
      return html(page('Pesan diterima', `<h1>Pesan diterima</h1><p>Terima kasih. Nomor pesan: <strong>${requestId}</strong></p><p><a href="/privacy">Kembali ke Kebijakan Privasi</a></p>`));
    }

    if (request.method === 'POST' && url.pathname === '/account-deletion') {
      const contentLength = Number(request.headers.get('content-length') || 0);
      if (contentLength > 16_384) return html(deletionPage('<p>Permintaan terlalu besar.</p>'), 413);
      const form = await request.formData();
      const email = String(form.get('email') || '').trim().toLowerCase();
      const note = String(form.get('note') || '').trim().slice(0, 500);
      const honeypot = String(form.get('website') || '').trim();
      const confirmed = form.get('confirm') === 'yes';
      if (honeypot) return html(deletionPage('<p>Permintaan diterima.</p>'));
      if (!confirmed || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return html(deletionPage('<p style="color:#a33"><strong>Periksa email dan konfirmasi, lalu coba lagi.</strong></p>'), 400);
      }
      const requestId = crypto.randomUUID();
      await env.CONTENT.put(`private/deletion-requests/${requestId}.json`, JSON.stringify({
        requestId,
        email,
        note,
        requestedAt: new Date().toISOString(),
        status: 'pending',
      }), {httpMetadata: {contentType: 'application/json; charset=utf-8'}});
      return html(page('Permintaan diterima', `<h1>Permintaan diterima</h1><p>Kami akan memverifikasi permintaan untuk <strong>${escapeHtml(email)}</strong> sebelum menghapus akun dan data terkait.</p><p>Nomor permintaan: <strong>${requestId}</strong></p><p><a href="/privacy">Kembali ke Kebijakan Privasi</a></p>`));
    }

    if ((request.method === 'GET' || request.method === 'HEAD') && url.pathname === '/v1/catalog') {
      return serveObject(request, env, 'catalog.json', cors);
    }

    if ((request.method === 'GET' || request.method === 'HEAD') && url.pathname.startsWith('/v1/assets/')) {
      const key = safeKey(url.pathname.slice('/v1/assets/'.length));
      return key && !key.startsWith('private/')
        ? serveObject(request, env, key, cors)
        : json({error: 'Invalid key'}, 400, cors);
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
