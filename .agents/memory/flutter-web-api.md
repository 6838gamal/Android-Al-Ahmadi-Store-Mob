---
name: Flutter web API URL
description: How the Flutter app base URL is configured — web uses Uri.base.origin, mobile uses Render.com URL. Compiled build/web must be patched if already built with old Render.com URL.
---

## Rule

`api_client.dart` `_resolveBase()` uses:
1. `--dart-define=API_BASE_URL=...` compile-time override (if set)
2. `Uri.base.origin` when `kIsWeb` (works on Replit via server.js proxy `/api/*` → port 8000)
3. `AppConstants.baseUrl` (Render.com) for mobile

**Why:** On web, the Flutter app is served through the same origin as the API proxy (server.js). Using `Uri.base.origin` means API calls go to the same domain, and server.js routes `/api/*` to the local backend (port 8000). This works on Replit. For mobile, the backend is on Render.com.

**If already-built `build/web/main.dart.js` has Render.com URL baked in:**
```bash
REPLIT_DOMAIN="https://${REPLIT_DEV_DOMAIN}"
sed -i "s|https://android-al-ahmadi-store-api.onrender.com|${REPLIT_DOMAIN}|g" build/web/main.dart.js
```
Then restart the `Start application` workflow.

**How to apply:** After any Flutter web rebuild, verify the URL with:
```bash
grep -c "onrender.com" build/web/main.dart.js   # should be 0 after patch
grep -c "replit.dev" build/web/main.dart.js      # should be 2 after patch
```
