const http = require('http');
const fs = require('fs');
const path = require('path');
const root = path.resolve(process.env.GEMBALA_PREVIEW_ROOT || path.join(__dirname, 'build', 'web'));
const port = Number(process.env.GEMBALA_PREVIEW_PORT || 57182);
const mime = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.css': 'text/css', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.wasm': 'application/wasm', '.mp3': 'audio/mpeg',
};
http.createServer((req, res) => {
  let url;
  try { url = decodeURIComponent(req.url.split('?')[0]); }
  catch { res.writeHead(400); return res.end(); }
  const requested = url === '/' ? '/index.html' : url;
  const file = path.resolve(root, `.${requested}`);
  if (!file.startsWith(root + path.sep) && file !== root) { res.writeHead(403); return res.end(); }
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); return res.end(); }
  fs.stat(file, (error, stat) => {
    if (error || !stat.isFile()) { res.writeHead(404); return res.end('Not found'); }
    const headers = {
      'Content-Type': mime[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
      'Accept-Ranges': 'bytes',
    };
    if (stat.size === 0) {
      res.writeHead(200, {...headers, 'Content-Length': 0});
      return res.end();
    }
    let start = 0;
    let end = stat.size - 1;
    let status = 200;
    // HTMLAudioElement needs byte ranges to seek within MP3 narration.
    if (req.headers.range) {
      const match = /^bytes=(\d*)-(\d*)$/.exec(req.headers.range);
      if (!match || (!match[1] && !match[2])) {
        res.writeHead(416, {...headers, 'Content-Range': `bytes */${stat.size}`});
        return res.end();
      }
      if (!match[1]) {
        const suffix = Number(match[2]);
        if (!Number.isSafeInteger(suffix) || suffix <= 0) {
          res.writeHead(416, {...headers, 'Content-Range': `bytes */${stat.size}`});
          return res.end();
        }
        start = Math.max(0, stat.size - suffix);
      } else {
        start = Number(match[1]);
        if (match[2]) end = Math.min(Number(match[2]), stat.size - 1);
      }
      if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start >= stat.size || start > end) {
        res.writeHead(416, {...headers, 'Content-Range': `bytes */${stat.size}`});
        return res.end();
      }
      status = 206;
      headers['Content-Range'] = `bytes ${start}-${end}/${stat.size}`;
    }
    headers['Content-Length'] = end - start + 1;
    res.writeHead(status, headers);
    if (req.method === 'HEAD') return res.end();
    fs.createReadStream(file, {start, end}).pipe(res);
  });
}).listen(port, '127.0.0.1', () => console.log(`Flutter preview: http://127.0.0.1:${port}/`));
