-- Item chutes and downpipes: one-way links to the floor below. Sprites are
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

local function storage_tank(name, item, picture)
  return {
    type = "storage-tank",
    name = name,
    icon = graphics .. "icons/downpipe.png",
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

local function container(name, item, picture)
  return {
    type = "container",
    name = name,
    icon = graphics .. "icons/item-chute.png",
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

data:extend({
  container(chute.inlet, chute.item, "item-chute-top"),
  container(chute.outlet, chute.item, "item-chute-bottom"),
  storage_tank(downpipe.inlet, downpipe.item, "downpipe-top"),
  storage_tank(downpipe.outlet, downpipe.item, "downpipe-bottom"),
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
