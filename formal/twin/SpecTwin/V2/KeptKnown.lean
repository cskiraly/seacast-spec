import SpecTwin.V2.ReplayKnown

/-! # The v2 forms of `on_pace_tick` and `on_block_installed`: their known answer

The cases were written before `V2/Kept.lean`. Each record is a JSON line in the tracer's form, hand-built from
protocol.md's Python of the two functions and protocol-v2.md's `send_gossip`. Each is replayed in two ways:
`asV2` replays it with `runV2`, which runs the v2 forms, and `asV1` with `Replay.run`, which runs protocol.md's
forms. A pass is a "fewer" count of 0, and a failure an error that starts with the quoted prefix.

A node's `traced` names hold the two functions. The type `column` has `ANNOUNCE_EXTRA` at `ALL_JOINED`, so v2's
`send_gossip` offers nothing of a group of that type. -/

namespace SpecTwin.V2.KeptKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.V2
open SpecTwin.V2.ReplayKnown (g gq rootq id3 c0 c2 params line ret)

def paramsK : TypeId → Option TypeParams := fun T =>
  if T == "column" then some { ANNOUNCE_EXTRA := some .allJoined } else params T
def tracedK : List String := fnsV2 ++ keptV2 ++ keptFormsV2

/-- The replay of one line with the v2 forms (`runV2`). -/
def asV2 (l : String) : Except String (Array String × Nat) := do
  runV2 c0 c2 paramsK [] tracedK (← record (← Json.parse l) docV2)

/-- The replay of one line with protocol.md's forms (`Replay.run`). -/
def asV1 (l : String) : Except String (Array String × Nat) := do
  run c0 [] tracedK (← record (← Json.parse l) docV2)

def fewer (x : Except String (Array String × Nat)) : Option Nat :=
  match x with
  | .ok (_, n) => some n
  | .error _ => none

def failsWith (pre : String) (x : Except String (Array String × Nat)) : Bool :=
  match x with
  | .error e => e.startsWith pre
  | .ok _ => false

/-! ## K1 and K2: `on_pace_tick` -/

def emptyQueue : String := "[\"pace_queue\", [\"jobs\"], null]"

/-- K1: the queue is empty. -/
def k1 : String :=
  line "on_pace_tick" "[]" s!"[{emptyQueue}]" "[]" "[]" "[]" (ret "null") "[\"on_pace_tick\"]" "[\"pace_queue\"]"

#guard fewer (asV2 k1) == some 0

/-- K2: one job, of chunk 3 of the group, queued at time 0 for peer 5, which is connected. The time is 0, within
a heartbeat of the job. v2's `send_gossip` asks the group's type, which offers nothing. -/
def k2 : String :=
  line "on_pace_tick" "[]" s!"[[\"pace_queue\", [\"jobs\"], [[5, [\"{id3}\"], 0]]]]" s!"[{emptyQueue}]" "[]"
    (s!"[[\"connected\", [5], true], [\"group_bits\", [[\"{id3}\"]], [[{gq}, 8]]], " ++
     s!"[\"type_of_group\", [{gq}], \"column\"]]")
    (ret "null") "[\"on_pace_tick\", \"send_gossip\"]" "[\"pace_queue\"]"

#guard fewer (asV2 k2) == some 0
#guard failsWith "tape: " (asV1 k2)

/-! ## K3 and K4: `on_block_installed` with nothing pending and nothing tied, and no connected topic peer -/

/-- A record of `on_block_installed(root)` whose bid answers `bid`, with these names reached. The pops read the
root's rows, and `tied`'s pop scans its level, as the tracer's views log a pop. -/
def installed (bid reached : String) : String :=
  line "on_block_installed" s!"[{rootq}]" s!"[[\"pending\", [{rootq}], null], [\"tied\", [{rootq}], null]]" "[]"
    "[]" s!"[[\"bid_group\", [{rootq}], {bid}], [\"connected_topic_peers\", [], []]]" (ret "null") reached
    "[\"pending\", \"tied\"]" (scans := s!"[[\"tied\", [{rootq}]]]")

/-- K3: no bid, so the Python calls `ledger(None)`. -/
def k3 : String := installed "null" "[\"ledger\", \"on_block_installed\"]"

#guard fewer (asV2 k3) == some 0
#guard failsWith "reached: the twin entered" (asV1 k3)
#guard failsWith "reached: the twin entered" (asV2 (installed "null" "[\"on_block_installed\"]"))

/-- K4: a bid of the group, whose ledger finds nothing: the two forms agree. -/
def k4 : String := installed gq "[\"ledger\", \"on_block_installed\"]"

#guard fewer (asV2 k4) == some 0
#guard fewer (asV1 k4) == some 0

end SpecTwin.V2.KeptKnown
