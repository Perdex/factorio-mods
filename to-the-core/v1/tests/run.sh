#!/usr/bin/env bash
# Headless engine test: creates a map with to-the-core plus the ttc-test mod,
# runs it with --benchmark and prints the test's "TTC" log lines and errors.
# Uses its own write-data directory, so the normal Factorio profile is untouched.
#
# Usage: tests/run.sh [ticks]   (FACTORIO_BIN overrides the game binary)
set -euo pipefail
ticks="${1:-6010}"
factorio="${FACTORIO_BIN:-/mnt/games/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
v1="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/mods" "$work/write"
ln -s "$v1/to-the-core" "$work/mods/to-the-core"
ln -s "$v1/tests/ttc-test" "$work/mods/ttc-test"
cat > "$work/mods/mod-list.json" <<JSON
{"mods":[{"name":"base","enabled":true},{"name":"to-the-core","enabled":true},{"name":"ttc-test","enabled":true},
{"name":"space-age","enabled":false},{"name":"quality","enabled":false},{"name":"elevated-rails","enabled":false},{"name":"recycler","enabled":false}]}
JSON
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$work/write" > "$work/config.ini"

run() { "$factorio" -c "$work/config.ini" --mod-directory "$work/mods" --disable-audio "$@" 2>&1; }
run --create "$work/test.zip" | grep -iA6 "error" && exit 1
run --benchmark "$work/test.zip" --benchmark-ticks "$ticks" \
  | grep -iE "TTC|error|traceback|__.*\.lua" | sed 's/.*Script @__ttc-test__\/control.lua:[0-9]*: //'
