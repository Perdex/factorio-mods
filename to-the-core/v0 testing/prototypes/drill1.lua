local F = "__Aisodoi-test__";

data:extend {
    {
        type = "mining-drill",
        name = "drill",
        localised_name = {"", "Drill"},
        icon = F .. "/graphics/drill-icon.png",
        icon_size = 64,
        flags = {"player-creation", "placeable-player"},
        resource_searching_radius = 2,
        --minable = false,-- {mining_time = 0.5, result = "stairs", count = 1},
        placeable_by = {item = "drill", count = 1},
        max_health = 2000,
        collision_box = {{-1.4, -0.9}, {1.4, 0.9}},
        selection_box = {{-1.4, -0.9}, {1.4, 0.9}},
        base_picture = {
            north = {
                layers = {
                    {
                        filename = F .. "/graphics/drill-right.png",
                        width = 400,
                        height = 200,
                        scale = 0.6,
                        shift = {0.2, -0.1},
                        draw_as_shadow = true
                    },
                    {
                        filename = F .. "/graphics/drill-right.png",
                        width = 400,
                        height = 200,
                        scale = 0.6,
                        shift = {0, 0}
                    }
                }
            },
        },
        window_bounding_box = {{0, 0}, {0, 0}},
        energy_source = "electric",
        energy_usage = "150kW",
        fluid_boxes = {
            {
                volume = 1,
                pipe_connections = {},
            }
        },
        show_recipe_icon = "false",
        ignore_output_full = "true",
        vector_to_place_result = {1.0, 0},
        flow_length_in_ticks = 1,
        circuit_wire_max_distance = 0,
        map_color = {r = 0.8, g = 0.7, b = 0.55}
    },
    {
        type = "item",
        name = "drill",
        icon = F .. "/graphics/drill-icon.png",
        icon_size = 64,
        subgroup = "aisodoimod",
        order = "a-a",
        weight = 100000000,
        place_result = "drill",
        stack_size = 1,
        flags = {"primary-place-result", "not-stackable"}
    },
    -- Crafting recipe
    {
        type = "recipe",
        name = "drill",
        localised_name = {"", "Drill"},
        enabled = true,
        ingredients = {
            {type = "item", name = "iron-plate",  amount = 1}
        },
        results = {{type = "item", name = "drill", amount = 1}},
    },
}
