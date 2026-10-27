-- Item chutes and downpipes: one-way links to the floor below. Placing an
-- inlet creates its outlet directly below, which needs open ground there;
-- removing either end removes both. Every transfer tick items and fluid move
-- from the inlet to the outlet, never back.
local transfer_config = require("shared.transfer")
local layers = require("runtime.layers")
local tunnel = require("runtime.tunnel")

local inlet_kinds, outlet_kinds = {}, {}
for key, kind in pairs(transfer_config.kinds) do
  kind.key = key
  inlet_kinds[kind.inlet] = kind
  outlet_kinds[kind.outlet] = kind
end

local transfer = {}

-- Links by inlet unit number; outlets map back to their inlet.
local function links()
  storage.ttc.transfers = storage.ttc.transfers or {}
  return storage.ttc.transfers
end

local function outlets()
  storage.ttc.transfer_outlets = storage.ttc.transfer_outlets or {}
  return storage.ttc.transfer_outlets
end

function transfer.handles(entity)
  return inlet_kinds[entity.name] ~= nil or outlet_kinds[entity.name] ~= nil
end

local function refund(entity, kind, player, reason)
  local surface, position = entity.surface, entity.position
  entity.destroy()
  local stack = {name = kind.item, count = 1}
  if not (player and player.insert(stack) > 0) then
    surface.spill_item_stack({position = position, stack = stack, allow_belts = false})
  end
  if player then
    player.create_local_flying_text({text = {"ttc.transfer-" .. reason}, position = position})
  end
end

function transfer.on_built(entity, player)
  local kind = inlet_kinds[entity.name]
  if not kind then
    -- An outlet can only come from its inlet (e.g. not from a blueprint).
    if not outlets()[entity.unit_number] then
      refund(entity, outlet_kinds[entity.name], player, "outlet-alone")
    end
    return
  end

  local below = layers.below(entity.surface)
  local lower = below and game.surfaces[below.surface_name]
  if not lower then
    return refund(entity, kind, player, "no-floor-below")
  end
  local position = entity.position
  if not tunnel.is_open(lower, position)
    or not lower.can_place_entity({name = kind.outlet, position = position, force = entity.force}) then
    return refund(entity, kind, player, "blocked-below")
  end

  local outlet = lower.create_entity({name = kind.outlet, position = position, force = entity.force})
  links()[entity.unit_number] = {kind = kind.key, inlet = entity, outlet = outlet}
  outlets()[outlet.unit_number] = entity.unit_number
end

-- Removes the other end of a removed inlet or outlet. Its items go to the
-- mining player's buffer when there is one.
function transfer.on_removed(entity, buffer)
  local inlet_number = inlet_kinds[entity.name] and entity.unit_number or outlets()[entity.unit_number]
  local link = inlet_number and links()[inlet_number]
  if not link then
    return
  end
  links()[inlet_number] = nil
  if link.outlet.valid then
    outlets()[link.outlet.unit_number] = nil
  end

  local other = entity == link.inlet and link.outlet or link.inlet
  if not other.valid then
    return
  end
  local inventory = other.get_inventory(defines.inventory.chest)
  if inventory then
    for _, item in pairs(inventory.get_contents()) do
      local moved = buffer and buffer.insert(item) or 0
      if moved < item.count then
        other.surface.spill_item_stack({
          position = other.position,
          stack = {name = item.name, count = item.count - moved, quality = item.quality},
          allow_belts = false
        })
      end
    end
  end
  other.destroy()
end

local function move_items(link)
  local from = link.inlet.get_inventory(defines.inventory.chest)
  local to = link.outlet.get_inventory(defines.inventory.chest)
  for _, item in pairs(from.get_contents()) do
    local moved = to.insert(item)
    if moved > 0 then
      from.remove({name = item.name, count = moved, quality = item.quality})
    end
  end
end

local function move_fluid(link, kind)
  local fluid = link.inlet.get_fluid(1)
  if not fluid then
    return
  end
  local target = link.outlet.get_fluid(1)
  if target and target.name ~= fluid.name then
    return
  end
  local space = link.outlet.get_fluid_capacity(1) - (target and target.amount or 0)
  local amount = math.min(fluid.amount, space, kind.flow)
  if amount > 0 then
    link.outlet.add_fluid(1, link.inlet.remove_fluid(1, amount))
  end
end

function transfer.tick()
  for inlet_number, link in pairs(links()) do
    if not (link.inlet.valid and link.outlet.valid) then
      links()[inlet_number] = nil
    elseif link.kind == "item_chute" then
      move_items(link)
    else
      move_fluid(link, transfer_config.kinds[link.kind])
    end
  end
end

return transfer
