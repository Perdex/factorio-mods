# To the Core

An early playable slice of a Factorio 2.1 digging-progression mod.

## Try it in-game

Copy the `to-the-core` directory into Factorio's `mods` directory as
`to-the-core_0.1.0`, enable the mod, and start a new game. New players receive
a core drill and a starter supply of iron plates, stone, wood, gears, belts
and drill heads.

1. The starting surface has no ore. Salvage the core drill from the crashed
   ship and blades from the wreckage, and gather wood and stone. Wooden drill
   heads take 2 wood, 1 stone and a blade. Place the core drill (5x5) and feed
   it fuel and wooden heads, one per segment. Like a rocket silo building
   rocket parts, it crafts 20 shaft segments, each bringing up 10-20 sand and
   20-30 clay; its status shows the progress.
2. When the shaft breaks through, a pit is left behind with stairs going down
   along its north and south rims, and the drill moves down onto a small
   landing on the first underground layer. Walk down either stairway to follow
   it, and back up the same stairs below to return. Anything left in the drill
   moves down with it; take it out, then feed the drill the next layer's
   (harder) inputs. Shafts to even layers have their stairs on the west and
   east rims instead, so a layer's landing and its next pit don't overlap.
3. Floor 1 reveals the Mk1 tunnel bore (2x2), built from wood, stone, clay
   and blades; clay drill heads (shape clay, then fire it in a furnace); glass
   (smelted from sand); and item chutes, which drop items to the floor below.
   Like an offshore pump the bore can only be placed at the edge of open
   ground, facing the rock wall it will dig into.
4. Open the bore. It works like a burner assembler: a fuel slot with its own
   burn bar, a dig recipe (picked from the drill heads you carry when placing
   it, changeable in the GUI) and a crafting progress bar. Drill heads wear
   out like repair packs: one craft is one head's life, and the progress bar
   shows it wearing down. Floor 1 is clay, 40 hits per tile: two clay heads
   and 80 s. Each tile yields about 20 clay, some stone, coal and sand. Iron is
   on floor 2, which is four times harder.
5. Once it has belts, the bore lays two per tile behind itself: the left lane carries
   supplies (fuel, heads, belts) in and the right lane carries drops out.
   Hidden loaders follow its rear to connect them. Belts that arrive on the
   supply lane go into the bore's belt stock (up to 10), so run belts on one
   lane of the supply belt and heads and fuel on the other.
6. If anything stands in the tiles ahead, the bore pauses without consuming
   anything and shows "Tunnel ahead is blocked".
7. Things only flow down at first: item chutes and (from floor 2) downpipes
   link a spot to the same spot on the floor below, which must already be
   dug out. Water comes down from the surface's lakes; pipes need glass.
   See `FLOORS.md` for the plan of floors 1-5.

Tunnels are edged with cliff faces. The "Testing starter kit" map setting
(on by default) also gives the first player two bores and plenty of
materials. The plan for floors 1-5 is in `FLOORS.md`. Run `../deploy_local.sh` to link the mod
into `~/.factorio/mods`, and `../tests/run.sh` for the headless engine test.

## Current scope

This version contains two underground layers (the second is a placeholder)
and one bore tier. The underground
surface is void outside its small starting platform and the tunnel the bore
opens. Its lanes automatically supply belts and drill heads to the bore and
carry its drops away. Layers, their shaft and dig recipes (ingredients and times),
drops and unlocks are configured in `shared/layers.lua`; the dig recipes
are generated from it in `prototypes/bore.lua`. Graphics are rendered by the scripts in
`../tools/`. The layer marks its starting chunks generated before
placing tiles, avoiding normal terrain generation during entry.
