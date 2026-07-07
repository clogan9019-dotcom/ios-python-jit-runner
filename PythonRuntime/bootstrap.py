"""Bootstrap for the embedded iOS Python runtime."""
from __future__ import annotations

import os
import sys
from pathlib import Path


def configure_site_packages(app_documents: str) -> None:
    site_packages = Path(app_documents) / "site-packages"
    site_packages.mkdir(parents=True, exist_ok=True)
    if str(site_packages) not in sys.path:
        sys.path.insert(0, str(site_packages))


def run_user_code(code: str, filename: str = "<user>") -> dict:
    namespace = {"__name__": "__main__", "__file__": filename}
    compiled = compile(code, filename, "exec")
    exec(compiled, namespace, namespace)
    return {"ok": True}
