import SpecTwin.Seacast.ReplayKnown
import SpecTwin.Seacast.FormsRows

/-! # A chunk where seacast.md writes it narrow: its guards

seacast.md's writer writes a chunk wide, with a sixth member (what level 1 reads of it), only where it arrives or
waits: `on_chunk`, `on_validated` and `defer`'s arguments, and the encoder's other wide places, which the twin reads
with `chunkF` as before. Everywhere else it writes five members, and there a sixth is refused, with "a chunk here is
narrow, five members: ". The places, each guarded below:
1. `decode`'s answer;
2. a read of `chunks`;
3. a queue entry's chunk;
4. the chunk arguments of the covered records but the three wide ones, and of `message_id`, `tie_room` and
   `choose_push`, which seacast-lite.md's run reads under the v2 form;
5. `respond`'s answers.

Each place refuses a six-member chunk and does not refuse the same chunk with five members. The guards use only the
places themselves, so that they build at the code before the narrow reader, and fail there at each refusal. Under
seacast-lite.md nothing changes: the same three kept records and a queue entry read six members as before. -/

namespace SpecTwin.Seacast.NarrowKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.Seacast
open SpecTwin.Seacast.ReplayKnown (g gq root id3 chunk3 c0 line replay ret traced)

/-- The same chunk with a sixth member, what level 1 reads of it: no descriptor, no proof, a blob. -/
def chunk6 : String := s!"[{gq}, 3, 1, \"{root}\", \"{id3}\", [null, [], [16, \"x\"]]]"

def narrow : String := "a chunk here is narrow, five members: "

/-- Whether `x` failed with the narrow reader's words. -/
def isNarrow {α} (x : Except String α) : Bool :=
  match x with
  | .error e => (e.splitOn narrow).length > 1
  | .ok _ => false

def parse (s : String) : Json := (Json.parse s).toOption.getD Json.null

-- the reader of a chunk anywhere reads six members, as before
#guard (chunkF (parse chunk6)).isOk && (chunkF (parse chunk3)).isOk

/-! ## 1. `decode`'s answer, asked as a record's tape asks it (FormsRows' row) -/

def decodeRow (c : String) : Json := parse s!"[\"decode\", [\"row\", {gq}, null], [[3, {c}]]]"
def decodeAsk (c : String) : Except String Json := do
  let row := decodeRow c
  let .ok (.arr args) := row.getArrVal? 1 | throw "no arguments"
  FormsRows.onTape [row] (← FormsRows.askOf "decode" args Json.null)   -- the answer is an order's alone

#guard isNarrow (decodeAsk chunk6)
#guard (decodeAsk chunk3).isOk

/-! ## 2. A read of `chunks` -/

#guard isNarrow (chunksReadSeacast (parse s!"[{gq}, 3]") (parse chunk6))
#guard (chunksReadSeacast (parse s!"[{gq}, 3]") (parse chunk3)).isOk

/-! ## 3. A queue entry's chunk, under each document -/

#guard isNarrow (qentry (parse s!"[{chunk6}, null, false]") .v2)
#guard (qentry (parse s!"[{chunk3}, null, false]") .v2).isOk
#guard (qentry (parse s!"[{chunk6}, null, false]") .v1).isOk         -- seacast-lite.md's, as before

/-! ## 4 and 5. Records' chunk arguments and `respond`'s answers, replayed by `runSeacast` -/

/-- A record of `fn` with these arguments and nothing else: what a refusal of its arguments needs. -/
def rec1 (fn args : String) : String := line fn args "[]" "[]" "[]" "[]" (ret "null") s!"[\"{fn}\"]" "[]"

/-- Each covered record whose chunk the writer writes narrow, and the kept three under the v2 form, with the chunk
`c` as its argument. -/
def narrowRecords (c : String) : List (String × String) :=
  [("candidates_for_source", s!"[{c}]"), ("origin_written", s!"[{c}]"), ("serve_probe", s!"[2, {gq}, {c}]"),
   ("push_rebuilt_as_source", s!"[{gq}, [[3, {c}]]]"), ("fill", s!"[{gq}, 3, {c}, null]"),
   ("forward", s!"[{c}, 2]"), ("forward", s!"[{c}, 2, null]"), ("respond", s!"[2, [], [{c}], 0]"),
   ("message_id", s!"[{c}]"), ("tie_room", s!"[2, {c}]"), ("choose_push", s!"[{c}, [2, 3], 1, false]")]

#guard (narrowRecords chunk6).all fun (fn, a) => isNarrow (replay (rec1 fn a))
#guard (narrowRecords chunk3).all fun (fn, a) => !isNarrow (replay (rec1 fn a))

-- where a chunk arrives or waits it is read wide, as before
def wideRecords (c : String) : List (String × String) :=
  [("on_chunk", s!"[2, {c}]"), ("on_validated", s!"[2, {c}, \"ACCEPT\"]"), ("defer", s!"[2, {c}]")]
#guard (wideRecords chunk6).all fun (fn, a) => !isNarrow (replay (rec1 fn a))

/-- The same record replayed under seacast-lite.md: its run with seacast-lite.md's form. -/
def replayV1 (l : String) : Except String (Array String × Nat) := do
  run c0 [] traced (← record (← Json.parse l)) [] .v1

-- the kept three under seacast-lite.md read six members, as before
#guard [("message_id", s!"[{chunk6}]"), ("tie_room", s!"[2, {chunk6}]"),
        ("choose_push", s!"[{chunk6}, [2, 3], 1, false]")].all fun (fn, a) => !isNarrow (replayV1 (rec1 fn a))

end SpecTwin.Seacast.NarrowKnown
