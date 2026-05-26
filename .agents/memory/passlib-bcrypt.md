---
name: passlib bcrypt version compatibility
description: bcrypt 5.x breaks passlib; must pin to 4.0.1
---

passlib's bcrypt backend fails with bcrypt>=5.0.0 due to `AttributeError: module 'bcrypt' has no attribute '__about__'`.

**Rule:** Always pin `bcrypt==4.0.1` when using passlib for password hashing in Python.

Install: `pip install "bcrypt==4.0.1"`

**Why:** bcrypt 5.x removed the `__about__` module that passlib's backend introspection relies on. passlib itself hasn't released a fix for this yet.
