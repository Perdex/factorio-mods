# Floor plan: surface to floor 5

Status: the surface and floors 1–5 are implemented (floors 3–5 still need
playtesting and balance). All numbers live in `shared/layers.lua`,
`shared/bore.lua`, `shared/progression.lua` and `prototypes/items.lua`.

Floors 1–5 cover about **half the tech tree**, up to roughly the chemical
(blue) science tier. Floors 6+ are for the rest.

**Pacing target:** 20–40 hours for the whole game; 5–10 hours to reach
floor 5 (1–2 hours for a speedrunner). The game should demand careful
infrastructure planning — rock disposal, one-way logistics between floors,
veins as long projects — rather than a straight-line run.

The loop on every floor:

1. **Arrive** by the core drill's shaft onto a small landing. The arrival
   unlocks the floor's basic tools.
2. **Dig out room** with tunnel bores. Wall hardness (hits per tile) grows
   about 4x per floor, so opening space is always a major project; in return
   every tile is rich in the floor's materials.
3. **Find** the floor's resources in the walls. The first find of a key
   resource unlocks the next tier (a "discovery").
4. **Supply the shaft down**: the core drill on each floor needs a steady
   flow of something made from what the floors above produce.

## Things flow down; up only from floor 4

- **Item chute** (wood + stone) and **downpipe** (pipes + stone), both from
  floor 2: a hopper or pipe end on one floor and an outlet directly below on
  the next. Items and fluids only move down. Water is piped down from the
  surface's lakes; there is no water underground.
- **Power connector** (floor 4): an electric pole whose twin below supplies
  the power drawn above, up to 10 MW.
- All need the spot below to be dug out already, and removing either end
  removes both.
- **Up** is only by carrying things up the shaft stairs, until floor 4
  (*freight lift*, items) and floor 5 (*lift pump*, fluids). These are
  placed on the lower floor; their outlet opens on the floor above (or the
  surface).

So the first automation has to be built as a cascade: raw inputs from the
surface and upper floors fall down to the factories below.

## Getting rid of rock

Every floor yields far more stone than anything needs, and it's hard to get
rid of. From floor 2 (they need iron and gears), a **grinder** (burner, 2x2)
crushes stone to gravel, gravel to sand and sand to dust; each step turns 3
items into 2 and takes three times as long, so one stone grinder needs 2
gravel grinders, 4 sand grinders and 8 winnowers behind it. The **winnower**
(3x3, wind-driven, no fuel) lets the dust blow away — but only under open
sky, so the dust has to get back to the surface: carried up the stairs at
first, freight lifts from floor 4. On floor 1 the stone simply has to be
stored. The sand on the way is welcome: it makes glass.

## Ore veins

Each floor hides veins in its rock (`veins` in `shared/layers.lua`): patches
twenty times harder to dig, which yield their resource instead of the floor's
usual drops. They show as ore on the rock face once a tunnel exposes them, so
they can be dug around — or into, when the resource is worth it.

| Floor | Veins |
|---|---|
| 1 | stone (an obstacle: ~1200 stone a tile, nothing else) |
| 2 | stone; iron (~1600 iron ore a tile) |
| 3 | copper, coal, iron |
| 4 | sulfur, coal; oil pockets (soft; the first tile dug leaves a crude oil well) |
| 5 | uranium, iron, copper |

## Drill heads

They wear out like repair packs. Each kind hits three times as fast as the
one before and lasts longer, so better heads keep up with harder rock.

| Head | Lasts | Hits/s | Made from | Unlocked |
|---|---|---|---|---|
| Wooden | 10 hits | 0.33 | 2 wood, 1 stone | start |
| Clay | 20 | 1 | 5 clay, shaped, then fired | floor 1 |
| Iron | 80 | 3 | 4 iron plates | iron discovery (floor 2) |
| Reinforced | 500 | 9 | 3 steel, 2 copper | 10 steel plates crafted (floor 4) |
| Hardened | 3000 | 27 | 5 steel, 2 plastic | plastics (floor 4) |
| Carbide | 15 000 | 81 | 5 steel, 5 sulfur, 1 advanced circuit | floor 5 |

## Tunnel bores

| Bore | Speed | Lays belts | Made from | Unlocked |
|---|---|---|---|---|
| Mk1 | 1 | no | wood, clay bricks, glass | floor 1 |
| Mk2 | 2 | yes | 20 iron, 20 gears, bricks, glass | iron discovery |
| Mk3 | 5 | yes, and pipes; 3 wide, water inlet at the back (1 per hit) | Mk2, 50 steel, gears, circuits, pipes | 200 steel crafted |

Veins are meant to be long projects, like base-game ore patches: an iron
vein tile on floor 2 is 3200 hits (~9 min for a Mk2 with iron heads), a
floor 3 vein tile 12 800 hits (~5 min for a Mk3 with reinforced heads), and a
vein is tens of tiles, best dug from all sides at once.

## Surface (no ore)

- **Has:** trees (wood), rocks (stone), the crash site: the core drill in
  the ship along with 5 wooden drill heads. Lakes for water.
- **Make:** wooden drill heads, stone furnaces.
- **Shaft to floor 1:** 100 hits (10 wooden heads), each hit bringing up
  1–2 sand and 2–3 clay. The core drill takes any drill head and wears it
  four times faster than a tunnel bore.

## Floor 1 — clay (hardness 40) ✔

- **Arrival unlocks:** tunnel bore Mk1 (wood, clay bricks, glass; lays no
  belts), clay drill heads, glass (smelted from sand). Bricks are fired from
  clay.
- **Landing:** only the drill's spot, the stairs and one row beyond them are
  open, as wide as the drill; each side is reached by its own stairs, the
  rest has to be dug out.
- **Walls give per tile:** ~20 clay, ~12 stone (rubble to get rid of — a
  central theme), ~1 coal, ~2 sand. Two clay heads and 40 s per tile in a Mk1.
- **No iron here:** supplies are carried down the stairs.
- **Shaft to floor 2:** 400 hits (20 clay heads), 1–2 stone per hit.
- **Base tech tier:** none yet (stone furnaces, hand crafting).

## Floor 2 — stone with iron (hardness 160) ✔

- **Arrival unlocks:** item chute and downpipe.
- **Walls give per tile:** ~40 stone, ~8 iron ore, ~3 coal. A tile takes two
  iron heads (8 plates), so iron digging just about keeps itself going.
- **Discovery — iron ore:** iron drill heads and the tunnel bore Mk2, which
  lays its own belt lanes. Red tier (automation, logistics, basic military).
- **Shaft to floor 3:** 10 000 hits through solid stone — about 15 minutes
  of digging with iron heads, ~2 000 stone. The rock is the real limit: the
  drill stops whenever its stone isn't cleared away.
- **Problem it poses:** glass for pipes comes from floor 1 sand, water from
  the surface — the first cross-floor supply chains, all flowing down.

## Floor 3 — copper and coal (hardness 640)

- **Walls give per tile:** ~60 stone, ~20 copper ore, ~10 coal, ~13 iron:
  more iron than the iron heads a tile takes.
- **Discovery — copper ore:** electronics, then electricity (steam from
  surface water through downpipes); the green tier starts.
- **Shaft to floor 4:** 40 000 hits — about 20 minutes of digging with
  reinforced heads, ~4 000 stone to dispose of.

## Floor 4 — sulfur and oil (hardness 2560)

- **Walls give per tile:** ~50 stone, ~20 sulfur, ~20 coal, ~10 iron and
  copper ore. Veins of sulfur and coal; **oil pockets** leave a crude oil
  well for a pumpjack when a tunnel breaks into them.
- **Arrival unlocks:** steel, power connectors, freight lifts, oil gathering,
  plastics, sulfur processing; the military tier.
- **Heads:** hardened (with plastics); 200 steel plates unlock the Mk3 bore.
- **Shaft to floor 5:** 100 000 hits — about 15 minutes with hardened heads,
  ~5 000 stone.

## Floor 5 — hot rock (hardness 10 240)

- **Hazard — heat:** only the coolant-cooled Mk3 bore can dig here; others
  stop with "too hot".
- **Walls give per tile:** ~50 stone, ~20 uranium ore, ~30 iron and copper,
  ~20 sulfur; uranium, iron and copper veins.
- **Arrival unlocks:** lift pumps, carbide drill heads, and the blue tier
  (with blue crafting milestones along the way).
- **Shaft to floor 6:** not yet — floor 5 is the deepest.

## Tech tree

There is no science and no lab. Red, green, military and blue technologies
unlock by progression instead (`shared/progression.lua`): either on reaching
a floor (once their prerequisites are done) or with the game's own crafting,
fluid and building triggers. Science pack technologies are removed.
Examples:

| Trigger | Unlocks |
|---|---|
| Craft 50 / 100 iron plates (floor 2) | steam power / automation |
| Craft 100 belts, 100 bricks, magazines | logistics, stone walls, turrets |
| Reach floor 2 | military |
| Craft 10 copper plates (floor 3) | electronics |
| Reach floor 3 | radar, logistics 2, toolbelt |
| Craft circuits (50/100/200) or glass (50) | repair packs, fast inserters, circuit network, lamps |
| Reach floor 4 | steel, oil gathering, plastics, sulfur |
| Craft steel / engines / plastic | automation 2, engines, railways, advanced circuits |
| Reach floor 4 | flamethrower, energy shields |
| Craft piercing rounds / grenades / explosives | defender, damage upgrades, rocketry, land mines |
| Craft plastic, heavy oil, lubricant, robot frames | advanced oil, lubricant, electric engines, robotics |
| Craft processing units / batteries | level-2 modules, lasers |
| Reach floor 5 | batteries, modules, uranium, power armour, laser weapons, tank |

Production, utility and space science technologies keep their costs and are
out of reach until deeper floors exist.

## Open questions

- **Enemies:** surface only, or underground creatures from floor 3 on?
- **Item chute throughput:** currently unlimited; should it have a rate
  (and an upgrade path)?
