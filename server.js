const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const API_PORT = 8000;
const ADMIN_PORT = 8080;
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

  const clientIp = req.headers['x-real-ip']
    || (req.headers['x-forwarded-for'] || '').split(',')[0].trim()
    || req.socket.remoteAddress
    || '127.0.0.1';

  const options = {
    hostname: '127.0.0.1',
    port: API_PORT,
    path: proxyPath,
    method: req.method,
    headers: {
      ...req.headers,
      host: `127.0.0.1:${API_PORT}`,
      'x-real-ip': clientIp,
      'x-forwarded-for': clientIp,
    },
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

function proxyAdminRequest(req, res) {
  // Strip /admin-panel prefix when forwarding to admin panel port
  const adminPath = req.url.startsWith('/admin-panel')
    ? (req.url.slice('/admin-panel'.length) || '/')
    : req.url;

  const options = {
    hostname: '127.0.0.1',
    port: ADMIN_PORT,
    path: adminPath,
    method: req.method,
    headers: { ...req.headers, host: `127.0.0.1:${ADMIN_PORT}` },
  };

  const proxyReq = http.request(options, (proxyRes) => {
    proxyReq.setTimeout(0); // Clear timeout once connection is established
    // For 302/303 redirects: use client-side JS redirect so the browser
    // navigates with GET instead of relying on the proxy chain which
    // incorrectly re-POSTs the redirect.
    if ([301, 302, 303].includes(proxyRes.statusCode) && proxyRes.headers.location) {
      const loc = proxyRes.headers.location;
      const newLoc = (loc.startsWith('/') && !loc.startsWith('/admin-panel'))
        ? `/admin-panel${loc}`
        : loc;

      // Build response headers, forwarding Set-Cookie so session is saved
      const respHeaders = { 'content-type': 'text/html; charset=utf-8' };
      if (proxyRes.headers['set-cookie']) {
        respHeaders['set-cookie'] = proxyRes.headers['set-cookie'];
      }

      proxyRes.resume();
      res.writeHead(200, respHeaders);
      res.end(`<!doctype html><html><head>
<script>window.location.replace(${JSON.stringify(newLoc)})</script>
</head><body>جارٍ التحويل...</body></html>`);
      return;
    }

    // For HTML responses, buffer and rewrite absolute links to include /admin-panel prefix
    const contentType = proxyRes.headers['content-type'] || '';
    if (contentType.includes('text/html')) {
      const headers = { ...proxyRes.headers };
      delete headers['content-length']; // Body length changes after rewrite
      res.writeHead(proxyRes.statusCode, headers);

      const chunks = [];
      proxyRes.on('data', chunk => chunks.push(chunk));
      proxyRes.on('end', () => {
        let body = Buffer.concat(chunks).toString('utf8');
        // Rewrite absolute paths → prepend /admin-panel
        body = body.replace(/href="\//g, 'href="/admin-panel/');
        body = body.replace(/action="\//g, 'action="/admin-panel/');
        body = body.replace(/src="\//g, 'src="/admin-panel/');
        res.end(body);
      });
      return;
    }

    // Stream all other responses (images, CSS, JS, JSON) as-is
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.setTimeout(25000, () => {
    proxyReq.destroy();
    if (!res.headersSent) {
      res.writeHead(504, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end('<h3>الخادم يستغرق وقتاً أطول من المعتاد — أعد المحاولة خلال لحظات</h3>');
    }
  });

  proxyReq.on('error', (err) => {
    console.error('Admin proxy error:', err.message);
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end('<h3>لوحة الإدارة غير متاحة مؤقتاً — أعد المحاولة</h3>');
    }
  });

  req.pipe(proxyReq, { end: true });
}

const server = http.createServer((req, res) => {
  // Proxy /admin-panel/* to admin panel (port 8080)
  if (req.url === '/admin-panel' || req.url.startsWith('/admin-panel/') || req.url.startsWith('/admin-panel?')) {
    return proxyAdminRequest(req, res);
  }

  // Proxy /api/* and /uploads/* to backend (port 8000)
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
  console.log(`Proxying /admin-panel/* → http://127.0.0.1:${ADMIN_PORT}`);
});
