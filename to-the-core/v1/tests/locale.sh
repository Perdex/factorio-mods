#!/usr/bin/env bash
# Locale check: dumps the prototypes with and without the mod and reports
# every name or description that would show as an unknown key
# (tests/check_locale.py). Uses its own write-data directories, so the normal
# Factorio profile is untouched.
#
# Usage: tests/locale.sh   (FACTORIO_BIN overrides the game binary)
set -euo pipefail
factorio="${FACTORIO_BIN:-/mnt/games/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
game_data="$(cd "$(dirname "$factorio")/../../data" && pwd)"
v1="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# dump <dir> <to-the-core enabled: true|false>
dump() {
  mkdir -p "$1/mods" "$1/write"
  ln -s "$v1/src" "$1/mods/to-the-core"
  cat > "$1/mods/mod-list.json" <<JSON
{"mods":[{"name":"base","enabled":true},{"name":"to-the-core","enabled":$2},
{"name":"space-age","enabled":false},{"name":"quality","enabled":false},{"name":"elevated-rails","enabled":false},{"name":"recycler","enabled":false}]}
JSON
  printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$1/write" > "$1/config.ini"
  "$factorio" -c "$1/config.ini" --mod-directory "$1/mods" --disable-audio --dump-data > "$1/log.txt" 2>&1 \
    || { cat "$1/log.txt"; exit 1; }
}
dump "$work/mod" true
dump "$work/base" false

lua "$v1/tests/locale_keys.lua" "$v1/src" > "$work/runtime-keys.txt"
python3 -I "$v1/tests/check_locale.py" \
  --dump "$work/mod/write/script-output/data-raw-dump.json" \
  --baseline "$work/base/write/script-output/data-raw-dump.json" \
  --base-locale "$game_data/core/locale/en/core.cfg" "$game_data/base/locale/en/base.cfg" \
  --mod-locale "$v1"/src/locale/en/*.cfg \
  --sources "$v1/src" \
  --runtime-keys "$work/runtime-keys.txt"
