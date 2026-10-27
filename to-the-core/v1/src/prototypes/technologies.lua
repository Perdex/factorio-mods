-- Progression technologies. None are researched with science: the runtime
-- researches them when a shaft first reaches a floor (`reached_unlocks` in
-- shared/layers.lua) or a bore first digs up a resource (`unlocks`).
local bore = require("shared.bore")

local icons = "__to-the-core__/graphics/icons/"
local technologies = {
  {
    name = "ttc-reach-floor-1",
    icon = icons .. "mk1-bore.png",
    recipes = {"ttc-mk1-bore", "ttc-item-chute", "ttc-unfired-clay-drill-head", "ttc-clay-drill-head", "ttc-glass"}
  },
  {
    name = "ttc-reach-floor-2",
    icon = icons .. "downpipe.png",
    recipes = {"ttc-downpipe"}
  },
  {
    name = "ttc-iron-discovery",
    icon = "__base__/graphics/icons/iron-ore.png",
    recipes = {"ttc-iron-drill-head", "ttc-blade"}
  },
  {
    name = "ttc-reach-floor-3",
    icon = icons .. "core-drill.png",
    recipes = {}
  },
  {
    name = "ttc-copper-discovery",
    icon = "__base__/graphics/icons/copper-ore.png",
    recipes = {"ttc-reinforced-drill-head"}
  }
}

for index, technology in ipairs(technologies) do
  local effects = {}
  for _, recipe in ipairs(technology.recipes) do
    effects[#effects + 1] = {type = "unlock-recipe", recipe = recipe}
  end
  data:extend({
    {
      type = "technology",
      name = technology.name,
      icon = technology.icon,
      icon_size = 64,
      effects = effects,
      unit = {
        count = 1,
        ingredients = {{"automation-science-pack", 1}},
        time = 1
      },
      enabled = false,
      order = string.format("a-%02d", index)
    }
  })
end

-- Dig recipes that come with a technology.
for _, layer in ipairs(require("shared.layers")) do
  for _, dig_recipe in ipairs(layer.dig_recipes) do
    if dig_recipe.unlocked_by then
      local technology = data.raw.technology[dig_recipe.unlocked_by]
      table.insert(technology.effects, {
        type = "unlock-recipe",
        recipe = bore.recipe_name(layer, dig_recipe)
      })
    end
  end
end
