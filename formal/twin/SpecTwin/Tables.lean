import SpecTwin.State

/-! # The twin's state, read and written entry by entry (generated)

This file is written whole by `tools/gen/gen.py` from `gen/schema.py` and `gen/schema_v2.py`, one
entry there per table, and `gen.py --check` compares it byte for byte. Do not edit it: change the schema,
or the generator.

§6.1's code reaches its state through this interface and in no other way: `Sec61.lean` is written over a monad
that has `Tables` and `Node61`, and no state of its own. One operation per table and kind of access: read an
entry, write it, or read a level as a whole.

`Tables.ofState` is the interface over the twin's `State`: each operation does its work on the state and notes
what it touched (`Touch`): the entry read or written, or the level read as a whole with the entries it held.
An access below a table's top level in a table that keeps its rows also notes the rows it went through
(`pass`), before its other notes. The replay collects the notes and compares them with what the Python read
and wrote (`Replay.lean`); it takes a pass as a read of each row only where the trace's header names the table
in `row_reads`, and as nothing otherwise. A proof's interpreter notes nothing.

The notes are this file's word for what its operations do. The replay does not take that word alone: it also
compares the twin's whole state after a call with the record's (`Replay.lean`, `wholeState`), and the mutants
of this file (`mutants3.py`, the `tables-` ones) show what that comparison sees in each kind of record. -/

namespace SpecTwin

/-- §6.1's own state (§8.1), as its code uses it. A missing entry reads as empty, and reading allocates nothing. -/
class Tables (m : Type → Type) where
  /-- `asked_at.get(a)` -/
  askedAt? : Key → m (Option Float)
  /-- `asked_at[a] = t` -/
  setAskedAt : Key → Float → m Unit
  /-- `asked_at.pop(a, None)` -/
  eraseAskedAt : Key → m Unit
  /-- `tried[a].get(p)` -/
  tried? : Key → Peer → m (Option Float)
  /-- `tried[a][p] = t` -/
  setTried : Key → Peer → Float → m Unit
  /-- `tried[a].pop(p)` -/
  eraseTried : Key → Peer → m Unit
  /-- `offers[a]` -/
  offersOf : Key → m (List Peer)
  /-- `offers[a] = o` -/
  setOffers : Key → List Peer → m Unit
  /-- `offers.pop(a, None)` -/
  eraseOffers : Key → m Unit
  /-- `promises.get((a, p))` -/
  promise? : Key → Peer → m (Option Float)
  /-- `promises[(a, p)] = t` -/
  setPromise : Key → Peer → Float → m Unit
  /-- `del promises[(a, p)]` -/
  erasePromise : Key → Peer → m Unit
  /-- every promise: `for (b, r) in promises` -/
  allPromises : m (List ((Key × Peer) × Float))
  /-- `offered[q][g]` -/
  offeredBits : Peer → Group → m Bits
  /-- `offered[q][g] = b` -/
  setOffered : Peer → Group → Bits → m Unit
  /-- `park[p].get(g)` -/
  parkUntil? : Peer → Group → m (Option Float)
  /-- `park[p][g] = t` -/
  setPark : Peer → Group → Float → m Unit
  /-- `park[p].pop(g, None)` -/
  erasePark : Peer → Group → m Unit
  /-- `asked_parked[k]` -/
  askedParkedOf : Chunk → m (Std.HashSet Peer)
  /-- `asked_parked[k] = s` -/
  setAskedParked : Chunk → Std.HashSet Peer → m Unit
  /-- `asked_parked.pop(k, None)` -/
  eraseAskedParked : Chunk → m Unit
  /-- `k in last_resort_armed` -/
  lrArmed? : Chunk → m Bool
  /-- `last_resort_armed.add(k)`, or `.discard(k)` -/
  setLrArmed : Chunk → Bool → m Unit
  /-- `ihave_frames[p]` -/
  ihaveFrames : Peer → m Nat
  /-- `ihave_frames[p] = n` -/
  setIhaveFrames : Peer → Nat → m Unit
  /-- `ihave_frames.clear()`: a write of every entry there -/
  clearIhaveFrames : m Unit
  /-- `ihave_asked[p]` -/
  ihaveAsked : Peer → m Nat
  /-- `ihave_asked[p] = n` -/
  setIhaveAsked : Peer → Nat → m Unit
  /-- `ihave_asked.clear()`: a write of every entry there -/
  clearIhaveAsked : m Unit
  /-- `held_back.get(k)` -/
  heldBack? : Chunk → m (Option Key)
  /-- `held_back[k] = a` -/
  setHeldBack : Chunk → Key → m Unit
  /-- `held_back.clear()`: a write of every entry there -/
  clearHeldBack : m Unit
  /-- every `held_back`: `held_back.values()` -/
  allHeldBack : m (List (Chunk × Key))
  /-- `received[g]` -/
  receivedBits : Group → m Bits
  /-- `received[g] = b` -/
  setReceived : Group → Bits → m Unit
  /-- `mine[g]` -/
  mineBits : Group → m Bits
  /-- `mine[g] = b` -/
  setMine : Group → Bits → m Unit
  /-- `state[g]` -/
  state? : Group → m (Option GroupState)
  /-- `state[g] = st` -/
  setState : Group → GroupState → m Unit
  /-- `tied[r][p].get(g)` -/
  tied? : Root → Peer → Group → m (Option Bits)
  /-- `tied[r][p][g] = b` -/
  setTied : Root → Peer → Group → Bits → m Unit
  /-- `tied[r][p].pop(g)` -/
  eraseTied : Root → Peer → Group → m Unit
  /-- `r in tied`: the row there -/
  tiedRow? : Root → m Bool
  /-- `tied.pop(r, ...)`: the row and all under it -/
  eraseTiedRow : Root → m Unit
  /-- `p in tied[r]`: the row there -/
  tiedPeerRow? : Root → Peer → m Bool
  /-- `tied[r].pop(p, ...)`: the row and all under it -/
  eraseTiedPeerRow : Root → Peer → m Unit
  /-- every `tied` -/
  allTiedAll : m (List (Root × List (Peer × List (Group × Bits))))
  /-- every `tied[r]` -/
  allTiedRoot : Root → m (List (Peer × List (Group × Bits)))
  /-- every `tied[r][p]` -/
  allTiedPeer : Root → Peer → m (List (Group × Bits))
  /-- `queue[p].normal`, or `queue[p].urgent` -/
  lane? : Peer → Lane → m (Option (List QEntry))
  /-- a lane after the writer's pop -/
  setLane : Peer → Lane → List QEntry → m Unit
  /-- a lane assigned empty to a queue that is not there: it stays missing, no row made -/
  eraseLane : Peer → Lane → m Unit
  /-- every `queue[p]`: `list(queue)` -/
  allQueue : m (List (Peer × List (Lane × List QEntry)))
  /-- `pending[root]` -/
  pendingOf : Root → m (List (Peer × ChunkF))
  /-- `pending[root] = w` -/
  setPending : Root → List (Peer × ChunkF) → m Unit
  /-- `pending.pop(root, None)`, `del pending[root]` -/
  erasePending : Root → m Unit
  /-- every `pending`: `list(pending)` -/
  allPending : m (List (Root × List (Peer × ChunkF)))
  /-- `mid in pending_ids` -/
  pendingId? : Key → m Bool
  /-- `pending_ids.add(mid)`, or `.discard(mid)` -/
  setPendingId : Key → Bool → m Unit
  /-- `tie_slot.get((root, p))` -/
  tieSlot? : Root → Peer → m (Option Nat)
  /-- `tie_slot[(root, p)] = s` -/
  setTieSlot : Root → Peer → Nat → m Unit
  /-- `tie_slot.pop((root, p), None)` -/
  eraseTieSlot : Root → Peer → m Unit
  /-- every `tie_slot`: `list(tie_slot.items())` -/
  allTieSlot : m (List ((Root × Peer) × Nat))
  /-- `owed[p].get(g)` -/
  owed? : Peer → Group → m (Option Bits)
  /-- `owed[p][g] = b` -/
  setOwed : Peer → Group → Bits → m Unit
  /-- `owed[p].pop(g)` -/
  eraseOwed : Peer → Group → m Unit
  /-- `p in owed`: the row there -/
  owedRow? : Peer → m Bool
  /-- `owed.pop(p)`: the row and all under it -/
  eraseOwedRow : Peer → m Unit
  /-- every `owed[p]`: `if owed[p]`, `list(owed[p])` -/
  allOwed : Peer → m (List (Group × Bits))
  /-- `owed_answers[p][g]` -/
  owedAnswerBits : Peer → Group → m Bits
  /-- `owed_answers[p][g] = b` -/
  setOwedAnswers : Peer → Group → Bits → m Unit
  /-- every `owed_answers[p]`: `if owed_answers[p]` -/
  allOwedAnswers : Peer → m (List (Group × Bits))
  /-- `sent_to[p][g]` -/
  sentToBits : Peer → Group → m Bits
  /-- `sent_to[p][g] = b` -/
  setSentTo : Peer → Group → Bits → m Unit
  /-- `slot_held[p]` -/
  slotHeld? : Peer → m Bool
  /-- `slot_held[p] = True`, or `= False` -/
  setSlotHeld : Peer → Bool → m Unit
  /-- `pace_queue`, the jobs in order -/
  paceJobs : PaceKey → m (List Job)
  /-- `pace_queue` after an append or a pop -/
  setPaceJobs : PaceKey → List Job → m Unit
  /-- `stop_pull[g]` -/
  stopPull : Group → m Bool
  /-- `stop_pull[g] = True` -/
  setStopPull : Group → Bool → m Unit
  /-- `peer_has[p][g]`: the entry, or none where p sent no HAVE for g -/
  peerHasEntry? : Peer → Group → m (Option HaveEntry)
  /-- `peer_has[p][g]`'s bits and ttl set -/
  setPeerHas : Peer → Group → HaveEntry → m Unit
  /-- `holders[g][i]` -/
  holdersOf : Group → Nat → m (Std.HashSet Peer)
  /-- `holders[g][i] = s` -/
  setHolders : Group → Nat → Std.HashSet Peer → m Unit
  /-- `serve_count[p][mid]` -/
  serveCount : Peer → Key → m Nat
  /-- `serve_count[p][mid] = n` -/
  setServeCount : Peer → Key → Nat → m Unit
  /-- `origin[g]`, as `g in origin` or `origin[g]`: the bitmap, or none where g is not there -/
  origin : Group → m (Option Bits)
  /-- `origin[g] = b`, `origin[g].set(i)` -/
  setOrigin : Group → Bits → m Unit
  /-- `planned[g].get(i)`: the peers chosen for chunk i, or none where i has no entry -/
  plannedTargets? : Group → Nat → m (Option (Std.HashSet Peer))
  /-- `planned[g][i] = set(targets)` -/
  setPlanned : Group → Nat → Std.HashSet Peer → m Unit
  /-- `g in planned`: the row there -/
  planned : Group → m Bool
  /-- the row and all under it -/
  erasePlannedRow : Group → m Unit
  /-- `pushed[p][g]`: the entry, or none where nothing was pushed p of g -/
  pushedEntry? : Peer → Group → m (Option PushEntry)
  /-- `pushed[p][g]`'s bits, clock and ttl set -/
  setPushed : Peer → Group → PushEntry → m Unit
  /-- `desc[g]`, as `g in desc` or `desc[g]`: the group's descriptor, or none where it is not there -/
  desc : Group → m (Option Descriptor)
  /-- `desc[g] = d` -/
  setDesc : Group → Descriptor → m Unit
  /-- `in_flight`, the slots in use -/
  inFlight : CountKey → m Int
  /-- `in_flight += 1`, `in_flight -= 1` -/
  setInFlight : CountKey → Int → m Unit
  /-- `waiters`, the peers in line, in order -/
  waitersLine : LineKey → m (List Peer)
  /-- `waiters` after a popleft, an append or a remove -/
  setWaitersLine : LineKey → List Peer → m Unit
  /-- `sent.get(key)`, `key in sent` -/
  sentAt? : SendKey → m (Option Float)
  /-- `sent[key] = now` -/
  setSentAt : SendKey → Float → m Unit
  /-- `del sent[key]`, `sent.pop(key)` -/
  eraseSentAt : SendKey → m Unit
  /-- `unwanted[p]`: the ids p said it does not want -/
  unwantedOf : Peer → m (Std.HashSet Hex)
  /-- `unwanted[p].add(h)` -/
  setUnwanted : Peer → Std.HashSet Hex → m Unit
  /-- `join_recv[p][T]`: what p declared to us, or none (a KeyError in the Python) -/
  joinRecv? : Peer → V2.TypeId → m (Option V2.Join)
  /-- `join_recv[p][T] = j` -/
  setJoinRecv : Peer → V2.TypeId → V2.Join → m Unit
  /-- `join_sent[p][T]`: what we declared to p, or none (a KeyError in the Python) -/
  joinSent? : Peer → V2.TypeId → m (Option V2.Join)
  /-- `join_sent[p][T] = j` -/
  setJoinSent : Peer → V2.TypeId → V2.Join → m Unit
  /-- `push_out[p][T][fam]`: the colours we push p -/
  pushOutOf : Peer → V2.TypeId → V2.Fam → m (Std.HashSet Nat)
  /-- `push_out[p][T][fam].add(c)`, `.discard(c)` -/
  setPushOut : Peer → V2.TypeId → V2.Fam → Std.HashSet Nat → m Unit
  /-- `push_in[p][T][fam]`: the colours p pushes us -/
  pushInOf : Peer → V2.TypeId → V2.Fam → m (Std.HashSet Nat)
  /-- `push_in[p][T][fam].add(c)`, `.discard(c)` -/
  setPushIn : Peer → V2.TypeId → V2.Fam → Std.HashSet Nat → m Unit
  /-- `grafted_out[p][T][fam]`: the colours we offered to push p, unanswered -/
  graftedOutOf : Peer → V2.TypeId → V2.Fam → m (Std.HashSet Nat)
  /-- `grafted_out[p][T][fam].add(c)`, `.discard(c)` -/
  setGraftedOut : Peer → V2.TypeId → V2.Fam → Std.HashSet Nat → m Unit
  /-- `grafted_in[p][T][fam]`: the colours we asked p to push us, unanswered -/
  graftedInOf : Peer → V2.TypeId → V2.Fam → m (Std.HashSet Nat)
  /-- `grafted_in[p][T][fam].add(c)`, `.discard(c)` -/
  setGraftedIn : Peer → V2.TypeId → V2.Fam → Std.HashSet Nat → m Unit
  /-- `owed_relations[p]`: the JOINs, GRAFTs and PRUNEs a full queue refused, in order -/
  owedRelationsOf : Peer → m (List V2.Relation)
  /-- `owed_relations[p]` after an append or a `pop(0)` -/
  setOwedRelations : Peer → List V2.Relation → m Unit
  /-- `backoff[p][T][fam].get((c, direction))`: until when we do not graft p, or none -/
  backoff? : Peer → V2.TypeId → V2.Fam → ColourDir → m (Option Float)
  /-- `backoff[p][T][fam][(c, direction)] = t` -/
  setBackoff : Peer → V2.TypeId → V2.Fam → ColourDir → Float → m Unit
  /-- `T_of[g]`, as `g in T_of` or `T_of[g]`: the group's type, or none -/
  tOf? : Group → m (Option V2.TypeId)
  /-- `T_of[g] = T` -/
  setTOf : Group → V2.TypeId → m Unit
  /-- `rebuilt[g]`: the chunks from a decode -/
  rebuiltBits : Group → m Bits
  /-- `rebuilt[g].set(i)`, `|=` -/
  setRebuilt : Group → Bits → m Unit
  /-- `interest[g]` where it is stored, or none (the Python then asks `own_interest(g)`) -/
  interest? : Group → m (Option V2.IBits)
  /-- `interest[g] = b`, `interest[g] |= b` -/
  setInterest : Group → V2.IBits → m Unit
  /-- `known_at[g]`, `known_at.setdefault(g, now)`: when the group id became known, or none -/
  knownAt? : Group → m (Option Float)
  /-- `known_at[g] = t`, `known_at.setdefault(g, now)` where it is missing -/
  setKnownAt : Group → Float → m Unit
  /-- `standing[g][i]`, as `standing[g].pop(i, ())` reads it: the peers, or none -/
  standing? : Group → Nat → m (Option (Std.HashSet Peer))
  /-- `standing[g][i].add(q)` -/
  setStanding : Group → Nat → Std.HashSet Peer → m Unit
  /-- `standing[g].pop(i, ())` where the entry is there -/
  eraseStanding : Group → Nat → m Unit
  /-- `claims[g]`: the peers whose claim_all arrived, or none where the group has no entry -/
  claims? : Group → m (Option (Std.HashSet Peer))
  /-- `claims[g].add(q)`, `claims[g].discard(q)`: the entry stays, empty or not -/
  setClaims : Group → Std.HashSet Peer → m Unit
  /-- every `claims`: `claims.items()` -/
  allClaims : m (List (Group × Std.HashSet Peer))
  /-- `reconsider_at.get(g)`: when our later decode duty fires, or none -/
  reconsiderAt? : Group → m (Option Float)
  /-- `reconsider_at[g] = at` -/
  setReconsiderAt : Group → Float → m Unit
  /-- `del reconsider_at[g]` -/
  eraseReconsiderAt : Group → m Unit
  /-- `deferred[g]` -/
  deferred? : Group → m Bool
  /-- `deferred[g] = True`, or `= False` -/
  setDeferred : Group → Bool → m Unit
  /-- `duty_at[g]`, `duty_at.get(g, now)`: the duty's own time, or none -/
  dutyAt? : Group → m (Option Float)
  /-- `duty_at[g] = t` -/
  setDutyAt : Group → Float → m Unit
  /-- `waited[g]` -/
  waited? : Group → m Bool
  /-- `waited[g] = True`, or `= False` -/
  setWaited : Group → Bool → m Unit
  /-- `probe[g]`: the index we asked a claimant for, or none -/
  probe? : Group → m (Option Nat)
  /-- `probe[g] = i` -/
  setProbe : Group → Nat → m Unit
  /-- `probed[g]`, `probed.get(g)`: the claimant we asked, or none -/
  probed? : Group → m (Option Nat)
  /-- `probed[g] = q` -/
  setProbed : Group → Nat → m Unit
  /-- `a in probe_asks` -/
  probeAsk? : Key → m Bool
  /-- `probe_asks.add(a)`, or `.discard(a)` -/
  setProbeAsk : Key → Bool → m Unit
  /-- `g in probe_sent` -/
  probeSent? : Group → m Bool
  /-- `probe_sent.add(g)`, or `.discard(g)` -/
  setProbeSent : Group → Bool → m Unit
  /-- `probe_ok[g]`, as `g in probe_ok` or `probe_ok[g]`: the verdict (a stored None too), or none -/
  probeOk? : Group → m (Option (Option Bool))
  /-- `probe_ok[g] = v` -/
  setProbeOk : Group → Option Bool → m Unit
  /-- `rsample[g]`: the repair sample's indices, in order -/
  rsampleOf : Group → m (List Nat)
  /-- `rsample[g].append(i)` -/
  setRsample : Group → List Nat → m Unit
  /-- `rsample_step[g]` -/
  rsampleStep : Group → m Nat
  /-- `rsample_step[g] = n` -/
  setRsampleStep : Group → Nat → m Unit
  /-- `rsample_asked[g][i]`: the custodians a sampled cell was asked of -/
  rsampleAskedOf : Group → Nat → m (Std.HashSet Peer)
  /-- `rsample_asked[g][i].add(q)` -/
  setRsampleAsked : Group → Nat → Std.HashSet Peer → m Unit
  /-- `rsample_final[g]` -/
  rsampleFinal? : Group → m Bool
  /-- `rsample_final[g] = True`, or `= False` -/
  setRsampleFinal : Group → Bool → m Unit
  /-- `served[p][g]`: the chunks answered -/
  servedCount : Peer → Group → m Nat
  /-- `served[p][g] += 1` -/
  setServed : Peer → Group → Nat → m Unit
  /-- `want_p[p].get(g)`: what p asked us for, or none (`EMPTY` in the Python) -/
  wantP? : Peer → Group → m (Option V2.IBits)
  /-- `want_p[p][g] = b` -/
  setWantP : Peer → Group → V2.IBits → m Unit
  /-- `probe_served[p][g]` -/
  probeServed : Peer → Group → m Bool
  /-- `probe_served[p][g] = True` -/
  setProbeServed : Peer → Group → Bool → m Unit
  /-- `probe_answers[p][g]` -/
  probeAnswerBits : Peer → Group → m Bits
  /-- `probe_answers[p][g].set(i)`, `.clear()` -/
  setProbeAnswers : Peer → Group → Bits → m Unit
  /-- `probe_waiting[g][p]`: p's first marked ask of the group, or none -/
  probeWaiting? : Group → Peer → m (Option Nat)
  /-- `probe_waiting[g][p] = i` -/
  setProbeWaiting : Group → Peer → Nat → m Unit
  /-- `del probe_waiting[g][p]` -/
  eraseProbeWaiting : Group → Peer → m Unit
  /-- every `probe_waiting[g]`: `probe_waiting[g].items()` -/
  allProbeWaiting : Group → m (List (Peer × Nat))
  /-- `sampled_from[b]`: the peers asked for a sample of the block -/
  sampledFromOf : BlockId → m (Std.HashSet Peer)
  /-- `sampled_from[b].add(q)` -/
  setSampledFrom : BlockId → Std.HashSet Peer → m Unit
  /-- `samples_in_flight[b]`: our second-phase sample asks in flight -/
  samplesInFlight : BlockId → m Int
  /-- `samples_in_flight[b] += 1`, `-= 1` -/
  setSamplesInFlight : BlockId → Int → m Unit
  /-- `held_samples[b]`: second-phase asks waiting for room, in order -/
  heldSamplesOf : BlockId → m (List GI)
  /-- `held_samples[b]` after an append or a `pop(0)` -/
  setHeldSamples : BlockId → List GI → m Unit
  /-- `forwarded[p]`: routed requests from p passed on this slot -/
  forwardedCount : Peer → m Nat
  /-- `forwarded[p] += 1` -/
  setForwarded : Peer → Nat → m Unit
  -- The levels §6.1's code never reads as a whole. They are here so that a twin that does, a mutant, can be
  -- written, and is then seen to.
  /-- every `asked_at` -/
  allAskedAt : m (List (Key × Float))
  /-- every `tried`, under every key -/
  allTriedAll : m (List (Key × List (Peer × Float)))
  /-- every `tried[a]` -/
  allTried : Key → m (List (Peer × Float))
  /-- every offer list -/
  allOffers : m (List (Key × List Peer))
  /-- every `offered`, of every peer -/
  allOfferedAll : m (List (Peer × List (Group × Bits)))
  /-- every `offered[q]` -/
  allOffered : Peer → m (List (Group × Bits))
  /-- every `park`, of every peer -/
  allParkAll : m (List (Peer × List (Group × Float)))
  /-- every `park[p]` -/
  allPark : Peer → m (List (Group × Float))
  /-- every `asked_parked` -/
  allAskedParked : m (List (Chunk × Std.HashSet Peer))
  /-- every member of `last_resort_armed` -/
  allLrArmed : m (List Chunk)
  /-- every `ihave_frames` -/
  allIhaveFrames : m (List (Peer × Nat))
  /-- every `ihave_asked` -/
  allIhaveAsked : m (List (Peer × Nat))
  /-- every `received` -/
  allReceived : m (List (Group × Bits))
  /-- every `mine` -/
  allMine : m (List (Group × Bits))
  /-- every `state` -/
  allState : m (List (Group × GroupState))
  /-- every member of `pending_ids` -/
  allPendingIds : m (List Key)
  /-- every `owed` -/
  allOwedAll : m (List (Peer × List (Group × Bits)))
  /-- every `owed_answers` -/
  allOwedAnswersAll : m (List (Peer × List (Group × Bits)))
  /-- every `sent_to` -/
  allSentToAll : m (List (Peer × List (Group × Bits)))
  /-- every peer whose writer holds a slot -/
  allSlotHeld : m (List Peer)
  /-- the pace queue's one entry -/
  allPaceQueue : m (List (PaceKey × List Job))
  /-- every group stopped -/
  allStopPull : m (List Group)
  /-- every `peer_has` -/
  allPeerHas : m (List (Peer × List (Group × HaveEntry)))
  /-- every `holders` -/
  allHolders : m (List (Group × List (Nat × Std.HashSet Peer)))
  /-- every `serve_count` -/
  allServeCount : m (List (Peer × List (Key × Nat)))
  /-- every `origin` -/
  allOrigin : m (List (Group × Bits))
  /-- every `planned` -/
  allPlannedAll : m (List (Group × List (Nat × Std.HashSet Peer)))
  /-- every `pushed` -/
  allPushed : m (List (Peer × List (Group × PushEntry)))
  /-- every `desc` -/
  allDesc : m (List (Group × Descriptor))
  /-- the window's count's one entry -/
  allInFlight : m (List (CountKey × Int))
  /-- the line's one entry -/
  allWaiters : m (List (LineKey × List Peer))
  /-- every `sent` -/
  allSent : m (List (SendKey × Float))
  /-- every `unwanted` -/
  allUnwanted : m (List (Peer × Std.HashSet Hex))
  /-- every `join_recv` -/
  allJoinRecvAll : m (List (Peer × List (V2.TypeId × V2.Join)))
  /-- every `join_sent` -/
  allJoinSentAll : m (List (Peer × List (V2.TypeId × V2.Join)))
  /-- every `push_out` -/
  allPushOutAll : m (List (Peer × List (V2.TypeId × List (V2.Fam × Std.HashSet Nat))))
  /-- every `push_in` -/
  allPushInAll : m (List (Peer × List (V2.TypeId × List (V2.Fam × Std.HashSet Nat))))
  /-- every `grafted_out` -/
  allGraftedOutAll : m (List (Peer × List (V2.TypeId × List (V2.Fam × Std.HashSet Nat))))
  /-- every `grafted_in` -/
  allGraftedInAll : m (List (Peer × List (V2.TypeId × List (V2.Fam × Std.HashSet Nat))))
  /-- every `owed_relations` -/
  allOwedRelations : m (List (Peer × List V2.Relation))
  /-- every `backoff` -/
  allBackoffAll : m (List (Peer × List (V2.TypeId × List (V2.Fam × List (ColourDir × Float)))))
  /-- every `T_of` -/
  allTOf : m (List (Group × V2.TypeId))
  /-- every `rebuilt` -/
  allRebuilt : m (List (Group × Bits))
  /-- every `interest` -/
  allInterest : m (List (Group × V2.IBits))
  /-- every `known_at` -/
  allKnownAt : m (List (Group × Float))
  /-- every `standing` -/
  allStandingAll : m (List (Group × List (Nat × Std.HashSet Peer)))
  /-- every `reconsider_at` -/
  allReconsiderAt : m (List (Group × Float))
  /-- every group deferred once on a claim -/
  allDeferred : m (List Group)
  /-- every `duty_at` -/
  allDutyAt : m (List (Group × Float))
  /-- every group waited for once -/
  allWaited : m (List Group)
  /-- every `probe` -/
  allProbe : m (List (Group × Nat))
  /-- every `probed` -/
  allProbed : m (List (Group × Nat))
  /-- every member of `probe_asks` -/
  allProbeAsk : m (List Key)
  /-- every member of `probe_sent` -/
  allProbeSent : m (List Group)
  /-- every `probe_ok` -/
  allProbeOk : m (List (Group × Option Bool))
  /-- every `rsample` -/
  allRsample : m (List (Group × List Nat))
  /-- every `rsample_step` -/
  allRsampleStep : m (List (Group × Nat))
  /-- every `rsample_asked` -/
  allRsampleAskedAll : m (List (Group × List (Nat × Std.HashSet Peer)))
  /-- every group whose last step's re-asks were waited for -/
  allRsampleFinal : m (List Group)
  /-- every `served` -/
  allServedAll : m (List (Peer × List (Group × Nat)))
  /-- every `want_p` -/
  allWantPAll : m (List (Peer × List (Group × V2.IBits)))
  /-- every `probe_served` -/
  allProbeServedAll : m (List (Peer × List (Group × Bool)))
  /-- every `probe_answers` -/
  allProbeAnswersAll : m (List (Peer × List (Group × Bits)))
  /-- every `probe_waiting` -/
  allProbeWaitingAll : m (List (Group × List (Peer × Nat)))
  /-- every `sampled_from` -/
  allSampledFrom : m (List (BlockId × Std.HashSet Peer))
  /-- every `samples_in_flight` -/
  allSamplesInFlight : m (List (BlockId × Int))
  /-- every `held_samples` -/
  allHeldSamples : m (List (BlockId × List GI))
  /-- every `forwarded` -/
  allForwarded : m (List (Peer × Nat))

namespace Tables

/-- The interface over the twin's `State`, with a note of each access. -/
@[instance_reducible]
def ofState {m : Type → Type} [Monad m] [MonadStateOf State m] (note : Touch → m Unit) : Tables m where
  askedAt? a := do note (.read (.askedAt a)); return (← get).askedAt.get? a
  setAskedAt a t := do note (.write (.askedAt a)); modify fun s => { s with askedAt := s.askedAt.insert a t }
  eraseAskedAt a := do note (.write (.askedAt a)); modify fun s => { s with askedAt := s.askedAt.erase a }
  tried? a p := do note (.read (.tried a p)); return ((← get).tried.getD a {}).get? p
  setTried a p t := do
    note (.write (.tried a p))
    modify fun s => { s with tried := s.tried.insert a ((s.tried.getD a {}).insert p t) }
  eraseTried a p := do
    note (.write (.tried a p))
    modify fun s => { s with tried := s.tried.insert a ((s.tried.getD a {}).erase p) }
  offersOf a := do note (.read (.offers a)); return (← get).offers.getD a []
  setOffers a o := do note (.write (.offers a)); modify fun s => { s with offers := s.offers.insert a o }
  eraseOffers a := do note (.write (.offers a)); modify fun s => { s with offers := s.offers.erase a }
  promise? a p := do note (.read (.promise a p)); return (← get).promises.get? (a, p)
  setPromise a p t := do note (.write (.promise a p)); modify fun s => { s with promises := s.promises.insert (a, p) t }
  erasePromise a p := do note (.write (.promise a p)); modify fun s => { s with promises := s.promises.erase (a, p) }
  allPromises := do
    let l := (← get).promises.toList
    note (.scan .promises (l.map fun ((a, p), _) => .promise a p))
    return l
  offeredBits q g := do note (.read (.offered q g)); return ((← get).offered.getD q {}).getD g 0
  setOffered q g b := do
    note (.write (.offered q g))
    modify fun s => { s with offered := s.offered.insert q ((s.offered.getD q {}).insert g b) }
  parkUntil? p g := do note (.read (.park p g)); return ((← get).park.getD p {}).get? g
  setPark p g t := do
    note (.write (.park p g))
    modify fun s => { s with park := s.park.insert p ((s.park.getD p {}).insert g t) }
  erasePark p g := do
    note (.write (.park p g))
    modify fun s => { s with park := s.park.insert p ((s.park.getD p {}).erase g) }
  askedParkedOf k := do note (.read (.askedParked k)); return (← get).askedParked.getD k {}
  setAskedParked k ps := do
    note (.write (.askedParked k))
    modify fun s => { s with askedParked := s.askedParked.insert k ps }
  eraseAskedParked k := do
    note (.write (.askedParked k))
    modify fun s => { s with askedParked := s.askedParked.erase k }
  lrArmed? k := do note (.read (.lrArmed k)); return (← get).lastResortArmed.contains k
  setLrArmed k armed := do
    note (.write (.lrArmed k))
    modify fun s => { s with
      lastResortArmed := if armed then s.lastResortArmed.insert k else s.lastResortArmed.erase k }
  ihaveFrames p := do note (.read (.ihaveFrames p)); return (← get).ihaveFrames.getD p 0
  setIhaveFrames p n := do
    note (.write (.ihaveFrames p))
    modify fun s => { s with ihaveFrames := s.ihaveFrames.insert p n }
  clearIhaveFrames := do
    for (p, _) in (← get).ihaveFrames.toList do note (.write (.ihaveFrames p))
    modify fun s => { s with ihaveFrames := {} }
  ihaveAsked p := do note (.read (.ihaveAsked p)); return (← get).ihaveAsked.getD p 0
  setIhaveAsked p n := do
    note (.write (.ihaveAsked p))
    modify fun s => { s with ihaveAsked := s.ihaveAsked.insert p n }
  clearIhaveAsked := do
    for (p, _) in (← get).ihaveAsked.toList do note (.write (.ihaveAsked p))
    modify fun s => { s with ihaveAsked := {} }
  heldBack? k := do note (.read (.heldBack k)); return (← get).heldBack.get? k
  setHeldBack k a := do note (.write (.heldBack k)); modify fun s => { s with heldBack := s.heldBack.insert k a }
  clearHeldBack := do
    for (k, _) in (← get).heldBack.toList do note (.write (.heldBack k))
    modify fun s => { s with heldBack := {} }
  allHeldBack := do
    let l := (← get).heldBack.toList
    note (.scan .heldBack (l.map fun (k, _) => .heldBack k))
    return l
  receivedBits g := do note (.read (.received g)); return (← get).received.getD g 0
  setReceived g b := do note (.write (.received g)); modify fun s => { s with received := s.received.insert g b }
  mineBits g := do note (.read (.mine g)); return (← get).mine.getD g 0
  setMine g b := do note (.write (.mine g)); modify fun s => { s with mine := s.mine.insert g b }
  state? g := do note (.read (.state g)); return (← get).state.get? g
  setState g st := do note (.write (.state g)); modify fun s => { s with state := s.state.insert g st }
  tied? r p g := do
    note (.pass "tied" [.tiedRow r, .tiedPeerRow r p])
    note (.read (.tied r p g))
    return (((← get).tied.getD r {}).getD p {}).get? g
  setTied r p g b := do
    note (.pass "tied" [.tiedRow r, .tiedPeerRow r p])
    let s ← get
    if !s.tied.contains r then note (.write (.tiedRow r))
    if !(s.tied.getD r {}).contains p then note (.write (.tiedPeerRow r p))
    note (.write (.tied r p g))
    modify fun s => { s with
      tied := s.tied.insert r ((s.tied.getD r {}).insert p (((s.tied.getD r {}).getD p {}).insert g b)) }
  eraseTied r p g := do
    note (.pass "tied" [.tiedRow r, .tiedPeerRow r p])
    note (.write (.tied r p g))
    modify fun s => { s with tied := s.tied.modify r (·.modify p (·.erase g)) }
  tiedRow? r := do note (.read (.tiedRow r)); return (← get).tied.contains r
  eraseTiedRow r := do
    let l := ((← get).tied.getD r {}).toList.map fun (p, m) => (p, m.toList)
    note (.write (.tiedRow r))
    for c in l.flatMap fun (p, gs) => .tiedPeerRow r p :: gs.map fun (g, _) => .tied r p g do note (.write c)
    modify fun s => { s with tied := s.tied.erase r }
  tiedPeerRow? r p := do
    note (.pass "tied" [.tiedRow r])
    note (.read (.tiedPeerRow r p))
    return ((← get).tied.getD r {}).contains p
  eraseTiedPeerRow r p := do
    note (.pass "tied" [.tiedRow r])
    let l := (((← get).tied.getD r {}).getD p {}).toList
    note (.write (.tiedPeerRow r p))
    for c in l.map fun (g, _) => .tied r p g do note (.write c)
    modify fun s => { s with tied := s.tied.modify r (·.erase p) }
  allTiedAll := do
    let l := (← get).tied.toList.map fun (r, m) => (r, m.toList.map fun (p, m) => (p, m.toList))
    note (.scan .tiedAll (l.flatMap fun (r, ps) => .tiedRow r :: ps.flatMap fun (p, gs) => .tiedPeerRow r p :: gs.map fun (g, _) => .tied r p g))
    return l
  allTiedRoot r := do
    note (.pass "tied" [.tiedRow r])
    let l := ((← get).tied.getD r {}).toList.map fun (p, m) => (p, m.toList)
    note (.scan (.tiedRoot r) (l.flatMap fun (p, gs) => .tiedPeerRow r p :: gs.map fun (g, _) => .tied r p g))
    return l
  allTiedPeer r p := do
    note (.pass "tied" [.tiedRow r, .tiedPeerRow r p])
    let l := (((← get).tied.getD r {}).getD p {}).toList
    note (.scan (.tiedPeer r p) (l.map fun (g, _) => .tied r p g))
    return l
  lane? p l := do
    note (.pass "queue" [.queueRow p])
    note (.read (.queue p l))
    return ((← get).queue.getD p {}).get? l
  setLane p l es := do
    note (.pass "queue" [.queueRow p])
    let s ← get
    if !s.queue.contains p then note (.write (.queueRow p))
    note (.write (.queue p l))
    modify fun s => { s with queue := s.queue.insert p ((s.queue.getD p {}).insert l es) }
  eraseLane p l := do
    note (.pass "queue" [.queueRow p])
    note (.write (.queue p l))
    modify fun s => { s with queue := s.queue.modify p (·.erase l) }
  allQueue := do
    let l := (← get).queue.toList.map fun (p, m) => (p, m.toList)
    note (.scan .queueAll (l.flatMap fun (p, ls) => .queueRow p :: ls.map fun (l, _) => .queue p l))
    return l
  pendingOf r := do note (.read (.pending r)); return (← get).pending.getD r []
  setPending r w := do note (.write (.pending r)); modify fun s => { s with pending := s.pending.insert r w }
  erasePending r := do note (.write (.pending r)); modify fun s => { s with pending := s.pending.erase r }
  allPending := do
    let l := (← get).pending.toList
    note (.scan .pending (l.map fun (r, _) => .pending r))
    return l
  pendingId? m := do note (.read (.pendingId m)); return (← get).pendingIds.contains m
  setPendingId m armed := do
    note (.write (.pendingId m))
    modify fun s => { s with
      pendingIds := if armed then s.pendingIds.insert m else s.pendingIds.erase m }
  tieSlot? r p := do note (.read (.tieSlot r p)); return (← get).tieSlot.get? (r, p)
  setTieSlot r p sl := do note (.write (.tieSlot r p)); modify fun s => { s with tieSlot := s.tieSlot.insert (r, p) sl }
  eraseTieSlot r p := do note (.write (.tieSlot r p)); modify fun s => { s with tieSlot := s.tieSlot.erase (r, p) }
  allTieSlot := do
    let l := (← get).tieSlot.toList
    note (.scan .tieSlot (l.map fun ((r, p), _) => .tieSlot r p))
    return l
  owed? p g := do
    note (.pass "owed" [.owedRow p])
    note (.read (.owed p g))
    return ((← get).owed.getD p {}).get? g
  setOwed p g b := do
    note (.pass "owed" [.owedRow p])
    let s ← get
    if !s.owed.contains p then note (.write (.owedRow p))
    note (.write (.owed p g))
    modify fun s => { s with owed := s.owed.insert p ((s.owed.getD p {}).insert g b) }
  eraseOwed p g := do
    note (.pass "owed" [.owedRow p])
    note (.write (.owed p g))
    modify fun s => { s with owed := s.owed.modify p (·.erase g) }
  owedRow? p := do note (.read (.owedRow p)); return (← get).owed.contains p
  eraseOwedRow p := do
    let l := ((← get).owed.getD p {}).toList
    note (.write (.owedRow p))
    for c in l.map fun (g, _) => .owed p g do note (.write c)
    modify fun s => { s with owed := s.owed.erase p }
  allOwed p := do
    note (.pass "owed" [.owedRow p])
    let l := ((← get).owed.getD p {}).toList
    note (.scan (.owed p) (l.map fun (g, _) => .owed p g))
    return l
  owedAnswerBits p g := do note (.read (.owedAnswers p g)); return ((← get).owedAnswers.getD p {}).getD g 0
  setOwedAnswers p g b := do
    note (.write (.owedAnswers p g))
    modify fun s => { s with owedAnswers := s.owedAnswers.insert p ((s.owedAnswers.getD p {}).insert g b) }
  allOwedAnswers p := do
    let l := ((← get).owedAnswers.getD p {}).toList
    note (.scan (.owedAnswers p) (l.map fun (g, _) => .owedAnswers p g))
    return l
  sentToBits p g := do note (.read (.sentTo p g)); return ((← get).sentTo.getD p {}).getD g 0
  setSentTo p g b := do
    note (.write (.sentTo p g))
    modify fun s => { s with sentTo := s.sentTo.insert p ((s.sentTo.getD p {}).insert g b) }
  slotHeld? p := do note (.read (.slotHeld p)); return (← get).slotHeld.contains p
  setSlotHeld p armed := do
    note (.write (.slotHeld p))
    modify fun s => { s with
      slotHeld := if armed then s.slotHeld.insert p else s.slotHeld.erase p }
  paceJobs e := do note (.read (.paceQueue e)); return (← get).paceQueue.getD e []
  setPaceJobs e js := do note (.write (.paceQueue e)); modify fun s => { s with paceQueue := s.paceQueue.insert e js }
  stopPull g := do note (.read (.stopPull g)); return (← get).stopPull.contains g
  setStopPull g armed := do
    note (.write (.stopPull g))
    modify fun s => { s with
      stopPull := if armed then s.stopPull.insert g else s.stopPull.erase g }
  peerHasEntry? p g := do note (.read (.peerHas p g)); return ((← get).peerHas.getD p {}).get? g
  setPeerHas p g e := do
    note (.write (.peerHas p g))
    modify fun s => { s with peerHas := s.peerHas.insert p ((s.peerHas.getD p {}).insert g e) }
  holdersOf g i := do note (.read (.holders g i)); return ((← get).holders.getD g {}).getD i {}
  setHolders g i ps := do
    note (.write (.holders g i))
    modify fun s => { s with holders := s.holders.insert g ((s.holders.getD g {}).insert i ps) }
  serveCount p m := do note (.read (.serveCount p m)); return ((← get).serveCount.getD p {}).getD m 0
  setServeCount p m n := do
    note (.write (.serveCount p m))
    modify fun s => { s with serveCount := s.serveCount.insert p ((s.serveCount.getD p {}).insert m n) }
  origin g := do note (.read (.origin g)); return (← get).origin.get? g
  setOrigin g b := do note (.write (.origin g)); modify fun s => { s with origin := s.origin.insert g b }
  plannedTargets? g i := do
    note (.pass "planned" [.plannedRow g])
    note (.read (.planned g i))
    return ((← get).planned.getD g {}).get? i
  setPlanned g i ps := do
    note (.pass "planned" [.plannedRow g])
    let s ← get
    if !s.planned.contains g then note (.write (.plannedRow g))
    note (.write (.planned g i))
    modify fun s => { s with planned := s.planned.insert g ((s.planned.getD g {}).insert i ps) }
  planned g := do note (.read (.plannedRow g)); return (← get).planned.contains g
  erasePlannedRow g := do
    let l := ((← get).planned.getD g {}).toList
    note (.write (.plannedRow g))
    for c in l.map fun (i, _) => .planned g i do note (.write c)
    modify fun s => { s with planned := s.planned.erase g }
  pushedEntry? p g := do note (.read (.pushed p g)); return ((← get).pushed.getD p {}).get? g
  setPushed p g e := do
    note (.write (.pushed p g))
    modify fun s => { s with pushed := s.pushed.insert p ((s.pushed.getD p {}).insert g e) }
  desc g := do note (.read (.desc g)); return (← get).desc.get? g
  setDesc g d := do note (.write (.desc g)); modify fun s => { s with desc := s.desc.insert g d }
  inFlight e := do note (.read (.inFlight e)); return (← get).inFlight.getD e 0
  setInFlight e n := do note (.write (.inFlight e)); modify fun s => { s with inFlight := s.inFlight.insert e n }
  waitersLine e := do note (.read (.waiters e)); return (← get).waiters.getD e []
  setWaitersLine e o := do note (.write (.waiters e)); modify fun s => { s with waiters := s.waiters.insert e o }
  sentAt? k := do note (.read (.sent k)); return (← get).sent.get? k
  setSentAt k t := do note (.write (.sent k)); modify fun s => { s with sent := s.sent.insert k t }
  eraseSentAt k := do note (.write (.sent k)); modify fun s => { s with sent := s.sent.erase k }
  unwantedOf p := do note (.read (.unwanted p)); return (← get).unwanted.getD p {}
  setUnwanted p ids := do note (.write (.unwanted p)); modify fun s => { s with unwanted := s.unwanted.insert p ids }
  joinRecv? p T := do note (.read (.joinRecv p T)); return ((← get).joinRecv.getD p {}).get? T
  setJoinRecv p T jn := do
    note (.write (.joinRecv p T))
    modify fun s => { s with joinRecv := s.joinRecv.insert p ((s.joinRecv.getD p {}).insert T jn) }
  joinSent? p T := do note (.read (.joinSent p T)); return ((← get).joinSent.getD p {}).get? T
  setJoinSent p T jn := do
    note (.write (.joinSent p T))
    modify fun s => { s with joinSent := s.joinSent.insert p ((s.joinSent.getD p {}).insert T jn) }
  pushOutOf p T fam := do note (.read (.pushOut p T fam)); return (((← get).pushOut.getD p {}).getD T {}).getD fam {}
  setPushOut p T fam cs := do
    note (.write (.pushOut p T fam))
    modify fun s => { s with pushOut := s.pushOut.insert p ((s.pushOut.getD p {}).insert T (((s.pushOut.getD p {}).getD T {}).insert fam cs)) }
  pushInOf p T fam := do note (.read (.pushIn p T fam)); return (((← get).pushIn.getD p {}).getD T {}).getD fam {}
  setPushIn p T fam cs := do
    note (.write (.pushIn p T fam))
    modify fun s => { s with pushIn := s.pushIn.insert p ((s.pushIn.getD p {}).insert T (((s.pushIn.getD p {}).getD T {}).insert fam cs)) }
  graftedOutOf p T fam := do note (.read (.graftedOut p T fam)); return (((← get).graftedOut.getD p {}).getD T {}).getD fam {}
  setGraftedOut p T fam cs := do
    note (.write (.graftedOut p T fam))
    modify fun s => { s with graftedOut := s.graftedOut.insert p ((s.graftedOut.getD p {}).insert T (((s.graftedOut.getD p {}).getD T {}).insert fam cs)) }
  graftedInOf p T fam := do note (.read (.graftedIn p T fam)); return (((← get).graftedIn.getD p {}).getD T {}).getD fam {}
  setGraftedIn p T fam cs := do
    note (.write (.graftedIn p T fam))
    modify fun s => { s with graftedIn := s.graftedIn.insert p ((s.graftedIn.getD p {}).insert T (((s.graftedIn.getD p {}).getD T {}).insert fam cs)) }
  owedRelationsOf p := do note (.read (.owedRelations p)); return (← get).owedRelations.getD p []
  setOwedRelations p rs := do
    note (.write (.owedRelations p))
    modify fun s => { s with owedRelations := s.owedRelations.insert p rs }
  backoff? p T fam cd := do note (.read (.backoff p T fam cd)); return ((((← get).backoff.getD p {}).getD T {}).getD fam {}).get? cd
  setBackoff p T fam cd t := do
    note (.write (.backoff p T fam cd))
    modify fun s => { s with backoff := s.backoff.insert p ((s.backoff.getD p {}).insert T (((s.backoff.getD p {}).getD T {}).insert fam ((((s.backoff.getD p {}).getD T {}).getD fam {}).insert cd t))) }
  tOf? g := do note (.read (.tOf g)); return (← get).tOf.get? g
  setTOf g ty := do note (.write (.tOf g)); modify fun s => { s with tOf := s.tOf.insert g ty }
  rebuiltBits g := do note (.read (.rebuilt g)); return (← get).rebuilt.getD g 0
  setRebuilt g b := do note (.write (.rebuilt g)); modify fun s => { s with rebuilt := s.rebuilt.insert g b }
  interest? g := do note (.read (.interest g)); return (← get).interest.get? g
  setInterest g ib := do note (.write (.interest g)); modify fun s => { s with interest := s.interest.insert g ib }
  knownAt? g := do note (.read (.knownAt g)); return (← get).knownAt.get? g
  setKnownAt g t := do note (.write (.knownAt g)); modify fun s => { s with knownAt := s.knownAt.insert g t }
  standing? g i := do note (.read (.standing g i)); return ((← get).standing.getD g {}).get? i
  setStanding g i ps := do
    note (.write (.standing g i))
    modify fun s => { s with standing := s.standing.insert g ((s.standing.getD g {}).insert i ps) }
  eraseStanding g i := do
    note (.write (.standing g i))
    modify fun s => { s with standing := s.standing.insert g ((s.standing.getD g {}).erase i) }
  claims? g := do note (.read (.claims g)); return (← get).claims.get? g
  setClaims g ps := do note (.write (.claims g)); modify fun s => { s with claims := s.claims.insert g ps }
  allClaims := do
    let l := (← get).claims.toList
    note (.scan .claims (l.map fun (g, _) => .claims g))
    return l
  reconsiderAt? g := do note (.read (.reconsiderAt g)); return (← get).reconsiderAt.get? g
  setReconsiderAt g t := do
    note (.write (.reconsiderAt g))
    modify fun s => { s with reconsiderAt := s.reconsiderAt.insert g t }
  eraseReconsiderAt g := do
    note (.write (.reconsiderAt g))
    modify fun s => { s with reconsiderAt := s.reconsiderAt.erase g }
  deferred? g := do note (.read (.deferred g)); return (← get).deferred.contains g
  setDeferred g armed := do
    note (.write (.deferred g))
    modify fun s => { s with
      deferred := if armed then s.deferred.insert g else s.deferred.erase g }
  dutyAt? g := do note (.read (.dutyAt g)); return (← get).dutyAt.get? g
  setDutyAt g t := do note (.write (.dutyAt g)); modify fun s => { s with dutyAt := s.dutyAt.insert g t }
  waited? g := do note (.read (.waited g)); return (← get).waited.contains g
  setWaited g armed := do
    note (.write (.waited g))
    modify fun s => { s with
      waited := if armed then s.waited.insert g else s.waited.erase g }
  probe? g := do note (.read (.probe g)); return (← get).probe.get? g
  setProbe g sl := do note (.write (.probe g)); modify fun s => { s with probe := s.probe.insert g sl }
  probed? g := do note (.read (.probed g)); return (← get).probed.get? g
  setProbed g sl := do note (.write (.probed g)); modify fun s => { s with probed := s.probed.insert g sl }
  probeAsk? a := do note (.read (.probeAsk a)); return (← get).probeAsks.contains a
  setProbeAsk a armed := do
    note (.write (.probeAsk a))
    modify fun s => { s with
      probeAsks := if armed then s.probeAsks.insert a else s.probeAsks.erase a }
  probeSent? g := do note (.read (.probeSent g)); return (← get).probeSent.contains g
  setProbeSent g armed := do
    note (.write (.probeSent g))
    modify fun s => { s with
      probeSent := if armed then s.probeSent.insert g else s.probeSent.erase g }
  probeOk? g := do note (.read (.probeOk g)); return (← get).probeOk.get? g
  setProbeOk g vd := do note (.write (.probeOk g)); modify fun s => { s with probeOk := s.probeOk.insert g vd }
  rsampleOf g := do note (.read (.rsample g)); return (← get).rsample.getD g []
  setRsample g ixs := do note (.write (.rsample g)); modify fun s => { s with rsample := s.rsample.insert g ixs }
  rsampleStep g := do note (.read (.rsampleStep g)); return (← get).rsampleStep.getD g 0
  setRsampleStep g n := do
    note (.write (.rsampleStep g))
    modify fun s => { s with rsampleStep := s.rsampleStep.insert g n }
  rsampleAskedOf g i := do note (.read (.rsampleAsked g i)); return ((← get).rsampleAsked.getD g {}).getD i {}
  setRsampleAsked g i ps := do
    note (.write (.rsampleAsked g i))
    modify fun s => { s with rsampleAsked := s.rsampleAsked.insert g ((s.rsampleAsked.getD g {}).insert i ps) }
  rsampleFinal? g := do note (.read (.rsampleFinal g)); return (← get).rsampleFinal.contains g
  setRsampleFinal g armed := do
    note (.write (.rsampleFinal g))
    modify fun s => { s with
      rsampleFinal := if armed then s.rsampleFinal.insert g else s.rsampleFinal.erase g }
  servedCount p g := do note (.read (.served p g)); return ((← get).served.getD p {}).getD g 0
  setServed p g n := do
    note (.write (.served p g))
    modify fun s => { s with served := s.served.insert p ((s.served.getD p {}).insert g n) }
  wantP? p g := do note (.read (.wantP p g)); return ((← get).wantP.getD p {}).get? g
  setWantP p g ib := do
    note (.write (.wantP p g))
    modify fun s => { s with wantP := s.wantP.insert p ((s.wantP.getD p {}).insert g ib) }
  probeServed p g := do note (.read (.probeServed p g)); return ((← get).probeServed.getD p {}).getD g false
  setProbeServed p g fl := do
    note (.write (.probeServed p g))
    modify fun s => { s with probeServed := s.probeServed.insert p ((s.probeServed.getD p {}).insert g fl) }
  probeAnswerBits p g := do note (.read (.probeAnswers p g)); return ((← get).probeAnswers.getD p {}).getD g 0
  setProbeAnswers p g b := do
    note (.write (.probeAnswers p g))
    modify fun s => { s with probeAnswers := s.probeAnswers.insert p ((s.probeAnswers.getD p {}).insert g b) }
  probeWaiting? g p := do note (.read (.probeWaiting g p)); return ((← get).probeWaiting.getD g {}).get? p
  setProbeWaiting g p sl := do
    note (.write (.probeWaiting g p))
    modify fun s => { s with probeWaiting := s.probeWaiting.insert g ((s.probeWaiting.getD g {}).insert p sl) }
  eraseProbeWaiting g p := do
    note (.write (.probeWaiting g p))
    modify fun s => { s with probeWaiting := s.probeWaiting.insert g ((s.probeWaiting.getD g {}).erase p) }
  allProbeWaiting g := do
    let l := ((← get).probeWaiting.getD g {}).toList
    note (.scan (.probeWaiting g) (l.map fun (p, _) => .probeWaiting g p))
    return l
  sampledFromOf b := do note (.read (.sampledFrom b)); return (← get).sampledFrom.getD b {}
  setSampledFrom b ps := do
    note (.write (.sampledFrom b))
    modify fun s => { s with sampledFrom := s.sampledFrom.insert b ps }
  samplesInFlight b := do note (.read (.samplesInFlight b)); return (← get).samplesInFlight.getD b 0
  setSamplesInFlight b n := do
    note (.write (.samplesInFlight b))
    modify fun s => { s with samplesInFlight := s.samplesInFlight.insert b n }
  heldSamplesOf b := do note (.read (.heldSamples b)); return (← get).heldSamples.getD b []
  setHeldSamples b gs := do
    note (.write (.heldSamples b))
    modify fun s => { s with heldSamples := s.heldSamples.insert b gs }
  forwardedCount p := do note (.read (.forwarded p)); return (← get).forwarded.getD p 0
  setForwarded p n := do note (.write (.forwarded p)); modify fun s => { s with forwarded := s.forwarded.insert p n }
  allAskedAt := do
    let l := (← get).askedAt.toList
    note (.scan .askedAt (l.map fun (a, _) => .askedAt a))
    return l
  allTriedAll := do
    let l := (← get).tried.toList.map fun (a, m) => (a, m.toList)
    note (.scan .triedAll (l.flatMap fun (a, ps) => ps.map fun (p, _) => .tried a p))
    return l
  allTried a := do
    let l := ((← get).tried.getD a {}).toList
    note (.scan (.tried a) (l.map fun (p, _) => .tried a p))
    return l
  allOffers := do
    let l := (← get).offers.toList
    note (.scan .offers (l.map fun (a, _) => .offers a))
    return l
  allOfferedAll := do
    let l := (← get).offered.toList.map fun (q, m) => (q, m.toList)
    note (.scan .offeredAll (l.flatMap fun (q, gs) => gs.map fun (g, _) => .offered q g))
    return l
  allOffered q := do
    let l := ((← get).offered.getD q {}).toList
    note (.scan (.offered q) (l.map fun (g, _) => .offered q g))
    return l
  allParkAll := do
    let l := (← get).park.toList.map fun (p, m) => (p, m.toList)
    note (.scan .parkAll (l.flatMap fun (p, gs) => gs.map fun (g, _) => .park p g))
    return l
  allPark p := do
    let l := ((← get).park.getD p {}).toList
    note (.scan (.park p) (l.map fun (g, _) => .park p g))
    return l
  allAskedParked := do
    let l := (← get).askedParked.toList
    note (.scan .askedParked (l.map fun (k, _) => .askedParked k))
    return l
  allLrArmed := do
    let l := (← get).lastResortArmed.toList
    note (.scan .lrArmed (l.map fun k => .lrArmed k))
    return l
  allIhaveFrames := do
    let l := (← get).ihaveFrames.toList
    note (.scan .ihaveFrames (l.map fun (p, _) => .ihaveFrames p))
    return l
  allIhaveAsked := do
    let l := (← get).ihaveAsked.toList
    note (.scan .ihaveAsked (l.map fun (p, _) => .ihaveAsked p))
    return l
  allReceived := do
    let l := (← get).received.toList
    note (.scan .received (l.map fun (g, _) => .received g))
    return l
  allMine := do
    let l := (← get).mine.toList
    note (.scan .mine (l.map fun (g, _) => .mine g))
    return l
  allState := do
    let l := (← get).state.toList
    note (.scan .state (l.map fun (g, _) => .state g))
    return l
  allPendingIds := do
    let l := (← get).pendingIds.toList
    note (.scan .pendingIds (l.map fun m => .pendingId m))
    return l
  allOwedAll := do
    let l := (← get).owed.toList.map fun (p, m) => (p, m.toList)
    note (.scan .owedAll (l.flatMap fun (p, gs) => .owedRow p :: gs.map fun (g, _) => .owed p g))
    return l
  allOwedAnswersAll := do
    let l := (← get).owedAnswers.toList.map fun (p, m) => (p, m.toList)
    note (.scan .owedAnswersAll (l.flatMap fun (p, gs) => gs.map fun (g, _) => .owedAnswers p g))
    return l
  allSentToAll := do
    let l := (← get).sentTo.toList.map fun (p, m) => (p, m.toList)
    note (.scan .sentToAll (l.flatMap fun (p, gs) => gs.map fun (g, _) => .sentTo p g))
    return l
  allSlotHeld := do
    let l := (← get).slotHeld.toList
    note (.scan .slotHeld (l.map fun p => .slotHeld p))
    return l
  allPaceQueue := do
    let l := (← get).paceQueue.toList
    note (.scan .paceQueue (l.map fun (e, _) => .paceQueue e))
    return l
  allStopPull := do
    let l := (← get).stopPull.toList
    note (.scan .stopPull (l.map fun g => .stopPull g))
    return l
  allPeerHas := do
    let l := (← get).peerHas.toList.map fun (p, m) => (p, m.toList)
    note (.scan .peerHas (l.flatMap fun (p, gs) => gs.map fun (g, _) => .peerHas p g))
    return l
  allHolders := do
    let l := (← get).holders.toList.map fun (g, m) => (g, m.toList)
    note (.scan .holders (l.flatMap fun (g, is) => is.map fun (i, _) => .holders g i))
    return l
  allServeCount := do
    let l := (← get).serveCount.toList.map fun (p, m) => (p, m.toList)
    note (.scan .serveCount (l.flatMap fun (p, ms) => ms.map fun (m, _) => .serveCount p m))
    return l
  allOrigin := do
    let l := (← get).origin.toList
    note (.scan .origin (l.map fun (g, _) => .origin g))
    return l
  allPlannedAll := do
    let l := (← get).planned.toList.map fun (g, m) => (g, m.toList)
    note (.scan .plannedAll (l.flatMap fun (g, is) => .plannedRow g :: is.map fun (i, _) => .planned g i))
    return l
  allPushed := do
    let l := (← get).pushed.toList.map fun (p, m) => (p, m.toList)
    note (.scan .pushed (l.flatMap fun (p, gs) => gs.map fun (g, _) => .pushed p g))
    return l
  allDesc := do
    let l := (← get).desc.toList
    note (.scan .desc (l.map fun (g, _) => .desc g))
    return l
  allInFlight := do
    let l := (← get).inFlight.toList
    note (.scan .inFlight (l.map fun (e, _) => .inFlight e))
    return l
  allWaiters := do
    let l := (← get).waiters.toList
    note (.scan .waiters (l.map fun (e, _) => .waiters e))
    return l
  allSent := do
    let l := (← get).sent.toList
    note (.scan .sent (l.map fun (k, _) => .sent k))
    return l
  allUnwanted := do
    let l := (← get).unwanted.toList
    note (.scan .unwanted (l.map fun (p, _) => .unwanted p))
    return l
  allJoinRecvAll := do
    let l := (← get).joinRecv.toList.map fun (p, m) => (p, m.toList)
    note (.scan .joinRecvAll (l.flatMap fun (p, Ts) => Ts.map fun (T, _) => .joinRecv p T))
    return l
  allJoinSentAll := do
    let l := (← get).joinSent.toList.map fun (p, m) => (p, m.toList)
    note (.scan .joinSentAll (l.flatMap fun (p, Ts) => Ts.map fun (T, _) => .joinSent p T))
    return l
  allPushOutAll := do
    let l := (← get).pushOut.toList.map fun (p, m) => (p, m.toList.map fun (T, m) => (T, m.toList))
    note (.scan .pushOutAll (l.flatMap fun (p, Ts) => Ts.flatMap fun (T, fams) => fams.map fun (fam, _) => .pushOut p T fam))
    return l
  allPushInAll := do
    let l := (← get).pushIn.toList.map fun (p, m) => (p, m.toList.map fun (T, m) => (T, m.toList))
    note (.scan .pushInAll (l.flatMap fun (p, Ts) => Ts.flatMap fun (T, fams) => fams.map fun (fam, _) => .pushIn p T fam))
    return l
  allGraftedOutAll := do
    let l := (← get).graftedOut.toList.map fun (p, m) => (p, m.toList.map fun (T, m) => (T, m.toList))
    note (.scan .graftedOutAll (l.flatMap fun (p, Ts) => Ts.flatMap fun (T, fams) => fams.map fun (fam, _) => .graftedOut p T fam))
    return l
  allGraftedInAll := do
    let l := (← get).graftedIn.toList.map fun (p, m) => (p, m.toList.map fun (T, m) => (T, m.toList))
    note (.scan .graftedInAll (l.flatMap fun (p, Ts) => Ts.flatMap fun (T, fams) => fams.map fun (fam, _) => .graftedIn p T fam))
    return l
  allOwedRelations := do
    let l := (← get).owedRelations.toList
    note (.scan .owedRelations (l.map fun (p, _) => .owedRelations p))
    return l
  allBackoffAll := do
    let l := (← get).backoff.toList.map fun (p, m) => (p, m.toList.map fun (T, m) => (T, m.toList.map fun (fam, m) => (fam, m.toList)))
    note (.scan .backoffAll (l.flatMap fun (p, Ts) => Ts.flatMap fun (T, fams) => fams.flatMap fun (fam, cds) => cds.map fun (cd, _) => .backoff p T fam cd))
    return l
  allTOf := do
    let l := (← get).tOf.toList
    note (.scan .tOf (l.map fun (g, _) => .tOf g))
    return l
  allRebuilt := do
    let l := (← get).rebuilt.toList
    note (.scan .rebuilt (l.map fun (g, _) => .rebuilt g))
    return l
  allInterest := do
    let l := (← get).interest.toList
    note (.scan .interest (l.map fun (g, _) => .interest g))
    return l
  allKnownAt := do
    let l := (← get).knownAt.toList
    note (.scan .knownAt (l.map fun (g, _) => .knownAt g))
    return l
  allStandingAll := do
    let l := (← get).standing.toList.map fun (g, m) => (g, m.toList)
    note (.scan .standingAll (l.flatMap fun (g, is) => is.map fun (i, _) => .standing g i))
    return l
  allReconsiderAt := do
    let l := (← get).reconsiderAt.toList
    note (.scan .reconsiderAt (l.map fun (g, _) => .reconsiderAt g))
    return l
  allDeferred := do
    let l := (← get).deferred.toList
    note (.scan .deferred (l.map fun g => .deferred g))
    return l
  allDutyAt := do
    let l := (← get).dutyAt.toList
    note (.scan .dutyAt (l.map fun (g, _) => .dutyAt g))
    return l
  allWaited := do
    let l := (← get).waited.toList
    note (.scan .waited (l.map fun g => .waited g))
    return l
  allProbe := do
    let l := (← get).probe.toList
    note (.scan .probe (l.map fun (g, _) => .probe g))
    return l
  allProbed := do
    let l := (← get).probed.toList
    note (.scan .probed (l.map fun (g, _) => .probed g))
    return l
  allProbeAsk := do
    let l := (← get).probeAsks.toList
    note (.scan .probeAsk (l.map fun a => .probeAsk a))
    return l
  allProbeSent := do
    let l := (← get).probeSent.toList
    note (.scan .probeSent (l.map fun g => .probeSent g))
    return l
  allProbeOk := do
    let l := (← get).probeOk.toList
    note (.scan .probeOk (l.map fun (g, _) => .probeOk g))
    return l
  allRsample := do
    let l := (← get).rsample.toList
    note (.scan .rsample (l.map fun (g, _) => .rsample g))
    return l
  allRsampleStep := do
    let l := (← get).rsampleStep.toList
    note (.scan .rsampleStep (l.map fun (g, _) => .rsampleStep g))
    return l
  allRsampleAskedAll := do
    let l := (← get).rsampleAsked.toList.map fun (g, m) => (g, m.toList)
    note (.scan .rsampleAskedAll (l.flatMap fun (g, is) => is.map fun (i, _) => .rsampleAsked g i))
    return l
  allRsampleFinal := do
    let l := (← get).rsampleFinal.toList
    note (.scan .rsampleFinal (l.map fun g => .rsampleFinal g))
    return l
  allServedAll := do
    let l := (← get).served.toList.map fun (p, m) => (p, m.toList)
    note (.scan .servedAll (l.flatMap fun (p, gs) => gs.map fun (g, _) => .served p g))
    return l
  allWantPAll := do
    let l := (← get).wantP.toList.map fun (p, m) => (p, m.toList)
    note (.scan .wantPAll (l.flatMap fun (p, gs) => gs.map fun (g, _) => .wantP p g))
    return l
  allProbeServedAll := do
    let l := (← get).probeServed.toList.map fun (p, m) => (p, m.toList)
    note (.scan .probeServedAll (l.flatMap fun (p, gs) => gs.map fun (g, _) => .probeServed p g))
    return l
  allProbeAnswersAll := do
    let l := (← get).probeAnswers.toList.map fun (p, m) => (p, m.toList)
    note (.scan .probeAnswersAll (l.flatMap fun (p, gs) => gs.map fun (g, _) => .probeAnswers p g))
    return l
  allProbeWaitingAll := do
    let l := (← get).probeWaiting.toList.map fun (g, m) => (g, m.toList)
    note (.scan .probeWaitingAll (l.flatMap fun (g, ps) => ps.map fun (p, _) => .probeWaiting g p))
    return l
  allSampledFrom := do
    let l := (← get).sampledFrom.toList
    note (.scan .sampledFrom (l.map fun (b, _) => .sampledFrom b))
    return l
  allSamplesInFlight := do
    let l := (← get).samplesInFlight.toList
    note (.scan .samplesInFlight (l.map fun (b, _) => .samplesInFlight b))
    return l
  allHeldSamples := do
    let l := (← get).heldSamples.toList
    note (.scan .heldSamples (l.map fun (b, _) => .heldSamples b))
    return l
  allForwarded := do
    let l := (← get).forwarded.toList
    note (.scan .forwarded (l.map fun (p, _) => .forwarded p))
    return l

/-- The interface through a monad transformer. -/
abbrev lift {m n : Type → Type} [Tables m] (f : ∀ {α : Type}, m α → n α) : Tables n where
  askedAt? a := f (askedAt? a)
  setAskedAt a t := f (setAskedAt a t)
  eraseAskedAt a := f (eraseAskedAt a)
  tried? a p := f (tried? a p)
  setTried a p t := f (setTried a p t)
  eraseTried a p := f (eraseTried a p)
  offersOf a := f (offersOf a)
  setOffers a o := f (setOffers a o)
  eraseOffers a := f (eraseOffers a)
  promise? a p := f (promise? a p)
  setPromise a p t := f (setPromise a p t)
  erasePromise a p := f (erasePromise a p)
  allPromises := f allPromises
  offeredBits q g := f (offeredBits q g)
  setOffered q g b := f (setOffered q g b)
  parkUntil? p g := f (parkUntil? p g)
  setPark p g t := f (setPark p g t)
  erasePark p g := f (erasePark p g)
  askedParkedOf k := f (askedParkedOf k)
  setAskedParked k ps := f (setAskedParked k ps)
  eraseAskedParked k := f (eraseAskedParked k)
  lrArmed? k := f (lrArmed? k)
  setLrArmed k b := f (setLrArmed k b)
  ihaveFrames p := f (ihaveFrames p)
  setIhaveFrames p n := f (setIhaveFrames p n)
  clearIhaveFrames := f clearIhaveFrames
  ihaveAsked p := f (ihaveAsked p)
  setIhaveAsked p n := f (setIhaveAsked p n)
  clearIhaveAsked := f clearIhaveAsked
  heldBack? k := f (heldBack? k)
  setHeldBack k a := f (setHeldBack k a)
  clearHeldBack := f clearHeldBack
  allHeldBack := f allHeldBack
  receivedBits g := f (receivedBits g)
  setReceived g b := f (setReceived g b)
  mineBits g := f (mineBits g)
  setMine g b := f (setMine g b)
  state? g := f (state? g)
  setState g st := f (setState g st)
  tied? r p g := f (tied? r p g)
  setTied r p g b := f (setTied r p g b)
  eraseTied r p g := f (eraseTied r p g)
  tiedRow? r := f (tiedRow? r)
  eraseTiedRow r := f (eraseTiedRow r)
  tiedPeerRow? r p := f (tiedPeerRow? r p)
  eraseTiedPeerRow r p := f (eraseTiedPeerRow r p)
  allTiedAll := f allTiedAll
  allTiedRoot r := f (allTiedRoot r)
  allTiedPeer r p := f (allTiedPeer r p)
  lane? p l := f (lane? p l)
  setLane p l es := f (setLane p l es)
  eraseLane p l := f (eraseLane p l)
  allQueue := f allQueue
  pendingOf r := f (pendingOf r)
  setPending r w := f (setPending r w)
  erasePending r := f (erasePending r)
  allPending := f allPending
  pendingId? m := f (pendingId? m)
  setPendingId m armed := f (setPendingId m armed)
  tieSlot? r p := f (tieSlot? r p)
  setTieSlot r p sl := f (setTieSlot r p sl)
  eraseTieSlot r p := f (eraseTieSlot r p)
  allTieSlot := f allTieSlot
  owed? p g := f (owed? p g)
  setOwed p g b := f (setOwed p g b)
  eraseOwed p g := f (eraseOwed p g)
  owedRow? p := f (owedRow? p)
  eraseOwedRow p := f (eraseOwedRow p)
  allOwed p := f (allOwed p)
  owedAnswerBits p g := f (owedAnswerBits p g)
  setOwedAnswers p g b := f (setOwedAnswers p g b)
  allOwedAnswers p := f (allOwedAnswers p)
  sentToBits p g := f (sentToBits p g)
  setSentTo p g b := f (setSentTo p g b)
  slotHeld? p := f (slotHeld? p)
  setSlotHeld p armed := f (setSlotHeld p armed)
  paceJobs e := f (paceJobs e)
  setPaceJobs e js := f (setPaceJobs e js)
  stopPull g := f (stopPull g)
  setStopPull g armed := f (setStopPull g armed)
  peerHasEntry? p g := f (peerHasEntry? p g)
  setPeerHas p g e := f (setPeerHas p g e)
  holdersOf g i := f (holdersOf g i)
  setHolders g i ps := f (setHolders g i ps)
  serveCount p m := f (serveCount p m)
  setServeCount p m n := f (setServeCount p m n)
  origin g := f (origin g)
  setOrigin g b := f (setOrigin g b)
  plannedTargets? g i := f (plannedTargets? g i)
  setPlanned g i ps := f (setPlanned g i ps)
  planned g := f (planned g)
  erasePlannedRow g := f (erasePlannedRow g)
  pushedEntry? p g := f (pushedEntry? p g)
  setPushed p g e := f (setPushed p g e)
  desc g := f (desc g)
  setDesc g d := f (setDesc g d)
  inFlight e := f (inFlight e)
  setInFlight e n := f (setInFlight e n)
  waitersLine e := f (waitersLine e)
  setWaitersLine e o := f (setWaitersLine e o)
  sentAt? k := f (sentAt? k)
  setSentAt k t := f (setSentAt k t)
  eraseSentAt k := f (eraseSentAt k)
  unwantedOf p := f (unwantedOf p)
  setUnwanted p ids := f (setUnwanted p ids)
  joinRecv? p T := f (joinRecv? p T)
  setJoinRecv p T jn := f (setJoinRecv p T jn)
  joinSent? p T := f (joinSent? p T)
  setJoinSent p T jn := f (setJoinSent p T jn)
  pushOutOf p T fam := f (pushOutOf p T fam)
  setPushOut p T fam cs := f (setPushOut p T fam cs)
  pushInOf p T fam := f (pushInOf p T fam)
  setPushIn p T fam cs := f (setPushIn p T fam cs)
  graftedOutOf p T fam := f (graftedOutOf p T fam)
  setGraftedOut p T fam cs := f (setGraftedOut p T fam cs)
  graftedInOf p T fam := f (graftedInOf p T fam)
  setGraftedIn p T fam cs := f (setGraftedIn p T fam cs)
  owedRelationsOf p := f (owedRelationsOf p)
  setOwedRelations p rs := f (setOwedRelations p rs)
  backoff? p T fam cd := f (backoff? p T fam cd)
  setBackoff p T fam cd t := f (setBackoff p T fam cd t)
  tOf? g := f (tOf? g)
  setTOf g ty := f (setTOf g ty)
  rebuiltBits g := f (rebuiltBits g)
  setRebuilt g b := f (setRebuilt g b)
  interest? g := f (interest? g)
  setInterest g ib := f (setInterest g ib)
  knownAt? g := f (knownAt? g)
  setKnownAt g t := f (setKnownAt g t)
  standing? g i := f (standing? g i)
  setStanding g i ps := f (setStanding g i ps)
  eraseStanding g i := f (eraseStanding g i)
  claims? g := f (claims? g)
  setClaims g ps := f (setClaims g ps)
  allClaims := f allClaims
  reconsiderAt? g := f (reconsiderAt? g)
  setReconsiderAt g t := f (setReconsiderAt g t)
  eraseReconsiderAt g := f (eraseReconsiderAt g)
  deferred? g := f (deferred? g)
  setDeferred g armed := f (setDeferred g armed)
  dutyAt? g := f (dutyAt? g)
  setDutyAt g t := f (setDutyAt g t)
  waited? g := f (waited? g)
  setWaited g armed := f (setWaited g armed)
  probe? g := f (probe? g)
  setProbe g sl := f (setProbe g sl)
  probed? g := f (probed? g)
  setProbed g sl := f (setProbed g sl)
  probeAsk? a := f (probeAsk? a)
  setProbeAsk a armed := f (setProbeAsk a armed)
  probeSent? g := f (probeSent? g)
  setProbeSent g armed := f (setProbeSent g armed)
  probeOk? g := f (probeOk? g)
  setProbeOk g vd := f (setProbeOk g vd)
  rsampleOf g := f (rsampleOf g)
  setRsample g ixs := f (setRsample g ixs)
  rsampleStep g := f (rsampleStep g)
  setRsampleStep g n := f (setRsampleStep g n)
  rsampleAskedOf g i := f (rsampleAskedOf g i)
  setRsampleAsked g i ps := f (setRsampleAsked g i ps)
  rsampleFinal? g := f (rsampleFinal? g)
  setRsampleFinal g armed := f (setRsampleFinal g armed)
  servedCount p g := f (servedCount p g)
  setServed p g n := f (setServed p g n)
  wantP? p g := f (wantP? p g)
  setWantP p g ib := f (setWantP p g ib)
  probeServed p g := f (probeServed p g)
  setProbeServed p g fl := f (setProbeServed p g fl)
  probeAnswerBits p g := f (probeAnswerBits p g)
  setProbeAnswers p g b := f (setProbeAnswers p g b)
  probeWaiting? g p := f (probeWaiting? g p)
  setProbeWaiting g p sl := f (setProbeWaiting g p sl)
  eraseProbeWaiting g p := f (eraseProbeWaiting g p)
  allProbeWaiting g := f (allProbeWaiting g)
  sampledFromOf b := f (sampledFromOf b)
  setSampledFrom b ps := f (setSampledFrom b ps)
  samplesInFlight b := f (samplesInFlight b)
  setSamplesInFlight b n := f (setSamplesInFlight b n)
  heldSamplesOf b := f (heldSamplesOf b)
  setHeldSamples b gs := f (setHeldSamples b gs)
  forwardedCount p := f (forwardedCount p)
  setForwarded p n := f (setForwarded p n)
  allAskedAt := f allAskedAt
  allTriedAll := f allTriedAll
  allTried a := f (allTried a)
  allOffers := f allOffers
  allOfferedAll := f allOfferedAll
  allOffered q := f (allOffered q)
  allParkAll := f allParkAll
  allPark p := f (allPark p)
  allAskedParked := f allAskedParked
  allLrArmed := f allLrArmed
  allIhaveFrames := f allIhaveFrames
  allIhaveAsked := f allIhaveAsked
  allReceived := f allReceived
  allMine := f allMine
  allState := f allState
  allPendingIds := f allPendingIds
  allOwedAll := f allOwedAll
  allOwedAnswersAll := f allOwedAnswersAll
  allSentToAll := f allSentToAll
  allSlotHeld := f allSlotHeld
  allPaceQueue := f allPaceQueue
  allStopPull := f allStopPull
  allPeerHas := f allPeerHas
  allHolders := f allHolders
  allServeCount := f allServeCount
  allOrigin := f allOrigin
  allPlannedAll := f allPlannedAll
  allPushed := f allPushed
  allDesc := f allDesc
  allInFlight := f allInFlight
  allWaiters := f allWaiters
  allSent := f allSent
  allUnwanted := f allUnwanted
  allJoinRecvAll := f allJoinRecvAll
  allJoinSentAll := f allJoinSentAll
  allPushOutAll := f allPushOutAll
  allPushInAll := f allPushInAll
  allGraftedOutAll := f allGraftedOutAll
  allGraftedInAll := f allGraftedInAll
  allOwedRelations := f allOwedRelations
  allBackoffAll := f allBackoffAll
  allTOf := f allTOf
  allRebuilt := f allRebuilt
  allInterest := f allInterest
  allKnownAt := f allKnownAt
  allStandingAll := f allStandingAll
  allReconsiderAt := f allReconsiderAt
  allDeferred := f allDeferred
  allDutyAt := f allDutyAt
  allWaited := f allWaited
  allProbe := f allProbe
  allProbed := f allProbed
  allProbeAsk := f allProbeAsk
  allProbeSent := f allProbeSent
  allProbeOk := f allProbeOk
  allRsample := f allRsample
  allRsampleStep := f allRsampleStep
  allRsampleAskedAll := f allRsampleAskedAll
  allRsampleFinal := f allRsampleFinal
  allServedAll := f allServedAll
  allWantPAll := f allWantPAll
  allProbeServedAll := f allProbeServedAll
  allProbeAnswersAll := f allProbeAnswersAll
  allProbeWaitingAll := f allProbeWaitingAll
  allSampledFrom := f allSampledFrom
  allSamplesInFlight := f allSamplesInFlight
  allHeldSamples := f allHeldSamples
  allForwarded := f allForwarded

instance instReaderT {m : Type → Type} {ρ : Type} [Monad m] [Tables m] : Tables (ReaderT ρ m) :=
  lift (m := m) (n := ReaderT ρ m) fun x => monadLift x

end Tables

end SpecTwin
