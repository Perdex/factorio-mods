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

local S, B, D, M, W, C, chute, pipe, stray, combinator, reinforced, obstacle, V, vein_tile
local hole, stray_hole, lift, lift_pump, hot_mk2, hot_mk3, oil_tile, oil_bore, beside, grinder, winnower, T, pulses
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
  -- Keep the first Mk3 cooled while it digs; from tick 589 on its use is
  -- measured.
  if C and C.valid and tick > 300 and tick < 590 then
    C.set_fluid(1, {name = "ttc-coolant", amount = 200})
  end
  if T and T.valid and T.get_signal({type = "virtual", name = "signal-check"},
    defines.wire_connector_id.circuit_red) > 0 then
    pulses = pulses + 1
  end
  if tick == 1 then
    -- Veins are tested on their own; the rest of the test digs plain rock.
    remote.call("to-the-core", "set_veins", false)
    S = game.create_surface("ttc-floor-1", {width = 1, height = 1})

    -- Item 0: a platform at the origin must survive later chunk generation.
    tunnel.open_area(S, {x = -6, y = -5}, {x = 6, y = 5}, "stone-path")
    S.request_to_generate_chunks({0, 0}, 3)
    S.force_generate_chunk_requests()
    check("origin platform survives generation",
      count_tiles({x = -6, y = -5}, {x = 6, y = 5}, "stone-path") == 143)
    -- 13x11 platform: cliffs on the 2*13 + 2*11 rock tiles along its sides.
    check("origin platform walled", #wall_tiles({{-8, -7}, {8, 7}}) == 48)

    -- Bore platform near a chunk border, digging east into ungenerated chunks.
    tunnel.open_area(S, {x = 18, y = -5}, {x = 29, y = 5}, "stone-path")
    local function can(position, direction)
      return S.can_place_entity({name = "ttc-mk1-bore", position = position, direction = direction, force = "player"})
    end
    check("bore placeable at edge facing rock", can({29, 0}, east))
    check("bore placeable mid-platform", can({24, 0}, east))
    check("bore placeable facing open ground", can({19, 0}, east))
    check("bore not placeable over void", not can({31, 0}, east))

    -- Core drill on the starting surface: the 200-hit shaft takes 20 wooden
    -- heads (150 s at 3 s per hit and crafting speed 4); 3 spare ones go down
    -- with it.
    D = game.surfaces.nauvis.create_entity({name = "ttc-core-drill", position = drill_position, force = "player", raise_built = true})
    D.insert({name = "ttc-wooden-drill-head", count = 23})
    D.insert({name = "coal", count = 20})
    -- Whatever is built where the pit and its stairs open up gets destroyed.
    obstacle = game.surfaces.nauvis.create_entity({name = "wooden-chest", position = {drill_position.x - 3, drill_position.y}, force = "player"})

    local unfired = prototypes.recipe["ttc-dig-unfired_clay"]
    check("an unfired clay head digs once, at one hit a second", unfired and game.forces.player.recipes["ttc-dig-unfired_clay"].enabled
      and unfired.ingredients[1].name == "ttc-unfired-clay-drill-head" and unfired.energy == 1
      and prototypes.recipe["ttc-shaft-unfired_clay"] ~= nil, unfired and unfired.energy)
    check("a bore takes any drill head from the start", game.forces.player.recipes["ttc-dig-clay"].enabled
      and game.forces.player.recipes["ttc-dig-reinforced"].enabled)
    check("iron drill heads are not craftable before iron is found",
      not game.forces.player.recipes["ttc-iron-drill-head"].enabled)

    -- A second bore on the origin platform, never given belts: wooden heads
    -- last 10 hits, so a 40-hit clay tile takes four of them.
    W = S.create_entity({name = "ttc-mk1-bore", position = {6, 0}, direction = east, force = "player", raise_built = true})
    W.insert({name = "wood", count = 20})
    W.insert({name = "ttc-wooden-drill-head", count = 4})

    -- A Mk3 on the origin platform's west edge, with heads and fuel but no
    -- water yet.
    -- 3 wide: centred on a tile across its digging direction.
    C = S.create_entity({name = "ttc-mk3-bore", position = {-5, 0.5}, direction = defines.direction.west, force = "player", raise_built = true})
    C.insert({name = "ttc-iron-drill-head", count = 2})
    C.insert({name = "coal", count = 10})

    -- The main bore: four clay heads (20 hits each), two 40-hit tiles.
    -- Getting rid of rock: a grinder on stone, a winnower on dust, and a
    -- winnower wrongly built underground.
    local nauvis = game.surfaces.nauvis
    for _, entity in pairs(nauvis.find_entities_filtered({area = {{-90, -70}, {-70, -50}}})) do
      if entity.type ~= "character" then
        entity.destroy()
      end
    end
    grinder = nauvis.create_entity({name = "ttc-grinder", position = {-80, -60}, force = "player", raise_built = true})
    grinder.insert({name = "stone", count = 20})
    grinder.insert({name = "coal", count = 5})
    winnower = nauvis.create_entity({name = "ttc-winnower", position = {-75.5, -60.5}, force = "player", raise_built = true})
    winnower.insert({name = "ttc-dust", count = 10})

    -- Ten furnaces smelting 10 iron ore each: 100 plates unlock automation.
    for i = 1, 10 do
      local furnace = game.surfaces.nauvis.create_entity({name = "stone-furnace", position = {-40 + i * 3, -40}, force = "player"})
      furnace.insert({name = "iron-ore", count = 10})
      furnace.insert({name = "coal", count = 5})
    end

    B = S.create_entity({name = "ttc-mk2-bore", position = {29, 0}, direction = east, force = "player", raise_built = true})
    B.insert({name = "wood", count = 30})
    B.insert({name = "ttc-clay-drill-head", count = 4})
    -- Wired to a combinator behind it: the wire should follow along the belts.
    combinator = S.create_entity({name = "constant-combinator", position = {26.5, -2.5}, force = "player"})
    combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true)
      .connect_to(B.get_wire_connector(defines.wire_connector_id.circuit_green, true))
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
    if tick == 300 then
      check("Mk3 waits for coolant", C.custom_status and C.custom_status.label[1] == "ttc-status.needs-coolant",
        C.custom_status and serpent.line(C.custom_status.label))
      C.set_fluid(1, {name = "ttc-coolant", amount = 200})
      -- Pipes on its supply lane: it lays one behind its inlet per tile.
      for _, loader in pairs(S.find_entities_filtered({name = "loader-1x1", area = {{-4.5, -1.5}, {-2.5, 2.5}}})) do
        if loader.loader_type == "input" then
          for i = 1, 2 do
            loader.get_transport_line(i).insert_at_back({name = "pipe", count = 1})
          end
        end
      end
    end
    if tick == 600 then
      -- One or two bore updates (every 10 ticks) since the last top-up, at
      -- 100 a second: 16.7 each.
      local coolant = C.get_fluid(1)
      check("Mk3 digs using 100 coolant a second", C.custom_status and C.custom_status.label[1] == "ttc-status.digging"
        and coolant and coolant.amount > 200 - 33.4 and coolant.amount < 200 - 16.6, coolant and coolant.amount)
      check("Mk3 lays a pipe behind its inlet as it advances",
        #S.find_entities_filtered({name = "pipe", area = {{-6, 0}, {0, 1}}}) >= 1,
        #S.find_entities_filtered({name = "pipe", area = {{-6, 0}, {0, 1}}}))
      local connected = false
      for _, neighbour in pairs(C.fluidbox_neighbours[1] or {}) do
        connected = connected or neighbour.name == "pipe"
      end
      check("the laid pipe feeds the Mk3's inlet", connected)
      local function unlocked_by(technology)
        local recipes = {}
        for _, effect in ipairs(prototypes.technology[technology].effects) do
          recipes[effect.recipe or ""] = true
        end
        return recipes
      end
      local function inputs(name)
        local recipe = prototypes.recipe[name]
        local found = {}
        for _, ingredient in ipairs(recipe.ingredients) do
          found[ingredient.name] = ingredient.amount
        end
        return found, recipe.categories[1] == "chemistry" and recipe.products[1].name == "ttc-coolant"
          and recipe.products[1].amount == 100
      end
      local oil = unlocked_by("oil-processing")
      check("the Mk3 and petroleum coolant come with oil processing", oil["ttc-mk3-bore"]
        and oil["ttc-coolant-from-petroleum"] and unlocked_by("lubricant")["ttc-coolant-from-lubricant"]
        and prototypes.technology["ttc-mk3-bore"] == nil)
      local petroleum, petroleum_ok = inputs("ttc-coolant-from-petroleum")
      local lubricant, lubricant_ok = inputs("ttc-coolant-from-lubricant")
      check("coolant is water with a little petroleum gas or lubricant, and dust", petroleum_ok and lubricant_ok
        and petroleum.water == 100 and petroleum["petroleum-gas"] == 20 and petroleum["ttc-dust"] == 2
        and lubricant.water == 100 and lubricant.lubricant == 4 and lubricant["ttc-dust"] == 2,
        serpent.line({petroleum, lubricant}))
      local reinforced_trigger = prototypes.technology["ttc-reinforced-drill-head"].research_trigger
      check("reinforced heads unlock after a few steel plates",
        reinforced_trigger.type == "craft-item" and reinforced_trigger.item.name == "steel-plate"
        and reinforced_trigger.count == 10, serpent.line(reinforced_trigger))
    end
    if tick == 300 then
      check("inserting a drill head picks the bore's dig recipe", B.get_recipe() and B.get_recipe().name == "ttc-dig-clay",
        B.get_recipe() and B.get_recipe().name)
    end
    if tick == 300 then
      -- Clay heads hit once a second and the Mk2 runs at speed 2: 5 s in,
      -- about 10 hits, as the first head wears out.
      local label = B.custom_status and B.custom_status.label
      check("hits accrue while the head wears", label and tonumber(label[2]) >= 8 and tonumber(label[2]) <= 11 and label[3] == "40",
        serpent.line(label))
    end
    if tick == 9300 then
      -- The shaft has broken through: a belt and water down to floor 1.
      local nauvis = game.surfaces.nauvis
      chute = nauvis.create_entity({name = "ttc-underground-belt-down", position = {100.5, 96.5},
        direction = defines.direction.east, force = "player", raise_built = true})
      chute.get_transport_line(1).insert_at_back({name = "wood", count = 1})
      chute.get_transport_line(2).insert_at_back({name = "stone", count = 1})
      pipe = nauvis.create_entity({name = "ttc-pipe-down", position = {102.5, 96.5}, force = "player", raise_built = true})
      pipe.set_fluid(1, {name = "water", amount = 300})
      stray = nauvis.create_entity({name = "ttc-underground-belt-down", position = {150.5, 150.5}, force = "player",
        raise_built = true})
      nauvis.create_entity({name = "ttc-power-connector", position = {98.5, 96.5}, force = "player", raise_built = true})
      nauvis.find_entity("ttc-power-connector-sink", {98.5, 96.5}).energy = 1000000
    elseif tick == 9900 then
      local outlet = S.find_entity("ttc-underground-belt-down-outlet", {100.5, 96.5})
      check("turning one belt end turns both", outlet and outlet.direction == chute.direction
        and chute.linked_belt_neighbour == outlet and chute.linked_belt_type == "input",
        outlet and {chute.direction, outlet.direction, chute.linked_belt_type})
    elseif tick == 9600 then
      local outlet = S.find_entity("ttc-underground-belt-down-outlet", {100.5, 96.5})
      check("a belt going down gets its outlet on the floor below", outlet ~= nil
        and outlet.direction == defines.direction.east and outlet.linked_belt_type == "output")
      local lines = outlet and {outlet.get_transport_line(1), outlet.get_transport_line(2)}
      check("items go down on their own lane", lines and lines[1].get_item_count("wood") == 1
        and lines[1].get_item_count("stone") == 0 and lines[2].get_item_count("stone") == 1,
        lines and {lines[1].get_contents(), lines[2].get_contents()})
      chute.rotate()
      local pipe_outlet = S.find_entity("ttc-pipe-down-outlet", {102.5, 96.5})
      local fluid = pipe_outlet and pipe_outlet.get_fluid(1)
      check("a pipe going down drains water", fluid and fluid.name == "water" and fluid.amount == 300 and pipe.get_fluid(1) == nil,
        serpent.line(fluid))
      check("a belt end over solid rock is refunded", not (stray and stray.valid)
        and game.surfaces.nauvis.count_entities_filtered({type = "item-entity", position = {150.5, 150.5}, radius = 2}) == 1)
      game.surfaces.nauvis.find_entities_filtered({type = "item-entity", position = {150.5, 150.5}, radius = 2})[1].destroy()
      pipe.destroy({raise_destroy = true})
      check("removing an inlet removes its outlet", not (pipe_outlet and pipe_outlet.valid))
      local sink = game.surfaces.nauvis.find_entity("ttc-power-connector-sink", {98.5, 96.5})
      local source = S.find_entity("ttc-power-connector-source", {98.5, 96.5})
      check("power connector carries energy down", S.find_entity("ttc-power-connector-outlet", {98.5, 96.5}) ~= nil
        and source and source.energy > 0 and sink.energy < 1000000, source and source.energy)
    end
    if tick % 900 == 0 then
      snap("run")
    end
  elseif tick == 9901 then
    snap("end")
    check("bore dug 2 tiles with 4 clay heads", B.position.x == 31, B.position.x)
    check("2 belts laid per tile", #S.find_entities_filtered({name = "transport-belt", area = {{20, -3}, {40, 3}}}) == 4)
    check("4 wooden heads dig one tile", W.position.x == 7, W.position.x)
    local green = defines.wire_connector_id.circuit_green
    local bore_wire = B.get_wire_connector(green, false)
    local newest_belt = S.find_entity("transport-belt", {28.5, -0.5})
    local combinator_wire = combinator.get_wire_connector(green, false)
    check("bore stays wired through its newest supply belt",
      bore_wire and newest_belt and bore_wire.is_connected_to(newest_belt.get_wire_connector(green, false))
        and not bore_wire.is_connected_to(combinator_wire)
        and bore_wire.network_id == combinator_wire.network_id and bore_wire.network_id > 0,
      bore_wire and bore_wire.connection_count)
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
    local face = S.find_entities_filtered({name = "ttc-tunnel-wall-s", area = {{29, -3}, {37, 3}}})
    local variations = {}
    for _, wall in pairs(face) do
      variations[#variations + 1] = wall.graphics_variation
    end
    table.sort(variations)
    check("neighbouring cliff faces continue one cliff run", #variations >= 2 and variations[2] == variations[1] + 1,
      serpent.line(variations))
    -- 2 per dug column, 2 ahead, plus 2 of the platform's own side walls.
    check("tunnel walled on both sides and ahead", #walls == 8, #walls)
    check("no spilled items", #S.find_entities_filtered({type = "item-entity", area = {{-10, -10}, {40, 10}}}) == 0)

    local nauvis = game.surfaces.nauvis
    check("core drill left the starting surface", not D.valid)
    check("shaft top left on starting surface", nauvis.find_entity("ttc-shaft-top-ns", drill_position) ~= nil)
    local spilled = 0
    for _, item in pairs(nauvis.find_entities_filtered({type = "item-entity", position = drill_position, radius = 8})) do
      if item.stack.name ~= "wooden-chest" then
        spilled = spilled + 1
      end
    end
    check("no shaft output spilled beside the pit", spilled == 0, spilled)
    M = S.find_entity("ttc-core-drill", drill_position)
    check("core drill moved down to layer 1", M ~= nil)
    check("shaft bottom on layer 1", S.find_entity("ttc-shaft-bottom-ns", drill_position) ~= nil)
    check("nothing spilled on the landing", #S.find_entities_filtered({type = "item-entity", position = drill_position, radius = 8}) == 0)
    check("clay heads pay out their life's drops",
      game.forces.player.get_item_production_statistics(S).get_input_count("ttc-clay") >= 20)
    check("no iron on floor 1", game.forces.player.get_item_production_statistics(S).get_input_count("iron-ore") == 0)
    check("the burner inserter needs no fuel", prototypes.entity["burner-inserter"].burner_prototype == nil
      and prototypes.entity["burner-inserter"].void_energy_source_prototype ~= nil)
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
      check("wooden drill heads wait in the crashed ship", ship["ttc-wooden-drill-head"] == 5)
      local debris = remote.call("freeplay", "get_debris_items")
      check("only coal (no iron) in the wreckage", debris.coal == 2 and table_size(debris) == 1, serpent.line(debris))
      check("blades are gone", prototypes.item["ttc-blade"] == nil)
    else
      L("no freeplay interface in the test map")
    end
    if M then
      local output = M.get_output_inventory()
      check("moved drill keeps the shaft's sand and clay and digs on",
        output.get_item_count("ttc-sand") > 0 and output.get_item_count("ttc-clay") > 0
          and output.get_item_count("stone") > 0, serpent.line(output.get_contents()))
      local input = M.get_inventory(defines.inventory.crafter_input)
      local spare = input.get_item_count("ttc-wooden-drill-head") + (M.is_crafting() and 1 or 0)
      check("moved drill brought its spare heads down", spare >= 1 and spare <= 13, spare)
      check("fuel moved with the drill", M.get_fuel_inventory().get_item_count("wood") > 0 or M.burner.currently_burning ~= nil)
      M.get_output_inventory().clear()
    end
    check("reaching floor 1 unlocks the bore", game.forces.player.technologies["ttc-reach-floor-1"].researched
      and game.forces.player.recipes["ttc-mk1-bore"].enabled)
    -- Landing: the drill's 5x5 plus, on the stair sides only, the 5-tile
    -- stair strips and two rows beyond them.
    local reach = 5.5
    local open = count_tiles({x = drill_position.x - reach, y = drill_position.y - reach}, {x = drill_position.x + reach - 1, y = drill_position.y + reach - 1}, "dirt-7")
    check("landing is the drill spot and the two stair sides", open == 25 + 2 * 5 * 3, open)
    check("the sides without stairs stay rock", S.get_tile(drill_position.x + 3, drill_position.y).name == "out-of-map"
      and S.get_tile(drill_position.x - 3, drill_position.y).name == "out-of-map")
    check("nothing open beyond the landing", S.get_tile(drill_position.x, drill_position.y + 6).name == "out-of-map"
      and S.get_tile(drill_position.x + 3, drill_position.y + 4).name == "out-of-map")
    local stair = {x = drill_position.x, y = drill_position.y - 3}
    check("nothing can be built on the stairs", not S.can_place_entity({name = "wooden-chest", position = stair, force = "player"})
      and not game.surfaces.nauvis.can_place_entity({name = "wooden-chest", position = stair, force = "player"}))
    check("players can still walk the stairs", S.can_place_entity({name = "character", position = stair}))

    check("the core drill takes any drill head", prototypes.recipe["ttc-shaft-wooden"] ~= nil
      and prototypes.recipe["ttc-shaft-reinforced"] ~= nil and prototypes.recipe["ttc-shaft-floor_2"] == nil)
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
    -- Both ways the player arrives halfway along the same stairs.
    check("north stairs down: east end walking east", lands(travel(nauvis, 2, -3, d.east), S, 0, -3),
      serpent.line(travel(nauvis, 2, -3, d.east)))
    check("south stairs down: west end walking west", lands(travel(nauvis, -2, 3, d.west), S, 0, 3))
    check("no descent walking up the stairs", travel(nauvis, 2, -3, d.west) == nil)
    check("descent from the middle of the stairs", lands(travel(nauvis, 0, -3, d.east), S, 0, -3))
    check("no descent on the upper half", travel(nauvis, -1, -3, d.east) == nil)
    check("north stairs up: west end walking west", lands(travel(S, -2, -3, d.west), nauvis, 0, -3))
    check("south stairs up: east end walking east", lands(travel(S, 2, 3, d.northeast), nauvis, 0, 3))
    check("no ascent walking down the stairs", travel(S, -2, -3, d.east) == nil)
  elseif tick == 9930 then
    -- Science is gone: red, green, military and blue technologies unlock by
    -- progression.
    local mapped_packs = {
      ["automation-science-pack"] = true,
      ["logistic-science-pack"] = true,
      ["military-science-pack"] = true,
      ["chemical-science-pack"] = true
    }
    local left = {}
    for name, technology in pairs(prototypes.technology) do
      if not technology.hidden and technology.research_unit_ingredients then
        local mapped = #technology.research_unit_ingredients > 0
        for _, ingredient in ipairs(technology.research_unit_ingredients) do
          mapped = mapped and mapped_packs[ingredient.name]
        end
        if mapped then
          left[#left + 1] = name
        end
      end
    end
    check("no red, green, military or blue science costs left", #left == 0, table.concat(left, " "))
    check("science pack technologies removed", prototypes.technology["logistic-science-pack"].hidden
      and prototypes.technology["automation-science-pack"].hidden)
    check("lab removed", prototypes.item["lab"].hidden and not game.forces.player.recipes["lab"].enabled)
    local function trigger(name)
      return prototypes.technology[name].research_trigger
    end
    check("50 smelted iron plates unlock automation", game.forces.player.technologies["automation"].researched
      and trigger("automation").count == 50)
    check("10 belts unlock logistics", trigger("logistics").type == "craft-item" and trigger("logistics").count == 10)
    check("military waits for floor 4", trigger("military").type == "scripted" and trigger("gun-turret").type == "scripted"
      and not game.forces.player.technologies["military"].researched)
    check("landfill waits for floor 9", serpent.line(trigger("landfill").trigger_description):find('"9"') ~= nil,
      serpent.line(trigger("landfill").trigger_description))
    check("uranium processing waits for the first uranium dug up", trigger("uranium-processing").type == "scripted"
      and trigger("uranium-processing").trigger_description[1] == "ttc-trigger.discover")
    check("no lab speed upgrades left", prototypes.technology["research-speed-5"].hidden
      and prototypes.technology["research-speed-6"].hidden)
    local wooden = prototypes.recipe["ttc-wooden-drill-head"].ingredients
    check("wooden drill heads are wood and stone", #wooden == 2)
    local function uses(recipe, item)
      for _, ingredient in ipairs(prototypes.recipe[recipe].ingredients) do
        if ingredient.name == item then
          return true
        end
      end
      return false
    end
    check("bricks are fired from clay", uses("stone-brick", "ttc-clay") and not uses("stone-brick", "stone")
      and prototypes.recipe["stone-brick"].ingredients[1].amount == 5)
    local steps = {"ttc-grind-stone", "ttc-grind-gravel", "ttc-grind-sand", "ttc-winnow-dust"}
    local chain = true
    for i, name in ipairs(steps) do
      local recipe = prototypes.recipe[name]
      chain = chain and recipe.ingredients[1].amount == 3 and recipe.energy == 3 ^ (i - 1)
        and (#recipe.products == 0 or recipe.products[1].amount == 2)
    end
    check("grinding turns 3 into 2, each step three times slower", chain)
    check("grinders wait for floor 2", not game.forces.player.recipes["ttc-grinder"].enabled)
    check("a grinder grinds stone to gravel", grinder.get_output_inventory().get_item_count("ttc-gravel") > 0,
      serpent.line(grinder.get_output_inventory().get_contents()))
    check("a winnower lets dust blow away on the surface",
      winnower.get_inventory(defines.inventory.crafter_input).get_item_count("ttc-dust") + (winnower.is_crafting() and 3 or 0) < 10)
    local underground = S.create_entity({name = "ttc-winnower", position = {0, 0}, force = "player", raise_built = true})
    check("a winnower underground is taken back", not (underground and underground.valid))
    check("bricks are called clay bricks", prototypes.item["stone-brick"].localised_name[1] == "item-name.stone-brick")
    check("bore Mk1 is bricks and glass, no iron", uses("ttc-mk1-bore", "stone-brick") and uses("ttc-mk1-bore", "ttc-glass")
      and not uses("ttc-mk1-bore", "iron-plate"))
    check("bore Mk2 takes plenty of iron", uses("ttc-mk2-bore", "iron-plate"))
    check("core drill needs steel and circuits", uses("ttc-core-drill", "steel-plate") and uses("ttc-core-drill", "electronic-circuit"))
    check("lamps need glass, boilers and steam engines bricks", uses("small-lamp", "ttc-glass")
      and uses("boiler", "stone-brick") and uses("steam-engine", "stone-brick"))
    check("electric mining drill removed", prototypes.item["electric-mining-drill"].hidden
      and prototypes.technology["electric-mining-drill"].hidden)
    local function amounts(list)
      local found = {}
      for _, entry in ipairs(list) do
        found[entry.name] = entry.amount
      end
      return found
    end
    local function unlocks(technology, recipe)
      for _, effect in ipairs(prototypes.technology[technology].effects) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe then
          return true
        end
      end
      return false
    end
    local down = amounts(prototypes.recipe["underground-belt"].products)
    local up = amounts(prototypes.recipe["ttc-underground-belt-up"].products)
    check("underground belts come as a down and an up end", prototypes.item["underground-belt"].hidden
      and down["ttc-underground-belt-down"] == 1 and table_size(down) == 1
      and up["ttc-underground-belt-up"] == 1 and table_size(up) == 1, serpent.line({down, up}))
    check("up ends unlock on floor 3", unlocks("ttc-reach-floor-3", "ttc-underground-belt-up")
      and unlocks("ttc-reach-floor-3", "ttc-pipe-up") and not unlocks("logistics", "ttc-underground-belt-up")
      and unlocks("logistics-2", "ttc-fast-underground-belt-up"))
    local fast_down = amounts(prototypes.recipe["fast-underground-belt"].ingredients)
    local fast_up = amounts(prototypes.recipe["ttc-fast-underground-belt-up"].ingredients)
    check("faster ends are made from the ends below them", fast_down["ttc-underground-belt-down"] == 1
      and fast_up["ttc-underground-belt-up"] == 1 and not fast_down["ttc-underground-belt-up"],
      serpent.line({fast_down, fast_up}))
    check("the manhole comes halfway down to floor 4", prototypes.technology["ttc-manhole"].research_trigger.type == "scripted"
      and not game.forces.player.recipes["ttc-manhole"].enabled)
    check("bore Mk1 has no loaders", #S.find_entities_filtered({name = "loader-1x1", area = {{0, -3}, {12, 3}}}) == 0)
    check("buildings in the pit's way are dropped on the ground", not obstacle.valid
      and #game.surfaces.nauvis.find_entities_filtered({type = "item-entity", position = drill_position, radius = 8}) > 0)
  elseif tick == 9940 then
    M.insert({name = "coal", count = 50})
  elseif tick == 10001 then
    -- Manholes: one over dug-out ground on floor 1, one over rock.
    tunnel.open_area(S, {x = 70, y = 44}, {x = 71, y = 45}, "stone-path")
    hole = game.surfaces.nauvis.create_entity({name = "ttc-manhole", position = {71, 45}, force = "player",
      raise_built = true})
    stray_hole = game.surfaces.nauvis.create_entity({name = "ttc-manhole", position = {81, 45}, force = "player",
      raise_built = true})
    -- A bore in a 2-tall corridor, told to turn clockwise: it crosses one
    -- open tile, turns south and starts on the rock there.
    tunnel.open_area(S, {x = 60, y = 44}, {x = 65, y = 45}, "stone-path")
    T = S.create_entity({name = "ttc-mk1-bore", position = {61, 45}, direction = east,
      force = "player", raise_built = true})
    T.insert({name = "ttc-clay-drill-head", count = 5})
    T.insert({name = "coal", count = 10})
    local turner = S.create_entity({name = "constant-combinator", position = {58.5, 44.5}, force = "player"})
    turner.get_control_behavior().add_section().set_slot(1,
      {value = {type = "virtual", name = "signal-clockwise-circle-arrow", quality = "normal"}, min = 1})
    turner.get_wire_connector(defines.wire_connector_id.circuit_red, true)
      .connect_to(T.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
    remote.call("to-the-core", "set_bore_signals", T.unit_number, {read_hits = true, read_moved = true})
    pulses = 0
    -- Find a stone vein out east and set a bore up facing it, with plain
    -- rock beside the vein on the other half of the face.
    remote.call("to-the-core", "set_veins", true)
    for x = 200, 400 do
      for y = -40, 40 do
        if not vein_tile and remote.call("to-the-core", "vein_at", S.index, {x = x, y = y}) == "stone"
          and not remote.call("to-the-core", "vein_at", S.index, {x = x - 2, y = y})
          and not remote.call("to-the-core", "vein_at", S.index, {x = x - 1, y = y})
          and not remote.call("to-the-core", "vein_at", S.index, {x = x, y = y + 1}) then
          vein_tile = {x = x, y = y}
        end
      end
    end
    check("floor 1 has stone veins", vein_tile ~= nil)
    local clay = nil
    for x = 200, 400, 2 do
      for y = -40, 40, 2 do
        clay = clay or remote.call("to-the-core", "vein_at", S.index, {x = x, y = y}) == "ttc-clay" and {x, y} or nil
      end
    end
    check("floor 1 has clay veins", clay ~= nil and prototypes.entity["ttc-vein-ttc-clay"] ~= nil)
    if vein_tile then
      local body = {}
      for dx = -2, -1 do
        for dy = 0, 1 do
          body[#body + 1] = {x = vein_tile.x + dx, y = vein_tile.y + dy}
        end
      end
      tunnel.open(S, body, "dirt-7")
      V = S.create_entity({name = "ttc-mk1-bore", position = {vein_tile.x - 1, vein_tile.y + 1}, direction = east,
        force = "player", raise_built = true})
      -- Iron heads: 3 hits a second, so the plain rock (40 hits) breaks
      -- within 15 s while the vein (800) holds.
      V.insert({name = "ttc-iron-drill-head", count = 5})
      V.insert({name = "coal", count = 10})
      check("exposed vein rock shows its ore", S.find_entity("ttc-vein-stone", {vein_tile.x + 0.5, vein_tile.y + 0.5}) ~= nil)
    end
  elseif tick == 9701 then
    -- A bore on the landing past the stairs, facing the short wall: the rock
    -- ahead is still under the landing's 7x7 art, which mustn't block.
    beside = S.create_entity({name = "ttc-mk1-bore", position = {drill_position.x + 1.5, drill_position.y + 4.5},
      direction = east, force = "player", raise_built = true})
    check("bore fits on the landing beside the drill", beside ~= nil)
    if beside then
      beside.insert({name = "ttc-clay-drill-head", count = 2})
      beside.insert({name = "coal", count = 5})
    end
  elseif tick == 10101 then
    check("bore facing the landing's short wall digs", beside and beside.custom_status
      and beside.custom_status.label[1] ~= "ttc-status.front-blocked", beside and beside.custom_status and serpent.line(beside.custom_status.label))
    -- A belt and a pipe coming up from floor 1 to the surface.
    local nauvis = game.surfaces.nauvis
    for _, entity in pairs(nauvis.find_entities_filtered({position = {99.5, 104.5}, radius = 1.5})) do
      if entity.type ~= "character" then
        entity.destroy()
      end
    end
    lift = nauvis.create_entity({name = "ttc-underground-belt-up", position = {99.5, 104.5},
      direction = defines.direction.east, force = "player", raise_built = true})
    local inlet = S.find_entity("ttc-underground-belt-up-inlet", {99.5, 104.5})
    if inlet then
      inlet.get_transport_line(2).insert_at_back({name = "stone", count = 1})
    end
    lift_pump = nauvis.create_entity({name = "ttc-pipe-up", position = {100.5, 104.5}, force = "player", raise_built = true})
    local pump_inlet = S.find_entity("ttc-pipe-up-inlet", {100.5, 104.5})
    if pump_inlet then
      pump_inlet.set_fluid(1, {name = "water", amount = 100})
    end
    -- Floor 5 is too hot for bores without coolant.
    local hot = game.create_surface("ttc-floor-5", {width = 1, height = 1})
    tunnel.open_area(hot, {x = -6, y = -3}, {x = 6, y = 3}, "red-desert-0")
    hot_mk2 = hot.create_entity({name = "ttc-mk2-bore", position = {6, -1}, direction = east, force = "player", raise_built = true})
    hot_mk2.insert({name = "ttc-carbide-drill-head", count = 1})
    hot_mk2.insert({name = "coal", count = 10})
    hot_mk3 = hot.create_entity({name = "ttc-mk3-bore", position = {-5, -0.5}, direction = defines.direction.west, force = "player", raise_built = true})
    hot_mk3.insert({name = "ttc-carbide-drill-head", count = 1})
    hot_mk3.insert({name = "coal", count = 10})
    hot_mk3.set_fluid(1, {name = "ttc-coolant", amount = 200})
    -- Floor 4: break into an oil pocket.
    local deep = game.create_surface("ttc-floor-4", {width = 1, height = 1})
    for x = -200, 200 do
      for y = -60, 60 do
        if not oil_tile and remote.call("to-the-core", "vein_at", deep.index, {x = x, y = y}) == "crude-oil"
          and not remote.call("to-the-core", "vein_at", deep.index, {x = x - 2, y = y})
          and not remote.call("to-the-core", "vein_at", deep.index, {x = x - 1, y = y})
          and not remote.call("to-the-core", "vein_at", deep.index, {x = x - 2, y = y + 1})
          and not remote.call("to-the-core", "vein_at", deep.index, {x = x - 1, y = y + 1}) then
          oil_tile = {x = x, y = y}
        end
      end
    end
    check("floor 4 has oil pockets", oil_tile ~= nil)
    if oil_tile then
      local body = {}
      for dx = -2, -1 do
        for dy = -1, 1 do
          body[#body + 1] = {x = oil_tile.x + dx, y = oil_tile.y + dy}
        end
      end
      tunnel.open(deep, body, "dry-dirt")
      oil_bore = deep.create_entity({name = "ttc-mk3-bore", position = {oil_tile.x - 1, oil_tile.y + 0.5}, direction = east,
        force = "player", raise_built = true})
      oil_bore.insert({name = "ttc-carbide-drill-head", count = 2})
      oil_bore.insert({name = "coal", count = 50})
      oil_bore.set_fluid(1, {name = "ttc-coolant", amount = 200})
    end
  elseif tick > 10101 and tick < 11000 and tick % 10 == 0 then
    -- Keep the Mk3s cooled: with carbide heads they use ~400 coolant a second.
    for _, cooled in ipairs({oil_bore, hot_mk3}) do
      if cooled and cooled.valid then
        cooled.set_fluid(1, {name = "ttc-coolant", amount = 200})
        cooled.get_output_inventory().clear()
      end
    end
    -- The vein bore's stone, once its drops have been checked.
    if V and V.valid and tick > 10301 then
      V.get_output_inventory().clear()
    end
  elseif tick == 11001 then
    check("a manhole goes over dug-out ground", hole and hole.valid)
    -- Spilled next to the spot, or a little further if something stands there.
    local refunded = 0
    for _, item in pairs(game.surfaces.nauvis.find_entities_filtered({type = "item-entity", position = {81, 45}, radius = 6})) do
      if item.stack.name == "ttc-manhole" then
        refunded = refunded + item.stack.count
      end
    end
    check("a manhole over rock is refunded", not (stray_hole and stray_hole.valid) and refunded == 1, refunded)
    check("a turn signal turns the bore as it moves", T and T.direction == defines.direction.south
      and T.position.x == 62, T and {T.direction, T.position})
    local remaining = T and T.get_signal({type = "virtual", name = "signal-H"}, defines.wire_connector_id.circuit_red)
    -- 40 hits a tile on floor 1, 20 times that if the map put a vein there.
    check("the bore outputs the hits remaining", remaining and remaining > 0 and remaining <= 800, remaining)
    check("the bore pulses for one tick when it moves", pulses == 1, pulses)
    local plain = vein_tile and {x = vein_tile.x, y = vein_tile.y + 1}
    check("plain rock beside a vein breaks first", plain and not tunnel.is_void(S, plain)
      and tunnel.is_void(S, vein_tile), V and V.custom_status and V.custom_status.label)
    local label = V and V.custom_status and V.custom_status.label
    check("the bore keeps at the vein", V and V.position.x == vein_tile.x - 1
      and label and label[1] == "ttc-status.digging-vein" and tonumber(label[2]) > 40 and label[3] == "800",
      serpent.line(label))
    check("a belt from below brings items up on their lane", lift and lift.valid
      and lift.get_transport_line(2).get_item_count("stone") == 1 and lift.get_transport_line(1).get_item_count() == 0,
      lift and lift.valid and lift.get_transport_line(2).get_contents())
    local water = lift_pump and lift_pump.valid and lift_pump.get_fluid(1)
    check("a pipe from below brings fluid up", water and water.name == "water" and water.amount == 100, water)
    check("bores without coolant are too hot on floor 5", hot_mk2.custom_status
      and hot_mk2.custom_status.label[1] == "ttc-status.too-hot")
    check("a Mk3 digs on floor 5", hot_mk3.crafting_progress > 0, hot_mk3.crafting_progress)
    local oil = oil_tile and game.surfaces["ttc-floor-4"].find_entities_filtered({name = "crude-oil",
      area = {{oil_tile.x - 1, oil_tile.y - 1}, {oil_tile.x + 3, oil_tile.y + 3}}})
    check("breaking into an oil pocket leaves crude oil", oil and #oil == 1, oil and #oil)
  elseif tick == 10301 then
    local label = V and V.custom_status and V.custom_status.label
    check("a vein takes 20 times the hits", label and label[1] == "ttc-status.digging-vein" and label[3] == "800",
      serpent.line(label))
    local output = V and V.get_output_inventory()
    check("a vein yields its own drops", output and output.get_item_count("stone") > 0 and output.get_item_count("ttc-clay") == 0,
      output and serpent.line(output.get_contents()))
  elseif tick > 9940 and tick < 21000 and tick % 60 == 0 then
    -- Each hit brings up a stone or two: keep the output clear.
    -- Dig on to floor 2 (400 hits) with reinforced heads: 120 hits each at
    -- 0.5 s, 50 s at crafting speed 4. The head slot takes another kind of
    -- head only once the current kind is used up.
    if M.valid and not reinforced and M.get_inventory(defines.inventory.crafter_input).is_empty()
      and not M.is_crafting() then
      reinforced = M.insert({name = "ttc-reinforced-drill-head", count = 11}) == 11
    end
    if M.valid then
      M.get_output_inventory().clear()
    end
  elseif tick == 21000 then
    local floor_2 = game.surfaces["ttc-floor-2"]
    check("core drill reaches floor 2", floor_2 ~= nil and floor_2.find_entity("ttc-core-drill", drill_position) ~= nil)
    check("reaching floor 2 researches its technologies", game.forces.player.technologies["ttc-reach-floor-2"].researched
      and not game.forces.player.technologies["military"].researched)
    local hot = game.surfaces["ttc-floor-5"]
    local uranium = hot and game.forces.player.get_item_production_statistics(hot).get_input_count("uranium-ore") or 0
    check("digging up uranium researches uranium processing", uranium > 0
      and game.forces.player.technologies["uranium-processing"].researched, uranium)
    check("floor 3 technologies still wait", not game.forces.player.technologies["radar"].researched)

    -- Floor 1 now has shaft 1's landing (stairs north/south, up to the
    -- surface) and shaft 2's pit (stairs east/west, down to floor 2) on the
    -- same spot; both must keep working.
    local function travel(dx, dy, direction)
      return remote.call("to-the-core", "travel_target", S.index,
        {x = drill_position.x + dx, y = drill_position.y + dy}, direction)
    end
    local up = travel(-2, -3, defines.direction.west)
    local down = travel(3, 2, defines.direction.south)
    check("floor 1 stairs still lead up to the surface", up and up.surface_index == game.surfaces.nauvis.index, serpent.line(up))
    check("floor 1 pit stairs lead down to floor 2", down and floor_2 and down.surface_index == floor_2.index, serpent.line(down))
  end
end)
