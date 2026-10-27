-- Tunnel bore: a burner crafting machine whose dig recipe wears out drill heads
-- while burning fuel. One craft is one head's whole life: its hits land on the
-- wall ahead as the craft progresses, and after the layer's hits_per_tile hits
-- the bore breaks through and advances one tile (mid-craft if need be),
-- opening the tunnel in front, laying a supply lane and an output lane behind
-- (from belts it pulls off the supply lane, if it has any), and moving the
-- hidden loaders that connect those lanes to the bore.
local layers = require("shared.layers")
local bore_config = require("shared.bore")
local research = require("runtime.research")
local tunnel = require("runtime.tunnel")

local bore_name = bore_config.entity_name
local loader_name = "loader-1x1"

local layers_by_surface = {}
for _, layer in ipairs(layers) do
  layers_by_surface[layer.surface_name] = layer
end

local forward_vectors = {
  [defines.direction.north] = {x = 0, y = -1},
  [defines.direction.east] = {x = 1, y = 0},
  [defines.direction.south] = {x = 0, y = 1},
  [defines.direction.west] = {x = -1, y = 0}
}

local is_wall = {}
for _, name in ipairs(tunnel.wall_names) do
  is_wall[name] = true
end

local bore = {}

local function bores()
  storage.ttc.bores = storage.ttc.bores or {}
  return storage.ttc.bores
end

local function opposite(direction)
  return (direction + 8) % 16
end

-- Position relative to the bore's center: along its facing, and across to its right.
local function relative(entity, along, across)
  local forward = forward_vectors[entity.direction]
  return {
    x = entity.position.x + forward.x * along - forward.y * across,
    y = entity.position.y + forward.y * along + forward.x * across
  }
end

local function front_tiles(entity)
  return {relative(entity, 1.5, -0.5), relative(entity, 1.5, 0.5)}
end

-- Input loader on the rear left, output loader on the rear right.
local function rear_tiles(entity)
  return relative(entity, -1.5, -0.5), relative(entity, -1.5, 0.5)
end

-- Stops the bore with a red status, or (status_key nil) lets it run.
local function set_status(state, status_key, ...)
  local entity = state.entity
  entity.disabled_by_script = status_key ~= nil
  entity.custom_status = status_key and {
    diode = defines.entity_status_diode.red,
    label = {"ttc-status." .. status_key, ...}
  } or nil
end

local function destroy_loaders(state)
  for _, key in ipairs({"input_loader", "output_loader"}) do
    local loader = state[key]
    if loader and loader.valid then
      loader.destroy()
    end
    state[key] = nil
  end
end

local function create_loader(entity, position, loader_type)
  local surface = entity.surface
  local direction = loader_type == "input" and entity.direction or opposite(entity.direction)
  if not surface.can_place_entity({
    name = loader_name,
    position = position,
    direction = direction,
    force = entity.force
  }) then
    return nil
  end

  local loader = surface.create_entity({
    name = loader_name,
    position = position,
    direction = direction,
    force = entity.force,
    type = loader_type
  })
  if loader then
    loader.minable_flag = false
    loader.destructible = false
  end
  return loader
end

local function attach_loaders(state)
  local entity = state.entity
  local input_position, output_position = rear_tiles(entity)
  if not (state.input_loader and state.input_loader.valid) then
    state.input_loader = create_loader(entity, input_position, "input")
  end
  if not (state.output_loader and state.output_loader.valid) then
    state.output_loader = create_loader(entity, output_position, "output")
  end
end

-- Moves paving belts that reached the input loader into the bore's stock, up
-- to its limit. The loader can't insert them (they are no dig recipe
-- ingredient), so once the stock is full they back up their lane while the
-- other lane keeps delivering heads and fuel.
local function collect_belts(state)
  local loader = state.input_loader
  if not (loader and loader.valid) then
    return
  end
  for index = 1, loader.get_max_transport_line_index() do
    local line = loader.get_transport_line(index)
    local count = math.min(
      line.get_item_count(bore_config.paving_item),
      bore_config.belt_stock_limit - state.belt_stock
    )
    if count > 0 then
      state.belt_stock = state.belt_stock
        + line.remove_item({name = bore_config.paving_item, count = count})
    end
  end
end

local function lay_belt(entity, position, direction)
  local surface = entity.surface
  local belt = {
    name = bore_config.paving_item,
    position = position,
    direction = direction,
    force = entity.force
  }
  if surface.can_place_entity(belt) and surface.create_entity(belt) then
    return
  end
  surface.spill_item_stack({
    position = position,
    stack = {name = bore_config.paving_item, count = 1},
    force = entity.force,
    allow_belts = false
  })
end

local function front_blocker(entity, layer)
  local surface = entity.surface
  local tiles = front_tiles(entity)
  local left_top = {
    x = math.min(tiles[1].x, tiles[2].x) - 0.45,
    y = math.min(tiles[1].y, tiles[2].y) - 0.45
  }
  local right_bottom = {
    x = math.max(tiles[1].x, tiles[2].x) + 0.45,
    y = math.max(tiles[1].y, tiles[2].y) + 0.45
  }
  local blockers = surface.find_entities_filtered({
    area = {left_top, right_bottom},
    type = {"resource", "item-entity", "entity-ghost", "tile-ghost", "corpse", "highlight-box"},
    invert = true
  })
  for _, blocker in pairs(blockers) do
    if not is_wall[blocker.name] then
      return "front-blocked"
    end
  end

  for _, position in ipairs(tiles) do
    local tile = surface.get_tile(position)
    if tile.name ~= tunnel.void_tile and tile.name ~= layer.tunnel_tile
      and tile.collides_with("player") then
      return "front-blocked"
    end
  end
end

-- Hits needed to advance: a full wall's worth, or one if the way is already open.
local function hits_needed(entity, layer)
  for _, position in ipairs(front_tiles(entity)) do
    if tunnel.is_void(entity.surface, position) then
      return layer.hits_per_tile
    end
  end
  return 1
end

-- Chips of rock flying off the wall ahead, one burst per hit.
local function hit_effect(entity)
  local surface = entity.surface
  local forward = forward_vectors[entity.direction]
  for _, position in ipairs(front_tiles(entity)) do
    for _ = 1, 4 do
      surface.create_particle({
        name = "stone-particle",
        position = position,
        movement = {
          -forward.x * 0.06 + (math.random() - 0.5) * 0.08,
          -forward.y * 0.06 + (math.random() - 0.5) * 0.08
        },
        height = 0.6,
        vertical_speed = 0.05 + math.random() * 0.05,
        frame_speed = 1
      })
    end
  end
end

local function unlock_discoveries(entity, layer)
  local statistics = entity.force.get_item_production_statistics(entity.surface)
  for _, unlock in ipairs(layer.unlocks or {}) do
    if statistics.get_input_count(unlock.item) > 0 then
      research.unlock(entity.force, unlock.technology)
    end
  end
end

-- Moves the bore one tile forward. Returns false if it could not move.
local function advance(state, layer)
  local entity = state.entity
  local surface = entity.surface
  local forward = forward_vectors[entity.direction]

  tunnel.open(surface, front_tiles(entity), layer.tunnel_tile)

  local input_position, output_position = rear_tiles(entity)
  destroy_loaders(state)
  if not entity.teleport({
    x = entity.position.x + forward.x,
    y = entity.position.y + forward.y
  }) then
    attach_loaders(state)
    return false
  end

  -- Without belts (no iron yet) the tunnel is left bare.
  if state.belt_stock >= bore_config.paving_count then
    lay_belt(entity, input_position, entity.direction)
    lay_belt(entity, output_position, opposite(entity.direction))
    state.belt_stock = state.belt_stock - bore_config.paving_count
  end
  attach_loaders(state)
  return true
end

-- Picks the best unlocked dig recipe (the last one listed), preferring one
-- whose drill head is in `inventory` (the builder's), if given.
local function default_recipe(entity, layer, inventory)
  local fallback
  for index = #layer.dig_recipes, 1, -1 do
    local dig_recipe = layer.dig_recipes[index]
    local name = bore_config.recipe_name(layer, dig_recipe)
    if entity.force.recipes[name].enabled then
      if not inventory or inventory.get_item_count(bore_config.heads[dig_recipe.head].item) > 0 then
        return name
      end
      fallback = fallback or name
    end
  end
  return fallback
end

function bore.register(entity, inventory)
  local state = {
    entity = entity,
    products_finished = entity.products_finished,
    hits = 0,
    belt_stock = 0
  }
  bores()[entity.unit_number] = state

  local layer = layers_by_surface[entity.surface.name]
  if layer and not entity.get_recipe() then
    local recipe = default_recipe(entity, layer, inventory)
    if recipe then
      entity.set_recipe(recipe)
    end
  end
  attach_loaders(state)
end

-- buffer: the mined-entity buffer, which receives the bore's belt stock.
function bore.unregister(entity, buffer)
  local state = bores()[entity.unit_number]
  if state then
    if buffer and state.belt_stock > 0 then
      buffer.insert({name = bore_config.paving_item, count = state.belt_stock})
    end
    destroy_loaders(state)
    bores()[entity.unit_number] = nil
  end
end

function bore.on_rotated(entity)
  local state = bores()[entity.unit_number]
  if state then
    destroy_loaders(state)
    attach_loaders(state)
  end
end

-- While running, shows wall progress in place of the plain "Working" status.
local function show_progress(state, layer)
  local entity = state.entity
  if entity.status == defines.entity_status.working then
    entity.custom_status = {
      diode = defines.entity_status_diode.green,
      label = {
        "ttc-status.digging",
        math.floor(state.hits),
        hits_needed(entity, layer),
        state.belt_stock,
        bore_config.belt_stock_limit
      }
    }
  else
    entity.custom_status = nil
  end
end

local function update(state)
  local entity = state.entity
  local layer = layers_by_surface[entity.surface.name]
  if not layer then
    set_status(state, "not-underground")
    return
  end

  local recipe = entity.get_recipe()
  if recipe and bore_config.recipe_layers[recipe.name] ~= layer then
    set_status(state, "wrong-layer")
    return
  end

  -- Hits dealt by the current recipe so far: worn-out heads plus the wear on
  -- the one in use. A recipe change restarts the craft, so any progress since
  -- then already belongs to the new recipe.
  local head = recipe and bore_config.recipe_heads[recipe.name]
  local dealt = head and (entity.products_finished + entity.crafting_progress) * head.durability or 0
  local recipe_name = recipe and recipe.name
  if state.recipe_name ~= recipe_name then
    state.recipe_name = recipe_name
    state.dealt = head and entity.products_finished * head.durability or 0
  end
  if dealt > state.dealt then
    local hits = state.hits + dealt - state.dealt
    if math.floor(hits) > math.floor(state.hits) then
      hit_effect(entity)
    end
    state.hits = hits
  end
  state.dealt = dealt

  local finished = entity.products_finished
  if finished > state.products_finished then
    unlock_discoveries(entity, layer)
  end
  state.products_finished = finished
  collect_belts(state)

  -- Also pauses digging before a hit lands on a tile the bore can't enter.
  while true do
    local blocker = front_blocker(entity, layer)
    if blocker then
      set_status(state, blocker)
      return
    end
    -- With a little slack: summed fractional progress drifts a hair short.
    local needed = hits_needed(entity, layer)
    if state.hits + 0.001 < needed then
      break
    end
    if not advance(state, layer) then
      set_status(state, "front-blocked")
      return
    end
    state.hits = state.hits - needed
  end

  attach_loaders(state)
  set_status(state, nil)
  show_progress(state, layer)
end

function bore.tick()
  for unit_number, state in pairs(bores()) do
    if state.entity.valid then
      update(state)
    else
      destroy_loaders(state)
      bores()[unit_number] = nil
    end
  end
end

-- Rebuilds bore state from the map, e.g. after the bore prototype changed type.
function bore.rescan()
  local known = bores()
  for unit_number, state in pairs(known) do
    if not state.entity or not state.entity.valid then
      known[unit_number] = nil
    end
  end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({name = bore_name})) do
      if not known[entity.unit_number] then
        bore.register(entity)
      end
    end
  end
end

bore.entity_name = bore_name

return bore
