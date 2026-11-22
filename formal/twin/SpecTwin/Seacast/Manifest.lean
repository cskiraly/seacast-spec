/-! # seacast.md's manifest: what a trace under it holds, by name (generated)

This file is written whole by `tools/gen/gen.py` from `gen/manifest_seacast.py`, and `gen.py --check` compares it
byte for byte. Do not edit it: change the manifest, or the generator.

The lists by which the replay routes a record of a trace under `seacast.md`, and against which it reads the
trace's header and nodes line. `gen/manifest_seacast.py` says what each list holds, and the rules they keep. -/

namespace SpecTwin.Seacast.Manifest

/-- `seacast.md`'s functions the twin transcribes, each a record of its own. -/
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
   "on_pace_tick", "on_block_installed", "joined", "drop_wants_beyond"]

/-- `seacast-lite.md`'s functions a record under `seacast.md` may name, kept all the way down. -/
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

/-- `seacast.md`'s functions not transcribed this cycle: a question at every node. -/
def cut : List String :=
  ["window_release"]

/-- The twin's tables, `seacast-lite.md`'s and then `seacast.md`'s, by the names a trace gives them. -/
def own : List String :=
  ["asked_at", "tried", "offers", "promises", "offered", "park", "asked_parked", "last_resort_armed", "ihave_frames",
   "ihave_asked", "held_back", "received", "mine", "state", "tied", "queue", "pending", "pending_ids", "tie_slot",
   "owed", "owed_answers", "sent_to", "slot_held", "pace_queue", "stop_pull", "peer_has", "holders", "serve_count",
   "origin", "planned", "pushed", "desc", "in_flight", "waiters", "sent", "unwanted", "join_recv", "join_sent",
   "push_out", "push_in", "grafted_out", "grafted_in", "owed_relations", "backoff", "T_of", "rebuilt", "interest",
   "known_at", "standing", "routed_standing", "claims", "reconsider_at", "deferred", "duty_at", "waited", "probe",
   "probed", "probe_asks", "probe_sent", "probe_ok", "rsample", "rsample_step", "rsample_asked", "rsample_final",
   "served", "offered_to", "want_p", "probe_served", "probe_answers", "probe_waiting", "sampled_from",
   "samples_in_flight", "held_samples", "forwarded", "served_hb"]

/-- Other sections' tables that a covered function reads, answered from the tape. -/
def foreign : List String :=
  ["known_id", "chunks"]

/-- The names the replay of a trace under `seacast.md` reads as questions, answered from the tape. -/
def questions : List String :=
  ["accepted", "admitted", "after", "authenticable", "bid_group", "block_of", "choice", "close_promises_of_group",
   "connected", "cover_candidates", "deferred_offers", "deliver", "duty_for", "enqueue", "expired", "families",
   "families_with_duty", "floor_candidates", "floor_links", "group_bits", "has_room", "high_custody",
   "interest_satisfied", "link_cover", "links", "live", "mark_seen", "merge_waiting", "node_id", "open_group",
   "open_link", "open_sampling_link", "payload_of", "penalise", "release", "release_wanted_groups", "reserve",
   "route_next", "sample_without_replacement", "seen", "send", "shuffled", "start", "store", "type_of", "type_of_group",
   "valid_have", "wake", "wants_family", "DECODE_AT_K", "DECODE_LATER", "REPAIR_TO", "cross", "decode",
   "derived_interest", "family", "header_of", "index_count", "project", "threshold", "verify", "group_of",
   "open_group_source", "own_interest", "gossip_put", "mesh_has", "gossip_remove_group"]

/-- The questions that no covered function loads, each with its reason. -/
def questionsUnloaded : List (String × String) :=
  [("group_of", "loaded by seacast.md's code outside COVERED, on publish's path"),
   ("open_group_source", "loaded by seacast.md's code outside COVERED, on publish's path"),
   ("own_interest", "interest's miss, asked as a question")]

end SpecTwin.Seacast.Manifest
