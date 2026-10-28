-- Researches base technologies tied to floor arrivals (shared/progression.lua):
-- once a force's shaft has reached the floor and the technology's
-- prerequisites are done. Crafting and building triggers are the game's own.
local progression_config = require("shared.progression")

local floor_technologies = {}
for name, trigger in pairs(progression_config.triggers) do
  if trigger.floor then
    floor_technologies[#floor_technologies + 1] = {name = name, floor = trigger.floor}
  end
end
table.sort(floor_technologies, function(a, b) return a.name < b.name end)

local progression = {}

local function floors_reached(force)
  storage.ttc.floors_reached = storage.ttc.floors_reached or {}
  storage.ttc.floors_reached[force.index] = storage.ttc.floors_reached[force.index] or {}
  return storage.ttc.floors_reached[force.index]
end

local function prerequisites_done(technology)
  for _, prerequisite in pairs(technology.prerequisites) do
    if not prerequisite.researched then
      return false
    end
  end
  return true
end

-- Researches every reachable floor technology, repeating while one unlocks
-- another.
function progression.refresh(force)
  local reached = floors_reached(force)
  local changed = true
  while changed do
    changed = false
    for _, entry in ipairs(floor_technologies) do
      local technology = force.technologies[entry.name]
      if technology and not technology.researched and reached[entry.floor]
        and prerequisites_done(technology) then
        technology.researched = true
        changed = true
      end
    end
  end
end

function progression.reach_floor(force, floor)
  floors_reached(force)[floor] = true
  progression.refresh(force)
end

-- A finished research (e.g. a crafting trigger) may complete the
-- prerequisites of a floor technology. Our own researches are handled by
-- refresh's loop.
function progression.on_research_finished(event)
  if not event.by_script then
    progression.refresh(event.research.force)
  end
end

return progression
