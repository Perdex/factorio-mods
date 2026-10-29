-- Replaces science-pack research with floor progression (shared/progression.lua).
-- Runs in data-final-fixes so the whole tree is known.
local progression = require("shared.progression")

local removed = {}
for _, name in ipairs(progression.removed) do
  removed[name] = true
  local technology = data.raw.technology[name]
  if technology then
    technology.hidden = true
    technology.enabled = false
  end
end

for _, name in ipairs(progression.removed_items) do
  for _, prototype in ipairs({data.raw.recipe[name], data.raw.item[name] or data.raw.tool[name]}) do
    if prototype then
      prototype.hidden = true
      if prototype.type == "recipe" then
        prototype.enabled = false
      end
    end
  end
end

for name, technology in pairs(data.raw.technology) do
  if technology.prerequisites then
    local kept = {}
    for _, prerequisite in ipairs(technology.prerequisites) do
      if not removed[prerequisite] then
        kept[#kept + 1] = prerequisite
      end
    end
    technology.prerequisites = kept
  end

  local trigger = progression.triggers[name]
  if trigger then
    technology.unit = nil
    if trigger.floor then
      technology.research_trigger = {
        type = "scripted",
        trigger_description = {"ttc-trigger.reach-floor", tostring(trigger.floor)},
        icon = "__to-the-core__/graphics/icons/core-drill.png",
        icon_size = 64
      }
    elseif trigger.craft then
      technology.research_trigger = {type = "craft-item", item = trigger.craft, count = trigger.count}
    elseif trigger.craft_fluid then
      technology.research_trigger = {type = "craft-fluid", fluid = trigger.craft_fluid, amount = trigger.amount}
    elseif trigger.build then
      technology.research_trigger = {type = "build-entity", entity = trigger.build}
    elseif trigger.discover then
      technology.research_trigger = {
        type = "scripted",
        trigger_description = {"ttc-trigger.discover", "[item=" .. trigger.discover .. "]"},
        icon = data.raw.item[trigger.discover].icon,
        icon_size = 64
      }
    end
  end
end
