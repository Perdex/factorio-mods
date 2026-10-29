-- Tunnel bore: a burner furnace whose dig recipe wears out drill heads while
-- burning fuel; the inserted head picks the recipe (runtime/wear.lua). Each
-- hit brings out some of the floor's rock. One craft is one head's whole life: its hits land on the
-- wall ahead as the craft progresses, and after the layer's hits_per_tile hits
-- the bore breaks through and advances one tile (mid-craft if need be; whole
-- hits left over don't carry to the next tile),
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

-- Circuit signals -------------------------------------------------------------

local function signal_value(signal)
  return {type = signal.type or "item", name = signal.name, quality = "normal"}
end

local function pulses()
  storage.ttc.bore_pulses = storage.ttc.bore_pulses or {}
  return storage.ttc.bore_pulses
end

-- Whether a player has wired the bore. The hidden combinator's own wires
-- don't count: the bore's circuit settings only show once a player wires it.
local function wired(entity)
  for _, id in ipairs(wire_ids) do
    local connector = entity.get_wire_connector(id, false)
    if connector then
      for _, connection in pairs(connector.connections) do
        if connection.origin == defines.wire_origin.player then
          return true
        end
      end
    end
  end
  return false
end

local function remove_signals(state)
  if state.signals and state.signals.valid then
    state.signals.destroy()
  end
  state.signals = nil
end

-- The hidden combinator carrying the bore's own signals, wired to both of
-- the bore's circuit connectors. It only exists while the bore is wired and
-- has an output turned on.
local function signal_section(state)
  local entity = state.entity
  local combinator = state.signals
  if not (combinator and combinator.valid) then
    combinator = entity.surface.create_entity({
      name = bore_config.signal_entity,
      position = entity.position,
      force = entity.force
    })
    combinator.destructible = false
    for _, id in ipairs(wire_ids) do
      combinator.get_wire_connector(id, true).connect_to(entity.get_wire_connector(id, true), false,
        defines.wire_origin.script)
    end
    state.signals = combinator
  end
  local behavior = combinator.get_control_behavior()
  return behavior.sections_count > 0 and behavior.get_section(1) or behavior.add_section()
end

-- Slot 1: hits remaining on the face ahead. Slot 2: the pulse when it moves.
local function output_hits(state, remaining)
  if not ((state.read_hits or state.read_moved) and wired(state.entity)) then
    remove_signals(state)
    return
  end
  local section = signal_section(state)
  if state.read_hits then
    section.set_slot(1, {value = signal_value(state.hits_signal), min = remaining})
  else
    section.clear_slot(1)
  end
end

local function pulse_moved(state)
  if not (state.read_moved and wired(state.entity)) then
    return
  end
  signal_section(state).set_slot(2, {value = signal_value(state.moved_signal), min = 1})
  pulses()[state.entity.unit_number] = game.tick
end

-- Ends the moved pulses a tick after they started.
function bore.end_pulses()
  local pending = pulses()
  if not next(pending) then
    return
  end
  for unit_number, tick in pairs(pending) do
    if game.tick > tick then
      local state = bores()[unit_number]
      if state and state.signals and state.signals.valid then
        signal_section(state).clear_slot(2)
      end
      pending[unit_number] = nil
    end
  end
end

-- Net turn signal on the bore's network: clockwise against anticlockwise.
local function turn_wanted(entity)
  local red, green = defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green
  return entity.get_signal(bore_config.clockwise_signal, red, green)
    - entity.get_signal(bore_config.anticlockwise_signal, red, green)
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

-- The rock ahead, tile by tile: each solid tile in front of the bore, the
-- hits it takes to break (more in a vein) and what each hit brings out.
local function rock_ahead(entity, layer)
  local rock = {}
  for _, position in ipairs(front_tiles(entity)) do
    if tunnel.is_void(entity.surface, position) then
      local vein = veins.at(entity.surface, position)
      rock[#rock + 1] = {
        position = position,
        vein = vein,
        needed = layer.hits_per_tile * (vein and vein.hardness or 1),
        drops = vein and vein.drops or layer.drops
      }
    end
  end
  return rock
end

-- Every hit lands on the whole face, so softer tiles give way first and the
-- bore advances once the hardest one breaks. Returns the hits that takes, the
-- hardest tile (a vein wins a tie) and the rock ahead. One hit is enough
-- where the way is already open.
local function hits_needed(entity, layer)
  local rock = rock_ahead(entity, layer)
  local hardest
  for _, tile in ipairs(rock) do
    if not hardest or tile.needed > hardest.needed
      or (tile.needed == hardest.needed and tile.vein and not hardest.vein) then
      hardest = tile
    end
  end
  return hardest and hardest.needed or 1, hardest, rock
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

-- Opens the rock at positions. Breaking into a vein that holds a resource (an
-- oil pocket) leaves it there, once per vein.
local function break_rock(surface, positions, layer)
  local springs = {}
  for _, position in ipairs(positions) do
    if tunnel.is_void(surface, position) then
      local vein, key = veins.at(surface, position)
      if vein and vein.resource then
        springs[#springs + 1] = {vein = vein, key = key, position = position}
      end
    end
  end
  tunnel.open(surface, positions, layer.tunnel_tile)
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
end

-- Moves the bore one tile forward. Returns false if it could not move.
local function advance(state, layer)
  local entity = state.entity
  local forward = forward_vectors[entity.direction]
  break_rock(entity.surface, front_tiles(entity), layer)

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
  if state.signals and state.signals.valid then
    state.signals.teleport(entity.position)
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
  state.hits_signal = bore_config.hits_signal
  state.moved_signal = bore_config.moved_signal
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
    if state.signals and state.signals.valid then
      state.signals.destroy()
    end
    bores()[entity.unit_number] = nil
  end
end

-- A turned bore faces a new wall and starts on it from scratch.
function bore.on_rotated(entity)
  local state = bores()[entity.unit_number]
  if state then
    state.hits = 0
    destroy_loaders(state)
    attach_loaders(state)
  end
end

-- While running, shows wall progress in place of the plain "Working" status.
local function progress_label(state, layer)
  local needed, hardest = hits_needed(state.entity, layer)
  local vein = hardest and hardest.vein
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

-- Wall bar ---------------------------------------------------------------------

-- A panel beside the bore's window, like the core drill's depth bar: the
-- crafting bar there is the drill head's wear, so the wall ahead gets its own
-- bar, with the vein's resource shown when the bore is in one.
local wall_frame = "ttc-bore-wall"

local function wall_panel(player)
  local frame = player.gui.relative[wall_frame]
  if frame and not frame.circuit then
    -- Built by an older version.
    frame.destroy()
    frame = nil
  end
  if not frame then
    frame = player.gui.relative.add({
      type = "frame",
      name = wall_frame,
      caption = {"ttc.bore-wall-title"},
      direction = "vertical",
      anchor = {
        gui = defines.relative_gui_type.furnace_gui,
        position = defines.relative_gui_position.right,
        names = bore_names
      }
    })
    local row = frame.add({type = "flow", name = "row", direction = "horizontal"})
    row.style.vertical_align = "center"
    row.add({type = "sprite", name = "vein"})
    row.add({type = "label", name = "wall"})
    frame.add({type = "progressbar", name = "bar"}).style.width = 220
    local circuit = frame.add({type = "flow", name = "circuit", direction = "vertical"})
    circuit.add({type = "line"})
    circuit.add({type = "label", caption = {"ttc.bore-circuit-title"}, style = "caption_label"})
    for _, option in ipairs({"hits", "moved"}) do
      local option_row = circuit.add({type = "flow", name = option, direction = "horizontal"})
      option_row.style.vertical_align = "center"
      option_row.add({type = "checkbox", name = "ttc-bore-read-" .. option, state = false,
        caption = {"ttc.bore-read-" .. option}, tags = {option = option}})
      option_row.add({type = "empty-widget"}).style.horizontally_stretchable = true
      option_row.add({type = "choose-elem-button", name = "ttc-bore-signal-" .. option, elem_type = "signal",
        style = "slot_button_in_shallow_frame", tags = {option = option}})
    end
    local hint = circuit.add({type = "label", caption = {"ttc.bore-turn-hint"}})
    hint.style.single_line = false
    hint.style.maximal_width = 220
  end
  return frame
end

local function show_wall(player, entity)
  local frame = wall_panel(player)
  local state = bores()[entity.unit_number]
  local layer = layers_by_surface[entity.surface.name]
  local row = frame.row
  frame.circuit.visible = state ~= nil and wired(entity)
  if state then
    for _, option in ipairs({"hits", "moved"}) do
      frame.circuit[option]["ttc-bore-read-" .. option].state = state["read_" .. option] or false
      frame.circuit[option]["ttc-bore-signal-" .. option].elem_value = state[option .. "_signal"]
    end
  end
  if not (state and layer) then
    row.vein.visible = false
    row.wall.caption = {"ttc-status.not-underground"}
    frame.bar.value = 0
    return
  end
  local needed, hardest = hits_needed(entity, layer)
  local vein = hardest and hardest.vein
  local hits = math.floor(state.hits)
  row.vein.visible = vein ~= nil
  if vein then
    row.vein.sprite = veins.sprite(vein)
    row.wall.caption = {"ttc.bore-wall-vein", hits, needed, {"ttc-vein-name." .. vein.name}}
  else
    row.wall.caption = {"ttc.bore-wall", hits, needed}
  end
  frame.bar.value = math.min(1, state.hits / needed)
end

function bore.on_gui_opened(event)
  local entity = event.entity
  if entity and entity.valid and bore.handles(entity) then
    show_wall(game.get_player(event.player_index), entity)
  end
end

-- The circuit options in the panel apply to the bore the player has open.
local function opened_state(player)
  local opened = player.opened
  if player.opened_gui_type == defines.gui_type.entity and opened and opened.valid and bore.handles(opened) then
    return bores()[opened.unit_number]
  end
end

function bore.on_gui_changed(event)
  local element = event.element
  local option = element.valid and element.tags.option
  if not (option and element.name:find("^ttc%-bore%-")) then
    return
  end
  local state = opened_state(game.get_player(event.player_index))
  if not state then
    return
  end
  if element.type == "checkbox" then
    state["read_" .. option] = element.state
  elseif element.elem_value then
    state[option .. "_signal"] = element.elem_value
  else
    -- An emptied signal button falls back to the default signal.
    state[option .. "_signal"] = bore_config[option .. "_signal"]
  end
  local layer = layers_by_surface[state.entity.surface.name]
  if layer then
    output_hits(state, math.ceil(hits_needed(state.entity, layer) - state.hits))
  end
end

function bore.set_signals(unit_number, options)
  local state = bores()[unit_number]
  if state then
    state.read_hits = options.read_hits
    state.read_moved = options.read_moved
  end
end

local function refresh_wall_panels()
  for _, player in pairs(game.connected_players) do
    local opened = player.opened
    if player.opened_gui_type == defines.gui_type.entity and opened and opened.valid and bore.handles(opened) then
      show_wall(player, opened)
    end
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
    local _, hardest = hits_needed(entity, layer)
    wear.roll(state, hardest and hardest.drops or layer.drops, whole)
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
    local needed, _, rock = hits_needed(entity, layer)
    if state.hits + 0.001 < needed then
      local broken = {}
      for _, tile in ipairs(rock) do
        if state.hits + 0.001 >= tile.needed then
          broken[#broken + 1] = tile.position
        end
      end
      if #broken > 0 then
        break_rock(entity.surface, broken, layer)
      end
      break
    end
    if not advance(state, layer) then
      set_status(state, "front-blocked")
      return
    end
    -- Only the part of a hit already under way carries over.
    state.hits = math.max(0, state.hits - needed) % 1
    pulse_moved(state)
    -- Turn signals turn it as it moves (a Mk3 only where its new footprint
    -- fits), facing a new wall.
    local turn = turn_wanted(entity)
    if turn ~= 0 and entity.rotate({reverse = turn < 0}) then
      bore.on_rotated(entity)
    end
  end

  attach_loaders(state)
  output_hits(state, math.ceil(hits_needed(entity, layer) - state.hits))
  set_status(state, nil)
  show_progress(state, layer)
end

function bore.tick()
  for unit_number, state in pairs(bores()) do
    if state.entity.valid then
      update(state)
    else
      destroy_loaders(state)
      if state.signals and state.signals.valid then
        state.signals.destroy()
      end
      bores()[unit_number] = nil
    end
  end
  refresh_wall_panels()
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
