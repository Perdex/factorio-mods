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
    -- Iron heads come with the iron, but floor 2's walls don't pay for them:
    -- worth it for finding veins, not for digging out room.
    recipes = {"ttc-grinder", "ttc-winnower", "ttc-sort-iron-rich-rock", "ttc-iron-plate-from-granules",
      "ttc-iron-drill-head"}
  },
  {
    name = "ttc-iron-discovery",
    icon = "__base__/graphics/icons/iron-ore.png",
    recipes = {"ttc-mk2-bore"}
  },
  -- Drill heads come floor by floor: clay heads from floor 1, iron heads from
  -- floor 2 (where clay heads from floor 1 still do most of the digging),
  -- reinforced from floor 4, hardened from floor 5 and carbide from floor 6.
  {
    name = "ttc-reach-floor-3",
    icon = icons .. "core-drill.png",
    recipes = {"ttc-sort-copper-rich-rock", "ttc-copper-plate-from-granules"}
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
    icon = icons .. "reinforced-drill-head.png",
    recipes = {"ttc-power-connector", "ttc-reinforced-drill-head"}
  },
  {
    name = "ttc-reach-floor-5",
    icon = icons .. "hardened-drill-head.png",
    recipes = {"ttc-hardened-drill-head"}
  },
  {
    -- There is no floor 6 yet: out of reach for now.
    name = "ttc-reach-floor-6",
    icon = icons .. "carbide-drill-head.png",
    recipes = {"ttc-carbide-drill-head"}
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

-- The Mk3 bore needs bore coolant: first made with petroleum gas, so it comes
-- with oil processing; lubricant makes it cheaper later.
for technology, recipes in pairs({
  ["oil-processing"] = {"ttc-mk3-bore", "ttc-coolant-from-petroleum"},
  ["lubricant"] = {"ttc-coolant-from-lubricant"}
}) do
  for _, recipe in ipairs(recipes) do
    table.insert(data.raw.technology[technology].effects, {type = "unlock-recipe", recipe = recipe})
  end
end

