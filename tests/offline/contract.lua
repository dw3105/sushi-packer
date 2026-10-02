-- Frozen contract table (SP-01): module -> { function name = arity }. Guard test and S0 stubs read this.
return {
  core = {
    new_box = 0, accept = 9, lane_room = 2, item_room = 5, used_slots = 1, free_slots = 1, on_tick = 3, flush_partials = 2,
    peek_out = 2, take_out = 3, remove_external = 4, adopt_external = 6, hold_items = 1,
    clear_hold = 1, totals = 1, led_state = 1, is_idle = 1,
  },
  belt_io = { behind = 2, front = 2, pull = 3, push = 5, belt_stack_size = 1, lane_rate = 1, behind_kinds = 2, set_tick = 1, can_push = 2, front_ok = 1, front_kind = 1 },
  led = { create = 1, set = 3, destroy = 1, ensure = 1 },
  registry = {
    on_built = 1, on_removed = 1, on_died = 1, get = 1,
    new_rec = 1, on_configuration_changed = 1, stash = 1, take_stash = 1, on_rotated = 1, migrate = 1,
  },
  copy = {
    default_settings = 0, export = 1, import = 2, on_setup_blueprint = 1,
    on_settings_pasted = 1, on_cloned = 1,
  },
  gui = { on_opened = 1, on_closed = 1, on_event = 1, open = 2, on_open_input = 1 },
  circuit = { compare = 3, evaluate = 1, sync = 1, apply = 1 },
  tick = { on_tick = 1, on_research = 1, timeout_ticks = 1, on_decon = 2, counters_on = 0, counters = 0 },
  filter = { match = 4 },
  ledger = { new = 0, plan = 4, hoard = 4, led = 3, scan = 4, hands = 4, steer = 2 },
  arms = { count = 1, create = 1, destroy = 2, pause = 3, skip = 3, ensure = 1, need_slot = 3,
    pause_out = 3, hand = 2, held = 2, clear_held = 3, drain_hands = 1,
    aim_out = 2, wire = 2, shut = 1, steer = 3 },
  sim = { scene = 1 },
}
