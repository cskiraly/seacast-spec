import SpecTwin.Replay
import SpecTwin.Seacast.Sample
import SpecTwin.Seacast.Writer
import SpecTwin.Seacast.Kept
import SpecTwin.Seacast.Serve
import SpecTwin.Seacast.Upkeep
import SpecTwin.Seacast.Manifest

/-! # Replaying a record of a trace under seacast.md

`runSeacast` replays one record of a trace whose header names seacast.md, as `Replay.run` replays one under
`seacast-lite.md`, and with the same verdict (`Replay.judge`).

- **The tape.** SEACAST's questions are the replay's `call` entries: a name, the arguments as compact JSON, the answer
  (`Replay.askCall`), in the forms the instance below writes. `entrySeacast` reads the entries whose form
  `seacast-lite.md`'s reader does not take or reads otherwise: an `order` and two `keys` entries, `after` with SEACAST's
  timers, `valid_have` of a whole HAVE, `shuffled` of pairs, `forward` with three arguments, a read of `chunks`
  with no check of the chunk's place (`chunksReadSeacast`), and SEACAST's question names.
- **The draws.** A `choice` answer must be a member of the question's list; where the Python draws from a set
  (`choice(list(s))`), the question's list is compared as a set. A `shuffled` answer must be a permutation of
  its question, and a `sample_without_replacement` answer k distinct members.
- **The orders.** An `order` or `keys` answer must be a permutation of the members the twin computed
  (`Replay.permOf`).
- **The values.** A record's values are read in seacast.md's forms (`docSeacast`, `Form.seacast`): `peer_has`'s entry
  with its two claims, and a lane's controls with SEACAST's IWANT, holdings and relation controls. Each position has
  one codec, injective there. An IWANT that `seacast-lite.md`'s code enqueues on its own reads into `Msg.iwant`, and
  `respond`'s entry, whose IWANT a lane holds as `.iwantSeacast`, is built so by its v2 form.
- **The functions.** `runSeacast` routes a record by the manifest (`routeSeacast`, `Seacast/Manifest.lean`). It runs
  SEACAST's functions (`fnsSeacast`, 91 with §4.1's relations and §4.11's window and writer) by their Python names,
  hands a record of one of `seacast-lite.md`'s functions that v2 keeps, or of the node's own `held` (`keptSeacast`), to
  `Replay.run`, runs the three that take another form under v2 (`keptFormsSeacast`) in their v2 forms
  (`Seacast/Kept.lean`), and refuses every other name, among them the ones v2 redefines and this cycle does not
  cover (`on_frame`, `on_heartbeat`). A record of a name the node's line replaces is refused, as `run` refuses
  one. -/

namespace SpecTwin.Seacast

open Lean (Json)
open SpecTwin.Replay

/-! ## SEACAST's values as a record writes them -/

/-- An integer in a record's signed form: a natural number, or `["-", n]` for −n (`intOf` reads it). -/
def intJson : Int → Json
  | .ofNat k => (k : Json)
  | .negSucc k => Json.arr #[Json.str "-", ((k + 1 : Nat) : Json)]

/-- A float as its 64-bit IEEE word. -/
def floatJson (x : Float) : Json := (x.toBits.toNat : Json)

def optJson {α} (f : α → Json) : Option α → Json
  | some x => f x
  | none => Json.null

def natsJson (xs : List Nat) : Json := Json.arr (xs.map fun (n : Nat) => (n : Json)).toArray

def giJson (gi : GI) : Json := Json.arr #[Json.str gi.1, (gi.2 : Json)]

def interestKindJson : InterestKind → Json
  | .all => Json.str "ALL"
  | .derived => Json.str "DERIVED"
  | .declared => Json.str "DECLARED"

def dutyJson : Duty → Json
  | .forward => Json.str "FORWARD"
  | .none => Json.str "NONE"

def directionJson : Direction → Json
  | .outward => Json.str "OUT"
  | .inward => Json.str "IN"
  | .both => Json.str "BOTH"

/-- A JOIN: `["join", T, interest, custody_count, duty, colours]` (`joinMsg` reads it). -/
def joinJson (j : Join) : Json :=
  Json.arr #[Json.str "join", Json.str j.objectType, interestKindJson j.interest, (j.custodyCount : Json),
             dutyJson j.duty, (j.colours : Json)]

/-- A relation message (`relation` reads it). -/
def relationJson : Relation → Json
  | .join m => joinJson m
  | .graft m => Json.arr #[Json.str "graft", Json.str m.objectType, intJson m.family, (m.colour : Json),
                           directionJson m.direction, Json.bool m.answer]
  | .prune m => Json.arr #[Json.str "prune", Json.str m.objectType, intJson m.family, (m.colour : Json),
                           directionJson m.direction]

/-- A HAVE: `["have", g, bits, offer, claim_all, complete]`. -/
def haveJson (h : Have) : Json :=
  Json.arr #[Json.str "have", Json.str h.group, (h.bits : Json), Json.bool h.offer, Json.bool h.claimAll,
             Json.bool h.complete]

/-- A WANT: `["want", g, bits, standing, hops, probe]`. -/
def wantJson (w : Want) : Json :=
  Json.arr #[Json.str "want", Json.str w.group, (w.bits : Json), Json.bool w.standing, (w.hops : Json),
             Json.bool w.probe]

def msgSeacastJson : MsgSeacast → Json
  | .have h => haveJson h
  | .want w => wantJson w
  | .relation r => relationJson r

/-- A record of a node or of a link: `{"id": p, "families": [...], "high": b}`, with the fields it has. -/
def coverJson (r : Cover) : Json :=
  Json.mkObj ((match r.id with | some q => [("id", (q : Json))] | none => []) ++
              [("families", Json.arr (r.families.map intJson).toArray)] ++
              (match r.high with | some b => [("high", Json.bool b)] | none => []))

/-- A v2 timer's target and arguments, as `after(delay, fn, *args)` names them. -/
def timerSeacastJson : TimerSeacast → String × Json
  | .reconsider g t => ("reconsider", Json.arr #[Json.str g, floatJson t])
  | .askSample g i => ("ask_sample", Json.arr #[Json.str g, (i : Json)])
  | .resample g i q first => ("resample", Json.arr #[Json.str g, (i : Json), (q : Json), Json.bool first])

/-! ## Reading them -/

def optOf {α} (f : Json → Except String α) (j : Json) : Except String (Option α) :=
  if j == .null then pure none else some <$> f j

def floatOf (j : Json) : Except String Float := do return Float.ofBits (← bits64 j)

def famsOf (j : Json) : Except String (List Fam) := do (← arr j).mapM intOf

def haveOf (j : Json) : Except String Have := do
  let #[.str "have", g, b, o, ca, c] ← j.getArr? | throw s!"not a HAVE: {j.compress}"
  return { group := ← Replay.groupKey g, bits := ← nat b, offer := ← boolOf o, claimAll := ← boolOf ca,
           complete := ← boolOf c }

/-- A record of a node or a link: `families`, and `id` and `high` where it has them; no other field. -/
def coverOf (j : Json) : Except String Cover := do
  let .ok kvs := j.getObj? | throw s!"not a record of a node: {j.compress}"
  if let some f := kvs.keys.find? (!["id", "families", "high"].contains ·) then
    throw s!"not a field of a node's record: {f}"
  let some fs := field j "families" | throw s!"a node's record without its families: {j.compress}"
  return { id := ← (field j "id").mapM nat, families := ← famsOf fs, high := ← (field j "high").mapM boolOf }

/-- A failure in reading type `t`'s parameter `name`, which its message then starts with. -/
def inParam {α} (t : TypeId) (name : String) (x : Except String α) : Except String α :=
  x.mapError (s!"types: {t}: {name}: " ++ ·)

/-- `REPAIR_SAMPLE`'s steps, `[[S, L], ...]`: one step or more, as the tracer writes them. -/
def repairSteps (j : Json) : Except String (List (Nat × Nat)) := do
  let l ← pairs "repair step" nat nat j
  if l.isEmpty then throw "no repair step: an empty list"
  return l

/-- A type parameter's float: its 64-bit word, finite, where `inf` lets the word of +∞ through, as a limit's
none. -/
def paramFloat (inf : Bool) (j : Json) : Except String Float := do
  match inf, j.getNat? with
  | true, .ok 9218868437227405312 => return Float.ofBits 9218868437227405312
  | _, _ => return Float.ofBits (← bits64 j)

def announceWidthOf : Json → Except String AnnounceWidth
  | .str "ALL_JOINED" => pure .allJoined
  | .str "SAMPLE" => pure .sample
  | .str "NONE" => pure .none
  | j => throw s!"not an announce width: {j.compress}"

/-- `uplink_class()`'s answer: `"FAST"` or `"HOME"`. -/
def uplinkClassOf : Json → Except String UplinkClass
  | .str "FAST" => pure .fast
  | .str "HOME" => pure .home
  | j => throw s!"not an uplink class: {j.compress}"

/-- One type's parameters in a nodes entry's `types` map, `{NAME: value, ...}` (`TypeParams`). A natural number is not
negative, and neither `M` nor `MAX_INDICES` is 0. A boolean is JSON's. A float is its 64-bit word and finite, and
`SERVE_LIMIT`, `FORWARD_LIMIT` and `MAX_RELATIONS` may be +∞. A finite `MAX_RELATIONS` is a count: not negative and
integral (−0.0 among them, which compares as 0). `ANNOUNCE_EXTRA` is one of `"ALL_JOINED"`, `"SAMPLE"` and
`"NONE"`. `EVIDENCE` is present only as `null`. `REPAIR_SAMPLE` is `null` or `[[S, L], ...]`, one step or more. A
parameter the type does not have is left out, and its read is the toy's `AttributeError`; a missing member and `null`
differ. -/
def typeParamsOf (t : TypeId) (j : Json) : Except String TypeParams := do
  let .ok kvs := j.getObj? | throw s!"types: {t}: not a map of parameters: {j.compress}"
  let mut p : TypeParams := {}
  for name in kvs.keys do
    let some v := field j name | throw s!"types: {t}: {name}: no value"
    let n : Except String Nat := inParam t name (nat v)
    let b : Except String Bool := inParam t name (boolOf v)
    let x (inf : Bool) : Except String Float := inParam t name (paramFloat inf v)
    match name with
    | "M" =>
      let m ← n
      if m == 0 then throw s!"types: {t}: M: 0, where a type has at least one chunk"
      p := { p with M := some m }
    | "F_LO" => p := { p with F_LO := some (← n) }
    | "F_HI" => p := { p with F_HI := some (← n) }
    | "D_OUT" => p := { p with D_OUT := some (← n) }
    | "D_OUT_FAST" => p := { p with D_OUT_FAST := some (← n) }
    | "D_OUT_MAX" => p := { p with D_OUT_MAX := some (← n) }
    | "SAMPLE_COVER" => p := { p with SAMPLE_COVER := some (← n) }
    | "COVER_HIGH" => p := { p with COVER_HIGH := some (← n) }
    | "ROUTE_HOPS" => p := { p with ROUTE_HOPS := some (← n) }
    | "MAX_INDICES" =>
      let k ← n
      if k == 0 then throw s!"types: {t}: MAX_INDICES: 0, where a group of a type has at least one index"
      p := { p with MAX_INDICES := some k }
    | "SYMMETRIC" => p := { p with SYMMETRIC := some (← b) }
    | "EAGER" => p := { p with EAGER := some (← b) }
    | "REPAIR_BUDGET" => p := { p with REPAIR_BUDGET := some (← b) }
    | "REPAIR_REASK" => p := { p with REPAIR_REASK := some (← b) }
    | "PRUNE_BACKOFF" => p := { p with PRUNE_BACKOFF := some (← x false) }
    | "START_DELAY" => p := { p with START_DELAY := some (← x false) }
    | "SAMPLE_RETRY" => p := { p with SAMPLE_RETRY := some (← x false) }
    | "SAMPLE_RETRY2" => p := { p with SAMPLE_RETRY2 := some (← x false) }
    | "DEFER_WINDOW" => p := { p with DEFER_WINDOW := some (← x false) }
    | "SAMPLE_WAIT" => p := { p with SAMPLE_WAIT := some (← x false) }
    | "SERVE_LIMIT" => p := { p with SERVE_LIMIT := some (← x true) }
    | "FORWARD_LIMIT" => p := { p with FORWARD_LIMIT := some (← x true) }
    | "MAX_RELATIONS" =>
      let v ← x true
      if v.isFinite && (v < 0 || v.floor != v) then         -- §1.1's `int`: a count, or +∞, the toy's default
        throw s!"types: {t}: MAX_RELATIONS: no count nor +∞: {v}"
      p := { p with MAX_RELATIONS := some v }
    | "ANNOUNCE_EXTRA" => p := { p with ANNOUNCE_EXTRA := some (← inParam t name (announceWidthOf v)) }
    | "EVIDENCE" =>
      if v != .null then throw s!"types: {t}: EVIDENCE: present only as null in this version: {v.compress}"
      p := { p with EVIDENCE := some none }
    | "REPAIR_SAMPLE" =>
      p := { p with REPAIR_SAMPLE := some (← inParam t name (optOf repairSteps v)) }
    | _ => throw s!"types: {t}: not a type parameter: {name}"
  return p

/-- A nodes entry's `types` map, `{T: {NAME: value, ...}, ...}`: the parameters of each type that
`type_of_group` can answer at the node, the payload's always. -/
def typesOf (j : Json) : Except String (List (TypeId × TypeParams)) := do
  let .ok kvs := j.getObj? | throw s!"types: not a map of types: {j.compress}"
  let l ← kvs.keys.mapM fun t => do
    let some v := field j t | throw s!"types: {t}: no value"
    return (← typeId (.str t), ← typeParamsOf t v)
  if !l.any (·.1 == "payload") then throw s!"types: no payload type: {j.compress}"
  return l

def repairVerdictOf : Json → Except String RepairVerdict
  | .str "REPAIRED" => pure .repaired
  | .str "NOT_REPAIRED" => pure .notRepaired
  | .str "ASKED" => pure .asked
  | j => throw s!"not a repair verdict: {j.compress}"

/-- `probe_promise`'s return: `null`, or `[[key, peer], time]`. -/
def probePromiseOf (j : Json) : Except String (Option ((Key × Peer) × Float)) :=
  optOf (fun j => do
    let #[kp, t] ← j.getArr? | throw s!"not a promise: {j.compress}"
    let #[k, p] ← kp.getArr? | throw s!"not a promise's key: {kp.compress}"
    return ((← key k, ← nat p), ← floatOf t)) j

/-- A list of groups, none twice. -/
def groupList (what : String) (j : Json) : Except String (List Group) := do
  let l ← (← arr j).mapM Replay.groupKey
  nodup what l
  return l

/-- A draw's answer: a member of the question's list. -/
def member {α} [BEq α] (what : String) (xs : List α) (x : α) : Except String α :=
  if xs.contains x then pure x else throw s!"{what}: not a member of the question's"

/-! ## SEACAST's tape entries -/

/-- SEACAST's questions whose entries are calls as they are. `sample_without_replacement` and
`push_rebuilt` are `seacast-lite.md`'s `call` names already. `pop_owed_answer` is a call here, its answer a chunk
written narrow, where `seacast-lite.md`'s reader takes it as an entry of its own. -/
def callNamesSeacast : List String :=
  ["type_of_group", "type_of", "index_count", "threshold", "verify", "decode", "header_of", "project", "cross",
   "family", "derived_interest", "DECODE_AT_K", "DECODE_LATER", "REPAIR_TO", "send", "links", "link_cover",
   "cover_candidates", "floor_candidates", "floor_links", "high_custody", "families", "families_with_duty",
   "wants_family", "duty_for", "route_next", "block_of", "group_of", "node_id", "interest_satisfied",
   "merge_waiting", "deferred_offers", "open_group_source", "release_wanted_groups", "open_link",
   "open_sampling_link", "choice", "own_interest", "send_have", "serve_standing", "owed_missing", "repair_verdict",
   "note_claim", "known_in_scope", "own_id", "admitted_group", "runs_type", "our_join", "candidates", "in_pushers",
   "out_pushees", "uplink_class", "pop_owed_answer", "wire_size", "offers_in"]

/-- SEACAST's own timers, the targets `after` names beside `seacast-lite.md`'s four. -/
def timersSeacast : List String := ["reconsider", "ask_sample", "resample"]

/-- A read of `chunks[g][i]` under v2: the chunk held there, which need not name that place. A rebuilt row's
chunks are column chunks, which `decode_group` stores under the row's places, and `fill` stores a received chunk
under each axis's place the same way; the chunk keeps its own coordinates and id. Its own id must still agree
with its own coordinates, and the store holds it narrow (`chunkN`). A missing chunk is outside the domain, as under
`seacast-lite.md`. -/
def chunksReadSeacast (path v : Json) : Except String Entry := do
  let #[g, i] ← path.getArr? | throw s!"not a place of chunks: {path.compress}"
  if v == .null then throw s!"chunks: no chunk there, where the Python raises: {path.compress}"
  return .readChunkAt (← Replay.groupKey g) (← nat i) (← chunkN v)

/-- The entries of a v2 record that `seacast-lite.md`'s reader does not take, or reads otherwise. -/
def entrySeacast (j : Json) : Option (Except String Entry) :=
  match j.getArr? with
  | .ok #[.str "order", .str place, ms] =>
    some (pure (.call "order" (Json.arr #[Json.str place]).compress ms.compress))
  | .ok #[.str "keys", .str "probe_waiting", .arr #[g], ks] =>
    some (pure (.call "keys" (Json.arr #[Json.str "probe_waiting", Json.arr #[g]]).compress ks.compress))
  | .ok #[.str "keys", .str "claims", .arr #[], ks] =>
    some (pure (.call "keys" (Json.arr #[Json.str "claims", Json.arr #[]]).compress ks.compress))
  | .ok #[.str "read", .str "chunks", path, v] => some (chunksReadSeacast path v)
  | .ok #[.str name, args@(.arr as), r] =>
    let call : Option (Except String Entry) := some (pure (.call name args.compress r.compress))
    if callNamesSeacast.contains name then call
    else match name, as with
      | "after", #[_, .str f, _] => if timersSeacast.contains f then call else none
      | "valid_have", #[h] => match h.getArrVal? 0 with
        | .ok (.str "have") => call
        | _ => none
      | "shuffled", #[.arr xs] =>                -- of pairs `[i, f]`; peers and indices are seacast-lite.md's entry
        match (xs[0]? : Option Json) with
        | some (.arr p) => match (p[0]? : Option Json) with
          | some (.num _) => call
          | _ => none
        | _ => none
      | "forward", #[_, _, _] => call            -- SEACAST's, with its axes; seacast-lite.md's has two arguments
      | _, _ => none
  | _ => none

/-- A `KeyError`'s key under v2, as the twin's crash names it, with its kind: a group `["group", g]` is
`group G`, a type `["type", tid]` is `type T`, and an integer in the signed form is bare. -/
def raisesKeySeacast (j : Json) : Except String String :=
  match j with
  | .arr #[.str "group", g] => do return s!"group {← Replay.groupKey g}"
  | .arr #[.str "type", t] => do return s!"type {← typeId t}"
  | j => do return toString (← intOf j)

/-- How a record of a trace under seacast.md is read. -/
def docSeacast : Doc := { entry := entrySeacast, raisesKey := raisesKeySeacast, form := .seacast }

/-! ## Answering SEACAST's questions from the tape -/

/-- A question kept as a call whose arguments the twin compares by a test, not as text: the tape's next entry
must be this question, with arguments the test takes. Its answer is read as `askCall` reads one. -/
def askCallBy {α} (name shown : String) (argsOk : Json → Bool) (read : Json → Except String α) : R α := do
  match ← pop with
  | some (.call n a r) =>
    if n != name || !(match Json.parse a with | .ok j => argsOk j | .error _ => false) then
      asked s!"{name}{shown}" (some (.call n a r))
    match Json.parse r with
    | .error e => throw s!"tape: {name}: its answer cannot be read: {e}"
    | .ok j =>
      if let .ok (.str x) := j.getObjVal? "raises" then throw s!"crash: {x}: (the node's {name})"
      match read j with
      | .ok v => return v
      | .error e => throw s!"tape: {name}: its answer: {e}"
  | e => asked s!"{name}{shown}" e

/-- Whether a return value is the record's, as `f` reads the record's. -/
def retIs {α} [BEq α] (ret : Json) (f : Json → Except String α) (v : α) : Except String Bool := do
  return v == (← f ret)

/-- The same peers, as sets. -/
def samePeers (a b : List Peer) : Bool := sortBy (· < ·) a == sortBy (· < ·) b

instance : NodeSeacast R where
  typeOfGroup g := askCall "type_of_group" [Json.str g] typeId
  typeOf t := askCall "type_of" [Json.str t] typeId
  indexCount T h := askCall "index_count" [Json.str T, optJson descriptorJson h] nat
  threshold T h := askCall "threshold" [Json.str T, optJson descriptorJson h] nat
  -- a chunk in SEACAST's questions is written narrow, `[group, index, slot, root, id]`
  verify T f h := askCall "verify" [Json.str T, chunkJson f, optJson descriptorJson h] verdict
  decode T g h := askCall "decode" [Json.str T, Json.str g, optJson descriptorJson h] fun j => do
    if j == .null then return none
    let l ← pairs "index and chunk" nat chunkN j       -- the rebuilt chunks, narrow
    nodup "decode" (l.map (·.1))
    return some l
  headerOf T f := askCall "header_of" [Json.str T, chunkJson f] (optOf descriptor)
  project T f := askCall "project" [Json.str T, chunkJson f] giList
  cross T g i := askCall "cross" [Json.str T, Json.str g, (i : Json)] giList
  family T g := askCall "family" [Json.str T, Json.str g] intOf
  derivedInterest T g h nid j :=
    askCall "derived_interest" [Json.str T, Json.str g, optJson descriptorJson h, Json.str nid, joinJson j] intOf
  decodeAtK T g := askCall "DECODE_AT_K" [Json.str T, Json.str g] boolOf
  decodeLater T g := askCall "DECODE_LATER" [Json.str T, Json.str g] (optOf floatOf)
  repairTo T g := askCall "REPAIR_TO" [Json.str T, Json.str g] (peerList "REPAIR_TO")
  send p x u := askCall "send" [(p : Json), msgSeacastJson x, Json.bool u] boolOf
  afterSeacast d t := let (f, xs) := timerSeacastJson t; askCall "after" [floatJson d, Json.str f, xs] nothing
  links T := askCall "links" [Json.str T] (peerList "links")
  linkCover q T := askCall "link_cover" [(q : Json), Json.str T] fun j => do
    let r ← coverOf j
    if r.id.isSome || r.high.isNone then throw s!"not a link's cover, its families and its flag: {j.compress}"
    return r
  coverCandidates T := askCall "cover_candidates" [Json.str T] fun j => do
    (← arr j).mapM fun x => do
      let r ← coverOf x
      if r.id.isNone || r.high.isNone then throw s!"not a candidate, its id, families and flag: {x.compress}"
      return r
  floorCandidates T := askCall "floor_candidates" [Json.str T] fun j => do
    (← arr j).mapM fun x => do
      let r ← coverOf x
      if r.id.isNone || r.high.isSome then throw s!"not a floor candidate, its id and families: {x.compress}"
      return r
  floorLinks T fam := askCall "floor_links" [Json.str T, intJson fam] (peerList "floor_links")
  highCustody q T := askCall "high_custody" [(q : Json), Json.str T] boolOf
  families T := askCall "families" [Json.str T] famsOf
  familiesWithDuty T := askCall "families_with_duty" [Json.str T] famsOf
  wantsFamily T fam := askCall "wants_family" [Json.str T, intJson fam] boolOf
  dutyFor g := askCall "duty_for" [Json.str g] duty
  routeNext T fam qs := askCall "route_next" [Json.str T, intJson fam, natsJson qs] (peerList "route_next")
  blockOf g := askCall "block_of" [Json.str g] blockKey
  groupOf b h := askCall "group_of" [blockJson b, descriptorJson h] Replay.groupKey
  nodeId p := askCall "node_id" [(p : Json)] hex
  ownId := askCall "own_id" [] hex
  admittedGroup p g := askCall "admitted_group" [(p : Json), Json.str g] boolOf
  -- §4.1's upkeep. `candidates`, `in_pushers` and `out_pushees` read the node's own tables and its peers; their
  -- answers are lists of peers, none twice, in the toy's order, which the twin keeps
  runsType t := askCall "runs_type" [Json.str t] boolOf
  ourJoin T := askCall "our_join" [Json.str T] joinMsg
  candidates T fam c d :=
    askCall "candidates" [Json.str T, intJson fam, (c : Json), directionJson d] (peerList "candidates")
  inPushers T fam c := askCall "in_pushers" [Json.str T, intJson fam, (c : Json)] (peerList "in_pushers")
  outPushees T fam c := askCall "out_pushees" [Json.str T, intJson fam, (c : Json)] (peerList "out_pushees")
  uplinkClass := askCall "uplink_class" [] uplinkClassOf
  interestSatisfied g := askCall "interest_satisfied" [Json.str g] boolOf
  validHaveSeacast h := askCall "valid_have" [haveJson h] boolOf
  mergeWaiting p h := askCall "merge_waiting" [(p : Json), haveJson h] boolOf
  deferredOffers p h := askCall "deferred_offers" [(p : Json), haveJson h] fun j => do (← arr j).mapM key
  openGroupSource g d := askCall "open_group_source" [Json.str g, descriptorJson d] nothing
  releaseWantedGroups := askCall "release_wanted_groups" [] nothing
  openLink r T := askCall "open_link" [coverJson r, Json.str T] nothing
  openSamplingLink r T := askCall "open_sampling_link" [coverJson r, Json.str T] nothing
  -- the draws: a member of the question's list
  choicePeer xs := askCall "choice" [natsJson xs] fun j => do member "choice" xs (← nat j)
  choiceOfSet xs :=                     -- `choice(list(s))`: the list in the set's order, compared as a set
    askCallBy "choice" s!"[{natsJson xs |>.compress}] as a set"
      (fun a => match a with
        | .arr #[l] => match peerList "choice" l with
          | .ok ps => samePeers ps xs
          | .error _ => false
        | _ => false)
      fun j => do member "choice" xs (← nat j)
  choiceNat xs := askCall "choice" [natsJson xs] fun j => do member "choice" xs (← nat j)
  choiceCover xs := askCall "choice" [Json.arr (xs.map coverJson).toArray] fun j => do
    member "choice" xs (← coverOf j)
  shuffledPeers xs := Node61.shuffledNats xs        -- seacast-lite.md's entry
  shuffledPairs xs := do
    let enc := fun (p : Nat × ChunkF) => Json.arr #[(p.1 : Json), chunkJson p.2]
    if xs.isEmpty then                  -- `shuffled([])`, which seacast-lite.md's reader takes as one of keys
      match ← pop with
      | some (.shuffled [] []) => return []
      | e => asked "shuffled([])" e
    -- a permutation of the question's pairs, as they are written; the twin's own pairs in the answer's order
    askCall "shuffled" [Json.arr (xs.map enc).toArray] fun j => do
      let l ← arr j
      if l.length != xs.length then throw s!"not a permutation of the question's pairs: {j.compress}"
      let mut left := xs
      let mut out : List (Nat × ChunkF) := []
      for x in l do
        match left.find? (enc · == x) with
        | some p => out := out ++ [p]; left := left.erase p
        | none => throw s!"not a permutation of the question's pairs: {j.compress}"
      return out
  sampleCovers xs k := askCall "sample_without_replacement" [Json.arr (xs.map coverJson).toArray, (k : Json)]
    fun j => do
      let l ← (← arr j).mapM coverOf
      if l.length != k then throw s!"not {k} records: {j.compress}"
      if l.eraseDups.length != l.length then throw s!"a record twice: {j.compress}"
      if !l.all xs.contains then throw s!"a record that is not of the question's: {j.compress}"
      return l
  -- the orders of proxied sets and of SEACAST's own levels: a permutation of what the twin holds
  order place xs := do
    permOf s!"the order at {place}" xs (← askCall "order" [Json.str place] (peerList s!"the order at {place}"))
  probeWaitingOrder g xs := do
    let ks ← askCall "keys" [Json.str "probe_waiting", Json.arr #[Json.str g]] (peerList "keys of probe_waiting")
    permOf s!"probe_waiting[{g}]'s keys" xs ks
  claimsOrder gs := do
    permOf "claims' keys" gs (← askCall "keys" [Json.str "claims", Json.arr #[]] (groupList "keys of claims"))
  ownInterest g := askCall "own_interest" [Json.str g] intOf
  -- §4.11's writer: the owed answer's chunk, narrow; an entry's bytes on the wire; the offers an entry carries. An
  -- entry in a question is compared by its value, read in SEACAST's form (`qentry`)
  popOwedAnswer p := askCall "pop_owed_answer" [(p : Json)] chunkN
  wireSize p e :=
    askCallBy "wire_size" s!"[{p}, {reprStr e}]"
      (fun a => match a with
        | .arr #[q, x] => q == (p : Json) && (match qentry x .seacast with | .ok e' => e' == e | .error _ => false)
        | _ => false)
      nat
  offersIn e :=
    askCallBy "offers_in" s!"[{reprStr e}]"
      (fun a => match a, e with
        | .arr #[.null], none => true
        | .arr #[x], some e => match qentry x .seacast with | .ok e' => e' == e | .error _ => false
        | _, _ => false)
      (pairs "group and bits" Replay.groupKey nat)
  -- the names a node's line can give as replaced: asked where it does, the document's body run elsewhere
  forwardNode f p axes :=
    askCall "forward" [chunkJson f, (p : Json), optJson (fun l => Json.arr (l.map giJson).toArray) axes] nothing
  pushRebuiltNode g new := askCall "push_rebuilt" [Json.str g, natsJson new] nothing
  sendHaveNode p g := askCall "send_have" [(p : Json), Json.str g] nothing
  serveStandingNode g i := askCall "serve_standing" [Json.str g, (i : Json)] nothing
  owedMissingNode g := askCall "owed_missing" [Json.str g] boolOf
  repairVerdictNode g := askCall "repair_verdict" [Json.str g] repairVerdictOf
  noteClaimNode p g := askCall "note_claim" [(p : Json), Json.str g] nothing
  knownInScopeNode g := askCall "known_in_scope" [Json.str g] nat

/-! ## One record -/

/-- The functions of `seacast-lite.md` that a record under v2 may name and that take another form under v2: the two
that call a name v2 redefines, and `respond`, whose IWANT a record under v2 writes in SEACAST's form. The replay serves
them with their v2 forms (`Seacast/Kept.lean`), not with `Replay.run`. -/
def keptFormsSeacast : List String := ["on_pace_tick", "on_block_installed", "respond"]

/-- SEACAST's functions this cycle covers, by their Python names: the manifest's covered names but the two kept forms,
the 66, main's `fill` and `serve_standing`, v0.11.1's `joined` and `drop_wants_beyond`, §4.5's serving
(`index_bound`, `our_interest_for`, `outside`, `route_want`, `on_want`), §4.1's relations with §6.3's limit
(`relation_room`, `graft`, `on_prune`, `on_graft`, `maintain_relations`, `on_join`), and §4.11's window and writer
(`wake_front`, `write_waits`, `acquire_room`, `leave_line`, `track_in_flight`, `window_release`, `window_timeout`,
`noted`, `free_room`, `next_to_send`): 91. -/
def fnsSeacast : List String := Manifest.covered.filter (!keptFormsSeacast.contains ·)

/-- The functions of `seacast-lite.md` that a record under v2 may name, which `Replay.run` serves (but `respond`, a kept
form): the manifest's kept names, `seacast-lite.md`'s all the way down by both documents' code, and the node's own
helpers (`held`). -/
def keptSeacast : List String := Manifest.kept ++ Manifest.nodeOwn.map (·.1)

/-- Where a record under v2 goes, by its function's name. -/
inductive Route where
  /-- SEACAST's own code, by one of `runSeacast`'s cases -/
  | seacast
  /-- a kept function's v2 form (`Seacast/Kept.lean`) -/
  | form
  /-- `seacast-lite.md`'s code, by `Replay.run` with SEACAST's forms -/
  | kept
  /-- no function of the twin under v2: a name v2 redefines and this cycle does not cover, or any other -/
  | refused
  deriving BEq, Repr

/-- The route of a record of `f` under v2: a kept form first, then SEACAST's covered names, then the kept names and the
node's own helpers, and every other name refused. -/
def routeSeacast (f : String) : Route :=
  if keptFormsSeacast.contains f then .form
  else if fnsSeacast.contains f then .seacast
  else if keptSeacast.contains f then .kept
  else .refused

set_option maxHeartbeats 1600000 in
/-- What one replayed record of a trace under seacast.md gives: the branches it took and how many of the
Python's reads the twin did not make, or the first difference. `params` are the types' parameters at the node;
`rowReads` the tables whose rows the trace's view logs as read (`rowReadsOf`, the header's `row_reads`). -/
def runSeacast (c : Consts) (c2 : ConstsSeacast) (params : TypeId → Option TypeParams) (replaced traced : List String)
    (r : Record) (rowReads : List String := []) : Except String (Array String × Nat) := do
  if replaced.contains r.fn then throw s!"a record of {r.fn} at a node that has replaced it"
  match routeSeacast r.fn with
  | .kept => return ← run c replaced traced r rowReads .seacast
  | .refused => throw s!"not a function of the twin under seacast.md: {r.fn}"
  | _ => pure ()
  let ctx : Ctx2 := { base := { c, now := Float.ofBits r.t, replaced }, c2, params }
  let rs0 : RSt := { tape := r.tape, twin := ← load r, rowReads }
  let exec {α} (x : M2 R α) (ok : α → Except String Bool) : Except String (Except String (State × Bool) × RSt) := do
    let (res, rs) := Id.run (((x.run ctx).run).run rs0)
    match res with
    | .ok v => return (.ok (rs.twin, ← if r.raises.isSome then pure true else ok v), rs)
    | .error e => return (.error e, rs)
  let none_ : Unit → Except String Bool := fun _ => return r.ret == .null
  let (res, rs) ← match r.fn, r.args with
    -- §1.4 and §4.1
    | "colour_of", #[g, i] => do exec (colourOf (← Replay.groupKey g) (← nat i)) (retIs r.ret nat)
    | "joined", #[p, t] => do exec (joined (← nat p) (← typeId t)) (retIs r.ret boolOf)
    | "send_relation", #[p, m] => do exec (sendRelation (← nat p) (← relation m)) none_
    | "send_join", #[p, j] => do exec (sendJoin (← nat p) (← joinMsg j)) none_
    | "prune", #[q, t, f, k, d] => do
      exec (prune (← nat q) (← typeId t) (← intOf f) (← nat k) (← direction d)) none_
    | "yes", #[p, t, f, k, d] => do exec (yes (← nat p) (← typeId t) (← intOf f) (← nat k) (← direction d)) none_
    | "no", #[p, t, f, k, d] => do exec (no (← nat p) (← typeId t) (← intOf f) (← nat k) (← direction d)) none_
    | "queue_owed_relations", #[p] => do exec (queueOwedRelations (← nat p)) none_
    | "interest_of_peer", #[p, g] => do exec (interestOfPeer (← nat p) (← Replay.groupKey g)) (retIs r.ret intOf)
    | "wants_from_me", #[p, g] => do exec (wantsFromMe (← nat p) (← Replay.groupKey g)) (retIs r.ret intOf)
    | "serves", #[q, g, i] => do exec (serves (← nat q) (← Replay.groupKey g) (← nat i)) (retIs r.ret boolOf)
    | "counted", #[need, x, t] => do       -- `need` as `[[family, count], ...]`, the dict's order
      exec (counted (← pairs "family and count" intOf intOf need) (← coverOf x) (← typeId t)) (retIs r.ret famsOf)
    | "keep_coverage", #[t] => do exec (keepCoverage (← typeId t)) none_
    | "keep_floor", #[t] => do exec (keepFloor (← typeId t)) none_
    | "relation_room", #[p, t, f, k] => do
      exec (relationRoom (← nat p) (← typeId t) (← intOf f) (← nat k)) (retIs r.ret boolOf)
    | "graft", #[q, t, f, k, d] => do
      exec (graft (← nat q) (← typeId t) (← intOf f) (← nat k) (← direction d)) none_
    | "on_prune", #[p, x] => do
      let .prune pr ← relation x | throw s!"on_prune: not a PRUNE: {x.compress}"
      exec (onPrune (← nat p) pr) none_
    | "on_graft", #[p, x] => do
      let .graft gr ← relation x | throw s!"on_graft: not a GRAFT: {x.compress}"
      exec (onGraft (← nat p) gr) none_
    | "maintain_relations", #[t] => do exec (maintainRelations (← typeId t)) none_
    | "on_join", #[p, j] => do exec (onJoin (← nat p) (← joinMsg j)) none_
    -- §4.2, §4.4, §4.7 to §4.9
    | "fills", #[g, i] => do exec (fills (← Replay.groupKey g) (← nat i)) (retIs r.ret giList)
    | "note_push", #[p, g, i] => do exec (notePush (← nat p) (← Replay.groupKey g) (← nat i)) none_
    | "suppression_scope", #[g] => do      -- a set: compared as one
      exec (suppressionScope (← Replay.groupKey g)) fun v => do return samePeers v (← peers r.ret)
    | "holding_of", #[g, b] => do exec (holdingOf (← Replay.groupKey g) (← nat b)) (retIs r.ret haveOf)
    | "send_have", #[p, g] => do exec (sendHave (← nat p) (← Replay.groupKey g)) none_
    | "announce", #[p, g, b] => do exec (announce (← nat p) (← Replay.groupKey g) (← nat b)) none_
    | "announce_extra", #[g, i] => do exec (announceExtra (← Replay.groupKey g) (← nat i)) (retIs r.ret peers)
    | "join_push", #[p, t, f, k] => do exec (joinPush (← nat p) (← typeId t) (← intOf f) (← nat k)) none_
    | "source_pool", #[t, g, k] => do exec (sourcePool (← typeId t) (← Replay.groupKey g) (← nat k)) (retIs r.ret peers)
    | "unpush", #[p, g, i] => do exec (unpush (← nat p) (← Replay.groupKey g) (← nat i)) none_
    -- a chunk argument is narrow but in on_validated, defer and on_chunk, where a chunk arrives or waits (`chunkN`)
    | "candidates_for_source", #[f] => do exec (candidatesForSource (← chunkN f)) (retIs r.ret peers)
    | "origin_written", #[f] => do exec (originWritten (← chunkN f)) none_
    | "offer_at_publish", #[g, d] => do exec (offerAtPublish (← Replay.groupKey g) (← descriptor d)) none_
    | "origin_acked", #[g, i] => do exec (originAcked (← Replay.groupKey g) (← nat i)) none_
    | "send_gossip", #[q, ids] => do exec (sendGossip (← nat q) (← (← arr ids).mapM mid)) none_
    | "projected", #[p, g] => do exec (projected (← nat p) (← Replay.groupKey g)) (retIs r.ret boolOf)
    -- the probe, §4.5's standing answers, §4.6's repair checks
    | "gated", #[a] => do exec (gated (← key a)) (retIs r.ret boolOf)
    | "settle_probe", #[g, v] => do exec (settleProbe (← Replay.groupKey g) (← optOf boolOf v)) none_
    | "probe_answer", #[g, i, p] => do exec (probeAnswer (← Replay.groupKey g) (← nat i) (← optOf nat p)) none_
    | "probe_promise", #[g, i] => do
      exec (probePromise (← Replay.groupKey g) (← nat i)) fun v => do
        let w ← probePromiseOf r.ret      -- the time compared as its bits
        return (v.map fun (k, t) => (k, t.toBits)) == (w.map fun (k, t) => (k, t.toBits))
    | "probe_waits", #[a, p] => do exec (probeWaits (← askSeacastOf a) (← nat p)) (retIs r.ret boolOf)
    | "probe_settled", #[a] => do exec (probeSettled (← askSeacastOf a)) (retIs r.ret boolOf)
    | "probe_of_claim", #[p, a] => do exec (probeOfClaim (← nat p) (← optOf askSeacastOf a)) (retIs r.ret boolOf)
    | "serve_probe", #[p, g, f] => do exec (serveProbe (← nat p) (← Replay.groupKey g) (← chunkN f)) none_
    | "serve_standing", #[g, i] => do exec (serveStanding (← Replay.groupKey g) (← nat i)) none_
    | "drop_wants_beyond", #[g] => do exec (dropWantsBeyond (← Replay.groupKey g)) none_
    | "serve_waiting_probe", #[g, i] => do exec (serveWaitingProbe (← Replay.groupKey g) (← nat i)) none_
    | "known_in_scope", #[g] => do exec (knownInScope (← Replay.groupKey g)) (retIs r.ret nat)
    | "known_across", #[g] => do exec (knownAcross (← Replay.groupKey g)) (retIs r.ret nat)
    | "ask_custodian", #[g, i] => do exec (askCustodian (← Replay.groupKey g) (← nat i)) (retIs r.ret boolOf)
    | "repair_verdict", #[g] => do exec (repairVerdict (← Replay.groupKey g)) (retIs r.ret repairVerdictOf)
    | "owed_missing", #[g] => do exec (owedMissing (← Replay.groupKey g)) (retIs r.ret boolOf)
    -- §4.5's serving, and §4.10's routed request
    | "index_bound", #[g] => do exec (indexBound (← Replay.groupKey g)) (retIs r.ret nat)
    | "our_interest_for", #[p, g] => do exec (ourInterestFor (← nat p) (← Replay.groupKey g)) (retIs r.ret intOf)
    | "outside", #[p, g, i, b] => do
      exec (outside (← nat p) (← Replay.groupKey g) (← nat i) (← boolOf b)) (retIs r.ret boolOf)
    | "route_want", #[p, g, i, h] => do
      exec (routeWant (← nat p) (← Replay.groupKey g) (← nat i) (← nat h)) (retIs r.ret boolOf)
    | "on_want", #[p, asks] => do          -- the answers, narrow, compared in order
      exec (onWant (← nat p) (← (← arr asks).mapM askSeacastOf)) fun v => do return v == (← (← arr r.ret).mapM chunkN)
    -- fill, §4.6's completion, decoding and claims, filter_entry
    | "push_rebuilt_as_source", #[g, items] => do
      exec (pushRebuiltAsSource (← Replay.groupKey g) (← pairs "index and chunk" nat chunkN items)) none_
    | "push_rebuilt", #[g, new] => do exec (pushRebuilt (← Replay.groupKey g) (← natList new)) none_
    | "fill", #[g, i, f, p] => do exec (fill (← Replay.groupKey g) (← nat i) (← chunkN f) (← optOf nat p)) none_
    | "arm", #[g, t] => do exec (arm (← Replay.groupKey g) (← floatOf t)) none_
    | "check_completion", #[g] => do exec (checkCompletion (← Replay.groupKey g)) none_
    | "defer_on_claim", #[g] => do exec (deferOnClaim (← Replay.groupKey g)) none_
    | "reconsider", #[g, t] => do exec (reconsider (← Replay.groupKey g) (← floatOf t)) none_
    | "decode_group", #[g] => do exec (decodeGroup (← Replay.groupKey g)) none_
    | "claims_close", #[p] => do exec (claimsClose (← nat p)) none_
    | "note_claim", #[p, g] => do exec (noteClaim (← nat p) (← Replay.groupKey g)) none_
    | "filter_entry", #[p, e] => do exec (filterEntry (← nat p) (← qentry e .seacast)) (retIs r.ret (optOf (qentry · .seacast)))
    -- forward, §4.2's chunk, §4.3's holding and offer
    | "forward", #[f, p] => do exec (forward (← chunkN f) (← nat p) none) none_
    | "forward", #[f, p, axes] => do exec (forward (← chunkN f) (← nat p) (← optOf giList axes)) none_
    | "on_validated", #[p, f, v] => do exec (onValidated (← nat p) (← chunkF f) (← verdict v)) none_
    | "defer", #[p, f] => do exec (defer (← nat p) (← chunkF f)) none_
    | "on_chunk", #[p, f] => do exec (onChunk (← nat p) (← chunkF f)) none_
    | "on_holding", #[p, h] => do exec (onHolding (← nat p) (← haveOf h)) none_
    | "on_offer", #[p, h] => do exec (onOffer (← nat p) (← haveOf h)) fun v => do return v == (← (← arr r.ret).mapM key)
    -- §4.10, §4.12, §4.13
    | "ask_scale", #[] => do exec askScale fun v => do return v.toBits == (← bits64 r.ret)
    | "own_chunk", #[e] => do exec (ownChunk (← qentry e .seacast)) (retIs r.ret boolOf)
    | "pick", #[q, ks] => do exec (pick (← nat q) (← natList ks)) (retIs r.ret nat)
    | "choose", #[q] => do exec (choose (← nat q)) (retIs r.ret nat)
    | "ask_sample", #[g, i] => do exec (askSample (← Replay.groupKey g) (← nat i) false) none_
    | "ask_sample", #[g, i, b] => do exec (askSample (← Replay.groupKey g) (← nat i) (← boolOf b)) none_
    | "resample", #[g, i, q, b] => do
      exec (resample (← Replay.groupKey g) (← nat i) (← nat q) (← boolOf b)) none_
    | "sample", #[g, b] => do exec (sample (← Replay.groupKey g) (← nat b)) none_
    -- §4.11's window and writer: a chunk narrow, an entry in SEACAST's form, a time as its word
    | "wake_front", #[] => do exec Seacast.wakeFront none_
    | "write_waits", #[p] => do exec (Seacast.writeWaits (← nat p)) none_
    | "free_room", #[n] => do exec (Seacast.freeRoom (← nat n)) none_
    | "acquire_room", #[p, n] => do exec (Seacast.acquireRoom (← nat p) (← nat n)) (retIs r.ret boolOf)
    | "leave_line", #[p] => do exec (Seacast.leaveLine (← nat p)) none_
    | "track_in_flight", #[p, f, n] => do exec (Seacast.trackInFlight (← nat p) (← chunkN f) (← nat n)) none_
    | "window_release", #[p, g, i] => do
      exec (Seacast.windowRelease (← nat p) (← Replay.groupKey g) (← nat i)) none_
    | "window_timeout", #[k, t] => do exec (Seacast.windowTimeout (← sendKey k) (← floatOf t)) none_
    | "noted", #[p, e] => do
      exec (Seacast.noted (← nat p) (← optOf (qentry · .seacast) e)) (retIs r.ret (optOf (qentry · .seacast)))
    | "next_to_send", #[p] => do           -- an entry, `"WAIT"` or null
      exec (Seacast.nextToSend (← nat p)) fun v => do
        let want : Next ← match r.ret with
          | .str "WAIT" => pure .wait
          | .null => pure .nothing
          | j => .entry <$> qentry j .seacast
        return v == want
    -- seacast-lite.md's two that call SEACAST's functions, in their v2 forms
    | "on_pace_tick", #[] => do exec onPaceTick none_
    | "on_block_installed", #[root] => do exec (onBlockInstalled (← rootKey root)) none_
    | "respond", #[p, asks, answers, prunes] => do
      exec (Seacast.respond (← nat p) (← (← arr asks).mapM key) (← (← arr answers).mapM chunkN) (← nat prunes)) none_
    | f, _ => throw s!"not a function of the twin under seacast.md, or not its arguments: {f}"
  judge traced r res rs

end SpecTwin.Seacast
