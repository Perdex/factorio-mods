"""Checks that no recipe unlocks before its ingredients can be had.

Simulates progression floor by floor (the starting surface is floor 0) from a
`--dump-data` prototype dump and the mod's config (tests/progression_export.lua):

- What can be had: the crash site kit, wood, stone and coal from the
  surface's trees and rocks, water once an offshore pump can be built, each
  reached floor's wall and vein drops (a hot floor only with a coolant bore
  and its coolant), the drops of the shaft dug from it, vein resources such
  as crude oil once something can mine them, and the products of every
  enabled recipe whose ingredients can be had and that something can craft.
- When technologies unlock: on reaching a floor, a discovery (the item dug
  up on its floor), halfway down a shaft, or the game's own craft, build and
  mine triggers. Technologies that still cost science never unlock.

A recipe unlocked on a floor where its ingredients can't all be had yet is
reported, with the floor where the missing ones turn up (if any).

Usage: python3 check_unlocks.py --dump data-raw-dump.json --config config.json
Exits 1 if anything is reported.
"""
import argparse
import json
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--dump", required=True)
parser.add_argument("--config", required=True)
options = parser.parse_args()

with open(options.dump, encoding="utf-8") as f:
    raw = json.load(f)
with open(options.config, encoding="utf-8") as f:
    config = json.load(f)
layers = config["layers"]

# What the game hands out at the start, and what the surface itself offers.
START = {"ttc-core-drill", "ttc-wooden-drill-head", "coal", "wood", "stone"}
# Dig recipes only list their drops for the output slots; drops are modelled
# from the floors instead.
SKIPPED_CATEGORIES = {"ttc-dig", "ttc-shaft"}


def names(entries):
    return [entry["name"] for entry in entries or []]


def item_name(value):
    return value["name"] if isinstance(value, dict) else value


recipes = {name: r for name, r in raw["recipe"].items() if not r.get("hidden") and not r.get("parameter")}


def recipe_categories(recipe):
    return recipe.get("categories") or [recipe.get("category", "crafting")]


# Which crafting categories each item's entity brings (machines, the player).
crafter_types = ["assembling-machine", "furnace", "rocket-silo"]
category_items = {}
for type_name in crafter_types:
    for name, entity in raw.get(type_name, {}).items():
        for category in entity.get("crafting_categories", []):
            category_items.setdefault(category, set()).add(name)
item_places = {}
for type_name, prototypes in raw.items():
    for name, prototype in prototypes.items():
        if isinstance(prototype, dict) and prototype.get("place_result"):
            item_places.setdefault(prototype["place_result"], set()).add(name)
hand_categories = set(raw["character"]["character"].get("crafting_categories", ["crafting"]))

# Scripted technologies: what fires them.
scripted = {}
for index, layer in enumerate(layers, 1):
    for technology in layer.get("reached_unlocks", []):
        scripted[technology] = ("floor", index)
    for unlock in layer.get("unlocks", []):
        scripted[unlock["technology"]] = ("dug", index, unlock["item"])
    for unlock in layer.get("shaft", {}).get("unlocks", []):
        scripted[unlock["technology"]] = ("floor", index - 1)
for technology, trigger in config["triggers"].items():
    if "floor" in trigger:
        scripted[technology] = ("floor", trigger["floor"])
    elif "discover" in trigger:
        scripted[technology] = ("discover", trigger["discover"])


def floor_drops(floor):
    """Items dug from a floor's walls and veins, and resources in its veins."""
    layer = layers[floor - 1]
    items = set(names(layer.get("drops")))
    resources = set()
    for vein in layer.get("veins", []):
        items |= set(names(vein.get("drops")))
        if vein.get("resource"):
            resources.add(vein["resource"]["name"])
    return items, resources


have = set(START)  # items and fluids that can be had
enabled = {name for name, r in recipes.items() if r.get("enabled", True) is not False}
researched = set()
first_floor = {name: 0 for name in have}  # where each thing can first be had
unlocked_on = {}  # recipe -> (floor, technology)
too_early = {}  # recipe -> (floor, technology, missing ingredients)


def craftable(recipe):
    categories = recipe_categories(recipe)
    if any(c in SKIPPED_CATEGORIES for c in categories):
        return False
    if not any(c in hand_categories or any(i in have for e in category_items.get(c, ()) for i in item_places.get(e, ()))
               for c in categories):
        return False
    return all(name in have for name in names(recipe.get("ingredients")))


def can_place(entity):
    return any(item in have for item in item_places.get(entity, ()))


def trigger_fires(name, technology, floor, dug):
    if name in scripted:
        kind = scripted[name]
        if kind[0] == "floor":
            return floor >= kind[1]
        if kind[0] == "dug":
            return floor >= kind[1] and kind[2] in dug
        return kind[1] in dug
    trigger = technology.get("research_trigger")
    if not trigger or technology.get("unit"):
        return False
    if not all(p in researched for p in technology.get("prerequisites", [])):
        return False
    kind = trigger.get("type")
    if kind == "craft-item":
        item = item_name(trigger["item"])
        return any(item in names(recipes[r].get("results")) for r in enabled if r in recipes
                   and craftable(recipes[r]))
    if kind == "craft-fluid":
        fluid = item_name(trigger["fluid"])
        return any(fluid in names(recipes[r].get("results")) for r in enabled if r in recipes
                   and craftable(recipes[r]))
    if kind == "build-entity":
        return can_place(item_name(trigger["entity"]))
    if kind == "mine-entity":
        entities = trigger.get("entities") or [trigger.get("entity")]
        return any(item_name(entity) in mined for entity in entities)
    return False


technologies = {name: t for name, t in raw["technology"].items()
                if not t.get("hidden") and t.get("enabled", True) is not False}
mined = set()
for floor in range(0, len(layers) + 1):
    dug, resources = set(), set()
    if floor >= 1:
        layer = layers[floor - 1]
        if not layer.get("needs_coolant") or ("ttc-mk3-bore" in have and "ttc-coolant" in have):
            dug, resources = floor_drops(floor)
    if floor < len(layers):
        dug |= set(names(layers[floor]["shaft"].get("drops")))
    changed = True
    while changed:
        changed = False
        new = set(dug)
        if "offshore-pump" in have:
            new.add("water")
        for resource in resources:
            if resource == "crude-oil" and can_place("pumpjack"):
                new.add("crude-oil")
                mined.add("crude-oil")
        for name in enabled:
            recipe = recipes.get(name)
            if recipe and craftable(recipe):
                new |= set(names(recipe.get("results")))
        for thing in new - have:
            have.add(thing)
            first_floor[thing] = floor
            changed = True
        for name, technology in technologies.items():
            if name not in researched and trigger_fires(name, technology, floor, dug):
                researched.add(name)
                changed = True
                for effect in technology.get("effects", []):
                    if effect.get("type") == "unlock-recipe" and effect["recipe"] not in enabled:
                        enabled.add(effect["recipe"])
                        unlocked_on[effect["recipe"]] = (floor, name)
    # Check what this floor unlocked against everything it can provide.
    for recipe_name, (unlock_floor, technology) in unlocked_on.items():
        if unlock_floor != floor or recipe_name not in recipes:
            continue
        missing = [n for n in names(recipes[recipe_name].get("ingredients")) if n not in have]
        if missing:
            too_early[recipe_name] = (floor, technology, missing)

problems = []
for recipe_name, (floor, technology, missing) in sorted(too_early.items()):
    later = ", ".join(f"{n} (floor {first_floor[n]})" if n in first_floor else f"{n} (never)" for n in missing)
    problems.append(f"{recipe_name}: unlocked by {technology} on floor {floor}, before {later}")

for line in problems:
    print(line)
print(f"{len(researched)} technologies reachable, {len(problems)} recipes unlocked too early")
sys.exit(1 if problems else 0)
