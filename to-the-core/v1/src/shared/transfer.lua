-- One-way transfers to the floor below, shared by the data and control stages.
-- Placing an inlet on a floor creates its outlet directly below on the next
-- floor; things only ever move down. (Lifting things up comes on floors 4-5.)
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
    }
  }
}
