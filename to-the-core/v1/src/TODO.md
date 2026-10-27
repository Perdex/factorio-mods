# To the Core — TODO

Design goal (from the original brief): replace science-based progression with
digging. Start with almost nothing, dig down with core drills to new layers
(surfaces), dig sideways with tunnel bores that need a constant supply of
materials from the previous layer, and open the tech tree through trigger
technologies as new depths are reached. Levels, drops and unlocks must stay
easy to configure for balancing.

Legend: `[x]` done, `[ ]` open, `[~]` partly done / needs revisiting.

---

## 0. Known bugs / tech debt

- [x] **Underground platform could be wiped by terrain generation.** All
  tunnel/platform tiles now go through `runtime/tunnel.lua`, which generates
  the chunk first (or marks it generated when it lies outside the 1x1 layer
  map, where generation never runs). Covered by the engine test.
- [x] Removed the old-save migration hacks (`layer_surface_version`,
  `void_area(..., preserve_existing)`, origin-portal relocation). No save
  migrations until the first public release.
- [x] `deploy_local.sh` symlinks the working copy into the mods directory.
- [x] `first_layer` hard-coding removed; layers are looked up by surface
  (`runtime/layers.lua`).
- [x] Technology icon for `ttc-mk1-bore` uses the bore icon.

## 1. Tunnel bore

- [x] 2x2 footprint with proper 4-direction graphics and cutter animation.
- [x] Rotatable (via an always-on rear-left fluid box).
- [x] Burner energy source with native fuel bar; native crafting progress bar.
- [x] Dig recipes generated per layer from `shared/layers.lua`; consume drill
  head + 2 belts per tile; drops are recipe results.
- [x] Each craft is one hit on the wall; after `hits_per_tile` hits (10 on
  layer 1) it breaks through, opens the tiles, lays supply/output belt lanes
  and moves the hidden loaders along. Status shows hits and belt stock.
- [x] Paving belts are pulled off the supply lane into a belt stock of up to
  10 (returned when the bore is mined), not consumed by the dig recipe.
- [x] Placeable only at the edge of open ground facing rock, like an offshore
  pump (`tile_buildability_rules`).
- [x] Sprite frames are 4x4 tiles so the cutter head overlaps the wall ahead.
- [x] Rock-chip particles on every hit.
- [x] Pauses with a custom status when the tiles ahead are blocked.
- [ ] Verify in the real client (headless tests only so far): GUI layout,
  rotation feel, sprite alignment, shadow, working sound, alt-mode icon.
- [ ] Decide what the rear fluid box is for. Options: coolant input for deeper
  layers, or hide it with pipe covers until a fluid recipe is selected.
- [ ] Auto-switch to a better dig recipe when one is unlocked (currently the
  player has to change it in the GUI), or at least notify the player.
- [ ] Hide recipes of other layers from the bore's recipe picker (currently
  they are selectable and only rejected with a "wrong layer" status).
- [ ] Hit sound effect.
- [x] Drill heads wear out like repair packs (`heads` in `shared/bore.lua`):
  wooden 10 hits at 2 s, iron 40 at 0.5 s, reinforced 120 at 0.25 s. One dig
  craft is one head's life; hits accrue continuously from crafting progress
  and drops are paid out per head as a range around the expected amount.
- [x] Layer 1 is clay (40 hits/tile, ~1 iron head and 40 s per tile)
  yielding ~20 clay and ~6 iron ore per tile, so iron heads and belts pay for
  themselves.
- [ ] Balance check in play: wooden heads (2 wood, 1 stone, 1 blade) 4 per
  tile; iron 1 per tile; ~60 salvaged blades before iron.
- [ ] Belts that can't be laid (occupied tile) are spilled on the ground —
  consider returning them to the output lane or refunding into the bore.
- [ ] Stop condition / range: what happens at map edges or when hitting
  another tunnel? Joining tunnels should probably connect belts cleanly.
- [ ] Turning: a rotated bore mid-tunnel leaves a belt corner problem. Decide
  whether bores can turn in place, or must be picked up and re-placed.
- [ ] Optional circuit connection (read progress / enable-disable).
- [ ] Remote view / map visibility of tunnels (chart revealed tiles).
- [ ] Higher bore tiers (Mk2/Mk3): faster, wider tunnel (3-4 tiles), electric
  or fluid fuel, more output slots. Make the 2-tile geometry in
  `runtime/bore.lua` width-configurable first.
- [ ] Tunnel width option: wider tunnels for building space vs. narrow mining
  shafts.
- [ ] Sound and visual feedback when a tile is dug (particles, dust, sound).

## 2. Underground layers

See `FLOORS.md` for the plan of floors 0-5 (for review).


- [x] Runtime is layer-indexed. `upper_crust` is real; `lower_crust` is a
  placeholder (shaft needs stone bricks + reinforced heads; copper/coal drops).
- [ ] Define the full layer list in `shared/layers.lua`, e.g.
  1. Upper crust — stone, iron ore; iron drill heads.
  2. Lower crust — copper/coal; iron-copper drill heads.
  3. Mantle edge — heat; drill heads + cooling fluid.
  4. Mantle — …
  5. Core — win condition.
- [ ] Per-layer config fields to add: tunnel tile, wall tile/visual, ambient
  light/daytime, required bore tier, required fluid, dig speed modifier,
  hazards.
- [x] Wall visuals: cliff-face pieces per open side/diagonal of each rock
  tile (`ttc-tunnel-wall-<piece>`, art from `tools/wall_gfx.py`).
- [ ] Wall art polish: less regular strata, shading/AO on the floor at the
  wall base, variation per layer.
- [ ] Ore patches hidden in the walls: when a bore digs into a pre-seeded patch
  area, place resource entities in the tunnel (configurable per layer: ore,
  frequency, size, richness). Pre-generate patch locations deterministically
  per surface seed.
- [ ] Rare drops and special finds (geodes, artifacts) that feed unlocks.
- [ ] Layer hazards for later layers: heat (needs cooling), gas pockets,
  water flooding, collapses, underground creatures.
- [ ] Power and pollution underground: decide whether pollution exists and
  how electricity reaches lower layers (cables through core drill shafts?).

## 3. Core drill and layer travel

- [x] Core drill is a 5x5 burner machine that crafts shaft segments like a
  rocket silo builds rocket parts (`shaft` per layer in `shared/layers.lua`).
- [x] On breakthrough: a 7x7 pit stays behind with stairs running down along
  two opposite rims, the layer below gets an 11x11 landing (shaft + 2 tiles)
  where the same stairs arrive, and the drill moves down with its fuel and
  contents. It keeps the old recipe until its leftovers are taken out, then
  switches to the next layer's shaft. Stairs alternate north/south and
  west/east rims by depth so landings and pits never overlap.
- [x] Shaft ends are linked in `storage.ttc.shafts`; any number of shafts and
  layers.
- [x] Stair travel is covered by the engine test via the `to-the-core`
  remote interface (`travel_target`).
- [ ] Playtest the stair feel: trigger at the low/high end, arrival one tile
  past the stairs.
- [ ] Shaft art polish: depth/parallax in the pit, lighting from above on the
  landing, smoke/dust while drilling, breakthrough effect and sound.
- [ ] Core drill GUI: a dedicated segment progress bar (like the rocket silo's)
  instead of only the status text.
- [ ] What if the landing spot below is blocked by player builds: currently
  the drill waits with "landing blocked"; maybe clear or relocate instead.
- [~] Shaft inputs per layer: wooden heads → sand and clay into layer 1, iron
  heads → ~a stack of stone per segment into layer 2. Layer 2+ still need
  real designs.
- [x] One-way transfer down: item chute (floor 1) and downpipe (floor 2),
  `runtime/transfer.lua`. Outlet appears directly below on open ground.
- [ ] Lifting up: freight lift (floor 4) and lift pump (floor 5).
- [ ] Item chute throughput limit / sprites polish.
- [ ] Vehicle / train travel between layers (later).
- [ ] Travel UX: tooltip or flying text on the stairs; maybe a hotkey to use
  the nearest shaft.

## 4. Progression and tech tree

- [ ] Strip the base tech tree down to "very basic technologies" at start.
  Decide approach: disable most base technologies and re-enable them as
  trigger technologies, or replace science packs entirely.
- [ ] Make unlocks data-driven per layer: `unlocks` in `shared/layers.lua`
  already maps item → technology; extend with triggers like "reach layer N",
  "dig N tiles", "find ore X", "craft item Y".
- [ ] Use Factorio 2.x `research_trigger` technologies where possible instead
  of script-researched ones (`craft-item`, `mine-entity`, `build-entity`,
  `scripted` triggers), so the tech tree shows the condition.
- [ ] Map base-game technologies to layers (e.g. automation on layer 1,
  logistics on layer 2, oil on layer 4) in a single config table.
- [ ] Decide fate of science packs and labs: remove, keep for infinite research
  only, or convert labs into something depth-related.
- [ ] Win condition: reaching the core.

## 5. Start of game / world

- [x] No ore on the starting surface (`prototypes/world.lua` strips resource
  autoplace from Nauvis; trees and rocks stay).
- [x] Sand → glass (pipes need glass); clay → unfired → fired clay drill
  heads for floor 1. Iron moved to floor 2.
- [ ] Map base technologies onto floor arrivals/discoveries (`FLOORS.md`
  tech mapping), reaching the chemical tier by floor 5.
- [ ] Floors 4-5 configs; floor 3 shaft inputs.
- [x] Start from the freeplay crash site: core drill and blades in the ship,
  more blades in the wreckage (`set_up_crash_site` in `runtime/init.lua`);
  the tunnel bore needs no iron (wood, stone, clay, blades).
- [ ] Freeplay scenario intro / tips explaining the loop.
- [ ] Multiplayer / multiple forces: check that per-force state (home drills,
  bores, unlocks) is correct.

## 6. Items and recipes

- [ ] Drill head chain per layer: iron → iron-copper → … with recipes using
  previous-layer materials.
- [ ] Coolant fluid and its production chain.
- [ ] Use for stone (the main by-product): bricks, landfill-like fill for
  tunnels, walls; at minimum make dumping it easy early on.
- [ ] Balance pass: dig time, fuel per tile, heads per tile, drop rates.
  Keep all numbers in `shared/layers.lua` / `shared/bore.lua`.

## 7. Graphics, locale, polish

- [ ] Core drill graphics are a static picture; make an animated drilling rig.
- [ ] Icons for dig recipes per layer (currently the drill head icon).
- [ ] Technology icons.
- [ ] Locale for every layer name, status and tooltip; factoriopedia entries.
- [ ] Map colors for bore and tunnel tiles.
- [ ] Mod thumbnail and info.json description for the portal.

## 8. Tooling and testing

- [x] Headless test harness: `v1/tests/run.sh` creates a map with the
  `tests/ttc-test` mod and runs it with `--benchmark`, printing PASS/FAIL.
- [~] Automated checks: platform/tunnel survival, bore placement rules,
  digging, belts and walls are covered. Still missing: blocking, unlocks,
  belt-fed supplies, portal round-trip (needs a way to test without players).
- [x] `deploy_local.sh` symlinks into the mods directory.
- [ ] Lua language server annotations (`.luarc.json` with Factorio API
  definitions) for editor support.
