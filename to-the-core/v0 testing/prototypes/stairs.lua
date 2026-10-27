local F = "__Aisodoi-test__";

data:extend {
    {
        type = "rocket-silo",
        name = "stairs",
        localised_name = {"", "Stairs"},
        icon = F .. "/graphics/stairs-icon.png",
        icon_size = 100,
        flags = {"player-creation", "placeable-player"},
        --minable = false,-- {mining_time = 0.5, result = "stairs", count = 1},
        placeable_by = {item = "stairs", count = 1},
        max_health = 2000,
        collision_box = {{-2.4, -0.9}, {2.4, 1.4}},
        selection_box = {{-2.4, -1.4}, {2.4, 1.4}},
        pictures = {
            picture = {
                layers = {
                    --[[{
                        filename = F .. "/graphics/stairs.png",
                        width = 400,
                        height = 200,
                        scale = 0.6,
                        shift = {0, 0.2},
                        draw_as_shadow = true
                    },]]
                    {
                        filename = F .. "/graphics/stairs.png",
                        width = 400,
                        height = 200,
                        scale = 0.6,
                        shift = {0, 0}
                    }
                }
            },
        },
        window_bounding_box = {{0, 0}, {0, 0}},
        fluid_box = {
            volume = 1,
            pipe_connections = {},
        },
        flow_length_in_ticks = 1,
        circuit_wire_max_distance = 0,
        map_color = {r = 0.8, g = 0.7, b = 0.55}
    },
    {
        type = "item",
        name = "stairs",
        icon = F .. "/graphics/stairs-icon.png",
        icon_size = 100,
        subgroup = "aisodoimod",
        order = "a-a",
        weight = 100000000,
        place_result = "stairs",
        stack_size = 1,
        flags = {"primary-place-result", "not-stackable"}
    },
    -- recipe
    {
        type = "recipe",
        name = "stairs",
        localised_name = {"", "Stairs"},
        enabled = true,
        ingredients = {
            {type = "item", name = "iron-plate",  amount = 1}
        },
        results = {{type = "item", name = "drill", amount = 1}},
    },
}
