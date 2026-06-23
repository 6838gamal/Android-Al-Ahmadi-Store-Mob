import sys
import os

# Ensure .pythonlibs is on the path (Replit environment)
_pythonlibs = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".pythonlibs", "lib", "python3.11", "site-packages")
if os.path.isdir(_pythonlibs) and _pythonlibs not in sys.path:
    sys.path.insert(0, _pythonlibs)

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "backend.main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
    )
