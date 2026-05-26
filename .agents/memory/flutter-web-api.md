---
name: Flutter web dynamic API URL
description: How to construct the correct API base URL in Flutter web using Dio
---

In Flutter web, `localhost` and empty `baseUrl` both fail with Dio because:
- `localhost` in the browser refers to the user's machine, not the Replit server
- Empty string `''` makes Dio crash at runtime (needs an absolute URL)

**Rule:** Use `Uri.base.origin` when `kIsWeb` is true.

```dart
String _resolveBaseUrl() {
  if (kIsWeb) {
    return '${Uri.base.origin}${AppConstants.apiVersion}';
  }
  return '${AppConstants.baseUrl}${AppConstants.apiVersion}';
}
```

**Why:** The Flutter web app is served through the Replit preview proxy; the browser's current origin (port 5000) is the only reliable base. The Node.js server then proxies /api/* to the FastAPI backend on port 8000.

**How to apply:** Import `package:flutter/foundation.dart` for `kIsWeb`. Set `AppConstants.baseUrl = ''` (unused on web). This pattern works for any Replit-hosted Flutter web app.
