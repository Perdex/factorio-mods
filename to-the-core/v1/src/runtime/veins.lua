-- Ore veins hidden in the rock of each floor (`veins` in shared/layers.lua).
-- Where they are follows from the map seed alone, so nothing is stored: the
-- floor is split into square cells, each of which may hold one roughly round
-- vein with a ragged edge.
local layer_configs = require("shared.layers")

local index_by_surface_name = {}
for index, layer in ipairs(layer_configs) do
  index_by_surface_name[layer.surface_name] = index
end

local veins = {}

local modulus = 2147483647

-- A deterministic number in [0, 1) for three integers.
local function hash(a, b, c)
  local h = (a * 73856093 + b * 19349663 + c * 83492791) % modulus
  h = (h * 48271) % modulus
  h = (h * 48271) % modulus
  return h / modulus
end
veins.hash = hash

-- Derived from the map seed, so every Lua state (and every player) computes
-- the same value; cached because reading map settings copies them.
local cached_seed

local function seed()
  cached_seed = cached_seed or game.surfaces.nauvis.map_gen_settings.seed % 1000003
  return cached_seed
end

local function enabled()
  local setting = settings.global["ttc-veins"]
  return not setting or setting.value
end

-- The vein (its config) the rock at `position` belongs to, if any, and a key
-- naming that one vein.
function veins.at(surface, position)
  local index = index_by_surface_name[surface.name]
  local list = index and layer_configs[index].veins
  if not list or not enabled() then
    return nil
  end
  local x, y = math.floor(position.x), math.floor(position.y)
  for vein_index, vein in ipairs(list) do
    local salt = seed() + index * 1009 + vein_index * 7919
    local cell = vein.cell
    local home_x, home_y = math.floor(x / cell), math.floor(y / cell)
    -- Radii stay below a cell, so only the neighbouring cells can reach here.
    for cx = home_x - 1, home_x + 1 do
      for cy = home_y - 1, home_y + 1 do
        if hash(cx, cy, salt) < vein.chance then
          local center_x = (cx + hash(cx, cy, salt + 1)) * cell
          local center_y = (cy + hash(cx, cy, salt + 2)) * cell
          local radius = vein.radius[1] + (vein.radius[2] - vein.radius[1]) * hash(cx, cy, salt + 3)
          local edge = radius * (0.8 + 0.4 * hash(x, y, salt + 4))
          local dx, dy = x + 0.5 - center_x, y + 0.5 - center_y
          if dx * dx + dy * dy <= edge * edge then
            return vein, index .. ":" .. vein_index .. ":" .. cx .. ":" .. cy
          end
        end
      end
    end
  end
end

return veins
