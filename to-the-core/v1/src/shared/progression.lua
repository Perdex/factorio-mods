-- How base technologies unlock without science packs or labs. Shared by the
-- data and control stages; FLOORS.md has the plan behind it.
--
-- triggers: technology name -> one of
--   {floor = n}                researched once a shaft reaches floor n and the
--                              technology's prerequisites are done
--   {craft = item, count = n}  the game's own craft-item trigger
--   {craft_fluid = fluid, amount = n}  the game's own craft-fluid trigger
--   {build = entity}           the game's own build-entity trigger
--   {discover = item}          researched when a tunnel bore first digs the
--                              item up (`unlocks` in shared/layers.lua)
-- removed: technologies taken out of the tree (science packs, research speed).
--
-- Red, green, military and chemical (blue) science technologies are mapped;
-- production, utility and space science ones keep their costs and stay out
-- of reach until deeper floors exist.
return {
  removed = {
    "automation-science-pack",
    "logistic-science-pack",
    "military-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack",
    "space-science-pack",
    "research-speed-1",
    "research-speed-2",
    "research-speed-3",
    "research-speed-4",
    "research-speed-5",
    "research-speed-6",
    -- Uranium comes from digging, not from mining with fluid.
    "uranium-mining",
    -- Ore comes from digging, not mining drills.
    "electric-mining-drill"
  },

  -- Hidden along with the science technologies.
  removed_items = {
    "lab",
    "electric-mining-drill",
    "automation-science-pack",
    "logistic-science-pack",
    "military-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack",
    "space-science-pack"
  },

  triggers = {
    -- Floor 2: iron. (Steam power and electronics keep their base triggers:
    -- 50 iron plates and 10 copper plates.)
    ["automation"] = {craft = "iron-plate", count = 50},
    ["logistics"] = {craft = "transport-belt", count = 10},
    ["stone-wall"] = {craft = "stone-brick", count = 100},
    ["gate"] = {craft = "stone-wall", count = 100},

    -- Floor 3: copper and coal, the start of the green tier.
    ["radar"] = {floor = 3},
    ["logistics-2"] = {floor = 3},
    ["toolbelt"] = {floor = 3},
    -- No floor 9 yet: landfill stays out of reach for now.
    ["landfill"] = {floor = 9},
    ["repair-pack"] = {craft = "electronic-circuit", count = 50},
    ["lamp"] = {craft = "ttc-glass", count = 50},
    ["fast-inserter"] = {craft = "electronic-circuit", count = 100},
    ["circuit-network"] = {craft = "electronic-circuit", count = 200},

    -- Floor 4: steel, sulfur and oil; the green tier completes.
    ["steel-processing"] = {floor = 4},
    -- The first military technologies: enemies are to come from floor 4.
    ["military"] = {floor = 4},
    ["gun-turret"] = {floor = 4},
    ["physical-projectile-damage-1"] = {floor = 4},
    ["weapon-shooting-speed-1"] = {floor = 4},
    ["physical-projectile-damage-2"] = {craft = "firearm-magazine", count = 200},
    ["weapon-shooting-speed-2"] = {craft = "firearm-magazine", count = 200},
    ["heavy-armor"] = {craft = "steel-plate", count = 20},
    ["automation-2"] = {craft = "steel-plate", count = 50},
    ["electric-energy-distribution-1"] = {craft = "steel-plate", count = 50},
    ["military-2"] = {craft = "steel-plate", count = 50},
    ["engine"] = {craft = "steel-plate", count = 100},
    ["solar-energy"] = {craft = "steel-plate", count = 100},
    ["advanced-material-processing"] = {craft = "steel-plate", count = 200},
    ["concrete"] = {craft = "stone-brick", count = 1000},
    ["fluid-handling"] = {craft = "engine-unit", count = 10},
    ["automobilism"] = {craft = "engine-unit", count = 20},
    ["railway"] = {craft = "engine-unit", count = 50},
    ["automated-rail-transportation"] = {build = "locomotive"},
    ["fluid-wagon"] = {build = "cargo-wagon"},
    ["oil-gathering"] = {floor = 4},
    ["flammables"] = {floor = 4},
    ["plastics"] = {floor = 4},
    ["sulfur-processing"] = {floor = 4},
    ["explosives"] = {craft = "sulfur", count = 50},
    ["cliff-explosives"] = {craft = "explosives", count = 50},
    ["stronger-explosives-1"] = {craft = "grenade", count = 50},
    ["advanced-circuit"] = {craft = "plastic-bar", count = 100},

    -- Floor 5: into the blue tier.
    ["battery"] = {floor = 5},
    ["electric-energy-accumulators"] = {floor = 5},
    ["modules"] = {floor = 5},
    ["speed-module"] = {floor = 5},
    ["efficiency-module"] = {floor = 5},
    ["productivity-module"] = {floor = 5},
    ["mining-productivity-1"] = {floor = 5},
    ["bulk-inserter"] = {floor = 5},
    ["inserter-capacity-bonus-1"] = {floor = 5},
    ["inserter-capacity-bonus-2"] = {floor = 5},
    ["modular-armor"] = {floor = 5},
    ["solar-panel-equipment"] = {floor = 5},
    ["night-vision-equipment"] = {floor = 5},
    ["belt-immunity-equipment"] = {floor = 5},
    ["battery-equipment"] = {floor = 5},

    -- Military tier (the military science pack is gone): floor 4 and
    -- military crafting milestones.
    ["defender"] = {craft = "piercing-rounds-magazine", count = 200},
    ["follower-robot-count-1"] = {craft = "defender-capsule", count = 50},
    ["follower-robot-count-2"] = {craft = "defender-capsule", count = 150},
    ["energy-shield-equipment"] = {floor = 4},
    ["flamethrower"] = {floor = 4},
    ["refined-flammables-1"] = {craft = "flamethrower-ammo", count = 50},
    ["refined-flammables-2"] = {craft = "flamethrower-ammo", count = 200},
    ["land-mine"] = {craft = "explosives", count = 100},
    ["rocketry"] = {craft = "explosives", count = 200},
    ["physical-projectile-damage-3"] = {craft = "piercing-rounds-magazine", count = 300},
    ["physical-projectile-damage-4"] = {craft = "piercing-rounds-magazine", count = 1000},
    ["weapon-shooting-speed-3"] = {craft = "piercing-rounds-magazine", count = 300},
    ["weapon-shooting-speed-4"] = {craft = "piercing-rounds-magazine", count = 1000},
    ["stronger-explosives-2"] = {craft = "grenade", count = 200},

    -- Blue tier: blue crafting milestones from floor 4's oil and sulfur,
    -- and reaching floor 5.
    ["processing-unit"] = {craft = "advanced-circuit", count = 200},
    ["advanced-oil-processing"] = {craft = "plastic-bar", count = 500},
    ["lubricant"] = {craft_fluid = "heavy-oil", amount = 1000},
    ["electric-engine"] = {craft_fluid = "lubricant", amount = 1000},
    ["robotics"] = {craft = "electric-engine-unit", count = 50},
    ["construction-robotics"] = {craft = "flying-robot-frame", count = 20},
    ["logistic-robotics"] = {craft = "flying-robot-frame", count = 50},
    ["worker-robots-speed-1"] = {craft = "logistic-robot", count = 50},
    ["worker-robots-speed-2"] = {craft = "logistic-robot", count = 200},
    ["worker-robots-storage-1"] = {craft = "logistic-robot", count = 100},
    ["laser"] = {craft = "battery", count = 100},
    ["laser-turret"] = {craft = "battery", count = 300},
    ["low-density-structure"] = {craft = "steel-plate", count = 1000},
    ["advanced-combinators"] = {craft = "arithmetic-combinator", count = 50},
    ["braking-force-1"] = {craft = "locomotive", count = 5},
    ["braking-force-2"] = {craft = "locomotive", count = 20},
    ["efficiency-module-2"] = {craft = "processing-unit", count = 100},
    ["productivity-module-2"] = {craft = "processing-unit", count = 100},
    ["speed-module-2"] = {craft = "processing-unit", count = 100},
    ["rocket-fuel"] = {craft = "solid-fuel", count = 100},
    ["nuclear-power"] = {craft = "uranium-235", count = 1},
    ["uranium-processing"] = {discover = "uranium-ore"},
    ["advanced-material-processing-2"] = {floor = 5},
    ["electric-energy-distribution-2"] = {floor = 5},
    ["inserter-capacity-bonus-3"] = {floor = 5},
    ["mining-productivity-2"] = {floor = 5},
    ["military-3"] = {floor = 5},
    ["distractor"] = {floor = 5},
    ["tank"] = {floor = 5},
    ["explosive-rocketry"] = {floor = 5},
    ["follower-robot-count-3"] = {floor = 5},
    ["refined-flammables-3"] = {floor = 5},
    ["physical-projectile-damage-5"] = {floor = 5},
    ["weapon-shooting-speed-5"] = {floor = 5},
    ["stronger-explosives-3"] = {floor = 5},
    ["laser-shooting-speed-1"] = {floor = 5},
    ["laser-shooting-speed-2"] = {floor = 5},
    ["laser-shooting-speed-3"] = {floor = 5},
    ["laser-shooting-speed-4"] = {floor = 5},
    ["laser-weapons-damage-1"] = {floor = 5},
    ["laser-weapons-damage-2"] = {floor = 5},
    ["laser-weapons-damage-3"] = {floor = 5},
    ["laser-weapons-damage-4"] = {floor = 5},
    ["power-armor"] = {floor = 5},
    ["battery-mk2-equipment"] = {floor = 5},
    ["exoskeleton-equipment"] = {floor = 5},
    ["personal-roboport-equipment"] = {floor = 5},
    ["energy-shield-mk2-equipment"] = {floor = 5},
    ["discharge-defense-equipment"] = {floor = 5},
    ["personal-laser-defense-equipment"] = {floor = 5}
  }
}
