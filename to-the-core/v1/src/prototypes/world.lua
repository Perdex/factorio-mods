-- The starting surface has no ore: resources are only found by digging.
-- Removes every resource's autoplace from Nauvis (trees and rocks stay, for
-- wood and stone).
local map_gen = data.raw.planet.nauvis.map_gen_settings
local entity_settings = map_gen.autoplace_settings.entity.settings

for name, resource in pairs(data.raw.resource) do
  entity_settings[name] = nil
  local control = resource.autoplace and resource.autoplace.control
  if control then
    map_gen.autoplace_controls[control] = nil
  end
end
