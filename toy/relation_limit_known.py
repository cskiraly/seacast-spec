#!/usr/bin/env python3
"""A known answer for protocol-v2.md §6.3's limit on the relations one link may carry, in §4.1's `on_graft`
(`relation_room`, `MAX_RELATIONS`): the pairs of family and colour a link has in any state (relations, the node's own
GRAFTs not yet answered, backoffs not yet run out, and its GRAFTs and PRUNEs still owed) stay at most at the limit.
Over it, a GRAFT for a new pair is ignored without an answer and without penalty, a PRUNE for one sets no backoff, and
the node's own upkeep sends no GRAFT for one; a pair the link already has is handled as before.

    python3 relation_limit_known.py

The check, on a small custody network (8 nodes, seed 7) that is built and published, not run, with node S and one of
its peers p. Each GRAFT is given to S's `on_graft` as if p had sent it, asking S to push p a column family S custodies,
and S's answers to p are recorded:
- (a) with S's limit set to the pairs the link has now, a GRAFT for a family it does not have: no answer, no relation;
- (b) the control: the same limit, a GRAFT for a family and colour the link carries: answered yes again;
- (d) the same limit, S's own GRAFT for a new family (`graft`, as its upkeep calls it): nothing sent, nothing pending;
- (e) the same limit, with backoffs of five seconds, a PRUNE for a new family: no backoff; the control, a PRUNE for
  a pair the link carries: its backoff set;
- (c) the control: with no limit, the GRAFT of (a): answered yes, and the relation made;
- (f) what counts toward the limit, read from `relation_room` with the limit one above what the link has: a backoff
  not yet run out counts, one run out does not, and a PRUNE of S's still owed to p counts;
- (g) with no limit and (f)'s run-out backoff still stored, p's PRUNE for another family: the run-out backoff is gone,
  and with the toy's `PRUNE_BACKOFF` of zero the PRUNE stores none; the control, the same with a `PRUNE_BACKOFF` of
  five seconds: its backoff is stored;
- (h) S's upkeep (`maintain_relations`) with p offered as the only candidate for every family and colour: with the
  limit at the pairs the link has, no GRAFT to p for a pair new to the link; the control, with no limit: such
  GRAFTs to p;
- penalties: none.
On the document before the limit, (a), (d), (e), (f) and (h) fail; (g) fails on the document before run-out backoffs
were dropped.
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
    spec_bo, COL.params.PRUNE_BACKOFF = COL.params.PRUNE_BACKOFF, 5.0   # a backoff a PRUNE would store
    ns["on_prune"](p, ns["Prune"](object_type="column", family=new[2], colour=0, direction="IN"))
    ctl = None
    if carried:
        f0, k0 = sorted(carried)[0]
        ns["on_prune"](p, ns["Prune"](object_type="column", family=f0, colour=k0, direction="IN"))
        ctl = any(t > ns["now"] for t in ns["backoff"][p][COL][f0].values())
    COL.params.PRUNE_BACKOFF = spec_bo
    line(f"(e) the same limit, backoffs of 5 s: a PRUNE for column family {new[2]}: backoff set; the control, a "
         f"PRUNE for a pair the link carries: backoff set", (bool(ns["backoff"][p][COL][new[2]]), ctl), (False, True))
    COL.params.MAX_RELATIONS = math.inf
    line(f"(c) no limit: a GRAFT for column family {new[0]}: answers, relation", graft(new[0]), (["Graft"], True))
    if "relation_room" in ns:
        have = {(f, k) for m in ("push_in", "push_out", "grafted_in", "grafted_out")
                for f, ks in ns[m][p][COL].items() for k in ks}
        COL.params.MAX_RELATIONS = len(have) + 1
        x, y = new[3], new[4]
        room = lambda: ns["relation_room"](p, COL, y, 0)
        r0 = room()
        ns["backoff"][p][COL][x][(0, "IN")] = ns["now"] + 10.0
        r1 = room()
        ns["backoff"][p][COL][x][(0, "IN")] = ns["now"] - 1.0
        r2 = room()
        ns["owed_relations"][p].append(ns["Prune"](object_type="column", family=x, colour=0, direction="IN"))
        r3 = room()
        ns["owed_relations"][p].pop()
        COL.params.MAX_RELATIONS = math.inf
        line("(f) one place left: room; with a backoff running; with it run out; with a PRUNE of S's owed",
             (r0, r1, r2, r3), (True, False, True, False))
        z, w = new[5], new[6]
        ns["on_prune"](p, ns["Prune"](object_type="column", family=z, colour=0, direction="IN"))
        gone = x not in ns["backoff"][p][COL]           # the run-out backoff, and the entry it emptied
        none = not any(ns["backoff"][p][COL][z].values())
        spec_bo, COL.params.PRUNE_BACKOFF = COL.params.PRUNE_BACKOFF, 5.0
        ns["on_prune"](p, ns["Prune"](object_type="column", family=w, colour=0, direction="IN"))
        COL.params.PRUNE_BACKOFF = spec_bo
        stored = ns["backoff"][p][COL][w].get((0, "OUT"), 0.0) > ns["now"]
        line(f"(g) p's PRUNE for family {z}: family {x}'s run-out backoff and its entry gone, none stored at a "
             f"backoff of 0; at 5 s, "
             f"family {w}'s stored", (gone, none, stored), (True, True, True))
        spec_cand = ns["candidates"]
        ns["candidates"] = lambda T, fam, c, d: [p]     # p, for every family and colour the upkeep looks at
        held = {(f, k) for m in ("push_in", "push_out", "grafted_in", "grafted_out")
                for f, ks in ns[m][p][COL].items() for k in ks}
        held |= {(f, k) for f, bo in ns["backoff"][p][COL].items() for (k, dd), t in bo.items() if t > ns["now"]}
        counts, grafts = [], []
        ns["send"] = lambda q, m, urgent=False: (grafts.append((m.family, m.colour)) if q == p and
                                                  type(m).__name__ == "Graft" else None, spec_send(q, m, urgent))[1]
        for lim in (len(held), math.inf):
            COL.params.MAX_RELATIONS = lim
            grafts.clear()
            ns["maintain_relations"](COL)
            counts.append(len([g for g in grafts if g not in held]))   # GRAFTs for pairs new to the link
            for m in ("grafted_in", "grafted_out"):     # undo the GRAFTs pending, for the next pass
                for f in list(ns[m][p][COL]):
                    ns[m][p][COL][f] = {k for k in ns[m][p][COL][f] if (f, k) in held}
        ns["candidates"] = spec_cand
        COL.params.MAX_RELATIONS = math.inf
        line(f"(h) the upkeep with p the only candidate: GRAFTs to p for pairs new to the link, at the limit "
             f"{len(held)} and with no limit", (counts[0], counts[1] > 0), (0, True))
    else:
        line("(f) relation_room", "not in the document", "present")
    line("penalties", pen, [])


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: relation_limit_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
