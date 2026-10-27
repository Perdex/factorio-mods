-- Cliff faces that edge the tunnels on underground layers. Each void (solid
-- rock) tile next to open ground gets one piece per open side, plus a corner
-- piece per open diagonal not covered by a side; the void itself blocks
-- movement. Pieces are rendered by v1/tools/wall_gfx.py.
local tunnel = require("shared.tunnel")

for _, piece in ipairs(tunnel.wall_pieces) do
  local pictures = {}
  for variant = 0, tunnel.wall_variants - 1 do
    pictures[#pictures + 1] = {
      filename = "__to-the-core__/graphics/entities/tunnel-wall-" .. piece .. ".png",
      x = variant * 64,
      width = 64,
      height = 64,
      scale = 0.5
    }
  end
  data:extend({
    {
      type = "simple-entity",
      name = tunnel.wall_name(piece),
      localised_name = {"entity-name.ttc-tunnel-wall"},
      icon = "__base__/graphics/icons/big-rock.png",
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
