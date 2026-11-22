import SpecTwin.V2.Basic
import SpecTwin.Readers

/-! # protocol-v2.md §1.4, §2 and §4.1: colours, links and the relations' messages

The twin of `colour_of` (§1.4), §2's `joined`, and §4.1's functions that the cycle covers: `send_join`, `interest_of_peer`,
`wants_from_me`, `prune`, `yes`, `no`, `send_relation`, `queue_owed_relations`, `serves`, `counted`,
`keep_coverage` and `keep_floor`. `join_push`, §4.1's too, calls §4.4's `announce`, so it is in
`V2/Announce.lean`. `graft` comes with v0.10.12's text.

v2's files follow the calls, not the sections: each function comes after every function it calls, and §4's
sections call each other both ways (`protocol.md`'s twin does the same, README.md's Scope).

- **A type is its id:** `T.params.X` is `param`, read from the context, and `T.id` is `T`.
- **A missing key of a dict that raises** is a crash named `KeyError`, with the key: `join_recv[p][T]` raises on
  the type, named with its kind (`type T`), and `need[fam]` in `counted` on the family, an integer, bare.
- **Two loops with a bound:** `queue_owed_relations`' fuel is the list's length at the first guard,
  plus one; `keep_coverage`'s is the sum of the positive needs at the first guard, plus one. Running out of fuel
  is a crash of the twin's own name.
- **`or` and `and` short-circuit** as the Python's do: `send_relation` asks `send` only where nothing is owed,
  and `serves` asks `interest_of_peer` only where p's interest is not `DECLARED`.
- **Writes, in every v2 file.** A method call that changes a value in place (`.set(i)`, `.clear(i)`, a set
  value's `.add` or `.discard`, an attribute of an entry object such as `e.bits |= h.bits`) reads its entry
  first, as the Python does, and the tracer logs a write only where the value changed. The twin may write it
  whether it changes or not, since the replay passes a write that leaves an entry the Python read as it was
  (`Replay.lean`'s footprint), as `protocol.md`'s twin does; some places skip the unchanged write, some make it,
  and both pass. Two kinds are writes always, so the twin makes them unconditionally: an assignment to a
  subscript, augmented ones included (`interest[g] |= bits` is `interest[g] = interest[g] | bits`, a write even
  where nothing changes; `served[q][g] += 1`), and a set that is a table of its own (`probe_asks`, `probe_sent`),
  whose `add` and `discard` the tracer's view logs as a write with no read, so the twin reads nothing there.
- **A function a node can replace** (`forward`, `push_rebuilt`, `send_have`, `serve_standing`,
  `owed_missing`, `repair_verdict`, `note_claim`, `known_in_scope`) is called through its `…Call`, which asks the
  node's own where the node's line names it as replaced. -/

namespace SpecTwin.V2

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeV2 m]

/-- `colour_of(g, i)` (§1.4): `i % type_of_group(g).params.M` -/
def colourOf (g : Group) (i : Nat) : M2 m Nat := do
  enter "colour_of"
  let M ← param (← NodeV2.typeOfGroup g) "M" (·.M)
  if M == 0 then crash "ZeroDivisionError: integer modulo by zero (colour_of)"
  return i % M

/-- `send_relation(p, m)` (§4.1): a JOIN, GRAFT or PRUNE is never lost to a full queue; one refused, and every
later one, is owed in order -/
def sendRelation (p : Peer) (r : Relation) : M2 m Unit := do
  enter "send_relation"
  let urgent := match r with | .join _ => true | _ => false     -- `urgent=isinstance(m, Join)`
  -- `if owed_relations[p] or not send(p, m, urgent=...)`: send is asked only where nothing is owed
  let refused ← if !(← owedRelationsOf p).isEmpty then pure true
                else do pure !(← NodeV2.send p (.relation r) urgent)
  if refused then
    setOwedRelations p ((← owedRelationsOf p) ++ [r])          -- `owed_relations[p].append(m)`
    wake p
    branch "send_relation: owed"
  else branch "send_relation: sent"

/-- `joined(p, T)` (§2): the link joined T: p's JOIN received, ours queued, not owed (§4.1's links) -/
def joined (p : Peer) (T : TypeId) : M2 m Bool := do
  enter "joined"
  return (← NodeV2.links T).contains p                       -- `p in links(T)`

/-- `send_join(p, j)` (§4.1): every JOIN of ours, once per link and type -/
def sendJoin (p : Peer) (j : Join) : M2 m Unit := do
  enter "send_join"
  setJoinSent p (← NodeV2.typeOf j.objectType) j
  sendRelation p (.join j)

/-- `push_in[q][T][fam].discard(c)` and the other three: a colour that is not there is no write -/
private def discardColour (get : Peer → TypeId → Fam → M2 m (Std.HashSet Nat))
    (set : Peer → TypeId → Fam → Std.HashSet Nat → M2 m Unit) (q : Peer) (T : TypeId) (fam : Fam) (c : Nat) :
    M2 m Unit := do
  let s ← get q T fam
  if s.contains c then set q T fam (s.erase c)

/-- `prune(q, T, fam, c, d)` (§4.1): our PRUNE; the relation ends at our end at once -/
def prune (q : Peer) (T : TypeId) (fam : Fam) (c : Nat) (d : Direction) : M2 m Unit := do
  enter "prune"
  if d == .inward || d == .both then
    discardColour pushInOf setPushIn q T fam c
    discardColour graftedInOf setGraftedIn q T fam c
  if d == .outward || d == .both then
    discardColour pushOutOf setPushOut q T fam c
    discardColour graftedOutOf setGraftedOut q T fam c
  sendRelation q (.prune { objectType := T, family := fam, colour := c, direction := d })

/-- `yes(p, T, fam, c, d)` (§4.1): an accepted GRAFT's answer, from our side -/
def yes (p : Peer) (T : TypeId) (fam : Fam) (c : Nat) (d : Direction) : M2 m Unit := do
  enter "yes"
  sendRelation p (.graft { objectType := T, family := fam, colour := c, direction := d, answer := true })

/-- `no(p, T, fam, c, d)` (§4.1): a refused GRAFT's answer, from our side -/
def no (p : Peer) (T : TypeId) (fam : Fam) (c : Nat) (d : Direction) : M2 m Unit := do
  enter "no"
  sendRelation p (.prune { objectType := T, family := fam, colour := c, direction := d })

/-- `queue_owed_relations(p)` (§4.1): the writer, before anything else (§4.11) -/
def queueOwedRelations (p : Peer) : M2 m Unit := do
  enter "queue_owed_relations"
  let fuel := (← owedRelationsOf p).length + 1                -- read at the first guard: each turn pops one
  for _ in List.range fuel do
    -- `while owed_relations[p] and has_room(p):`
    let owed ← owedRelationsOf p
    if owed.isEmpty then
      branch "queue_owed_relations: nothing owed"
      return
    if !(← hasRoom p) then
      branch "queue_owed_relations: no room"
      return
    match owed with
    | r :: rest =>
      setOwedRelations p rest                                 -- `m = owed_relations[p].pop(0)`
      let _ ← NodeV2.send p (.relation r) (match r with | .join _ => true | _ => false)
      branch "queue_owed_relations: one sent"
    | [] => pure ()
  crash "twin: queue_owed_relations ran out of fuel (the owed list's length at the first guard, plus one)"

/-- `interest_of_peer(p, g)` (§4.1): what p is to receive of g, as far as we know -/
def interestOfPeer (p : Peer) (g : Group) : M2 m IBits := do
  enter "interest_of_peer"
  let T ← NodeV2.typeOfGroup g
  let some j ← joinRecv? p T | crash s!"KeyError: type {T} (interest_of_peer: join_recv[p][T])"
  match j.interest with
  | .all =>
    branch "interest_of_peer: ALL"
    return IBits.not 0                                        -- `EVERY_INDEX`
  | .derived =>
    branch "interest_of_peer: DERIVED"
    -- `T.derived_interest(g, hdr.get(g), node_id(p), j)`: the arguments left to right
    NodeV2.derivedInterest T g (← desc g) (← NodeV2.nodeId p) j
  | .declared =>
    branch "interest_of_peer: DECLARED"
    return (← wantP? p g).getD 0                              -- `want_p[p].get(g, EMPTY)`

/-- `wants_from_me(p, g)` (§4.1, [I3]): pushes and offers go into interest -/
def wantsFromMe (p : Peer) (g : Group) : M2 m IBits := do
  enter "wants_from_me"
  let e := (← peerHasEntry? p g).getD {}                      -- `e = peer_has[p][g]`
  if e.complete then
    branch "wants_from_me: complete"
    return 0
  let i ← interestOfPeer p g
  -- `interest_of_peer(p, g) & ~e.bits & ~pushed[p][g]`
  return IBits.and (IBits.and i (IBits.not (IBits.ofBits e.bits))) (IBits.not (IBits.ofBits (← v1 (pushed p g))))

/-- `serves(q, g, i)` (§1.3): q's interest holds index i of g, so q will hold it -/
def serves (q : Peer) (g : Group) (i : Nat) : M2 m Bool := do
  enter "serves"
  let T ← NodeV2.typeOfGroup g
  let some j ← joinRecv? q T | crash s!"KeyError: type {T} (serves: join_recv[q][T])"
  if j.interest == .declared then
    branch "serves: DECLARED"
    return false
  return (← interestOfPeer q g).has i

/-- `need[fam]`: a KeyError on a family `need` does not hold -/
private def needOf (need : List (Fam × Int)) (fam : Fam) (where_ : String) : M2 m Int :=
  match need.lookup fam with
  | some n => pure n
  | none => crash s!"KeyError: {fam} ({where_}: need[fam])"

/-- `need[fam] -= 1`: the entry keeps its place -/
private def lower (need : List (Fam × Int)) (fam : Fam) : List (Fam × Int) :=
  need.map fun (f, n) => if f == fam then (f, n - 1) else (f, n)

/-- `counted(need, r, T)` (§1.3): the short families r covers; one of high custody counts for at most
`COVER_HIGH` of them -/
def counted (need : List (Fam × Int)) (r : Cover) (T : TypeId) : M2 m (List Fam) := do
  enter "counted"
  let short ← r.families.filterM fun fam => do return (← needOf need fam "counted") > 0
  let some high := r.high | crash "AttributeError: the record has no 'high' (counted: r.high)"
  if high then
    branch "counted: high custody"
    return short.take (← param T "COVER_HIGH" (·.COVER_HIGH))
  return short

/-- `keep_coverage(T)` (§1.3, [D12]): at the heartbeat, for a type we sample -/
def keepCoverage (T : TypeId) : M2 m Unit := do
  enter "keep_coverage"
  -- `need = {fam: T.params.SAMPLE_COVER for fam in families(T)}`: a family named twice keeps its first place
  let mut need : List (Fam × Int) := []
  for fam in ← NodeV2.families T do
    let n : Int := (← param T "SAMPLE_COVER" (·.SAMPLE_COVER) : Nat)
    need := if need.any (·.1 == fam) then need.map fun (f, x) => if f == fam then (f, n) else (f, x)
            else need ++ [(fam, n)]
  for q in ← NodeV2.links T do                                -- every link counts, whatever it was opened for
    for fam in ← counted need (← NodeV2.linkCover q T) T do
      need := lower need fam
  -- the loop's fuel: each turn takes one at least from a positive need
  let fuel := (need.foldl (fun s (_, n) => if n > 0 then s + n.toNat else s) 0) + 1
  for _ in List.range fuel do
    if !need.any (·.2 > 0) then                               -- `while any(n > 0 for n in need.values()):`
      branch "keep_coverage: covered"
      return
    let cs ← (← NodeV2.coverCandidates T).filterM fun r => do return !(← counted need r T).isEmpty
    if cs.isEmpty then
      branch "keep_coverage: nobody for those families now"
      return
    let mut best := 0                                         -- `max(len(counted(need, r, T)) for r in cs)`
    let mut first := true
    for r in cs do
      let n := (← counted need r T).length
      if first || n > best then best := n
      first := false
    let r ← NodeV2.choiceCover (← cs.filterM fun r => do return (← counted need r T).length == best)
    NodeV2.openSamplingLink r T                               -- JOIN (DECLARED, NONE)
    for fam in ← counted need r T do
      need := lower need fam
    branch "keep_coverage: a sampling link opened"
  crash "twin: keep_coverage ran out of fuel (the positive needs' sum at the first guard, plus one)"

/-- `keep_floor(T)` (§1.4): at the heartbeat, the links the floor forms on -/
def keepFloor (T : TypeId) : M2 m Unit := do
  enter "keep_floor"
  for fam in ← NodeV2.familiesWithDuty T do
    let fLo ← param T "F_LO" (·.F_LO)                         -- read before floor_links is asked
    let short : Int := (fLo : Int) - ((← NodeV2.floorLinks T fam).length : Int)
    if short ≤ 0 then
      branch "keep_floor: enough"
      continue
    let rs := (← NodeV2.floorCandidates T).filter (·.families.contains fam)
    let k : Int := if (rs.length : Int) < short then rs.length else short    -- `min(short, len(rs))`
    for r in ← NodeV2.sampleCovers rs k.toNat do
      NodeV2.openLink r T
    branch "keep_floor: links opened"

end SpecTwin.V2
