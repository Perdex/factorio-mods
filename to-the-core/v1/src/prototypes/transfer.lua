-- Links to the floor below (shared/transfer.lua): underground belts and
-- pipes-to-ground that go down or come up, and power connectors. Pipe sprites
-- are rendered by v1/tools/transfer_gfx.py; belts use the base game's.
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

-- A base game icon with an arrow in its corner: down, or up for `up` kinds.
local function arrow_icons(icon, up)
  return {
    {icon = icon, icon_size = 64},
    {icon = "__base__/graphics/icons/arrows/" .. (up and "up" or "down") .. "-arrow.png", icon_size = 64,
      scale = 0.25, shift = {-8, -8}}
  }
end

-- Storage tanks only take two-way connections; the script alone moves fluid
-- from inlet to outlet, so nothing goes the other way.
local function pipe_connections()
  local connections = {}
  for _, direction in ipairs({defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}) do
    connections[#connections + 1] = {direction = direction, position = {0, 0}}
  end
  return connections
end

local function storage_tank(name, item, picture, icons)
  return {
    type = "storage-tank",
    name = name,
    icons = icons,
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

-- A linked belt with an underground belt's speed and looks.
local function linked_belt(underground, name, item, icons)
  local belt = table.deepcopy(underground)
  belt.type = "linked-belt"
  belt.name = name
  belt.icon = nil
  belt.icons = icons
  belt.hidden = nil
  belt.minable = {mining_time = underground.minable and underground.minable.mining_time or 0.1, result = item}
  belt.placeable_by = {item = item, count = 1}
  belt.next_upgrade = nil
  belt.fast_replaceable_group = nil
  belt.max_distance = nil
  belt.underground_sprite = nil
  belt.underground_remove_belts_sprite = nil
  belt.max_distance_underground_remove_belts_sprite = nil
  belt.max_distance_tint = nil
  belt.underground_collision_mask = nil
  belt.allow_side_loading = false
  return belt
end

local function link_item(kind, icons, subgroup, order)
  return {
    type = "item",
    name = kind.item,
    icons = icons,
    subgroup = subgroup,
    order = order,
    place_result = kind.top,
    stack_size = 50
  }
end

local prototypes = {}
local function add(prototype)
  prototypes[#prototypes + 1] = prototype
end

-- Underground belts and pipes-to-ground: the base game's are hidden, and
-- data-final-fixes.lua swaps them out of every recipe.
for key, kind in pairs(transfer.kinds) do
  local base_name = kind.belt or (kind.flow and "pipe-to-ground")
  local base_item = base_name and data.raw.item[base_name]
  if base_item then
    local icons = arrow_icons(base_item.icon, kind.up)
    local order = base_item.order .. (kind.up and "-b" or "-a")
    add(link_item(kind, icons, base_item.subgroup, order))
    if kind.belt then
      local underground = data.raw["underground-belt"][kind.belt]
      add(linked_belt(underground, kind.top, kind.item, icons))
      add(linked_belt(underground, kind.bottom, kind.item, icons))
    else
      local art = kind.up and "lift-pump" or "downpipe"
      add(storage_tank(kind.top, kind.item, art .. "-top", icons))
      add(storage_tank(kind.bottom, kind.item, art .. "-bottom", icons))
    end
  end
end
for base_name in pairs(transfer.replaced) do
  local item = data.raw.item[base_name]
  if item then
    item.hidden = true
    local entity = data.raw["underground-belt"][base_name] or data.raw["pipe-to-ground"][base_name]
    if entity then
      entity.hidden = true
      -- An upgrade target needs an item that isn't hidden.
      entity.next_upgrade = nil
    end
  end
end

local power = transfer.kinds.power

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

add(power_pole(power.top))
add(power_pole(power.bottom))
add(energy_interface(power.sink, "secondary-input"))
add(energy_interface(power.source, "secondary-output"))
add({
  type = "item",
  name = power.item,
  icon = graphics .. "icons/power-connector.png",
  icon_size = 64,
  subgroup = "ttc-boring",
  order = "e[transfer]-c[power-connector]",
  place_result = power.top,
  stack_size = 20
})
add({
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
})

data:extend(prototypes)
