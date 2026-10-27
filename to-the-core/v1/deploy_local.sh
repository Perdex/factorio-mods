#!/usr/bin/env bash
# Links the mod into the local Factorio mods directory, so the game always runs
# the working copy. Factorio accepts an unversioned "to-the-core" folder.
set -euo pipefail
mods_dir="${FACTORIO_MODS:-$HOME/.factorio/mods}"
source_dir="$(cd "$(dirname "$0")/to-the-core" && pwd)"
target="$mods_dir/to-the-core"

if [ -e "$target" ] && [ ! -L "$target" ]; then
  echo "$target exists and is not a symlink; remove it first." >&2
  exit 1
fi
ln -sfn "$source_dir" "$target"
echo "Linked $target -> $source_dir"
