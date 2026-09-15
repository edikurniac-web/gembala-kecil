const http = require('http');
const fs = require('fs');
const path = require('path');
const {randomUUID} = require('crypto');
const {execFile} = require('child_process');
const {promisify} = require('util');

const project = path.resolve(process.env.GEMBALA_PROJECT_ROOT || path.join(__dirname, '..'));
const port = Number(process.env.GEMBALA_BACKOFFICE_PORT || 57183);
const content = path.join(project, 'assets', 'content');
const catalogFile = path.join(content, 'catalog.json');
const maxBody = 120 * 1024 * 1024;
const runFile = promisify(execFile);
const json = (res, status, value) => {
  res.writeHead(status, {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store'});
  res.end(JSON.stringify(value));
};
const fail = (message) => { throw new Error(message); };
const slug = (value) => String(value || '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 64);
const validId = (value) => /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value);
const wordCount = (value) => value.trim().split(/\s+/).length;
const readCatalog = () => JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
const note = 'Perubahan tersimpan. Jalankan flutter build web --no-pub untuk memperbarui preview.';
function assetPath(asset, id) {
  if (!asset) return null;
  const prefix = `assets/content/${id}-`;
  if (typeof asset !== 'string' || !asset.startsWith(prefix) || asset.includes('..') || asset.includes('\\')) fail('Path asset tidak aman.');
  const target = path.join(content, path.basename(asset));
  if (path.dirname(target) !== content) fail('Path asset di luar folder konten.');
  return target;
}
function storyAssets(item) {
  return [item.cover, item.audio, item.timingAsset, ...item.pages.map(page => page.image)].filter(Boolean);
}
function commitCatalog(catalog) {
  const temporary = `${catalogFile}.${randomUUID()}.tmp`;
  try {
    fs.writeFileSync(temporary, JSON.stringify(catalog, null, 2) + '\n', {flag: 'wx'});
    fs.renameSync(temporary, catalogFile);
  } finally {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
  }
}
function archiveAssets(assets, id) {
  if (!assets.length) return null;
  const directory = path.join(content, '.trash', `${id}-${Date.now()}-${randomUUID()}`);
  fs.mkdirSync(directory, {recursive: true});
  const moved = [];
  try {
    assets.forEach(asset => {
      const original = assetPath(asset, id);
      if (!fs.existsSync(original)) return;
      const archived = path.join(directory, path.basename(original));
      fs.renameSync(original, archived);
      moved.push({original, archived});
    });
  } catch (error) {
    moved.reverse().forEach(file => fs.renameSync(file.archived, file.original));
    throw error;
  }
  return {directory, moved};
}

function decodeFile(data, kind, label) {
  if (!data || typeof data !== 'object' || typeof data.base64 !== 'string') fail(`${label} belum dipilih.`);
  const buffer = Buffer.from(data.base64, 'base64');
  if (!buffer.length) fail(`${label} kosong.`);
  if (kind === 'png' && (buffer.length < 24 || buffer.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a')) fail(`${label} harus PNG.`);
  if (kind === 'png' && buffer.readUInt32BE(16) !== buffer.readUInt32BE(20)) fail(`${label} harus persegi (1:1).`);
  if (kind === 'mp3' && buffer.subarray(0, 3).toString() !== 'ID3' && buffer[0] !== 0xff) fail(`${label} harus MP3.`);
  return buffer;
}

function validateTiming(timing, texts) {
  if (!timing) return null;
  if (!Number.isInteger(timing.audioDurationMs) || timing.audioDurationMs <= 0) fail('Durasi timing tidak valid.');
  if (!Array.isArray(timing.pages) || timing.pages.length !== texts.length) fail('Jumlah halaman timing harus sama dengan teks.');
  let previous = -1;
  timing.pages.forEach((page, index) => {
    if (!Number.isInteger(page.startMs) || !Number.isInteger(page.endMs) || page.startMs < previous || page.endMs <= page.startMs) fail(`Rentang timing halaman ${index + 1} tidak valid.`);
    if (!Array.isArray(page.wordStartsMs) || page.wordStartsMs.length !== wordCount(texts[index])) fail(`Jumlah timestamp kata halaman ${index + 1} tidak cocok.`);
    if (page.wordStartsMs.some((time, position) => !Number.isInteger(time) || time < page.startMs || time >= page.endMs || (position && time < page.wordStartsMs[position - 1]))) fail(`Timestamp kata halaman ${index + 1} tidak urut.`);
    previous = page.endMs;
  });
  if (previous > timing.audioDurationMs) fail('Timing melebihi durasi audio.');
  return timing;
}

function receive(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let length = 0;
    req.on('data', chunk => {
      length += chunk.length;
      if (length > maxBody) { reject(new Error('Paket terlalu besar (maksimum 120 MB).')); req.destroy(); return; }
      chunks.push(chunk);
    });
    req.on('end', () => { try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch { reject(new Error('Format JSON tidak valid.')); } });
    req.on('error', reject);
  });
}

function saveUpload(type, input) {
  const catalog = readCatalog();
  const id = slug(input.id || input.title);
  if (!validId(id)) fail('Judul/ID tidak valid.');
  if ([...catalog.stories, ...catalog.verses].some(item => item.id === id)) fail(`ID ${id} sudah ada. Gunakan ID baru.`);
  const title = String(input.title || '').trim();
  const reference = String(input.reference || '').trim();
  if (!title || !reference) fail('Judul dan referensi wajib diisi.');
  const outputs = [];
  const add = (suffix, buffer) => {
    const name = `${id}-${suffix}`;
    const target = path.join(content, name);
    if (fs.existsSync(target)) fail(`Asset ${name} sudah ada.`);
    outputs.push({name, target, buffer});
    return `assets/content/${name}`;
  };
  let item;
  if (type === 'story') {
    const texts = String(input.pageTexts || '').split(/^---+$/m).map(value => value.trim()).filter(Boolean);
    if (!texts.length || texts.length > 50) fail('Cerita perlu 1–50 halaman teks yang dipisahkan baris --- .');
    if (!Array.isArray(input.pageImages) || input.pageImages.length !== texts.length) fail('Jumlah gambar harus sama dengan jumlah halaman teks.');
    const cover = add('cover.png', decodeFile(input.cover, 'png', 'Cover'));
    const pages = texts.map((text, index) => ({text, image: add(`page-${index + 1}.png`, decodeFile(input.pageImages[index], 'png', `Gambar halaman ${index + 1}`))}));
    const audio = input.audio ? add('narration.mp3', decodeFile(input.audio, 'mp3', 'Narasi')) : null;
    const timing = validateTiming(input.timing, texts);
    if (timing && !audio) fail('File timing memerlukan narasi MP3.');
    if (audio && !timing) fail('Narasi MP3 memerlukan timing kata JSON agar highlight akurat.');
    const timingAsset = timing ? add('timing.json', Buffer.from(JSON.stringify(timing, null, 2) + '\n')) : null;
    item = {id, title, reference, summary: String(input.summary || '').trim(), cover, audio, timingAsset, pages, isFree: input.isFree !== false};
    catalog.stories.push(item);
  } else {
    const text = String(input.text || '').trim();
    if (!text) fail('Teks ayat wajib diisi.');
    const image = input.image ? add('verse.png', decodeFile(input.image, 'png', 'Gambar ayat')) : null;
    const audio = input.audio ? add('verse.mp3', decodeFile(input.audio, 'mp3', 'Audio ayat')) : null;
    item = {id, title, reference, text, image, audio};
    catalog.verses.push(item);
  }
  fs.mkdirSync(content, {recursive: true});
  const written = [];
  const temporary = `${catalogFile}.${randomUUID()}.tmp`;
  try {
    outputs.forEach(file => { fs.writeFileSync(file.target, file.buffer, {flag: 'wx'}); written.push(file.target); });
    fs.writeFileSync(temporary, JSON.stringify(catalog, null, 2) + '\n', {flag: 'wx'});
    fs.renameSync(temporary, catalogFile);
  } catch (error) {
    try { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); } catch {}
    written.forEach(file => { try { fs.unlinkSync(file); } catch {} });
    throw error;
  }
  return {item, files: outputs.length, note: 'Upload tersimpan. Jalankan flutter build web --no-pub untuk memperbarui preview.'};
}

function editStory(id, input) {
  if (!validId(id)) fail('ID cerita tidak valid.');
  const catalog = readCatalog();
  const index = catalog.stories.findIndex(item => item.id === id);
  if (index < 0) fail('Cerita tidak ditemukan. Cerita bawaan tidak dapat diedit di backoffice.');
  const old = catalog.stories[index];
  const title = String(input.title || '').trim();
  const reference = String(input.reference || '').trim();
  if (!title || !reference) fail('Judul dan referensi wajib diisi.');
  const texts = String(input.pageTexts || '').split(/^---+$/m).map(value => value.trim()).filter(Boolean);
  if (texts.length !== old.pages.length) fail('Jumlah halaman tidak boleh berubah saat edit.');
  if (!Array.isArray(input.pageImages) || input.pageImages.length !== texts.length) fail('Daftar gambar halaman tidak lengkap.');
  const outputs = [];
  const revision = `edit-${randomUUID()}`;
  const add = (suffix, buffer) => {
    const name = `${id}-${revision}-${suffix}`;
    const target = path.join(content, name);
    outputs.push({target, buffer});
    return `assets/content/${name}`;
  };
  const cover = input.cover ? add('cover.png', decodeFile(input.cover, 'png', 'Cover')) : old.cover;
  const pages = texts.map((text, i) => ({
    text,
    image: input.pageImages[i]
      ? add(`page-${i + 1}.png`, decodeFile(input.pageImages[i], 'png', `Gambar halaman ${i + 1}`))
      : old.pages[i].image,
  }));
  const audio = input.audio ? add('narration.mp3', decodeFile(input.audio, 'mp3', 'Narasi')) : old.audio;
  const textChanged = texts.some((text, i) => text !== old.pages[i].text);
  if (audio && (input.audio || textChanged) && !input.timing) fail('Ganti narasi/teks memerlukan timing kata JSON baru.');
  const timing = input.timing ? validateTiming(input.timing, texts) : null;
  if (timing && !audio) fail('File timing memerlukan narasi MP3.');
  const timingAsset = timing ? add('timing.json', Buffer.from(JSON.stringify(timing, null, 2) + '\n')) : old.timingAsset;
  const item = {id, title, reference, summary: String(input.summary || '').trim(), cover, audio, timingAsset, pages, isFree: input.isFree !== false};
  catalog.stories[index] = item;
  const written = [];
  try {
    outputs.forEach(file => { fs.writeFileSync(file.target, file.buffer, {flag: 'wx'}); written.push(file.target); });
    commitCatalog(catalog);
  } catch (error) {
    written.forEach(file => { try { fs.unlinkSync(file); } catch {} });
    throw error;
  }
  const retained = new Set(storyAssets(item));
  const unused = storyAssets(old).filter(asset => !retained.has(asset));
  try { archiveAssets(unused, id); } catch (error) { console.error('Could not archive replaced assets:', error); }
  return {item, files: outputs.length, note};
}

function deleteStory(id) {
  if (!validId(id)) fail('ID cerita tidak valid.');
  const catalog = readCatalog();
  const index = catalog.stories.findIndex(item => item.id === id);
  if (index < 0) fail('Cerita tidak ditemukan. Cerita bawaan tidak dapat dihapus di backoffice.');
  const [item] = catalog.stories.splice(index, 1);
  const archive = archiveAssets(storyAssets(item), id);
  try {
    commitCatalog(catalog);
  } catch (error) {
    archive?.moved.reverse().forEach(file => fs.renameSync(file.archived, file.original));
    throw error;
  }
  return {id, archivedTo: archive?.directory || null, note};
}

async function publishContent() {
  const script = path.join(project, 'tool', 'publish_content_r2.mjs');
  const {stdout, stderr} = await runFile(process.execPath, [script], {
    cwd: project,
    timeout: 20 * 60 * 1000,
    maxBuffer: 4 * 1024 * 1024,
    windowsHide: true,
  });
  return {
    ok: true,
    note: 'Konten lokal sudah dipublikasikan ke Cloudflare R2.',
    output: `${stdout}${stderr}`.trim(),
  };
}

http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/') {
      res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
      return fs.createReadStream(path.join(__dirname, 'index.html')).pipe(res);
    }
    if (req.method === 'GET' && req.url === '/font.ttf') {
      res.writeHead(200, {'Content-Type': 'font/ttf'});
      return fs.createReadStream(path.join(project, 'assets', 'fonts', 'Fredoka-Regular.ttf')).pipe(res);
    }
    if (req.method === 'GET' && req.url === '/api/catalog') return json(res, 200, readCatalog());
    if (req.method === 'POST' && req.url === '/api/publish') return json(res, 200, await publishContent());
    if (req.method === 'POST' && (req.url === '/api/story' || req.url === '/api/verse')) {
      const input = await receive(req);
      return json(res, 201, saveUpload(req.url.endsWith('story') ? 'story' : 'verse', input));
    }
    const storyRoute = /^\/api\/story\/([a-z0-9]+(?:-[a-z0-9]+)*)$/.exec(req.url || '');
    if (storyRoute && req.method === 'PATCH') return json(res, 200, editStory(storyRoute[1], await receive(req)));
    if (storyRoute && req.method === 'DELETE') return json(res, 200, deleteStory(storyRoute[1]));
    json(res, 404, {error: 'Not found'});
  } catch (error) { json(res, 400, {error: error.message}); }
}).listen(port, '127.0.0.1', () => console.log(`Gembala Kecil backoffice: http://127.0.0.1:${port}/`));
