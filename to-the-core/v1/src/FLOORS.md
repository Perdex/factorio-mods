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
   every tile is rich in the floor's materials. A bore's hits land on the
   tiles in front of it in turn, skipping open ones, and every tile takes
   the floor's hits per tile and gives the same drops, whatever the bore: a
   faster bore only gets there sooner. So a face that is half open takes
   half the hits and gives half the drops, rock beside a vein gives the
   average of the two, and a 3-wide Mk3's step takes and gives 1.5 times a
   2-wide bore's. The amounts below are per 2-wide step (two tiles).
3. **Find** the floor's resources in the walls. The first find of a key
   resource unlocks the next tier (a "discovery").
4. **Supply the shaft down**: the core drill on each floor needs a steady
   flow of something made from what the floors above produce.

## Going under something means going down a floor

- **Underground belts and pipes-to-ground** really go underground: the base
  game's are replaced by a *down* and an *up* end, each its own recipe from
  half the old pair's ingredients. Down ends unlock as usual; the first
  tier's up ends (belt and pipe) only on floor 3, faster tiers' with their
  down ends. Until then things only flow down. A belt or pipe going down drops to an outlet directly
  below on the next floor, facing the same way; one coming up rises from an
  inlet directly below. Both ends are placed on the upper floor. To cross
  something, route the belt through the floor below and bring it back up.
  Belt ends are linked belts: items keep their lane, at the tier's speed.
  On the deepest floor there is nothing to go under.
- Water is piped down from the surface's lakes; there is no water
  underground.
- **Power connector** (floor 4): an electric pole whose twin below supplies
  the power drawn above, up to 10 MW.
- All need the spot below to be dug out and free: otherwise the piece goes
  back into your hand. Removing either end removes both.
- **Manhole** (halfway down the shaft to floor 4): a 2x2 hole over ground
  that is dug out on the floor below. Step in and you land there; holes
  over holes drop you several floors at once. Back up is by the stairs.

## Getting rid of rock

Every floor yields far more stone than anything needs, and it's hard to get
rid of. From floor 2 (they need iron and gears), a **grinder** (burner, 2x2)
crushes stone to gravel, gravel to sand and sand to dust; each step turns 3
items into 2 and takes three times as long (2, 6 and 18 s), so one stone
grinder needs 2 gravel grinders, 4 sand grinders and 4 winnowers behind it.
Stone only stacks to 20, so it can't simply be stockpiled. The deep shafts
bring up **hardened stone**, which doesn't stack at all and can't be sorted
by hand; for now a grinder takes 10 s to turn one into gravel. The **winnower**
(3x3, wind-driven, no fuel) lets the dust blow away — but only under open
sky, so the dust has to get back to the surface: carried up the stairs at
first, then on belts coming up from below. On floor 1 the stone simply has to be
stored. The sand on the way is welcome: it makes glass.

## Coal

A tunnel bore burns the same per hit whatever its tier, by drill head:
450 kJ with wooden heads, 150 kJ with clay and 50 kJ with iron (coal holds
4 MJ). Floors 1 and 2 are dug with clay heads (0.0375 coal a hit). Floor 1
gives that back in full (0.0375 a hit), since firing the heads and smelting
take coal on top; floor 2 gives back about 90% (0.034): the surface's huge
rocks (24–50 coal each) top it up now and then, until coal veins turn up on
floor 2. Wooden
heads get only about 30% back. Not counted: the core drill (shafts give no
coal), grinders (about 0.011 coal a hit's worth of rock, twice the coal hand
sorting finds instead) and veins, whose own drops hold no coal unless they
are coal veins.

## Walls and ore veins

Each floor hides veins in its rock (`veins` in `shared/layers.lua`): patches
twenty times harder to dig (clay only five), which yield their resource
instead of the floor's usual drops. They show as ore on the rock face once a
tunnel exposes them, so they can be dug around — or into, when the resource
is worth it. The walls themselves give no plain ore from floor 2 on, only
iron- and copper-rich rock, which is sorted by hand (20% ore) or ground
(80% granules, 4 to a plate); plain ore is in the veins.

Per tile (a 2-wide step is two tiles, a Mk3's three):

| Floor | Hits a tile | Wall drops a tile | Veins: hits a tile, drops a tile |
|---|---|---|---|
| 1 | 20 | 6 clay, 3 stone, 0.75 coal, 1 sand | stone 400, 600 stone (an obstacle); clay 200, 300 clay |
| 2 | 80 | 20 iron-rich rock, 2.7 coal | stone 1600, 2400 stone; coal 1600, 800 coal |
| 3 | 320 | 32 iron-rich rock, 32 copper-rich rock, 4.8 coal | copper, iron and coal 6400, 3200 ore or coal |
| 4 | 1280 | 25.6 iron-rich rock, 25.6 copper-rich rock, 10 sulfur, 10 coal | sulfur and coal 25 600, 12 800 each; oil pockets 1280 (soft; the first tile dug leaves a crude oil well) |
| 5 | 5120 | 77 iron-rich rock, 77 copper-rich rock, 10 sulfur | uranium, iron and copper 102 400, 51 200 ore |

How often veins turn up and how much they hold. "Found within" is the
average straight 2-wide tunnel before one shows on its walls, and the time
that takes one bore with the floor's heads; the aim is no more than ~4 h on
average (so ~8 h even when unlucky), and much less for the veins progress
leans on:

| Floor | Vein | Found within | Size | A whole vein |
|---|---|---|---|---|
| 1 | clay | ~75 tiles (~0.8 h) | ~30 tiles | ~9 000 clay (0.8 h) |
| 1 | stone | ~90 tiles (~1 h) | ~41 tiles | ~25 000 stone |
| 2 | coal | ~63 tiles (~1.4 h) | ~46 tiles | ~37 000 coal (10 h) |
| 2 | stone | ~150 tiles (~3.3 h) | ~67 tiles | ~160 000 stone |
| 3 | iron, copper | ~100 tiles (~3 h) | ~99 tiles | ~316 000 ore each (29 h) |
| 3 | coal | ~136 tiles (~4 h) | ~41 tiles | ~132 000 coal |
| 4 | oil pocket | ~90 tiles (~2 h) | ~20 tiles | a crude oil well |
| 4 | sulfur, coal | ~165 tiles (~4 h) | ~41–67 tiles | ~530 000–855 000 |
| 5 | uranium | ~127 tiles (~4 h) | ~41 tiles | ~2.1 M ore |
| 5 | iron, copper | ~123 tiles (~4 h) | ~67 tiles | ~3.4 M ore each |

## Drill heads

They wear out like repair packs. Each kind hits three times as fast as the
one before and lasts longer, so better heads keep up with harder rock.

| Head | Lasts | Hits/s | Made from | Unlocked |
|---|---|---|---|---|
| Wooden | 10 hits | 0.33 | 2 wood, 1 stone | start |
| Unfired clay | 1 | 1 | 5 clay, shaped | floor 1 |
| Clay | 25 | 1 | 5 clay, shaped, then fired | floor 1 |
| Iron | 80 | 3 | 1 gear, 2 iron plates | floor 2 |
| Reinforced | 500 | 9 | 3 steel, 2 copper | floor 4 |
| Hardened | 3000 | 27 | 5 steel, 2 plastic | floor 5 |
| Carbide | 15 000 | 81 | 5 steel, 5 sulfur, 1 advanced circuit | floor 6 (not yet) |

Each floor is mostly dug with the heads of the floor above: clay heads from
floor 1 dig floor 2, where automation has to start, so they keep coming down
from floor 1. Iron heads come with floor 2, but its walls don't pay for them:
they're for reaching veins quickly, and take over on floor 3.

## Tunnel bores

| Bore | Speed | Lays belts | Made from | Unlocked |
|---|---|---|---|---|
| Mk1 | 1 | no | wood, clay bricks, glass | floor 1 |
| Mk2 | 2 | yes | 20 iron, 10 gears, bricks, glass | iron discovery |
| Mk3 | 5 | yes, and pipes; 3x3 (turns in place), coolant inlet at the back (100 a second) | Mk2, 50 steel, gears, circuits, pipes | oil processing |

Veins are meant to be long projects, like base-game ore patches (a few
hundred thousand ore at first, millions later): a coal vein step on floor 2
is 3200 hits (~27 min for a Mk2 with clay heads), a floor 3 vein step
12 800 hits (~36 min for a Mk2 with iron heads), and a vein is tens to a
hundred tiles, best dug from all sides at once.

## Core drill stages

What each shaft takes and gives in all, with the heads meant for it (the
core drill grinds a head down five times faster than a bore, and hits 4
times as fast as a Mk1 with the same head). Fuel is the drill's own (300 kW;
coal at 4 MJ). Worked out from `shared/layers.lua`, `shared/bore.lua` and
`shared/shaft.lua`; rerun the numbers when those change.

| Shaft | Hits | Heads | Head materials | Fuel | Time | Brings up |
|---|---|---|---|---|---|---|
| Surface → 1 | 20 | 10 wooden | 20 wood, 10 stone | ~1 coal | 15 s | ~180 clay, ~45 sand |
| 1 → 2 | 400 | 80 clay | 400 clay (+ ~6 coal to fire them) | ~8 coal | 1.7 min | ~200 stone, ~20 iron-rich rock |
| 2 → 3 | 10 000 | 2 000 clay | 10 000 clay (+ ~140 coal to fire them) | ~190 coal | 42 min | ~20 000 stone, ~500 iron-rich rock, ~250 coal |
| 3 → 4 | 40 000 | 2 500 iron | 10 000 iron plates (2 500 gears, 5 000 plates) | ~250 coal | 56 min | ~16 700 hardened stone |
| 4 → 5 | 100 000 | 1 000 reinforced | 3 000 steel (15 000 iron plates), 2 000 copper plates | ~210 coal | 46 min | ~41 700 hardened stone |

What that means upstream and downstream:

- **Clay:** the 2 → 3 shaft's 10 000 clay is about 1.3 clay veins' worth of
  floor 1's spare clay (a vein gives ~9 000 clay and its own digging takes
  ~1 200 of it back as heads); plain floor 1 walls leave only 0.1 clay a
  hit spare, ~100 000 hits of bore digging.
- **Iron:** the 3 → 4 shaft's 10 000 plates is ~40 000 iron granules, i.e.
  ~50 000 iron-rich rock ground (floor 3 walls give 0.1 a hit), or
  10 000 iron ore from veins.
- **Steel:** the 4 → 5 shaft's 3 000 steel is 15 000 iron plates on top.
- **Rock to get rid of:** the 2 → 3 shaft's 8 stone a second needs ~6
  stone grinders (1.5 stone a second each, plus 12 gravel and 24 sand
  grinders and 24 winnowers to finish it off); hardened stone (10 s a piece
  to gravel, for now) needs 50 grinders on the 3 → 4 shaft and 150 on the
  4 → 5 one, to keep up.
- **The drill's spare coal:** the 2 → 3 shaft brings up ~250 coal against
  its own ~190 coal of fuel, so it pays its fuel bill (not its heads'
  firing); the others don't.

## Surface (no ore)

- **Has:** trees (wood), rocks (stone), the crash site: the core drill in
  the ship along with 5 wooden drill heads, and 2 coal in the wreckage to
  start it with. Lakes for water.
- **Make:** wooden drill heads, stone furnaces.
- **Shaft to floor 1:** 20 hits (10 wooden heads), each hit bringing up
  8–10 clay and (on 3 hits in 4) 3 sand (~180 clay, ~45 sand to start with). The core drill takes any
  drill head and hits as fast as a tunnel bore four times over, but grinds
  heads down five times faster: a head lasts a fifth of its hits in it. The
  core drill is the factory's main sink for drill heads. A yellow loader
  on each side without stairs carries its drops out (up to 30 a second),
  once that side is dug out, like a bore's.

## Floor 1 — clay (hardness 20) ✔

- **Arrival unlocks:** tunnel bore Mk1 (wood, clay bricks, glass; lays no
  belts), clay drill heads, glass (smelted from sand). Bricks are fired from
  clay.
- **Landing:** only the drill's spot, the stairs and one row beyond them are
  open, as wide as the drill; each side is reached by its own stairs, the
  rest has to be dug out.
- **Walls give per step:** ~12 clay, ~6 stone (rubble to get rid of — a
  central theme), ~1.5 coal, ~2 sand. 1.6 clay heads and 40 s per step in a
  Mk1.
- **Clay balance:** a clay head (5 clay) lasts 25 hits, 0.2 clay a hit. Plain
  walls give 0.3 a hit, so only a third of the heads made can be sent to the
  core drill or floor 2; a clay vein (200 hits a tile) gives 1–2 a hit, so 87% can, 13 times
  as many spare heads per hit. The clay veins are floor 1's real head
  factories. Stone veins give no clay at all.
- **No iron here:** supplies are carried down the stairs.
- **Shaft to floor 2:** 400 hits (80 clay heads, 400 clay): 2 stone and 0.2
  of floor 2's iron-rich rock a second (~200 and ~20; the rock is sortable
  once floor 2 is reached), so floor 1 has no iron of its own.
- **Base tech tier:** none yet (stone furnaces, hand crafting).

## Floor 2 — iron, no copper (hardness 80) ✔

- **Arrival unlocks:** grinders and winnowers, sorting iron-rich rock by hand
  (including what the shaft brought up), smelting granules; pipes, the pipe
  down and the offshore pump.
- **Walls give per step:** 40 iron-rich rock, ~5 coal; no iron veins and
  **no copper at all**:
  - **Sorted by hand** (2 s each): 20% iron ore, 2% coal, otherwise stone:
    as much iron as grinding gets out (~8 iron ore a step), but slow, and
    it needs no machines.
  - **Ground** in a grinder (2 s each): one gravel, plus iron granules 80% of
    the time: ~32 granules a step. Four smelt into a plate, so ~8 iron
    plates a step, but iron heads (2 a step, 8 plates) would eat all of it,
    belts and all. So floor 2 is dug with clay heads sent down from floor 1,
    which forces floor 2's automation. Iron heads are unlocked here too, for
    reaching veins quickly, not for digging out room.
- **No electricity:** without copper there are no power poles, so the first
  assembling machine burns fuel (and needs no circuits), and steam power
  waits for floor 3's copper. The splitter and long-handed inserter, which
  take circuits, come with electronics.
- **Discovery — iron-rich rock:** the tunnel bore Mk2, which lays its own belt
  lanes. Red tier (automation, logistics); military waits
  for floor 4.
- **Shaft to floor 3:** 10 000 hits through floor 2's own rock — 2 000 clay
  heads (10 000 clay, a clay vein's worth and more), about 42 minutes of
  digging: 8 stone a second (~20 000) and a touch of iron-rich rock and
  coal, a real load for floor 2's grinders. The drill stops whenever its
  output isn't cleared away.
- **Problem it poses:** glass for pipes comes from floor 1 sand, water from
  the surface — the first cross-floor supply chains, all flowing down.

## Floor 3 — copper and coal (hardness 320)

- **Walls give per step:** ~64 iron-rich and ~64 copper-rich rock (~13
  plates of each, ground), ~10 coal; copper, iron and coal veins. A step
  takes 8 iron heads (32 plates).
- **Discovery — copper-rich rock:** steam power (boilers, steam engines);
  crafting copper plates brings electronics, power poles and the green
  tier.
- **Arrival unlocks:** sorting copper-rich rock and smelting its granules;
  up ends for belts and pipes, so things can come back up.
- **Shaft to floor 4:** 40 000 hits — 2 500 iron heads (10 000 iron plates' worth), about 55 minutes of
  digging: hardened stone, 5 a second (~16 700). Halfway down: the
  manhole.

## Floor 4 — sulfur and oil (hardness 1280)

- **Walls give per step:** ~50 iron-rich and ~50 copper-rich rock (~10
  plates of each), ~20 sulfur, ~20 coal. Veins of sulfur and coal; **oil
  pockets** leave a crude oil well for a pumpjack when a tunnel breaks into
  them.
- **Arrival unlocks:** reinforced drill heads, steel, power connectors, oil gathering,
  plastics, sulfur processing; the military tier, from the first turrets
  on (enemies are meant to start here).
- **Mk3:** oil processing brings the Mk3 bore and
  its coolant: 100 water, 20 petroleum gas and 2 dust make 100 bore coolant
  in a chemical plant; with lubricant, 4 lubricant replace the petroleum. A
  Mk3 uses 100 a second while digging, so the oil industry and the rock
  disposal both feed it.
- **Shaft to floor 5:** 100 000 hits — 1 000 reinforced heads (3 000 steel, 2 000 copper), about 46
  minutes: hardened stone at three times the rate, 15 a second (~41 700).

## Floor 5 — hot rock (hardness 5120)

- **Hazard — heat:** only the coolant-cooled Mk3 bore can dig here; others
  stop with "too hot".
- **Walls give per step:** ~150 iron-rich and ~150 copper-rich rock (~30
  plates of each), ~20 sulfur; uranium, iron and copper veins. Uranium is
  only in its veins.
- **Arrival unlocks:** hardened drill heads, and the blue tier
  (with blue crafting milestones along the way).
- **Shaft to floor 6:** not yet — floor 5 is the deepest. Floor 6 is to
  bring carbide drill heads.

## Tech tree

There is no science and no lab. Red, green, military and blue technologies
unlock by progression instead (`shared/progression.lua`): either on reaching
a floor (once their prerequisites are done) or with the game's own crafting,
fluid and building triggers. Science pack technologies are removed.
Examples:

| Trigger | Unlocks |
|---|---|
| Craft 30 iron plates (floor 2) | automation (burner assembling machine) |
| Dig up copper-rich rock (floor 3) | steam power |
| Craft 10 belts, 100 bricks | logistics, stone walls |
| Craft 10 copper plates (floor 3) | electronics |
| Reach floor 3 | radar, logistics 2, toolbelt |
| Craft circuits (25/50/100/200) | lamps, repair packs, fast inserters, circuit network |
| Reach floor 4 | steel, oil gathering, plastics, sulfur |
| Craft steel / engines / plastic | automation 2, engines, railways, advanced circuits |
| Reach floor 4 | military, gun turrets, damage and shooting speed 1, flamethrower, energy shields |
| Craft 200 magazines (floor 4) | damage and shooting speed 2 |
| Craft piercing rounds / grenades / explosives | defender, damage upgrades, rocketry, land mines |
| Craft plastic, heavy oil, lubricant, robot frames | advanced oil, lubricant, electric engines, robotics |
| Craft processing units / batteries | level-2 modules, lasers |
| Reach floor 5 | batteries, modules, power armour, laser weapons, tank |
| Dig up uranium ore (floor 5) | uranium processing |
| Reach floor 9 (none yet) | landfill |

Production, utility and space science technologies keep their costs and are
out of reach until deeper floors exist.

## Open questions

- **Enemies:** from floor 4 on (the military tier unlocks there); surface
  too, or only underground?
