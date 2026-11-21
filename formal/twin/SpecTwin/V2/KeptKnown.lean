import SpecTwin.V2.ReplayKnown

/-! # The v2 forms of `on_pace_tick`, `on_block_installed` and `respond`: their known answer

The cases were written before their forms in `V2/Kept.lean`. Each record is a JSON line in the tracer's form,
hand-built from protocol.md's Python of the functions and protocol-v2.md's `send_gossip`, or taken from a trace
under v2 and written in v2's forms. Each is replayed in two ways: `asV2` replays it with `runV2`, which runs the v2
forms, and `asV1` with `Replay.run`, which runs protocol.md's forms. A pass is a "fewer" count of 0, and a failure
an error that starts with the quoted prefix.

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

/-- The replay of one line with protocol.md's forms (`Replay.run`), its values read in v2's forms. -/
def asV1 (l : String) : Except String (Array String × Nat) := do
  run c0 [] tracedK (← record (← Json.parse l) docV2) [] .v2

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

/-! ## K5 to K7: `respond`

The record of K5 is a trace's: hand5 under protocol-v2.md has one record of `respond` that enqueues an IWANT. The
node asks peer 4 for chunk 0 of a group, with no answers and no prunes. The IWANT stands three times, in
`enqueue`'s argument, in the call's note of the normal lane, and in the record's writes. -/

/-- `respond`'s IWANT of chunk 0, in v2's form, or in `protocol.md`'s with `v1`. -/
def iwant0 (v1 : Bool) : String :=
  if v1 then s!"[\"iwant\", [[{gq}, 0]]]" else s!"[\"iwant\", [[[{gq}, 0], false, 0, false]], false]"

/-- A record of `respond` whose one enqueued entry, also the normal lane after it, is `entry`. -/
def responded (args entry : String) : String :=
  let lanes := s!"[[\"queue\", [4, \"normal\"], [{entry}]], [\"queue\", [4, \"urgent\"], []], [\"queue\", [4], true]]"
  line "respond" args "[]" lanes "[]"
    (s!"[[\"enqueue\", [4, [\"entry\", {entry}], false], true, " ++
     s!"\{\"cr\": [[\"queue\", [4, \"normal\"], null]], \"cw\": {lanes}}]]")
    (ret "null") "[\"respond\"]" "[\"queue\"]"

/-- The record with one ask and no answer: the entry is the control alone, an IWANT and an empty PRUNE. -/
def asked1 (v1 : Bool) : String :=
  responded s!"[4, [[{gq}, 0]], [], 0]" s!"[null, [{iwant0 v1}, [\"prune\", []]], false]"

-- K5: in v2's forms the record passes with `respond`'s v2 form; protocol.md's builds `.iwant`, which `enqueue`'s
-- argument does not hold
#guard fewer (asV2 (asked1 false)) == some 0
#guard failsWith "tape: " (asV1 (asked1 false))

-- K6: the record as protocol.md's forms write it is refused under v2, before anything runs
#guard failsWith "under protocol-v2.md an IWANT is [\"iwant\", asks, want]: " (asV2 (asked1 true))

/-- K7: one answer and no ask: the entry holds the chunk and no control, and the two forms agree. -/
def answered1 : String :=
  responded s!"[4, [], [{ReplayKnown.chunk3}], 0]" s!"[{ReplayKnown.chunk3}, null, true]"

#guard fewer (asV2 answered1) == some 0
#guard fewer (asV1 answered1) == some 0

end SpecTwin.V2.KeptKnown
