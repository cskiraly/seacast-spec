# SEACAST's next version (draft): its figures

This file holds the figures behind [`protocol-v2.md`](protocol-v2.md), the draft of SEACAST's next
version, and behind its decision record, [`protocol-v2-decisions.md`](protocol-v2-decisions.md).
Both documents state the rules and their reasons in words, and they point here for the numbers, as
`(protocol-v2-figures.md, §4.1)`, or as `(protocol-v2-figures.md, §4.6, "The probe")` for a part of
an entry. The entries are grouped by the section that cites them, under that section's number and
heading, in the document's order. The decision record's own figures close the file, each under its
decision's label, such as `[D12]`.

**Where the figures come from.** The file holds the toy's figures and, marked as such, a few of the
research harness's. Every figure comes from the toy (`toy/`, `toy/run.py --doc v2`) unless its entry
says in its first line that a figure comes from the research harness of the posts. A figure comes
from a network of 60 nodes unless its entry gives another size. The toy's graph scripts
(`toy/sampler_graph.py`, `toy/sampler_match.py`) build the toy's networks and run no events, so
neither the transport nor the event rules apply to their figures. `toy/graft_check.py` explores
every interleaving of two nodes up to a bound, so its counts have no network and no seed.

**A cell, the median and the tail.** A cell is one run of one configuration of the toy: its network
and size, its setting, its faults and its flags, at one seed. For each message, a payload or a
block, the toy prints the receivers' completion times, each from the publish instant. The median and
the tail are the 50th and the 99th percentile of those times, by nearest rank. A warm figure is the
median of a cell's figures over its messages after the first. Copies count what a node received, in
units of what its own interest needs: the compressed payload, or for a custodian its own custody's
chunks. They count data and control together unless an entry says otherwise.

**Seeds.** A figure from fewer than ten seeds, a single seed unless stated, is a toy check of a
mechanism, not a measurement. Ranges over ten or more seeds say so. Each entry names its seeds, and
says where a figure is a mean or a median over seeds. "The median of the seeds, and its range" is
the median over the seeds of a change, paired by seed, and the range of that change over the seeds.

**The transport.** On 2026-11-15 the toy took `protocol.md` §7.3's rule as its default: one entry at
a time per connection (`--send-buffer 1`). With `--uplink rr`, which has no send buffer, writes
still go at once. Figures and comparisons measured before that change ran with the earlier
transport, which takes every write at once (`--send-buffer 0`), unless they name `--send-buffer 1`.

**Each entry gives its own conditions:** the network and its size, the degree, the messages, the
seeds, the operating point (the setting, the source's uplink, the faults), the transport, the
baseline, and the rules it ran on. The rules are the draft's on the date of the run. An entry gives
that date and the commit on this repository's main line that first wrote the figure into the text; a
commit off the main line is named by its date. It names the later changes of the rules that its
figures predate, where it can point to them; the versions of `protocol.md` carried since are listed
in `protocol-v2-decisions.md` ("The versions of `protocol.md` carried"). A condition that the run's
record does not give is called unknown.

## §1.3 Links, joins and relations

**Conditions.** The toy's graphs, built without events by `toy/sampler_graph.py` (`a` for the
floor's links, `c` for routed requests): 500 nodes, a fifth of them samplers of eight cells each,
every other node a custodian of 8 of 128 columns, no supernodes, and degree 70 or 16. A custodian
also keeps the toy's floor of 6 custodian links for each column it custodies. Seeds 7 to 16: each
figure is over all ten graphs, as the share of samplers or as the median over samplers. The method
was first run on 2026-10-23, and the scripts came into the toy on 2026-10-26. The figures were first
written into the text on the main line in spec `0d968d8` (2026-11-14). No event runs, so the
transport and the later event rules do not apply. The floors follow the rules of `[D12]` as decided:
covers counted by distinct links, a peer of high custody counting for at most one family
(`COVER_HIGH` 1), except where an item says "counted in full".

- Without the coverage floor, a sampler of eight cells holds a sample that no link serves with
  probability 17 % at 70 links and 96 % at 16 [16.6 % and 95.7 %].
- One cover by the fewest links (a greedy cover, high custody counted in full) adds a median of 2
  sampling-only links per sampler at 70 links and 13 at 16. `protocol-v2.md` §7 cites the 13.
- The diversity floor of two covers adds a median of 8 links per sampler on top of 70 and 29 on top
  of 16. The 500-node cells of §6.3's `SAMPLE_COVER` entry built the same floors: their floor links
  equal those of the graph built alone.
- With the toy's floor per column, a custodian keeps a median of about 57 links at a degree of 16.

## §4.1 Joining, and keeping the relations

### The model checks (`toy/graft_check.py`)

**Conditions.** §4.1's functions as written, on two nodes, for one relation over an ordered
connection with queues of one entry, explored over every interleaving up to a bound on each end's
upkeep steps: three unless an item says two. The abstract comparison (`--model`) runs four steps per
end. A count is of the states reached within the bound. A state "at rest" has nothing queued, owed
or on the wire. The text checked is the draft of 2026-11-10, with the answered GRAFT, the yes again
and the symmetric relation; the figures were first written into the text on the main line in spec
`0d968d8` (2026-11-14). The four modes printed the same counts again on the draft of 2026-11-14, and
the one-way mode on that of 2026-11-16; no later run is recorded. The controls are the earlier texts
kept in `toy/controls/`. The control of the answered GRAFT is the text of 2026-11-03, that of the
owed JOIN the text of 2026-11-04, and that of the yes again the text of 2026-11-08.

- **The answered GRAFT** (one-way, three steps): 2 367 518 states, 846 of them at rest, every one
  agreeing. Before the yes again, the text of 2026-11-08 reached 1 484 804 states, 846 at rest.
- **Its control** (`toy/controls/graft-unanswered.md`, two steps): the ends disagree in 324 of 724
  states at rest [of 292 612 states].
- **The abstract comparison** (`--model`, four steps per end): counted at the GRAFT, 32 of 81 states
  at rest disagree without a backoff, and none of 121 with a backoff longer than the round trip;
  answered, none of 49.
- **The yes again** (`--diverged`, three steps): 1 175 922 states, and 4 647 412 with `--both` [270
  at rest once an upkeep has acted, in each]. Its control (`toy/controls/held-graft-unanswered.md`,
  two steps) leaves a GRAFT for a held relation unanswered in 18 of 117 states at rest [of 67 677
  states].
- **The symmetric relation** (`--both`, three steps): 846 states at rest of 2 755 607. The text
  without the one-way step fails in 108 states at rest, at three steps.
- **The owed JOIN's control** (`toy/controls/join-lost.md`, two steps): in 40 of 508 states at rest
  a JOIN was sent and the link did not form [of 261 167 states].

### The prune at `F_HI`

**Conditions.** The payload in the tier 4 setting, 60 nodes, degree 30, the all-home network
(`home`), six messages, seed 7, under `--upkeep on --churn 20`: 20 links replaced per message gap,
120 over the run. The transport then took every write at once (`--send-buffer 0`). Run on 2026-11-09
on the draft with the five gaps' rules; on 2026-11-10 the revised text printed the same figures.
First written into the text on the main line in spec `0d968d8` (2026-11-14). The run predates the
close's lifetimes of 2026-11-16 (§3, `protocol.md` §8.1) and the transport of 2026-11-15; it was not
run again.

- With a prune only above `F_HI`, no node was ever pruned, and nodes ended at 12 relations at most
  (`F_HI` is 12 for the payload, §6.1). The relations averaged 8.5 per node [8.53].
- With the prune at `F_HI`, 24 PRUNEs left no node above 11, and the average was 7.9 [7.87].

### The floor's links (`keep_floor`)

**Conditions.** 500 nodes, degree 70, the custody setting with a fifth of the nodes sampling (two
covers, routed requests on), the 1 Gbps proposer (`--net bld`), two blocks a run (`--msgs 2`), under
`--upkeep on`. 1 % and 5 % of the links were replaced per message gap (`--churn 175` and `--churn
875`), with the floor (`--keep-floor on`) and without it. The baseline for the share below `F_LO` is
the same cells with upkeep and no churn. Seeds 7 to 16: each figure is its range over the ten seeds,
paired by seed where it is a difference. Run on 2026-11-08 and 2026-11-09 on the toy of 2026-11-08,
before the five gaps' text of 2026-11-10. The toy's floor was the one `keep_floor` states: under
that text, the toy's known answer gave the same events. First written into the text on the main line
in spec `0d968d8` (2026-11-14). The transport took every write at once (`--send-buffer 0`). The runs
predate 2026-11-16, when the toy's close began to drop the closed peer's offers, tries, promises and
ties and to keep its park (§3's lifetimes, `protocol.md` §8.1), and the transport of 2026-11-15.
They were not run again.

- **The ends of a closed link:** without the floor, 8 to 11 % of the nodes at the ends of a closed
  link had not come back by the run's end to their count of (family, colour) below `F_LO` before the
  close, at every seed; with it, 0.1 to 1.2 %.
- **Churn's excess:** the floor removed 84 to 91 % of churn's excess in the share of (node, family,
  colour) below `F_LO`, the share averaged over the heartbeats from the first block on [84.0 to 90.5
  % at 1 %, 85.2 to 86.9 % at 5 %].
- **Its cost per node and message gap**, paired by seed: 0.14 to 0.19 JOINs and 0.30 to 0.44 GRAFTs
  more at 1 %, and 0.69 to 0.88 JOINs and 1.53 to 1.92 GRAFTs more at 5 %.
- **Delivery:** every node completed, and the warm block's 99th percentile moved within the toy's
  noise: with the floor minus without, a median of −2 ms at 1 % (−26 to +28 ms) and of +1 ms at 5 %
  (−25 to +34 ms).

## §4.3 A holding or an offer arrives

**Conditions.** `toy/run.py --doc v2 --ihave-limits 4096,5000`, `protocol.md` §8.3's reference
values, at 60 nodes, degree 30, three messages, the default transport (`--send-buffer 1`). The
baseline is the same cell with no limit: each run gave that cell's digest. The cells:
- seed 7: the tier 4 setting's fifteen recorded cells, variant C (`c`), and custody, with and
  without a fifth of the nodes sampling. Run on 2026-11-18 on the draft carrying `protocol.md`
  v0.10.3.
- seeds 7 to 9: the rows setting. Run on 2026-11-18 on the same draft. The run's record does not
  name the withheld variant on its line; the text says the runs were with and without half the
  columns withheld.

Both were first written into the text on the main line in spec `0edbdc7` (2026-11-18). They predate
v0.10.7's and v0.10.9's window line (§4.11), which moved two of the recorded cells (§6.1's entry);
they were not run again.

- No ask was held back in any of these cells.
- Under custody, the busiest peer reached 244 offer-bearing frames and 58 asks in a heartbeat
  without samplers, and 248 and 49 with them (the text had "at most 248 frames and 58 asks", a pair
  from the two cells). Under variant C it reached 42 and 11.
- Under the rows setting, the busiest peer reached 1 254 frames and 178 asks [857 to 1 254 frames
  and 78 to 178 asks over the three seeds].

## §4.10 A sampler pulls

**Conditions.** The toy's graphs of §1.3's entry, built by `toy/sampler_graph.py c`: 500 nodes,
seeds 7 to 16, graph only, degree 70 or 16, each figure a share of all (sampler, column) pairs over
the ten graphs. "One step" goes to the link whose computed custody is nearest the column. "With the
floor" is the toy's floor of 6 custodian links per column; "without it" a node has exactly its 16
links. The method was first run on 2026-10-23. The shares at 70 and 16 links were first written into
the text on the main line in spec `fda38ff` (2026-11-19), the others in `0d968d8` (2026-11-14). No
event runs.

- A sampler's own links serve 98 % of (sampler, column) pairs at 70 links and 58 % at 16 [97.7 % and
  57.6 %]. A path of two hops exists for every other pair.
- One step left 1.8 % of all pairs unreached at 16 links where custodians keep their floor per
  column [1.75 %], and 19 % without that floor [19.41 %].
- Without the floor, the Kademlia-style rule reached 95.9 % of the pairs within two hops and the
  other 4.1 % in three.

## §6.1 v0.3 as a setting

### The distance to the recordings, by date

**Conditions.** The regression's cells, `toy/check.py`: `toy/run.py --nodes 60 --degree 30 --msgs 3
--seed 7` with each cell's flags, so one seed. A figure is a cell's warm median and warm 99th
percentile, or its warm copies. Each bullet of §6.1's Rationale compares this document's recording
(`toy/golden-v2.txt`, `check.py --doc v2`) with `protocol.md`'s (`toy/golden.txt`) as both stood
after the change the bullet names, on the rules of that date. `loss-thin` runs at a 20 Mbps uplink.
Before 2026-11-15 every cell took every write at once (`--send-buffer 0`); the bullet of 2026-11-15
ran with `--send-buffer 1`, except `rr-stripe`, whose uplink (`--uplink rr`) has no send buffer. The
run dates and the commits on the main line that first wrote each figure:

| bullet (the change) | run | first written on the main line |
|---|---|---|
| v0.3's window, and the window in bytes | 2026-10-07 | `08fbc3d` (v0.6, 2026-10-21) |
| v0.4's P4 | 2026-10-21 | `08fbc3d`; `silent`'s example without P4 in `fda38ff` (2026-11-19) |
| v0.5 | 2026-10-21 | `08fbc3d` |
| the group's key (the rule dated 2026-10-23 in the text) | 2026-10-25 | `a2ca0bc` (2026-10-25) |
| ties, and no second ask at once | 2026-10-26 | `e234d70` (same day); `without-a`'s in `fda38ff` |
| v0.9's rules | 2026-11-11 | `0d968d8` (2026-11-14); `cap-wait`'s example in `fda38ff` |
| the transport | 2026-11-15 | `2f7ede2` (2026-11-15) |

The examples first written on 2026-11-19 are the cells' recorded values of their bullet's date: for
example, `silent` at 678 and 576 ms is the two recordings just before P4 came in.

The bullets give the distances on their dates. Since 2026-11-15 both recordings have moved again.
`protocol.md` §7.1's and §7.2's window line (2026-11-20, `1dc2d93` and `903f12b`) moved
`protocol.md`'s `ihave-limits` cell (p50 512 to 511 ms, p99 592 to 594 ms, copies 2.05 to 2.06), its
`loss-thin` (p50 789 to 788 ms, p99 888 to 867 ms, copies 1.71 to 1.70) and its `late-block`. This
document's §4.11 (2026-11-20, `67cbfba`) moved its `loss-thin` (p50 807 to 814 ms, p99 922 to 894
ms, copies 1.64 to 1.65) and its `late-block`. The wake at the wait (2026-11-21, `5372ebb`) moved
the digests of `rr-stripe` and `push-deep` only. Read from both recordings at `9f300cf`
(2026-11-21), the eleven cells of the last bullet stand as they stood on 2026-11-15. `loss-thin` is
26 ms later at the median, 27 ms later at the tail and 0.05 copies lighter (p50 814 against 788 ms,
p99 894 against 867 ms, 1.65 against 1.70 copies). `late-block` is 6 ms later at the median and 11
ms later at the tail. `ihave-limits` is 1 ms sooner at the median and at the tail, with 0.01 copies
more (p50 510 against 511 ms, p99 593 against 594 ms, 2.07 against 2.06 copies).

- **v0.3's window and the window in bytes** (2026-10-07). With v0.3's window (slots of one payload
  chunk), eleven of the twelve cells reproduced v0.3's completion times and bytes exactly, and
  `rr-stripe` differed by 3 ms at the median. With the window in bytes, the cells moved by at most 7
  ms at the median, 15 ms at the tail and 0.04 copies either way: `announce` p99 576 → 587 ms,
  `without-a` 578 → 565 ms, `loss-thin` 984 → 999 ms, `push` copies 2.41 → 2.43.
- **v0.4's P4** (2026-10-21), against v0.4's recording: eleven cells within 3 ms at the median, 16
  ms at the tail and 0.03 copies (`announce` p99 568 → 584 ms, `rr-stripe` 521 → 505 ms).
  `loss-thin` was 8 ms later at the median and 0.10 copies lighter. Without P4, the medians had been
  up to 102 ms behind v0.4's (`silent` 678 against 576 ms).
- **v0.5** (2026-10-21), against v0.5's recording: eleven cells within 7 ms at the median, 15 ms at
  the tail and 0.03 copies (`rr-stripe` p50 417 → 410 ms, `dcb20` p99 358 → 343 ms, `cap-wait` 740 →
  754 ms). `loss-thin` was 1 ms later at the median and 0.12 copies lighter (1.81 copies).
- **The group's key** (2026-10-25): eleven cells within 6 ms at the median, 35 ms at the tail and
  0.03 copies (`without-a` p99 613 → 578 ms, `cap-wait` 815 → 797 ms). `loss-thin` was 10 ms later
  at the median and 0.11 copies lighter (1.81 copies).
- **Ties, and no second ask of a peer at once** (2026-10-26): eleven cells within 8 ms at the
  median, 30 ms at the tail and 0.03 copies (`silent` p50 641 → 649 ms, `without-a` p99 598 → 568
  ms). `loss-thin` was 8 ms later at the median and 0.12 copies lighter (1.81 copies).
- **v0.9's rules** (2026-11-11), against v0.9's own recording: eleven cells within 13 ms at the
  median, 18 ms at the tail and 0.06 copies (`cap-wait` 630 → 643 ms, `without-a` p99 551 → 533 ms).
  `loss-thin` was 6 ms later at the median and 0.14 copies lighter (1.80 copies).
- **The transport** (2026-11-15), against `protocol.md`'s recording: eleven cells within 8 ms at the
  median, 16 ms at the tail and 0.02 copies (`cap-wait` 544 → 552 ms, p99 710 → 726 ms). `loss-thin`
  was 18 ms later at the median and 0.07 copies lighter (1.64 copies).

### `ihave-limits` against `protocol.md`

**Conditions.** The regression's `ihave-limits` cell: as the other cells above, with stock
gossipsub's two limits (`--ihave-limits 10,5000`), one seed (7). Under v0.9's rules:
- with the toy's transport since 2026-11-15 (`--send-buffer 1`): run on 2026-11-15, first written on
  the main line in `2f7ede2` (2026-11-15). `protocol.md`'s side of it moved on 2026-11-20 (above).
- with the earlier transport (`--send-buffer 0`): run on 2026-11-14, first written on the main line
  in `0d968d8` (2026-11-14).

The figure before §4.3 carried the limits is the `push` cell's warm median in this document's
recording of 2026-10-27, with the earlier transport. First written on the main line in `0d968d8`.

- With `--send-buffer 1`, this document held back 26 667 asks to the next heartbeat, where
  `protocol.md` held back 26 799. It was 2 ms sooner at the median and 1 ms later at the tail, with
  0.02 copies more: p50 510 against 512 ms, p99 593 against 592 ms, 2.07 against 2.05 copies.
- With `--send-buffer 0`, it held back 24 248 asks against 24 538, 3 ms sooner at the median and 7
  ms sooner at the tail: p50 541 against 544 ms, p99 621 against 628 ms, 2.41 against 2.40 copies.
- Before §4.3 carried the limits, it held back none and ran as without them (p50 470 ms).

## §6.2 The five designs as settings

**Conditions.** 60 nodes, degree 30, the 1 Gbps proposer, 6 row reconstructors where there are rows,
the custody and rows settings of `toy/README.md` ("The next version"). Seeds 7 to 19, thirteen runs
of each cell, unless an item names seed 7, the recorded seed. Run on 2026-10-07 (the repair floor)
and 2026-10-08 (three supernodes, `--supernodes`, on datacenter links); first written into the text
on the main line in spec `08fbc3d` (v0.6, 2026-10-21), and recorded in the toy's README there. The
transport took every write at once (`--send-buffer 0`). The runs predate v0.4's P4 (2026-10-21): the
toy's README says that its tables from before that date were recorded without P4. They also predate
v0.5 (2026-10-21), the group's key (2026-10-25), ties (2026-10-26), v0.9's source at the
acknowledgement (2026-11-11), the transport (2026-11-15) and the probe's rules (2026-11-15 and
2026-11-16). They were not run again.

- **Custody, half the columns withheld:** with three supernodes, every custodian completes on all
  thirteen seeds. Without them, 58 of 59 custodians stay short (seed 7).
- **Rows, 16 subnets, half withheld:** at seed 7, every custodian completes through the rows. With
  the repair floor, every run completes on all thirteen seeds from 7 to 19. Without it
  (`--repair-floor 0`), five of the thirteen runs left custodians short, each for a missing link.
- **Rows, 32 subnets, half withheld:** with three supernodes, the second phase completes the cell on
  all thirteen seeds. Without them the cell stays short at seed 7, since three of its subnets have
  no member.
- **The time:** with three supernodes, the second phase halves the withheld cells' time [the
  16-subnet rows cell: a median over the seeds of 1 200 ms, against 2 442 ms without them].

## §6.3 Parameters, limits and constants

### `R_NODE`, `R` for cells

**Conditions.** As §6.2's entry: 60 nodes, degree 30, the 1 Gbps proposer, 6 row reconstructors
where there are rows, three supernodes on datacenter links, seeds 7 to 19. A time is the median over
the seeds of a cell's median or 99th percentile; copies are of own custody, the median over the
seeds. "Cells at `R`" means the fast class off (`--without 17`, card 17), which leaves the cells
without supernodes as they were, event for event at seeds 7 to 9. Run on 2026-10-08, first written
on the main line in `08fbc3d`, recorded in the toy's README there; the same later rules as §6.2's
entry, and the same transport. A column has about ten custodians at this scale.

- With supernodes in the fast class: 0.96 copies more per node in the honest custody cell (3.10
  against 2.14), and 0.72 copies and half a second of tail more in the honest row cell (2.88 against
  2.16 copies; a p99 of 1 674 against 1 143 ms).
- With cells at `R`: the honest row cell is back at 1.13 s at the tail and 2.22 copies (1.14 s and
  2.16 without supernodes). The withheld cells are as fast or faster at the tail (custody 1.25 s, 16
  subnets 1.64 s, 32 subnets 1.69 s, against 1.25, 1.76 and 1.83 s) at 0.6 to 1.2 copies fewer. The
  honest custody cell gives up 31 ms at the median and 73 ms at the tail for 1.17 copies fewer.

### `PROMISE`

**Conditions.** The figures come from the toy but for the last, which comes from the research
harness of the posts (below). The honest row cell: 60 nodes, degree 30, the 1 Gbps proposer, 6 row
reconstructors, the default 32 row subnets and no supernodes, seeds 7 to 9, at v0.3's promise of 400
ms and at 0.8 s (`--promise 0.8`). The times of the late answers, and the refusals, are seed 7's.
Run on 2026-10-08, first written on the main line in `08fbc3d`, recorded in the toy's README there;
the same later rules as §6.2's entry, and the same transport.

The payload's promise was evaluated with §4.13 on 2026-10-19, and first written on the main line in
`08fbc3d`. Its figure comes from the research harness, not the toy: every node at 10 Mbps up and 20
Mbps down, 30 % withholders, the median of three seeds, each paired with the tier 4 cell of the same
seed under v0.3's fixed ask window and promise. The promise was scaled with the ask window, to 2 s
in place of 400 ms. The text's statement that silent peers were not hurt in the toy gives no figure.

- In the honest row cell the 400 ms promise broke 3 321 to 4 204 times per run and parked 804 to
  1 039 honest (peer, group) pairs.
- At seed 7, 3 522 of the 3 580 broken promises were column asks that the asked node answered later:
  0.45 s after the ask at the median and 0.8 s at the 99th percentile [448 and 824 ms]. None was a
  refusal: the asked nodes left no ask unanswered.
- At 0.8 s the promise broke 1 to 3 times (seeds 7 to 9). The medians moved by at most 3 ms, the
  tails by at most 20 ms, and the copies not at all (the toy's README; the text had "completion
  times and bytes unchanged").
- For the payload, the promise stretched with the ask window lengthened the tail by 18.5 % with 30 %
  withholders at 10 Mbps (the research harness, the median of three paired seeds).

### `SAMPLE_RETRY` and `SAMPLE_COVER`: the 500-node cells

**Conditions.** `--setting custody --samplers 20 --net bld --msgs 2`: 500 nodes, a fifth of them
samplers of eight cells, the 1 Gbps proposer, two blocks, degree 70 or 16, honest and with 30 %
withholding custodians (`--fault wh30`). Routed requests are on (`ROUTE_HOPS` 1), with a floor of
one cover or of two. Seeds 7 to 16, 2 000 sampler-blocks per row. A time is the median over the 20
blocks. Run on 2026-10-26 on the draft of 2026-10-23, and recorded in the toy's README ("A sampler's
reach"). First written into the text on the main line in spec `0d968d8` (2026-11-14). The transport
took every write at once (`--send-buffer 0`). `SAMPLE_RETRY` was 2 s, `SAMPLE_RETRY2` 0.5 s and
`SAMPLE_OUTSTANDING` 4. The runs predate ties (2026-10-26), the IHAVE limits (2026-10-27), v0.9's
source at the acknowledgement (2026-11-11) and the transport (2026-11-15); they were not run again.

- **`SAMPLE_RETRY`:** the custodians' 99th percentile was 0.67 to 0.70 s, honest [666 to 678 ms at
  70 links, 694 to 702 ms at 16]. Under 30 % withholders the samplers' median was 2.5 to 2.9 s.
- **Two covers** left no sampler short, honest or under 30 % withholders, at 70 links and at 16.
- **One cover** did as well at 70. At 16 it left 7 sampler-blocks short under withholders, and it
  raised the honest samples' 99th percentile to 2.2 s, against 0.7 s with two [2 197 and 679 ms].

### `SAMPLE_COVER`, `COVER_HIGH`, `ROUTE_FLOOR` and the sampling-only links: the graphs

**Conditions.** The toy's graphs of §1.3's entry: 500 nodes, seeds 7 to 16, graph only.
- The floor of the fewest links: `toy/sampler_graph.py a`, a greedy cover, high custody counted in
  full. Medians over samplers, with the range in brackets.
- The diversity floor: `toy/sampler_match.py`, covers counted by distinct links, 400 draws per
  sampler. A share is that of eight-sample draws that find eight distinct serving links, the mean
  over the seeds. It is given over three populations: 8-column custodians, 5 % supernodes, and the
  row setting's network.
- `ROUTE_FLOOR`: `toy/sampler_graph.py c` at 16 links without the per-column floor. Links added are
  counted at both ends.

The method was first run on 2026-10-23 and came into the toy on 2026-10-26. The figures were first
written into the text on the main line in spec `0d968d8` (2026-11-14), but the `COVER_HIGH` figure
for sixteen samples (`fda38ff`, 2026-11-19, from the same run). The sampling-only links per other
node are the two-cover links per sampler spread over the other nodes (a fifth of 500 nodes sample),
first written in `0d968d8`.

- **The floor of the fewest links:** one cover adds a median of 2 links on top of 70 (0 to 5) and 13
  on top of 16 (9 to 18), and 23 from none. Two covers add 8, 29 and 42. One link to a node
  custodying every column covers all. With 10 % of the nodes custodying 64 columns, one cover adds 0
  on top of 70 and 3 on top of 16.
- **The diversity floor:** two covers give 99.77 % or more at 16 links (29 to 31 links added,
  median) and 99.92 % or more at 70 (8 to 9). Three covers give 99.99 % or more at both (47 to 49,
  and 17 to 20), and they are the floor that holds for sixteen samples. One cover gives only 64 to
  86 % at 16 and 97 % at 70.
- **`COVER_HIGH`:** 0 is within 0.4 points of 1 with eight samples, and within 1.7 with sixteen, at
  a link more. Counted in full, one supernode link with no other rule finds eight distinct servers
  for 4.7 % of draws at 16 links.
- **`ROUTE_FLOOR`:** the hypercube rule brings every (sampler, column) pair within two hops for 17
  added links per custodian. The Kademlia-style rule brings 95.9 % within two and 4.1 % in three,
  for 6.4.
- **Sampling-only links accepted:** two covers add 8 links per sampler at 70 links and 29 at 16,
  about 2 and 7 per other node.

### `ROUTE_HOPS` and `FORWARD_LIMIT`: the 60-node cells

**Conditions.** `--setting custody --samplers 20 --net bld`: 60 nodes, 12 samplers of eight cells,
the 1 Gbps proposer, seed 7, routed requests on. The transport took every write at once
(`--send-buffer 0`).
- `ROUTE_HOPS`: `--route-hops 2`, degree 30, in the known answers of 2026-10-23 on that day's draft,
  recorded in the toy's README ("A sampler's reach"). The record does not name the cell's floor or
  its blocks. First written on the main line in `0d968d8`.
- `FORWARD_LIMIT`: `--forward-limit 1` against no limit, a floor of two covers, three blocks,
  honest, with 30 % withholders and with half the columns withheld (`--withhold 64`). The degree is
  not printed in the outputs. Run on 2026-11-03 on the draft of that day; first written on the main
  line in `0d968d8`.

Both predate v0.9's source at the acknowledgement (2026-11-11) and the transport (2026-11-15).

- **`ROUTE_HOPS`:** one request took a second step, and its sample came at 468 ms, where with one
  step it had waited for the second phase.
- **`FORWARD_LIMIT`:** a limit of 1 changed no event, honest or under 30 % withholders. With half
  the columns withheld it refused 10 of 1 048 forwards, and the same samples arrived.

### `ASK_UPLINK`

**Conditions.** 500 nodes, seeds 7 to 9, the ask window scaled by the uplink (§4.13) against v0.3's
fixed 200 ms window, each seed paired with the same cell with the rule off. The toy ran in the
research harness's setting: no rebuilt chunks pushed (`--rebuilt none`) and striping on (`--stripe
on`). The networks: all-home at 12.5 Mbps uplinks; 30 % silent peers; 30 % withholders; 10 % of
chunks lost; and the mixed-bandwidth network at 6 Mbps for its home nodes, with a home builder or a
datacenter builder. Run on 2026-10-19, on the draft before v0.4's P4 (2026-10-21); first written on
the main line in `08fbc3d`. The transport took every write at once (`--send-buffer 0`). The runs
predate every rule carried after 2026-10-19, and they were not run again.

- Fewer copies in every cell: 0.16 to 0.33, the median over the seeds per cell.
- The tail shorter: all-home at 12.5 Mbps by 0.7 to 3.0 %; with 30 % silent peers by 2.4 to 4.4 %;
  mixed-bandwidth at 6 Mbps by 3.1 to 3.2 % with a home builder and by 3.0 to 3.6 % with a
  datacenter builder; within ±1.6 % with 30 % withholders.
- With 10 % of chunks lost, the tail is up to 3.2 % longer.

### `MERGE_HOLDINGS`

**Conditions.** The custody setting at 60 nodes, a 50 Mbps proposer of 128 column groups, seeds 7 to
16, warm medians. A figure is the median over the seeds of the change, paired by seed: P4 against no
P4, and P4 with merging (`--merge-holdings on`) against P4. The baselines differ by transport:
writes that complete at once (`--send-buffer 0`), and one write per connection at a time
(`--send-buffer 1`), each with its own P4 baseline. Run on 2026-10-21, the day v0.4's P4 came in,
and recorded in the toy's README ("The next version", P4's and `--merge-holdings`'s tables). First
written on the main line in `08fbc3d`. The runs predate v0.5 (2026-10-21), ties (2026-10-26), v0.9's
source at the acknowledgement (2026-11-11) and the transport of 2026-11-15.

- With writes that complete at once, merging takes back 10 ms of P4's 116 ms at the custody block's
  median. With one write per connection at a time, it takes back 16 ms of 80 ms. The copies are
  unchanged.

### The IHAVE limits

**Conditions.** The regression's `ihave-limits` cell (§6.1's entry), `toy/run.py --doc v2
--ihave-limits M,5000`, 60 nodes, degree 30, three payloads, seed 7, against the same cell with no
limit. Under v0.9's rules, with the earlier transport (`--send-buffer 0`). Run on 2026-11-14; first
written on the main line in spec `0d968d8`. The cell was first swept on 2026-10-27 under the rules
of then, with other values; the text gives the run of 2026-11-14. It predates the transport of
2026-11-15 and the window line of 2026-11-20 and 2026-11-21 (§6.1's entry), and it was not run
again. At `protocol.md` §8.3's reference values, the cells and their conditions are §4.3's entry.

- Against no limit (p50 461 ms, 2.49 copies): 10 frames cost 80 ms at the median and save 0.08
  copies, 20 cost 31 ms and save 0.11, 40 cost 3 ms and save 0.01, and 100 change neither. The 5000
  asks never bound.

## §7 Bindings

`protocol-v2.md` §7 cites §1.3's entry: at 16 links, one cover by the fewest links adds a median of
13 links.

## The decision record's figures

These entries hold the figures of `protocol-v2-decisions.md` that no section's entry above holds,
each under its decision's label.

### [D12] A sampler's reach

The record of `[D12]` cites §1.3's, §4.10's and §6.3's entries. Its own figures follow.

**Conditions.** `--setting custody --samplers 20 --net bld`: 60 nodes, degree 30, 12 samplers of
eight cells, the 1 Gbps proposer, seed 7 unless an item says otherwise, on the draft of 2026-10-23.
"Before one sample per peer" is that draft before that day's changes, which made one sample per
peer; "after" is the draft with them. The transport took every write at once (`--send-buffer 0`).
First written into the text on the main line in spec `0d968d8` (2026-11-14). The runs predate ties
(2026-10-26), v0.9's source at the acknowledgement (2026-11-11) and the transport (2026-11-15). They
were not run again.

- **Why diversity** (honest, three blocks, the floor of one cover and routed requests, before one
  sample per peer): the proposer was asked for 28 of 288 samples, up to 5 of one sampler's 8 in a
  block, and no other peer for more than 2. After, the proposer was asked for none, and no peer for
  more than one of a sampler's samples in a block.
- **The hunt's cost** (half the columns withheld, `--withhold 64`, two blocks), after: 1.3 to 1.7
  asks per sample without routed requests [1.32 with no floor, 1.65 with two covers], 3.0 with them
  [2.96], and 4.2 to 5.2 with the floor of one or two covers as well [5.20 with two]. 380 to 704
  requests were passed on over two blocks. Before: 11 to 12 asks per sample, and 1 813 to 2 042
  requests passed on.
- **The cost of one sample per peer** (30 % withholders, the floor of one cover with routed
  requests, seed 8; the record does not give the blocks): every sample arrived, at a median of 2.7
  to 3.7 s and a 99th percentile up to 7.7 s, against 2.2 to 2.7 s and 4.9 s before.
- **Small networks** (the 60-node custody cell with 12 samplers, at seed 7): seven of the 128
  columns (14, 30, 31, 39, 67, 70 and 108) had no custodian but the proposer. Without samplers, the
  custody cell at seed 7 has four such columns (14, 31, 39 and 108), in the toy check of 2026-11-10
  (§4.7's entry, "A source's links in a family it does not custody").
- **The route:** where custodians keep their floor per column, one step on random links left 0.05 %
  of (sampler, column) pairs unreached at 70 links. The graphs and their conditions are §4.10's
  entry, which gives the other shares.
- **Rows as a second axis:** `toy/sampler_graph.py e`, the graphs of §1.3's entry at 70 links.
  Counting half rows takes the samplers left with a sample no link serves from 17 % to 7.5 % with 32
  row subnets and to 13.5 % with 128. Counting whole rows (FullDAS's two-dimensional code) takes
  them to 3.2 % and 11.0 %. At 16 links, rows barely help [95.7 % to 90.1 % at best].
