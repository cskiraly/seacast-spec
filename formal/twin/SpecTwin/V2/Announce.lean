import SpecTwin.V2.Relations
import SpecTwin.Sec42
import SpecTwin.Sec52

/-! # protocol-v2.md's offers and holdings: §4.4, §4.2's holding, §4.7's source, §4.8 and §4.9

The twin of the functions that offer, note pushes and send holdings: §4.4's `announce`, `announce_extra`,
`fills` and `note_push`; §4.1's `join_push`, which calls `announce`; §4.2's `suppression_scope`, `holding_of`
and `send_have`; §4.7's `source_pool`, `unpush`, `candidates_for_source`, `origin_written`, `offer_at_publish`
and `origin_acked`; §4.8's `send_gossip`; and §4.9's `projected`. Each comes after every function it calls
(`V2/Relations.lean`'s rule).

- **`protocol.md`'s functions that v2 calls unchanged** run through `v1`: `have_bits` (§4.2 there), `owe`
  (§5.2) and `N` (§1). v2's functions of the same names as `protocol.md`'s (`announce`, `note_push`, `unpush`,
  `send_have`, `origin_written`, `origin_acked`, `send_gossip`, `projected`) are this namespace's, and calls
  among them name it (`V2.announce`).
- **`suppression_scope(g)` is a set the tracer proxies** (design §3.1, §3.2): the twin computes its members in
  the order `links(T)` gives them, and each caller asks the order it iterates them in, once per iteration, with
  the place named for the caller.
- **`planned` and `origin` are plain dicts** in the toy, so `planned[g][i]` and `origin[g]` raise `KeyError` on
  a missing key, as they crash here. `planned[g][i]` is read once per peer of the pool, as the comprehension
  reads it: not at all where the pool is empty. It is read as its leaf alone, as the tracer's view logs it
  (`tools/footprint.py`'s `__getitem__` logs no read of a level it passes through). **A gap on the two raises:**
  the view logs nothing where `planned[g]` is missing, and the leaf's read alone where only `[i]` is; the twin
  needs the row's read to tell the two apart, so a record that raises there fails the replay, loudly, until the
  view logs a missing level (the tracer's v2 step).
- **Questions asked twice where the Python calls twice:** `announce_extra` asks `links(T)` twice, `source_pool`
  a second time where no relation peer holds the colour, `offer_at_publish` reads `N(d)` twice, and `projected`
  asks `T.threshold(h)` twice.
- **`pushed[p][g2].clear(i2)`** on an entry that is not there leaves it out (the toy's detached `PushEntry`
  joins its map at a write that sets a bit, or its clock or its expiry), as `protocol.md`'s `unpush` does. -/

namespace SpecTwin.V2

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeV2 m]

/-- `bitmap(s)` of a list of indices -/
private def bitmapOf (is : List Nat) : Bits := is.foldl (fun b j => b ||| (1 <<< j)) 0

/-- `fills(g, i)` (§4.4, R4): every (group, index) the chunk at index i of g fills, from the ids alone -/
def fills (g : Group) (i : Nat) : M2 m (List GI) := do
  enter "fills"
  return (g, i) :: (← NodeV2.cross (← NodeV2.typeOfGroup g) g i)   -- `[(g, i)] + type_of_group(g).cross(g, i)`

/-- `note_push(p, g, i)` (§4.4): `protocol.md` §5.2's, under every group the chunk fills (R4) -/
def notePush (p : Peer) (g : Group) (i : Nat) : M2 m Unit := do
  enter "note_push"
  for (g2, i2) in ← fills g i do
    let e := (← pushedEntry? p g2).getD {}                    -- `e = pushed[p][g2]`
    let now := (← read).base.now.toBits
    let first := if e.bits == 0 then some now else e.firstPush   -- `if e.empty(): e.first_push = now`
    -- `e.set(i2); e.ttl = PUSH_TTL`
    setPushed p g2 { bits := e.bits.set i2, firstPush := first, ttl := (← read).base.c.PUSH_TTL }
    branch (if e.bits == 0 then "note_push: the first push" else "note_push: a later push")

/-- `suppression_scope(g)` (§4.2): whoever may push g's family to us, as the members the twin computed in
`links(T)`'s order; the caller asks the order it iterates them in -/
def suppressionScope (g : Group) : M2 m (List Peer) := do
  enter "suppression_scope"
  let T ← NodeV2.typeOfGroup g
  let fam ← NodeV2.family T g
  let mut out : List Peer := []
  for q in ← NodeV2.links T do                                -- `{q for q in links(T) if push_in[q][T][fam]}`
    if !(← pushInOf q T fam).isEmpty && !out.contains q then out := out ++ [q]
  return out

/-- `holding_of(g, bits)` (§4.2, §1.5): a holding, with its two claims -/
def holdingOf (g : Group) (bits : Bits) : M2 m Have := do
  enter "holding_of"
  let n ← NodeV2.indexCount (← NodeV2.typeOfGroup g) (← desc g)   -- `type_of_group(g).index_count(hdr[g])`
  if (← origin g).isSome then                                 -- [P4] a group we publish: both claims once every
    branch "holding_of: a group we publish"                   --   chunk is known to have arrived, none before
    let whole := bits.popcount ≥ n
    return { group := g, bits := bits, offer := false, claimAll := whole, complete := whole }
  -- `state[g] == DECODING or popcount(mine[g]) >= n`: `mine` is read only where the group is not decoding
  let whole ← if (← state? g) == some .decoding then pure true else do pure ((← mineBits g).popcount ≥ n)
  let done ← stopPull g
  branch "holding_of: a group we receive"
  return { group := g, bits := bits, offer := false, claimAll := whole, complete := done }

/-- `send_have(p, g)` (§4.2) [c7]: a holding, the whole bitmap, urgent -/
def sendHave (p : Peer) (g : Group) : M2 m Unit := do
  enter "send_have"
  let h ← holdingOf g (← v1 (haveBits g))                     -- `holding_of(g, have_bits(g))`
  -- `if g in origin and MERGE_HOLDINGS and merge_waiting(p, h): return`
  if (← origin g).isSome && (← read).c2.MERGE_HOLDINGS then
    if ← NodeV2.mergeWaiting p h then
      branch "send_have: merged"                              -- [P4] merged (§4.7)
      return
  let _ ← NodeV2.send p (.have h) true
  branch "send_have: sent"

/-- A call `send_have(p, g)` as the node binds the name: the node's own where its line names it as replaced, a
question (design §1.4), else the document's -/
def sendHaveCall (p : Peer) (g : Group) : M2 m Unit := do
  if (← read).base.replaced.contains "send_have" then NodeV2.sendHaveNode p g else sendHave p g

/-- `announce(p, g, bits)` (§4.4) [c3, c7]: an offer, of what p does not hold, was not pushed and wants -/
def announce (p : Peer) (g : Group) (bits : Bits) : M2 m Unit := do
  enter "announce"
  -- `bits & ~pushed[p][g] & ~peer_has[p][g].bits & interest_of_peer(p, g)`, read left to right
  let pu ← v1 (pushed p g)
  let ph ← v1 (peerHas p g)
  let b := Bits.andI ((bits.minus pu).minus ph) (← interestOfPeer p g)
  if b == 0 then                                              -- an empty bitmap is not sent
    branch "announce: nothing to offer"
    return
  let h : Have := { group := g, bits := b, offer := true, claimAll := false, complete := false }
  if ← NodeV2.send p (.have h) false then
    branch "announce: sent"
  else
    v1 (owe p g b)                                            -- refused by a full queue: owed (v0.5)
    branch "announce: refused, owed"

/-- `announce_extra(g, i)` (§4.4, [D5]): the links outside the relation that want chunk i, at forward time -/
def announceExtra (g : Group) (i : Nat) : M2 m (List Peer) := do
  enter "announce_extra"
  let T ← NodeV2.typeOfGroup g
  let fam ← NodeV2.family T g
  if (← param T "ANNOUNCE_EXTRA" (·.ANNOUNCE_EXTRA)) != .allJoined then
    branch "announce_extra: not ALL_JOINED"                   -- SAMPLE: the heartbeat's paced gossip (§4.8)
    return []
  -- `related = {q for q in links(T) if push_out[q][T][fam] or push_in[q][T][fam]}`: push_in read only where
  -- push_out is empty
  let mut related : List Peer := []
  for q in ← NodeV2.links T do
    let r ← if !(← pushOutOf q T fam).isEmpty then pure true else do pure !(← pushInOf q T fam).isEmpty
    if r then related := related ++ [q]
  -- `[q for q in links(T) if q not in related and wants_from_me(q, g).has(i)]`: links(T) asked again
  let out ← (← NodeV2.links T).filterM fun q => do
    if related.contains q then return false
    return (← wantsFromMe q g).has i
  branch "announce_extra: ALL_JOINED"
  return out

/-- `join_push(p, T, fam, c)` (§4.1): p joins our push relation for colour c: what we hold of it is announced
(`protocol.md` §5.4's `on_mesh_join`); a GRAFT that adds nothing runs nothing -/
def joinPush (p : Peer) (T : TypeId) (fam : Fam) (c : Nat) : M2 m Unit := do
  enter "join_push"
  let s ← pushOutOf p T fam
  if s.contains c then                                        -- `if c in push_out[p][T][fam]: return`
    branch "join_push: in the relation already"
    return
  setPushOut p T fam (s.insert c)                             -- `push_out[p][T][fam].add(c)`
  for g in ← chunksGroups do                                  -- `for g in list(chunks):`
    -- `expired(g) or state[g] == INVALID or type_of_group(g) != T or T.family(g) != fam`, left to right
    if ← expired g then
      branch "join_push: an expired group"
      continue
    if (← state? g) == some .invalid then
      branch "join_push: a dropped group"
      continue
    if (← NodeV2.typeOfGroup g) != T then
      branch "join_push: another type"
      continue
    if (← NodeV2.family T g) != fam then
      branch "join_push: another family"
      continue
    -- `bitmap({i for i in chunks[g] if colour_of(g, i) == c})`
    let is ← (← chunkIndices g).filterM fun i => do return (← colourOf g i) == c
    V2.announce p g (bitmapOf is)
    branch "join_push: a group offered"

/-- `source_pool(T, g, c)` (§4.7): whom a source pushes below `STRIPE_UPLINK`, and offers to: the relation
peers of colour c, or the links where there are none -/
def sourcePool (T : TypeId) (g : Group) (c : Nat) : M2 m (List Peer) := do
  enter "source_pool"
  let fam ← NodeV2.family T g
  let rel ← (← NodeV2.links T).filterM fun q => do return (← pushOutOf q T fam).contains c
  if !rel.isEmpty then
    branch "source_pool: the relation"
    return rel
  branch "source_pool: the links"
  NodeV2.links T                                              -- `rel or links(T)`: asked again

/-- `unpush(p, g, i)` (§4.7) [c3]: a chosen push that will not be made: not counted, under every group
`note_push` marked, and owed to a relation peer, or at a source to a peer of the pool as it stands now -/
def unpush (p : Peer) (g : Group) (i : Nat) : M2 m Unit := do
  enter "unpush"
  for (g2, i2) in ← fills g i do
    match ← pushedEntry? p g2 with                            -- `pushed[p][g2].clear(i2)`
    | some e => setPushed p g2 { e with bits := e.bits.clear i2 }
    | none => branch "unpush: nothing pushed"                 -- a missing entry stays missing
  -- `p in mesh or (g in origin and p in source_pool(type_of_group(g), g, colour_of(g, i)))`, left to right
  let owes ← if ← meshHas p then pure true else do
    let o ← origin g                                          -- read only where p is not in the mesh
    if o.isNone then pure false else do
      let T ← NodeV2.typeOfGroup g
      let c ← colourOf g i
      pure ((← sourcePool T g c).contains p)
  if owes then
    v1 (owe p g (1 <<< i))
    branch "unpush: owed"
  else
    branch "unpush: not owed"

/-- `candidates_for_source(f)` (§4.7): whom a source may push chunk f to -/
def candidatesForSource (f : ChunkF) : M2 m (List Peer) := do
  enter "candidates_for_source"
  let T ← NodeV2.typeOfGroup f.g
  let g := f.g
  let _fam ← NodeV2.family T g                                -- `fam = T.family(g)`: asked, not used
  let c ← colourOf g f.i
  let cfg := (← read).base.c
  let pool ← if cfg.UPLINK ≥ cfg.STRIPE_UPLINK then do        -- [c13] every link
      branch "candidates_for_source: every link"
      NodeV2.links T
    else do                                                   -- the relation, as the other nodes do
      branch "candidates_for_source: the pool"
      sourcePool T g c
  pool.filterM fun q => do return (← wantsFromMe q g).has f.i

/-- `origin_written(f)` (§4.7): at `SOURCE_OFFERS = PUBLISH`, a chunk of a group we publish leaves for the first
time; it joins our holding, which goes where `origin_acked`'s goes (§4.2) -/
def originWritten (f : ChunkF) : M2 m Unit := do
  enter "origin_written"
  let g := f.g
  match ← origin g with                                       -- `if g not in origin or origin[g].has(f.index)`
  | none => branch "origin_written: not a group we publish"
  | some b =>
    if b.has f.i then
      branch "origin_written: in our holding already"
    else
      setOrigin g (b.set f.i)                                 -- `origin[g].set(f.index)`
      for q in ← NodeV2.order "origin_written" (← suppressionScope g) do
        sendHaveCall q g
      branch "origin_written: the holding grows"

/-- `offer_at_publish(g, d)` (§4.7): a pull-only type's source pushes nothing, so every chunk is offered at once
to the peers `origin_acked` would offer it to, and our holding names every chunk -/
def offerAtPublish (g : Group) (d : Descriptor) : M2 m Unit := do
  enter "offer_at_publish"
  setOrigin g ((1 <<< (← v1 (N (some d)))) - 1)              -- `origin[g] = all_bits(N(d))`
  for q in ← NodeV2.order "offer_at_publish" (← suppressionScope g) do
    sendHaveCall q g
  let T ← NodeV2.typeOfGroup g
  -- `offers.setdefault(q, set()).add(i)`: a dict, in the order its keys were first set
  let mut offers : List (Peer × Bits) := []
  for i in List.range (← v1 (N (some d))) do                  -- `range(N(d))`: N read again
    for q in ← sourcePool T g (← colourOf g i) do
      offers := if offers.any (·.1 == q) then offers.map fun (x, b) => if x == q then (x, b.set i) else (x, b)
                else offers ++ [(q, (0 : Bits).set i)]
  for (q, idx) in offers do
    V2.announce q g idx
  branch "offer_at_publish: offered"

/-- `origin_acked(g, i)` (§4.7) [c3, P4]: a chunk of a group we publish is acknowledged; it joins our holding,
and the pool's peers not chosen to be pushed it are offered it -/
def originAcked (g : Group) (i : Nat) : M2 m Unit := do
  enter "origin_acked"
  if (← read).base.c.SOURCE_OFFERS_PUBLISH then               -- `if SOURCE_OFFERS == PUBLISH: return`
    branch "origin_acked: at PUBLISH, nothing"
    return
  let some b ← origin g | crash s!"KeyError: {g} (origin_acked: origin[g])"
  if b.has i then                                             -- `if origin[g].has(i): return`
    branch "origin_acked: acknowledged before"
    return
  setOrigin g (b.set i)                                       -- `origin[g].set(i)`
  for q in ← NodeV2.order "origin_acked" (← suppressionScope g) do
    sendHaveCall q g
  let T ← NodeV2.typeOfGroup g
  let _fam ← NodeV2.family T g                                -- `fam = T.family(g)`: asked, not used
  let c ← colourOf g i
  -- `[q for q in source_pool(T, g, c) if q not in planned[g][i]]`: planned[g][i] read once per peer
  let ps ← (← sourcePool T g c).filterM fun q => do
    match ← plannedTargets? g i with                          -- the leaf alone, as the tracer's view logs it
    | some ts => return !ts.contains q
    | none =>                                                 -- (the raises' reads: a gap, in the header)
      if !(← planned g) then return (← crash s!"KeyError: {g} (origin_acked: planned[g])")
      return (← crash s!"KeyError: {i} (origin_acked: planned[g][i])")
  for p in ps do
    V2.announce p g (1 <<< i)                                 -- a refused push is owed (v0.7)
  branch "origin_acked: the holding grows"

/-- `send_gossip(q, ids)` (§4.8) [c7]: offers per group, for the types whose `ANNOUNCE_EXTRA` is `SAMPLE` -/
def sendGossip (q : Peer) (ids : List Key) : M2 m Unit := do
  enter "send_gossip"
  for (g, bits) in ← groupBits ids do                         -- `for g, bits in group_bits(ids):`
    if (← param (← NodeV2.typeOfGroup g) "ANNOUNCE_EXTRA" (·.ANNOUNCE_EXTRA)) == .sample then
      V2.announce q g bits                                    -- [D5] ALL_JOINED offered at forward time already
      branch "send_gossip: offered"
    else
      branch "send_gossip: not SAMPLE"

/-- `projected(p, g)` (§4.9) [c12]: `protocol.md` §7.2's, read per object type -/
def projected (p : Peer) (g : Group) : M2 m Bool := do
  enter "projected"
  let T ← NodeV2.typeOfGroup g                                -- `T, h = type_of_group(g), hdr[g]`
  let h ← desc g
  if (← NodeV2.threshold T h) == (← NodeV2.indexCount T h) then
    branch "projected: no code"                               -- every index is needed: nothing is projected
    return false
  let has ← v1 (peerHas p g)                                  -- `has, sent = peer_has[p][g].bits, sent_to[p][g]`
  let sent ← sentToBits p g
  let r := has.popcount + (← read).base.c.FAN_IN * (sent.minus has).popcount ≥ (← NodeV2.threshold T h)
  branch (if r then "projected: the threshold reached without us" else "projected: not yet")
  return r

end SpecTwin.V2
