# Floor plan: surface to floor 5

Status: the surface and floors 1–2 are implemented, floor 3 roughly; floors 4–5
are a plan for review. All numbers live in `shared/layers.lua`,
`shared/bore.lua` and `prototypes/items.lua`.

Floors 1–5 cover about **half the tech tree**, up to roughly the chemical
(blue) science tier. Floors 6+ are for the rest.

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

## Things only flow down (until floor 4)

- **Item chute** (wood + stone, floor 1): a hopper on one floor and an outlet
  directly below on the next. Items only move down.
- **Downpipe** (pipes + stone, floor 2): the same for fluids. Water is piped
  down from the surface's lakes; there is no water underground.
- Both need the spot below to be dug out already, and removing either end
  removes both.
- **Up** is only by carrying things up the shaft stairs, until floor 4
  (*freight lift*, items) and floor 5 (*lift pump*, fluids).

So the first automation has to be built as a cascade: raw inputs from the
surface and upper floors fall down to the factories below.

## Drill heads

They wear out like repair packs. Better heads last longer *and* hit faster.

| Head | Lasts | s/hit | Made from | Unlocked |
|---|---|---|---|---|
| Wooden | 10 hits | 3 | 2 wood, 1 stone, 1 blade | start |
| Clay | 20 | 2 | 5 clay, shaped, then fired in a furnace | floor 1 |
| Iron | 40 | 1 | iron plate | iron discovery (floor 2) |
| Reinforced | 120 | 0.5 | iron + copper | copper discovery (floor 3) |
| Steel | 400 | 0.25 | steel + reinforced head | floor 4 (planned) |

## Surface (no ore)

- **Has:** trees (wood), rocks (stone), the crash site: the core drill in
  the ship and about 60 blades in the ship and wreckage. Lakes for water.
- **Make:** wooden drill heads, stone furnaces.
- **Shaft to floor 1:** 20 segments × 1 wooden head → each segment brings up
  10–20 sand and 20–30 clay.
- **Problem it poses:** blades are finite; every wooden head spends one. Clay
  heads (floor 1) need none.

## Floor 1 — clay (hardness 40) ✔

- **Arrival unlocks:** tunnel bore Mk1 (wood, stone, clay, blades), clay
  drill heads, glass (smelted from sand), item chute.
- **Walls give per tile:** ~20 clay, ~4 stone, ~2 coal (fuel), a little
  sand. Two clay heads and 80 s per tile.
- **No iron here:** belts can't be made yet, so bores dig without laying
  lanes; supplies are carried or dropped down item chutes.
- **Shaft to floor 2:** 30 segments × 2 clay heads → 45–50 stone each.
- **Base tech tier:** none yet (stone furnaces, hand crafting).

## Floor 2 — stone with iron (hardness 160) ✔

- **Arrival unlocks:** downpipe.
- **Walls give per tile:** ~40 stone, ~10 iron ore, ~3 coal. Iron heads (4
  per tile, 2 plates) and the bore's two belts (3 plates) are paid for by the
  tile's iron.
- **Discovery — iron ore:** iron drill heads, blades from iron. Planned: the
  red-science tier (automation, logistics, basic military).
- **Shaft to floor 3:** 40 segments × 2 iron heads → 45–50 stone each.
- **Problem it poses:** glass for pipes comes from floor 1 sand, water from
  the surface — the first cross-floor supply chains, all flowing down.

## Floor 3 — copper and coal (hardness 640) (rough)

- **Walls give per tile:** ~60 stone, ~20 copper ore, ~10 coal, ~6 iron.
- **Discovery — copper ore:** reinforced drill heads. Planned: electricity
  (steam from surface water through downpipes), electronics, the start of
  the green-science tier.
- **Planned shaft to floor 4:** reinforced heads + stone bricks.
- **Planned:** bores break into hidden *ore patches* — resource entities in
  the tunnel that ordinary drills can mine. Bores are for space; patches are
  for throughput.

## Floor 4 — sulfur and oil (hardness 2560) (plan)

- **Walls give:** stone, sulfur, **oil pockets** (crude oil resource
  entities), some coal.
- **Arrival unlocks:** the **freight lift** (items up one floor), steel
  processing, steel drill heads.
- **Discoveries:** sulfur → basic chemistry; crude oil → oil processing,
  plastics. Green tier complete.
- **Shaft to floor 5:** steel heads + water as coolant (core drill fluid
  input).

## Floor 5 — hot rock (hardness 10 240) (plan)

- **Hazard — heat:** bores need coolant through their fluid input or they
  overheat and stop (the bore already has a fluid box).
- **Walls give:** stone, uranium ore (for later), heat pockets.
- **Arrival unlocks:** the **lift pump** (fluids up one floor).
- **Discoveries:** reaching here brings the chemical (blue) tier: advanced
  electronics, batteries, sulfuric acid, modules.
- **Shaft to floor 6:** whatever the next half of the game starts with.

## Tech tree mapping (planned)

Base technologies get gated behind arrivals and discoveries instead of
science (trigger technologies):

| Trigger | Tier | Unlocks (base) |
|---|---|---|
| Reach floor 1 | pre-red | tunnel bore, clay heads, glass, item chute |
| Reach floor 2 | pre-red | downpipe |
| Find iron ore (floor 2) | red | automation, logistics, turrets |
| Find copper (floor 3) | red → green | electricity, electronics |
| Reach floor 3 | green | fast inserters, logistics 2 |
| Reach floor 4 | green | steel, freight lift |
| Find sulfur / oil (floor 4) | green | chemistry, oil processing, plastics |
| Reach floor 5 | blue | lift pump, advanced electronics, batteries |

## Open questions

- **Science packs:** remove entirely, or keep labs for infinite research?
- **Enemies:** surface only, or underground creatures from floor 3 on?
- **Item chute throughput:** currently unlimited; should it have a rate
  (and an upgrade path)?
