#!/usr/bin/env python3
"""A known answer for protocol-v2.md §4.5's serving budget (`SERVE_BUDGET`, `served_hb`, `offered_to`): a node answers
one peer at most `SERVE_BUDGET` chunks a heartbeat across groups, not counting the answers to asks on its own offers or
to a claim's probe; an ask over it is refused, and a standing request's answer dropped, without penalty; the budget
starts again at each heartbeat. The node records its offers when its writer writes them (`noted`, `offers_in`), so an
owed offer counts as one.

    python3 serve_budget_known.py

The check, on a small custody network (8 nodes, seed 7) whose block has run two seconds, with node S and one of its
peers p, and S's budget set to two. Each ask is given to S's `on_want` as a WANT that p sent, for cells S holds and p
does not, each of a different column:
- (a) three asks, none on an offer of S's: two answered, the third refused;
- (b) the same heartbeat, S sends p an offer of a cell as `announce` does, and its writer writes it; p's ask for it:
  answered;
- (c) the same, for an offer owed (`owe`, as a full queue makes it), which the writer writes on its own: answered;
- (d) the same heartbeat, a standing request of p's whose chunk S holds (`serve_standing`): its answer dropped;
- (e) the same heartbeat, p's kept probe of S's claim (`serve_waiting_probe`): answered;
- (f) after the heartbeat (`on_heartbeat`), two of (a)'s asks again: both answered;
- (g) one frame asking an id twice: one answer, the budget, the stock count and `served` charged once;
- (h) with one unit of the budget left, an id not on an offer at the stock limit of three answers: refused without
  spending the budget; the next ask, for another id not on an offer, is answered with that unit;
- (i) after the heartbeat, with one unit of the group's limit (`SERVE_LIMIT`) left, one frame with a plain ask and
  then p's probe of S's claim, for the same id, and one with the two the other way round: one answer each, the
  probe's exemption taken (`probe_answers`), and no budget spent, in both;
- (j) with one unit of a group's limit left, one frame with a plain ask of index A, a plain ask of index B of the
  same group, and p's probe of A: A answered, as the probe, and B refused at the limit, as without the probe; then
  A's answer queued, p's holding of A arriving before the write, and the writer: A written all the same, as a
  probe's answer is;
- (k) one frame with a standing ask of an index S lacks in its custody, and p's probe of it, which does not pass as
  one (S claims no such index): the standing request kept;
- penalties: none.
On the document before the budget, (a), (d) and (g) fail, and (b) and (c) have no record of S's offers; (h) fails if
the budget is charged before the stock limit is read; (i) fails, in its first order, on the document before an id
asked twice in a frame kept a probe among its asks; (j) and (k) fail on the document whose probe dropped a plain ask
of its index before reading whether it passed.
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
    cells = []                                      # one cell a column: S holds it, p does not
    for g in sorted(ns["chunks"], key=str):
        if sim.gtype.get(g) == "column":
            i = next((i for i in sorted(ns["chunks"][g]) if not ns["peer_has"][p][g].has(i)), None)
            if i is not None:
                cells.append((g, i))
    pen = []
    spec_pen = ns["penalise"]
    ns["penalise"] = lambda q: (pen.append(q), spec_pen(q))
    print(f"custody network, block run: S = node {S.id}, p = node {p}; {len(cells)} columns with a cell S holds "
          f"and p does not")
    ns["SERVE_BUDGET"] = 2

    def answered(gi):
        return len(ns["on_want"](p, [Wm.WantIndex(*gi)]))

    def write_all():                                # S's writer to p, until nothing is left to write
        for _ in range(50):
            e = ns["next_to_send"](p)
            if e is None or e == ns.get("WAIT"):
                return
    line("(a) budget 2: three asks, distinct columns, none on an offer: answered",
         [answered(c) for c in cells[:3]], [1, 1, 0])
    if "offered_to" not in ns:
        line("(b), (c) a record of S's offers to p (offered_to)", "not in the document", "present")
    else:
        g, i = cells[3]                             # the offer as announce sends it, past its filter
        ns["send"](p, ns["Have"](group=g, bits=ns["bitmap"]({i}), offer=True, claim_all=False, complete=False),
                   urgent=False)
        write_all()
        line("(b) an offer sent and written; p's ask on it: recorded, answered",
             (ns["offered_to"][p][g].has(i), answered(cells[3])), (True, 1))
        g, i = cells[4]
        ns["owe"](p, g, ns["bitmap"]({i}))
        write_all()
        line("(c) an offer owed and written; p's ask on it: recorded, answered",
             (ns["offered_to"][p][g].has(i), answered(cells[4])), (True, 1))
    g, i = cells[5]
    ns["standing"][g][i].add(p)
    before = len(ns["queue"][p].normal)
    ns["serve_standing"](g, i)
    queued = len(ns["queue"][p].normal) > before or ns["owed_answers"][p][g].has(i)
    line("(d) a standing request whose chunk S holds, the budget spent: answer queued or owed", queued, False)
    g, i = cells[6]
    ns["probe_waiting"][g][p] = i
    before = len(ns["queue"][p].normal)
    ns["serve_waiting_probe"](g, i)
    line("(e) p's kept probe, the budget spent: answer queued", len(ns["queue"][p].normal) > before, True)
    ns["on_heartbeat"]()
    line("(f) after the heartbeat, two asks of (a) again: answered", [answered(c) for c in cells[:2]], [1, 1])
    ns["on_heartbeat"]()
    g, i = cells[2]
    mid = ns["resolve"](Wm.WantIndex(g, i))
    hb0, sc0, sv0 = ns["served_hb"][p], ns["serve_count"][p][mid], ns["served"][p][g]
    got = len(ns["on_want"](p, [Wm.WantIndex(g, i), Wm.WantIndex(g, i)]))
    line("(g) one frame asking an id twice: answers; budget, stock count, served charged",
         (got, ns["served_hb"][p] - hb0, ns["serve_count"][p][mid] - sc0, ns["served"][p][g] - sv0), (1, 1, 1, 1))
    g, i = cells[0]                                 # (g) spent one unit: one is left
    mid = ns["resolve"](Wm.WantIndex(g, i))
    ns["serve_count"][p][mid] = ns["GOSSIP_RETRANSMISSION"]
    hb0 = ns["served_hb"][p]
    got = (ns["SERVE_BUDGET"] - hb0, answered(cells[0]), ns["served_hb"][p] - hb0, answered(cells[1]),
           ns["served_hb"][p] - hb0)
    line("(h) one unit left: an id at the stock limit: answered, budget spent; then another id: answered, budget "
         "spent", got, (1, 0, 0, 1, 1))
    ns["on_heartbeat"]()
    got = []
    for c, first_probe in ((cells[2], False), (cells[5], True)):   # no probe of these groups yet
        g, i = c
        T = ns["type_of_group"](g)
        spec_lim, T.params.SERVE_LIMIT = T.params.SERVE_LIMIT, ns["served"][p][g] + 1   # one unit left
        hb0 = ns["served_hb"][p]
        plain, probe = Wm.WantIndex(g, i), Wm.FlaggedWant(g, i, False, 0, True)
        n = len(ns["on_want"](p, [probe, plain] if first_probe else [plain, probe]))
        T.params.SERVE_LIMIT = spec_lim
        got.append((n, ns["probe_answers"][p][g].has(i), ns["served_hb"][p] - hb0))
    line("(i) one unit of the group's limit left: a plain ask and a probe of the same id in one frame, then the other "
         "order: answers, probe's exemption taken, budget spent", got, [(1, True, 0), (1, True, 0)])
    ns["on_heartbeat"]()
    def fresh(g, i):                                # an id p lacks and the cases above never asked
        return (not ns["peer_has"][p][g].has(i) and (g, i) not in cells
                and ns["serve_count"][p][ns["resolve"](Wm.WantIndex(g, i))] == 0)
    g, a, b = next((g, *two) for g in sorted(ns["chunks"], key=str) if sim.gtype.get(g) == "column"
                   and not ns["probe_served"][p][g]
                   and len(two := [i for i in sorted(ns["chunks"][g]) if fresh(g, i)][:2]) == 2)
    T = ns["type_of_group"](g)
    spec_lim, T.params.SERVE_LIMIT = T.params.SERVE_LIMIT, ns["served"][p][g] + 1   # one unit left
    out = ns["on_want"](p, [Wm.WantIndex(g, a), Wm.WantIndex(g, b), Wm.FlaggedWant(g, a, False, 0, True)])
    T.params.SERVE_LIMIT = spec_lim
    ns["sent_to"][p][g].clear(a)
    ns["respond"](p, [], out, [])
    ns["peer_has"][p][g].bits |= ns["bitmap"]({a})  # p's holding of A, from elsewhere, before the write
    write_all()
    line(f"(j) one unit of the group's limit left: plain A ({a}), plain B ({b}), probe A in one frame: indices "
         f"answered; A written after p's holding of it, as a probe's answer is",
         ([c.index for c in out], ns["sent_to"][p][g].has(a)), ([a], True))
    g, i = next((g2, i) for g2 in sorted(ns["chunks"], key=str) if sim.gtype.get(g2) == "column" and g2 != g
                for i in sorted(ns["chunks"][g2]) if fresh(g2, i) and ns["our_interest_for"](p, g2).has(i))
    spec_chunk = ns["chunks"][g].pop(i)             # S lacks index i of a column in its custody
    ns["mine"][g].clear(i)
    ns["on_want"](p, [Wm.FlaggedWant(g, i, True, 0), Wm.FlaggedWant(g, i, False, 0, True)])
    kept = p in ns["standing"][g].get(i, ())
    ns["standing"][g].get(i, set()).discard(p)
    ns["chunks"][g][i] = spec_chunk
    ns["mine"][g].set(i)
    line(f"(k) a standing ask of index {i}, which S lacks, and p's probe of it, which does not pass as one: the "
         f"standing request kept", kept, True)
    line("penalties", pen, [])


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: serve_budget_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
