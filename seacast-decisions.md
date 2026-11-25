# SEACAST: its decisions

This is the decision record of SEACAST, [`seacast.md`](seacast.md). It lists the design
decisions `[D1]` to `[D12]` and the others that SEACAST took: when each was decided, what was not
taken and why, and the runs behind it. It also lists the versions of [`seacast-lite.md`](seacast-lite.md)
that SEACAST has carried. `seacast.md` states the rules and gives their reasons; the comments in
its code cite these labels where each decision bites.

In this file, a section number (§) without the name of a document refers to `seacast.md`'s
sections, and "this document" and "this draft" mean `seacast.md`. The figures behind this record
are in [`seacast-figures.md`](seacast-figures.md), under the conditions that its preamble
states.

## The decisions, and where they bite

| decision | where in `seacast.md` |
|---|---|
| `[D1]` identity and bindings (decided: a protocol of its own, carried by its bindings, in their own document since 2026-11-17, three when decided and four by carrier since 2026-11-21; a bridge to the stock path is outside this version) | §7, `seacast-bindings.md`; §0's "what is assumed" |
| `[D2]` two bitmaps, WANT per recipient, no need bitmap (decided, as written) | §2 `Want`, `on_want`, `wants_from_me` |
| `[D3]` two claims (decided, as written) | §2 `Have`, §1.5, §4.6 |
| `[D4]` repair's parameters (decided: EIP-8371's phases, rebuilt cells pushed to the custodians lacking them, `DEFER_WINDOW` 1 s, `REPAIR_BUDGET` an option, off; the repair floor at least one link to a custodian of each column) | `TypeParams.DECODE_AT_K`, `DECODE_LATER`, `REPAIR_TO`, `DEFER_WINDOW`; §6.3's `REPAIR_SAMPLE`, `REBUILT_SEEN`, `ALARM_WAIT`; §4.6 `check_completion`, `reconsider`, `push_rebuilt` |
| `[D5]` the announce relation's width (decided: `ALL_JOINED` for columns and rows; `NONE` permitted for columns, never for rows) | `TypeParams.ANNOUNCE_EXTRA`, §4.4 `announce_extra`, §4.8 `send_gossip` |
| `[D6]` the payload's consistency route (decided: none in this version; the `EVIDENCE` hook stays) | `TypeParams.EVIDENCE`, §4.6 `decode_group`, the payload's leaf rule (`seacast-lite.md` §1's commitment, which §1.1's `verify` checks) |
| `[D7]` groups per column and per row, cross-fill (decided, as written) | `ObjectType.project`, `family`, §4.2 `on_validated`, §4.4 `forward` |
| `[D8]` the row pull delay (decided: 1 s; shorter at a cost under liars) | `TypeParams.START_DELAY`, §4.3 `on_offer` |
| `[D9]` one document or a sibling (decided: a sibling) | `seacast.md`; §6.1 is the merge path |
| `[D10]` colours (decided: a parameter, with no default) | `TypeParams.M`, `F_LO`, `F_HI`, `D_OUT`, `SYMMETRIC`, §1.4, §4.1 |
| `[D11]` join = (interest, duty); topics as rendezvous (decided: the join as written; the rendezvous gossipsub topics per family, with the ENR beside them) | §2 `Join`, §1.2, `seacast-bindings.md` §0's rendezvous row |
| `[D12]` a sampler's reach (decided: a coverage floor with `SAMPLE_COVER` set at 2, LiteDAS's second phase, routed sample requests of one step) | §1.3; §2 `Want`; §4.1 `keep_coverage`; §4.5 `route_want`; §4.10; `TypeParams.SAMPLE_RETRY2`, `SAMPLE_COVER`, `COVER_HIGH`, `ROUTE_HOPS`, `FORWARD_LIMIT`; the node's `SAMPLE_OUTSTANDING`; §6.3's `ROUTE_FLOOR`; §7's last paragraph |
| the promise's length (§4.13) (decided: 400 ms the default; the per-peer promise permitted as local policy) | `seacast-lite.md` §6.1's `PROMISE`; §6.3's `PROMISE` row |
| a source's links in a family it does not custody (decided: it never waits for links; three layers on top of its fanout; a refused push to a fallback link owed) | §4.7 `source_pool`, `candidates_for_source`, `origin_acked`, `unpush`; §6.3's `SOURCE_FLOOR` row |
| the probe of a claim (R5) (decided: the claimant judged by its own copy; the probe marked and answered whatever the asker holds, once per asker and group; the asker's queue keeps it; its cell drawn at random) | §2 `Want.probe`; §4.2 `on_chunk`, `fill`; §4.5 `on_want`; §4.6 `reconsider`, `defer_on_claim`, `settle_probe`, `probe_answer`, `probe_promise`, `probe_waits`, `probe_of_claim`, `serve_probe`, `filter_entry`; `seacast-bindings.md` §0's WANT row |

**Decided on 2026-11-13.** Six of the decisions above were chosen on that day, and each entry below
says what was not taken:
- **`[D1]` identity and bindings.** SEACAST is its own protocol: it is defined on its own messages
  and carried by three bindings, which are defined in their own document (`seacast-bindings.md`,
  since 2026-11-17). The three were the standalone binding, the binding onto the Partial Messages
  Extension of gossipsub, and the gossipsub binding. Since 2026-11-21 they are named by their
  carriers: the libp2p stream and Waggle bindings, the gossipsub binding and the partial-messages
  binding (`seacast-bindings.md` §2 to §5; below, "Decided on 2026-11-21"). §7 states what
  every binding provides and the capabilities that each gives up. The extension alone was not
  taken: it gives up interest without subscription and the floor and direction of the push relation
  (§7). Deciding after a paired test of the signalling cost on both wires was not taken either:
  neither implementation here can run that test, since neither speaks the wire of the extension. A
  mixed network needs a bridge between a binding and the stock path; that bridge is a deployment
  question that no measurement here settles, and it is outside this version.
- **`[D4]` the repair floor.** A node that may rebuild keeps at least `REPAIR_FLOOR` links to
  custodians of each column that it does not custody (§4.6). The parameter is at least 1. Without
  the floor, some runs of the toy's row cell with half the columns withheld left custodians short,
  each one by a missing link; with a floor of 1, every run completed (seacast-figures.md, §6.2).
  Opening a link only when a rebuilt cell has nowhere to go (§4.6) was not taken; it is kept as an
  option.
- **`[D6]` the payload's consistency route.** This version has no such route: it leaves the
  consistency of the payload to level 2 and the application, and `EVIDENCE` stays a hook that an
  object type may fill. Three routes were not taken here, and each needs work outside this
  document. A fraud proof over the current code would change the leaf rule and would need a
  condition on the consensus side; it stays the route that changes neither the code nor the
  commitment scheme. The payload in blobs would be a change to the bid. The third route is a layout
  in two dimensions.
- **`[D9]` one document or a sibling.** The draft is a sibling. `seacast-lite.md` is the published and
  measured protocol, and this document contains it as one setting; that setting (§6.1) is the merge
  path if one document is ever wanted. The cost is that each version of `seacast-lite.md` is carried in
  here (§5). One document was not taken. The case for it is that the payload and the general rules
  are the same code; folding `seacast-lite.md` into these notions would rewrite text without changing
  behaviour.
- **`[D10]` colours.** The number of colours, `M`, is a parameter with no default. It is measured
  at 1 (tier 4, `seacast-lite.md`) and at N (variant C). Values with 1 < M < N are for later study,
  which first needs colour negotiation and a floor per colour in the toy. A measured default before
  release was not taken.
- **`[D11]` the rendezvous.** Every binding uses gossipsub topics per family as the rendezvous, with
  the ENR beside them. This keeps the stock path, and a network that mixes it with the bindings. The
  ENR alone was not taken; it is an option that the libp2p stream binding could run.

The other choices, listed below, were confirmed as the toy runs them and, where named, as the Go
build of the research harness runs them. Nothing measured argues against them.
- **`[D2]`:** the draft has two bitmaps, the WANT per recipient, and no bitmap for need (§2), as the
  RowDAS design has it. `[D12]` added `standing` and `hops` to the WANT.
- **`[D3]`:** the draft has the two claims, `claim_all` and `complete` (§2, §1.5). They are
  unverified, and a claim not followed by the chunks it implies counts against the claimant.
- **`[D4]`, the rest of repair's parameters:**
  - EIP-8371's phases decide who decodes and when;
  - rebuilt cells are pushed to the custodians that lack them;
  - `DEFER_WINDOW` is 1 s;
  - `REPAIR_BUDGET` is an option, and it is off.

  §6.3 gives their values, which are the same in both implementations.
- **`[D7]`:** the draft has groups per column and per row, and a rebuilt chunk fills its other
  groups (`project`, `cross`, R4).
- **`[D11]`, the join:** there is a JOIN per link and object type, and it carries interest and duty
  (§2, §4.1).

**The promise's length.** §4.13 stretches the ask window on thin links and keeps the promise at
400 ms, so a peer that does not answer is parked as in `seacast-lite.md` §6.1. A slow honest peer can be
parked as well: its answer can take longer than the promise while the stretched ask window still
keeps the asker waiting on it. The option is a promise per peer that follows the
times its answers took: `max(PROMISE, srtt + 4 · rttvar)`, smoothed as TCP's retransmission timer is
(RFC 6298); a peer that never answered keeps the floor. In the toy, in the setting of the research
harness at 12.5 Mbps, the option gave the same completion times and bytes as §4.13's form, parked
fewer honest (peer, group) pairs than that form and than `seacast-lite.md`, and parked the withholders
of a 30 % withholding network as before (seacast-figures.md, §4.13). It buys the standing of
honest peers (and whatever scoring reads from broken promises), not time; it needs per-peer state
and a sample on every answered ask. It is not measured in the harness. The other form, a promise
stretched with the window, is rejected (§4.13).
- **Decided on 2026-11-13:** 400 ms stays the default, and the per-peer promise is permitted as
  local policy, as `MERGE_HOLDINGS` is. The promise is the asker's own timer: it changes whom the
  asker parks, and so whom it asks next, not what either end means.
- **Not taken:** making the per-peer promise the default would first call for runs in the research
  harness at ten seeds.

**A source's links in a family it does not custody** (decided 2026-11-13, §4.7). A source never
waits for links: it publishes at once to the links it has. When it has no relation in a family for
a chunk's colour, its fanout uses those of its links whose interest holds the chunk. A push to one
of them that a full queue refuses is owed, as to a relation peer (decided 2026-11-14). On top of
the fanout, three layers keep its chunks moving: links kept to custodians of each family it will
publish (`SOURCE_FLOOR`, a parameter with no default), a hunt through the binding when a chunk has
nowhere to go, and the code as the backstop. In the toy the fallback never yields a peer, since the
proposer of the toy has a relation with every custodian it links to, and the hunt is not measured.
Two alternatives were not taken. Holding the publish until the links are there would delay every
family for one that the code can recover. For a refused push, an offer at the chunk's
acknowledgement was not taken either: when every copy was refused, that offer waits for a holding
that names the chunk or for the timeout of a later copy.

**The window's unit** (X3, decided 2026-11-13): the unit is bytes, as §4.11 runs it, and a chunk
takes its own length of the window. In the toy the column cells gain, at 500 nodes too, and tier 4
moves little (seacast-figures.md, §4.11). The alternatives not taken were the slots of
`CHUNK_BYTES` that `seacast-lite.md` uses, and slots per object type, which leave the same capacity
question at every boundary between types (§4.11).

**Decided on 2026-11-14.** Two decisions were made after their runs; the rule of §4.12 was also
decided. The runs are toy checks (`toy/run.py --doc seacast`, the flags `--col-announce`,
`--row-announce` and `--row-delay`). Each setting is read against the value that every earlier
measurement ran, paired by seed. A value is *close* if it leaves no more nodes short, and none on a
seed where the other left none, and moves the custodians' median and 99th percentile, and in the
row settings a row member's 64th cell, by at most +20 ms at the median over the seeds.
- **`[D5]` the announce relation's width.** The width is `ALL_JOINED` (§4.4) for columns and rows,
  as every measurement ran it. `NONE`, which sends offers to the relations only, is permitted for
  columns, never for rows.
  - *At 60 nodes*, the columns' `NONE` is close in custody at 50 Mbps and with a 1 Gbps proposer,
    in custody and in rows with half the columns withheld, and in the honest rows. It sends fewer
    offers, and slightly fewer copies. With a fifth of the nodes lying about their row holdings
    (`claim20`) it is not close: on one seed a custodian is short in more blocks than with
    `ALL_JOINED`, and on another a row member is short where none was (seacast-figures.md,
    [D5]).
  - *At 500 nodes*, it is close in custody, with fewer offers and slightly fewer copies. It is close
    in rows with half the columns withheld and a 1 Gbps proposer, with fewer offers and fewer
    copies. With liars and no withheld columns it is close by the rule as written, the median over
    the seeds, but not on every seed: the custodians' median is inside the bound on the middle seed
    and outside it on another. It is not close with half withheld. No node is short in either
    (seacast-figures.md, [D5]). Three seeds show a pass or a fail, not a comparison, and do not
    show the 60-node shortfall gone.
  - *The rows' `NONE`* left row members short on every seed in every row setting: the rows need
    the offers to every joined peer.
  - *The columns' `SAMPLE`* (the heartbeat's paced gossip) was close where `NONE` was, except in the
    500-node rows with half withheld, where the custodians' 99th percentile on the middle seed is
    over the bound (seacast-figures.md, [D5]). The rows' `SAMPLE` runs as `NONE`, since a cell
    is published under its column and the heartbeat offers it there.
  - `NONE` was not taken as the default for columns. Its saving is mostly control; its failures are
    under liars, where the offers beyond the relation are the fallback; and its passes at 500 nodes
    rest on three seeds.
- **`[D8]` the row pull delay.** The delay is 1 s, as every measurement of the toy and the research
  harness ran it: a secondary axis waits for the column path (R7). In the toy at 60 nodes (honest
  rows, rows with a fifth of the nodes lying about their row holdings, rows with half the columns
  withheld), 2 s costs the column path: the custodians complete later at the median, in all three
  settings (seacast-figures.md, [D8]).
  - *It can be shorter, at a cost.* 0.5 s and 0 s move the custodians little at the median. 0.5 s
    brings a row member's 64th cell sooner at the median. But with liars both leave row members
    short on every seed, far more than 1 s does (counted once per block they are short in), and 0 s
    also leaves more custodians short (seacast-figures.md, [D8]). Without liars neither leaves
    any short. Why this happens was not traced.
  - The draft did not take 2 s, which fails R7. Nor did it take a delay under 1 s as the default.
- **A source's own chunks go first** (§4.12), under X3's window in bytes. In the toy its clearest
  gain was in custody with a 50 Mbps proposer, and single-group cells run as under v0.3's order,
  which takes the rarest of the chunks ahead of the first control-only entry (card 9)
  (seacast-figures.md, §4.12). The alternatives not taken were v0.3's order, and dropping the
  source's offers or queueing them after the block's pushes, which delay a fast proposer's
  completion at the median (seacast-figures.md, §4.12).

**The probe of a claim** (R5, decided 2026-11-15, §4.6). The probe judges the claimant only by the
claimant's own copy of the probed cell, which comes as an answer or a push. Three rules make that
fair to an honest claimant and hard to meet for a dishonest one. First, the probe's WANT is marked
(`probe`, §2), and the claimant answers it whatever the asker's holdings say. It does so once per
asker and group: the answer takes this exemption, which is spent when the answer is written.
Second, the queue of the asker keeps its marked WANT while the probe waits. Third, the probed cell
is drawn at random among the cells that the member lacks. In the toy's rows, over five settings, no
honest or hoarding claimant failed its probe, with the rules of 2026-11-18 or with those of
2026-11-16; before them, a few failed without the mark and the kept WANT. Liars almost never passed
in two of the three settings with liars, and passed more often in the one with supernodes
(seacast-figures.md, §4.6, "The probe"). Since 2026-11-16, the following holds: the probe's
wait starts at its write; a probe not written when the duty next fires gets no verdict unless the
claimant's own copy came first, and it is not written later; a claimant still decoding keeps the
first probe per asker and group and answers it once when the cell is stored; a claimant that leaves
before the verdict gets none; without a verdict, the member's own repair is reconsidered at the
duty's own time, or at once if that time has passed; and once the probe is settled, a promise under
its key is the promise of a plain ask, which any copy closes. Three alternatives were not taken: any
peer's copy passing the claimant, which let liars pass whenever another peer brought the cell (far
more often in the same settings, measured before 2026-11-16); hiding the probed cell from the
claimant in the asker's holdings while the probe waits, which changes what a node announces and
cannot hide a cell already named before the probe; and the lowest lacked index, which a claimant
can read from the member's holdings. The random index is meant to counter a claimant that keeps only
the cell it expects to be asked; that purpose is not measured, since the toy's liars do not aim.
SEACAST's message encoding carries `standing` and `probe` in one `Bitvector[8]`; its other bits are
zero when sent and ignored when received, so that a later flag fits without breaking older readers
(`seacast-bindings.md` §1.2). On the gossipsub binding the mark is one more bit beside
`standing`, in version 4 of the strings (§4 there). Two alternatives were not taken there: a byte of
its own for the mark, which every WANT would pay, and a message of its own for the probe, which
every binding would have to carry.

**The repair's options** `[D4]` (decided 2026-11-01). The repair sample and rebuilt cells marked
seen stay options. They are on together where a node defends against hoarding claimants, and the
second is never on alone (§4.6). The custodian's alarm stays an option for networks without an
honest supernode.

**Dropped: biasing the repair sample**. The bias would draw half of each step's new cells from the
columns that the member check cannot vouch for. These are the columns that no member of the row's
subnet custodies.
- *What the node knows.* It knows only the members it is linked to. From those, most of the cells a
  member lacks look uncovered, so the bias barely narrows the draw.
- *The odds.* In a network model of the toy's 500-node rows, in one network whose hoarders repair
  the members' cells and leave a few columns unrepaired, the bias over linked members makes it only
  somewhat less likely that every honest member of the subnet passes the member check, the case in
  which nobody repairs the row and it stays short. It makes that unlikely only with every member
  known, a view the node does not have.
- *Where hoarders mark their rebuilt cells seen,* the uniform sample already catches them in the
  model. Beside that option, the runs (a toy check) showed nothing from the bias
  (seacast-figures.md, §4.6, "Biasing the repair sample").

**A sampler's reach** `[D12]`, decided (2026-11-03). The steady state is a coverage floor (§1.3),
built for diversity. Its size is `SAMPLE_COVER`, a parameter of the object type with a bound of at
least 1, set at two links per family; `COVER_HIGH` is set at 1 (§6.3). Routed sample requests
take what the floor misses, with one forwarding step by default (§4.10, `ROUTE_HOPS` 1). Both run on
LiteDAS's two phases: one sample per peer, with peers of high custody as the second phase's
fallback. Since 2026-11-22, the second phase's asks in flight have one cap per block, counted across
the block's sampled types. The cap is `SAMPLE_OUTSTANDING`, a setting of the node with a bound of at
least 1; before, it was a parameter of each object type. One cap per block bounds the asks that a
block's hunt has in flight, and a cap per type, on a count that the types share, could keep §4.10's
refill loop from ending. The standing WANT carries the first phase (§2, §4.5), and `FORWARD_LIMIT`
and `SERVE_LIMIT` are limits stated by their bounds (§6.3). The evidence is the toy's graphs, its
60-node cells and its 500-node cells at ten seeds (seacast-figures.md, §6.3). These are kept as
options: one cover (`SAMPLE_COVER` 1), more than one forwarding step, the routing neighbours
(`ROUTE_FLOOR`), and the fetch outside the links (§7). The notes below are kept for later study:
- *Why diversity, not the fewest links.* There are three reasons. First, one node that holds a
  sampler's whole sample can release exactly those cells to it. This is the selective share
  disclosure of Al-Bassam, Sonnino and Buterin ("If a block producer selectively releases shares as
  light clients ask for them, up to (k + 1)² shares, they can violate the soundness property", their
  §5.4), which is defeated only where "the network would not be able to link different per-share
  sample requests to the same clients". Second, custody counts are self-declared, so a node that
  claims every column would attract every sampler's floor and samples. Third, the load would
  concentrate on the nodes of high custody. In the toy's honest 60-node cell before this rule (floor
  and routed requests, one seed), the proposer, which holds every column, was asked for some of the
  samples, up to most of one sampler's samples in a block, where no other peer was asked for as
  many; with the rule, the proposer was asked for none, and no peer was asked for more than one
  (seacast-figures.md, [D12]).
- *The floor's size.* The decision sets `SAMPLE_COVER`, a parameter of the object type, at 2. On
  the toy's graphs, eight samples find eight distinct serving links in nearly every draw with two
  covers; with one, they fall well short of that at 16 links, and a little short at 70. In the
  toy's 500-node cells, two covers confirmed every sampler in every block, honest and under 30 %
  withholders, at 70 links and at 16. One cover did as well at 70 links. At 16 it cost the honest
  tail, and under withholders some sampler-blocks did not confirm. Two covers add more links than
  one, on top of 70 and on top of 16. Three covers, a floor nearer every draw and the one that holds
  for sixteen samples, would add more again (seacast-figures.md, §6.3). The number of
  sampling-only links that a custodian accepts is a bound, and each node's own number lies within it
  (§6.3); the serving load that these links bring the custodian is not measured.
- *The floor's lifetime.* The floor is kept across slots and chosen from custody alone. Whether and
  how often it rotates, and what churn costs it, are not measured.
- *The route and its privacy.* Without routing neighbours a first hop is any link with duty
  `FORWARD`. Where custodians keep a floor per column of their own (§1.4, as PeerDAS's subnet
  peering), one step on random links left few (sampler, column) pairs unreached at 16 links in the
  toy's graphs, and almost none at 70; without such a floor, it left many more unreached at 16 links
  (§4.10). The routing rules (§1.3, `ROUTE_FLOOR`) are for networks without it; the Kademlia-style
  rule is the cheaper, and the pairs it reaches only at three hops are the case for `ROUTE_HOPS`
  above one (seacast-figures.md, §4.10, [D12]). A first hop drawn at random is not measured.
  Nothing yet measures what a forwarder learns (one sample of one sampler), a forwarder colluding
  with the proposer, or the time a routed sample takes.
- *The hunt's cost.* A sample that nobody holds is asked of one fresh peer after another until none
  is left, and each peer is asked at most once per block, so the asks per block are bounded by the
  node's links. With half the columns withheld (60 nodes, one seed), a sample took a few asks, more
  with routed requests and more again with the floor of one or two covers as well, and hundreds of
  requests were passed on; before one sample per peer, a sample took more asks, and more requests
  were passed on (seacast-figures.md, [D12]). Whether to bound the first hops that a sample
  tries, or to let the application's deadline end the hunt, is open.
- *The cost of one sample per peer.* Under 30 % withholders (the toy, the floor with routed
  requests, one cover, one seed), every sample still arrived, but later at the median and at the
  99th percentile than when a peer could be asked again: the second phase must find a fresh peer
  each time (seacast-figures.md, [D12]).
- *Small networks.* The floor covers only the families some node other than a source custodies;
  in the toy's 60-node cells a few columns had no custodian but the proposer, and routed requests
  reached it for them (seacast-figures.md, [D12]).
- *Rows as a second axis.* A row member holds a cell of its row once it has it, and serves it to
  anyone who asks; `serves` counts columns only. In the toy's graphs at 70 links
  (`toy/sampler_graph.py e`), counting half rows (the draft's members stop at 64 of 128) leaves
  fewer samplers with a sample no link serves, more so with 32 row subnets than with 128; whole
  rows (FullDAS's two-dimensional code) leave fewer still. At 16 links rows barely help
  (seacast-figures.md, [D12]).
- *LiteDAS's slot start.* A group id names the block, so a WANT waits for the block's header; a
  request keyed by slot would let it go at slot start, as LiteDAS's does. Such a request is not
  proposed.
- *LiteDAS's extensions.* Neither of these is proposed: a holdings list in the reply, and a NACK by
  which a custodian that lacks the cell asks the sampler to pass it on once it has it (feeding
  custody).
- *Outside the links.* In this option, a node fetches from a node of the known node set that is not
  a link (§7). The binding chooses how the fetch travels: over an ephemeral libp2p connection, plain
  UDP, a fast QUIC connection or discv5.
- *Rejected:* the draft rejects narrowing the sample to what the node's links serve (§4.10).

**Decided on 2026-11-21.** Four decisions on the bindings, each given in `seacast-bindings.md`:
- **The bindings by carrier.** The bindings document defines SEACAST's message encoding once (§1
  there), then one binding per carrier: the libp2p stream binding, the Waggle binding, the gossipsub
  binding and the partial-messages binding (§2 to §5 there), and the native QUIC binding as a draft
  (§7 there). The gossipsub binding uses gossipsub's wire alone, as `seacast-lite.md` does; the
  partial-messages binding is kept beside it.
- **The gossipsub binding to the byte.** Its extra fields, a holding's `claim_all` and `complete`
  and a WANT's `standing`, `hops` and `probe`, travel in version 4 of the id strings, and a WANT's
  index is a little-endian `uint32`, as `seacast-lite.md` §2 writes it (§4 there). On that binding,
  EVIDENCE is reserved as a full message on the rendezvous topic, as SEACAST's message encoding
  reserves its kind `0x08` (§1.1 there).
- **A cell group's header in three forms** (§1.6 there): from the block, in every cell, or in a
  message of its own. Each object type's definition fixes one form, never mixed on one topic. The
  same three are open on the libp2p stream, Waggle and gossipsub bindings; the partial-messages
  binding carries form (b), by the partial columns' own rule. Not taken: one form for every object
  type, since whether a block comes before its cells differs between applications.
- **The native QUIC binding, as a draft** (§7 there). It carries SEACAST directly on QUIC, with a
  control stream, a stream per chunk, cancel by a stream's reset, and the control stream first where
  the implementation orders streams. It is for study, and not normative. *Open:* whether it runs
  beside libp2p on libp2p's port, beside it on a port of its own, or alone; two studies bear on it
  (§7.1 there), and neither chooses a model. Not taken in this version: datagrams for chunks, since
  a cell does not fit one at the study's packet sizes unless it compresses well, and small payload
  chunks in datagrams were slower in the toy.

## The versions of `seacast-lite.md` carried

**The versions carried.** Each later version of `seacast-lite.md` comes in the same way. Its changes to
functions that this document does not redefine apply as written. Its changes to functions that
this document redefines are carried into them, and an entry gives the date of each one that was
carried later than its version.
- v0.4 (2026-10-13): its one change of behaviour, the source's HAVE paced by its sends [P4], is
  carried since 2026-10-21 (§4.2 `send_have`, §4.7 `publish`, §4.11 `next_to_send`).
- v0.5 (2026-10-21, the fixes from a model check of v0.4): its fixes are in §4.3 `on_offer`, §4.4
  `forward` and `announce`, §4.5 `serve_standing`, §4.6 `decode_group` and the repair, §4.7
  `publish`, and §4.11 `next_to_send`.
- v0.6 (2026-10-21) released this document's draft and changed nothing in `seacast-lite.md`. v0.6.1
  changed only its §9.
- v0.7 (2026-10-25) comes in as follows:
  - The live window and the group's key apply as written; §6.1 shows how the cells moved.
  - Gossipsub's IHAVE limits are carried since 2026-10-27 (§4 `on_frame`, §4.3 `on_offer`,
    §4.8).
  - Its single offer at the source (`seacast-lite.md` §5.1) is carried since 2026-11-04 (§4.7
    `publish`): a chunk is offered only to the peers of its pool that were not chosen to be pushed
    it, so a push that its queue refused, which is owed already, is not offered a second time.
- v0.8 (2026-10-26) comes in as follows:
  - The node announces what it holds to a peer that joins the mesh: §4.1's `join_push` runs at a
    GRAFT that the node accepts and, since 2026-11-04, at the yes to its own GRAFT (§4.1).
  - §4.2 covers ties and the cells released at the header.
  - A node does not ask a peer a second time at once (§4.3).
  - A rebuilt chunk names its sources' block (§4.6).
  - Since 2026-10-28, an ask goes with its announcer's offers (§4.2), and relabelled copies are
    open (§4.6).
- v0.9 (2026-11-10) comes in as follows:
  - The source's holding grows at a chunk's acknowledgement, not at its write (§4.3 `on_holding`,
    §4.7 `origin_acked`, §4.11 `window_timeout` and `next_to_send`), at `SOURCE_OFFERS = ACK`, the
    default since 2026-11-18 (§4.7).
  - Its offers wait for the acknowledgement too, at `ACK`, for every object type a source pushes; a
    pull-only type's source pushes nothing and offers every chunk at publish (§4.7).
  - What the transport below the writer should hold, and the note for operators (its §7.3), apply
    as written (§4.11).
- v0.10 (2026-11-15) comes in as follows:
  - The toy's default transport keeps `seacast-lite.md` §7.3's rule, one entry at a time per
    connection, and both recordings were made again (`seacast-figures.md`'s preamble, §6.1).
  - What waits for a gate is carried where this document uses `seacast-lite.md`'s functions: `tie`, with
    `tie_room`'s limits, the limit of unknown groups and the slot it records (`tie_slot`);
    `close_promises`, which `seacast-lite.md` now gives as code, called from `fill` and `tie`; and
    `on_block_installed`, which drops at installation a tied index the group, known by then, does
    not have, and whose level 1 for the payload is `validate_chunk` with its new check of the copy's
    slot (`seacast-lite.md` §3, §4.2).
  - The announcers beyond a chunk's ordered list are tried in the node's own order, in
    `seacast-lite.md`'s ask path, which this document keeps (`seacast-lite.md` §6.1).
  - Since 2026-11-16, this document carries the following where it has functions of its own
    (§4.2, §4.3, §4.8, §1's table):
    - its `defer` ignores a copy beyond its sender's limit of unknown groups, as `seacast-lite.md`'s
      does;
    - its `on_heartbeat` calls `drop_stale_waits`, so what waits for a gate that never opens goes
      at the live window's edge or the group's expiry;
    - its `fill` calls `drop_beyond` when it opens a group, so offers, asks and ties of an index
      beyond the group's count go;
    - its `on_offer` holds an offer's bitmap to a holding's limits, as `seacast-lite.md`'s `on_ihave`
      holds an IHAVE's;
    - its `on_header_validated` drops a tied index a cell group, known by then, does not have, and
      removes a sender's `tie_slot` with its last tie under the root, as `on_block_installed` does;
    - a cell's level 1 rejects a copy whose slot is not its header's, as `validate_chunk` does for
      the payload against its block (decided 2026-11-16).
- Across v0.10.1 (2026-11-15) and v0.10.2 (2026-11-16), the prose and comments of `seacast-lite.md`
  were rewritten, with its code the same, and the toy's tables were made faster, with the digests of
  the recorded cells the same; there is nothing to carry.
- In v0.10.3 (2026-11-18), `seacast-lite.md` groups its constants into three kinds and gives reference
  values for gossipsub's two IHAVE limits. It calls what a peer writes on its stream a "frame",
  describes the source's HAVE as "acknowledged", and gives the source a choice of when it announces
  (`SOURCE_OFFERS`). This draft carries them all: the rename (`on_frame`, `frame`, `ihave_frames`),
  the bounds of §6.3 in the kinds of §8.3, the IHAVE values (§4.3, §6.3), "acknowledged" (§4.7), and
  `SOURCE_OFFERS` (§4.7, §6.3).
- v0.10.4 (2026-11-18): `seacast-lite.md` says what heartbeat gossip tells of the source, names as open
  the case of a chunk that is never acknowledged, and keeps an IDONTWANT entry that is not a HAVE
  bitmap as stock gossipsub keeps an id (`on_frame`); the toy follows the documents at a dropped
  group and in its reading of bitmaps and ids. This draft runs on the same toy. It carries the
  IDONTWANT rule onto the gossipsub binding (`seacast-bindings.md` §4), where the toy now keeps
  such an entry in `unwanted[p]`. §4.7 already says that, for a type that gossips
  (`ANNOUNCE_EXTRA = SAMPLE`), the source's heartbeat gossip draws on every chunk at either setting,
  and its open item on a chunk that is never acknowledged is the one `seacast-lite.md` §5.1 names.
- v0.10.5 (2026-11-19): `seacast-lite.md` is the same but for its version line, and the proofs in
  `formal/veil/` move to Veil's release. The toy's `accepted` answers whether the id was stored, as
  `seacast-lite.md`'s helper list says, so under this draft a later copy of a copy that level 1 rejected
  no longer passes the probe (R5), and a repeat of a copy under a second id, seen and not stored, is
  not acknowledged (§4.2). This draft runs on the same toy; there is nothing else to carry.
- v0.10.6 (2026-11-19): `seacast-lite.md` names an open question in §1, whether the protocol fixes a
  coded group's compressed bytes ("Open: the compressed bytes"); this draft points to it from §1.1's
  `decode` row, and leaves where the descriptor travels open, as `seacast-lite.md` §1 does.
- In v0.10.7 (2026-11-20), the window's line in `seacast-lite.md` (§7.1, §7.2) works this way: a free
  slot goes to the first writer in line that can write, and a writer in line that writes control
  first wakes another that can write. This draft carries both into its window in bytes
  (§4.11), with its own `wake_front` over `W_BYTES`, and it wakes on a third path that it has, a
  control-only entry of the normal lane; `line_stall_known.py --doc seacast` shows the first.
- v0.10.8 (2026-11-21): `seacast-lite.md` is the same but for its version line, and the Lean twin's
  record and a first piece of a refinement come into `formal/`; there is nothing to carry.
- v0.10.9 (2026-11-21): in `seacast-lite.md`, the wake in the window's line moves to the moment a writer
  starts to wait for its transport (§7.1, §7.2). In this draft, `write_waits` wakes the first writer
  in line that can write if the waiting writer is in line and the window has room (§4.11). It
  replaces the wake before the write on the three control paths, and `wake_front` loses `past`;
  `write_wait_known.py --doc seacast` checks it on all three.
- v0.10.10 (2026-11-21): `seacast-lite.md` is the same but for its version line, and the proofs in
  `formal/veil/` take in four of its rules added after v0.8; there is nothing to carry.
- v0.10.11 (2026-11-21): `seacast-lite.md` is the same but for its version line, one row of its §8.1
  table, the window's line, which this draft names in §3's lifetimes (`leave_line`), and §5.1's
  citation of the draft's figures, now in `seacast-figures.md`. This draft is restructured: its
  decisions and its figures are in files of their own, and its bindings are named by their
  carriers.
- v0.10.12 (2026-11-22): in `seacast-lite.md`, a HAVE or an offered id of a group beyond the peer's
  limit of unknown groups (§8.2) is ignored before it leaves any state (`admitted` in `on_have` and
  `on_ihave`), and §7.1 says which of `write_wait_known.py`'s five cases keep the writer's place.
  This draft carries the first in `on_holding` and `on_offer` (§4.3), and bounds more of what a peer
  can make a node keep or serve: asks outside what it serves, a WANT's index and group, the
  relations on a link, the answers to one peer in a heartbeat and the routed requests it passes on.
- v0.11.0 (2026-11-22): `seacast-lite.md` is the same but for its version line and its names: its title
  and a new opening paragraph name it SEACAST on gossipsub, and §5.1 and §9 cite this document and
  the announcement post by their current names. This draft is named SEACAST; there is nothing to
  carry.
- v0.11.1 (2026-11-22): `seacast-lite.md` is the same but for its version line, so there is nothing to
  carry. In this draft, one setting of the node caps a block's second-phase asks in flight across
  the block's sampled types, and the block's held samples are tried while room is left even when
  the group of the ask whose wait ended has expired (§4.10). §3 declares `want_p`.
- v0.12.0 (2026-11-22): this release changes names only. `protocol.md` is now `seacast-lite.md`,
  and its protocol is SEACAST Lite, no longer SEACAST on gossipsub; this draft's files,
  `protocol-v2.md` and `protocol-v2-*.md`, are now `seacast.md` and `seacast-*.md`. No rule
  changed, so there is nothing to carry.
- v0.13.0-rc.1 (2026-11-25): `seacast-lite.md` is the same but for its version line, so there is
  nothing to carry. In this draft, §1.4 says how the floor per colour is kept, §3 lists
  `joined_peers()` and `related(q)`, `propose_colour` and `least_used_colour` are gone,
  `on_header_validated` visits the block's groups in `cell_groups`' order, and §4.10's text says
  that a sample's hunt also ends when it arrives. No rule changed.
