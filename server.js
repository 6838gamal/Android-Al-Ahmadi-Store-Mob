const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const API_PORT = 8000;
const WEB_DIR = path.join(__dirname, 'build', 'web');

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.svg': 'image/svg+xml',
};

function proxyRequest(req, res, urlOverride) {
  const proxyPath = urlOverride || req.url;

  const options = {
    hostname: '127.0.0.1',
    port: API_PORT,
    path: proxyPath,
    method: req.method,
    headers: { ...req.headers, host: `127.0.0.1:${API_PORT}` },
  };

  const proxyReq = http.request(options, (proxyRes) => {
    // Follow 307/308 redirects internally
    if ((proxyRes.statusCode === 307 || proxyRes.statusCode === 308) && proxyRes.headers.location) {
      proxyRes.resume();
      const loc = new URL(proxyRes.headers.location);
      return proxyRequest(req, res, loc.pathname + loc.search);
    }
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (err) => {
    console.error('Proxy error:', err.message);
    res.writeHead(502);
    res.end('Backend unavailable');
  });

  req.pipe(proxyReq, { end: true });
}

const server = http.createServer((req, res) => {
  // Proxy /api/* and /uploads/* to backend
  if (req.url.startsWith('/api') || req.url.startsWith('/uploads')) {
    return proxyRequest(req, res);
  }

  // Serve static Flutter web files
  let urlPath = req.url.split('?')[0];
  let filePath = path.join(WEB_DIR, urlPath === '/' ? 'index.html' : urlPath);

  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      // SPA fallback
      filePath = path.join(WEB_DIR, 'index.html');
    }

    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }

      const ext = path.extname(filePath);
      const contentType = mimeTypes[ext] || 'application/octet-stream';

      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      });
      res.end(data);
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Flutter web app running at http://0.0.0.0:${PORT}`);
  console.log(`Proxying /api/* and /uploads/* → http://127.0.0.1:${API_PORT}`);
});
