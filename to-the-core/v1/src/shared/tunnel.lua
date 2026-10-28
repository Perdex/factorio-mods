-- Tunnel wall constants shared by the data and control stages.
local tunnel = {
  -- Cliff-face pieces, cut from the base game's cliff textures, for the sides
  -- of a rock tile that face open ground: "s" the full rock face (open ground
  -- to the south), "s_short" the same where the rock is one tile thin, "n"
  -- the cliff's top lip, "e" and "w" the side faces.
  wall_pieces = {"n", "e", "s", "s_short", "w"},
  -- The base cliff sheet has 8 variations of 4-tile cliff runs; each piece
  -- variation is one 1-tile slice of one run.
  cliff_frames = 8,
  cliff_slices = 4
}

function tunnel.wall_name(piece)
  return "ttc-tunnel-wall-" .. piece
end

-- Ore showing in exposed rock that belongs to a vein (shared/layers.lua).
function tunnel.vein_name(vein_name)
  return "ttc-vein-" .. vein_name
end

tunnel.vein_variations = 16

-- Every vein name used on any floor, and the vein config that defines its
-- look (the first one with that name).
tunnel.vein_names = {}
tunnel.vein_looks = {}
for _, layer in ipairs(require("shared.layers")) do
  for _, vein in ipairs(layer.veins or {}) do
    if not tunnel.vein_looks[vein.name] then
      tunnel.vein_looks[vein.name] = vein
      tunnel.vein_names[#tunnel.vein_names + 1] = vein.name
    end
  end
end

return tunnel
