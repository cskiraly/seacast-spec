import SpecTwin.Replay
import SpecTwin.V2.Sample

/-! # Replaying a record of a trace under protocol-v2.md

`runV2` replays one record of a trace whose header names protocol-v2.md, as `Replay.run` replays one under
`protocol.md`, and with the same verdict (`Replay.judge`).

- **The tape.** v2's questions are the replay's `call` entries: a name, the arguments as compact JSON, the answer
  (`Replay.askCall`), in the forms the instance below writes. `entryV2` reads the entries whose form
  `protocol.md`'s reader does not take or reads otherwise: an `order` and two `keys` entries, `after` with v2's
  timers, `valid_have` of a whole HAVE, `shuffled` of pairs, `forward` with three arguments, a read of `chunks`
  with no check of the chunk's place (`chunksReadV2`), and v2's question names.
- **The draws.** A `choice` answer must be a member of the question's list; where the Python draws from a set
  (`choice(list(s))`), the question's list is compared as a set. A `shuffled` answer must be a permutation of
  its question, and a `sample_without_replacement` answer k distinct members.
- **The orders.** An `order` or `keys` answer must be a permutation of the members the twin computed
  (`Replay.permOf`).
- **The functions.** `runV2` runs v2's 68 functions by their Python names, hands a record of one of
  `protocol.md`'s functions that v2 keeps (`keptV2`) to `Replay.run`, and refuses every other name,
  among them the ones v2 redefines and this cycle does not cover (`on_frame`, `on_heartbeat`, `next_to_send`,
  `wake_front`, `track_in_flight`, `window_release`, `window_timeout`). A record of a name the node's line
  replaces is refused, as `run` refuses one. -/

namespace SpecTwin.V2

open Lean (Json)
open SpecTwin.Replay

/-! ## v2's values as a record writes them -/

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

def msgV2Json : MsgV2 → Json
  | .have h => haveJson h
  | .want w => wantJson w
  | .relation r => relationJson r

/-- A record of a node or of a link: `{"id": p, "families": [...], "high": b}`, with the fields it has. -/
def coverJson (r : Cover) : Json :=
  Json.mkObj ((match r.id with | some q => [("id", (q : Json))] | none => []) ++
              [("families", Json.arr (r.families.map intJson).toArray)] ++
              (match r.high with | some b => [("high", Json.bool b)] | none => []))

/-- A v2 timer's target and arguments, as `after(delay, fn, *args)` names them. -/
def timerV2Json : TimerV2 → String × Json
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

/-- An ask with its flags: `[key, standing, hops, probe]`. -/
def askV2Of (j : Json) : Except String AskV2 := do
  let #[k, s, h, p] ← j.getArr? | throw s!"not an ask with its flags: {j.compress}"
  return { key := ← key k, standing := ← boolOf s, hops := ← nat h, probe := ← boolOf p }

/-- A record of a node or a link: `families`, and `id` and `high` where it has them; no other field. -/
def coverOf (j : Json) : Except String Cover := do
  let .ok kvs := j.getObj? | throw s!"not a record of a node: {j.compress}"
  if let some f := kvs.keys.find? (!["id", "families", "high"].contains ·) then
    throw s!"not a field of a node's record: {f}"
  let some fs := field j "families" | throw s!"a node's record without its families: {j.compress}"
  return { id := ← (field j "id").mapM nat, families := ← famsOf fs, high := ← (field j "high").mapM boolOf }

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

/-! ## v2's tape entries -/

/-- v2's questions whose entries are calls as they are. `sample_without_replacement` and
`push_rebuilt` are `protocol.md`'s `call` names already. -/
def callNamesV2 : List String :=
  ["type_of_group", "type_of", "index_count", "threshold", "verify", "decode", "header_of", "project", "cross",
   "family", "derived_interest", "DECODE_AT_K", "DECODE_LATER", "REPAIR_TO", "send", "links", "link_cover",
   "cover_candidates", "floor_candidates", "floor_links", "high_custody", "families", "families_with_duty",
   "wants_family", "duty_for", "route_next", "block_of", "group_of", "node_id", "interest_satisfied",
   "merge_waiting", "deferred_offers", "open_group_source", "open_link", "open_sampling_link", "choice",
   "own_interest", "window_release", "send_have", "serve_standing", "owed_missing", "repair_verdict", "note_claim",
   "known_in_scope"]

/-- v2's own timers, the targets `after` names beside `protocol.md`'s four. -/
def timersV2 : List String := ["reconsider", "ask_sample", "resample"]

/-- A read of `chunks[g][i]` under v2: the chunk held there, which need not name that place. A rebuilt row's
chunks are column chunks, which `decode_group` stores under the row's places, and `fill` stores a received chunk
under each axis's place the same way; the chunk keeps its own coordinates and id. Its own id must still agree
with its own coordinates (`chunkF`). A missing chunk is outside the domain, as under `protocol.md`. -/
def chunksReadV2 (path v : Json) : Except String Entry := do
  let #[g, i] ← path.getArr? | throw s!"not a place of chunks: {path.compress}"
  if v == .null then throw s!"chunks: no chunk there, where the Python raises: {path.compress}"
  return .readChunkAt (← Replay.groupKey g) (← nat i) (← chunkF v)

/-- The entries of a v2 record that `protocol.md`'s reader does not take, or reads otherwise. -/
def entryV2 (j : Json) : Option (Except String Entry) :=
  match j.getArr? with
  | .ok #[.str "order", .str place, ms] =>
    some (pure (.call "order" (Json.arr #[Json.str place]).compress ms.compress))
  | .ok #[.str "keys", .str "probe_waiting", .arr #[g], ks] =>
    some (pure (.call "keys" (Json.arr #[Json.str "probe_waiting", Json.arr #[g]]).compress ks.compress))
  | .ok #[.str "keys", .str "claims", .arr #[], ks] =>
    some (pure (.call "keys" (Json.arr #[Json.str "claims", Json.arr #[]]).compress ks.compress))
  | .ok #[.str "read", .str "chunks", path, v] => some (chunksReadV2 path v)
  | .ok #[.str name, args@(.arr as), r] =>
    let call : Option (Except String Entry) := some (pure (.call name args.compress r.compress))
    if callNamesV2.contains name then call
    else match name, as with
      | "after", #[_, .str f, _] => if timersV2.contains f then call else none
      | "valid_have", #[h] => match h.getArrVal? 0 with
        | .ok (.str "have") => call
        | _ => none
      | "shuffled", #[.arr xs] =>                -- of pairs `[i, f]`; peers and indices are protocol.md's entry
        match (xs[0]? : Option Json) with
        | some (.arr p) => match (p[0]? : Option Json) with
          | some (.num _) => call
          | _ => none
        | _ => none
      | "forward", #[_, _, _] => call            -- v2's, with its axes; protocol.md's has two arguments
      | _, _ => none
  | _ => none

/-- A `KeyError`'s key under v2: a group `["group", g]`, a type `["type", tid]`, or an integer in
the signed form; as the twin's crash names it. -/
def raisesKeyV2 (j : Json) : Except String String :=
  match j with
  | .arr #[.str "group", g] => Replay.groupKey g
  | .arr #[.str "type", t] => typeId t
  | j => do return toString (← intOf j)

/-- How a record of a trace under protocol-v2.md is read. -/
def docV2 : Doc := { entry := entryV2, raisesKey := raisesKeyV2 }

/-! ## Answering v2's questions from the tape -/

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

instance : NodeV2 R where
  typeOfGroup g := askCall "type_of_group" [Json.str g] typeId
  typeOf t := askCall "type_of" [Json.str t] typeId
  indexCount T h := askCall "index_count" [Json.str T, optJson descriptorJson h] nat
  threshold T h := askCall "threshold" [Json.str T, optJson descriptorJson h] nat
  -- a chunk in v2's questions is written narrow, `[group, index, slot, root, id]`
  verify T f h := askCall "verify" [Json.str T, chunkJson f, optJson descriptorJson h] verdict
  decode T g h := askCall "decode" [Json.str T, Json.str g, optJson descriptorJson h] fun j => do
    if j == .null then return none
    let l ← pairs "index and chunk" nat chunkF j
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
  send p x u := askCall "send" [(p : Json), msgV2Json x, Json.bool u] boolOf
  afterV2 d t := let (f, xs) := timerV2Json t; askCall "after" [floatJson d, Json.str f, xs] nothing
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
  interestSatisfied g := askCall "interest_satisfied" [Json.str g] boolOf
  validHaveV2 h := askCall "valid_have" [haveJson h] boolOf
  mergeWaiting p h := askCall "merge_waiting" [(p : Json), haveJson h] boolOf
  deferredOffers p h := askCall "deferred_offers" [(p : Json), haveJson h] fun j => do (← arr j).mapM key
  openGroupSource g d := askCall "open_group_source" [Json.str g, descriptorJson d] nothing
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
  shuffledPeers xs := Node61.shuffledNats xs        -- protocol.md's entry
  shuffledPairs xs := do
    let enc := fun (p : Nat × ChunkF) => Json.arr #[(p.1 : Json), chunkJson p.2]
    if xs.isEmpty then                  -- `shuffled([])`, which protocol.md's reader takes as one of keys
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
  -- the orders of proxied sets and of v2's own levels: a permutation of what the twin holds
  order place xs := do
    permOf s!"the order at {place}" xs (← askCall "order" [Json.str place] (peerList s!"the order at {place}"))
  probeWaitingOrder g xs := do
    let ks ← askCall "keys" [Json.str "probe_waiting", Json.arr #[Json.str g]] (peerList "keys of probe_waiting")
    permOf s!"probe_waiting[{g}]'s keys" xs ks
  claimsOrder gs := do
    permOf "claims' keys" gs (← askCall "keys" [Json.str "claims", Json.arr #[]] (groupList "keys of claims"))
  ownInterest g := askCall "own_interest" [Json.str g] intOf
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

/-- The functions that the 71 call and this cycle leaves out: a question at every node until transcribed. -/
instance : V2Later R where
  windowRelease p g i := askCall "window_release" [(p : Json), Json.str g, (i : Json)] nothing

/-! ## One record -/

/-- v2's functions this cycle covers, by their Python names: the 66 and main's `fill` and `serve_standing`. -/
def fnsV2 : List String :=
  ["colour_of", "send_relation", "send_join", "prune", "yes", "no", "queue_owed_relations", "interest_of_peer",
   "wants_from_me", "serves", "counted", "keep_coverage", "keep_floor",
   "fills", "note_push", "suppression_scope", "holding_of", "send_have", "announce", "announce_extra", "join_push",
   "source_pool", "unpush", "candidates_for_source", "origin_written", "offer_at_publish", "origin_acked",
   "send_gossip", "projected",
   "gated", "settle_probe", "probe_answer", "probe_promise", "probe_waits", "probe_settled", "probe_of_claim",
   "serve_probe", "serve_standing", "serve_waiting_probe", "known_in_scope", "known_across", "ask_custodian",
   "repair_verdict", "owed_missing",
   "push_rebuilt_as_source", "push_rebuilt", "fill", "arm", "check_completion", "defer_on_claim", "reconsider",
   "decode_group", "claims_close", "note_claim", "filter_entry",
   "forward", "on_validated", "defer", "on_chunk", "on_holding", "on_offer",
   "ask_scale", "own_chunk", "pick", "choose", "ask_sample", "resample", "sample"]

/-- The functions of `protocol.md` that a record under v2 may name, which `Replay.run` serves: the 16
the 71 call directly, the two timer targets `promise_due` and `ask_parked`, `message_id` (the alias `chunk_id`),
`retry_offer`, the three that the v2 form of `on_block_installed` calls besides (`drop_tie`, `ledger`,
`validate_chunk`), and every function those reach in `protocol.md`'s code, with the node's own `held`. None of
them reaches a name v2 redefines. Computed from the extracted code (`protocol.md` at the spec's pin) by a scan of
the names each function's body uses; a list generated per document is to replace it. -/
def keptV2 : List String :=
  ["K", "N", "add_offer", "announcers", "ask_parked", "choose_push", "close_promises", "committed_descriptor",
   "drop_beyond", "drop_group", "drop_offer", "drop_tie", "group_id", "group_key", "guard_fails", "have_bits",
   "last_resort", "least_recently_tried", "ledger", "may_ask", "message_id", "outstanding", "over_ihave_limits",
   "owe", "parked", "promise_due", "rarest", "retry_offer", "segment_length", "tie", "tie_room", "tied_to_root",
   "untried", "valid_descriptor", "validate_chunk", "held"]

set_option maxHeartbeats 1600000 in
/-- What one replayed record of a trace under protocol-v2.md gives: the branches it took and how many of the
Python's reads the twin did not make, or the first difference. `params` are the types' parameters at the node;
`rowReads` the tables whose rows the trace's view logs as read (`rowReadsOf`, the header's `row_reads`). -/
def runV2 (c : Consts) (c2 : ConstsV2) (params : TypeId → Option TypeParams) (replaced traced : List String)
    (r : Record) (rowReads : List String := []) : Except String (Array String × Nat) := do
  if replaced.contains r.fn then throw s!"a record of {r.fn} at a node that has replaced it"
  if keptV2.contains r.fn then return ← run c replaced traced r rowReads
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
    | "candidates_for_source", #[f] => do exec (candidatesForSource (← chunkF f)) (retIs r.ret peers)
    | "origin_written", #[f] => do exec (originWritten (← chunkF f)) none_
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
    | "probe_waits", #[a, p] => do exec (probeWaits (← askV2Of a) (← nat p)) (retIs r.ret boolOf)
    | "probe_settled", #[a] => do exec (probeSettled (← askV2Of a)) (retIs r.ret boolOf)
    | "probe_of_claim", #[p, a] => do exec (probeOfClaim (← nat p) (← optOf askV2Of a)) (retIs r.ret boolOf)
    | "serve_probe", #[p, g, f] => do exec (serveProbe (← nat p) (← Replay.groupKey g) (← chunkF f)) none_
    | "serve_standing", #[g, i] => do exec (serveStanding (← Replay.groupKey g) (← nat i)) none_
    | "serve_waiting_probe", #[g, i] => do exec (serveWaitingProbe (← Replay.groupKey g) (← nat i)) none_
    | "known_in_scope", #[g] => do exec (knownInScope (← Replay.groupKey g)) (retIs r.ret nat)
    | "known_across", #[g] => do exec (knownAcross (← Replay.groupKey g)) (retIs r.ret nat)
    | "ask_custodian", #[g, i] => do exec (askCustodian (← Replay.groupKey g) (← nat i)) (retIs r.ret boolOf)
    | "repair_verdict", #[g] => do exec (repairVerdict (← Replay.groupKey g)) (retIs r.ret repairVerdictOf)
    | "owed_missing", #[g] => do exec (owedMissing (← Replay.groupKey g)) (retIs r.ret boolOf)
    -- fill, §4.6's completion, decoding and claims, filter_entry
    | "push_rebuilt_as_source", #[g, items] => do
      exec (pushRebuiltAsSource (← Replay.groupKey g) (← pairs "index and chunk" nat chunkF items)) none_
    | "push_rebuilt", #[g, new] => do exec (pushRebuilt (← Replay.groupKey g) (← natList new)) none_
    | "fill", #[g, i, f, p] => do exec (fill (← Replay.groupKey g) (← nat i) (← chunkF f) (← optOf nat p)) none_
    | "arm", #[g, t] => do exec (arm (← Replay.groupKey g) (← floatOf t)) none_
    | "check_completion", #[g] => do exec (checkCompletion (← Replay.groupKey g)) none_
    | "defer_on_claim", #[g] => do exec (deferOnClaim (← Replay.groupKey g)) none_
    | "reconsider", #[g, t] => do exec (reconsider (← Replay.groupKey g) (← floatOf t)) none_
    | "decode_group", #[g] => do exec (decodeGroup (← Replay.groupKey g)) none_
    | "claims_close", #[p] => do exec (claimsClose (← nat p)) none_
    | "note_claim", #[p, g] => do exec (noteClaim (← nat p) (← Replay.groupKey g)) none_
    | "filter_entry", #[p, e] => do exec (filterEntry (← nat p) (← qentry e)) (retIs r.ret (optOf qentry))
    -- forward, §4.2's chunk, §4.3's holding and offer
    | "forward", #[f, p] => do exec (forward (← chunkF f) (← nat p) none) none_
    | "forward", #[f, p, axes] => do exec (forward (← chunkF f) (← nat p) (← optOf giList axes)) none_
    | "on_validated", #[p, f, v] => do exec (onValidated (← nat p) (← chunkF f) (← verdict v)) none_
    | "defer", #[p, f] => do exec (defer (← nat p) (← chunkF f)) none_
    | "on_chunk", #[p, f] => do exec (onChunk (← nat p) (← chunkF f)) none_
    | "on_holding", #[p, h] => do exec (onHolding (← nat p) (← haveOf h)) none_
    | "on_offer", #[p, h] => do exec (onOffer (← nat p) (← haveOf h)) fun v => do return v == (← (← arr r.ret).mapM key)
    -- §4.10, §4.12, §4.13
    | "ask_scale", #[] => do exec askScale fun v => do return v.toBits == (← bits64 r.ret)
    | "own_chunk", #[e] => do exec (ownChunk (← qentry e)) (retIs r.ret boolOf)
    | "pick", #[q, ks] => do exec (pick (← nat q) (← natList ks)) (retIs r.ret nat)
    | "choose", #[q] => do exec (choose (← nat q)) (retIs r.ret nat)
    | "ask_sample", #[g, i] => do exec (askSample (← Replay.groupKey g) (← nat i) false) none_
    | "ask_sample", #[g, i, b] => do exec (askSample (← Replay.groupKey g) (← nat i) (← boolOf b)) none_
    | "resample", #[g, i, q, b] => do
      exec (resample (← Replay.groupKey g) (← nat i) (← nat q) (← boolOf b)) none_
    | "sample", #[g, b] => do exec (sample (← Replay.groupKey g) (← nat b)) none_
    | f, _ => throw s!"not a function of the twin under protocol-v2.md, or not its arguments: {f}"
  judge traced r res rs

end SpecTwin.V2
