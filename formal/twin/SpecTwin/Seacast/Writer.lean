import SpecTwin.Seacast.Sample
import SpecTwin.Seacast.Window

/-! # seacast.md's writer: §4.11's `next_to_send`

The twin of `next_to_send`, `seacast-lite.md` §7.2's with the chunk chosen before the room is taken. The functions it
calls come first: `queue_owed_relations` (§4.1, `Seacast/Relations.lean`), `choose` (§4.12, `Seacast/Sample.lean`),
`filter_entry` (`Seacast/Decode.lean`), `origin_written` (§4.7, `Seacast/Announce.lean`) and the window's
(`Seacast/Window.lean`). `with_owed` is `seacast-lite.md`'s, kept: it runs through `lite`. Python's meanings kept on
purpose:
- **`while True` is one turn at a time** (`turn`), at most a bound of turns, taken from what the first turn reads:
  the normal lane's length, `owed_relations[p]`'s and the owed answers' count, and two. Each turn that goes on pops
  one normal entry, and the loop adds normal entries only from the owed answers (one a turn, by `enqueue`) and the
  owed relations (a GRAFT or a PRUNE each, by `send`), neither of which grows inside the loop: `owed_relations`
  grows only in `send_relation`, and `owed_answers` only in the serving paths. The Python's loop has no bound; the
  twin's is one it can show, and a turn past it crashes with the twin's own message.
- **`and` short-circuits:** `has_room(p)` is asked only where `owed_answers[p]` holds an answer, and `wire_size` only
  for an entry with a chunk; a `need` of 0 (control) takes no room and never waits.
- **An `Entry` has no `__bool__` and no `__len__`** (toy/wire.py), nor has a chunk: `if out` is `out is not None`, and
  `out and out.chunk` is an entry with a chunk.
- **The entry in hand is a value:** read from its lane, popped (the lane written whole), filtered and returned.
- **`pop_owed_answer` and `wire_size`** are `NodeSeacast`'s questions; `has_room` and `enqueue` are the node's
  (`Node61`). `noted` asks `offers_in`.
- **The return** is `seacast-lite.md`'s `Next`: an entry, nothing (`None`), or `WAIT`. -/

namespace SpecTwin.Seacast

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeSeacast m]

/-- One turn of `next_to_send(p)` -/
def turn (p : Peer) : M2 m Turn := do
  let rels ← owedRelationsOf p                                -- read where `queue_owed_relations` reads it first
  Seacast.queueOwedRelations p                                -- JOINs, GRAFTs and PRUNEs a full queue refused (§4.1)
  -- `if owed_answers[p] and has_room(p):` an answer a full queue refused (v0.5 §4.1)
  let oa ← allOwedAnswers p
  if !oa.isEmpty then
    if ← hasRoom p then
      let f ← NodeSeacast.popOwedAnswer p                     -- `enqueue(p, Entry(chunk=pop_owed_answer(p),
      let _ ← enqueue p (.entry { chunk := some f, control := none, solicited := true }) false   -- solicited=True),
      branch "next_to_send: an owed answer enqueued"          --   urgent=False)`
  -- `if q.urgent: return noted(p, with_owed(p, q.urgent.pop(0)))`: HAVEs, acks, decode claims first
  match (← lane? p .urgent).getD [] with
  | e :: rest =>
    setLane p .urgent rest                                    -- `q.urgent.pop(0)`
    branch "next_to_send: urgent"
    return .done (match ← Seacast.noted p (← lite (withOwed p e)) with | some e => .entry e | none => .nothing)
  | [] => pure ()
  let normal := (← lane? p .normal).getD []
  let bound := normal.length + rels.length + oa.foldl (fun n (_, b) => n + b.popcount) 0 + 2
  if normal.isEmpty then                                      -- `if not q.normal:`
    let _ ← owedRow? p                                        -- `out = with_owed(p, Entry()) if owed[p] else None`
    let owed ← allOwed p
    let out ← if owed.isEmpty then pure none else lite (withOwed p QEntry.blank)
    if let some o := out then                                 -- `if out: return noted(p, out)`
      branch "next_to_send: owed offers alone"
      return .done (match ← Seacast.noted p (some o) with | some e => .entry e | none => .nothing)
    Seacast.leaveLine p                                       -- `leave_line(p); return None`: nothing to send
    branch "next_to_send: nothing"
    return .done .nothing
  let k ← Seacast.choose p                                    -- `k = choose(q)` (§4.12): its size is what the window
  let entry ← match ((← lane? p .normal).getD [])[k]? with    --   counts; `entry = q.normal[k]`
    | some e => pure e
    | none => crash "IndexError: list index out of range (next_to_send: q.normal[k])"
  -- `need = wire_size(p, entry) if entry.chunk else 0`: control takes no room
  let need ← if entry.chunk.isSome then NodeSeacast.wireSize p entry else pure 0
  if need != 0 then                                           -- `if need and not acquire_room(p, need): return WAIT`
    if !(← Seacast.acquireRoom p need) then                   -- [c14] in line, FIFO over peers; an urgent arrival
      branch "next_to_send: in line"                          --   wakes the writer, which keeps its place
      return .done .wait
  let lane := (← lane? p .normal).getD []                     -- `q.normal.pop(k)`
  if k ≥ lane.length then crash "IndexError: pop index out of range (next_to_send)"
  setLane p .normal (lane.eraseIdx k)
  let out ← Seacast.filterEntry p entry                       -- [c8, c12], and stale asks
  -- `if need and not (out and out.chunk): free_room(need)`: the chunk did not leave, the room goes back
  if need != 0 && !(out.any (·.chunk.isSome)) then Seacast.freeRoom need
  match out with
  | some o =>                                                 -- `if out:`
    if let some f := o.chunk then
      Seacast.trackInFlight p f need                          -- [c14] the room travels with the chunk
      -- §4.7: the holding at the first write
      if (← read).base.c.SOURCE_OFFERS_PUBLISH then Seacast.originWritten f   -- `if SOURCE_OFFERS == PUBLISH:`
    branch (if o.chunk.isSome then "next_to_send: a chunk" else "next_to_send: control")
    -- `return noted(p, with_owed(p, out))`: owed offers ride along
    return .done (match ← Seacast.noted p (← lite (withOwed p o)) with | some e => .entry e | none => .nothing)
  | none =>
    branch "next_to_send: nothing left of the entry, again"
    return .again bound                                       -- start again from the owed relations

/-- The turns after the first, at most `fuel` -/
def turns (p : Peer) : Nat → M2 m Next
  | 0 => crash "twin: next_to_send ran out of turns (the bound its first turn read)"
  | fuel + 1 => do
    match ← Seacast.turn p with
    | .done r => return r
    | .again _ => Seacast.turns p fuel

/-- `next_to_send(p)` (§4.11): an entry to write, nothing, or WAIT -/
def nextToSend (p : Peer) : M2 m Next := do
  enter "next_to_send"
  match ← Seacast.turn p with
  | .done r => return r
  | .again bound => Seacast.turns p bound

end SpecTwin.Seacast
