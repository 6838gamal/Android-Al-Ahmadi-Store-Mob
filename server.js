const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const EXTERNAL_API = (process.env.BACKEND_API_URL || 'http://localhost:8000').replace(/\/$/, '');
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

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', () => resolve(Buffer.alloc(0)));
  });
}

function proxyWithBody(req, res, bodyBuffer, urlOverride) {
  const proxyPath = urlOverride || req.url;
  const target = new URL(EXTERNAL_API);
  const isHttps = target.protocol === 'https:';

  const clientIp = req.headers['x-real-ip']
    || (req.headers['x-forwarded-for'] || '').split(',')[0].trim()
    || req.socket.remoteAddress
    || '127.0.0.1';

  const headers = {
    ...req.headers,
    host: target.host,
    'x-real-ip': clientIp,
    'x-forwarded-for': clientIp,
  };

  if (bodyBuffer.length > 0) {
    headers['content-length'] = bodyBuffer.length;
  }

  const options = {
    hostname: target.hostname,
    port: target.port || (isHttps ? 443 : 80),
    path: proxyPath,
    method: req.method,
    headers,
  };

  const transport = isHttps ? https : http;

  const proxyReq = transport.request(options, (proxyRes) => {
    if ((proxyRes.statusCode === 307 || proxyRes.statusCode === 308) && proxyRes.headers.location) {
      proxyRes.resume();
      const loc = new URL(proxyRes.headers.location);
      return proxyWithBody(req, res, bodyBuffer, loc.pathname + loc.search);
    }
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

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
        detail: 'تعذّر الاتصال بالخادم — تأكد من تشغيل الـ Backend وأعد المحاولة'
      }));
    }
  });

  if (bodyBuffer.length > 0) {
    proxyReq.write(bodyBuffer);
  }
  proxyReq.end();
}

const server = http.createServer(async (req, res) => {
  if (req.url.startsWith('/api') || req.url.startsWith('/uploads')) {
    const bodyBuffer = await readBody(req);
    return proxyWithBody(req, res, bodyBuffer);
  }

  let urlPath = req.url.split('?')[0];
  let filePath = path.join(WEB_DIR, urlPath === '/' ? 'index.html' : urlPath);

  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
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

      const isServiceWorker = filePath.endsWith('flutter_service_worker.js');
      const isBootstrap = filePath.endsWith('flutter_bootstrap.js');
      let body = data;
      if (isServiceWorker) {
        body = data.toString('utf8').replace(
          /const REMOTE_API\s*=\s*['"][^'"]*['"]\s*;/,
          `const REMOTE_API = ${JSON.stringify(EXTERNAL_API)};`
        );
      } else if (isBootstrap) {
        body = data.toString('utf8').replace(
          /_flutter\.loader\.load\(\{[\s\S]*?\}\);/,
          `_flutter.loader.load({});`
        );
      }

      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      });
      res.end(body);
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Flutter web app running at http://0.0.0.0:${PORT}`);
  console.log(`Proxying /api/* and /uploads/* → ${EXTERNAL_API}`);
});
