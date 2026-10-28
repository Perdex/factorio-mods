-- Tunnel bore: a burner furnace whose dig recipe wears out drill heads while
-- burning fuel; the inserted head picks the recipe (runtime/wear.lua). Each
-- hit brings out some of the floor's rock. One craft is one head's whole life: its hits land on the
-- wall ahead as the craft progresses, and after the layer's hits_per_tile hits
-- the bore breaks through and advances one tile (mid-craft if need be),
-- opening the tunnel in front, laying a supply lane and an output lane behind
-- (from belts it pulls off the supply lane, if it has any), and moving the
-- hidden loaders that connect those lanes to the bore.
local layers = require("shared.layers")
local bore_config = require("shared.bore")
local research = require("runtime.research")
local tunnel = require("runtime.tunnel")
local veins = require("runtime.veins")
local wear = require("runtime.wear")

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

local bore_names = {}
for name in pairs(bore_config.tiers) do
  bore_names[#bore_names + 1] = name
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

local function width_of(entity)
  return bore_config.tiers[entity.name].width or 2
end

local function front_tiles(entity)
  local width = width_of(entity)
  local tiles = {}
  for i = 0, width - 1 do
    tiles[#tiles + 1] = relative(entity, 1.5, i - (width - 1) / 2)
  end
  return tiles
end

-- Input loader on the rear left, output loader on the rear right.
local function rear_tiles(entity)
  local half = (width_of(entity) - 1) / 2
  return relative(entity, -1.5, -half), relative(entity, -1.5, half), relative(entity, -1.5, 0)
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

-- Only belt-laying bores (Mk2) have loaders at their rear.
local function attach_loaders(state)
  if not state.lays_belts then
    return
  end
  local entity = state.entity
  local input_position, output_position, pipe_position = rear_tiles(entity)
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
local function collect(loader, item, stock, limit)
  for index = 1, loader.get_max_transport_line_index() do
    local line = loader.get_transport_line(index)
    local count = math.min(line.get_item_count(item), limit - stock)
    if count > 0 then
      stock = stock + line.remove_item({name = item, count = count})
    end
  end
  return stock
end

local function collect_belts(state)
  if not state.lays_belts then
    return
  end
  local loader = state.input_loader
  if not (loader and loader.valid) then
    return
  end
  state.belt_stock = collect(loader, bore_config.paving_item, state.belt_stock, bore_config.belt_stock_limit)
  if state.lays_pipes then
    state.pipe_stock = collect(loader, bore_config.pipe_item, state.pipe_stock, bore_config.pipe_stock_limit)
  end
end

local function lay_belt(entity, position, direction, item)
  local surface = entity.surface
  local belt = {
    name = item or bore_config.paving_item,
    position = position,
    direction = direction,
    force = entity.force
  }
  if surface.can_place_entity(belt) then
    local created = surface.create_entity(belt)
    if created then
      return created
    end
  end
  surface.spill_item_stack({
    position = position,
    stack = {name = item or bore_config.paving_item, count = 1},
    force = entity.force,
    allow_belts = false
  })
end

local wire_ids = {defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green}

-- What the bore's red and green wires are connected to, by wire.
local function circuit_targets(entity)
  local targets = {}
  for _, id in ipairs(wire_ids) do
    local connector = entity.get_wire_connector(id, false)
    if connector then
      for _, connection in pairs(connector.connections) do
        if connection.origin == defines.wire_origin.player then
          targets[id] = targets[id] or {}
          table.insert(targets[id], connection.target)
        end
      end
    end
  end
  return targets
end

-- Keeps the bore wired as it moves: the newly laid supply belt takes over
-- the bore's connections and the bore connects to that belt, so the wire
-- runs along the supply lane back to wherever it was attached.
local function carry_wires(entity, targets, belt)
  for id, wired in pairs(targets) do
    local bore_connector = entity.get_wire_connector(id, true)
    local belt_connector = belt.get_wire_connector(id, true)
    for _, target in ipairs(wired) do
      if target.valid and belt_connector.connect_to(target) then
        bore_connector.disconnect_from(target)
      end
    end
    bore_connector.connect_to(belt_connector)
  end
end

local function front_blocker(entity, layer)
  local surface = entity.surface
  local tiles = front_tiles(entity)
  local left_top = {x = math.huge, y = math.huge}
  local right_bottom = {x = -math.huge, y = -math.huge}
  for _, tile in ipairs(tiles) do
    left_top = {x = math.min(left_top.x, tile.x - 0.45), y = math.min(left_top.y, tile.y - 0.45)}
    right_bottom = {x = math.max(right_bottom.x, tile.x + 0.45), y = math.max(right_bottom.y, tile.y + 0.45)}
  end
  local blockers = surface.find_entities_filtered({
    area = {left_top, right_bottom},
    type = {"resource", "item-entity", "entity-ghost", "tile-ghost", "corpse", "highlight-box"},
    invert = true
  })
  -- Things nothing collides with (cliff faces, vein ore, the landing under a
  -- core drill) don't stand in the way.
  for _, blocker in pairs(blockers) do
    if next(blocker.prototype.collision_mask.layers) then
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
-- The rock ahead: hits needed to break through, what each hit brings out, and
-- the vein it belongs to, if any (the hardest of the two tiles counts). One
-- hit is enough where the way is already open.
local function rock_ahead(entity, layer)
  local solid, vein = false, nil
  for _, position in ipairs(front_tiles(entity)) do
    if tunnel.is_void(entity.surface, position) then
      solid = true
      local found = veins.at(entity.surface, position)
      if found and (not vein or found.hardness > vein.hardness) then
        vein = found
      end
    end
  end
  if not solid then
    return 1, layer.drops
  end
  if vein then
    return layer.hits_per_tile * vein.hardness, vein.drops, vein
  end
  return layer.hits_per_tile, layer.drops
end

local function hits_needed(entity, layer)
  return (rock_ahead(entity, layer))
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

  -- Breaking into a vein that holds a resource (an oil pocket) leaves it
  -- there, once per vein.
  local front = front_tiles(entity)
  local springs = {}
  for _, position in ipairs(front) do
    if tunnel.is_void(surface, position) then
      local vein, key = veins.at(surface, position)
      if vein and vein.resource then
        springs[#springs + 1] = {vein = vein, key = key, position = position}
      end
    end
  end
  tunnel.open(surface, front, layer.tunnel_tile)
  storage.ttc.vein_resources = storage.ttc.vein_resources or {}
  for _, spring in ipairs(springs) do
    if not storage.ttc.vein_resources[spring.key] then
      storage.ttc.vein_resources[spring.key] = true
      surface.create_entity({
        name = spring.vein.resource.name,
        position = {x = math.floor(spring.position.x) + 0.5, y = math.floor(spring.position.y) + 0.5},
        amount = spring.vein.resource.amount
      })
    end
  end

  local input_position, output_position = rear_tiles(entity)
  local wires = circuit_targets(entity)
  destroy_loaders(state)
  if not entity.teleport({
    x = entity.position.x + forward.x,
    y = entity.position.y + forward.y
  }) then
    attach_loaders(state)
    return false
  end

  -- Without belts (no iron yet) the tunnel is left bare.
  -- Coolant bores lay a pipe right behind their inlet (no loader sits there),
  -- so the water line follows.
  if state.lays_pipes and state.pipe_stock >= 1 then
    local _, _, pipe_position = rear_tiles(entity)
    lay_belt(entity, pipe_position, defines.direction.north, bore_config.pipe_item)
    state.pipe_stock = state.pipe_stock - 1
  end
  if state.lays_belts and state.belt_stock >= bore_config.paving_count then
    local supply_belt = lay_belt(entity, input_position, entity.direction)
    lay_belt(entity, output_position, opposite(entity.direction))
    state.belt_stock = state.belt_stock - bore_config.paving_count
    if supply_belt then
      carry_wires(entity, wires, supply_belt)
    end
  end
  attach_loaders(state)
  return true
end

function bore.register(entity)
  local state = wear.new_state(entity)
  state.entity = entity
  state.hits = 0
  state.belt_stock = 0
  state.pipe_stock = 0
  state.lays_pipes = bore_config.tiers[entity.name].lays_pipes
  state.lays_belts = bore_config.tiers[entity.name].lays_belts
  state.coolant = bore_config.tiers[entity.name].coolant
  bores()[entity.unit_number] = state
  attach_loaders(state)
end

-- buffer: the mined-entity buffer, which receives the bore's belt stock.
function bore.unregister(entity, buffer)
  local state = bores()[entity.unit_number]
  if state then
    if buffer and state.belt_stock > 0 then
      buffer.insert({name = bore_config.paving_item, count = state.belt_stock})
    end
    if buffer and (state.pipe_stock or 0) > 0 then
      buffer.insert({name = bore_config.pipe_item, count = state.pipe_stock})
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
local function progress_label(state, layer)
  local needed, _, vein = rock_ahead(state.entity, layer)
  local hits = math.floor(state.hits)
  local vein_name = vein and {"ttc-vein-name." .. vein.name}
  if state.lays_belts then
    local stock, limit = state.belt_stock, bore_config.belt_stock_limit
    if vein then
      return {"ttc-status.digging-vein-belts", hits, needed, vein_name, stock, limit}
    end
    return {"ttc-status.digging", hits, needed, stock, limit}
  end
  if vein then
    return {"ttc-status.digging-vein", hits, needed, vein_name}
  end
  return {"ttc-status.digging-no-belts", hits, needed}
end

local function show_progress(state, layer)
  local entity = state.entity
  if entity.status == defines.entity_status.working then
    entity.custom_status = {
      diode = defines.entity_status_diode.green,
      label = progress_label(state, layer)
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

  -- Hot floors need a coolant-cooled bore.
  if layer.needs_coolant and not state.coolant then
    set_status(state, "too-hot")
    return
  end

  -- Coolant-cooled bores stop without water.
  local water = state.coolant and entity.get_fluid(1)
  if state.coolant and (not water or water.amount < state.coolant) then
    set_status(state, "needs-coolant")
    return
  end

  -- Each hit on the wall brings out some of the floor's rock.
  local dealt, whole = wear.update(state, entity, bore_config.recipe_heads)
  if water and whole > 0 then
    entity.remove_fluid(1, math.min(water.amount, whole * state.coolant))
  end
  state.hits = state.hits + dealt
  if whole > 0 then
    hit_effect(entity)
    local _, drops = rock_ahead(entity, layer)
    wear.roll(state, drops, whole)
  end
  local delivered_all, delivered = wear.deliver(state, entity)
  if delivered then
    unlock_discoveries(entity, layer)
  end
  if not delivered_all and entity.get_recipe() then
    set_status(state, "output-full")
    return
  end
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
    for _, entity in pairs(surface.find_entities_filtered({name = bore_names})) do
      if not known[entity.unit_number] then
        bore.register(entity)
      end
    end
  end
end

function bore.handles(entity)
  return bore_config.tiers[entity.name] ~= nil
end

return bore
