import SpecTwin.Seacast.Gate
import SpecTwin.Seacast.Kept
import SpecTwin.Seacast.Upkeep
import SpecTwin.Sec64

/-! # seacast.md's roots: §4's `on_frame`, §4.8's `on_heartbeat` and §4.7's `publish`

The three functions a node's events enter: a frame from a peer, the heartbeat, and a block of its own to publish. Each
comes after every function it calls (`Seacast/Relations.lean`'s rule).

- **`on_frame(p, frame)`** takes the frame as the binding hands it over: its chunks, holdings and offers, asks, GRAFTs
  and PRUNEs, each in the frame's order (`FrameSeacast`). An offer is a have whose `offer` is true and whose link
  joined its group's type: `type_of_group(h.group)` is asked and `joined` runs only for a have whose `offer` is true,
  as `and` short-circuits, and a holding asks neither. The second pass over the haves hands `on_holding` each have
  whose `offer` is false, so an offer on a link not joined for its type reaches neither handler. The response is
  `respond`'s v2 form (`Seacast/Kept.lean`), with no PRUNE.
- **`on_want` can be replaced** by a binding of the node's own: where the node's line names it, the frame's asks are
  handed to the node (`onWantNode`) and its answers are the ones it returns (`onWantCall`).
- **`on_heartbeat()`** clears four tables, each a write of every entry there and no read: `ihave_frames`,
  `ihave_asked`, `held_back` and `served_hb`. `held_back.values()` reads the table as a whole, in the node's order
  (`heldBackOrder`), as `seacast-lite.md`'s twin reads it (`Sec64.lean`). `joined_types()` is asked twice, as the
  Python calls it twice, and the twin does not take the two answers to be equal. `related(q)` is asked of every
  joined peer, and `gossip_eligible(q)` of the unrelated ones alone. The gossip count is `seacast-lite.md`'s
  (`gossipCount`, floats as the Python's).
- **`publish(block, d, shards)`** asks `group_of(block, d)` for the group, and `open_group_source(g, d)` writes what
  opens it (its row on the tape). The chunks are built as `seacast-lite.md`'s twin builds them (`Sec51.lean`): wide,
  with no id until `chunk_id(f)` gives one, and `block_root(block)` asked once per shard, as the Python evaluates it
  inside the loop. `N(d)` is `seacast-lite.md`'s, read twice, as the Python reads it twice. `origin[g]` is read once
  per peer's first chunk, as the Python reads it there. The pool of the offers at publish is `source_pool`'s list, in
  its order.

Limits, named, as `seacast-lite.md`'s `publish` has them (`Sec51.lean`): a descriptor of no chunk (the twin stops at
once, before any question); a descriptor that counts more chunks than the shards give (`chunks[g][i]` a KeyError, which
no record writes). -/

namespace SpecTwin.Seacast

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeSeacast m]

/-- A frame (§4; `seacast-bindings.md` §0): the messages one binding's unit carries, by kind, each in the frame's
order -/
structure FrameSeacast where
  chunks : List ChunkF
  haves : List Have
  asks : List AskSeacast
  grafts : List Graft
  prunes : List Prune
  deriving BEq, Repr, Inhabited

/-- A call `on_want(p, asks)` as the node binds the name -/
def onWantCall (p : Peer) (asks : List AskSeacast) : M2 m (List ChunkF) := do
  if (← read).base.replaced.contains "on_want" then NodeSeacast.onWantNode p asks else Seacast.onWant p asks

/-- `on_frame(p, frame)` (§4): one frame from p, in `seacast-lite.md`'s order: chunks, offers, asks, GRAFT and PRUNE,
holdings, then the response -/
def onFrame (p : Peer) (frame : FrameSeacast) : M2 m Unit := do
  enter "on_frame"
  for f in frame.chunks do Seacast.onChunk p f                 -- §2: chunks and holdings on any link
  -- `offers = [h for h in frame.haves if h.offer and joined(p, type_of_group(h.group))]`
  let mut offers : List Have := []
  for h in frame.haves do
    if h.offer then
      if ← joined p (← NodeSeacast.typeOfGroup h.group) then offers := offers ++ [h]
      else branch "on_frame: an offer on a link not joined for its type, ignored"
  if !offers.isEmpty then                                      -- `if offers: ihave_frames[p] += 1`
    setIhaveFrames p ((← ihaveFrames p) + 1)
    branch "on_frame: an offer-bearing frame"
  let mut asks : List Key := []                                -- `[a for h in offers for a in on_offer(p, h)]`
  for h in offers do asks := asks ++ (← Seacast.onOffer p h)
  let answers ← onWantCall p frame.asks                        -- `answers = on_want(p, frame.asks)` (§4.5)
  for gr in frame.grafts do Seacast.onGraft p gr               -- §4.1: it sends its own answers
  for pr in frame.prunes do Seacast.onPrune p pr
  for h in frame.haves do                                      -- `if not h.offer: on_holding(p, h)` (§4.3)
    if !h.offer then Seacast.onHolding p h
  Seacast.respond p asks answers 0                             -- `respond(p, asks, answers, [])`

/-- `on_heartbeat()` (§4.8) -/
def onHeartbeat : M2 m Unit := do
  enter "on_heartbeat"
  clearIhaveFrames; clearIhaveAsked                            -- §4.3's limits start again,
  let held ← allHeldBack                                       -- `for a in held_back.values(): retry_offer(a)`
  for k in ← heldBackOrder (held.map (·.1)) do
    match held.lookup k with
    | some a =>
      lite (retryOffer a)                                      --   the retry runs for what they held back,
      branch "on_heartbeat: a held-back offer retried"
    | none => crash "KeyError: held_back (on_heartbeat: the node's order names a chunk the table has not)"
  clearHeldBack                                                --   which they do not count
  clearServedHb                                                -- §4.5's serving budget starts again
  NodeSeacast.releaseWantedGroups                              -- §4.5: the places of unknown groups named in WANTs
  lite dropStaleWaits                                          -- seacast-lite.md §4.2: copies and ties past their window
  let ids ← gossipIds                                          -- stock: ids of the last 3 heartbeats
  for T in ← NodeSeacast.joinedTypes do keepFloor T            -- §4.1, links for the floor per family
  for T in ← NodeSeacast.joinedTypes do maintainRelations T    -- §4.1: asked again, as the Python calls it again
  for T in ← NodeSeacast.sampledTypes do keepCoverage T        -- §4.1, the coverage floor [D12]
  -- `[q for q in joined_peers() if not related(q) and gossip_eligible(q)]` (stock: scores)
  let mut eligible : List Peer := []
  for q in ← NodeSeacast.joinedPeers do
    if ← NodeSeacast.related q then
      branch "on_heartbeat: a related peer, no gossip"
    else if ← gossipEligible q then
      eligible := eligible ++ [q]
    else
      branch "on_heartbeat: a peer not eligible for gossip"
  let n ← lite (gossipCount eligible.length)
  let ctx := (← read).base
  for q in ← Node61.sample eligible n do                              -- `for q in sample_without_replacement(eligible, n):`
    if ctx.c.PACED then                                        -- [c15] `pace_queue.append((q, ids, now))`
      setPaceJobs .jobs ((← paceJobs .jobs) ++ [{ q, ids, at_ := ctx.now.toBits }])
    else Seacast.sendGossip q ids
  branch (if ctx.c.PACED then "on_heartbeat: gossip paced" else "on_heartbeat: gossip sent at once")

/-- `publish(block, d, shards)` (§4.7): the payload's builder, `seacast-lite.md` §5.1 over the relation. It holds every
chunk from the start; a pull-only type pushes nothing and offers every chunk at once; otherwise it plans R copies of
each chunk, sends the first copy of every chunk before any second, and leaves the pool's peers not pushed a chunk to
be offered it (at its acknowledgement, or now at `PUBLISH`). -/
def publish (block : Block) (d : Descriptor) (shards : List Shard) : M2 m Unit := do
  enter "publish"
  let c := (← read).base.c
  if d.count == 0 then
    return (← crash "limit: publish of a descriptor of no chunk (planned[g] an empty row, which the twin's table does not hold)")
  let g ← NodeSeacast.groupOf block d                          -- `g = group_of(block, d)`
  if ← expired g then                                          -- `if expired(g) or not live(block.slot): return`
    branch "publish: the group expired"
    return
  if !(← live block.slot) then
    branch "publish: past its live window"
    return
  NodeSeacast.releaseWantedGroups                              -- §4.5: a place that ran out goes before its group opens
  NodeSeacast.openGroupSource g d                              -- hdr[g] = d; T_of, interest, known_at
  dropWantsBeyond g                                            -- §4.5: its count is known now
  let T ← NodeSeacast.typeOfGroup g
  for s in shards do                                           -- the source holds every chunk from the start
    let f : ChunkF :=                                          -- `Chunk(slot=…, beacon_block_root=block_root(block), …)`
      { g, i := s.index, slot := block.slot, root := ← blockRoot block, mid := .want g s.index,
        wide := some { desc := some d, proof := s.proof, data := s.data } }
    store g s.index f                                          -- `store(g, s.index, f)`
    let a ← lite (messageId f)                                 -- `mark_seen(chunk_id(f))`
    markSeen a
    gossipPut { f with mid := a }                              -- `gossip_history.put(f)` (§4.8)
  setMine g ((1 <<< (← lite (N (some d)))) - 1)                -- `mine[g] = all_bits(N(d))`
  setState g .complete                                         -- `state[g] = COMPLETE`
  setStopPull g true                                           -- `stop_pull[g] = True`
  for s in shards do serveStandingCall g s.index               -- §4.10: WANTs that came before the chunks
  if !(← param T "EAGER" (·.EAGER)) then                       -- `if not T.params.EAGER: return offer_at_publish(g, d)`
    offerAtPublish g d
    branch "publish: a pull-only type, offered at publish"
    return
  setOrigin g 0                                                -- `origin[g] = bitmap(set())` [P4]: none yet
  let mut plan : Array (ChunkF × List Peer) := #[]
  for i in List.range (← lite (N (some d))) do                 -- index order; each chunk's targets see earlier plans
    let f ← chunkAt g i                                        -- `f = chunks[g][i]`
    let targets ← lite (choosePush f (← Seacast.candidatesForSource f) c.R true)   -- seacast-lite.md §5.3
    for p in targets do Seacast.notePush p g i
    plan := plan.push (f, targets)
  let mut led : List Peer := []
  for copy in List.range c.R do                                -- the first copy of every chunk before any second [c2]
    for (f, targets) in plan do
      if let some p := targets[copy]? then                     -- `if copy < len(targets): p = targets[copy]`
        if !led.contains p then                                -- [P4] a peer's first chunk from us follows our
          led := p :: led                                      --   holding naming it
          let some o ← origin g
            | crash "KeyError: origin[g] (publish: written above)"
          -- `send(p, holding_of(g, origin[g] | bitmap({f.index})), urgent=True)`
          let _ ← NodeSeacast.send p (.have (← holdingOf g (o ||| (1 <<< f.i)))) true
        if !(← enqueue p (.chunk f) false) then                -- refused: offered instead
          Seacast.unpush p g f.i
          branch "publish: a push refused, unpushed"
  erasePlannedRow g                                            -- `planned[g] = {f.index: set(targets) for …}`: the
  for (f, targets) in plan do                                  --   row assigned whole [c3]
    setPlanned g f.i (Std.HashSet.ofList targets)
  if c.SOURCE_OFFERS_PUBLISH then                              -- `if SOURCE_OFFERS == PUBLISH:` those offers now
    for (f, targets) in plan do
      for p in ← sourcePool T g (← colourOf g f.i) do          -- `source_pool(T, g, colour_of(g, f.index))`
        if !targets.contains p then
          Seacast.announce p g (1 <<< f.i)                     -- `announce(p, g, bitmap({f.index}))`
          branch "publish: an offer at publish"

end SpecTwin.Seacast
