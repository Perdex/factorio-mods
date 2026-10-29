-- Links between a floor and the one below it, shared by the data and control
-- stages. Placing a link's top end creates its bottom end directly below on
-- the next floor; things only move one way: down, or for the `up` kinds from
-- the bottom end up to the top one.
local transfer = {
  -- The base game's underground belts and pipes-to-ground are replaced by a
  -- down and an up end each, so going under something means routing it
  -- through the floor below. Tiers missing from the game are skipped.
  undergrounds = {"underground-belt", "fast-underground-belt", "express-underground-belt", "turbo-underground-belt"},
  kinds = {
    pipe_down = {
      item = "ttc-pipe-down",
      top = "ttc-pipe-down",
      bottom = "ttc-pipe-down-outlet",
      -- Fluid moved per transfer tick (every 10 ticks): 1200/s.
      flow = 200
    },
    pipe_up = {
      item = "ttc-pipe-up",
      top = "ttc-pipe-up",
      bottom = "ttc-pipe-up-inlet",
      up = true,
      flow = 200
    },
    -- Electric poles; hidden energy interfaces under them draw power from the
    -- network above and supply it below.
    power = {
      item = "ttc-power-connector",
      top = "ttc-power-connector",
      bottom = "ttc-power-connector-outlet",
      sink = "ttc-power-connector-sink",
      source = "ttc-power-connector-source",
      -- Most power carried down: each interface buffers 10 ticks' worth.
      power = "10MW",
      buffer = "2MJ"
    }
  }
}

-- Linked belts, one pair per underground belt tier: items keep their lane.
-- `belt` names the underground belt a kind replaces.
for _, underground in ipairs(transfer.undergrounds) do
  for _, way in ipairs({"down", "up"}) do
    local name = "ttc-" .. underground .. "-" .. way
    transfer.kinds[underground .. "-" .. way] = {
      item = name,
      top = name,
      bottom = name .. (way == "down" and "-outlet" or "-inlet"),
      belt = underground,
      up = way == "up"
    }
  end
end

-- The two items that replace each base game item.
transfer.replaced = {["pipe-to-ground"] = {"ttc-pipe-down", "ttc-pipe-up"}}
for _, underground in ipairs(transfer.undergrounds) do
  transfer.replaced[underground] = {"ttc-" .. underground .. "-down", "ttc-" .. underground .. "-up"}
end

return transfer
