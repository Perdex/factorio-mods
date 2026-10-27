-- Underground floors, in descending order. Shared by the data and control
-- stages. FLOORS.md has the plan behind the numbers.
--
-- shaft: what a core drill needs to dig from the layer above (the starting
--   surface for the first layer) down into this one. Like rocket parts in a
--   silo, the drill crafts `segments` shaft segments, each taking `time`
--   seconds and consuming `ingredients`; each yields `results` as
--   {item, amount} or {item, minimum, maximum}.
-- reached_unlocks: technologies researched when a shaft first reaches the layer.
-- hits_per_tile: wall hardness, the hits a tunnel bore needs to break through
--   one tile. Meant to grow steeply with depth.
-- dig_recipes: drill heads (see shared/bore.lua) a tunnel bore can dig this
--   layer with; one recipe is generated per entry, named
--   "ttc-dig-<layer>-<head>". Each craft wears out one head.
--   unlocked_by: technology that enables the recipe; enabled from the start if nil.
-- drops: wall material per hit, as chance (0..1) and inclusive amounts. A dig
--   craft pays out its head's whole life at once, as a range around the
--   expected amount.
-- unlocks: technologies researched when a bore on this layer first outputs an item.
return {
  {
    name = "floor_1",
    surface_name = "ttc-floor-1",
    tunnel_tile = "dirt-7",
    shaft = {
      segments = 20,
      time = 4,
      ingredients = {{"ttc-wooden-drill-head", 1}},
      results = {{"ttc-sand", 10, 20}, {"ttc-clay", 20, 30}}
    },
    reached_unlocks = {"ttc-reach-floor-1"},
    -- Clay: two clay heads and 80 s per tile, or four wooden heads.
    hits_per_tile = 40,
    dig_recipes = {
      {head = "wooden"},
      {head = "clay"}
    },
    -- Per tile: ~20 clay, ~4 stone, ~2 coal for fuel and the odd bit of sand.
    drops = {
      {name = "ttc-clay", chance = 0.5, minimum = 1, maximum = 1},
      {name = "stone", chance = 0.1, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.05, minimum = 1, maximum = 1},
      {name = "ttc-sand", chance = 0.025, minimum = 1, maximum = 1}
    }
  },
  {
    name = "floor_2",
    surface_name = "ttc-floor-2",
    tunnel_tile = "dirt-4",
    shaft = {
      segments = 30,
      time = 6,
      ingredients = {{"ttc-clay-drill-head", 2}},
      results = {{"stone", 45, 50}}
    },
    reached_unlocks = {"ttc-reach-floor-2"},
    -- Stone, four times harder than clay. Iron is found here.
    hits_per_tile = 160,
    dig_recipes = {
      {head = "clay"},
      {head = "iron", unlocked_by = "ttc-iron-discovery"}
    },
    -- Per tile: ~40 stone, ~10 iron ore, ~3 coal. With iron heads (4 per
    -- tile, 2 plates) and two belts (3 plates) iron digging pays for itself.
    drops = {
      {name = "stone", chance = 0.25, minimum = 1, maximum = 1},
      {name = "iron-ore", chance = 0.06, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.02, minimum = 1, maximum = 1}
    },
    unlocks = {
      {item = "iron-ore", technology = "ttc-iron-discovery"}
    }
  },
  -- Rough: copper and coal. Floors 4-5 are still only planned in FLOORS.md.
  {
    name = "floor_3",
    surface_name = "ttc-floor-3",
    tunnel_tile = "red-desert-2",
    shaft = {
      segments = 40,
      time = 8,
      ingredients = {{"ttc-iron-drill-head", 2}},
      results = {{"stone", 45, 50}}
    },
    reached_unlocks = {"ttc-reach-floor-3"},
    hits_per_tile = 640,
    dig_recipes = {
      {head = "iron"},
      {head = "reinforced", unlocked_by = "ttc-copper-discovery"}
    },
    -- Per tile: ~60 stone, ~20 copper ore, ~10 coal, ~6 iron ore.
    drops = {
      {name = "stone", chance = 0.1, minimum = 1, maximum = 1},
      {name = "copper-ore", chance = 0.03, minimum = 1, maximum = 1},
      {name = "coal", chance = 0.015, minimum = 1, maximum = 1},
      {name = "iron-ore", chance = 0.01, minimum = 1, maximum = 1}
    },
    unlocks = {
      {item = "copper-ore", technology = "ttc-copper-discovery"}
    }
  }
}
