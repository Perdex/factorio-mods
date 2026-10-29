local bore = require("shared.bore")

local graphics = "__to-the-core__/graphics/"

-- Frames are 4x4 tiles centred on the 2x2 body, so the cutter head overlaps
-- the wall the bore is digging into. Rendered by v1/tools/bore_gfx.py.
local function direction_animation(sprite, direction, width)
  local sheet = graphics .. "entities/" .. sprite .. "-bore-" .. direction
  -- Frames are (width + 2) tiles across the bore and 4 along it.
  local across, along = (width + 2) * 64, 256
  local sideways = direction == "east" or direction == "west"
  local frame_width = sideways and along or across
  local frame_height = sideways and across or along
  return {
    layers = {
      {
        filename = sheet .. ".png",
        width = frame_width,
        height = frame_height,
        frame_count = 8,
        line_length = 8,
        animation_speed = 0.4,
        scale = 0.5
      },
      {
        filename = sheet .. "-shadow.png",
        width = frame_width,
        height = frame_height,
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
  }
})

-- A furnace, so it has no recipe to pick: inserting a drill head selects that
-- head's dig recipe, like ammo in a turret.
local function bore_entity(name, tier)
  local icon = graphics .. "icons/" .. tier.sprite .. "-bore.png"
  -- Across the digging direction (2 or 3 tiles); 2 tiles along it.
  local half = (tier.width or 2) / 2
  data:extend({
    {
      type = "furnace",
      name = name,
      icon = icon,
      icon_size = 64,
      flags = {"placeable-neutral", "placeable-player", "player-creation"},
      minable = {mining_time = 0.5, result = name},
      max_health = 400,
      corpse = "medium-remnants",
      dying_explosion = "medium-explosion",
      collision_box = {{-half + 0.1, -0.9}, {half - 0.1, 0.9}},
      selection_box = {{-half, -1}, {half, 1}},
      -- Stands anywhere on open ground; it crosses open ground one tile per
      -- hit until it meets rock.
      tile_buildability_rules = {
        {
          area = {{-half + 0.1, -0.9}, {half - 0.1, 0.9}},
          required_tiles = {layers = {ground_tile = true}},
          colliding_tiles = {layers = {out_of_map = true}},
          remove_on_collision = true
        }
      },
      crafting_categories = {bore.recipe_category},
      source_inventory_size = 1,
      -- The floor's wall drops (runtime/bore.lua puts them here); set to the
      -- number of possible drops below.
      result_inventory_size = 1,
      cant_insert_at_source_message_key = "ttc.bore-needs-drill-head",
      crafting_speed = tier.speed,
      energy_usage = tier.energy,
      energy_source = {
        type = "burner",
        fuel_categories = {"chemical"},
        effectivity = 1,
        fuel_inventory_size = 1,
        emissions_per_minute = {pollution = 6}
      },
      graphics_set = {
        animation = {
          north = direction_animation(tier.sprite, "north", tier.width or 2),
          east = direction_animation(tier.sprite, "east", tier.width or 2),
          south = direction_animation(tier.sprite, "south", tier.width or 2),
          west = direction_animation(tier.sprite, "west", tier.width or 2)
        }
      },
      -- Square crafting machines are only rotatable with a fluid box. Bores
      -- that need coolant take it in through the middle of their back, where
      -- they lay their pipe; the others get one nothing can connect to.
      fluid_boxes = {
        tier.coolant and {
          production_type = "input",
          volume = 200,
          filter = bore.coolant_fluid,
          pipe_connections = {
            {flow_direction = "input", direction = defines.direction.south, position = {0, 0.5}}
          }
        } or {production_type = "input", volume = 1, pipe_connections = {}}
      },
      -- Circuit connection on the rear-left corner, by the supply lane: the
      -- wire follows a belt-laying bore along its belts (runtime/bore.lua).
      circuit_wire_max_distance = default_circuit_wire_max_distance,
      circuit_connector = circuit_connector_definitions.create_vector(universal_connector_template, {
        {variation = 18, main_offset = util.by_pixel(-20, 20), shadow_offset = util.by_pixel(-16, 22), show_shadow = true},
        {variation = 18, main_offset = util.by_pixel(-20, -20), shadow_offset = util.by_pixel(-16, -18), show_shadow = true},
        {variation = 18, main_offset = util.by_pixel(20, -20), shadow_offset = util.by_pixel(24, -18), show_shadow = true},
        {variation = 18, main_offset = util.by_pixel(20, 20), shadow_offset = util.by_pixel(24, 22), show_shadow = true}
      }),
      module_slots = 0,
      allowed_effects = {},
      working_sound = burner_drill and burner_drill.working_sound,
      impact_category = tier.lays_belts and "metal" or "wood"
    },
    {
      type = "item",
      name = name,
      icon = icon,
      icon_size = 64,
      subgroup = "ttc-boring",
      order = "b[bore]-" .. tier.sprite,
      place_result = name,
      stack_size = 10
    }
  })
end

for name, tier in pairs(bore.tiers) do
  bore_entity(name, tier)
end

local function recipe(name, ingredients)
  local result = {
    type = "recipe",
    name = name,
    categories = {"crafting"},
    enabled = false,
    energy_required = 8,
    ingredients = {},
    results = {{type = "item", name = name, amount = 1}}
  }
  for _, ingredient in ipairs(ingredients) do
    result.ingredients[#result.ingredients + 1] = {type = "item", name = ingredient[1], amount = ingredient[2]}
  end
  data:extend({result})
end

-- Mk1: timber and fired clay, no iron, so it can dig out the first iron.
recipe("ttc-mk1-bore", {{"wood", 20}, {"stone-brick", 20}, {"ttc-glass", 10}})
-- Mk2 lays its own supply and output belt lanes and digs twice as fast.
recipe("ttc-mk2-bore", {{"iron-plate", 20}, {"iron-gear-wheel", 20}, {"stone-brick", 10}, {"ttc-glass", 10}})
-- Mk3 digs five times as fast as a Mk1, cooled with bore coolant.
recipe("ttc-mk3-bore", {{"ttc-mk2-bore", 1}, {"steel-plate", 50}, {"iron-gear-wheel", 40},
  {"electronic-circuit", 20}, {"pipe", 20}})

local function item_icons(name)
  local item = data.raw.item[name]
  return item.icons or {{icon = item.icon, icon_size = item.icon_size or 64}}
end

-- Every item any floor's walls or veins can drop. Each dig recipe lists them as
-- products the game never makes itself (amount 0) only so that the furnace's
-- output slots accept them; the runtime puts the real drops there.
local drop_items, drop_names = {}, {}
local function add_drops(drops)
  for _, drop in ipairs(drops) do
    if not drop_items[drop.name] then
      drop_items[drop.name] = true
      drop_names[#drop_names + 1] = drop.name
    end
  end
end
for _, layer in ipairs(require("shared.layers")) do
  add_drops(layer.drops)
  for _, vein in ipairs(layer.veins or {}) do
    add_drops(vein.drops)
  end
end
local output_slots = {}
for _, name in ipairs(drop_names) do
  output_slots[#output_slots + 1] = {type = "item", name = name, amount = 0}
end
for name in pairs(bore.tiers) do
  data.raw.furnace[name].result_inventory_size = #drop_names
end

for head_name, head in pairs(bore.heads) do
  local stats = {"ttc.drill-head-description", tostring(head.durability), string.format("%.2g", 1 / head.hit_time)}
  data.raw.item[head.item].localised_description = head.own_description
    and {"", stats, "\n", {"item-description." .. head.item}} or stats

  -- One craft is one head's life. The drops depend on the floor and are paid
  -- out by the runtime.
  data:extend({
    {
      type = "recipe",
      name = bore.recipe_name(head_name),
      localised_name = {"ttc.dig-recipe-name", {"item-name." .. head.item}},
      localised_description = {"ttc.dig-recipe-description", tostring(head.durability)},
      icons = item_icons(head.item),
      subgroup = "ttc-boring",
      order = "c[dig]-" .. head.durability,
      categories = {bore.recipe_category},
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

-- The hidden combinator that outputs a bore's own signals (shared/bore.lua).
local signals = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
signals.name = bore.signal_entity
signals.hidden = true
signals.flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "hide-alt-info"}
signals.selectable_in_game = false
signals.minable = nil
signals.fast_replaceable_group = nil
signals.next_upgrade = nil
signals.corpse = nil
signals.dying_explosion = nil
signals.collision_box = {{-0.1, -0.1}, {0.1, 0.1}}
signals.collision_mask = {layers = {}}
signals.selection_box = nil
signals.sprites = util.empty_sprite()
signals.activity_led_sprites = util.empty_sprite()
signals.draw_circuit_wires = false
data:extend({signals})

-- Bore coolant for the Mk3: water with a little petroleum gas or lubricant,
-- and dust, mixed in a chemical plant. The petroleum recipe comes with oil
-- processing, together with the Mk3; the cheaper lubricant one later
-- (prototypes/technologies.lua).
local water = data.raw.fluid["water"]
local coolant_icon = {icon = water.icon, icon_size = water.icon_size or 64, tint = {r = 0.55, g = 1, b = 0.85}}

local function coolant_recipe(name, additive, amount)
  local additive_fluid = data.raw.fluid[additive]
  return {
    type = "recipe",
    name = name,
    categories = {"chemistry"},
    enabled = false,
    energy_required = 2,
    ingredients = {
      {type = "fluid", name = "water", amount = 100},
      {type = "fluid", name = additive, amount = amount},
      {type = "item", name = "ttc-dust", amount = 2}
    },
    results = {{type = "fluid", name = bore.coolant_fluid, amount = 100}},
    icons = {
      coolant_icon,
      {icon = additive_fluid.icon, icon_size = additive_fluid.icon_size or 64, scale = 0.25, shift = {-8, -8}}
    },
    subgroup = "fluid-recipes",
    order = "z[ttc-coolant]-" .. name,
    crafting_machine_tint = {
      primary = {r = 0.2, g = 0.75, b = 0.65},
      secondary = {r = 0.6, g = 1, b = 0.9}
    }
  }
end

data:extend({
  {
    type = "fluid",
    name = bore.coolant_fluid,
    icons = {coolant_icon},
    base_color = {r = 0.2, g = 0.75, b = 0.65},
    flow_color = {r = 0.6, g = 1, b = 0.9},
    default_temperature = 15,
    subgroup = "fluid",
    order = "z[ttc-coolant]"
  },
  coolant_recipe("ttc-coolant-from-petroleum", "petroleum-gas", 20),
  coolant_recipe("ttc-coolant-from-lubricant", "lubricant", 4)
})
