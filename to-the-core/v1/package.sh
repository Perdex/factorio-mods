#!/usr/bin/env bash
# Builds the mod portal zip, dist/<name>_<version>.zip, from src: everything
# under one <name>_<version>/ folder, minus the development notes and hidden
# files. Name and version come from src/info.json.
set -euo pipefail
v1="$(cd "$(dirname "$0")" && pwd)"

python3 -I - "$v1/src" "$v1/dist" <<'PY'
import json, os, sys, zipfile

src, dist = sys.argv[1], sys.argv[2]
excluded = {"TODO.md", "FLOORS.md"}

with open(os.path.join(src, "info.json")) as f:
    info = json.load(f)
folder = f"{info['name']}_{info['version']}"
os.makedirs(dist, exist_ok=True)
target = os.path.join(dist, folder + ".zip")
if os.path.exists(target):
    sys.exit(f"{target} exists; raise the version in info.json or delete it.")

count = 0
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(files):
            if name.startswith(".") or name in excluded:
                continue
            path = os.path.join(root, name)
            archive.write(path, os.path.join(folder, os.path.relpath(path, src)))
            count += 1
print(f"Wrote {target}: {count} files, {os.path.getsize(target) / 1e6:.1f} MB")
PY
