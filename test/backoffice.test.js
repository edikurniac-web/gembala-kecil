const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');

const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==';

test('backoffice creates, edits and deletes stories without losing verse data', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'gembala-backoffice-'));
  const content = path.join(root, 'assets', 'content');
  fs.mkdirSync(content, {recursive: true});
  fs.writeFileSync(path.join(content, 'catalog.json'), JSON.stringify({schemaVersion: 1, stories: [], verses: []}));
  const port = 57184;
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'backoffice', 'server.js')], {
    env: {...process.env, GEMBALA_PROJECT_ROOT: root, GEMBALA_BACKOFFICE_PORT: String(port)},
    stdio: 'ignore',
  });
  try {
    let ready = false;
    for (let i = 0; i < 30; i++) {
      try { await fetch(`http://127.0.0.1:${port}/api/catalog`); ready = true; break; }
      catch { await new Promise(resolve => setTimeout(resolve, 100)); }
    }
    assert.ok(ready, 'backoffice server started');
    const post = (kind, body) => fetch(`http://127.0.0.1:${port}/api/${kind}`, {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body),
    });
    const file = {name: 'square.png', base64: png};
    const story = await post('story', {
      id: 'test-story', title: 'Test Story', reference: 'Matius 1:1',
      pageTexts: 'Satu halaman.', cover: file, pageImages: [file],
    });
    assert.equal(story.status, 201, JSON.stringify(await story.json()));
    const verse = await post('verse', {id: 'test-verse', title: 'Test Verse', reference: 'Mazmur 1:1', text: 'Kasih Tuhan.'});
    assert.equal(verse.status, 201);
    const duplicate = await post('verse', {id: 'test-verse', title: 'Test Verse', reference: 'Mazmur 1:1', text: 'Kasih Tuhan.'});
    assert.equal(duplicate.status, 400);
    const catalog = JSON.parse(fs.readFileSync(path.join(content, 'catalog.json'), 'utf8'));
    assert.equal(catalog.stories.length, 1);
    assert.equal(catalog.verses.length, 1);
    assert.ok(fs.existsSync(path.join(content, 'test-story-page-1.png')));
    const patchStory = body => fetch(`http://127.0.0.1:${port}/api/story/test-story`, {
      method: 'PATCH', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body),
    });
    const edit = await patchStory({
      title: 'Edited Story', reference: 'Matius 1:2', summary: 'Baru',
      pageTexts: 'Satu halaman.', pageImages: [file], cover: null, audio: null, isFree: true,
    });
    assert.equal(edit.status, 200, JSON.stringify(await edit.json()));
    let changed = JSON.parse(fs.readFileSync(path.join(content, 'catalog.json'), 'utf8'));
    assert.equal(changed.stories[0].title, 'Edited Story');
    assert.match(changed.stories[0].pages[0].image, /edit-/);
    assert.ok(fs.existsSync(path.join(content, changed.stories[0].pages[0].image.split('/').at(-1))));
    assert.ok(!fs.existsSync(path.join(content, 'test-story-page-1.png')));
    const invalidAudio = await patchStory({
      title: 'Edited Story', reference: 'Matius 1:2', pageTexts: 'Satu halaman.',
      pageImages: [null], audio: {name: 'new.mp3', base64: Buffer.from('ID3example').toString('base64')},
    });
    assert.equal(invalidAudio.status, 400, 'replacing narration requires new word timing');
    const goodAudio = await patchStory({
      title: 'Edited Story', reference: 'Matius 1:2', pageTexts: 'Satu halaman.',
      pageImages: [null], audio: {name: 'new.mp3', base64: Buffer.from('ID3example').toString('base64')},
      timing: {version: 1, audioDurationMs: 1000, pages: [{startMs: 0, endMs: 1000, wordStartsMs: [100, 500]}]},
    });
    assert.equal(goodAudio.status, 200, JSON.stringify(await goodAudio.json()));
    changed = JSON.parse(fs.readFileSync(path.join(content, 'catalog.json'), 'utf8'));
    assert.ok(changed.stories[0].audio);
    assert.ok(changed.stories[0].timingAsset);
    const remove = await fetch(`http://127.0.0.1:${port}/api/story/test-story`, {method: 'DELETE'});
    assert.equal(remove.status, 200);
    const removed = await remove.json();
    assert.ok(fs.existsSync(removed.archivedTo));
    changed = JSON.parse(fs.readFileSync(path.join(content, 'catalog.json'), 'utf8'));
    assert.equal(changed.stories.length, 0);
    assert.equal(changed.verses.length, 1);
  } finally {
    if (child.exitCode === null) {
      child.kill();
      await new Promise(resolve => child.once('exit', resolve));
    }
    fs.rmSync(root, {recursive: true, force: true});
  }
});
