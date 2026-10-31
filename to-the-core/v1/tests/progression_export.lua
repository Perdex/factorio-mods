-- Prints the mod's floor and progression config as JSON for
-- tests/check_unlocks.py: the layers (drops, veins, shafts and what they
-- unlock) and the base technology triggers.
-- Usage: lua tests/progression_export.lua <mod src dir>
package.path = arg[1] .. "/?.lua;" .. package.path
local layers = require("shared.layers")
local progression = require("shared.progression")

local function encode(value)
  local kind = type(value)
  if kind == "table" then
    if #value > 0 or next(value) == nil then
      local parts = {}
      for _, item in ipairs(value) do
        parts[#parts + 1] = encode(item)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do
      keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
      parts[#parts + 1] = string.format("%q", key) .. ":" .. encode(value[key] == nil and value[tonumber(key)] or value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif kind == "string" then
    return string.format("%q", value)
  elseif kind == "number" or kind == "boolean" then
    return tostring(value)
  end
  return "null"
end

print(encode({layers = layers, triggers = progression.triggers}))
