-- Engine test for To the Core, run by tests/run.sh. Logs "TTC ..." lines;
-- checks print PASS/FAIL.
local tunnel = require("__to-the-core__/runtime/tunnel")

local function L(...)
  local n = select("#", ...)
  local t = {...}
  for i = 1, n do
    local v = t[i]
    t[i] = type(v) == "table" and serpent.line(v) or tostring(v)
  end
  log("TTC " .. table.concat(t, " "))
end

local function check(name, ok, detail)
  L(ok and "PASS" or "FAIL", name, detail or "")
end

local S, B, D, M, W, chute, pipe, stray
local drill_position = {x = 100.5, y = 100.5}
local east = defines.direction.east

local function snap(tag)
  L(tag, "tick", game.tick, "pos", B.position, "status", B.status,
    "custom", B.custom_status and B.custom_status.label,
    "heads", B.get_inventory(defines.inventory.crafter_input).get_item_count("ttc-clay-drill-head"),
    "progress", B.crafting_progress,
    "belts laid", #S.find_entities_filtered({name = "transport-belt", area = {{20, -3}, {40, 3}}}))
end

local function count_tiles(left_top, right_bottom, name)
  local count = 0
  for x = left_top.x, right_bottom.x do
    for y = left_top.y, right_bottom.y do
      if S.get_tile(x + 0.5, y + 0.5).name == name then
        count = count + 1
      end
    end
  end
  return count
end

-- Distinct tiles holding any cliff piece.
local function wall_tiles(area)
  local seen, tiles = {}, {}
  for _, wall in pairs(S.find_entities_filtered({name = tunnel.wall_names, area = area})) do
    local key = wall.position.x .. "," .. wall.position.y
    if not seen[key] then
      seen[key] = true
      tiles[#tiles + 1] = key
    end
  end
  table.sort(tiles)
  return tiles
end

-- Feeds belts to an east-facing bore's supply lane and empties its output
-- lane's tail (the first belt it laid, behind its starting position).
local function feed_belts(bore, start_x)
  local loader = S.find_entity("loader-1x1", {bore.position.x - 1.5, bore.position.y - 0.5})
  if loader then
    for i = 1, 2 do
      loader.get_transport_line(i).insert_at_back({name = "transport-belt", count = 1})
    end
  end
  local tail = S.find_entity("transport-belt", {start_x - 1.5, 0.5})
  if tail then
    for i = 1, tail.get_max_transport_line_index() do
      tail.get_transport_line(i).clear()
    end
  end
end

script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick
  if tick == 1 then
    S = game.create_surface("ttc-floor-1", {width = 1, height = 1})

    -- Item 0: a platform at the origin must survive later chunk generation.
    tunnel.open_area(S, {x = -6, y = -5}, {x = 6, y = 5}, "stone-path")
    S.request_to_generate_chunks({0, 0}, 3)
    S.force_generate_chunk_requests()
    check("origin platform survives generation",
      count_tiles({x = -6, y = -5}, {x = 6, y = 5}, "stone-path") == 143)
    check("origin platform walled", #wall_tiles({{-8, -7}, {8, 7}}) == 52)

    -- Bore platform near a chunk border, digging east into ungenerated chunks.
    tunnel.open_area(S, {x = 18, y = -5}, {x = 29, y = 5}, "stone-path")
    local function can(position, direction)
      return S.can_place_entity({name = "ttc-mk1-bore", position = position, direction = direction, force = "player"})
    end
    check("bore placeable at edge facing rock", can({29, 0}, east))
    check("bore not placeable mid-platform", not can({24, 0}, east))
    check("bore not placeable facing platform", not can({19, 0}, east))
    check("bore not placeable over void", not can({31, 0}, east))

    -- Core drill on the starting surface: 20 segments of 1 wooden head, plus
    -- 3 extra heads: one is in the 21st segment's craft when the shaft breaks
    -- through and two are left over.
    D = game.surfaces.nauvis.create_entity({name = "ttc-core-drill", position = drill_position, force = "player", raise_built = true})
    D.insert({name = "ttc-wooden-drill-head", count = 23})
    D.insert({name = "wood", count = 20})

    -- A second bore on the origin platform, never given belts: wooden heads
    -- last 10 hits, so a 40-hit clay tile takes four of them.
    W = S.create_entity({name = "ttc-mk1-bore", position = {6, 0}, direction = east, force = "player", raise_built = true})
    W.set_recipe("ttc-dig-floor_1-wooden")
    W.insert({name = "wood", count = 20})
    W.insert({name = "ttc-wooden-drill-head", count = 4})

    -- The main bore: four clay heads (20 hits each), two 40-hit tiles.
    B = S.create_entity({name = "ttc-mk1-bore", position = {29, 0}, direction = east, force = "player", raise_built = true})
    B.set_recipe("ttc-dig-floor_1-clay")
    B.insert({name = "wood", count = 30})
    B.insert({name = "ttc-clay-drill-head", count = 4})
    snap("start")
  elseif tick > 1 and tick % 300 == 0 and tick <= 9900 then
    feed_belts(B, 29)
    -- Keep the core drill's sand and clay from filling its output.
    if D.valid then
      local output = D.get_output_inventory()
      if output.get_item_count("ttc-sand") >= 60 or output.get_item_count("ttc-clay") >= 60 then
        output.clear()
      end
    end
    if tick == 900 then
      -- 15 s into a clay head's 40 s life at 2 s per hit, mid-craft.
      local label = B.custom_status and B.custom_status.label
      check("hits accrue while the head wears", label and tonumber(label[2]) >= 6 and tonumber(label[2]) <= 8 and label[3] == "40",
        serpent.line(label))
    end
    if tick == 5100 then
      -- The shaft has broken through: drop items and water down to floor 1.
      local nauvis = game.surfaces.nauvis
      chute = nauvis.create_entity({name = "ttc-item-chute", position = {105.5, 100.5}, force = "player", raise_built = true})
      chute.insert({name = "wood", count = 20})
      pipe = nauvis.create_entity({name = "ttc-downpipe", position = {105.5, 102.5}, force = "player", raise_built = true})
      pipe.set_fluid(1, {name = "water", amount = 300})
      stray = nauvis.create_entity({name = "ttc-item-chute", position = {150.5, 150.5}, force = "player", raise_built = true})
    elseif tick == 5400 then
      local outlet = S.find_entity("ttc-item-chute-outlet", {105.5, 100.5})
      check("item chute outlet appears on the floor below", outlet ~= nil)
      check("item chute drops items down",
        outlet and outlet.get_inventory(defines.inventory.chest).get_item_count("wood") == 20 and chute.get_inventory(defines.inventory.chest).is_empty())
      local pipe_outlet = S.find_entity("ttc-downpipe-outlet", {105.5, 102.5})
      local fluid = pipe_outlet and pipe_outlet.get_fluid(1)
      check("downpipe drains water down", fluid and fluid.name == "water" and fluid.amount == 300 and pipe.get_fluid(1) == nil,
        serpent.line(fluid))
      check("chute over solid rock is refunded", not (stray and stray.valid)
        and game.surfaces.nauvis.count_entities_filtered({type = "item-entity", position = {150.5, 150.5}, radius = 2}) == 1)
      game.surfaces.nauvis.find_entities_filtered({type = "item-entity", position = {150.5, 150.5}, radius = 2})[1].destroy()
      pipe.destroy({raise_destroy = true})
      check("removing an inlet removes its outlet", not (pipe_outlet and pipe_outlet.valid))
    end
    if tick % 900 == 0 then
      snap("run")
    end
  elseif tick == 9901 then
    snap("end")
    check("bore dug 2 tiles with 4 clay heads", B.position.x == 31, B.position.x)
    check("2 belts laid per tile", #S.find_entities_filtered({name = "transport-belt", area = {{20, -3}, {40, 3}}}) == 4)
    check("4 wooden heads dig one tile", W.position.x == 7, W.position.x)
    check("without belts the tunnel is left bare", #S.find_entities_filtered({name = "transport-belt", area = {{0, -3}, {12, 3}}}) == 0)
    check("dug chunks marked generated", S.is_chunk_generated({1, 0}) and S.is_chunk_generated({1, -1}))
    S.request_to_generate_chunks({48, 16}, 1)
    S.force_generate_chunk_requests()
    check("tunnel survives generation", count_tiles({x = 30, y = -1}, {x = 31, y = 0}, "dirt-7") == 4)
    local walls = wall_tiles({{29, -3}, {37, 3}})
    L("tunnel walls", table.concat(walls, " "))
    local pieces = {}
    for _, wall in pairs(S.find_entities_filtered({name = tunnel.wall_names, area = {{29, -3}, {37, 3}}})) do
      pieces[wall.name] = (pieces[wall.name] or 0) + 1
    end
    L("wall pieces", pieces)
    check("tunnel has cliff faces on both sides and ahead",
      pieces["ttc-tunnel-wall-s"] and pieces["ttc-tunnel-wall-n"] and pieces["ttc-tunnel-wall-w"])
    -- 2 per dug column, 4 ahead, plus 2 of the platform's own corner walls.
    check("tunnel walled on both sides and ahead", #walls == 10, #walls)
    check("no spilled items", #S.find_entities_filtered({type = "item-entity", area = {{-10, -10}, {40, 10}}}) == 0)

    local nauvis = game.surfaces.nauvis
    check("core drill left the starting surface", not D.valid)
    check("shaft top left on starting surface", nauvis.find_entity("ttc-shaft-top-ns", drill_position) ~= nil)
    check("nothing spilled beside the pit", #nauvis.find_entities_filtered({type = "item-entity", position = drill_position, radius = 8}) == 0)
    M = S.find_entity("ttc-core-drill", drill_position)
    check("core drill moved down to layer 1", M ~= nil)
    check("shaft bottom on layer 1", S.find_entity("ttc-shaft-bottom-ns", drill_position) ~= nil)
    check("nothing spilled on the landing", #S.find_entities_filtered({type = "item-entity", position = drill_position, radius = 8}) == 0)
    check("clay heads pay out their life's drops",
      game.forces.player.get_item_production_statistics(S).get_input_count("ttc-clay") >= 20)
    check("no iron on floor 1", game.forces.player.get_item_production_statistics(S).get_input_count("iron-ore") == 0)
    check("pipes need glass", (function()
      for _, ingredient in ipairs(prototypes.recipe["pipe"].ingredients) do
        if ingredient.name == "ttc-glass" then return true end
      end
    end)())
    local bore_recipe = prototypes.recipe["ttc-mk1-bore"]
    local needs_iron = false
    for _, ingredient in ipairs(bore_recipe.ingredients) do
      needs_iron = needs_iron or ingredient.name:find("iron") ~= nil
    end
    check("tunnel bore is craftable without iron", not needs_iron)
    if remote.interfaces["freeplay"] then
      local ship = remote.call("freeplay", "get_ship_items")
      check("core drill waits in the crashed ship", ship["ttc-core-drill"] == 1, serpent.line(ship))
      check("blades are scattered in the wreckage", (remote.call("freeplay", "get_debris_items")["ttc-blade"] or 0) > 0)
    else
      L("no freeplay interface in the test map")
    end
    if M then
      local output = M.get_output_inventory()
      check("moved drill keeps the shaft's sand and clay inside",
        output.get_item_count("ttc-sand") > 0 and output.get_item_count("ttc-clay") > 0, serpent.line(output.get_contents()))
      check("moved drill waits for leftovers to be taken out",
        M.custom_status and M.custom_status.label[1] == "ttc-status.shaft-leftovers")
      local input = M.get_inventory(defines.inventory.crafter_input)
      -- 23 heads went in, 20 were used: the rest come back exactly once.
      check("moved drill keeps unused and in-progress inputs (no duplicates)",
        input.get_item_count("ttc-wooden-drill-head") == 3, serpent.line(input.get_contents()))
      input.clear()
      check("fuel moved with the drill", M.get_fuel_inventory().get_item_count("wood") > 0 or M.burner.currently_burning ~= nil)
      M.get_output_inventory().clear()
    end
    check("reaching floor 1 unlocks the bore", game.forces.player.technologies["ttc-reach-floor-1"].researched
      and game.forces.player.recipes["ttc-mk1-bore"].enabled)
    -- Landing platform: 7x7 shaft plus a 2-tile margin, nothing more.
    local reach = 5.5
    local open = count_tiles({x = drill_position.x - reach, y = drill_position.y - reach}, {x = drill_position.x + reach - 1, y = drill_position.y + reach - 1}, "dirt-7")
    check("landing platform is 11x11", open == 121, open)
    check("nothing open beyond the landing", S.get_tile(drill_position.x + 6, drill_position.y).name == "out-of-map")

    local shaft_2 = prototypes.recipe["ttc-shaft-floor_2"]
    check("shaft to floor 2 takes clay heads for 45-50 stone",
      shaft_2.ingredients[1].name == "ttc-clay-drill-head" and shaft_2.products[1].name == "stone"
        and shaft_2.products[1].amount_min == 45 and shaft_2.products[1].amount_max == 50)
    nauvis.request_to_generate_chunks({0, 0}, 4)
    nauvis.force_generate_chunk_requests()
    check("no ore on the starting surface", nauvis.count_entities_filtered({type = "resource"}) == 0,
      nauvis.count_entities_filtered({type = "resource"}))

    -- Stairs: shaft 1 has them along the north and south rims.
    local d = defines.direction
    local function travel(surface, dx, dy, direction)
      return remote.call("to-the-core", "travel_target", surface.index,
        {x = drill_position.x + dx, y = drill_position.y + dy}, direction)
    end
    local function lands(result, surface, dx, dy)
      return result ~= nil and result.surface_index == surface.index
        and result.position.x == drill_position.x + dx and result.position.y == drill_position.y + dy
    end
    check("north stairs down: east end walking east", lands(travel(nauvis, 2, -3, d.east), S, 3, -3),
      serpent.line(travel(nauvis, 2, -3, d.east)))
    check("south stairs down: west end walking west", lands(travel(nauvis, -2, 3, d.west), S, -3, 3))
    check("no descent walking up the stairs", travel(nauvis, 2, -3, d.west) == nil)
    check("no descent mid-stairs", travel(nauvis, 0, -3, d.east) == nil)
    check("north stairs up: west end walking west", lands(travel(S, -2, -3, d.west), nauvis, -3, -3))
    check("south stairs up: east end walking east", lands(travel(S, 2, 3, d.northeast), nauvis, 3, 3))
    check("no ascent walking down the stairs", travel(S, -2, -3, d.east) == nil)
  elseif tick == 9940 then
    L("drill after emptying: input", M.get_inventory(defines.inventory.crafter_input).get_contents(),
      "output", M.get_output_inventory().get_contents(), "status", M.custom_status and M.custom_status.label)
    check("emptied drill switches to the next shaft", M.get_recipe() and M.get_recipe().name == "ttc-shaft-floor_2",
      M.get_recipe() and M.get_recipe().name)
  end
end)
