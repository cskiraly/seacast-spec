import SpecTwin.Seacast.Receive
import SpecTwin.Seacast.Serve
import SpecTwin.Sec42
import SpecTwin.Sec61

/-! # seacast.md §4.2's gate for cells: a block's cell header validated

The twin of §4.2's `on_header_validated` and of §4.5's `drop_outside`, which it calls. `drop_outside` comes first, as
each function comes after every function it calls (`Seacast/Relations.lean`'s rule).

- **`groups`** is `dict.fromkeys(cell_groups(root))`: the question's answer without repeats, in the order of each
  group's first place in it. It is read by membership three times, where its order does not show, and iterated
  once, by the groups' pass, whose calls ask questions: there its order is read from the tape (`groupsOrder`), a
  permutation of its members, which the tracer writes in `cell_groups`' order.
- **The cells that waited** are `pending[root]`'s, in the list's own order. `pending[root]` is then written with the
  rest, an empty list included, as the Python's plain assignment stores it. A twin that deleted `pending[root]` where
  the rest is empty would pass the same records: the tracer writes an empty list as no entry, so both would write
  the same entry and hold the same state (`ReplayTables.lean`'s `valueAt`).
- **`tied[root]`'s levels** are iterated in the node's order, asked as `seacast-lite.md`'s twin asks it where the Python
  iterates one of them (`Sec42.lean`): the peers at the loop's start, and each peer's groups as its turn builds the
  list of those in `groups`. The second scan, of the peers left with nothing, asks the peers' order again, every
  peer still under the root in it, since a trace logs the order wherever the Python iterates the level, though only
  deletions follow. At a root with no row both scans ask it, each an empty list. `tied.pop(root, None)` on an empty
  row is `seacast-lite.md`'s `popTiedRoot`, as `drop_stale_waits` pops it, which asks the order only where the row
  was there.
- **A tie's bits** iterate upward (`TieBits`, a bitmap). `type_of_group(g)` is asked again for `index_count`, as the
  Python calls it there, and `mine[g]` is read only where the link joined g's type (`and` short-circuits).
- **`drop_outside`'s two loops** iterate tables: `standing[g]`'s indices (`standingOrder`, a `keys` entry), each
  index's set of peers (`order`, at "drop_outside") and `want_p`'s peers (`wantPOrder`, a `keys` entry). Each list is
  built whole before its loop, as the Python builds it. A `want_p` bitmap iterates upward, and a complemented one
  raises `ValueError`, as in `drop_wants_beyond`. The lazy tables create nothing on a read, so
  `routed_standing[g][i]` with no entry reads an empty set. -/

namespace SpecTwin.Seacast

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeSeacast m]

/-- `q in routed_standing[g][i]`: an entry missing reads as an empty set, and stores nothing -/
private def routedHas (g : Group) (i : Nat) (q : Peer) : M2 m Bool := do
  return ((← routedStanding? g i).getD {}).contains q

/-- `drop_outside(g)` (§4.5): what came before the gate, tested once it opens: a standing request, and the index a
DECLARED peer's WANT added to its interest -/
def dropOutside (g : Group) : M2 m Unit := do
  enter "drop_outside"
  -- `for i in list(standing[g]):`
  let st ← allStanding g
  for i in ← NodeSeacast.standingOrder g (st.map (·.1)) do
    -- `[q for q in standing[g][i] if outside(q, g, i, q in routed_standing[g][i])]`, built whole
    let s := (← standing? g i).getD {}
    let mut out : List Peer := []
    for q in ← NodeSeacast.order "drop_outside" s.toList do
      if ← outside q g i (← routedHas g i q) then out := out ++ [q]
    for q in out do
      discardFrom standing? setStanding g i q                -- `standing[g][i].discard(q)`
      discardFrom routedStanding? setRoutedStanding g i q    -- `routed_standing[g][i].discard(q)`
      branch "drop_outside: a standing request outside, dropped"
  -- `for q in [q for q in want_p if g in want_p[q]]:`, built whole
  -- A limit: a record the Python makes can be refused. Example: the toy's `release_places` deletes a peer's last
  -- group and keeps its empty `want_p` row; the Python's loop puts that peer on the tape, the twin's tables hold no
  -- empty row, and `wantPOrder` refuses the record. No recorded cell calls the gate (`on_header_validated`, this
  -- function's one caller), and no K4 draw has such a row. Nor does the replay tell a row deleted from a row left
  -- empty: the state is compared entry by entry, (p, g), and an empty row has no entry.
  let all ← allWantPAll
  let mut qs : List Peer := []
  for q in ← NodeSeacast.wantPOrder (all.map (·.1)) do
    if ((all.lookup q).getD []).any (·.1 == g) then qs := qs ++ [q]
  for q in qs do
    -- `want_p[q][g] & ~bitmap({i for i in want_p[q][g] if outside(q, g, i, q in routed_standing[g][i])})`
    let some b ← wantP? q g | return (← crash s!"KeyError: {g} (drop_outside: want_p[q][g])")
    let some bs := b.toBits? | return (← crash "ValueError: iterating a complemented bitmap (drop_outside)")
    let mut drop : Bits := 0
    for i in bs.toList do                                     -- upward
      if ← outside q g i (← routedHas g i q) then drop := drop.set i
    setWantP q g (IBits.minus b (IBits.ofBits drop))
    branch (if drop == 0 then "drop_outside: interest kept" else "drop_outside: interest bits outside, dropped")

/-- `on_header_validated(root)` (§4.2, P2): a block's cell header, validated once: the cells' gate, as installation is
the payload's -/
def onHeaderValidated (root : Root) : M2 m Unit := do
  enter "on_header_validated"
  let groups := (← NodeSeacast.cellGroups root).eraseDups   -- `groups = dict.fromkeys(cell_groups(root))`
  -- `cells = [... if f.group in groups]`; `pending[root] = [... if f.group not in groups]`: the payload waits
  let waits ← pendingOf root
  setPending root (waits.filter fun (_, f) => !groups.contains f.g)
  for (p, f) in waits.filter fun (_, f) => groups.contains f.g do   -- the cells that waited resume level 1
    setPendingId (← lite (messageId f)) false                -- `pending_ids.discard(chunk_id(f))`
    release p f
    let T ← NodeSeacast.typeOfGroup f.g
    let result ← NodeSeacast.verify T f (← NodeSeacast.headerOf T f)   -- `T.verify(f, T.header_of(f))`
    Seacast.onValidated p f result
    branch "on_header_validated: a cell that waited resumes"
  -- `for p, held in tied[root].items():` their senders' ties for the root's cell groups release
  let rows ← allTiedRoot root
  for p in ← tiedPeersOrder root (rows.map (·.1)) do
    let held ← allTiedPeer root p
    -- `[g for g in held if g in groups]`, built whole, in the row's order
    let gs := (← tiedGroupsOrder root p (held.map (·.1))).filter groups.contains
    for g in gs do
      let some bits ← tied? root p g                          -- `bits = held.pop(g)`
        | return (← crash "KeyError: held.pop(g) (on_header_validated)")
      eraseTied root p g
      if ← expired g then
        branch "on_header_validated: a tie of an expired group"
        continue
      let _ ← parkUntil? p g                                  -- `park[p].pop(g, None)`: parks lift
      erasePark p g
      let offers ← joined p (← NodeSeacast.typeOfGroup g)     -- §2: an offer only on a link that joined g's type
      for i in bits.toList do                                 -- upward
        let done ← askedParkedOf (g, i)                       -- `asked_parked[(g, i)].discard(p)`: last-resort
        if done.contains p then                               --   counts clear
          setAskedParked (g, i) (done.erase p)
        let h ← desc g
        if h.isSome then                                      -- `if g in hdr and i >= type_of_group(g).index_count(hdr[g])`
          let n ← NodeSeacast.indexCount (← NodeSeacast.typeOfGroup g) h
          if i ≥ n then
            branch "on_header_validated: an index beyond the count learnt meanwhile"
            continue
        if !offers then                                       -- `if offers and not mine[g].has(i)`
          branch "on_header_validated: a tie on a link not joined for the type"
          continue
        if (← mineBits g).has i then
          branch "on_header_validated: a tied index held"
          continue
        lite (addOffer (.want g i) p)                         -- `add_offer(Ask(g, i), p)`: an offer again
        branch "on_header_validated: an offer again"
  -- `for p in [p for p, held in tied[root].items() if not held]:` the row's peers in the node's order, the emptied
  -- ones among the rest, built whole before the loop deletes
  let rows' ← allTiedRoot root
  let emptied := (← tiedPeersOrder root (rows'.map (·.1))).filter fun p => ((rows'.lookup p).getD []).isEmpty
  for p in emptied do
    eraseTiedPeerRow root p                                   -- `del tied[root][p]`
    let _ ← tieSlot? root p                                   -- `tie_slot.pop((root, p), None)`: its slot goes too
    eraseTieSlot root p
    branch "on_header_validated: a sender's last tie under the root gone, with its slot"
  let there ← tiedRow? root                                   -- `if not tied[root]: tied.pop(root, None)`
  if (← allTiedRoot root).isEmpty then
    let _ ← lite (popTiedRoot root)
    if there then branch "on_header_validated: the root's ties gone"
  -- `for g in groups:` every column and row group of the block, in `cell_groups`' order, read from the tape.
  -- A limit: the order is read, not computed, and any permutation of `groups` the tape gives is followed. Example: on
  -- a pass over two groups where neither drops nor retries anything, a tape with its order entry and the two
  -- groups' entries reversed together replays clean, though the Python's order is `cell_groups`'.
  for g in ← NodeSeacast.groupsOrder "on_header_validated" groups do
    dropOutside g                                             -- §4.5: the asks that came before the header
    for a in ← lite (ledger g) do                             -- offered meanwhile, or released, asked for now
      lite (retryOffer a)

end SpecTwin.Seacast
