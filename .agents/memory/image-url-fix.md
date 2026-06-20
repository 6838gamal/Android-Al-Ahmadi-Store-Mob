---
name: Flutter image URL fix (Render.com baked URL)
description: AppConstants.baseUrl is baked into the compiled Flutter JS as the Render.com URL; must be stripped at serve time so image URLs become relative paths served through the local proxy.
---

# Flutter Image URL Fix

## The Rule
`server.js` must patch `main.dart.js` at serve time to replace the baked-in Render.com URL (`https://android-al-ahmadi-store-api.onrender.com`) with an empty string. This makes `AppConstants.baseUrl` effectively `''`, so image URLs resolve as relative paths (e.g. `/uploads/uuid.jpg`).

**Why:** `AppConstants.baseUrl` is a Dart `const` defined via `String.fromEnvironment` with a Render.com default. It is inlined at compile time into `main.dart.js`. Without patching, all image requests go directly to Render.com, bypassing the local proxy. Render.com free tier has ephemeral storage, so images are lost on restart.

**How to apply:** In `server.js`, after serving static files, add a branch for `main.dart.js`:
```javascript
} else if (isMainDart) {
  const BAKED_URL = 'https://android-al-ahmadi-store-api.onrender.com';
  body = data.toString('utf8').split(BAKED_URL).join('');
}
```

## Companion Fix
`BACKEND_API_URL` must be set to `http://localhost:8000` (not the Render.com external URL) so that:
- `server.js` proxies `/uploads/*` to the local backend (serves local files)
- `admin_panel/main.py` uploads images to the local backend (saves to local `uploads/`)
- Images persist across Replit restarts (unlike Render.com free tier)
