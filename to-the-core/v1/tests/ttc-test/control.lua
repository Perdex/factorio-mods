-- Engine test for To the Core, run by tests/run.sh. Logs "TTC ..." lines;
-- checks print PASS/FAIL.
local tunnel = require("__to-the-core__/runtime/tunnel")
local layer_configs = require("__to-the-core__/shared/layers")

local function L(...)
  local n = select("#", ...)
  local t = {...}
  for i = 1, n do
    local v = t[i]
    t[i] = type(v) == "table" and serpent.line(v) or tostring(v)
  end
  log("TTC " .. table.concat(t, " "))
end

-- The floor whose arrival technology unlocks a recipe, if any.
local function unlocked_on_floor(recipe)
  for floor = 1, 6 do
    for _, effect in ipairs(prototypes.technology["ttc-reach-floor-" .. floor].effects) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe then
        return floor
      end
    end
  end
end

-- Test bores that aren't about belts dig on without them (by default a
-- belt-laying bore stops when it runs out).
local function keep_going(bore)
  if bore and bore.valid then
    remote.call("to-the-core", "set_bore_options", bore.unit_number, {stop_without_stock = false})
  end
  return bore
end

local function check(name, ok, detail)
  L(ok and "PASS" or "FAIL", name, detail or "")
end

local S, B, D, M, W, C, chute, pipe, stray, combinator, reinforced, obstacle, V, vein_tile
local vein_drops = {}
local stocker, stocker_x
local uranium_bore, wide_bore, half_bore, rock_grinder, hole, stray_hole, lift, lift_pump, hot_mk2, hot_mk3, oil_tile, oil_bore, beside, grinder, winnower, T, pulses
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
  local loader = S.find_entity("ttc-loader", {bore.position.x - 1.5, bore.position.y - 0.5})
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
  -- Its stone only stacks to 20: keep the output clear while it's measured.
  if C and C.valid and tick < 600 then
    C.get_output_inventory().clear()
  end
  for _, cooled in ipairs({wide_bore, uranium_bore}) do
    if cooled and cooled.valid then
      cooled.set_fluid(1, {name = "ttc-coolant", amount = 200})
    end
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
    C = S.create_entity({name = "ttc-mk3-bore", position = {-4.5, 0.5}, direction = defines.direction.west, force = "player", raise_built = true})
    keep_going(C)
    C.insert({name = "ttc-iron-drill-head", count = 2})
    C.insert({name = "coal", count = 10})

    -- The main bore: four clay heads (25 hits each), two 40-hit tiles and
    -- 20 hits into the next.
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
    -- And one on floor 2's iron-rich rock.
    rock_grinder = nauvis.create_entity({name = "ttc-grinder", position = {-80, -55}, force = "player", raise_built = true})
    rock_grinder.insert({name = "ttc-iron-rich-rock", count = 50})
    rock_grinder.insert({name = "coal", count = 10})
    winnower = nauvis.create_entity({name = "ttc-winnower", position = {-75.5, -60.5}, force = "player", raise_built = true})
    winnower.insert({name = "ttc-dust", count = 10})

    -- Ten furnaces smelting 10 iron ore each: 100 plates unlock automation.
    for i = 1, 10 do
      local furnace = game.surfaces.nauvis.create_entity({name = "stone-furnace", position = {-40 + i * 3, -40}, force = "player"})
      furnace.insert({name = "iron-ore", count = 10})
      furnace.insert({name = "coal", count = 5})
    end

    B = S.create_entity({name = "ttc-mk2-bore", position = {29, 0}, direction = east, force = "player", raise_built = true})
    keep_going(B)
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
      for _, loader in pairs(S.find_entities_filtered({name = "ttc-loader", area = {{-4.5, -1.5}, {-2.5, 2.5}}})) do
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
        and coolant and coolant.amount > 200 - 33.4 and coolant.amount < 200 - 16.6,
        {coolant and coolant.amount, C.custom_status and C.custom_status.label})
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
      -- Drill heads come floor by floor.
      local head_floors = {}
      for floor = 1, 6 do
        for recipe in pairs(unlocked_by("ttc-reach-floor-" .. floor)) do
          head_floors[recipe] = floor
        end
      end
      check("drill heads unlock floor by floor", head_floors["ttc-clay-drill-head"] == 1
        and head_floors["ttc-iron-drill-head"] == 2 and head_floors["ttc-reinforced-drill-head"] == 4
        and head_floors["ttc-hardened-drill-head"] == 5 and head_floors["ttc-carbide-drill-head"] == 6
        and not unlocked_by("ttc-iron-discovery")["ttc-iron-drill-head"]
        and prototypes.technology["ttc-reinforced-drill-head"] == nil, serpent.line(head_floors))
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
      -- Floor 1's stairs run north and south: the loaders go east and west,
      -- once their spots are dug out (the east one is, at tick 9930).
      check("the core drill's loaders wait for their spots to be dug",
        S.count_entities_filtered({name = "ttc-loader", position = M.position, radius = 4}) == 0)
      local output = M.get_output_inventory()
      -- Sand only comes on 3 hits in 4, and the test clears the output now
      -- and then: clay is the sure sign.
      check("moved drill keeps the shaft's clay and digs on",
        output.get_item_count("ttc-clay") > 0
          and (M.is_crafting() or output.get_item_count("stone") + output.get_item_count("ttc-iron-rich-rock") > 0),
          serpent.line(output.get_contents()))
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
    -- Dig out the core drill's east loader spot (checked at 10001).
    tunnel.open(S, {{x = M.position.x + 3, y = M.position.y}}, "dirt-7")
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
    check("30 smelted iron plates unlock automation", game.forces.player.technologies["automation"].researched
      and trigger("automation").count == 30)
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
      and prototypes.recipe["stone-brick"].ingredients[1].amount == 4)
    -- Grinding takes 2, 6 and 18 s; winnowing the dust away 27.
    local steps = {{"ttc-grind-stone", 2}, {"ttc-grind-gravel", 6}, {"ttc-grind-sand", 18}, {"ttc-winnow-dust", 27}}
    local chain = true
    for _, step in ipairs(steps) do
      local recipe = prototypes.recipe[step[1]]
      chain = chain and recipe.ingredients[1].amount == 3 and recipe.energy == step[2]
        and (#recipe.products == 0 or recipe.products[1].amount == 2)
    end
    check("grinding turns 3 into 2, each step three times slower", chain)
    check("metal-rich rock takes 2 s a piece to grind", prototypes.recipe["ttc-grind-iron-rich-rock"].energy == 2
      and prototypes.recipe["ttc-grind-copper-rich-rock"].energy == 2)
    check("grinders wait for floor 2", not game.forces.player.recipes["ttc-grinder"].enabled)
    local ground = rock_grinder.get_output_inventory()
    check("ground iron-rich rock gives gravel and iron granules, no copper", ground.get_item_count("ttc-gravel") >= 30
      and ground.get_item_count("ttc-iron-granules") > 0 and ground.get_item_count("ttc-copper-granules") == 0,
      serpent.line(ground.get_contents()))
    -- A product's chance: its independent chance times its share of the
    -- recipe's one shared roll.
    local function products(name)
      local found = {}
      for _, product in ipairs(prototypes.recipe[name].products) do
        local shared = product.shared_probability
        local chance = (product.independent_probability or 1) * (shared and shared.max - shared.min or 1)
        found[product.name] = math.floor(chance * 1000 + 0.5) / 1000
      end
      return found
    end
    local sorted = products("ttc-sort-iron-rich-rock")
    check("iron-rich rock is sorted only by hand", prototypes.recipe["ttc-sort-iron-rich-rock"].categories[1] == "hand-crafting"
      and prototypes.recipe["ttc-sort-iron-rich-rock"].energy == 2
      and sorted["iron-ore"] == 0.2 and not sorted["copper-ore"] and sorted.coal == 0.02 and sorted.stone == 0.78,
      serpent.line(sorted))
    local grains = products("ttc-grind-iron-rich-rock")
    local copper_grains = products("ttc-grind-copper-rich-rock")
    check("grinding gives 80% granules of the rock's metal", grains["ttc-gravel"] == 1
      and grains["ttc-iron-granules"] == 0.8 and not grains["ttc-copper-granules"]
      and copper_grains["ttc-copper-granules"] == 0.8, serpent.line({grains, copper_grains}))
    check("copper-rich rock is sorted and smelted from floor 3", unlocked_on_floor("ttc-sort-copper-rich-rock") == 3
      and unlocked_on_floor("ttc-copper-plate-from-granules") == 3)
    local floor_3 = {}
    for _, drop in ipairs(layer_configs[3].drops) do
      floor_3[drop.name] = drop.chance
    end
    check("floor 3's walls give iron- and copper-rich rock alike, no plain ore or stone",
      floor_3["ttc-iron-rich-rock"] and floor_3["ttc-iron-rich-rock"] == floor_3["ttc-copper-rich-rock"]
      and not floor_3.stone and not floor_3["iron-ore"] and not floor_3["copper-ore"], serpent.line(floor_3))
    local assembler = prototypes.entity["assembling-machine-1"]
    local assembler_parts = {}
    for _, ingredient in ipairs(prototypes.recipe["assembling-machine-1"].ingredients) do
      assembler_parts[ingredient.name] = true
    end
    check("the first assembling machine burns fuel and needs no circuits", assembler.burner_prototype ~= nil
      and not assembler_parts["electronic-circuit"], serpent.line(assembler_parts))
    check("power waits for the first copper-rich rock, pipes come with floor 2",
      prototypes.technology["steam-power"].research_trigger.type == "scripted"
      and unlocked_on_floor("pipe") == 2 and unlocked_on_floor("offshore-pump") == 2
      and unlocked_on_floor("ttc-pipe-down") == 2)
    local smelt = prototypes.recipe["ttc-copper-plate-from-granules"]
    check("granules smelt 4:1 into plates", smelt.categories[1] == "smelting" and smelt.ingredients[1].amount == 4
      and smelt.products[1].name == "copper-plate" and smelt.products[1].amount == 1)
    local floor_2 = {}
    for _, drop in ipairs(layer_configs[2].drops) do
      floor_2[drop.name] = true
    end
    check("floor 2's walls give iron-rich rock, not stone or iron ore", floor_2["ttc-iron-rich-rock"]
      and not floor_2.stone and not floor_2["iron-ore"])
    local floor_2_veins = {}
    for _, vein in ipairs(layer_configs[2].veins) do
      floor_2_veins[vein.name] = true
    end
    local shaft_drops = {}
    for _, drop in ipairs(layer_configs[2].shaft.drops) do
      shaft_drops[drop.name] = drop.chance
    end
    check("the shaft to floor 2 brings up stone and some iron-rich rock, sortable from floor 2",
      shaft_drops.stone == 0.5 and shaft_drops["ttc-iron-rich-rock"] == 0.05
      and not game.forces.player.recipes["ttc-sort-iron-rich-rock"].enabled
      and unlocked_on_floor("ttc-sort-iron-rich-rock") == 2, serpent.line(shaft_drops))
    local deep = {}
    for _, drop in ipairs(layer_configs[4].shaft.drops) do
      deep[drop.name] = true
    end
    check("the core drill wears heads five times faster, at the same pace",
      prototypes.recipe["ttc-shaft-clay"].energy == 5 and prototypes.recipe["ttc-dig-clay"].energy == 25
      and layer_configs[1].shaft.hits == 20, prototypes.recipe["ttc-shaft-clay"].energy)
    check("the drill on floor 2 brings up mostly stone, 2 a hit", layer_configs[3].shaft.drops[1].name == "stone"
      and layer_configs[3].shaft.drops[1].minimum == 2)
    local deepest = {}
    for _, drop in ipairs(layer_configs[5].shaft.drops) do
      deepest[drop.name] = true
    end
    check("the deep shafts bring up hardened stone", deep["ttc-hardened-stone"] and deepest["ttc-hardened-stone"]
      and table_size(deep) == 1 and table_size(deepest) == 1, serpent.line({deep, deepest}))
    check("stone stacks to 20, hardened stone not at all, and grinds in 10 s", prototypes.item["stone"].stack_size == 20
      and prototypes.item["ttc-hardened-stone"].stack_size == 1
      and prototypes.recipe["ttc-grind-hardened-stone"].energy == 10)
    local wall_uranium = false
    for _, drop in ipairs(layer_configs[5].drops) do
      wall_uranium = wall_uranium or drop.name == "uranium-ore"
    end
    check("uranium only in veins", not wall_uranium)
    check("floor 2 has stone and coal veins, no iron", floor_2_veins.stone and floor_2_veins.coal
      and not floor_2_veins["iron-ore"])
    check("floor 2's walls take 80 hits a tile, 40 iron-rich rock a 2-wide step", layer_configs[2].hits_per_tile == 80
      and layer_configs[2].drops[1].chance * 80 * 2 == 40)
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
    check("the one core drill can't be mined or crafted", prototypes.entity["ttc-core-drill"].mineable_properties.minable == false
      and prototypes.recipe["ttc-core-drill"] == nil)
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
    local down = amounts(prototypes.recipe["ttc-underground-belt-down"].products)
    local up = amounts(prototypes.recipe["ttc-underground-belt-up"].products)
    check("underground belts come as a down and an up end", prototypes.item["underground-belt"].hidden
      and prototypes.recipe["underground-belt"].hidden and unlocks("logistics", "ttc-underground-belt-down")
      and down["ttc-underground-belt-down"] == 1 and table_size(down) == 1
      and up["ttc-underground-belt-up"] == 1 and table_size(up) == 1, serpent.line({down, up}))
    check("up ends unlock on floor 3", unlocks("ttc-reach-floor-3", "ttc-underground-belt-up")
      and unlocks("ttc-reach-floor-3", "ttc-pipe-up") and not unlocks("logistics", "ttc-underground-belt-up")
      and unlocks("logistics-2", "ttc-fast-underground-belt-up"))
    local fast_down = amounts(prototypes.recipe["ttc-fast-underground-belt-down"].ingredients)
    local fast_up = amounts(prototypes.recipe["ttc-fast-underground-belt-up"].ingredients)
    check("faster ends are made from the ends below them", fast_down["ttc-underground-belt-down"] == 1
      and fast_up["ttc-underground-belt-up"] == 1 and not fast_down["ttc-underground-belt-up"],
      serpent.line({fast_down, fast_up}))
    check("the manhole comes halfway down to floor 4", prototypes.technology["ttc-manhole"].research_trigger.type == "scripted"
      and not game.forces.player.recipes["ttc-manhole"].enabled)
    check("bore Mk1 has no loaders", #S.find_entities_filtered({name = "ttc-loader", area = {{0, -3}, {12, 3}}}) == 0)
    check("buildings in the pit's way are dropped on the ground", not obstacle.valid
      and #game.surfaces.nauvis.find_entities_filtered({type = "item-entity", position = drill_position, radius = 8}) > 0)
  elseif tick == 9940 then
    M.insert({name = "coal", count = 50})
  elseif tick == 10001 then
    local loaders = S.find_entities_filtered({name = "ttc-loader", position = M.position, radius = 4})
    check("a core drill loader appears once its spot is dug", #loaders == 1 and loaders[1].loader_type == "output"
      and loaders[1].position.x == M.position.x + 3 and loaders[1].position.y == M.position.y,
      loaders[1] and loaders[1].position)
    -- Veins from here on: everything set up below sees them.
    remote.call("to-the-core", "set_veins", true)
    -- A Mk3 (3 wide) on floor 1: each tile still takes 20 hits.
    tunnel.open_area(S, {x = 119, y = 44}, {x = 121, y = 46}, "stone-path")
    wide_bore = S.create_entity({name = "ttc-mk3-bore", position = {120.5, 45.5}, direction = east, force = "player",
      raise_built = true})
    keep_going(wide_bore)
    wide_bore.insert({name = "ttc-clay-drill-head", count = 3})
    wide_bore.insert({name = "coal", count = 10})
    -- A Mk2 with heads and fuel but no belts: by default it digs its face out
    -- and waits for them before moving on.
    -- Somewhere its face is plain rock, so the face is gone in time.
    stocker_x = 130
    while remote.call("to-the-core", "vein_at", S.index, {x = stocker_x + 2.5, y = 44.5})
      or remote.call("to-the-core", "vein_at", S.index, {x = stocker_x + 2.5, y = 45.5}) do
      stocker_x = stocker_x + 3
    end
    tunnel.open_area(S, {x = stocker_x, y = 44}, {x = stocker_x + 1, y = 45}, "stone-path")
    stocker = S.create_entity({name = "ttc-mk2-bore", position = {stocker_x + 1, 45}, direction = east, force = "player",
      raise_built = true})
    stocker.insert({name = "ttc-iron-drill-head", count = 2})
    stocker.insert({name = "coal", count = 5})
    -- A bore facing a wall that is half open already: half the hits.
    tunnel.open_area(S, {x = 88, y = 44}, {x = 89, y = 45}, "stone-path")
    tunnel.open(S, {{x = 90.5, y = 44.5}}, "stone-path")
    half_bore = S.create_entity({name = "ttc-mk1-bore", position = {89, 45}, direction = east, force = "player",
      raise_built = true})
    half_bore.insert({name = "ttc-clay-drill-head", count = 2})
    half_bore.insert({name = "coal", count = 5})
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
    remote.call("to-the-core", "set_bore_options", T.unit_number, {read_hits = true, read_moved = true})
    pulses = 0
    -- Find a stone vein out east and set a bore up facing it, with plain
    -- rock beside the vein on the other half of the face.
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
    hot_mk3 = hot.create_entity({name = "ttc-mk3-bore", position = {-4.5, -0.5}, direction = defines.direction.west, force = "player", raise_built = true})
    keep_going(hot_mk3)
    hot_mk3.insert({name = "ttc-carbide-drill-head", count = 1})
    hot_mk3.insert({name = "coal", count = 10})
    hot_mk3.set_fluid(1, {name = "ttc-coolant", amount = 200})
    -- Uranium is only in its veins: a Mk3 facing one.
    local uranium_tile
    for x = -200, 200, 2 do
      for y = -60, 60, 2 do
        if not uranium_tile and remote.call("to-the-core", "vein_at", hot.index, {x = x, y = y}) == "uranium-ore" then
          uranium_tile = {x = x, y = y}
        end
      end
    end
    if uranium_tile then
      tunnel.open_area(hot, {x = uranium_tile.x - 3, y = uranium_tile.y - 1}, {x = uranium_tile.x - 1, y = uranium_tile.y + 1},
        "red-desert-0")
      uranium_bore = hot.create_entity({name = "ttc-mk3-bore", position = {uranium_tile.x - 1.5, uranium_tile.y + 0.5},
        direction = east, force = "player", raise_built = true})
      keep_going(uranium_bore)
      uranium_bore.insert({name = "ttc-carbide-drill-head", count = 1})
      uranium_bore.insert({name = "coal", count = 10})
    end
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
      for dx = -3, -1 do
        for dy = -1, 1 do
          body[#body + 1] = {x = oil_tile.x + dx, y = oil_tile.y + dy}
        end
      end
      tunnel.open(deep, body, "dry-dirt")
      oil_bore = deep.create_entity({name = "ttc-mk3-bore", position = {oil_tile.x - 1.5, oil_tile.y + 0.5}, direction = east,
        force = "player", raise_built = true})
      keep_going(oil_bore)
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
    -- The vein bore's output, counted up before it's cleared.
    if V and V.valid then
      for _, item in pairs(V.get_output_inventory().get_contents()) do
        vein_drops[item.name] = (vein_drops[item.name] or 0) + item.count
      end
      V.get_output_inventory().clear()
    end
  elseif tick == 11102 then
    local waiting = stocker and stocker.valid and stocker.custom_status and stocker.custom_status.label
    check("a Mk2 out of belts digs its face out, then waits to move", waiting
      and waiting[1] == "ttc-status.needs-belts" and stocker.position.x == stocker_x + 1
      and not tunnel.is_void(S, {x = stocker_x + 2.5, y = 44.5}) and not tunnel.is_void(S, {x = stocker_x + 2.5, y = 45.5}),
      waiting)
  elseif tick == 11101 then
    local stopped = V and V.valid and V.custom_status and V.custom_status.label
    check("a bore set to stop at veins stops", stopped and stopped[1] == "ttc-status.vein-ahead", stopped)
  elseif tick == 11001 then
    -- From here on the vein bore stops at the vein it's in.
    if V and V.valid then
      remote.call("to-the-core", "set_bore_options", V.unit_number, {stop_at_vein = true})
    end
    -- Hits alternate between the vein (stone) and the plain rock beside it
    -- (floor 1's clay), so the drops mix.
    check("each tile yields its own drops", (vein_drops.stone or 0) > 0 and (vein_drops["ttc-clay"] or 0) > 0,
      vein_drops)
    check("a manhole goes over dug-out ground", hole and hole.valid)
    -- Spilled next to the spot, or further if the map put trees or water
    -- there.
    local refunded = 0
    for _, item in pairs(game.surfaces.nauvis.find_entities_filtered({type = "item-entity", position = {81, 45}, radius = 40})) do
      if item.stack.name == "ttc-manhole" then
        refunded = refunded + item.stack.count
      end
    end
    local left = game.surfaces.nauvis.count_entities_filtered({name = "ttc-manhole", position = {81, 45}, radius = 2})
    check("a manhole over rock is refunded", left == 0 and refunded == 1, {left = left, refunded = refunded})
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
      and label and label[1] == "ttc-status.digging-vein" and tonumber(label[2]) > 40 and label[3] == "420",
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
    local hardness = {}
    for _, vein in ipairs(layer_configs[1].veins) do
      hardness[vein.name] = vein.hardness
    end
    local face = 0
    for y = 44, 46 do
      local vein = remote.call("to-the-core", "vein_at", S.index, {x = 122.5, y = y + 0.5})
      face = face + 20 * (vein and hardness[vein] or 1)
    end
    local wide = wide_bore and wide_bore.valid and wide_bore.custom_status and wide_bore.custom_status.label
    check("a Mk3's tiles take as many hits as anyone's", wide and tonumber(wide[3]) == face, {wide, face})
    -- 3x3, so it turns in place.
    local turned = wide_bore and wide_bore.valid and wide_bore.rotate()
    check("a Mk3 can turn", turned and wide_bore.direction == defines.direction.south, wide_bore and wide_bore.direction)
    local half = half_bore and half_bore.valid and half_bore.custom_status and half_bore.custom_status.label
    -- The solid half may be vein rock, depending on the map.
    local half_vein = remote.call("to-the-core", "vein_at", S.index, {x = 90.5, y = 45.5})
    local expected = 20 * (half_vein and hardness[half_vein] or 1)
    check("a half-open face takes half the hits", half and tonumber(half[3]) == expected, {half, expected})
    -- Half the face is vein (20 times 40 over 2 tiles), half plain rock.
    check("a vein takes 20 times the hits", label and label[1] == "ttc-status.digging-vein" and label[3] == "420",
      serpent.line(label))

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
