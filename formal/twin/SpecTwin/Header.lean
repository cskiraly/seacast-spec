import SpecTwin.Replay
import SpecTwin.Seacast.Replay
import SpecTwin.Seacast.Manifest

/-! # The header's and the nodes line's readers, for both documents

A trace's header (its second line) names the document it was made under in its arguments (`--doc seacast`, or none for
`seacast-lite.md`), and the document decides the rest: the tables the header must name, the functions `traced` may
list, the names a subset may pick, the members of each nodes entry, and the names a node may replace. Under
`seacast-lite.md` every list is this twin's own, as the replay has always read them. Under `seacast.md` the lists
are its manifest's (`Seacast/Manifest.lean`, generated from `tools/gen/manifest_seacast.py`). `Main.lean`'s loop calls these
readers and prints each failure they give. -/

namespace SpecTwin.Header

open Lean (Json)
open SpecTwin SpecTwin.Replay

/-- The members an envelope line may have, and must have: nothing else passes. -/
def members (what : String) (j : Json) (may must : List String) : Except String Unit := do
  let .ok kvs := j.getObj? | throw s!"{what}: not an object"
  if let some f := kvs.keys.find? (!may.contains ·) then throw s!"{what}: not a member of it: {f}"
  if let some f := must.find? (!kvs.keys.contains ·) then throw s!"{what}: no {f}"

def constNames : List String :=
  ["IWANT_WINDOW", "RETRY_SLACK", "PROMISE", "PARK_TTL", "MAX_IHAVE_MESSAGES", "MAX_IHAVE_LENGTH", "MAX_PENDING_GROUPS",
   "MAX_PLAIN_CHUNKS", "CANCEL", "PROJECT", "RAREST", "FAN_IN", "UNIT", "MAX_CHUNKS", "MAX_SEGMENT_SIZE",
   "HEARTBEAT", "GOSSIP_FACTOR", "D_LAZY", "PACED", "HAVE_TTL", "GOSSIP_RETRANSMISSION",
   "DESCRIPTOR_IN_CHUNK", "PUSH_TTL", "R_NODE", "GUARD_GRACE", "UPLINK", "STRIPE_UPLINK",
   "W", "WINDOW_TIMEOUT", "SOURCE_OFFERS", "R"]

def consts (j : Json) : Except String Consts := do
  members "consts" j constNames constNames
  let f (k : String) : Except String Float := do return Float.ofBits (← bits64 (← j.getObjVal? k))
  -- STRIPE_UPLINK alone may be +∞: where card 13 is off no uplink reaches the stripe's (the toy writes math.inf;
  -- the cell without-b). Any other float of the line is finite, as `bits64` holds it.
  let fOrInf (k : String) : Except String Float := do
    let v ← j.getObjVal? k
    if v == Json.num (0x7FF0000000000000 : Nat) then return Float.ofBits 0x7FF0000000000000 else f k
  -- a limit the client does not set (§8.2) is written `null`
  let limit (k : String) : Except String (Option Nat) := do
    let v ← j.getObjVal? k
    if v == .null then return none else return some (← v.getNat?)
  return { IWANT_WINDOW := ← f "IWANT_WINDOW", RETRY_SLACK := ← f "RETRY_SLACK", PROMISE := ← f "PROMISE",
           PARK_TTL := ← f "PARK_TTL", MAX_IHAVE_MESSAGES := ← limit "MAX_IHAVE_MESSAGES",
           MAX_IHAVE_LENGTH := ← limit "MAX_IHAVE_LENGTH", MAX_PENDING_GROUPS := ← limit "MAX_PENDING_GROUPS",
           MAX_PLAIN_CHUNKS := ← (← j.getObjVal? "MAX_PLAIN_CHUNKS").getNat?,
           CANCEL := ← (← j.getObjVal? "CANCEL").getBool?, PROJECT := ← (← j.getObjVal? "PROJECT").getBool?,
           RAREST := ← (← j.getObjVal? "RAREST").getBool?, FAN_IN := ← (← j.getObjVal? "FAN_IN").getNat?,
           UNIT := ← (← j.getObjVal? "UNIT").getNat?, MAX_CHUNKS := ← (← j.getObjVal? "MAX_CHUNKS").getNat?,
           MAX_SEGMENT_SIZE := ← (← j.getObjVal? "MAX_SEGMENT_SIZE").getNat?,
           HEARTBEAT := ← f "HEARTBEAT", GOSSIP_FACTOR := ← f "GOSSIP_FACTOR",
           D_LAZY := ← (← j.getObjVal? "D_LAZY").getNat?, PACED := ← (← j.getObjVal? "PACED").getBool?,
           HAVE_TTL := ← (← j.getObjVal? "HAVE_TTL").getNat?,
           GOSSIP_RETRANSMISSION := ← (← j.getObjVal? "GOSSIP_RETRANSMISSION").getNat?,
           DESCRIPTOR_IN_CHUNK := ← (← j.getObjVal? "DESCRIPTOR_IN_CHUNK").getBool?,
           PUSH_TTL := ← (← j.getObjVal? "PUSH_TTL").getNat?,
           R_NODE := ← (← j.getObjVal? "R_NODE").getNat?, GUARD_GRACE := ← f "GUARD_GRACE",
           UPLINK := ← f "UPLINK", STRIPE_UPLINK := ← fOrInf "STRIPE_UPLINK",
           W := ← limit "W", WINDOW_TIMEOUT := ← f "WINDOW_TIMEOUT",
           R := ← (← j.getObjVal? "R").getNat?,
           SOURCE_OFFERS_PUBLISH := ← (match ← j.getObjVal? "SOURCE_OFFERS" with
             | .str "ACK" => pure false
             | .str "PUBLISH" => pure true
             | v => throw s!"consts: SOURCE_OFFERS is ACK or PUBLISH: {v.compress}") }

/-- The traced names a node may run as something else, where the twin then asks the node. -/
def replaceable : List String := ["forward", "on_iwant", "push_rebuilt", "validate_chunk"]

/-- The replaceable names taken in a trace of the whole state alone (a directed set): a scenario's level 1. No cell
runs anything but the document's `validate_chunk`; a cell's nodes line that names it is refused. -/
def replaceableWhole : List String := ["validate_chunk"]

/-- The nodes line: its entries, each `{"n": [node, ...], "consts": {...}, "replaced": [name, ...]}`.
Every node once; a replaced name is one the twin has a question for. -/
def nodesLine (j : Json) : Except String (List (Nat × Consts × List String)) := do
  let mut out : List (Nat × Consts × List String) := []
  for e in (← j.getArr?) do
    members "nodes" e ["n", "consts", "replaced"] ["n", "consts", "replaced"]
    let cj ← e.getObjVal? "consts"
    let c ← (consts cj).mapError ("nodes: " ++ ·)
    let rp ← names "nodes: replaced" (← e.getObjVal? "replaced")
    if let some f := rp.find? (!replaceable.contains ·) then
      throw s!"nodes: a replaced function the twin has no question for: {f}"
    let ids ← (← (← e.getObjVal? "n").getArr?).toList.mapM (·.getNat?)
    if ids.isEmpty then throw "nodes: an entry of no node"
    for n in ids do
      if out.any (·.1 == n) then throw s!"nodes: a node twice: {n}"
      out := (n, c, rp) :: out
  return out

/-! ## The header, by its document -/

/-- The header's document, from its arguments (`argsOf`, a list of strings where present) as the tracer reads them
(`docOf`, as `rowReadsOf` reads them): none, or `v03`, is `seacast-lite.md`; `v2` is `seacast.md`. The toy's parser
takes those two words alone. -/
def headerForm (hd : Json) : Except String Form := do
  match docOf (← argsOf hd) with
  | none | some "v03" => return .v1
  | some "seacast" => return .v2
  | some d => throw s!"header: a document this replay does not read: {d}"

/-- The tables a header names under each document: its own, then the other sections' it reads. Under `seacast-lite.md`
the twin's own tables as the schema names them (`ownTables`, generated) and the two it reads (`unwanted` is the
twin's own); under `seacast.md` the manifest's two lists. -/
def docTables : Form → List String × List String
  | .v1 => (ownTables, ["known_id", "chunks"])
  | .v2 => (Seacast.Manifest.own, Seacast.Manifest.foreign)

/-- Under `seacast.md`, what is wrong with the header's `traced`: a name the manifest cuts at every node first,
then the names it does not list as covered, kept or the node's own. -/
def tracedSeacast (traced : List String) : Option String :=
  let known := Seacast.Manifest.covered ++ Seacast.Manifest.kept ++ Seacast.Manifest.nodeOwn.map (·.1)
  match traced.find? Seacast.Manifest.cut.contains, traced.filter (!known.contains ·) with
  | some f, _ => some s!"header: traced holds {f}, which is cut at every node"
  | none, [] => none
  | none, l => some s!"header: traced names that seacast.md's manifest does not list: {", ".intercalate l}"

/-- A subset's word, `fn=NAME` or `table=NAME`, names a function the header lists as traced, or a table the
document's header names as the twin's own: else it would pick no record, and a mutant replayed on it would pass
unread. -/
def onlyKnown (f : Form) (traced : List String) (w : String) : Bool :=
  match w.splitOn "=" with
  | ["fn", fn] => traced.contains fn
  | ["table", tb] => (docTables f).1.contains tb
  | _ => false

/-- What the header gives the replay, and every failure found in it, in the order the replay prints them. -/
structure HeaderRead where
  form : Form := .v1
  /-- the functions traced: sorted names, none twice; a record's `reached` names none but these -/
  traced : Option (List String) := none
  /-- the tables whose rows the view logs as read (`rowReadsOf`) -/
  rowReads : List String := []
  failures : List String := []

/-- The header read: its document, its format, its tables, `traced`, `row_reads` and the subset's word against the
document's lists. (Its members, `whole` and its place in the trace are `Main.lean`'s.) A document the replay does not
read is a failure, and the rest is read as `seacast-lite.md`'s. -/
def readHeader (hd : Json) (only? : Option String) : HeaderRead := Id.run do
  let mut fails : List String := []
  let form := match headerForm hd with
    | .ok f => f
    | .error _ => .v1
  if let .error e := headerForm hd then fails := fails ++ [e]
  let format := (hd.getObjValAs? Nat "format").toOption
  let tables (k : String) := (hd.getObjValAs? (List String) k).toOption
  let schema := tables "own" == some (docTables form).1 && tables "foreign" == some (docTables form).2
  let traced? := (do names "traced" (← hd.getObjVal? "traced") : Except String (List String)).toOption
  if traced?.isNone then fails := fails ++ ["header: traced is not a sorted list of names, none twice"]
  if form == .v2 then
    if let some e := traced?.bind tracedSeacast then fails := fails ++ [e]
  let mut rowReads : List String := []
  match rowReadsOf hd with
  | .ok l => rowReads := l
  | .error e => fails := fails ++ [e]
  if let some w := only? then
    if !onlyKnown form (traced?.getD []) w then
      fails := fails ++ [s!"subset: --only {w}: not a function the header lists as traced, nor a table of the twin's own"]
  if format != some 7 then fails := fails ++ [s!"header: format {format}, this replay reads format 7"]
  if !schema then fails := fails ++ ["header: the tables are not this twin's (own, foreign)"]
  return { form, traced := traced?, rowReads, failures := fails }

/-- The names a subset's `fn=NAME` also picks by the tape: those a node may replace, which are asked on the tape
where replaced and are not among what the record reached there. -/
def asksNames : Form → List String
  | .v1 => replaceable
  | .v2 => Seacast.Manifest.replaceable ++ Seacast.Manifest.replaceableWhole

/-- A record's line asks `f` on the tape, by the tape entry's text, `["NAME",`, anywhere in the line, for the
replaceable names of the trace's document alone: the tape is not at the line's end, and the line is not parsed
before it is picked. Text that only looks like such an entry takes a record more. A pick may take too much, never
too little. -/
def asks (form : Form) (line f : String) : Bool :=
  (asksNames form).contains f && (line.splitOn s!"[\"{f}\",").length > 1

/-! ## The nodes line under seacast.md -/

/-- SEACAST's constants beyond `seacast-lite.md`'s 31, which a v2 entry's `consts` holds besides. -/
def constNamesSeacast : List String :=
  ["ANSWERS_FIRST", "ASK_UPLINK", "MERGE_HOLDINGS", "SAMPLE_OUTSTANDING", "SERVE_BUDGET"]

/-- A v2 entry's `consts`: `seacast-lite.md`'s 31 and SEACAST's five, exactly. `ANSWERS_FIRST` and `MERGE_HOLDINGS` are
JSON's booleans; `ASK_UPLINK` is a float as its 64-bit word, finite and not negative; `SAMPLE_OUTSTANDING` is a
JSON integer of at least 1; `SERVE_BUDGET` is one too, or `null` for no limit (the toy's `math.inf`, written as a
limit the client does not set is). -/
def constsSeacast (j : Json) : Except String (Consts × Seacast.ConstsSeacast) := do
  members "consts" j (constNames ++ constNamesSeacast) (constNames ++ constNamesSeacast)
  let .ok kvs := j.getObj? | throw "consts: not an object"
  let c ← consts (Json.mkObj (kvs.toList.filter fun (k, _) => !constNamesSeacast.contains k))
  let b (k : String) : Except String Bool := do
    match ← j.getObjVal? k with
    | .bool x => return x
    | v => throw s!"consts: {k} is true or false: {v.compress}"
  let u ← j.getObjVal? "ASK_UPLINK"
  let up ← match u.getNat? with
    | .ok n =>
      let x := Float.ofBits (UInt64.ofNat n)
      if n < 2 ^ 64 && x.isFinite && x ≥ 0 then pure x
      else throw s!"consts: ASK_UPLINK is a finite float, not negative: {u.compress}"
    | .error _ => throw s!"consts: ASK_UPLINK is a finite float, not negative: {u.compress}"
  let so ← j.getObjVal? "SAMPLE_OUTSTANDING"
  let sampleOutstanding : Nat ← match so.getNat? with
    | .ok n =>
      if n ≥ 1 then pure n
      else throw s!"consts: SAMPLE_OUTSTANDING is a natural number, at least 1: {so.compress}"
    | .error _ => throw s!"consts: SAMPLE_OUTSTANDING is a natural number, at least 1: {so.compress}"
  let sb ← j.getObjVal? "SERVE_BUDGET"
  let serveBudget : Option Nat ← match sb, sb.getNat? with
    | .null, _ => pure none
    | _, .ok n =>
      if n ≥ 1 then pure (some n)
      else throw s!"consts: SERVE_BUDGET is null or a natural number, at least 1: {sb.compress}"
    | _, .error _ => throw s!"consts: SERVE_BUDGET is null or a natural number, at least 1: {sb.compress}"
  return (c, { ANSWERS_FIRST := ← b "ANSWERS_FIRST", ASK_UPLINK := up, MERGE_HOLDINGS := ← b "MERGE_HOLDINGS",
               SAMPLE_OUTSTANDING := sampleOutstanding, SERVE_BUDGET := serveBudget })

/-- A v2 entry's `chains`: an object from a traced name to the layers the node runs under it, outermost first, each
a qualified name of the toy, or `doc` for the document's own function. -/
def chainsOf (j : Json) : Except String (List (String × List String)) := do
  let .ok kvs := j.getObj? | throw s!"chains: not a map of names: {j.compress}"
  kvs.toList.mapM fun (k, v) => do
    let bad := s!"chains: {k}: not a non-empty list of names: {v.compress}"
    let .ok a := v.getArr? | throw bad
    if a.isEmpty then throw bad
    let l ← a.toList.mapM fun x => match x with
      | .str s => pure s
      | _ => throw bad
    return (k, l)

/-- One node's configuration under `seacast.md`. -/
structure NodeV2Cfg where
  c : Consts
  c2 : Seacast.ConstsSeacast
  /-- the parameters of each type the node can answer `type_of_group` with, the payload's always -/
  types : List (Seacast.TypeId × Seacast.TypeParams)
  replaced : List String

/-- The nodes line under `seacast.md`: its entries, each `{"n": [...], "consts": {...}, "replaced": [...],
"types": {...}, "chains": {...}}`, every member required and no other. Every node once. A replaced name is never the
manifest's cut, is one the manifest lets a node replace, is `validate_chunk` only in a trace of the whole state, and
is one the header lists as traced. Of `chains`: every key is traced, every replaced name is a key, and a key whose
innermost layer is not the document's is replaced. Nothing more of `chains` is read. The first failure. -/
def nodesLineSeacast (j : Json) (whole : Bool) (traced : List String) : Except String (List (Nat × NodeV2Cfg)) := do
  let mem := ["n", "consts", "replaced", "types", "chains"]
  let mut out : List (Nat × NodeV2Cfg) := []
  for e in (← j.getArr?) do
    members "nodes" e mem mem
    let (c, c2) ← (constsSeacast (← e.getObjVal? "consts")).mapError ("nodes: " ++ ·)
    let rp ← names "nodes: replaced" (← e.getObjVal? "replaced")
    let ids ← (← (← e.getObjVal? "n").getArr?).toList.mapM (·.getNat?)
    let some n0 := ids.head? | throw "nodes: an entry of no node"
    if let some f := rp.find? Seacast.Manifest.cut.contains then
      throw s!"nodes: node {n0} has replaced {f}, which is cut at every node"
    if let some f := rp.find? (!(Seacast.Manifest.replaceable ++ Seacast.Manifest.replaceableWhole).contains ·) then
      throw s!"nodes: a replaced function the twin has no question for: {f}"
    if !whole && rp.any Seacast.Manifest.replaceableWhole.contains then
      throw s!"nodes: node {n0} has replaced {rp.filter Seacast.Manifest.replaceableWhole.contains}, which only a trace of the whole state may"
    if rp.any (!traced.contains ·) then
      throw s!"nodes: node {n0} has replaced {rp.filter (!traced.contains ·)}, which the header does not list as traced"
    let types ← (Seacast.typesOf (← e.getObjVal? "types")).mapError ("nodes: " ++ ·)
    let ch ← (chainsOf (← e.getObjVal? "chains")).mapError ("nodes: " ++ ·)
    if let some (k, _) := ch.find? (!traced.contains ·.1) then
      throw s!"nodes: chains: a name the header does not list as traced: {k}"
    if let some f := rp.find? (fun f => !ch.any (·.1 == f)) then
      throw s!"nodes: chains: a replaced name with no chain: {f}"
    if let some (k, _) := ch.find? (fun (k, l) => l.getLast? != some "doc" && !rp.contains k) then
      throw s!"nodes: chains: {k}: its innermost layer is not the document's, and the node has not replaced it"
    for n in ids do
      if out.any (·.1 == n) then throw s!"nodes: a node twice: {n}"
      out := (n, { c, c2, types, replaced := rp }) :: out
  return out

end SpecTwin.Header
