local events = {}

---Drop-in replacement for script.on_event however it supports multiple handlers per event. You can also use 'on_built' 'on_destroyed' and 'on_init' as shortcuts for multiple events.
---@param event defines.events|defines.events[]|string
---@param f function
aisodoimod.on_event = function(event, f)
    for _, event in pairs(type(event) == "table" and event or {event}) do
        event = tostring(event)
        events[event] = events[event] or {}
        table.insert(events[event], f)
    end
end

aisodoimod.on_nth_tick = function(event, f)
    events[event] = events[event] or {}
    table.insert(events[event], f)
end

local function one_function_from_many(functions)
    local l = #functions
    if l == 1 then return functions[1] end

    return function(arg)
        for i = 1, l do
            functions[i](arg)
        end
    end
end

local finalized = false
aisodoimod.finalize_events = function()
    if finalized then error("Events already finalized") end
    local i = 0
    for event, functions in pairs(events) do
        local f = one_function_from_many(functions)
        if type(event) == "number" then
            script.on_nth_tick(event, f)
        elseif event == aisodoimod.events.on_init() then
            script.on_init(f)
            script.on_configuration_changed(f)
        else
            script.on_event(tonumber(event) or event, f)
        end
        i = i + 1
    end
    finalized = true
    log("Finalized " .. i .. " events for " .. script.mod_name)
end

--- Sentinel values for defining groups of events
aisodoimod.events = {
    --- Called after an entity is constructed.
    --- Note: Using this event may be bad practice. Consider instead defining `created_effect` in the entity prototype.
    ---
    --- entity.created_effect = {
    --- 	type = 'direct',
    --- 	action_delivery = {
    --- 		type = 'instant',
    --- 		source_effects = {
    --- 			type = 'script',
    --- 			effect_id = 'on_built_[ENTITY NAME]'
    --- 		}
    --- 	}
    --- }
    on_built = function()
        return {
            defines.events.on_built_entity,
            defines.events.on_robot_built_entity,
            defines.events.script_raised_built,
            defines.events.script_raised_revive,
            defines.events.on_space_platform_built_entity,
            defines.events.on_biter_base_built
        }
    end,
    --- Called after the results of an entity being mined are collected just before the entity is destroyed. [...]
    on_destroyed = function()
        return {
            defines.events.on_player_mined_entity,
            defines.events.on_robot_mined_entity,
            defines.events.on_entity_died,
            defines.events.script_raised_destroy,
            defines.events.on_space_platform_mined_entity
        }
    end,
    --- Called after a tile is built.
    on_built_tile = function()
        return {
            defines.events.on_robot_built_tile,
            defines.events.on_player_built_tile,
            defines.events.on_space_platform_built_tile,
        }
    end,
    on_mined_tile = function()
        return {
            defines.events.on_player_mined_tile,
            defines.events.on_robot_mined_tile,
            defines.events.on_space_platform_mined_tile,
        }
    end,
    --- Called for on_init and on_configuration_changed
    on_init = function()
        return "ON INIT EVENT"
    end,
    --- Custom event for when a player clicks on an entity
    on_entity_clicked = function()
        return "build"
    end
}
