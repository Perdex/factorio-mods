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
  -- Both are 7x7 around the 5x5 drill; the lower layer's platform adds a
  -- margin of open ground around that.
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

function shaft.recipe_name(layer)
  return "ttc-shaft-" .. layer.name
end

return shaft
