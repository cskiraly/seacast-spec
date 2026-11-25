import SpecTwin.Seacast.Probe
import SpecTwin.Sec61

/-! # seacast.md §4.5: an ask arrives, and serving

The twin of §4.5's `on_want` and the three it calls, `outside`, `index_bound` and `our_interest_for`, and of §4.10's
`route_want`, which `on_want` calls for a routed sample request it cannot answer. Each comes after every function it
calls (`Seacast/Relations.lean`'s rule). It also holds §4.5's `may_be_asked`, P7's definition, which no function
calls: its records are directed ones.

- **`on_want`'s three maps.** `answers` is a dict by id, in insertion order: no id is set twice in it, since an id
  already there is skipped first, and its values are returned in that order. `probes` is built by a comprehension
  over the asks, so a later probe of the same group and index replaces an earlier one; it is read only by `.get`, so
  the twin keeps the probes in order and takes the last of a place. `taken` is a set, read only by `in`. None of the
  three is a table, and no proxied set is iterated, so `on_want` asks no `order`.
- **An ask always has a group and an index here** (`groupIndex` of a `Key`, `Seacast/Probe.lean`), so `gi` is never
  none: the tracer refuses an ask that is neither an ask by index nor a structured id. The twin crashes with a name
  of its own where it would be.
- **`or` and `and` short-circuit** as the Python's do, read for read: `outside` is called before `peer_has[p][g]` is
  read; `probe_of_claim` is called a second time, with the frame's probe of the place or none, only where the
  first call is false; `offered_to` is read only where the answer is not a probe's, and `served_hb` only where the
  budget counts it.
- **The two serving counters.** `serve_count[p][mid] >= GOSSIP_RETRANSMISSION` is tested before `serve_count` is
  raised, where `seacast-lite.md`'s `on_iwant` raises it first and tests `>` (`Sec41.lean`). `SERVE_BUDGET` is none
  for no limit, as `serve_standing` reads it.
- **The lazy tables** (toy/node.py's `lazy`, `lazy2`): a read creates nothing. `standing[g][i].discard(p)` on a
  missing entry writes nothing, and on a present one leaves its set, empty or not; `.add` makes the entry.
- **The plain dicts that raise:** `join_sent[p][T]` and `join_recv[p][T]` crash as `KeyError` on the type, named
  with its kind (`type T`), where the Python loads them, as `interest_of_peer` does.
- **Questions:** `admitted_group(p, g)` and `own_id()`, SEACAST's; `resolve(a)`, `chunk_of(mid)`, `expired(g)`,
  `authenticable(g)` and `penalise(p)`, the node's store and helpers, as `seacast-lite.md`'s `on_iwant` asks them.
  `own_id()` is asked only in `our_interest_for`'s DERIVED case, where the Python calls it. -/

namespace SpecTwin.Seacast

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeSeacast m]

/-- `index_bound(g)` (§4.5): the group's count once known, else the most indices a group of its type has -/
def indexBound (g : Group) : M2 m Nat := do
  enter "index_bound"
  let T ← NodeSeacast.typeOfGroup g
  -- `T.index_count(hdr[g]) if g in hdr else T.params.MAX_INDICES`
  match ← desc g with
  | some h => NodeSeacast.indexCount T (some h)
  | none => param T "MAX_INDICES" (·.MAX_INDICES)

/-- `our_interest_for(p, g)` (§4.5): our interest in g as we declared it to p -/
def ourInterestFor (p : Peer) (g : Group) : M2 m IBits := do
  enter "our_interest_for"
  let T ← NodeSeacast.typeOfGroup g
  let some j ← joinSent? p T | crash s!"KeyError: type {T} (our_interest_for: join_sent[p][T])"
  match j.interest with
  | .all => return IBits.not 0                                -- `EVERY_INDEX`
  | .derived =>
    -- `T.derived_interest(g, hdr.get(g), own_id(), j)`: the arguments left to right
    NodeSeacast.derivedInterest T g (← desc g) (← NodeSeacast.ownId) j
  | .declared => return 0                                     -- `EMPTY`: a sampler is asked only for what it holds

/-- `may_be_asked(p, g, i, routed=False)` (§4.5, P7): which asks of ours p may take. The four operands of the `or`
are asked in order, each only where those before it are false -/
def mayBeAsked (p : Peer) (g : Group) (i : Nat) (routed : Bool) : M2 m Bool := do
  enter "may_be_asked"
  let T ← NodeSeacast.typeOfGroup g                            -- `T = type_of_group(g)`, before the `return`
  if ← NodeSeacast.offeredUs p g i then                        -- `offered_us(p, g, i)`, the binding's
    branch "may_be_asked: offered us"
    return true
  if (← interestOfPeer p g).has i then                         -- `interest_of_peer(p, g).has(i)`
    branch "may_be_asked: in its interest"
    return true
  if ((← peerHasEntry? p g).getD {}).claimAll then             -- `peer_has[p][g].claim_all`: no entry reads as none
    branch "may_be_asked: claimed whole"
    return true
  -- `routed and join_recv[p][T].duty == FORWARD`: [D12] a routed request may go to any forwarding node.
  -- `interest_of_peer` read the same entry, so its absence raised there first.
  if routed then
    let some j ← joinRecv? p T | crash s!"KeyError: type {T} (may_be_asked: join_recv[p][T])"
    if j.duty == .forward then
      branch "may_be_asked: routed to a forwarding node"
      return true
    branch "may_be_asked: routed, not to a forwarding node"
    return false
  branch "may_be_asked: none of the four"
  return false

/-- `outside(p, g, i, routed)` (§4.5): `may_be_asked` as p reads us is false, once we can tell -/
def outside (p : Peer) (g : Group) (i : Nat) (routed : Bool) : M2 m Bool := do
  enter "outside"
  let T ← NodeSeacast.typeOfGroup g
  -- `not authenticable(g) or g in origin or mine[g].has(i)`: held, or claimed whole (decoding)
  if !(← authenticable g) then
    branch "outside: not authenticable"
    return false
  if (← origin g).isSome then
    branch "outside: our own group"
    return false
  if (← mineBits g).has i then
    branch "outside: held"
    return false
  -- `routed and join_sent[p][T].duty == FORWARD`: [D12] a routed request to a forwarding node
  if routed then
    let some j ← joinSent? p T | crash s!"KeyError: type {T} (outside: join_sent[p][T])"
    if j.duty == .forward then
      branch "outside: routed to a forwarding node"
      return false
  -- `not our_interest_for(p, g).has(i)`: never offered, since an offer names only what we hold
  if (← ourInterestFor p g).has i then
    branch "outside: in our interest"
    return false
  branch "outside: outside our interest"
  return true

/-- `route_want(p, g, i, hops)` (§4.10): a routed sample request we cannot answer, one step on -/
def routeWant (p : Peer) (g : Group) (i : Nat) (hops : Nat) : M2 m Bool := do
  enter "route_want"
  let T ← NodeSeacast.typeOfGroup g
  -- `join_sent[p][T].duty != FORWARD or forwarded[p][T] >= T.params.FORWARD_LIMIT`: (X6) refused without penalty
  let some j ← joinSent? p T | crash s!"KeyError: type {T} (route_want: join_sent[p][T])"
  if j.duty != .forward then
    branch "route_want: not a forwarding link"
    return false
  let n ← forwardedCount p T
  if natGeFloat n (← param T "FORWARD_LIMIT" (·.FORWARD_LIMIT)) then
    branch "route_want: past the limit"
    return false
  -- `[q for q in links(T) if q != p and serves(q, g, i) and not parked(q, Ask(g, i))]`, left to right
  let mut qs ← (← NodeSeacast.links T).filterM fun q => do
    if q == p then return false
    if !(← serves q g i) then return false
    return !(← lite (parked q (.want g i)))
  let mut left := 0
  if qs.isEmpty && hops > 1 then
    -- `route_next(T, T.family(g), [q for q in links(T) if q != p and join_recv[q][T].duty == FORWARD])`: the
    -- family asked before the links, as the arguments are evaluated
    let fam ← NodeSeacast.family T g
    let fs ← (← NodeSeacast.links T).filterM fun q => do
      if q == p then return false
      let some jq ← joinRecv? q T | crash s!"KeyError: type {T} (route_want: join_recv[q][T])"
      return jq.duty == .forward
    qs ← NodeSeacast.routeNext T fam fs
    left := hops - 1
  if qs.isEmpty then
    branch "route_want: no route"                             -- silence, as above
    return false
  let q ← NodeSeacast.choicePeer qs
  let w : Want := { group := g, bits := (0 : Bits).set i, standing := true, hops := left, probe := false }
  if !(← NodeSeacast.send q (.want w) false) then
    branch "route_want: refused by a full queue"              -- not passed on, not counted
    return false
  setForwarded p T ((← forwardedCount p T) + 1)               -- `forwarded[p][T] += 1`
  branch "route_want: passed on"
  return true

/-- `served[p][g] >= type_of_group(g).params.SERVE_LIMIT`: the count read first, then the type asked and the limit
read, as the Python evaluates them -/
private def pastServeLimit (p : Peer) (g : Group) : M2 m Bool := do
  let n ← servedCount p g
  let lim ← param (← NodeSeacast.typeOfGroup g) "SERVE_LIMIT" (·.SERVE_LIMIT)
  return natGeFloat n lim                                    -- Python's int-to-float `>=`, exactly

/-- `s[g][i].discard(p)` on a lazy set table: a missing entry is left missing, a present one keeps its set -/
def discardFrom (get : Group → Nat → M2 m (Option (Std.HashSet Peer)))
    (set : Group → Nat → Std.HashSet Peer → M2 m Unit) (g : Group) (i : Nat) (p : Peer) : M2 m Unit := do
  if let some s ← get g i then
    if s.contains p then set g i (s.erase p)

/-- `s[g][i].add(p)` on a lazy set table: the entry is made at its first addition -/
private def addTo (get : Group → Nat → M2 m (Option (Std.HashSet Peer)))
    (set : Group → Nat → Std.HashSet Peer → M2 m Unit) (g : Group) (i : Nat) (p : Peer) : M2 m Unit := do
  let s := (← get g i).getD {}
  if !s.contains p then set g i (s.insert p)

/-- `on_want(p, asks)` (§4.5): `seacast-lite.md` §4.5's `on_iwant`, plus the serving limit (R6); the answers, one chunk
per id, in the order first answered -/
def onWant (p : Peer) (asks : List AskSeacast) : M2 m (List ChunkF) := do
  enter "on_want"
  let mut answers : List (Key × ChunkF) := []                -- by id: one answer per id per frame
  -- `probes = {(gi.group, gi.index): gi for gi in map(group_index, asks) if gi and gi.probe}`: the last of a place
  let probes := (asks.filterMap groupIndex).filter (·.probe)
  let mut taken : List (Group × Nat) := []                   -- §4.5: the indices answered in this frame
  for a in asks do
    let some gi := groupIndex a | crash "twin: on_want: group_index(a) is none, which no ask the twin reads gives"
    let g := gi.key.group; let i := gi.key.index
    if taken.contains (g, i) then
      branch "on_want: an index answered in this frame"
      continue
    if !(← joined p (← NodeSeacast.typeOfGroup g)) then
      branch "on_want: a type the link has not joined"          -- §2
      continue
    if ← expired g then
      branch "on_want: expired"                                -- past its active lifetime: ignored, no penalty
      continue
    if i ≥ (← indexBound g) then
      branch "on_want: an index the group cannot have"         -- ignored
      continue
    -- `gi.hops if gi and join_sent[p][type_of_group(gi.group)].duty == FORWARD else 0`: routed only through a
    -- forwarding node
    let T ← NodeSeacast.typeOfGroup g
    let some js ← joinSent? p T | crash s!"KeyError: type {T} (on_want: join_sent[p][T])"
    let hops := if js.duty == .forward then gi.hops else 0
    -- `outside(p, g, i, hops > 0) and not peer_has[p][g].has(i)`: not ours to serve p, ignored with no penalty
    if ← outside p g i (hops > 0) then
      if !(← lite (peerHas p g)).has i then
        branch "on_want: outside what we serve p"
        continue
    if !(← NodeSeacast.admittedGroup p g) then
      branch "on_want: a group not admitted"                   -- beyond p's unknown groups named in WANTs
      continue
    -- `declared = gi and join_recv[p][type_of_group(gi.group)].interest == DECLARED`
    let T' ← NodeSeacast.typeOfGroup g
    let some jr ← joinRecv? p T' | crash s!"KeyError: type {T'} (on_want: join_recv[p][T])"
    let declared := jr.interest == .declared
    -- `declared and not (hops > 0 and not our_interest_for(p, g).has(i))`: its WANT is its interest (§1.2), but for
    -- a routed one outside ours
    if declared then
      let keep ← if hops > 0 then do pure ((← ourInterestFor p g).has i) else pure true
      if keep then
        -- `want_p[p][g] = want_p[p].get(g, EMPTY) | bitmap({i})`
        setWantP p g (IBits.or ((← wantP? p g).getD 0) (IBits.ofBits ((0 : Bits).set i)))
    -- `probe_of_claim(p, gi) or (gi is not None and probe_of_claim(p, probes.get((gi.group, gi.index))))`
    let flagged ← do
      if ← probeOfClaim p (some gi) then pure true
      else probeOfClaim p (probes.filter (fun x => x.key.group == g && x.key.index == i)).getLast?
    -- `gi and peer_has[p][g].has(i) and not flagged`: the holding read first
    if (← lite (peerHas p g)).has i then
      if !flagged then
        penalise p                                             -- it asks for a chunk it claimed: the claim wins
        branch "on_want: an ask of a chunk p claimed"
        continue
    if ← pastServeLimit p g then
      branch "on_want: past the serving limit"                 -- (R6) refused without penalty
      continue
    match ← resolve a.key with                                 -- [c7] our chunk at that index: received or rebuilt
    | none =>
      -- `passed = gi and hops > 0 and route_want(p, g, i, hops)`: §4.10, one step on
      let passed ← if hops > 0 then routeWant p g i hops else pure false
      -- `flagged and p not in probe_waiting[g]`: probe_waiting read only where flagged
      if flagged then
        if (← probeWaiting? g p).isNone then
          -- (R5) claimed, not stored: we are decoding; the first per asker and group is answered when it is (§4.6),
          -- once, in place of p's standing WANT of that index
          setProbeWaiting g p i
          discardFrom standing? setStanding g i p
          discardFrom routedStanding? setRoutedStanding g i p
          branch "on_want: a probe kept until we decode"
          continue
      -- `gi and (declared or gi.standing) and probe_waiting[g].get(p) != i and (hops == 0 or passed or
      -- our_interest_for(p, g).has(i))`
      let mut stand := false
      if declared || gi.standing then
        if (← probeWaiting? g p) != some i then
          stand ← if hops == 0 || passed then pure true else do pure ((← ourInterestFor p g).has i)
      if stand then
        addTo standing? setStanding g i p                      -- §4.10: answered when the chunk arrives; a routed one
        if hops > 0 then addTo routedStanding? setRoutedStanding g i p   -- outside our interest only if passed on
        branch "on_want: standing until the chunk arrives"
        continue
      branch "on_want: nothing to answer with"
      continue
    | some mid =>
      if let some f := answers.lookup mid then                 -- §4.5: an id is answered once a frame, and counted once
        if flagged then serveProbe p g f                       -- (R5) a probe through its other type: the answer chosen
        branch "on_want: an id answered in this frame"
        continue
      if (← unwantedOf p).contains mid.idHex then              -- `mid in unwanted[p] and not flagged`
        if !flagged then
          branch "on_want: unwanted"
          continue
      if (← serveCount p mid) ≥ (← read).base.c.GOSSIP_RETRANSMISSION then
        branch "on_want: served too often"                     -- stock: 3 answers per id per peer
        continue
      -- `counted = not flagged and not (gi and offered_to[p][g].has(i))`: the budget counts an answer given, not a
      -- probe's, not one on our offer
      let counted ← if flagged then pure false else do pure (!(← offeredToBits p g).has i)
      if counted then
        let n ← servedHbCount p
        if (← read).c2.SERVE_BUDGET.any (n ≥ ·) then
          branch "on_want: over the budget"                    -- refused without penalty
          continue
        setServedHb p ((← servedHbCount p) + 1)                -- `served_hb[p] += 1`
      setServeCount p mid ((← serveCount p mid) + 1)           -- `serve_count[p][mid] += 1`
      setServed p g ((← servedCount p g) + 1)                  -- `served[p][g] += 1`
      if flagged then serveProbe p g (← chunkOf mid)           -- (R5) answered: the probe's one exemption, taken
      answers := answers ++ [(mid, ← chunkOf mid)]             -- `answers[mid] = chunk_of(mid)`
      taken := taken ++ [(g, i)]
      branch "on_want: answered"
  return answers.map (·.2)                                    -- [c14] one chunk per queue entry

end SpecTwin.Seacast
