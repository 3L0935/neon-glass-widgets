#!/usr/bin/env bash
# Pack each widget as a .plasmoid (a zip of the package) for a release / the KDE Store: dist/<id>-<version>.plasmoid
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/tools/sync-shared.sh" >/dev/null
mkdir -p "$ROOT/dist"
for pkg in player monitor clock; do
  version="$(sed -n 's/.*"Version": "\(.*\)".*/\1/p' "$ROOT/$pkg/metadata.json")"
  out="$ROOT/dist/neon-glass-$pkg-$version.plasmoid"
  rm -f "$out"
  python3 -I - "$ROOT/$pkg" "$out" <<'PY'
import sys, zipfile
from pathlib import Path
src, out = Path(sys.argv[1]), sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted([src / "metadata.json", *(src / "contents").rglob("*")]):
        if f.is_file():
            z.write(f, f.relative_to(src))
PY
  echo "$out"
done
