#!/usr/bin/env python3
"""A known answer for protocol-v2.md §4.5's two bounds on a WANT: an index the group has not, once its count is
known, and a group beyond the asker's limit of unknown groups (`admitted_group`, protocol.md §8.2's
`MAX_PENDING_GROUPS`). Either is ignored without penalty, and keeps no standing request.

    python3 want_bounds_known.py

The check, on a small custody network (8 nodes, seed 7) that is built and published, not run, with node S and one of
its peers p, each ask given to S's `on_want` as a standing WANT that p sent, for columns S custodies and does not hold:
- (a) a column whose header S holds (`hdr`), at an index beyond its count: no standing request; the control, index 0
  of the same column: kept;
- (b) with p's limit of unknown groups set to one, two columns S knows nothing of yet: the first kept, the second
  ignored; a third column, whose header S holds, kept whatever the limit;
- penalties: none.
On the document before the bounds, (a) and (b) fail.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
bad = 0


def line(what, got, want):
    global bad
    ok = got == want
    bad += not ok
    print(f"{what}: {got}" + ("" if ok else f"  <-- FAIL, want {want}"))


def build(args):
    import run as R
    import sim as SM
    got, spec_run = {}, R.run
    R.run = lambda cfg, out=None: got.setdefault("sim", SM.Sim(cfg))
    try:
        R.main(args)
    finally:
        R.run = spec_run
    sim = got["sim"]
    sim.run(sim.cfg["first"])
    sim.publish(1)
    return sim


def kept(ns, g, i, p):
    return p in ns["standing"].get(g, {}).get(i, ())


def main():
    import wire as Wm
    sim = build(["--doc", "v2", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7"])
    S = sim.nodes[2]
    ns = S.ns
    p = min(q for q in S.peers if q != 1)
    mine = sim.custody[S.id]
    cols = [g for c, g in sorted((sim.gcol[g], g) for g in sim.canonical if sim.gtype.get(g) == "column")
            if c in mine]
    ga, gb, gc, gd = cols[:4]
    pen = []
    spec_pen = ns["penalise"]
    ns["penalise"] = lambda q: (pen.append(q), spec_pen(q))
    print(f"custody network: S = node {S.id} (custody {sorted(mine)}), p = node {p}")
    ns["hdr"][ga] = sim.ghdr[ga]
    n = ns["type_of_group"](ga).index_count(sim.ghdr[ga])
    ns["on_want"](p, [Wm.FlaggedWant(ga, n, True, 0), Wm.FlaggedWant(ga, 0, True, 0)])
    line(f"(a) column {sim.gcol[ga]}, count {n}: index {n} kept; index 0 kept",
         (kept(ns, ga, n, p), kept(ns, ga, 0, p)), (False, True))
    ns["MAX_PENDING_GROUPS"] = 1
    ns["hdr"][gd] = sim.ghdr[gd]
    ns["on_want"](p, [Wm.FlaggedWant(gb, 0, True, 0), Wm.FlaggedWant(gc, 0, True, 0), Wm.FlaggedWant(gd, 0, True, 0)])
    line(f"(b) limit 1: unknown columns {sim.gcol[gb]} and {sim.gcol[gc]} kept, known column {sim.gcol[gd]} kept",
         (kept(ns, gb, 0, p), kept(ns, gc, 0, p), kept(ns, gd, 0, p)), (True, False, True))
    line("penalties", pen, [])


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: want_bounds_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
