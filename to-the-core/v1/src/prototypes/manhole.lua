-- The manhole: a 2x2 hole to jump into, landing on the floor below
-- (runtime/manhole.lua). Buildings can't go on it, but characters walk onto
-- it: its collision mask leaves out the layers characters collide with. Art
-- from v1/tools/manhole_gfx.py.
local graphics = "__to-the-core__/graphics/"
local name = "ttc-manhole"

data:extend({
  {
    type = "simple-entity-with-owner",
    name = name,
    icon = graphics .. "icons/manhole.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = name},
    max_health = 200,
    collision_box = {{-0.9, -0.9}, {0.9, 0.9}},
    collision_mask = {layers = {item = true, meltable = true, object = true, water_tile = true, is_lower_object = true}},
    selection_box = {{-1, -1}, {1, 1}},
    render_layer = "floor",
    picture = {
      filename = graphics .. "entities/manhole.png",
      width = 160,
      height = 160,
      scale = 0.5
    }
  },
  {
    type = "item",
    name = name,
    icon = graphics .. "icons/manhole.png",
    icon_size = 64,
    subgroup = "ttc-boring",
    order = "e[transfer]-d[manhole]",
    place_result = name,
    stack_size = 10
  },
  {
    type = "recipe",
    name = name,
    categories = {"crafting"},
    enabled = false,
    energy_required = 5,
    ingredients = {
      {type = "item", name = "stone-brick", amount = 20},
      {type = "item", name = "iron-plate", amount = 10}
    },
    results = {{type = "item", name = name, amount = 1}}
  }
})
