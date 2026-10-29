-- Prints the locale keys the runtime builds from the shared config, one per
-- line, for tests/check_locale.py: layer and vein names, the hint at the
-- ground below each floor, and messages of mid-shaft unlocks.
-- Usage: lua tests/locale_keys.lua <mod src dir>
package.path = arg[1] .. "/?.lua;" .. package.path
local layers = require("shared.layers")

for _, layer in ipairs(layers) do
  print("ttc-layer-name." .. layer.name)
  print("ttc-ground-below." .. layer.name)
  for _, vein in ipairs(layer.veins or {}) do
    print("ttc-vein-name." .. vein.name)
  end
  for _, unlock in ipairs(layer.shaft and layer.shaft.unlocks or {}) do
    print(unlock.message)
  end
end
