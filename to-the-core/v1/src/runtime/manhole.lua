-- Manholes: holes to jump into. One goes over ground that is dug out on the
-- floor below; a character standing in it lands at the same spot down there,
-- and falls on through any manhole it lands in.
local layers = require("runtime.layers")
local transfer = require("runtime.transfer")
local tunnel = require("runtime.tunnel")

local manhole = {}

local name = "ttc-manhole"

function manhole.handles(entity)
  return entity.name == name
end

-- The floor below, if the ground under the hole's 2x2 tiles is dug out.
local function landing(surface, position)
  local below = layers.below(surface)
  local target = below and game.surfaces[below.surface_name]
  if not target then
    return nil, "transfer-no-floor-below"
  end
  for dx = -0.5, 0.5 do
    for dy = -0.5, 0.5 do
      if not tunnel.is_open(target, {x = position.x + dx, y = position.y + dy}) then
        return nil, "manhole-not-dug"
      end
    end
  end
  return target
end

function manhole.on_built(entity, player)
  local target, reason = landing(entity.surface, entity.position)
  if not target then
    local surface, position = entity.surface, entity.position
    entity.destroy()
    transfer.give_back(player, {name = name, count = 1}, surface, position)
    if player then
      player.create_local_flying_text({text = {"ttc." .. reason}, position = position})
    end
  end
end

local function check_player(player)
  local character = player.character
  if not character or player.vehicle then
    return
  end
  local position = character.position
  local hole = character.surface.find_entities_filtered({
    name = name,
    area = {{position.x - 0.1, position.y - 0.1}, {position.x + 0.1, position.y + 0.1}},
    limit = 1
  })[1]
  if not hole then
    return
  end
  local target = landing(hole.surface, hole.position)
  if not target then
    return
  end
  local spot = target.find_non_colliding_position("character", position, 3, 0.1) or position
  player.teleport(spot, target)
end

function manhole.check_falls()
  for _, player in pairs(game.connected_players) do
    check_player(player)
  end
end

return manhole
