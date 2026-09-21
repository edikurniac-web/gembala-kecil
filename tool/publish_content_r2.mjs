import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const contentDirectory = path.join(root, 'assets', 'content');
const workerDirectory = path.join(root, 'cloudflare', 'content-worker');
const wranglerPath = path.join(
  workerDirectory,
  'node_modules',
  'wrangler',
  'bin',
  'wrangler.js',
);
const catalogPath = path.join(contentDirectory, 'catalog.json');
const publishStatePath = path.join(root, '.r2-publish-state.json');
const bucket = process.env.GEMBALA_R2_BUCKET || 'gembala-kecil-content';
const contentApi =
  process.env.GEMBALA_CONTENT_API ||
  'https://api-gembalakecil.duniapinta.my.id';
const dryRun = process.argv.includes('--dry-run');
const forceAll = process.argv.includes('--force-all');
const bootstrapFromCloud = process.argv.includes('--bootstrap-from-cloud');
const concurrency = 1;
const maxAttempts = 6;
const uploadSpacingMs = 650;
let cloudflareApiToken = process.env.CLOUDFLARE_API_TOKEN || null;

function fail(message) {
  throw new Error(message);
}

function contentType(filename) {
  if (filename.endsWith('.png')) return 'image/png';
  if (filename.endsWith('.mp3')) return 'audio/mpeg';
  if (filename.endsWith('.json')) return 'application/json; charset=utf-8';
  return 'application/octet-stream';
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function fileHash(filename) {
  return createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
}

function readPublishState() {
  if (!fs.existsSync(publishStatePath)) return {};
  try {
    const value = JSON.parse(fs.readFileSync(publishStatePath, 'utf8'));
    return value && typeof value === 'object' ? value : {};
  } catch {
    return {};
  }
}

function writePublishState(state) {
  const temporaryPath = `${publishStatePath}.tmp`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(state, null, 2)}\n`);
  fs.renameSync(temporaryPath, publishStatePath);
}

function wranglerConfigPaths() {
  const paths = [];
  if (process.env.XDG_CONFIG_HOME) {
    paths.push(
      path.join(process.env.XDG_CONFIG_HOME, '.wrangler', 'config', 'default.toml'),
    );
  }
  if (process.env.APPDATA) {
    paths.push(
      path.join(
        process.env.APPDATA,
        'xdg.config',
        '.wrangler',
        'config',
        'default.toml',
      ),
    );
  }
  paths.push(
    path.join(os.homedir(), '.config', '.wrangler', 'config', 'default.toml'),
  );
  return [...new Set(paths)];
}

function readWranglerOAuthToken() {
  for (const configPath of wranglerConfigPaths()) {
    if (!fs.existsSync(configPath)) continue;
    const config = fs.readFileSync(configPath, 'utf8');
    const match = /^oauth_token\s*=\s*"([^"]+)"/m.exec(config);
    if (match) return match[1];
  }
  return null;
}

function refreshWranglerLogin() {
  if (cloudflareApiToken || dryRun) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [wranglerPath, 'whoami'], {
      cwd: workerDirectory,
      env: {...process.env, WRANGLER_WRITE_LOGS: 'false'},
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });
    let output = '';
    child.stdout.on('data', (chunk) => (output += chunk));
    child.stderr.on('data', (chunk) => (output += chunk));
    child.on('error', reject);
    child.on('close', (code) => {
      if (code !== 0) {
        reject(
          new Error(
            'Login Cloudflare perlu diperbarui. Jalankan `npx wrangler login` lalu coba publish lagi.',
          ),
        );
        return;
      }
      cloudflareApiToken = readWranglerOAuthToken();
      if (!cloudflareApiToken) {
        reject(
          new Error(
            'Token OAuth Wrangler tidak ditemukan setelah login diperiksa.',
          ),
        );
        return;
      }
      resolve();
    });
  });
}

function collectAssets(catalog) {
  const paths = new Set();
  const add = (value) => {
    if (!value) return;
    if (typeof value !== 'string' || !value.startsWith('assets/content/')) {
      fail(`Cloud asset path is not supported: ${value}`);
    }
    const key = value.substring('assets/content/'.length);
    if (!key || key.includes('..') || key.includes('/') || key.includes('\\')) {
      fail(`Unsafe cloud asset key: ${key}`);
    }
    const source = path.join(contentDirectory, key);
    if (!fs.existsSync(source)) fail(`Missing local content asset: ${source}`);
    paths.add(key);
  };
  for (const story of catalog.stories || []) {
    add(story.cover);
    add(story.audio);
    add(story.timingAsset);
    for (const page of story.pages || []) add(page.image);
  }
  for (const verse of catalog.verses || []) {
    add(verse.image);
    add(verse.audio);
  }
  return [...paths].sort();
}

function uploadOnce(key, source, cacheControl) {
  if (dryRun) {
    console.log(`[dry-run] ${key}`);
    return Promise.resolve();
  }
  const args = [
    wranglerPath,
    'r2',
    'object',
    'put',
    `${bucket}/${key}`,
    '--file',
    source,
    '--content-type',
    contentType(key),
    '--cache-control',
    cacheControl,
    '--remote',
    '--force',
  ];
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, args, {
      cwd: workerDirectory,
      env: {
        ...process.env,
        CLOUDFLARE_API_TOKEN: cloudflareApiToken,
        WRANGLER_WRITE_LOGS: 'false',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });
    let output = '';
    child.stdout.on('data', (chunk) => (output += chunk));
    child.stderr.on('data', (chunk) => (output += chunk));
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        console.log(`Uploaded ${key}`);
        resolve();
      } else {
        reject(new Error(`Upload failed for ${key}: ${output.trim()}`));
      }
    });
  });
}

async function upload(key, source, cacheControl) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await uploadOnce(key, source, cacheControl);
      return;
    } catch (error) {
      if (attempt === maxAttempts) throw error;
      const message = String(error);
      const rateLimited =
        message.includes('429') ||
        message.includes('Too Many Requests') ||
        message.includes('Rate limited');
      const delay = rateLimited
        ? Math.min(60000, 5000 * 2 ** (attempt - 1))
        : attempt * 2000;
      console.warn(
        `Retrying ${key} (${attempt}/${maxAttempts}) in ${Math.ceil(delay / 1000)}s...`,
      );
      await sleep(delay);
    }
  }
}

async function runPool(items, task) {
  let cursor = 0;
  const workers = Array.from({length: Math.min(concurrency, items.length)}, async () => {
    while (cursor < items.length) {
      const index = cursor++;
      await task(items[index], index);
    }
  });
  await Promise.all(workers);
}

const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
if (catalog.schemaVersion !== 1) fail('Unsupported catalog schema.');
const assets = collectAssets(catalog);
const publishState = readPublishState();
if (bootstrapFromCloud && !dryRun) {
  const response = await fetch(`${contentApi}/v1/catalog`);
  if (!response.ok) {
    fail(`Cannot read published catalog (${response.status}).`);
  }
  const publishedCatalog = await response.json();
  for (const key of collectAssets(publishedCatalog)) {
    const source = path.join(contentDirectory, key);
    if (fs.existsSync(source)) publishState[key] = fileHash(source);
  }
  writePublishState(publishState);
  console.log('Resumed from the currently published Cloudflare catalog.');
}
const pendingAssets =
  dryRun || forceAll
    ? assets
    : assets.filter(
        (key) =>
          publishState[key] !== fileHash(path.join(contentDirectory, key)),
      );
console.log(
  `${dryRun ? 'Checking' : 'Publishing'} ${pendingAssets.length} changed assets ` +
    `(${assets.length} referenced)...`,
);
await refreshWranglerLogin();
await runPool(pendingAssets, async (key) => {
  const source = path.join(contentDirectory, key);
  await upload(key, source, 'public, max-age=31536000, immutable');
  if (!dryRun) {
    publishState[key] = fileHash(source);
    writePublishState(publishState);
    await sleep(uploadSpacingMs);
  }
});
await upload('catalog.json', catalogPath, 'public, max-age=60');
console.log(`Published catalog with ${catalog.stories.length} stories and ${catalog.verses.length} verses.`);
