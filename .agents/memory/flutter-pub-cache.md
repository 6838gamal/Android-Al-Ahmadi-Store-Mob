---
name: Flutter pub cache path
description: Replit stores the Dart/Flutter pub cache at /home/runner/.pub-cache. Must set PUB_CACHE before flutter pub get / build web. open_file package may be missing from cache requiring network fetch.
---

## Rule

Before running `flutter pub get` or `flutter build web`, set:

```bash
export PUB_CACHE=/home/runner/.pub-cache
```

Then run the flutter command in the same shell session.

**Why:** Replit's NixOS environment places the pub cache at `/home/runner/.pub-cache`. Flutter defaults to `~/.pub-cache` which may differ. Without PUB_CACHE set, `flutter pub get` can fail with "could not find package X in cache".

**Known issue:** The `open_file` package is sometimes missing from the offline cache. `flutter pub get --offline` will fail with "could not find package open_file in cache". Use network mode (no --offline flag) to fetch it.

**How to apply:** Any time `flutter pub get` or `flutter build web` is needed:
```bash
PUB_CACHE=/home/runner/.pub-cache flutter pub get
PUB_CACHE=/home/runner/.pub-cache flutter build web
```
