import SpecTwin.Seacast.Announce
import SpecTwin.Sec71

/-! # seacast.md's window, in bytes: §4.11

The twin of §4.11's `wake_front`, `write_waits`, `free_room`, `acquire_room`, `leave_line`, `track_in_flight`,
`window_release`, `window_timeout` and `noted`. Each comes after every function it calls (`Seacast/Relations.lean`'s
rule). `next_to_send` is `Seacast/Writer.lean`'s.

- **The window's tables are the twin's own:** `in_flight`, a signed count of bytes in one entry (`free_room` can take
  it below 0 on a drawn state, as `seacast-lite.md`'s `free_slot` can); `waiters`, the line, one entry, the peers in
  order, the same table as `seacast-lite.md`'s; `sent`, the send's time and its bytes under the key (peer, group,
  index), this document's form of the table (`sentSeacast`).
- **`W_BYTES`** is `ConstsSeacast`'s, none where the window is off (card 14 off: the toy's `math.inf`). Where it is
  none, `in_flight >= W_BYTES` is false and `in_flight + need <= W_BYTES` is true.
- **`front` is `seacast-lite.md` §7.1's**, which seacast.md calls unchanged: it runs through `lite`, and asks
  `writing` of each writer in line up to the first that can write.
- **Reads as the Python's.** A count or a line read twice in the Python is read once here: a record's reads are a
  set. `acquire_room` reads `in_flight` once, and nothing between that read and `in_flight += need` writes it.
  Python's `and` short-circuits, so `acquire_room` asks `front` only where the chunk fits.
- **`sent.pop(key, None)`** and `sent.get(key)` read the entry; the entry is written (erased) only where it is
  there, as `seacast-lite.md`'s `window_release` has it.
- **Calls:** `wake` (the node's writer), `writing` (through `front`), `after` (the window's timer, `seacast-lite.md`'s
  `window_timeout` target with the send's key and time) and `offers_in` (§3's helper: the offers an entry carries,
  `NodeSeacast`'s). `origin_acked` is SEACAST's own (`Seacast/Announce.lean`). -/

namespace SpecTwin.Seacast

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeSeacast m]

/-- `in_flight >= W_BYTES`: no room left. Never where the window is off (`W_BYTES` none, the toy's `inf`). -/
def noRoom (n : Int) : M2 m Bool := do
  match (← read).c2.W_BYTES with
  | none => return false
  | some w => return n ≥ (w : Int)

/-- `wake_front()` (§4.11): room is free, so the first in line that can write tries again -/
def wakeFront : M2 m Unit := do
  enter "wake_front"
  if ← noRoom (← inFlight .count) then                       -- `if in_flight >= W_BYTES: return`
    branch "wake_front: no room"
    return
  match ← lite front with                                     -- `q = front()`
  | some q => wake q                                          -- `if q is not None: wake(q)`
  | none => branch "wake_front: nobody in line can write"

/-- `write_waits(p)` (§4.11): p's write has not completed, so the line skips p, and the first writer in line that
can write tries again, if room is free -/
def writeWaits (p : Peer) : M2 m Unit := do
  enter "write_waits"
  if (← waitersLine .line).contains p then                    -- `if p in waiters: wake_front()`
    Seacast.wakeFront
  else branch "write_waits: not in line"

/-- `free_room(need)` (§4.11) -/
def freeRoom (need : Nat) : M2 m Unit := do
  enter "free_room"
  setInFlight .count ((← inFlight .count) - need)             -- `in_flight -= need`
  Seacast.wakeFront                                           -- the first writer in line that can write tries again

/-- `acquire_room(p, need)` (§4.11): true, p's writer may send `need` bytes now; false, it waits in line -/
def acquireRoom (p : Peer) (need : Nat) : M2 m Bool := do
  enter "acquire_room"
  let n ← inFlight .count                                     -- read once: the Python reads `in_flight` again after
                                                              --   `front()`: the same unless `writing` writes it
  let under := match (← read).c2.W_BYTES with                 -- `in_flight + need <= W_BYTES`
    | none => true
    | some w => n + need ≤ (w : Int)
  let fits := under || n == 0                                 -- `or in_flight == 0`: an empty window always takes one
  if !under && n == 0 then branch "acquire_room: an empty window, over W_BYTES"    --   chunk
  let takes ← if fits then do                                 -- `fits and front() in (None, p)`: no writer that can
      let q ← lite front                                      --   write is ahead of p (front asked where it fits
      pure (q == none || q == some p)                         --   alone)
    else pure false
  if takes then
    let line ← waitersLine .line
    if line.contains p then setWaitersLine .line (line.erase p)    -- `if p in waiters: waiters.remove(p)`
    setInFlight .count (n + need)                             -- `in_flight += need`
    Seacast.wakeFront                                         -- room remains: the next in line tries too
    branch "acquire_room: room"
    return true
  let line ← waitersLine .line
  if !line.contains p then setWaitersLine .line (line ++ [p])   -- a writer keeps its place while it waits
  branch "acquire_room: in line"
  return false

/-- `leave_line(p)` (§4.11): p's writer has nothing to send now -/
def leaveLine (p : Peer) : M2 m Unit := do
  enter "leave_line"
  let line ← waitersLine .line
  if line.contains p then                                     -- `if p in waiters:`
    setWaitersLine .line (line.erase p)                       -- `waiters.remove(p)`
    Seacast.wakeFront
    branch "leave_line: left the line"
  else branch "leave_line: not in line"

/-- `track_in_flight(p, f, need)` (§4.11): the room now travels with chunk f -/
def trackInFlight (p : Peer) (f : ChunkF) (need : Nat) : M2 m Unit := do
  enter "track_in_flight"
  let k : SendKey := (p, f.g, f.i)                            -- `key = (p, f.group, f.index)`
  if (← sentSeacast? k).isSome then                           -- `if key in sent: return free_room(need)`: a second
    Seacast.freeRoom need                                     --   copy still in flight: back at once
    branch "track_in_flight: a second copy"
    return
  let now := (← read).base.now
  setSentSeacast k (now, need)                                -- `sent[key] = (now, need)`
  after (← read).base.c.WINDOW_TIMEOUT (.windowTimeout k now)   -- `after(WINDOW_TIMEOUT, window_timeout, key, now)`

/-- `window_release(p, g, i)` (§4.11): p holds chunk i, from anyone (§4.3) -/
def windowRelease (p : Peer) (g : Group) (i : Nat) : M2 m Unit := do
  enter "window_release"
  let k : SendKey := (p, g, i)
  match ← sentSeacast? k with                                 -- `e = sent.pop((p, g, i), None)`
  | some (_, need) =>
    eraseSentSeacast k
    Seacast.freeRoom need                                     -- `if e is not None: free_room(e[1])`
    branch "window_release: a send released"
  | none => branch "window_release: nothing in flight"

/-- `window_timeout(key, at)` (§4.11) -/
def windowTimeout (k : SendKey) (at_ : Float) : M2 m Unit := do
  enter "window_timeout"
  match ← sentSeacast? k with                                 -- `e = sent.get(key)`
  | some (t, need) =>
    if t == at_ then                                          -- `if e is not None and e[0] == at:`
      eraseSentSeacast k                                      -- `del sent[key]`
      Seacast.freeRoom need                                   -- `free_room(e[1])`
      -- [c3, P4] no holding came in time: released anyway (§4.7)
      if ← planned k.2.1 then Seacast.originAcked k.2.1 k.2.2   -- `if key[1] in planned: origin_acked(key[1], key[2])`
      branch "window_timeout: released"
    else branch "window_timeout: stale"
  | none => branch "window_timeout: nothing in flight"

/-- `noted(p, e)` (§4.11, §4.5): the offers an entry carries, recorded as it is written, whichever path queued them;
asks on them are outside the serving budget. `e` may be none: `noted` is called with `with_owed`'s result. -/
def noted (p : Peer) (e : Option QEntry) : M2 m (Option QEntry) := do
  enter "noted"
  let offers ← NodeSeacast.offersIn e                         -- `for g, bits in offers_in(e):`
  if offers.isEmpty then branch "noted: no offers"
  for (g, bits) in offers do
    setOfferedTo p g ((← offeredToBits p g) ||| bits)         -- `offered_to[p][g] = offered_to[p][g] | bits`
  return e

end SpecTwin.Seacast
