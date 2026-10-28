-- Drill head wear in the furnace-type digging machines (tunnel bore, core
-- drill). Inserting a head picks its dig recipe; one craft is one head's
-- whole life, so its hits accrue with the crafting progress. Each whole hit
-- rolls the rock's drops, which wait in `state.pending` until they fit in the
-- machine's output.
local wear = {}

-- The dig recipe in use, or between heads the one last used.
local function recipe_name(entity)
  local recipe = entity.get_recipe()
  if recipe then
    return recipe.name
  end
  local previous = entity.previous_recipe
  local name = previous and previous.name
  -- A recipe ID reads back as its prototype.
  if name and type(name) ~= "string" then
    name = name.name
  end
  return name
end

function wear.new_state(entity)
  return {
    products_finished = entity.products_finished,
    dealt = 0,
    total = 0,
    paid = 0,
    pending = {}
  }
end

-- Advances the hit count from the machine's progress. `recipe_heads` maps
-- dig recipe names to drill heads. Returns the hits dealt since the last
-- call (fractional) and how many whole hits that completed.
function wear.update(state, entity, recipe_heads)
  local current = recipe_name(entity)
  local head = recipe_heads[current]
  local finished = entity.products_finished
  -- Worn-out heads plus the wear on the one in use. A recipe change restarts
  -- the craft, so any progress since then already belongs to the new head.
  local dealt = head and (finished + entity.crafting_progress) * head.durability or 0
  if state.recipe_name ~= current then
    state.recipe_name = current
    state.dealt = head and finished * head.durability or 0
  end
  local delta = math.max(0, dealt - state.dealt)
  state.dealt = dealt
  state.products_finished = finished

  -- Whole hits, with a little slack: summed fractional progress drifts.
  state.total = state.total + delta
  local whole = math.floor(state.total + 0.001) - state.paid
  state.paid = state.paid + whole
  return delta, whole
end

-- Rolls `hits` hits' worth of drops: {name, chance, minimum, maximum} each.
function wear.roll(state, drops, hits)
  for _ = 1, hits do
    for _, drop in ipairs(drops) do
      if math.random() < drop.chance then
        state.pending[drop.name] = (state.pending[drop.name] or 0) + math.random(drop.minimum, drop.maximum)
      end
    end
  end
end

-- Moves pending drops into the output, counting them as produced. Returns
-- whether all of them fit, and whether any were delivered.
function wear.deliver(state, entity)
  local output = entity.get_output_inventory()
  local statistics = entity.force.get_item_production_statistics(entity.surface)
  local all, any = true, false
  for name, count in pairs(state.pending) do
    local inserted = output.insert({name = name, count = count})
    if inserted > 0 then
      statistics.on_flow(name, inserted)
      any = true
    end
    if inserted < count then
      state.pending[name] = count - inserted
      all = false
    else
      state.pending[name] = nil
    end
  end
  return all, any
end

return wear
