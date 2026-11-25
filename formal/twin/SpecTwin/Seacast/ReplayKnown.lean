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

/-! ## §4.5's serving: `on_want`, `outside`, `index_bound`, `our_interest_for`, and §4.10's `route_want`

Hand-written records, each written from the Python's order of reads and questions, and each passing with "fewer" 0
and exactly the branch labels it was written for, in order:
- one per branch label of `on_want` (16), `outside` (6) and `route_want` (5);
- the decisions inside an exit that change a read, a question or a write: an ask made a probe by the frame's probe
  of its place, a probe of an id answered already, of an id p does not want, an answer on our offer, a DECLARED
  peer's routed ask, a probe or a standing ask where p's probe of the index is kept, a routed standing ask not passed
  on, two answers in their order, a DECLARED peer's bit already set, the probe answered and the DECLARED peer's WANT;
- `route_want` with several links in order, one parked, and a fallback past a link that does not forward;
- `index_bound` at its bounds, known and not, and without the parameter; `our_interest_for`'s three cases;
- each `KeyError` of a missing JOIN, as the Python raises it. No call through `on_want` reaches one in the toy, since
  `links(T)` needs both JOINs (toy/node.py:1399-1402) and `on_want` makes these lookups only past `joined`. A direct
  call of `outside`, `our_interest_for` or `route_want` can reach the lookup of p's JOIN. Each is a record of what the
  Python does in that state.

Several must fail: a wrong return, a question out of order, a record of `on_want` at a node that replaced it, and the
four questions' answers that their readers refuse by their own checks.

What a record shows, and what it does not: the replay holds the twin to the record's questions in order, its return
or raise, its writes and the cells it read. It does not show how many times a cell was read, in what order, or when
a write fell between two questions. Those come from reading the Python against the Lean, line by line (the
source-order audit), which each piece repeats. The questions here are stubbed by their tape entries, so their own
effects (`admitted_group`'s, a sent WANT's) are not part of these records. Peer 4 asks index 3 of g, of the type
`row`. -/

namespace Serve

/-- The type `row`: M = 4, a serving limit of 2, at most 8 indices before a group's count is known, and one routed
request passed on per link; `column` the same; `payload`, with parameters but no `MAX_INDICES` -/
def params1 : TypeId → Option TypeParams := fun T =>
  if T == "row" || T == "column" then
    some { M := some 4, SERVE_LIMIT := some 2.0, MAX_INDICES := some 8, FORWARD_LIMIT := some 1.0 }
  else if T == "payload" then some { M := some 1 }
  else none

def replay1 (l : String) (c2' : ConstsSeacast := c2) (replaced : List String := []) :
    Except String (Array String × Nat) := do
  runSeacast c0 c2' params1 replaced traced (← record (← Json.parse l) docSeacast) []

/-- The record passes, with no read of the Python's left unmade, through these branch labels in order -/
def takes (l : String) (marks : List String) (c2' : ConstsSeacast := c2) : Bool :=
  match replay1 l c2' with
  | .ok (ms, 0) => ms.toList == marks
  | _ => false

def fails1 (pre : String) (l : String) (replaced : List String := []) : Bool :=
  match replay1 l (replaced := replaced) with
  | .error e => e.startsWith pre
  | .ok _ => false

def arrL (xs : List String) : String := "[" ++ ", ".intercalate xs ++ "]"
def quoted (xs : List String) : String := arrL (xs.map (s!"\"{·}\""))

/-- The tables a record's reads and writes name, sorted, as its `tables` -/
def tablesIn (xs : List String) : String :=
  let names := xs.foldl (fun acc s => match Json.parse s with
    | .ok (Json.arr a) => acc ++ a.toList.filterMap fun (e : Json) => match e with
      | Json.arr b => match (b[0]? : Option Json) with
        | some (Json.str t) => some t
        | _ => none
      | _ => none
    | _ => acc) []
  quoted (names.eraseDups.toArray.qsort (· < ·)).toList

/-- A record with nothing in its rest, its reached names sorted and its tables those its reads and writes name -/
def rec1 (fn args : String) (reads writes tape : List String) (out : List (String × String)) (reached : List String) :
    String :=
  line fn args (arrL reads) (arrL writes) "[]" (arrL tape) out (quoted (reached.toArray.qsort (· < ·)).toList)
    (tablesIn [arrL reads, arrL writes])

def jn (i d : String) : String := s!"[\"join\", \"row\", \"{i}\", 0, \"{d}\", 1]"
def tog : String := s!"[\"type_of_group\", [{gq}], \"row\"]"
def linksQ (ps : String) : String := s!"[\"links\", [\"row\"], {ps}]"
def expQ (b : String) : String := s!"[\"expired\", [{gq}], {b}]"
def authQ (b : String) : String := s!"[\"authenticable\", [{gq}], {b}]"
def admQ (b : String) : String := s!"[\"admitted_group\", [4, {gq}], {b}]"
def ak (i : Nat) : String := s!"[{gq}, {i}]"
def resQ (i : Nat) (r : String) : String := s!"[\"resolve\", [{ak i}], {r}]"
def id3q : String := s!"\"{id3}\""
def chunkQ : String := s!"[\"chunk_of\", [{id3q}], {chunk3}]"
def penQ : String := "[\"penalise\", [4], null]"
def rd (t path v : String) : String := s!"[\"{t}\", {path}, {v}]"
def askOf (i : Nat) (st : Bool := false) (hops : Nat := 0) (probe : Bool := false) : String :=
  s!"[{ak i}, {st}, {hops}, {probe}]"
def pg (p : Nat) : String := s!"[{p}, {gq}]"
def pT (p : Nat) : String := s!"[{p}, \"row\"]"
def gp : String := s!"[{gq}]"
def gi3 : String := s!"[{gq}, 3]"
def gp4 : String := s!"[{gq}, 4]"
def desc2 : String := s!"[2, 0, 1, 2, 11660, 11660, \"{root}\"]"
def nid : String := "\"7fec7acb96f018d21bd2b8790a5e680a21afe7f53cce623525328929af3c6436\""
def choice5 : String := "[\"choice\", [[5]], 5]"
def sendQ (hops : Nat) (r : String) (q : Nat := 5) : String :=
  s!"[\"send\", [{q}, [\"want\", {gq}, 8, true, {hops}, false], false], {r}]"
/-- Chunk 5 of g, stored: a second answer -/
def id5 : String := g ++ "05000000" ++ String.ofList (List.replicate 40 '0')
def id5q : String := s!"\"{id5}\""
def chunk5 : String := s!"[{gq}, 5, 1, \"{root}\", \"{id5}\"]"
def chunkQ5 : String := s!"[\"chunk_of\", [{id5q}], {chunk5}]"
/-- A column group whose index 2 is the cell the row group g holds at index 3. The toy stores the one chunk at both
places, under the id of its native place, the column's (`store` and `resolve`, toy/node.py:660-662 and :707-713;
`COL.project`, :1275), so `resolve` gives both asks that id -/
def gH : String := String.ofList (List.replicate 64 'c')
def hq : String := s!"\"{gH}\""
def idH2 : String := gH ++ "02000000" ++ String.ofList (List.replicate 40 '0')
def idH2q : String := s!"\"{idH2}\""
def chunkH2 : String := s!"[{hq}, 2, 1, \"{root}\", \"{idH2}\"]"
def jnT (T i d : String) : String := s!"[\"join\", \"{T}\", \"{i}\", 0, \"{d}\", 1]"
def togH : String := s!"[\"type_of_group\", [{hq}], \"column\"]"
/-- The IEEE-754 bits of 1.0: a park until then, past the record's now of 0 -/
def oneBits : String := "4607182418800017408"

/-! ### on_want -/

/-- The reads of one ask on the plain path to the serving limit: no count known, a link of duty NONE and interest
ALL each way, nothing held or claimed, `served` as given -/
def readsTo (served : String := "null") : List String :=
  [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "null",
   rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "peer_has" (pg 4) "null", rd "served" (pg 4) served]
/-- Its questions up to `resolve`: joined's type and links, expired, index_bound's type, the hops' type, outside's
type and authenticable, our_interest_for's type, admitted_group, declared's type, the serving limit's type -/
def tapeTo : List String :=
  [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", tog, admQ "true", tog, tog]
def reachedTo : List String := ["on_want", "joined", "index_bound", "outside", "our_interest_for", "probe_of_claim"]
/-- The reads after `resolve` of an answer counted against the budget -/
def readsAnswer (hb : String := "null") : List String :=
  [rd "unwanted" "[4]" "null", rd "serve_count" s!"[4, {id3q}]" "null", rd "offered_to" (pg 4) "null",
   rd "served_hb" "[4]" hb]
def writesAnswer : List String :=
  [rd "served_hb" "[4]" "1", rd "serve_count" s!"[4, {id3q}]" "1", rd "served" (pg 4) "1"]
def inInterest : String := "outside: in our interest"

-- answered, on the plain path
def w1 : String :=
  rec1 "on_want" s!"[4, [{askOf 3}]]" (readsTo ++ readsAnswer) writesAnswer (tapeTo ++ [resQ 3 id3q, chunkQ])
    (ret s!"[{chunk3}]") reachedTo
#guard takes w1 [inInterest, "on_want: answered"]
-- an index answered in this frame: the same place asked again by its structured id
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}, [{id3q}, false, 0, false]]]" (readsTo ++ readsAnswer) writesAnswer
    (tapeTo ++ [resQ 3 id3q, chunkQ]) (ret s!"[{chunk3}]") reachedTo)
  [inInterest, "on_want: answered", "on_want: an index answered in this frame"]
-- a type the link has not joined
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]" [] [] [tog, linksQ "[5]"] (ret "[]") ["on_want", "joined"])
  ["on_want: a type the link has not joined"]
-- expired
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]" [] [] [tog, linksQ "[4]", expQ "true"] (ret "[]") ["on_want", "joined"])
  ["on_want: expired"]
-- an index the group cannot have: 8, at MAX_INDICES 8 with no count known (indices 0 to 7), as the toy's own known
-- answer asks it (toy/want_bounds_known.py)
#guard takes (rec1 "on_want" s!"[4, [{askOf 8}]]" [rd "desc" gp "null"] [] [tog, linksQ "[4]", expQ "false", tog]
    (ret "[]") ["on_want", "joined", "index_bound"])
  ["on_want: an index the group cannot have"]
-- the same at a known count: 4 indices, and index 4 asked
#guard takes (rec1 "on_want" s!"[4, [{askOf 4}]]" [rd "desc" gp desc2] []
    [tog, linksQ "[4]", expQ "false", tog, s!"[\"index_count\", [\"row\", {desc2}], 4]"]
    (ret "[]") ["on_want", "joined", "index_bound"])
  ["on_want: an index the group cannot have"]
-- outside what we serve p: our JOIN to p DECLARED, so our interest for it is EMPTY, and p claims nothing
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "DECLARED" "NONE"), rd "origin" gp "null", rd "mine" gp "null",
     rd "peer_has" (pg 4) "null"] []
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", tog] (ret "[]")
    ["on_want", "joined", "index_bound", "outside", "our_interest_for"])
  ["outside: outside our interest", "on_want: outside what we serve p"]
-- a group not admitted
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "null"] []
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", tog, admQ "false"] (ret "[]")
    ["on_want", "joined", "index_bound", "outside", "our_interest_for"])
  [inInterest, "on_want: a group not admitted"]
-- an ask of a chunk p claimed: penalised
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "null",
     rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "peer_has" (pg 4) "[8, 3, false, false]"] []
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", tog, admQ "true", tog, penQ] (ret "[]") reachedTo)
  [inInterest, "on_want: an ask of a chunk p claimed"]
-- past the serving limit: 2 served, the limit 2
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]" (readsTo "2") [] tapeTo (ret "[]") reachedTo)
  [inInterest, "on_want: past the serving limit"]
-- nothing to answer with: not stored, not standing, not DECLARED, not a probe
def w10 : String := rec1 "on_want" s!"[4, [{askOf 3}]]" readsTo [] (tapeTo ++ [resQ 3 "null"]) (ret "[]") reachedTo
#guard takes w10 [inInterest, "on_want: nothing to answer with"]
-- standing until the chunk arrives: a standing ask, not stored
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (st := true)}]]"
    (readsTo ++ [rd "probe_waiting" gp4 "null", rd "standing" gi3 "null"])
    [rd "standing" gi3 "[4]"] (tapeTo ++ [resQ 3 "null"]) (ret "[]") reachedTo)
  [inInterest, "on_want: standing until the chunk arrives"]
-- a probe kept until we decode: p probes index 3, which we claim (mine) and do not store; p's standing WANT of it
-- and its route mark go
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (probe := true)}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "8",
     rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "probe_served" (pg 4) "null", rd "probe_waiting" gp4 "null",
     rd "peer_has" (pg 4) "null", rd "served" (pg 4) "null", rd "standing" gi3 "[4, 5]",
     rd "routed_standing" gi3 "[4]"]
    [rd "probe_waiting" gp4 "3", rd "standing" gi3 "[5]", rd "routed_standing" gi3 "[]"]
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", admQ "true", tog, tog, resQ 3 "null"] (ret "[]")
    ["on_want", "joined", "index_bound", "outside", "probe_of_claim"])
  ["outside: held", "on_want: a probe kept until we decode"]
-- a probe answered: the chunk stored; served counts it, the budget does not, and the probe's exemption is taken
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (probe := true)}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "8",
     rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "probe_served" (pg 4) "null", rd "probe_waiting" gp4 "null",
     rd "peer_has" (pg 4) "null", rd "served" (pg 4) "null", rd "unwanted" "[4]" "null",
     rd "serve_count" s!"[4, {id3q}]" "null", rd "probe_answers" (pg 4) "null"]
    [rd "serve_count" s!"[4, {id3q}]" "1", rd "served" (pg 4) "1", rd "probe_served" (pg 4) "true",
     rd "probe_answers" (pg 4) "8"]
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", admQ "true", tog, tog, resQ 3 id3q, chunkQ, chunkQ]
    (ret s!"[{chunk3}]") ["on_want", "joined", "index_bound", "outside", "probe_of_claim", "serve_probe"])
  ["outside: held", "on_want: answered"]
-- an id answered in this frame: p asks index 2 of the column group, answered; then probes index 3 of g, the same
-- cell, which we claim. Its id is answered already, so the probe takes its exemption on that answer: no second
-- chunk_of, no second count
#guard takes (rec1 "on_want" s!"[4, [[[{hq}, 2], false, 0, false], {askOf 3 (probe := true)}]]"
    [rd "desc" s!"[{hq}]" "null", rd "join_sent" "[4, \"column\"]" (jnT "column" "ALL" "NONE"),
     rd "origin" s!"[{hq}]" "null", rd "mine" s!"[{hq}]" "null",
     rd "join_recv" "[4, \"column\"]" (jnT "column" "ALL" "NONE"), rd "peer_has" s!"[4, {hq}]" "null",
     rd "served" s!"[4, {hq}]" "null", rd "unwanted" "[4]" "null", rd "serve_count" s!"[4, {idH2q}]" "null",
     rd "offered_to" s!"[4, {hq}]" "null", rd "served_hb" "[4]" "null",
     rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "8",
     rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "probe_served" (pg 4) "null", rd "probe_waiting" gp4 "null",
     rd "peer_has" (pg 4) "null", rd "served" (pg 4) "null", rd "probe_answers" s!"[4, {hq}]" "null"]
    [rd "served_hb" "[4]" "1", rd "serve_count" s!"[4, {idH2q}]" "1", rd "served" s!"[4, {hq}]" "1",
     rd "probe_served" (pg 4) "true", rd "probe_answers" s!"[4, {hq}]" "4"]
    [togH, "[\"links\", [\"column\"], [4]]", s!"[\"expired\", [{hq}], false]", togH, togH, togH,
     s!"[\"authenticable\", [{hq}], true]", togH, s!"[\"admitted_group\", [4, {hq}], true]", togH, togH,
     s!"[\"resolve\", [[{hq}, 2]], {idH2q}]", s!"[\"chunk_of\", [{idH2q}], {chunkH2}]",
     tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", admQ "true", tog, tog, resQ 3 idH2q]
    (ret s!"[{chunkH2}]")
    ["on_want", "joined", "index_bound", "outside", "our_interest_for", "probe_of_claim", "serve_probe"])
  [inInterest, "on_want: answered", "outside: held", "on_want: an id answered in this frame"]
-- unwanted: p said it does not want the id
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]" (readsTo ++ [rd "unwanted" "[4]" s!"[{id3q}]"]) []
    (tapeTo ++ [resQ 3 id3q]) (ret "[]") reachedTo)
  [inInterest, "on_want: unwanted"]
-- served too often: 3 answers of the id to p already
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    (readsTo ++ [rd "unwanted" "[4]" "null", rd "serve_count" s!"[4, {id3q}]" "3"]) [] (tapeTo ++ [resQ 3 id3q])
    (ret "[]") reachedTo)
  [inInterest, "on_want: served too often"]
-- over the budget: a budget of 1 answer a heartbeat, 1 given
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]" (readsTo ++ readsAnswer "1") [] (tapeTo ++ [resQ 3 id3q]) (ret "[]")
    reachedTo)
  [inInterest, "on_want: over the budget"] { c2 with SERVE_BUDGET := some 1 }
-- a DECLARED peer's WANT is its interest: want_p gains the index; then answered
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    ([rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "null",
      rd "join_recv" (pT 4) (jn "DECLARED" "NONE"), rd "want_p" (pg 4) "1", rd "peer_has" (pg 4) "null",
      rd "served" (pg 4) "null"] ++ readsAnswer)
    ([rd "want_p" (pg 4) "9"] ++ writesAnswer) (tapeTo ++ [resQ 3 id3q, chunkQ]) (ret s!"[{chunk3}]") reachedTo)
  [inInterest, "on_want: answered"]
-- a routed standing ask through a forwarding link, not stored: passed on one step (route_want), and kept standing
-- with its route mark
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (st := true) (hops := 1)}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "FORWARD"), rd "origin" gp "null", rd "mine" gp "null",
     rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "peer_has" (pg 4) "null", rd "served" (pg 4) "null",
     rd "forwarded" (pT 4) "null", rd "join_recv" (pT 5) (jn "ALL" "NONE"), rd "park" s!"[5, {gq}]" "null",
     rd "probe_waiting" gp4 "null", rd "standing" gi3 "null", rd "routed_standing" gi3 "null"]
    [rd "forwarded" (pT 4) "1", rd "standing" gi3 "[4]", rd "routed_standing" gi3 "[4]"]
    [tog, linksQ "[4, 5]", expQ "false", tog, tog, tog, authQ "true", admQ "true", tog, tog, resQ 3 "null",
     tog, linksQ "[4, 5]", tog, tog, choice5, sendQ 0 "true"] (ret "[]")
    ["on_want", "joined", "index_bound", "outside", "probe_of_claim", "route_want", "serves", "interest_of_peer",
     "parked"])
  ["outside: routed to a forwarding node", "interest_of_peer: ALL", "route_want: passed on",
   "on_want: standing until the chunk arrives"]

/-! The decisions inside an exit. A probe of index 3 of g, which we claim and store, answered: its reads, writes and
questions up to `resolve` -/
def probeReads (unw : String := "null") : List String :=
  [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "8",
   rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "probe_served" (pg 4) "null", rd "probe_waiting" gp4 "null",
   rd "peer_has" (pg 4) "null", rd "served" (pg 4) "null", rd "unwanted" "[4]" unw,
   rd "serve_count" s!"[4, {id3q}]" "null", rd "probe_answers" (pg 4) "null"]
def probeWrites : List String :=
  [rd "serve_count" s!"[4, {id3q}]" "1", rd "served" (pg 4) "1", rd "probe_served" (pg 4) "true",
   rd "probe_answers" (pg 4) "8"]
def tapeHeld : List String := [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", admQ "true", tog, tog]
def reachedProbe : List String := ["on_want", "joined", "index_bound", "outside", "probe_of_claim", "serve_probe"]
/-- The answered probe, its asks and `unwanted[p]` as given, and `serve_probe`'s `chunk_of` answered as given -/
def wP (asks : String) (unw : String := "null") (first : String := chunkQ) : String :=
  rec1 "on_want" s!"[4, {asks}]" (probeReads unw) probeWrites (tapeHeld ++ [resQ 3 id3q, first, chunkQ])
    (ret s!"[{chunk3}]") reachedProbe

-- a plain ask of index 3, then p's probe of it in the same frame: the plain ask is flagged by the frame's probe of
-- its place, so it is answered as the probe, outside the budget; the probe then finds its index taken
#guard takes (wP s!"[{askOf 3}, {askOf 3 (probe := true)}]")
  ["outside: held", "on_want: answered", "on_want: an index answered in this frame"]
-- a probe of an id p said it does not want: a flagged ask passes `unwanted`, and is answered
#guard takes (wP s!"[{askOf 3 (probe := true)}]" (unw := s!"[{id3q}]")) ["outside: held", "on_want: answered"]
-- an answer on our own offer, at a spent budget of 0: not counted, so `served_hb` is neither read nor raised
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    (readsTo ++ [rd "unwanted" "[4]" "null", rd "serve_count" s!"[4, {id3q}]" "null", rd "offered_to" (pg 4) "8"])
    [rd "serve_count" s!"[4, {id3q}]" "1", rd "served" (pg 4) "1"] (tapeTo ++ [resQ 3 id3q, chunkQ])
    (ret s!"[{chunk3}]") reachedTo)
  [inInterest, "on_want: answered"] { c2 with SERVE_BUDGET := some 0 }
-- a DECLARED peer's routed ask through us, a forwarding node, outside our interest (our JOIN to p DECLARED): it
-- keeps its hops, `our_interest_for` is asked, and `want_p` is neither read nor written; answered
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (hops := 1)}]]"
    ([rd "desc" gp "null", rd "join_sent" (pT 4) (jn "DECLARED" "FORWARD"), rd "origin" gp "null",
      rd "mine" gp "null", rd "join_recv" (pT 4) (jn "DECLARED" "NONE"), rd "peer_has" (pg 4) "null",
      rd "served" (pg 4) "null"] ++ readsAnswer)
    writesAnswer
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", admQ "true", tog, tog, tog, resQ 3 id3q, chunkQ]
    (ret s!"[{chunk3}]") reachedTo)
  ["outside: routed to a forwarding node", "on_want: answered"]
-- a standing probe, not stored, with p's probe of index 3 kept already: neither kept again nor made standing
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (st := true) (probe := true)}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "8",
     rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "probe_served" (pg 4) "null", rd "probe_waiting" gp4 "3",
     rd "peer_has" (pg 4) "null", rd "served" (pg 4) "null"] []
    (tapeHeld ++ [resQ 3 "null"]) (ret "[]") ["on_want", "joined", "index_bound", "outside", "probe_of_claim"])
  ["outside: held", "on_want: nothing to answer with"]
-- a standing plain ask, not stored, with p's probe of the same index kept: not made standing
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (st := true)}]]" (readsTo ++ [rd "probe_waiting" gp4 "3"]) []
    (tapeTo ++ [resQ 3 "null"]) (ret "[]") reachedTo)
  [inInterest, "on_want: nothing to answer with"]
-- a routed standing ask through us, a forwarding node, not stored and not passed on (past the limit), outside our
-- interest: `our_interest_for` is asked once, at its third call site, on_want's standing test after `route_want`
-- (`outside` returns at the routed guard, and p's ALL skips the DECLARED test), and the ask is not kept
#guard takes (rec1 "on_want" s!"[4, [{askOf 3 (st := true) (hops := 1)}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "DECLARED" "FORWARD"), rd "origin" gp "null",
     rd "mine" gp "null", rd "join_recv" (pT 4) (jn "ALL" "NONE"), rd "peer_has" (pg 4) "null",
     rd "served" (pg 4) "null", rd "forwarded" (pT 4) "1", rd "probe_waiting" gp4 "null"] []
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", admQ "true", tog, tog, resQ 3 "null", tog, tog]
    (ret "[]") ["on_want", "joined", "index_bound", "outside", "probe_of_claim", "route_want", "our_interest_for"])
  ["outside: routed to a forwarding node", "route_want: past the limit", "on_want: nothing to answer with"]
-- two answers, returned in the order asked: index 5, then index 3
#guard takes (rec1 "on_want" s!"[4, [{askOf 5}, {askOf 3}]]"
    (readsTo ++ [rd "unwanted" "[4]" "null", rd "serve_count" s!"[4, {id5q}]" "null", rd "offered_to" (pg 4) "null",
                 rd "served_hb" "[4]" "null", rd "serve_count" s!"[4, {id3q}]" "null"])
    [rd "served_hb" "[4]" "2", rd "serve_count" s!"[4, {id5q}]" "1", rd "serve_count" s!"[4, {id3q}]" "1",
     rd "served" (pg 4) "2"]
    (tapeTo ++ [resQ 5 id5q, chunkQ5] ++ tapeTo ++ [resQ 3 id3q, chunkQ]) (ret s!"[{chunk5}, {chunk3}]") reachedTo)
  [inInterest, "on_want: answered", inInterest, "on_want: answered"]
-- a DECLARED peer's WANT of an index its interest holds already: want_p written with its value unchanged. The
-- footprint cannot tell this write from none (the replay passes a skipped write that leaves the entry as read)
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    ([rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "null",
      rd "join_recv" (pT 4) (jn "DECLARED" "NONE"), rd "want_p" (pg 4) "8", rd "peer_has" (pg 4) "null",
      rd "served" (pg 4) "null"] ++ readsAnswer)
    ([rd "want_p" (pg 4) "8"] ++ writesAnswer) (tapeTo ++ [resQ 3 id3q, chunkQ]) (ret s!"[{chunk3}]") reachedTo)
  [inInterest, "on_want: answered"]

-- the two KeyErrors of on_want's own, each past `joined`, which the toy's links(T) passes only with both JOINs
-- (toy/node.py:1399-1402), so the toy cannot reach either: no JOIN sent to p, where the hops are read
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]" [rd "desc" gp "null", rd "join_sent" (pT 4) "null"] []
    [tog, linksQ "[4]", expQ "false", tog, tog]
    [("raises", "\"KeyError\""), ("raises_key", "[\"type\", \"row\"]")] ["on_want", "joined", "index_bound"])
  ["raises: KeyError"]
-- no JOIN received from p, where `declared` is read
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}]]"
    [rd "desc" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE"), rd "origin" gp "null", rd "mine" gp "null",
     rd "join_recv" (pT 4) "null"] []
    [tog, linksQ "[4]", expQ "false", tog, tog, tog, authQ "true", tog, admQ "true", tog]
    [("raises", "\"KeyError\""), ("raises_key", "[\"type\", \"row\"]")]
    ["on_want", "joined", "index_bound", "outside", "our_interest_for"])
  [inInterest, "raises: KeyError"]

-- the three that must fail: a wrong return, a question out of order, a record at a node that replaced on_want
#guard fails1 "return value: toy " (rec1 "on_want" s!"[4, [{askOf 3}]]" readsTo [] (tapeTo ++ [resQ 3 "null"])
  (ret s!"[{chunk3}]") reachedTo)
#guard fails1 "tape: type_of_group" (rec1 "on_want" s!"[4, [{askOf 3}]]" [] [] [linksQ "[5]", tog] (ret "[]")
  ["on_want", "joined"])
#guard fails1 "a record of on_want at a node that has replaced it" w1 (replaced := ["on_want"])
-- and four answers that their readers refuse by their own checks, each in a record that passes otherwise: the
-- answered probe's first chunk_of answer with six members, where the tracer writes five; another id's chunk; an
-- id of three hex digits; a resolved id that is hex but no structured id
#guard fails1 "tape: chunk_of: its answer: a chunk here is narrow, five members: "
  (wP s!"[{askOf 3 (probe := true)}]"
    (first := s!"[\"chunk_of\", [{id3q}], [{gq}, 3, 1, \"{root}\", \"{id3}\", [null, [], [0, \"x\"]]]]"))
#guard fails1 "tape: chunk_of: its answer: not the chunk of the id asked: "
  (rec1 "on_want" s!"[4, [{askOf 3}]]" (readsTo ++ readsAnswer) writesAnswer
    (tapeTo ++ [resQ 3 id3q, s!"[\"chunk_of\", [{id3q}], {chunk5}]"]) (ret s!"[{chunk5}]") reachedTo)
#guard fails1 "tape: own_id: its answer: not hex digits, two a byte: 7fe"
  (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) (jn "DERIVED" "NONE"), rd "desc" gp "null"] []
    [tog, "[\"own_id\", [], \"7fe\"]",
     s!"[\"derived_interest\", [\"row\", {gq}, null, \"7fe\", {jn "DERIVED" "NONE"}], 6]"] (ret "6")
    ["our_interest_for"])
#guard fails1 "tape: resolve: its answer: not a structured id: abcd"
  (rec1 "on_want" s!"[4, [{askOf 3}]]" readsTo [] (tapeTo ++ [resQ 3 "\"abcd\""]) (ret "[]") reachedTo)

/-! ### outside -/

def out1 (routed : Bool) (reads tape : List String) (r : String) (reached : List String := ["outside"]) : String :=
  rec1 "outside" s!"[4, {gq}, 3, {routed}]" reads [] tape (ret r) reached

#guard takes (out1 false [] [tog, authQ "false"] "false") ["outside: not authenticable"]
#guard takes (out1 false [rd "origin" gp "0"] [tog, authQ "true"] "false") ["outside: our own group"]
#guard takes (out1 false [rd "origin" gp "null", rd "mine" gp "8"] [tog, authQ "true"] "false") ["outside: held"]
#guard takes (out1 true [rd "origin" gp "null", rd "mine" gp "null", rd "join_sent" (pT 4) (jn "ALL" "FORWARD")]
    [tog, authQ "true"] "false")
  ["outside: routed to a forwarding node"]
#guard takes (out1 true [rd "origin" gp "null", rd "mine" gp "null", rd "join_sent" (pT 4) (jn "ALL" "NONE")]
    [tog, authQ "true", tog] "false" ["outside", "our_interest_for"])
  ["outside: in our interest"]
#guard takes (out1 false [rd "origin" gp "null", rd "mine" gp "null", rd "join_sent" (pT 4) (jn "DECLARED" "NONE")]
    [tog, authQ "true", tog] "true" ["outside", "our_interest_for"])
  ["outside: outside our interest"]
-- a routed ask with no JOIN sent to p: KeyError on the type
#guard takes (rec1 "outside" s!"[4, {gq}, 3, true]"
    [rd "origin" gp "null", rd "mine" gp "null", rd "join_sent" (pT 4) "null"] [] [tog, authQ "true"]
    [("raises", "\"KeyError\""), ("raises_key", "[\"type\", \"row\"]")] ["outside"])
  ["raises: KeyError"]

/-! ### index_bound and our_interest_for -/

#guard takes (rec1 "index_bound" s!"[{gq}]" [rd "desc" gp "null"] [] [tog] (ret "8") ["index_bound"]) []
#guard takes (rec1 "index_bound" s!"[{gq}]" [rd "desc" gp desc2] []
  [tog, s!"[\"index_count\", [\"row\", {desc2}], 4]"] (ret "4") ["index_bound"]) []
-- a type with parameters but no MAX_INDICES: AttributeError, from the missing field
#guard takes (rec1 "index_bound" s!"[{gq}]" [rd "desc" gp "null"] [] [s!"[\"type_of_group\", [{gq}], \"payload\"]"]
  [("raises", "\"AttributeError\"")] ["index_bound"]) ["raises: AttributeError"]
-- the same type with the group's count known: index_count answers, and no parameter is read
#guard takes (rec1 "index_bound" s!"[{gq}]" [rd "desc" gp desc2] []
  [s!"[\"type_of_group\", [{gq}], \"payload\"]", s!"[\"index_count\", [\"payload\", {desc2}], 4]"] (ret "4")
  ["index_bound"]) []
#guard takes (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) (jn "ALL" "NONE")] [] [tog]
  (ret "[\"-\", 1]") ["our_interest_for"]) []
#guard takes (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) (jn "DECLARED" "NONE")] [] [tog]
  (ret "0") ["our_interest_for"]) []
-- DERIVED: hdr.get(g) read, own_id() asked, then derived_interest
#guard takes (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) (jn "DERIVED" "NONE"), rd "desc" gp "null"]
  [] [tog, s!"[\"own_id\", [], {nid}]",
      s!"[\"derived_interest\", [\"row\", {gq}, null, {nid}, {jn "DERIVED" "NONE"}], 6]"] (ret "6")
  ["our_interest_for"]) []
-- no JOIN sent to p: KeyError on the type. No call through on_want reaches it in the toy: on_want asks it, itself
-- and through outside, only of a link past `joined`, which the toy's links(T) passes only with both JOINs
-- (toy/node.py:1399-1402). A direct call of our_interest_for can
#guard takes (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) "null"] [] [tog]
  [("raises", "\"KeyError\""), ("raises_key", "[\"type\", \"row\"]")] ["our_interest_for"]) ["raises: KeyError"]

/-! ### route_want -/

#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 1]" [rd "join_sent" (pT 4) (jn "ALL" "NONE")] [] [tog] (ret "false")
  ["route_want"]) ["route_want: not a forwarding link"]
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 1]" [rd "join_sent" (pT 4) (jn "ALL" "FORWARD"),
  rd "forwarded" (pT 4) "1"] [] [tog] (ret "false") ["route_want"]) ["route_want: past the limit"]
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 1]" [rd "join_sent" (pT 4) (jn "ALL" "FORWARD"),
  rd "forwarded" (pT 4) "null"] [] [tog, linksQ "[4]"] (ret "false") ["route_want"]) ["route_want: no route"]
/-- A link that serves the index and is not parked -/
def servesReads : List String :=
  [rd "join_sent" (pT 4) (jn "ALL" "FORWARD"), rd "forwarded" (pT 4) "null", rd "join_recv" (pT 5) (jn "ALL" "NONE"),
   rd "park" s!"[5, {gq}]" "null"]
def servesTape : List String := [tog, linksQ "[4, 5]", tog, tog]
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 1]" servesReads [rd "forwarded" (pT 4) "1"]
    (servesTape ++ [choice5, sendQ 0 "true"]) (ret "true") ["route_want", "serves", "interest_of_peer", "parked"])
  ["interest_of_peer: ALL", "route_want: passed on"]
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 1]" servesReads [] (servesTape ++ [choice5, sendQ 0 "false"])
    (ret "false") ["route_want", "serves", "interest_of_peer", "parked"])
  ["interest_of_peer: ALL", "route_want: refused by a full queue"]
-- no link serves it, two hops left: one step toward the family, through the forwarding links
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 2]"
    [rd "join_sent" (pT 4) (jn "ALL" "FORWARD"), rd "forwarded" (pT 4) "null",
     rd "join_recv" (pT 5) (jn "DECLARED" "FORWARD")]
    [rd "forwarded" (pT 4) "1"]
    [tog, linksQ "[4, 5]", tog, s!"[\"family\", [\"row\", {gq}], 0]", linksQ "[4, 5]",
     "[\"route_next\", [\"row\", 0, [5]], [5]]", choice5, sendQ 1 "true"] (ret "true") ["route_want", "serves"])
  ["serves: DECLARED", "route_want: passed on"]
-- three links serve the index, in the links' order 5, 6, 7; 6 is parked until 1.0, past the record's now of 0, so
-- the choice is between 5 and 7
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 1]"
    [rd "join_sent" (pT 4) (jn "ALL" "FORWARD"), rd "forwarded" (pT 4) "null",
     rd "join_recv" (pT 5) (jn "ALL" "NONE"), rd "join_recv" (pT 6) (jn "ALL" "NONE"),
     rd "join_recv" (pT 7) (jn "ALL" "NONE"), rd "park" s!"[5, {gq}]" "null", rd "park" s!"[6, {gq}]" oneBits,
     rd "park" s!"[7, {gq}]" "null"]
    [rd "forwarded" (pT 4) "1"]
    [tog, linksQ "[4, 5, 6, 7]", tog, tog, tog, tog, tog, tog, "[\"choice\", [[5, 7]], 7]", sendQ 0 "true" (q := 7)]
    (ret "true") ["route_want", "serves", "interest_of_peer", "parked"])
  ["interest_of_peer: ALL", "interest_of_peer: ALL", "interest_of_peer: ALL", "route_want: passed on"]
-- no link serves it (both DECLARED), two hops left: the fallback keeps 5, which forwards, and leaves 6, which does not
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 2]"
    [rd "join_sent" (pT 4) (jn "ALL" "FORWARD"), rd "forwarded" (pT 4) "null",
     rd "join_recv" (pT 5) (jn "DECLARED" "FORWARD"), rd "join_recv" (pT 6) (jn "DECLARED" "NONE")]
    [rd "forwarded" (pT 4) "1"]
    [tog, linksQ "[4, 5, 6]", tog, tog, s!"[\"family\", [\"row\", {gq}], 0]", linksQ "[4, 5, 6]",
     "[\"route_next\", [\"row\", 0, [5]], [5]]", choice5, sendQ 1 "true"] (ret "true") ["route_want", "serves"])
  ["serves: DECLARED", "serves: DECLARED", "route_want: passed on"]
-- the two KeyErrors of route_want's own. No JOIN sent to p: on_want asks route_want only past `joined`, which the
-- toy's links(T) passes only with both JOINs (toy/node.py:1399-1402), so no call through on_want reaches it in the
-- toy. A direct call of route_want can
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 1]" [rd "join_sent" (pT 4) "null"] [] [tog]
    [("raises", "\"KeyError\""), ("raises_key", "[\"type\", \"row\"]")] ["route_want"])
  ["raises: KeyError"]
-- no JOIN received from a link, in the fallback's list. The toy cannot reach it: each link of the toy's links(T) has
-- both JOINs, and the first list asks `serves`, which raises first, of the same links. Here links(T) answers p alone
-- the first time and adds 6 the second, which the Python's code allows and the toy's state does not
#guard takes (rec1 "route_want" s!"[4, {gq}, 3, 2]"
    [rd "join_sent" (pT 4) (jn "ALL" "FORWARD"), rd "forwarded" (pT 4) "null", rd "join_recv" (pT 6) "null"] []
    [tog, linksQ "[4]", s!"[\"family\", [\"row\", {gq}], 0]", linksQ "[4, 6]"]
    [("raises", "\"KeyError\""), ("raises_key", "[\"type\", \"row\"]")] ["route_want"])
  ["raises: KeyError"]

end Serve

/-! ## §4.1's relations and §6.3's limit on them: `relation_room`, `graft`, `on_prune`, `on_graft`,
`maintain_relations` and `on_join`

Hand-written records, each written from the Python's order of reads and questions, and each passing with "fewer" 0
and exactly the branch labels it was written for, in order:
- one per branch label of `relation_room` (3), `graft` (2), `on_prune` (8), `on_graft` (16), `maintain_relations`
  (6) and `on_join` (4);
- the decisions inside an exit that change a read, a question or a write: `graft`'s three directions; a symmetric
  PRUNE of direction IN ending both ways; a symmetric GRAFT taken without an answer because it answers ours, and
  because it is a yes to a relation held, and the same relation answered again where it is not a yes; each part of
  the accept tests refusing in turn (`in_pushers` at the cap, `wants_family`, the duty), and a one-way GRAFT of
  direction BOTH running both blocks; `uplink_class` FAST and HOME, with the outs' target met;
- the short-circuits that leave a read or a question unmade: `in_pushers` not asked for a relation held (symmetric),
  `out_pushees` not asked where the duty is not FORWARD, and `grafted_out[q]` not read where `grafted_in[q]` holds
  the colour (the half-held relations);
- `maintain_relations` with two candidates in a known order, one without room, `relation_room` called for each; the
  half-held relations grafted in `sorted` order where the questions' order is not;
- the boundaries: `relation_room` at exactly `MAX_RELATIONS` and one below, a pair held in two maps counting once, a
  backoff that runs out exactly now (not counted, and deleted), the slice `cs[:n]` at `n` = 0 and -1;
- `relation_room` at a type with parameters but no `MAX_RELATIONS` (`param`'s missing-field arm);
- the parameters the Python leaves unread, each at a type that lacks it, so that a read would raise: `MAX_RELATIONS`
  where the pair is held (`payload`), and `M` where no family has duty (`bare`, which lacks `M` alone among the
  parameters §4.1's upkeep reads), beside `M`'s `AttributeError` where one does;
- the owed messages: a JOIN of the record's own type not counted, a GRAFT of the type counted, with `answer` false and
  with it true, a GRAFT of another type not counted, and a PRUNE of the type counted. That a JOIN's type is not read
  is the audit's: a record holds no read of a message's fields;
- symmetric upkeep at each of its places: below the floor, between the floor and the cap (the repair alone), and at
  the cap with a draw of 2 and of 0; and a symmetric PRUNE with a backoff, ending both ways with two backoffs;
- each `KeyError` of a missing JOIN sent, as the Python raises it. The toy reaches none of them: `on_graft` returns
  first unless `joined(p, T)`, which is `p in links(T)`, and the toy's `links(T)` needs both JOINs
  (toy/node.py:1399-1402). Each record answers `links` with p on its tape, and is a record of what the Python does in
  that state.

Several must fail: a wrong return, a question out of order, `type_of` answered once where the Python asks it twice,
the six questions' answers that their readers refuse by their own checks, and a draw of a negative count at the
symmetric cap, which the twin refuses with a crash of its own. No tracer writes that record faithfully: the draw's
encoder raises `TypeError` on the negative count before the tape entry is written, so the tracer writes the call as
raising `TypeError` and the trace ends stopped. A record beside it names the twin's crash as its raise, so that the
judge holds where the crash comes: after `families_with_duty` and `in_pushers`, with the tape used up.

What a record shows, and what it does not: as in §4.5's records, the replay holds the twin to the record's questions
in order, its return or raise, its writes and the cells it read. It does not show how many times a cell was read, in
what order, or when a write fell between two questions; nor a level's presence once its leaves are gone, nor whether a
parameter was read where the type has it. Those come from the source-order audit of each function, line by line
against the Python. The questions are stubbed by their tape entries, and their own reads (`cr`) are left out here:
the traces carry them.

The link is peer 4, the family 0 and the colour 0. Five types have parameters: `row`, one way, with a limit of 2
pairs and a backoff of 1.0; `column`, symmetric, with no limit (+∞, the toy's default) and no backoff; `payload`, with
parameters but no `MAX_RELATIONS`; `sym`, symmetric, with a floor below its cap and a `D_OUT` above both, and a
backoff of 1.0; and `bare`, with `row`'s parameters but no `M`. The toy fixes `F_HI`, `D_OUT`, `D_OUT_FAST` and
`D_OUT_MAX` at 12, 8, 8 and 12 for its three types (toy/node.py:1235, :1285, :1330); the records take smaller values,
which §1.1's class allows, so that their lists stay short, and the twin reads each from the context the same way at
any value. Two symmetric types are outside the mesh's `F_LO ≤ D_OUT < F_HI` (§9's table), which the toy's `payload`,
the only type the toy makes symmetric, meets at 6 ≤ 8 < 12: `column`, whose `D_OUT` is below its floor, and `sym`,
whose `D_OUT` is above its cap, so that the draw at the cap can be asked with 0, and with a negative count in the one
that must fail.

Each record is a seeded state: a store and tables that the toy's code can hold at the record's parameters. Not every
one is reached by the toy's events (a JOIN of `row` with interest ALL, two backoffs at times that one `PRUNE_BACKOFF`
cannot leave together, pairs of families with no history); a record claims a way the toy reaches it only where its
comment gives one. A record's time is 0 unless it says otherwise. -/

namespace Upkeep

open Serve (rd arrL quoted tablesIn jnT)

/-- +∞, the toy's `MAX_RELATIONS` unless a run sets it -/
def inf : Float := Float.ofBits 9218868437227405312

/-- `row`: one way, M = 1, a floor and a cap of 1 pusher, 1 out (2 on a fast uplink), a limit of 2 pairs per link, a
backoff of 1.0; `column`: symmetric, M = 1, a floor and a cap of 3, 1 out, no limit and no backoff; `payload`: no
`MAX_RELATIONS`; `sym`: symmetric, M = 1, a floor of 1 and a cap of 2, so that one pusher sits between them, a
`D_OUT` of 3 above the cap, so that the draw at the cap can be 0 or negative, no limit, and a backoff of 1.0; `bare`:
`row`'s parameters with no `M`, so that among the parameters §4.1's upkeep reads, an `AttributeError` there can come
only from a read of `M`; `bare` lacks the type's other parameters too, and the judge matches a raise by its class -/
def params2 : TypeId → Option TypeParams := fun T =>
  if T == "row" then
    some { M := some 1, SYMMETRIC := some false, F_LO := some 1, F_HI := some 1, D_OUT := some 1,
           D_OUT_FAST := some 2, D_OUT_MAX := some 1, PRUNE_BACKOFF := some 1.0, MAX_RELATIONS := some 2.0 }
  else if T == "column" then
    some { M := some 1, SYMMETRIC := some true, F_LO := some 3, F_HI := some 3, D_OUT := some 1,
           PRUNE_BACKOFF := some 0.0, MAX_RELATIONS := some inf }
  else if T == "payload" then some { M := some 1, SYMMETRIC := some false, PRUNE_BACKOFF := some 0.0 }
  else if T == "sym" then
    some { M := some 1, SYMMETRIC := some true, F_LO := some 1, F_HI := some 2, D_OUT := some 3,
           PRUNE_BACKOFF := some 1.0, MAX_RELATIONS := some inf }
  else if T == "bare" then
    some { SYMMETRIC := some false, F_LO := some 1, F_HI := some 1, D_OUT := some 1, D_OUT_FAST := some 2,
           D_OUT_MAX := some 1, PRUNE_BACKOFF := some 1.0, MAX_RELATIONS := some 2.0 }
  else none

def replay2 (l : String) : Except String (Array String × Nat) := do
  runSeacast c0 c2 params2 [] traced (← record (← Json.parse l) docSeacast) []

/-- The record passes, with no read of the Python's left unmade, through these branch labels in order -/
def takes2 (l : String) (marks : List String) : Bool :=
  match replay2 l with
  | .ok (ms, 0) => ms.toList == marks
  | _ => false

def fails2 (pre : String) (l : String) : Bool :=
  match replay2 l with
  | .error e => e.startsWith pre
  | .ok _ => false

/-- A record at time `t` (a float's word), with its scans and its rest: the entries it wrote without reading them
that held a value before it, as the tracer writes them (none here). Its tables are those its reads, scans and writes
name. -/
def rec2 (fn args : String) (reads scans writes tape : List String) (out : List (String × String))
    (reached : List String) (rest : List String := []) (t : String := "0") : String :=
  let fs := [("n", "1"), ("t", t), ("fn", s!"\"{fn}\""), ("args", args), ("reads", arrL reads),
             ("scans", arrL scans), ("writes", arrL writes), ("rest", arrL rest), ("tape", arrL tape)] ++ out ++
            [("reached", quoted (reached.toArray.qsort (· < ·)).toList),
             ("tables", tablesIn [arrL reads, arrL scans, arrL writes])]
  "{" ++ ", ".intercalate (fs.map fun (k, v) => s!"\"{k}\": {v}") ++ "}"

/-- 1.0, 2.0 and 3.0 as their words -/
def f1 : String := "4607182418800017408"
def f2 : String := "4611686018427387904"
def f3 : String := "4613937818241073152"

def pt (p : Nat) (T : String) : String := s!"[{p}, \"{T}\"]"
def ptf (p : Nat) (T : String) (f : Nat := 0) : String := s!"[{p}, \"{T}\", {f}]"
/-- `backoff[p][T][f][(k, d)]`'s path -/
def ptfk (p : Nat) (T : String) (f k : Nat) (d : String) : String := s!"[{p}, \"{T}\", {f}, [{k}, \"{d}\"]]"
def sc (tb path : String) : String := s!"[\"{tb}\", {path}]"
/-- A relation map's entry `m[p][T][f]`, family 0 unless named -/
def rc (tb : String) (p : Nat) (T v : String) (f : Nat := 0) : String := rd tb (ptf p T f) v
def owed0 (p : Nat) : String := rd "owed_relations" s!"[{p}]" "null"
/-- `relation_room(p, T, …)`'s scans: the four maps' `m[p][T]` and `backoff[p][T]`, and each family's keys of
`backoff[p][T]` -/
def room (p : Nat) (T : String) (fams : List Nat := []) : List String :=
  ["push_in", "push_out", "grafted_in", "grafted_out", "backoff"].map (sc · (pt p T)) ++
    fams.map fun f => sc "backoff" (ptf p T f)
/-- row's limit reached at link p by two pairs other than (0, 0): (2, 0) pushed to us, our GRAFT of (3, 0) -/
def full (p : Nat) : List String := [rc "push_in" p "row" "[0]" 2, rc "grafted_out" p "row" "[0]" 3]

def runsQ (T : String) (b : Bool := true) : String := s!"[\"runs_type\", [\"{T}\"], {b}]"
def typeQ (T : String) : String := s!"[\"type_of\", [\"{T}\"], \"{T}\"]"
def linksQ (T ps : String) : String := s!"[\"links\", [\"{T}\"], {ps}]"
/-- `on_graft`'s and `on_prune`'s entry: the type run, joined by p, and asked again -/
def entryQ (T : String) : List String := [runsQ T, typeQ T, linksQ T "[4]", typeQ T]
def inQ (T ps : String) : String := s!"[\"in_pushers\", [\"{T}\", 0, 0], {ps}]"
def outQ (T ps : String) : String := s!"[\"out_pushees\", [\"{T}\", 0, 0], {ps}]"
def candQ (T d ps : String) : String := s!"[\"candidates\", [\"{T}\", 0, 0, \"{d}\"], {ps}]"
def wantsQ (T : String) (b : Bool) : String := s!"[\"wants_family\", [\"{T}\", 0], {b}]"
def upQ (u : String) : String := s!"[\"uplink_class\", [], \"{u}\"]"
def dutyQ (T fams : String) : String := s!"[\"families_with_duty\", [\"{T}\"], {fams}]"
def gr (T d : String) (a : Bool) : String := s!"[\"graft\", \"{T}\", 0, 0, \"{d}\", {a}]"
def pr (T d : String) : String := s!"[\"prune\", \"{T}\", 0, 0, \"{d}\"]"
def sendQ (q : Nat) (m : String) (urgent : Bool := false) : String := s!"[\"send\", [{q}, {m}, {urgent}], true]"
/-- `list(chunks)` of an empty store: `join_push` announces nothing -/
def chunksQ : String := "[\"keys\", \"chunks\", [], []]"
def fwd (T : String) : String := rd "join_sent" (pt 4 T) (jnT T "ALL" "FORWARD")
def none4 (T : String) : String := rd "join_sent" (pt 4 T) (jnT T "ALL" "NONE")
def args (T : String) : String := s!"[4, \"{T}\", 0, 0]"

def below : String := "relation_room: below the limit"
def atLimit : String := "relation_room: at the limit"
def heldPair : String := "relation_room: the pair held"
def sent : String := "send_relation: sent"
def raisesKey (T : String) : List (String × String) :=
  [("raises", "\"KeyError\""), ("raises_key", s!"[\"type\", \"{T}\"]")]

/-! ### relation_room -/

-- nothing held: below the limit, read only here
#guard takes2 (rec2 "relation_room" (args "row") [owed0 4] (room 4 "row") [] [] (ret "true") ["relation_room"])
  [below]
-- one below the limit: one other pair
#guard takes2 (rec2 "relation_room" (args "row") [rc "push_in" 4 "row" "[0]" 2, owed0 4] (room 4 "row") [] []
    (ret "true") ["relation_room"])
  [below]
-- at exactly the limit: two other pairs
#guard takes2 (rec2 "relation_room" (args "row") (full 4 ++ [owed0 4]) (room 4 "row") [] [] (ret "false")
    ["relation_room"])
  [atLimit]
-- the pair held, at the limit otherwise: three pairs, the asked one among them
#guard takes2 (rec2 "relation_room" (args "row") (full 4 ++ [rc "push_out" 4 "row" "[0]", owed0 4]) (room 4 "row")
    [] [] (ret "true") ["relation_room"])
  [heldPair]
-- a pair held in two maps counts once: one pair, below the limit
#guard takes2 (rec2 "relation_room" (args "row")
    [rc "push_in" 4 "row" "[0]" 2, rc "push_out" 4 "row" "[0]" 2, owed0 4] (room 4 "row") [] [] (ret "true")
    ["relation_room"])
  [below]
-- at time 2.0: a backoff run out at 1.0 and one that runs out exactly now are not counted, nor an owed JOIN of the
-- type, nor an owed GRAFT of another type; one pair counted, below the limit. That the JOIN's type is not read is
-- the audit's: the record holds no read of a message's fields
#guard takes2 (rec2 "relation_room" (args "row")
    [rc "push_in" 4 "row" "[0]" 2, rd "backoff" (ptfk 4 "row" 3 0 "IN") f1, rd "backoff" (ptfk 4 "row" 5 1 "OUT") f2,
     rd "owed_relations" "[4]" s!"[{jnT "row" "ALL" "FORWARD"}, [\"graft\", \"column\", 6, 0, \"OUT\", false]]"]
    (room 4 "row" [3, 5]) [] [] (ret "true") ["relation_room"] (t := f2))
  [below]
-- at time 2.0: a backoff that runs out at 3.0 and an owed PRUNE of the type are counted; two pairs, at the limit
#guard takes2 (rec2 "relation_room" (args "row")
    [rd "backoff" (ptfk 4 "row" 5 1 "OUT") f3, rd "owed_relations" "[4]" "[[\"prune\", \"row\", 7, 0, \"IN\"]]"]
    (room 4 "row" [5]) [] [] (ret "false") ["relation_room"] (t := f2))
  [atLimit]
-- an owed GRAFT of the type is counted: with one pair pushed to us, two pairs, at the limit
#guard takes2 (rec2 "relation_room" (args "row")
    [rc "push_in" 4 "row" "[0]" 2, rd "owed_relations" "[4]" "[[\"graft\", \"row\", 6, 0, \"OUT\", false]]"]
    (room 4 "row") [] [] (ret "false") ["relation_room"])
  [atLimit]
-- and an owed GRAFT of the type that answers yes (`answer` true) is counted the same
#guard takes2 (rec2 "relation_room" (args "row")
    [rc "push_in" 4 "row" "[0]" 2, rd "owed_relations" "[4]" "[[\"graft\", \"row\", 6, 0, \"OUT\", true]]"]
    (room 4 "row") [] [] (ret "false") ["relation_room"])
  [atLimit]
-- a type with parameters but no MAX_RELATIONS: AttributeError, from the missing field, where the pair is not held
#guard takes2 (rec2 "relation_room" (args "payload") [owed0 4] (room 4 "payload") [] []
    [("raises", "\"AttributeError\"")] ["relation_room"])
  ["raises: AttributeError"]
-- the same type with the pair held: MAX_RELATIONS is not read
#guard takes2 (rec2 "relation_room" (args "payload") [rc "push_in" 4 "payload" "[0]", owed0 4] (room 4 "payload") []
    [] (ret "true") ["relation_room"])
  [heldPair]

/-! ### graft -/

-- no room: nothing written, nothing sent
#guard takes2 (rec2 "graft" "[4, \"row\", 0, 0, \"IN\"]" (full 4 ++ [owed0 4]) (room 4 "row") [] [] (ret "null")
    ["graft", "relation_room"])
  [atLimit, "graft: no room"]
-- IN: grafted_in alone
#guard takes2 (rec2 "graft" "[4, \"row\", 0, 0, \"IN\"]" [owed0 4, rc "grafted_in" 4 "row" "null"] (room 4 "row")
    [rc "grafted_in" 4 "row" "[0]"] [sendQ 4 (gr "row" "IN" false)] (ret "null")
    ["graft", "relation_room", "send_relation"])
  [below, "graft: sent", sent]
-- OUT: grafted_out alone
#guard takes2 (rec2 "graft" "[4, \"row\", 0, 0, \"OUT\"]" [owed0 4, rc "grafted_out" 4 "row" "null"] (room 4 "row")
    [rc "grafted_out" 4 "row" "[0]"] [sendQ 4 (gr "row" "OUT" false)] (ret "null")
    ["graft", "relation_room", "send_relation"])
  [below, "graft: sent", sent]
-- BOTH, at a type with no limit: both
#guard takes2 (rec2 "graft" "[4, \"column\", 0, 0, \"BOTH\"]"
    [owed0 4, rc "grafted_in" 4 "column" "null", rc "grafted_out" 4 "column" "null"] (room 4 "column")
    [rc "grafted_in" 4 "column" "[0]", rc "grafted_out" 4 "column" "[0]"] [sendQ 4 (gr "column" "BOTH" false)]
    (ret "null") ["graft", "relation_room", "send_relation"])
  [below, "graft: sent", sent]

/-! ### on_prune -/

-- a type the node does not run
#guard takes2 (rec2 "on_prune" s!"[4, {pr "cell" "IN"}]" [] [] [] [runsQ "cell" false] (ret "null") ["on_prune"])
  ["on_prune: a type the node does not run"]
-- a link that has not joined the type
#guard takes2 (rec2 "on_prune" s!"[4, {pr "row" "IN"}]" [] [] [] [runsQ "row", typeQ "row", linksQ "row" "[5]"]
    (ret "null") ["on_prune", "joined"])
  ["on_prune: a link that has not joined the type"]
-- no room: the cleanup finds nothing, and no backoff is written
#guard takes2 (rec2 "on_prune" s!"[4, {pr "row" "IN"}]" (full 4 ++ [owed0 4]) (room 4 "row") [] (entryQ "row")
    (ret "null") ["on_prune", "joined", "relation_room"])
  [atLimit, "on_prune: no room"]
-- OUT, p stops pushing us: push_in ends, and our "push me" waits until 1.0
def p1 : String := rec2 "on_prune" s!"[4, {pr "row" "OUT"}]"
  [rc "push_in" 4 "row" "[0]", owed0 4, rc "grafted_in" 4 "row" "null"] (room 4 "row")
  [rc "push_in" 4 "row" "null", rd "backoff" (ptfk 4 "row" 0 0 "IN") f1] (entryQ "row") (ret "null")
  ["on_prune", "joined", "relation_room"]
#guard takes2 p1 [heldPair, "on_prune: pushes to us end, a backoff"]
-- IN, p asks us to stop pushing: push_out ends, and our "I will push you" waits until 1.0
#guard takes2 (rec2 "on_prune" s!"[4, {pr "row" "IN"}]"
    [rc "push_out" 4 "row" "[0]", owed0 4, rc "grafted_out" 4 "row" "null"] (room 4 "row")
    [rc "push_out" 4 "row" "null", rd "backoff" (ptfk 4 "row" 0 0 "OUT") f1] (entryQ "row") (ret "null")
    ["on_prune", "joined", "relation_room"])
  [heldPair, "on_prune: our pushes end, a backoff"]
-- symmetric, a PRUNE of direction IN: the relation ends both ways, with no backoff (PRUNE_BACKOFF 0)
#guard takes2 (rec2 "on_prune" s!"[4, {pr "column" "IN"}]"
    [rc "push_in" 4 "column" "[0]", rc "push_out" 4 "column" "[0]", owed0 4, rc "grafted_in" 4 "column" "null",
     rc "grafted_out" 4 "column" "null"] (room 4 "column")
    [rc "push_in" 4 "column" "null", rc "push_out" 4 "column" "null"] (entryQ "column") (ret "null")
    ["on_prune", "joined", "relation_room"])
  [heldPair, "on_prune: pushes to us end, no backoff", "on_prune: our pushes end, no backoff"]
-- the same at a symmetric type with a backoff (sym's 1.0): both ends wait until 1.0
#guard takes2 (rec2 "on_prune" s!"[4, {pr "sym" "IN"}]"
    [rc "push_in" 4 "sym" "[0]", rc "push_out" 4 "sym" "[0]", owed0 4, rc "grafted_in" 4 "sym" "null",
     rc "grafted_out" 4 "sym" "null"] (room 4 "sym")
    [rc "push_in" 4 "sym" "null", rd "backoff" (ptfk 4 "sym" 0 0 "IN") f1, rc "push_out" 4 "sym" "null",
     rd "backoff" (ptfk 4 "sym" 0 0 "OUT") f1] (entryQ "sym") (ret "null")
    ["on_prune", "joined", "relation_room"])
  [heldPair, "on_prune: pushes to us end, a backoff", "on_prune: our pushes end, a backoff"]
-- at time 2.0, the cleanup: family 0's (0, IN) ran out at 1.0 and goes, its (0, OUT) runs out at 3.0 and stays;
-- family 3's (1, IN) runs out exactly now and goes, which empties the family. Then OUT sets (0, IN) again, to 3.0
#guard takes2 (rec2 "on_prune" s!"[4, {pr "row" "OUT"}]"
    [rd "backoff" (ptfk 4 "row" 0 0 "IN") f1, rd "backoff" (ptfk 4 "row" 0 0 "OUT") f3,
     rd "backoff" (ptfk 4 "row" 3 1 "IN") f2, rc "push_in" 4 "row" "[0]", owed0 4, rc "grafted_in" 4 "row" "null"]
    (room 4 "row" [0, 3])
    [rd "backoff" (ptfk 4 "row" 0 0 "IN") f3, rd "backoff" (ptfk 4 "row" 3 1 "IN") "null", rc "push_in" 4 "row" "null"]
    (entryQ "row") (ret "null") ["on_prune", "joined", "relation_room"] (t := f2))
  ["on_prune: a backoff run out", "on_prune: a backoff run out", heldPair, "on_prune: pushes to us end, a backoff"]

/-! ### on_graft -/

-- a type the node does not run
#guard takes2 (rec2 "on_graft" s!"[4, {gr "cell" "OUT" false}]" [] [] [] [runsQ "cell" false] (ret "null")
    ["on_graft"])
  ["on_graft: a type the node does not run"]
-- a link that has not joined the type
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]" [] [] [] [runsQ "row", typeQ "row", linksQ "row" "[5]"]
    (ret "null") ["on_graft", "joined"])
  ["on_graft: a link that has not joined the type"]
-- no room: ignored, unanswered
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]" (full 4 ++ [owed0 4]) (room 4 "row") [] (entryQ "row")
    (ret "null") ["on_graft", "joined", "relation_room"])
  [atLimit, "on_graft: no room"]

/-- A symmetric GRAFT's reads before its accept test: `grafted_in`, `grafted_out`, `push_in`, `push_out` -/
def symReads (gi go pi po : String) : List String :=
  [owed0 4, rc "grafted_in" 4 "column" gi, rc "grafted_out" 4 "column" go, rc "push_in" 4 "column" pi,
   rc "push_out" 4 "column" po]
def symCalls : List String := ["on_graft", "joined", "relation_room"]

-- symmetric, nothing held, not asked: yes, both ways, and join_push announces what we hold (nothing)
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" false}]"
    (symReads "null" "null" "null" "null" ++ [fwd "column"])
    (room 4 "column") [rc "push_in" 4 "column" "[0]", rc "push_out" 4 "column" "[0]"]
    (entryQ "column" ++ [inQ "column" "[]", wantsQ "column" true, sendQ 4 (gr "column" "BOTH" true), chunksQ])
    (ret "null") (symCalls ++ ["yes", "send_relation", "join_push"]))
  [below, "on_graft: symmetric, yes", sent]
-- symmetric, the yes to our GRAFT (grafted_out holds it): taken, with no answer
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" true}]"
    (symReads "null" "[0]" "null" "null" ++ [fwd "column"])
    (room 4 "column")
    [rc "grafted_out" 4 "column" "null", rc "push_in" 4 "column" "[0]", rc "push_out" 4 "column" "[0]"]
    (entryQ "column" ++ [inQ "column" "[]", wantsQ "column" true, chunksQ]) (ret "null") (symCalls ++ ["join_push"]))
  [heldPair, "on_graft: symmetric, taken without an answer"]
-- symmetric, a yes to a relation held one way: made whole with no answer, and in_pushers is not asked
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" true}]" (symReads "null" "null" "[0]" "null")
    (room 4 "column") [rc "push_out" 4 "column" "[0]"] (entryQ "column" ++ [chunksQ]) (ret "null")
    (symCalls ++ ["join_push"]))
  [heldPair, "on_graft: symmetric, taken without an answer"]
-- the same, where the GRAFT is not a yes: answered yes again
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" false}]" (symReads "null" "null" "[0]" "null")
    (room 4 "column") [rc "push_out" 4 "column" "[0]"]
    (entryQ "column" ++ [sendQ 4 (gr "column" "BOTH" true), chunksQ]) (ret "null")
    (symCalls ++ ["yes", "send_relation", "join_push"]))
  [heldPair, "on_graft: symmetric, yes", sent]
-- symmetric, no: in_pushers at F_HI (3); wants_family not asked, join_sent not read
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" false}]" (symReads "null" "null" "null" "null")
    (room 4 "column") [] (entryQ "column" ++ [inQ "column" "[5, 6, 7]", sendQ 4 (pr "column" "BOTH")]) (ret "null")
    (symCalls ++ ["no", "send_relation"]))
  [below, "on_graft: symmetric, no", sent]
-- symmetric, no: a family we do not want; join_sent not read
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" false}]" (symReads "null" "null" "null" "null")
    (room 4 "column") [] (entryQ "column" ++ [inQ "column" "[]", wantsQ "column" false, sendQ 4 (pr "column" "BOTH")])
    (ret "null") (symCalls ++ ["no", "send_relation"]))
  [below, "on_graft: symmetric, no", sent]
-- symmetric, no: our JOIN to p has duty NONE
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" false}]"
    (symReads "null" "null" "null" "null" ++ [none4 "column"])
    (room 4 "column") [] (entryQ "column" ++ [inQ "column" "[]", wantsQ "column" true, sendQ 4 (pr "column" "BOTH")])
    (ret "null") (symCalls ++ ["no", "send_relation"]))
  [below, "on_graft: symmetric, no", sent]
-- symmetric, no JOIN sent to p: KeyError on the type. The toy cannot reach it: on_graft returns unless joined(p, T),
-- and the toy's links(T) needs both JOINs. The tape answers links with p
#guard takes2 (rec2 "on_graft" s!"[4, {gr "column" "BOTH" false}]"
    (symReads "null" "null" "null" "null" ++ [rd "join_sent" (pt 4 "column") "null"])
    (room 4 "column") [] (entryQ "column" ++ [inQ "column" "[]", wantsQ "column" true]) (raisesKey "column") symCalls)
  [below, "raises: KeyError"]

-- one way, OUT (p will push us), nothing held: yes, "push me"
def o1 : String := rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]"
  [owed0 4, rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "null"] (room 4 "row")
  [rc "push_in" 4 "row" "[0]"] (entryQ "row" ++ [inQ "row" "[]", wantsQ "row" true, sendQ 4 (gr "row" "IN" true)])
  (ret "null") (symCalls ++ ["yes", "send_relation"])
#guard takes2 o1 [below, "on_graft: pushes to us, yes", sent]
-- the yes to our "push me": taken, with no answer
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" true}]"
    [owed0 4, rc "grafted_in" 4 "row" "[0]", rc "push_in" 4 "row" "null"] (room 4 "row")
    [rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "[0]"]
    (entryQ "row" ++ [inQ "row" "[]", wantsQ "row" true]) (ret "null") symCalls)
  [heldPair, "on_graft: pushes to us, taken without an answer"]
-- no, "stop pushing me": in_pushers at F_HI (1); wants_family not asked
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]"
    [owed0 4, rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "null"] (room 4 "row") []
    (entryQ "row" ++ [inQ "row" "[5]", sendQ 4 (pr "row" "IN")]) (ret "null") (symCalls ++ ["no", "send_relation"]))
  [below, "on_graft: pushes to us, no", sent]
-- no: a family we do not want
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]"
    [owed0 4, rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "null"] (room 4 "row") []
    (entryQ "row" ++ [inQ "row" "[]", wantsQ "row" false, sendQ 4 (pr "row" "IN")]) (ret "null")
    (symCalls ++ ["no", "send_relation"]))
  [below, "on_graft: pushes to us, no", sent]
-- held, and not a yes: yes again
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]"
    [owed0 4, rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "[0]"] (room 4 "row") []
    (entryQ "row" ++ [sendQ 4 (gr "row" "IN" true)]) (ret "null") (symCalls ++ ["yes", "send_relation"]))
  [heldPair, "on_graft: pushes to us held, yes again", sent]
-- held, and a yes: no answer
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" true}]"
    [owed0 4, rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "[0]"] (room 4 "row") [] (entryQ "row")
    (ret "null") symCalls)
  [heldPair, "on_graft: pushes to us held, no answer"]
-- held, not a yes, but it answers ours (grafted_in): no answer
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]"
    [owed0 4, rc "grafted_in" 4 "row" "[0]", rc "push_in" 4 "row" "[0]"] (room 4 "row")
    [rc "grafted_in" 4 "row" "null"] (entryQ "row") (ret "null") symCalls)
  [heldPair, "on_graft: pushes to us held, no answer"]

-- one way, IN (p asks us to push it), nothing held, duty FORWARD: yes, "I will push you", and join_push
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "IN" false}]"
    [owed0 4, rc "grafted_out" 4 "row" "null", rc "push_out" 4 "row" "null", fwd "row"] (room 4 "row")
    [rc "push_out" 4 "row" "[0]"] (entryQ "row" ++ [outQ "row" "[]", sendQ 4 (gr "row" "OUT" true), chunksQ])
    (ret "null") (symCalls ++ ["yes", "send_relation", "join_push"]))
  [below, "on_graft: our pushes, yes", sent]
-- the yes to our "I will push you": no answer, and join_push
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "IN" true}]"
    [owed0 4, rc "grafted_out" 4 "row" "[0]", rc "push_out" 4 "row" "null", fwd "row"] (room 4 "row")
    [rc "grafted_out" 4 "row" "null", rc "push_out" 4 "row" "[0]"] (entryQ "row" ++ [outQ "row" "[]", chunksQ])
    (ret "null") (symCalls ++ ["join_push"]))
  [heldPair, "on_graft: our pushes, taken without an answer"]
-- no: our JOIN to p has duty NONE; out_pushees not asked
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "IN" false}]"
    [owed0 4, rc "grafted_out" 4 "row" "null", rc "push_out" 4 "row" "null", none4 "row"] (room 4 "row") []
    (entryQ "row" ++ [sendQ 4 (pr "row" "OUT")]) (ret "null") (symCalls ++ ["no", "send_relation"]))
  [below, "on_graft: our pushes, no", sent]
-- no: out_pushees at D_OUT_MAX (1)
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "IN" false}]"
    [owed0 4, rc "grafted_out" 4 "row" "null", rc "push_out" 4 "row" "null", fwd "row"] (room 4 "row") []
    (entryQ "row" ++ [outQ "row" "[5]", sendQ 4 (pr "row" "OUT")]) (ret "null") (symCalls ++ ["no", "send_relation"]))
  [below, "on_graft: our pushes, no", sent]
-- held, and not a yes: yes again
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "IN" false}]"
    [owed0 4, rc "grafted_out" 4 "row" "null", rc "push_out" 4 "row" "[0]"] (room 4 "row") []
    (entryQ "row" ++ [sendQ 4 (gr "row" "OUT" true)]) (ret "null") (symCalls ++ ["yes", "send_relation"]))
  [heldPair, "on_graft: our pushes held, yes again", sent]
-- held, and a yes: no answer
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "IN" true}]"
    [owed0 4, rc "grafted_out" 4 "row" "null", rc "push_out" 4 "row" "[0]"] (room 4 "row") [] (entryQ "row")
    (ret "null") symCalls)
  [heldPair, "on_graft: our pushes held, no answer"]
-- BOTH, one way, nothing held: both blocks, in the Python's order, each answered
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "BOTH" false}]"
    [owed0 4, rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "null", rc "grafted_out" 4 "row" "null",
     rc "push_out" 4 "row" "null", fwd "row"] (room 4 "row")
    [rc "push_in" 4 "row" "[0]", rc "push_out" 4 "row" "[0]"]
    (entryQ "row" ++ [inQ "row" "[]", wantsQ "row" true, sendQ 4 (gr "row" "IN" true), outQ "row" "[]",
                     sendQ 4 (gr "row" "OUT" true), chunksQ])
    (ret "null") (symCalls ++ ["yes", "send_relation", "join_push"]))
  [below, "on_graft: pushes to us, yes", sent, "on_graft: our pushes, yes", sent]
-- IN, no JOIN sent to p: KeyError on the type. The toy cannot reach it: on_graft returns unless joined(p, T), and
-- the toy's links(T) needs both JOINs. The tape answers links with p
#guard takes2 (rec2 "on_graft" s!"[4, {gr "row" "IN" false}]"
    [owed0 4, rc "grafted_out" 4 "row" "null", rc "push_out" 4 "row" "null", rd "join_sent" (pt 4 "row") "null"]
    (room 4 "row") [] (entryQ "row") (raisesKey "row") symCalls)
  [below, "raises: KeyError"]

/-! ### maintain_relations -/

-- one way, below the floor, two candidates in the question's order: 5 at the limit, 6 with room. relation_room is
-- called for both, each time; 6 is grafted IN, then, as an out on a HOME uplink, OUT
#guard takes2 (rec2 "maintain_relations" "[\"row\"]"
    (full 5 ++ [owed0 5, owed0 6, rc "grafted_in" 6 "row" "null", rc "grafted_out" 6 "row" "null"])
    (room 5 "row" ++ room 6 "row") [rc "grafted_in" 6 "row" "[0]", rc "grafted_out" 6 "row" "[0]"]
    [dutyQ "row" "[0]", inQ "row" "[]", candQ "row" "IN" "[5, 6]", sendQ 6 (gr "row" "IN" false), outQ "row" "[]",
     upQ "HOME", candQ "row" "OUT" "[5, 6]", sendQ 6 (gr "row" "OUT" false)]
    (ret "null") ["maintain_relations", "relation_room", "graft", "send_relation"])
  [atLimit, below, "maintain_relations: below the floor, one way", below, "graft: sent", sent, atLimit, heldPair,
   heldPair, "graft: sent", sent]
-- one way, a FAST uplink: the outs' target is D_OUT_FAST (2), one short; 6 grafted OUT
#guard takes2 (rec2 "maintain_relations" "[\"row\"]" [owed0 6, rc "grafted_out" 6 "row" "null"] (room 6 "row")
    [rc "grafted_out" 6 "row" "[0]"]
    [dutyQ "row" "[0]", inQ "row" "[5]", outQ "row" "[5]", upQ "FAST", candQ "row" "OUT" "[6]",
     sendQ 6 (gr "row" "OUT" false)]
    (ret "null") ["maintain_relations", "relation_room", "graft", "send_relation"])
  [below, below, "graft: sent", sent]
-- the same on a HOME uplink: the target D_OUT (1) is met; relation_room is called, and nothing grafted
def m1 : String := rec2 "maintain_relations" "[\"row\"]" [owed0 6] (room 6 "row") []
  [dutyQ "row" "[0]", inQ "row" "[5]", outQ "row" "[5]", upQ "HOME", candQ "row" "OUT" "[6]"]
  (ret "null") ["maintain_relations", "relation_room"]
#guard takes2 m1 [below]
-- one way, past the cap: ins[F_HI:] pruned IN, from the list asked at the top
#guard takes2 (rec2 "maintain_relations" "[\"row\"]"
    [rc "push_in" 6 "row" "[0]", rc "grafted_in" 6 "row" "null", owed0 6] [] [rc "push_in" 6 "row" "null"]
    [dutyQ "row" "[0]", inQ "row" "[5, 6]", sendQ 6 (pr "row" "IN"), outQ "row" "[]", upQ "HOME",
     candQ "row" "OUT" "[]"]
    (ret "null") ["maintain_relations", "prune", "send_relation"])
  ["maintain_relations: past the cap, one way", sent]
-- no family with duty: nothing asked of the type, M not read
#guard takes2 (rec2 "maintain_relations" "[\"row\"]" [] [] [] [dutyQ "row" "[]"] (ret "null") ["maintain_relations"]) []
-- the same at a type with no M, where a read of M would raise
#guard takes2 (rec2 "maintain_relations" "[\"bare\"]" [] [] [] [dutyQ "bare" "[]"] (ret "null") ["maintain_relations"])
  []
-- and with one family: range(T.params.M) reads the missing field, AttributeError
#guard takes2 (rec2 "maintain_relations" "[\"bare\"]" [] [] [] [dutyQ "bare" "[0]"] [("raises", "\"AttributeError\"")]
    ["maintain_relations"])
  ["raises: AttributeError"]
-- symmetric, below the floor with none: D_OUT - 0 = 1 of the two candidates grafted BOTH; no relation held half
#guard takes2 (rec2 "maintain_relations" "[\"column\"]"
    [owed0 5, owed0 6, rc "grafted_in" 5 "column" "null", rc "grafted_out" 5 "column" "null"]
    (room 5 "column" ++ room 6 "column") [rc "grafted_in" 5 "column" "[0]", rc "grafted_out" 5 "column" "[0]"]
    [dutyQ "column" "[0]", inQ "column" "[]", candQ "column" "BOTH" "[5, 6]", sendQ 5 (gr "column" "BOTH" false),
     inQ "column" "[]", outQ "column" "[]"]
    (ret "null") ["maintain_relations", "relation_room", "graft", "send_relation"])
  [below, below, "maintain_relations: below the floor", below, "graft: sent", sent]
-- symmetric, below the floor with two: D_OUT - 2 = -1, Python's slice drops the last candidate, so 7 of 7 and 8
-- is grafted
#guard takes2 (rec2 "maintain_relations" "[\"column\"]"
    [owed0 7, owed0 8, rc "grafted_in" 7 "column" "null", rc "grafted_out" 7 "column" "null"]
    (room 7 "column" ++ room 8 "column") [rc "grafted_in" 7 "column" "[0]", rc "grafted_out" 7 "column" "[0]"]
    [dutyQ "column" "[0]", inQ "column" "[5, 6]", candQ "column" "BOTH" "[7, 8]", sendQ 7 (gr "column" "BOTH" false),
     inQ "column" "[5, 6]", outQ "column" "[5, 6]"]
    (ret "null") ["maintain_relations", "relation_room", "graft", "send_relation"])
  [below, below, "maintain_relations: below the floor, a negative slice", below, "graft: sent", sent]
-- symmetric, below the floor with one: D_OUT - 1 = 0, none grafted. Then the relations held one way, 8 pushing us
-- (push_in) and 6 and 7 pushed (push_out), are grafted in sorted order, 6, 7, 8, not the questions' 8, 6, 7; each
-- pair is held already, so relation_room says so
#guard takes2 (rec2 "maintain_relations" "[\"column\"]"
    ([owed0 5, rc "push_in" 8 "column" "[0]", rc "push_out" 6 "column" "[0]", rc "push_out" 7 "column" "[0]"] ++
      [6, 7, 8].flatMap fun q => [rc "grafted_in" q "column" "null", rc "grafted_out" q "column" "null", owed0 q])
    (room 5 "column" ++ [6, 7, 8].flatMap (room · "column"))
    ([6, 7, 8].flatMap fun q => [rc "grafted_in" q "column" "[0]", rc "grafted_out" q "column" "[0]"])
    [dutyQ "column" "[0]", inQ "column" "[8]", candQ "column" "BOTH" "[5]", inQ "column" "[8]",
     outQ "column" "[6, 7]", sendQ 6 (gr "column" "BOTH" false), sendQ 7 (gr "column" "BOTH" false),
     sendQ 8 (gr "column" "BOTH" false)]
    (ret "null") ["maintain_relations", "relation_room", "graft", "send_relation"])
  ([below, "maintain_relations: below the floor"] ++
    (List.replicate 3 ["maintain_relations: a half-held relation grafted", heldPair, "graft: sent", sent]).flatten)
-- the same with our GRAFTs pending: 5's in grafted_in, so its grafted_out is not read; 6's in grafted_out
#guard takes2 (rec2 "maintain_relations" "[\"column\"]"
    [rc "grafted_in" 5 "column" "[0]", rc "grafted_in" 6 "column" "null", rc "grafted_out" 6 "column" "[0]"]
    [] [] [dutyQ "column" "[0]", inQ "column" "[5]", candQ "column" "BOTH" "[]", inQ "column" "[5]",
           outQ "column" "[6]"]
    (ret "null") ["maintain_relations"])
  ["maintain_relations: below the floor"]
-- symmetric, at the cap: len(ins) - D_OUT = 2 drawn at random and pruned BOTH; then no relation held half
#guard takes2 (rec2 "maintain_relations" "[\"column\"]"
    ([7, 5].flatMap fun q => [rc "push_in" q "column" "[0]", rc "grafted_in" q "column" "null",
                              rc "push_out" q "column" "[0]", rc "grafted_out" q "column" "null", owed0 q])
    [] ([7, 5].flatMap fun q => [rc "push_in" q "column" "null", rc "push_out" q "column" "null"])
    [dutyQ "column" "[0]", inQ "column" "[5, 6, 7]", "[\"sample_without_replacement\", [[5, 6, 7], 2], [7, 5]]",
     sendQ 7 (pr "column" "BOTH"), sendQ 5 (pr "column" "BOTH"), inQ "column" "[6]", outQ "column" "[6]"]
    (ret "null") ["maintain_relations", "prune", "send_relation"])
  ["maintain_relations: at the cap", sent, sent]
-- symmetric, at the cap with len(ins) = D_OUT (sym: 3 pushers, F_HI 2, D_OUT 3): the draw is asked with 0 and
-- answers none; then no relation held half
#guard takes2 (rec2 "maintain_relations" "[\"sym\"]" [] [] []
    [dutyQ "sym" "[0]", inQ "sym" "[5, 6, 7]", "[\"sample_without_replacement\", [[5, 6, 7], 0], []]",
     inQ "sym" "[5, 6, 7]", outQ "sym" "[5, 6, 7]"]
    (ret "null") ["maintain_relations"])
  ["maintain_relations: at the cap"]
-- symmetric, between the floor and the cap (sym: 1 pusher, F_LO 1, F_HI 2): only the half-held repair runs, for 5
-- pushing us and 6 pushed, each pair held already
#guard takes2 (rec2 "maintain_relations" "[\"sym\"]"
    ([rc "push_in" 5 "sym" "[0]", rc "push_out" 6 "sym" "[0]"] ++
      [5, 6].flatMap fun q => [rc "grafted_in" q "sym" "null", rc "grafted_out" q "sym" "null", owed0 q])
    ([5, 6].flatMap (room · "sym"))
    ([5, 6].flatMap fun q => [rc "grafted_in" q "sym" "[0]", rc "grafted_out" q "sym" "[0]"])
    [dutyQ "sym" "[0]", inQ "sym" "[5]", inQ "sym" "[5]", outQ "sym" "[6]", sendQ 5 (gr "sym" "BOTH" false),
     sendQ 6 (gr "sym" "BOTH" false)]
    (ret "null") ["maintain_relations", "relation_room", "graft", "send_relation"])
  (List.replicate 2 ["maintain_relations: a half-held relation grafted", heldPair, "graft: sent", sent]).flatten

/-! ### on_join -/

-- a type the node does not run
#guard takes2 (rec2 "on_join" s!"[4, {jnT "cell" "ALL" "FORWARD"}]" [] [] [] [runsQ "cell" false] (ret "null")
    ["on_join"])
  ["on_join: a type the node does not run"]
-- colours that are not the type's M (1): the stock path remains
#guard takes2 (rec2 "on_join" "[4, [\"join\", \"row\", \"ALL\", 0, \"FORWARD\", 4]]" [] [] []
    [runsQ "row", typeQ "row"] (ret "null") ["on_join"])
  ["on_join: colours not the type's"]
-- p's JOIN first: recorded, and answered with ours, which send_join records and sends on the urgent lane
def j1 : String := rec2 "on_join" s!"[4, {jnT "row" "DECLARED" "NONE"}]" [rd "join_sent" (pt 4 "row") "null", owed0 4]
  [] [rd "join_recv" (pt 4 "row") (jnT "row" "DECLARED" "NONE"), fwd "row"]
  [runsQ "row", typeQ "row", s!"[\"our_join\", [\"row\"], {jnT "row" "ALL" "FORWARD"}]", typeQ "row",
   sendQ 4 (jnT "row" "ALL" "FORWARD") (urgent := true)]
  (ret "null") ["on_join", "send_join", "send_relation"]
#guard takes2 j1 ["on_join: answered", sent]
-- ours first: recorded, not answered
#guard takes2 (rec2 "on_join" s!"[4, {jnT "row" "DECLARED" "NONE"}]" [fwd "row"] []
    [rd "join_recv" (pt 4 "row") (jnT "row" "DECLARED" "NONE")] [runsQ "row", typeQ "row"] (ret "null") ["on_join"]
   )
  ["on_join: ours went first"]

/-! ### The ones that must fail -/

-- a wrong return
#guard fails2 "return value: " (rec2 "relation_room" (args "row") [owed0 4] (room 4 "row") [] [] (ret "false")
    ["relation_room"])
-- a question out of order: wants_family logged before in_pushers
#guard fails2 "tape: in_pushers" (rec2 "on_graft" s!"[4, {gr "row" "OUT" false}]"
    [owed0 4, rc "grafted_in" 4 "row" "null", rc "push_in" 4 "row" "null"] (room 4 "row")
    [rc "push_in" 4 "row" "[0]"] (entryQ "row" ++ [wantsQ "row" true, inQ "row" "[]", sendQ 4 (gr "row" "IN" true)])
    (ret "null") (symCalls ++ ["yes", "send_relation"]))
-- type_of answered once, where on_prune asks it twice
#guard fails2 "tape: type_of" (rec2 "on_prune" s!"[4, {pr "row" "OUT"}]"
    [rc "push_in" 4 "row" "[0]", owed0 4, rc "grafted_in" 4 "row" "null"] (room 4 "row")
    [rc "push_in" 4 "row" "null", rd "backoff" (ptfk 4 "row" 0 0 "IN") f1]
    [runsQ "row", typeQ "row", linksQ "row" "[4]"]
    (ret "null") ["on_prune", "joined", "relation_room"])
-- a draw of a negative count at the symmetric cap (sym: 2 pushers, F_HI 2, D_OUT 3, so 2 - 3 = -1), where the
-- Python's draw raises ValueError: the twin's question cannot carry the count, and the twin crashes with a name of its
-- own. No tracer writes this record faithfully (the draw's encoder raises TypeError on the negative count, so the
-- tracer writes the call as raising TypeError and stops); it is written here by hand
#guard fails2 ("the Python raises ValueError; the twin: crash: twin: sample_without_replacement of a negative " ++
    "count")
  (rec2 "maintain_relations" "[\"sym\"]" [] [] [] [dutyQ "sym" "[0]", inQ "sym" "[5, 6]"]
    [("raises", "\"ValueError\"")] ["maintain_relations"])
-- where that crash comes: the same input with the twin's crash named as the raise ("twin"), so that the judge holds
-- the tape used up after families_with_duty and in_pushers, the functions reached, the state and the footprint. Not a
-- record of the Python's; it locates the must-fail above
#guard takes2 (rec2 "maintain_relations" "[\"sym\"]" [] [] [] [dutyQ "sym" "[0]", inQ "sym" "[5, 6]"]
    [("raises", "\"twin\"")] ["maintain_relations"])
  ["raises: twin"]
-- and the six questions' answers that their readers refuse by their own checks, each in a record that passes
-- otherwise: a number for a bool, a JOIN's array with another tag, a peer twice in each list of peers, an uplink
-- class outside the two
#guard fails2 "tape: runs_type: its answer: not a bool: 1"
  (rec2 "on_prune" s!"[4, {pr "cell" "IN"}]" [] [] [] ["[\"runs_type\", [\"cell\"], 1]"] (ret "null") ["on_prune"])
#guard fails2 "tape: our_join: its answer: not a JOIN: "
  (j1.replace s!"[\"our_join\", [\"row\"], {jnT "row" "ALL" "FORWARD"}]"
    "[\"our_join\", [\"row\"], [\"graft\", \"row\", \"ALL\", 0, \"FORWARD\", 1]]")
#guard fails2 "tape: candidates: its answer: candidates: a key twice"
  (m1.replace (candQ "row" "OUT" "[6]") (candQ "row" "OUT" "[6, 6]"))
#guard fails2 "tape: in_pushers: its answer: in_pushers: a key twice"
  (m1.replace (inQ "row" "[5]") (inQ "row" "[5, 5]"))
#guard fails2 "tape: out_pushees: its answer: out_pushees: a key twice"
  (m1.replace (outQ "row" "[5]") (outQ "row" "[5, 5]"))
#guard fails2 "tape: uplink_class: its answer: not an uplink class: \"SLOW\"" (m1.replace (upQ "HOME") (upQ "SLOW"))
-- and the records these six are made from pass as they are
#guard takes2 j1 ["on_join: answered", sent] && takes2 m1 [below]

end Upkeep

/-! ## §4.11's window, in bytes, and the writer: `wake_front`, `write_waits`, `acquire_room`, `leave_line`,
`track_in_flight`, `window_release`, `window_timeout`, `noted`, `free_room` and `next_to_send`

Hand-written records, each written from the Python's order of reads and questions (seacast.md:3016-3098, and
seacast-lite.md's `front`, which they call), and each passing with "fewer" 0 and exactly the branch labels it was
written for, in order. A function's labels come after those of the functions it calls before it ends, as the twin
emits them:
- one per branch label of the ten, and `front`'s;
- the window's boundaries: `in_flight` at exactly `W_BYTES` and one below in `wake_front`; `acquire_room` filling the
  window exactly, one byte over, and an empty window taking a chunk larger than `W_BYTES`; `free_room` ending at
  `W_BYTES` exactly, and at 0, where the count's entry goes; the window off (`W_BYTES` none, the toy's `inf`);
- the line: a writer mid-write passed over and the next one woken; `acquire_room` with a writer that can write ahead
  of p, with p at the front, with p behind a writer mid-write, and with p in line already and still no room;
  `leave_line` with p alone in line and with another behind it;
- `track_in_flight`'s second copy, its room back at once and no timer; `window_release` and `window_timeout` giving
  back the send's own bytes; `window_timeout` stale, with nothing in flight, and with `planned` holding the group,
  where `origin_acked` runs;
- `noted` with None, with no offers, with offers ORed into what p was offered, and with a group named twice, whose
  second read is the twin's own write;
- `next_to_send`'s ways out: urgent, owed offers alone, nothing (`leave_line`), nothing where `with_owed` filters
  every bit (so `noted` is not called), `WAIT`, a chunk the filter drops (its room back, and a second turn),
  control (no `wire_size` asked, no room taken), a chunk at `SOURCE_OFFERS = PUBLISH` (`origin_written`) and without
  it, an owed answer enqueued, and owed answers where `has_room` says no;
- `next_to_send` at a node whose line replaces `filter_entry`, which it asks: the entry returned with its chunk, the
  question carrying the call's log of `sent_to`, and the entry dropped (its room back, and a second turn).

Several must fail: a wrong return of `acquire_room` at the boundary and of `next_to_send`, `wire_size` asked for a
control entry, a question out of order in the line, `window_release` taped as a question (it is the twin's own now),
the three new questions' answers that their readers refuse by their own checks, two `sent` cells that its reader
refuses, and `filter_entry`'s question taped at a node that has not replaced it, asked of another entry, and answered
with a wide chunk.

What a record shows, and what it does not, is as in the sections above: the questions in order, the return, the writes
and the cells read, not how many times a cell was read or in what order. The questions' own reads are left out.

The window is `W_BYTES` = 3000, two chunks of 1200 bytes and not a third (the toy's is `W` slots of `CHUNK_BYTES`).
The writer is peer 5, and peer 6 waits beside it where a record says so. The chunk is `chunk3`, narrow, index 3 of
`g`. A record's time is 0 unless it says otherwise. Each record is a seeded state that the toy's code can hold; a
record claims a way the toy reaches it only where its comment gives one. -/

namespace Window

open Serve (rd arrL quoted tablesIn)
open Upkeep (rec2 f1 f2 f3 sc)

/-- `W_BYTES` = 3000 -/
def c3 : ConstsSeacast := { c2 with W_BYTES := some 3000 }
/-- `SOURCE_OFFERS = PUBLISH`, and card 8 (`CANCEL`) on -/
def cPub : Consts := { c0 with SOURCE_OFFERS_PUBLISH := true }
def cCancel : Consts := { c0 with CANCEL := true }

def replay3 (l : String) (c : Consts := c0) (c2' : ConstsSeacast := c3) : Except String (Array String × Nat) := do
  runSeacast c c2' params [] traced (← record (← Json.parse l) docSeacast) []

/-- The record passes, with no read of the Python's left unmade, through these branch labels in order -/
def takes3 (l : String) (marks : List String) (c : Consts := c0) (c2' : ConstsSeacast := c3) : Bool :=
  match replay3 l c c2' with
  | .ok (ms, 0) => ms.toList == marks
  | _ => false

def fails3 (pre : String) (l : String) (c : Consts := c0) (c2' : ConstsSeacast := c3) : Bool :=
  match replay3 l c c2' with
  | .error e => e.startsWith pre
  | .ok _ => false

/-- The same at a node whose line replaces `filter_entry` (`--promise-mode peer`'s, say), which `next_to_send` then
asks (seacast.md:3091) -/
def replay3r (l : String) : Except String (Array String × Nat) := do
  runSeacast c0 c3 params ["filter_entry"] traced (← record (← Json.parse l) docSeacast) []

def takes3r (l : String) (marks : List String) : Bool :=
  match replay3r l with
  | .ok (ms, 0) => ms.toList == marks
  | _ => false

def fails3r (pre : String) (l : String) : Bool :=
  match replay3r l with
  | .error e => e.startsWith pre
  | .ok _ => false

/-- The same at a node whose line replaces the names `rp` -/
def replay3at (rp : List String) (l : String) : Except String (Array String × Nat) := do
  runSeacast c0 c3 params rp traced (← record (← Json.parse l) docSeacast) []

def takes3at (rp : List String) (l : String) (marks : List String) : Bool :=
  match replay3at rp l with
  | .ok (ms, 0) => ms.toList == marks
  | _ => false

def fails3at (rp : List String) (pre : String) (l : String) : Bool :=
  match replay3at rp l with
  | .error e => e.startsWith pre
  | .ok _ => false

/-- The window's count and line, as one entry each -/
def inF (v : String) : String := rd "in_flight" "[\"count\"]" v
def wl (v : String) : String := rd "waiters" "[\"line\"]" v
def wrQ (p : Nat) (b : Bool) : String := s!"[\"writing\", [{p}], {b}]"
def wakeQ (p : Nat) : String := s!"[\"wake\", [{p}], null]"
/-- `sent[(5, g, 3)]`, and the timer `after(WINDOW_TIMEOUT, window_timeout, key, at)`, 0.5 s as its word -/
def key3 : String := s!"[5, {gq}, 3]"
def sentR (v : String) : String := rd "sent" s!"[{key3}]" v
def half : String := "4602678819172646912"
def afterQ (at_ : String) : String := s!"[\"after\", [{half}, \"window_timeout\", [{key3}, {at_}]], null]"
def plannedR (v : String) : String := rd "planned" s!"[{gq}]" v
def offR (v : String) : String := rd "offered_to" s!"[5, {gq}]" v
def offersQ (e ans : String) : String := s!"[\"offers_in\", [{e}], {ans}]"
def gb (b : Nat) : String := s!"[{gq}, {b}]"

def lNoRoom : String := "wake_front: no room"
def lNobody : String := "wake_front: nobody in line can write"
def lPassed : String := "front: a writer mid-write passed"
def lRoom : String := "acquire_room: room"
def lInLine : String := "acquire_room: in line"
def lNothingOwed : String := "queue_owed_relations: nothing owed"

/-- The window's functions reached below a release: `free_room` and `wake_front`, and `front` where there is room -/
def freed : List String := ["free_room", "front", "wake_front"]

/-! ### wake_front -/

-- no room: in_flight at exactly W_BYTES; front is not asked
#guard takes3 (rec2 "wake_front" "[]" [inF "3000"] [] [] [] (ret "null") ["wake_front"]) [lNoRoom]
-- one below: room, and nobody in line
#guard takes3 (rec2 "wake_front" "[]" [inF "2999", wl "null"] [] [] [] (ret "null") ["front", "wake_front"]) [lNobody]
-- nobody in line can write: the one there is mid-write (front's generator ends)
#guard takes3 (rec2 "wake_front" "[]" [inF "null", wl "[5]"] [] [] [wrQ 5 true] (ret "null") ["front", "wake_front"])
  [lPassed, lNobody]
-- a writer mid-write passed over: the next in line is woken
#guard takes3 (rec2 "wake_front" "[]" [inF "1200", wl "[5, 6]"] [] [] [wrQ 5 true, wrQ 6 false, wakeQ 6] (ret "null")
    ["front", "wake_front"])
  [lPassed]
-- the first in line woken; the one behind it is not asked
#guard takes3 (rec2 "wake_front" "[]" [inF "1200", wl "[5, 6]"] [] [] [wrQ 5 false, wakeQ 5] (ret "null")
    ["front", "wake_front"])
  []
-- the window off (W_BYTES none, the toy's inf): no count is too many
#guard takes3 (rec2 "wake_front" "[]" [inF "1000000", wl "[5]"] [] [] [wrQ 5 false, wakeQ 5] (ret "null")
    ["front", "wake_front"]) [] (c2' := c2)

/-! ### write_waits -/

-- p is not in line: nothing (the toy calls it at each write that does not complete, run.py's send buffer of 1)
#guard takes3 (rec2 "write_waits" "[5]" [wl "[6]"] [] [] [] (ret "null") ["write_waits"]) ["write_waits: not in line"]
#guard takes3 (rec2 "write_waits" "[5]" [wl "null"] [] [] [] (ret "null") ["write_waits"]) ["write_waits: not in line"]
-- p in line and mid-write: the line skips it and wakes the next
#guard takes3 (rec2 "write_waits" "[5]" [wl "[5, 6]", inF "null"] [] [] [wrQ 5 true, wrQ 6 false, wakeQ 6] (ret "null")
    ["front", "wake_front", "write_waits"])
  [lPassed]
-- p in line, and no room: nobody is woken
#guard takes3 (rec2 "write_waits" "[5]" [wl "[5]", inF "3000"] [] [] [] (ret "null") ["wake_front", "write_waits"])
  [lNoRoom]

/-! ### free_room -/

-- 1200 back from a full window, and nobody in line
#guard takes3 (rec2 "free_room" "[1200]" [inF "3000", wl "null"] [] [inF "1800"] [] (ret "null") freed) [lNobody]
-- back to 0: the count's entry goes, and the first in line is woken
#guard takes3 (rec2 "free_room" "[1200]" [inF "1200", wl "[5]"] [] [inF "null"] [wrQ 5 false, wakeQ 5] (ret "null")
    freed)
  []
-- ending at W_BYTES exactly (an empty window took more): still no room
#guard takes3 (rec2 "free_room" "[1200]" [inF "4200"] [] [inF "3000"] [] (ret "null") ["free_room", "wake_front"])
  [lNoRoom]

/-! ### acquire_room -/

-- filling the window exactly: 1800 + 1200 = W_BYTES, nobody in line; no room left for the next
#guard takes3 (rec2 "acquire_room" "[5, 1200]" [inF "1800", wl "null"] [] [inF "3000"] [] (ret "true")
    ["acquire_room", "front", "wake_front"])
  [lNoRoom, lRoom]
-- one byte over: p joins the line, and front is not asked (`and` short-circuits)
#guard takes3 (rec2 "acquire_room" "[5, 1200]" [inF "1801", wl "null"] [] [wl "[5]"] [] (ret "false")
    ["acquire_room"])
  [lInLine]
-- an empty window takes a chunk over W_BYTES (`or in_flight == 0`)
#guard takes3 (rec2 "acquire_room" "[5, 4000]" [inF "null", wl "null"] [] [inF "4000"] [] (ret "true")
    ["acquire_room", "front", "wake_front"])
  ["acquire_room: an empty window, over W_BYTES", lNoRoom, lRoom]
-- room, but a writer that can write is ahead of p: p joins the line behind it
#guard takes3 (rec2 "acquire_room" "[5, 1200]" [inF "null", wl "[6]"] [] [wl "[6, 5]"] [wrQ 6 false] (ret "false")
    ["acquire_room", "front"])
  [lInLine]
-- p at the front: it leaves the line, takes the room, and the next in line is woken
#guard takes3 (rec2 "acquire_room" "[5, 1200]" [inF "null", wl "[5, 6]"] [] [wl "[6]", inF "1200"]
    [wrQ 5 false, wrQ 6 false, wakeQ 6] (ret "true") ["acquire_room", "front", "wake_front"])
  [lRoom]
-- p behind a writer mid-write: p goes first; the other stays in line and still cannot write
#guard takes3 (rec2 "acquire_room" "[5, 1200]" [inF "null", wl "[6, 5]"] [] [wl "[6]", inF "1200"]
    [wrQ 6 true, wrQ 5 false, wrQ 6 true] (ret "true") ["acquire_room", "front", "wake_front"])
  [lPassed, lPassed, lNobody, lRoom]
-- p in line already, and still no room: it keeps its place, nothing written
#guard takes3 (rec2 "acquire_room" "[5, 1200]" [inF "2000", wl "[6, 5]"] [] [] [] (ret "false") ["acquire_room"])
  [lInLine]
-- the window off: any count fits
#guard takes3 (rec2 "acquire_room" "[5, 1200]" [inF "1000000", wl "null"] [] [inF "1001200"] [] (ret "true")
    ["acquire_room", "front", "wake_front"])
  [lNobody, lRoom] (c2' := c2)

/-! ### leave_line -/

#guard takes3 (rec2 "leave_line" "[5]" [wl "[6]"] [] [] [] (ret "null") ["leave_line"]) ["leave_line: not in line"]
-- p leaves; the one behind it is woken
#guard takes3 (rec2 "leave_line" "[5]" [wl "[5, 6]", inF "null"] [] [wl "[6]"] [wrQ 6 false, wakeQ 6] (ret "null")
    ["front", "leave_line", "wake_front"])
  ["leave_line: left the line"]
-- p alone in line: the line's entry goes
#guard takes3 (rec2 "leave_line" "[5]" [wl "[5]", inF "null"] [] [wl "null"] [] (ret "null")
    ["front", "leave_line", "wake_front"])
  [lNobody, "leave_line: left the line"]

/-! ### track_in_flight -/

-- the first copy: the room travels with it, and its timer is armed with the send's time
#guard takes3 (rec2 "track_in_flight" s!"[5, {chunk3}, 1200]" [sentR "null"] [] [sentR s!"[{f1}, 1200]"] [afterQ f1]
    (ret "null") ["track_in_flight"] (t := f1))
  []
-- a second copy while the first is in flight: its room back at once, the first's entry and timer kept
#guard takes3 (rec2 "track_in_flight" s!"[5, {chunk3}, 1200]" [sentR s!"[{f1}, 1200]", inF "2400", wl "null"] []
    [inF "1200"] [] (ret "null") (freed ++ ["track_in_flight"]) (t := f2))
  [lNobody, "track_in_flight: a second copy"]

/-! ### window_release -/

-- the send's own bytes come back (900, not a chunk's 1200)
#guard takes3 (rec2 "window_release" s!"[5, {gq}, 3]" [sentR s!"[{f1}, 900]", inF "3000", wl "null"] []
    [sentR "null", inF "2100"] [] (ret "null") (freed ++ ["window_release"]))
  [lNobody, "window_release: a send released"]
-- nothing in flight under the key: a holding of a chunk we did not send, or one released before
#guard takes3 (rec2 "window_release" s!"[5, {gq}, 3]" [sentR "null"] [] [] [] (ret "null") ["window_release"])
  ["window_release: nothing in flight"]

/-! ### window_timeout -/

-- the send's own timer: released, its room back; the group not planned
#guard takes3 (rec2 "window_timeout" s!"[{key3}, {f1}]" [sentR s!"[{f1}, 1200]", inF "1200", wl "null", plannedR "null"]
    [] [sentR "null", inF "null"] [] (ret "null") (freed ++ ["window_timeout"]) (t := f3))
  [lNobody, "window_timeout: released"]
-- a group we plan: origin_acked(g, 3) runs, here with chunk 3 acknowledged before (origin[g] holds bit 3)
#guard takes3 (rec2 "window_timeout" s!"[{key3}, {f1}]"
    [sentR s!"[{f1}, 1200]", inF "1200", wl "null", plannedR "true", rd "origin" s!"[{gq}]" "8"] []
    [sentR "null", inF "null"] [] (ret "null") (freed ++ ["origin_acked", "window_timeout"]) (t := f3))
  [lNobody, "origin_acked: acknowledged before", "window_timeout: released"]
-- stale: a later send under the key (at 2.0), whose own timer is still to come
#guard takes3 (rec2 "window_timeout" s!"[{key3}, {f1}]" [sentR s!"[{f2}, 1200]"] [] [] [] (ret "null")
    ["window_timeout"] (t := f3))
  ["window_timeout: stale"]
-- nothing in flight: a holding released it first
#guard takes3 (rec2 "window_timeout" s!"[{key3}, {f1}]" [sentR "null"] [] [] [] (ret "null") ["window_timeout"]
    (t := f3))
  ["window_timeout: nothing in flight"]

/-! ### noted -/

/-- Entries: a pushed chunk; an answer; an IHAVE of g's indices 3 and 4; the same as two bitmaps of g; a PRUNE of
SEACAST's relations -/
def eC : String := s!"[{chunk3}, null, false]"
def eA : String := s!"[{chunk3}, null, true]"
def eI : String := s!"[null, [[\"ihave\", [[\"bits\", {gq}, 24]]]], false]"
def eI2 : String := s!"[null, [[\"ihave\", [[\"bits\", {gq}, 8], [\"bits\", {gq}, 16]]]], false]"
def ePr : String := "[null, [[\"prune\", [[\"prune\", \"row\", 0, 0, \"IN\"]]]], false]"

-- None (with_owed found nothing): offers_in(None) is []
#guard takes3 (rec2 "noted" "[5, null]" [] [] [] [offersQ "null" "[]"] (ret "null") ["noted"]) ["noted: no offers"]
-- an entry with no offers
#guard takes3 (rec2 "noted" s!"[5, {eC}]" [] [] [] [offersQ eC "[]"] (ret eC) ["noted"]) ["noted: no offers"]
-- offers ORed into what p was offered: 1 | 24
#guard takes3 (rec2 "noted" s!"[5, {eI}]" [offR "1"] [] [offR "25"] [offersQ eI s!"[{gb 24}]"] (ret eI) ["noted"]) []
-- a group named twice ORs twice: the second read is the twin's own write
#guard takes3 (rec2 "noted" s!"[5, {eI2}]" [offR "null"] [] [offR "24"] [offersQ eI2 s!"[{gb 8}, {gb 16}]"] (ret eI2)
    ["noted"])
  []

/-! ### next_to_send -/

def qR (l v : String) : String := rd "queue" s!"[5, \"{l}\"]" v
def relsR : String := rd "owed_relations" "[5]" "null"
def oaS : String := sc "owed_answers" "[5]"
def owS : String := sc "owed" "[5]"
def owRow (v : String) : String := rd "owed" "[5]" v
def owedR (v : String) : String := rd "owed" s!"[5, {gq}]" v
def recvR (v : String) : String := rd "received" s!"[{gq}]" v
def sentToR (v : String) : String := rd "sent_to" s!"[5, {gq}]" v
def wireQ (e : String) (n : Nat) : String := s!"[\"wire_size\", [5, {e}], {n}]"
/-- `list(owed[p])` in `with_owed` (seacast-lite.md:1916): the row's keys in the node's order -/
def owedKeysQ (ks : String) : String := s!"[\"keys\", \"owed\", [5], {ks}]"
/-- Each turn's start: no owed relations, and no owed answers -/
def start : List String := [relsR]
def ntsWay (w : String) : String := s!"next_to_send: {w}"

-- urgent: an IHAVE, first, with its offers noted; the normal lane not read
#guard takes3 (rec2 "next_to_send" "[5]" (start ++ [qR "urgent" s!"[{eI}]", owRow "null", offR "null"]) [oaS, owS]
    [qR "urgent" "[]", offR "24"] [owedKeysQ "[]", offersQ eI s!"[{gb 24}]"] (ret eI)
    ["next_to_send", "noted", "queue_owed_relations", "with_owed"])
  [lNothingOwed, ntsWay "urgent"]
-- owed offers alone: both lanes empty, an IHAVE of what is owed
#guard takes3 (rec2 "next_to_send" "[5]"
    (start ++ [qR "urgent" "[]", qR "normal" "[]", owRow "true", owedR "24", rd "pushed" s!"[5, {gq}]" "null",
      rd "peer_has" s!"[5, {gq}]" "null", offR "null"]) [oaS, owS]
    [owedR "null", offR "24"] [owedKeysQ s!"[{gq}]", offersQ eI s!"[{gb 24}]"] (ret eI)
    ["next_to_send", "noted", "queue_owed_relations", "with_owed"])
  [lNothingOwed, ntsWay "owed offers alone"]
-- nothing: both lanes empty, nothing owed; p leaves the line (not in it)
#guard takes3 (rec2 "next_to_send" "[5]" (start ++ [qR "urgent" "[]", qR "normal" "[]", owRow "null", wl "null"])
    [oaS, owS] [] [] (ret "null") ["leave_line", "next_to_send", "queue_owed_relations"])
  [lNothingOwed, "leave_line: not in line", ntsWay "nothing"]
-- nothing, where with_owed filters every bit (p holds what is owed): noted is not called
#guard takes3 (rec2 "next_to_send" "[5]"
    (start ++ [qR "urgent" "[]", qR "normal" "[]", owRow "true", owedR "24", rd "pushed" s!"[5, {gq}]" "null",
      rd "peer_has" s!"[5, {gq}]" "[24, 3, false, false]", wl "null"]) [oaS, owS]
    [owedR "null"] [owedKeysQ s!"[{gq}]"] (ret "null")
    ["leave_line", "next_to_send", "queue_owed_relations", "with_owed"])
  [lNothingOwed, "leave_line: not in line", ntsWay "nothing"]
-- WAIT: a chunk not ours (received), the first; 1200 bytes do not fit beside 2000; p joins the line
def nWait : String := rec2 "next_to_send" "[5]"
  (start ++ [qR "urgent" "[]", qR "normal" s!"[{eC}]", recvR "8", inF "2000", wl "null"]) [oaS]
  [wl "[5]"] [wireQ eC 1200] (ret "\"WAIT\"")
  ["acquire_room", "choose", "next_to_send", "own_chunk", "queue_owed_relations"]
#guard takes3 nWait [lNothingOwed, "choose: the first", lInLine, ntsWay "in line"]
-- a chunk, filling the window exactly; SOURCE_OFFERS not PUBLISH: origin_written is not called
#guard takes3 (rec2 "next_to_send" "[5]"
    (start ++ [qR "urgent" "[]", qR "normal" s!"[{eC}]", recvR "8", inF "1800", wl "null", sentToR "null",
      sentR "null", owRow "null"]) [oaS, owS]
    [inF "3000", qR "normal" "[]", sentToR "8", sentR s!"[{f1}, 1200]"]
    [wireQ eC 1200, afterQ f1, owedKeysQ "[]", offersQ eC "[]"]
    (ret eC)
    ["acquire_room", "choose", "filter_entry", "front", "next_to_send", "noted", "own_chunk", "queue_owed_relations",
     "track_in_flight", "wake_front", "with_owed"] (t := f1))
  [lNothingOwed, "choose: the first", lNoRoom, lRoom, "filter_entry: sent", ntsWay "a chunk", "noted: no offers"]
-- a chunk at SOURCE_OFFERS = PUBLISH: origin_written runs at its first write (here not a group we publish)
#guard takes3 (rec2 "next_to_send" "[5]"
    (start ++ [qR "urgent" "[]", qR "normal" s!"[{eC}]", recvR "8", inF "null", wl "null", sentToR "null",
      sentR "null", rd "origin" s!"[{gq}]" "null", owRow "null"]) [oaS, owS]
    [inF "1200", qR "normal" "[]", sentToR "8", sentR s!"[{f1}, 1200]"]
    [wireQ eC 1200, afterQ f1, owedKeysQ "[]", offersQ eC "[]"]
    (ret eC)
    ["acquire_room", "choose", "filter_entry", "front", "next_to_send", "noted", "origin_written", "own_chunk",
     "queue_owed_relations", "track_in_flight", "wake_front", "with_owed"] (t := f1))
  [lNothingOwed, "choose: the first", lNobody, lRoom, "filter_entry: sent", "origin_written: not a group we publish",
   ntsWay "a chunk", "noted: no offers"] (c := cPub)
-- a chunk the filter drops (card 8: p holds it): its room back, and a second turn, which finds nothing
#guard takes3 (rec2 "next_to_send" "[5]"
    (start ++ [qR "urgent" "[]", qR "normal" s!"[{eC}]", recvR "8", inF "null", wl "null",
      rd "peer_has" s!"[5, {gq}]" "[8, 3, false, false]", owRow "null"]) [oaS, owS]
    [inF "null", qR "normal" "[]"] [wireQ eC 1200] (ret "null")
    ["acquire_room", "choose", "filter_entry", "free_room", "front", "leave_line", "next_to_send", "own_chunk",
     "queue_owed_relations", "wake_front"])
  [lNothingOwed, "choose: the first", lNobody, lRoom, "filter_entry: cancelled", lNobody,
   ntsWay "nothing left of the entry, again", lNothingOwed, "leave_line: not in line", ntsWay "nothing"]
  (c := cCancel)
/-- `filter_entry(p, entry)` asked of the node: the entry as handed over, and what of it the node returns -/
def feQ (e ans : String) (log : String := "") : String := s!"[\"filter_entry\", [5, {e}], {ans}{log}]"
-- at a node that replaces filter_entry, the chunk filling the window exactly: the question in the document's place,
-- its code run at the node, outside `reached`; its read and write of sent_to are the call's log, and the write is
-- the record's too. The rest is the record above's, with no filter_entry label
def nAsked : String := rec2 "next_to_send" "[5]"
  (start ++ [qR "urgent" "[]", qR "normal" s!"[{eC}]", recvR "8", inF "1800", wl "null", sentR "null", owRow "null"])
  [oaS, owS] [inF "3000", qR "normal" "[]", sentToR "8", sentR s!"[{f1}, 1200]"]
  [wireQ eC 1200, feQ eC eC s!", \{\"cr\": [{sentToR "null"}], \"cw\": [{sentToR "8"}]}", afterQ f1, owedKeysQ "[]",
   offersQ eC "[]"]
  (ret eC)
  ["acquire_room", "choose", "front", "next_to_send", "noted", "own_chunk", "queue_owed_relations", "track_in_flight",
   "wake_front", "with_owed"] (t := f1)
#guard takes3r nAsked [lNothingOwed, "choose: the first", lNoRoom, lRoom, ntsWay "a chunk", "noted: no offers"]
-- at a node that replaces filter_entry, the node's filter_entry drops the entry: its room back, and a second turn,
-- which finds nothing
def nDropped : String := rec2 "next_to_send" "[5]"
  (start ++ [qR "urgent" "[]", qR "normal" s!"[{eC}]", recvR "8", inF "null", wl "null", owRow "null"]) [oaS, owS]
  [inF "null", qR "normal" "[]"] [wireQ eC 1200, feQ eC "null"] (ret "null")
  ["acquire_room", "choose", "free_room", "front", "leave_line", "next_to_send", "own_chunk", "queue_owed_relations",
   "wake_front"]
#guard takes3r nDropped [lNothingOwed, "choose: the first", lNobody, lRoom, lNobody,
  ntsWay "nothing left of the entry, again", lNothingOwed, "leave_line: not in line", ntsWay "nothing"]
-- at a node that replaces filter_entry, the node's filter_entry returns the entry with its chunk cleared (the
-- document's returns None there; a node's own need not): its room back, and the entry, holding nothing, is not None
-- (an `Entry` has no `__bool__`), so it goes on as control does. `with_owed` finds it empty and gives None, of which
-- `noted` asks `offers_in`, and nothing is returned
#guard takes3r (rec2 "next_to_send" "[5]"
    (start ++ [qR "urgent" "[]", qR "normal" s!"[{eC}]", recvR "8", inF "null", wl "null", owRow "null"]) [oaS, owS]
    [inF "null", qR "normal" "[]"]
    [wireQ eC 1200, feQ eC "[null, null, false]", owedKeysQ "[]", offersQ "null" "[]"]
    (ret "null")
    ["acquire_room", "choose", "free_room", "front", "next_to_send", "noted", "own_chunk", "queue_owed_relations",
     "wake_front", "with_owed"])
  [lNothingOwed, "choose: the first", lNobody, lRoom, lNobody, ntsWay "control", "noted: no offers"]
-- control: at the head it goes at once; no wire_size, no room
def nControl : String := rec2 "next_to_send" "[5]"
  (start ++ [qR "urgent" "[]", qR "normal" s!"[{ePr}]", owRow "null"]) [oaS, owS]
  [qR "normal" "[]"] [owedKeysQ "[]", offersQ ePr "[]"] (ret ePr)
  ["choose", "filter_entry", "next_to_send", "noted", "queue_owed_relations", "with_owed"]
#guard takes3 nControl [lNothingOwed, "choose: control at the head", ntsWay "control", "noted: no offers"]
-- an owed answer enqueued (has_room says yes): the normal lane then holds it, as the Python reads it after enqueue;
-- its 1200 bytes do not fit beside 2000
def nAnswer : String := rec2 "next_to_send" "[5]"
  (start ++ [rd "owed_answers" s!"[5, {gq}]" "8", qR "urgent" "[]", qR "normal" s!"[{eA}]", inF "2000", wl "null"])
  [oaS] [wl "[5]"]
  ["[\"has_room\", [5], true]", s!"[\"pop_owed_answer\", [5], {chunk3}]",
   s!"[\"enqueue\", [5, [\"entry\", {eA}], false], true]", wireQ eA 1200]
  (ret "\"WAIT\"") ["acquire_room", "choose", "next_to_send", "own_chunk", "queue_owed_relations"]
#guard takes3 nAnswer [lNothingOwed, ntsWay "an owed answer enqueued", "choose: the first", lInLine, ntsWay "in line"]
-- owed answers, and has_room says no: nothing is popped
#guard takes3 (rec2 "next_to_send" "[5]"
    (start ++ [rd "owed_answers" s!"[5, {gq}]" "8", qR "urgent" "[]", qR "normal" "[]", owRow "null", wl "null"])
    [oaS, owS] [] ["[\"has_room\", [5], false]"] (ret "null") ["leave_line", "next_to_send", "queue_owed_relations"])
  [lNothingOwed, "leave_line: not in line", ntsWay "nothing"]

/-! ### The ones that must fail -/

-- acquire_room's wrong return at the boundary: the window filled exactly is room
#guard fails3 "return value: " (rec2 "acquire_room" "[5, 1200]" [inF "1800", wl "null"] [] [inF "3000"] []
    (ret "false") ["acquire_room", "front", "wake_front"])
-- next_to_send's wrong return: nothing where it waits
#guard fails3 "return value: " (nWait.replace "\"ret\": \"WAIT\"" "\"ret\": null")
-- wire_size asked for a control entry
#guard fails3 "tape: owed[5]'s groups, of [] asked, SpecTwin.Replay.Entry.call \"wire_size\""
  (nControl.replace s!"[{owedKeysQ "[]"}, {offersQ ePr "[]"}]"
    s!"[{wireQ ePr 0}, {owedKeysQ "[]"}, {offersQ ePr "[]"}]")
-- a question out of order: writing(6) logged before writing(5)
#guard fails3 "tape: writing[5] asked" (rec2 "wake_front" "[]" [inF "1200", wl "[5, 6]"] [] []
    [wrQ 6 false, wrQ 5 true, wakeQ 6] (ret "null") ["front", "wake_front"])
-- window_release taped as a question: the twin runs it as its own now, so no reader takes it
#guard fails3 "not a question of the block: [\"window_release\""
  (rec2 "track_in_flight" s!"[5, {chunk3}, 1200]" [sentR "null"] [] [sentR s!"[{f1}, 1200]"]
    [afterQ f1, s!"[\"window_release\", [5, {gq}, 3], null]"] (ret "null") ["track_in_flight"] (t := f1))
-- the three questions' answers that their readers refuse: a wide chunk, a negative size, a group of 63 digits
#guard fails3 "tape: pop_owed_answer: its answer: a chunk here is narrow"
  (nAnswer.replace s!"[\"pop_owed_answer\", [5], {chunk3}]"
    s!"[\"pop_owed_answer\", [5], [{gq}, 3, 1, \"{root}\", \"{id3}\", 1]]")
#guard fails3 "tape: wire_size: its answer: Natural number expected"
  (nWait.replace (wireQ eC 1200) s!"[\"wire_size\", [5, {eC}], [\"-\", 1]]")
#guard fails3 "tape: offers_in: its answer: not a group key: "
  (rec2 "noted" s!"[5, {eI}]" [offR "1"] [] [offR "25"]
    [offersQ eI s!"[[\"{String.ofList (List.replicate 63 'a')}\", 24]]"] (ret eI) ["noted"])
-- sent's cells that its reader refuses: bytes not a natural number, and a key of two members
#guard fails3 "Natural number expected" (rec2 "window_release" s!"[5, {gq}, 3]" [sentR s!"[{f1}, 900.5]"] [] [] []
    (ret "null") ["window_release"])
#guard fails3 "not a send's key: " (rec2 "window_release" s!"[5, {gq}, 3]" [rd "sent" s!"[[5, {gq}]]" "null"] [] []
    [] (ret "null") ["window_release"])
-- filter_entry's question at a node that has not replaced it: the twin runs the document's, and the next question it
-- asks (track_in_flight's timer) finds the question on the tape. With the call's log, the log is checked first: the
-- document's code has written sent_to already, where the log's read has none
#guard fails3 "tape: after(0.500000, SpecTwin.Timer.windowTimeout" nDropped
#guard fails3 "tape: SpecTwin.Replay.Entry.call" nAsked
-- the question asked of another entry (solicited, where the record's is not)
#guard fails3r "tape: filter_entry[5, "
  (nAsked.replace s!"[\"filter_entry\", [5, {eC}]" s!"[\"filter_entry\", [5, {eA}]")
-- its answer's chunk wide, which the entry's reader refuses
#guard fails3r "tape: filter_entry: its answer: a chunk here is narrow"
  (nAsked.replace s!"[5, {eC}], {eC}" s!"[5, {eC}], [[{gq}, 3, 1, \"{root}\", \"{id3}\", 1], null, false]")
/-- A timer that the node's own `filter_entry` armed, as the question's log notes it: §6.1's `promise_due` for the
ask `[g, 3]` of peer 5, PROMISE and the time it was armed as their words (`after(PROMISE, promise_due, a, p, now)`) -/
def promiseNote : String := s!"[\"after\", {f1}, \"promise_due\", [[{gq}, 3], 5, {f2}]]"
/-- A synthetic alarm note for the reader's form test. The arguments are group, index, peer and arming time. -/
def alarmNote : String := s!"[\"after\", {f1}, \"Node._alarm.<locals>.alarm_due\", [{gq}, 3, 5, {f2}]]"
/-- `promiseNote` naming the toy's wrapper of `promise_due`, which no `after` of the documents arms -/
def wrapperNote : String := s!"[\"after\", {f1}, \"Node._seacast.<locals>.promise_due\", [[{gq}, 3], 5, {f2}]]"
/-- `nAsked` with `filter_entry`'s log noting the timers `ns` -/
def withNotes (ns : String) : String :=
  nAsked.replace s!"\"cw\": [{sentToR "8"}]}" s!"\"cw\": [{sentToR "8"}], \"timers\": [{ns}]}"
def nNoted : String := withNotes s!"{promiseNote}, {alarmNote}"
-- the notes of an asked call are read for their form and arm nothing, so the record passes with them as without
#guard nNoted != nAsked
#guard takes3r nNoted [lNothingOwed, "choose: the first", lNoRoom, lRoom, ntsWay "a chunk", "noted: no offers"]
-- a note whose target no `after` arms is refused where the record is read
#guard fails3r "a timer note's target is not one an after arms: " (withNotes wrapperNote)
-- a record where the twin runs its own code for a name the node has replaced is refused, naming the first such name
-- it entered: `--answers-first line` replaces `choose` and `acquire_room`, and `choose` is entered first
#guard fails3at ["acquire_room", "choose"] "the twin ran its own choose, which this node has replaced" nWait
#guard fails3at ["acquire_room"] "the twin ran its own acquire_room, which this node has replaced" nWait
-- a replaced name that the record does not enter refuses nothing: control takes no room
#guard takes3at ["acquire_room"] nControl
  [lNothingOwed, "choose: control at the head", ntsWay "control", "noted: no offers"]
-- and the records these are made from pass as they are
#guard takes3 nWait [lNothingOwed, "choose: the first", lInLine, ntsWay "in line"] &&
  takes3 nControl [lNothingOwed, "choose: control at the head", ntsWay "control", "noted: no offers"] &&
  takes3 nAnswer [lNothingOwed, ntsWay "an owed answer enqueued", "choose: the first", lInLine, ntsWay "in line"] &&
  takes3r nAsked [lNothingOwed, "choose: the first", lNoRoom, lRoom, ntsWay "a chunk", "noted: no offers"]

end Window

/-! ## §4.2's gate for cells: `on_header_validated` and `drop_outside`

Hand-written records, each written from the Python's order of reads and questions (seacast.md:1197-1221 and
:1573-1579), and each passing with "fewer" 0 and exactly the branch labels it was written for, in order:
- a root with no pending cell and no tie, whose one group has no standing request and no `want_p` entry: `tied`'s
  keys entry at :1205 and again at :1216, each empty, and nothing at :1218, where the pop finds no row;
- peer 7's tie of indices 3 and 4 of g, whose count is 4 by now: index 3, at `index_count - 1`, offered again,
  and index 4, at `index_count`, dropped; the peer emptied, with its slot, and the root's row popped;
- the tie of an expired group; a tie on a link not joined for the type, the count not known; a tied index the node
  holds, which peer 7 was asked as a last resort;
- a tie that also holds a group outside the block: that one stays, so nothing is emptied and nothing popped;
- `drop_outside` with a complemented `want_p` bitmap, whose iteration raises `ValueError`; and with a standing
  request outside, dropped, an interest bit outside, dropped, and one the node holds, kept.

The cells that waited for the header and resume level 1 are left to the directed set made from
`seacast_carried_known.py`. Four must fail: :1216's keys entry missing, the order of the groups naming another
group, `cell_groups` answering a key of 63 hex digits, and index 4 offered too.

What a record shows, and what it does not, is as in the sections above. A `pending` entry and an `asked_parked`
entry left empty are written as no entry, as the twin's state reads them. Each record is a seeded state, written
for the branches it reaches; none claims a way the toy's code reaches that state. -/

namespace Gate

open Serve (rd replay1 takes fails1 tog expQ authQ desc2 gp pg)
open Upkeep (rec2 sc)

/-- A second group, of no cell of the block -/
def g2 : String := String.ofList (List.replicate 64 'c')
def g2q : String := s!"\"{g2}\""
def cgQ (gs : String) : String := s!"[\"cell_groups\", [{rootq}], {gs}]"
def tiedK (path ks : String) : String := s!"[\"keys\", \"tied\", {path}, {ks}]"
def ordQ (gs : String) : String := s!"[\"order\", \"on_header_validated\", {gs}]"
def ordD (ps : String) : String := s!"[\"order\", \"drop_outside\", {ps}]"
def stK (ks : String) : String := s!"[\"keys\", \"standing\", [{gq}], {ks}]"
def wpK (ks : String) : String := s!"[\"keys\", \"want_p\", [], {ks}]"
def ctpQ (ps : String) : String := s!"[\"connected_topic_peers\", [], {ps}]"
def linksQ (ps : String) : String := s!"[\"links\", [\"row\"], {ps}]"
def icQ (n : Nat) : String := s!"[\"index_count\", [\"row\", {desc2}], {n}]"
def listedQ (p n : Nat) : String := s!"[\"listed\", [{p}], {n}]"
def jnD : String := "[\"join\", \"row\", \"DECLARED\", 0, \"NONE\", 1]"
/-- `tied[root]`, `tied[root][7]` and `tied[root][7][g]`, as read and as written -/
def tr : String := s!"[{rootq}]"
def tr7 : String := s!"[{rootq}, 7]"
def tr7g : String := s!"[{rootq}, 7, {gq}]"
def slot7 : String := s!"[[{rootq}, 7]]"
/-- The scans of a gate with peer 7's tie under the root, and the groups' pass over g with nothing standing -/
def scans7 : List String := [sc "tied" tr, sc "tied" tr7, sc "standing" gp, sc "want_p" "[]"]
/-- The end of the gate: :1216's keys entry, :1218's pop of the emptied row, and the groups' pass over g with
nothing standing, no `want_p` entry and an empty ledger -/
def end7 : List String :=
  [tiedK tr "[7]", tiedK tr "[]", ordQ s!"[{gq}]", stK "[]", wpK "[]", ctpQ "[]"]
/-- What a gate that empties peer 7 and the root writes, besides its own -/
def gone7 : List String :=
  [rd "pending" tr "null", rd "tied" tr7g "null", rd "tied" tr7 "null", rd "tied" tr "null", rd "tie_slot" slot7 "null"]
def reads7 (bits : String) : List String :=
  [rd "pending" tr "null", rd "tied" tr "true", rd "tied" tr7 "true", rd "tied" tr7g bits]

def lExpired : String := "on_header_validated: a tie of an expired group"
def lBeyond : String := "on_header_validated: an index beyond the count learnt meanwhile"
def lNotJoined : String := "on_header_validated: a tie on a link not joined for the type"
def lHeld : String := "on_header_validated: a tied index held"
def lAgain : String := "on_header_validated: an offer again"
def lPeerGone : String := "on_header_validated: a sender's last tie under the root gone, with its slot"
def lRootGone : String := "on_header_validated: the root's ties gone"
def lDropped : String := "drop_outside: a standing request outside, dropped"
def lBits : String := "drop_outside: interest bits outside, dropped"
def lKept : String := "drop_outside: interest kept"

/-! ### on_header_validated -/

-- no pending cell, no tie: :1205's and :1216's keys entries empty, no pop at :1218, where the row is read absent
def r0 : String :=
  rec2 "on_header_validated" s!"[{rootq}]" [rd "pending" tr "null", rd "tied" tr "null"]
    [sc "tied" tr, sc "standing" gp, sc "want_p" "[]"] [rd "pending" tr "null"]
    [cgQ s!"[{gq}]", tiedK tr "[]", tiedK tr "[]", ordQ s!"[{gq}]", stK "[]", wpK "[]", ctpQ "[]"]
    (ret "null") ["on_header_validated", "drop_outside", "ledger"]
#guard takes r0 ["ledger: empty"]

-- peer 7's tie of indices 3 and 4, g's count 4 known by now: 3 (count - 1) offered again, 4 (the count) dropped
def r1 : String :=
  rec2 "on_header_validated" s!"[{rootq}]"
    (reads7 "24" ++ [rd "park" (pg 7) "null", rd "asked_parked" s!"[[{gq}, 3]]" "null",
      rd "asked_parked" s!"[[{gq}, 4]]" "null", rd "desc" gp desc2, rd "mine" gp "null", rd "offered" (pg 7) "null",
      rd "offers" s!"[[{gq}, 3]]" "null", rd "tie_slot" slot7 "5"])
    scans7 (gone7 ++ [rd "offered" (pg 7) "8", rd "offers" s!"[[{gq}, 3]]" "[7]"])
    ([cgQ s!"[{gq}]", tiedK tr "[7]", tiedK tr7 s!"[{gq}]", expQ "false", tog, linksQ "[7]", tog, icQ 4,
      listedQ 7 0, tog, icQ 4] ++ end7)
    (ret "null") ["on_header_validated", "joined", "add_offer", "drop_outside", "ledger"]
#guard takes r1 ["add_offer: listed", lAgain, lBeyond, lPeerGone, lRootGone, "ledger: empty"]

-- the tie of an expired group: released, nothing offered, no park or last-resort count touched
def r2 : String :=
  rec2 "on_header_validated" s!"[{rootq}]" (reads7 "8" ++ [rd "tie_slot" slot7 "5"]) scans7 gone7
    ([cgQ s!"[{gq}]", tiedK tr "[7]", tiedK tr7 s!"[{gq}]", expQ "true"] ++ end7)
    (ret "null") ["on_header_validated", "drop_outside", "ledger"]
#guard takes r2 [lExpired, lPeerGone, lRootGone, "ledger: empty"]

-- indices 2 and 3 tied on a link not joined for the type, the count not known: no count asked, `mine` not read
def r3a : String :=
  rec2 "on_header_validated" s!"[{rootq}]"
    (reads7 "12" ++ [rd "park" (pg 7) "null", rd "asked_parked" s!"[[{gq}, 2]]" "null",
      rd "asked_parked" s!"[[{gq}, 3]]" "null", rd "desc" gp "null", rd "tie_slot" slot7 "5"])
    scans7 gone7
    ([cgQ s!"[{gq}]", tiedK tr "[7]", tiedK tr7 s!"[{gq}]", expQ "false", tog, linksQ "[]"] ++ end7)
    (ret "null") ["on_header_validated", "joined", "drop_outside", "ledger"]
#guard takes r3a [lNotJoined, lNotJoined, lPeerGone, lRootGone, "ledger: empty"]

-- a tied index the node holds, on a joined link; peer 7 was asked it as a last resort, and that count clears
def r3b : String :=
  rec2 "on_header_validated" s!"[{rootq}]"
    (reads7 "8" ++ [rd "park" (pg 7) "null", rd "asked_parked" s!"[[{gq}, 3]]" "[7]", rd "desc" gp "null",
      rd "mine" gp "8", rd "tie_slot" slot7 "5"])
    scans7 (gone7 ++ [rd "asked_parked" s!"[[{gq}, 3]]" "null"])
    ([cgQ s!"[{gq}]", tiedK tr "[7]", tiedK tr7 s!"[{gq}]", expQ "false", tog, linksQ "[7]"] ++ end7)
    (ret "null") ["on_header_validated", "joined", "drop_outside", "ledger"]
#guard takes r3b [lHeld, lPeerGone, lRootGone, "ledger: empty"]

-- peer 7's tie holds g, of the block, and g2, of no cell of it: g's tie goes and g2's stays, so peer 7 is not
-- emptied, :1216 deletes nothing and :1218 pops nothing
def r6 : String :=
  rec2 "on_header_validated" s!"[{rootq}]" (reads7 "8" ++ [rd "tied" s!"[{rootq}, 7, {g2q}]" "4"]) scans7
    [rd "pending" tr "null", rd "tied" tr7g "null"]
    [cgQ s!"[{gq}]", tiedK tr "[7]", tiedK tr7 s!"[{g2q}, {gq}]", expQ "true", tiedK tr "[7]", ordQ s!"[{gq}]",
     stK "[]", wpK "[]", ctpQ "[]"]
    (ret "null") ["on_header_validated", "drop_outside", "ledger"]
#guard takes r6 [lExpired, "ledger: empty"]

/-! ### drop_outside -/

-- a complemented `want_p` bitmap: its iteration raises
#guard takes (rec2 "drop_outside" s!"[{gq}]" [rd "want_p" (pg 5) "[\"-\", 1]"] [sc "standing" gp, sc "want_p" "[]"]
    [] [stK "[]", wpK "[5]"] [("raises", "\"ValueError\"")] ["drop_outside"])
  ["raises: ValueError"]

-- peer 4's standing request for index 3, outside (DECLARED, not held), dropped; its interest bit 3 the same; peer
-- 5's bit 2, which the node holds, kept, and written as it was
#guard takes (rec2 "drop_outside" s!"[{gq}]"
    [rd "standing" s!"[{gq}, 3]" "[4]", rd "routed_standing" s!"[{gq}, 3]" "null", rd "origin" gp "null",
     rd "mine" gp "4", rd "join_sent" "[4, \"row\"]" jnD, rd "want_p" (pg 4) "8", rd "want_p" (pg 5) "4",
     rd "routed_standing" s!"[{gq}, 2]" "null"]
    [sc "standing" gp, sc "want_p" "[]"]
    [rd "standing" s!"[{gq}, 3]" "[]", rd "want_p" (pg 4) "0", rd "want_p" (pg 5) "4"]
    [stK "[3]", ordD "[4]", tog, authQ "true", tog, wpK "[4, 5]", tog, authQ "true", tog, tog, authQ "true"]
    (ret "null") ["drop_outside", "outside", "our_interest_for"])
  ["outside: outside our interest", lDropped, "outside: outside our interest", lBits, "outside: held", lKept]

/-! ### The ones that must fail -/

-- :1216's keys entry missing: the twin asks the order of tied[root]'s peers there, and takes :1218's entry for it
#guard fails1 "tape: tied[" (rec2 "on_header_validated" s!"[{rootq}]" (reads7 "8" ++ [rd "tie_slot" slot7 "5"]) scans7
  gone7 ([cgQ s!"[{gq}]", tiedK tr "[7]", tiedK tr7 s!"[{gq}]", expQ "true", tiedK tr "[]", ordQ s!"[{gq}]", stK "[]",
    wpK "[]", ctpQ "[]"]) (ret "null") ["on_header_validated", "drop_outside", "ledger"])
-- the groups' order naming a group the block has not
#guard fails1 "tape: the order at on_header_validated: the node's order " (r0.replace (ordQ s!"[{gq}]") (ordQ s!"[{g2q}]"))
-- `cell_groups` answering a key of 63 hex digits
#guard fails1 "tape: cell_groups: its answer: not a group key: "
  (r0.replace (cgQ s!"[{gq}]") (cgQ s!"[\"{String.ofList (List.replicate 63 'a')}\"]"))
-- index 4, at the count, offered too
#guard fails1 "post: the whole state: " (r1.replace (rd "offered" (pg 7) "8") (rd "offered" (pg 7) "24"))
-- and each of the three replacements changed its record
#guard r0.replace (ordQ s!"[{gq}]") (ordQ s!"[{g2q}]") != r0 &&
  r0.replace (cgQ s!"[{gq}]") (cgQ s!"[\"{String.ofList (List.replicate 63 'a')}\"]") != r0 &&
  r1.replace (rd "offered" (pg 7) "8") (rd "offered" (pg 7) "24") != r1

end Gate

end SpecTwin.Seacast.ReplayKnown
