---
name: Flutter compiled SW URL rewrite
description: Pre-compiled Flutter web (build/web) has Render.com URL baked in; runtime _resolveBase() may not be compiled correctly; fix via service worker patch
---

# Flutter compiled SW URL rewrite

## The Rule
When running the pre-compiled `build/web` Flutter app on Replit dev, API calls go directly to `https://android-al-ahmadi-store-api.onrender.com` instead of through the local server.js proxy. Fix by patching `build/web/flutter_service_worker.js`.

## Why
The compiled `main.dart.js` may have been built with an older version of `_resolveBase()` that always uses the Render.com URL regardless of the host. Changing source code in `lib/` doesn't help without rebuilding. The service worker intercepts ALL fetches from the Flutter app — including cross-origin ones.

## How to Apply
Two changes to `build/web/flutter_service_worker.js`:

1. **Bump CACHE_NAME** (forces browser to install new SW):
   ```js
   const CACHE_NAME = 'flutter-app-cache-v2'; // increment on each fix
   ```

2. **Add URL rewrite at top of fetch handler** (before the `!GET` return):
   ```js
   const REMOTE_API = 'https://android-al-ahmadi-store-api.onrender.com';
   self.addEventListener("fetch", (event) => {
     if (event.request.url.startsWith(REMOTE_API)) {
       var relativePath = event.request.url.slice(REMOTE_API.length) || '/';
       var newUrl = self.location.origin + relativePath;
       var newRequest = new Request(newUrl, { method: event.request.method, headers: event.request.headers, ... });
       event.respondWith(fetch(newRequest));
       return;
     }
     // ... rest of handler
   ```

3. Also patch `build/web/index.html` with a window.fetch + XHR interceptor as a belt-and-suspenders fallback.

**Do NOT** need to rebuild Flutter — the SW patch alone is sufficient.
