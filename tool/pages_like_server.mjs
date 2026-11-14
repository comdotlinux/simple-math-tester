// Static server that redirects like Cloudflare Pages: /index.html -> /,
// /foo.html -> /foo, and /foo is served from foo.html. _headers is not served.
// Usage: node tool/pages_like_server.mjs <dir> <port>
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const [root, port] = process.argv.slice(2);
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.bin': 'application/octet-stream',
  '.wav': 'audio/wav',
};

async function file(path) {
  try {
    return (await stat(path)).isFile() ? path : null;
  } catch {
    return null;
  }
}

createServer(async (req, res) => {
  const { pathname, search } = new URL(req.url, 'http://localhost');
  if (pathname.endsWith('.html')) {
    const target = pathname.slice(0, -'.html'.length).replace(/\/index$/, '/');
    res.writeHead(308, { Location: target + search }).end();
    return;
  }
  // normalize() of a path starting with "/" cannot climb above the root.
  const local = join(root, normalize(decodeURIComponent(pathname)));
  const path = pathname.split('/').pop() === '_headers' ? null
    : pathname.endsWith('/') ? await file(join(local, 'index.html'))
    : (await file(local)) ?? (await file(`${local}.html`));
  if (!path) {
    res.writeHead(404).end('Not found');
    return;
  }
  res.writeHead(200, { 'Content-Type': types[extname(path)] ?? 'application/octet-stream' });
  res.end(await readFile(path));
}).listen(Number(port), () => console.log(`Serving ${root} on http://localhost:${port}`));
