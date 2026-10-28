-- Cliff faces that edge the tunnels on underground floors, cut tile by tile
-- from the base game's cliff textures. Each void (solid rock) tile next to
-- open ground gets one piece per open side; the void itself blocks movement.
-- runtime/tunnel.lua picks each piece's slice from the tile's position, so
-- neighbouring tiles continue the same cliff run.
local tunnel = require("shared.tunnel")

local sheet = "__base__/graphics/terrain/cliffs/cliff-sides.png"
local frame = 256 -- one 4x4-tile cliff frame in the sheet (scale 0.5)
local tile = 64

-- Sheet rows: 0 the low top lip, 2 the tall south-facing face, 1 and 3 the
-- side faces rising to the west and to the east.
-- `crop` is the vertical part of a horizontal run to use; shifts align the
-- face's base or lip with the open edge of the tile.
local pieces = {
  s = {row = 2, horizontal = true, crop = {0, frame}, shift = {0, -0.7}},
  -- Only the bottom tile of the face, so it can't spill onto open ground
  -- beyond a thin wall.
  s_short = {row = 2, horizontal = true, crop = {141, tile}, shift = {0, 0}},
  n = {row = 0, horizontal = true, crop = {0, frame}, shift = {0, -0.35}},
  e = {row = 1, horizontal = false, shift = {-0.15, 0}},
  w = {row = 3, horizontal = false, shift = {0.23, 0}}
}

for _, name in ipairs(tunnel.wall_pieces) do
  local piece = pieces[name]
  local pictures = {}
  for frame_index = 0, tunnel.cliff_frames - 1 do
    for slice = 0, tunnel.cliff_slices - 1 do
      local picture = {filename = sheet, scale = 0.5, shift = piece.shift}
      if piece.horizontal then
        picture.x = frame_index * frame + slice * tile
        picture.y = piece.row * frame + piece.crop[1]
        picture.width = tile
        picture.height = piece.crop[2]
      else
        picture.x = frame_index * frame
        picture.y = piece.row * frame + slice * tile
        picture.width = frame
        picture.height = tile
      end
      pictures[#pictures + 1] = picture
    end
  end

  data:extend({
    {
      type = "simple-entity",
      name = tunnel.wall_name(name),
      localised_name = {"entity-name.ttc-tunnel-wall"},
      icon = "__base__/graphics/icons/cliff.png",
      icon_size = 64,
      hidden = true,
      flags = {"placeable-neutral", "not-blueprintable", "not-deconstructable", "not-flammable"},
      selectable_in_game = false,
      collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
      collision_mask = {layers = {}},
      -- Below objects, so the bore's cutter head draws over the wall it digs.
      render_layer = "lower-object",
      pictures = pictures,
      map_color = {r = 0.32, g = 0.28, b = 0.24}
    }
  })
end

-- Ore showing in exposed vein rock, from the base game's resource sprites
-- (8 variations x 8 richness stages of 128 px; the two richest stages).
for _, vein_name in ipairs(tunnel.vein_names) do
  local look = tunnel.vein_looks[vein_name]
  local sprite = look.sprite or vein_name
  local resource = data.raw.resource[sprite]
  local pictures = {}
  for index = 0, tunnel.vein_variations - 1 do
    pictures[#pictures + 1] = {
      filename = "__base__/graphics/entity/" .. sprite .. "/" .. sprite .. ".png",
      x = index % 8 * 128,
      y = math.floor(index / 8) * 128,
      width = 128,
      height = 128,
      scale = 0.5,
      tint = look.tint
    }
  end
  data:extend({
    {
      type = "simple-entity",
      name = tunnel.vein_name(vein_name),
      localised_name = {"ttc-vein-name." .. vein_name},
      icon = resource and resource.icon or "__base__/graphics/icons/stone.png",
      icon_size = 64,
      hidden = true,
      flags = {"placeable-neutral", "not-blueprintable", "not-deconstructable", "not-flammable"},
      selectable_in_game = false,
      collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
      collision_mask = {layers = {}},
      -- Above the void, below the cliff faces.
      render_layer = "floor",
      pictures = pictures,
      map_color = resource and resource.map_color or {r = 0.5, g = 0.5, b = 0.5}
    }
  })
end
