local layers = require("shared.layers")
local shaft = require("shared.shaft")

local graphics = "__to-the-core__/graphics/"
local icon = graphics .. "icons/core-drill.png"

-- Drill frames are 6x6 tiles centred on the 5x5 body; shaft pictures are 7x7.
-- Both are rendered by v1/tools/core_drill_gfx.py.
local burner_drill = data.raw["mining-drill"]["burner-mining-drill"]

local drill_animation = {
  layers = {
    {
      filename = graphics .. "entities/core-drill.png",
      width = 384,
      height = 384,
      frame_count = 8,
      line_length = 8,
      animation_speed = 0.3,
      scale = 0.5
    },
    {
      filename = graphics .. "entities/core-drill-shadow.png",
      width = 384,
      height = 384,
      frame_count = 1,
      repeat_count = 8,
      scale = 0.5,
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
    type = "assembling-machine",
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
    crafting_categories = {shaft.recipe_category},
    crafting_speed = 1,
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
      {type = "item", name = "iron-gear-wheel", amount = 10}
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

for index, layer in ipairs(layers) do
  local ingredients, results = {}, {}
  for _, ingredient in ipairs(layer.shaft.ingredients) do
    ingredients[#ingredients + 1] = {type = "item", name = ingredient[1], amount = ingredient[2]}
  end
  for _, result in ipairs(layer.shaft.results) do
    results[#results + 1] = {
      type = "item",
      name = result[1],
      amount_min = result[2],
      amount_max = result[3] or result[2]
    }
  end
  data:extend({
    {
      type = "recipe",
      name = shaft.recipe_name(layer),
      localised_name = {"ttc.shaft-recipe-name", {"ttc-layer-name." .. layer.name}},
      icon = icon,
      icon_size = 64,
      subgroup = "ttc-boring",
      order = string.format("d[shaft]-%02d", index),
      categories = {shaft.recipe_category},
      enabled = true,
      hide_from_player_crafting = true,
      allow_decomposition = false,
      allow_productivity = false,
      energy_required = layer.shaft.time,
      ingredients = ingredients,
      results = results
    }
  })
end
