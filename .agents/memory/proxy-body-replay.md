---
name: Proxy body replay on redirect
description: server.js must buffer POST body before proxying so it survives 307/308 redirects from FastAPI
---

## Rule
Always buffer the full request body as a `Buffer` before proxying any API request. Never use `req.pipe(proxyReq)` directly when the proxy follows redirects.

**Why:** FastAPI redirects bare paths (e.g. `/api/orders`) to trailing-slash paths (`/api/orders/`) with HTTP 307. Node.js `IncomingMessage` is a readable stream that can only be piped once — after the first `req.pipe()` call, the stream is exhausted. A second proxy attempt on redirect receives an empty body, causing a 422 validation error.

**How to apply:**
- In `server.js`, use `readBody(req)` to collect all chunks into a `Buffer` before calling `proxyWithBody`
- Pass the `Buffer` to every proxy call, including redirect retries
- Write the buffer directly: `proxyReq.write(bodyBuffer); proxyReq.end()` — do NOT `req.pipe()`
- Set `content-length` header to `bodyBuffer.length` when buffer is non-empty
