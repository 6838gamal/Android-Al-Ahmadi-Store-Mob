---
name: OTP phone normalisation — must include +prefix variant
description: _normalise_phone() in auth.py must always include +967XXXXXXXXX form; users stored with leading + weren't matched; also 0XXXXXXXXX needs special handling.
---

## The Rule
`_normalise_phone(p)` must always produce variants that include the original form AND `+967XXXXXXXXX` regardless of input format.

## Why
Users are stored with `phone="+967XXXXXXXXX"` (Flutter sends + prefix). The old `_normalise_phone` stripped the leading `+` and never re-added it, so queries like `WHERE phone IN (variants)` never matched.

## Current Logic (correct)
```python
def _normalise_phone(p: str) -> list[str]:
    p = p.strip()
    variants = [p]                # always keep original
    stripped = p.lstrip("+")
    if stripped != p:
        variants.append(stripped)  # +967... → also add without +
    else:
        variants.append("+" + p)   # bare → also add with +

    for prefix in ("967", "00967"):
        if stripped.startswith(prefix):
            local = stripped[len(prefix):]
            variants += [local, "0"+local, "967"+local, "+967"+local]

    if not stripped.startswith("0") and len(stripped) == 9:
        variants += ["0"+stripped, "967"+stripped, "+967"+stripped]

    # 10-digit with leading 0 (0770887247) → strip 0, add 967
    if stripped.startswith("0") and len(stripped) == 10:
        local = stripped[1:]
        variants += [local, "967"+local, "+967"+local]

    return list(dict.fromkeys(variants))
```

## How to Apply
Any endpoint that searches a user by phone (verify-otp, reset-password, login) should iterate over `_normalise_phone(phone)` variants. Any time you add new phone-based lookups, use this function.
