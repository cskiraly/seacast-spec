import SpecTwin.Seacast.Announce
import SpecTwin.Seacast.Receive
import SpecTwin.Sec41
import SpecTwin.Sec42
import SpecTwin.Sec61
import SpecTwin.Sec64

/-! # seacast-lite.md's functions that v2 keeps, in the forms they take under v2

The Python binds a name when it calls it, so under seacast.md `on_pace_tick` sends SEACAST's gossip and
`on_block_installed` validates with SEACAST's `on_validated`. The twin binds a name when the function is defined, so
each of the two has a copy here, in `M2`, that calls SEACAST's. `respond` calls nothing v2 redefines, but the IWANT it
builds is one a record under v2 writes in SEACAST's form: the toy has one IWANT class, and a lane's IWANT under v2 is
`.iwantSeacast`, so its copy builds that constructor. Each copy is its original's text (`Sec64.lean`'s `paceTurns` and
`onPaceTick`, `Sec42.lean`'s `onBlockInstalled`, `Sec41.lean`'s `respond`) with these differences alone, to which
`tools/keptcopy.py` holds it:

- The monad is `M2 m`, and `paceTurns` takes seacast-lite.md's context as `(← read).base`.
- A function of seacast-lite.md's Lean runs through `v1`. The node's questions and the tables are called as they are.
- A call that the Python binds late names SEACAST's function: `Seacast.sendGossip`, `Seacast.paceTurns` and `Seacast.onValidated`.
  SEACAST's `on_validated` takes no fuel, since it does not recurse through `defer`.
- The no-bid branch of `on_block_installed` is reached under v2, for a block of columns. There the Python calls
  `ledger(None)`: it enters `ledger`, asks the connected topic peers, and reads `offered[q][None]` for each,
  which the tracer does not write. No table holds a group of `None`, so the call returns no ask. The copy enters
  `ledger` and asks the peers.
- `respond`'s IWANT is `.iwantSeacast false`, its asks plain, where the original builds `.iwant`. -/

namespace SpecTwin.Seacast

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeSeacast m] [SeacastLater m]

/-- The turns of `on_pace_tick`'s loop under v2, at most `fuel`: seacast-lite.md's, with SEACAST's `send_gossip`. -/
def paceTurns : Nat → M2 m Unit
  | 0 => do
    if (← paceJobs .jobs).isEmpty then branch "on_pace_tick: the queue ran out"
    else crash "RecursionError: on_pace_tick (more turns than the jobs at entry: L1)"
  | fuel + 1 => do
    match ← paceJobs .jobs with                             -- `while pace_queue:`
    | [] => branch "on_pace_tick: the queue ran out"
    | job :: rest =>
      setPaceJobs .jobs rest                                -- `q, ids, at = pace_queue.pop(0)`
      let ctx := (← read).base
      if ctx.now - Float.ofBits job.at_ ≥ ctx.c.HEARTBEAT then   -- stale
        branch "on_pace_tick: a stale job dropped"
        paceTurns fuel
      else if !(← connected job.q) then                     -- or q has left
        branch "on_pace_tick: the job of a peer that left dropped"
        paceTurns fuel
      else
        Seacast.sendGossip job.q job.ids
        branch "on_pace_tick: one job's gossip sent"        -- one peer per tick, even if nothing was left to send

/-- `on_pace_tick()` under v2: seacast-lite.md's, with SEACAST's turns -/
def onPaceTick : M2 m Unit := do
  enter "on_pace_tick"
  Seacast.paceTurns (← paceJobs .jobs).length

/-- `on_block_installed(root)` under v2: seacast-lite.md's, with SEACAST's `on_validated`, and its no-bid branch entering `ledger` -/
def onBlockInstalled (root : Root) : M2 m Unit := do
  enter "on_block_installed"
  let waits ← pendingOf root                                -- `for p, f in pending.pop(root, []):`, in the list's
  erasePending root                                         --   own order
  for (p, f) in waits do
    setPendingId (← v1 (messageId f)) false                      -- `pending_ids.discard(message_id(f))`
    release p f                                             -- the reservation goes back
    Seacast.onValidated p f (← v1 (validateChunk f))          -- `on_validated(p, f, validate_chunk(f))`
  let g0 ← bidGroup root                                    -- the group this root's bid commits
  for (p, groups) in ← v1 (popTiedRoot root) do                  -- `for p, groups in tied.pop(root, {}).items():` the
    let _ ← tieSlot? root p                                 --   copies that waited for this root;
    eraseTieSlot root p                                     --   `tie_slot.pop((root, p), None)`
    for (g, bits) in groups do                              -- `for g, bits in groups.items():`
      if ← expired g then                                   -- its offers went with its lifetime (§8.1)
        branch "on_block_installed: a tie of an expired group"
        continue
      if g0 != some g then                                  -- a copy naming a group its root does not commit
        v1 (dropTie p g bits)                                    --   is a forgery: nothing is released
        branch "on_block_installed: a tie of another group, dropped"
        continue
      let _ ← parkUntil? p g                                -- `park[p].pop(g, None)`: the senders' parks for the
      erasePark p g                                         --   group lift,
      for i in bits.toList do
        let done ← askedParkedOf (g, i)                     -- `asked_parked[(g, i)].discard(p)`: the last-resort counts for
        if done.contains p then                             --   their indices clear,
          setAskedParked (g, i) (done.erase p)
        if (← desc g).isSome then                           -- `if g in desc and i >= N(desc[g]): continue`: an
          let n ← v1 (N (← desc g))                              --   index the group, known now, has not is dropped
                                                            --   (§8.2), the others kept,
          if i ≥ n then
            branch "on_block_installed: an index beyond the count learnt meanwhile"
            continue
        if !(← mineBits g).has i then                       --   and each is an offer of its index again
          v1 (addOffer (.want g i) p)
      branch "on_block_installed: a tie released"
  match g0 with                                             -- `for a in ledger(g0): retry_offer(a)`: what was
  | some g0 =>                                              --   announced meanwhile (§4.4), and what the ties
    for a in ← v1 (ledger g0) do                                 --   released, is asked for now
      v1 (retryOffer a)
  | none =>                                                 -- a block of columns, reached under v2: the Python's
    enter "ledger"                                          --   `ledger(None)` is entered, asks the peers, and
    let _ ← connectedTopicPeers                             --   reads `offered[q][None]`, which the tracer does
    branch "on_block_installed: no group committed"         --   not write; no table holds a group of None, so
                                                            --   it returns no ask

/-- `respond(p, asks, answers, prunes)` under v2: seacast-lite.md's, its IWANT in SEACAST's form -/
def respond (p : Peer) (asks : List Key) (answers : List ChunkF) (prunes : Nat) : M2 m Unit := do
  enter "respond"
  -- `control = IWANT(asks) + PRUNE(prunes) if asks or prunes else None`: an empty part is left out by the queue
  let control : Option (List Ctl) :=
    if !asks.isEmpty || prunes > 0 then some [.iwantSeacast false (asks.map fun k => { key := k }), .prune] else none
  if answers.isEmpty then
    if control.isSome then
      let _ ← enqueue p (.entry { chunk := none, control, solicited := false }) false
      branch "respond: control alone"
    else branch "respond: nothing to ask, answer or prune"
    return
  let mut first := true
  for f in answers do                                       -- one chunk per entry; the control rides on the first
    let e : QEntry := { chunk := some f, control := if first then control else none, solicited := true }
    first := false
    if !(← enqueue p (.entry e) false) then                 -- refused by a full queue: owed, and queued once
      setOwedAnswers p f.g ((← owedAnswerBits p f.g).set f.i)    --   there is room (§7.2)
      branch "respond: an answer refused, owed"
  branch "respond: answers"

end SpecTwin.Seacast
