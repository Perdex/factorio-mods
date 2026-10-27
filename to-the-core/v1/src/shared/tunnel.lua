-- Tunnel wall constants shared by the data and control stages.
local tunnel = {
  -- Sides (n, e, s, w) and diagonals (ne, se, sw, nw) a wall piece faces.
  wall_pieces = {"n", "e", "s", "w", "ne", "se", "sw", "nw"},
  wall_variants = 4
}

function tunnel.wall_name(piece)
  return "ttc-tunnel-wall-" .. piece
end

return tunnel
