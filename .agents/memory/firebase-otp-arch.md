---
name: Firebase phone OTP architecture
description: How Firebase phone auth OTP is integrated across the Flutter Web + backend stack
---

# Firebase Phone OTP Architecture

## Overview
Phone OTP verification uses Firebase Auth (Web SDK) bridged to Flutter via JS interop.

## Key files
- `build/web/index.html` — loads Firebase compat SDK 10.12.2, defines `window.firebasePhoneAuth` with `init/sendOtp/verifyOtp` methods; invisible reCAPTCHA div `#recaptcha-container` required
- `server.js` — serves `/firebase-config` endpoint; reads keys from env vars `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`; never hardcodes keys
- `lib/core/services/firebase_phone_service.dart` — Dart service that fetches config from `/firebase-config`, then calls JS bridge
- `lib/core/services/firebase_js_bridge.dart` — stub for non-web (returns unsupported)
- `lib/core/services/firebase_js_bridge_web.dart` — web impl using `dart:js_util` + polling pattern (window[cbKey] set by JS, read by Dart every 100ms, max 60s)
- `lib/features/auth/presentation/pages/phone_otp_page.dart` — dual-mode page (mode='verify' marks user verified, mode='login' logs in via OTP)
- `backend/api/routes/auth.py` — two endpoints: `POST /auth/verify-phone` (requires auth token, marks is_verified=True) and `POST /auth/verify-phone-login` (no auth required, finds user by phone variants, returns app JWT)

## Flow
1. Flutter fetches `/firebase-config` → gets Firebase keys
2. Dart calls `jsBridgeCall('init', config)` → JS initialises Firebase app
3. User enters phone → `jsBridgeCall('sendOtp', {phone})` → JS creates RecaptchaVerifier + calls `signInWithPhoneNumber`
4. User enters 6-digit code → `jsBridgeCall('verifyOtp', {code})` → JS calls `confirmationResult.confirm(code)` → returns Firebase ID token
5. Flutter POSTs ID token to backend endpoint
6. Backend calls Firebase REST `accounts:lookup` to validate token, extracts phone number, matches to user

## JS bridge polling pattern
JS writes result to `window[cbKey]`, Dart polls every 100ms. Avoids dart:js deprecated APIs while staying compatible with Flutter Web build.

**Why:** `dart:js` is deprecated in Dart 3. `dart:js_interop` (Dart 3 native) can't easily await JS Promises in the compat SDK style. The polling pattern is reliable and works with any JS Promise result.

## Phone number normalisation
Backend strips `+`, `967`, `00967`, leading `0` to compare local number formats. Tries multiple variants when looking up user by phone.

## Security
- Firebase project ID: `android-al-ahmadi-store`
- Auth domain must be whitelisted in Firebase Console → Authentication → Settings → Authorized domains
- reCAPTCHA is invisible — user sees no challenge for legitimate traffic
