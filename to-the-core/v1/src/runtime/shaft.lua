-- Core drill and shafts. A core drill crafts the shaft segments of the layer
-- below it, like a rocket silo crafts rocket parts. When the last segment is
-- done the shaft breaks through: the drill's site becomes a pit with stairs
-- going down along two of its rims (shaft top), the layer below gets a small
-- landing platform where the same stairs arrive (shaft bottom), and the drill
-- itself moves down onto the landing. Anything left in it moves along; it then
-- waits until that is taken out and it is fed the next layer's inputs.
--
-- Players travel by walking along the stairs: down to their low end on a shaft
-- top to descend, up to their high end on a shaft bottom to ascend.
local shaft_config = require("shared.shaft")
local layers = require("runtime.layers")
local research = require("runtime.research")
local tunnel = require("runtime.tunnel")

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

-- Shaft links by "<surface index>:<x>:<y>" of either end.
local function links()
  storage.ttc.shafts = storage.ttc.shafts or {}
  return storage.ttc.shafts
end

local function link_key(surface, position)
  return surface.index .. ":" .. position.x .. ":" .. position.y
end

local function set_status(entity, status_key, diode, ...)
  entity.disabled_by_script = diode == defines.entity_status_diode.red
  entity.custom_status = status_key and {
    diode = diode,
    label = {"ttc-status." .. status_key, ...}
  } or nil
end

-- emptying: the drill still holds the previous shaft's leftovers and keeps
-- that recipe until they are taken out.
function shaft.register(entity, emptying)
  drills()[entity.unit_number] = {
    entity = entity,
    products_finished = entity.products_finished,
    segments = 0,
    emptying = emptying
  }
  local below = layers.below(entity.surface)
  if below and not emptying then
    entity.set_recipe(shaft_config.recipe_name(below))
  end
end

function shaft.unregister(entity)
  drills()[entity.unit_number] = nil
end

local function open_landing(surface, position, layer, axis)
  -- From the centre tile to the outermost tile centre of shaft plus margin.
  local reach = half - 0.5 + shaft_config.platform_margin
  tunnel.open_area(
    surface,
    {x = position.x - reach, y = position.y - reach},
    {x = position.x + reach, y = position.y + reach},
    layer.tunnel_tile
  )
  local name = shaft_config.bottom_name(axis)
  if not surface.find_entity(name, position) then
    surface.create_entity({name = name, position = position})
  end
end

local function is_empty(entity)
  return entity.get_inventory(defines.inventory.crafter_input).is_empty()
    and entity.get_output_inventory().is_empty()
end

-- Puts the previous shaft's inputs and outputs back into the moved drill,
-- which keeps that shaft's recipe to hold them. Returns false if there was
-- nothing to keep.
local function keep_leftovers(drill, recipe_name, inputs, outputs)
  if #inputs == 0 and #outputs == 0 then
    return false
  end
  drill.set_recipe(recipe_name)
  local input = drill.get_inventory(defines.inventory.crafter_input)
  local output = drill.get_output_inventory()
  local items = {}
  for _, item in ipairs(inputs) do
    items[#items + 1] = {item = item, inventories = {input, output}}
  end
  for _, item in ipairs(outputs) do
    items[#items + 1] = {item = item, inventories = {output, input}}
  end
  for _, entry in ipairs(items) do
    local item = entry.item
    local left = item.count
    for _, inventory in ipairs(entry.inventories) do
      if left > 0 then
        left = left - inventory.insert({name = item.name, count = left, quality = item.quality})
      end
    end
    if left > 0 then
      drill.surface.spill_item_stack({
        position = drill.position,
        stack = {name = item.name, count = left, quality = item.quality},
        force = drill.force,
        allow_belts = false
      })
    end
  end
  return true
end

-- Breaks the shaft through and moves the drill down. Returns false if the
-- landing spot below is blocked.
local function break_through(state, below, below_index)
  local drill = state.entity
  local surface, force = drill.surface, drill.force
  local position = {x = drill.position.x, y = drill.position.y}
  local lower = layers.surface(below)
  local axis = shaft_config.axis(below_index)

  open_landing(lower, position, below, axis)
  if not lower.can_place_entity({name = drill_name, position = position, force = force}) then
    return false
  end

  local recipe_name = drill.get_recipe().name
  local input = drill.get_inventory(defines.inventory.crafter_input)
  local output = drill.get_output_inventory()
  local inputs, outputs = input.get_contents(), output.get_contents()
  input.clear()
  output.clear()
  -- With the inventories emptied, clearing the recipe hands back only the
  -- ingredients of a craft in progress.
  for _, item in ipairs(drill.set_recipe(nil)) do
    inputs[#inputs + 1] = item
  end
  local fuel = drill.get_fuel_inventory().get_contents()
  local burner = drill.burner
  local burning = burner.currently_burning
  local remaining = burner.remaining_burning_fuel
  local health = drill.health

  shaft.unregister(drill)
  drill.destroy()
  surface.create_entity({name = shaft_config.top_name(axis), position = position})

  local moved = lower.create_entity({name = drill_name, position = position, force = force})
  moved.health = health
  for _, item in ipairs(fuel) do
    moved.get_fuel_inventory().insert(item)
  end
  if burning then
    moved.burner.currently_burning = burning
    moved.burner.remaining_burning_fuel = remaining
  end
  shaft.register(moved, keep_leftovers(moved, recipe_name, inputs, outputs))

  links()[link_key(surface, position)] = lower.index
  links()[link_key(lower, position)] = surface.index
  for _, technology in ipairs(below.reached_unlocks or {}) do
    research.unlock(force, technology)
  end
  force.print({"ttc.shaft-reached", {"ttc-layer-name." .. below.name}})
  return true
end

local function update(state)
  local drill = state.entity
  if state.emptying then
    if not is_empty(drill) then
      set_status(drill, "shaft-leftovers", defines.entity_status_diode.red)
      return
    end
    state.emptying = nil
  end

  local below, below_index = layers.below(drill.surface)
  if not below then
    set_status(drill, "deepest-layer", defines.entity_status_diode.red)
    return
  end

  local recipe_name = shaft_config.recipe_name(below)
  local recipe = drill.get_recipe()
  if not recipe or recipe.name ~= recipe_name then
    for _, item in ipairs(drill.set_recipe(recipe_name)) do
      drill.surface.spill_item_stack({
        position = drill.position,
        stack = item,
        force = drill.force,
        allow_belts = false
      })
    end
    state.products_finished = drill.products_finished
  end

  local finished = drill.products_finished
  state.segments = state.segments + finished - state.products_finished
  state.products_finished = finished

  if state.segments >= below.shaft.segments then
    if not break_through(state, below, below_index) then
      set_status(drill, "landing-blocked", defines.entity_status_diode.red)
    end
    return
  end

  if drill.status == defines.entity_status.working then
    set_status(drill, "shaft-progress", defines.entity_status_diode.green,
      state.segments, below.shaft.segments, {"ttc-layer-name." .. below.name})
  else
    set_status(drill, nil)
  end
end

function shaft.tick()
  for unit_number, state in pairs(drills()) do
    if state.entity.valid then
      update(state)
    else
      drills()[unit_number] = nil
    end
  end
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
-- returns the target surface and position, or nil. Stepping onto the low end
-- of a top's stairs leads just past the foot of the same stairs below;
-- stepping onto the high end of a bottom's stairs leads just past their head
-- above.
function shaft.travel_target(surface, position, direction)
  local walk = walk_vector(direction)
  for _, entity in pairs(surface.find_entities_filtered({
    name = shaft_names,
    position = position,
    radius = half + 1
  })) do
    local kind = shaft_kinds[entity.name]
    local other = game.surfaces[links()[link_key(surface, entity.position)] or -1]
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
          if kind.top and heading > 0.5 and along >= length - 0.5 and along <= length + 0.7 then
            return other, {
              x = center.x + stair.low.x + u.x + n.x * across,
              y = center.y + stair.low.y + u.y + n.y * across
            }
          elseif not kind.top and heading < -0.5 and along <= 0.5 and along >= -0.7 then
            return other, {
              x = center.x + stair.high.x - u.x + n.x * across,
              y = center.y + stair.high.y - u.y + n.y * across
            }
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
  for _, player in pairs(game.connected_players) do
    check_player(player)
  end
end

shaft.drill_name = drill_name

return shaft
