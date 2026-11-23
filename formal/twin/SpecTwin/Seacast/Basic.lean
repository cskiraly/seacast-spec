import SpecTwin.Basic
import SpecTwin.Seacast.Types

/-! # The v2 layer's basic types: bitmaps that can be complemented (seacast.md §3)

`EVERY_INDEX` is the toy's `Bits(-1)`, and interest flows into bitmaps through `&`, `|` and `~` on Python ints, so a
bitmap that interest reaches is an `IBits`, an `Int` read in two's complement, as Python reads it. Core Lean has
`~~~` on `Int` but no `&&&` or `|||`, so the operations are defined here through `Nat`'s, on the two cases of an
`Int`: `ofNat a`, whose set bits are `a`'s, and `negSucc m`, which is `~m`, whose set bits are every bit `m` lacks.
The `#guard` cases below are Python's own values (`python3 -c`), over both signs.

The typing rule: `Bits & IBits` is a `Bits` (`Bits.andI`), since one side
is not negative; `IBits & ~Bits` and `IBits | Bits` are `IBits`. -/

namespace SpecTwin.Seacast

/-- A `Bits` as an `IBits` (`IBits` is in `Seacast/Types.lean`). -/
def IBits.ofBits (b : Bits) : IBits := Int.ofNat b

/-- `~a` -/
def IBits.not : IBits → IBits
  | .ofNat a => .negSucc a
  | .negSucc m => .ofNat m

/-- `a & b` -/
def IBits.and : IBits → IBits → IBits
  | .ofNat a, .ofNat b => .ofNat (a &&& b)
  | .ofNat a, .negSucc m => .ofNat (Bits.minus a m)            -- `a & ~m`
  | .negSucc m, .ofNat b => .ofNat (Bits.minus b m)
  | .negSucc m, .negSucc n => .negSucc (m ||| n)              -- `~m & ~n == ~(m | n)`

/-- `a | b` -/
def IBits.or : IBits → IBits → IBits
  | .ofNat a, .ofNat b => .ofNat (a ||| b)
  | .ofNat a, .negSucc m => .negSucc (Bits.minus m a)          -- `a | ~m == ~(m & ~a)`
  | .negSucc m, .ofNat b => .negSucc (Bits.minus m b)
  | .negSucc m, .negSucc n => .negSucc (m &&& n)              -- `~m | ~n == ~(m & n)`

/-- `a & ~b` -/
def IBits.minus (a b : IBits) : IBits := IBits.and a (IBits.not b)

/-- `a.has(i)`: `(a >> i) & 1 == 1` -/
def IBits.has : IBits → Nat → Bool
  | .ofNat a, i => a.testBit i
  | .negSucc m, i => !(m.testBit i)

/-- `not a` (`Bits.__bool__`): no index at all. -/
def IBits.empty (a : IBits) : Bool := a == 0

/-- `b & a`, a `Bits` masked by an `IBits`: never negative, so a `Bits` again. -/
def Bits.andI (b : Bits) : IBits → Bits
  | .ofNat a => b &&& a
  | .negSucc m => Bits.minus b m

/-- An `IBits` where the Python iterates or counts it: none for a negative one, where the toy raises `ValueError`
("iterating a complemented bitmap", `toy/bits.py:74-77`; "popcount of a complemented bitmap", `toy/bits.py:89-93`).
The caller crashes with that message at the Python's place. -/
def IBits.toBits? : IBits → Option Bits
  | .ofNat a => some a
  | .negSucc _ => none

/-- A type's 24 constant parameters: §1.1's `TypeParams` less its three functions (`DECODE_AT_K`, `DECODE_LATER`,
`REPAIR_TO`, which are questions), and the three the code reads beyond the class (`REPAIR_SAMPLE`, `SAMPLE_WAIT`,
`REPAIR_REASK`). `SAMPLE_OUTSTANDING` is no type's but the node's (`ConstsSeacast`). Each is optional: the toy gives
its payload and row types no `SAMPLE_RETRY2`, `SAMPLE_COVER`, `COVER_HIGH`, `ROUTE_HOPS` or `FORWARD_LIMIT`
(`toy/node.py:1231-1243`, `toy/node.py:1318-1339`), and a read of a missing one raises `AttributeError` there, as it
crashes here. The two
limits that can be unbounded are floats, infinity for none. -/
structure TypeParams where
  M : Option Nat := none
  F_LO : Option Nat := none
  F_HI : Option Nat := none
  D_OUT : Option Nat := none
  D_OUT_FAST : Option Nat := none
  D_OUT_MAX : Option Nat := none
  SYMMETRIC : Option Bool := none
  PRUNE_BACKOFF : Option Float := none
  ANNOUNCE_EXTRA : Option AnnounceWidth := none
  EAGER : Option Bool := none
  REPAIR_BUDGET : Option Bool := none
  DEFER_WINDOW : Option Float := none
  START_DELAY : Option Float := none
  SERVE_LIMIT : Option Float := none
  SAMPLE_RETRY : Option Float := none
  SAMPLE_RETRY2 : Option Float := none
  SAMPLE_COVER : Option Nat := none
  COVER_HIGH : Option Nat := none
  ROUTE_HOPS : Option Nat := none
  FORWARD_LIMIT : Option Float := none
  /-- Present and none in this version (§1.5): the nodes line refuses any other value. -/
  EVIDENCE : Option (Option TypeId) := none
  /-- The repair sample's steps `[(S1, L1), …]`, or none (§4.6's `repair_verdict`). -/
  REPAIR_SAMPLE : Option (Option (List (Nat × Nat))) := none
  SAMPLE_WAIT : Option Float := none
  REPAIR_REASK : Option Bool := none
  deriving Repr, Inhabited

/-! ## What SEACAST's code asks of the rest of the node

A type is its id; its methods and its three parameters that
are functions are questions with the id first. The helpers the document does not write out are questions too,
and what they read and write of the twin's tables are their `cr` and `cw` notes on the tape. -/

/-- A record of a node that could be linked, or of a link: `cover_candidates`' and `floor_candidates`' records
and `link_cover`'s answer. Each has the fields its helper gives it, and a read of one it lacks
crashes as the toy's `AttributeError`: `link_cover`'s has no id, `floor_candidates`' no flag. -/
structure Cover where
  id : Option Peer := none
  families : List Fam
  high : Option Bool := none
  deriving BEq, Repr, Inhabited

/-- SEACAST's timers (§4.6, §4.10), asked through `afterSeacast`. `promise_due`, which SEACAST's `filter_entry` arms, stays on
`seacast-lite.md`'s `after`. -/
inductive TimerSeacast where
  | reconsider (g : Group) (at_ : Float)
  | askSample (g : Group) (i : Nat)
  | resample (g : Group) (i : Nat) (q : Peer) (first : Bool)
  deriving BEq, Repr

class NodeSeacast (m : Type → Type) where
  /-- `type_of_group(g)` (§3): the group's type, as its id -/
  typeOfGroup : Group → m TypeId
  /-- `type_of(tid)` (§3): the type of that id at this node -/
  typeOf : TypeId → m TypeId
  /-- `T.index_count(h)` -/
  indexCount : TypeId → Option Descriptor → m Nat
  /-- `T.threshold(h)` -/
  threshold : TypeId → Option Descriptor → m Nat
  /-- `T.verify(f, h)` -/
  verify : TypeId → ChunkF → Option Descriptor → m Verdict
  /-- `T.decode(chunks, h)`: the node's store of the group's chunks; the decoded chunks in the answer's order,
  each with the index it is stored under -/
  decode : TypeId → Group → Option Descriptor → m (Option (List (Nat × ChunkF)))
  /-- `T.header_of(f)` -/
  headerOf : TypeId → ChunkF → m (Option Descriptor)
  /-- `T.project(f)`: the places a chunk fills, one per axis -/
  project : TypeId → ChunkF → m (List GI)
  /-- `T.cross(g, i)`: the place's other coordinates -/
  cross : TypeId → Group → Nat → m (List GI)
  /-- `T.family(g)` -/
  family : TypeId → Group → m Fam
  /-- `T.derived_interest(g, h, nid, j)` -/
  derivedInterest : TypeId → Group → Option Descriptor → Hex → Join → m IBits
  /-- `T.params.DECODE_AT_K(g)` -/
  decodeAtK : TypeId → Group → m Bool
  /-- `T.params.DECODE_LATER(g)`: a delay, or none -/
  decodeLater : TypeId → Group → m (Option Float)
  /-- `T.params.REPAIR_TO(g)`: peers, in the order the set iterates -/
  repairTo : TypeId → Group → m (List Peer)
  /-- `send(p, msg, urgent)` (§7): whether it went or was queued -/
  send : Peer → MsgSeacast → Bool → m Bool
  /-- `after(delay, fn, …)` for SEACAST's timers -/
  afterSeacast : Float → TimerSeacast → m Unit
  /-- `links(T)`: the peers linked for the type -/
  links : TypeId → m (List Peer)
  /-- `link_cover(q, T)`: the families q serves and whether its custody is high; no id -/
  linkCover : Peer → TypeId → m Cover
  /-- `cover_candidates(T)`: nodes not linked, each with its id, families and flag -/
  coverCandidates : TypeId → m (List Cover)
  /-- `floor_candidates(T)`: nodes not linked, each with its id and families, no flag -/
  floorCandidates : TypeId → m (List Cover)
  /-- `floor_links(T, fam)`: the peers whose custody holds `fam`, joined or not -/
  floorLinks : TypeId → Fam → m (List Peer)
  /-- `high_custody(q, T)` -/
  highCustody : Peer → TypeId → m Bool
  /-- `families(T)` -/
  families : TypeId → m (List Fam)
  /-- `families_with_duty(T)` -/
  familiesWithDuty : TypeId → m (List Fam)
  /-- `wants_family(T, fam)` -/
  wantsFamily : TypeId → Fam → m Bool
  /-- `duty_for(g)` -/
  dutyFor : Group → m Duty
  /-- `route_next(T, fam, qs)`: of the links `qs`, those nearest `fam` -/
  routeNext : TypeId → Fam → List Peer → m (List Peer)
  /-- `block_of(g)` -/
  blockOf : Group → m BlockId
  /-- `group_of(block, h)`: the group a header names in a block -/
  groupOf : Block → Descriptor → m Group
  /-- `node_id(p)`: the peer's node id, as the hex of its bytes -/
  nodeId : Peer → m Hex
  /-- `interest_satisfied(g)` -/
  interestSatisfied : Group → m Bool
  /-- `valid_have(h)` for a whole `Have` (§8.2's limits) -/
  validHaveSeacast : Have → m Bool
  /-- `merge_waiting(p, h)`: whether a holding of h's group to p merged into one waiting -/
  mergeWaiting : Peer → Have → m Bool
  /-- `deferred_offers(p, h)`: offers recorded now, asked when the start delay has run; its answer, `[]` -/
  deferredOffers : Peer → Have → m (List Key)
  /-- `open_group_source(g, d)` -/
  openGroupSource : Group → Descriptor → m Unit
  /-- `release_wanted_groups()` (§3): defined in prose alone, by no code block, so a question whose logic the twin
  does not check; what it writes of the twin's tables (an expired place's `standing`, `routed_standing` and
  `want_p`) is its `cw` on the tape -/
  releaseWantedGroups : m Unit
  /-- `open_link(r, T)` -/
  openLink : Cover → TypeId → m Unit
  /-- `open_sampling_link(r, T)` -/
  openSamplingLink : Cover → TypeId → m Unit
  /-- `choice(xs)` of peers: a draw, answered with a member -/
  choicePeer : List Peer → m Peer
  /-- `choice(list(s))` of a set of peers: the replay compares the argument as a set -/
  choiceOfSet : List Peer → m Peer
  /-- `choice(xs)` of indices -/
  choiceNat : List Nat → m Nat
  /-- `choice(xs)` of records -/
  choiceCover : List Cover → m Cover
  /-- `shuffled(xs)` of peers -/
  shuffledPeers : List Peer → m (List Peer)
  /-- `shuffled(xs)` of pairs of an index and a chunk (`push_rebuilt`'s `lacks`) -/
  shuffledPairs : List (Nat × ChunkF) → m (List (Nat × ChunkF))
  /-- `sample_without_replacement(xs, k)` of records -/
  sampleCovers : List Cover → Nat → m (List Cover)
  /-- the order in which a proxied set of peers iterates at a place of SEACAST's code, an `order` entry on the tape: a permutation of
  the members the twin computed -/
  order : String → List Peer → m (List Peer)
  /-- the order in which `probe_waiting[g]`'s keys iterate (`probe_waiting[g].items()` in `serve_waiting_probe`,
  a `keys` entry on the tape): a permutation of the keys the twin holds -/
  probeWaitingOrder : Group → List Peer → m (List Peer)
  /-- the order in which `claims`' keys iterate (`claims.items()` in `claims_close`, a `keys` entry on
  the tape): a permutation of the keys the twin holds -/
  claimsOrder : List Group → m (List Group)
  /-- `own_interest(g)`: `interest[g]`'s default, read where the table has no entry for g, which stores nothing -/
  ownInterest : Group → m IBits
  -- The eight names of the 71 that a node can replace, by a binding of its own that changes what the function
  -- does, and that have a call site inside the replayed closure: where the node's line names one as replaced, the
  -- Python asks the node, and the twin asks this question in place of the document's body, as `seacast-lite.md`'s
  -- `forwardNode` is.
  /-- `forward(f, from_peer, axes)` as the node binds it -/
  forwardNode : ChunkF → Peer → Option (List GI) → m Unit
  /-- `push_rebuilt(g, new)` as the node binds it -/
  pushRebuiltNode : Group → List Nat → m Unit
  /-- `send_have(p, g)` as the node binds it -/
  sendHaveNode : Peer → Group → m Unit
  /-- `serve_standing(g, i)` as the node binds it -/
  serveStandingNode : Group → Nat → m Unit
  /-- `owed_missing(g)` as the node binds it -/
  owedMissingNode : Group → m Bool
  /-- `repair_verdict(g)` as the node binds it -/
  repairVerdictNode : Group → m RepairVerdict
  /-- `note_claim(p, g)` as the node binds it -/
  noteClaimNode : Peer → Group → m Unit
  /-- `known_in_scope(g)` as the node binds it -/
  knownInScopeNode : Group → m Bits

/-- The functions of the 89 left out of this cycle that the 71 call. Until each is transcribed, its
instance is a question on the tape. -/
class SeacastLater (m : Type → Type) where
  /-- `window_release(p, g, i)` (§4.11) -/
  windowRelease : Peer → Group → Nat → m Unit

namespace NodeSeacast

/-- Asking through a monad transformer, as `Node61.lift`. -/
abbrev lift {m n : Type → Type} [NodeSeacast m] (f : ∀ {α : Type}, m α → n α) : NodeSeacast n where
  typeOfGroup a := f (typeOfGroup a)
  typeOf a := f (typeOf a)
  indexCount a b := f (indexCount a b)
  threshold a b := f (threshold a b)
  verify a b c := f (verify a b c)
  decode a b c := f (decode a b c)
  headerOf a b := f (headerOf a b)
  project a b := f (project a b)
  cross a b c := f (cross a b c)
  family a b := f (family a b)
  derivedInterest a b c d e := f (derivedInterest a b c d e)
  decodeAtK a b := f (decodeAtK a b)
  decodeLater a b := f (decodeLater a b)
  repairTo a b := f (repairTo a b)
  send a b c := f (send a b c)
  afterSeacast a b := f (afterSeacast a b)
  links a := f (links a)
  linkCover a b := f (linkCover a b)
  coverCandidates a := f (coverCandidates a)
  floorCandidates a := f (floorCandidates a)
  floorLinks a b := f (floorLinks a b)
  highCustody a b := f (highCustody a b)
  families a := f (families a)
  familiesWithDuty a := f (familiesWithDuty a)
  wantsFamily a b := f (wantsFamily a b)
  dutyFor a := f (dutyFor a)
  routeNext a b c := f (routeNext a b c)
  blockOf a := f (blockOf a)
  groupOf a b := f (groupOf a b)
  nodeId a := f (nodeId a)
  interestSatisfied a := f (interestSatisfied a)
  validHaveSeacast a := f (validHaveSeacast a)
  mergeWaiting a b := f (mergeWaiting a b)
  deferredOffers a b := f (deferredOffers a b)
  openGroupSource a b := f (openGroupSource a b)
  releaseWantedGroups := f releaseWantedGroups
  openLink a b := f (openLink a b)
  openSamplingLink a b := f (openSamplingLink a b)
  choicePeer a := f (choicePeer a)
  choiceOfSet a := f (choiceOfSet a)
  choiceNat a := f (choiceNat a)
  choiceCover a := f (choiceCover a)
  shuffledPeers a := f (shuffledPeers a)
  shuffledPairs a := f (shuffledPairs a)
  sampleCovers a b := f (sampleCovers a b)
  order a b := f (order a b)
  probeWaitingOrder a b := f (probeWaitingOrder a b)
  claimsOrder a := f (claimsOrder a)
  ownInterest a := f (ownInterest a)
  forwardNode a b c := f (forwardNode a b c)
  pushRebuiltNode a b := f (pushRebuiltNode a b)
  sendHaveNode a b := f (sendHaveNode a b)
  serveStandingNode a b := f (serveStandingNode a b)
  owedMissingNode a := f (owedMissingNode a)
  repairVerdictNode a := f (repairVerdictNode a)
  noteClaimNode a b := f (noteClaimNode a b)
  knownInScopeNode a := f (knownInScopeNode a)

instance {m : Type → Type} {σ : Type} [Monad m] [NodeSeacast m] : NodeSeacast (StateT σ m) :=
  lift (m := m) (n := StateT σ m) fun x => monadLift x
instance {m : Type → Type} {ρ : Type} [Monad m] [NodeSeacast m] : NodeSeacast (ReaderT ρ m) :=
  lift (m := m) (n := ReaderT ρ m) fun x => monadLift x

end NodeSeacast

instance {m : Type → Type} {σ : Type} [Monad m] [SeacastLater m] : SeacastLater (StateT σ m) where
  windowRelease p g i := monadLift (SeacastLater.windowRelease (m := m) p g i)
instance {m : Type → Type} {ρ : Type} [Monad m] [SeacastLater m] : SeacastLater (ReaderT ρ m) where
  windowRelease p g i := monadLift (SeacastLater.windowRelease (m := m) p g i)

/-- SEACAST's node-wide constants this cycle reads that `seacast-lite.md`'s `Consts` lacks. Two of SEACAST's
constants are `Consts`' own fields, read there, so that v2 and the kept functions it calls read one value:
`SOURCE_OFFERS` is `SOURCE_OFFERS_PUBLISH` (whether it is `PUBLISH`), and `IWANT_WINDOW` is the effective window,
already scaled by `ask_scale()` at load time, which `may_ask`, `retry_offer` and `ask_parked` read. -/
structure ConstsSeacast where
  ANSWERS_FIRST : Bool
  /-- §4.13's uplink, in bits per second, at and above which `IWANT_WINDOW` keeps `seacast-lite.md`'s value; 0 never
  scales (the toy's `--ask-uplink 0`) -/
  ASK_UPLINK : Float
  MERGE_HOLDINGS : Bool
  /-- §4.10's cap on a block's second-phase sample asks in flight, across its sampled types; at least 1 -/
  SAMPLE_OUTSTANDING : Nat
  /-- §4.5's answers to one peer in a heartbeat, across groups, that the budget counts; none for no limit (the
  toy's `math.inf`), else at least 1 -/
  SERVE_BUDGET : Option Nat
  deriving Repr, Inhabited

/-- What a call of SEACAST's code reads that does not change during it: `seacast-lite.md`'s context, SEACAST's constants, and
the types' parameters at the node (none for an id the node has no type of). -/
structure Ctx2 where
  base : Ctx
  c2 : ConstsSeacast
  params : TypeId → Option TypeParams

abbrev M2 (m : Type → Type) := ReaderT Ctx2 m

/-- A call of `seacast-lite.md`'s Lean from SEACAST's: it reads the base context. -/
def lite {m : Type → Type} {α : Type} (x : M m α) : M2 m α := fun c => x c.base

/-- `T.params.X`: the twin reads it from the context, with no question. A type the node has no parameters for,
or a parameter the type does not have, crashes as the toy's `AttributeError`. -/
def param {m : Type → Type} [Monad m] [Node61 m] {α : Type} [Inhabited α] (T : TypeId) (name : String)
    (f : TypeParams → Option α) : M2 m α := do
  match (← read).params T with
  | none => Node61.crash s!"AttributeError: no parameters of type {T} at this node ({name})"
  | some p =>
    match f p with
    | some v => pure v
    | none => Node61.crash s!"AttributeError: 'TypeParams' object has no attribute '{name}' (type {T})"

/-! ## Python's values -/

-- and
#guard IBits.and (0) (0) == (0)
#guard IBits.and (0) (255) == (0)
#guard IBits.and (0) (-13) == (0)
#guard IBits.and (5) (12) == (4)
#guard IBits.and (5) (-6) == (0)
#guard IBits.and (12) (5) == (4)
#guard IBits.and (12) (-1) == (12)
#guard IBits.and (12) (-256) == (0)
#guard IBits.and (255) (0) == (0)
#guard IBits.and (255) (255) == (255)
#guard IBits.and (255) (-13) == (243)
#guard IBits.and (-1) (12) == (12)
#guard IBits.and (-1) (-6) == (-6)
#guard IBits.and (-6) (5) == (0)
#guard IBits.and (-6) (-1) == (-6)
#guard IBits.and (-6) (-256) == (-256)
#guard IBits.and (-13) (0) == (0)
#guard IBits.and (-13) (255) == (243)
#guard IBits.and (-13) (-13) == (-13)
#guard IBits.and (-256) (12) == (0)
#guard IBits.and (-256) (-6) == (-256)
-- or
#guard IBits.or (0) (5) == (5)
#guard IBits.or (0) (-1) == (-1)
#guard IBits.or (0) (-256) == (-256)
#guard IBits.or (5) (0) == (5)
#guard IBits.or (5) (255) == (255)
#guard IBits.or (5) (-13) == (-9)
#guard IBits.or (12) (12) == (12)
#guard IBits.or (12) (-6) == (-2)
#guard IBits.or (255) (5) == (255)
#guard IBits.or (255) (-1) == (-1)
#guard IBits.or (255) (-256) == (-1)
#guard IBits.or (-1) (0) == (-1)
#guard IBits.or (-1) (255) == (-1)
#guard IBits.or (-1) (-13) == (-1)
#guard IBits.or (-6) (12) == (-2)
#guard IBits.or (-6) (-6) == (-6)
#guard IBits.or (-13) (5) == (-9)
#guard IBits.or (-13) (-1) == (-1)
#guard IBits.or (-13) (-256) == (-13)
#guard IBits.or (-256) (0) == (-256)
#guard IBits.or (-256) (255) == (-1)
#guard IBits.or (-256) (-13) == (-13)
-- minus
#guard IBits.minus (0) (12) == (0)
#guard IBits.minus (0) (-6) == (0)
#guard IBits.minus (5) (5) == (0)
#guard IBits.minus (5) (-1) == (0)
#guard IBits.minus (5) (-256) == (5)
#guard IBits.minus (12) (0) == (12)
#guard IBits.minus (12) (255) == (0)
#guard IBits.minus (12) (-13) == (12)
#guard IBits.minus (255) (12) == (243)
#guard IBits.minus (255) (-6) == (5)
#guard IBits.minus (-1) (5) == (-6)
#guard IBits.minus (-1) (-1) == (0)
#guard IBits.minus (-1) (-256) == (255)
#guard IBits.minus (-6) (0) == (-6)
#guard IBits.minus (-6) (255) == (-256)
#guard IBits.minus (-6) (-13) == (8)
#guard IBits.minus (-13) (12) == (-13)
#guard IBits.minus (-13) (-6) == (1)
#guard IBits.minus (-256) (5) == (-256)
#guard IBits.minus (-256) (-1) == (0)
#guard IBits.minus (-256) (-256) == (0)
-- has
#guard IBits.has (0) 0 == false
#guard IBits.has (0) 2 == false
#guard IBits.has (0) 3 == false
#guard IBits.has (0) 9 == false
#guard IBits.has (5) 0 == true
#guard IBits.has (5) 2 == true
#guard IBits.has (5) 3 == false
#guard IBits.has (5) 9 == false
#guard IBits.has (12) 0 == false
#guard IBits.has (12) 2 == true
#guard IBits.has (12) 3 == true
#guard IBits.has (12) 9 == false
#guard IBits.has (255) 0 == true
#guard IBits.has (255) 2 == true
#guard IBits.has (255) 3 == true
#guard IBits.has (255) 9 == false
#guard IBits.has (-1) 0 == true
#guard IBits.has (-1) 2 == true
#guard IBits.has (-1) 3 == true
#guard IBits.has (-1) 9 == true
#guard IBits.has (-6) 0 == false
#guard IBits.has (-6) 2 == false
#guard IBits.has (-6) 3 == true
#guard IBits.has (-6) 9 == true
#guard IBits.has (-13) 0 == true
#guard IBits.has (-13) 2 == false
#guard IBits.has (-13) 3 == false
#guard IBits.has (-13) 9 == true
#guard IBits.has (-256) 0 == false
#guard IBits.has (-256) 2 == false
#guard IBits.has (-256) 3 == false
#guard IBits.has (-256) 9 == true
-- not
#guard IBits.not (0) == (-1)
#guard IBits.not (5) == (-6)
#guard IBits.not (12) == (-13)
#guard IBits.not (255) == (-256)
#guard IBits.not (-1) == (0)
#guard IBits.not (-6) == (5)
#guard IBits.not (-13) == (12)
#guard IBits.not (-256) == (255)
-- Bits & IBits
#guard Bits.andI 0 (0) == 0
#guard Bits.andI 0 (5) == 0
#guard Bits.andI 0 (12) == 0
#guard Bits.andI 0 (255) == 0
#guard Bits.andI 0 (-1) == 0
#guard Bits.andI 0 (-6) == 0
#guard Bits.andI 0 (-13) == 0
#guard Bits.andI 0 (-256) == 0
#guard Bits.andI 5 (0) == 0
#guard Bits.andI 5 (5) == 5
#guard Bits.andI 5 (12) == 4
#guard Bits.andI 5 (255) == 5
#guard Bits.andI 5 (-1) == 5
#guard Bits.andI 5 (-6) == 0
#guard Bits.andI 5 (-13) == 1
#guard Bits.andI 5 (-256) == 0
#guard Bits.andI 12 (0) == 0
#guard Bits.andI 12 (5) == 4
#guard Bits.andI 12 (12) == 12
#guard Bits.andI 12 (255) == 12
#guard Bits.andI 12 (-1) == 12
#guard Bits.andI 12 (-6) == 8
#guard Bits.andI 12 (-13) == 0
#guard Bits.andI 12 (-256) == 0
#guard Bits.andI 255 (0) == 0
#guard Bits.andI 255 (5) == 5
#guard Bits.andI 255 (12) == 12
#guard Bits.andI 255 (255) == 255
#guard Bits.andI 255 (-1) == 255
#guard Bits.andI 255 (-6) == 250
#guard Bits.andI 255 (-13) == 243
#guard Bits.andI 255 (-256) == 0

/-! ## The new constructors in `seacast-lite.md`'s pure case analyses

`QEntry.asks` reads every IWANT, marked or not, as the toy's `entry.iwants()` does, and drops the flags; a
relation and a holding hold no ask. `Ctl.isEmpty` is the toy's `_Msg.empty`: an IWANT with no asks is empty, a
relation never is. -/

private def k1 : Key := .want "g" 1
private def k2 : Key := .want "g" 2
private def rel : Relation := .prune { objectType := "payload", family := -1, colour := 0, direction := .outward }
private def ctlE (cs : List Ctl) : QEntry := { chunk := none, control := some cs, solicited := false }

#guard (ctlE [.iwantSeacast true [{ key := k1, standing := true, hops := 2 }, { key := k2 }]]).asks == [k1, k2]
#guard (ctlE [.iwantSeacast false [{ key := k1, probe := true }]]).asks == [k1]
#guard (ctlE [.iwant [k2], .iwantSeacast true [{ key := k1 }]]).asks == [k2, k1]
#guard (ctlE [.relation rel, .idontwant [.holding "g" 5 true false]]).asks == []
#guard (ctlE [.iwantSeacast true []]).asks == []
#guard (Ctl.iwantSeacast true []).isEmpty
#guard !(Ctl.iwantSeacast false [{ key := k1 }]).isEmpty
#guard !(Ctl.relation rel).isEmpty
#guard (Ctl.idontwant [.holding "g" 0 false false]).isEmpty == false
#guard (Ctl.idontwant []).isEmpty
#guard (ctlE [.iwantSeacast true []]).isEmpty
#guard !(ctlE [.relation rel]).isEmpty

end SpecTwin.Seacast
