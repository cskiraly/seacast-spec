# SEACAST's next version: its figures

This file holds the figures behind [`protocol-v2.md`](protocol-v2.md), SEACAST's next version, and
behind its decision record, [`protocol-v2-decisions.md`](protocol-v2-decisions.md).
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
block, the toy prints the receivers' completion times, each from the publish instant. The median
(p50) and the tail (p99) are the 50th and the 99th percentile of those times, by nearest rank. A
warm figure is the median of a cell's figures over its messages after the first. Copies count what
a node received, in units of what its own interest needs: the compressed payload, or for a custodian
its own custody's chunks. They count data and control together unless an entry says otherwise.

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
baseline, and the rules it ran on. The rules are those of `protocol-v2.md` on the date of the run;
below, the draft of a date means `protocol-v2.md` as it was on that date. An entry gives that date
and the commit on this repository's main line that first wrote the figure into the text; a commit
off the main line is named by its date. It names the later changes of the rules that its figures
predate, where it can point to them; the versions of `protocol.md` carried since are listed in
`protocol-v2-decisions.md` ("The versions of `protocol.md` carried"). A condition that the run's
record does not give is called unknown.

## §1.3 Links, joins and relations

**Conditions.** The figures come from the toy's graphs, which `toy/sampler_graph.py` builds without
events (`a` for the floor's links, `c` for routed requests). Each graph has 500 nodes: a fifth of
them are samplers of eight cells each, every other node is a custodian of 8 of 128 columns, no node
is a supernode, and the degree is 70 or 16. A custodian also keeps the toy's floor of 6 custodian
links for each column it custodies. The graphs use seeds 7 to 16, and each figure is over all ten
graphs, as the share of samplers or as the median over samplers. The method was first run on
2026-10-23, and the scripts came into the toy on 2026-10-26. The figures were first written into the
text on the main line in spec `0d968d8` (2026-11-14). The script runs no events, so the transport
and the later event rules do not apply. The floors follow the rules of `[D12]` as decided: covers
are counted by distinct links, and a peer of high custody counts for at most one family
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

**Conditions.** The checks run §4.1's functions as written, on two nodes, for one relation over an
ordered connection with queues of one entry. They explore every interleaving up to a bound on each
end's upkeep steps: three unless an item says two. The abstract comparison (`--model`) runs four
steps per end. A count covers the states reached within the bound. A state "at rest" has nothing
queued, owed or on the wire. The text checked is the draft of 2026-11-10, with the answered GRAFT,
the yes again and the symmetric relation (`protocol-v2.md` §4.1); the figures were first written
into the text on the main line in spec `0d968d8` (2026-11-14). The four modes printed the same
counts again on the draft of 2026-11-14, and the one-way mode did so on the draft of 2026-11-16; no
later run is recorded. The controls are the earlier texts kept in `toy/controls/`. The control of
the answered GRAFT is the text of 2026-11-03, the control of the owed JOIN is the text of
2026-11-04, and the control of the yes again is the text of 2026-11-08.

- **The answered GRAFT** (one-way, three steps) reaches 2 367 518 states, 846 of them at rest, and
  the ends agree in every one of those. Before the yes again, the text of 2026-11-08 reached
  1 484 804 states, 846 at rest.
- **Its control** (`toy/controls/graft-unanswered.md`, two steps): the ends disagree in 324 of 724
  states at rest [of 292 612 states].
- **The abstract comparison** (`--model`, four steps per end): with the relation counted at the
  GRAFT, the ends disagree in 32 of 81 states at rest without a backoff, and in none of 121 with a
  backoff longer than the round trip. With the GRAFT answered, they disagree in none of 49.
- **The yes again** (`--diverged`, three steps) reaches 1 175 922 states, and 4 647 412 with
  `--both` [270 at rest once an upkeep has acted, in each]. Its control
  (`toy/controls/held-graft-unanswered.md`, two steps) leaves a GRAFT for a held relation unanswered
  in 18 of 117 states at rest [of 67 677 states].
- **The symmetric relation** (`--both`, three steps) reaches 846 states at rest out of 2 755 607.
  The text without the one-way step fails in 108 states at rest, at three steps.
- **The owed JOIN's control** (`toy/controls/join-lost.md`, two steps): in 40 of 508 states at rest
  a JOIN was sent and the link did not form [of 261 167 states].

### The prune at `F_HI`

**Conditions.** The cell carries the payload in the tier 4 setting (`protocol-v2.md` §6.2), on 60
nodes at degree 30 in the all-home network (`home`), with six messages and seed 7, under
`--upkeep on --churn 20`: it replaced 20 links per message gap, 120 over the run. The transport
then took every write at once (`--send-buffer 0`). The cell ran on 2026-11-09 on the draft with the
five gaps' rules; on 2026-11-10 the revised text printed the same figures. The figures were first
written into the text on the main line in spec `0d968d8` (2026-11-14). The run predates the close's
lifetimes of 2026-11-16 (§3, `protocol.md` §8.1) and the transport of 2026-11-15; it was not run
again.

- With a prune only above `F_HI` (`protocol-v2.md` §1.4), no node was ever pruned, and nodes ended
  at 12 relations at most (`F_HI` is 12 for the payload, §6.1). The relations averaged 8.5 per node
  [8.53].
- With the prune at `F_HI`, 24 PRUNEs left no node above 11, and the average was 7.9 [7.87].

### The floor's links (`keep_floor`)

**Conditions.** The cells run 500 nodes at degree 70 in the custody setting, with a fifth of the
nodes sampling (two covers, routed requests on), the 1 Gbps proposer (`--net bld`) and two blocks a
run (`--msgs 2`), under `--upkeep on`. They replaced 1 % and 5 % of the links per message gap
(`--churn 175` and `--churn 875`), with the floor (`--keep-floor on`) and without it. The baseline
for the share below `F_LO` (`protocol-v2.md` §1.4) is the same cells with upkeep and no churn. The
cells ran at seeds 7 to 16. The figures give ranges across those ten seeds; where a figure gives a
difference, the comparison pairs runs by seed. The cells ran on 2026-11-08 and 2026-11-09 on the
toy of 2026-11-08, before the five gaps' text of 2026-11-10. The toy's floor was the one
`keep_floor` states: under that text, the toy's known answer gave the same events. The figures were
first written into the text on the main line in spec `0d968d8` (2026-11-14). The transport took
every write at once (`--send-buffer 0`). The runs predate 2026-11-16, when the toy's close began to
drop the closed peer's offers, tries, promises and ties and to keep its park (§3's lifetimes,
`protocol.md` §8.1), and the transport of 2026-11-15. They were not run again.

- **The ends of a closed link:** without the floor, 8 to 11 % of the nodes at the ends of a closed
  link had not come back by the run's end to their count of (family, colour) below `F_LO` before the
  close, at every seed; with it, 0.1 to 1.2 % had not.
- **Churn's excess:** the floor removed 84 to 91 % of churn's excess in the share of (node, family,
  colour) below `F_LO`, the share averaged over the heartbeats from the first block on [84.0 to
  90.5 % at 1 %, 85.2 to 86.9 % at 5 %].
- **Its cost per node and message gap**, paired by seed, was 0.14 to 0.19 JOINs and 0.30 to 0.44
  GRAFTs more at 1 %, and 0.69 to 0.88 JOINs and 1.53 to 1.92 GRAFTs more at 5 %.
- **Delivery:** every node completed, and the warm block's 99th percentile moved within the toy's
  noise: the change with the floor minus without had a median of −2 ms at 1 % (−26 to +28 ms) and
  of +1 ms at 5 % (−25 to +34 ms).

## §4.3 A holding or an offer arrives

**Conditions.** The cells ran `toy/run.py --doc v2 --ihave-limits 4096,5000`, whose limits are the
reference values of `protocol.md` §8.3, at 60 nodes and degree 30, with three messages and the
default transport (`--send-buffer 1`). The baseline is the same cell with no limit: each run gave
the same digest as that cell, so the limits changed no event. The cells are these:
- At seed 7, they are the tier 4 setting's fifteen recorded cells, variant C (`c`,
  `protocol-v2.md` §6.2), and custody, with and without a fifth of the nodes sampling. They ran on
  2026-11-18 on the draft carrying `protocol.md` v0.10.3.
- At seeds 7 to 9, they are the rows setting. They ran on 2026-11-18 on the same draft. The run's
  record does not name the withheld variant on its line; the text says the runs were with and
  without half the columns withheld.

Both were first written into the text on the main line in spec `0edbdc7` (2026-11-18). They predate
v0.10.7's and v0.10.9's window line (§4.11), which moved two of the recorded cells (§6.1's entry);
they were not run again.

- No ask was held back in any of these cells.
- Under custody, the busiest peer reached 244 offer-bearing frames and 58 asks in a heartbeat
  without samplers, and 248 and 49 with them (the text had "at most 248 frames and 58 asks", a pair
  from the two cells). Under variant C it reached 42 and 11.
- Under the rows setting, the busiest peer reached 1 254 frames and 178 asks [857 to 1 254 frames
  and 78 to 178 asks over the three seeds].

## §4.6 Completion, the claims, decoding and repair

**Conditions.** Every figure below comes from the toy (`toy/run.py --doc v2`) in the rows setting
(`--setting rows`: RowDAS's row on top of PeerDAS custody, 128 columns, rows of 128 cells with K =
64) or under custody alone (`--setting custody`), as each sub-entry says. "Half the columns
withheld" is `--withhold 64`: the proposer keeps the last 64 columns, which only reconstruction
fills. A cell's median and tail are the 50th and 99th percentiles of its custodians' completion
times. "Seeds 7 to 19" are thirteen seeds; a figure over them is the median over the seeds unless
the sub-entry says otherwise. A figure from fewer than ten seeds is a toy check of a mechanism, not
a measurement. The toy took every write at once (`--send-buffer 0`) in every run behind this entry.
For the figures first written before 2026-11-15, that was the toy's only transport then; for the
probe's runs of 2026-11-16 and 2026-11-18 and the alarm's runs of 2026-11-18, their command lines
set it (named in each sub-entry). The toy's default since 2026-11-15 is `--send-buffer 1`. Unless a
figure says otherwise, the runs made before 2026-11-15 had the probe ask the lowest index the
member lacked, without the mark and the kept WANT (`protocol-v2.md` §4.6), and let any peer's copy
pass the claimant. The 60-node rows runs of 2026-10-07 to 2026-10-10 had degree 30, a 1 Gbps
proposer and 6 row reconstructors (`--reconstructors 10`, percent), as the README states (README
949, 1032); the probe's runs of November name their own command line. "README" below is
`toy/README.md` at `a6ca1fc`, with its line numbers. Each sub-entry gives the date on which its
figures were first written, and in brackets the commit of the main line that first carried them.

**Rules changed since the October runs** (the runs of the sub-entries dated 2026-10-07 to
2026-10-10) are these. Those runs predate every version of `protocol.md` after v0.3 that the draft
carried (`protocol-v2-decisions.md`, "The versions of `protocol.md` carried"), among them v0.5's
fixes to §4.6's `decode_group` and the repair (2026-10-21), v0.8's rebuilt chunk, which names the
block of its sources (2026-10-26), v0.9's source holding at the acknowledgement (2026-11-10) and
v0.10's rules (carried 2026-11-15 and 2026-11-16). They also predate §4.6's own later rules: the
probe marked and its cell drawn at random (2026-11-15); its wait from the write, a claimant still
decoding and a claimant that leaves (2026-11-16); `probe_of_claim` and `note_push` under every group
a chunk fills (2026-11-17). Whether any of these moves a figure is not traced.

### The deferral

**Conditions.** The figures were first written on 2026-10-07 (03:59) [`08fbc3d`, 2026-10-21]. The
record is the toy's README of that commit and README 979–981. The runs are the 60-node rows cells
without liars (honest with 32 subnets; half the columns withheld with 16 and with 32 subnets), at
degree 30, with a 1 Gbps proposer and 6 reconstructors, at one seed (7). They ran under
`protocol.md`'s slot window (a window counted in 12 KB slots), before the window in bytes (§4.11,
2026-10-07 04:40), and with `protocol.md`'s `PROMISE` of 400 ms as the probe's promise, the rule
this figure changed. The record gives one figure, not its statistic: whether it is one probe or
typical is not stated.
- A reconstructor's answer to a probe left 450 ms after the probe was decided, behind its burst of
  rebuilt cells. The deferred duties re-armed against honest claimants were 1 in the honest cell and
  8 in the 16-subnet withheld cell (the toy's README of 2026-10-07, 03:59).

### The probe

**Conditions common to its runs.** The runs use the toy's rows setting at 60 nodes and degree 30,
with three blocks (`--msgs 3`), seeds 7, 8 and 9, `--send-buffer 0` and the toy's default net
(home), in five cells. C0 is honest (`--seed S`, 32 row subnets). In C1, a fifth of the nodes lie
(`--fault claim20`). C2 is the same with 16 subnets and half the columns withheld
(`--row-subnets 16 --withhold 64 --fault claim20`). C3 is C2 with a fifth hoarding
(`--fault hoard20`) in place of the liars. C4 is C2 with 5 % supernodes (`--supernodes 5`, three
of 60). The runs before 2026-11-16 called `run.py` itself, with the variant's text loaded through
`TOY_DOC2`; those of 2026-11-16 and 2026-11-18 went through a counting wrapper of the toy's run,
which prints the probe's counts. `DEFER_WINDOW` was 1 s in every run (the toy's default). A toy liar
answers no ask, so it passes a probe only on a copy it pushed. The toy's queues refuse nothing, and
these cells close no connection. C2 at seed 9 never completes: a published column's custodians are
all liars (README 1134–1139).

**On the rules of 2026-11-18.** These figures were first written on 2026-11-18 (08:11) [`0edbdc7`,
2026-11-18]. The runs used
`--nodes 60 --degree 30 --msgs 3 --doc v2 --digest --setting rows --send-buffer 0`, through the
counting wrapper, on the toy of 2026-11-18, from 07:30 CET that day. The baseline is the runs with
the rules of 2026-11-16 (below). These figures were not run with the rules changed since: v0.10.5's
`accepted` (2026-11-19: a later copy of a copy that level 1 rejected no longer passes the probe) and
v0.10.7's and v0.10.9's wake in the window's line (2026-11-20 and 2026-11-21, §4.11); v0.10.3 and
v0.10.4 were carried after these runs too (`protocol-v2-decisions.md`, "The versions of
`protocol.md` carried").
- None of the 1 281 verdicts on honest or hoarding claimants failed, and no such claimant was left
  without a verdict.
- Every probe got a verdict and was written; none was still unwritten when its window ran out, and
  no probe reached a claimant still decoding.
- Liars passed their probe 1, 0 and 65 times in C1, C2 and C4, over the three seeds (of C4's liar
  verdicts, 65 passed and 704 failed).
- The mark cost 5 duplicate cells in 2 417 probes decided: these were exempt answers written over a
  holding the asker had sent.
- At the median a probe was written when it was decided (the text's figure; the record gives the
  longest only). The longest wait from decision to write was 163 ms (162.6 ms, C3 at seed 9),
  against a `DEFER_WINDOW` of 1 s.
- C2 at seed 9 delivers no block to 58 of its 60 nodes, as it did before, and decides no probe; the
  figures include it.
- Against the runs with the rules of 2026-11-16, every run changed its events (all 15 rows digests
  moved; custody's did not). The warm copies stayed within 0.03 in 11 of 15 runs. They moved in four
  runs, by −0.04 at seed 9 and +0.03 at seed 7 in C3, and by +0.04 at seed 7 and +0.09 at seed 9 in
  C4. These changes were not traced.

**With the rules of 2026-11-16.** These figures were first written on 2026-11-16 (11:43) [`62a8179`,
2026-11-16]. The runs used the same command line, on the draft of 2026-11-16 with the probe's wait
from its write, from 01:25 GMT that day. As the text names them, the changes since are four fixes (a
probe settled while queued, a kept probe answered once, the duty's own time, a settled probe's
promise; the commits that made them are not traced here) and the later changes to the draft, among
them those named for the runs of 2026-11-18.
- None of the 1 298 verdicts on honest or hoarding claimants failed, and no such claimant was left
  without a verdict.
- Liars passed 3, 1 and 61 times in C1, C2 and C4.
- The mark cost 9 duplicate cells in 2 428 probes decided.
- One probe, in C4 at seed 8, passed before it was written (307 decided, 306 written, 307 verdicts),
  on the claimant's own copy. The record does not count whether that claimant was honest or a liar;
  its counts suggest a liar's push but do not show it.
- C2 at seed 9 decided 3 probes.
- The wait from decision to write was 0 ms at the median in every run; the longest was 101 ms
  (101.2 ms, C3), against 62.2 ms in C2 and 60.7 ms in C4.
- These runs' C4 at seeds 8 and 9 carry v0.10's order of the announcers beyond the list
  (`protocol.md` §6.1, spec `512efe6`), found by a bisection.

**Before 2026-11-16.** These figures were first written in `0d968d8` (2026-11-14). The runs are
those of the toy's experiment build of 2026-11-14 with each variant's patch and the probe text's own
runs on its draft of 2026-11-15. All of them came before v0.10's order of the announcers
(`512efe6`), which moves C4 at seed 8 and, bracketed but not run at that change, at seed 9.
- A variant run on 2026-11-14 probed the lowest index without the mark and the kept WANT, and
  judged each claimant by its own copy alone. In it, 3 of 1 289 verdicts on honest or hoarding
  claimants failed, and all three were on honest claimants in C3.
- With the mark and the kept WANT (the probe text's own runs of 2026-11-15), none of 1 299 failed,
  and there were 9 duplicate cells in 2 434 probes.
- When any peer's copy passed the claimant (a variant run on 2026-11-14), liars passed at least 57,
  115 and 558 times in C1, C2 and C4. These are lower bounds: each counts the passes of the variant
  judged by the claimant's own copy, plus that variant's failures with the cell held.
- Against the runs where any peer's copy passed the claimant (with the lowest index), the warm
  copies stayed within 0.03 in 12 of 15 runs. C3 at seed 8 was 0.03 to 0.04 lighter (2.15425 against
  2.19, rounded), and C4 was 0.083 lighter at seed 7 and 0.077 at seed 9 (the runs with the random
  index of 2026-11-15, whose digests the text's runs share), almost all of it data (data 2.408
  against 2.490 and 2.438 against 2.514); this was not traced further.

**The random index against the lowest.** These figures were first written in `0d968d8` (the counts)
and on 2026-11-16 (the trace's figures) [`62a8179`]. The runs, on 2026-11-15 from 11:39 to 11:59,
are the random index against the lowest, both with the mark, and a trace of the runs with the random
index.
- Liars passed 3, 1 and 61 times with the random index, against 0, 0 and 49 with the lowest (C1, C2,
  C4).
- Six traced runs with the random index (C1 at seeds 7 and 9, C2 at seed 7, C4 at seeds 7 to 9) hold
  all 65 such passes. In 45 the liar had already sent the member the lowest lacked cell by then; in
  20 it held that cell unsent; in every one, it had done one or the other.

### The verdict

**Conditions.** The figures come from rows and custody cells at 60 nodes (degree 30, a 1 Gbps
proposer, 6 row reconstructors), at seeds 7 to 19, as each figure names them, with three supernodes
on datacenter links where the figure says so. The record is the toy's README of 2026-10-09 (01:54),
and README 1114–1132 (and 1148–1191 for the member check). The rules are the probe as before
2026-11-15, the window in bytes, and the repair floor at 1. The figures on the wording ran with the
member check on (README 1127–1130).
- *The earlier wording* (a member told by a non-empty suppression scope), first written on
  2026-10-09 (16:01) [`08fbc3d`]: with 32 subnets, members decoded 20 rows per run against draft 1's
  16, about 4 more, the median over seeds 7 to 19; with 16 subnets, they decoded 9, as under draft
  1, so none more. With 32 subnets a subnet has about two members at 60 nodes. The record does not
  name the cells.
- *This wording*, first written the same day [`08fbc3d`]: the row cells with supernodes (honest, and
  half the columns withheld with 16 and with 32 subnets) and the withheld custody cell with a fifth
  of the nodes hoarding run as under draft 1, event for event, on all 13 seeds; so do 48 of the 52
  seed-cells of the row cells with supernodes and a fifth or half hoarding (16 and 32 subnets, 13
  seeds each).
- *The first version* (a verified claim only from a peer in the node's view), first written the same
  day [`08fbc3d`; recorded in the toy's README of 2026-10-09, 01:54]: members decoded 31 rows per
  run against draft 1's 9 with 16 subnets, and 38 against 16 with 32, the medians over seeds 7 to
  19. That is two to four times as many, for no change in time or bytes. It was traced in three
  runs. The record does not name the cells.
- *Supernodes and hoarders*, first written the same day [`08fbc3d`]: in three traced runs no
  supernode ended its duty on a verified claim (README 1175–1177).
- *Without supernodes*, first written the same day [`08fbc3d`]: a fifth of the nodes hoarding (16
  subnets, half withheld) left custodians short in every run over seeds 7 to 19, under draft 1 and
  under the wording before the member check (371 to 810 pairs; README 1165). The record traces
  seed 7: its four short rows were all of one subnet, rebuilt only by a hoarding row reconstructor
  to which 15 duties had deferred.

### The member check

**Conditions.** The figures were first written on 2026-10-09 (12:42) [`08fbc3d`, 2026-10-21] unless
a figure says otherwise. The record is README 1148–1191, first recorded on 2026-10-09. The runs have
60 nodes, degree 30, a 1 Gbps proposer, 6 row reconstructors and 16 row subnets, with half the
columns withheld, at seeds 7 to 19, and without supernodes unless the figure says so. They set
`--member-check on` against `off`, under the faults `--fault hoard20`, `hoard50` and `claim20`. The
rules are the probe as before 2026-11-15 (the liars' figure says so itself), the window in bytes,
the repair floor at 1, and R5's wording before its fix of 2026-10-09 (16:01), which changed no cell
without supernodes (README 1173–1174).
- With a fifth of the nodes hoarding, custodians were left short on every seed without the check
  (371 to 810 pairs), and on 3 of 13 with it (seeds 14, 17 and 18, one subnet each without an honest
  member).
- With half hoarding, 13 of 13 seeds were short without the check, and 10 of 13 with it (the seeds
  with one to four subnets without an honest member).
- In the liars' cell without supernodes, the check fired 1 to 3 times per run on 5 of 13 seeds, each
  time on a liar's claim that passed because another peer brought the probed cell (measured when
  that copy also passed the claimant). The firings were traced at seeds 8, 11 and 12 (README
  1185–1186). The check moved the short pairs on three seeds by one or two (4 to 5, 0 to 1, 3 to 5),
  and in the three traces every short pair, with and without the check, was a liar's own row.
- A member whose 8 custody columns of 128 are all among the 64 published holds its cells whatever
  the claimant does. Such members make up 0.3 % of the members. This is arithmetic, not a run:
  C(64, 8) / C(128, 8) ≈ 0.31 %.
- Against a claimant that pushes each member exactly its custody cells (`--fault hoardm20`, without
  supernodes), custodians were short on all 13 seeds with the member check alone. This figure was
  first written on 2026-10-10 [`08fbc3d`]; its record is README 1204–1210.
- Without a fault, in the five cells run (rows honest with and without supernodes; withheld with 16
  subnets with and without; withheld with 32 with supernodes), the check never fired and every event
  is the same.
- A rescued block (a fifth hoarding, without supernodes) completes at 3.25 / 3.44 s (p50 / p99;
  3 254 / 3 438 ms in the README) against 2.44 / 2.71 s without hoarders, at 2.33 copies against
  2.36.
- In ten traced runs with hoarders or liars, all 162 firings were on a misbehaving claimant's claim.
  This figure is in the text only (2026-10-09); the README does not give it.

### Sampling the repair

**Conditions.** The 60-node figures were first written on 2026-10-10 (02:32), those on re-ask the
same day (10:47) and those at 500 nodes later that day (13:46), all [`08fbc3d`, 2026-10-21]. The
record is README 1193–1259. The 60-node runs have degree 30, a 1 Gbps proposer, 6 row reconstructors
and 16 row subnets, with half the columns withheld, at seeds 7 to 19, with the member check on
throughout and `--sample-wait 0.5` (s). They run the forms `--repair-sample 3:1,6:2`, `4:0,8:1` and
`6:0,12:1`, without supernodes or with three, under the faults `hoard20`, `hoardm20` and `claim20`.
The 500-node runs have degree 70 and 32 row subnets, with half withheld, at seeds 7, 8 and 9,
without supernodes or with 25 (5 %); they set `4:0,8:1` with re-ask against the member check alone,
and took 47 to 105 minutes a run (README 1243). Blocks per run are not stated for the 60-node runs;
the per-run and per-node-and-block counts below imply two. The rules are the probe as before
2026-11-15, the window in bytes, and the repair floor at 1.
- Against `hoardm20` without supernodes, the member check alone left 13 seeds short,
  `(3, 1), (6, 2)` left 5, and `(4, 0), (8, 1)` or `(6, 0), (12, 1)` left 3: seeds 14, 17 and 18,
  on which a subnet has no honest member.
- In the run traced at seed 7 (`4:0,8:1`), all 14 failed samples were on hoarders' claims, and all
  112 verdicts on honest claimants passed.
- `(3, 1), (6, 2)` passed partial repairs: at seed 7 the one honest member of a subnet got 4 of 6
  cells, which the hoarding members' own pushes had brought into some columns.
- A rescued block completes at 4.2 s at the median (4 184 to 4 231 ms over the three forms) against
  2.4 s without the fault; the member check alone rescues a claimant that repairs nothing
  (`hoard20`) at 3.25 s.
- Without a fault, no sample failed in any form, with or without supernodes; the copies moved by at
  most 0.02. At `(4, 0), (8, 1)` without supernodes the sample asked 532 cells per run (median), 4.4
  per node and block averaged over all nodes (532 / (60 × 2)).
- Among liars, a sample cell asked of a liar is lost: at `(4, 0), (8, 1)`, 18 of 41 verdicts on
  honest claimants failed at seed 7, and 46 of 48 at seed 8 with supernodes. Members rebuilt 21 to
  26 more rows per run in the strict forms.
- With re-ask (`--repair-reask on`), among liars, the strict forms' failed samples per run (median)
  fell from 15 and 17 (`4:0,8:1`, without and with supernodes) and from 20 and 27 (`6:0,12:1`) to 0,
  and to at most 22 in one run (the text's figure; the README does not give it). Without
  supernodes, `4:0,8:1` gave 74 member decodes per run against 80 with the member check alone; with
  supernodes, it gave 46 against 45.
- With re-ask against `hoardm20`, `4:0,8:1` and `6:0,12:1` leave seeds 14, 17 and 18 short; the
  rescued blocks complete at 4 714 / 4 876 ms and 4 688 / 4 915 ms (p50 / p99), about 0.5 s later
  (one more `SAMPLE_WAIT` of 0.5 s); `(3, 1), (6, 2)` is short on 4 seeds.
- At 500 nodes without a fault, the member check never fired and no sample failed. The medians were
  2 309 to 2 360 ms without supernodes and 1 170 to 1 179 ms with them, over both arms (README
  1249–1250; the text had 2 312 to 2 360 ms, which leaves out the member check alone at seed 9). The
  sample asked 2 687 to 2 788 cells per run without supernodes, 2.7 per node and block over two
  blocks, and 172 to 258 with them.
- At 500 nodes against `hoardm20`, nobody was short with the member check alone (2 354 to 2 388 ms
  at the median). With the sample, seeds 8 and 9 are similar (2 410 and 2 389 ms); at seed 7 nine
  samples failed, all on one subnet's row of the second block, which its members rebuilt at 19.5 s.
  In the trace, the block's last custody cells came at 19.65 s at the median, against 17.37 s in the
  run with the member check alone: 2.3 s later.

### Rebuilt cells marked seen

**Conditions.** The figures were first written on 2026-11-10 [`0d968d8`]. The option was kept on
2026-11-01. The figures come from four records, on four trees, all at 500 nodes and degree 70 in the
rows setting, with 32 row subnets, half the columns withheld, no supernodes, two blocks and
`--send-buffer 0`:
1. The first record holds a network model of the hoarders' accidental repair (no run), and the runs
   of the option on the toy of 2026-10-26 (2026-10-26 and 27; seeds 11, 12 and 16 under `hoardm20`,
   7 to 9 honest; three seeds, a toy check).
2. The second holds the stage runs of 2026-10-22 to 2026-10-24, on the toy of 2026-10-23 for seeds 8
   to 16 and of `b3b64d7` for seed 7's rerun; they ran with `--net bld`, with the member check alone
   and with the sample `4:0,8:1` with re-ask.
3. The third holds the alarm's runs at ten seeds, on the toy of 2026-11-01 (2026-11-01 17:00 to
   2026-11-02 06:17 CET), with the alarm off.
4. The fourth holds the same campaign's off arm (the sample and rebuilt-seen off), for the honest
   cost.
- *Accidental repair:* at seed 11, hoarders that mark their rebuilt cells seen leave 34 columns
  unrepaired instead of 5 in the model, and the run matched it: 456 custodians were short in each
  block, against 168 (record 1).
- *The member check alone with the option* left more custodians short over seeds 11, 12 and 16: 5 of
  6 blocks were short either way, with 2 311 custodians short against 1 735; only seed 11 moved
  (record 1).
- *Ten seeds* (seeds 7 to 16, 20 blocks), against `hoardm20`: the member check alone left 5 of 20
  blocks short and the sample 1 (record 2, the stage runs); the sample with rebuilt cells marked
  seen left none (record 3, on a later tree).
- *The honest cost* of the two together against neither was +0.01 copies a block at the median,
  about +0.5 % of the off arm's 2.28. The comparison used 20 block pairs per network, with the
  builder at 1 Gbps (`bld`) and at home, and the alarm off. Control moved by +0.004 and was higher
  in all 40 pairs. At the median, the paired difference of the tail (p99) was 0 ms in `bld` (10
  pairs higher and 10 lower) and +0.5 ms at home (record 4).

### Biasing the repair sample

The decision record's "Dropped: biasing the repair sample" points here.

**Conditions.** The figures were first written on 2026-11-10 [`0d968d8`]. They come from two
records. The first is a network model of 2026-10-26, not a run: it takes each seed's network as the
toy builds it at 500 nodes and the columns left unrepaired as the model of the hoarders' accidental
repair gives them, and it simulates the two steps of `repair_verdict` at `4:0,8:1`, 50 000 times a
member. The second holds runs on the toy of 2026-10-27 at 500 nodes and degree 70, with 32 row
subnets, half withheld, no supernodes, `--repair-bias 0.5` and the sample `4:0,8:1` with re-ask.
They ran `hoardm20` at seeds 11, 12 and 16 with rebuilt cells marked seen on and off, and honest
cells at seeds 7, 8 and 9; with three seeds, this is a toy check.
- *What the node knows:* a member is linked to 4 to 6 of its subnet's 8 to 11 other members that are
  not claimants it heard; each custodies about 4 of the 64 withheld columns. So 38 to 50 of the
  about 60 cells a member lacks look uncovered.
- *The odds,* at seed 11 (subnet 5), whose hoarders repair the members' cells and leave 5 columns
  unrepaired: the chance that every honest member of the subnet passes, so that the row stays short,
  is 0.52 with the uniform sample, 0.38 with the bias over linked members, and 0.06 with every
  member known.
- *Hoarders that mark their rebuilt cells seen* (34 columns unrepaired at seed 11; 33 at seed 12, 43
  at seed 16): the chance is below 0.001 with every form of the sample.
- *The runs beside that option:* all six `hoardm20` cells with rebuilt cells marked seen complete,
  biased or not, and the honest cells have no "not repaired" verdict.

### A custodian's alarm

**Conditions.** Every alarm run sets `--alarm-wait 3.5` (s), `--alarm-next 1.5` (s),
`--alarm-max 3` and `--alarm-jitter` 0.2 s. The cells run rows at 500 nodes and degree 70, with 32
row subnets, half the columns withheld, two blocks and `--send-buffer 0`. In `hoardcol20`, a fifth
of the nodes repair every withheld column of their row except one per subnet; the toy ran this fault
with rebuilt cells marked seen. In the toy, the member's ask of its claimant starts its promise at
its write since 2026-11-17 (at the decision before), and a member that rebuilds the row answers the
alarm from `decode_group` since 2026-11-17. The ten-seed runs probed the lowest index a member
lacked; the runs of 2026-11-18 ran after the probed index became random (2026-11-15), and their
record does not count probes at a hidden index.

**The bound on its wait.** This figure was first written on 2026-11-10 [`0d968d8`]. Its record is
the stage runs of 2026-10-22 to 2026-10-24 (as for rebuilt cells marked seen, record 2).
- Without a fault, no custodian completed later than 2 944 ms over seeds 7 to 16 and both blocks:
  the latest was in the honest cell with 5 % supernodes and the sample (2 910 ms with the member
  check alone; 2 634 and 2 621 ms without supernodes). The clock runs from the block's publish;
  `known_at` is later, so the margin to the alarm is larger.

**On the rules of 2026-11-18.** These figures were first written on 2026-11-18 (11:53) [`0edbdc7`,
2026-11-18]. Every cell ran with `--send-buffer 0`, on the toy of 2026-11-18, from 09:24 CET that
day. The figures come from the six `hoardcol20` cells (the sample `4:0,8:1` with re-ask, alarm off
and at 3.5 s, seeds 11, 12 and 16); the last item names the honest and `claim20` cells of the same
runs. The rules changed since are those named for the probe's runs of 2026-11-18.
- Without the alarm, 2 of 6 blocks were short, with 108 custodians short (seed 12's first block, 53;
  seed 16's second, 55). Before, 3 of 6 blocks and 165 custodians were short: seed 16's first block
  now completes. Each block's prediction still equals its count.
- With the alarm, none was short, for 61 alarms and 10 rebuilds, as before (seed 16: 31 cells
  alarmed, against 32 before).
- In the honest and `claim20` cells (seeds 7 to 9, the sample with re-ask, rebuilt cells not marked
  seen, alarm off and on), nothing was short, and there was no alarm.

**At ten seeds.** These figures were first written on 2026-11-10 [`0d968d8`]. The runs are 130 cells
at seeds 7 to 16, on the toy of 2026-11-01, from 2026-11-01 17:00 to 2026-11-02 06:17 CET, all with
the sample `4:0,8:1`, re-ask and rebuilt cells marked seen (but for the honest cost's off arm), and
with the alarm off or at 3.5 s. These ran before the member's changes of 2026-11-17.
- In `hoardcol20` without supernodes, without the alarm, 3 of 20 blocks were short, with 165
  custodians short (seed 12's first block and both of seed 16's); with it, none was short, for 61
  alarms and 10 rebuilds, all at those two seeds (seed 12: 41 alarms and 5 rebuilds; seed 16: 20 and
  5).
- In `hoardcol20` with 5 % supernodes (25), alarm off, none was short.
- In the honest cells, with the builder at 1 Gbps (`bld`) or at home, there was no alarm; the latest
  custodians completed at 2.60 s and 2.77 s (the text rounds them to 2.6 and 2.8 s).
- In `claim20`, there were 2 alarms (seed 13, the second block) and no rebuild.

### The repair floor

**Conditions.** The figures were first written on 2026-10-07 (14:21) [`08fbc3d`, 2026-10-21]. The
record is README 1001–1020, first recorded the same day. The runs are the withheld row cell at 60
nodes and degree 30, with a 1 Gbps proposer, 6 row reconstructors, 16 row subnets and half the
columns withheld, at seeds 7 to 19, with `--repair-floor 0` against 1. They ran with the window in
bytes, with no member check (decided 2026-10-09) and no supernodes (2026-10-08) yet, and with the
probe as before 2026-11-15.
- Without the floor, 5 of 13 runs left custodians short, each by a missing link. In four (seeds 10,
  12, 16 and 18) a withheld column with two custodians missed one or two cells: the only member that
  rebuilt the row was linked to neither. In the fifth (seed 15) a subnet had two members, each of
  which gathered 63 of the 64 cells of its rows: neither was linked to the only custodian of
  published column 24.
- With `REPAIR_FLOOR = 1` all thirteen runs completed. The floor adds 1 to 30 links per run (2 to 8
  in the honest cell). On the eight seeds that complete either way, it moves the median by −54 to
  +34 ms, the tail by −65 to +129 ms and the copies by at most 0.07, within the seeds' spread.
- *A rebuilt chunk completes the groups it fills:* with the floor, the run at seed 7 found a node
  that held every cell of a custody column and never completed it, before `decode_group` checked the
  completion of the groups it filled. Without the floor the fix changes one event in one of the
  thirteen runs and no result.

### Supernodes

**Conditions.** The figures were first written on 2026-10-08 (01:14) [`08fbc3d`, 2026-10-21], and
those on the fast class's budget later that night (01:31). The record is README 1022–1074. The runs
have 60 nodes, degree 30, a 1 Gbps proposer, 6 row reconstructors where there are rows, and three
supernodes (5 %) on datacenter links (`--supernode-link dc`) unless the figure says home links, with
`--phase2` 1 s and `--phase2-jitter` 0.2 s, at seeds 7 to 19. The figures are the medians over the
seeds, and the tail's worst seed where named. The rules are the window in bytes, the repair floor at
1 and the probe as before 2026-11-15, before the member check (which changes no event without a
fault).
- The custody cell with half the columns withheld completes in no run without supernodes (58 of 59
  custodians short at seed 7); with them, every custodian completes on all thirteen seeds, at
  1 196 ms at the median and 1 251 ms at the tail (medians over the seeds; the text rounds them to
  1.20 and 1.25 s).
- The 32-subnet withheld row cell is short without supernodes (3 subnets without members at seed
  7); with them, its median and tail are 1 202 / 1 833 ms.
- In the 16-subnet withheld row cell, the median and tail are 2 442 / 2 709 ms without supernodes
  and 1 200 / 1 756 ms with them.
- Copies of a node's custody are 3.33 and 3.32 in the withheld row cells (16 and 32 subnets) against
  2.36 without supernodes, and 3.76 in the withheld custody cell. Most of it is duplicate pushes of
  the fast class (`R_FAST`, six peers).
- With the fast class off (`--without 17`, a budget of `R` for cells), the copies are 2.60 in the
  withheld custody cell, and 2.76 and 2.66 in the withheld row cells. Their tails are 1 247, 1 642
  and 1 685 ms, against 1 251, 1 756 and 1 833 ms with it: 4 ms shorter in the custody cell, and 0.1
  to 0.15 s in the row cells (the text gave 0.1 to 0.15 s for all three).
- *A row held on the columns,* without the wait (`known_across`), on home links: three supernodes
  rebuilt 186 rows of the honest row cell at seed 7, and its tail went from 1.09 to 1.49 s.
- With the wait, on datacenter links, supernodes rebuilt 0 rows in any of the 13 honest custody or
  row runs. In the withheld cells the supernodes made 131 to 167 of the 192 row decodes that three
  supernodes and two blocks of 32 rows allow (143 to 167 custody, 131 to 153 rows with 16 subnets,
  144 to 165 with 32).
- For a member the wait changed no event: every cell without supernodes kept its digest at seed 7.

### A rebuilder pushes as a source

**Conditions.** The figures were first written on 2026-10-08 (01:14) [`08fbc3d`, 2026-10-21]. The
record is README 1035–1074 (`--repair-budget on` against off). The runs are as for supernodes above,
with members on home links, at seeds 7 to 19 unless the figure says 7 to 9.
- Without supernodes, in the withheld 16-subnet row cell, there were 12 900 repair pushes against
  36 900 (the text's figures; the README gives no push counts); the copies were 2.19 against 2.36;
  the tail was 2 623 against 2 709 ms (the median over the seeds) and 2 677 against 2 816 ms at the
  worst seed.
- With three supernodes, whose budget is the fast class's, the copies were 3.18 against 3.33 with 16
  subnets, with the tail at 2 002 against 1 756 ms, and 3.15 against 3.32 with 32, with the tail at
  2 041 against 1 833 ms. So it saves 0.15 copies with 16 subnets and 0.17 with 32 (the text gave
  0.15 for both). In the withheld custody cell, the copies were 3.71 against 3.76, and the tail was
  1 304 against 1 251 ms (53 ms).
- With the fast class off (`--without 17`), the figures for seeds 7 to 9 were 2.37 copies and
  1 305 / 1 728 ms at the median and the tail. The record reads them as 0.41 copies saved for 0.1 s
  at the median and the tail.

### Whom rebuilt cells go to

**Conditions.** The figures were first written on 2026-10-09 (01:54) [`08fbc3d`, 2026-10-21]. The
record is README 1090–1112, "explored on 2026-10-08". The 60-node runs have three supernodes, at
seeds 7 to 19, and give the medians over the seeds; they set the arms `--repair-keepers offer`,
`--repair-keepers skip` and `--repair-push offer` against the push. The 500-node figure comes from
seed 7. The rules are those of the supernodes' runs.
- At 500 nodes (seed 7), 88 % of the rebuilt cells pushed in the withheld custody cell arrived as
  duplicates, the whole of that cell's extra cost over the honest one: 3.76 against 2.83 copies.
- Offering to the nodes that keep every row took 0.17 to 0.33 copies fewer in the withheld cells, at
  no cost in time (custody 3.43 against 3.76 copies; rows 3.16 and 3.17 against 3.34).
- Offering every rebuilt cell took 0.5 to 0.7 copies fewer (3.04, 2.80, 2.70) and added 60 to
  110 ms to the median completion (1 264 against 1 196 ms; 1 313 against 1 203; 1 304 against
  1 208).
- Leaving the keepers out gave copies as with offering to them (3.38, 3.16, 3.16), but a 2.3 s tail
  in the custody cell (2 309 ms against 1 251).

## §4.7 The source

§4.7's Rationale draws on five campaigns: the checks of the writer's order of 2026-10-07, the runs
of 2026-10-21 on P4 (`protocol-v2.md` §0) and merging, the single offer's recording of 2026-11-04,
the toy check of v0.9's source rules of 2026-11-10, and the `SOURCE_OFFERS` runs of 2026-11-18. Each
sub-entry gives its own conditions. A figure from fewer than ten seeds is a toy check of a
mechanism, not a measurement.

### v0.7's single offer

**Conditions.** The cells are the thirteen that `toy/check.py --doc v2` recorded on 2026-11-04
(60 nodes, degree 30, three payloads, seed 7). The cell `loss-thin` refuses a tenth of
the data chunks at admission (`--loss-data 10`) on 20 Mbps uplinks (`--up 20`). It ran at one seed.
It was re-recorded on 2026-11-04, when the draft carried v0.7's single offer; the baseline is the
cell's recording just before it (digest `bbee3759f47bd944`, after it `2839de460f2704e5`). The
figures were first written the same day [`0d968d8`, 2026-11-14]. Every write was taken at once
(`--send-buffer 0`, the toy's default until 2026-11-15). The rules are the draft's of 2026-11-04:
the source offered at publish, and its paced holding grew at each chunk's write. The rules changed
since are v0.9's offers and holding at the acknowledgement (2026-11-11, §4.7), and the line that
skips a writer mid-write (2026-11-20) and the wake at the wait (v0.10.9), both §4.11.
- Of the thirteen recorded cells, only `loss-thin` met the second offer. There the single offer
  sends 91 fewer offers of 82 938 over its three payloads. Its warm medians, of completion and of
  copies, are unchanged.

### When the source offers: offering at publish

**Conditions.** The runs took place on 2026-11-18, from 07:30 CET, on the toy of that day with a
toy-only switch, `--source-offers publish`, whose events are those of "the document before" of the
2026-11-10 entry below (the known answers' digests); `SOURCE_OFFERS = PUBLISH`, the same day, gives
the same digests. The figures were first written on the main line in `fda38ff` (2026-11-19). The
runs use the custody setting with a 1 Gbps proposer (`--net bld`), three blocks and seeds 7, 8 and
9, on two graphs, both run in the toy: the toy's own (60 nodes, degree 30) and the research
harness's 100-node graph (through `--topology`, with `--ihave-limits 4096,5000`). They use both
transports: every write at once (`--send-buffer 0`), and one write per connection at a time
(`--send-buffer 1`). Each figure is the range over the three seeds of the change at publish against
the acknowledgement, paired by seed. The copies on the 60-node graph are the toy's warm copies of
the block received per node, data and control; on the 100-node graph they are the research
harness's statistic, the copies of a node's own custody to completion, computed from the toy's
runs. The rules are the draft's of 2026-11-18: v0.9's source rules since 2026-11-11
and v0.10's since 2026-11-16. The rules changed since are the line skip (2026-11-20) and the wake at
the wait (v0.10.9), both §4.11; the record does not say whether they move these cells.
- A 1 Gbps proposer that offers at publish completes its block sooner at the median. On the 60-node
  graph it is 37 to 114 ms sooner with writes at once and 30 to 102 ms sooner with one write at a
  time; on the 100-node graph, 13 to 86 ms and 17 to 92 ms. Over both transports, that is 30 to
  114 ms and 13 to 92 ms.
- It answers more asks: 6.1 to 9.7 times as many with writes at once and 4.7 to 8.2 times with one
  write at a time on the 60-node graph, 9.5 to 12.2 and 6.8 to 8.9 times on the 100-node one: 4.7 to
  12 times in all.
- The copies rise by 0.06 to 0.13 and by 0.08 to 0.14 on the 60-node graph, and fall by 0.11 to 0.19
  and by 0.10 to 0.16 on the 100-node one: 0.06 to 0.14 added and 0.10 to 0.19 saved. The toy's own
  copies on the 100-node runs fall too (0.08 to 0.12).
- A 50 Mbps proposer is not in this campaign. Its figures for offering at publish, 24 ms later at 60
  nodes and 26 ms later at 500, restate two figures of 2026-11-10 (below). At 60 nodes the
  acknowledgement is compared with the document before, whose source offers at publish with its
  holding at the write; with the acknowledgement, the proposer's block completes 24 ms sooner, over
  seeds 7 to 16. At 500 nodes the acknowledgement is compared with offers per type, whose column
  offers are at publish but whose holding grows at the acknowledgement; with the acknowledgement,
  the proposer's block completes 26 ms sooner, over seeds 7 to 9.

### The acknowledgement against the document before, at 60 nodes

**Conditions.** The figures come from the toy check of v0.9's rules in this draft, run on
2026-11-10. Stage 1 ran at seed 7; seeds 8 and 9 followed, then the ten seeds 7 to 16, which ended
at 18:49 CET. The rules were taken into the draft on 2026-11-11, and the figures were first written
then [`0d968d8`, 2026-11-14]. The baseline is the draft of 2026-11-10 before them, "the document
before": the source offers at publish, and its holding grows at each chunk's write. The runs have 60
nodes, degree 30 and three messages, at seeds 7 to 16; each figure is the median of the seeds and
its range, at the median of completion unless it names the tail. The cells are tier 4's payload
cells (`push`, `--rebuilt none`, `sil30`, and the 1 Gbps builder `dcb20`), custody with a 50 Mbps
proposer and with a 1 Gbps one (`--net bld`), the rows, and the rows with a fifth of the nodes
lying about their row holdings (`--fault claim20`). Every write was taken at once
(`--send-buffer 0`). "With §4.11's rule" is `--send-buffer 1`, compared with
`--send-buffer 1` alone. The rules are the draft's of 2026-11-11. The rules changed since are the
probe of a claim (R5, 2026-11-15, §4.6), in the row cells; v0.10's rules (spec `62a8179`,
2026-11-16); `SOURCE_OFFERS` (2026-11-18), which keeps the acknowledgement as the default; and the
line skip (2026-11-20) and the wake at the wait (v0.10.9), both §4.11.
- The payload moves by −4 ms (`push`), −4 (`--rebuilt none`), −8 (`sil30`) and 0 (`dcb20`): it
  completes 0 to 8 ms sooner.
- A 50 Mbps proposer's custody block completes 24 ms sooner (−46 to +10), sooner on eight seeds.
- At the medians over the seeds, a column's source uploads 5 to 28 % less (the 50 Mbps custody cell
  1.46 copies of its block against 1.54, the rows' proposer 1.49 against 2.07, a 1 Gbps proposer
  1.96 against 2.74), and it is asked 88 to 99 % less (18 ids over three blocks against 1 611, 214
  against 6 241, 1 274 against 10 788). With §4.11's rule, against that rule alone, it uploads 5 to
  29 % less (4.6 % for the 50 Mbps custody cell, 1.44 copies against 1.51; 29.2 % for the rows) and
  is asked 87 to 96 % less. The record recomputed the 5 to 29 % when the patch was made.
- The cost is that the rows complete 178 ms later (+69 to +304), later on every seed; with no source
  offers at all, they complete 128 ms later (−10 to +235). The rows with liars complete 214 ms later
  (+39 to +429), and a 1 Gbps proposer's custody block 38 ms later (+24 to +114).
- Why the rows pay is seen at seed 7 alone, in messages 2 and 3, over 118 (node, message) pairs from
  the run's per-node lines. The nodes are grouped by the answers each pulled from the proposer in
  the document before. Those that pulled 6 to 20, 21 to 60 and more than 60 completed 412, 470 and
  471 ms later at the median. The 60 pairs that pulled none completed 56 ms later.

### At 500 nodes

**Conditions.** The figures come from the same campaign, stages 3 and 4, on 2026-11-10 (18:45 to
19:47 and 21:45 to 23:04 CET). The runs have 500 nodes, degree 70 and two messages a run. The
payload (tier 4), the rows and the 50 Mbps custody cell ran in the all-home network; the 1 Gbps
custody cell ran with a fifth of the nodes sampling. The comparison against the document before
uses seed 7, one run each, at the median of completion. The comparison against offers per type (the
payload's offers at the acknowledgement, a column's at publish, the holding at the acknowledgement
for every type) uses seeds 7, 8 and 9, paired by seed, and gives the median of the seeds and its
range. Every write was taken at once unless a figure names §4.11's rule. The rules and the changes
since are those of the 60-node entry.
- Against the document before, at seed 7, the payload moves by −4 ms, the rows by −8 ms, a 50 Mbps
  proposer's custody block by −48 ms, and a 1 Gbps proposer's by +5 ms.
- Against offers per type, the rows move by +7 ms (−15 to +17), later on two seeds of three; with
  §4.11's rule, they move by +28 ms (+18 to +54), later on all three. A 1 Gbps proposer's block
  moves by +9 ms (+6 to +15). A 50 Mbps proposer's block moves by −26 ms (−38 to −18), and by −41 ms
  (−62 to −30) at the tail. A column's source uploads 8 to 33 % less (the 50 Mbps custody cell 8 to
  9 %, the rows 14 to 23 %, the 1 Gbps custody cell 28 to 33 %) and is asked 57 to 98 % less.
- The figures on the relation peers, at seed 7, come from stage 4's per-node lines. Under offers per
  type, 12 of the 499 nodes pull more than 20 answers from the rows' proposer in the warm block (17
  in the cold one); at 60 nodes, in the document before, 26 of 59 did. With the offers at the
  acknowledgement these 12 complete 18 ms later at the median (−140 to +292). The two of them that
  completed first, at 1.79 and 2.05 s (the network's median was 2.20 s), are 292 and 253 ms later.
  The 449 nodes that pull nothing from the proposer move by 5 ms.

### Offers per type

**Conditions.** The figures come from the same campaign. At 60 nodes, offers at the acknowledgement
for every type are compared with offers per type's stand-ins: the holding moved alone, and for the
1 Gbps proposer the offers keyed on the uplink, whose events are those of offers per type, over
seeds 7 to 16. At 500 nodes they are compared with offers per type itself, over seeds 7 to 9, as
above.
- With offers at the acknowledgement for every type, at 60 nodes, the rows complete 175 ms later
  (+58 to +324), and 300 ms later (+144 to +414) with §4.11's rule. A 1 Gbps proposer's block
  completes 44 ms later (+28 to +121) at 60 nodes, and 9 ms later (+6 to +15) at 500. These are what
  offers per type kept.
- What offers per type gave up, at 500 nodes, are the figures of the entry above: a column's source
  saves 8 to 33 % of its upload, and a 50 Mbps proposer's block is 26 ms sooner, for the rows' 7 ms
  (28 with §4.11's rule).

### A source's links in a family it does not custody

**Conditions.** The withheld block at 500 nodes is §4.11's run of 2026-10-07 (§4.11's entry, "The
window's unit (X3), and what it changes"): it runs the row setting at 500 nodes and degree 70, with
half the columns withheld, 32 subnets, 50 reconstructors and a 1 Gbps proposer, at one seed, with
every write at once, under the window in bytes and v0.3's order of the queue. Its rules and the
changes since are given there.
- Every custodian completed through the rows, at 2 368 ms at the median and 2 505 ms at the tail
  (the toy's README of 2026-10-07, 04:40).
- The figure on the columns that no node but the source custodies was first written on 2026-11-13
  as "seven of 128 in the toy's 60-node cells" [`0d968d8`]. At seed 7, the 60-node custody cell with
  12 samplers has seven such columns (14, 30, 31, 39, 67, 70 and 108), in the known answers of
  2026-10-23 (the `[D12]` entry, "Small networks"). The same cell without samplers has four (14, 31,
  39 and 108), in the toy check of 2026-11-10, where those columns' groups are never acknowledged.

### P4: the cost of the later holding

**Conditions.** The figures come from the payload cells of the campaign of 2026-11-10 (the 60-node
entry above), at seeds 7 to 16. The counts are the chunks of a message that come back to its
source, per message, with every write at once, and with §4.11's rule as `--send-buffer 1`.
- In the three all-home payload cells (`push`, `--rebuilt none` and `sil30`), with writes at once,
  1⅚ to 6⅙ of a payload's chunks come back a message at the median of the seeds, and at most 59 a
  message on average at one seed: seed 9's `push` cell, with 65, 61 and 51 over its three messages.
- In those cells with §4.11's rule, 0 to 2⅓ come back at the median of the seeds, and at most 17⅓ a
  message on average at one seed: seed 14's `push` cell, with 17, 18 and 17 over its three
  messages.
- In the 1 Gbps builder's cell (`dcb20`) more come back: 7⅓ a message at the median of the seeds
  with writes at once and 6⅙ with §4.11's rule, and at most 47⅓ and 50⅓ a message on average at
  one seed, both at seed 14 (47, 48 and 47; 50, 52 and 49).
- The record's text gives no maximum; the runs' outputs give these counts.
- No cell of a column comes back in custody. In the rows the counts are repair deliveries to the
  proposer, which keeps every row, and they are the same in every arm.

### What P4 costs

**Conditions.** The runs took place on 2026-10-21, before v0.5 was merged into the draft the same
day (12:04), and the figures were first written that day [`08fbc3d`]. The figures of P4's cost come
from the merging runs (264 runs, 04:00 to 05:37 CEST, on the draft of that night with merging),
whose arms with and without P4 reproduced the earlier P4 batch of the same night digest for digest.
The runs have 60 nodes, degree 30 and three blocks. The custody cell with a 50 Mbps and with a
1 Gbps proposer, the rows, and the rows with liars ran at seeds 7 to 16; the warm-median comparison
gives the median of the seeds and its range, against the same cells without P4. Every write was
taken at once. The rules are the draft's of that night: the source offered at publish,
and its paced holding grew at each chunk's write. The rules changed since are v0.5 (2026-10-21);
v0.9's holding and offers at the acknowledgement (2026-11-11), which §4.7 names ("measured with the
holding at the write"); and the line skip (2026-11-20) and the wake at the wait (v0.10.9), both
§4.11.
- The holdings: at seed 7, in the custody cell with writes at once, the source sent 38 808 holdings
  of the groups it publishes, 52 bytes each on average. That is 2.03 MB over the three blocks,
  0.68 MB a block, 5.4 Mbit, which takes about 108 ms of a 50 Mbps uplink (counted from a debug
  trace of the run).
- With a 50 Mbps proposer the custody block completes 116 ms later at the median (+53 to +164) and
  106 ms later at the tail (−4 to +175). The rows complete 98 ms later at the median (+4 to +180)
  and 132 ms later at the tail (+96 to +157). With a 1 Gbps proposer the cost is 6 ms (−1 to +7).
- Under the liar fault (`--fault claim20`), over seeds 7 to 16, 108 (member, row) pairs never
  complete, against 80 without P4: more on seven seeds, as many on two, fewer on one (not traced).
  The earlier P4 batch of the same night recorded them.
- With v0.5 merged (2026-10-21; the toy's README, "v0.5 in the next version"), 2 pairs stay short
  over seeds 7 to 16, and none on eight of the seeds.
- The toy check of v0.5's last resort (2026-10-21) ran at seeds 9, 14 and 15. With the last resort
  off, 12, 24 and 18 pairs stay short, as before v0.5 (12, 22 and 20). With the candidates limited
  to the ordered list of the first sixteen announcers, 0, 1 and 0 stay short, as with all of v0.5.
- The other cells move by −7 to +19 ms at the median, in the table for v0.5 in the toy's README,
  against the draft just before it, with P4 (seeds 7 to 16 for the custody and row cells, seed 7 for
  the rest). The +19 ms is the cell with `--promise-mode peer`, an option.

### P4 with the holding at the acknowledgement

**Conditions.** The figures come from the campaign of 2026-11-10 (the 60-node entry above), at
seeds 7 to 16, against the document before. The holding is moved alone, with a column's offers
still at publish: that holds for the rows and the 50 Mbps custody cell, and for the 1 Gbps custody
cell with its offers keyed on the uplink, which leave at publish for a 1 Gbps source.
- At seed 7, P4 sends 38 808 holdings in the custody cell with the holding at the write and at the
  acknowledgement alike (a known answer of the campaign).
- At the median, the rows move by 0 ms (−20 to +34), the rows with liars by −1 ms (−32 to +9), and
  the custody block by −5 ms (−34 to 0) with a 50 Mbps proposer and by −6 ms (−9 to +4) with a
  1 Gbps one.

### Merging the source's holdings

**Conditions.** The figures come from the merging runs of 2026-10-21 ("What P4 costs", above), on
the same cells and seeds, against P4 without merging under the same transport, before v0.5. The
runs use both transports: every write at once, and one write per connection at a time
(`--send-buffer 1`), which has its own P4 baseline.
- With writes at once, 7.1 % of the 50 Mbps proposer's holdings merge. The custody block gains 10 ms
  at the median (−18 to −1) of P4's 116, and 12 ms at the tail (−54 to +7). The rows gain 4 ms at
  the median (−44 to +16) and 20 ms at the tail (−85 to +30).
- With `--send-buffer 1`, 17.8 % merge. P4 itself costs the custody block 80 ms at the median there
  (+34 to +116), and merging gains 16 ms of it (−24 to +13). The rows gain 4 ms at the median (−29
  to +39).
- Copies move by at most 0.01, and no cell completes less. Under the liar fault, over seeds 7 to 16,
  merging leaves 100 (member, row) pairs short against P4's 108 (80 without P4) with writes at once,
  and 57 against 68 (55) with `--send-buffer 1`.
- At seed 7, with writes at once, 59.2 % of the source's holdings find no earlier holding of their
  group still waiting. 9.6 % follow one made in the same instant, which merging catches, and 31.2 %
  follow one still waiting in the transport, which it cannot reach (counted from a debug trace).

### The source's offers at publish (card 3)

**Conditions.** The figures come from the checks of the writer's order of 2026-10-07 (11:05; the
toy's README of that commit, the paragraph on `--answers-first`), the same runs that checked §4.12's
rule. They were first written that day [`08fbc3d`, 2026-10-21]. The runs have 60 nodes, degree 30
and three payloads, at seeds 7, 8 and 9. The tier 4 cells are `push` (a 50 Mbps home builder) and
`dcb20` (a 1 Gbps builder), with the source's offers dropped (`--source-offers off`) against the
same cells with them; the source then offered at publish, as v0.3's did. The 1 Gbps proposer of
columns is the custody setting; its figure is the mean over seeds 7, 8 and 9, paired by seed,
against v0.3's order of the queue with the offers. Every write was taken at once, under the window
in bytes. The rules are the draft's of 2026-10-07. The rules changed since are P4 and v0.5
(2026-10-21); v0.9's offers at the acknowledgement (2026-11-11), so that a source no longer offers
at publish by default (§4.7); the payload cells' group key (2026-10-23), which moves their exact
values (the toy's README); and the line skip (2026-11-20) and the wake at the wait (v0.10.9), both
§4.11.
- A home builder answers 0.34 to 1.35 copies of the message over seeds 7 to 9, and 81 to 94 % of
  those answers arrive as duplicates.
- Without its offers a home builder uploads 1.6 to 1.8 copies of the message instead of 2.1 to 2.9,
  and its cells' medians move by less than 10 ms.
- A fast builder uploads 9.7 to 12.0 copies with its offers and 2.0 without, and then completes
  10 ms later at the median.
- Without its offers a 1 Gbps proposer of columns completes 75 ms later at the median, and 59 ms
  later at the tail.

### The source's offers at the acknowledgement (card 3)

**Conditions.** The figures come from the payload cells of the campaign of 2026-11-10 (the 60-node
entry above), at seeds 7 to 16, as the medians over the seeds, against the document before. The
runs use both transports: every write at once, and §4.11's rule as `--send-buffer 1`. The figures
were first written on 2026-11-11 [`0d968d8`].
- The home builder (`push`) is asked for 222 ids over three payloads against 572: 61 % fewer.
- It uploads 2.07 copies of the message against 2.50, and a 1 Gbps builder (`dcb20`) 5.94 against
  9.98.
- The medians move by −4 ms (`push`), −4 (`--rebuilt none`), −8 (`sil30`) and 0 (`dcb20`).
- With §4.11's rule the home builder is asked for 40 ids against 45, and the medians move within
  4 ms.

### A column's offers at the acknowledgement, and the offers keyed on the uplink

**Conditions.** The figures come from the campaign of 2026-11-10: at 60 nodes over seeds 7 to 16,
and at 500 nodes over seeds 7 to 9 with a fifth of the nodes sampling, each paired by seed.
- A 1 Gbps proposer's block, with its offers at the acknowledgement against its offers at publish
  (offers per type's stand-in), completes 44 ms later at 60 nodes (+28 to +121) and 9 ms later at
  500 (+6 to +15).
- With the offers keyed on the configured uplink (offers at publish for a source at or above
  `STRIPE_UPLINK`, the holding at the acknowledgement), the 1 Gbps proposer's block completes 6 ms
  sooner at 60 nodes than in the document before (−9 to +4). At 500 nodes the cost it would take
  back is the 9 ms above.

## §4.10 A sampler pulls

**Conditions.** The figures come from the toy's graphs of §1.3's entry, built by
`toy/sampler_graph.py c`, with 500 nodes, seeds 7 to 16 and degree 70 or 16, graph only; each figure
is a share of all (sampler, column) pairs over the ten graphs. "One step" goes to the link whose
computed custody is nearest the column. "With the floor" is the toy's floor of 6 custodian links per
column; "without it" means that a node has exactly its 16 links. The method was first run on
2026-10-23. The shares at 70 and 16 links were first written into the text on the main line in spec
`fda38ff` (2026-11-19), the others in `0d968d8` (2026-11-14). The script runs no events.

- A sampler's own links serve 98 % of (sampler, column) pairs at 70 links and 58 % at 16 [97.7 % and
  57.6 %]. A path of two hops exists for every other pair.
- One step left 1.8 % of all pairs unreached at 16 links where custodians keep their floor per
  column [1.75 %], and 19 % without that floor [19.41 %].
- Without the floor, the Kademlia-style rule reached 95.9 % of the pairs within two hops and the
  other 4.1 % in three.

## §4.11 The window, in bytes

### The window's unit (X3), and what it changes

**Conditions.** The figures come from runs of 2026-10-07: those of the custody setting's first
figures, under `protocol.md`'s slot window (02:16); those of the row setting (03:59); and those of
the window in bytes, with the slot window's figures beside it (04:40; the toy's README of that
commit gives every table). The figures were first written that day [`08fbc3d`, 2026-10-21]. Each
cell ran at one seed, which the record does not name; the toy's default then was seed 7. The
baseline is `protocol.md`'s slot window, in the same cell and seed. Every write was taken at once.
The custody setting publishes a block of 32 blobs as 128 column groups, gives each node a derived
custody of 8 columns and a floor of 6 custodian peers (2 for the proposer), and makes node 1 the
proposer. The row cells at 60 nodes have degree 30, a 1 Gbps proposer and 6 reconstructors; at
500 nodes, they have degree 70, 32 subnets and 50 reconstructors. The rules are the draft's of
2026-10-07 under v0.3's order of the queue, before §4.12's source rule (the same day at 11:05)
except where a figure names it. The rules changed since are §4.12's source rule; P4 and v0.5
(2026-10-21; "Tables further down that predate 2026-10-21 were recorded without P4", the toy's
README); v0.9's source rules (2026-11-11); the probe of a claim (R5, 2026-11-15, §4.6), in the row
cells; and the line skip (2026-11-20) and the wake at the wait (v0.10.9).
- Under the slot window, a 50 Mbps proposer of 128 column groups took 9 173 ms for a 9 MB block,
  which needs about 2 s at 50 Mbps: it was held to about 10 Mbps. A 1 Gbps proposer was held to
  about a fifth of its uplink. These figures come from the custody setting at 60 nodes, degree 30.
- Under the slot window, a reconstructor's answer to a probe left 450 ms after it was decided, in
  the honest row cells at 60 nodes (the toy's README of 03:59 that day).
- At 60 nodes with a 1 Gbps proposer, the custody block's warm p50 / p99 are 347 / 456 ms, against
  777 / 963 ms under slots. With a 50 Mbps proposer, its warm p50 / p99 are 2 444 / 2 907 ms under
  v0.3's order and 2 220 / 2 479 ms with §4.12's source rule (11:05 that day), against
  9 173 / 9 475 ms under slots.
- In the sampling cell (60 nodes, 12 samplers, a 1 Gbps proposer), the samples arrive at 277 ms at
  the median (p99 440 ms) under bytes, against 750 ms (p99 828 ms) under slots, in the toy's README
  of 04:40 that day. The text had 264 ms, which no record found gives.
- In the rows at 60 nodes with half the columns withheld and 16 subnets, the custodians complete at
  2 438 / 2 750 ms, against 2 735 / 3 104 ms under slots; every claim is verified and none re-armed,
  against 8 re-arms of honest claimants under slots. The honest row cell, with 32 subnets, has no
  later decode, against 37 later decodes and one re-arm under slots.
- At 500 nodes, degree 70, with a 1 Gbps proposer, the custody block completes at 531 / 680 ms,
  against 1 011 / 1 207 ms under slots. These are under v0.3's order; with §4.12's source rule the
  tail is 697 ms (the toy's README of 11:05 that day). The withheld block completes through the rows
  at 2 368 / 2 505 ms (2.4 and 2.5 s), against 2.5 and 3.0 s under slots.
- In tier 4, the recorded cells (`check.py`: 60 nodes, degree 30, three payloads, seed 7) differ
  from v0.3's by at most 7 ms at the median, 15 ms at the tail and 0.04 copies either way. The
  README puts that to the writer choosing the entry before taking room and to control taking none,
  not to the unit.
- The decision record's "The window's unit" repeats the 500-node custody figures and tier 4's 15 ms.

### Below the writer

**Conditions.** The figures come from the campaign of 2026-11-10 (§4.7's entry, "The
acknowledgement against the document before, at 60 nodes"), and were first written on 2026-11-11
[`0d968d8`]. The rule runs as one write per connection at a time (`--send-buffer 1`), against every
write at once. "With §4.7's rules" is the draft as taken on 2026-11-11, with offers and holding at
the acknowledgement for every type; "with a column's offers at publish" is offers per type. The
rules and the changes since are those of §4.7's entry for this campaign.
- At seed 7, with the rule read in bytes instead (`--send-buffer 12000`, one payload chunk), the
  column cells move by at most 36 ms at the median (103 ms at the tail, in the rows with the offers
  at the acknowledgement).
- The figures below hold with §4.7's rules, at 60 nodes, over seeds 7 to 16, as the median of the
  seeds and its range:
  - the 50 Mbps payload cells complete sooner, `push` by 38 ms, `--rebuilt none` by 38 and `sil30`
    by 46, and they are sooner in 29 of their 30 runs, with 0.36, 0.10 and 0.17 fewer copies;
  - the rows complete 14 ms sooner (−93 to +164), sooner on six seeds, and the rows with liars 47 ms
    sooner (−83 to +139), sooner on six seeds;
  - with offers per type, the rule brought the rows 110 ms sooner (−179 to −76) and the rows with
    liars 90 ms sooner (−195 to −64);
  - a 50 Mbps proposer's custody block completes 48 ms later (−36 to +63), later on eight seeds, and
    34 ms later at the tail;
  - of the 1 Gbps cells, the custody block moves by −4 ms and the `dcb20` payload by −3 ms.
- At 500 nodes, the payload completes 18 ms sooner with 0.31 fewer copies at seed 7 (offers per type
  with the rule against offers per type; the payload's rule is the same in both). The rows complete
  2 ms sooner (−21 to −1) over seeds 7 to 9, sooner on all three.

### The line skips a writer mid-write; the recorded cells

**Conditions.** The figures come from 2026-11-20, from the line skip alone (00:45) and then from
spec `67cbfba` (01:07), as their commit messages give them. The known answer
`toy/line_stall_known.py --doc v2` runs on the `push` cell's network (60 nodes, degree 30, seed 7)
and publishes its first payload only. It stalls the source's line head when the line first holds
two writers, watches the two seconds after the stall (its `SPAN`), and counts the chunks sent to
the other peers from 600 ms after the stall on (past `WINDOW_TIMEOUT`). Since `aba3986`
(2026-11-20, 01:52), after these figures, the other peers count as held up where none was sent to
them and chunks still wait for them, whatever the window's state; before, only while the window had
room. The recorded cells
(`toy/check.py --doc v2`: 60 nodes, degree 30, three payloads, seed 7) ran at the toy's default
transport since 2026-11-15, one write per connection at a time (`--send-buffer 1`), except
`push-deep`, which runs at `--send-buffer 0`. The baseline is v0.10.6's recording, `golden-v2.txt`.
The figures are of v0.10.7's form: the line skip, with a wake before every control write of a
writer in line (`67cbfba`). v0.10.9's wake at the wait moves `rr-stripe` and `push-deep` in their
digest only, and no other cell (§4.11).
- Before the rule, with the source's line head stalled, nine other peers' chunks waited in an empty
  window, and none was sent to them from 600 ms after the stall to the end of the check's two
  seconds.
- In `loss-thin`, p50 moved 807 → 814 ms, p99 922 → 894 ms and the copies 1.64 → 1.65. In
  `late-block`, p99 moved 727 → 718 ms. With the line skip alone (00:45), `loss-thin` moved to p50
  805 ms, p99 938 ms and 1.65 copies, and `late-block` to p99 726 ms.

## §4.12 Which entry goes next

**Conditions.** The figures come from the toy (`toy/run.py --doc v2`), at 60 nodes and degree 30
unless an entry gives another size. A cell is one configuration of the toy; the median and the tail
are the 50th and the 99th percentile of a cell's completion times. Each entry names its seeds; a
figure from fewer than ten seeds is a toy check of a mechanism, not a measurement. The baseline is
v0.3's order, the toy's `--answers-first v03`, with v2's window in bytes. Every figure below was
first written on 2026-10-07 (11:05), when the draft took the writer's order, and the toy's README of
that commit records the checks. Spec `08fbc3d`, the v0.6 draft of 2026-10-21, took them into the
main line. Like every figure from before 2026-11-15, they ran with the toy's earlier transport,
which takes every write at once (`--send-buffer 0`). The rules they ran on are the draft's of
2026-10-07. Which of them changed since is not traced here; §4.7's entry for the source's offers at
publish (card 3), from the same runs, names the later rules it can point to.

**A source's own chunks first, against v0.3's order:**
- With a 50 Mbps proposer, by the mean over seeds 7, 8 and 9 (paired by seed), the custody block
  completes 247 ms sooner at the median and 430 ms sooner at the tail, and sooner on every seed. At
  seed 7, the proposer's last first copy leaves 0.3 s sooner. It sends 1 992 second copies where it
  sent 2 400, and answers 518 asks where it answered 1 212. Over both blocks it sends 15 % fewer
  chunks, since a holding drops more of its queued pushes while they wait (card 8).
- Every single-group cell (tier 4, variant C, the twelve check cells at seed 7) runs exactly as
  under v0.3's order, at 60 nodes and at 500.
- With a 1 Gbps proposer at 60 nodes, every cell runs exactly as under v0.3's order, except the
  honest row cell. There the tail is 22 ms sooner, and the median moves by between 8 ms sooner and
  42 ms later over seeds 7, 8 and 9.
- With a 1 Gbps proposer at 500 nodes, over three seeds (not named in the record), the custody and
  sampling cells move within 5 ms at the median, and by between 5 ms sooner and 17 ms later at the
  tail. The withheld row cell runs exactly as under v0.3's order.

**The two other cures** (dropping the source's offers, or queueing them after the block's pushes)
were each compared with v0.3's order, by the mean over seeds 7, 8 and 9. With a 50 Mbps proposer
they made the median 282 and 266 ms sooner, against the rule's 247. With a fast proposer they made
it 7 to 355 ms later.

**Answers first, against the source-first rule with the option off,** gives these figures, as the
mean over seeds 7, 8 and 9:
- the median moves within 5 ms in every tier 4 and variant C cell but the thin lossy one
  (`loss-thin`), which is 12 ms later at the median on every seed; the honest row cell's median is
  39 ms sooner;
- the asks' round trip at the 99th percentile is shorter in most cells, by up to 44 ms, and a few
  hundredths of a copy are saved;
- with cards 8, 9, 12 and 15 off (seeds not given in the record), a node's answers waited 1.1 to
  1.7 s at the 99th percentile, and at most 0.22 s with the option.

**The three other forms, against v0.3's order:** over seeds 7, 8 and 9 (the mean), the oldest answer
first costs a 50 Mbps proposer 315 ms at the median, and the same with the answer's writer ahead of
the line costs `loss-thin` 91 ms at the median. An answer first only once it has waited 100 ms costs
`loss-thin` 12 ms and the 50 Mbps proposer 61 ms (its seeds not given in the record).

## §4.13 The ask window follows the uplink

The figures of §4.13, and of the decision record's "The promise's length", come from the work of
2026-10-19, first written on the main line in `08fbc3d` (2026-10-21). It used two instruments: the
research harness of the posts, which is not the toy, and the toy in the research harness's setting.

### The research harness: the promise stretched, and the evidence

**Conditions.** These figures come from the research harness of the posts, not from the toy. They
were run on 2026-10-19. Each arm is paired with tier 4's cell of the same seed, from the posts'
ten-seed corpus; tier 4's cell with 30 % withholders at 10 Mbps was run for this work. The tail is
the 99th percentile of the warm payloads, and the copies are data copies. A figure is the median
over the seeds of the change, with its range. "10 Mbps" is the 10/20 Mbps network and "25 Mbps" the
25/100 Mbps one. The forms are the ask window stretched alone (an ask window of 1 000 ms with a
promise of 400 ms at 10 Mbps, and 400 / 400 ms at 25 Mbps), and the promise stretched with it
(1 000 / 2 000 ms at 10 Mbps). The record does not name the seeds. The rules are the research
harness's own, tier 4's, not this draft's.
- With the promise stretched with the window, with 30 % withholders at 10 Mbps, over three paired
  seeds, the tail is 18.5 % longer at the median (+9.7 to +18.6 %), and the form is better on both
  axes on none of the three.
- With the ask window alone, at 10 Mbps, over ten paired seeds, the tail is 5.1 % shorter at the
  median (2.2 to 8.4 %) and the copies are 0.20 fewer (0.15 to 0.23), better on both axes on all
  ten.
- At 25 Mbps, over ten paired seeds, the copies are 0.03 fewer (0.01 to 0.06), fewer on all ten, and
  the tail is 0.8 % shorter at the median (from 2.4 % shorter to 3.3 % longer).
- With 30 % withholders at 10 Mbps, over three paired seeds, the tail is 3.5 % shorter (3.0 to
  5.4 %) and the copies are 0.18 fewer (0.16 to 0.18).

### The toy in the research harness's setting: parked pairs, and the per-peer promise

**Conditions.** The toy (`toy/run.py --doc v2`) ran on 2026-10-19 with 500 nodes and seeds 7, 8 and
9, in the research harness's setting (`--rebuilt none --stripe on`), at 12.5 Mbps (the 12.5/25 Mbps
network) unless a figure names another. Each form is compared with the rule off, `protocol.md`'s
fixed window. Every write was taken at once (`--send-buffer 0`). "Parked" counts the (peer, group)
pairs parked on a broken promise in a run. The rules are the draft's of 2026-10-19. The rules
changed since are P4 and v0.5 (2026-10-21), v0.9's source rules (2026-11-11), the line skip
(2026-11-20) and the wake at the wait (v0.10.9).
- The ask window alone, §4.13's form, parks 503 to 642 pairs in the all-home network, against 584 to
  702 with `protocol.md`'s window. With 30 % withholders it parks about 10 700, against about
  12 600. With 10 % of chunks lost it parks 9 054 to 9 313, against 5 575 to 5 864: about 60 % more.
- The record gives no parked count for the mixed network, which §4.13 names among the networks where
  the count stayed below `protocol.md`'s.
- The per-peer promise (the decision record's "The promise's length") parks 283 to 360 honest pairs
  a run in the all-home network. Its completion times and bytes are those of the ask window alone:
  the tail moves by −3.2, −2.0 and −0.9 % per seed, against −3.0, −2.3 and −0.7 %, and the copies
  are 0.21 fewer in both. With 30 % withholders it parks about 10 200, against about 10 700.

## §6.1 `protocol.md` as a setting

### The distance to the recordings, by date

**Conditions.** The figures come from the regression cells in `toy/check.py`. For each cell, the
script runs `toy/run.py --nodes 60 --degree 30 --msgs 3 --seed 7` with that cell's flags, so each
cell uses one seed. A figure is a cell's warm median and warm 99th percentile, or its warm copies.
Each bullet of §6.1's Rationale compares this document's recording (`toy/golden-v2.txt`,
`check.py --doc v2`) with `protocol.md`'s (`toy/golden.txt`) as both stood after the change the
bullet names, on the rules of that date. `loss-thin` runs at a 20 Mbps uplink. Before 2026-11-15
every cell took every write at once (`--send-buffer 0`); the bullet of 2026-11-15 ran with
`--send-buffer 1`, except `rr-stripe`, whose uplink (`--uplink rr`) has no send buffer. The table
gives the run dates and the commits on the main line that first wrote each figure:

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
document's §4.11 (2026-11-20, `67cbfba`) moved its `loss-thin` (p50 807 to 814 ms, p99 922 to
894 ms, copies 1.64 to 1.65) and its `late-block`. The wake at the wait (2026-11-21, `5372ebb`)
moved the digests of `rr-stripe` and `push-deep` only. Read from both recordings at `a6ca1fc`
(2026-11-21), the eleven cells of the last bullet stand as they stood on 2026-11-15. `loss-thin` is
26 ms later at the median, 27 ms later at the tail and 0.05 copies lighter (p50 814 against 788 ms,
p99 894 against 867 ms, 1.65 against 1.70 copies). `late-block` is 6 ms later at the median and
11 ms later at the tail. `ihave-limits` is 1 ms sooner at the median and at the tail, with 0.01
copies more (p50 510 against 511 ms, p99 593 against 594 ms, 2.07 against 2.06 copies).

- **v0.3's window and the window in bytes** (2026-10-07). With v0.3's window (slots of one payload
  chunk), eleven of the twelve cells reproduced v0.3's completion times and bytes exactly, and
  `rr-stripe` differed by 3 ms at the median. With the window in bytes, the cells moved by at most
  7 ms at the median, 15 ms at the tail and 0.04 copies either way: `announce` p99 576 → 587 ms,
  `without-a` 578 → 565 ms, `loss-thin` 984 → 999 ms, `push` copies 2.41 → 2.43.
- **v0.4's P4** (2026-10-21), against v0.4's recording: eleven cells were within 3 ms at the
  median, 16 ms at the tail and 0.03 copies (`announce` p99 568 → 584 ms, `rr-stripe` 521 → 505 ms).
  `loss-thin` was 8 ms later at the median and 0.10 copies lighter. Without P4, the medians had been
  up to 102 ms behind v0.4's (`silent` 678 against 576 ms).
- **v0.5** (2026-10-21), against v0.5's recording: eleven cells were within 7 ms at the median,
  15 ms at the tail and 0.03 copies (`rr-stripe` p50 417 → 410 ms, `dcb20` p99 358 → 343 ms,
  `cap-wait` 740 → 754 ms). `loss-thin` was 1 ms later at the median and 0.12 copies lighter
  (1.81 copies).
- **The group's key** (2026-10-25): eleven cells were within 6 ms at the median, 35 ms at the tail
  and 0.03 copies (`without-a` p99 613 → 578 ms, `cap-wait` 815 → 797 ms). `loss-thin` was 10 ms
  later at the median and 0.11 copies lighter (1.81 copies).
- **Ties, and no second ask of a peer at once** (2026-10-26): eleven cells were within 8 ms at the
  median, 30 ms at the tail and 0.03 copies (`silent` p50 641 → 649 ms, `without-a` p99 598 →
  568 ms). `loss-thin` was 8 ms later at the median and 0.12 copies lighter (1.81 copies).
- **v0.9's rules** (2026-11-11), against v0.9's own recording: eleven cells were within 13 ms at the
  median, 18 ms at the tail and 0.06 copies (`cap-wait` 630 → 643 ms, `without-a` p99 551 →
  533 ms). `loss-thin` was 6 ms later at the median and 0.14 copies lighter (1.80 copies).
- **The transport** (2026-11-15), against `protocol.md`'s recording: eleven cells were within 8 ms
  at the median, 16 ms at the tail and 0.02 copies (`cap-wait` 544 → 552 ms, p99 710 → 726 ms).
  `loss-thin` was 18 ms later at the median and 0.07 copies lighter (1.64 copies).

### `ihave-limits` against `protocol.md`

**Conditions.** The figures come from the regression's `ihave-limits` cell, which runs as the other
cells above, with stock gossipsub's two limits (`--ihave-limits 10,5000`), at one seed (7). It ran
under v0.9's rules:
- With the toy's transport since 2026-11-15 (`--send-buffer 1`), it ran on 2026-11-15, and the
  figures were first written on the main line in `2f7ede2` (2026-11-15). `protocol.md`'s side of it
  moved on 2026-11-20 (above).
- With the earlier transport (`--send-buffer 0`), it ran on 2026-11-14, and the figures were first
  written on the main line in `0d968d8` (2026-11-14).

The figure before §4.3 carried the limits is the `push` cell's warm median in this document's
recording of 2026-10-27, with the earlier transport. It was first written on the main line in
`0d968d8`.

- With `--send-buffer 1`, this document held back 26 667 asks to the next heartbeat, where
  `protocol.md` held back 26 799. It was 2 ms sooner at the median and 1 ms later at the tail, with
  0.02 copies more: p50 510 against 512 ms, p99 593 against 592 ms, 2.07 against 2.05 copies.
- With `--send-buffer 0`, it held back 24 248 asks against 24 538, and it was 3 ms sooner at the
  median and 7 ms sooner at the tail: p50 541 against 544 ms, p99 621 against 628 ms, 2.41 against
  2.40 copies.
- Before §4.3 carried the limits, it held back none and ran as without them (p50 470 ms).

## §6.2 The five designs as settings

**Conditions.** The cells have 60 nodes, degree 30, the 1 Gbps proposer and 6 row reconstructors
where there are rows, in the custody and rows settings of `toy/README.md` ("The next version"). They
ran at seeds 7 to 19, thirteen runs of each cell, unless an item names seed 7, the recorded seed.
They ran on 2026-10-07 (the repair floor) and 2026-10-08 (three supernodes, `--supernodes`, on
datacenter links); the figures were first written into the text on the main line in spec `08fbc3d`
(v0.6, 2026-10-21), and recorded in the toy's README there. The transport took every write at once
(`--send-buffer 0`). The runs predate v0.4's P4 (2026-10-21): the toy's README says that its tables
from before that date were recorded without P4. They also predate
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

**Conditions.** The cells are as in §6.2's entry: 60 nodes, degree 30, the 1 Gbps proposer, 6 row
reconstructors where there are rows, three supernodes on datacenter links, and seeds 7 to 19. A time
is the median over the seeds of a cell's median or 99th percentile; copies are of own custody, as
the median over the seeds. "Cells at `R`" means the fast class off (`--without 17`, card 17), which
leaves the cells without supernodes as they were, event for event at seeds 7 to 9. The cells ran on
2026-10-08; the figures were first written on the main line in `08fbc3d` and recorded in the toy's
README there. The runs predate the same later rules as §6.2's entry, and used the same transport. A
column has about ten custodians at this scale.

- With supernodes in the fast class, the honest custody cell takes 0.96 copies more per node (3.10
  against 2.14), and the honest row cell takes 0.72 copies and half a second of tail more (2.88
  against 2.16 copies; a p99 of 1 674 against 1 143 ms).
- With cells at `R`, the honest row cell is back at 1.13 s at the tail and 2.22 copies (1.14 s and
  2.16 without supernodes). The withheld cells are as fast or faster at the tail (custody 1.25 s, 16
  subnets 1.64 s, 32 subnets 1.69 s, against 1.25, 1.76 and 1.83 s) at 0.6 to 1.2 copies fewer. The
  honest custody cell gives up 31 ms at the median and 73 ms at the tail for 1.17 copies fewer.

### `PROMISE`

**Conditions.** The figures come from the toy but for the last, which comes from the research
harness of the posts (below). The honest row cell has 60 nodes, degree 30, the 1 Gbps proposer, 6
row reconstructors, the default 32 row subnets and no supernodes; it ran at seeds 7 to 9, at
`protocol.md`'s promise of 400 ms and at 0.8 s (`--promise 0.8`). The times of the late answers,
and the refusals, are seed 7's. It ran on 2026-10-08; the figures were first written on the main
line in `08fbc3d` and recorded in the toy's README there. The runs predate the same later rules as
§6.2's entry, and used the same transport.

The payload's promise was evaluated with §4.13 on 2026-10-19, and first written on the main line in
`08fbc3d`. Its figure comes from the research harness, not the toy: every node is at 10 Mbps up and
20 Mbps down, with 30 % withholders, and the figure is the median of three seeds, each paired with
the tier 4 cell of the same seed under `protocol.md`'s fixed ask window and promise. The promise was
scaled with the ask window, to 2 s in place of 400 ms. The text's statement that silent peers were
not hurt in the toy gives no figure.

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

**Conditions.** The cells run `--setting custody --samplers 20 --net bld --msgs 2`: 500 nodes, a
fifth of them samplers of eight cells, the 1 Gbps proposer, two blocks, degree 70 or 16, honest and
with 30 % withholding custodians (`--fault wh30`). Routed requests are on (`ROUTE_HOPS` 1), with a
floor of one cover or of two. The cells ran at seeds 7 to 16: 2 000 sampler-blocks for each
configuration (100 samplers, two blocks, ten seeds). A time is the median over the 20 blocks. They
ran on 2026-10-26 on the draft of 2026-10-23, and were recorded in the toy's README ("A sampler's
reach"). The figures were first written into the text on the main line in spec `0d968d8`
(2026-11-14). The transport took every write at once (`--send-buffer 0`). `SAMPLE_RETRY` was 2 s,
`SAMPLE_RETRY2` 0.5 s and `SAMPLE_OUTSTANDING` 4. The runs predate ties (2026-10-26), the IHAVE
limits (2026-10-27), v0.9's source at the acknowledgement (2026-11-11) and the transport
(2026-11-15); they were not run again.

- **`SAMPLE_RETRY`:** the custodians' 99th percentile was 0.67 to 0.70 s, honest [666 to 678 ms at
  70 links, 694 to 702 ms at 16]. Under 30 % withholders the samplers' median was 2.5 to 2.9 s.
- **Two covers** left no sampler short, honest or under 30 % withholders, at 70 links and at 16.
- **One cover** did as well at 70. At 16 it left 7 sampler-blocks short under withholders, and it
  raised the honest samples' 99th percentile to 2.2 s, against 0.7 s with two [2 197 and 679 ms].

### `SAMPLE_COVER`, `COVER_HIGH`, `ROUTE_FLOOR` and the sampling-only links: the graphs

**Conditions.** The figures come from the toy's graphs of §1.3's entry, with 500 nodes and seeds 7
to 16, graph only.
- The floor of the fewest links comes from `toy/sampler_graph.py a`, a greedy cover, with high
  custody counted in full. Its figures are medians over samplers, with the range in parentheses.
- The diversity floor comes from `toy/sampler_match.py`, with covers counted by distinct links and
  400 draws per sampler. A share is that of eight-sample draws that find eight distinct serving
  links, the mean over the seeds. It is given over three populations: 8-column custodians, 5 %
  supernodes, and the row setting's network.
- `ROUTE_FLOOR` comes from `toy/sampler_graph.py c` at 16 links without the per-column floor. Links
  added are counted at both ends.

The method was first run on 2026-10-23 and came into the toy on 2026-10-26. The figures were first
written into the text on the main line in spec `0d968d8` (2026-11-14), except the `COVER_HIGH`
figure for sixteen samples (`fda38ff`, 2026-11-19, from the same run). The sampling-only links per
other node are the two-cover links per sampler spread over the other nodes (a fifth of 500 nodes
sample). The figures for sampling-only links per other node were first written in `0d968d8`.

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

**Conditions.** The cells run `--setting custody --samplers 20 --net bld`: 60 nodes, 12 samplers of
eight cells, the 1 Gbps proposer, seed 7, routed requests on. The transport took every write at
once (`--send-buffer 0`).
- `ROUTE_HOPS` ran `--route-hops 2` at degree 30, in the known answers of 2026-10-23 on that day's
  draft, recorded in the toy's README ("A sampler's reach"). The record does not name the cell's
  floor or its blocks. The figure was first written on the main line in `0d968d8`.
- `FORWARD_LIMIT` ran `--forward-limit 1` against no limit, with a floor of two covers and three
  blocks, honest, with 30 % withholders and with half the columns withheld (`--withhold 64`). The
  degree is not printed in the outputs. The runs took place on 2026-11-03 on the draft of that day.
  The figures were first written on the main line in `0d968d8`.

Both predate v0.9's source at the acknowledgement (2026-11-11) and the transport (2026-11-15).

- **`ROUTE_HOPS`:** one request took a second step, and its sample came at 468 ms, where with one
  step it had waited for the second phase.
- **`FORWARD_LIMIT`:** a limit of 1 changed no event, honest or under 30 % withholders. With half
  the columns withheld it refused 10 of 1 048 forwards, and the same samples arrived.

### `ASK_UPLINK`

**Conditions.** The runs have 500 nodes and seeds 7 to 9, and set the ask window scaled by the
uplink (§4.13) against `protocol.md`'s fixed 200 ms window, each seed paired with the same cell with
the rule off. The toy ran in the research harness's setting: no rebuilt chunks pushed
(`--rebuilt none`) and striping on (`--stripe on`). The networks are all-home at 12.5 Mbps uplinks;
30 % silent peers; 30 % withholders; 10 % of chunks lost; and the mixed-bandwidth network at 6 Mbps
for its home nodes, with a home builder or a datacenter builder. The runs took place on 2026-10-19,
on the draft before v0.4's P4 (2026-10-21); the figures were first written on the main line in
`08fbc3d`. The transport took every write at once (`--send-buffer 0`). The runs predate every rule
carried after 2026-10-19, and they were not run again.

- Every cell takes fewer copies: 0.16 to 0.33, the median over the seeds per cell.
- The tail is shorter in all-home at 12.5 Mbps by 0.7 to 3.0 %, with 30 % silent peers by 2.4 to
  4.4 %, and in mixed-bandwidth at 6 Mbps by 3.1 to 3.2 % with a home builder and by 3.0 to 3.6 %
  with a datacenter builder; it moves within ±1.6 % with 30 % withholders.
- With 10 % of chunks lost, the tail is up to 3.2 % longer.

### `MERGE_HOLDINGS`

**Conditions.** The cells run the custody setting at 60 nodes with a 50 Mbps proposer of 128 column
groups, at seeds 7 to 16, and the figures are warm medians. A figure is the median over the seeds of
the change, paired by seed: P4 against no P4, and P4 with merging (`--merge-holdings on`) against
P4. The baselines differ by transport: writes that complete at once (`--send-buffer 0`), and one
write per connection at a time (`--send-buffer 1`), each with its own P4 baseline. The cells ran on
2026-10-21, the day v0.4's P4 came in, and were recorded in the toy's README ("The next version",
P4's and `--merge-holdings`'s tables). The figures were first written on the main line in
`08fbc3d`. The runs predate v0.5 (2026-10-21), ties (2026-10-26), v0.9's source at the
acknowledgement (2026-11-11) and the transport of 2026-11-15.

- With writes that complete at once, merging takes back 10 ms of P4's 116 ms at the custody block's
  median. With one write per connection at a time, it takes back 16 ms of 80 ms. The copies are
  unchanged.

### The IHAVE limits

**Conditions.** The figures come from the regression's `ihave-limits` cell (§6.1's entry), which
runs `toy/run.py --doc v2 --ihave-limits M,5000` on 60 nodes at degree 30, with three payloads and
seed 7, against the same cell with no limit. It ran under v0.9's rules, with the earlier transport
(`--send-buffer 0`), on 2026-11-14; the figures were first written on the main line in spec
`0d968d8`. The cell was first swept on 2026-10-27 under the rules of then, with other values; the
text gives the run of 2026-11-14. It predates the transport of 2026-11-15 and the window line of
2026-11-20 and 2026-11-21 (§6.1's entry), and it was not run again. At `protocol.md` §8.3's
reference values, the cells and their conditions are those of §4.3's entry.

- Against no limit (p50 461 ms, 2.49 copies): 10 frames cost 80 ms at the median and save 0.08
  copies, 20 cost 31 ms and save 0.11, 40 cost 3 ms and save 0.01, and 100 change neither. The 5000
  asks never bound.

## §7 Bindings

`protocol-v2.md` §7 cites §1.3's entry: at 16 links, one cover by the fewest links adds a median of
13 links.

## The decision record's figures

These entries hold the figures of `protocol-v2-decisions.md` that no section's entry above holds,
each under its decision's label.

### [D5] The announce relation's width

The decision record's "Decided on 2026-11-14" points here for `[D5]`.

**Conditions.** The figures were first written on the main line in `0d968d8` (2026-11-14). The
60-node runs ran on the toy of 2026-11-13, with its flags `--col-announce`, `--row-announce` and
`--row-delay`. The record does not name the tree of the 500-node runs; their known answer is the
500-node row of the toy's README. Each arm is compared with `base` (`ALL_JOINED` on both axes, a 1 s
row delay), paired by seed. For the paired changes, the entry gives the median over the seeds of the
change, and its range. *Short* counts the nodes with a group incomplete in a block, summed over the
seeds and blocks; *copies* are data and control; *offers* are the arm's total against `base`'s.
Every write was taken at once (`--send-buffer 0`, the toy's default until 2026-11-15).
- At 60 nodes, 300 cells ran on 2026-11-13, 17:54 to 20:35 CET, at degree 30, with three blocks, at
  seeds 7 to 16. The settings are custody with a 50 Mbps proposer and with a 1 Gbps one
  (`--net bld`), custody half withheld (`--withhold 64 --supernodes 10`), the rows, the rows half
  withheld (`--withhold 64 --row-subnets 16`), and the rows with liars (`--fault claim20`, a fifth
  of the nodes lying about their row holdings).
- At 500 nodes, 18 cells ran on 2026-11-13, 21:00 to 22:07 CET, at degree 70, with two blocks, at
  seeds 7 to 9: custody at 50 Mbps, and the rows half withheld with 32 subnets, 50 reconstructors
  and a 1 Gbps proposer. A further 12 cells at that size, with liars, ran on 2026-11-14, 01:10 to
  02:20 CET: the rows with no column withheld in the default network, and the rows half withheld as
  above.
- The rules are the draft's of 2026-11-13 for the 60-node runs, with v0.9's source rules since
  2026-11-11. The rules changed since are a source's links in a family it does not custody
  (2026-11-13, 19:16, after the 60-node runs began), which keeps the custody and row cells' digests
  at seed 7 (its commit message); the probe of a claim (R5, 2026-11-15, §4.6), in the row cells;
  v0.10's rules (spec `62a8179`, 2026-11-16); and the line skip (2026-11-20) and the wake at the
  wait (v0.10.9), both §4.11.

The figures are these:
- At 60 nodes, in the five settings where it is close, the columns' `NONE` sends 19.7 to 29.6 %
  fewer offers (19 to 30 % in round figures), and its copies fall by 0.00 to 0.06 (control 0.002 to
  0.048, data at most 0.02).
- With liars at 60 nodes, `NONE` leaves custodians short in two blocks on seed 13 (blocks 1 and 3),
  where `base` left one short in one (block 2). It leaves a row member short on seed 15, where
  `base` left none; `base`'s one short row member is on seed 12, where `NONE` leaves none.
- At 500 nodes, in custody, `NONE` moves the custodians by +2 ms at the median (−4 to +6) and −7 ms
  at the tail (−17 to +46), with no pair short. It sends 7 % fewer offers (1.135 M against 1.222 M)
  and 0.03 fewer copies of 1.81.
- At 500 nodes, in the rows half withheld with a 1 Gbps proposer, `NONE` moves the custodians by
  +11 ms at the median (+2 to +21) and +7 ms at the tail (−9 to +20), with no pair short. It sends
  28 % fewer offers (3.62 M against 5.05 M) and 0.15 fewer copies of about 2.3.
- At 500 nodes with liars, in the rows with no column withheld, the custodians' median moves by
  +31 ms at seed 7, 0 at seed 8 and +19 at seed 9; the median change is +19 ms (0 to +31), that of
  the middle seed. In the rows half withheld, the median change is +40 ms (−13 to +71). No node is
  short in either.
- With the columns' `SAMPLE`, at 500 nodes in the rows half withheld, the custodians' tail moves by
  +26 ms at the median (−12 to +28), on seed 8, the middle seed; their median moves by +11 ms; no
  pair is short.
- The rows' `NONE` at 60 nodes leaves row members short on every seed: 1 365, 1 444 and 1 770
  node-blocks in the rows, the rows with liars and the rows half withheld, against 0, 1 and 0.

### [D8] The row pull delay

The decision record's "Decided on 2026-11-14" points here for `[D8]`.

**Conditions.** The figures come from the 60-node runs of the `[D5]` entry (2026-11-13), in its
three row settings: the rows, the rows with liars, and the rows half withheld. The arms
`--row-delay 0`, `0.5` and `2` are compared with `base`'s 1 s. "A row member's 64th cell" is the
time at which a row member holds 64 cells of its row. The rules and the changes since are the
`[D5]` entry's.
- With 2 s the custodians complete later at the median: by 161 ms in the rows, 147 with liars and
  386 half withheld, so by 147 to 386 ms.
- With 0 and 0.5 s the custodians move by −10 to +10 ms at the median, and by −15 to +6 ms at the
  tail.
- With 0.5 s a row member's 64th cell comes sooner at the median: by 47 ms in the rows (on 10 of 10
  seeds), 24 ms half withheld (9 of 10) and 80 ms with liars (10 of 10).
- With liars, over the ten seeds, 0.5 s leaves 154 row members short and 0 s leaves 219, counted
  once per block they are short in, against one with 1 s (on seed 12); up to 12 are short in a
  block. 0 s leaves 2 custodians short on seed 13, against `base`'s 1; 0.5 s leaves 1.
- Without liars, neither leaves any node short.

### [D12] A sampler's reach

The record of `[D12]` cites §1.3's, §4.10's and §6.3's entries. Its own figures follow.

**Conditions.** The cells run `--setting custody --samplers 20 --net bld`: 60 nodes, degree 30, 12
samplers of eight cells, the 1 Gbps proposer, seed 7 unless an item says otherwise, on the draft of
2026-10-23. "Before one sample per peer" is that draft before that day's changes, which made one
sample per peer; "after" is the draft with them. The transport took every write at once
(`--send-buffer 0`). The figures were first written into the text on the main line in spec `0d968d8`
(2026-11-14). The runs predate ties (2026-10-26), v0.9's source at the acknowledgement (2026-11-11)
and the transport (2026-11-15). They were not run again.

- **Why diversity** (honest, three blocks, the floor of one cover and routed requests, before one
  sample per peer): the proposer was asked for 28 of 288 samples, up to 5 of one sampler's 8 in a
  block, and no other peer for more than 2. After, the proposer was asked for none, and no peer for
  more than one of a sampler's samples in a block.
- **The hunt's cost** (half the columns withheld, `--withhold 64`, two blocks) was, after one sample
  per peer, 1.3 to 1.7 asks per sample without routed requests [1.32 with no floor, 1.65 with two
  covers], 3.0 with them [2.96], and 4.2 to 5.2 with the floor of one or two covers as well [5.20
  with two; the record does not give the 4.2]. 380 to 704 requests were passed on over two blocks.
  Before, it was 11 to 12 asks per sample, and 1 813 to 2 042 requests were passed on.
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
- **Rows as a second axis:** for the comparison at 70 links, `toy/sampler_graph.py e` uses the
  graphs of §1.3's entry. Counting half rows takes the samplers left with a sample no link serves
  from 17 % to 7.5 % with 32 row subnets and to 13.5 % with 128. Counting whole rows (FullDAS's
  two-dimensional code) takes them to 3.2 % and 11.0 %. At 16 links, rows barely help [95.7 % to
  90.1 % at best].
