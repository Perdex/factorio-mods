-- The hidden yellow 1x1 loader the belt-laying bores and the core drill use:
-- the base game's, with a plate over just the half of the tile against the
-- machine, so the belt end shows in the other half. Art from
-- v1/tools/loader_gfx.py.
local bore = require("shared.bore")

local loader = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
loader.name = bore.loader_entity
loader.flags = {"placeable-neutral", "not-blueprintable", "not-deconstructable"}
loader.minable = nil
local sheet = "__to-the-core__/graphics/entities/loader-structure.png"
-- Frames are two tiles, the loader's in the middle, so the box can reach as
-- low as the belt beside it.
loader.structure = {
  direction_in = {sheet = {filename = sheet, priority = "extra-high", width = 128, height = 128, scale = 0.5}},
  direction_out = {sheet = {filename = sheet, priority = "extra-high", width = 128, height = 128, y = 128, scale = 0.5}}
}
data:extend({loader})
