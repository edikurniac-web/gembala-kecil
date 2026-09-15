const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');

test('preview serves seekable MP3 byte ranges', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'gembala-preview-'));
  const audio = path.join(root, 'narration.mp3');
  fs.writeFileSync(audio, '0123456789');
  const port = 57185;
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'preview-server.js')], {
    env: {...process.env, GEMBALA_PREVIEW_ROOT: root, GEMBALA_PREVIEW_PORT: String(port)},
    stdio: 'ignore',
  });
  try {
    let ready = false;
    for (let i = 0; i < 30; i++) {
      try { await fetch(`http://127.0.0.1:${port}/narration.mp3`); ready = true; break; }
      catch { await new Promise(resolve => setTimeout(resolve, 100)); }
    }
    assert.ok(ready, 'preview server started');
    const url = `http://127.0.0.1:${port}/narration.mp3`;
    const full = await fetch(url);
    assert.equal(full.status, 200);
    assert.equal(full.headers.get('accept-ranges'), 'bytes');
    const middle = await fetch(url, {headers: {Range: 'bytes=3-5'}});
    assert.equal(middle.status, 206);
    assert.equal(middle.headers.get('content-range'), 'bytes 3-5/10');
    assert.equal(await middle.text(), '345');
    const suffix = await fetch(url, {headers: {Range: 'bytes=-2'}});
    assert.equal(suffix.status, 206);
    assert.equal(await suffix.text(), '89');
    const invalid = await fetch(url, {headers: {Range: 'bytes=100-200'}});
    assert.equal(invalid.status, 416);
  } finally {
    if (child.exitCode === null) {
      child.kill();
      await new Promise(resolve => child.once('exit', resolve));
    }
    fs.rmSync(root, {recursive: true, force: true});
  }
});
