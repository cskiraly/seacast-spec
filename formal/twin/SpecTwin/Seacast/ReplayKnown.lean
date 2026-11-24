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

One hand-written record per branch label of `on_want`, `outside` and `route_want`, and per case of `index_bound` and
`our_interest_for`, each written from the Python's order of reads and questions. Each passes with "fewer" 0 and the
branch labels it was written for, in order. Three must fail: a wrong return, a question out of order, and a record of
`on_want` at a node that replaced it. Peer 4 asks index 3 of g, of the type `row`. -/

namespace Serve

/-- The type `row`: M = 4, a serving limit of 2, at most 8 indices before a group's count is known, and one routed
request passed on per link -/
def params1 : TypeId → Option TypeParams := fun T =>
  if T == "row" then some { M := some 4, SERVE_LIMIT := some 2.0, MAX_INDICES := some 8, FORWARD_LIMIT := some 1.0 }
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
def sendQ (hops : Nat) (r : String) : String :=
  s!"[\"send\", [5, [\"want\", {gq}, 8, true, {hops}, false], false], {r}]"

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
-- an index the group cannot have: 9, past MAX_INDICES 8 with no count known
#guard takes (rec1 "on_want" s!"[4, [{askOf 9}]]" [rd "desc" gp "null"] [] [tog, linksQ "[4]", expQ "false", tog]
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
-- an id answered in this frame: index 5 of g resolves to the id index 3 was answered with
#guard takes (rec1 "on_want" s!"[4, [{askOf 3}, {askOf 5}]]" (readsTo ++ readsAnswer) writesAnswer
    (tapeTo ++ [resQ 3 id3q, chunkQ] ++ tapeTo ++ [resQ 5 id3q]) (ret s!"[{chunk3}]") reachedTo)
  [inInterest, "on_want: answered", inInterest, "on_want: an id answered in this frame"]
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

-- the three that must fail: a wrong return, a question out of order, a record at a node that replaced on_want
#guard fails1 "return value: toy " (rec1 "on_want" s!"[4, [{askOf 3}]]" readsTo [] (tapeTo ++ [resQ 3 "null"])
  (ret s!"[{chunk3}]") reachedTo)
#guard fails1 "tape: type_of_group" (rec1 "on_want" s!"[4, [{askOf 3}]]" [] [] [linksQ "[5]", tog] (ret "[]")
  ["on_want", "joined"])
#guard fails1 "a record of on_want at a node that has replaced it" w1 (replaced := ["on_want"])

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
-- a type with no MAX_INDICES at the node: AttributeError
#guard takes (rec1 "index_bound" s!"[{gq}]" [rd "desc" gp "null"] [] [s!"[\"type_of_group\", [{gq}], \"column\"]"]
  [("raises", "\"AttributeError\"")] ["index_bound"]) ["raises: AttributeError"]
#guard takes (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) (jn "ALL" "NONE")] [] [tog]
  (ret "[\"-\", 1]") ["our_interest_for"]) []
#guard takes (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) (jn "DECLARED" "NONE")] [] [tog]
  (ret "0") ["our_interest_for"]) []
-- DERIVED: hdr.get(g) read, own_id() asked, then derived_interest
#guard takes (rec1 "our_interest_for" s!"[4, {gq}]" [rd "join_sent" (pT 4) (jn "DERIVED" "NONE"), rd "desc" gp "null"]
  [] [tog, s!"[\"own_id\", [], {nid}]",
      s!"[\"derived_interest\", [\"row\", {gq}, null, {nid}, {jn "DERIVED" "NONE"}], 6]"] (ret "6")
  ["our_interest_for"]) []

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

end Serve

end SpecTwin.Seacast.ReplayKnown
