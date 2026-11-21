import SpecTwin.V2.Receive
import SpecTwin.Sec72

/-! # protocol-v2.md's sampler, the writer's choice and the ask window: §4.10, §4.12, §4.13

The twin of §4.13's `ask_scale`, §4.12's `own_chunk`, `pick` and `choose`, and §4.10's `ask_sample`, `resample`
and `sample`. Each comes after every function it calls (`V2/Relations.lean`'s rule).

- **No recursion between `ask_sample` and `resample`:** `ask_sample` reaches `resample`, and itself again, only
  through timers (`afterV2`); `resample` calls `ask_sample` directly.
- **`resample`'s loop** runs on fuel `n·(n+1)+1`, `n` the length of `held_samples[b]` at its first guard (design
  §7); running out is a crash of the twin's own name.
- **`ask_sample`'s `order`** is built whole before `next` tests it, as the Python builds the list: `via`'s
  route and `ROUTE_HOPS` are asked, and `high` computed, whichever list is the first that is not empty.
- **A queue as an argument** (design §7): `choose` and `pick` take the peer and read its normal lane, as
  `protocol.md`'s `rarest` does. Their raises are the Python's: `IndexError` at `q.normal[0]` and at `ks[0]`,
  `ValueError` from `min` on no places, and an entry with no chunk at a place `pick` ranks is outside the domain,
  a crash here.
- **`ask_scale()`** divides by `UPLINK`, a float: 0 raises `ZeroDivisionError`. -/

namespace SpecTwin.V2

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeV2 m]

/-- `ask_scale()` (§4.13): 1 at `ASK_UPLINK` and above; `ASK_UPLINK / UPLINK` below it -/
def askScale : M2 m Float := do
  enter "ask_scale"
  let u := (← read).base.c.UPLINK
  if u == 0 then crash "ZeroDivisionError: float division by zero (ask_scale)"
  let r := (← read).c2.ASK_UPLINK / u
  return if r > 1.0 then r else 1.0                           -- `max(1.0, ASK_UPLINK / UPLINK)`

/-- `own_chunk(e)` (§4.12): a push of a chunk this node held before any peer: it is the group's source (§1.6) -/
def ownChunk (e : QEntry) : M2 m Bool := do
  enter "own_chunk"
  -- `f is not None and not e.solicited and not received[f.group].has(f.index) and not rebuilt[…].has(…)`
  let some f := e.chunk | return false
  if e.solicited then return false
  if (← receivedBits f.g).has f.i then return false
  return !(← rebuiltBits f.g).has f.i

/-- `pick(q, ks)` (§4.12, [c9]): of these places in p's normal lane, the rarest chunk's, the earliest on a tie;
without card 9 the first -/
def pick (p : Peer) (ks : List Nat) : M2 m Nat := do
  enter "pick"
  if !(← read).base.c.RAREST then                             -- `return ks[0]`
    let some k := ks.head? | crash "IndexError: list index out of range (pick: ks[0])"
    return k
  -- `min` of no places raises before its key reads anything
  if ks.isEmpty then crash "ValueError: min() iterable argument is empty (pick)"
  let normal := (← lane? p .normal).getD []
  -- `min(ks, key=lambda k: (len(holders[q.normal[k].chunk.group][q.normal[k].chunk.index]), k))`
  let mut best : Option (Nat × Nat) := none
  for k in ks do
    let some e := normal[k]? | crash "IndexError: list index out of range (pick: q.normal[k])"
    let some f := e.chunk | crash "AttributeError: 'NoneType' object has no attribute 'group' (pick)"
    let n ← v1 (holders f.g f.i)
    best := match best with
      | some (bn, bk) => if n < bn || (n == bn && k < bk) then some (n, k) else some (bn, bk)
      | none => some (n, k)
  match best with
  | some (_, k) => return k
  | none => crash "ValueError: min() iterable argument is empty (pick)"

/-- `choose(q)` (§4.12): the normal entry p's writer sends next -/
def choose (p : Peer) : M2 m Nat := do
  enter "choose"
  let normal := (← lane? p .normal).getD []
  let some e0 := normal.head? | crash "IndexError: list index out of range (choose: q.normal[0])"
  if e0.chunk.isNone then                                     -- control at the head goes at once: it takes no room
    branch "choose: control at the head"
    return 0
  -- `[k for k, e in enumerate(q.normal) if own_chunk(e)]`
  let own ← ((List.range normal.length).zip normal).filterMapM fun (k, e) => do
    return if ← ownChunk e then some k else none
  if !own.isEmpty then                                        -- [X3] a source's own chunks first
    branch "choose: our own chunks"
    return (← pick p own)
  if (← read).c2.ANSWERS_FIRST then                           -- an option, off in every setting
    let asked := ((List.range normal.length).zip normal).filterMap fun (k, e) => if e.solicited then some k else none
    if !asked.isEmpty then
      branch "choose: answers first"
      return (← pick p asked)
  if (← read).base.c.RAREST then                              -- [c9] v0.3: up to the first control-only entry
    branch "choose: the rarest"
    v1 (rarest normal)
  else
    branch "choose: the first"
    return 0

/-- `ask_sample(g, i, first)` (§4.10): one sample to one peer, never one asked for another sample of the block
(I6): a link that serves it, else a routed request through another -/
def askSample (g : Group) (i : Nat) (first : Bool) : M2 m Unit := do
  enter "ask_sample"
  let T ← NodeV2.typeOfGroup g                                -- `T, b = type_of_group(g), block_of(g)`
  let b ← NodeV2.blockOf g
  -- `mine[g].has(i) or expired(g)`
  if (← mineBits g).has i then
    branch "ask_sample: held"
    return
  if ← expired g then
    branch "ask_sample: expired"
    return
  -- `not first and samples_in_flight[b] >= T.params.SAMPLE_OUTSTANDING`: LiteDAS's cap
  if !first then
    if (← samplesInFlight b) ≥ ((← param T "SAMPLE_OUTSTANDING" (·.SAMPLE_OUTSTANDING) : Nat) : Int) then
      setHeldSamples b ((← heldSamplesOf b) ++ [(g, i)])      -- `held_samples[b].append((g, i))`
      branch "ask_sample: held back"
      return
  let a : Key := .want g i
  -- `[q for q in links(T) if q not in sampled_from[b] and not parked(q, Ask(g, i))]`
  let fresh ← (← NodeV2.links T).filterM fun q => do
    if (← sampledFromOf b).contains q then return false
    return !(← v1 (parked q a))
  -- `[q for q in fresh if serves(q, g, i) and not high_custody(q, T)]`
  let direct ← fresh.filterM fun q => do
    if !(← serves q g i) then return false
    return !(← NodeV2.highCustody q T)
  -- `route_next(T, T.family(g), [q for q in fresh if not serves(q, g, i) and join_recv[q][T].duty == FORWARD])`
  let fam ← NodeV2.family T g
  let toward ← fresh.filterM fun q => do
    if ← serves q g i then return false
    let some j ← joinRecv? q T | crash s!"KeyError: {T} (ask_sample: join_recv[q][T])"
    return j.duty == .forward
  let via ← NodeV2.routeNext T fam toward
  -- `[q for q in fresh if serves(q, g, i) and high_custody(q, T)]`
  let high ← fresh.filterM fun q => do
    if !(← serves q g i) then return false
    NodeV2.highCustody q T
  -- `order = [(direct, 0), (via, T.params.ROUTE_HOPS)] + ([] if first else [(high, 0)])`, built whole
  let hopsVia ← param T "ROUTE_HOPS" (·.ROUTE_HOPS)
  let order := [(direct, 0), (via, hopsVia)] ++ (if first then [] else [(high, 0)])
  match order.find? (!·.1.isEmpty) with                       -- `next(((c, h) for c, h in order if c), (None, 0))`
  | none =>
    if first then                                             -- only high custody serves it: the second phase
      NodeV2.afterV2 (← param T "SAMPLE_RETRY" (·.SAMPLE_RETRY)) (.askSample g i)
      branch "ask_sample: nobody now, the second phase"
    else
      branch "ask_sample: nobody left"                        -- missing, for the application's verdict
  | some (cands, hops) =>
    let q ← NodeV2.choicePeer cands
    setSampledFrom b ((← sampledFromOf b).insert q)           -- `sampled_from[b].add(q)`
    if !first then setSamplesInFlight b ((← samplesInFlight b) + 1)
    let w : Want := { group := g, bits := (0 : Bits).set i, standing := true, hops := hops, probe := false }
    let _ ← NodeV2.send q (.want w) false                     -- no promise timer (§4.5)
    let d ← if first then param T "SAMPLE_RETRY" (·.SAMPLE_RETRY) else param T "SAMPLE_RETRY2" (·.SAMPLE_RETRY2)
    NodeV2.afterV2 d (.resample g i q first)
    branch "ask_sample: asked"

/-- `resample(g, i, q, first)` (§4.10): the wait ran out -/
def resample (g : Group) (i : Nat) (q : Peer) (first : Bool) : M2 m Unit := do
  enter "resample"
  let T ← NodeV2.typeOfGroup g                                -- `T, b = type_of_group(g), block_of(g)`
  let b ← NodeV2.blockOf g
  if !first then setSamplesInFlight b ((← samplesInFlight b) - 1)
  if ← expired g then                                         -- past its lifetime: no state is made again for it
    branch "resample: expired"
    return
  if !(← mineBits g).has i then
    setPark q g ((← read).base.now + (← read).base.c.PARK_TTL)   -- `park[q][g] = now + PARK_TTL`
    askSample g i false                                       -- the second phase: another peer, a short wait
  -- `while held_samples[b] and samples_in_flight[b] < T.params.SAMPLE_OUTSTANDING:`
  let n := (← heldSamplesOf b).length                         -- read at the first guard (design §7)
  for _ in List.range (n * (n + 1) + 1) do
    let held ← heldSamplesOf b
    if held.isEmpty then
      branch "resample: none held"
      return
    if (← samplesInFlight b) ≥ ((← param T "SAMPLE_OUTSTANDING" (·.SAMPLE_OUTSTANDING) : Nat) : Int) then
      branch "resample: the cap reached"
      return
    match held with
    | (g2, i2) :: rest =>
      setHeldSamples b rest                                   -- `held_samples[b].pop(0)`
      askSample g2 i2 false
    | [] => pure ()
  crash "twin: resample ran out of fuel (notes/spec-lean/v2-layer/design.md §7)"

/-- `sample(g, bits)` (§4.10): at block arrival, the application's draw, never narrowed to what our links serve;
ours from now on (§1.5) -/
def sample (g : Group) (bits : Bits) : M2 m Unit := do
  enter "sample"
  if ← expired g then                                         -- past its lifetime (protocol.md §8.1)
    branch "sample: expired"
    return
  setInterest g (IBits.or (← interestOf g) (IBits.ofBits bits))   -- `interest[g] |= bits`
  for i in bits.toList do
    askSample g i true                                        -- the first phase: every sample at once
  branch "sample: asked"

end SpecTwin.V2
