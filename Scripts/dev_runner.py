#!/usr/bin/env python3
"""Desktop mock runner for iOS Python Runner development."""
from __future__ import annotations

import argparse
import os
import runpy
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / ".local_runner"
SITE = LOCAL / "site-packages"


def ensure_site() -> None:
    SITE.mkdir(parents=True, exist_ok=True)
    if str(SITE) not in sys.path:
        sys.path.insert(0, str(SITE))
    os.environ["PYTHONPATH"] = str(SITE) + os.pathsep + os.environ.get("PYTHONPATH", "")


def run_script(path: str) -> int:
    ensure_site()
    script = Path(path)
    if not script.is_absolute():
        script = ROOT / script
    if not script.exists():
        print(f"Script not found: {script}", file=sys.stderr)
        return 2
    runpy.run_path(str(script), run_name="__main__")
    return 0


def pip_cmd(args: list[str]) -> int:
    ensure_site()
    cmd = [sys.executable, "-m", "pip", *args]
    if args and args[0] == "install":
        cmd = [sys.executable, "-m", "pip", "install", "--target", str(SITE), *args[1:]]
    return subprocess.call(cmd, cwd=ROOT)


def main() -> int:
    parser = argparse.ArgumentParser(description="Desktop mock runner for iOS Python Runner")
    sub = parser.add_subparsers(dest="cmd", required=True)

    run_p = sub.add_parser("run", help="Run a Python script with local site-packages")
    run_p.add_argument("script")

    pip_p = sub.add_parser("pip", help="Run pip against .local_runner/site-packages")
    pip_p.add_argument("pip_args", nargs=argparse.REMAINDER)

    args = parser.parse_args()
    if args.cmd == "run":
        return run_script(args.script)
    if args.cmd == "pip":
        return pip_cmd(args.pip_args)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
