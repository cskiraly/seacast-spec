import SpecTwin.Seacast.Replay

/-! # SEACAST's replay: its known answer

The replay's known answer, written before `Seacast/Replay.lean`.
Each record is a JSON line in the tracer's form, read by `Replay.record` with seacast.md's reading (`docSeacast`)
and replayed by `runSeacast`, with the node's constants built here. A case passes where `runSeacast` returns a "fewer"
count of 0, and fails where its error starts with the quoted prefix (and, for the order entry, holds the quoted words). A
planted case is the passing record with one change. -/

namespace SpecTwin.Seacast.ReplayKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.Seacast

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
/-- SEACAST's constants: a cap of 1 sample in flight per block, and no serving budget, which no record here meets -/
def c2 : ConstsSeacast :=
  { ANSWERS_FIRST := false, ASK_UPLINK := 50e6, MERGE_HOLDINGS := false, SAMPLE_OUTSTANDING := 1, SERVE_BUDGET := none }
/-- The type `row` has M = 4; no other type has parameters at the node. -/
def params : TypeId → Option TypeParams := fun T => if T == "row" then some { M := some 4 } else none
def traced : List String := fnsSeacast ++ keptSeacast

/-- A record's line: its fields as JSON text, in the tracer's order. -/
def line (fn args reads writes rest tape : String) (out : List (String × String)) (reached tables : String)
    (scans : String := "[]") : String :=
  let fs := [("n", "1"), ("t", "0"), ("fn", s!"\"{fn}\""), ("args", args), ("reads", reads), ("scans", scans),
             ("writes", writes), ("rest", rest), ("tape", tape)] ++ out ++
            [("reached", reached), ("tables", tables)]
  "{" ++ ", ".intercalate (fs.map fun (k, v) => s!"\"{k}\": {v}") ++ "}"

/-- The replay of one line at a node with these constants and replaced names, and these tables' rows read where
an access goes through them (a header's `row_reads`). -/
def replay (l : String) (c : Consts := c0) (replaced : List String := []) (rowReads : List String := []) :
    Except String (Array String × Nat) := do
  runSeacast c c2 params replaced traced (← record (← Json.parse l) docSeacast) rowReads

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

/-- `peer_has`'s entries in SEACAST's form, with the two claims; `lite` writes them in `seacast-lite.md`'s. -/
def reads4 (lite : Bool := false) : String :=
  let claims := if lite then "" else ", false, false"
  s!"[[\"mine\", [{gq}], 1], [\"push_in\", [5, \"row\", 0], [0]], [\"push_in\", [7, \"row\", 0], [1]], " ++
  s!"[\"claims\", [{gq}], null], [\"peer_has\", [5, {gq}], [2, 3{claims}]], [\"peer_has\", [7, {gq}], [4, 3{claims}]]]"
def tape4 (order : List String) : String :=
  "[" ++ ", ".intercalate ([s!"[\"type_of_group\", [{gq}], \"row\"]", s!"[\"family\", [\"row\", {gq}], 0]",
    "[\"links\", [\"row\"], [5, 7]]"] ++ order) ++ "]"
def r4 (order : List String) (lite : Bool := false) : String :=
  line "known_in_scope" s!"[{gq}]" (reads4 lite) "[]" "[]" (tape4 order) (ret "7")
    "[\"known_in_scope\", \"suppression_scope\"]" "[\"claims\", \"mine\", \"peer_has\", \"push_in\"]"

#guard passes (r4 ["[\"order\", \"known_in_scope\", [7, 5]]"])
-- `seacast-lite.md`'s form of a `peer_has` entry is refused under v2
#guard failsWith "not an entry of peer_has under seacast.md, [bits, ttl, claim_all, complete]: "
  (r4 ["[\"order\", \"known_in_scope\", [7, 5]]"] (lite := true))
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
-- the same key's text with the other kind: the twin raised on the group
#guard failsWith "the Python raises KeyError on type "
  (r6raise [("raises", "\"KeyError\""), ("raises_key", s!"[\"type\", {gq}]")])
#guard failsWith "crash: KeyError" (r6raise (ret "null"))

/-! ## Rows read on the way down: `tie(7, f)` under a view that logs them

seacast-lite.md's `tie`, which v2 keeps, on its path where the copy's group is tied for the peer already: it reads
`tied[root][7][g]` in `tie_room` and again to set the index, and the view logs the two rows the subscripts go
through, `tied[root]` and `tied[root][7]`, before the entry. With the rows named in `row_reads` the twin's
accesses read them too; without, the twin reads the entry alone, and the Python's two row reads are counted as
reads it did not make. -/

def rootq : String := s!"\"{root}\""
def rowsRead : String := s!"[\"tied\", [{rootq}], true], [\"tied\", [{rootq}, 7], true], "
def tie7 (rows : String) : String :=
  line "tie" s!"[7, {chunk3}]"
    (s!"[[\"desc\", [{gq}], null], " ++ rows ++
     s!"[\"tied\", [{rootq}, 7, {gq}], 1], [\"tie_slot\", [[{rootq}, 7]], 1]]")
    s!"[[\"tied\", [{rootq}, 7, {gq}], 9]]" "[]"
    s!"[[\"expired\", [{gq}], false], [\"live\", [1], true], [\"admitted\", [7, {chunk3}], true]]" (ret "null")
    "[\"close_promises\", \"tie\", \"tie_room\"]" "[\"desc\", \"promises\", \"tie_slot\", \"tied\"]"
    (scans := "[[\"promises\", []]]")

/-- The "fewer" count of a replay that passes, or none. -/
def fewer (l : String) (rowReads : List String) : Option Nat :=
  match replay l (rowReads := rowReads) with
  | .ok (_, n) => some n
  | .error _ => none

#guard fewer (tie7 rowsRead) rowTables == some 0
#guard fewer (tie7 rowsRead) [] == some 2
#guard match replay (tie7 "") (rowReads := rowTables) with
  | .error e => e.startsWith "footprint, reads: the twin reads an entry the Python did not read: " &&
                (e.splitOn "a row on its way down").length > 1
  | .ok _ => false
#guard fewer (tie7 "") [] == some 0

/-! ## The header's `row_reads` -/

def hdr (s : String) : Json := (Json.parse s).toOption.getD .null
def four : String := "[\"owed\", \"planned\", \"queue\", \"tied\"]"
def readsAs (l : List String) (s : String) : Bool :=
  match rowReadsOf (hdr s) with
  | .ok l' => l' == l
  | .error _ => false
def refused (pre : String) (s : String) : Bool :=
  match rowReadsOf (hdr s) with
  | .error e => e.startsWith pre
  | .ok _ => false

#guard readsAs rowTables s!"\{\"args\": [\"--doc\", \"v2\"], \"row_reads\": {four}}"
#guard readsAs rowTables s!"\{\"args\": [\"--doc=seacast\"], \"row_reads\": {four}}"
#guard readsAs [] "{\"args\": [\"--doc\", \"v2\"]}"
#guard readsAs [] "{\"args\": []}"
#guard readsAs rowTables s!"\{\"args\": [\"--doc\", \"seacast\"], \"row_reads\": {four}}"
#guard readsAs rowTables s!"\{\"args\": [\"--doc=v2\"], \"row_reads\": {four}}"
#guard refused "header: row_reads in a trace of seacast-lite.md" s!"\{\"args\": [\"--doc\", \"lite\"], \"row_reads\": {four}}"
#guard refused "header: row_reads in a trace of seacast-lite.md" s!"\{\"args\": [\"--doc\", \"v03\"], \"row_reads\": {four}}"
#guard refused "header: row_reads in a trace of seacast-lite.md" s!"\{\"args\": [], \"row_reads\": {four}}"
#guard refused "header: row_reads in a trace of seacast-lite.md" s!"\{\"row_reads\": {four}}"
#guard refused "header: row_reads in a trace of seacast-lite.md" s!"\{\"args\": [\"--doc\"], \"row_reads\": {four}}"
#guard refused "header: row_reads is not " "{\"args\": [\"--doc\", \"v2\"], \"row_reads\": [\"tied\"]}"
#guard refused "header: row_reads is not "
  "{\"args\": [\"--doc\", \"v2\"], \"row_reads\": [\"tied\", \"queue\", \"planned\", \"owed\"]}"
#guard refused "header: row_reads is not " "{\"args\": [\"--doc\", \"v2\"], \"row_reads\": true}"

end SpecTwin.Seacast.ReplayKnown
