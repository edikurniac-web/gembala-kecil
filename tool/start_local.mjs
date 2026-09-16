import net from 'node:net';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function isListening(port) {
  return new Promise((resolve) => {
    const socket = net.createConnection({host: '127.0.0.1', port});
    const finish = (value) => {
      socket.destroy();
      resolve(value);
    };
    socket.setTimeout(700, () => finish(false));
    socket.once('connect', () => finish(true));
    socket.once('error', () => finish(false));
  });
}

function startDetached(script) {
  const child = spawn(process.execPath, [script], {
    cwd: project,
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
  });
  child.unref();
}

async function waitForPort(port) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (await isListening(port)) return true;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  return false;
}

if (!(await isListening(57182))) startDetached('preview-server.js');
if (!(await isListening(57183))) startDetached(path.join('backoffice', 'server.js'));

const [previewReady, backofficeReady] = await Promise.all([
  waitForPort(57182),
  waitForPort(57183),
]);

process.exitCode = previewReady && backofficeReady ? 0 : 1;
