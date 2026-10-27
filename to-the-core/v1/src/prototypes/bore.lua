local bore = require("shared.bore")
local layers = require("shared.layers")

local graphics = "__to-the-core__/graphics/"
local icon = graphics .. "icons/mk1-bore.png"

-- Frames are 4x4 tiles centred on the 2x2 body, so the cutter head overlaps
-- the wall the bore is digging into. Rendered by v1/tools/bore_gfx.py.
local function direction_animation(direction)
  local sheet = graphics .. "entities/mk1-bore-" .. direction
  return {
    layers = {
      {
        filename = sheet .. ".png",
        width = 256,
        height = 256,
        frame_count = 8,
        line_length = 8,
        animation_speed = 0.4,
        scale = 0.5
      },
      {
        filename = sheet .. "-shadow.png",
        width = 256,
        height = 256,
        frame_count = 1,
        repeat_count = 8,
        scale = 0.5,
        draw_as_shadow = true
      }
    }
  }
end

local burner_drill = data.raw["mining-drill"]["burner-mining-drill"]

data:extend({
  {
    type = "recipe-category",
    name = bore.recipe_category
  },
  {
    type = "assembling-machine",
    name = bore.entity_name,
    icon = icon,
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.5, result = bore.entity_name},
    max_health = 400,
    corpse = "medium-remnants",
    dying_explosion = "medium-explosion",
    collision_box = {{-0.9, -0.9}, {0.9, 0.9}},
    selection_box = {{-1, -1}, {1, 1}},
    -- Like an offshore pump: the body stands on open ground and the tiles in
    -- front (rotated with the bore) must be solid rock to dig into.
    tile_buildability_rules = {
      {
        area = {{-0.9, -0.9}, {0.9, 0.9}},
        required_tiles = {layers = {ground_tile = true}},
        colliding_tiles = {layers = {out_of_map = true}},
        remove_on_collision = true
      },
      {
        area = {{-0.9, -1.9}, {0.9, -1.1}},
        required_tiles = {layers = {out_of_map = true}},
        colliding_tiles = {layers = {}}
      }
    },
    crafting_categories = {bore.recipe_category},
    crafting_speed = 1,
    energy_usage = "150kW",
    energy_source = {
      type = "burner",
      fuel_categories = {"chemical"},
      effectivity = 1,
      fuel_inventory_size = 1,
      emissions_per_minute = {pollution = 6}
    },
    graphics_set = {
      animation = {
        north = direction_animation("north"),
        east = direction_animation("east"),
        south = direction_animation("south"),
        west = direction_animation("west")
      }
    },
    -- Lets the bore rotate: crafting machines without an active fluid box are
    -- fixed to north, so it must stay on even when the recipe uses no fluids.
    -- Later layers can feed coolant through it.
    fluid_boxes = {
      {
        production_type = "input",
        volume = 100,
        pipe_connections = {
          {flow_direction = "input", direction = defines.direction.west, position = {-0.5, 0.5}}
        }
      }
    },
    return_ingredients_on_change = true,
    module_slots = 0,
    allowed_effects = {},
    working_sound = burner_drill and burner_drill.working_sound,
    impact_category = "metal"
  },
  {
    type = "item",
    name = bore.entity_name,
    icon = icon,
    icon_size = 64,
    subgroup = "ttc-boring",
    order = "b[bore]-a[mk1]",
    place_result = bore.entity_name,
    stack_size = 10
  },
  {
    type = "recipe",
    name = bore.entity_name,
    categories = {"crafting"},
    enabled = false,
    energy_required = 8,
    -- No iron: the first bores are built from what the surface and the clay
    -- layer give, so they can dig out the first iron.
    ingredients = {
      {type = "item", name = "wood", amount = 20},
      {type = "item", name = "stone", amount = 20},
      {type = "item", name = "ttc-clay", amount = 30},
      {type = "item", name = "ttc-blade", amount = 8}
    },
    results = {
      {type = "item", name = bore.entity_name, amount = 1}
    }
  }
})

local function item_icons(name)
  local item = data.raw.item[name]
  return item.icons or {{icon = item.icon, icon_size = item.icon_size or 64}}
end

-- One head's life of drops: a range around the expected amount, or a chance
-- of one item when less than one is expected.
local function life_drops(layer, head)
  local results = {}
  for _, drop in ipairs(layer.drops) do
    local expected = head.durability * drop.chance * (drop.minimum + drop.maximum) / 2
    if expected >= 1 then
      results[#results + 1] = {
        type = "item",
        name = drop.name,
        amount_min = math.max(1, math.floor(expected * 0.75)),
        amount_max = math.ceil(expected * 1.25)
      }
    else
      results[#results + 1] = {
        type = "item",
        name = drop.name,
        amount = 1,
        independent_probability = expected
      }
    end
  end
  return results
end

for _, head in pairs(bore.heads) do
  data.raw.item[head.item].localised_description =
    {"ttc.drill-head-description", tostring(head.durability), tostring(head.hit_time)}
end

for layer_index, layer in ipairs(layers) do
  for recipe_index, dig_recipe in ipairs(layer.dig_recipes) do
    local head = bore.heads[dig_recipe.head]
    data:extend({
      {
        type = "recipe",
        name = bore.recipe_name(layer, dig_recipe),
        localised_name = {"ttc.dig-recipe-name", {"ttc-layer-name." .. layer.name}, {"item-name." .. head.item}},
        localised_description = {
          "ttc.dig-recipe-description",
          tostring(head.durability),
          tostring(layer.hits_per_tile),
          string.format("%.2g", head.durability / layer.hits_per_tile)
        },
        icons = item_icons(head.item),
        subgroup = "ttc-boring",
        order = string.format("c[dig]-%02d-%02d", layer_index, recipe_index),
        categories = {bore.recipe_category},
        enabled = dig_recipe.unlocked_by == nil,
        hide_from_player_crafting = true,
        allow_decomposition = false,
        allow_productivity = false,
        energy_required = head.durability * head.hit_time,
        ingredients = {{type = "item", name = head.item, amount = 1}},
        results = life_drops(layer, head)
      }
    })
  end
end
