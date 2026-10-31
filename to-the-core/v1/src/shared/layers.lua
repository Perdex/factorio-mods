-- Underground floors, in descending order. Shared by the data and control
-- stages. FLOORS.md has the plan behind the numbers.
--
-- shaft: the core drill's dig from the floor above (the starting surface for
--   floor 1) down into this one: `hits` drill head hits deep, each bringing up
--   `drops` like a tunnel bore's. Any drill head works; better ones dig faster.
--   The rates below are with the heads meant for each shaft (the core drill
--   hits 4 times a second with clay heads, 12 with iron, 36 with reinforced).
--   `unlocks`: technologies researched once a shaft is `progress` (0..1) of the
--   way down, with a `message` to the force.
-- reached_unlocks: technologies researched when a shaft first reaches the layer.
-- hits_per_tile: wall hardness, the hits it takes to break one tile, whatever
--   the bore (a vein's tile takes `hardness` times as many). Meant to grow
--   steeply with depth.
-- drops: wall material per tunnel bore hit, as chance (0..1) and inclusive
--   amounts. Rolled once per hit, for the tile the hit lands on; a bore's
--   hits take turns over the tiles in front of it (runtime/bore.lua). So a
--   tile always takes the same hits and gives the same drops; the "per step"
--   totals below are for a 2-wide bore's step (two tiles), and a Mk3's step
--   (three tiles) takes and gives 1.5 times as much.
-- unlocks: technologies researched when a bore on this layer first outputs an item.
-- veins: patches of harder rock hidden in the walls, each `hardness` times the
--   floor's hits per tile, yielding `drops` per hit instead of the floor's.
--   Placed from the map seed: the floor is split into `cell`-tile squares,
--   each holding a vein with probability `chance`, `radius` tiles across.
--   `name` names the vein; `sprite` is the base resource whose ore sprite
--   marks it in the wall (default `name`), with an optional `tint`.
--   `resource`: breaking into the vein leaves that resource entity (once per
--   vein), e.g. crude oil for pumpjacks.
-- needs_coolant: too hot for tunnel bores without coolant (Mk3).
--
-- Coal: a bore burns the same per hit whatever its tier, by head: 450 kJ
-- (wooden), 150 kJ (clay), 50 kJ (iron); coal holds 4 MJ. Floors 1 and 2 are
-- dug with clay heads (0.0375 coal a hit). Floor 1 gives that back (0.0375,
-- with firing the heads and smelting still to pay for), floor 2 about 90%
-- (0.034): surface rocks top it up now and then until coal veins turn up.
local layers = {
  {
    name = "floor_1",
    surface_name = "ttc-floor-1",
    tunnel_tile = "dirt-7",
    -- 10 wooden heads' worth (2 hits each in the core drill), ~180 clay to
    -- start with and ~45 sand.
    shaft = {
      hits = 20,
      drops = {
        {name = "ttc-sand", chance = 0.75, minimum = 3, maximum = 3},
        {name = "ttc-clay", chance = 1, minimum = 8, maximum = 10}
      }
    },
    reached_unlocks = {"ttc-reach-floor-1"},
    -- Clay: 20 hits a tile, so a 2-wide step takes 1.6 clay heads and 40 s in
    -- a Mk1, or four wooden heads.
    hits_per_tile = 20,
    -- Per step: ~12 clay, ~6 stone (rubble to get rid of), ~1.5 coal (the
    -- clay heads' fuel) and the odd bit of sand.
    drops = {
      -- Clay heads use 0.2 clay a hit, so a third of the heads made from
      -- plain clay walls can be sent off; clay veins (1.5 a hit) give 87%.
      {name = "ttc-clay", chance = 0.3, minimum = 1, maximum = 1},
      {name = "stone", chance = 0.15, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.0375, minimum = 1, maximum = 1},
      {name = "ttc-sand", chance = 0.05, minimum = 1, maximum = 1}
    },
    -- Solid stone: nothing to gain, just rock to dig around (or through).
    -- Clay: soft pockets of pure clay, quicker to dig than solid stone.
    veins = {
      {name = "stone", cell = 20, chance = 0.4, radius = {2, 5}, hardness = 20,
        drops = {{name = "stone", chance = 1, minimum = 1, maximum = 2}}},
      {name = "ttc-clay", sprite = "stone", tint = {r = 0.85, g = 0.55, b = 0.4}, cell = 24, chance = 0.77,
        radius = {2, 4}, hardness = 10, drops = {{name = "ttc-clay", chance = 1, minimum = 1, maximum = 2}}}
    }
  },
  {
    name = "floor_2",
    surface_name = "ttc-floor-2",
    tunnel_tile = "dirt-4",
    -- 80 clay heads. 2 stone and 0.2 of floor 2's iron-rich rock a second
    -- (~200 and ~20 in all); the rock can only be sorted once floor 2 is
    -- reached.
    shaft = {
      hits = 400,
      drops = {
        {name = "stone", chance = 0.5, minimum = 1, maximum = 1},
        {name = "ttc-iron-rich-rock", chance = 0.05, minimum = 1, maximum = 1}
      }
    },
    reached_unlocks = {"ttc-reach-floor-2"},
    -- Stone, four times harder than clay, soft enough to go looking for the
    -- coal veins. Iron is found here.
    hits_per_tile = 80,
    -- Per step: 40 iron-rich rock and ~5 coal (about 90% of the clay heads'
    -- fuel). No copper. Sorted by hand, the rock gives ~8 iron ore; ground,
    -- ~32 iron granules (4 make a plate):
    -- 8 iron plates, just what the 2 iron heads a step would take, so iron
    -- digging doesn't pay for itself. Clay heads from floor 1 dig here.
    drops = {
      {name = "ttc-iron-rich-rock", chance = 0.25, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.034, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "stone", cell = 24, chance = 0.3, radius = {3, 6}, hardness = 20,
        drops = {{name = "stone", chance = 1, minimum = 1, maximum = 2}}},
      -- Fuel for the bores, little needed until power grows: small but
      -- common, found within ~63 tiles of tunnel, ~37 000 coal a vein.
      {name = "coal", cell = 24, chance = 0.8, radius = {3, 4.5}, hardness = 20,
        drops = {{name = "coal", chance = 0.5, minimum = 1, maximum = 1}}}
    },
    unlocks = {
      {item = "ttc-iron-rich-rock", technology = "ttc-iron-discovery"}
    }
  },
  -- Copper, coal and more iron.
  {
    name = "floor_3",
    surface_name = "ttc-floor-3",
    tunnel_tile = "red-desert-2",
    -- The deep shafts are projects: 2000 clay heads, and the drill stops
    -- whenever its output isn't cleared. 8 stone a second (~20 000 in all)
    -- and a touch of floor 2's iron-rich rock and coal.
    shaft = {
      hits = 10000,
      drops = {
        {name = "stone", chance = 1, minimum = 2, maximum = 2},
        {name = "ttc-iron-rich-rock", chance = 0.05, minimum = 1, maximum = 1},
        {name = "coal", chance = 0.025, minimum = 1, maximum = 1}
      }
    },
    reached_unlocks = {"ttc-reach-floor-3"},
    hits_per_tile = 320,
    -- Per step: ~64 iron-rich and ~64 copper-rich rock (~13 plates of each
    -- when ground), ~10 coal. Plain ore only in the veins.
    drops = {
      {name = "ttc-iron-rich-rock", chance = 0.1, minimum = 1, maximum = 1},
      {name = "ttc-copper-rich-rock", chance = 0.1, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.015, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "copper-ore", cell = 30, chance = 0.6, radius = {4, 7}, hardness = 20,
        drops = {{name = "copper-ore", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "coal", cell = 30, chance = 0.6, radius = {2, 5}, hardness = 20,
        drops = {{name = "coal", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "iron-ore", cell = 30, chance = 0.6, radius = {4, 7}, hardness = 20,
        drops = {{name = "iron-ore", chance = 0.5, minimum = 1, maximum = 1}}}
    }
  },
  -- Sulfur and oil; steel arrives. Oil veins are soft pockets that leave a
  -- crude oil well for a pumpjack once a tunnel breaks into them.
  {
    name = "floor_4",
    surface_name = "ttc-floor-4",
    tunnel_tile = "dry-dirt",
    -- 2500 iron heads; hardened stone that doesn't stack and can't be sorted
    -- by hand, 5 a second (~16 700 in all).
    shaft = {
      hits = 40000,
      drops = {
        {name = "ttc-hardened-stone", chance = 5 / 12, minimum = 1, maximum = 1}
      },
      unlocks = {
        {progress = 0.5, technology = "ttc-manhole", message = "ttc.manhole-realized"}
      }
    },
    reached_unlocks = {"ttc-reach-floor-4"},
    hits_per_tile = 1280,
    -- Per step: ~50 iron-rich and ~50 copper-rich rock (~10 plates of each),
    -- ~20 sulfur, ~20 coal.
    drops = {
      {name = "ttc-iron-rich-rock", chance = 0.02, minimum = 1, maximum = 1},
      {name = "ttc-copper-rich-rock", chance = 0.02, minimum = 1, maximum = 1},
      {name = "sulfur", chance = 0.008, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.008, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "sulfur", sprite = "stone", tint = {r = 1, g = 0.95, b = 0.35}, cell = 36, chance = 0.6,
        radius = {3, 6}, hardness = 20, drops = {{name = "sulfur", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "coal", cell = 33, chance = 0.6, radius = {2, 5}, hardness = 20,
        drops = {{name = "coal", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "crude-oil", sprite = "coal", tint = {r = 0.45, g = 0.4, b = 0.55}, cell = 22, chance = 0.6,
        radius = {2, 3}, hardness = 1, resource = {name = "crude-oil", amount = 600000},
        drops = {{name = "stone", chance = 0.02, minimum = 1, maximum = 1}}}
    }
  },
  -- Hot rock: only coolant-cooled bores can work here. Uranium.
  {
    name = "floor_5",
    surface_name = "ttc-floor-5",
    tunnel_tile = "red-desert-0",
    needs_coolant = true,
    -- 1000 reinforced heads; hardened stone at three times the rate, 15 a
    -- second (~41 700 in all).
    shaft = {
      hits = 100000,
      drops = {
        {name = "ttc-hardened-stone", chance = 5 / 12, minimum = 1, maximum = 1}
      }
    },
    reached_unlocks = {"ttc-reach-floor-5"},
    hits_per_tile = 5120,
    -- Per step: ~150 iron-rich and ~150 copper-rich rock (~30 plates of
    -- each), ~20 sulfur. Uranium only in its veins.
    drops = {
      {name = "ttc-iron-rich-rock", chance = 0.015, minimum = 1, maximum = 1},
      {name = "ttc-copper-rich-rock", chance = 0.015, minimum = 1, maximum = 1},
      {name = "sulfur", chance = 0.002, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "uranium-ore", cell = 29, chance = 0.6, radius = {2, 5}, hardness = 20,
        drops = {{name = "uranium-ore", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "iron-ore", cell = 31, chance = 0.6, radius = {3, 6}, hardness = 20,
        drops = {{name = "iron-ore", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "copper-ore", cell = 31, chance = 0.6, radius = {3, 6}, hardness = 20,
        drops = {{name = "copper-ore", chance = 0.5, minimum = 1, maximum = 1}}}
    }
  }
}

return layers
