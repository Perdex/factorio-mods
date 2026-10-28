local layers = require("shared.layers")
local shaft = require("shared.shaft")

local graphics = "__to-the-core__/graphics/"
local icon = graphics .. "icons/core-drill.png"

-- Shaft pictures are 7x7.
-- Both are rendered by v1/tools/core_drill_gfx.py.
local burner_drill = data.raw["mining-drill"]["burner-mining-drill"]

-- Frames are 6x8 tiles with the 5x5 footprint low in them, so the rig and
-- its auger can rise above the ground; the shadow slants east.
local drill_animation = {
  layers = {
    {
      filename = graphics .. "entities/core-drill.png",
      width = 384,
      height = 512,
      frame_count = 8,
      line_length = 8,
      animation_speed = 0.3,
      scale = 0.5,
      shift = {0, -1}
    },
    {
      filename = graphics .. "entities/core-drill-shadow.png",
      width = 576,
      height = 512,
      frame_count = 1,
      repeat_count = 8,
      scale = 0.5,
      shift = {1.5, -1},
      draw_as_shadow = true
    }
  }
}

local function shaft_picture(name)
  return {
    filename = graphics .. "entities/" .. name .. ".png",
    width = 448,
    height = 448,
    scale = 0.5
  }
end

local half = shaft.size / 2

data:extend({
  {
    type = "recipe-category",
    name = shaft.recipe_category
  },
  {
    -- A furnace, like the tunnel bore: inserting any drill head picks its
    -- shaft dig recipe.
    type = "furnace",
    name = shaft.drill_name,
    icon = icon,
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = shaft.drill_name},
    max_health = 1000,
    corpse = "big-remnants",
    dying_explosion = "big-explosion",
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
    -- The rig rises about 1.5 tiles above its footprint.
    drawing_box_vertical_extension = 1.5,
    crafting_categories = {shaft.recipe_category},
    source_inventory_size = 1,
    -- Set to the number of possible shaft drops below.
    result_inventory_size = 1,
    cant_insert_at_source_message_key = "ttc.core-drill-needs-drill-head",
    -- Wears heads four times faster than a tunnel bore: a shaft is hundreds
    -- or thousands of hits deep.
    crafting_speed = 4,
    energy_usage = "300kW",
    energy_source = {
      type = "burner",
      fuel_categories = {"chemical"},
      effectivity = 1,
      fuel_inventory_size = 2,
      emissions_per_minute = {pollution = 10}
    },
    graphics_set = {
      animation = drill_animation
    },
    return_ingredients_on_change = true,
    module_slots = 0,
    allowed_effects = {},
    working_sound = burner_drill and burner_drill.working_sound,
    impact_category = "metal"
  },
  {
    type = "item",
    name = shaft.drill_name,
    icon = icon,
    icon_size = 64,
    subgroup = "ttc-boring",
    order = "a[core-drill]",
    place_result = shaft.drill_name,
    stack_size = 1
  },
  {
    type = "recipe",
    name = shaft.drill_name,
    categories = {"crafting"},
    enabled = true,
    energy_required = 5,
    ingredients = {
      {type = "item", name = "iron-plate", amount = 20},
      {type = "item", name = "iron-gear-wheel", amount = 10},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "electronic-circuit", amount = 20}
    },
    results = {
      {type = "item", name = shaft.drill_name, amount = 1}
    }
  }
})

for _, axis in ipairs(shaft.axes) do
  data:extend({
    {
      type = "simple-entity",
      name = shaft.top_name(axis),
      localised_name = {"entity-name.ttc-shaft-top"},
      icon = icon,
      icon_size = 64,
      flags = {"placeable-neutral", "not-blueprintable", "not-deconstructable", "not-flammable"},
      hidden = true,
      -- Only the pit blocks; the stairs along its rims are walkable.
      collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
      collision_mask = {layers = {object = true, player = true, item = true}},
      selection_box = {{-half, -half}, {half, half}},
      selection_priority = 1,
      render_layer = "floor-mechanics-under-corpse",
      picture = shaft_picture("shaft-top-" .. axis),
      map_color = {r = 0.08, g = 0.07, b = 0.06}
    },
    {
      type = "simple-entity",
      name = shaft.bottom_name(axis),
      localised_name = {"entity-name.ttc-shaft-bottom"},
      icon = icon,
      icon_size = 64,
      flags = {"placeable-neutral", "not-blueprintable", "not-deconstructable", "not-flammable"},
      hidden = true,
      collision_box = {{-half + 0.1, -half + 0.1}, {half - 0.1, half - 0.1}},
      collision_mask = {layers = {}},
      selectable_in_game = false,
      render_layer = "floor",
      picture = shaft_picture("shaft-bottom-" .. axis),
      map_color = {r = 0.45, g = 0.4, b = 0.33}
    }
  })
end

-- Stair blockers: they collide with buildings, belts, rails, vehicles and
-- items on the ground, but not with players (who collide on `player`,
-- `is_object` and `train` only).
for _, axis in ipairs(shaft.axes) do
  local long, short = 2.45, 0.45
  data:extend({
    {
      type = "simple-entity",
      name = shaft.stair_blocker_name(axis),
      localised_name = {"entity-name.ttc-shaft-stairs"},
      icon = icon,
      icon_size = 64,
      hidden = true,
      flags = {"placeable-neutral", "not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable"},
      selectable_in_game = false,
      collision_box = axis == "ns" and {{-long, -short}, {long, short}} or {{-short, -long}, {short, long}},
      collision_mask = {layers = {object = true, floor = true, transport_belt = true, item = true, car = true}},
      picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1}
    }
  })
end

-- Shaft dig recipes, one per drill head, as for the tunnel bore: one craft is
-- one head's life, and the shaft's drops come out per hit (runtime/wear.lua).
-- Every possible shaft drop is listed as a product the game never makes itself
-- (amount 0) only so that the furnace's output slots accept it.
local drop_names, seen = {}, {}
for _, layer in ipairs(layers) do
  for _, drop in ipairs(layer.shaft.drops) do
    if not seen[drop.name] then
      seen[drop.name] = true
      drop_names[#drop_names + 1] = drop.name
    end
  end
end
local output_slots = {}
for _, name in ipairs(drop_names) do
  output_slots[#output_slots + 1] = {type = "item", name = name, amount = 0}
end
data.raw.furnace[shaft.drill_name].result_inventory_size = #drop_names

for head_name, head in pairs(require("shared.bore").heads) do
  local item = data.raw.item[head.item]
  data:extend({
    {
      type = "recipe",
      name = shaft.recipe_name(head_name),
      localised_name = {"ttc.shaft-recipe-name", {"item-name." .. head.item}},
      icons = item.icons or {{icon = item.icon, icon_size = item.icon_size or 64}},
      subgroup = "ttc-boring",
      order = "d[shaft]-" .. head.durability,
      categories = {shaft.recipe_category},
      enabled = true,
      hide_from_player_crafting = true,
      allow_decomposition = false,
      allow_productivity = false,
      energy_required = head.durability * head.hit_time,
      ingredients = {{type = "item", name = head.item, amount = 1}},
      results = output_slots
    }
  })
end
