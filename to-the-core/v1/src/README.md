# To the Core

An early playable slice of a Factorio 2.1 digging-progression mod.

## Try it in-game

Copy the `to-the-core` directory into Factorio's `mods` directory as
`to-the-core_0.1.0`, enable the mod, and start a new game. New players receive
a core drill and a starter supply of iron plates, stone, wood, gears, belts
and drill heads.

1. The starting surface has no ore. Salvage the core drill and five wooden
   drill heads from the crashed ship and 2 coal from the wreckage, and gather
   wood and stone. Wooden drill
   heads take 2 wood and 1 stone. Place the core drill (5x5) and feed
   it fuel and drill heads: it takes any head, like the tunnel bore, and wears
   them out hit by hit. The shaft to floor 1 is 100 hits deep (10 wooden
   heads), each hit bringing up sand and clay; a panel beside its window shows the shaft's depth.
2. When the shaft breaks through, a pit is left behind with stairs going down
   along its north and south rims, and the drill moves down onto a small
   landing on the first underground layer. Walk down either stairway to follow
   it, and back up the same stairs below to return. Everything in the drill moves
   down with it, and it carries on with the next, deeper shaft. Shafts to even layers have their stairs on the west and
   east rims instead, so a layer's landing and its next pit don't overlap.
3. The landing below is only the drill's spot and, on the stair sides, the
   stairs and one row beyond them: reach each side by its own stairs, and
   dig out the rest. Walking past the middle of a stairway takes you to the
   middle of the same stairs on the other floor. Floor 1 reveals
   the tunnel bore Mk1 (2x2, wood, clay bricks and glass), clay drill heads
   (shape clay, then fire it in a furnace), glass (smelted from sand) and
   bricks (fired from clay). The bore can be placed anywhere on open
   ground, facing the rock it will dig into.
4. Open the bore. It works like a burner furnace: no recipe to choose, just
   put in any drill head you have unlocked and it digs with it, the way a
   turret takes any ammo. It has a fuel slot with its own burn bar and a
   progress bar that shows the current head wearing down (heads wear out like
   repair packs). The floor decides how hard the rock is and what comes out:
   floor 1 is clay, 40 hits per tile: two clay heads and 40 s in a Mk1. Each tile
   yields about 20 clay and a lot of loose stone, plus a little coal and
   sand: getting rid of the rock is part of the job. Iron is on floor 2,
   which is four times harder.
5. The tunnel bore Mk2 (unlocked by finding iron) also lays two belts per
   tile behind itself, once it has belts: the left lane carries
   supplies (fuel, heads, belts) in and the right lane carries drops out.
   Hidden loaders follow its rear to connect them. Belts that arrive on the
   supply lane go into the bore's belt stock (up to 10), so run belts on one
   lane of the supply belt and heads and fuel on the other.
6. The rock hides veins, shown by ore on the exposed rock face: twenty
   times harder to dig, but they yield their resource in bulk (on floor 1
   just stone, an obstacle to dig around).
7. If anything stands in the tiles ahead, the bore pauses without consuming
   anything and shows "Tunnel ahead is blocked".
8. Underground belts and pipes-to-ground really go underground: each comes
   as a down end and an up end, and its other end opens directly below on
   the next floor, which must already be dug out. To cross something, route
   the belt through the floor below and bring it back up. Up ends unlock on
   floor 3, so until then things only go down. Halfway down the shaft to
   floor 4 comes the manhole, a hole to jump into that lands you on the
   floor below. From floor 4, power connectors carry electricity down. Water comes down from the
   surface's lakes; pipes need glass.
   See `FLOORS.md` for the plan of floors 1-5.

Digging leaves far more stone than anything needs. From floor 2, grinders
crush it to gravel, sand and dust, and winnowers on the surface let the wind
carry the dust away; until then it has to be stored. Tunnels are edged with cliff faces. Run `../deploy_local.sh` to link the mod
into `~/.factorio/mods`, and `../tests/run.sh` for the headless engine test.

## Current scope

Five floors: clay; stone with iron; copper and coal; sulfur and oil; and hot
rock that only the water-cooled Mk3 bore can dig. Three bore tiers and six
kinds of drill head. Red, green, military and blue technologies unlock by
reaching floors and by crafting milestones; there is no science and no lab.
Underground belts and pipes go through the floor below. A game
starts with empty pockets.

Floors, shafts, drops, veins and unlocks are configured in
`shared/layers.lua`, drill heads and bore tiers in `shared/bore.lua`, the
technology mapping in `shared/progression.lua`. `FLOORS.md` explains the
plan. Graphics are rendered by the scripts in `../tools/`.
