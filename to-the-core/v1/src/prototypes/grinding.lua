-- Getting rid of rock: grinders crush stone to gravel, gravel to sand and sand
-- to dust, each step turning 3 items into 2 and taking three times as long,
-- so the later steps need many more grinders. Winnowers, which only work under open sky,
-- let the wind carry the dust away. Sprites from v1/tools/grinding_gfx.py.
local graphics = "__to-the-core__/graphics/"
local burner_drill = data.raw["mining-drill"]["burner-mining-drill"]

local function animation(name, width, height, shift)
  return {
    filename = graphics .. "entities/" .. name .. ".png",
    width = width,
    height = height,
    frame_count = 8,
    line_length = 8,
    animation_speed = 0.25,
    scale = 0.5,
    shift = shift
  }
end

local function machine(name, size, extra)
  local half = size / 2
  local entity = {
    type = "furnace",
    name = name,
    icon = graphics .. "icons/" .. name:gsub("^ttc%-", "") .. ".png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.5, result = name},
    max_health = 250,
    corpse = "medium-remnants",
    collision_box = {{-half + 0.1, -half + 0.1}, {half - 0.1, half - 0.1}},
    selection_box = {{-half, -half}, {half, half}},
    source_inventory_size = 1,
    result_inventory_size = 1,
    crafting_speed = 1,
    module_slots = 0,
    allowed_effects = {},
    impact_category = "stone"
  }
  for key, value in pairs(extra) do
    entity[key] = value
  end
  return entity
end

local function item(name, order)
  return {
    type = "item",
    name = name,
    icon = graphics .. "icons/" .. name:gsub("^ttc%-", "") .. ".png",
    icon_size = 64,
    subgroup = "ttc-boring",
    order = order,
    place_result = name,
    stack_size = 20
  }
end

local function recipe(name, category, time, ingredient, result)
  return {
    type = "recipe",
    name = name,
    categories = {category},
    enabled = true,
    hide_from_player_crafting = true,
    allow_decomposition = false,
    energy_required = time,
    ingredients = {{type = "item", name = ingredient, amount = 3}},
    results = result and {{type = "item", name = result, amount = 2}} or {},
    -- With nothing coming out, the recipe needs its own icon.
    icon = not result and graphics .. "icons/dust.png" or nil,
    icon_size = not result and 64 or nil
  }
end

local function building_recipe(name, ingredients)
  local result = {
    type = "recipe",
    name = name,
    categories = {"crafting"},
    enabled = false,
    energy_required = 5,
    ingredients = {},
    results = {{type = "item", name = name, amount = 1}}
  }
  for _, ingredient in ipairs(ingredients) do
    result.ingredients[#result.ingredients + 1] = {type = "item", name = ingredient[1], amount = ingredient[2]}
  end
  return result
end

data:extend({
  {type = "recipe-category", name = "ttc-grinding"},
  {type = "recipe-category", name = "ttc-winnowing"},

  -- Each step 3:2 and three times slower than the one before.
  recipe("ttc-grind-stone", "ttc-grinding", 1, "stone", "ttc-gravel"),
  recipe("ttc-grind-gravel", "ttc-grinding", 3, "ttc-gravel", "ttc-sand"),
  recipe("ttc-grind-sand", "ttc-grinding", 9, "ttc-sand", "ttc-dust"),
  recipe("ttc-winnow-dust", "ttc-winnowing", 27, "ttc-dust", nil),

  machine("ttc-grinder", 2, {
    crafting_categories = {"ttc-grinding"},
    energy_usage = "90kW",
    energy_source = {
      type = "burner",
      fuel_categories = {"chemical"},
      effectivity = 1,
      fuel_inventory_size = 1,
      emissions_per_minute = {pollution = 4}
    },
    graphics_set = {animation = animation("grinder", 192, 192, {0, -0.1})},
    working_sound = burner_drill and burner_drill.working_sound
  }),
  -- Runs on the wind: no fuel, but only under open sky (runtime/init.lua).
  machine("ttc-winnower", 3, {
    crafting_categories = {"ttc-winnowing"},
    energy_usage = "1kW",
    energy_source = {type = "void"},
    graphics_set = {animation = animation("winnower", 256, 320, {0, -1})},
    drawing_box_vertical_extension = 1,
    impact_category = "wood"
  }),
  item("ttc-grinder", "f[grinding]-a[grinder]"),
  item("ttc-winnower", "f[grinding]-b[winnower]"),
  building_recipe("ttc-grinder", {{"iron-plate", 10}, {"iron-gear-wheel", 10}, {"stone", 20}, {"stone-brick", 5}}),
  building_recipe("ttc-winnower", {{"wood", 30}, {"stone-brick", 10}, {"iron-gear-wheel", 10}, {"iron-plate", 5}})
})
