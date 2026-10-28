-- Underground terrain: everything is void except opened tiles, and the void
-- bordering open ground gets cliff faces (cut from the base cliff textures) so
-- the open area reads as a tunnel cut into rock.
local wall_config = require("shared.tunnel")
local veins = require("runtime.veins")

local tunnel = {
  void_tile = "out-of-map"
}

local function tile_center(position)
  return {x = math.floor(position.x) + 0.5, y = math.floor(position.y) + 0.5}
end

-- Generates the position's chunk now, so later generation can't overwrite
-- tiles or walls placed in it. Layer surfaces are 1x1 tile maps: chunks
-- outside those bounds never generate (they are already void), so they are
-- only marked generated, which lets them be charted.
function tunnel.ensure_generated(surface, position)
  local chunk = {x = math.floor(position.x / 32), y = math.floor(position.y / 32)}
  if surface.is_chunk_generated(chunk) then
    return
  end
  surface.request_to_generate_chunks(position, 0)
  surface.force_generate_chunk_requests()
  if not surface.is_chunk_generated(chunk) then
    surface.set_chunk_generated_status(chunk, defines.chunk_generated_status.entities)
  end
end

function tunnel.is_void(surface, position)
  return surface.get_tile(position).name == tunnel.void_tile
end

-- Whether a position is dug out; ungenerated chunks are solid rock.
function tunnel.is_open(surface, position)
  local chunk = {x = math.floor(position.x / 32), y = math.floor(position.y / 32)}
  return surface.is_chunk_generated(chunk) and not tunnel.is_void(surface, position)
end

local sides = {
  n = {x = 0, y = -1},
  e = {x = 1, y = 0},
  s = {x = 0, y = 1},
  w = {x = -1, y = 0}
}

local wall_names = {}
for _, piece in ipairs(wall_config.wall_pieces) do
  wall_names[#wall_names + 1] = wall_config.wall_name(piece)
end

-- Cliff pieces and vein ore: everything a rock tile shows.
local rock_names = {}
for _, name in ipairs(wall_names) do
  rock_names[#rock_names + 1] = name
end
for _, vein_name in ipairs(wall_config.vein_names) do
  rock_names[#rock_names + 1] = wall_config.vein_name(vein_name)
end

local function is_open(surface, center, offset)
  local position = {x = center.x + offset.x, y = center.y + offset.y}
  tunnel.ensure_generated(surface, position)
  return not tunnel.is_void(surface, position)
end

-- Which 1-tile slice of which cliff run a piece shows: runs are 4 tiles long
-- along the face, so neighbouring tiles continue the same run, and each run
-- of 4 picks one of the cliff variations.
local function cliff_variation(center, along_x)
  local x, y = math.floor(center.x), math.floor(center.y)
  local along = along_x and x or y
  local run = math.floor(along / wall_config.cliff_slices)
  local across = along_x and y or x
  local frame = (run * 7 + across * 3) % wall_config.cliff_frames
  return frame * wall_config.cliff_slices + along % wall_config.cliff_slices + 1
end

-- Replaces the cliff pieces on one tile to match its open neighbours, with
-- ore showing in front of them if the rock belongs to a vein.
local function rebuild_walls(surface, center)
  for _, wall in pairs(surface.find_entities_filtered({
    name = rock_names,
    area = {{center.x - 0.1, center.y - 0.1}, {center.x + 0.1, center.y + 0.1}}
  })) do
    wall.destroy()
  end
  if not tunnel.is_void(surface, center) then
    return
  end

  local exposed = false
  for side, offset in pairs(sides) do
    if is_open(surface, center, offset) then
      exposed = true
      local piece = side
      -- A face on rock only one tile thin would spill over the open ground
      -- behind it.
      if side == "s" and is_open(surface, center, sides.n) then
        piece = "s_short"
      end
      local wall = surface.create_entity({name = wall_config.wall_name(piece), position = center})
      wall.graphics_variation = cliff_variation(center, side == "n" or side == "s")
    end
  end

  local vein = exposed and veins.at(surface, center)
  if vein then
    local ore = surface.create_entity({name = wall_config.vein_name(vein.name), position = center})
    local x, y = math.floor(center.x), math.floor(center.y)
    ore.graphics_variation = math.floor(veins.hash(x, y, 17) * wall_config.vein_variations) + 1
    -- The ore sits behind the cliff faces, so every third tile along a face
    -- also carries the vein's icon; it goes when the ore does.
    if (x + y) % 3 == 0 then
      rendering.draw_sprite({
        sprite = veins.sprite(vein),
        target = ore,
        surface = surface,
        x_scale = 0.5,
        y_scale = 0.5,
        render_layer = "higher-object-under"
      })
    end
  end
end

-- Turns the void tiles among positions into tile_name and rebuilds the cliff
-- walls around them. Already open tiles are left as they are.
function tunnel.open(surface, positions, tile_name)
  local opened = {}
  for _, position in ipairs(positions) do
    local center = tile_center(position)
    tunnel.ensure_generated(surface, center)
    if tunnel.is_void(surface, center) then
      opened[#opened + 1] = {name = tile_name, position = center}
    end
  end
  surface.set_tiles(opened, true, false, true, false)

  local rebuilt = {}
  for _, tile in ipairs(opened) do
    for dx = -1, 1 do
      for dy = -1, 1 do
        local center = {x = tile.position.x + dx, y = tile.position.y + dy}
        local key = center.x .. ":" .. center.y
        if not rebuilt[key] then
          rebuilt[key] = true
          tunnel.ensure_generated(surface, center)
          rebuild_walls(surface, center)
        end
      end
    end
  end
end

function tunnel.open_area(surface, left_top, right_bottom, tile_name)
  local positions = {}
  for x = left_top.x, right_bottom.x do
    for y = left_top.y, right_bottom.y do
      positions[#positions + 1] = {x = x, y = y}
    end
  end
  tunnel.open(surface, positions, tile_name)
end

tunnel.wall_names = wall_names

local is_rock_name = {}
for _, name in ipairs(rock_names) do
  is_rock_name[name] = true
end

-- Whether an entity is part of the rock's look (a cliff piece or vein ore).
function tunnel.is_wall(entity)
  return is_rock_name[entity.name] == true
end

return tunnel
