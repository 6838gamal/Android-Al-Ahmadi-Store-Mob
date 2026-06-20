---
name: SMS gateway sending
description: How to reliably send SMS via sms-gateway.app from the Python backend on Replit
---

# SMS Gateway Sending

## The rule
Use `subprocess curl` (not `httpx` or `urllib`) to call sms-gateway.app. Strip `+` prefix from phone numbers (replace `+967` with `00967`). Ensure `sms_devices` in AppSetting DB is a numeric device ID, not a phone number.

**Why:**
- sms-gateway.app is behind Cloudflare, which blocks Python HTTP clients (urllib returns 403, httpx returns 403) due to TLS fingerprint detection. `curl` has a trusted TLS fingerprint that passes.
- Phone numbers with `+` prefix (e.g. `+967774440982`) cause "Please use a valid Mobile Number" error. Use `00967774440982` format instead.
- `sms_devices` AppSetting was incorrectly set to `+967774440982` (a phone number). The field must contain the numeric device ID assigned by sms-gateway.app (found in successful API responses as `deviceID`, e.g. `11209`). Passing a phone number as device ID causes "Invalid request format."

**How to apply:**
- `_normalise_phone_for_gateway()` converts `+967...` → `00967...`
- `_send_sms()` uses `subprocess.run(["curl", "-s", "-d", f"key=...", "-d", f"number={gw_phone}", ...])` — separate `-d` flags, raw UTF-8, no URL-encoding
- Newlines in messages must be replaced with spaces before sending (sms-gateway.app rejects multi-line via `-d`)
- Device ID 11209 is the active device in the account (as of June 2026)
- JSON parsing: gateway appends PHP exception text after JSON on errors; extract JSON with `raw[:raw.rfind("}")+1]`
