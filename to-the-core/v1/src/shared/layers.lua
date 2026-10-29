-- Underground floors, in descending order. Shared by the data and control
-- stages. FLOORS.md has the plan behind the numbers.
--
-- shaft: the core drill's dig from the floor above (the starting surface for
--   floor 1) down into this one: `hits` drill head hits deep, each bringing up
--   `drops` like a tunnel bore's. Any drill head works; better ones dig faster.
--   `unlocks`: technologies researched once a shaft is `progress` (0..1) of the
--   way down, with a `message` to the force.
-- reached_unlocks: technologies researched when a shaft first reaches the layer.
-- hits_per_tile: wall hardness, the hits a tunnel bore needs to break through
--   one tile. Meant to grow steeply with depth.
-- drops: wall material per tunnel bore hit, as chance (0..1) and inclusive
--   amounts.
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
return {
  {
    name = "floor_1",
    surface_name = "ttc-floor-1",
    tunnel_tile = "dirt-7",
    -- 10 wooden heads' worth.
    shaft = {
      hits = 100,
      drops = {
        {name = "ttc-sand", chance = 1, minimum = 1, maximum = 2},
        {name = "ttc-clay", chance = 1, minimum = 2, maximum = 3}
      }
    },
    reached_unlocks = {"ttc-reach-floor-1"},
    -- Clay: two clay heads and 80 s per tile, or four wooden heads.
    hits_per_tile = 40,
    -- Per tile: ~20 clay, ~12 stone (rubble to get rid of), ~1 coal for fuel
    -- and the odd bit of sand.
    drops = {
      {name = "ttc-clay", chance = 0.5, minimum = 1, maximum = 1},
      {name = "stone", chance = 0.3, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.025, minimum = 1, maximum = 1},
      {name = "ttc-sand", chance = 0.05, minimum = 1, maximum = 1}
    },
    -- Solid stone: nothing to gain, just rock to dig around (or through).
    -- Clay: soft pockets of pure clay, quicker to dig than solid stone.
    veins = {
      {name = "stone", cell = 20, chance = 0.4, radius = {2, 5}, hardness = 20,
        drops = {{name = "stone", chance = 1, minimum = 1, maximum = 2}}},
      {name = "ttc-clay", sprite = "stone", tint = {r = 0.85, g = 0.55, b = 0.4}, cell = 24, chance = 0.35,
        radius = {2, 4}, hardness = 5, drops = {{name = "ttc-clay", chance = 1, minimum = 1, maximum = 2}}}
    }
  },
  {
    name = "floor_2",
    surface_name = "ttc-floor-2",
    tunnel_tile = "dirt-4",
    -- 20 clay heads' worth.
    shaft = {
      hits = 400,
      drops = {
        {name = "stone", chance = 1, minimum = 1, maximum = 2}
      }
    },
    reached_unlocks = {"ttc-reach-floor-2"},
    -- Stone, four times harder than clay. Iron is found here.
    hits_per_tile = 160,
    -- Per tile: ~40 stone, ~8 iron ore, ~3 coal. A tile takes two iron heads
    -- (8 plates), so iron digging just about keeps itself going.
    drops = {
      {name = "stone", chance = 0.25, minimum = 1, maximum = 1},
      {name = "iron-ore", chance = 0.05, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.02, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "stone", cell = 24, chance = 0.3, radius = {3, 6}, hardness = 20,
        drops = {{name = "stone", chance = 1, minimum = 1, maximum = 2}}},
      -- Hard to break, but each tile gives ~1600 iron ore.
      {name = "iron-ore", cell = 28, chance = 0.3, radius = {2, 5}, hardness = 20,
        drops = {
          {name = "iron-ore", chance = 0.5, minimum = 1, maximum = 1},
          {name = "stone", chance = 0.25, minimum = 1, maximum = 1}
        }}
    },
    unlocks = {
      {item = "iron-ore", technology = "ttc-iron-discovery"}
    }
  },
  -- Copper, coal and more iron.
  {
    name = "floor_3",
    surface_name = "ttc-floor-3",
    tunnel_tile = "red-desert-2",
    -- The deep shafts are projects: ~15 min of digging with iron heads, but
    -- the drill stops whenever its stone isn't cleared (~2000 stone).
    shaft = {
      hits = 10000,
      drops = {
        {name = "stone", chance = 0.2, minimum = 1, maximum = 1}
      }
    },
    reached_unlocks = {"ttc-reach-floor-3"},
    hits_per_tile = 640,
    -- Per tile: ~60 stone, ~20 copper ore, ~10 coal, ~13 iron ore: more iron
    -- than the 16 iron heads (8 plates) a tile takes.
    drops = {
      {name = "stone", chance = 0.1, minimum = 1, maximum = 1},
      {name = "copper-ore", chance = 0.03, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.015, minimum = 1, maximum = 1},
      {name = "iron-ore", chance = 0.02, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "copper-ore", cell = 24, chance = 0.3, radius = {3, 6}, hardness = 20,
        drops = {{name = "copper-ore", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "coal", cell = 28, chance = 0.25, radius = {2, 5}, hardness = 20,
        drops = {{name = "coal", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "iron-ore", cell = 32, chance = 0.2, radius = {2, 4}, hardness = 20,
        drops = {{name = "iron-ore", chance = 0.5, minimum = 1, maximum = 1}}}
    }
  },
  -- Sulfur and oil; steel arrives. Oil veins are soft pockets that leave a
  -- crude oil well for a pumpjack once a tunnel breaks into them.
  {
    name = "floor_4",
    surface_name = "ttc-floor-4",
    tunnel_tile = "dry-dirt",
    -- ~20 min with reinforced heads, ~4000 stone.
    shaft = {
      hits = 40000,
      drops = {
        {name = "stone", chance = 0.1, minimum = 1, maximum = 1}
      },
      unlocks = {
        {progress = 0.5, technology = "ttc-manhole", message = "ttc.manhole-realized"}
      }
    },
    reached_unlocks = {"ttc-reach-floor-4"},
    hits_per_tile = 2560,
    -- Per tile: ~50 stone, ~20 sulfur, ~20 coal, ~10 iron and copper ore.
    drops = {
      {name = "stone", chance = 0.02, minimum = 1, maximum = 1},
      {name = "sulfur", chance = 0.008, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.008, minimum = 1, maximum = 1},
      {name = "iron-ore", chance = 0.004, minimum = 1, maximum = 1},
      {name = "copper-ore", chance = 0.004, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "sulfur", sprite = "stone", tint = {r = 1, g = 0.95, b = 0.35}, cell = 28, chance = 0.3,
        radius = {3, 6}, hardness = 20, drops = {{name = "sulfur", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "coal", cell = 28, chance = 0.25, radius = {2, 5}, hardness = 20,
        drops = {{name = "coal", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "crude-oil", sprite = "coal", tint = {r = 0.45, g = 0.4, b = 0.55}, cell = 40, chance = 0.35,
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
    -- ~15 min with hardened heads, ~5000 stone.
    shaft = {
      hits = 100000,
      drops = {
        {name = "stone", chance = 0.05, minimum = 1, maximum = 1}
      }
    },
    reached_unlocks = {"ttc-reach-floor-5"},
    hits_per_tile = 10240,
    -- Per tile: ~50 stone, ~20 uranium ore, ~30 iron and copper ore, ~20 sulfur.
    drops = {
      {name = "stone", chance = 0.005, minimum = 1, maximum = 1},
      {name = "uranium-ore", chance = 0.002, minimum = 1, maximum = 1},
      {name = "iron-ore", chance = 0.003, minimum = 1, maximum = 1},
      {name = "copper-ore", chance = 0.003, minimum = 1, maximum = 1},
      {name = "sulfur", chance = 0.002, minimum = 1, maximum = 1}
    },
    veins = {
      {name = "uranium-ore", cell = 32, chance = 0.25, radius = {2, 5}, hardness = 20,
        drops = {{name = "uranium-ore", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "iron-ore", cell = 28, chance = 0.3, radius = {3, 6}, hardness = 20,
        drops = {{name = "iron-ore", chance = 0.5, minimum = 1, maximum = 1}}},
      {name = "copper-ore", cell = 28, chance = 0.3, radius = {3, 6}, hardness = 20,
        drops = {{name = "copper-ore", chance = 0.5, minimum = 1, maximum = 1}}}
    }
  }
}
