#!/usr/bin/env python3
"""A known answer for protocol-v2.md §6.3's limit on the relations one link may carry, in §4.1's `on_graft`
(`relation_room`, `MAX_RELATIONS`): the pairs of family and colour a link has in any state (relations, the node's own
GRAFTs not yet answered, backoffs) stay at most at the limit. Over it, a GRAFT for a new pair is ignored without an
answer and without penalty, a PRUNE for one sets no backoff, and the node's own upkeep sends no GRAFT for one; a pair the
link already has is handled as before.

    python3 relation_limit_known.py

The check, on a small custody network (8 nodes, seed 7) that is built and published, not run, with node S and one of
its peers p. Each GRAFT is given to S's `on_graft` as if p had sent it, asking S to push p a column family S custodies,
and S's answers to p are recorded:
- (a) with S's limit set to the pairs the link has now, a GRAFT for a family it does not have: no answer, no relation;
- (b) the control: the same limit, a GRAFT for a family and colour the link carries: answered yes again;
- (d) the same limit, S's own GRAFT for a new family (`graft`, as its upkeep calls it): nothing sent, nothing pending;
- (e) the same limit, a PRUNE for a new family: no backoff;
- (c) the control: with no limit, the GRAFT of (a): answered yes, and the relation made;
- penalties: none.
On the document before the limit, (a), (d) and (e) fail.
"""
import math
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


def main():
    sim = build(["--doc", "v2", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7"])
    S = sim.nodes[2]
    ns = S.ns
    COL = ns["type_of"]("column")
    p = min(q for q in S.peers if q != 1)
    carried = {(f, k) for m in ("push_in", "push_out", "grafted_in", "grafted_out")
               for f, ks in ns[m][p][COL].items() for k in ks}
    mine = sorted(sim.custody[S.id])
    new = [f for f in mine if (f, 0) not in carried]
    sent = []
    spec_send = ns["send"]
    ns["send"] = lambda q, m, urgent=False: (sent.append(type(m).__name__) if q == p else None,
                                              spec_send(q, m, urgent))[1]
    pen = []
    spec_pen = ns["penalise"]
    ns["penalise"] = lambda q: (pen.append(q), spec_pen(q))
    print(f"custody network: S = node {S.id} (custody {mine}), p = node {p}; the link carries {sorted(carried)}")

    def graft(fam):
        sent.clear()
        ns["on_graft"](p, ns["Graft"](object_type="column", family=fam, colour=0, direction="IN", answer=False))
        return list(sent), 0 in ns["push_out"][p][COL][fam]

    COL.params.MAX_RELATIONS = len(carried)
    line(f"(a) limit {len(carried)} (full): a GRAFT for column family {new[0]}: answers, relation",
         graft(new[0]), ([], False))
    if carried:
        f0 = next(iter(sorted(carried)))[0]
        got = graft(f0)
        line(f"(b) the same limit: a GRAFT for family {f0}, carried: answered yes", got[0], ["Graft"])
    sent.clear()
    ns["graft"](p, COL, new[1], 0, "IN")
    line(f"(d) the same limit: S's own GRAFT for column family {new[1]}: sent, pending",
         (list(sent), 0 in ns["grafted_in"][p][COL][new[1]]), ([], False))
    ns["on_prune"](p, ns["Prune"](object_type="column", family=new[2], colour=0, direction="IN"))
    line(f"(e) the same limit: a PRUNE for column family {new[2]}: backoff set", bool(ns["backoff"][p][COL][new[2]]),
         False)
    COL.params.MAX_RELATIONS = math.inf
    line(f"(c) no limit: a GRAFT for column family {new[0]}: answers, relation", graft(new[0]), (["Graft"], True))
    line("penalties", pen, [])


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: relation_limit_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
