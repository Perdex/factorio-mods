local bore = require("runtime.bore")
local layers = require("runtime.layers")
local shaft = require("runtime.shaft")
local transfer = require("runtime.transfer")

-- A normal start has nothing but what survived the crash: the core drill
-- and some blades in the ship, more blades in the wreckage. Wood and stone
-- come from trees and rocks.
local starter = {
  player = {["pistol"] = 1, ["firearm-magazine"] = 10, ["stone-furnace"] = 1},
  ship = {["ttc-core-drill"] = 1, ["ttc-blade"] = 10},
  debris = {["ttc-blade"] = 50}
}

-- With the "ttc-testing-kit" setting: enough to reach layer 2 and dig around.
local testing = {
  player = {
    ["ttc-mk1-bore"] = 2,
    ["ttc-item-chute"] = 10,
    ["ttc-downpipe"] = 10,
    ["pipe"] = 100,
    ["offshore-pump"] = 2,
    ["ttc-clay-drill-head"] = 200,
    ["iron-plate"] = 200,
    ["iron-gear-wheel"] = 50,
    ["wood"] = 100,
    ["stone"] = 100,
    ["coal"] = 200,
    ["ttc-blade"] = 100,
    ["ttc-wooden-drill-head"] = 200,
    ["transport-belt"] = 400,
    ["ttc-iron-drill-head"] = 400,
    ["ttc-reinforced-drill-head"] = 200
  },
  ship = {["ttc-core-drill"] = 1, ["ttc-blade"] = 10},
  debris = {["ttc-blade"] = 50}
}

local function kit()
  return settings.global["ttc-testing-kit"].value and testing or starter
end

local function state()
  storage.ttc = storage.ttc or {}
  storage.ttc.bores = storage.ttc.bores or {}
  storage.ttc.core_drills = storage.ttc.core_drills or {}
  storage.ttc.shafts = storage.ttc.shafts or {}
  storage.ttc.last_teleport = storage.ttc.last_teleport or {}
  return storage.ttc
end

local function enable_starter_recipes(force)
  for _, name in ipairs({"ttc-core-drill", "ttc-iron-drill-head"}) do
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
  local items = kit()
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
    for _, part in pairs(kit()) do
      for name, count in pairs(part) do
        player.insert({name = name, count = count})
      end
    end
  end
  enable_starter_recipes(player.force)
  player.print({"ttc.starter-instructions"})
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end

  if entity.name == shaft.drill_name then
    shaft.register(entity)
  elseif entity.name == bore.entity_name then
    local player = event.player_index and game.get_player(event.player_index)
    bore.register(entity, player and player.get_main_inventory())
  elseif transfer.handles(entity) then
    transfer.on_built(entity, event.player_index and game.get_player(event.player_index))
  end
end

local function on_removed(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end

  if entity.name == shaft.drill_name then
    shaft.unregister(entity)
  elseif entity.name == bore.entity_name then
    bore.unregister(entity, event.buffer)
  elseif transfer.handles(entity) then
    transfer.on_removed(entity, event.buffer)
  end
end

local function on_rotated(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == bore.entity_name then
    bore.on_rotated(entity)
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
script.on_event(defines.events.on_chunk_generated, layers.on_chunk_generated)
script.on_nth_tick(10, function()
  bore.tick()
  transfer.tick()
end)
script.on_nth_tick(30, shaft.tick)
script.on_nth_tick(6, shaft.check_travel)
