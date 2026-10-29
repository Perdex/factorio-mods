"""Checks that every name and description the player can see resolves to a
locale key, the way the game falls back between them.

Reads two `--dump-data` prototype dumps, one with the mod and a baseline with
the base game alone, and the locale files. Checked in each dump: every
localised string set anywhere in a prototype (names, descriptions, trigger
descriptions); the default names of the mod's own visible prototypes
(ttc-*), of visible items and the entities they place, of visible recipes,
technologies, fluids and mod settings. Keys the base game alone already
misses are left out. Also the locale keys the mod's Lua sources use: string
literals shaped like the mod's keys ("ttc.x", "ttc-status.y"), statuses and
refund reasons named at their call sites, and the keys built from the shared
config (listed by tests/locale_keys.lua, read from --runtime-keys).

Usage: python3 check_locale.py --dump mod.json --baseline base.json
         --base-locale core.cfg base.cfg --mod-locale mod.cfg... --sources src
         --runtime-keys keys.txt
Prints each missing key and exits 1 if there are any.
"""
import argparse
import json
import os
import re
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--dump", required=True)
parser.add_argument("--baseline", required=True)
parser.add_argument("--base-locale", nargs="+", required=True)
parser.add_argument("--mod-locale", nargs="+", required=True)
parser.add_argument("--sources", required=True)
parser.add_argument("--runtime-keys", required=True)
options = parser.parse_args()


def read_keys(paths):
    keys = set()
    for path in paths:
        section = ""
        with open(path, encoding="utf-8-sig") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith((";", "#")):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    section = line[1:-1]
                elif "=" in line:
                    key = line.split("=", 1)[0]
                    keys.add(f"{section}.{key}" if section else key)
    return keys


ITEM_TYPES = {
    "item", "ammo", "armor", "blueprint", "blueprint-book", "capsule", "copy-paste-tool", "deconstruction-item",
    "gun", "item-with-entity-data", "item-with-inventory", "item-with-label", "item-with-tags", "module",
    "rail-planner", "repair-tool", "selection-tool", "spidertron-remote", "tool", "upgrade-item",
    "space-platform-starter-pack",
}
SETTING_TYPES = {"bool-setting", "int-setting", "double-setting", "string-setting", "color-setting"}
# Prototypes that aren't entities, or whose names never show.
NOT_ENTITIES = ITEM_TYPES | SETTING_TYPES | {
    "recipe", "technology", "fluid", "tile", "quality", "space-location", "planet", "surface-property",
    "utility-constants", "utility-sounds", "utility-sprites", "map-settings", "map-gen-presets", "gui-style",
    "font", "mouse-cursor", "god-controller", "editor-controller", "spectator-controller", "remote-controller",
    "noise-expression", "noise-function", "custom-event", "sprite", "sound", "ambient-sound",
    "tips-and-tricks-item-category", "tips-and-tricks-item", "trigger-target-type", "collision-layer",
    "airborne-pollutant", "impact-category", "deliver-category", "deliver-impact-combination", "particle",
    "optimized-particle", "optimized-decorative", "shortcut", "custom-input", "virtual-signal", "item-group",
    "item-subgroup", "recipe-category", "resource-category", "fuel-category", "module-category",
    "ammo-category", "equipment-category", "equipment-grid", "damage-type", "autoplace-control", "mod-data",
    "achievement", "tutorial", "surface", "procession", "procession-layer-inheritance-group",
    "burner-usage", "chain-active-trigger", "delayed-active-trigger", "active-trigger",
}


def find_missing(raw, keys):
    """Missing locale key -> where it is used."""
    missing = {}

    def report(key, where):
        missing.setdefault(key, set()).add(where)

    def check_localised(value, where):
        if isinstance(value, list) and value:
            head = value[0]
            if isinstance(head, str) and head and "." in head and head not in keys:
                report(head, where)
            for part in value[1:]:
                check_localised(part, where)

    def walk(value, where, field=""):
        """Localised strings anywhere in a prototype: in fields named like
        localised_name or trigger_description."""
        if isinstance(value, dict):
            for key, child in value.items():
                walk(child, where, key)
        elif isinstance(value, list):
            if field.startswith("localised_") or field.endswith("_description"):
                check_localised(value, where)
            else:
                for child in value:
                    walk(child, where, field)

    def find(type_names, name):
        for type_name in type_names:
            prototype = raw.get(type_name, {}).get(name)
            if prototype:
                return prototype
        return None

    entity_types = [t for t in raw if t not in NOT_ENTITIES]

    def resolves(kind, name, prototype, seen=()):
        if (kind, name) in seen:
            return False
        seen = seen + ((kind, name),)
        if prototype.get("localised_name") is not None:
            return True  # checked by walk()
        if kind == "item":
            if f"item-name.{name}" in keys:
                return True
            place = prototype.get("place_result")
            entity = place and find(entity_types, place)
            if entity:
                return resolves("entity", place, entity, seen)
            tile = (prototype.get("place_as_tile") or {}).get("result")
            if tile and f"tile-name.{tile}" in keys:
                return True
            equipment = prototype.get("place_as_equipment_result")
            return bool(equipment and f"equipment-name.{equipment}" in keys)
        if kind == "recipe":
            if f"recipe-name.{name}" in keys:
                return True
            results = prototype.get("results") or []
            main = prototype.get("main_product") or (results[0]["name"] if len(results) == 1 else None)
            if not main:
                return False
            product = next((r for r in results if r["name"] == main), {"type": "item"})
            if product.get("type") == "fluid":
                fluid = find(["fluid"], main)
                return bool(fluid) and resolves("fluid", main, fluid, seen)
            item = find(ITEM_TYPES, main)
            return bool(item) and resolves("item", main, item, seen)
        if kind == "technology":
            return (f"technology-name.{name}" in keys
                    or f"technology-name.{re.sub(r'-[0-9]+$', '', name)}" in keys)
        return f"{kind}-name.{name}" in keys

    for type_name, prototypes in raw.items():
        if type_name in ITEM_TYPES:
            kind = "item"
        elif type_name in SETTING_TYPES:
            kind = "mod-setting"
        elif type_name in ("recipe", "technology", "fluid", "tile"):
            kind = type_name
        elif type_name not in NOT_ENTITIES:
            kind = "entity"
        else:
            kind = None
        for name, prototype in prototypes.items():
            where = f"{type_name} {name}"
            walk(prototype, where)
            if not kind or prototype.get("hidden") or prototype.get("parameter"):
                continue
            if kind == "entity" and not name.startswith("ttc-"):
                continue  # base entities: checked through the items placing them
            if not resolves(kind, name, prototype):
                report(f"{kind}-name.{name}", where)
    return missing


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


base_keys = read_keys(options.base_locale)
missing = find_missing(load(options.dump), base_keys | read_keys(options.mod_locale))
for key in find_missing(load(options.baseline), base_keys):
    missing.pop(key, None)

keys = base_keys | read_keys(options.mod_locale)


def require_key(key, where):
    if key not in keys:
        missing.setdefault(key, set()).add(where)


# Keys in the Lua sources: whole string literals shaped like a key, in a base
# section ({"item-name.x"}) or one of the mod's ("ttc.x", "ttc-status.y"),
# but not the start of a key built with `..`; and the parts the sources
# complete at run time.
literal = re.compile(r'"((?:ttc[a-z-]*|[a-z-]+-name|[a-z-]+-description)\.[A-Za-z0-9_-]+)"(?!\s*\.\.)')
built = [
    (re.compile(r'set_status\([^,()]+,\s*"([a-z-]+)"'), "ttc-status."),
    (re.compile(r'refund\([^()]*"([a-z-]+)"\)'), "ttc.transfer-"),
    (re.compile(r'return nil, "([a-z-]+)"'), "ttc."),
]
for root, _, files in os.walk(options.sources):
    for file_name in sorted(files):
        if file_name.endswith(".lua"):
            path = os.path.join(root, file_name)
            with open(path, encoding="utf-8") as f:
                for number, line in enumerate(f, 1):
                    where = f"{os.path.relpath(path, options.sources)}:{number}"
                    for key in literal.findall(line):
                        require_key(key, where)
                    for pattern, prefix in built:
                        for part in pattern.findall(line):
                            require_key(prefix + part, where)
with open(options.runtime_keys, encoding="utf-8") as f:
    for line in f:
        if line.strip():
            require_key(line.strip(), "shared config")

for key in sorted(missing):
    print(f"missing {key}  ({', '.join(sorted(missing[key])[:3])})")
print(f"{len(missing)} missing locale keys")
sys.exit(1 if missing else 0)
