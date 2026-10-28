-- Core drill and shaft constants shared by the data and control stages.
local shaft = {
  drill_name = "ttc-core-drill",
  recipe_category = "ttc-shaft",
  -- Each shaft leaves a top (a pit with stairs going down along two opposite
  -- rims) on the layer it was dug from and a bottom (a landing where the same
  -- stairs arrive) on the layer it reaches. Shafts alternate the rims their
  -- stairs use, so a layer's landing and its next pit never overlap: shafts
  -- into odd layers use "ns" (north and south rims), even layers "we".
  axes = {"ns", "we"},
  -- Both are 7x7 around the 5x5 drill. The landing below opens only the
  -- drill's spot and the stairs, plus `platform_margin` rows beyond them:
  -- room for a 2x2 tunnel bore, since nothing can be built on the stairs.
  size = 7,
  platform_margin = 2
}

function shaft.top_name(axis)
  return "ttc-shaft-top-" .. axis
end

function shaft.bottom_name(axis)
  return "ttc-shaft-bottom-" .. axis
end

-- Axis of the shaft that reaches layer `layer_index`.
function shaft.axis(layer_index)
  return layer_index % 2 == 1 and "ns" or "we"
end

-- Stairs in shaft-local tile centres: walking from `high` to `low` descends.
-- "we" is "ns" turned a quarter clockwise.
shaft.stairs = {
  ns = {
    {high = {x = -2, y = -3}, low = {x = 2, y = -3}},
    {high = {x = 2, y = 3}, low = {x = -2, y = 3}}
  },
  we = {
    {high = {x = 3, y = -2}, low = {x = 3, y = 2}},
    {high = {x = -3, y = 2}, low = {x = -3, y = -2}}
  }
}

-- The core drill is a furnace that takes the same drill heads as the tunnel
-- bore (shared/bore.lua): one shaft dig recipe per head, any floor.
-- Invisible strips over each stairway that keep buildings (and tunnel bores)
-- off the stairs but let players walk: "ns" stairs run east-west, "we" stairs
-- north-south.
function shaft.stair_blocker_name(axis)
  return "ttc-stairs-" .. axis
end

function shaft.recipe_name(head_name)
  return "ttc-shaft-" .. head_name
end

shaft.recipe_heads = {}
for head_name, head in pairs(require("shared.bore").heads) do
  shaft.recipe_heads[shaft.recipe_name(head_name)] = head
end

return shaft
