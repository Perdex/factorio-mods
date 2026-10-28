# To the Core — TODO

Design goal (from the original brief): replace science-based progression with
digging. Start with almost nothing, dig down with core drills to new floors,
dig sideways with tunnel bores that need a constant supply of materials, and
open the tech tree as new depths are reached. Floors, drops and unlocks stay
easy to configure for balancing. `FLOORS.md` has the floor-by-floor plan.

Legend: `[x]` done, `[ ]` open, `[~]` partly done / needs revisiting.

---

## Next up

1. **Playtest from an empty start** against the pacing target (20–40 h in
   total, 5–10 h to floor 5, 1–2 h for speedrunners; see `FLOORS.md`): soft-locks, pacing of floors 1–5, stair feel, the left cliff
   wall, vein visibility, the core drill depth bar.
2. **Getting rid of rock** — grinders (3:2 per step, 3x slower per step,
   from floor 2) and surface-only winnowers. Playtest whether it's hard
   enough, and whether dust should also be usable (e.g. as filler).
3. **Floors 6+** for production, utility and space science, and a win
   condition.

## Known quirks

- [ ] Dig recipes list every possible drop as an amount-0 product (so the
  furnace output slots accept them); the recipe tooltips show those.
- [ ] Furnace input is one slot: a bore or core drill only takes another kind
  of head once the current kind is used up (shift-click does nothing).
- [ ] The head being worn when a core drill moves down comes back whole.
- [ ] Switching head type mid-dig loses up to 10 ticks of wear.
- [ ] A bore without belts can't carry its circuit wire along; it stays put
  and may end up out of reach.

## 1. Tunnel bore

- [x] Three tiers: Mk1 (speed 1, no belts), Mk2 (speed 2, lays belt lanes,
  unlocked by finding iron), Mk3 (speed 5, water coolant 1 per hit, unlocked
  after 200 steel plates).
- [x] Heads hit three times as fast per tier (wooden 10 hits, clay 20, iron
  80, reinforced 500), so veins are long but feasible projects.
- [x] Mk1/Mk2 are 2x2, rotatable (a connectionless fluid box keeps a square
  furnace rotatable), 4-direction sprites with the cutter overlapping the wall
  ahead; placeable only at the edge of open ground facing rock.
- [x] Mk3 is 3 wide and 2 long with two cutters: supply loader, water inlet
  and output loader across its back. It lays a pipe behind its inlet per tile
  from a pipe stock of up to 10, pulled off the supply lane (returned when
  mined), so the water line follows it.
- [x] Burner furnace: any drill head goes in, like ammo in a turret, and picks
  its dig recipe. Heads wear out like repair packs; the crafting bar is the
  head's wear. Dig recipes are always enabled; crafting heads unlocks.
- [x] Wall hardness per floor (`hits_per_tile`); each hit rolls the floor's
  drops (`runtime/wear.lua`), with rock-chip particles. Output-full pauses.
- [x] Mk2 lays supply/output belt lanes from a belt stock of up to 10, pulled
  off the supply lane; without belts it leaves a bare tunnel. Hidden loaders
  follow its rear.
- [x] Circuit connection; its wires follow the bore along the supply lane.
- [x] Pauses with a status when the tiles ahead are blocked.
- [ ] Belts that can't be laid (occupied tile) are spilled on the ground.
- [ ] Meeting another tunnel or the map edge; joining belt lanes cleanly.
- [ ] Turning: rotating mid-tunnel breaks the belt lanes.
- [ ] Higher tiers (Mk2/Mk3): faster, wider tunnels, electric or fluid fuel.
- [ ] Hit and break-through sounds; dust.
- [ ] Map visibility of tunnels (chart dug tiles).

## 2. Floors

- [x] Floors 1–3 in `shared/layers.lua`: clay with lots of loose stone (40
  hits/tile), stone with a little iron (160), copper, coal and more iron (640,
  rough). Surfaces `ttc-floor-N`.
- [x] Cliff walls cut from the base game's cliff textures, continuing 4-tile
  runs along a wall; thin walls get a short face.
- [x] Floors 4 (sulfur, oil pockets) and 5 (hot rock: Mk3 only, uranium).
- [ ] Floors 6+ for the second half of the game.
- [x] Ore veins in the rock (`veins` per floor, `runtime/veins.lua`): placed
  from the map seed, shown by base ore sprites on exposed rock, 20x harder,
  rich in their resource. Floor 1 stone; floor 2 stone and iron; floor 3
  copper, coal and iron. "Ore veins" setting; remote `set_veins`/`vein_at`.
- [ ] Rare finds (geodes, artifacts).
- [x] Heat on floor 5: bores without coolant stop.
- [ ] More hazards: gas, flooding, collapses.
- [ ] Power and pollution underground: how does electricity get down?
- [ ] Wall polish: cliff shadows, corner pieces, per-floor tint.
- [ ] Per-floor ambience: lighting, tunnel tile, wall tint.

## 3. Core drill, shafts and travel

- [x] 5x5 burner furnace taking any drill head (crafting speed 4). Shafts are
  `hits` deep with per-hit drops: 100 to floor 1 (sand, clay), 400 to
  floor 2 (both dug by hand-fed drills), then 10 000 to floor 3, 40 000 to
  floor 4 and 100 000 to floor 5 (~15–20 min of digging each), leaving
  2 000–5 000 stone: getting rid of it is the real limit. Crafting one needs
  steel and circuits. Each break-through message hints at the ground below.
- [x] The burner inserter is a mechanical inserter (no fuel), so floor 2
  can be automated.
- [x] Break-through clears the site (buildings are mined and dropped on the
  ground with their contents), leaves a 7x7 pit with stairs along two rims,
  and opens a landing below: the drill's spot plus, on the two stair sides
  only, the stairs and two rows beyond (room for a bore), as wide as the
  drill. Each side is reached by its own stairs. Walking past the middle of
  the stairs switches floors, landing mid-stairs. The drill moves down with
  everything in it and digs on. Stair rims alternate by depth.
- [x] Nothing can be built on the stairs: invisible blockers stop buildings,
  belts and vehicles but not players. Pit stairs on a floor are cut one tile
  longer at each end so they join the ground around them.
- [x] Shaft links per direction (`storage.ttc.shafts`), rebuilt from the
  pits for older saves. Stair travel covered by the engine test.
- [x] One-way transfer down: item chute and downpipe (floor 2), power
  connector (floor 4: hidden energy interfaces under twin poles).
- [ ] Power connector graphics (reuses the medium electric pole).
- [x] Depth bar panel beside the core drill's window.
- [ ] Shaft drops and depths for floors 3+ need real designs.
- [ ] Landing spot blocked by player builds: currently waits; clear/relocate?
- [ ] Item chute sprite polish (throughput stays unlimited: one tile can't
  be loaded fast anyway).
- [ ] Travel UX: hint on the stairs, maybe a hotkey.
- [ ] Shaft art: depth in the pit, light on the landing, break-through effect.
- [ ] Vehicles/trains between floors (later).

## 4. Progression and tech tree

- [x] No science or labs. Red/green technologies unlock by floor arrivals and
  crafting/building triggers (`shared/progression.lua`); floor arrivals and
  discoveries (iron, copper) use scripted triggers.
- [x] Automation unlocks with the first 100 smelted iron plates.
- [x] Military and blue tiers mapped (floor 4–5 arrivals, crafting and fluid
  milestones); research speed 3–4 and uranium mining removed.
- [ ] Production/utility/space tiers (floors 6+), win condition.
- [ ] Freeplay intro / tips explaining the loop.

## 5. Start and items

- [x] No ore on the surface. Crash site: core drill and 5 wooden drill heads
  in the ship, nothing in the wreckage, empty pockets.
- [x] Drill heads: wooden (wood, stone), clay (shaped, then fired), iron (iron
  discovery), reinforced (10 steel plates crafted).
- [x] Sand → glass (pipes, lamps); clay → clay bricks (5:1; the base stone
  brick, renamed; boilers, steam engines, bore Mk1).
- [x] Rock disposal from floor 2: grinder (burner, 2x2, 3:2 per step) and
  winnower (3x3, wind-powered, surface only), `prototypes/grinding.lua`, art
  from `tools/grinding_gfx.py`. The electric mining drill is removed: ore comes from digging.
- [x] Hardened (plastics) and carbide (floor 5) drill heads; Mk3 bores use
  water as coolant.
- [ ] Balance pass on dig times, fuel, heads and drops per floor.

## 6. Polish

- [ ] Technology icons; dig recipe icons per head and machine.
- [ ] Locale review, factoriopedia entries, map colours.
- [ ] Mod portal thumbnail and description.

## 7. Tooling and testing

- [x] Headless engine test (`v1/tests/run.sh`, 104 checks): tunnels and walls,
  bore placement, digging, belts, wires, core drill shafts to floor 2, stairs,
  transfers, crash site, technologies.
- [x] `deploy_local.sh` links `src` into the mods folder.
- [ ] Tests still missing: blocked bore, belt-fed supply, multiplayer forces.
- [ ] Lua language server annotations (`.luarc.json`).
