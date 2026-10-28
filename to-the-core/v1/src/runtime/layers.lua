-- Underground layer surfaces: lookup by surface and on-demand creation.
-- Every surface that is not a layer counts as the starting surface, above layer 1.
local layer_configs = require("shared.layers")
local tunnel = require("runtime.tunnel")

local layers = {}

local index_by_surface_name = {}
for index, layer in ipairs(layer_configs) do
  index_by_surface_name[layer.surface_name] = index
end

-- Returns the layer config and its index, or nil for a non-layer surface.
function layers.of_surface(surface)
  local index = index_by_surface_name[surface.name]
  return index and layer_configs[index], index
end

-- The layer a shaft dug from this surface leads to and its index, if any.
function layers.below(surface)
  local _, index = layers.of_surface(surface)
  local below_index = (index or 0) + 1
  return layer_configs[below_index], below_index
end

-- The surface a floor's shafts come from: the floor above, or the starting
-- surface for floor 1. Nil for a non-floor surface.
function layers.above(surface)
  local _, index = layers.of_surface(surface)
  if not index then
    return nil
  end
  if index == 1 then
    return game.surfaces.nauvis
  end
  return game.surfaces[layer_configs[index - 1].surface_name]
end

function layers.surface(layer)
  local surface = game.surfaces[layer.surface_name]
  if surface then
    return surface
  end

  -- A 1x1 map: nothing generates outside it, so the layer is void rock except
  -- where it is opened (see runtime/tunnel.lua).
  surface = game.create_surface(layer.surface_name, {
    autoplace_controls = {},
    default_enable_all_autoplace_controls = false,
    width = 1,
    height = 1,
    no_enemies_mode = true,
    autoplace_settings = {
      entity = {treat_missing_as_default = false, settings = {}},
      decorative = {treat_missing_as_default = false, settings = {}},
      tile = {treat_missing_as_default = false, settings = {}}
    }
  })
  surface.localised_name = {"ttc-layer-name." .. layer.name}
  surface.daytime = 0
  surface.freeze_daytime = true
  surface.peaceful_mode = true
  return surface
end

local function clear_worldgen(surface, area)
  for _, entity in pairs(surface.find_entities_filtered({
    area = area,
    type = {"resource", "tree", "simple-entity", "cliff", "fish", "unit", "unit-spawner", "turret"}
  })) do
    entity.destroy()
  end
end

-- The chunks inside a layer's 1x1 map do generate; keep them solid rock.
function layers.on_chunk_generated(event)
  if not layers.of_surface(event.surface) then
    return
  end

  local area = event.area
  local tiles = {}
  for x = area.left_top.x, area.right_bottom.x - 1 do
    for y = area.left_top.y, area.right_bottom.y - 1 do
      tiles[#tiles + 1] = {name = tunnel.void_tile, position = {x, y}}
    end
  end
  clear_worldgen(event.surface, area)
  event.surface.set_tiles(tiles, false, false, false, false)
end

return layers
