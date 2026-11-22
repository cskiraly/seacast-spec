#!/usr/bin/env python3
"""A known answer for seacast.md §4.5's ask outside what a node serves (`outside`, `drop_outside`): once a
group's gate is open, a node ignores an ask for an index it does not hold, that is outside its interest as it declared
it to the asker, for a group it has not claimed whole, unless it is a routed request to a forwarding node. It answers
nothing, keeps no standing request and no WANT bit for it, and does not penalise the asker. An ask that comes before
the gate is kept, and tested when the gate opens.

    python3 outside_ask_known.py

The check, on small custody networks (8 nodes, seed 7) that are built and published, not run, with node S and one of
its peers p, each ask given to S's `on_want` as a WANT that p sent:
- (a) a standing WANT for an index of a column S does not custody: S keeps no standing request, and penalises no one;
- (b) the control: the same for a column S custodies, which S does not hold yet: kept as a standing request;
- (c) a routed WANT (hops 1) for a column S does not custody, S's duty toward p being FORWARD: kept, and marked
  routed (`routed_standing`);
- (d) a standing WANT for a column S does not custody, after S claimed it whole (`mine` full, as at K before the
  decode): kept;
- (e) with S's gate held closed, a standing WANT for a column S does not custody: kept; once the gate opens
  (`on_header_validated`, which calls `drop_outside`), it is removed, and a control in S's custody is kept;
- (f) on a network with samplers, a sampler's WANT to S for a column S does not custody: no standing request and no
  bit in the sampler's interest (`want_p`); the control, a column S custodies: both kept;
- (h) on the same network, with S's gate held closed, a sampler's routed WANT (hops 1) for a column S does not
  custody: kept standing if S passed it on (read from S's own sends), and no interest bit, as it is outside S's
  interest; the same once the gate opens (`on_header_validated`);
- (i) the same, with the next peer's queue refusing S's WANT: not kept, no interest bit, and not counted against
  `FORWARD_LIMIT`;
- (j) with S's duty toward the sampler set to `NONE` and S's gate held closed, the sampler's routed WANT (hops 1) for a
  column S does not custody: read as a WANT without hops, so kept standing, unmarked, with its interest bit; once the
  gate opens, removed with its bit.
Then (g): honest runs drop nothing: in a custody run with samplers and routed requests (12 nodes, 25 % samplers, two
blocks) and in a rows run (8 nodes, one block), `on_want` ignores no ask as outside.
(g) prints how many asks reached the test, and how many of them were routed, and fails if the custody run met no
routed request. On the document before the rule, (a), (c), (e), (f), (h) and (i) fail; (j) fails on the document
before hops were read through S's duty.
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


def build(args, run_to=None):
    import run as R
    import sim as SM
    got, spec_run = {}, R.run
    R.run = lambda cfg, out=None: got.setdefault("sim", SM.Sim(cfg))
    try:
        R.main(args)
    finally:
        R.run = spec_run
    sim = got["sim"]
    if run_to is None:
        sim.run(sim.cfg["first"])
        sim.publish(1)
    return sim


def columns(sim, S):
    mine = sim.custody[S.id]
    cols = sorted((sim.gcol[g], g) for g in sim.canonical if sim.gtype.get(g) == "column")
    return [g for c, g in cols if c not in mine], [g for c, g in cols if c in mine]


def kept(ns, g, i, p):
    return p in ns["standing"].get(g, {}).get(i, ())


def custody_cases():
    import wire as Wm
    sim = build(["--doc", "seacast", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7"])
    S = sim.nodes[2]
    ns = S.ns
    p = min(q for q in S.peers if q != 1)
    out_cols, in_cols = columns(sim, S)
    ga, gc, gd, ge = out_cols[:4]
    gh = in_cols[0]
    pen = []
    spec_pen = ns["penalise"]
    ns["penalise"] = lambda q: (pen.append(q), spec_pen(q))
    print(f"custody network: S = node {S.id} (custody {sorted(sim.custody[S.id])}), p = node {p}")
    ns["on_want"](p, [Wm.FlaggedWant(ga, 0, True, 0)])
    line(f"(a) column {sim.gcol[ga]}, a standing WANT outside S's custody: kept, penalised",
         (kept(ns, ga, 0, p), p in pen), (False, False))
    ns["on_want"](p, [Wm.FlaggedWant(gh, 0, True, 0)])
    line(f"(b) column {sim.gcol[gh]} (S's custody), not held: kept", kept(ns, gh, 0, p), True)
    duty = ns["join_sent"][p][ns["type_of_group"](gc)].duty
    ns["on_want"](p, [Wm.FlaggedWant(gc, 0, True, 1)])
    line(f"(c) column {sim.gcol[gc]}, routed (hops 1), S's duty toward p {duty}: kept, marked routed",
         (kept(ns, gc, 0, p), p in ns.get("routed_standing", {}).get(gc, {}).get(0, ())), (True, True))
    n = ns["type_of_group"](gd).index_count(sim.ghdr[gd])
    ns["mine"][gd] = ns["mine"][gd] | ns["bitmap"](set(range(n)))
    ns["on_want"](p, [Wm.FlaggedWant(gd, 0, True, 0)])
    line(f"(d) column {sim.gcol[gd]}, after S claimed it whole: kept", kept(ns, gd, 0, p), True)
    if "drop_outside" not in ns:
        line("(e) the gate held closed, then opened: drop_outside", "not in the document", "present")
    else:
        spec_auth = ns["authenticable"]
        ns["authenticable"] = lambda g: False if g in (ge, in_cols[1]) else spec_auth(g)
        ns["on_want"](p, [Wm.FlaggedWant(ge, 0, True, 0), Wm.FlaggedWant(in_cols[1], 0, True, 0)])
        before = (kept(ns, ge, 0, p), kept(ns, in_cols[1], 0, p))
        ns["authenticable"] = spec_auth
        ns["on_header_validated"](sim.ghdr[ge].block)   # the gate opens: the block's header is validated
        line(f"(e) gate closed: column {sim.gcol[ge]} (outside) and {sim.gcol[in_cols[1]]} (custody) kept; "
             f"gate open (on_header_validated): kept", (before, (kept(ns, ge, 0, p), kept(ns, in_cols[1], 0, p))),
             ((True, True), (False, True)))
    line("penalties in the custody cases", pen, [])


def sampler_cases():
    import wire as Wm
    sim = build(["--doc", "seacast", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7",
                 "--samplers", "50"])
    smp = set(sim.cfg["sampler_ids"])
    S = next(sim.nodes[q] for q in sorted(sim.nodes) if q not in smp and q != 1
             and any(s in sim.nodes[q].peers for s in smp))
    ns = S.ns
    p = min(s for s in smp if s in S.peers)
    out_cols, in_cols = columns(sim, S)
    go, gi = out_cols[0], in_cols[0]
    ns["on_want"](p, [Wm.WantIndex(go, 0), Wm.WantIndex(gi, 0)])
    wp = ns["want_p"][p]
    print(f"custody network with samplers: S = node {S.id} (custody {sorted(sim.custody[S.id])}), p = sampler {p}")
    line(f"(f) sampler p's WANT, column {sim.gcol[go]} (outside S's custody): kept, in p's interest",
         (kept(ns, go, 0, p), go in wp and wp[go].has(0)), (False, False))
    line(f"    control, column {sim.gcol[gi]} (S's custody): kept, in p's interest",
         (kept(ns, gi, 0, p), gi in wp and wp[gi].has(0)), (True, True))
    gr = out_cols[1]
    spec_auth, spec_send, sends = ns["authenticable"], ns["send"], []
    ns["send"] = lambda q, m, urgent=False: (sends.append(type(m).__name__), spec_send(q, m, urgent))[1]
    ns["authenticable"] = lambda g: False if g == gr else spec_auth(g)
    ns["on_want"](p, [Wm.FlaggedWant(gr, 0, True, 1)])
    passed = "Want" in sends                        # S's own WANT one step on, read from its sends
    before = (kept(ns, gr, 0, p), gr in wp and wp[gr].has(0))
    ns["authenticable"] = spec_auth
    ns["on_header_validated"](sim.ghdr[gr].block)
    after = (kept(ns, gr, 0, p), gr in wp and wp[gr].has(0))
    line(f"(h) sampler p's routed WANT (hops 1), column {sim.gcol[gr]} outside S's custody, passed on {passed}: "
         f"kept, in p's interest, before the gate and after it", (before, after),
         ((passed, False), (passed, False)))
    gq = out_cols[2]
    fwd = ns["forwarded"][p][ns["type_of_group"](gq)]
    ns["send"] = lambda q, m, urgent=False: False if type(m).__name__ == "Want" else spec_send(q, m, urgent)
    ns["on_want"](p, [Wm.FlaggedWant(gq, 0, True, 1)])
    ns["send"] = spec_send
    line(f"(i) the same for column {sim.gcol[gq]}, the next queue refusing S's WANT: kept, in p's interest, "
         f"counted against FORWARD_LIMIT", (kept(ns, gq, 0, p), gq in wp and wp[gq].has(0), ns["forwarded"][p][ns["type_of_group"](gq)] > fwd),
         (False, False, False))
    import copy
    gn, COL = out_cols[3], ns["type_of_group"](out_cols[3])
    spec_join = ns["join_sent"][p][COL]
    j = copy.copy(spec_join)
    j.duty = "NONE"
    ns["join_sent"][p][COL] = j
    ns["authenticable"] = lambda g: False if g == gn else spec_auth(g)
    ns["on_want"](p, [Wm.FlaggedWant(gn, 0, True, 1)])
    marked = p in ns["routed_standing"].get(gn, {}).get(0, ())
    before = (kept(ns, gn, 0, p), marked, gn in wp and wp[gn].has(0))
    ns["authenticable"] = spec_auth
    ns["on_header_validated"](sim.ghdr[gn].block)
    after = (kept(ns, gn, 0, p), gn in wp and wp[gn].has(0))
    ns["join_sent"][p][COL] = spec_join
    line(f"(j) S's duty toward p NONE, gate closed: p's routed WANT (hops 1), column {sim.gcol[gn]} outside S's "
         f"custody: kept, marked routed, in p's interest; after the gate: kept, in p's interest", (before, after),
         ((True, False, True), (False, False)))


def honest_runs():
    import run as R
    import sim as SM
    for label, args in (("custody, 25 % samplers, two blocks",
                         ["--doc", "seacast", "--setting", "custody", "--nodes", "12", "--degree", "8", "--msgs", "2",
                          "--seed", "7", "--samplers", "25"]),
                        ("rows, one block", ["--doc", "seacast", "--setting", "rows", "--nodes", "8", "--degree", "6",
                                             "--msgs", "1", "--seed", "7"])):
        got, spec_run = {}, R.run
        R.run = lambda cfg, out=None: got.setdefault("sim", SM.Sim(cfg))
        try:
            R.main(args)
        finally:
            R.run = spec_run
        sim = got["sim"]
        dropped, tested, routed_n = [0], [0], [0]
        for node in sim.nodes.values():
            ns = node.ns
            if "outside" not in ns:
                continue
            spec_out = ns["outside"]

            def counted(p, g, i, routed, spec_out=spec_out, ns=ns):
                r = spec_out(p, g, i, routed)
                tested[0] += 1
                routed_n[0] += bool(routed)
                if r and not ns["peer_has"][p][g].has(i):
                    dropped[0] += 1
                return r
            ns["outside"] = counted
        for k in range(sim.cfg["msgs"]):            # the blocks, published as run.py's schedule would
            sim.run(sim.cfg["first"] + k * sim.cfg["gap"])
            sim.publish(k + 1)
        sim.run(sim.cfg["first"] + sim.cfg["gap"] * (sim.cfg["msgs"] + 1))
        print(f"    {label}: asks tested {tested[0]}, of them routed {routed_n[0]}")
        global bad
        bad += tested[0] == 0                       # a control that tested nothing would show nothing
        bad += label.startswith("custody") and routed_n[0] == 0   # nor one that met no routed request
        line(f"(g) {label}: asks ignored as outside", dropped[0], 0)


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: outside_ask_known.py")
    custody_cases()
    sampler_cases()
    honest_runs()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
