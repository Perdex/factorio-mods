-- Links to the floor below (shared/transfer.lua): underground belts and
-- pipes-to-ground going down or coming up, and power connectors. Placing a
-- top end creates its bottom end directly below, which needs open ground
-- there; if it can't, the top end goes back into the player's hand. Removing
-- either end removes both. Belt ends are linked belts, so items cross at belt
-- speed on their own lane; every transfer tick fluid or energy moves along
-- the link, never back.
local transfer_config = require("shared.transfer")
local layers = require("runtime.layers")
local tunnel = require("runtime.tunnel")

local top_kinds, bottom_kinds = {}, {}
for key, kind in pairs(transfer_config.kinds) do
  if prototypes.entity[kind.top] then
    kind.key = key
    top_kinds[kind.top] = kind
    bottom_kinds[kind.bottom] = kind
  end
end

local transfer = {}

-- Links by top unit number; bottom ends map back to their top.
local function links()
  storage.ttc.transfers = storage.ttc.transfers or {}
  -- Saves from when links had an inlet and an outlet (power connectors).
  local old_outlets = storage.ttc.transfer_outlets
  if old_outlets then
    storage.ttc.transfer_bottoms = old_outlets
    storage.ttc.transfer_outlets = nil
    for _, link in pairs(storage.ttc.transfers) do
      link.top, link.bottom, link.inlet, link.outlet = link.inlet, link.outlet, nil, nil
    end
  end
  return storage.ttc.transfers
end

local function bottoms()
  storage.ttc.transfer_bottoms = storage.ttc.transfer_bottoms or {}
  return storage.ttc.transfer_bottoms
end

function transfer.handles(entity)
  return top_kinds[entity.name] ~= nil or bottom_kinds[entity.name] ~= nil
end

-- Puts the item back in the player's hand (or inventory), else on the ground.
function transfer.give_back(player, stack, surface, position)
  if player then
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name == stack.name
      and cursor.count < cursor.prototype.stack_size then
      cursor.count = cursor.count + 1
      return
    end
    if cursor and not cursor.valid_for_read and cursor.set_stack(stack) then
      return
    end
    if player.insert(stack) > 0 then
      return
    end
  end
  surface.spill_item_stack({position = position, stack = stack, allow_belts = false})
end

local function refund(entity, kind, player, reason)
  local surface, position = entity.surface, entity.position
  entity.destroy()
  transfer.give_back(player, {name = kind.item, count = 1}, surface, position)
  if player then
    player.create_local_flying_text({text = {"ttc.transfer-" .. reason}, position = position})
  end
end

-- Belt ends: the down kinds take items in at the top, the up kinds at the
-- bottom; both ends face the same way.
local function link_belts(kind, top, bottom)
  top.disconnect_linked_belts()
  top.linked_belt_type = kind.up and "output" or "input"
  bottom.linked_belt_type = kind.up and "input" or "output"
  bottom.direction = top.direction
  top.connect_linked_belts(bottom)
end

function transfer.on_built(entity, player)
  local kind = top_kinds[entity.name]
  if not kind then
    -- A bottom end only comes from its top end (e.g. not from a blueprint).
    if not bottoms()[entity.unit_number] then
      refund(entity, bottom_kinds[entity.name], player, "bottom-alone")
    end
    return
  end

  local below = layers.below(entity.surface)
  local target = below and game.surfaces[below.surface_name]
  if not target then
    return refund(entity, kind, player, "no-floor-below")
  end
  local position = entity.position
  if not tunnel.is_open(target, position)
    or not target.can_place_entity({name = kind.bottom, position = position, direction = entity.direction,
      force = entity.force}) then
    return refund(entity, kind, player, "blocked-below")
  end

  local bottom = target.create_entity({name = kind.bottom, position = position, direction = entity.direction,
    force = entity.force})
  local link = {kind = kind.key, top = entity, bottom = bottom}
  if kind.belt then
    link_belts(kind, entity, bottom)
    link.direction = entity.direction
  end
  if kind.sink then
    link.sink = entity.surface.create_entity({name = kind.sink, position = position, force = entity.force})
    link.source = target.create_entity({name = kind.source, position = position, force = entity.force})
  end
  links()[entity.unit_number] = link
  bottoms()[bottom.unit_number] = entity.unit_number
end

local function link_of(entity)
  local top_number = top_kinds[entity.name] and entity.unit_number or bottoms()[entity.unit_number]
  return top_number and links()[top_number], top_number
end

-- Turning either belt end turns both, keeping the link. The link remembers
-- its direction, so whichever end no longer matches it was turned.
local function sync_direction(link, kind)
  if link.top.direction == link.direction and link.bottom.direction == link.direction then
    return
  end
  if link.top.direction == link.direction then
    link.top.direction = link.bottom.direction
  end
  link.direction = link.top.direction
  link_belts(kind, link.top, link.bottom)
end

function transfer.on_rotated(entity)
  local link = link_of(entity)
  local kind = link and transfer_config.kinds[link.kind]
  if kind and kind.belt and link.top.valid and link.bottom.valid then
    sync_direction(link, kind)
  end
end

-- Items still on a belt end, or in a chest.
local function contents(entity)
  if entity.type == "linked-belt" then
    local items = {}
    for index = 1, entity.get_max_transport_line_index() do
      for _, item in pairs(entity.get_transport_line(index).get_contents()) do
        items[#items + 1] = item
      end
    end
    return items
  end
  local inventory = entity.get_inventory(defines.inventory.chest)
  return inventory and inventory.get_contents() or {}
end

-- Removes the other end of a removed top or bottom end. Its items go to the
-- mining player's buffer when there is one.
function transfer.on_removed(entity, buffer)
  local link, top_number = link_of(entity)
  if not link then
    return
  end
  links()[top_number] = nil
  if link.bottom.valid then
    bottoms()[link.bottom.unit_number] = nil
  end
  for _, hidden in ipairs({link.sink, link.source}) do
    if hidden.valid then
      hidden.destroy()
    end
  end

  local other = entity == link.top and link.bottom or link.top
  if not other.valid then
    return
  end
  for _, item in ipairs(contents(other)) do
    local moved = buffer and buffer.insert(item) or 0
    if moved < item.count then
      other.surface.spill_item_stack({
        position = other.position,
        stack = {name = item.name, count = item.count - moved, quality = item.quality},
        allow_belts = false
      })
    end
  end
  other.destroy()
end

local function move_fluid(from, to, kind)
  local fluid = from.get_fluid(1)
  if not fluid then
    return
  end
  local target = to.get_fluid(1)
  if target and target.name ~= fluid.name then
    return
  end
  local space = to.get_fluid_capacity(1) - (target and target.amount or 0)
  local amount = math.min(fluid.amount, space, kind.flow)
  if amount > 0 then
    to.add_fluid(1, from.remove_fluid(1, amount))
  end
end

local function move_energy(link)
  local moved = math.min(link.sink.energy, link.source.electric_buffer_size - link.source.energy)
  if moved > 0 then
    link.sink.energy = link.sink.energy - moved
    link.source.energy = link.source.energy + moved
  end
end

function transfer.tick()
  for top_number, link in pairs(links()) do
    local kind = transfer_config.kinds[link.kind]
    if not (kind and link.top and link.top.valid and link.bottom and link.bottom.valid) then
      -- Also drops links from saves with the old chutes and lifts.
      links()[top_number] = nil
    elseif kind.belt then
      -- Script turns raise no event.
      sync_direction(link, kind)
    elseif kind.sink then
      move_energy(link)
    elseif kind.flow then
      if kind.up then
        move_fluid(link.bottom, link.top, kind)
      else
        move_fluid(link.top, link.bottom, kind)
      end
    end
  end
end

return transfer
