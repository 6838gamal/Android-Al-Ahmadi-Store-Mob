---
name: Flutter web API URL
description: How the Flutter app base URL is configured — now hardcoded to Render.com
---

**Current rule:** `baseUrl` is a `const String` always pointing to the deployed Render.com backend:

```dart
static const String baseUrl = 'https://android-al-ahmadi-store-api.onrender.com';
```

**Why changed from `Uri.base.origin`:** The backend is deployed on Render.com with a fixed PostgreSQL database. Both web and native Flutter should always call the same deployed API, not a local Replit proxy.

**Previous pattern (no longer used):** `Uri.base.origin` when `kIsWeb` — was needed when the backend ran locally and Flutter was served through the Replit proxy on port 5000. No longer applicable since backend is on Render.com.

**How to apply:** `AppConstants.baseUrl` is a plain `const` — no import of `package:flutter/foundation.dart` needed.
