"""seacast.md's manifest: what a trace under it holds, by name, beside schema_seacast.py's tables.

gen.py writes it into SpecTwin/Seacast/Manifest.lean whole (its fourth generated file), and `gen.py --check` compares that
file byte for byte. The replay routes a record of a trace under seacast.md by these lists, and reads the trace's
header and nodes line against them. The tracer's own lists under --doc seacast are to be these (trace3.py).

The lists:
- COVERED: seacast.md's functions the twin transcribes, each a record of its own. The 66 that the cycle's 71
  call, main's `fill` and `serve_standing`, then `on_pace_tick` and `on_block_installed`, which seacast.md
  redefines and the twin serves in their v2 forms, then `joined` and `drop_wants_beyond`, which v0.11.1 adds on
  `on_holding`'s path and `fill`'s, then §4.5's serving: `index_bound`, `our_interest_for`, `outside`, §4.10's
  `route_want`, and `on_want`, then §4.1's relations and §6.3's limit on them: `relation_room`, `graft`, `on_prune`,
  `on_graft`, `maintain_relations` and `on_join`, then §4.11's window and writer: `wake_front`, `write_waits`,
  `free_room`, `acquire_room`, `leave_line`, `track_in_flight`, `window_release`, `window_timeout`, `noted` and
  `next_to_send`.
- KEPT: seacast-lite.md's functions that a record under seacast.md may name: those seacast-lite.md keeps all the way down
  under v2 (trace3.py's `seacast_kept` over the toy's two documents), less NODE_OWN's names. Of §7.1's window it
  holds `front` alone, which seacast.md's window calls unchanged.
  `gen.py --check` computes the rule and compares.
- NODE_OWN: a traced name that is no function of either document but the node's own helper, which the twin has as
  its own code, with the helper's qualified name in the toy (`held`, §8's interface).
- REPLACEABLE: the traced names a node may run as something else (a fault, a variant). At such a node the name is a
  question, and the nodes line names it. They are the names a toy's wrapper changes the behaviour of, and
  `on_iwant` and `on_want`, which a withholder replaces.
- REPLACEABLE_WHOLE: the names replaceable only in a trace of the whole state (a directed set's), never in a cell's.
- CUT: seacast.md's functions the twin does not transcribe this cycle: a question at every node.
- OWN: the twin's tables, seacast-lite.md's (schema.py) and then seacast.md's (schema_seacast.py), by the names a trace
  gives them.
- FOREIGN: the tables of other sections that a covered function reads, which the twin answers from the tape.
- QUESTIONS: the names the replay of a trace under seacast.md reads as questions, which the tracer tapes and
  the twin asks: the globals that covered functions load and that are answered from the tape, the callables of a
  type's parameters, the object type's functions, the context globals' uses by their tape names, and the names of
  QUESTIONS_UNLOADED. check.sh's scope step holds the list to the twin both ways: each name is read by an `askCall`
  or a case of the tape reader, and each name the twin asks or reads as a call under seacast.md is a question, a
  covered or cut function, or one of the replay's own entries (`keys`, `order`).
- QUESTIONS_UNLOADED: the questions that no covered function loads, each with its reason; a comparison of
  QUESTIONS with the covered functions' code leaves them out.

The manifest's own rules, which `gen.py --check` holds it to: no list holds a name twice; COVERED and KEPT share no
name; NODE_OWN's keys are in neither; CUT's names are in no other list; REPLACEABLE_WHOLE is within KEPT; QUESTIONS
shares no name with COVERED or KEPT, and holds no key of NODE_OWN; QUESTIONS_UNLOADED's keys are within QUESTIONS.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))    # an isolated Python (-I) puts no directory there itself
import schema                                               # noqa: E402
import schema_seacast                                            # noqa: E402

COVERED = [
    "colour_of", "send_relation", "send_join", "prune", "yes", "no", "queue_owed_relations", "interest_of_peer",
    "wants_from_me", "serves", "counted", "keep_coverage", "keep_floor",
    "fills", "note_push", "suppression_scope", "holding_of", "send_have", "announce", "announce_extra", "join_push",
    "source_pool", "unpush", "candidates_for_source", "origin_written", "offer_at_publish", "origin_acked",
    "send_gossip", "projected",
    "gated", "settle_probe", "probe_answer", "probe_promise", "probe_waits", "probe_settled", "probe_of_claim",
    "serve_probe", "serve_standing", "serve_waiting_probe", "known_in_scope", "known_across", "ask_custodian",
    "repair_verdict", "owed_missing",
    "push_rebuilt_as_source", "push_rebuilt", "fill", "arm", "check_completion", "defer_on_claim", "reconsider",
    "decode_group", "claims_close", "note_claim", "filter_entry",
    "forward", "on_validated", "defer", "on_chunk", "on_holding", "on_offer",
    "ask_scale", "own_chunk", "pick", "choose", "ask_sample", "resample", "sample",
    "on_pace_tick", "on_block_installed",
    "joined", "drop_wants_beyond",
    "index_bound", "our_interest_for", "outside", "route_want", "on_want",
    "relation_room", "graft", "on_prune", "on_graft", "maintain_relations", "on_join",
    "wake_front", "write_waits", "free_room", "acquire_room", "leave_line", "track_in_flight", "window_release",
    "window_timeout", "noted", "next_to_send"]

KEPT = [
    "K", "N", "add_offer", "announcers", "ask_parked", "build_group", "choose_push", "close_promises",
    "committed_descriptor", "drop_beyond", "drop_group", "drop_offer", "drop_stale_waits", "drop_tie", "expand",
    "front", "group_id", "group_key", "guard_fails", "have_bits", "last_resort", "least_recently_tried", "ledger",
    "may_ask", "message_id", "on_iwant", "outstanding", "over_ihave_limits", "owe", "parked", "promise_due", "rarest",
    "respond", "retry_offer", "segment_length", "tie", "tie_room", "tied_to_root", "untried", "valid_descriptor",
    "valid_id", "validate_chunk", "with_owed"]

NODE_OWN = {"held": "Node._namespace.<locals>.held"}

REPLACEABLE = [
    "forward",              # a silent node's; a scenario's
    "push_rebuilt",         # a silent node's, --rebuilt none, hold or announce, a cap, the repair variants, the hoards
    "send_have",            # --fault claim
    "serve_standing",       # --fault hoard, --alarm-wait
    "owed_missing",         # --member-check off
    "filter_entry",         # --promise-mode peer, --alarm-wait
    "repair_verdict",       # --repair-bias
    "decode_group",         # --rebuilt-seen on
    "note_claim",           # --keeper-claims ignore at a supernode
    "choose",               # --answers-first other than off and on
    "publish",              # --source-offers off and late
    "known_in_scope",       # the hand cases that rebind it (toy/*_known.py)
    "on_iwant",             # a withholder's (check.py's withholders, silent, cap-wait)
    "on_want",              # a withholder's, the hoarders' filters, --alarm-wait
    "acquire_room"]         # --answers-first line, for an answer its choose chose

REPLACEABLE_WHOLE = ["validate_chunk"]

CUT = []

# a table a record names by one of seacast-lite.md's names (`trace`: seacast.md's `sent`) is that name, once
OWN = [t.name for t in schema.TABLES] + [t.name for t in schema_seacast.TABLES_Seacast if not t.trace]

# closed for COVERED: closure_seacast.py classes every global a covered function loads at each v2 trace's start, and a
# table in neither OWN nor this list stops the tracer. KEPT is outside that rule, since the twin runs it as its own
# Lean; its functions load 11 globals the rule's classes would not take (HaveBitmap, IWANT, PRUNE,
# SegmentDescriptor, Shard, ceil, content_id, inf, is_have_bitmap, uint32_le, uint64_le).
FOREIGN = ["known_id", "chunks"]

QUESTIONS = [
    # the globals that covered functions load, classed as questions: each is answered from the tape
    "accepted", "admitted", "admitted_group", "after", "authenticable", "bid_group", "block_of", "candidates", "choice",
    "chunk_of", "close_promises_of_group", "connected", "cover_candidates", "deferred_offers", "deliver", "duty_for",
    "enqueue", "expired", "families", "families_with_duty", "floor_candidates", "floor_links", "group_bits", "has_room",
    "high_custody", "in_pushers", "interest_satisfied", "link_cover", "links", "live", "mark_seen", "merge_waiting",
    "node_id", "open_group", "open_link", "open_sampling_link", "our_join", "out_pushees", "own_id", "payload_of",
    "penalise", "release", "release_wanted_groups", "reserve", "resolve", "route_next", "runs_type",
    "sample_without_replacement", "seen", "send", "shuffled", "start", "store", "type_of", "type_of_group",
    "uplink_class", "valid_have", "wake", "wants_family",
    # §4.11's writer: the owed answer popped, an entry's bytes on the wire, the offers an entry carries
    "pop_owed_answer", "wire_size", "offers_in",
    # the callables of a type's parameters (`T.params`)
    "DECODE_AT_K", "DECODE_LATER", "REPAIR_TO",
    # the object type's functions, which covered functions call on a type
    "cross", "decode", "derived_interest", "family", "header_of", "index_count", "project", "threshold", "verify",
    # asked by the twin and loaded by no covered function: QUESTIONS_UNLOADED's
    "group_of", "open_group_source", "own_interest", "writing",
    # the context globals' uses, by their tape names: `gossip_history.put(f)` in forward, `p in mesh` in unpush, and
    # `gossip_history.remove_group(g)` in drop_group, a kept function the twin runs as its own
    "gossip_put", "mesh_has", "gossip_remove_group"]

QUESTIONS_UNLOADED = {
    "group_of": "loaded by seacast.md's code outside COVERED, on publish's path",
    "open_group_source": "loaded by seacast.md's code outside COVERED, on publish's path",
    "own_interest": "interest's miss, asked as a question",
    "writing": "asked by seacast-lite.md's front, a kept function the twin runs as its own"}

# the lists, in the order Manifest.lean has them, each with its Lean name and its doc comment there
LISTS = (("COVERED", "covered",
          "`seacast.md`'s functions the twin transcribes, each a record of its own."),
         ("KEPT", "kept",
          "`seacast-lite.md`'s functions a record under `seacast.md` may name, kept all the way down."),
         ("NODE_OWN", "nodeOwn",
          "The node's own helpers among the traced names, with their qualified names in the toy."),
         ("REPLACEABLE", "replaceable",
          "The traced names a node may run as something else: a question there."),
         ("REPLACEABLE_WHOLE", "replaceableWhole",
          "The names replaceable only in a trace of the whole state."),
         ("CUT", "cut",
          "`seacast.md`'s functions not transcribed this cycle: a question at every node."),
         ("OWN", "own",
          "The twin's tables, `seacast-lite.md`'s and then `seacast.md`'s, by the names a trace gives them."),
         ("FOREIGN", "foreign",
          "Other sections' tables that a covered function reads, answered from the tape."),
         ("QUESTIONS", "questions",
          "The names the replay of a trace under `seacast.md` reads as questions, answered from the tape."),
         ("QUESTIONS_UNLOADED", "questionsUnloaded",
          "The questions that no covered function loads, each with its reason."))
