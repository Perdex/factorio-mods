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
make_item("ttc-hardened-drill-head", "hardened-drill-head", "ttc-drill-head-e", 50)
make_item("ttc-carbide-drill-head", "carbide-drill-head", "ttc-drill-head-f", 50)

-- Shaft spoils and what they turn into.
make_item("ttc-sand", "sand", "z[ttc]-sand", 100, "raw-resource")
make_item("ttc-clay", "clay", "z[ttc]-clay", 100, "raw-resource")
make_item("ttc-glass", "glass", "z[ttc]-glass", 100, "raw-material")
-- Ground-down rock (prototypes/grinding.lua).
make_item("ttc-gravel", "gravel", "z[ttc]-gravel", 100, "raw-resource")
make_item("ttc-dust", "dust", "z[ttc]-dust", 200, "raw-resource")

make_recipe("ttc-wooden-drill-head", true, 1,
  {{"wood", 2}, {"stone", 1}}, {{"ttc-wooden-drill-head", 1}})
-- Clay heads are shaped by hand, then fired in a furnace.
make_recipe("ttc-unfired-clay-drill-head", false, 1,
  {{"ttc-clay", 5}}, {{"ttc-unfired-clay-drill-head", 1}})
make_recipe("ttc-clay-drill-head", false, 3.2,
  {{"ttc-unfired-clay-drill-head", 1}}, {{"ttc-clay-drill-head", 1}}, "smelting")
make_recipe("ttc-glass", false, 3.2,
  {{"ttc-sand", 2}}, {{"ttc-glass", 1}}, "smelting")
make_recipe("ttc-iron-drill-head", false, 2,
  {{"iron-plate", 4}}, {{"ttc-iron-drill-head", 1}})
make_recipe("ttc-reinforced-drill-head", false, 3,
  {{"steel-plate", 3}, {"copper-plate", 2}}, {{"ttc-reinforced-drill-head", 1}})
make_recipe("ttc-hardened-drill-head", false, 5,
  {{"steel-plate", 5}, {"plastic-bar", 2}}, {{"ttc-hardened-drill-head", 1}})
make_recipe("ttc-carbide-drill-head", false, 8,
  {{"steel-plate", 5}, {"sulfur", 5}, {"advanced-circuit", 1}}, {{"ttc-carbide-drill-head", 1}})

-- Pipes have windows: everything that moves fluids needs glass. So do lamps.
-- No fuel underground to spare: the burner inserter becomes a mechanical
-- one, so floor 2 can be automated before there is electricity.
local inserter = data.raw["inserter"]["burner-inserter"]
inserter.energy_source = {type = "void"}
inserter.allow_burner_leech = nil

table.insert(data.raw.recipe["pipe"].ingredients, {type = "item", name = "ttc-glass", amount = 1})
table.insert(data.raw.recipe["small-lamp"].ingredients, {type = "item", name = "ttc-glass", amount = 1})

-- Bricks are fired clay, not stone: stone is the rubble digging leaves behind.
data.raw.recipe["stone-brick"].ingredients = {{type = "item", name = "ttc-clay", amount = 5}}
for _, name in ipairs({"boiler", "steam-engine"}) do
  table.insert(data.raw.recipe[name].ingredients, {type = "item", name = "stone-brick", amount = 5})
end
