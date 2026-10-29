-- Swaps the base game's underground belts and pipes-to-ground out of every
-- recipe for their down and up ends (shared/transfer.lua). A recipe that made
-- a pair now makes one down end, from half the ingredients (down ends of the
-- tier below among them), and a new recipe makes the up end the same way.
-- Runs in data-final-fixes so every recipe and technology is known.
local transfer = require("shared.transfer")

-- The first tiers' up ends wait for floor 3; faster tiers' come with their
-- down ends, which unlock later anyway.
local up_unlock = {["underground-belt"] = "ttc-reach-floor-3", ["pipe-to-ground"] = "ttc-reach-floor-3"}

local function half(amount)
  return math.max(1, math.ceil(amount / 2))
end

-- end_index: 1 for down ends, 2 for up ends.
local function halved(list, end_index)
  local result = {}
  for _, entry in ipairs(list or {}) do
    local copy = table.deepcopy(entry)
    if copy.amount then
      copy.amount = half(copy.amount)
    end
    local ends = transfer.replaced[copy.name]
    if ends and data.raw.item[ends[1]] then
      copy.name = ends[end_index]
    end
    result[#result + 1] = copy
  end
  return result
end

-- A replaced item a recipe makes, if any.
local function made(recipe)
  for _, result in ipairs(recipe.results or {}) do
    local ends = transfer.replaced[result.name]
    if ends and data.raw.item[ends[1]] then
      return result.name
    end
  end
end

-- Ingredients elsewhere: a pair becomes one down and one up end.
local function swap_ingredients(recipe)
  local swapped, changed = {}, false
  for _, entry in ipairs(recipe.ingredients or {}) do
    local ends = transfer.replaced[entry.name]
    if ends and data.raw.item[ends[1]] and entry.amount then
      for _, name in ipairs(ends) do
        swapped[#swapped + 1] = {type = "item", name = name, amount = half(entry.amount)}
      end
      changed = true
    else
      swapped[#swapped + 1] = entry
    end
  end
  if changed then
    recipe.ingredients = swapped
  end
end

local up_recipes = {}
for name, recipe in pairs(data.raw.recipe) do
  local base_name = made(recipe)
  if base_name then
    local ends = transfer.replaced[base_name]
    local up = table.deepcopy(recipe)
    up.name = ends[2]
    up.ingredients = halved(recipe.ingredients, 2)
    up.results = halved(recipe.results, 2)
    up.main_product = nil
    recipe.ingredients = halved(recipe.ingredients, 1)
    recipe.results = halved(recipe.results, 1)
    recipe.main_product = nil
    up_recipes[name] = {recipe = up, unlock = up_unlock[base_name]}
  else
    swap_ingredients(recipe)
  end
end

for name, up in pairs(up_recipes) do
  data:extend({up.recipe})
  if up.unlock then
    up.recipe.enabled = false
    table.insert(data.raw.technology[up.unlock].effects, {type = "unlock-recipe", recipe = up.recipe.name})
  else
    for _, technology in pairs(data.raw.technology) do
      for _, effect in ipairs(technology.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe == name then
          table.insert(technology.effects, {type = "unlock-recipe", recipe = up.recipe.name})
          break
        end
      end
    end
  end
end
