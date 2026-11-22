import SpecTwin.State
import SpecTwin.ReplayBase

/-! # The replay's reading and comparing of the twin's state, table by table (generated)

This file is written whole by `tools/gen/gen.py` from `gen/schema.py` and `gen/schema_seacast.py`, one
entry there per table, and `gen.py --check` compares it byte for byte. Do not edit it: change the schema,
or the generator.

How an entry and a level are read from a record (`cell`, `val`, `level`), and how a state is looked up, changed
and listed entry by entry (`valueAt`, `put`, `drop`, `entries`, `under`, `covers`). The kinds of value (`Val`)
and the parsers of keys are in `ReplayBase.lean`, written by hand. -/

namespace SpecTwin.Replay

open Lean (Json)

/-- An entry of §6.1's tables, from its table's name and its path (one element per level). -/
def cell (table : String) (path : Json) : Except String Cell := do
  match table, ← path.getArr? with
  | "asked_at", #[a] => return .askedAt (← key a)
  | "tried", #[a, p] => return .tried (← key a) (← nat p)
  | "offers", #[a] => return .offers (← key a)
  | "promises", #[ap] =>
    let #[a, p] ← ap.getArr? | throw s!"not a promise's key: {ap.compress}"
    return .promise (← key a) (← nat p)
  | "offered", #[q, g] => return .offered (← nat q) (← groupKey g)
  | "park", #[p, g] => return .park (← nat p) (← groupKey g)
  | "asked_parked", #[k] => return .askedParked (← chunk k)
  | "last_resort_armed", #[k] => return .lrArmed (← chunk k)
  | "ihave_frames", #[p] => return .ihaveFrames (← nat p)
  | "ihave_asked", #[p] => return .ihaveAsked (← nat p)
  | "held_back", #[k] => return .heldBack (← chunk k)
  | "received", #[g] => return .received (← groupKey g)
  | "mine", #[g] => return .mine (← groupKey g)
  | "state", #[g] => return .state (← groupKey g)
  | "tied", #[r, p, g] => return .tied (← rootKey r) (← nat p) (← groupKey g)
  | "tied", #[r] => return .tiedRow (← rootKey r)
  | "tied", #[r, p] => return .tiedPeerRow (← rootKey r) (← nat p)
  | "queue", #[p, l] => return .queue (← nat p) (← laneName l)
  | "queue", #[p] => return .queueRow (← nat p)
  | "pending", #[r] => return .pending (← rootKey r)
  | "pending_ids", #[m] => return .pendingId (← key m)
  | "tie_slot", #[rp] =>
    let #[r, p] ← rp.getArr? | throw s!"not a tieSlot's key: {rp.compress}"
    return .tieSlot (← rootKey r) (← nat p)
  | "owed", #[p, g] => return .owed (← nat p) (← groupKey g)
  | "owed", #[p] => return .owedRow (← nat p)
  | "owed_answers", #[p, g] => return .owedAnswers (← nat p) (← groupKey g)
  | "sent_to", #[p, g] => return .sentTo (← nat p) (← groupKey g)
  | "slot_held", #[p] => return .slotHeld (← nat p)
  | "pace_queue", #[e] => return .paceQueue (← paceKey e)
  | "stop_pull", #[g] => return .stopPull (← groupKey g)
  | "peer_has", #[p, g] => return .peerHas (← nat p) (← groupKey g)
  | "holders", #[g, i] => return .holders (← groupKey g) (← nat i)
  | "serve_count", #[p, m] => return .serveCount (← nat p) (← key m)
  | "origin", #[g] => return .origin (← groupKey g)
  | "planned", #[g, i] => return .planned (← groupKey g) (← nat i)
  | "planned", #[g] => return .plannedRow (← groupKey g)
  | "pushed", #[p, g] => return .pushed (← nat p) (← groupKey g)
  | "desc", #[g] => return .desc (← groupKey g)
  | "in_flight", #[e] => return .inFlight (← countKey e)
  | "waiters", #[e] => return .waiters (← lineKey e)
  | "sent", #[k] => return .sent (← sendKey k)
  | "unwanted", #[p] => return .unwanted (← nat p)
  | "join_recv", #[p, T] => return .joinRecv (← nat p) (← typeId T)
  | "join_sent", #[p, T] => return .joinSent (← nat p) (← typeId T)
  | "push_out", #[p, T, fam] => return .pushOut (← nat p) (← typeId T) (← intOf fam)
  | "push_in", #[p, T, fam] => return .pushIn (← nat p) (← typeId T) (← intOf fam)
  | "grafted_out", #[p, T, fam] => return .graftedOut (← nat p) (← typeId T) (← intOf fam)
  | "grafted_in", #[p, T, fam] => return .graftedIn (← nat p) (← typeId T) (← intOf fam)
  | "owed_relations", #[p] => return .owedRelations (← nat p)
  | "backoff", #[p, T, fam, cd] => return .backoff (← nat p) (← typeId T) (← intOf fam) (← colourDir cd)
  | "T_of", #[g] => return .tOf (← groupKey g)
  | "rebuilt", #[g] => return .rebuilt (← groupKey g)
  | "interest", #[g] => return .interest (← groupKey g)
  | "known_at", #[g] => return .knownAt (← groupKey g)
  | "standing", #[g, i] => return .standing (← groupKey g) (← nat i)
  | "routed_standing", #[g, i] => return .routedStanding (← groupKey g) (← nat i)
  | "claims", #[g] => return .claims (← groupKey g)
  | "reconsider_at", #[g] => return .reconsiderAt (← groupKey g)
  | "deferred", #[g] => return .deferred (← groupKey g)
  | "duty_at", #[g] => return .dutyAt (← groupKey g)
  | "waited", #[g] => return .waited (← groupKey g)
  | "probe", #[g] => return .probe (← groupKey g)
  | "probed", #[g] => return .probed (← groupKey g)
  | "probe_asks", #[a] => return .probeAsk (← key a)
  | "probe_sent", #[g] => return .probeSent (← groupKey g)
  | "probe_ok", #[g] => return .probeOk (← groupKey g)
  | "rsample", #[g] => return .rsample (← groupKey g)
  | "rsample_step", #[g] => return .rsampleStep (← groupKey g)
  | "rsample_asked", #[g, i] => return .rsampleAsked (← groupKey g) (← nat i)
  | "rsample_final", #[g] => return .rsampleFinal (← groupKey g)
  | "served", #[p, g] => return .served (← nat p) (← groupKey g)
  | "offered_to", #[p, g] => return .offeredTo (← nat p) (← groupKey g)
  | "want_p", #[p, g] => return .wantP (← nat p) (← groupKey g)
  | "probe_served", #[p, g] => return .probeServed (← nat p) (← groupKey g)
  | "probe_answers", #[p, g] => return .probeAnswers (← nat p) (← groupKey g)
  | "probe_waiting", #[g, p] => return .probeWaiting (← groupKey g) (← nat p)
  | "sampled_from", #[b] => return .sampledFrom (← blockKey b)
  | "samples_in_flight", #[b] => return .samplesInFlight (← blockKey b)
  | "held_samples", #[b] => return .heldSamples (← blockKey b)
  | "forwarded", #[p, T] => return .forwarded (← nat p) (← typeId T)
  | "served_hb", #[p] => return .servedHb (← nat p)
  | _, _ => throw s!"not an entry of §6.1's tables: {table}{path.compress}"

/-- An entry's value: `null` for a missing one. An empty value is refused: the tracer writes it as missing. `f`: the
document whose forms a lane and a peer's holding take (`laneEntries`, `haveEntry`). -/
def val (c : Cell) (j : Json) (f : Form := .v1) : Except String (Option Val) := do
  if j == .null then return none
  match c with
  | .askedAt _ | .tried .. | .promise .. | .park .. | .sent _ | .backoff .. | .knownAt _ | .reconsiderAt _ | .dutyAt _ => return some (.time (← bits64 j))
  | .offers _ | .waiters _ =>
    let l ← peers j
    if l.isEmpty then throw "an empty offer list as a value"
    return some (.peers l)
  | .askedParked _ | .holders .. | .rsampleAsked .. | .sampledFrom _ =>
    let l ← peers j
    if l.isEmpty then throw "an empty set as a value"
    if !(l.zip (l.drop 1)).all (fun (x, y) => x < y) then throw s!"a set not sorted, or with a peer twice: {j.compress}"
    return some (.peers l)
  | .offered .. | .received _ | .mine _ | .owedAnswers .. | .sentTo .. | .rebuilt _ | .offeredTo .. | .probeAnswers .. =>
    let b ← nat j
    if b == 0 then throw "an empty bitmap as a value"
    return some (.bits b)
  | .lrArmed _ | .pendingId _ | .probeAsk _ | .probeSent _ => if j == .bool true then return some .flag else throw s!"not a set's member: {j.compress}"
  | .ihaveFrames _ | .ihaveAsked _ | .serveCount .. | .rsampleStep _ | .served .. | .forwarded .. | .servedHb _ =>
    let n ← nat j
    if n == 0 then throw "a count of zero as a value"
    return some (.count n)
  | .heldBack _ => return some (.key (← key j))
  | .state _ => return some (.state (← groupState j))
  | .tied .. | .owed .. => return some (.bits (← nat j))
  | .queue .. => return some (.lane (← laneEntries j f))
  | .pending _ =>
    let l ← waitList j
    if l.isEmpty then throw "an empty list of waits as a value"
    return some (.waits l)
  | .tieSlot .. | .probe _ | .probed _ | .probeWaiting .. => return some (.slot (← nat j))
  | .slotHeld _ | .stopPull _ | .deferred _ | .waited _ | .rsampleFinal _ => if j == .bool true then return some .flag else throw s!"not a set's member: {j.compress}"
  | .peerHas .. => return some (.have (← haveEntry j f))
  | .paceQueue _ =>
    let l ← jobList j
    if l.isEmpty then throw "an empty pace queue as a value"
    return some (.jobs l)
  | .origin _ => return some (.bits (← nat j))
  | .planned .. =>
    let l ← peers j
    if !(l.zip (l.drop 1)).all (fun (x, y) => x < y) then throw s!"a set not sorted, or with a peer twice: {j.compress}"
    return some (.peers l)
  | .pushed .. => return some (.push (← pushEntry j))
  | .desc _ => return some (.desc (← descriptor j))
  | .inFlight _ | .samplesInFlight _ =>
    let n ← intOf j
    if n == 0 then throw "a count of zero as a value"
    return some (.int n)
  | .unwanted _ =>
    let l ← hexes j
    if l.isEmpty then throw "an empty set as a value"
    if !(l.zip (l.drop 1)).all (fun (x, y) => x < y) then throw s!"a set not sorted, or with an id twice: {j.compress}"
    return some (.ids l)
  | .tOf _ => return some (.typeId (← typeId j))
  | .interest _ | .wantP .. => return some (.ibits (← intOf j))
  | .joinRecv .. | .joinSent .. => return some (.join (← joinMsg j))
  | .pushOut .. | .pushIn .. | .graftedOut .. | .graftedIn .. =>
    let l ← natList j
    if l.isEmpty then throw "an empty set of colours as a value"
    if !(l.zip (l.drop 1)).all (fun (x, y) => x < y) then throw s!"a set not sorted, or with a colour twice: {j.compress}"
    return some (.colours l)
  | .owedRelations _ =>
    let l ← relationList j
    if l.isEmpty then throw "an empty list of relations as a value"
    return some (.relations l)
  | .standing .. | .routedStanding .. | .claims _ =>
    let l ← peers j
    if !(l.zip (l.drop 1)).all (fun (x, y) => x < y) then throw s!"a set not sorted, or with a peer twice: {j.compress}"
    return some (.peers l)
  | .probeOk _ => return some (.verdict (← probeVerdict j))
  | .probeServed .. => if j == .bool true then return some .flag else throw s!"not a flag's true: {j.compress}"
  | .rsample _ =>
    let l ← natList j
    if l.isEmpty then throw "an empty list of indices as a value"
    return some (.indices l)
  | .heldSamples _ =>
    let l ← giList j
    if l.isEmpty then throw "an empty list of groups and indices as a value"
    return some (.gis l)
  | .tiedRow _ | .tiedPeerRow .. | .queueRow _ | .owedRow _ | .plannedRow _ =>
    if j == .bool true then return some .flag else throw s!"not a row's presence: {j.compress}"

/-- A level read as a whole: `[table, prefix]`. -/
def level (j : Json) : Except String Level := do
  let #[.str table, pre] ← j.getArr? | throw s!"not a level: {j.compress}"
  match table, ← pre.getArr? with
  | "asked_at", #[] => return .askedAt
  | "tried", #[] => return .triedAll
  | "tried", #[a] => return .tried (← key a)
  | "offers", #[] => return .offers
  | "promises", #[] => return .promises
  | "offered", #[] => return .offeredAll
  | "offered", #[q] => return .offered (← nat q)
  | "park", #[] => return .parkAll
  | "park", #[p] => return .park (← nat p)
  | "asked_parked", #[] => return .askedParked
  | "last_resort_armed", #[] => return .lrArmed
  | "ihave_frames", #[] => return .ihaveFrames
  | "ihave_asked", #[] => return .ihaveAsked
  | "held_back", #[] => return .heldBack
  | "received", #[] => return .received
  | "mine", #[] => return .mine
  | "state", #[] => return .state
  | "tied", #[] => return .tiedAll
  | "tied", #[r] => return .tiedRoot (← rootKey r)
  | "tied", #[r, p] => return .tiedPeer (← rootKey r) (← nat p)
  | "queue", #[] => return .queueAll
  | "pending", #[] => return .pending
  | "pending_ids", #[] => return .pendingIds
  | "tie_slot", #[] => return .tieSlot
  | "owed", #[p] => return .owed (← nat p)
  | "owed", #[] => return .owedAll
  | "owed_answers", #[p] => return .owedAnswers (← nat p)
  | "owed_answers", #[] => return .owedAnswersAll
  | "sent_to", #[] => return .sentToAll
  | "slot_held", #[] => return .slotHeld
  | "pace_queue", #[] => return .paceQueue
  | "stop_pull", #[] => return .stopPull
  | "peer_has", #[] => return .peerHas
  | "holders", #[] => return .holders
  | "serve_count", #[] => return .serveCount
  | "origin", #[] => return .origin
  | "planned", #[] => return .plannedAll
  | "pushed", #[] => return .pushed
  | "desc", #[] => return .desc
  | "in_flight", #[] => return .inFlight
  | "waiters", #[] => return .waiters
  | "sent", #[] => return .sent
  | "unwanted", #[] => return .unwanted
  | "join_recv", #[] => return .joinRecvAll
  | "join_sent", #[] => return .joinSentAll
  | "push_out", #[] => return .pushOutAll
  | "push_in", #[] => return .pushInAll
  | "grafted_out", #[] => return .graftedOutAll
  | "grafted_in", #[] => return .graftedInAll
  | "owed_relations", #[] => return .owedRelations
  | "backoff", #[] => return .backoffAll
  | "T_of", #[] => return .tOf
  | "rebuilt", #[] => return .rebuilt
  | "interest", #[] => return .interest
  | "known_at", #[] => return .knownAt
  | "standing", #[g] => return .standing (← groupKey g)
  | "standing", #[] => return .standingAll
  | "routed_standing", #[] => return .routedStandingAll
  | "claims", #[] => return .claims
  | "reconsider_at", #[] => return .reconsiderAt
  | "deferred", #[] => return .deferred
  | "duty_at", #[] => return .dutyAt
  | "waited", #[] => return .waited
  | "probe", #[] => return .probe
  | "probed", #[] => return .probed
  | "probe_asks", #[] => return .probeAsk
  | "probe_sent", #[] => return .probeSent
  | "probe_ok", #[] => return .probeOk
  | "rsample", #[] => return .rsample
  | "rsample_step", #[] => return .rsampleStep
  | "rsample_asked", #[] => return .rsampleAskedAll
  | "rsample_final", #[] => return .rsampleFinal
  | "served", #[] => return .servedAll
  | "offered_to", #[] => return .offeredToAll
  | "want_p", #[] => return .wantPAll
  | "probe_served", #[] => return .probeServedAll
  | "probe_answers", #[] => return .probeAnswersAll
  | "probe_waiting", #[g] => return .probeWaiting (← groupKey g)
  | "probe_waiting", #[] => return .probeWaitingAll
  | "sampled_from", #[] => return .sampledFrom
  | "samples_in_flight", #[] => return .samplesInFlight
  | "held_samples", #[] => return .heldSamples
  | "forwarded", #[] => return .forwarded
  | "served_hb", #[] => return .servedHb
  | _, _ => throw s!"not a level of §6.1's tables: {j.compress}"

/-- An entry's value in a state: none where it is missing or empty. -/
def valueAt (s : State) : Cell → Option Val
  | .askedAt a => (s.askedAt.get? a).map (.time ·.toBits)
  | .tried a p => ((s.tried.getD a {}).get? p).map (.time ·.toBits)
  | .offers a => match s.offers.getD a [] with
    | [] => none
    | l => some (.peers l)
  | .promise a p => (s.promises.get? (a, p)).map (.time ·.toBits)
  | .offered q g => match (s.offered.getD q {}).getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .park p g => ((s.park.getD p {}).get? g).map (.time ·.toBits)
  | .askedParked k => match sortBy (· < ·) (s.askedParked.getD k {}).toList with
    | [] => none
    | l => some (.peers l)
  | .lrArmed k => if s.lastResortArmed.contains k then some .flag else none
  | .ihaveFrames p => match s.ihaveFrames.getD p 0 with
    | 0 => none
    | n => some (.count n)
  | .ihaveAsked p => match s.ihaveAsked.getD p 0 with
    | 0 => none
    | n => some (.count n)
  | .heldBack k => (s.heldBack.get? k).map (.key ·)
  | .received g => match s.received.getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .mine g => match s.mine.getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .state g => (s.state.get? g).map (.state ·)
  | .tied r p g => (((s.tied.getD r {}).getD p {}).get? g).map (.bits ·)
  | .tiedRow r => if s.tied.contains r then some .flag else none
  | .tiedPeerRow r p => if (s.tied.getD r {}).contains p then some .flag else none
  | .queue p l => ((s.queue.getD p {}).get? l).map (.lane ·)
  | .queueRow p => if s.queue.contains p then some .flag else none
  | .pending r => match s.pending.getD r [] with
    | [] => none
    | l => some (.waits l)
  | .pendingId m => if s.pendingIds.contains m then some .flag else none
  | .tieSlot r p => (s.tieSlot.get? (r, p)).map (.slot ·)
  | .owed p g => ((s.owed.getD p {}).get? g).map (.bits ·)
  | .owedRow p => if s.owed.contains p then some .flag else none
  | .owedAnswers p g => match (s.owedAnswers.getD p {}).getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .sentTo p g => match (s.sentTo.getD p {}).getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .slotHeld p => if s.slotHeld.contains p then some .flag else none
  | .paceQueue e => match s.paceQueue.getD e [] with
    | [] => none
    | l => some (.jobs l)
  | .stopPull g => if s.stopPull.contains g then some .flag else none
  | .peerHas p g => ((s.peerHas.getD p {}).get? g).map (.have ·)
  | .holders g i => match sortBy (· < ·) ((s.holders.getD g {}).getD i {}).toList with
    | [] => none
    | l => some (.peers l)
  | .serveCount p m => match (s.serveCount.getD p {}).getD m 0 with
    | 0 => none
    | n => some (.count n)
  | .origin g => (s.origin.get? g).map (.bits ·)
  | .planned g i => ((s.planned.getD g {}).get? i).map (fun ps => .peers (sortBy (· < ·) ps.toList))
  | .plannedRow g => if s.planned.contains g then some .flag else none
  | .pushed p g => ((s.pushed.getD p {}).get? g).map (.push ·)
  | .desc g => (s.desc.get? g).map (.desc ·)
  | .inFlight e => match s.inFlight.getD e 0 with
    | 0 => none
    | n => some (.int n)
  | .waiters e => match s.waiters.getD e [] with
    | [] => none
    | l => some (.peers l)
  | .sent k => (s.sent.get? k).map (.time ·.toBits)
  | .unwanted p => match sortBy (· < ·) (s.unwanted.getD p {}).toList with
    | [] => none
    | l => some (.ids l)
  | .joinRecv p T => ((s.joinRecv.getD p {}).get? T).map (.join ·)
  | .joinSent p T => ((s.joinSent.getD p {}).get? T).map (.join ·)
  | .pushOut p T fam => match sortBy (· < ·) (((s.pushOut.getD p {}).getD T {}).getD fam {}).toList with
    | [] => none
    | l => some (.colours l)
  | .pushIn p T fam => match sortBy (· < ·) (((s.pushIn.getD p {}).getD T {}).getD fam {}).toList with
    | [] => none
    | l => some (.colours l)
  | .graftedOut p T fam => match sortBy (· < ·) (((s.graftedOut.getD p {}).getD T {}).getD fam {}).toList with
    | [] => none
    | l => some (.colours l)
  | .graftedIn p T fam => match sortBy (· < ·) (((s.graftedIn.getD p {}).getD T {}).getD fam {}).toList with
    | [] => none
    | l => some (.colours l)
  | .owedRelations p => match s.owedRelations.getD p [] with
    | [] => none
    | l => some (.relations l)
  | .backoff p T fam cd => ((((s.backoff.getD p {}).getD T {}).getD fam {}).get? cd).map (.time ·.toBits)
  | .tOf g => (s.tOf.get? g).map (.typeId ·)
  | .rebuilt g => match s.rebuilt.getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .interest g => (s.interest.get? g).map (.ibits ·)
  | .knownAt g => (s.knownAt.get? g).map (.time ·.toBits)
  | .standing g i => ((s.standing.getD g {}).get? i).map (fun ps => .peers (sortBy (· < ·) ps.toList))
  | .routedStanding g i => ((s.routedStanding.getD g {}).get? i).map (fun ps => .peers (sortBy (· < ·) ps.toList))
  | .claims g => (s.claims.get? g).map (fun ps => .peers (sortBy (· < ·) ps.toList))
  | .reconsiderAt g => (s.reconsiderAt.get? g).map (.time ·.toBits)
  | .deferred g => if s.deferred.contains g then some .flag else none
  | .dutyAt g => (s.dutyAt.get? g).map (.time ·.toBits)
  | .waited g => if s.waited.contains g then some .flag else none
  | .probe g => (s.probe.get? g).map (.slot ·)
  | .probed g => (s.probed.get? g).map (.slot ·)
  | .probeAsk a => if s.probeAsks.contains a then some .flag else none
  | .probeSent g => if s.probeSent.contains g then some .flag else none
  | .probeOk g => (s.probeOk.get? g).map (.verdict ·)
  | .rsample g => match s.rsample.getD g [] with
    | [] => none
    | l => some (.indices l)
  | .rsampleStep g => match s.rsampleStep.getD g 0 with
    | 0 => none
    | n => some (.count n)
  | .rsampleAsked g i => match sortBy (· < ·) ((s.rsampleAsked.getD g {}).getD i {}).toList with
    | [] => none
    | l => some (.peers l)
  | .rsampleFinal g => if s.rsampleFinal.contains g then some .flag else none
  | .served p g => match (s.served.getD p {}).getD g 0 with
    | 0 => none
    | n => some (.count n)
  | .offeredTo p g => match (s.offeredTo.getD p {}).getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .wantP p g => ((s.wantP.getD p {}).get? g).map (.ibits ·)
  | .probeServed p g => if (s.probeServed.getD p {}).getD g false then some .flag else none
  | .probeAnswers p g => match (s.probeAnswers.getD p {}).getD g 0 with
    | 0 => none
    | b => some (.bits b)
  | .probeWaiting g p => ((s.probeWaiting.getD g {}).get? p).map (.slot ·)
  | .sampledFrom b => match sortBy (· < ·) (s.sampledFrom.getD b {}).toList with
    | [] => none
    | l => some (.peers l)
  | .samplesInFlight b => match s.samplesInFlight.getD b 0 with
    | 0 => none
    | n => some (.int n)
  | .heldSamples b => match s.heldSamples.getD b [] with
    | [] => none
    | l => some (.gis l)
  | .forwarded p T => match (s.forwarded.getD p {}).getD T 0 with
    | 0 => none
    | n => some (.count n)
  | .servedHb p => match s.servedHb.getD p 0 with
    | 0 => none
    | n => some (.count n)

/-- A state with one more entry: how a record's `reads` become the twin's state. -/
def put (s : State) (c : Cell) (v : Val) : Except String State :=
  match c, v with
  | .askedAt a, .time t => pure { s with askedAt := s.askedAt.insert a (Float.ofBits t) }
  | .tried a p, .time t => pure { s with tried := s.tried.insert a ((s.tried.getD a {}).insert p (Float.ofBits t)) }
  | .offers a, .peers l => pure { s with offers := s.offers.insert a l }
  | .promise a p, .time t => pure { s with promises := s.promises.insert (a, p) (Float.ofBits t) }
  | .offered q g, .bits b => pure { s with offered := s.offered.insert q ((s.offered.getD q {}).insert g b) }
  | .park p g, .time t => pure { s with park := s.park.insert p ((s.park.getD p {}).insert g (Float.ofBits t)) }
  | .askedParked k, .peers l => pure { s with askedParked := s.askedParked.insert k (l.foldl (·.insert ·) {}) }
  | .lrArmed k, .flag => pure { s with lastResortArmed := s.lastResortArmed.insert k }
  | .ihaveFrames p, .count n => pure { s with ihaveFrames := s.ihaveFrames.insert p n }
  | .ihaveAsked p, .count n => pure { s with ihaveAsked := s.ihaveAsked.insert p n }
  | .heldBack k, .key a => pure { s with heldBack := s.heldBack.insert k a }
  | .received g, .bits b => pure { s with received := s.received.insert g b }
  | .mine g, .bits b => pure { s with mine := s.mine.insert g b }
  | .state g, .state x => pure { s with state := s.state.insert g x }
  | .tied r p g, .bits b => pure { s with tied := s.tied.insert r ((s.tied.getD r {}).insert p (((s.tied.getD r {}).getD p {}).insert g b)) }
  | .tiedRow r, .flag => pure { s with tied := (if s.tied.contains r then s.tied else s.tied.insert r {}) }
  | .tiedPeerRow r p, .flag => pure { s with tied := s.tied.insert r (if (s.tied.getD r {}).contains p then (s.tied.getD r {}) else (s.tied.getD r {}).insert p {}) }
  | .queue p l, .lane es => pure { s with queue := s.queue.insert p ((s.queue.getD p {}).insert l es) }
  | .queueRow p, .flag => pure { s with queue := (if s.queue.contains p then s.queue else s.queue.insert p {}) }
  | .pending r, .waits w => pure { s with pending := s.pending.insert r w }
  | .pendingId m, .flag => pure { s with pendingIds := s.pendingIds.insert m }
  | .tieSlot r p, .slot n => pure { s with tieSlot := s.tieSlot.insert (r, p) n }
  | .owed p g, .bits b => pure { s with owed := s.owed.insert p ((s.owed.getD p {}).insert g b) }
  | .owedRow p, .flag => pure { s with owed := (if s.owed.contains p then s.owed else s.owed.insert p {}) }
  | .owedAnswers p g, .bits b => pure { s with owedAnswers := s.owedAnswers.insert p ((s.owedAnswers.getD p {}).insert g b) }
  | .sentTo p g, .bits b => pure { s with sentTo := s.sentTo.insert p ((s.sentTo.getD p {}).insert g b) }
  | .slotHeld p, .flag => pure { s with slotHeld := s.slotHeld.insert p }
  | .paceQueue e, .jobs js => pure { s with paceQueue := s.paceQueue.insert e js }
  | .stopPull g, .flag => pure { s with stopPull := s.stopPull.insert g }
  | .peerHas p g, .have e => pure { s with peerHas := s.peerHas.insert p ((s.peerHas.getD p {}).insert g e) }
  | .holders g i, .peers l => pure { s with holders := s.holders.insert g ((s.holders.getD g {}).insert i (l.foldl (·.insert ·) {})) }
  | .serveCount p m, .count n => pure { s with serveCount := s.serveCount.insert p ((s.serveCount.getD p {}).insert m n) }
  | .origin g, .bits b => pure { s with origin := s.origin.insert g b }
  | .planned g i, .peers l => pure { s with planned := s.planned.insert g ((s.planned.getD g {}).insert i (l.foldl (·.insert ·) {})) }
  | .plannedRow g, .flag => pure { s with planned := (if s.planned.contains g then s.planned else s.planned.insert g {}) }
  | .pushed p g, .push e => pure { s with pushed := s.pushed.insert p ((s.pushed.getD p {}).insert g e) }
  | .desc g, .desc d => pure { s with desc := s.desc.insert g d }
  | .inFlight e, .int n => pure { s with inFlight := s.inFlight.insert e n }
  | .waiters e, .peers l => pure { s with waiters := s.waiters.insert e l }
  | .sent k, .time t => pure { s with sent := s.sent.insert k (Float.ofBits t) }
  | .unwanted p, .ids l => pure { s with unwanted := s.unwanted.insert p (l.foldl (·.insert ·) {}) }
  | .joinRecv p T, .join m => pure { s with joinRecv := s.joinRecv.insert p ((s.joinRecv.getD p {}).insert T m) }
  | .joinSent p T, .join m => pure { s with joinSent := s.joinSent.insert p ((s.joinSent.getD p {}).insert T m) }
  | .pushOut p T fam, .colours l => pure { s with pushOut := s.pushOut.insert p ((s.pushOut.getD p {}).insert T (((s.pushOut.getD p {}).getD T {}).insert fam (l.foldl (·.insert ·) {}))) }
  | .pushIn p T fam, .colours l => pure { s with pushIn := s.pushIn.insert p ((s.pushIn.getD p {}).insert T (((s.pushIn.getD p {}).getD T {}).insert fam (l.foldl (·.insert ·) {}))) }
  | .graftedOut p T fam, .colours l => pure { s with graftedOut := s.graftedOut.insert p ((s.graftedOut.getD p {}).insert T (((s.graftedOut.getD p {}).getD T {}).insert fam (l.foldl (·.insert ·) {}))) }
  | .graftedIn p T fam, .colours l => pure { s with graftedIn := s.graftedIn.insert p ((s.graftedIn.getD p {}).insert T (((s.graftedIn.getD p {}).getD T {}).insert fam (l.foldl (·.insert ·) {}))) }
  | .owedRelations p, .relations l => pure { s with owedRelations := s.owedRelations.insert p l }
  | .backoff p T fam cd, .time t => pure { s with backoff := s.backoff.insert p ((s.backoff.getD p {}).insert T (((s.backoff.getD p {}).getD T {}).insert fam ((((s.backoff.getD p {}).getD T {}).getD fam {}).insert cd (Float.ofBits t)))) }
  | .tOf g, .typeId x => pure { s with tOf := s.tOf.insert g x }
  | .rebuilt g, .bits b => pure { s with rebuilt := s.rebuilt.insert g b }
  | .interest g, .ibits b => pure { s with interest := s.interest.insert g b }
  | .knownAt g, .time t => pure { s with knownAt := s.knownAt.insert g (Float.ofBits t) }
  | .standing g i, .peers l => pure { s with standing := s.standing.insert g ((s.standing.getD g {}).insert i (l.foldl (·.insert ·) {})) }
  | .routedStanding g i, .peers l => pure { s with routedStanding := s.routedStanding.insert g ((s.routedStanding.getD g {}).insert i (l.foldl (·.insert ·) {})) }
  | .claims g, .peers l => pure { s with claims := s.claims.insert g (l.foldl (·.insert ·) {}) }
  | .reconsiderAt g, .time t => pure { s with reconsiderAt := s.reconsiderAt.insert g (Float.ofBits t) }
  | .deferred g, .flag => pure { s with deferred := s.deferred.insert g }
  | .dutyAt g, .time t => pure { s with dutyAt := s.dutyAt.insert g (Float.ofBits t) }
  | .waited g, .flag => pure { s with waited := s.waited.insert g }
  | .probe g, .slot n => pure { s with probe := s.probe.insert g n }
  | .probed g, .slot n => pure { s with probed := s.probed.insert g n }
  | .probeAsk a, .flag => pure { s with probeAsks := s.probeAsks.insert a }
  | .probeSent g, .flag => pure { s with probeSent := s.probeSent.insert g }
  | .probeOk g, .verdict v => pure { s with probeOk := s.probeOk.insert g v }
  | .rsample g, .indices l => pure { s with rsample := s.rsample.insert g l }
  | .rsampleStep g, .count n => pure { s with rsampleStep := s.rsampleStep.insert g n }
  | .rsampleAsked g i, .peers l => pure { s with rsampleAsked := s.rsampleAsked.insert g ((s.rsampleAsked.getD g {}).insert i (l.foldl (·.insert ·) {})) }
  | .rsampleFinal g, .flag => pure { s with rsampleFinal := s.rsampleFinal.insert g }
  | .served p g, .count n => pure { s with served := s.served.insert p ((s.served.getD p {}).insert g n) }
  | .offeredTo p g, .bits b => pure { s with offeredTo := s.offeredTo.insert p ((s.offeredTo.getD p {}).insert g b) }
  | .wantP p g, .ibits b => pure { s with wantP := s.wantP.insert p ((s.wantP.getD p {}).insert g b) }
  | .probeServed p g, .flag => pure { s with probeServed := s.probeServed.insert p ((s.probeServed.getD p {}).insert g true) }
  | .probeAnswers p g, .bits b => pure { s with probeAnswers := s.probeAnswers.insert p ((s.probeAnswers.getD p {}).insert g b) }
  | .probeWaiting g p, .slot n => pure { s with probeWaiting := s.probeWaiting.insert g ((s.probeWaiting.getD g {}).insert p n) }
  | .sampledFrom b, .peers l => pure { s with sampledFrom := s.sampledFrom.insert b (l.foldl (·.insert ·) {}) }
  | .samplesInFlight b, .int n => pure { s with samplesInFlight := s.samplesInFlight.insert b n }
  | .heldSamples b, .gis l => pure { s with heldSamples := s.heldSamples.insert b l }
  | .forwarded p T, .count n => pure { s with forwarded := s.forwarded.insert p ((s.forwarded.getD p {}).insert T n) }
  | .servedHb p, .count n => pure { s with servedHb := s.servedHb.insert p n }
  | c, v => throw s!"not a value of {reprStr c}: {reprStr v}"

/-- A state without an entry: how a record's erasing write is applied. -/
def drop (s : State) : Cell → State
  | .askedAt a => { s with askedAt := s.askedAt.erase a }
  | .tried a p => { s with tried := s.tried.insert a ((s.tried.getD a {}).erase p) }
  | .offers a => { s with offers := s.offers.erase a }
  | .promise a p => { s with promises := s.promises.erase (a, p) }
  | .offered q g => { s with offered := s.offered.insert q ((s.offered.getD q {}).erase g) }
  | .park p g => { s with park := s.park.insert p ((s.park.getD p {}).erase g) }
  | .askedParked k => { s with askedParked := s.askedParked.erase k }
  | .lrArmed k => { s with lastResortArmed := s.lastResortArmed.erase k }
  | .ihaveFrames p => { s with ihaveFrames := s.ihaveFrames.erase p }
  | .ihaveAsked p => { s with ihaveAsked := s.ihaveAsked.erase p }
  | .heldBack k => { s with heldBack := s.heldBack.erase k }
  | .received g => { s with received := s.received.erase g }
  | .mine g => { s with mine := s.mine.erase g }
  | .state g => { s with state := s.state.erase g }
  | .tied r p g => { s with tied := s.tied.modify r (·.modify p (·.erase g)) }
  | .tiedRow r => { s with tied := s.tied.erase r }
  | .tiedPeerRow r p => { s with tied := s.tied.modify r (·.erase p) }
  | .queue p l => { s with queue := s.queue.modify p (·.erase l) }
  | .queueRow p => { s with queue := s.queue.erase p }
  | .pending r => { s with pending := s.pending.erase r }
  | .pendingId m => { s with pendingIds := s.pendingIds.erase m }
  | .tieSlot r p => { s with tieSlot := s.tieSlot.erase (r, p) }
  | .owed p g => { s with owed := s.owed.modify p (·.erase g) }
  | .owedRow p => { s with owed := s.owed.erase p }
  | .owedAnswers p g => { s with owedAnswers := s.owedAnswers.insert p ((s.owedAnswers.getD p {}).erase g) }
  | .sentTo p g => { s with sentTo := s.sentTo.insert p ((s.sentTo.getD p {}).erase g) }
  | .slotHeld p => { s with slotHeld := s.slotHeld.erase p }
  | .paceQueue e => { s with paceQueue := s.paceQueue.erase e }
  | .stopPull g => { s with stopPull := s.stopPull.erase g }
  | .peerHas p g => { s with peerHas := s.peerHas.insert p ((s.peerHas.getD p {}).erase g) }
  | .holders g i => { s with holders := s.holders.insert g ((s.holders.getD g {}).erase i) }
  | .serveCount p m => { s with serveCount := s.serveCount.insert p ((s.serveCount.getD p {}).erase m) }
  | .origin g => { s with origin := s.origin.erase g }
  | .planned g i => { s with planned := s.planned.modify g (·.erase i) }
  | .plannedRow g => { s with planned := s.planned.erase g }
  | .pushed p g => { s with pushed := s.pushed.insert p ((s.pushed.getD p {}).erase g) }
  | .desc g => { s with desc := s.desc.erase g }
  | .inFlight e => { s with inFlight := s.inFlight.erase e }
  | .waiters e => { s with waiters := s.waiters.erase e }
  | .sent k => { s with sent := s.sent.erase k }
  | .unwanted p => { s with unwanted := s.unwanted.erase p }
  | .joinRecv p T => { s with joinRecv := s.joinRecv.insert p ((s.joinRecv.getD p {}).erase T) }
  | .joinSent p T => { s with joinSent := s.joinSent.insert p ((s.joinSent.getD p {}).erase T) }
  | .pushOut p T fam => { s with pushOut := s.pushOut.insert p ((s.pushOut.getD p {}).insert T (((s.pushOut.getD p {}).getD T {}).erase fam)) }
  | .pushIn p T fam => { s with pushIn := s.pushIn.insert p ((s.pushIn.getD p {}).insert T (((s.pushIn.getD p {}).getD T {}).erase fam)) }
  | .graftedOut p T fam => { s with graftedOut := s.graftedOut.insert p ((s.graftedOut.getD p {}).insert T (((s.graftedOut.getD p {}).getD T {}).erase fam)) }
  | .graftedIn p T fam => { s with graftedIn := s.graftedIn.insert p ((s.graftedIn.getD p {}).insert T (((s.graftedIn.getD p {}).getD T {}).erase fam)) }
  | .owedRelations p => { s with owedRelations := s.owedRelations.erase p }
  | .backoff p T fam cd => { s with backoff := s.backoff.insert p ((s.backoff.getD p {}).insert T (((s.backoff.getD p {}).getD T {}).insert fam ((((s.backoff.getD p {}).getD T {}).getD fam {}).erase cd))) }
  | .tOf g => { s with tOf := s.tOf.erase g }
  | .rebuilt g => { s with rebuilt := s.rebuilt.erase g }
  | .interest g => { s with interest := s.interest.erase g }
  | .knownAt g => { s with knownAt := s.knownAt.erase g }
  | .standing g i => { s with standing := s.standing.insert g ((s.standing.getD g {}).erase i) }
  | .routedStanding g i => { s with routedStanding := s.routedStanding.insert g ((s.routedStanding.getD g {}).erase i) }
  | .claims g => { s with claims := s.claims.erase g }
  | .reconsiderAt g => { s with reconsiderAt := s.reconsiderAt.erase g }
  | .deferred g => { s with deferred := s.deferred.erase g }
  | .dutyAt g => { s with dutyAt := s.dutyAt.erase g }
  | .waited g => { s with waited := s.waited.erase g }
  | .probe g => { s with probe := s.probe.erase g }
  | .probed g => { s with probed := s.probed.erase g }
  | .probeAsk a => { s with probeAsks := s.probeAsks.erase a }
  | .probeSent g => { s with probeSent := s.probeSent.erase g }
  | .probeOk g => { s with probeOk := s.probeOk.erase g }
  | .rsample g => { s with rsample := s.rsample.erase g }
  | .rsampleStep g => { s with rsampleStep := s.rsampleStep.erase g }
  | .rsampleAsked g i => { s with rsampleAsked := s.rsampleAsked.insert g ((s.rsampleAsked.getD g {}).erase i) }
  | .rsampleFinal g => { s with rsampleFinal := s.rsampleFinal.erase g }
  | .served p g => { s with served := s.served.insert p ((s.served.getD p {}).erase g) }
  | .offeredTo p g => { s with offeredTo := s.offeredTo.insert p ((s.offeredTo.getD p {}).erase g) }
  | .wantP p g => { s with wantP := s.wantP.insert p ((s.wantP.getD p {}).erase g) }
  | .probeServed p g => { s with probeServed := s.probeServed.insert p ((s.probeServed.getD p {}).erase g) }
  | .probeAnswers p g => { s with probeAnswers := s.probeAnswers.insert p ((s.probeAnswers.getD p {}).erase g) }
  | .probeWaiting g p => { s with probeWaiting := s.probeWaiting.insert g ((s.probeWaiting.getD g {}).erase p) }
  | .sampledFrom b => { s with sampledFrom := s.sampledFrom.erase b }
  | .samplesInFlight b => { s with samplesInFlight := s.samplesInFlight.erase b }
  | .heldSamples b => { s with heldSamples := s.heldSamples.erase b }
  | .forwarded p T => { s with forwarded := s.forwarded.insert p ((s.forwarded.getD p {}).erase T) }
  | .servedHb p => { s with servedHb := s.servedHb.erase p }

/-- Every entry a state holds, empty ones left out: what two states are compared by. -/
def entries (s : State) : List (Cell × Val) :=
  let all : List Cell :=
    s.askedAt.toList.map (fun (a, _) => .askedAt a)
    ++ s.tried.toList.flatMap (fun (a, m) => m.toList.map fun (p, _) => .tried a p)
    ++ s.offers.toList.map (fun (a, _) => .offers a)
    ++ s.promises.toList.map (fun ((a, p), _) => .promise a p)
    ++ s.offered.toList.flatMap (fun (q, m) => m.toList.map fun (g, _) => .offered q g)
    ++ s.park.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .park p g)
    ++ s.askedParked.toList.map (fun (k, _) => .askedParked k)
    ++ s.lastResortArmed.toList.map (fun k => .lrArmed k)
    ++ s.ihaveFrames.toList.map (fun (p, _) => .ihaveFrames p)
    ++ s.ihaveAsked.toList.map (fun (p, _) => .ihaveAsked p)
    ++ s.heldBack.toList.map (fun (k, _) => .heldBack k)
    ++ s.received.toList.map (fun (g, _) => .received g)
    ++ s.mine.toList.map (fun (g, _) => .mine g)
    ++ s.state.toList.map (fun (g, _) => .state g)
    ++ s.tied.toList.flatMap (fun (r, m) => m.toList.flatMap fun (p, m) => m.toList.map fun (g, _) => .tied r p g)
    ++ s.tied.toList.map (fun (r, _) => .tiedRow r)
    ++ s.tied.toList.flatMap (fun (r, m) => m.toList.map fun (p, _) => .tiedPeerRow r p)
    ++ s.queue.toList.flatMap (fun (p, m) => m.toList.map fun (l, _) => .queue p l)
    ++ s.queue.toList.map (fun (p, _) => .queueRow p)
    ++ s.pending.toList.map (fun (r, _) => .pending r)
    ++ s.pendingIds.toList.map (fun m => .pendingId m)
    ++ s.tieSlot.toList.map (fun ((r, p), _) => .tieSlot r p)
    ++ s.owed.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .owed p g)
    ++ s.owed.toList.map (fun (p, _) => .owedRow p)
    ++ s.owedAnswers.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .owedAnswers p g)
    ++ s.sentTo.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .sentTo p g)
    ++ s.slotHeld.toList.map (fun p => .slotHeld p)
    ++ s.paceQueue.toList.map (fun (e, _) => .paceQueue e)
    ++ s.stopPull.toList.map (fun g => .stopPull g)
    ++ s.peerHas.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .peerHas p g)
    ++ s.holders.toList.flatMap (fun (g, m) => m.toList.map fun (i, _) => .holders g i)
    ++ s.serveCount.toList.flatMap (fun (p, m) => m.toList.map fun (m, _) => .serveCount p m)
    ++ s.origin.toList.map (fun (g, _) => .origin g)
    ++ s.planned.toList.flatMap (fun (g, m) => m.toList.map fun (i, _) => .planned g i)
    ++ s.planned.toList.map (fun (g, _) => .plannedRow g)
    ++ s.pushed.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .pushed p g)
    ++ s.desc.toList.map (fun (g, _) => .desc g)
    ++ s.inFlight.toList.map (fun (e, _) => .inFlight e)
    ++ s.waiters.toList.map (fun (e, _) => .waiters e)
    ++ s.sent.toList.map (fun (k, _) => .sent k)
    ++ s.unwanted.toList.map (fun (p, _) => .unwanted p)
    ++ s.joinRecv.toList.flatMap (fun (p, m) => m.toList.map fun (T, _) => .joinRecv p T)
    ++ s.joinSent.toList.flatMap (fun (p, m) => m.toList.map fun (T, _) => .joinSent p T)
    ++ s.pushOut.toList.flatMap (fun (p, m) => m.toList.flatMap fun (T, m) => m.toList.map fun (fam, _) => .pushOut p T fam)
    ++ s.pushIn.toList.flatMap (fun (p, m) => m.toList.flatMap fun (T, m) => m.toList.map fun (fam, _) => .pushIn p T fam)
    ++ s.graftedOut.toList.flatMap (fun (p, m) => m.toList.flatMap fun (T, m) => m.toList.map fun (fam, _) => .graftedOut p T fam)
    ++ s.graftedIn.toList.flatMap (fun (p, m) => m.toList.flatMap fun (T, m) => m.toList.map fun (fam, _) => .graftedIn p T fam)
    ++ s.owedRelations.toList.map (fun (p, _) => .owedRelations p)
    ++ s.backoff.toList.flatMap (fun (p, m) => m.toList.flatMap fun (T, m) => m.toList.flatMap fun (fam, m) => m.toList.map fun (cd, _) => .backoff p T fam cd)
    ++ s.tOf.toList.map (fun (g, _) => .tOf g)
    ++ s.rebuilt.toList.map (fun (g, _) => .rebuilt g)
    ++ s.interest.toList.map (fun (g, _) => .interest g)
    ++ s.knownAt.toList.map (fun (g, _) => .knownAt g)
    ++ s.standing.toList.flatMap (fun (g, m) => m.toList.map fun (i, _) => .standing g i)
    ++ s.routedStanding.toList.flatMap (fun (g, m) => m.toList.map fun (i, _) => .routedStanding g i)
    ++ s.claims.toList.map (fun (g, _) => .claims g)
    ++ s.reconsiderAt.toList.map (fun (g, _) => .reconsiderAt g)
    ++ s.deferred.toList.map (fun g => .deferred g)
    ++ s.dutyAt.toList.map (fun (g, _) => .dutyAt g)
    ++ s.waited.toList.map (fun g => .waited g)
    ++ s.probe.toList.map (fun (g, _) => .probe g)
    ++ s.probed.toList.map (fun (g, _) => .probed g)
    ++ s.probeAsks.toList.map (fun a => .probeAsk a)
    ++ s.probeSent.toList.map (fun g => .probeSent g)
    ++ s.probeOk.toList.map (fun (g, _) => .probeOk g)
    ++ s.rsample.toList.map (fun (g, _) => .rsample g)
    ++ s.rsampleStep.toList.map (fun (g, _) => .rsampleStep g)
    ++ s.rsampleAsked.toList.flatMap (fun (g, m) => m.toList.map fun (i, _) => .rsampleAsked g i)
    ++ s.rsampleFinal.toList.map (fun g => .rsampleFinal g)
    ++ s.served.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .served p g)
    ++ s.offeredTo.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .offeredTo p g)
    ++ s.wantP.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .wantP p g)
    ++ s.probeServed.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .probeServed p g)
    ++ s.probeAnswers.toList.flatMap (fun (p, m) => m.toList.map fun (g, _) => .probeAnswers p g)
    ++ s.probeWaiting.toList.flatMap (fun (g, m) => m.toList.map fun (p, _) => .probeWaiting g p)
    ++ s.sampledFrom.toList.map (fun (b, _) => .sampledFrom b)
    ++ s.samplesInFlight.toList.map (fun (b, _) => .samplesInFlight b)
    ++ s.heldSamples.toList.map (fun (b, _) => .heldSamples b)
    ++ s.forwarded.toList.flatMap (fun (p, m) => m.toList.map fun (T, _) => .forwarded p T)
    ++ s.servedHb.toList.map (fun (p, _) => .servedHb p)
  all.filterMap fun c => (valueAt s c).map fun v => (c, v)

/-- Whether a level read as a whole holds an entry. -/
def under (c : Cell) (l : Level) : Bool :=
  match l, c with
  | .askedAt, .askedAt _ => true
  | .triedAll, .tried .. => true
  | .tried a, .tried b _ => a == b
  | .offers, .offers _ => true
  | .promises, .promise .. => true
  | .offeredAll, .offered .. => true
  | .offered q, .offered r _ => q == r
  | .parkAll, .park .. => true
  | .park p, .park r _ => p == r
  | .askedParked, .askedParked _ => true
  | .lrArmed, .lrArmed _ => true
  | .ihaveFrames, .ihaveFrames _ => true
  | .ihaveAsked, .ihaveAsked _ => true
  | .heldBack, .heldBack _ => true
  | .received, .received _ => true
  | .mine, .mine _ => true
  | .state, .state _ => true
  | .tiedAll, .tied .. => true
  | .tiedAll, .tiedRow _ => true
  | .tiedAll, .tiedPeerRow .. => true
  | .tiedRoot r, .tied r' _ _ => r == r'
  | .tiedRoot r, .tiedPeerRow r' _ => r == r'
  | .tiedPeer r p, .tied r' p' _ => r == r' && p == p'
  | .queueAll, .queue .. => true
  | .queueAll, .queueRow _ => true
  | .pending, .pending _ => true
  | .pendingIds, .pendingId _ => true
  | .tieSlot, .tieSlot .. => true
  | .owed p, .owed p' _ => p == p'
  | .owedAll, .owed .. => true
  | .owedAll, .owedRow _ => true
  | .owedAnswers p, .owedAnswers p' _ => p == p'
  | .owedAnswersAll, .owedAnswers .. => true
  | .sentToAll, .sentTo .. => true
  | .slotHeld, .slotHeld _ => true
  | .paceQueue, .paceQueue _ => true
  | .stopPull, .stopPull _ => true
  | .peerHas, .peerHas .. => true
  | .holders, .holders .. => true
  | .serveCount, .serveCount .. => true
  | .origin, .origin _ => true
  | .plannedAll, .planned .. => true
  | .plannedAll, .plannedRow _ => true
  | .pushed, .pushed .. => true
  | .desc, .desc _ => true
  | .inFlight, .inFlight _ => true
  | .waiters, .waiters _ => true
  | .sent, .sent _ => true
  | .unwanted, .unwanted _ => true
  | .joinRecvAll, .joinRecv .. => true
  | .joinSentAll, .joinSent .. => true
  | .pushOutAll, .pushOut .. => true
  | .pushInAll, .pushIn .. => true
  | .graftedOutAll, .graftedOut .. => true
  | .graftedInAll, .graftedIn .. => true
  | .owedRelations, .owedRelations _ => true
  | .backoffAll, .backoff .. => true
  | .tOf, .tOf _ => true
  | .rebuilt, .rebuilt _ => true
  | .interest, .interest _ => true
  | .knownAt, .knownAt _ => true
  | .standing g, .standing g' _ => g == g'
  | .standingAll, .standing .. => true
  | .routedStandingAll, .routedStanding .. => true
  | .claims, .claims _ => true
  | .reconsiderAt, .reconsiderAt _ => true
  | .deferred, .deferred _ => true
  | .dutyAt, .dutyAt _ => true
  | .waited, .waited _ => true
  | .probe, .probe _ => true
  | .probed, .probed _ => true
  | .probeAsk, .probeAsk _ => true
  | .probeSent, .probeSent _ => true
  | .probeOk, .probeOk _ => true
  | .rsample, .rsample _ => true
  | .rsampleStep, .rsampleStep _ => true
  | .rsampleAskedAll, .rsampleAsked .. => true
  | .rsampleFinal, .rsampleFinal _ => true
  | .servedAll, .served .. => true
  | .offeredToAll, .offeredTo .. => true
  | .wantPAll, .wantP .. => true
  | .probeServedAll, .probeServed .. => true
  | .probeAnswersAll, .probeAnswers .. => true
  | .probeWaiting g, .probeWaiting g' _ => g == g'
  | .probeWaitingAll, .probeWaiting .. => true
  | .sampledFrom, .sampledFrom _ => true
  | .samplesInFlight, .samplesInFlight _ => true
  | .heldSamples, .heldSamples _ => true
  | .forwarded, .forwarded .. => true
  | .servedHb, .servedHb _ => true
  | _, _ => false

/-- Whether a level holds another: itself, or a table's whole against one of its rows. -/
def covers (l₁ l₂ : Level) : Bool :=
  l₁ == l₂ || match l₁, l₂ with
  | .triedAll, .tried _ => true
  | .offeredAll, .offered _ => true
  | .parkAll, .park _ => true
  | .tiedAll, .tiedRoot _ => true
  | .tiedAll, .tiedPeer _ _ => true
  | .tiedRoot r, .tiedPeer r' _ => r == r'
  | .owedAll, .owed _ => true
  | .owedAnswersAll, .owedAnswers _ => true
  | .standingAll, .standing _ => true
  | .probeWaitingAll, .probeWaiting _ => true
  | _, _ => false

end SpecTwin.Replay
