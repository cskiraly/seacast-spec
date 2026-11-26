# SEACAST: its rationale

This file holds the rationale, evidence and history that accompany [`seacast.md`](seacast.md). It states no rule: the rules are in `seacast.md`, and where the two differ, `seacast.md` holds. Its sections carry `seacast.md`'s numbers and titles, and its text stands as it was written there: "this document" and the section numbers in it refer to `seacast.md`, and "above" and "below" may point to this file or to `seacast.md`.

*The name dates from 2026-10-19; `seacast-lite.md`'s protocol, now SEACAST Lite, was
published at v0.4 as Informed Diffusion, which now names SEACAST's diffusion part (§0, "The
parts"). Up to v0.11.1 this file was `protocol-v2.md` and `seacast-lite.md` was `protocol.md`.*

*This document began as draft 1, of 2026-10-07.*

## 1. Notions

### 1.3 Links, joins and relations

#### Rationale

**A floor built for diversity, not for the fewest links.** Its aim is that the node's samples, one
per peer (§4.10), find distinct peers that serve them, so that no peer learns the node's whole
sample. One link to a node that custodies every column would otherwise cover them all and serve
every sample; this is why a peer of high custody counts for at most `COVER_HIGH` families. Links
chosen before and independently of any sample reveal nothing about what the node will sample
(FullDAS's independence of the sample). A source's holding does not count because a proposer holds
every column of its own block only, and proposers rotate. Two covers were decided on 2026-11-03
(`[D12]`, §8).

**What the floor buys, and what it costs, in the toy.** Without it, a sample of a column none of the
node's links custodies is never served. In the toy's 500-node graphs, some samplers of eight cells
have such a sample at 70 links, and nearly all do at 16. With the floor, on the same graphs, one
cover by the fewest links adds a few sampling-only links at 70 links and many more at 16 (§6.3);
the diversity floor of two covers adds more again (§6.3, §8; seacast-figures.md, §1.3).

**One forwarding step usually reaches the family.** A custodian's floor per column (§1.4) makes it
likely that one of a forwarding link's own links custodies the sample's family: in the toy's graphs
the floor gives a custodian many more links than a degree of 16 (seacast-figures.md, §1.3).

## 4. Events

### 4.1 Joining, and keeping the relations

#### Rationale

**A refusal names its direction from its sender's side** (decided 2026-11-01). The refusals had
echoed the GRAFT's direction, which undid the opposite relation at the grafter.

**A GRAFT is answered** (decided 2026-11-04).

- **Why.** Silence cannot tell a yes from a GRAFT not yet read, refused by a full queue or ignored.
  Counted at once, a GRAFT that is never accepted leaves its sender pushing a peer that does not
  count it, or counting a pusher that does not push, and the floor per colour (§1.4) is only as
  good as its count. Gossipsub keeps the two ends' views together with its backoff after a PRUNE,
  which must outlast the round trip at both ends. Here the agreement rests on no timer, and the
  backoff only paces the next GRAFT. The cost is a control message per accepted GRAFT, and an offer
  to push takes effect a round trip after the GRAFT, where silence let it start at once; a request
  to be pushed takes effect when the pusher says yes, as before. A peer that agrees and then does
  not push is not caught by this, as it was not before.

- **Checked** (`toy/graft_check.py`): the check runs this section's functions as written, on two
  nodes, from the link's first JOIN, sent by either end or both, for one relation over an ordered
  connection with queues of one entry and other traffic taking their room, with each end's upkeep
  grafting or pruning up to three times and every GRAFT accepted or refused at will. In every state
  with nothing queued, owed or on the wire, the two ends agree and no GRAFT is unanswered, and every
  exchange ends. The check fails where it should: on the text before this rule
  (`toy/controls/graft-unanswered.md`), where the GRAFT's sender recorded nothing (the ends disagree
  in nearly half of such states at two upkeep steps), and on this rule without the owing, with an
  owed message overtaken, without the yes, or with a PRUNE that leaves the receiver's GRAFT standing
  (seacast-figures.md, §4.1). The toy's recorded cells keep their relations static and do not
  run this; under `--upkeep on` it runs this section on the wire.

- **Compared** (`toy/graft_check.py --model`: one relation in the abstract, without queues, four
  upkeep steps per end): with the relation counted at the GRAFT, many states at rest disagree
  without a backoff, and none do with a backoff longer than the round trip; with the GRAFT answered,
  none do (seacast-figures.md, §4.1).

**A GRAFT for a relation already held is answered yes again** (decided 2026-11-09).

- **Why.** From ends that agree, the rules keep them agreed (Checked, above). Where they diverge,
  one end in a relation the other has left through lost state or a peer's error, the other end's
  GRAFT for that relation went unanswered: its sender kept it unanswered and never grafted that peer
  again for the relation, while the receiver counted a pusher that did not push, or pushed a peer
  that did not count it. When the sender receives the repeated yes, it joins the relation it asked
  for, and the ends agree.

- **Checked** (`toy/graft_check.py --diverged`). The check starts from linked ends that disagree:
  one counts a pusher that does not push, or pushes a peer that does not count it; with `--both`,
  the two ends hold the relation in any way but whole at both or at neither. At three upkeep steps,
  every state at rest once an upkeep has acted agrees, with no GRAFT unanswered, and every exchange
  ends (seacast-figures.md, §4.1). The text before (`toy/controls/held-graft-unanswered.md`)
  fails: a GRAFT for a relation the receiver holds goes unanswered in some states at rest, at two
  steps. Without the mark, the check finds an exchange that never ends, at two steps. One end's
  PRUNE crosses the other's later GRAFT, the first end accepts that GRAFT, the second decides its
  yes as a new GRAFT, and the two then answer each other's yes for ever.

**A symmetric relation** (decided 2026-11-09).

- **Why at `F_HI`.** Gossipsub's heartbeat prunes a mesh above `D_high` down to `D`, and a mesh gets
  there because, at `D_high`, gossipsub v1.1 refuses only a GRAFT from an inbound connection. Here
  `on_graft` refuses at `F_HI` for every peer, so a prune that waited for more than `F_HI` would
  never run: the relations would rest wherever the GRAFTs left them, near `F_HI`, and cost more
  bytes wherever every relation is pushed (tier 1). In the toy (the payload at 60 nodes, under
  `--upkeep on` with links replaced, one seed), with a prune only above `F_HI` no node was ever
  pruned, and nodes ended at the cap, `F_HI`. With the prune at `F_HI`, no node ended at the cap,
  and the relations per node averaged fewer (seacast-figures.md, §4.1).

- **Why at random.** A capped relation is first come, first served: a full node refuses later
  GRAFTs, and near peers' GRAFTs arrive first, so the relations lean on near peers. Gossipsub's
  prune keeps `D_score` peers by score and the rest at random; scoring is the client's, and the draw
  is this rule's.

- **Checked** (`toy/graft_check.py --both`: both ends graft the relation below `F_LO` and prune it
  at `F_HI`). At three upkeep steps, in every state at rest, the ends agree in both directions and
  each end holds both or neither, with no GRAFT unanswered, and every exchange ends. In every state
  at rest of these runs and of `--both --diverged` (above), an end that holds the relation one way
  acts on it with its count between its floor and its cap. The text without that step fails there:
  in some states at rest, at three steps, an end holds the relation one way and neither end's
  upkeep acts. In the first such state that the check records, one end counts the other as a pusher
  and the other holds nothing (seacast-figures.md, §4.1).

**A candidate's interest holds the family** (decided 2026-11-09).

- **Why.** Before, `candidates` took any joined peer with duty, so a column's relations could form
  with peers that neither receive nor want the column, and they carried nothing. The toy has read it
  this way since its upkeep was built.

**The backoff after a PRUNE** (decided 2026-11-09).

- **Why.** Before, the backoff was the client's, and the libp2p stream binding has no client under
  it, so `candidates` asked again, at the next heartbeat, a peer that had just refused. Where most
  of a short node's candidates are at their cap for the relation, a draw at random keeps landing on
  them: with one-way relations capped near their targets the refused GRAFTs repeat at every
  heartbeat, and the relations can take many heartbeats to rest, or not rest within a run.

- **Checked.** Since the backoff touches only when a node grafts, every state `toy/graft_check.py`
  reaches with it is one it reaches without, and the check runs at a backoff of 0.

**A JOIN is owed too** (decided 2026-11-04).

- **Why.** Before, a JOIN that a full queue refused was lost, and with it the link for the type,
  until the connection closed: the peer never had the node's JOIN, so it never counted the node as
  a link. Such a JOIN is one that opens the type, or answers the peer's, on a connection already
  busy with another type.

- **Checked** with the GRAFT (`toy/graft_check.py`, above): at rest, once either end has sent its
  JOIN, both ends hold each other's, and no GRAFT or PRUNE ever reaches a node that has no link for
  it. The check fails on the text before (`toy/controls/join-lost.md`), where a JOIN a full queue
  refused was lost (in some states at rest, at two upkeep steps, a JOIN was sent and the link did
  not form; seacast-figures.md, §4.1), and where `send_join` records its JOIN but does not owe
  it (a GRAFT then reaches a node that has no link for it).

**A peer that joins a push relation is announced what the node holds** (2026-10-26, from
`seacast-lite.md` §5.4's `on_mesh_join`).

- **Why.** Offers come from `forward`, at a chunk's arrival, to the relation for its colour (§4.4).
  Nothing else offers the chunk to a peer that joins the relation after the chunk was forwarded.
  Nothing else offers a peer whose connection closed what the old connection lost, either.
  Heartbeat gossip offers the last three heartbeats' chunks only to peers outside the relations,
  and only for a type whose `ANNOUNCE_EXTRA` is `SAMPLE` (§4.8). A holding is not an offer (§4.3).
  Derived interest lets a custodian be asked without an offer (§4.5), but only samplers, routed
  requests, the repair sample and a custodian's alarm ask that way (§4.6, §4.10).

- **The toy's recorded cells** keep their relations static and do not run this; under
  `--upkeep on` it runs.

**`keep_coverage` reads custody, never a sample.** The links it opens say nothing about the sample
(§1.3). With a node of high custody counted for at most `COVER_HIGH` families, the floor rests on
many peers of ordinary custody rather than on one that claims everything: custody counts are
self-declared, and a node that claims every column would otherwise attract every sampler's floor,
its samples and its load. A sampling-only link is not pruned for serving nothing, since its use is
the samples it may serve.

**The floor's links** (decided 2026-11-09).

- **Why.** Nothing kept that floor at runtime before. `maintain_relations` grafts only among the
  links the node has, and only `keep_coverage` opened links, for a sampler's floor (§1.3). Yet the
  draft assumes it: the rendezvous is per family (§1.1), and §8's route leans on custodians keeping
  a floor per column.

- **Measured** in the toy, in its custody setting at 500 nodes with links replaced during the run
  (seacast-figures.md, §4.1): without the rule, at every seed, some of the nodes at the ends of
  a closed link had not, by the run's end, come back to the number of their (family, colour) pairs
  below `F_LO` that they had before the close; with the rule, far fewer fell short. Against the
  same cells without churn, it also removed most of churn's excess in the share of (node, family,
  colour) below `F_LO`, but not all of it. It cost more JOINs and GRAFTs per node and message gap,
  the more so the more links were replaced. Every node completed, and the warm block's 99th
  percentile moved within the toy's noise. These runs predate 2026-11-16. Since then, the toy's
  close also drops the closed peer's offers, tries, promises and ties, and keeps its park (§3's
  lifetimes, `seacast-lite.md` §8.1). They were not run again.

### 4.2 A chunk arrives

#### Rationale

**A copy that waits ties its sender** (2026-10-26, from `seacast-lite.md` v0.8). With it, v0.5's offer
of a refused copy is gone.

**A block's cell header before the block** (decided 2026-11-01). The installation would otherwise
resume the cells with the payload's check and drop their ties as forgeries.

**An ask goes with its announcer's offers** (from `seacast-lite.md` v0.8, 2026-10-28). If the node
kept the ask, the ask would leave the peer outstanding. `on_offer` would pass over the peer's next
offer. While this peer is unparked, a parked announcer's offer would draw no last resort. Once the
peer's promise fell due, nothing would ask either peer again, and the pull would stall.

**In the toy** cells carry their header, so their gate is open from the first cell and neither
`defer` nor `on_header_validated` runs there; `toy/seacast_carried_known.py` calls the latter by hand.

### 4.3 A holding or an offer arrives

#### Rationale

**The reference values hold no ask back in the toy.** At 4096 frames and 5000 ids, the toy's 60-node
cells hold back no ask, under this draft's tier 4 setting, variant C (`c`) and custody, with and
without samplers, nor under the rows setting, with and without half the columns withheld. The
busiest peer stayed well below both values in a heartbeat, in every setting
(seacast-figures.md, §4.3).

### 4.5 An ask arrives, and serving

- *Why no penalty.* The asker's view can lag the node's honestly: a header the asker holds first, a
  JOIN or an offer in flight. In the toy's custody runs with samplers, the asks a strict test would
  call outside were all such races: a sampler's standing WANT reaching a custodian before the
  custodian had validated the header, for a column it custodies (seacast-figures.md, §4.5). The
  rule therefore ignores without penalty, and tests what came before the gate once the gate opens.
  Without the rule, such an ask kept a standing request, or a bit of a `DECLARED` peer's interest,
  that the node could never answer until `GROUP_TTL`: a table any peer could grow.

Without them, a WANT for an index that does not exist kept a standing request that nothing could
answer, and WANTs for groups that never come kept entries that `expired` never reaches, since such a
group has no lifetime.

### 4.6 Completion, the claims, decoding and repair

  The sample allows a lost cell at its last step, since a custodian
  may not yet hold a repaired cell when asked. So a claimant that repairs every withheld column of
  its row but one passes every member's sample with certainty, and the custodians of that column
  stay short. Only they see which cell is missing.

  - The rule keeps honest copies on the source's block only as long as no node relabels a chunk
    (`seacast-lite.md` §4.6, "Open: relabelled copies", with its options; 2026-10-28). The payload is
    exposed as there. A cell relabelled under the other block is a cell of that block's groups,
    which its id carries. It cannot stand in for the source's copy or tie its sender for this
    block's groups: for cells this is that list's option of a group per block root. The cells'
    case is by inspection: neither the toy nor a model runs relabelled copies.

#### Rationale

**Deferral on a claim, verified by one ask.**

- *The probe's promise* is the window, not `PROMISE`: a reconstructor that has just decoded is
  pushing a row's worth of rebuilt cells through its window. In the toy its answer to a probe left
  later than `PROMISE` after the probe was decided, so with the shorter promise honest claimants
  were parked and penalised (seacast-figures.md, §4.6, "The deferral").

- *A claim outside the subnet's view.* Executing the toy's liar fault (seacast-figures.md,
  §4.6, "The probe") showed that a false claim counted there made the row look whole to every
  member of its subnet and suppressed the third phase, the suppression the RowDAS design warned of.

- *The probe exempt.* Without the exemptions, the one-ask-per-index window dropped the probe in the
  toy and penalised honest reconstructors.

- *Defer and re-arm.* The RowDAS design asked for "defer and re-arm" because a bitmap takes a round
  trip and cancelling on a claim outright lets any peer suppress reconstruction; the probe makes the
  re-arm a verdict on the claimant rather than a timer, at the cost of one cell.

**The probe is marked, and its cell drawn at random** (decided 2026-11-15; the probe's wait from its
write, a claimant still decoding and a claimant that leaves since 2026-11-16; `probe_of_claim` since
2026-11-17).

- *Why the mark.* The probed cell often reaches the asker from another peer during the wait, on its
  other axis, and the asker's holding then names it; without the mark, the claimant's queue
  cancelled its own answer as a duplicate, and an honest claimant failed its probe.

- *Why the asker's queue keeps it.* Otherwise the asker dropped its own probe, and the claimant
  could pass only on a push.

- *Why at random.* The lowest index the member lacks, which an earlier draft took, can be read from
  the member's announced holdings, so a claimant could keep exactly that cell and withhold the
  rest; when the index is drawn at random, the claimant cannot tell which cell will be asked.

- *Why from its write.* Starting the wait at the decision instead penalised a claimant for a WANT
  it never received.

- *Why the claimant keeps the probe.* Dropped, the probe would go unanswered, and an honest claimant
  whose decode outlasts the probe's round trip would be penalised. An honest member sends one probe
  per group; before, a faulty asker's second marked ask, of a stored cell, took the exemption, and
  the kept one went unanswered.

- *Measured* results come from five cells (seacast-figures.md,
  "A cell, the median and the tail") of the toy's rows, honest and under liars or hoarders, run on
  this section's rules as they stood on 2026-11-18 (seacast-figures.md, §4.6, "The probe"). No
  verdict on an honest or hoarding claimant failed. Every probe got a verdict and was written: none
  was still unwritten when its window ran out, and no probe reached a claimant still decoding (the
  toy's queues refuse nothing, and these cells close no connection). Liars almost never passed their
  probe in two of the three liar cells, and passed more often in the one with supernodes, each time
  on a copy the liar pushed (a toy liar answers no ask). The mark cost a few duplicate cells: exempt
  answers written over a holding the asker had sent. At the median a probe was written when it was
  decided, and its longest wait was far shorter than `DEFER_WINDOW`. One run of the liars' 16-subnet
  cell delivers no block to almost all of its nodes, as it did before, and decides no probe; the
  figures include it. Against the runs with the rules of 2026-11-16 (below), every run changed its
  events, and the copies of a few runs moved; those moves of the copies were not traced.

- *Measured with the rules of 2026-11-16*, before four later fixes (a probe settled while queued, a
  kept probe answered once, the duty's own time, a settled probe's promise) and the later changes to
  the draft, the same cells showed this: no verdict on an honest or hoarding claimant failed; liars
  almost never passed in two of the liar cells, and passed more often in the one with supernodes;
  the mark cost a few duplicate cells; one probe, in the supernodes' cell, passed before it was
  written, on the claimant's own copy; the run that delivers no block decided a few probes; and the
  longest wait from decision to write was a small part of the window (seacast-figures.md, §4.6,
  "The probe").

- *Measured before 2026-11-16*, and before v0.10's order of the announcers beyond the list
  (`seacast-lite.md` §6.1), these runs used the same five cells. That order moves a run of the
  supernodes' cell and, bracketed but not run at that change, another. Judged by the claimant's own
  copy without the mark and the kept WANT, a few verdicts on honest claimants failed, all in the
  hoarders' cell; with them, none did. When any peer's copy passed the claimant, liars passed far
  more often in every liar cell, by a count that is a lower bound. Against the earlier rule's runs
  (the lowest index, any peer's copy passing), the copies stayed close in most runs and were lighter
  in one run of the hoarders' cell and in two of the supernodes' cell. Almost all of the difference
  was data, and it was not traced further (seacast-figures.md, §4.6, "The probe").

- *The random index's cost, and what is not measured.* In the runs measured before 2026-11-16,
  liars passed a little more often with the random index than with the lowest. In the traced runs,
  which hold all such passes, the liar had by then already sent the member the lowest lacked cell
  in most of them and held it unsent in the rest; in none had it neither (seacast-figures.md,
  §4.6, "The probe"). The excess fits the draw choosing a cell already on its way, but that is not
  proven. The toy's liars do not aim at the cell they expect to be asked, so these runs measure the
  draw's side effects, not its purpose; nor does any fault send marked asks, which the cap bounds to
  one exempt answer per asker and group.

- The figures file gives the rules and the transport that each figure in this section ran with
  (seacast-figures.md, §4.6).

**The verdict, by what the node can see** (decided 2026-10-10). Draft 1 ended a row member's duty on
a verified claim; the rule above keeps that, subject to the member check.

- *The wording.* An earlier wording told the two apart by a non-empty suppression scope (some peer
  pushes the row to the node). A member that no peer pushed its row to then counted as keeping the
  row on no link and rebuilt after a verified claim. In the toy that added member decodes with 32
  subnets, where a subnet has few members, and none with 16. With this wording the row cells with
  supernodes (honest, and half the columns withheld with 16 and with 32 subnets) and the withheld
  custody cell with a fifth of the nodes hoarding run as under draft 1, event for event on every
  seed, and so do almost all seed-cells of the row cells with supernodes and a fifth or half
  hoarding (seacast-figures.md, §4.6, "The verdict").

- *Draft 1, and a first version.* Draft 1 ended the duty of both, a row member and a node that
  keeps the row on no link, on the probed cell; when the toy's rebuilders stopped pushing to
  supernodes (an exploration), supernodes deferred on a claim that came in an acknowledgement,
  received the probed cell, and ended one cell short of a column. A first version of this rule
  counted a verified claim only from a peer in the node's view, and row members decoded several
  times as many rows for no change in time or bytes (seacast-figures.md, §4.6, "The verdict"):
  their claimants were mostly supernodes rebuilding the row in the second phase, which have no
  relation on it, so their claims reach a member in the acknowledgement of a column chunk (§4.2,
  `fill`).

- *What it leaves to the member check.* A claimant that rebuilds a row, answers the probe and pushes
  nothing (the toy's `--fault hoard`) passes the probe and ends the members' duties. Where an honest
  supernode keeps the row, its second phase repairs the row, under this rule and under draft 1's
  alike: in the runs traced, no supernode ended its duty on a verified claim, presumably because a
  claim on a row reaches a supernode outside the subnet only in the acknowledgement of a cell the
  supernode sent, which a hoarder sends while still short. Where none does, the row is lost: without
  supernodes, a fifth of the nodes hoarding left custodians short in every run of the toy's withheld
  row cell, each time a subnet whose honest members had deferred to a hoarding reconstructor
  (seacast-figures.md, §4.6, "The verdict"); the member check (above) closed this in those runs
  wherever the subnet had an honest member, against a claimant that repairs nothing.

**The member check** (decided 2026-10-09). It was measured in the toy's withheld row cell
(seacast-figures.md, §4.6, "The member check"):

- *What it addresses: a claimant that rebuilds, passes the probe and repairs nothing* (the toy's
  `--fault hoard`). Without supernodes, with a fifth or half of the nodes hoarding, custodians were
  left short on every seed without the check, and with it they were left short on a few seeds at a
  fifth and on most at half. Every seed on which each subnet has an honest member completes.

- *And a false claim the cell's arrival let through.* For the duty, the claim holds when the probed
  cell arrives, from anyone; a claimant that never answers ends the duty when another peer brings
  the cell in time, though it is itself penalised (above). Among the toy's liars (`--fault claim`,
  which claim their row and answer no ask) without supernodes, this happened a few times per run on
  some seeds, and each time the member check sent the member to rebuild instead of trusting the liar
  (traced on some of those seeds; measured when that cell also passed the claimant). In the traces,
  the few (node, row) pairs left short, with and without the check, are the liars' own rows, which
  the toy's liars never rebuild: the check moved their count only slightly (seacast-figures.md,
  §4.6, "The member check").

- *What it does not address.* It does not address a subnet whose members all misbehave: nobody
  honest is there to check. A member whose custody columns are all among the published ones holds
  its cells whatever the claimant does (a small share of members where half the columns are
  withheld), so the check passes for it, though the other members of its subnet still check. A
  claimant that pushes each member exactly its custody cells of the row and withholds the rest
  passes the check (the toy's `--fault hoardm`: without supernodes, a fifth of the nodes doing so
  left custodians short on every seed); sampling the repair samples for it. Where an honest
  supernode keeps the row, its second phase already repairs what a hoarder withholds, and the check
  never fired there (seacast-figures.md, §4.6, "The member check").

- *What it costs.* Where nobody misbehaves, it costs nothing: in each cell run without a fault
  (rows honest with and without supernodes, withheld with 16 subnets with and without, withheld
  with 32 with supernodes) it never fired and every event is the same. A rescued block completes
  later than a block without hoarders, since the member rebuilds at the third phase after a
  deferral; its bytes are not higher, since hoarders push nothing. In the traced runs with hoarders
  or liars every firing was on a misbehaving claimant's claim: a needless rebuild, an honest
  claimant's repair still on its way when the window ends, was not seen at 60 nodes. It is the case
  to watch at larger scale, where repair travels further (seacast-figures.md, §4.6,
  "The member check").

**Sampling the repair.** The sample is extended, never redrawn, since the larger sample could have
been drawn at once ("toss a coin until you like the result" is the alternative the post rules
out); allowing losses is LossyDAS's answer to a custodian that has not yet received a repaired cell
when asked. It was measured in the toy's withheld row cell (seacast-figures.md, §4.6,
"Sampling the repair"):

- *Against a claimant that repairs only the members' cells* (a fifth of the nodes, without
  supernodes): the member check alone left custodians short on every seed. The lenient form,
  `(3, 1), (6, 2)`, left fewer short, and the strict forms, `(4, 0), (8, 1)` and `(6, 0), (12, 1)`,
  left short only the seeds on which a subnet has no honest member. In a traced run every failed
  sample was on a hoarder's claim. The lenient form passed partial repairs: the hoarding members'
  own pushes had filled some columns, and most of the sampled cells came. A rescued block completes
  later than a block without the fault, with the rebuild waiting out the deferral and two sample
  steps, and later than a block the member check alone rescues from a claimant that repairs nothing
  (seacast-figures.md, §4.6, "Sampling the repair").

- *Where nobody misbehaves* no sample failed in any form, with or without supernodes, and the times
  and bytes are within the seeds' spread; the cost is the sampled cells, a few per node and block
  (seacast-figures.md, §4.6, "Sampling the repair"). With supernodes every cell completed in
  every form.

- *Where custodians do not answer.* The toy's liars answer no ask, so a sample cell asked of one is
  lost: with a fifth of the nodes lying, `(4, 0), (8, 1)` failed on honest claimants in many
  verdicts, and in almost all of them in a run with supernodes, where a liar is a supernode and so a
  custodian of every column. The strict forms had members rebuild more rows per run, without
  changing completion (seacast-figures.md, §4.6, "Sampling the repair").

- *Re-asking a lost cell* (`REPAIR_REASK`) was measured over the same seeds. Among liars the strict
  forms' failed samples fell to none at the median, though not in every run, and members rebuilt
  about as many rows as with the member check alone. Where no cell was lost (no fault, and a
  claimant that repairs nothing) the runs are the same event for event. Against a claimant that
  repairs only the members' cells, `(4, 0), (8, 1)` and `(6, 0), (12, 1)` still leave short only the
  seeds without an honest member, and a rescued block completes later, by about the one more wait;
  `(3, 1), (6, 2)` stays lenient (seacast-figures.md, §4.6, "Sampling the repair").

- *At 500 nodes* (`(4, 0), (8, 1)` with re-ask against the member check alone): where nobody
  misbehaves, with and without supernodes, the member check never fired, no sample failed, and times
  and bytes are similar. The sample asked a few cells per node and block without supernodes, and far
  fewer with them, since a supernode's second phase makes most rows whole in the members' view
  first. A fifth of the nodes repairing only the members' cells left nobody short at this size even
  with the member check alone. With the sample, two seeds are similar, and on the third every failed
  sample was on one row the hoarder had not repaired. Its members rebuilt it after the deferral, two
  sample steps and the re-ask's wait, and the block's last custody cells came seconds later than in
  the run with the member check alone, where an honest node had rebuilt that row earlier (the runs
  diverge from the first block, and which node it was is not traced). The rescue path's length,
  `DEFER_WINDOW` plus two `SAMPLE_WAIT` and the re-ask's, is the cost to cut; a shorter wait was not
  measured (seacast-figures.md, §4.6, "Sampling the repair").

**Rebuilt cells marked seen** (kept as an option, 2026-11-01).

- *It needs the sample.* The forwarded copies also repair by accident: two hoarding reconstructors
  that forward each other's rebuilt cells fill columns that neither repairs on purpose. With the
  cells marked seen, such hoarders leave more columns unrepaired: in one network of the toy's
  500-node rows, a network model gives several times as many, and the runs matched the model
  (seacast-figures.md, §4.6, "Rebuilt cells marked seen"). The member check, which looks only
  at the member's own columns, misses them, and the sample catches them. With the member check
  alone, the option left more custodians short in the runs that measured it, so it is never on
  without the sample.

- *Measured at ten seeds* in the toy's 500-node rows, without supernodes, against a fifth of the
  nodes repairing only the members' cells: the member check alone left blocks short, the sample
  left fewer short, and the sample with rebuilt cells marked seen left none short. In honest cells
  the two together cost slightly more copies and control, against neither, with no direction in
  time (seacast-figures.md, §4.6, "Rebuilt cells marked seen").

**A custodian's alarm** (kept on 2026-11-01 for networks without an honest supernode).

- *Its wait, in the toy.* The measurements set the wait above the latest custodian's completion in
  the toy's 500-node rows without a fault (seacast-figures.md, §4.6, "A custodian's alarm", with
  the settings and the rules each run had).

- *Measured again on the rules as they stood* (2026-11-18), these figures come from the 500-node
  cells of the one-column hoarder (seacast-figures.md, §4.6, "A custodian's alarm"). Without
  the alarm some blocks were short: the same blocks as before but one, which now completes. With it
  none was, for as many alarms and rebuilds as before. In honest cells and under false claims
  (rebuilt cells not marked seen) no alarm fired. The figures of the ten-seed runs below were not
  measured again.

- *Measured at ten seeds*, before the member's changes of 2026-11-17, these runs had the sample and
  rebuilt cells marked seen. A fifth of the nodes repaired all but one withheld column per subnet,
  with no supernodes. Without the alarm some blocks were short; with it, none was, and every alarm
  and rebuild came at the short seeds. With supernodes none was short without it, since a
  supernode's second phase rebuilds the row: the alarm is for networks without one. In honest
  cells, with the builder at 1 Gbps or at home, no alarm fired, and the latest custodian completed
  before the alarm's wait. Under false claims by a fifth of the nodes, a few alarms fired and no
  rebuild followed (seacast-figures.md, §4.6, "A custodian's alarm").

- *Not measured:* the wait on thinner links, where the honest tail is longer, is not measured, and
  neither is the alarm since the probed cell is drawn at random. These runs probed the lowest index
  a member lacked, which was never the hidden column; drawn at random, the probe can ask for it, and
  a claimant that serves it to nobody then fails the probe itself.

**Repair across groups** (`note_push` under every group the chunk fills since 2026-11-17).

**A rebuilt chunk completes the groups it fills.** Draft 1 filled the column without the check, so
the member never completed it: it neither stopped pulling it nor told its peers, and the toy counted
it short (in a run of the repair floor's measurement below, before the fix; seacast-figures.md,
§4.6, "The repair floor").

**Every member keeps a link to each column.** In the toy's withheld row cell, without the floor
several runs left custodians short, and each was a missing link. In all but one of them, a column
with two custodians missed a cell because neither was linked to the only member that rebuilt the
row; the deferral on a claim, which cancels a second decode once the first is verified, makes a
single rebuilder common. In the other, a subnet had two members, linked only to each other among
members, and each gathered its rows from the columns' custodians one cell short: neither was linked
to the only custodian of one published column, so neither row was ever rebuilt. With
`REPAIR_FLOOR = 1` every run completed, and the links it added left completion times and bytes
within the seeds' spread (§6.2; seacast-figures.md, §4.6, "The repair floor").

**A supernode keeps every row.** In the toy, a few supernodes on datacenter links complete every
custodian on every seed of the custody cell whose proposer withholds half the columns, which nothing
else recovers. They complete the withheld row cell with 32 subnets, which its subnets without
members left short, and they complete the cell with 16 subnets much sooner. The cost is bytes, most
of it duplicate pushes of the fast class: with a budget of `R` for cells the copies are fewer and
the tails are shorter (§6.2; §6.3, `R_NODE`, for later study; seacast-figures.md, §4.6,
"Supernodes").

**A row held on the columns is on its way.** Without the wait, on home links, supernodes in the
toy's honest row cell rebuilt many rows that nobody had withheld, and the cell's tail grew. With the
wait, no supernode rebuilt a row in any honest custody or row run. In the withheld cells the
supernodes still rebuild most rows more than once; a jitter longer than a rebuilt row's trip to the
other supernodes would cancel more of them; such a longer jitter was not measured. For a member it
changed no event of the row cells without supernodes that were checked (seacast-figures.md,
§4.6, "Supernodes").

**A rebuilder pushes as a source.** Without supernodes, in the withheld 16-subnet row cell, where
members on home links rebuild, it is better on every count: fewer repair pushes, fewer copies, and a
shorter tail, at the median over the seeds and at the worst seed. With supernodes on datacenter
links, whose budget is the fast class's six, it saves copies and costs time at the tail, and in the
custody cell both the saving and the cost are small. With the fast class's budget off for cells
(§6.3, `R_NODE`) it saves more copies in the 16-subnet cell, for a later median and tail
(seacast-figures.md, §4.6, "A rebuilder pushes as a source").

**Whom rebuilt cells go to.** A supernode keeps every row, so a rebuilder's push into a column
reaches it too, and where several nodes rebuild a row their pushes cross in flight: at 500 nodes
most of the rebuilt cells pushed in the withheld custody cell arrived as duplicates, the whole of
that cell's extra cost over the honest one. The duplicates are bounded by what a node's own peers
push it, so no estimate of the network's size is needed to bound them. In the toy with supernodes,
offering the cells to the nodes that keep every row instead of pushing them saves copies at no cost
in time; offering every rebuilt cell, as a row's are, saves more and costs time at the median;
leaving the keepers out saves as much as offering to them, but lengthens the custody cell's tail,
since a supernode left out has only its own rebuild, after a deferral (seacast-figures.md, §4.6,
"Whom rebuilt cells go to").

### 4.7 The source

#### Rationale

**v0.7's single offer** (since 2026-11-04). Among the toy's recorded cells then, only the thin lossy
one (`loss-thin`), whose queues refuse some chunks at admission, met the second offer. There the
single offer sends fewer offers, and the warm medians (seacast-figures.md,
"A cell, the median and the tail"), of completion and of copies, stay as they were
(seacast-figures.md, §4.7).

**A refused push to a fallback link is owed** (decided 2026-11-14). Without it, a fallback target
whose push was refused would be neither pushed the chunk nor offered it at the acknowledgement,
whose offers skip the planned targets (`origin_acked`). When every copy was refused, no copy is in
the window either, so the acknowledgement itself waits for a holding that names the chunk, such as a
decode claim, or for a later copy, an answer to an ask, to time out. Two alternatives were not
taken: an offer to a refused fallback target at the chunk's acknowledgement, which then comes that
late; and leaving the gap.

**When the source offers** (v0.9 §5.1, taken for every object type on 2026-11-11; the source's
choice since 2026-11-18).

**Offering at the acknowledgement, by default.** Offered at publish, the offers race the pushes: a
transport that takes the whole batch at once lets every offer leave at once, the relation asks for
chunks whose pushes are still queued, and the source answers on top of its pushes. The
acknowledgement is the one event the source sees whatever the transport holds (§4.11).

**Offering at publish, the source's choice** (decided 2026-11-18). Two things decide it:

- *Its uplink.* The offers draw asks on top of its pushes. In the toy's custody cell, a 1 Gbps
  proposer that offers at publish completes its block sooner at the median than one that offers at
  the acknowledgement, on the toy's 60-node graph and on the research harness's 100-node one, with
  writes completing at once and with one write at a time. It also answers several times as many
  asks. A 50 Mbps proposer that offers at publish completes its block later, at 60 nodes and at 500
  (below; seacast-figures.md, §4.7).

- *Its privacy.* Every chunk offered at once, by the one node that holds them all, names the source
  to those peers, and the paced holding [P4] then hides nothing from them. Toward the peers outside
  its pool (the relation for the chunk's colour, or with none the fallback links, `source_pool`) the
  settings are alike: for a type whose `ANNOUNCE_EXTRA` is `SAMPLE`, its heartbeat gossip draws on
  every chunk at either setting, since `publish` puts each in the gossip history (§4.8), and for one
  at `ALL_JOINED` or `NONE` there is none. A source that wants P4's cover toward its pool offers at
  the acknowledgement.

Copies do not decide it: offering at publish adds a little to the copies of the block received per
node, data and control, on the toy's 60-node graph, and saves a little on the research harness's
100-node one (seacast-figures.md, §4.7). A client may key the choice on its uplink, as striping
is (`STRIPE_UPLINK`); this document does not, since a fast source may still want P4.

**A pull-only type's source** (decided 2026-11-18).

**A chunk that is never acknowledged, in the toy.** The recorded cells do not churn, and a churn
cell bounds it only where every copy of one chunk is lost with its connection; no toy knob closes a
source's links in the middle of a message.

**The acknowledgement against the document before, in the toy.** These are the results at 60
nodes (seacast-figures.md, §4.7):

- **The payload** completes as soon or a little sooner, and its source saves bytes where the
  transport takes the batch at once (below, "The source's offers, card 3 at the source").

- **A 50 Mbps proposer's custody block** completes sooner at the median, on most seeds.

- **A column's source** uploads less and is asked far less. With §4.11's rule it saves about as
  much, against that rule alone. The rows' proposer uploads fewer copies of its block.

- **The cost.** The rows complete later, on every seed, and later than with no source offers at
  all; the rows with liars complete later too. A 1 Gbps proposer's custody block completes later.

- **Why the rows pay at 60 nodes.** At one seed the proposer's relation peers pulled from it, while
  it pushed, the cells it did not push them. Offered each cell only at its acknowledgement, they
  completed much later. The other nodes moved little.

These are the results at 500 nodes (seacast-figures.md, §4.7):

- **Against the document before,** at one seed: the payload (tier 4 in the all-home network), the
  rows and a 50 Mbps proposer's custody block complete sooner at the median, and the custody block
  of a 1 Gbps proposer completes a little later (a fifth of the nodes sampling).

- **Against offers per type** (below):

  - the rows complete a little later at the median, and with §4.11's rule later on every seed;

  - a 1 Gbps proposer's block completes a little later;

  - the block of a 50 Mbps proposer completes sooner, at the median and at the tail;

  - a column's source uploads less, and is asked far less.

- **The relation peers at 500 nodes.** At one seed, a far smaller share of the nodes pulls many
  cells from the rows' proposer with offers per type than at 60 nodes in the document before. With
  the offers at the acknowledgement they complete a little later at the median. The two of them
  that completed first complete much later. The nodes that pull nothing from the proposer move
  little.

- **So the rows' cost is a 60-node finding.**

**The alternative: offers per type** (decided 2026-11-10, replaced 2026-11-11). A field per object
type had the payload's source offer at the acknowledgement and a column's at publish.

- **What it kept:** it kept the rows' early completion at 60 nodes, against offers at the
  acknowledgement for every type, with and without §4.11's rule; and a 1 Gbps proposer's earlier
  block, at 60 nodes and at 500 (seacast-figures.md, §4.7).

- **What it gave up:** at 500 nodes it gave up the saving in upload of a column's source and a
  50 Mbps proposer's earlier block, for the rows' small gain there, with and without §4.11's rule
  (seacast-figures.md, §4.7).

One rule for every type, as v0.9 has it, was taken instead; since 2026-11-18 any source may offer at
publish (`SOURCE_OFFERS`, above).

**A source's links in a family it does not custody** (decided 2026-11-13; found 2026-11-09, writing
`candidates`' interest rule, §4.1).

- *In the toy.* Its setup gives the proposer a relation with every custodian it links to, which are
  the fallback's peers. Its custody and row settings use a `SOURCE_FLOOR` of 2, at setup
  (`--source-floor`). The hunt is not measured. At 500 nodes, with half the columns withheld, every
  custodian completed through the rows (seacast-figures.md, §4.7).

- *Not taken:* the alternative of holding the publish until the links are there would delay every
  family for one that the code can recover. No layer reaches a column that no node but the source
  custodies, and the toy's 60-node cells have such columns (seacast-figures.md, §4.7); routed
  sample requests do (§4.10).

**The source's holding is paced** [P4].

- **Why not at the write.** Until v0.9 a chunk joined at its first write, as it still does at
  `PUBLISH`. Where the transport takes a batch at once, that named chunks which had not left (v0.9
  §5.1).

- **The signs that remain.** These remain here too, from v0.4's list and `seacast-lite.md` §5.1's:

  - the source offers every chunk, at `ACK` about a round trip after its first copy;

  - its holding tends to grow faster than anyone's;

  - it offers the chunks of the group that have the relation's colour at once to a peer that joins
    its relation (`join_push`, §4.1);

  - it is usually everyone's first sender;

  - and, at either setting, for a type whose `ANNOUNCE_EXTRA` is `SAMPLE`, its heartbeat gossip
    draws on every chunk of the group for the peers it samples outside its relations at each of its
    next three heartbeats, less what `announce` leaves out, since `publish` puts every chunk in the
    gossip history (§4.8), at `ACK` without waiting for any chunk's acknowledgement. Keeping a
    source's chunks out of the gossip history until they are acknowledged is left, as in
    `seacast-lite.md` §5.4, to the work on the source's privacy.

- **The cost of the later holding.** It names a chunk about a round trip later than at the write.
  A relation peer that got the chunk from a forwarder may push it back to the source until the
  holding arrives; cancel drops what is still queued. In the toy's all-home payload cells at 60
  nodes, with writes that complete at once, a few of a payload's chunks come back a message at the
  median of the seeds, and many more at one seed. With §4.11's rule fewer come back at the median.
  The 1 Gbps builder's cell has more come back either way, and no column's cells come back
  (seacast-figures.md, §4.7).

What P4 costs here depends on how many groups a source publishes. For the payload, one group, it
costs nothing (§6.1). A proposer of 128 column groups sends a holding per cell to each peer in that
column's scope, and on a 50 Mbps uplink those bytes take time of their own. In the toy at 60 nodes,
with a 50 Mbps proposer, the custody block completes later, at the median and at the tail, and so
do the row cells. With a 1 Gbps proposer the cost is small. Its peers, no longer told that it holds
every cell, also offer it cells. Under the liar fault P4 leaves more row members short (not
traced). With v0.5 merged (2026-10-21) few pairs stay short, and on most seeds none. It is v0.5's
last resort (its §6.1): when every announcer of a cell is parked, each is asked once more, at waits
that double. In a toy check at three seeds, without it the members stay short as before v0.5, while
asking announcers beyond the first sixteen changes nothing; the doubling waits are why those rows
complete late. The other cells move little (seacast-figures.md, §4.7).

The costs above were measured with the holding at the write. At the acknowledgement P4 sends as many
holdings, a round trip later. Moved there alone, with a column's offers still at publish, the
holding moves the toy's column cells little at the median: the rows, the rows with liars, and the
custody block with a 50 Mbps and with a 1 Gbps proposer (seacast-figures.md, §4.7).

The offers at the acknowledgement then move them as above.

**Merging the source's holdings** (measured with the holding at the write) takes back little of P4's
cost. With writes that complete at once, only holdings made in the same instant are in the queue
together: a small share of the slow proposer's holdings merge, and the custody block and the rows
gain a little, at the median and at the tail. With a transport that takes one write per connection
at a time (the toy's `--send-buffer 1`), a holding also waits while another entry to the same peer
goes out: more holdings merge, and the custody block gains a larger share of P4's cost, which is
smaller there; the rows gain as little at the median. Copies move by 0.01 at most, and under the
liar fault merging leaves slightly fewer pairs short than P4 alone (both before v0.5).
Most holdings would leave alone anyway: at one seed, most find no earlier holding of their group
still waiting, in the queue or in the transport. Taking back more needs fewer holdings, which v0.4
does not provide for: holding them back for a set time, or sending them to fewer of the scope's
peers; both are for later study (seacast-figures.md, §4.7).

**The source's offers, card 3 at the source,** cost a home builder bytes.

- **At publish**, in the toy's tier 4 cells (seacast-figures.md, §4.7):

  - they drew asks that the builder answered after its first copies, and most of those answers
    arrived as duplicates;

  - without the offers a 50 Mbps builder uploads fewer copies of the message, and its cells' medians
    move little;

  - a 1 Gbps builder uploads far fewer copies, but completes a little later;

  - a 1 Gbps proposer of columns completes later, since its offers let peers pull from it while its
    uplink has room.

- **At the acknowledgement**, with writes that complete at once (seacast-figures.md, §4.7):

  - the payload's offers draw fewer asks;

  - a 50 Mbps builder uploads fewer copies of the message, and so does a 1 Gbps builder;

  - the medians move little, and none is later.

  So most of those bytes are saved where the transport takes the batch at once, and none need saving
  where it keeps §4.11's rule: there the offers wait behind the pushes either way, and they draw
  about as many asks (seacast-figures.md, §4.7).

- **A column's offers wait for the acknowledgement too** (above). A fast proposer pays for it: its
  block completes later at 60 nodes, and a little later at 500, than with its offers at publish
  (seacast-figures.md, §4.7).

  - A fast proposer can take it back by offering at publish (`SOURCE_OFFERS`, above). With the
    offers keyed on the configured uplink, as striping is, its block completed a little sooner at
    60 nodes than in the document before; at 500 nodes the cost is the small one above
    (seacast-figures.md, §4.7). The order of a source's queue is §4.12's.

### 4.9 The window's projection, per object type

#### Rationale

**Why only with a code.** A column has no code across its cells (K = N), so the premise fails: a
dropped cell is a cell the peer still needs, and in a thin family nobody else may be pushing it.
Executing the custody setting (§6.2) found this: with `seacast-lite.md`'s `projected` a custodian ended
short of exactly the cells its pushers had projected away, and nobody offered them, since a planned
push is not announced.

### 4.10 A sampler pulls

#### Rationale

**From LiteDAS.** One sample per peer is LiteDAS's ("asking each from distinct nodes"), and so are
the two phases' timing ("an initial period to handle the happy path, and a second period to handle
potential issues") and the cap on the second phase's asks in flight ("use timeouts and the number of
outstanding queries to avoid traffic explosion").

**No promise for a sampler's WANT** (decided): v0.5 starts a promise when an ask is written (its
§7.2); a sampler's WANT, as the repair sample's, has only its own timers, while a claim's probe has
the promise of §4.6.

**Routed requests, from FullDAS:** they are its topic routing and its query forwarding as one
mechanism ("A node can take one of it's peers according to Topic Routing, and send to it a
forwardable query. We’ll get the sample in 2 hops").

**How far one step reaches, in the toy's graphs** (`toy/sampler_graph.py c`): a sampler's own links
serve nearly every (sampler, column) pair at 70 links and little more than half at 16, and a path
of two hops exists for every other pair. One step to the link whose computed custody is nearest the
column left few pairs unreached at 16 links where custodians keep their floor per column, and many
more without that floor; the second phase meets such a miss through another first hop, and the
routing rules meet it by construction (§6.3, `ROUTE_FLOOR`). Beyond one step: without the floor, the
Kademlia-style rule reached most pairs within two hops and the rest in three. A first hop drawn at
random, as here without the rules, was not measured (seacast-figures.md, §4.10).

**Not taken: narrowing the draw** to the columns the node's links serve was not taken. A sample
drawn among what a neighbourhood offers is a sample that neighbourhood steers, which breaks the
independence the guarantee rests on (FullDAS: "the more the block producer and its 'accomplices'
knows about the sample selection of a node, the easier it is to introduce correlation and thus fool
someone").

### 4.11 The window, in bytes

#### Rationale

**The window's unit (X3, decided 2026-11-13, §8).** `seacast-lite.md` §7.1 counts the window in slots
of `CHUNK_BYTES` (12 000 bytes, the payload's chunk),
`W = ceil(uplink_bytes_per_s · (RTT_REF + TARGET) / CHUNK_BYTES)`. A cell is 2 096 bytes, so the
same slot count carries a sixth of the bytes per round trip. In the toy, a proposer of 128 column
groups was held by its own window to a small share of its uplink, at 50 Mbps and at 1 Gbps, and a
reconstructor's answer to a probe left late behind its burst of rebuilt cells
(seacast-figures.md, §4.11). One window over every object type (X3) is therefore counted in
bytes here, and a chunk takes its own length of it; slots per object type would be the alternative,
with the same capacity question at every boundary between types.

**The entry before the room.** `seacast-lite.md` takes a slot first and chooses after, which also
makes a control-only entry at the head of the queue wait for a chunk's slot.

**What the unit changes, in the toy** (seacast-figures.md, §4.11). At 60 nodes, the custody
setting's block completes sooner, at the median and at the tail, with a 1 Gbps proposer. With a
50 Mbps proposer it completes at about the uplink's own bound, where the slot window took several
times as long, and a little sooner with §4.12's source rule. The sampling cell's samples arrive
sooner. Under half the columns withheld every custodian completes through the rows sooner, with
every claim verified and none re-armed, since a reconstructor's answers no longer queue behind its
rebuilt cells. In the honest row cell no member decodes at the third phase at all, where several
did under the slot window, because the column path is done before the phase and the subnet's view
is whole. At 500 nodes the custody block and the withheld block complete sooner too, at the median
and at the tail. Tier 4 moves little (§6.1).

**Below the writer, in the toy.** The toy runs the rule as one write per connection at a time
(`--send-buffer 1`). Read in bytes instead, as less than one payload chunk unsent, the rule moves
the column cells little at the median, at one seed (seacast-figures.md, §4.11).

- **Its effect,** with §4.7's rules, in the toy at 60 nodes (seacast-figures.md, §4.11):

  - the 50 Mbps payload cells complete sooner, on nearly every seed, with fewer copies;

  - the rows complete a little sooner at the median, on more than half the seeds, and the rows with
    liars complete sooner at the median, on more than half the seeds. With a column's offers at
    publish (§4.7's alternative) the rule brought them sooner by more;

  - a 50 Mbps proposer's custody block completes later, on most seeds, and later at the tail;

  - the 1 Gbps cells move little;

  - at 500 nodes, the payload completes sooner with fewer copies, at one seed, and the rows complete
    a little sooner, on every seed.

**The line skips a writer mid-write** (2026-11-20, from `seacast-lite.md` v0.10.7's §7.1).

- *The case.* The line admitted only its first writer, and every freed room woke only it. A writer
  whose write has not completed cannot take room, so a peer that stops reading while its writer
  heads the line held every free byte. On 2026-11-20 `toy/line_stall_known.py --doc seacast` showed it on
  the `push` cell's network: with the source's line head stalled, the other peers' chunks waited in
  an empty window, and none was sent to them from 600 ms after the stall to the end of the check
  (seacast-figures.md, §4.11). With the rule none was held up. The check counts the sends to the
  other peers from 600 ms after the stall on (past `WINDOW_TIMEOUT`), and accepts queues left empty.

- *The wake when a control write waits* (since `seacast-lite.md` v0.10.9's §7.1). A burst of urgent
  entries woke writers in line that each blocked on its write, and free room went to nobody.
  `seacast-lite.md`'s monitor (its W2) found this in `loss-thin`. So a writer in line whose control
  write does not complete at once wakes the first writer in line that can write, as it starts to
  wait (`write_waits`), as `seacast-lite.md`'s does. Here control has a third path, a control-only entry
  of the normal lane, which takes no room and reaches the lane's head when a writer's queued chunks
  are discarded (a dropped or expired group). The wake acts at the write, whatever the entry, so it
  covers that path with the other two. A client whose write call blocks may call `write_waits`
  before a control write from the line instead, once it has marked the write pending. The early call
  can queue an extra run even for a write that completes at once. Admission is unchanged: a writer
  takes room only while room is free, and never ahead of a writer in line that can write.
  `toy/write_wait_known.py --doc seacast` checks five cases on each of the three paths, with p the writer
  that writes control and q the other writer in line: q has no run queued when `next_to_send`
  returns p's control; q has one after p's write starts to wait, and only after the control reached
  the transport and `write_waits(p)` was called with the write pending; q has none when p is not in
  line or when no room is free, the window full or above its cap; and a write that completes at once
  calls no `write_waits`. In the first, the second and the fourth, p keeps its place at the head of
  the line. `seacast-lite.md` has no such third path: its control-only entry goes through
  `release_unused_slot`, which gives back the writer's slot and also takes the writer out of the
  line when it holds none, so there a control-only entry is never written from the line.
  `wake_front` is this document's own, since its room is counted in bytes (`W_BYTES`), where
  `seacast-lite.md`'s counts slots.

- *Replaced: the wake before the write* (v0.10.7's). It woke the next writer in line before every
  control write of a writer in line, whether or not the write then waited. A write that completes at
  once leaves its writer able to write, and waking another then would change the schedule of the
  node's writers where nothing else changes.

- *The recorded cells* (`golden-seacast.txt`, against v0.10.6's). Twelve move in their digest only:
  `push`, `hold`, `announce`, `none`, `withholders`, `silent`, `cap-wait`, `dcb20`, `rr-stripe`,
  `without-a`, `ihave-limits` and `push-deep`. Two move in their numbers too: `loss-thin` and
  `late-block` (seacast-figures.md, §4.11). `without-b` is the same. The figures in this
  document measured before 2026-11-20 ran without the rule. With the wake at the wait (v0.10.9),
  `rr-stripe` and `push-deep` move in their digest only, back to their values before v0.10.7. Every
  other cell kept its recorded digest, `loss-thin` and `late-block` among them: there the wake moved
  within the same writer event. The wake before the write could reorder writers' runs that fell at
  the same time, and their frames to different peers.

### 4.12 Which entry goes next

#### Rationale

**A source's own chunks first.** v0.3's order is rarest-first (card 9), and it reorders only the
chunks ahead of the first control-only entry. v0.3's source queued each group's offers after that
group's pushes (v0.3 §5.1). With one group, the offers follow every push, and rarest-first sees all
of them. A proposer, though, publishes all 128 column groups of a block at the same instant. It
queues the pushes and the offers of one group before those of the next. The first group's offers
then sit in every peer's queue ahead of the other groups' pushes, so rarest-first sees one group's
chunks at a time. The offers leave early and draw asks, and the answers and the second copies take
the proposer's window from its first copies. Taking the source's own chunks first, over the whole
queue, keeps them ahead. The rule was chosen with one window, counted in bytes over every group
(§4.11): the window part of X3. Its clearest gain in the toy was in custody with a 50 Mbps proposer.
The single-group cells checked ran exactly as under v0.3's order, and elsewhere the rule changed
nothing that the seeds could tell apart (seacast-figures.md, §4.12).

**Not taken: v0.3's order, and two other cures for the same cause.** v0.3's order is not taken for
the reason above. Dropping the source's offers, or queueing them after all of the block's pushes,
gains about as much with a 50 Mbps proposer. With a fast proposer, both delay completion at the
median, since its offers let custodians pull from it while its uplink has room
(seacast-figures.md, §4.12).

**Answers first, as an option.** An answer is a chunk its receiver asked for, so it is never a
guess, and the asker is timing it. For a pull on an offer, the asker may ask another holder after
the ask window (§4.13). If the promise is still open `PROMISE` after the ask's write, the asker
parks the asked peer for the group (§4.13). A sampler's WANT has its own timers (§4.10). A push has
no such clock. Under v0.3's order an asked chunk is rarely the rarest, since a peer of the
answering node holds it, so its answer waits behind fresh pushes. In the toy, the option moved
median completion little in most tier 4 cells, and shortened the asks' round trip at the 99th
percentile in most cells. With cards 8, 9, 12 and 15 off, answers waited behind long runs of
pushes, and the option cut their wait at the 99th percentile (seacast-figures.md, §4.12).

**Not taken: three other forms of answers first.** Each cost time in some cells of the toy
(seacast-figures.md, §4.12). The first sends the oldest answer first, ahead of a source's own
chunks too: it takes a slow proposer's uplink from its first copies. The second does that, and also
puts the answer's writer ahead of the window's line of writers (§4.11): it starves the other writers
at thin links. The third puts an answer first only once it has waited 100 ms.

### 4.13 The ask window follows the uplink

#### Rationale

**Why the window follows the uplink.** `seacast-lite.md`'s two clocks are fixed. Both were set where
answers come back within a round trip or two, at 50 Mbps. On a thinner link an answer waits longer
behind the answerer's queue, the window runs out before it arrives, the second ask's answer
competes with the first for the same thin uplinks, and both arrive: the bytes stop falling with the
bandwidth and the tail grows.

**The promise's length** (decided 2026-11-13, §8). Stretching the promise with the window too was
checked and rejected: with 30 % withholders at 10 Mbps it lengthened the tail at the median of
paired seeds in the research harness, since withholders then went unparked for the whole payload.
Under the rule as it stands (the window stretched, the promise at 400 ms), the toy's count of
parked pairs stayed below `seacast-lite.md`'s on clean, withholding and mixed networks, since fewer
asks go out, but rose with 10 % of chunks lost (lost answers break promises)
(seacast-figures.md, §4.13).

**Evidence** (the research harness of the posts) comes from runs against `seacast-lite.md`'s fixed
window on the same seed (seacast-figures.md, §4.13). At 10 Mbps per node every seed was faster
and leaner, and the tail was shorter at the median and the copies were fewer. At 25 Mbps every
seed had fewer copies, but only slightly fewer, and the tail was unchanged within the seeds'
spread. With 30 % withholders at 10 Mbps the tail was shorter and the copies were fewer. The toy's
checks (mixed network, silent peers, loss) are in §6.3, `ASK_UPLINK`.

## 6. Settings

### 6.1 `seacast-lite.md` as a setting

#### Rationale

**The distance to the recordings, by date.** The figures file gives the amounts
(seacast-figures.md, §6.1).

- Checked on 2026-10-07: with v0.3's window (slots of one payload chunk) every cell but `rr-stripe`
  reproduced v0.3's completion times and bytes exactly, and `rr-stripe` differed by a few ms at the
  median; the residue was the order of same-instant sends (this document iterates the relation in
  peer order where v0.3 iterated the mesh set). With the window in bytes (§4.11) the cells move
  little, by milliseconds at the median and the tail and by hundredths of a copy, either way, which
  is the two structural changes of §4.11 and not the unit: a control-only entry at the head of a
  queue no longer waits for a chunk's slot, and the chunk is chosen before the room is taken. So
  this document contains v0.3 to within those amounts, and with v0.3's window exactly but for
  `rr-stripe`'s residue.

- Since v0.4's P4 came in (2026-10-21, §4.7) the comparison is with v0.4's recording (`golden.txt`):
  eleven cells stay close to it, and `loss-thin`, at a 20 Mbps uplink, is a little later at the
  median and lighter in copies, the one cell where §4.13's scaled ask window applies; without P4 the
  medians had been well behind v0.4's.

- With v0.5 merged (2026-10-21; every cell of both recordings moves) the comparison is with v0.5's:
  eleven cells stay close to it, and `loss-thin` is a little later at the median and lighter in
  copies, as before the merge.

- With the group's key (2026-10-23, `seacast-lite.md` §1; both recordings move again, as under any
  renaming: `toy/README.md`) eleven cells stay close, and `loss-thin` is later at the median and
  lighter in copies.

- Since `seacast-lite.md` §5.1 announces only to the mesh peers it did not choose for a chunk
  (2026-10-25), its `loss-thin` runs differently with the same medians and copies, so these
  distances stand.

- With ties and no second ask of a peer at once (2026-10-26, `seacast-lite.md` §4.2, §6.1; both
  recordings move) eleven cells stay close, and `loss-thin` is a little later at the median and
  lighter in copies.

- Asks that go with their announcer's dropped offers (2026-10-28, `seacast-lite.md` §6.1) change no
  event in any cell of either recording: nothing was tied in the toy then, and its offers expire
  only after their group has completed.

- With v0.9's rules (2026-11-10, §4.7: the source's holding and its offers at the acknowledgement;
  every cell of both recordings moves), eleven cells stay close to v0.9's own recording, and
  `loss-thin` is a little later at the median and lighter in copies.

- With the toy's transport keeping `seacast-lite.md` §7.3's rule (2026-11-15, one entry at a time per
  connection; every cell of both recordings moves but `rr-stripe`, whose uplink has no send buffer),
  eleven cells stay close to `seacast-lite.md`'s recording, and `loss-thin` is later at the median and
  lighter in copies.

**`ihave-limits` against `seacast-lite.md`.**

- Under v0.9's rules and the toy's transport since 2026-11-15, in that day's recordings, this
  document held back slightly fewer asks to the next heartbeat than `seacast-lite.md` did. It was a
  little sooner at the median and a little later at the tail, with a few hundredths of a copy more.
  With the earlier transport (`--send-buffer 0`) it held back slightly fewer too, and it was a
  little sooner at the median and at the tail (seacast-figures.md, §6.1).

- Before §4.3 carried the limits, it held back none and ran as without them.

**Draft 0** did not reproduce the cells at all: it filtered a forwarding node's push candidates by
what it had already pushed, which `seacast-lite.md` does not, and it shuffled the relation peers for
repair in a different order than `seacast-lite.md`'s mesh set, so its random draws diverged; draft 1
fixed both.

### 6.2 The five designs as settings

#### Rationale

**Variant C** as a setting of this document completes the toy's check cell faster in the tail and at
more bytes than the tier 4 setting, the direction the harness measured, with the toy's sizes
(`toy/README.md`).

**The custody setting** runs a block of 32 blobs as 128 column groups from one proposer to
custodians of 8 columns each, with a mesh per column on the custodians' subgraph; every custodian
completes, nothing is pushed outside interest and no node pushes a chunk above its budget, and
executing it found two things in the carried-over code: the window's line of writers stalled while
slots were free (`seacast-lite.md` §7.1, fixed there, since it is `seacast-lite.md`'s window) and card 12's
projection assumes a code (§4.9). With supernodes (`--supernodes`), custodians of every column that
keep the rows and rebuild a row still short at the second phase's delay, the custody cell whose
proposer withholds half the columns completes on every seed run, where without them nearly every
custodian stays short; this is PeerDAS's reconstruction, delayed (§4.6; seacast-figures.md,
§6.2).

**The sampling setting** runs on top of custody (`--samplers`): a share of the nodes declare eight
cells per block to one custodian each, and every reachable sample completes, a little before the
custodians' columns do, with the custodians serving a handful of chunks each to samplers; executing
it is what made the WANT a standing request (§4.5, §4.10), since a sampler's WANT reaches the
custodian before the cell does, and a pull with a promise timer would have parked every custodian it
asked.

**The row setting** runs EIP-8371's rows on top of custody: each node has one designated subnet,
rows are pull-only, members complete at 64, reconstructors of 64 columns decode at K and any member
decodes later, and a proposer withholds half the columns, so that only the rows can fill them. At
the recorded seed every custodian completes through the rows, and on every seed run with a
custodian link per column for every member (§4.6's repair floor; without it some runs left
custodians short, each for a missing link), every cell sits in both of its groups (R4), and a liar
fault shows a false claim detected by the probe (R5; seacast-figures.md, §6.2). Executing it
changed the document in eight places: a chunk a node rebuilt is filled into its other groups as
rebuilt and acknowledged to nobody, and completes them (`decode_group` checks them as `on_chunk`
does); repair respects `EAGER`, so rebuilt row cells are offered to row members and pushed only
into the columns; the claim in a holding is "I hold or can produce every index", not "my interest
is satisfied", since a member complete at 64 was read as claiming 128; the probe is exempt from
stop-pull and the ask window and its promise is the deferral window; an unverified claim counts for
nothing in the subnet's view, or a liar suppresses the third phase; and "still incomplete" is read
in that view, or every member short of 128 rebuilds a row the network already has; and every
member keeps a link to each column (`REPAIR_FLOOR`), or a row is neither gathered nor repaired
where no member has one. With three supernodes the second phase completes the 32-subnet withheld
cell on every seed run, a cell some of whose subnets have no member (short without them at the
recorded seed), and much shortens the withheld cells' time (seacast-figures.md, §6.2); it
changed the document in two more places: a supernode keeps every row with interest declared on no
link (§1.2), and a row whole on its columns' bitmaps but not in the node's holdings waits once
before it is rebuilt (`known_across`), or a supernode still receiving its columns rebuilds rows
nobody withheld.

### 6.3 Parameters, limits and constants

#### Rationale

**When each was decided.** On 2026-11-01 the decisions were `REPAIR_SAMPLE` with its steps kept as
an option, `REBUILT_SEEN` only with it, and the alarm for networks without an honest supernode. On
2026-11-13 they were `M`, `DECODE_AT_K` and `DECODE_LATER`, `REPAIR_TO`, `REPAIR_BUDGET`,
`REPAIR_FLOOR`, `SOURCE_FLOOR`, `DEFER_WINDOW`, `EVIDENCE`, and the promise per peer. On 2026-11-14
they were `ANNOUNCE_EXTRA`, `START_DELAY`, and the bounds on groups tracked per slot, relations per
link and sampling-only links accepted. On 2026-11-18 the decision was `SOURCE_OFFERS`.

**`R_NODE`, `R` for cells, in the toy.** In the toy's 60-node cells so far, supernodes on datacenter
links, in the fast class, pushed mostly duplicates into columns of few custodians: more copies per
node in the honest custody and row cells, and a longer tail in the honest row cell. With cells at
`R`, the honest row cell's tail and copies are back near those without supernodes, the withheld
cells are as fast or faster at the tail for fewer copies, and the honest custody cell gives up a
few tens of ms at the median and at the tail for fewer copies (seacast-figures.md, §6.3).

**`PROMISE`, in the toy.** So far the toy shows this: in the honest row cell the 400 ms promise
broke thousands of times per run and parked hundreds of honest (peer, group) pairs. Nearly every
broken promise was a column ask that the asked node answered later, behind the rows' pulls on its
uplink, and none was a refusal. At 0.8 s it broke only a few times, with completion times moving
little and bytes unchanged, since the asker moves on after `IWANT_WINDOW` either way and the
promise decides only whom it parks. For the payload, the promise was evaluated with §4.13
(2026-10-19): a promise stretched with the ask window on thin links lets withholders go unparked
for the payload (with 30 % withholders at 10 Mbps it lengthened the tail in the research harness;
silent peers, who announce nothing and so are never asked, were not hurt in the toy), so the
payload's promise stays at 400 ms (seacast-figures.md, §6.3).

**`SAMPLE_RETRY`.** In the toy's 500-node cells the custodians' 99th percentile was well within
`SAMPLE_RETRY`'s wait. Under 30 % withholders the samplers' median follows that wait
(seacast-figures.md, §6.3).

**`SAMPLE_COVER`.** It is at least 1: without a floor some samplers of eight cells hold a sample no
link serves at 70 links, and nearly all do at 16 (§1.3). In the toy's 500-node cells, two covers
left no sampler short, honest or under 30 % withholders, at 70 links and at 16. One cover did as
well at 70; at 16 it left some samplers short under withholders, and it raised the honest samples'
99th percentile well above that with two covers. For the floor of the fewest links, with high
custody counted in full, in the toy's graphs (`toy/sampler_graph.py a`) one cover adds a few
links on top of 70 and more on top of 16, two covers add more again, and one link to a node
custodying every column covers all; where a tenth of the nodes custody 64 columns, the floor adds
none on top of 70 and few on top of 16. For the diversity floor, with covers counted by distinct
links (`toy/sampler_match.py`), nearly every draw of eight samples finds eight distinct serving
links with two covers, at 16 links and at 70; three covers do better still, and they are the floor
that holds for sixteen samples; one cover falls well short of that at 16 links, and a little short
at 70 (seacast-figures.md, §6.3).

**`COVER_HIGH`.** At 0, the share of draws that find distinct servers is nearly that at 1, with
eight samples and with sixteen, at a link more. With one supernode link counted in full and no
other rule, a draw rarely finds eight distinct servers at 16 links (seacast-figures.md, §6.3).

**`ROUTE_FLOOR`.** In the same graphs, without a per-column floor at 16 links: the hypercube rule
brings every (sampler, column) pair within two hops, and the Kademlia-style rule brings most pairs
within two and the rest in three, for fewer links added per custodian (seacast-figures.md,
§6.3).

**`ROUTE_HOPS` above 1** serves where one step does not reach a custodian, as for the pairs that the
Kademlia-style rule reaches only in three hops; in a 60-node cell one request that took a second
step brought its sample early, where with one step it had waited for the second phase
(seacast-figures.md, §6.3).

**`FORWARD_LIMIT`.** In the toy's 60-node cells (one seed, two covers, routed requests on), a limit
of 1 changed no event, honest or under 30 % withholders; with half the columns withheld it refused
a small share of the forwards, and the same samples arrived (seacast-figures.md, §6.3).

**Sampling-only links accepted.** On average the bound is the samplers' added links over the nodes
that serve them: in the toy's graphs, with a fifth of 500 nodes sampling, that comes to a few links
per other node, more at 16 links than at 70 (`SAMPLE_COVER`, above), and a limit at the average
would refuse some, as the draws are not even (seacast-figures.md, §6.3).

**`ASK_UPLINK`.** In the toy, in the research harness's setting, against `seacast-lite.md`'s fixed
window, the copies are fewer in every cell; the tail is a little shorter in the all-home network at
12.5 Mbps, with 30 % silent peers, and in the mixed-bandwidth network at 6 Mbps with a home builder
and with a datacenter builder, and about the same with 30 % withholders; with 10 % of chunks lost
it is a little longer (a lost answer is waited for until the longer window closes;
seacast-figures.md, §6.3).

**`MERGE_HOLDINGS`.** In the toy (§4.7), for a 50 Mbps proposer of 128 column groups, it takes back
a small part of what P4 costs at the custody block's median, with writes that complete at once and
with one write per connection at a time; the copies are unchanged (seacast-figures.md, §6.3).

**The IHAVE limits.** A low message limit trades latency for copies. Offers come chunk by chunk, so
it holds back many asks. An ask held back is likely often never made, because by the heartbeat the
chunk has come by push: that saves a duplicate pull (not counted). In the toy's `ihave-limits`
cell (60 nodes, one seed, under v0.9's rules; `toy/run.py --doc seacast --ihave-limits M,5000`),
against no limit, a limit of 10 frames costs the most time at the median for a small saving in
copies, 20 costs less time and saves the most, 40 costs and saves little, and 100 changes neither
(seacast-figures.md, §6.3). The 5000 asks never bound. On the libp2p stream binding, not
gossipsub's 10, since in that cell 20 saves more copies for less delay. On the gossipsub binding,
batching a peer's offers into fewer frames avoids the delay, and with it the saving. At
`seacast-lite.md` §8.3's reference values (4096 frames, 5000 ids, per peer and heartbeat), no ask was
held back in the toy's 60-node cells under the tier 4 setting, variant C and custody (with and
without samplers), nor under the rows setting (with and without half the columns withheld), and
each ran as with no limit; the busiest peer stayed well below both values (§4.3;
seacast-figures.md, §4.3). What the limits protect is mostly bounded already: one ask per index
at a time (`seacast-lite.md` §6.1), asks only for groups an installed block commits (§4.2), and the
offer table's limits (`seacast-lite.md` §8.2).

## 7. Bindings `[D1]`

**Where the gains are.** The libp2p stream and Waggle bindings are where X2's gains are had:
interest without subscription, a push relation per family and colour with a floor and a direction,
and scoring on these messages. The partial-messages binding, which carries columns, gives up the
first two, but for a sampler's interest. It uses only gossipsub's existing topics, so a network can
adopt it without new subscriptions. A mixed network needs a bridge between a binding and the
stock path that does not double the bytes; it is outside this version (`[D1]`, §8).

- *What it gives:* it reaches a custodian directly where §4.10 would route. That is one hop instead
  of two, nothing disclosed to a forwarder, and fewer links kept for the coverage floor, which
  matters most where a node's connection budget is small (at 16 links the floor of the fewest links
  nearly doubles a node's links, §6.3; seacast-figures.md, §1.3).
