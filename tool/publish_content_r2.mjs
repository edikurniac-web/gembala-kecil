import {spawn} from 'node:child_process';
import fs from 'node:fs';
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
const bucket = process.env.GEMBALA_R2_BUCKET || 'gembala-kecil-content';
const dryRun = process.argv.includes('--dry-run');
const concurrency = 2;
const maxAttempts = 4;

function fail(message) {
  throw new Error(message);
}

function contentType(filename) {
  if (filename.endsWith('.png')) return 'image/png';
  if (filename.endsWith('.mp3')) return 'audio/mpeg';
  if (filename.endsWith('.json')) return 'application/json; charset=utf-8';
  return 'application/octet-stream';
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
      const delay = attempt * 1500;
      console.warn(`Retrying ${key} (${attempt}/${maxAttempts})...`);
      await new Promise((resolve) => setTimeout(resolve, delay));
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
console.log(`${dryRun ? 'Checking' : 'Publishing'} ${assets.length} content assets...`);
await runPool(assets, (key) =>
  upload(key, path.join(contentDirectory, key), 'public, max-age=31536000, immutable'),
);
await upload('catalog.json', catalogPath, 'public, max-age=60');
console.log(`Published catalog with ${catalog.stories.length} stories and ${catalog.verses.length} verses.`);
