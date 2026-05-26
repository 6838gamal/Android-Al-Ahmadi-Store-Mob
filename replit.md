# Flutter Hello World

A basic Flutter web application showing "Hello, World!" built with Flutter 3.32.0 and Dart 3.8.0.

## Project Structure

- `lib/main.dart` — Flutter app source code
- `build/web/` — Compiled Flutter web output (served in development)
- `server.js` — Node.js static file server (serves `build/web/` on port 5000)
- `pubspec.yaml` — Flutter project manifest and dependencies

## Running the App

The workflow `Start application` runs `node server.js` which serves the pre-built Flutter web output on port 5000.

If you modify `lib/main.dart`, rebuild the web output first:

```bash
flutter build web --release
```

Then restart the workflow to serve the new build.

## Tech Stack

- **Framework**: Flutter 3.32.0
- **Language**: Dart 3.8.0
- **Platforms**: Web (served via Node.js static server)
- **Package manager**: pub (Flutter)

## User Preferences

(Add your preferences here)
