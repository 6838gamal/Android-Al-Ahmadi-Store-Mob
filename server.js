const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const EXTERNAL_API = 'https://android-al-ahmadi-store-api.onrender.com';
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
  const target = new URL(EXTERNAL_API);

  const clientIp = req.headers['x-real-ip']
    || (req.headers['x-forwarded-for'] || '').split(',')[0].trim()
    || req.socket.remoteAddress
    || '127.0.0.1';

  const options = {
    hostname: target.hostname,
    port: 443,
    path: proxyPath,
    method: req.method,
    headers: {
      ...req.headers,
      host: target.hostname,
      'x-real-ip': clientIp,
      'x-forwarded-for': clientIp,
    },
  };

  const proxyReq = https.request(options, (proxyRes) => {
    // Follow 307/308 redirects internally
    if ((proxyRes.statusCode === 307 || proxyRes.statusCode === 308) && proxyRes.headers.location) {
      proxyRes.resume();
      const loc = new URL(proxyRes.headers.location);
      return proxyRequest(req, res, loc.pathname + loc.search);
    }
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  // 45-second timeout for API requests — prevents hanging when backend is slow
  proxyReq.setTimeout(45000, () => {
    proxyReq.destroy();
    if (!res.headersSent) {
      res.writeHead(503, {
        'Content-Type': 'application/json; charset=utf-8',
        'Access-Control-Allow-Origin': '*',
      });
      res.end(JSON.stringify({
        detail: 'الخادم يستغرق وقتاً أطول من المعتاد — أعد المحاولة خلال لحظات'
      }));
    }
  });

  proxyReq.on('error', (err) => {
    console.error('Proxy error:', err.message);
    if (!res.headersSent) {
      res.writeHead(502, {
        'Content-Type': 'application/json; charset=utf-8',
        'Access-Control-Allow-Origin': '*',
      });
      res.end(JSON.stringify({
        detail: 'تعذّر الاتصال بالخادم الخارجي — تأكد من اتصالك بالإنترنت وأعد المحاولة'
      }));
    }
  });

  req.pipe(proxyReq, { end: true });
}

const server = http.createServer((req, res) => {
  // Firebase config endpoint — serves keys from env vars (never hardcoded)
  if (req.url === '/firebase-config') {
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    });
    res.end(JSON.stringify({
      apiKey:            process.env.FIREBASE_API_KEY || '',
      authDomain:        'android-al-ahmadi-store.firebaseapp.com',
      projectId:         'android-al-ahmadi-store',
      storageBucket:     'android-al-ahmadi-store.firebasestorage.app',
      messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID || '',
      appId:             process.env.FIREBASE_APP_ID || '',
    }));
    return;
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
  console.log(`Proxying /api/* and /uploads/* → ${EXTERNAL_API}`);
});
