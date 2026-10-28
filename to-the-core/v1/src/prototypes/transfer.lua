-- Item chutes, downpipes and power connectors (down), freight lifts and lift
-- pumps (up): one-way links between floors. Sprites are
-- rendered by v1/tools/transfer_gfx.py.
local transfer = require("shared.transfer")

local graphics = "__to-the-core__/graphics/"
local flags = {"placeable-neutral", "placeable-player", "player-creation"}

local function sprite(name)
  return {
    filename = graphics .. "entities/" .. name .. ".png",
    width = 96,
    height = 96,
    scale = 0.5
  }
end

-- Storage tanks only take two-way connections; the script alone moves fluid
-- from inlet to outlet, so nothing goes back up.
local function pipe_connections()
  local connections = {}
  for _, direction in ipairs({defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}) do
    connections[#connections + 1] = {direction = direction, position = {0, 0}}
  end
  return connections
end

local function storage_tank(name, item, picture, icon)
  return {
    type = "storage-tank",
    name = name,
    icon = graphics .. "icons/" .. (icon or "downpipe") .. ".png",
    icon_size = 64,
    flags = flags,
    minable = {mining_time = 0.3, result = item},
    placeable_by = {item = item, count = 1},
    max_health = 100,
    collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    fluid_box = {
      volume = 400,
      pipe_connections = pipe_connections(),
      hide_connection_info = false
    },
    two_direction_only = false,
    window_bounding_box = {{0, 0}, {0, 0}},
    flow_length_in_ticks = 1,
    pictures = {picture = sprite(picture)},
    impact_category = "metal"
  }
end

local function container(name, item, picture, icon)
  return {
    type = "container",
    name = name,
    icon = graphics .. "icons/" .. (icon or "item-chute") .. ".png",
    icon_size = 64,
    flags = flags,
    minable = {mining_time = 0.3, result = item},
    placeable_by = {item = item, count = 1},
    max_health = 100,
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    inventory_size = 16,
    picture = sprite(picture),
    impact_category = "wood"
  }
end

local chute = transfer.kinds.item_chute
local downpipe = transfer.kinds.downpipe
local power = transfer.kinds.power
local lift = transfer.kinds.freight_lift
local lift_pump = transfer.kinds.lift_pump

local function transfer_item(kind, icon, order)
  return {
    type = "item",
    name = kind.item,
    icon = graphics .. "icons/" .. icon .. ".png",
    icon_size = 64,
    subgroup = "ttc-boring",
    order = "e[transfer]-" .. order,
    place_result = kind.inlet,
    stack_size = 20
  }
end

local function transfer_recipe(kind, ingredients)
  local recipe = {
    type = "recipe",
    name = kind.item,
    categories = {"crafting"},
    enabled = false,
    energy_required = 5,
    ingredients = {},
    results = {{type = "item", name = kind.item, amount = 1}}
  }
  for _, ingredient in ipairs(ingredients) do
    recipe.ingredients[#recipe.ingredients + 1] = {type = "item", name = ingredient[1], amount = ingredient[2]}
  end
  return recipe
end

local function power_pole(name)
  local pole = table.deepcopy(data.raw["electric-pole"]["medium-electric-pole"])
  pole.name = name
  pole.icon = graphics .. "icons/power-connector.png"
  pole.icon_size = 64
  pole.icons = nil
  pole.minable = {mining_time = 0.3, result = power.item}
  pole.placeable_by = {item = power.item, count = 1}
  pole.next_upgrade = nil
  pole.fast_replaceable_group = nil
  -- Covers its own tile, where the hidden energy interface sits.
  pole.supply_area_distance = 0.5
  return pole
end

local function energy_interface(name, priority)
  return {
    type = "electric-energy-interface",
    name = name,
    icon = graphics .. "icons/power-connector.png",
    icon_size = 64,
    hidden = true,
    flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
    selectable_in_game = false,
    collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
    collision_mask = {layers = {}},
    energy_source = {
      type = "electric",
      usage_priority = priority,
      buffer_capacity = power.buffer,
      input_flow_limit = priority == "secondary-input" and power.power or "0W",
      output_flow_limit = priority == "secondary-output" and power.power or "0W"
    },
    energy_production = "0W",
    energy_usage = "0W"
  }
end

data:extend({
  container(chute.inlet, chute.item, "item-chute-top"),
  container(chute.outlet, chute.item, "item-chute-bottom"),
  storage_tank(downpipe.inlet, downpipe.item, "downpipe-top"),
  storage_tank(downpipe.outlet, downpipe.item, "downpipe-bottom"),
  container(lift.inlet, lift.item, "freight-lift-bottom", "freight-lift"),
  container(lift.outlet, lift.item, "freight-lift-top", "freight-lift"),
  storage_tank(lift_pump.inlet, lift_pump.item, "lift-pump-bottom", "lift-pump"),
  storage_tank(lift_pump.outlet, lift_pump.item, "lift-pump-top", "lift-pump"),
  transfer_item(lift, "freight-lift", "d[freight-lift]"),
  transfer_item(lift_pump, "lift-pump", "e[lift-pump]"),
  transfer_recipe(lift, {{"steel-plate", 20}, {"iron-gear-wheel", 20}, {"electronic-circuit", 10}, {"stone-brick", 20}}),
  transfer_recipe(lift_pump, {{"steel-plate", 20}, {"pipe", 20}, {"engine-unit", 5}, {"electronic-circuit", 10}}),
  power_pole(power.inlet),
  power_pole(power.outlet),
  energy_interface(power.sink, "secondary-input"),
  energy_interface(power.source, "secondary-output"),
  {
    type = "item",
    name = power.item,
    icon = graphics .. "icons/power-connector.png",
    icon_size = 64,
    subgroup = "ttc-boring",
    order = "e[transfer]-c[power-connector]",
    place_result = power.inlet,
    stack_size = 20
  },
  {
    type = "recipe",
    name = power.item,
    categories = {"crafting"},
    enabled = false,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "medium-electric-pole", amount = 2},
      {type = "item", name = "copper-cable", amount = 20},
      {type = "item", name = "stone-brick", amount = 10}
    },
    results = {{type = "item", name = power.item, amount = 1}}
  },
  {
    type = "item",
    name = chute.item,
    icon = graphics .. "icons/item-chute.png",
    icon_size = 64,
    subgroup = "ttc-boring",
    order = "e[transfer]-a[item-chute]",
    place_result = chute.inlet,
    stack_size = 20
  },
  {
    type = "item",
    name = downpipe.item,
    icon = graphics .. "icons/downpipe.png",
    icon_size = 64,
    subgroup = "ttc-boring",
    order = "e[transfer]-b[downpipe]",
    place_result = downpipe.inlet,
    stack_size = 20
  },
  {
    type = "recipe",
    name = chute.item,
    categories = {"crafting"},
    enabled = false,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "wood", amount = 10},
      {type = "item", name = "stone", amount = 10}
    },
    results = {{type = "item", name = chute.item, amount = 1}}
  },
  {
    type = "recipe",
    name = downpipe.item,
    categories = {"crafting"},
    enabled = false,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "pipe", amount = 10},
      {type = "item", name = "stone", amount = 10}
    },
    results = {{type = "item", name = downpipe.item, amount = 1}}
  }
})
