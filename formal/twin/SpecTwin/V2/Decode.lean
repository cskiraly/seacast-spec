import SpecTwin.V2.Probe
import SpecTwin.Sec46
import SpecTwin.Sec61
import SpecTwin.Sec72

/-! # protocol-v2.md's filling, completion, decoding and claims: §4.2's `fill`, §4.6, §4.11's `filter_entry`

The twin of `fill` (§4.2, v0.10.11's text: v0.10.12 changes it, and it is transcribed again from that text);
§4.6's `push_rebuilt_as_source`, `push_rebuilt`, `arm`, `check_completion`, `defer_on_claim`, `reconsider`,
`decode_group`, `claims_close` and `note_claim`; and `filter_entry`, `protocol.md` §7.2's with the probe's
lines. Each comes after every function it calls (`V2/Relations.lean`'s rule).

- **No two of them call each other directly in a cycle:** `arm` reaches `reconsider` through a timer
  (`afterV2`), and `check_completion` and `reconsider` start `decode_group` through `start`, a question, as
  `protocol.md`'s Lean does. So no block here is `mutual`.
- **`protocol.md`'s functions that v2 calls unchanged** run through `v1`: `drop_beyond`, `close_promises`,
  `drop_group`, `add_offer`, `owe`, `held` and `tied_to_root`. The node's helpers are `Node61`'s questions:
  `open_group` (v2's binding writes more, but the question is the same), `store`, `start`,
  `penalise`, `close_promises_of_group`, `deliver` and `payload_of`.
- **`chunks[g][i]`** is a read of another section's table, asked each time the Python reads it:
  `push_rebuilt` reads it once for `T.project` and once more per place the chunk fills.
- **The order of a proxied set** is asked in `fill` (on the claim branch: `suppression_scope(g) | ack`),
  `check_completion` and `reconsider`; `claims.items()` is a table's level, whose keys' order is asked with
  `claimsOrder`, a `keys` entry on the tape.
- **`max(a, b)`** is `if b > a then b else a`: Python's `max` keeps the first of two equal arguments.
- **An ask with its flags**: `filter_entry` filters a plain IWANT's keys and a v2 IWANT's asks
  alike; `held`, `gated` (v2's), `tied_to_root` and the promises take the ask's key, `probe_waits` and
  `probe_settled` the ask with its flags. A plain IWANT's `want` is false, as the toy's `_IWant`'s. -/

namespace SpecTwin.V2

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeV2 m]

/-- `max(a, b)` on floats: the first unless the second is greater, as Python's `max` -/
private def pyMax (a b : Float) : Float := if b > a then b else a

/-- `push_rebuilt_as_source(g2, items)` (§4.6, [D4]): with `REPAIR_BUDGET`, a rebuilt chunk is pushed as its
source pushes one (§1.6): to `R_NODE` peers that lack it, and offered to the rest -/
def pushRebuiltAsSource (g2 : Group) (items : List (Nat × ChunkF)) : M2 m Unit := do
  enter "push_rebuilt_as_source"
  let T2 ← NodeV2.typeOfGroup g2
  for (i2, f) in items do
    -- `[q for q in shuffled(T2.params.REPAIR_TO(g2)) if not (peer_has[q][g2].bits | pushed[q][g2]).has(i2) and
    -- not peer_has[q][g2].complete and interest_of_peer(q, g2).has(i2)]`, left to right
    let cands ← (← NodeV2.shuffledPeers (← NodeV2.repairTo T2 g2)).filterM fun q => do
      let e := (← peerHasEntry? q g2).getD {}
      if (e.bits ||| (← v1 (pushed q g2))).has i2 then return false
      if ((← peerHasEntry? q g2).getD {}).complete then return false
      return (← interestOfPeer q g2).has i2
    let r := (← read).base.c.R_NODE
    for q in cands.take r do                                  -- the per-chunk budget [c17]
      if ← enqueue q (.chunk f) false then
        V2.notePush q g2 i2
      else
        v1 (owe q g2 (1 <<< i2))                              -- refused: offered instead (v0.5)
        branch "push_rebuilt_as_source: a push refused, owed"
    for q in cands.drop r do
      V2.announce q g2 (1 <<< i2)                             -- [c3] offered to the rest
  branch "push_rebuilt_as_source: pushed"

/-- `push_rebuilt(g, new)` (§4.6, [c10]): `protocol.md` §4.6's, over each group a rebuilt chunk fills -/
def pushRebuilt (g : Group) (new : List Nat) : M2 m Unit := do
  enter "push_rebuilt"
  let T ← NodeV2.typeOfGroup g
  -- `by_group.setdefault(g2, []).append((i2, chunks[g][i]))`: a dict, in the order its keys were first set
  let mut byGroup : List (Group × List (Nat × ChunkF)) := []
  for i in new do
    for (g2, i2) in ← NodeV2.project T (← chunkAt g i) do
      let f ← chunkAt g i                                     -- `chunks[g][i]`, read again per place
      byGroup := if byGroup.any (·.1 == g2) then
          byGroup.map fun (x, l) => if x == g2 then (x, l ++ [(i2, f)]) else (x, l)
        else byGroup ++ [(g2, [(i2, f)])]
  for (g2, items) in byGroup do
    -- `expired(g2) or state[g2] == INVALID`: an expired or dropped axis is not acted on
    if ← expired g2 then
      branch "push_rebuilt: an expired group"
      continue
    if (← state? g2) == some .invalid then
      branch "push_rebuilt: a dropped group"
      continue
    let T2 ← NodeV2.typeOfGroup g2
    let k ← NodeV2.threshold T2 (← desc g2)                   -- `k = T2.threshold(hdr[g2])`
    -- `T2.params.REPAIR_BUDGET and T2.params.EAGER`
    let asSource ← if ← param T2 "REPAIR_BUDGET" (·.REPAIR_BUDGET) then param T2 "EAGER" (·.EAGER) else pure false
    if asSource then
      pushRebuiltAsSource g2 items
      continue
    for q in ← NodeV2.shuffledPeers (← NodeV2.repairTo T2 g2) do   -- whose interest includes them (I3) [D4]
      let e := (← peerHasEntry? q g2).getD {}
      let known := e.bits ||| (← v1 (pushed q g2))           -- what q claimed, and what we chose to push it
      let short : Int := (k : Int) - (known.popcount : Int)   -- q's shortfall: none after its decode claim
      if short ≤ 0 || e.complete then continue
      let want ← interestOfPeer q g2                          -- [I3] into interest only
      let lacks ← NodeV2.shuffledPairs (items.filter fun (x, _) => !known.has x && want.has x)
      for (i2, f) in lacks.take short.toNat do                --   so that decoded neighbours differ
        if !(← param T2 "EAGER" (·.EAGER)) then
          V2.announce q g2 (1 <<< i2)                         -- rows: offered, pulled when wanted
          continue
        if ← enqueue q (.chunk f) false then
          V2.notePush q g2 i2
        else
          v1 (owe q g2 (1 <<< i2))                            -- refused: offered instead (v0.5)
          branch "push_rebuilt: a push refused, owed"
      branch "push_rebuilt: a peer short"

/-- A call `push_rebuilt(g, new)` as the node binds the name: the node's own where its line names it as
replaced, a question, else the document's -/
def pushRebuiltCall (g : Group) (new : List Nat) : M2 m Unit := do
  if (← read).base.replaced.contains "push_rebuilt" then NodeV2.pushRebuiltNode g new else pushRebuilt g new

/-- `fill(g, i, f, p)` (§4.2, main's text): chunk i of g is ours, from peer p, or from our own decode where p is
none (R4) -/
def fill (g : Group) (i : Nat) (f : ChunkF) (p : Option Peer) : M2 m Unit := do
  enter "fill"
  if ← expired g then                                         -- not taken up again (protocol.md §8.1)
    branch "fill: expired"
    return
  if (← tOf? g).isNone then                                   -- `if g not in T_of:`
    openGroup g f                                             --   hdr[g], T_of[g], interest[g], known_at[g]
    v1 (dropBeyond g)                                         --   what named an index it has not goes
  if (← state? g) == some .invalid then                       -- a dropped group (§4.6)
    branch "fill: invalid"
    return
  -- `received[g].has(i) or rebuilt[g].has(i)`: a copy of a chunk we hold, acknowledged
  let dup ← if (← receivedBits g).has i then pure true else do pure ((← rebuiltBits g).has i)
  if dup then
    probeAnswer g i p                                         -- (R5) a duplicate from the claimant passes too
    if let some q := p then sendHaveCall q g
    branch "fill: held before"
    return
  store g i f
  match p with                                                -- from the network, or from our own decode
  | some _ => setReceived g ((← receivedBits g).set i)
  | none => setRebuilt g ((← rebuiltBits g).set i)
  probeAnswer g i p                                           -- (R5) the claimant's own copy passes its probe
  let kept ← probePromise g i                                 -- (R5) another peer's copy leaves it open
  v1 (closePromises g i none)                                 -- [c5] the chunk arrived, from anyone
  if let some ((a, q), t) := kept then setPromise a q t       -- `promises[kept[0]] = kept[1]`
  serveStandingCall g i                                       -- WANTs that preceded it are answered now
  serveWaitingProbe g i                                       -- (R5) and a probe that reached us while we decoded
  let claim := !(← mineBits g).has i                          -- not yet claimed
  if claim then setMine g ((← mineBits g).set i)              -- [c7] only chunks that passed level 1
  let ack : List Peer := match p with | some q => [q] | none => []
  if claim then
    -- `suppression_scope(g) | ack`: a proxied union, its order asked
    let scope ← suppressionScope g
    let union := scope ++ ack.filter (!scope.contains ·)
    for q in ← NodeV2.order "fill" union do
      sendHaveCall q g                                        -- [c7] the holding to our pushers, [c14] the ack
    branch "fill: stored and claimed"
  else
    for q in ack do sendHaveCall q g                          -- `ack`, a plain set of one peer or none
    branch "fill: stored, claimed before"

/-- `arm(g, at)` (§4.6): a decode duty that fires unless the group fills first -/
def arm (g : Group) (at_ : Float) : M2 m Unit := do
  enter "arm"
  setReconsiderAt g at_                                       -- `reconsider_at[g] = at`
  -- `after(max(0, at - now), reconsider, g, at)`
  NodeV2.afterV2 (pyMax 0 (at_ - (← read).base.now)) (.reconsider g at_)

/-- `check_completion(g)` (§4.6) -/
def checkCompletion (g : Group) : M2 m Unit := do
  enter "check_completion"
  let T ← NodeV2.typeOfGroup g
  -- `state[g] != COLLECTING or interest[g].empty() or not interest_satisfied(g)`
  if (← state? g) != some .collecting then
    branch "check_completion: not collecting"
    return
  if (← interestOf g).empty then
    branch "check_completion: no interest"
    return
  if !(← NodeV2.interestSatisfied g) then
    branch "check_completion: not satisfied"
    return
  setStopPull g true                                          -- [c6] no further asks for the group
  if ← NodeV2.decodeAtK T g then                              -- [c10] the decode claim at K, before decoding [D4]
    setState g .decoding
    setMine g ((1 <<< (← NodeV2.indexCount T (← desc g))) - 1)   -- `all_bits(T.index_count(hdr[g]))`
  else
    setState g .complete                                      -- e.g. a row member at K: no claim_all (R2)
    if let some later := (← NodeV2.decodeLater T g) then      -- a later duty, if still short then [D4]
      arm g (((← knownAt? g).getD 0.0) + later)               -- `known_at[g] + later`
  for q in ← NodeV2.order "check_completion" (← suppressionScope g) do
    sendHaveCall q g                                          -- complete; and claim_all when decoding
  closePromisesOfGroup g                                      -- [c5] nobody owes us chunks of this group
  if (← state? g) == some .decoding then
    start "decode_group" g                                    -- level 2, off the chunk path
    branch "check_completion: decoding"
  else
    branch "check_completion: complete"

/-- `defer_on_claim(g)` (§4.6, R5): verify the claim by one ask, and wait for it -/
def deferOnClaim (g : Group) : M2 m Unit := do
  enter "defer_on_claim"
  let T ← NodeV2.typeOfGroup g
  let now := (← read).base.now
  setDeferred g true                                          -- `deferred[g] = True`
  setDutyAt g ((← reconsiderAt? g).getD now)                  -- `duty_at[g] = reconsider_at.get(g, now)`
  -- `[i for i in range(T.index_count(hdr[g])) if not mine[g].has(i)]`
  let n ← NodeV2.indexCount T (← desc g)
  let lack ← if n == 0 then pure [] else do                  -- `mine[g]` is read per index: on an empty range,
    let mine ← mineBits g                                     --   not at all
    pure ((List.range n).filter (!mine.has ·))
  let i ← NodeV2.choiceNat lack                               -- an index we lack, at random
  setProbe g i                                                -- `probe[g] = i`
  let q ← NodeV2.choiceOfSet ((← claims? g).getD {}).toList   -- `q = probed[g] = choice(list(claims[g]))`
  setProbed g q
  let a : Key := .want g i
  v1 (addOffer a q)                                           -- a claim is an offer of every index (§6.1's tables)
  setTried a q now                                            -- `tried[a][q] = now`
  setProbeAsk a true                                          -- `probe_asks.add(a)`: gated exempts it; a write
                                                              --   with no read, as the tracer's view of a set logs it
  let w : Want := { group := g, bits := (0 : Bits).set i, standing := false, hops := 0, probe := true }
  if !(← NodeV2.send q (.want w) false) then                  -- marked: answered whatever we hold
    settleProbe g none                                        -- refused by a full queue, never written: no verdict
    let some d ← dutyAt? g | crash s!"KeyError: group {g} (defer_on_claim: duty_at[g])"
    arm g (pyMax now d)                                       -- `arm(g, max(now, duty_at[g]))`
    branch "defer_on_claim: refused"
    return
  -- `arm(g, max(reconsider_at.get(g, now), now + T.params.DEFER_WINDOW))`
  let r := (← reconsiderAt? g).getD now
  arm g (pyMax r (now + (← param T "DEFER_WINDOW" (·.DEFER_WINDOW))))
  branch "defer_on_claim: asked"

/-- `reconsider(g, at)` (§4.6): the decode duty, at its time -/
def reconsider (g : Group) (at_ : Float) : M2 m Unit := do
  enter "reconsider"
  let T ← NodeV2.typeOfGroup g
  let now := (← read).base.now
  -- `reconsider_at.get(g) != at or state[g] != COMPLETE`: re-armed since, or decoding already
  if (← reconsiderAt? g) != some at_ then
    branch "reconsider: re-armed since"
    return
  if (← state? g) != some .complete then
    branch "reconsider: not complete"
    return
  eraseReconsiderAt g                                         -- `del reconsider_at[g]`
  -- (R5) the verdict, once: a probe not written by now gets none
  if ← deferred? g then
    if (← probeOk? g).isNone then
      if ← probeSent? g then
        settleProbe g (some false)
        let some q ← probed? g | crash s!"KeyError: group {g} (reconsider: probed[g])"
        penalise q
        branch "reconsider: the probe failed"
      else
        settleProbe g none
        branch "reconsider: the probe got no verdict"
  -- `popcount(known_in_scope(g)) >= T.index_count(hdr[g])`: whole in the subnet's view
  let kis ← knownInScopeCall g
  if kis.popcount ≥ (← NodeV2.indexCount T (← desc g)) then
    branch "reconsider: whole in the subnet's view"
    return
  -- `deferred[g] and received[g].has(probe[g]) and wants_family(T, T.family(g)) and not owed_missing(g)`
  let claimHeld ← if !(← deferred? g) then pure false else do
    let r ← receivedBits g
    let some pi ← probe? g | crash s!"KeyError: group {g} (reconsider: probe[g])"
    if !r.has pi then pure false else do
      if !(← NodeV2.wantsFamily T (← NodeV2.family T g)) then pure false else do
        pure !(← owedMissingCall g)
  if claimHeld then
    if (← param T "REPAIR_SAMPLE" (·.REPAIR_SAMPLE)).isNone then
      branch "reconsider: the claim held, no repair sample"
      return
    match ← repairVerdictCall g with                          -- (R5, option) the repair sampled across the columns
    | .repaired =>
      branch "reconsider: repaired"
      return
    | .asked =>
      arm g (now + (← param T "SAMPLE_WAIT" (·.SAMPLE_WAIT)))
      branch "reconsider: the sample asked, re-armed"
      return
    | .notRepaired => branch "reconsider: not repaired"       -- rebuild
  -- `not waited[g] and not deferred[g] and popcount(known_in_scope(g) | known_across(g)) >= T.index_count(…)`
  let wait ← if ← waited? g then pure false else do
    if ← deferred? g then pure false else do
      let a ← knownInScopeCall g
      let b ← knownAcross g
      pure ((a ||| b).popcount ≥ (← NodeV2.indexCount T (← desc g)))
  if wait then
    setWaited g true                                          -- (R4) held on the other axis: wait once
    arm g (now + (← param T "DEFER_WINDOW" (·.DEFER_WINDOW)))
    branch "reconsider: held across, waited once"
    return
  -- `if claims[g] and not deferred[g]: return defer_on_claim(g)`
  if !((← claims? g).getD {}).isEmpty then
    if !(← deferred? g) then
      deferOnClaim g                                          -- (R5) a claim arrived: one deferral
      branch "reconsider: a claim, deferred"
      return
  setState g .decoding                                        -- the late decode claim, as at K
  setMine g ((1 <<< (← NodeV2.indexCount T (← desc g))) - 1)
  for q in ← NodeV2.order "reconsider" (← suppressionScope g) do
    sendHaveCall q g
  start "decode_group" g
  branch "reconsider: decoding"

/-- `decode_group(g)` (§4.6): level 2, off the chunk path -/
def decodeGroup (g : Group) : M2 m Unit := do
  enter "decode_group"
  let T ← NodeV2.typeOfGroup g
  let whole ← NodeV2.decode T g (← desc g)                    -- `T.decode(chunks[g], hdr[g])`
  if ← expired g then                                         -- the group passed its lifetime meanwhile
    branch "decode_group: expired meanwhile"
    return
  let some whole := whole
    | v1 (dropGroup g)                                        -- [D6]
      branch "decode_group: dropped"
  -- `[i for i in whole if not received[g].has(i)]`: rebuilt, and not received meanwhile
  let new ← (whole.map (·.1)).filterM fun i => do return !(← receivedBits g).has i
  let mut filled : List Group := []                           -- the other groups the rebuilt chunks fill, in order
  for i in new do
    let some f := whole.lookup i | crash s!"KeyError: {i} (decode_group: whole[i])"
    store g i f
    setRebuilt g ((← rebuiltBits g).set i)                    -- servable from now on
    serveStandingCall g i                                     -- as in fill
    serveWaitingProbe g i                                     -- (R5) a probe that reached us while we decoded
    for (g2, i2) in ← NodeV2.project T f do                   -- (R4) a rebuilt chunk fills its other groups too
      if g2 == g then continue
      fill g2 i2 f none
      if !filled.contains g2 then filled := filled ++ [g2]
  setState g .complete
  pushRebuiltCall g new                                       -- [c10] repair: level 2 has passed
  for g2 in filled do checkCompletion g2                      -- (R4) a filled group may be complete
  deliver g (← payloadOf whole)                               -- level 3: the application's checks
  branch "decode_group: complete"

/-- `claims_close(p)` (§4.6, R5): p's connection closed: its claims go; our probe of p, not yet judged, gets no
verdict, and the deferral ends -/
def claimsClose (p : Peer) : M2 m Unit := do
  enter "claims_close"
  let now := (← read).base.now
  -- `[g for g, qs in claims.items() if p in qs]`, in the keys' order
  let all ← allClaims
  let mut gs : List Group := []
  for g in ← NodeV2.claimsOrder (all.map (·.1)) do
    match all.lookup g with
    | some qs => if qs.contains p then gs := gs ++ [g]
    | none => return (← crash "twin: claims_close: the order names a group claims has not")
  for g in gs do
    let s := (← claims? g).getD {}                            -- `claims[g].discard(p)`: the leaf is kept
    if s.contains p then setClaims g (s.erase p)
    -- `deferred[g] and probed.get(g) == p and g not in probe_ok`
    if !(← deferred? g) then continue
    if (← probed? g) != some p then continue
    if (← probeOk? g).isSome then continue
    settleProbe g none
    arm g (pyMax now ((← dutyAt? g).getD now))                -- `max(now, duty_at.get(g, now))`
    branch "claims_close: the probe of p ended"

/-- `note_claim(p, g)` (§4.6, R5): from `on_holding`: p claims every index of g -/
def noteClaim (p : Peer) (g : Group) : M2 m Unit := do
  enter "note_claim"
  let s := (← claims? g).getD {}                              -- `claims[g].add(p)`
  if !s.contains p then setClaims g (s.insert p)
  -- `g in reconsider_at and state[g] == COMPLETE and not deferred[g] and popcount(mine[g]) <
  -- type_of_group(g).index_count(hdr[g])`
  if (← reconsiderAt? g).isNone then return
  if (← state? g) != some .complete then return
  if ← deferred? g then return
  let c := (← mineBits g).popcount
  if c < (← NodeV2.indexCount (← NodeV2.typeOfGroup g) (← desc g)) then
    deferOnClaim g
    branch "note_claim: deferred"

/-- A call `note_claim(p, g)` as the node binds the name: the node's own where its line names it as replaced, a
question, else the document's -/
def noteClaimCall (p : Peer) (g : Group) : M2 m Unit := do
  if (← read).base.replaced.contains "note_claim" then NodeV2.noteClaimNode p g else noteClaim p g

/-- The asks of one IWANT that still go (`filter_entry`'s `c.ids = [a for a in c.ids if …]`), and the promises
they start at the write [c5] -/
private def keepAsks (p : Peer) (want : Bool) (asks : List AskV2) : M2 m (List AskV2) := do
  let now := (← read).base.now
  -- `(not held(a) or probe_waits(a, p)) and not probe_settled(a) and not gated(a) and not expired(group(a)) and
  -- not tied_to_root(p, a)`, left to right
  let kept ← asks.filterM fun a => do
    if ← v1 (held a.key) then
      if !(← probeWaits a p) then return false
    if ← probeSettled a then return false
    if ← gated a.key then return false
    if ← expired a.key.group then return false
    return !(← v1 (tiedToRoot p a.key))
  for a in kept do
    let g := a.key.group
    -- `if probe_waits(a, p) and group(a) not in probe_sent:` our probe, written now
    let first ← if ← probeWaits a p then do pure !(← probeSent? g) else pure false
    if first then
      let W ← param (← NodeV2.typeOfGroup g) "DEFER_WINDOW" (·.DEFER_WINDOW)
      setProbeSent g true                                     -- `probe_sent.add(group(a))`
      setPromise a.key p now                                  -- `promises[(a, p)] = now`
      after W (.promiseDue a.key p now)                       -- broken: the claimant is parked
      arm g (pyMax ((← reconsiderAt? g).getD now) (now + W))
      continue
    -- `elif (a, p) not in promises and (not c.want or probe_waits(a, p)):`
    if (← promise? a.key p).isSome then continue
    let starts ← if !want then pure true else probeWaits a p
    if starts then
      setPromise a.key p now
      after (← read).base.c.PROMISE (.promiseDue a.key p now)   -- 400 ms
  return kept

/-- `filter_entry(p, entry)` (§4.11): `protocol.md` §7.2's, with the probe's lines (R5) and a WANT's -/
def filterEntry (p : Peer) (entry : QEntry) : M2 m (Option QEntry) := do
  enter "filter_entry"
  let c := (← read).base.c
  let mut e := entry
  if let some f := entry.chunk then
    -- `exempt = entry.solicited and probe_answers[p][f.group].has(f.index)`: our answer to p's probe
    let exempt ← if entry.solicited then do pure ((← probeAnswerBits p f.g).has f.i) else pure false
    -- `CANCEL and not exempt and peer_has[p][f.group].has(f.index)`
    let cancel ← if c.CANCEL && !exempt then do pure ((← v1 (peerHas p f.g)).has f.i) else pure false
    if cancel then
      e := { e with chunk := none }                           -- [c8] it became a duplicate
      branch "filter_entry: cancelled"
    else
      let skip ← if c.PROJECT && !entry.solicited then projected p f.g else pure false
      if skip then
        e := { e with chunk := none }                         -- [c12]
        V2.unpush p f.g f.i                                   -- [c3] not made: offered instead
        branch "filter_entry: projected away"
      else
        setSentTo p f.g ((← sentToBits p f.g).set f.i)       -- `sent_to[p][f.group].set(f.index)`
        if exempt then                                        -- (R5) spent by the answer written, once
          setProbeAnswers p f.g ((← probeAnswerBits p f.g).clear f.i)
        branch "filter_entry: sent"
  -- `for c in entry.iwants():` a plain IWANT's keys and a v2 IWANT's asks alike
  match e.control with
  | none => pure ()
  | some cs =>
    let mut out : List Ctl := []
    for msg in cs do
      match msg with
      | .iwant ids =>
        let kept ← keepAsks p false (ids.map fun k => { key := k })
        out := out ++ [.iwant (kept.map (·.key))]
      | .iwantV2 want asks =>
        out := out ++ [.iwantV2 want (← keepAsks p want asks)]
      | msg => out := out ++ [msg]
    e := { e with control := some out }
  return if e.isEmpty then none else some e                   -- control rides on and survives

end SpecTwin.V2
