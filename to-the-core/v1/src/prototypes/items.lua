local subgroup_name = "ttc-boring"
local icons = "__to-the-core__/graphics/icons/"

data:extend({
  {
    type = "item-subgroup",
    name = subgroup_name,
    group = "production",
    order = "z[ttc]"
  }
})

local function make_item(name, icon, order, stack_size, subgroup)
  data:extend({
    {
      type = "item",
      name = name,
      icon = icons .. icon .. ".png",
      icon_size = 64,
      subgroup = subgroup or subgroup_name,
      order = order,
      stack_size = stack_size
    }
  })
end

local function make_recipe(name, enabled, time, ingredients, results, category)
  local recipe = {
    type = "recipe",
    name = name,
    categories = {category or "crafting"},
    enabled = enabled,
    energy_required = time,
    ingredients = {},
    results = {}
  }
  for _, ingredient in ipairs(ingredients) do
    recipe.ingredients[#recipe.ingredients + 1] = {type = "item", name = ingredient[1], amount = ingredient[2]}
  end
  for _, result in ipairs(results) do
    recipe.results[#recipe.results + 1] = {type = "item", name = result[1], amount = result[2]}
  end
  data:extend({recipe})
end

-- Drill heads, in the order they become available (see FLOORS.md).
make_item("ttc-wooden-drill-head", "wooden-drill-head", "ttc-drill-head-a", 100)
make_item("ttc-unfired-clay-drill-head", "unfired-clay-drill-head", "ttc-drill-head-b1", 100)
make_item("ttc-clay-drill-head", "clay-drill-head", "ttc-drill-head-b2", 100)
make_item("ttc-iron-drill-head", "iron-drill-head", "ttc-drill-head-c", 100)
make_item("ttc-reinforced-drill-head", "reinforced-drill-head", "ttc-drill-head-d", 100)
-- Salvaged from the crash site at first; made from iron once there is iron.
make_item("ttc-blade", "blade", "ttc-blade", 100)

-- Shaft spoils and what they turn into.
make_item("ttc-sand", "sand", "z[ttc]-sand", 100, "raw-resource")
make_item("ttc-clay", "clay", "z[ttc]-clay", 100, "raw-resource")
make_item("ttc-glass", "glass", "z[ttc]-glass", 100, "raw-material")

make_recipe("ttc-wooden-drill-head", true, 1,
  {{"wood", 2}, {"stone", 1}, {"ttc-blade", 1}}, {{"ttc-wooden-drill-head", 1}})
-- Clay heads are shaped by hand, then fired in a furnace.
make_recipe("ttc-unfired-clay-drill-head", false, 1,
  {{"ttc-clay", 5}}, {{"ttc-unfired-clay-drill-head", 1}})
make_recipe("ttc-clay-drill-head", false, 3.2,
  {{"ttc-unfired-clay-drill-head", 1}}, {{"ttc-clay-drill-head", 1}}, "smelting")
make_recipe("ttc-glass", false, 3.2,
  {{"ttc-sand", 2}}, {{"ttc-glass", 1}}, "smelting")
make_recipe("ttc-blade", false, 1,
  {{"iron-plate", 1}}, {{"ttc-blade", 2}})
make_recipe("ttc-iron-drill-head", false, 2,
  {{"iron-plate", 2}}, {{"ttc-iron-drill-head", 4}})
make_recipe("ttc-reinforced-drill-head", false, 3,
  {{"iron-plate", 2}, {"copper-plate", 2}}, {{"ttc-reinforced-drill-head", 2}})

-- Pipes have windows: everything that moves fluids needs glass.
table.insert(data.raw.recipe["pipe"].ingredients, {type = "item", name = "ttc-glass", amount = 1})
