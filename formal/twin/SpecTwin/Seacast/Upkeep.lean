import SpecTwin.Seacast.Announce

/-! # seacast.md §4.1 and §6.3: keeping the relations

The twin of §4.1's `on_join`, `maintain_relations`, `graft`, `on_graft` and `on_prune`, and of §6.3's
`relation_room`, which the last four call. Each comes after every function it calls (`Seacast/Relations.lean`'s
rule): `relation_room`, `graft`, `on_prune`, `on_graft`, `maintain_relations`, `on_join`.

- **A type is its id:** `T.params.X` is `param`, read from the context, and `T.id` is `T`. A parameter is read
  where the Python reads it, so a type without it crashes as `AttributeError` there and nowhere earlier.
- **`relation_room`'s `held` is a set of pairs** `(family, colour)`: a pair that several maps hold counts once in
  `len(held)`. Each of the four relation maps' `m[p][T]` and `backoff[p][T]` is read whole (`.items()`), and
  `owed_relations[p]` is read as a list; a JOIN in it is skipped before its type is read. `MAX_RELATIONS` is read
  only where the pair is not held, and `len(held) < MAX_RELATIONS` is Python's exact comparison of an int and a
  float (`natGeFloat`); the toy's limit is `math.inf` unless the run sets it.
- **`type_of` is asked twice** in `on_graft` and `on_prune`, as the Python asks it: once for `joined`, once for `T`.
- **`on_prune`'s cleanup** goes over `backoff[p][T]` whole and deletes the keys whose time has come. The family a
  deletion empties is deleted too in the Python; a level deleted whole writes nothing that a record shows, so the
  twin leaves the empty family, which the replay cannot tell from a missing one: a record holds neither how often a
  cell is read nor a level's presence once its leaves are gone. Which family is cleaned first changes nothing that
  is written, so no order is asked.
- **`maintain_relations`' slices are Python's:** `cs[:n]` with a negative `n` drops the last `-n` candidates, so a
  symmetric type whose `D_OUT` is below `len(ins)` grafts fewer than all; `ins[F_HI:]` is every pusher past the
  first `F_HI`; `cs[:max(0, n)]` takes none for a negative `n`. `relation_room` is called for every candidate, in
  the question's order, before the slice is taken.
- **`sample_without_replacement(ins, len(ins) - D_OUT)`** is asked with a count that is not negative wherever
  `F_HI` is at least `D_OUT`, as the toy's 12 and 8 are for every type (toy/node.py:1235, :1285, :1330). A negative
  count, which the toy's draw refuses with `ValueError`, cannot be put to the twin's question; the twin crashes
  there with a name of its own.
- **The half-held relations** are `set(in_pushers(…)) ^ set(out_pushees(…))` in `sorted` order: the two lists
  hold no peer twice, so the difference is the peers of one list that the other lacks, sorted.
- **`or` and `and` short-circuit** as the Python's do, read for read: `grafted_out` is read only where
  `grafted_in` does not hold the colour, `push_out` only where `push_in` does not, and the accept test of a
  symmetric GRAFT asks `in_pushers`, reads `F_HI`, asks `wants_family` and loads `join_sent[p][T]` only as far as
  the parts before allow.
- **`join_sent[p][T]` raises** as `KeyError` on the type, named with its kind (`type T`), where the Python loads
  it; `T not in join_sent[p]` is a read of that entry, which creates nothing.
- **Writes** follow `Seacast/Relations.lean`'s rule: a set's `.add` reads the entry and writes it, changed or not;
  a `.discard` of a colour that is not there writes nothing; an assignment to a subscript is a write always.
- **Questions:** `runs_type(t)`, `our_join(T)`, `candidates(T, fam, c, d)`, `in_pushers(T, fam, c)`,
  `out_pushees(T, fam, c)` and `uplink_class()`, the node's, beside `type_of`, `links` (through `joined`),
  `families_with_duty`, `wants_family` and the draw. -/

namespace SpecTwin.Seacast

open SpecTwin Node61 Tables

variable {m : Type → Type} [Monad m] [Tables m] [Node61 m] [NodeSeacast m]

/-- Python's `xs[:n]`: a negative `n` counts from the end. -/
def pyTake {α} (xs : List α) (n : Int) : List α :=
  if n ≥ 0 then xs.take n.toNat else xs.take (xs.length - n.natAbs)

#guard pyTake [1, 2, 3] 2 == [1, 2]
#guard pyTake [1, 2, 3] 5 == [1, 2, 3]
#guard pyTake [1, 2, 3] 0 == []
#guard pyTake [1, 2, 3] (-1) == [1, 2]
#guard pyTake [1, 2, 3] (-3) == []
#guard pyTake [1, 2, 3] (-4) == []

/-- `relation_room(p, T, fam, c)` (§6.3, X6): the link has `(fam, c)` in some state already, or fewer pairs of T
than `MAX_RELATIONS` -/
def relationRoom (p : Peer) (T : TypeId) (fam : Fam) (c : Nat) : M2 m Bool := do
  enter "relation_room"
  let mut held : List (Fam × Nat) := []
  -- `{(f, k) for m in (push_in, push_out, grafted_in, grafted_out) for f, ks in m[p][T].items() for k in ks}`
  for level in [← allPushInType p T, ← allPushOutType p T, ← allGraftedInType p T, ← allGraftedOutType p T] do
    for (f, ks) in level do
      for k in ks.toList do
        if !held.contains (f, k) then held := held ++ [(f, k)]
  -- `{(f, k) for f, bo in backoff[p][T].items() for (k, d), until in bo.items() if until > now}`
  let now := (← read).base.now
  for (f, bo) in ← allBackoffType p T do
    for ((k, _), upTo) in bo do
      if upTo > now && !held.contains (f, k) then held := held ++ [(f, k)]
  -- `{(m.family, m.colour) for m in owed_relations[p] if not isinstance(m, Join) and m.object_type == T.id}`
  for r in ← owedRelationsOf p do
    let pair? : Option (Fam × Nat) := match r with
      | .join _ => none                                       -- a JOIN: its type is not read
      | .graft g => if g.objectType == T then some (g.family, g.colour) else none
      | .prune q => if q.objectType == T then some (q.family, q.colour) else none
    if let some x := pair? then
      if !held.contains x then held := held ++ [x]
  -- `(fam, c) in held or len(held) < T.params.MAX_RELATIONS`
  if held.contains (fam, c) then
    branch "relation_room: the pair held"
    return true
  if natGeFloat held.length (← param T "MAX_RELATIONS" (·.MAX_RELATIONS)) then
    branch "relation_room: at the limit"
    return false
  branch "relation_room: below the limit"
  return true

/-- `graft(q, T, fam, c, d)` (§4.1): our GRAFT; nothing is counted until q answers it -/
def graft (q : Peer) (T : TypeId) (fam : Fam) (c : Nat) (d : Direction) : M2 m Unit := do
  enter "graft"
  if !(← relationRoom q T fam c) then                        -- §6.3: our own relations stay under the limit too
    branch "graft: no room"
    return
  if d == .inward || d == .both then                          -- `grafted_in[q][T][fam].add(c)`
    setGraftedIn q T fam ((← graftedInOf q T fam).insert c)
  if d == .outward || d == .both then                         -- `grafted_out[q][T][fam].add(c)`
    setGraftedOut q T fam ((← graftedOutOf q T fam).insert c)
  branch "graft: sent"
  sendRelation q (.graft { objectType := T, family := fam, colour := c, direction := d, answer := false })

/-- `on_prune(p, pr)` (§4.1): p's no, or p's end of the relation; ours ends too -/
def onPrune (p : Peer) (pr : Prune) : M2 m Unit := do
  enter "on_prune"
  -- `not runs_type(pr.object_type) or not joined(p, type_of(pr.object_type))`, left to right
  if !(← NodeSeacast.runsType pr.objectType) then
    branch "on_prune: a type the node does not run"
    return
  if !(← joined p (← NodeSeacast.typeOf pr.objectType)) then
    branch "on_prune: a link that has not joined the type"
    return
  let T ← NodeSeacast.typeOf pr.objectType                   -- `T = type_of(pr.object_type)`: asked again
  let fam := pr.family
  let c := pr.colour
  let now := (← read).base.now
  -- `for f in list(backoff[p][T]): ... for k in [k for k, until in bo.items() if until <= now]: del bo[k]`
  for (f, bo) in ← allBackoffType p T do
    for (k, upTo) in bo do
      if upTo ≤ now then
        eraseBackoff p T f k
        branch "on_prune: a backoff run out"
  if !(← relationRoom p T fam c) then                         -- §6.3: a new pair over the link's limit
    branch "on_prune: no room"
    return
  -- `d = BOTH if T.params.SYMMETRIC else pr.direction`; `until = now + T.params.PRUNE_BACKOFF`
  let d := if (← param T "SYMMETRIC" (·.SYMMETRIC)) then Direction.both else pr.direction
  let upTo := now + (← param T "PRUNE_BACKOFF" (·.PRUNE_BACKOFF))
  if d == .outward || d == .both then                         -- "I stop pushing you", "I will not push you"
    discardColour pushInOf setPushIn p T fam c
    discardColour graftedInOf setGraftedIn p T fam c
    if upTo > now then
      setBackoff p T fam (c, .inward) upTo                -- our "push me" waits
      branch "on_prune: pushes to us end, a backoff"
    else branch "on_prune: pushes to us end, no backoff"
  if d == .inward || d == .both then                          -- "stop pushing me"
    discardColour pushOutOf setPushOut p T fam c
    discardColour graftedOutOf setGraftedOut p T fam c
    if upTo > now then
      setBackoff p T fam (c, .outward) upTo               -- our "I will push you" waits
      branch "on_prune: our pushes end, a backoff"
    else branch "on_prune: our pushes end, no backoff"

/-- `on_graft(p, gr)` (§4.1): each direction answered, a GRAFT yes, a PRUNE no -/
def onGraft (p : Peer) (gr : Graft) : M2 m Unit := do
  enter "on_graft"
  -- `not runs_type(gr.object_type) or not joined(p, type_of(gr.object_type))`, left to right
  if !(← NodeSeacast.runsType gr.objectType) then
    branch "on_graft: a type the node does not run"
    return
  if !(← joined p (← NodeSeacast.typeOf gr.objectType)) then
    branch "on_graft: a link that has not joined the type"
    return
  let T ← NodeSeacast.typeOf gr.objectType                   -- `T = type_of(gr.object_type)`: asked again
  let fam := gr.family
  let c := gr.colour
  if !(← relationRoom p T fam c) then                         -- §6.3: ignored, unanswered
    branch "on_graft: no room"
    return
  if ← param T "SYMMETRIC" (·.SYMMETRIC) then                -- one relation both ways: decided as one, one answer
    -- `asked = c in grafted_in[p][T][fam] or c in grafted_out[p][T][fam]`
    let asked ← if (← graftedInOf p T fam).contains c then pure true
                 else do pure ((← graftedOutOf p T fam).contains c)
    discardColour graftedInOf setGraftedIn p T fam c
    discardColour graftedOutOf setGraftedOut p T fam c
    -- `held = c in push_in[p][T][fam] or c in push_out[p][T][fam]`
    let held ← if (← pushInOf p T fam).contains c then pure true
                else do pure ((← pushOutOf p T fam).contains c)
    -- `held or (len(in_pushers(T, fam, c)) < T.params.F_HI and wants_family(T, fam)
    --           and join_sent[p][T].duty == FORWARD)`, left to right
    let accept ← if held then pure true else do
      let n := (← NodeSeacast.inPushers T fam c).length
      if n ≥ (← param T "F_HI" (·.F_HI)) then pure false
      else do
        if !(← NodeSeacast.wantsFamily T fam) then pure false
        else do
          let some j ← joinSent? p T | crash s!"KeyError: type {T} (on_graft: join_sent[p][T])"
          pure (j.duty == .forward)
    if accept then
      setPushIn p T fam ((← pushInOf p T fam).insert c)       -- `push_in[p][T][fam].add(c)`
      if !asked && !(held && gr.answer) then
        branch "on_graft: symmetric, yes"
        yes p T fam c .both
      else branch "on_graft: symmetric, taken without an answer"
      joinPush p T fam c                                      -- and push_out: what we hold is announced
    else
      branch "on_graft: symmetric, no"
      no p T fam c .both
    return
  if gr.direction == .outward || gr.direction == .both then   -- p will push us colour c
    let asked := (← graftedInOf p T fam).contains c          -- the yes to our "push me", or one that crossed it
    discardColour graftedInOf setGraftedIn p T fam c
    if (← pushInOf p T fam).contains c then                   -- held: yes again, unless it answers ours or is a yes
      if !asked && !gr.answer then
        branch "on_graft: pushes to us held, yes again"
        yes p T fam c .inward
      else branch "on_graft: pushes to us held, no answer"
    else
      -- `len(in_pushers(T, fam, c)) < T.params.F_HI and wants_family(T, fam)`, left to right
      let ok ← if (← NodeSeacast.inPushers T fam c).length ≥ (← param T "F_HI" (·.F_HI)) then pure false
               else NodeSeacast.wantsFamily T fam
      if ok then
        setPushIn p T fam ((← pushInOf p T fam).insert c)     -- `push_in[p][T][fam].add(c)`
        if !asked then
          branch "on_graft: pushes to us, yes"
          yes p T fam c .inward                               -- yes: "push me"
        else branch "on_graft: pushes to us, taken without an answer"
      else
        branch "on_graft: pushes to us, no"
        no p T fam c .inward                                  -- no: "stop pushing me"
  if gr.direction == .inward || gr.direction == .both then    -- p asks us to push it colour c
    let asked := (← graftedOutOf p T fam).contains c         -- the yes to our "I will push you", or one that crossed it
    discardColour graftedOutOf setGraftedOut p T fam c
    if (← pushOutOf p T fam).contains c then                  -- held: yes again, unless it answers ours or is a yes
      if !asked && !gr.answer then
        branch "on_graft: our pushes held, yes again"
        yes p T fam c .outward
      else branch "on_graft: our pushes held, no answer"
    else
      -- `join_sent[p][T].duty == FORWARD and len(out_pushees(T, fam, c)) < T.params.D_OUT_MAX`, left to right
      let some j ← joinSent? p T | crash s!"KeyError: type {T} (on_graft: join_sent[p][T])"
      let ok ← if j.duty != .forward then pure false
               else do pure ((← NodeSeacast.outPushees T fam c).length < (← param T "D_OUT_MAX" (·.D_OUT_MAX)))
      if ok then
        if !asked then
          branch "on_graft: our pushes, yes"
          yes p T fam c .outward                              -- yes: "I will push you"
        else branch "on_graft: our pushes, taken without an answer"
        joinPush p T fam c                                    -- in the relation at our end: what we hold is announced
      else
        branch "on_graft: our pushes, no"
        no p T fam c .outward                                 -- no: "I will not push you"

/-- `maintain_relations(T)` (§4.1): at the heartbeat, per family we have duty in -/
def maintainRelations (T : TypeId) : M2 m Unit := do
  enter "maintain_relations"
  for fam in ← NodeSeacast.familiesWithDuty T do
    for c in List.range (← param T "M" (·.M)) do               -- `range(T.params.M)`: read once per family
      let ins ← NodeSeacast.inPushers T fam c
      if ← param T "SYMMETRIC" (·.SYMMETRIC) then            -- one relation both ways, kept as gossipsub keeps its mesh
        if ins.length < (← param T "F_LO" (·.F_LO)) then      -- below the floor, graft up to D_OUT
          let cs ← (← NodeSeacast.candidates T fam c .both).filterM fun q => relationRoom q T fam c
          let n : Int := ((← param T "D_OUT" (·.D_OUT) : Nat) : Int) - ins.length   -- `D_OUT - len(ins)`
          branch (if n ≥ 0 then "maintain_relations: below the floor"
                  else "maintain_relations: below the floor, a negative slice")
          for q in pyTake cs n do
            graft q T fam c .both
        else
          let fHi ← param T "F_HI" (·.F_HI)
          if ins.length ≥ fHi then                            -- at the cap, prune down to D_OUT, at random
            let dOut ← param T "D_OUT" (·.D_OUT)
            if ins.length < dOut then
              crash ("twin: sample_without_replacement of a negative count (F_HI below D_OUT), which its question " ++
                     "cannot carry")
            branch "maintain_relations: at the cap"
            for q in ← Node61.sample ins (ins.length - dOut) do
              prune q T fam c .both
        -- `half = set(in_pushers(T, fam, c)) ^ set(out_pushees(T, fam, c))`, in `sorted` order
        let a ← NodeSeacast.inPushers T fam c
        let b ← NodeSeacast.outPushees T fam c
        for q in (a.filter (!b.contains ·) ++ b.filter (!a.contains ·)).mergeSort (· ≤ ·) do
          -- `c not in grafted_in[q][T][fam] and c not in grafted_out[q][T][fam]`, left to right
          if (← graftedInOf q T fam).contains c then continue
          if (← graftedOutOf q T fam).contains c then continue
          branch "maintain_relations: a half-held relation grafted"
          graft q T fam c .both
        continue
      let fLo ← param T "F_LO" (·.F_LO)
      if ins.length < fLo then                                -- the floor per colour [D10]
        let cs ← (← NodeSeacast.candidates T fam c .inward).filterM fun q => relationRoom q T fam c
        branch "maintain_relations: below the floor, one way"
        for q in cs.take (fLo - ins.length) do                -- `cs[: T.params.F_LO - len(ins)]`, positive here
          graft q T fam c .inward                             -- "push me": counted once q says yes
      if ins.length > (← param T "F_HI" (·.F_HI)) then
        branch "maintain_relations: past the cap, one way"
        for q in ins.drop (← param T "F_HI" (·.F_HI)) do      -- `ins[T.params.F_HI:]`
          prune q T fam c .inward                             -- "stop pushing me"
      let outs ← NodeSeacast.outPushees T fam c
      -- `target = T.params.D_OUT_FAST if uplink_class() == FAST else T.params.D_OUT` [c17]
      let target ← if (← NodeSeacast.uplinkClass) == .fast then param T "D_OUT_FAST" (·.D_OUT_FAST)
                   else param T "D_OUT" (·.D_OUT)
      let cs ← (← NodeSeacast.candidates T fam c .outward).filterM fun q => relationRoom q T fam c
      for q in cs.take (target - outs.length) do              -- `cs[: max(0, target - len(outs))]`
        graft q T fam c .outward                              -- "I will push you": pushed once q says yes

/-- `on_join(p, j)` (§4.1) -/
def onJoin (p : Peer) (j : Join) : M2 m Unit := do
  enter "on_join"
  if !(← NodeSeacast.runsType j.objectType) then             -- §2: a type the node does not run: no state
    branch "on_join: a type the node does not run"
    return
  let T ← NodeSeacast.typeOf j.objectType
  if j.colours != (← param T "M" (·.M)) then                 -- no SEACAST for T on this link
    branch "on_join: colours not the type's"
    return
  setJoinRecv p T j                                           -- `join_recv[p][T] = j`
  if (← joinSent? p T).isNone then                            -- `T not in join_sent[p]`
    branch "on_join: answered"
    sendJoin p (← NodeSeacast.ourJoin T)
  else branch "on_join: ours went first"

end SpecTwin.Seacast
