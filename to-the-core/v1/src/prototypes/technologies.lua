-- Progression technologies. None are researched with science: the runtime
-- researches them when a shaft first reaches a floor (`reached_unlocks` in
-- shared/layers.lua) or a bore first digs up a resource (`unlocks`); a few
-- use the game's own crafting triggers instead.

local icons = "__to-the-core__/graphics/icons/"
local technologies = {
  {
    name = "ttc-reach-floor-1",
    icon = icons .. "mk1-bore.png",
    recipes = {"ttc-mk1-bore", "ttc-unfired-clay-drill-head", "ttc-clay-drill-head", "ttc-glass"}
  },
  {
    name = "ttc-reach-floor-2",
    icon = icons .. "grinder.png",
    recipes = {"ttc-grinder", "ttc-winnower"}
  },
  {
    name = "ttc-iron-discovery",
    icon = "__base__/graphics/icons/iron-ore.png",
    recipes = {"ttc-iron-drill-head", "ttc-mk2-bore"}
  },
  {
    name = "ttc-reach-floor-3",
    icon = icons .. "core-drill.png",
    recipes = {}
  },
  {
    -- Researched halfway down the shaft to floor 4 (`unlocks` in the shaft
    -- config, shared/layers.lua).
    name = "ttc-manhole",
    icon = icons .. "manhole.png",
    recipes = {"ttc-manhole"}
  },
  {
    name = "ttc-reach-floor-4",
    icon = icons .. "power-connector.png",
    recipes = {"ttc-power-connector"}
  },
  {
    name = "ttc-reach-floor-5",
    icon = icons .. "carbide-drill-head.png",
    recipes = {"ttc-carbide-drill-head"}
  },
  {
    name = "ttc-mk3-bore",
    icon = icons .. "mk3-bore.png",
    recipes = {"ttc-mk3-bore"},
    -- Unlocked by the game's own trigger once enough steel has been made.
    trigger = {type = "craft-item", item = "steel-plate", count = 200}
  },
  {
    name = "ttc-reinforced-drill-head",
    icon = icons .. "reinforced-drill-head.png",
    recipes = {"ttc-reinforced-drill-head"},
    -- Unlocked by the game's own trigger once a few steel plates are made.
    trigger = {type = "craft-item", item = "steel-plate", count = 10}
  }
}

for index, technology in ipairs(technologies) do
  local effects = {}
  for _, recipe in ipairs(technology.recipes) do
    effects[#effects + 1] = {type = "unlock-recipe", recipe = recipe}
  end
  data:extend({
    {
      type = "technology",
      name = technology.name,
      icon = technology.icon,
      icon_size = 64,
      effects = effects,
      research_trigger = technology.trigger or {
        type = "scripted",
        trigger_description = {"ttc-trigger." .. technology.name},
        icon = technology.icon,
        icon_size = 64
      },
      order = string.format("a-%02d", index)
    }
  })
end

-- Hardened drill heads need plastic, so they come with it.
table.insert(data.raw.technology["plastics"].effects, {type = "unlock-recipe", recipe = "ttc-hardened-drill-head"})
