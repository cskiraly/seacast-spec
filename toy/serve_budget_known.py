#!/usr/bin/env python3
"""A known answer for protocol-v2.md §4.5's serving budget (`SERVE_BUDGET`, `served_hb`, `offered_to`): a node answers
one peer at most `SERVE_BUDGET` chunks a heartbeat across groups, not counting the answers to asks on its own offers or
to a claim's probe; asks over it are refused without penalty, and the budget starts again at each heartbeat.

    python3 serve_budget_known.py

The check, on a small custody network (8 nodes, seed 7) whose block has run two seconds, with node S and one of its
peers p, and S's budget set to two. Each ask is given to S's `on_want` as a WANT that p sent, for cells S holds and p
does not:
- (a) three asks, none on an offer of S's: two answered, the third refused;
- (b) the same heartbeat, an ask for a cell S offered p (`offered_to`): answered;
- (c) after the heartbeat (`on_heartbeat`), two more asks: both answered;
- penalties: none.
On the document before the budget, (a) fails, and (b) has no record of S's offers.
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


def main():
    import run as R
    import sim as SM
    import wire as Wm
    got, spec_run = {}, R.run
    R.run = lambda cfg, out=None: got.setdefault("sim", SM.Sim(cfg))
    try:
        R.main(["--doc", "v2", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7"])
    finally:
        R.run = spec_run
    sim = got["sim"]
    sim.run(sim.cfg["first"])
    sim.publish(1)
    sim.run(sim.cfg["first"] + 2.0)                 # the block has completed; its groups are live
    S = sim.nodes[2]
    ns = S.ns
    p = min(q for q in S.peers if q != 1)
    cells = [(g, i) for g in sorted(ns["chunks"], key=str) if sim.gtype.get(g) == "column"
             for i in sorted(ns["chunks"][g]) if not ns["peer_has"][p][g].has(i)][:6]
    pen = []
    spec_pen = ns["penalise"]
    ns["penalise"] = lambda q: (pen.append(q), spec_pen(q))
    print(f"custody network, block run: S = node {S.id}, p = node {p}; {len(cells)} cells S holds and p does not")
    ns["SERVE_BUDGET"] = 2

    def answered(gi):
        return len(ns["on_want"](p, [Wm.WantIndex(*gi)]))

    line("(a) budget 2: three asks, none on an offer: answered", [answered(c) for c in cells[:3]], [1, 1, 0])
    if "offered_to" in ns:
        g, i = cells[3]
        ns["offered_to"][p][g] = ns["offered_to"][p][g] | ns["bitmap"]({i})
        line("(b) the same heartbeat, an ask for a cell S offered p: answered", answered(cells[3]), 1)
    else:
        line("(b) a record of S's offers to p (offered_to)", "not in the document", "present")
    ns["on_heartbeat"]()
    line("(c) after the heartbeat, two more asks: answered", [answered(c) for c in cells[4:6]], [1, 1])
    line("penalties", pen, [])


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: serve_budget_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
