---
name: Node.js FastAPI proxy redirect handling
description: FastAPI 307-redirects bare paths to trailing slash; proxy must follow internally
---

FastAPI (with default redirect_slashes=True) returns HTTP 307 when a path is requested without a trailing slash but the route is defined with one (e.g. GET /api/products → 307 → /api/products/).

A simple pipe-based proxy does NOT follow these redirects — it passes the 307 to the Flutter client which ignores it.

**Rule:** The proxy must detect 307/308 responses and internally re-request the redirect location.

```js
if ((proxyRes.statusCode === 307 || proxyRes.statusCode === 308) && proxyRes.headers.location) {
  proxyRes.resume();
  const loc = new URL(proxyRes.headers.location);
  return proxyRequest(req, res, loc.pathname + loc.search);
}
```

**Why:** Flutter's Dio doesn't follow server-side redirects when the initial URL already resolves. The proxy is the right place to handle this transparently.
