-- Tunnel bore constants shared by the data and control stages.
local layers = require("shared.layers")

local bore = {
  entity_name = "ttc-mk1-bore",
  recipe_category = "ttc-dig",
  -- Belts laid behind the bore per tile as its supply and output lanes. Taken
  -- from the supply lane into the bore's belt stock, not via the dig recipe.
  paving_item = "transport-belt",
  paving_count = 2,
  -- Most belts the stock holds; feed them on one lane of the supply belt.
  belt_stock_limit = 10,
  -- Drill heads wear out like repair packs: a head lasts `durability` hits,
  -- each taking `hit_time` seconds at crafting speed 1. A dig recipe craft is
  -- one head's whole life, so its progress bar shows the head wearing down.
  heads = {
    wooden = {item = "ttc-wooden-drill-head", durability = 10, hit_time = 3},
    clay = {item = "ttc-clay-drill-head", durability = 20, hit_time = 2},
    iron = {item = "ttc-iron-drill-head", durability = 40, hit_time = 1},
    reinforced = {item = "ttc-reinforced-drill-head", durability = 120, hit_time = 0.5}
  }
}

function bore.recipe_name(layer, dig_recipe)
  return "ttc-dig-" .. layer.name .. "-" .. dig_recipe.head
end

-- Maps every dig recipe name to its layer and to its drill head.
bore.recipe_layers = {}
bore.recipe_heads = {}
for _, layer in ipairs(layers) do
  for _, dig_recipe in ipairs(layer.dig_recipes) do
    local name = bore.recipe_name(layer, dig_recipe)
    bore.recipe_layers[name] = layer
    bore.recipe_heads[name] = bore.heads[dig_recipe.head]
  end
end

return bore
