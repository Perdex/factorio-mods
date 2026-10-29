-- Tunnel bore constants shared by the data and control stages.
local bore = {
  -- Mk1 (wood and clay bricks) only digs; Mk2 also lays its own supply and
  -- output belt lanes and has the loaders that connect them; Mk3 is much
  -- faster but needs bore coolant (`coolant_fluid`), `coolant` units a second
  -- while it digs.
  tiers = {
    ["ttc-mk1-bore"] = {sprite = "mk1", speed = 1, energy = "150kW", lays_belts = false},
    ["ttc-mk2-bore"] = {sprite = "mk2", speed = 2, energy = "300kW", lays_belts = true},
    -- 3 wide: its coolant inlet sits in the middle of its back, between the
    -- belt lanes, and it lays a pipe there as it advances.
    ["ttc-mk3-bore"] = {sprite = "mk3", speed = 5, energy = "750kW", lays_belts = true, coolant = 100,
      width = 3, lays_pipes = true}
  },
  recipe_category = "ttc-dig",
  -- Mostly water, with a little petroleum gas or lubricant and dust
  -- (prototypes/bore.lua).
  coolant_fluid = "ttc-coolant",
  -- Belts laid behind the bore per tile as its supply and output lanes. Taken
  -- from the supply lane into the bore's belt stock, not via the dig recipe.
  paving_item = "transport-belt",
  paving_count = 2,
  -- Most belts the stock holds; feed them on one lane of the supply belt.
  belt_stock_limit = 10,
  -- Pipes a coolant bore lays behind its inlet, one per tile, pulled off the
  -- supply lane the same way.
  pipe_item = "pipe",
  pipe_stock_limit = 10,
  -- A hidden constant combinator wired to the bore puts its own signals on
  -- the bore's circuit network: hits remaining and a one-tick pulse when it
  -- moves (contents, ingredients and fuel are the furnace's own circuit
  -- settings). Turn signals on that network turn it as it moves.
  signal_entity = "ttc-bore-signals",
  hits_signal = {type = "virtual", name = "signal-H"},
  moved_signal = {type = "virtual", name = "signal-check"},
  clockwise_signal = {type = "virtual", name = "signal-clockwise-circle-arrow"},
  anticlockwise_signal = {type = "virtual", name = "signal-anticlockwise-circle-arrow"},
  -- Drill heads wear out like repair packs: a head lasts `durability` hits,
  -- each taking `hit_time` seconds at crafting speed 1. A dig recipe craft is
  -- one head's whole life, so its progress bar shows the head wearing down.
  -- Dig recipes are always enabled, so a bore takes any head the player has;
  -- crafting the heads is what unlocks over time (prototypes/items.lua).
  -- `own_description`: the item keeps its own description after the stats.
  heads = {
    -- Each kind hits three times as fast as the one before.
    wooden = {item = "ttc-wooden-drill-head", durability = 10, hit_time = 3},
    -- Unfired clay crumbles after a single hit; firing it is worth the wait.
    unfired_clay = {item = "ttc-unfired-clay-drill-head", durability = 1, hit_time = 1, own_description = true},
    clay = {item = "ttc-clay-drill-head", durability = 20, hit_time = 1},
    iron = {item = "ttc-iron-drill-head", durability = 80, hit_time = 1 / 3},
    reinforced = {item = "ttc-reinforced-drill-head", durability = 500, hit_time = 1 / 9},
    hardened = {item = "ttc-hardened-drill-head", durability = 3000, hit_time = 1 / 27},
    carbide = {item = "ttc-carbide-drill-head", durability = 15000, hit_time = 1 / 81}
  }
}

-- The bore is a furnace: inserting a head picks its dig recipe, like ammo in a
-- turret. One recipe per head, whatever the floor; the floor's drops come out
-- per hit (runtime/wear.lua).
function bore.recipe_name(head_name)
  return "ttc-dig-" .. head_name
end

bore.recipe_heads = {}
for head_name, head in pairs(bore.heads) do
  bore.recipe_heads[bore.recipe_name(head_name)] = head
end

return bore
