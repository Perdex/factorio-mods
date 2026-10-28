-- One-way transfers between floors, shared by the data and control stages.
-- Placing an inlet creates its outlet directly below on the next floor (or,
-- for the `up` kinds, directly above); things only move that one way.
return {
  kinds = {
    item_chute = {
      item = "ttc-item-chute",
      inlet = "ttc-item-chute",
      outlet = "ttc-item-chute-outlet"
    },
    downpipe = {
      item = "ttc-downpipe",
      inlet = "ttc-downpipe",
      outlet = "ttc-downpipe-outlet",
      -- Fluid moved per transfer tick (every 10 ticks): 1200/s.
      flow = 200
    },
    -- The first ways up: placed on the lower floor, their outlet opens on the
    -- floor above (or the starting surface).
    freight_lift = {
      item = "ttc-freight-lift",
      inlet = "ttc-freight-lift",
      outlet = "ttc-freight-lift-outlet",
      up = true
    },
    lift_pump = {
      item = "ttc-lift-pump",
      inlet = "ttc-lift-pump",
      outlet = "ttc-lift-pump-outlet",
      up = true,
      flow = 200
    },
    -- Electric poles; hidden energy interfaces under them draw power from the
    -- network above and supply it below.
    power = {
      item = "ttc-power-connector",
      inlet = "ttc-power-connector",
      outlet = "ttc-power-connector-outlet",
      sink = "ttc-power-connector-sink",
      source = "ttc-power-connector-source",
      -- Most power carried down: each interface buffers 10 ticks' worth.
      power = "10MW",
      buffer = "2MJ"
    }
  }
}
