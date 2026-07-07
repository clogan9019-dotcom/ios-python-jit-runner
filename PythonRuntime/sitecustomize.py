"""sitecustomize for app-sandbox packages."""
from __future__ import annotations

import os
import sys

extra = os.environ.get("IPYRUNNER_SITE_PACKAGES")
if extra and extra not in sys.path:
    sys.path.insert(0, extra)
