import SpecTwin.V2.Decode
import SpecTwin.Sec2
import SpecTwin.Sec42
import SpecTwin.Sec44
import SpecTwin.Sec53
import SpecTwin.Sec61

/-! # protocol-v2.md's arrivals: §4.4's `forward`, §4.2's chunk, §4.3's holding and offer

The twin of `forward` (§4.4), `on_validated`, `defer` and `on_chunk` (§4.2), and `on_holding` and `on_offer`
(§4.3). Each comes after every function it calls (`V2/Relations.lean`'s rule).

- **No recursion through `defer`.** `on_validated` calls `defer` on a `DEFER` verdict, and v2's
  `defer` calls `on_validated` only on another verdict, which never calls `defer` again. So `on_validated` is
  written in two parts: its head (`enter`, and the test of the group's lifetime and the slot's window), and its
  body past the `DEFER` test. `defer` runs the head and the body, as the Python's call does with a verdict that
  is not `DEFER`; `on_validated` runs the head, then `defer` or the body. Nothing is `mutual`.
- **`protocol.md`'s functions that v2 calls unchanged** run through `v1`: `message_id` (the toy's `chunk_id`),
  `tie`, `choose_push`, `add_offer`, `tied_to_root`, `parked`, `last_resort`, `outstanding`,
  `over_ihave_limits` and `may_ask`. The node's helpers are `Node61`'s questions: `seen`, `accepted`,
  `mark_seen`, `live`, `admitted`, `reserve`, `penalise`, `authenticable`, `shuffled`, and
  `gossip_history.put`; `valid_have(h)` and `deferred_offers(p, h)` are `NodeV2`'s, with the whole holding.
- **`window_release`** is cut at every node this cycle: `on_holding` calls it through `V2Later`.
- **`T.project(f)`** is asked each time the Python calls it: three times in `on_validated`.
- **`forward`'s axes** are an `Option`: none projects the chunk's own, and an empty list forwards on none. The
  Python's `None` and `[]` are two values there, and the twin keeps them apart. -/

namespace SpecTwin.V2

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeV2 m] [V2Later m]

/-- `forward(f, from_peer, axes)` (§4.4): pushes and offers on each axis we forward on -/
def forward (f : ChunkF) (fromPeer : Peer) (axes : Option (List GI)) : M2 m Unit := do
  enter "forward"
  -- `type_of_group(f.group).project(f) if axes is None else axes`
  let places ← match axes with
    | none => do NodeV2.project (← NodeV2.typeOfGroup f.g) f
    | some l => pure l
  for (g, i) in places do                                     -- (R4) each axis with its own type
    let T ← NodeV2.typeOfGroup g
    -- `expired(g) or state[g] == INVALID`: an expired or dropped axis is not acted on
    if ← expired g then
      branch "forward: an expired group"
      continue
    if (← state? g) == some .invalid then
      branch "forward: a dropped group"
      continue
    if (← NodeV2.dutyFor g) != .forward then                  -- no duty on this axis: we only serve asks
      branch "forward: no duty"
      continue
    let fam ← NodeV2.family T g                               -- `fam, c = T.family(g), colour_of(g, i)`
    let c ← colourOf g i
    let pushers ← (← NodeV2.links T).filterM fun q => do return (← pushOutOf q T fam).contains c
    let holding ← pushers.filterM fun q => do return (← v1 (peerHas q g)).has i   -- [c4] the sender, normally
    -- `[q for q in pushers if q not in holding and q != from_peer and interest_of_peer(q, g).has(i) and not
    -- peer_has[q][g].complete]`, left to right
    let cands ← pushers.filterM fun q => do
      if holding.contains q || q == fromPeer then return false
      if !(← interestOfPeer q g).has i then return false
      return !((← peerHasEntry? q g).getD {}).complete
    -- `max(0, R_NODE - len(holding)) if T.params.EAGER else 0`
    let budget ← if ← param T "EAGER" (·.EAGER) then
        pure (((← read).base.c.R_NODE : Int) - (holding.length : Int)).toNat
      else pure 0
    let targets ← v1 (choosePush f cands budget false)        -- protocol.md §5.3 unchanged
    for q in targets do
      if ← enqueue q (.chunk f) false then
        V2.notePush q g i                                     -- [c7, c16]
      else
        v1 (owe q g (1 <<< i))                                -- [c3] refused: offered instead (v0.5)
        branch "forward: a push refused, owed"
    for q in cands do
      if !targets.contains q then V2.announce q g (1 <<< i)   -- [c3] offered instead
    for q in ← announceExtra g i do                           -- [D5] width beyond the relation
      V2.announce q g (1 <<< i)
    branch "forward: an axis"
  if (← state? f.g) != some .invalid then gossipPut f         -- heartbeat gossip (§4.8); never a dropped group's

/-- A call `forward(f, from_peer, axes)` as the node binds the name: the node's own where its line names it as
replaced, a question with `axes`, else the document's -/
def forwardCall (f : ChunkF) (fromPeer : Peer) (axes : Option (List GI)) : M2 m Unit := do
  if (← read).base.replaced.contains "forward" then NodeV2.forwardNode f fromPeer axes else forward f fromPeer axes

/-- `on_validated`'s head: `if expired(f.group) or not live(f.slot): return`; whether the call goes on -/
private def validatedHead (f : ChunkF) : M2 m Bool := do
  enter "on_validated"
  if ← expired f.g then
    branch "on_validated: expired"
    return false
  if !(← live f.slot) then
    branch "on_validated: not live"
    return false
  return true

/-- `on_validated`'s body past its `DEFER` test: level 1's verdict is ACCEPT or REJECT -/
private def validatedBody (p : Peer) (f : ChunkF) (result : Verdict) : M2 m Unit := do
  markSeen (← v1 (messageId f))                               -- accepted or rejected: never validated again
  if result == .reject then                                   -- level 1 failures are the sender's
    penalise p
    branch "on_validated: rejected"
    return
  let T ← NodeV2.typeOfGroup f.g
  -- `[(g, i) for (g, i) in T.project(f) if not received[g].has(i)]`
  let new ← (← NodeV2.project T f).filterM fun (g, i) => do return !(← receivedBits g).has i
  for (g, i) in ← NodeV2.project T f do                       -- (R4) one arrival fills every group it belongs to
    fill g i f (some p)
  -- `[(g, i) for (g, i) in new if not expired(g) and state[g] != INVALID]`
  let acting ← new.filterM fun (g, _) => do
    if ← expired g then return false
    return (← state? g) != some .invalid
  -- `any(duty_for(g) == FORWARD for (g, i) in acting)`: the questions stop at the first
  let mut fwd := false
  for (g, _) in acting do
    if (← NodeV2.dutyFor g) == .forward then
      fwd := true
      break
  if fwd then forwardCall f p (some acting)                   -- on any axis we serve; never waits for level 2
  for (g, _) in ← NodeV2.project T f do
    checkCompletion g                                         -- §4.6
  branch "on_validated: filled"

/-- `defer(p, f)` (§4.2): `protocol.md` §4.2's, at the gate of f's type -/
def defer (p : Peer) (f : ChunkF) : M2 m Unit := do
  enter "defer"
  let T ← NodeV2.typeOfGroup f.g
  let result ← NodeV2.verify T f (← NodeV2.headerOf T f)     -- `T.verify(f, T.header_of(f))`
  if result != .defer then                                    -- the gate opened in the meantime:
    if ← validatedHead f then validatedBody p f result        --   `on_validated(p, f, result)`, not DEFER
    branch "defer: the gate opened"
    return
  if !(← admitted p f) then                                   -- beyond the peer's unknown groups: ignored
    branch "defer: not admitted"
    return
  v1 (tie p f)                                                -- kept or refused, its sender is tied to the root
  if ← reserve p f then                                       -- a per-peer reservation in the bounded store
    setPending f.root ((← pendingOf f.root) ++ [(p, f)])      -- `pending[f.beacon_block_root].append((p, f))`
    setPendingId (← v1 (messageId f)) true                    -- `pending_ids.add(chunk_id(f))`
    branch "defer: kept"
  else
    branch "defer: refused"                                   -- not kept; its sender stays tied

/-- `on_validated(p, f, result)` (§4.2) -/
def onValidated (p : Peer) (f : ChunkF) (result : Verdict) : M2 m Unit := do
  if !(← validatedHead f) then return
  if result == .defer then                                    -- `return defer(p, f)`: the bounded per-peer store
    defer p f
    branch "on_validated: deferred"
    return
  validatedBody p f result

/-- `on_chunk(p, f)` (§4.2) -/
def onChunk (p : Peer) (f : ChunkF) : M2 m Unit := do
  enter "on_chunk"
  let mid ← v1 (messageId f)                                  -- `mid = chunk_id(f)`
  -- `if seen(mid) or mid in pending_ids:` a duplicate, a chunk rejected before, or one waiting
  let dup ← if ← seen mid then pure true else pendingId? mid
  if dup then
    if ← accepted mid then                                    -- (R5) the claimant's copy passes its probe too
      for (g, i) in ← NodeV2.project (← NodeV2.typeOfGroup f.g) f do
        probeAnswer g i (some p)
      sendHaveCall p f.g                                      -- [c14] duplicates are acknowledged too
      branch "on_chunk: a duplicate, acknowledged"
    else if ← pendingId? mid then                             -- another copy of one that waits: its sender too
      v1 (tie p f)
      branch "on_chunk: a duplicate of one waiting, tied"
    else
      branch "on_chunk: a duplicate, ignored"
    return
  if ← expired f.g then                                       -- past its lifetime or live window
    branch "on_chunk: expired"
    return
  if !(← live f.slot) then
    branch "on_chunk: not live"
    return
  let T ← NodeV2.typeOfGroup f.g
  onValidated p f (← NodeV2.verify T f (← NodeV2.headerOf T f))   -- level 1; DEFER while the gate is closed

/-- `on_holding(p, h)` (§4.3): `protocol.md` §4.3's `on_have`, with the two claims -/
def onHolding (p : Peer) (h : Have) : M2 m Unit := do
  enter "on_holding"
  let g := h.group
  if ← expired g then                                         -- past its active lifetime: ignored
    branch "on_holding: expired"
    return
  if !(← NodeV2.validHaveV2 h) then                           -- length, and indices within N once known
    penalise p
    branch "on_holding: not a valid holding"
    return
  let e := (← peerHasEntry? p g).getD {}                      -- created at p's first holding for the group
  let newly : Bits := Bits.minus h.bits e.bits                -- `h.bits & ~e.bits`
  -- `e.bits |= h.bits; e.ttl = HAVE_TTL; e.claim_all = e.claim_all or h.claim_all; e.complete = e.complete or
  -- h.complete`
  setPeerHas p g { bits := e.bits ||| h.bits, ttl := (← read).base.c.HAVE_TTL,
                   claimAll := e.claimAll || h.claimAll, complete := e.complete || h.complete }
  if h.claimAll then noteClaimCall p g                        -- (R5) it may defer a decode duty of ours
  for i in newly.toList do
    setHolders g i ((← holdersOf g i).insert p)               -- [c9] distinct live holders
    V2Later.windowRelease p g i                               -- [c14] a slot to p frees when p holds i
    if ← planned g then originAcked g i                       -- [c3, P4] a copy of i exists elsewhere (§4.7)
  branch (if newly == 0 then "on_holding: nothing new" else "on_holding: new indices")

/-- `on_offer(p, h)` (§4.3): `protocol.md` §4.4's `on_ihave` over one group's bitmap; the asks -/
def onOffer (p : Peer) (h : Have) : M2 m (List Key) := do
  enter "on_offer"
  let g := h.group
  if ← expired g then
    branch "on_offer: expired"
    return []
  if !(← NodeV2.validHaveV2 h) then                           -- held to a holding's limits: ignored, and counted
    penalise p
    branch "on_offer: not a valid holding"
    return []
  -- `now - known_at[g] < type_of_group(g).params.START_DELAY`: [D8] (R7) a secondary axis waits
  let since := (← read).base.now - (← knownAt? g).getD 0.0
  if since < (← param (← NodeV2.typeOfGroup g) "START_DELAY" (·.START_DELAY)) then
    branch "on_offer: before the start delay"
    return (← NodeV2.deferredOffers p h)                      -- recorded as offers; asked when the delay has run
  let mut candidates : List Key := []
  -- `h.bits & interest[g] & ~mine[g]`: offered, wanted, and not held
  let offered := (Bits.andI h.bits (← interestOf g)).minus (← mineBits g)
  for i in offered.toList do
    let a : Key := .want g i
    v1 (addOffer a p)                                         -- [c5] the offer table (v0.5 §6.1)
    -- `if gated(a) or not authenticable(g): continue`: [c6] stop-pull; the gate first
    if ← gated a then
      branch "on_offer: gated"
      continue
    if !(← authenticable g) then
      branch "on_offer: no gate"
      continue
    if ← v1 (tiedToRoot p a) then                             -- its copy waits for its gate
      branch "on_offer: tied"
      continue
    if ← v1 (parked p a) then                                 -- [c5] park; every announcer parked: last resort
      v1 (lastResort a)
      branch "on_offer: parked"
      continue
    if ← v1 (outstanding p a) then                            -- an ask of it to p is open
      branch "on_offer: outstanding"
      continue
    candidates := candidates ++ [a]
  let mut asks : List Key := []
  for a in ← shuffled candidates do                           -- protocol.md §6.1: one ask per index at a time
    if ← v1 (overIhaveLimits p) then
      setHeldBack (a.group, a.index) a                        -- retried at the next heartbeat (§4.8)
      branch "on_offer: held back"
    else if ← v1 (mayAsk a p) then
      asks := asks ++ [a]
      setIhaveAsked p ((← ihaveAsked p) + 1)                  -- an ask in reply to p's offers
      branch "on_offer: asked"
  return asks

end SpecTwin.V2
