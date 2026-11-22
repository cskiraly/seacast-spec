import Lean.Data.Json
import SpecTwin.Basic
import SpecTwin.V2.Basic

/-! # What the replay's reading of a record starts from

The kinds of value an entry can have in a record (`Val`), the parsers of numbers, keys and lists, and a sort.
Written by hand; the per-table reading built on them is `ReplayTables.lean`, which is generated. -/

namespace SpecTwin.Replay

open Lean (Json)

/-- An entry's value, as a record writes it. A missing or empty entry has none. -/
inductive Val where
  | time (t : UInt64)                     -- a float's bits
  | peers (l : List Peer)                 -- an offer list in its order, or a set of peers sorted
  | bits (b : Nat)                        -- a bitmap
  | flag                                  -- a member of a set
  | count (n : Nat)                       -- a count, not zero
  | key (k : Key)                         -- an ask key
  | state (s : GroupState)                -- a group's state
  | lane (l : List QEntry)                -- a lane of a peer's queue, its entries in order; there and empty is a value
  | waits (l : List (Peer × ChunkF))     -- a root's waiting copies, in order; empty is no value
  | slot (n : Nat)                        -- a slot (`tie_slot`); 0 is a value
  | jobs (l : List Job)                   -- the pace queue's jobs, in order; empty is no value
  | have (e : HaveEntry)                  -- what a peer said it holds of a group, and its ttl
  | push (e : PushEntry)                  -- what the node chose to push a peer, its clock and its ttl
  | desc (d : Descriptor)                 -- a group's descriptor
  | int (n : Int)                         -- a signed count, not zero (the window's `in_flight`)
  | ids (l : List Hex)                    -- a set of opaque ids as hex, sorted (`unwanted[p]`)
  -- protocol-v2.md's (tools/gen/schema_v2.py)
  | typeId (t : V2.TypeId)                -- an object type's id (`T_of`)
  | ibits (b : V2.IBits)                  -- a bitmap that can be complemented (`interest`, `want_p`); 0 is a value
  | join (m : V2.Join)                    -- a JOIN (`join_recv`, `join_sent`)
  | colours (l : List Nat)                -- a set of colours, sorted; empty is no value
  | relations (l : List V2.Relation)      -- relation messages in order (`owed_relations`); empty is no value
  | verdict (v : Option Bool)             -- `probe_ok`'s verdict: true, false, or a stored None
  | indices (l : List Nat)                -- indices in order (`rsample`); empty is no value
  | gis (l : List GI)                     -- groups and indices in order (`held_samples`); empty is no value
  deriving BEq, Repr

/-! ## Reading a record: strictly, so that an altered field cannot pass by wrapping or collapsing -/

def nat (j : Json) : Except String Nat := j.getNat?

/-- A float's IEEE-754 word: 64 bits, and finite, as every time and delay is. -/
def bits64 (j : Json) : Except String UInt64 := do
  let n ← j.getNat?
  if n ≥ 2 ^ 64 then throw s!"not a 64-bit word: {n}"
  if !(Float.ofBits (UInt64.ofNat n)).isFinite then throw s!"not a finite float: {n}"
  return UInt64.ofNat n

/-- A group's key: 64 lowercase hex digits. -/
def group (s : String) : Except String Group := do
  if s.length == 64 && s.all (fun c => ('0' ≤ c ∧ c ≤ '9') ∨ ('a' ≤ c ∧ c ≤ 'f')) then return s
  throw s!"not a group key: {s}"

/-- No key twice in a list that stands for a map or a set. -/
def nodup {α} [BEq α] (what : String) (l : List α) : Except String Unit :=
  if l.eraseDups.length == l.length then pure () else throw s!"{what}: a key twice"

def key (j : Json) : Except String Key :=
  match j with
  | .str s => match Key.ofId s with
    | some k => pure k
    | none => throw s!"not a structured id: {s}"
  | .arr #[.str g, i] => return .want (← group g) (← i.getNat?)
  | _ => throw s!"not an ask key: {j.compress}"

def arr (j : Json) : Except String (List Json) := return (← j.getArr?).toList

def field (j : Json) (k : String) : Option Json := (j.getObjVal? k).toOption

/-- A list of rows, each a pair. -/
def pairs {α β} (what : String) (fa : Json → Except String α) (fb : Json → Except String β) (j : Json) :
    Except String (List (α × β)) := do
  (← arr j).mapM fun e => do
    let #[x, y] ← e.getArr? | throw s!"not a {what} row: {e.compress}"
    return (← fa x, ← fb y)

def peerFloats (j : Json) : Except String (List (Peer × UInt64)) := pairs "peer and time" nat bits64 j

def peers (j : Json) : Except String (List Peer) := do (← arr j).mapM nat

def groupKey (j : Json) : Except String Group := do
  let .str h := j | throw s!"not a group key: {j.compress}"
  group h

def rootKey (j : Json) : Except String Root := do
  let .str h := j | throw s!"not a root: {j.compress}"
  if h.length == 64 && h.all (fun c => ('0' ≤ c ∧ c ≤ '9') ∨ ('a' ≤ c ∧ c ≤ 'f')) then return h
  throw s!"not a root: {h}"

def groupState (j : Json) : Except String GroupState :=
  match j with
  | .str "COLLECTING" => pure .collecting
  | .str "DECODING" => pure .decoding
  | .str "COMPLETE" => pure .complete
  | .str "INVALID" => pure .invalid
  | _ => throw s!"not a group's state: {j.compress}"

def chunk (j : Json) : Except String Chunk := do
  let #[h, i] ← j.getArr? | throw s!"not a chunk: {j.compress}"
  return (← groupKey h, ← nat i)

/-- An entry of an IHAVE, as a record writes it: an id as its hex digits (one of 56 bytes read as a structured
id, any other as it is), or `["bits", group, bitmap]`. -/
def ihaveEntry (j : Json) : Except String IhaveEntry := do
  match j with
  | .arr #[.str "bits", g, b] => return .bitmap (← groupKey g) (← nat b)
  | .str s => match Key.ofId s with
    | some k => return .id k
    | none =>
      if s.length % 2 == 0 && s.all (fun c => ('0' ≤ c ∧ c ≤ '9') ∨ ('a' ≤ c ∧ c ≤ 'f')) && s.length != 112 then
        return .other s
      throw s!"not an IHAVE's entry: {j.compress}"
  | _ => throw s!"not an IHAVE's entry: {j.compress}"

/-- Byte strings as a record writes them: lowercase hex digits, two a byte. -/
def hex (j : Json) : Except String Hex := do
  let .str s := j | throw s!"not a byte string: {j.compress}"
  if s.length % 2 == 0 && s.all (fun c => ('0' ≤ c ∧ c ≤ '9') ∨ ('a' ≤ c ∧ c ≤ 'f')) then return s
  throw s!"not hex digits, two a byte: {s}"

/-- A list of byte strings (a set of ids, as a record writes `unwanted[p]`). -/
def hexes (j : Json) : Except String (List Hex) := do (← arr j).mapM hex

/-- A descriptor, as a record writes it: `[version, hash_id, encoding, count, segment_size,
total_length, root]`. -/
def descriptor (j : Json) : Except String Descriptor := do
  let #[v, h, e, c, s, t, r] ← j.getArr? | throw s!"not a descriptor: {j.compress}"
  return { version := ← nat v, hashId := ← nat h, encoding := ← nat e, count := ← nat c, segmentSize := ← nat s,
           totalLength := ← nat t, root := ← hex r }

def descriptorJson (d : Descriptor) : Json :=
  Json.arr #[d.version, d.hashId, d.encoding, d.count, d.segmentSize, d.totalLength, Json.str d.root]

/-- A blob, as a record writes it: `[length, tag]`, the tag the toy's, its tuples as lists. The twin keeps
the tag as its compact JSON. -/
def blob (j : Json) : Except String Blob := do
  let #[n, tag] ← j.getArr? | throw s!"not a blob: {j.compress}"
  return { n := ← nat n, tag := tag.compress }

def blobJson (b : Blob) : Json := Json.arr #[b.n, (Json.parse b.tag).toOption.getD (Json.str b.tag)]

/-- A chunk as a record writes it: `[group, index, slot, root, id]`, and where it arrives or waits a
sixth member, what level 1 reads of it: `[descriptor, [proof's digests], data]`. Its id is a chunk's structured id,
of its group and index (§2), as the toy's `message_id` makes it. -/
def chunkF (j : Json) : Except String ChunkF := do
  let a ← j.getArr?
  let (five, wide) ← match a with
    | #[g, i, slot, root, mid] => pure ((g, i, slot, root, mid), none)
    | #[g, i, slot, root, mid, w] =>
      let #[d, proof, data] ← w.getArr? | throw s!"not what level 1 reads of a chunk: {w.compress}"
      pure ((g, i, slot, root, mid),
            some { desc := ← (if d == .null then pure none else some <$> descriptor d),    -- none: design B's shape
                   proof := ← (← arr proof).mapM hex, data := ← blob data : Wide })
    | _ => throw s!"not a chunk: {j.compress}"
  let (g, i, slot, root, mid) := five
  let g ← groupKey g
  let i ← nat i
  -- (a chunk with no id, written null: one whose id the document's message_id cannot
  -- give, an index beyond a uint32. The twin holds it as an ask by index, which is no id: `Key.idHex`)
  if mid == .null then return { g, i, slot := ← nat slot, root := ← rootKey root, mid := .want g i, wide }
  let .str mid := mid | throw s!"not a chunk: {j.compress}"
  let some k := Key.ofId mid | throw s!"a chunk's id is not a structured id: {mid}"
  if k.group != g || k.index != i then throw s!"a chunk's id is not of its group and index: {j.compress}"
  return { g, i, slot := ← nat slot, root := ← rootKey root, mid := k, wide }

/-- A chunk where the document writes it narrow: `[group, index, slot, root, id]` exactly, read as `chunkF` reads
it, and a sixth member refused. Under protocol-v2.md a chunk is wide only where it arrives or waits, as its writer
has it (`tools/records_v2.py`, and trace3.py's `wchunk`); a lane's entry, a read of `chunks`, a decode answer,
`respond`'s answers and the chunk arguments of the other records are narrow. -/
def chunkN (j : Json) : Except String ChunkF := do
  if let .ok a := j.getArr? then
    if a.size == 6 then throw s!"a chunk here is narrow, five members: {j.compress}"
  chunkF j

/-- A block as a record writes it: `[slot, the bid's group id or null, the bid's descriptor or
null]`. -/
def blockOf (j : Json) : Except String Block := do
  let #[sl, gid, d] ← j.getArr? | throw s!"not a block: {j.compress}"
  return { slot := ← nat sl, groupId := ← if gid == .null then pure none else some <$> hex gid,
           desc := ← if d == .null then pure none else some <$> descriptor d }

/-- A lane's name in a record's path: `"urgent"` or `"normal"`. -/
def laneName (j : Json) : Except String Lane :=
  match j with
  | .str "urgent" => pure .urgent
  | .str "normal" => pure .normal
  | _ => throw s!"not a lane: {j.compress}"

/-- A root's waiting copies (`pending[root]`): `[[peer, chunk], ...]`, in order. -/
def waitList (j : Json) : Except String (List (Peer × ChunkF)) := do
  (← arr j).mapM fun e => do
    let #[p, f] ← e.getArr? | throw s!"not a waiting copy: {e.compress}"
    return (← nat p, ← chunkF f)

/-- An entry of `pushed` (§5.2): `[bits, the first push's time as its 64 bits or null, ttl]`. -/
def pushEntry (j : Json) : Except String PushEntry := do
  let #[b, fp, t] ← j.getArr? | throw s!"not an entry of pushed: {j.compress}"
  return { bits := ← nat b, firstPush := ← (if fp == .null then pure none else some <$> bits64 fp), ttl := ← nat t }

/-- An integer that can be negative, as a record writes it: a natural number, or `["-", n]` for −n, n not 0. The
tracer writes no number with a sign (`Strict.lean`). -/
def intOf (j : Json) : Except String Int := do
  match j with
  | .arr #[.str "-", n] =>
    let n ← nat n
    if n == 0 then throw "not an integer of a record: minus zero"
    return -(n : Int)
  | j => return ((← nat j) : Int)

/-! ### protocol-v2.md's keys and values, in the forms the tracer writes -/

/-- An object type's id: its string, as the toy names it (`"payload"`, `"column"`, `"row"`), not empty. -/
def typeId (j : Json) : Except String V2.TypeId := do
  let .str s := j | throw s!"not a type id: {j.compress}"
  if s.isEmpty then throw "not a type id: the empty string"
  return s

/-- A block id: 64 lowercase hex digits (a block root, or a group's own id where the type has no blocks). -/
def blockKey (j : Json) : Except String BlockId := rootKey j

def boolOf (j : Json) : Except String Bool := do
  let .bool b := j | throw s!"not a bool: {j.compress}"
  return b

/-- A direction, as the toy's string: `"OUT"`, `"IN"` or `"BOTH"`. -/
def direction (j : Json) : Except String V2.Direction :=
  match j with
  | .str "OUT" => pure .outward
  | .str "IN" => pure .inward
  | .str "BOTH" => pure .both
  | _ => throw s!"not a direction: {j.compress}"

/-- `backoff`'s inner key: `[colour, direction]`. -/
def colourDir (j : Json) : Except String ColourDir := do
  let #[c, d] ← j.getArr? | throw s!"not a colour and a direction: {j.compress}"
  return (← nat c, ← direction d)

def interestKind (j : Json) : Except String V2.InterestKind :=
  match j with
  | .str "ALL" => pure .all
  | .str "DERIVED" => pure .derived
  | .str "DECLARED" => pure .declared
  | _ => throw s!"not an interest: {j.compress}"

def duty (j : Json) : Except String V2.Duty :=
  match j with
  | .str "FORWARD" => pure .forward
  | .str "NONE" => pure .none
  | _ => throw s!"not a duty: {j.compress}"

/-- A JOIN: `["join", T, interest, custody_count, duty, colours]`. -/
def joinMsg (j : Json) : Except String V2.Join := do
  let #[.str "join", t, i, c, d, k] ← j.getArr? | throw s!"not a JOIN: {j.compress}"
  return { objectType := ← typeId t, interest := ← interestKind i, custodyCount := ← nat c, duty := ← duty d,
           colours := ← nat k }

/-- A relation message: a JOIN, `["graft", T, family, colour, direction, answer]` or
`["prune", T, family, colour, direction]`; a family in the signed form. -/
def relation (j : Json) : Except String V2.Relation := do
  match ← j.getArr? with
  | #[.str "join", _, _, _, _, _] => return .join (← joinMsg j)
  | #[.str "graft", t, f, c, d, a] =>
    return .graft { objectType := ← typeId t, family := ← intOf f, colour := ← nat c, direction := ← direction d,
                    answer := ← boolOf a }
  | #[.str "prune", t, f, c, d] =>
    return .prune { objectType := ← typeId t, family := ← intOf f, colour := ← nat c, direction := ← direction d }
  | _ => throw s!"not a relation message: {j.compress}"

def relationList (j : Json) : Except String (List V2.Relation) := do (← arr j).mapM relation

/-- `probe_ok`'s value: `true`, `false`, or `["none"]` for a stored None. -/
def probeVerdict (j : Json) : Except String (Option Bool) :=
  match j with
  | .bool b => pure (some b)
  | .arr #[.str "none"] => pure none
  | _ => throw s!"not a probe's verdict: {j.compress}"

def natList (j : Json) : Except String (List Nat) := do (← arr j).mapM nat

/-- Groups and indices in order: `[[group, index], ...]`. -/
def giList (j : Json) : Except String (List GI) := do (← arr j).mapM chunk

/-- The window's one-entry tables' names in a record's path: `"count"`, `"line"`. -/
def countKey (j : Json) : Except String CountKey :=
  match j with
  | .str "count" => pure .count
  | _ => throw s!"not the window's count's entry: {j.compress}"

def lineKey (j : Json) : Except String LineKey :=
  match j with
  | .str "line" => pure .line
  | _ => throw s!"not the window's line's entry: {j.compress}"

/-- A send's key in a record's path: `[peer, group, index]`. -/
def sendKey (j : Json) : Except String SendKey := do
  let #[p, g, i] ← j.getArr? | throw s!"not a send's key: {j.compress}"
  return (← nat p, ← groupKey g, ← nat i)

/-- The pace queue's one entry's name in a record's path: `"jobs"`. -/
def paceKey (j : Json) : Except String PaceKey :=
  match j with
  | .str "jobs" => pure .jobs
  | _ => throw s!"not the pace queue's entry: {j.compress}"

/-- The pace queue's value (§6.4): `[[peer, [id, ...], time], ...]`, the jobs in order; an id is a chunk's
structured id, a time its 64 bits. -/
def jobList (j : Json) : Except String (List Job) := do
  (← arr j).mapM fun e => do
    let #[q, ids, t] ← e.getArr? | throw s!"not a job of the pace queue: {e.compress}"
    let ids ← (← arr ids).mapM fun x => do
      let .str s := x | throw s!"not a gossip id: {x.compress}"
      let some k := Key.ofId s | throw s!"a gossip id is not a structured id: {s}"
      pure k
    return { q := ← nat q, ids, at_ := ← bits64 t }

def sortBy {α} (f : α → α → Bool) (l : List α) : List α := (l.toArray.qsort f).toList

/-! ### Values whose form is the document's: a peer's holding (`peer_has`) and a lane's controls (`queue`) -/

/-- The document whose forms a record's values take: `protocol.md`'s or protocol-v2.md's. Under each, the other's
forms are refused, as any form the reader does not know is. -/
inductive Form where
  | v1
  | v2
  deriving BEq, Repr, Inhabited

/-- A chunk under a record's document, at a place where protocol-v2.md writes it narrow: `chunkN` under
protocol-v2.md, and `chunkF` under protocol.md, as before. -/
def chunkIn (f : Form) (j : Json) : Except String ChunkF :=
  match f with
  | .v2 => chunkN j
  | .v1 => chunkF j

/-- An ask with its flags: `[key, standing, hops, probe]`. A structured id carries no flags, since the Python's is
bytes, so its ask is `[id, false, 0, false]` and any other is refused. -/
def askV2Of (j : Json) : Except String AskV2 := do
  let #[k, s, h, p] ← j.getArr? | throw s!"not an ask with its flags: {j.compress}"
  let a : AskV2 := { key := ← key k, standing := ← boolOf s, hops := ← nat h, probe := ← boolOf p }
  if let .id .. := a.key then
    if a.standing || a.hops != 0 || a.probe then throw s!"an ask of a structured id has no flags: {j.compress}"
  return a

/-- An entry of an IDONTWANT under protocol-v2.md: an id, as an IHAVE's entry is, or a holding,
`["holding", group, bits, claim_all, complete]`. A bitmap without its claims is refused. -/
def idontwantV2 (j : Json) : Except String IhaveEntry := do
  match j with
  | .arr #[.str "holding", g, b, ca, c] => return .holding (← groupKey g) (← nat b) (← boolOf ca) (← boolOf c)
  | .arr #[.str "bits", _, _] => throw s!"under protocol-v2.md an IDONTWANT's bitmap is a holding: {j.compress}"
  | j => ihaveEntry j

/-- A control message of a queue entry.
- Under `protocol.md`: `[kind, ids]`. A PRUNE has no ids in the toy's runs; a GRAFT, a JOIN, a PRUNE with ids, or
  another kind is not one the record can hold.
- Under protocol-v2.md: an IWANT is `["iwant", [ask, ...], want]`, each ask with its flags, whatever its mark and
  flags. An IHAVE is as under `protocol.md`. An IDONTWANT's bitmaps are holdings. A JOIN, a GRAFT or a PRUNE of
  v2 is `[kind, [message]]`, with one message, of that kind. gossipsub's PRUNE stays `["prune", []]`. -/
def ctl (j : Json) (f : Form := .v1) : Except String Ctl := do
  match f, ← j.getArr? with
  | .v1, #[.str "iwant", ids] => return .iwant (← (← arr ids).mapM key)
  | .v2, #[.str "iwant", asks, w] => return .iwantV2 (← boolOf w) (← (← arr asks).mapM askV2Of)
  | .v2, #[.str "iwant", _] => throw s!"under protocol-v2.md an IWANT is [\"iwant\", asks, want]: {j.compress}"
  | _, #[.str "ihave", ids] => return .ihave (← (← arr ids).mapM ihaveEntry)
  | .v1, #[.str "idontwant", ids] => return .idontwant (← (← arr ids).mapM ihaveEntry)
  | .v2, #[.str "idontwant", ids] => return .idontwant (← (← arr ids).mapM idontwantV2)
  | _, #[.str "prune", .arr #[]] => return .prune
  | .v2, #[.str k, .arr ms] =>
    if !["join", "graft", "prune"].contains k then throw s!"not a control message of a queue entry: {j.compress}"
    let #[m] := ms | throw s!"a relation control holds one message: {j.compress}"
    let r ← relation m
    let kind := match r with | .join _ => "join" | .graft _ => "graft" | .prune _ => "prune"
    if kind != k then throw s!"a relation control's message is of another kind: {j.compress}"
    return .relation r
  | _, _ => throw s!"not a control message of a queue entry: {j.compress}"

/-- A queue entry: `[chunk or null, control or null, solicited]`, its chunk and its controls in the document's forms
(the chunk narrow under protocol-v2.md, `chunkIn`). -/
def qentry (j : Json) (f : Form := .v1) : Except String QEntry := do
  let #[c, ctrl, .bool sol] ← j.getArr? | throw s!"not a queue entry: {j.compress}"
  let chunk ← if c == .null then pure none else some <$> chunkIn f c
  let control ← if ctrl == .null then pure none else some <$> (← arr ctrl).mapM (ctl · f)
  return { chunk, control, solicited := sol }

/-- A lane's value: its entries, in order. -/
def laneEntries (j : Json) (f : Form := .v1) : Except String (List QEntry) := do (← arr j).mapM (qentry · f)

/-- An entry of `peer_has` (§4.3): `[bits, ttl]` under `protocol.md`, and `[bits, ttl, claim_all, complete]` under
protocol-v2.md, with §1.5's two claims of a holding as JSON booleans. -/
def haveEntry (j : Json) (f : Form := .v1) : Except String HaveEntry := do
  match f with
  | .v1 =>
    let #[b, t] ← j.getArr? | throw s!"not an entry of peer_has: {j.compress}"
    return { bits := ← nat b, ttl := ← nat t }
  | .v2 =>
    let #[b, t, .bool ca, .bool c] ← j.getArr?
      | throw s!"not an entry of peer_has under protocol-v2.md, [bits, ttl, claim_all, complete]: {j.compress}"
    return { bits := ← nat b, ttl := ← nat t, claimAll := ca, complete := c }

/-! ### Timers, by their target and arguments: a record's own `after`, and a question's notes -/

/-- §6.1's timers by their target and arguments, as the record's own `after` writes them (the tracer's
`after_args`). An entry and a note read them with this one codec. -/
def timerV1Of : String → Array Json → Option (Except String Timer)
  | "retry_offer", #[a] => some do return .retryOffer (← key a)
  | "ask_parked", #[a] => some do return .askParked (← key a)
  | "promise_due", #[a, p, t] => some do return .promiseDue (← key a) (← nat p) (Float.ofBits (← bits64 t))
  | "window_timeout", #[k, t] => some do return .windowTimeout (← sendKey k) (Float.ofBits (← bits64 t))
  | _, _ => none

/-- v2's three timers by their target and arguments, in `timerV2Json`'s form: `reconsider [g, at]`,
`ask_sample [g, i]` and `resample [g, i, q, first]`, with a time as its word. `ask_sample` takes two arguments. -/
def timerV2Of : String → Array Json → Option (Except String V2.TimerV2)
  | "reconsider", #[g, t] => some do return .reconsider (← groupKey g) (Float.ofBits (← bits64 t))
  | "ask_sample", #[g, i] => some do return .askSample (← groupKey g) (← nat i)
  | "resample", #[g, i, q, f] => some do return .resample (← groupKey g) (← nat i) (← nat q) (← boolOf f)
  | _, _ => none

/-- The targets an `after` in a note may name: §6.1's four and v2's three. -/
def timerTargetsV1 : List String := ["retry_offer", "ask_parked", "promise_due", "window_timeout"]
def timerTargetsV2 : List String := ["reconsider", "ask_sample", "resample"]

/-- The one toy callback a note may name, by its qualified name: the timer that `--alarm-wait`'s `filter_entry`
arms. -/
def alarmDue : String := "Node._alarm.<locals>.alarm_due"

/-- What a timer that a question armed runs: one of §6.1's timers, one of v2's three, the toy callback
`alarm_due (g, i, q, at)`, or `decode_group (g)` by a `start`. -/
inductive NoteTimer where
  | v1 (t : Timer)
  | v2 (t : V2.TimerV2)
  | alarmDue (g : Group) (i : Nat) (q : Peer) (at_ : Float)
  | start (g : Group)
  deriving BEq, Repr

/-- A timer note: the delay handed to the simulator, as its word, and what the timer runs. -/
structure Note where
  delay : UInt64
  timer : NoteTimer
  deriving BEq, Repr

/-- A note's arguments, read by the target's reader: a list, of the target's form, or refused naming the target. -/
def noteArgs {α} (name : String) (xs : Json) (p : Array Json → Option (Except String α)) : Except String α := do
  let bad : Except String α := throw s!"a timer note's arguments are not {name}'s: {xs.compress}"
  let .arr as := xs | bad
  match p as with
  | some r => tryCatch r fun _ => bad
  | none => bad

/-- A timer note, `[kind, delay, target, args]`: an `after` of §6.1's four, of v2's three or of the toy
callback, or a `start` of `decode_group`. The delay is a float's word, and the arguments are in the codec of the
record's own `after`. -/
def noteOf (n : Json) : Except String Note := do
  let .arr #[k, d, f, xs] := n | throw s!"a timer note is [kind, delay, target, args]: {n.compress}"
  let delay ← tryCatch (bits64 d) fun _ => throw s!"a timer note's delay is the 64-bit word of a finite float: {n.compress}"
  match k, f with
  | .str "after", .str t =>
    if timerTargetsV1.contains t then return { delay, timer := .v1 (← noteArgs t xs (timerV1Of t)) }
    if timerTargetsV2.contains t then return { delay, timer := .v2 (← noteArgs t xs (timerV2Of t)) }
    if t == alarmDue then
      return { delay, timer := ← noteArgs t xs fun
        | #[g, i, q, a] => some do return .alarmDue (← groupKey g) (← nat i) (← nat q) (Float.ofBits (← bits64 a))
        | _ => none }
    throw s!"a timer note's target is not one an after arms: {f.compress}"
  | .str "start", .str "decode_group" =>
    return { delay, timer := ← noteArgs "decode_group" xs fun
      | #[g] => some do return .start (← groupKey g)
      | _ => none }
  | .str "start", _ => throw s!"a timer note's target is not one a start arms: {f.compress}"
  | .str "after", _ => throw s!"a timer note's target is not one an after arms: {f.compress}"
  | _, _ => throw s!"a timer note's kind is after or start: {n.compress}"

/-- A question's `timers`: its notes in the order armed. The list is never empty, since the tracer writes the
member only where the question armed a timer. -/
def notesOf (t : Json) : Except String (List Note) := do
  let .arr xs := t | throw s!"timers: not a list of notes: {t.compress}"
  if xs.isEmpty then throw s!"timers: an empty list, which the tracer does not write: {t.compress}"
  xs.toList.mapM noteOf

end SpecTwin.Replay
