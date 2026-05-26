---
name: Backend workflow must bind 0.0.0.0
description: Replit workflow port detection requires 0.0.0.0 binding, not localhost
---

**Rule:** Always run uvicorn with `host="0.0.0.0"` in Replit workflows that declare a port.

```python
uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
```

**Why:** Replit's workflow system probes for open ports externally. If the server binds only to `localhost`/`127.0.0.1`, the probe fails and the workflow is marked as "failed" even though the server is actually running.
