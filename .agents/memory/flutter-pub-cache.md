---
name: Flutter pub cache path
description: Replit stores the Dart/Flutter pub cache in the parent directory of the workspace, not ~/.pub-cache. Must set PUB_CACHE before any flutter pub get or build.
---

## Rule

Before running `flutter pub get` or `flutter build web`, set:

```bash
export PUB_CACHE=$(realpath ../.pub-cache)
```

Then run the flutter command in the same shell session.

**Why:** Replit's NixOS environment places the pub cache at `../.pub-cache` relative to the workspace root (i.e. one level up). Flutter defaults to `~/.pub-cache` which either doesn't exist or is empty. Without PUB_CACHE set, `flutter pub get` fails with "could not find package X in cache" and `flutter build web` errors with "Error when reading '../.pub-cache/hosted/pub.dev/...'".

**How to apply:** Any time `flutter pub get` or `flutter build web --release` is needed, prefix with the export above. The packages DO exist at `../.pub-cache/hosted/pub.dev/`; the issue is purely the path env var.
