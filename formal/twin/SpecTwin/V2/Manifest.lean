/-! # protocol-v2.md's manifest: what a trace under it holds, by name (generated)

This file is written whole by `tools/gen/gen.py` from `gen/manifest_v2.py`, and `gen.py --check` compares it
byte for byte. Do not edit it: change the manifest, or the generator.

The lists by which the replay routes a record of a trace under `protocol-v2.md`, and against which it reads the
trace's header and nodes line. `gen/manifest_v2.py` says what each list holds, and the rules they keep. -/

namespace SpecTwin.V2.Manifest

/-- `protocol-v2.md`'s functions the twin transcribes, each a record of its own. -/
def covered : List String :=
  ["colour_of", "send_relation", "send_join", "prune", "yes", "no", "queue_owed_relations", "interest_of_peer",
   "wants_from_me", "serves", "counted", "keep_coverage", "keep_floor", "fills", "note_push", "suppression_scope",
   "holding_of", "send_have", "announce", "announce_extra", "join_push", "source_pool", "unpush",
   "candidates_for_source", "origin_written", "offer_at_publish", "origin_acked", "send_gossip", "projected", "gated",
   "settle_probe", "probe_answer", "probe_promise", "probe_waits", "probe_settled", "probe_of_claim", "serve_probe",
   "serve_standing", "serve_waiting_probe", "known_in_scope", "known_across", "ask_custodian", "repair_verdict",
   "owed_missing", "push_rebuilt_as_source", "push_rebuilt", "fill", "arm", "check_completion", "defer_on_claim",
   "reconsider", "decode_group", "claims_close", "note_claim", "filter_entry", "forward", "on_validated", "defer",
   "on_chunk", "on_holding", "on_offer", "ask_scale", "own_chunk", "pick", "choose", "ask_sample", "resample", "sample",
   "on_pace_tick", "on_block_installed"]

/-- `protocol.md`'s functions a record under `protocol-v2.md` may name, kept all the way down. -/
def kept : List String :=
  ["K", "N", "add_offer", "announcers", "ask_parked", "build_group", "choose_push", "close_promises",
   "committed_descriptor", "drop_beyond", "drop_group", "drop_offer", "drop_stale_waits", "drop_tie", "expand",
   "group_id", "group_key", "guard_fails", "have_bits", "last_resort", "least_recently_tried", "ledger", "may_ask",
   "message_id", "on_iwant", "outstanding", "over_ihave_limits", "owe", "parked", "promise_due", "rarest", "respond",
   "retry_offer", "segment_length", "tie", "tie_room", "tied_to_root", "untried", "valid_descriptor", "valid_id",
   "validate_chunk", "with_owed"]

/-- The node's own helpers among the traced names, with their qualified names in the toy. -/
def nodeOwn : List (String × String) :=
  [("held", "Node._namespace.<locals>.held")]

/-- The traced names a node may run as something else: a question there. -/
def replaceable : List String :=
  ["forward", "push_rebuilt", "send_have", "serve_standing", "owed_missing", "filter_entry", "repair_verdict",
   "decode_group", "note_claim", "choose", "publish", "known_in_scope", "on_iwant"]

/-- The names replaceable only in a trace of the whole state. -/
def replaceableWhole : List String :=
  ["validate_chunk"]

/-- `protocol-v2.md`'s functions not transcribed this cycle: a question at every node. -/
def cut : List String :=
  ["window_release"]

/-- The twin's tables, `protocol.md`'s and then `protocol-v2.md`'s, by the names a trace gives them. -/
def own : List String :=
  ["asked_at", "tried", "offers", "promises", "offered", "park", "asked_parked", "last_resort_armed", "ihave_frames",
   "ihave_asked", "held_back", "received", "mine", "state", "tied", "queue", "pending", "pending_ids", "tie_slot",
   "owed", "owed_answers", "sent_to", "slot_held", "pace_queue", "stop_pull", "peer_has", "holders", "serve_count",
   "origin", "planned", "pushed", "desc", "in_flight", "waiters", "sent", "unwanted", "join_recv", "join_sent",
   "push_out", "push_in", "grafted_out", "grafted_in", "owed_relations", "backoff", "T_of", "rebuilt", "interest",
   "known_at", "standing", "claims", "reconsider_at", "deferred", "duty_at", "waited", "probe", "probed", "probe_asks",
   "probe_sent", "probe_ok", "rsample", "rsample_step", "rsample_asked", "rsample_final", "served", "want_p",
   "probe_served", "probe_answers", "probe_waiting", "sampled_from", "samples_in_flight", "held_samples", "forwarded"]

/-- Other sections' tables that a covered function reads, answered from the tape. -/
def foreign : List String :=
  ["known_id", "chunks"]

end SpecTwin.V2.Manifest
