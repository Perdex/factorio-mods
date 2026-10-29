-- Core drill and shafts. A core drill wears out drill heads like a tunnel bore
-- (runtime/wear.lua), digging the shaft to the floor below one hit at a time;
-- each hit brings up the shaft's drops. When the shaft is deep enough it breaks
-- through: the drill's site becomes a pit with stairs going down along two of
-- its rims (shaft top), the floor below gets a small landing platform where the
-- same stairs arrive (shaft bottom), and the drill moves down onto the landing
-- with everything in it, ready to dig the next, harder shaft.
--
-- Players travel by walking along the stairs: down to their low end on a shaft
-- top to descend, up to their high end on a shaft bottom to ascend.
local shaft_config = require("shared.shaft")
local layers = require("runtime.layers")
local progression = require("runtime.progression")
local research = require("runtime.research")
local tunnel = require("runtime.tunnel")
local wear = require("runtime.wear")

local drill_name = shaft_config.drill_name
local half = shaft_config.size / 2
local teleport_cooldown = 35

-- Shaft entity name -> {top = is a top, axis = stair axis}.
local shaft_kinds = {}
local shaft_names = {}
for _, axis in ipairs(shaft_config.axes) do
  shaft_kinds[shaft_config.top_name(axis)] = {top = true, axis = axis}
  shaft_kinds[shaft_config.bottom_name(axis)] = {top = false, axis = axis}
end
for name in pairs(shaft_kinds) do
  shaft_names[#shaft_names + 1] = name
end

local shaft = {}

local function drills()
  storage.ttc.core_drills = storage.ttc.core_drills or {}
  return storage.ttc.core_drills
end

-- Shaft links by "<surface index>:<x>:<y>": `down` is where a shaft top
-- there leads, `up` where a shaft bottom there leads. A floor's landing and
-- its next shaft share a spot, so one spot can have both.
local links_version = 2

local function links()
  storage.ttc.shafts = storage.ttc.shafts or {}
  return storage.ttc.shafts
end

local function link_key(surface, position)
  return surface.index .. ":" .. position.x .. ":" .. position.y
end

local function link(surface, position)
  local key = link_key(surface, position)
  links()[key] = links()[key] or {}
  return links()[key]
end

local function connect(upper, lower, position)
  link(upper, position).down = lower.index
  link(lower, position).up = upper.index
end

-- Rebuilds every link from the shaft tops on the map: each shaft has one,
-- on the floor it was dug from.
local function rebuild_links()
  storage.ttc.shafts = {}
  local top_names = {}
  for _, axis in ipairs(shaft_config.axes) do
    top_names[#top_names + 1] = shaft_config.top_name(axis)
  end
  for _, surface in pairs(game.surfaces) do
    local below = layers.below(surface)
    local lower = below and game.surfaces[below.surface_name]
    if lower then
      for _, top in pairs(surface.find_entities_filtered({name = top_names})) do
        connect(surface, lower, top.position)
      end
    end
  end
  storage.ttc.shaft_links_version = links_version
end

local function set_status(entity, status_key, diode, ...)
  entity.disabled_by_script = diode == defines.entity_status_diode.red
  entity.custom_status = status_key and {
    diode = diode,
    label = {"ttc-status." .. status_key, ...}
  } or nil
end

function shaft.register(entity)
  local state = wear.new_state(entity)
  state.entity = entity
  state.hits = 0
  drills()[entity.unit_number] = state
  return state
end

function shaft.unregister(entity)
  drills()[entity.unit_number] = nil
end

local shaft_entity_names = {}
for _, axis in ipairs(shaft_config.axes) do
  shaft_entity_names[shaft_config.top_name(axis)] = true
  shaft_entity_names[shaft_config.bottom_name(axis)] = true
  shaft_entity_names[shaft_config.stair_blocker_name(axis)] = true
end

-- Clears the square of `size` tiles around `position` for a shaft: whatever
-- was built there is mined (with the usual events, so bores and chutes clean
-- up) and dropped on the ground beside it with its contents; trees and rocks
-- are cleared away and players moved aside. Tunnel walls and shafts stay.
local function clear_site(surface, position, size)
  local half_size = size / 2
  local beside = {x = position.x, y = position.y + half_size + 1}
  local dropped = game.create_inventory(64)
  for _, entity in pairs(surface.find_entities_filtered({
    area = {{position.x - half_size, position.y - half_size}, {position.x + half_size, position.y + half_size}}
  })) do
    if entity.valid and not shaft_entity_names[entity.name]
      and not tunnel.is_wall(entity) and entity.type ~= "resource" then
      if entity.type == "character" then
        local target = surface.find_non_colliding_position("character", beside, 10, 0.5)
        if target then
          entity.teleport(target)
        end
      elseif entity.type == "item-entity" then
        entity.teleport(surface.find_non_colliding_position("item-on-ground", beside, 10, 0.5) or beside)
      elseif entity.force.name == "neutral"
        or not entity.mine({inventory = dropped, force = true, ignore_minable = true}) then
        -- Trees and rocks are simply cleared away.
        entity.destroy({raise_destroy = true})
      end
    end
  end
  for _, item in ipairs(dropped.get_contents()) do
    surface.spill_item_stack({
      position = beside,
      stack = {name = item.name, count = item.count, quality = item.quality},
      allow_belts = false
    })
  end
  dropped.destroy()
end

-- The strips that keep buildings off a shaft's stairs.
local function block_stairs(surface, position, axis)
  local name = shaft_config.stair_blocker_name(axis)
  for _, stair in ipairs(shaft_config.stairs[axis]) do
    local middle = {
      x = position.x + (stair.high.x + stair.low.x) / 2,
      y = position.y + (stair.high.y + stair.low.y) / 2
    }
    if not surface.find_entity(name, middle) then
      surface.create_entity({name = name, position = middle})
    end
  end
end

-- Tile offsets from a shaft's centre tile: the drill's 5x5, plus for each
-- stairway its 5-tile strip and `platform_margin` rows beyond it, as wide as
-- the drill. The other two sides stay rock, so each side is reached by its
-- own stairs.
local function landing_tiles(axis)
  local offsets = {}
  for x = -2, 2 do
    for y = -2, 2 do
      offsets[#offsets + 1] = {x = x, y = y}
    end
  end
  local outer = 3 + shaft_config.platform_margin
  for across = -2, 2 do
    for along = 3, outer do
      for _, side in ipairs({-1, 1}) do
        if axis == "ns" then
          offsets[#offsets + 1] = {x = across, y = side * along}
        else
          offsets[#offsets + 1] = {x = side * along, y = across}
        end
      end
    end
  end
  return offsets
end

local function open_tiles(surface, position, offsets, tile)
  local positions = {}
  for _, offset in ipairs(offsets) do
    positions[#positions + 1] = {x = position.x + offset.x, y = position.y + offset.y}
  end
  tunnel.open(surface, positions, tile)
end

-- Saves from before stairs kept buildings off get their blockers once.
local function ensure_stair_blockers()
  if storage.ttc.stair_blockers then
    return
  end
  storage.ttc.stair_blockers = true
  local kinds = {}
  for _, axis in ipairs(shaft_config.axes) do
    kinds[shaft_config.top_name(axis)] = axis
    kinds[shaft_config.bottom_name(axis)] = axis
  end
  local names = {}
  for name in pairs(kinds) do
    names[#names + 1] = name
  end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({name = names})) do
      block_stairs(surface, entity.position, kinds[entity.name])
    end
  end
end

local function open_landing(surface, position, layer, axis)
  open_tiles(surface, position, landing_tiles(axis), layer.tunnel_tile)
  local name = shaft_config.bottom_name(axis)
  if not surface.find_entity(name, position) then
    surface.create_entity({name = name, position = position})
  end
  block_stairs(surface, position, axis)
end

-- On a floor, the next shaft's stairs are cut into the rock beside its pit,
-- one tile longer at each end so they join the ground around them.
local function open_pit_stairs(surface, position, axis)
  local layer = layers.of_surface(surface)
  if layer then
    local offsets = {}
    for _, stair in ipairs(shaft_config.stairs[axis]) do
      local steps = math.abs(stair.low.x - stair.high.x) + math.abs(stair.low.y - stair.high.y)
      for step = -1, steps + 1 do
        local t = step / steps
        offsets[#offsets + 1] = {
          x = stair.high.x + (stair.low.x - stair.high.x) * t,
          y = stair.high.y + (stair.low.y - stair.high.y) * t
        }
      end
    end
    open_tiles(surface, position, offsets, layer.tunnel_tile)
  end
end

local function break_through(state, below, below_index)
  local drill = state.entity
  local surface, force = drill.surface, drill.force
  local position = {x = drill.position.x, y = drill.position.y}
  local lower = layers.surface(below)
  local axis = shaft_config.axis(below_index)

  open_landing(lower, position, below, axis)
  clear_site(lower, position, shaft_config.size)
  if not lower.can_place_entity({name = drill_name, position = position, force = force}) then
    return false
  end

  -- Everything moves down: the heads (the one being worn comes back whole),
  -- the shaft's drops and the fuel.
  local heads = drill.get_inventory(defines.inventory.crafter_input).get_contents()
  local current = drill.get_recipe()
  if current and drill.is_crafting() then
    heads[#heads + 1] = {name = current.ingredients[1].name, count = 1}
  end
  local pending = state.pending
  for _, item in ipairs(drill.get_output_inventory().get_contents()) do
    pending[item.name] = (pending[item.name] or 0) + item.count
  end
  local fuel = drill.get_fuel_inventory().get_contents()
  local burner = drill.burner
  local burning = burner.currently_burning
  local remaining = burner.remaining_burning_fuel
  local health = drill.health

  shaft.unregister(drill)
  drill.destroy()
  clear_site(surface, position, shaft_config.size)
  open_pit_stairs(surface, position, axis)
  surface.create_entity({name = shaft_config.top_name(axis), position = position})
  block_stairs(surface, position, axis)

  local moved = lower.create_entity({name = drill_name, position = position, force = force})
  moved.health = health
  for _, item in ipairs(fuel) do
    moved.get_fuel_inventory().insert(item)
  end
  if burning then
    moved.burner.currently_burning = burning
    moved.burner.remaining_burning_fuel = remaining
  end
  for _, item in ipairs(heads) do
    moved.get_inventory(defines.inventory.crafter_input).insert(item)
  end
  -- The output only takes drops once the drill digs again.
  shaft.register(moved).pending = pending

  connect(surface, lower, position)
  for _, technology in ipairs(below.reached_unlocks or {}) do
    research.unlock(force, technology)
  end
  progression.reach_floor(force, below_index)
  force.print({"ttc.shaft-reached", {"ttc-layer-name." .. below.name}})
  -- A hint at the ground the next shaft has to go through.
  force.print({"ttc-ground-below." .. below.name})
  return true
end

local function update(state)
  local drill = state.entity
  local below, below_index = layers.below(drill.surface)
  if not below then
    set_status(drill, "deepest-layer", defines.entity_status_diode.red)
    return
  end

  local dealt, whole = wear.update(state, drill, shaft_config.recipe_heads)
  state.hits = state.hits + dealt
  if whole > 0 then
    wear.roll(state, below.shaft.drops, whole)
  end
  if not wear.deliver(state, drill) and drill.get_recipe() then
    set_status(drill, "output-full", defines.entity_status_diode.red)
    return
  end

  for _, unlock in ipairs(below.shaft.unlocks or {}) do
    if state.hits >= unlock.progress * below.shaft.hits and research.unlock(drill.force, unlock.technology) then
      drill.force.print({unlock.message})
    end
  end

  if state.hits + 0.001 >= below.shaft.hits then
    if not break_through(state, below, below_index) then
      set_status(drill, "landing-blocked", defines.entity_status_diode.red)
    end
    return
  end

  if drill.status == defines.entity_status.working then
    set_status(drill, "shaft-progress", defines.entity_status_diode.green,
      math.floor(state.hits), below.shaft.hits, {"ttc-layer-name." .. below.name})
  else
    set_status(drill, nil)
  end
end

-- Depth bar ------------------------------------------------------------------

-- A panel beside the core drill's window: the crafting bar there is the drill
-- head's wear, so the shaft's depth gets its own bar.
local depth_frame = "ttc-core-drill-depth"

local function depth_panel(player)
  local frame = player.gui.relative[depth_frame]
  if not frame then
    frame = player.gui.relative.add({
      type = "frame",
      name = depth_frame,
      caption = {"ttc.shaft-depth-title"},
      direction = "vertical",
      anchor = {
        gui = defines.relative_gui_type.furnace_gui,
        position = defines.relative_gui_position.right,
        name = drill_name
      }
    })
    frame.add({type = "label", name = "depth"})
    frame.add({type = "progressbar", name = "bar"}).style.width = 220
  end
  return frame
end

local function show_depth(player, drill)
  local frame = depth_panel(player)
  local state = drills()[drill.unit_number]
  local below = layers.below(drill.surface)
  if not (state and below) then
    frame.depth.caption = {"ttc-status.deepest-layer"}
    frame.bar.value = 0
    return
  end
  frame.depth.caption = {"ttc.shaft-depth", math.floor(state.hits), below.shaft.hits, {"ttc-layer-name." .. below.name}}
  frame.bar.value = math.min(1, state.hits / below.shaft.hits)
end

function shaft.on_gui_opened(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == drill_name then
    show_depth(game.get_player(event.player_index), entity)
  end
end

local function refresh_depth_panels()
  for _, player in pairs(game.connected_players) do
    local opened = player.opened
    if player.opened_gui_type == defines.gui_type.entity and opened and opened.valid and opened.name == drill_name then
      show_depth(player, opened)
    end
  end
end

-- Saves from before links were kept per direction get theirs rebuilt.
local function ensure_links()
  if storage.ttc.shaft_links_version ~= links_version then
    rebuild_links()
  end
end

function shaft.tick()
  ensure_links()
  ensure_stair_blockers()
  for unit_number, state in pairs(drills()) do
    if state.entity.valid then
      update(state)
    else
      drills()[unit_number] = nil
    end
  end
  refresh_depth_panels()
end

function shaft.rescan()
  local known = drills()
  for unit_number, state in pairs(known) do
    if not (state.entity and state.entity.valid) then
      known[unit_number] = nil
    end
  end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({name = drill_name})) do
      if not known[entity.unit_number] then
        shaft.register(entity)
      end
    end
  end
end

-- Travel ---------------------------------------------------------------------

local function sign(value)
  return value > 0 and 1 or value < 0 and -1 or 0
end

local function walk_vector(direction)
  local angle = direction / 16 * 2 * math.pi
  return {x = math.sin(angle), y = -math.cos(angle)}
end

-- Where walking in `direction` at `position` on `surface` takes a player:
-- returns the target surface and position, or nil. Walking down a top's
-- stairs past their middle, or up a bottom's, leads to the middle of the same
-- stairs on the other floor, where the player carries on the same way.
function shaft.travel_target(surface, position, direction)
  local walk = walk_vector(direction)
  for _, entity in pairs(surface.find_entities_filtered({
    name = shaft_names,
    position = position,
    radius = half + 1
  })) do
    local kind = shaft_kinds[entity.name]
    local entry = links()[link_key(surface, entity.position)] or {}
    local index = kind.top and entry.down or entry.up
    local other = index and game.surfaces[index]
    if other then
      local center = entity.position
      for _, stair in ipairs(shaft_config.stairs[kind.axis]) do
        -- u runs down the stairs, n across them.
        local u = {x = sign(stair.low.x - stair.high.x), y = sign(stair.low.y - stair.high.y)}
        local n = {x = u.y, y = -u.x}
        local length = math.abs(stair.low.x - stair.high.x) + math.abs(stair.low.y - stair.high.y)
        local dx = position.x - center.x - stair.high.x
        local dy = position.y - center.y - stair.high.y
        local along = dx * u.x + dy * u.y
        local across = dx * n.x + dy * n.y
        local heading = walk.x * u.x + walk.y * u.y
        if math.abs(across) <= 0.5 then
          local half_way = length / 2
          local middle = {
            x = center.x + (stair.high.x + stair.low.x) / 2 + n.x * across,
            y = center.y + (stair.high.y + stair.low.y) / 2 + n.y * across
          }
          if kind.top and heading > 0.5 and along >= half_way and along <= length + 0.7 then
            return other, middle
          elseif not kind.top and heading < -0.5 and along <= half_way and along >= -0.7 then
            return other, middle
          end
        end
      end
    end
  end
end

local function check_player(player)
  local walking = player.walking_state
  if not walking.walking or not player.character
    or game.tick - (storage.ttc.last_teleport[player.index] or 0) < teleport_cooldown then
    return
  end

  local surface, position = shaft.travel_target(player.surface, player.position, walking.direction)
  if not surface then
    return
  end
  local target = surface.find_non_colliding_position("character", position, 2, 0.1) or position
  if player.teleport(target, surface) then
    storage.ttc.last_teleport[player.index] = game.tick
  end
end

function shaft.check_travel()
  ensure_links()
  for _, player in pairs(game.connected_players) do
    check_player(player)
  end
end

shaft.drill_name = drill_name

return shaft
