-- Floor 2 has iron but no copper, so it runs without electricity: the first
-- assembling machine burns fuel, and steam power waits for copper
-- (shared/progression.lua). Its pipes and offshore pump don't need power, so
-- they come with floor 2 instead. Runs after prototypes/undergrounds.lua,
-- which turns the pipe-to-ground unlock into the pipe down's.

local assembler = data.raw["assembling-machine"]["assembling-machine-1"]
assembler.energy_source = {
  type = "burner",
  fuel_categories = {"chemical"},
  effectivity = 1,
  fuel_inventory_size = 1,
  emissions_per_minute = {pollution = 4}
}
-- No circuits (they need copper): fired clay bricks instead.
data.raw.recipe["assembling-machine-1"].ingredients = {
  {type = "item", name = "iron-gear-wheel", amount = 5},
  {type = "item", name = "iron-plate", amount = 9},
  {type = "item", name = "stone-brick", amount = 5}
}

-- Moves recipe unlocks from one technology to another.
local function move_unlocks(from, to, recipes)
  local moved = {}
  for _, recipe in ipairs(recipes) do
    moved[recipe] = true
  end
  local kept = {}
  for _, effect in ipairs(data.raw.technology[from].effects) do
    if effect.type == "unlock-recipe" and moved[effect.recipe] then
      table.insert(data.raw.technology[to].effects, effect)
    else
      kept[#kept + 1] = effect
    end
  end
  data.raw.technology[from].effects = kept
end

move_unlocks("steam-power", "ttc-reach-floor-2", {"pipe", "ttc-pipe-down", "offshore-pump"})
-- The long-handed inserter (made from an inserter) and the splitter take
-- circuits: they come with them, not with floor 2's automation and belts.
move_unlocks("automation", "electronics", {"long-handed-inserter"})
move_unlocks("logistics", "electronics", {"splitter"})
