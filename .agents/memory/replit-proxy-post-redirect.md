---
name: Replit HTTPS proxy POST redirect bug
description: Replit's HTTPS proxy follows 302/303 redirects internally using the original HTTP method (POST stays POST) instead of switching to GET as browsers and the HTTP spec require for 303.
---

## The Rule
Never return a 302/303 redirect in response to a form POST when going through Replit's HTTPS proxy. The proxy re-POSTs to the redirect target, causing 405 Method Not Allowed if no POST handler exists.

**Why:** Replit's HTTPS proxy sits between the user's browser and the app server. When the app returns 303 `/dashboard` in response to a POST form submission, Replit's proxy follows the 303 internally as another POST (not GET), so the next handler receives `POST /dashboard` instead of `GET /dashboard`.

**How to apply:** Replace server-side 302/303 redirect responses with a `200 OK` HTML page that forwards the `Set-Cookie` header and uses `window.location.replace(url)` to perform a client-side GET navigation:

```javascript
// In the proxy (server.js) when admin panel returns 302/303:
if ([301, 302, 303].includes(proxyRes.statusCode) && proxyRes.headers.location) {
  const newLoc = rewriteLocation(proxyRes.headers.location);
  const respHeaders = { 'content-type': 'text/html; charset=utf-8' };
  if (proxyRes.headers['set-cookie']) {
    respHeaders['set-cookie'] = proxyRes.headers['set-cookie'];
  }
  proxyRes.resume();
  res.writeHead(200, respHeaders);
  res.end(`<!doctype html><html><head>
<script>window.location.replace(${JSON.stringify(newLoc)})</script>
</head></html>`);
  return;
}
```

This ensures:
1. The browser receives and stores the session cookie (Set-Cookie forwarded)
2. The browser navigates to the target via GET (correct behavior)
3. The URL bar updates correctly to the redirected URL
