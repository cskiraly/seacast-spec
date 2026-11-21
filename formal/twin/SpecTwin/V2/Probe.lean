import SpecTwin.V2.Announce

/-! # protocol-v2.md's probe, standing answers and repair checks: §4.5, §4.6

The twin of the probe's functions (R5): `gated`, `settle_probe`, `probe_answer`, `probe_promise`,
`probe_waits`, `probe_settled`, `probe_of_claim` and `serve_probe`; §4.5's `serve_standing` and
`serve_waiting_probe`; and §4.6's `known_in_scope`, `known_across`, `ask_custodian`, `repair_verdict` and
`owed_missing`. Each comes after every function it calls (`V2/Relations.lean`'s rule). `serve_standing` is
main's, v0.10.11's; part G changes it, and it is transcribed again from v0.10.12 (design §8).

- **An ask with its flags** is an `AskV2` (design §4.3). `group_index(a)` is the twin's own (design §5): an ask by
  index is itself, with its flags; a structured id gives its group and index with none, as the toy's
  `GroupIndex` carries none. Every `Key` has a group and an index, so it is never none here; `probe_waits`,
  `probe_settled` and `probe_of_claim` test it all the same, as the Python does, with no read where it is none.
- **The plain dicts raise** (design §4.4): `probe[g]` and `probed[g]` crash as `KeyError` on the group where the
  Python loads them; `.get` reads none; `g in probe_ok` is the entry's presence, whose value can be a present
  `None` (`some none`).
- **The order of a proxied set** is asked at each iteration (design §3.1): `serve_standing`'s popped set, empty
  or not, and `suppression_scope`'s in `known_in_scope` and `known_across`. `probe_waiting[g].items()` is a
  table's level, whose keys' order is asked with `probeWaitingOrder` (design §3.2's `keys` entry).
- **`interest[g2]`** reads the table, and asks `own_interest(g2)` where it has no entry, storing nothing
  (design §1's fourth point).
- **Writes** follow `V2/Relations.lean`'s rule: `probe_asks.discard`, a set's member, is a write with no read,
  as the tracer's view of a set logs it (`tools/footprint.py`, `add` and `discard`).
- **`repair_verdict`'s steps** (design §7): a `None` list crashes as `TypeError` at its first subscript, a step
  past the list as `IndexError`; `want` is an `Int`, and the loop stops at `want == 0` alone. -/

namespace SpecTwin.V2

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeV2 m]

/-- `group_index(a)` (design §5): the ask itself where it is by index, with its flags; a structured id's group
and index, with none -/
def groupIndex (a : AskV2) : Option AskV2 :=
  match a.key with
  | .want _ _ => some a
  | .id _ g i => some { key := .want g i }

/-- `interest[g]`: the table's entry, or `own_interest(g)` where it has none -/
def interestOf (g : Group) : M2 m IBits := do
  match ← interest? g with
  | some v => return v
  | none => NodeV2.ownInterest g

/-- `gated(a)` (protocol.md §6.2, [c6]): stop-pull, with the probe exempt -/
def gated (a : Key) : M2 m Bool := do
  enter "gated"
  -- `stop_pull[group(a)] and a not in probe_asks`
  if !(← stopPull a.group) then return false
  return !(← probeAsk? a)

/-- `settle_probe(g, verdict)` (§4.6, R5): the verdict, once (true passed, false failed, none no verdict);
settled, the probe's ask is gated again -/
def settleProbe (g : Group) (verdict : Option Bool) : M2 m Unit := do
  enter "settle_probe"
  setProbeOk g verdict                                        -- `probe_ok[g] = verdict`
  let some i ← probe? g | crash s!"KeyError: {g} (settle_probe: probe[g])"
  setProbeAsk (.want g i) false                               -- `probe_asks.discard(Ask(g, probe[g]))`: a write
  branch "settle_probe: the probe's exemption discarded"      --   with no read, as the tracer's view of a set logs it

/-- `probe_answer(g, i, p)` (§4.6, R5): the claimant's own copy of the probed index, first or a duplicate, passes
the probe and keeps its promise -/
def probeAnswer (g : Group) (i : Nat) (p : Option Peer) : M2 m Unit := do
  enter "probe_answer"
  -- `deferred[g] and probe.get(g) == i and p is not None and p == probed.get(g) and g not in probe_ok`
  if !(← deferred? g) then
    branch "probe_answer: not deferred"
    return
  if (← probe? g) != some i then
    branch "probe_answer: not the probed index"
    return
  let q ← match p with
    | none => do
      branch "probe_answer: our own decode"
      return
    | some q => pure q
  if (← probed? g) != some q then
    branch "probe_answer: not the claimant"
    return
  if (← probeOk? g).isSome then
    branch "probe_answer: settled before"
    return
  settleProbe g (some true)
  if (← promise? (.want g i) q).isSome then                   -- `promises.pop((Ask(g, i), p), None)`
    erasePromise (.want g i) q
  branch "probe_answer: passed"

/-- `probe_promise(g, i)` (§4.6, R5): the probe's promise, still open, with its key -/
def probePromise (g : Group) (i : Nat) : M2 m (Option ((Key × Peer) × Float)) := do
  enter "probe_promise"
  -- `if not deferred[g] or probe.get(g) != i or g in probe_ok: return None`
  if !(← deferred? g) then return none
  if (← probe? g) != some i then return none
  if (← probeOk? g).isSome then return none
  let some q ← probed? g | crash s!"KeyError: {g} (probe_promise: probed[g])"
  -- `return (k, promises[k]) if k in promises else None`
  match ← promise? (.want g i) q with
  | some t => return some ((.want g i, q), t)
  | none => return none

/-- `probe_waits(a, p)` (§4.6, R5): a is our probe of p, flagged and not yet answered or judged -/
def probeWaits (a : AskV2) (p : Peer) : M2 m Bool := do
  enter "probe_waits"
  let some gi := groupIndex a | return false
  let g := gi.key.group
  -- `gi.probe and deferred[g] and probed.get(g) == p and probe.get(g) == gi.index and g not in probe_ok`
  if !gi.probe then return false
  if !(← deferred? g) then return false
  if (← probed? g) != some p then return false
  if (← probe? g) != some gi.key.index then return false
  return (← probeOk? g).isNone

/-- `probe_settled(a)` (§4.6, R5): a is our probe, judged or given no verdict -/
def probeSettled (a : AskV2) : M2 m Bool := do
  enter "probe_settled"
  let some gi := groupIndex a | return false
  if !gi.probe then return false
  return (← probeOk? gi.key.group).isSome

/-- `probe_of_claim(p, gi)` (§4.6, R5): as the claimant, p's flagged ask of an index we claim, while no flagged
ask of the group from p was answered and none of another index of it is kept -/
def probeOfClaim (p : Peer) (gi : Option AskV2) : M2 m Bool := do
  enter "probe_of_claim"
  let some gi := gi | return false
  let g := gi.key.group; let i := gi.key.index
  -- `gi.probe and mine[g].has(i) and not probe_served[p][g] and probe_waiting[g].get(p, i) == i`
  if !gi.probe then return false
  if !(← mineBits g).has i then return false
  if ← probeServed p g then return false
  return ((← probeWaiting? g p).getD i) == i

/-- `serve_probe(p, g, f)` (§4.6, R5): f answers p's probe of g: the cap is taken, and card 8 lets that answer
through once -/
def serveProbe (p : Peer) (g : Group) (f : ChunkF) : M2 m Unit := do
  enter "serve_probe"
  setProbeServed p g true                                     -- `probe_served[p][g] = True`
  let b ← probeAnswerBits p f.g                               -- `probe_answers[p][f.group].set(f.index)`
  if !b.has f.i then setProbeAnswers p f.g (b.set f.i)

/-- The answer `serve_standing` and `serve_waiting_probe` enqueue: refused by a full queue, owed (v0.5 §7.2);
then noted, so that no offer follows it (§4.4) -/
private def answer (who : String) (q : Peer) (g : Group) (i : Nat) : M2 m Unit := do
  let f ← chunkAt g i                                         -- `chunks[g][i]`
  if !(← enqueue q (.entry { chunk := some f, control := none, solicited := true }) false) then
    let b ← owedAnswerBits q g                                -- `owed_answers[q][g].set(i)`
    if !b.has i then setOwedAnswers q g (b.set i)
    branch s!"{who}: refused, owed"
  notePush q g i

/-- `served[q][g] >= type_of_group(g).params.SERVE_LIMIT`: the type and the limit asked where the Python reads
them -/
private def servedOut (q : Peer) (g : Group) : M2 m Bool := do
  let n ← servedCount q g
  let lim ← param (← NodeV2.typeOfGroup g) "SERVE_LIMIT" (·.SERVE_LIMIT)
  return n.toFloat ≥ lim

/-- `serve_standing(g, i)` (§4.5, main's text): the chunk a WANT waited for is here -/
def serveStanding (g : Group) (i : Nat) : M2 m Unit := do
  enter "serve_standing"
  -- `standing[g].pop(i, ())`: a present set is deleted, a missing one left; its order asked, empty or not
  let popped ← standing? g i
  if popped.isSome then eraseStanding g i
  for q in ← NodeV2.order "serve_standing" ((popped.getD {}).toList) do
    -- `peer_has[q][g].has(i) or served[q][g] >= …SERVE_LIMIT`
    if (← v1 (peerHas q g)).has i then
      branch "serve_standing: held already"
      continue
    if ← servedOut q g then
      branch "serve_standing: past the limit"
      continue
    setServed q g ((← servedCount q g) + 1)                   -- `served[q][g] += 1`
    answer "serve_standing" q g i
    branch "serve_standing: answered"

/-- `serve_waiting_probe(g, i)` (§4.5, R5): the cell a kept probe waited for is here: answered as `on_want`
answers a probe, with its one exemption -/
def serveWaitingProbe (g : Group) (i : Nat) : M2 m Unit := do
  enter "serve_waiting_probe"
  -- `[q for q, j in probe_waiting[g].items() if j == i]`, in the keys' order
  let items ← allProbeWaiting g
  let mut qs : List Peer := []
  for q in ← NodeV2.probeWaitingOrder g (items.map (·.1)) do
    match items.lookup q with
    | some j => if j == i then qs := qs ++ [q]
    | none => return (← crash "twin: serve_waiting_probe: the order names a peer probe_waiting[g] has not")
  for q in qs do
    -- `del probe_waiting[g][q]`: the view logs the write before the deletion, which raises where a question's notes
    -- took the entry out since the list was made (the scan read it, so its read here is the Python's)
    let present ← probeWaiting? g q
    eraseProbeWaiting g q
    if present.isNone then return (← crash s!"KeyError: {q} (serve_waiting_probe: probe_waiting[g][q])")
    -- `probe_served[q][g] or served[q][g] >= …SERVE_LIMIT`
    if ← probeServed q g then
      branch "serve_waiting_probe: a probe answered before"
      continue
    if ← servedOut q g then
      branch "serve_waiting_probe: past the limit"
      continue
    setServed q g ((← servedCount q g) + 1)                   -- `served[q][g] += 1`
    serveProbe q g (← chunkAt g i)                            -- `serve_probe(q, g, chunks[g][i])`
    answer "serve_waiting_probe" q g i
    branch "serve_waiting_probe: answered"

/-- `known_in_scope(g)` (§4.6): what we and our relation peers hold of g, by their holdings; an unverified claim
counts for nothing -/
def knownInScope (g : Group) : M2 m Bits := do
  enter "known_in_scope"
  let mut known ← mineBits g                                  -- `known = mine[g].copy()`
  for q in ← NodeV2.order "known_in_scope" (← suppressionScope g) do
    if ((← claims? g).getD {}).contains q then continue       -- `if q in claims[g]: continue`
    known := known ||| (← v1 (peerHas q g))                   -- `known |= peer_has[q][g].bits`
  return known

/-- `known_across(g)` (§4.6, R4): what our relation peers on the other axis hold of g -/
def knownAcross (g : Group) : M2 m Bits := do
  enter "known_across"
  let T ← NodeV2.typeOfGroup g
  let mut known ← mineBits g                                  -- `known = mine[g].copy()`
  for i in List.range (← NodeV2.indexCount T (← desc g)) do   -- `range(T.index_count(hdr[g]))`
    if known.has i then continue
    for (g2, i2) in ← NodeV2.cross T g i do
      -- `any(peer_has[q][g2].has(i2) for q in suppression_scope(g2))`: the reads stop at the first holder
      let mut held := false
      for q in ← NodeV2.order "known_across" (← suppressionScope g2) do
        if (← v1 (peerHas q g2)).has i2 then
          held := true
          break
      if held then
        known := known.set i
        break
  return known

/-- `ask_custodian(g, i)` (§4.6, R5, option): cell i of g, of a custodian of its column not yet asked for it and
not a claimant -/
def askCustodian (g : Group) (i : Nat) : M2 m Bool := do
  enter "ask_custodian"
  let T ← NodeV2.typeOfGroup g
  let some (g2, i2) := (← NodeV2.cross T g i).head?           -- `T.cross(g, i)[0]`
    | crash "IndexError: list index out of range (ask_custodian: T.cross(g, i)[0])"
  if ← expired g2 then                                        -- an expired column is not asked for (§8.1 there)
    branch "ask_custodian: an expired column"
    return false
  -- `[q for q in links(type_of_group(g2)) if interest_of_peer(q, g2).has(i2) and q not in claims[g] and q not in
  -- rsample_asked[g][i]]`, left to right
  let qs ← (← NodeV2.links (← NodeV2.typeOfGroup g2)).filterM fun q => do
    if !(← interestOfPeer q g2).has i2 then return false
    if ((← claims? g).getD {}).contains q then return false
    return !(← rsampleAskedOf g i).contains q
  if qs.isEmpty then
    branch "ask_custodian: nobody to ask"
    return false
  let q ← NodeV2.choicePeer qs
  setRsampleAsked g i ((← rsampleAskedOf g i).insert q)       -- `rsample_asked[g][i].add(q)`
  let w : Want := { group := g2, bits := (0 : Bits).set i2, standing := false, hops := 0, probe := false }
  let _ ← NodeV2.send q (.want w) false
  branch "ask_custodian: asked"
  return true

/-- `received[g].has(i) or rebuilt[g].has(i)`: `rebuilt` read only where `received` lacks i -/
private def heldHere (g : Group) (i : Nat) : M2 m Bool := do
  if (← receivedBits g).has i then return true
  return (← rebuiltBits g).has i

/-- `steps[j]` of `repair_verdict`, with the Python's raises -/
private def step (steps : Option (List (Nat × Nat))) (j : Nat) (where_ : String) : M2 m (Nat × Nat) := do
  let some l := steps | crash s!"TypeError: 'NoneType' object is not subscriptable (repair_verdict: {where_})"
  let some s := l[j]? | crash s!"IndexError: list index out of range (repair_verdict: {where_})"
  return s

/-- `repair_verdict(g)` (§4.6, R5, option): IncrementalDAS on the claimant's repair: cells of g we lack, asked of
their columns' custodians, each step's sample containing the last -/
def repairVerdict (g : Group) : M2 m RepairVerdict := do
  enter "repair_verdict"
  let T ← NodeV2.typeOfGroup g
  let steps ← param T "REPAIR_SAMPLE" (·.REPAIR_SAMPLE)
  let k ← rsampleStep g
  if k > 0 then                                               -- step k's sample was asked SAMPLE_WAIT ago
    let lost ← (← rsampleOf g).filterM fun i => do return !(← heldHere g i)
    if lost.length ≤ (← step steps (k - 1) "steps[k - 1]").2 then
      branch "repair_verdict: the repair followed"
      return .repaired
    let len := (steps.getD []).length                         -- a list here: `steps[k - 1]` passed
    if k == len then
      if ← rsampleFinal? g then
        branch "repair_verdict: the last re-asks waited for"
        return .notRepaired
    -- `[i for i in lost if T.params.REPAIR_REASK and ask_custodian(g, i)]`
    let reasked ← lost.filterM fun i => do
      if !(← param T "REPAIR_REASK" (·.REPAIR_REASK)) then return false
      askCustodian g i
    if k == len then
      if reasked.isEmpty then
        branch "repair_verdict: no re-ask at the last step"
        return .notRepaired
      setRsampleFinal g true
      branch "repair_verdict: the last step's re-asks"
      return .asked
  let mut want : Int := ((← step steps k "steps[k]").1 : Int) - ((← rsampleOf g).length : Int)
  -- `[i for i in range(T.index_count(hdr[g])) if not (received… or rebuilt…) and i not in rsample[g]]`
  let cand ← (List.range (← NodeV2.indexCount T (← desc g))).filterM fun i => do
    if ← heldHere g i then return false
    return !(← rsampleOf g).contains i
  for i in ← shuffledNats cand do
    if want == 0 then break
    if ← askCustodian g i then
      setRsample g ((← rsampleOf g) ++ [i])                   -- `rsample[g].append(i)`
      want := want - 1
  setRsampleStep g (k + 1)
  if !(← rsampleOf g).isEmpty then
    branch "repair_verdict: asked"
    return .asked
  branch "repair_verdict: nothing left to sample"
  return .repaired

/-- `owed_missing(g)` (§4.6, R5): the member check: a chunk of g that is ours on the other axis is still missing -/
def owedMissing (g : Group) : M2 m Bool := do
  enter "owed_missing"
  let T ← NodeV2.typeOfGroup g
  -- `any(interest[g2].has(i2) and not (received[g].has(i) or rebuilt[g].has(i)) for i in range(…) for (g2, i2)
  -- in T.cross(g, i))`: the range is made first, the crosses one i at a time, and the reads stop at the first
  for i in List.range (← NodeV2.indexCount T (← desc g)) do
    for (g2, i2) in ← NodeV2.cross T g i do
      if (← interestOf g2).has i2 then
        if !(← heldHere g i) then
          branch "owed_missing: missing"
          return true
  branch "owed_missing: nothing missing"
  return false

/-! ### The calls as the node binds the names

A node can replace four of this file's functions (design §1.4). A call of one is the node's own where its line
names it as replaced, a question, and the document's otherwise. -/

/-- A call `serve_standing(g, i)` as the node binds the name -/
def serveStandingCall (g : Group) (i : Nat) : M2 m Unit := do
  if (← read).base.replaced.contains "serve_standing" then NodeV2.serveStandingNode g i else serveStanding g i

/-- A call `known_in_scope(g)` as the node binds the name -/
def knownInScopeCall (g : Group) : M2 m Bits := do
  if (← read).base.replaced.contains "known_in_scope" then NodeV2.knownInScopeNode g else knownInScope g

/-- A call `repair_verdict(g)` as the node binds the name -/
def repairVerdictCall (g : Group) : M2 m RepairVerdict := do
  if (← read).base.replaced.contains "repair_verdict" then NodeV2.repairVerdictNode g else repairVerdict g

/-- A call `owed_missing(g)` as the node binds the name -/
def owedMissingCall (g : Group) : M2 m Bool := do
  if (← read).base.replaced.contains "owed_missing" then NodeV2.owedMissingNode g else owedMissing g

end SpecTwin.V2
