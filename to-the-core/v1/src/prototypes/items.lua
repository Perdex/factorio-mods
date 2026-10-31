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

-- Stone has to be dealt with, not stockpiled: it stacks only to 20.
data.raw.item["stone"].stack_size = 20

-- The deep shafts' rock: too tough to sort by hand, and it doesn't stack.
-- Ground to gravel for now (prototypes/grinding.lua).
local stone = data.raw.item["stone"]
data:extend({
  {
    type = "item",
    name = "ttc-hardened-stone",
    icons = {{icon = stone.icon, icon_size = stone.icon_size or 64, tint = {r = 0.55, g = 0.56, b = 0.64}}},
    subgroup = "raw-resource",
    order = "z[ttc]-hardened-stone",
    stack_size = 1
  }
})
-- Metal-rich rock from the walls (iron from floor 2, copper from floor 3),
-- sorted by hand or ground (prototypes/grinding.lua); the granules smelt 4:1
-- to plates. Icons from v1/tools/ore_gfx.py.
for index, metal in ipairs({"iron", "copper"}) do
  local rock = "ttc-" .. metal .. "-rich-rock"
  make_item(rock, metal .. "-rich-rock", "z[ttc]-rich-rock-" .. index, 50, "raw-resource")
  make_item("ttc-" .. metal .. "-granules", metal .. "-granules", "z[ttc]-granules-" .. index, 100, "raw-resource")
  data:extend({
    {
      type = "recipe",
      name = "ttc-sort-" .. metal .. "-rich-rock",
      -- Only by hand: nothing but the player crafts in this category.
      categories = {"hand-crafting"},
      enabled = false,
      energy_required = 2,
      ingredients = {{type = "item", name = rock, amount = 1}},
      -- One roll per rock: 20% ore (as much metal as grinding gets out), 2%
      -- coal, otherwise plain stone.
      results = {
        {type = "item", name = metal .. "-ore", amount = 1, shared_probability = {min = 0, max = 0.2}},
        {type = "item", name = "coal", amount = 1, shared_probability = {min = 0.2, max = 0.22}},
        {type = "item", name = "stone", amount = 1, shared_probability = {min = 0.22, max = 1}}
      },
      icon = icons .. metal .. "-rich-rock.png",
      icon_size = 64,
      subgroup = "raw-resource",
      order = "z[ttc]-rich-rock-" .. index .. "-a[sort]",
      allow_decomposition = false
    }
  })
  make_recipe("ttc-" .. metal .. "-plate-from-granules", false, 3.2,
    {{"ttc-" .. metal .. "-granules", 4}}, {{metal .. "-plate", 1}}, "smelting")
end

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
  {{"iron-gear-wheel", 1}, {"iron-plate", 2}}, {{"ttc-iron-drill-head", 1}})
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
data.raw.recipe["stone-brick"].ingredients = {{type = "item", name = "ttc-clay", amount = 4}}
for _, name in ipairs({"boiler", "steam-engine"}) do
  table.insert(data.raw.recipe[name].ingredients, {type = "item", name = "stone-brick", amount = 5})
end
