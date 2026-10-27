
local surfacesettings = {
    width = 1, 
    height = 1, 
    no_enemies_mode = true}

local function create_next_floor(stairs)

    local surface

    game.get_player(1).print(storage.next_surface[stairs.surface_index])

    -- First lets create the surface
    if not storage.next_surface[stairs.surface_index] then
        game.get_player(1).print("Woah creating surface!")

        surface = game.create_surface("floor" .. storage.next_floor, surfacesettings)
        surface.localised_name = {"", "floor", storage.next_floor}
        surface.daytime = 0.
        surface.freeze_daytime = true

        storage.next_floor = storage.next_floor + 1
        storage.next_surface[stairs.surface_index] = surface
        storage.previous_surface[surface.index] = stairs.surface
    else
        surface = storage.next_surface[stairs.surface_index]
    end
    local chunk_x = stairs.position.x / 32
    local chunk_y = stairs.position.y / 32
    -- To make void chnks show up on the map, you need to tell them they've finished generating.
    for xx = -1, 2 do
        for yy = -1, 2 do
            surface.set_chunk_generated_status({chunk_x + xx, chunk_y + yy}, defines.chunk_generated_status.entities)
        end
    end
   
    -- TODO add wall-ore to the sides for the miner to mine

    -- Then let's add tiles and the stairs
    local tiles = {}
    local i = 1
    for x = -5, 5 - 1 do
        for y = -2, 3 - 1 do
            tiles[i] = {name = "landfill",
                position = {stairs.position.x + x, stairs.position.y + y}}
            i = i + 1
        end
    end
    surface.set_tiles(tiles)
    surface.create_entity{name="stairs", position=stairs.position, force=stairs.force}
    game.get_player(1).print("Setting stairs to")
    game.get_player(1).print(stairs.position)
end


-- Surface generation
aisodoimod.on_event(aisodoimod.events.on_built(), function(event)

    local entity = event.entity
    if not entity.valid then return end
    local entity_name = entity.name

    if entity_name and entity_name == "stairs" then
        create_next_floor(entity)
        return
    end
end)

local function teleport_safely(e, surface, player, position)

    if e.is_player() and not e.character then -- god controller
        e.teleport(position, surface)
        storage.last_player_teleport[player.index] = game.tick
    else
        position = surface.find_non_colliding_position(
            e.character.name,
            position, 5, 0.5, false
        ) or position
        e.teleport(position, surface)
        storage.last_player_teleport[player.index] = game.tick
    end

    --if player then aisodoimod.update_camera(player) end
end

local function enter_floor(e, stairs, player, up)
    if up then
        if player.physical_surface_index == 1 then return end

        player.print("Teleporting up to floor " .. player.physical_surface_index - 1)
        position = {x = player.physical_position.x+5, y = player.physical_position.y}
        teleport_safely(e, game.surfaces[player.physical_surface_index - 1], player, position)
    else
        if not game.surfaces[player.physical_surface_index + 1] then return end

        player.print("Teleporting down to floor " .. player.physical_surface_index + 1)
        position = {x = player.physical_position.x-5, y = player.physical_position.y}
        teleport_safely(e, game.surfaces[player.physical_surface_index + 1], player, position)
    end
end


BUILDING_TYPE = "storage-tank"
find_stairs_by_area = function(params)
    local surface = params.surface
    local area = params.area
    --params.player.print(serpent.block(area))
    local ans = nil
    for _, entity in pairs(surface.find_entities_filtered {area = area, type = BUILDING_TYPE}) do
        ans = entity
    end
    return ans
end

function check_position_and_enter_floor(player)
    if player.controller_type == defines.controllers.remote then return end

    local physical_position = player.physical_position

    local walking_direction = player.walking_state.direction
    local is_moving_left = walking_direction == defines.direction.west
        or walking_direction == defines.direction.southwest
        or walking_direction == defines.direction.northwest
    local is_moving_right = walking_direction == defines.direction.east
            or walking_direction == defines.direction.southeast
            or walking_direction == defines.direction.northeast

    if not is_moving_left and not is_moving_right then return end
    local tolerance = 0.3
    local stairs = find_stairs_by_area {
        player = player,
        surface = player.physical_surface,
        area = {
            {physical_position.x - tolerance, physical_position.y - tolerance},
            {physical_position.x + tolerance, physical_position.y + tolerance}
        } or nil
    }

    if not stairs then return end

    local is_going_down = math.abs(physical_position.y - stairs.position.y-1) < 1 and 
        math.abs(physical_position.x - stairs.position.x-2.5) < tolerance
    local is_going_up = math.abs(physical_position.y - stairs.position.y-1) < 1 and 
        math.abs(physical_position.x - stairs.position.x+2.5) < tolerance

    if is_going_down and is_moving_left then
        enter_floor(player, stairs, player, false)
    end
    if is_going_up and is_moving_right then
        enter_floor(player, stairs, player, true)
    end
end

aisodoimod.on_event(aisodoimod.events.on_init(), function()
    storage.last_player_teleport = storage.last_player_teleport or {}
    storage.next_surface = storage.next_surface or {}
    storage.previous_surface = storage.previous_surface or {}
    storage.next_floor = storage.next_floor or 2
end)
-- teleport players between factory buildings
aisodoimod.on_nth_tick(6, function()
    local tick = game.tick
    for player_index, player in pairs(game.connected_players) do
        if player.driving then goto continue end
        if tick - (storage.last_player_teleport[player_index] or 0) < 35 then goto continue end
        if not player.walking_state.walking then goto continue end

        check_position_and_enter_floor(player)

        ::continue::
    end
end)