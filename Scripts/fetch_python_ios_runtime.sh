#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/Frameworks" "$ROOT/iPyRunner/python"

if [ -d "$ROOT/Frameworks/Python.xcframework" ]; then
  echo "Frameworks/Python.xcframework already exists."
  exit 0
fi

# Use a known stable BeeWare iOS support asset by default. You can override this in Actions with
# PYTHON_IOS_SUPPORT_URL if needed.
DEFAULT_URL="https://github.com/beeware/Python-Apple-support/releases/download/3.13-b14/Python-3.13-iOS-support.b14.tar.gz"
URL="${PYTHON_IOS_SUPPORT_URL:-}"

if [ -z "$URL" ]; then
  echo "Resolving latest stable Python iOS support asset..."
  URL="$(python3 - <<'PY' || true
import json, urllib.request
try:
    with urllib.request.urlopen('https://api.github.com/repos/beeware/Python-Apple-support/releases?per_page=20', timeout=30) as r:
        data=json.load(r)
    # Prefer 3.13 over 3.14 beta for iOS app stability.
    for preferred in ('3.13', '3.12', '3.11'):
        for rel in data:
            for asset in rel.get('assets', []):
                name=asset.get('name','')
                if f'Python-{preferred}-iOS-support' in name and name.endswith('.tar.gz'):
                    print(asset['browser_download_url'])
                    raise SystemExit(0)
except Exception:
    pass
PY
)"
fi

if [ -z "$URL" ]; then
  URL="$DEFAULT_URL"
fi

echo "Downloading Python iOS support from: $URL"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl --fail --location --retry 3 --retry-delay 2 "$URL" -o "$TMP/python-ios-support.tar.gz"

echo "Checking archive..."
tar -tzf "$TMP/python-ios-support.tar.gz" >/dev/null

echo "Extracting archive..."
tar -xzf "$TMP/python-ios-support.tar.gz" -C "$TMP"

PY_XC="$(find "$TMP" -name Python.xcframework -type d | head -1)"
if [ -z "$PY_XC" ]; then
  echo "Could not find Python.xcframework in archive" >&2
  find "$TMP" -maxdepth 4 -type d | sort >&2
  exit 1
fi
cp -R "$PY_XC" "$ROOT/Frameworks/Python.xcframework"
echo "Installed Frameworks/Python.xcframework"

# Best-effort PYTHONHOME resource. Prefer the physical iPhone/device slice, not simulator.
IOS_SLICE="$(find "$ROOT/Frameworks/Python.xcframework" -maxdepth 1 -type d -name 'ios-arm64' | head -1 || true)"
if [ -z "$IOS_SLICE" ]; then
  IOS_SLICE="$(find "$ROOT/Frameworks/Python.xcframework" -maxdepth 1 -type d -name '*ios-arm64*' ! -name '*simulator*' | head -1 || true)"
fi
if [ -z "$IOS_SLICE" ]; then
  IOS_SLICE="$(find "$ROOT/Frameworks/Python.xcframework" -maxdepth 1 -type d -name '*ios*' | head -1 || true)"
fi

if [ -n "$IOS_SLICE" ] && [ -d "$IOS_SLICE/lib" ]; then
  rm -rf "$ROOT/iPyRunner/python"
  mkdir -p "$ROOT/iPyRunner/python"
  cp -R "$IOS_SLICE/lib" "$ROOT/iPyRunner/python/lib"
  echo "Copied Python stdlib/resource files from $(basename "$IOS_SLICE") to iPyRunner/python"
else
  echo "Warning: Could not locate iOS slice lib directory for PYTHONHOME resource." >&2
  find "$ROOT/Frameworks/Python.xcframework" -maxdepth 2 -type d | sort >&2
  exit 1
fi
