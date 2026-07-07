#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/Frameworks" "$ROOT/iPyRunner/python"

if [ -d "$ROOT/Frameworks/Python.xcframework" ]; then
  echo "Frameworks/Python.xcframework already exists."
  exit 0
fi

API="https://api.github.com/repos/beeware/Python-Apple-support/releases/latest"
URL="$(python3 - <<'PY'
import json, urllib.request
with urllib.request.urlopen('https://api.github.com/repos/beeware/Python-Apple-support/releases/latest', timeout=30) as r:
    data=json.load(r)
for asset in data.get('assets', []):
    name=asset.get('name','')
    if 'iOS-support' in name and name.endswith('.tar.gz'):
        print(asset['browser_download_url'])
        break
else:
    raise SystemExit('No iOS support asset found')
PY
)"

echo "Downloading Python iOS support from: $URL"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -L "$URL" -o "$TMP/python-ios-support.tar.gz"
tar -xzf "$TMP/python-ios-support.tar.gz" -C "$TMP"

PY_XC="$(find "$TMP" -name Python.xcframework -type d | head -1)"
if [ -z "$PY_XC" ]; then
  echo "Could not find Python.xcframework in archive" >&2
  find "$TMP" -maxdepth 3 -type d | sort >&2
  exit 1
fi
cp -R "$PY_XC" "$ROOT/Frameworks/Python.xcframework"
echo "Installed Frameworks/Python.xcframework"

# Best-effort PYTHONHOME resource. BeeWare's iOS framework slices contain lib/pythonX.Y.
IOS_SLICE="$(find "$ROOT/Frameworks/Python.xcframework" -type d \( -name '*ios-arm64*' -o -name '*iphoneos*' \) | head -1 || true)"
if [ -n "$IOS_SLICE" ] && [ -d "$IOS_SLICE/lib" ]; then
  rm -rf "$ROOT/iPyRunner/python"
  mkdir -p "$ROOT/iPyRunner/python"
  cp -R "$IOS_SLICE/lib" "$ROOT/iPyRunner/python/lib"
  echo "Copied Python stdlib/resource files to iPyRunner/python"
else
  echo "Warning: Could not locate iOS slice lib directory for PYTHONHOME resource."
fi
