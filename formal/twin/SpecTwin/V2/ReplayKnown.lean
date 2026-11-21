import SpecTwin.V2.Replay

/-! # v2's replay: its known answer

The replay's known answer, written before `V2/Replay.lean`.
Each record is a JSON line in the tracer's form, read by `Replay.record` with protocol-v2.md's reading (`docV2`)
and replayed by `runV2`, with the node's constants built here. A case passes where `runV2` returns a "fewer"
count of 0, and fails where its error starts with the quoted prefix (and, for the order entry, holds the quoted words). A
planted case is the passing record with one change. -/

namespace SpecTwin.V2.ReplayKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.V2

/-- A group's key, a root, and the structured id of chunk 3 of the group: the group, the index's four bytes
little-endian, a content id. -/
def g : String := String.ofList (List.replicate 64 'a')
def root : String := String.ofList (List.replicate 64 'b')
def id3 : String := g ++ "03000000" ++ String.ofList (List.replicate 40 '0')
def gq : String := s!"\"{g}\""
def chunk3 : String := s!"[{gq}, 3, 1, \"{root}\", \"{id3}\"]"

def c0 : Consts :=
  { IWANT_WINDOW := 0.2, RETRY_SLACK := 0.05, PROMISE := 1.0, PARK_TTL := 3.0, MAX_PLAIN_CHUNKS := 256,
    UPLINK := 10e6 }
def c2 : ConstsV2 := { ANSWERS_FIRST := false, ASK_UPLINK := 50e6, MERGE_HOLDINGS := false }
/-- The type `row` has M = 4; no other type has parameters at the node. -/
def params : TypeId → Option TypeParams := fun T => if T == "row" then some { M := some 4 } else none
def traced : List String := fnsV2 ++ keptV2

/-- A record's line: its fields as JSON text, in the tracer's order. -/
def line (fn args reads writes rest tape : String) (out : List (String × String)) (reached tables : String) :
    String :=
  let fs := [("n", "1"), ("t", "0"), ("fn", s!"\"{fn}\""), ("args", args), ("reads", reads), ("scans", "[]"),
             ("writes", writes), ("rest", rest), ("tape", tape)] ++ out ++
            [("reached", reached), ("tables", tables)]
  "{" ++ ", ".intercalate (fs.map fun (k, v) => s!"\"{k}\": {v}") ++ "}"

/-- The replay of one line at a node with these constants and replaced names. -/
def replay (l : String) (c : Consts := c0) (replaced : List String := []) : Except String (Array String × Nat) := do
  runV2 c c2 params replaced traced (← record (← Json.parse l) docV2)

def passes (l : String) (c : Consts := c0) (replaced : List String := []) : Bool :=
  match replay l c replaced with
  | .ok (_, 0) => true
  | _ => false

def failsWith (pre : String) (l : String) (c : Consts := c0) (replaced : List String := []) : Bool :=
  match replay l c replaced with
  | .error e => e.startsWith pre
  | .ok _ => false

def failsHolding (pre words : String) (l : String) : Bool :=
  match replay l with
  | .error e => e.startsWith pre && (e.splitOn words).length > 1
  | .ok _ => false

def ret (j : String) : List (String × String) := [("ret", j)]

/-! ## A function with no table and no question: `ask_scale()` -/

def r1 (ret' : String) : String := line "ask_scale" "[]" "[]" "[]" "[]" "[]" (ret ret') "[\"ask_scale\"]" "[]"

#guard passes (r1 "4617315517961601024")                                     -- 5.0
#guard failsWith "return value: toy " (r1 "4616189618054758400")             -- 4.0
#guard passes (line "ask_scale" "[]" "[]" "[]" "[]" "[]" [("raises", "\"ZeroDivisionError\"")] "[\"ask_scale\"]" "[]")
  { c0 with UPLINK := 0 }

/-! ## A type parameter and a question: `colour_of(g, 6)` -/

def r2 (tape : String) : String :=
  line "colour_of" s!"[{gq}, 6]" "[]" "[]" "[]" tape (ret "2") "[\"colour_of\"]" "[]"
def asked2 (T : String) : String := s!"[\"type_of_group\", [{gq}], \"{T}\"]"

#guard passes (r2 s!"[{asked2 "row"}]")
#guard failsWith "crash: AttributeError" (r2 s!"[{asked2 "column"}]")
#guard failsWith "tape: type_of_group" (r2 "[]")
#guard failsWith "tape: the toy asked more: " (r2 s!"[{asked2 "row"}, {asked2 "row"}]")

/-! ## Reads of own tables: `own_chunk(e)` of a push -/

def e3 : String := s!"[{chunk3}, null, false]"

#guard passes (line "own_chunk" s!"[{e3}]" s!"[[\"received\", [{gq}], 1], [\"rebuilt\", [{gq}], 2]]" "[]" "[]" "[]"
  (ret "true") "[\"own_chunk\"]" "[\"rebuilt\", \"received\"]")
#guard failsWith "footprint, reads: the twin reads an entry the Python did not read: "
  (line "own_chunk" s!"[{e3}]" s!"[[\"received\", [{gq}], 1]]" "[]" s!"[[\"rebuilt\", [{gq}], 2]]" "[]"
    (ret "true") "[\"own_chunk\"]" "[\"received\"]")

/-! ## An order entry: `known_in_scope(g)` -/

def reads4 : String :=
  s!"[[\"mine\", [{gq}], 1], [\"push_in\", [5, \"row\", 0], [0]], [\"push_in\", [7, \"row\", 0], [1]], " ++
  s!"[\"claims\", [{gq}], null], [\"peer_has\", [5, {gq}], [2, 3]], [\"peer_has\", [7, {gq}], [4, 3]]]"
def tape4 (order : List String) : String :=
  "[" ++ ", ".intercalate ([s!"[\"type_of_group\", [{gq}], \"row\"]", s!"[\"family\", [\"row\", {gq}], 0]",
    "[\"links\", [\"row\"], [5, 7]]"] ++ order) ++ "]"
def r4 (order : List String) : String :=
  line "known_in_scope" s!"[{gq}]" reads4 "[]" "[]" (tape4 order) (ret "7")
    "[\"known_in_scope\", \"suppression_scope\"]" "[\"claims\", \"mine\", \"peer_has\", \"push_in\"]"

#guard passes (r4 ["[\"order\", \"known_in_scope\", [7, 5]]"])
#guard passes (r4 ["[\"order\", \"known_in_scope\", [5, 7]]"])
#guard failsHolding "tape: " "is not of the twin's rows" (r4 ["[\"order\", \"known_in_scope\", [9, 5]]"])
#guard failsHolding "tape: " "asked" (r4 [])

/-! ## A replaced name: `fill`'s call of `send_have` -/

def r5 : String :=
  line "fill" s!"[{gq}, 3, {chunk3}, 5]"
    (s!"[[\"T_of\", [{gq}], \"row\"], [\"state\", [{gq}], null], [\"received\", [{gq}], 8], " ++
     s!"[\"deferred\", [{gq}], null]]") "[]" "[]"
    s!"[[\"expired\", [{gq}], false], [\"send_have\", [5, {gq}], null]]" (ret "null")
    "[\"fill\", \"probe_answer\"]" "[\"T_of\", \"deferred\", \"received\", \"state\"]"

#guard passes r5 (replaced := ["send_have"])
#guard failsWith "tape: " r5 (replaced := [])
#guard failsWith "a record of send_have at a node that has replaced it"
  (line "send_have" s!"[5, {gq}]" "[]" "[]" "[]" "[]" (ret "null") "[\"send_have\"]" "[]") (replaced := ["send_have"])

/-! ## A set table's member: `settle_probe(g, None)` -/

def probeOk : String := s!"[\"probe_ok\", [{gq}], [\"none\"]]"
def asks5 (v : String) : String := s!"[\"probe_asks\", [[{gq}, 5]], {v}]"

def r6 (writes rest tables : String) : String :=
  line "settle_probe" s!"[{gq}, null]" s!"[[\"probe\", [{gq}], 5]]" writes rest "[]" (ret "null") "[\"settle_probe\"]"
    tables
def r6raise (out : List (String × String)) : String :=
  line "settle_probe" s!"[{gq}, null]" s!"[[\"probe\", [{gq}], null]]" s!"[{probeOk}]" "[]" "[]" out
    "[\"settle_probe\"]" "[\"probe\", \"probe_ok\"]"

#guard passes (r6 s!"[{probeOk}, {asks5 "null"}]" "[]" "[\"probe\", \"probe_asks\", \"probe_ok\"]")
#guard passes (r6 s!"[{probeOk}, {asks5 "null"}]" s!"[{asks5 "true"}]" "[\"probe\", \"probe_asks\", \"probe_ok\"]")
#guard failsWith "footprint, writes: the twin writes an entry the Python neither read nor wrote: "
  (r6 s!"[{probeOk}]" "[]" "[\"probe\", \"probe_ok\"]")
#guard passes (r6raise [("raises", "\"KeyError\""), ("raises_key", s!"[\"group\", {gq}]")])
#guard failsWith "crash: KeyError" (r6raise (ret "null"))

end SpecTwin.V2.ReplayKnown
