local bore = require("runtime.bore")
local bore_config = require("shared.bore")
local layers = require("runtime.layers")
local manhole = require("runtime.manhole")
local progression = require("runtime.progression")
local shaft = require("runtime.shaft")
local transfer = require("runtime.transfer")
local veins = require("runtime.veins")

-- A normal start has nothing but what survived the crash: the core drill and
-- a few wooden drill heads in the ship, and in the wreckage a little coal to
-- start the drill with (freeplay's default would be iron). Wood and stone
-- come from trees and rocks.
local starter = {
  player = {},
  ship = {["ttc-core-drill"] = 1, ["ttc-wooden-drill-head"] = 5},
  debris = {coal = 2}
}

local function state()
  storage.ttc = storage.ttc or {}
  storage.ttc.bores = storage.ttc.bores or {}
  storage.ttc.core_drills = storage.ttc.core_drills or {}
  storage.ttc.shafts = storage.ttc.shafts or {}
  storage.ttc.last_teleport = storage.ttc.last_teleport or {}
  return storage.ttc
end

local function enable_starter_recipes(force)
  local names = {"ttc-core-drill"}
  -- A bore takes any drill head; saves from when dig recipes were locked
  -- behind technologies get them enabled here.
  for head_name in pairs(bore_config.heads) do
    names[#names + 1] = bore_config.recipe_name(head_name)
  end
  for _, name in ipairs(names) do
    local recipe = force.recipes[name]
    if recipe then
      recipe.enabled = true
    end
  end
end

-- Freeplay hands out the kit through its crash site; other scenarios get it
-- straight into the first player's inventory.
local function set_up_crash_site()
  if not remote.interfaces["freeplay"] then
    return
  end
  local items = starter
  remote.call("freeplay", "set_created_items", items.player)
  remote.call("freeplay", "set_ship_items", items.ship)
  remote.call("freeplay", "set_debris_items", items.debris)
  storage.ttc.crash_site_kit = true
end

local function on_player_created(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if not storage.ttc.crash_site_kit and not storage.ttc.kit_given then
    storage.ttc.kit_given = true
    for _, part in pairs(starter) do
      for name, count in pairs(part) do
        player.insert({name = name, count = count})
      end
    end
  end
  enable_starter_recipes(player.force)
  player.print({"ttc.starter-instructions"})
end

-- Winnowers let the wind carry dust away, so they need open sky: on a floor
-- they are taken back down.
local function needs_open_sky(entity, player)
  if not layers.of_surface(entity.surface) then
    return
  end
  local surface, position, name = entity.surface, entity.position, entity.name
  entity.destroy()
  local stack = {name = name, count = 1}
  if not (player and player.insert(stack) > 0) then
    surface.spill_item_stack({position = position, stack = stack, allow_belts = false})
  end
  if player then
    player.create_local_flying_text({text = {"ttc.needs-open-sky"}, position = position})
  end
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end

  if entity.name == shaft.drill_name then
    shaft.register(entity)
  elseif bore.handles(entity) then
    bore.register(entity)
  elseif transfer.handles(entity) then
    transfer.on_built(entity, event.player_index and game.get_player(event.player_index))
  elseif manhole.handles(entity) then
    manhole.on_built(entity, event.player_index and game.get_player(event.player_index))
  elseif entity.name == "ttc-winnower" then
    needs_open_sky(entity, event.player_index and game.get_player(event.player_index))
  end
end

local function on_removed(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end

  if entity.name == shaft.drill_name then
    shaft.unregister(entity)
  elseif bore.handles(entity) then
    bore.unregister(entity, event.buffer)
  elseif transfer.handles(entity) then
    transfer.on_removed(entity, event.buffer)
  end
end

local function on_rotated(event)
  local entity = event.entity
  if entity and entity.valid and bore.handles(entity) then
    bore.on_rotated(entity)
  elseif entity and entity.valid and transfer.handles(entity) then
    transfer.on_rotated(entity)
  end
end

local function initialize()
  state()
  bore.rescan()
  shaft.rescan()
  for _, force in pairs(game.forces) do
    enable_starter_recipes(force)
  end
end

-- Lets other mods (and the engine test) ask where shaft stairs lead.
remote.add_interface("to-the-core", {
  -- Turns ore veins on or off (the "ttc-veins" setting), e.g. for scenarios.
  set_veins = function(enabled)
    settings.global["ttc-veins"] = {value = enabled}
  end,
  vein_at = function(surface_index, position)
    local vein = veins.at(game.surfaces[surface_index], position)
    return vein and vein.name
  end,
  -- What the panel's circuit options set: options = {read_hits, read_moved}.
  set_bore_signals = function(unit_number, options)
    bore.set_signals(unit_number, options)
  end,
  travel_target = function(surface_index, position, direction)
    local surface, target = shaft.travel_target(game.surfaces[surface_index], position, direction)
    return surface and {surface_index = surface.index, position = target}
  end
})

script.on_init(function()
  initialize()
  set_up_crash_site()
end)
script.on_configuration_changed(initialize)

script.on_event(defines.events.on_player_created, on_player_created)
script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}, on_built)
script.on_event({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy
}, on_removed)
script.on_event(defines.events.on_player_rotated_entity, on_rotated)
script.on_event(defines.events.on_research_finished, progression.on_research_finished)
script.on_event(defines.events.on_gui_opened, function(event)
  shaft.on_gui_opened(event)
  bore.on_gui_opened(event)
end)
script.on_event(defines.events.on_chunk_generated, layers.on_chunk_generated)
script.on_event({
  defines.events.on_gui_checked_state_changed,
  defines.events.on_gui_elem_changed
}, bore.on_gui_changed)
script.on_event(defines.events.on_tick, bore.end_pulses)
script.on_nth_tick(10, function()
  bore.tick()
  transfer.tick()
end)
script.on_nth_tick(30, shaft.tick)
script.on_nth_tick(6, function()
  shaft.check_travel()
  manhole.check_falls()
end)
