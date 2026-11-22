"""protocol-v2.md's manifest: what a trace under it holds, by name, beside schema_v2.py's tables.

gen.py writes it into SpecTwin/V2/Manifest.lean whole (its fourth generated file), and `gen.py --check` compares that
file byte for byte. The replay routes a record of a trace under protocol-v2.md by these lists, and reads the trace's
header and nodes line against them. The tracer's own lists under --doc v2 are to be these (trace3.py).

The lists:
- COVERED: protocol-v2.md's functions the twin transcribes, each a record of its own. The 66 that the cycle's 71
  call, main's `fill` and `serve_standing`, then `on_pace_tick` and `on_block_installed`, which protocol-v2.md
  redefines and the twin serves in their v2 forms.
- KEPT: protocol.md's functions that a record under protocol-v2.md may name: those protocol.md keeps all the way down
  under v2 (trace3.py's `v2_kept` over the toy's two documents), less §7.1's window and less NODE_OWN's names.
  `gen.py --check` computes the rule and compares.
- NODE_OWN: a traced name that is no function of either document but the node's own helper, which the twin has as
  its own code, with the helper's qualified name in the toy (`held`, §8's interface).
- REPLACEABLE: the traced names a node may run as something else (a fault, a variant). At such a node the name is a
  question, and the nodes line names it. They are the names a toy's wrapper changes the behaviour of, and
  `on_iwant`, which a withholder replaces.
- REPLACEABLE_WHOLE: the names replaceable only in a trace of the whole state (a directed set's), never in a cell's.
- CUT: protocol-v2.md's functions the twin does not transcribe this cycle: a question at every node.
- OWN: the twin's tables, protocol.md's (schema.py) and then protocol-v2.md's (schema_v2.py), by the names a trace
  gives them.
- FOREIGN: the tables of other sections that a covered function reads, which the twin answers from the tape.

The manifest's own rules, which `gen.py --check` holds it to: no list holds a name twice; COVERED and KEPT share no
name; NODE_OWN's keys are in neither; CUT's names are in no other list; REPLACEABLE_WHOLE is within KEPT.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))    # an isolated Python (-I) puts no directory there itself
import schema                                               # noqa: E402
import schema_v2                                            # noqa: E402

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
    "on_pace_tick", "on_block_installed"]

KEPT = [
    "K", "N", "add_offer", "announcers", "ask_parked", "build_group", "choose_push", "close_promises",
    "committed_descriptor", "drop_beyond", "drop_group", "drop_offer", "drop_stale_waits", "drop_tie", "expand",
    "group_id", "group_key", "guard_fails", "have_bits", "last_resort", "least_recently_tried", "ledger", "may_ask",
    "message_id", "on_iwant", "outstanding", "over_ihave_limits", "owe", "parked", "promise_due", "rarest", "respond",
    "retry_offer", "segment_length", "tie", "tie_room", "tied_to_root", "untried", "valid_descriptor", "valid_id",
    "validate_chunk", "with_owed"]

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
    "on_iwant"]             # a withholder's (check.py's withholders, silent, cap-wait)

REPLACEABLE_WHOLE = ["validate_chunk"]

CUT = ["window_release"]

OWN = [t.name for t in schema.TABLES] + [t.name for t in schema_v2.TABLES_V2]

# open: a third name can come only from the closure rule (every global a covered function loads); a table found in
# neither list is kept by the twin as state or joins this one
FOREIGN = ["known_id", "chunks"]

# the lists, in the order Manifest.lean has them, each with its Lean name and its doc comment there
LISTS = (("COVERED", "covered",
          "`protocol-v2.md`'s functions the twin transcribes, each a record of its own."),
         ("KEPT", "kept",
          "`protocol.md`'s functions a record under `protocol-v2.md` may name, kept all the way down."),
         ("NODE_OWN", "nodeOwn",
          "The node's own helpers among the traced names, with their qualified names in the toy."),
         ("REPLACEABLE", "replaceable",
          "The traced names a node may run as something else: a question there."),
         ("REPLACEABLE_WHOLE", "replaceableWhole",
          "The names replaceable only in a trace of the whole state."),
         ("CUT", "cut",
          "`protocol-v2.md`'s functions not transcribed this cycle: a question at every node."),
         ("OWN", "own",
          "The twin's tables, `protocol.md`'s and then `protocol-v2.md`'s, by the names a trace gives them."),
         ("FOREIGN", "foreign",
          "Other sections' tables that a covered function reads, answered from the tape."))
