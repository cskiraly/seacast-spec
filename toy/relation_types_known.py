#!/usr/bin/env python3
"""A known answer for protocol-v2.md §2's rule on object types a link has not joined, in §4.1's code (`runs_type`,
`joined`): a JOIN for an object type the node does not run, and a GRAFT or a PRUNE for one the link has not joined,
leave no state, draw no answer and no penalty.

    python3 relation_types_known.py

The check, on a small rows network (8 nodes, seed 7, columns and rows, `--upkeep on`, so that the links are the JOINs'
`links(T)`) that is built and published, not run, with node S and one of its peers p, the link having JOINs both
ways for both types. Each message is given to S's own
handler as if p had sent it, and S's sends to p are recorded:
- (a) a JOIN for an object type S does not run: nothing stored in `join_recv`, no JOIN sent back;
- (b) with p's JOIN for rows taken back (the link has not joined rows), a GRAFT for a row family: no relation, no
  GRAFT pending, nothing sent;
- (c) the same link, with backoffs of five seconds, a PRUNE for that family: no backoff set; the control, a PRUNE
  for a column family the link has joined: its backoff set;
- (d) the control: a GRAFT for a column family the link has joined is handled: S answers it;
- (e) with S's own JOIN for columns owed to a second peer (not yet queued), that peer's GRAFT for a column family:
  ignored, as the link is not yet one of `links(T)`;
- (f) a WANT for a cell of the row S serves, on the link of (b), which has not joined rows: ignored, no standing
  request, no error;
- (g) the control: with only S's JOIN for rows owed to the second peer, its GRAFT for a column family: answered;
- (h) from a third peer whose JOIN for columns is taken back (the link has joined rows only), given to S's
  `on_frame` with the document's own handlers, since chunks and holdings are taken on any link (an answer to a row
  WANT, and its acknowledgement, can name the cell's column):
  - a cell that names its column group: verified, stored, and acknowledged to that peer with a holding;
  - a copy S wrote to that peer (its room in flight), and the peer's holding of it: the room freed;
  - the same copy written again, as a probe's answer is whatever the peer holds, and the same holding, whose bit
    is no longer new: the room freed again;
  - a copy of a column's cell naming an index beyond the header's count: rejected and counted against the sender,
    without an error;
  and from a fourth peer with both JOINs taken back: a cell stored, and its holding freeing the room;
- (i) a holding of a column group that claims it whole (`claim_all`), from the third peer: kept in `peer_has` with
  its claim, but the peer is not a claimant S would probe (`claims`), as the probe is a WANT that link ignores;
  the control, the same from p, whose link joined columns: a claimant.
On the document before the rule, (a), (b), (c), (e) and (f) fail; on the documents that tested chunks and holdings
for the link's types, (h) fails; before a repeated bit freed the room, (h)'s third part fails; before the toy's
level 1 checked a cell's index, (h)'s fourth part raises; before a claim needed a joined link, (i) fails.
"""
import copy as C
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
    sim = build(["--doc", "v2", "--setting", "rows", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7",
                 "--upkeep", "on"])
    S = sim.nodes[2]
    ns = S.ns
    COL, ROW = ns["type_of"]("column"), ns["type_of"]("row")
    p = next(q for q in sorted(S.peers) if q != 1 and ROW in ns["join_recv"][q] and ROW in ns["join_sent"][q]
             and COL in ns["join_recv"][q] and COL in ns["join_sent"][q])
    sent = []
    spec_send = ns["send"]
    ns["send"] = lambda q, m, urgent=False: (sent.append((q, type(m).__name__)) if q == p else None,
                                              spec_send(q, m, urgent))[1]
    pen = []
    spec_pen = ns["penalise"]
    ns["penalise"] = lambda q: (pen.append(q), spec_pen(q))
    print(f"rows network: S = node {S.id}, p = node {p}")

    before = set(ns["join_recv"][p])
    try:
        ns["on_join"](p, ns["Join"](object_type="unknown", interest="ALL", custody_count=0, duty="FORWARD",
                                    colours=1))
        got = (set(ns["join_recv"][p]) - before == set(), [m for q, m in sent])
    except Exception as e:                  # the document before the rule looks the type up and fails
        got = f"{type(e).__name__}: {e}"
    line("(a) a JOIN for an object type S does not run: nothing stored, nothing sent", got, (True, []))

    del ns["join_recv"][p][ROW]
    fam = next(iter(sim.gsub.values()), 0)
    sent.clear()
    ns["on_graft"](p, ns["Graft"](object_type="row", family=fam, colour=0, direction="IN", answer=False))
    rel = (0 in ns["push_out"][p][ROW][fam], 0 in ns["push_in"][p][ROW][fam],
           0 in ns["grafted_out"][p][ROW][fam], 0 in ns["grafted_in"][p][ROW][fam])
    line(f"(b) the link has not joined rows: a GRAFT for row family {fam}: relation or pending GRAFT, sent",
         (any(rel), [m for q, m in sent]), (False, []))
    spec_bo = (ROW.params.PRUNE_BACKOFF, COL.params.PRUNE_BACKOFF)
    ROW.params.PRUNE_BACKOFF = COL.params.PRUNE_BACKOFF = 5.0   # a backoff a PRUNE would store
    ns["on_prune"](p, ns["Prune"](object_type="row", family=fam, colour=0, direction="IN"))
    cf = sim.gcol[next(g for g in sim.canonical if sim.gtype.get(g) == "column")]
    ns["on_prune"](p, ns["Prune"](object_type="column", family=cf, colour=0, direction="IN"))
    ROW.params.PRUNE_BACKOFF, COL.params.PRUNE_BACKOFF = spec_bo
    line(f"(c) the same link, backoffs of 5 s: a PRUNE for row family {fam}: backoff set; the control, column "
         f"family {cf}, joined: backoff set", (bool(ns["backoff"][p][ROW][fam]),
                                               ns["backoff"][p][COL][cf].get((0, "OUT"), 0.0) > ns["now"]),
         (False, True))

    cfam = sim.gcol[next(g for g in sim.canonical if sim.gtype.get(g) == "column")]
    sent.clear()
    ns["on_graft"](p, ns["Graft"](object_type="column", family=cfam, colour=0, direction="IN", answer=False))
    line(f"(d) control: a GRAFT for column family {cfam}, joined: answered", bool(sent), True)

    p2 = next(q for q in sorted(S.peers) if q not in (1, p) and COL in ns["join_recv"][q]
              and COL in ns["join_sent"][q])
    ns["owed_relations"][p2].append(ns["join_sent"][p2][COL])
    rel = lambda: any(0 in ns[m][p2][COL][cfam] for m in ("push_out", "push_in", "grafted_out", "grafted_in"))
    sent.clear()
    ns["send"] = lambda q, m, urgent=False: (sent.append((q, type(m).__name__)) if q == p2 else None,
                                              spec_send(q, m, urgent))[1]
    ns["on_graft"](p2, ns["Graft"](object_type="column", family=cfam, colour=0, direction="IN", answer=False))
    line(f"(e) S's JOIN to node {p2} owed: its GRAFT for column family {cfam}: relation, sent",
         (rel(), [m for q, m in sent]), (False, []))
    ns["owed_relations"][p2].clear()

    import wire as Wm
    rg = next(g for g, sub in sim.gsub.items() if sub == S.row_subnet)   # the row S serves, its own subnet's
    try:
        ns["on_want"](p, [Wm.FlaggedWant(rg, 0, True, 0)])
        got = p in ns["standing"].get(rg, {}).get(0, ())
    except Exception as e:
        got = f"{type(e).__name__}: {e}"
    line("(f) a WANT for a cell of S's own row, the link not joined for rows: standing request kept", got, False)

    ns["owed_relations"][p2].append(ns["join_sent"][p2][ROW])
    sent.clear()
    ns["on_graft"](p2, ns["Graft"](object_type="column", family=cfam, colour=0, direction="IN", answer=False))
    answered = bool(sent) or any(type(m).__name__ == "Graft" for m in ns["owed_relations"][p2])   # owed behind
    ns["owed_relations"][p2].clear()                #   the JOIN, as every later relation message is (§4.1)
    line(f"(g) control: S's JOIN for rows owed to node {p2}, its GRAFT for column family {cfam}: answered (sent "
         f"or owed)", answered, True)

    src = sim.nodes[1].ns                           # the source holds every cell from its publish
    cols = [g for g in sorted(src["chunks"], key=str) if sim.gtype.get(g) == "column" and src["chunks"][g]]
    cg = cols[0]
    f = src["chunks"][cg][min(src["chunks"][cg])]
    both = [q for q in sorted(S.peers) if q not in (1, p, p2) and all(T in ns["join_recv"][q] and T in
            ns["join_sent"][q] for T in (COL, ROW))]
    if len(both) < 2:
        line("(h) two more peers with both types joined", len(both), ">= 2")
    else:
        p3, p4 = both[:2]
        del ns["join_recv"][p3][COL]
        del ns["join_recv"][p4][COL]
        del ns["join_recv"][p4][ROW]
        to = []
        ns["send"] = lambda q, m, urgent=False: (to.append((q, m)), spec_send(q, m, urgent))[1]
        bitmap = ns["bitmap"]

        def holding(g, i, claim=False):
            hb = Wm.HaveBitmap(group=g, bits=bitmap({i}))
            hb.claim_all = claim
            return Wm.Frame(Wm.Entry(control=Wm.IDONTWANT(hb)))

        def stored(g, i):
            return ns["received"][g].has(i)

        def acked(q, g):
            return any(r == q and type(m).__name__ == "Have" and m.group == g and not m.offer for r, m in to)

        def written(q, ch):                         # S's writer took room for ch and wrote it to q
            ns["in_flight"] += 1
            ns["track_in_flight"](q, ch, 1)

        def room(q, ch):
            return (q, ch.group, ch.index) in ns["sent"]

        try:
            ns["on_frame"](p3, Wm.Frame(Wm.Entry(chunk=f)))
            got = (stored(cg, f.index), acked(p3, cg))
        except Exception as e:
            got = f"{type(e).__name__}: {e}"
        line(f"(h) node {p3}, rows only joined: a cell naming column {sim.gcol[cg]}: stored, acknowledged to it",
             got, (True, True))
        g2 = cols[1]
        f2 = src["chunks"][g2][min(src["chunks"][g2])]
        written(p3, f2)
        before = (room(p3, f2), ns["in_flight"])
        ns["on_frame"](p3, holding(g2, f2.index))
        line(f"(h) node {p3}: S's copy of a cell of column {sim.gcol[g2]} in flight, then the peer's holding of it: "
             f"room held before, held after, in flight back", (before[0], room(p3, f2), ns["in_flight"] == before[1] - 1),
             (True, False, True))
        written(p3, f2)
        before = (room(p3, f2), ns["in_flight"])
        ns["on_frame"](p3, holding(g2, f2.index))
        line(f"(h) node {p3}: the same copy written again, the same holding, its bit not new: room held before, "
             f"held after, in flight back", (before[0], room(p3, f2), ns["in_flight"] == before[1] - 1),
             (True, False, True))
        g3 = cols[2]
        f3 = src["chunks"][g3][min(src["chunks"][g3])]
        bad_cell = C.copy(f3)
        bad_cell.index = sim.ghdr[g3].count          # an index the column's header does not have
        n_pen = len(pen)
        try:
            ns["on_frame"](p3, Wm.Frame(Wm.Entry(chunk=bad_cell)))
            got = (stored(g3, bad_cell.index), pen[n_pen:])
        except Exception as e:
            got = f"{type(e).__name__}: {e}"
        del pen[n_pen:]
        line(f"(h) node {p3}: a copy of a cell of column {sim.gcol[g3]} naming index {bad_cell.index}, beyond the "
             f"header's count: stored, penalties", got, (False, [p3]))
        g4 = cols[3]
        f4 = src["chunks"][g4][min(src["chunks"][g4])]
        ns["on_frame"](p4, Wm.Frame(Wm.Entry(chunk=f4)))
        written(p4, f2)
        ns["on_frame"](p4, holding(g2, f2.index))
        line(f"(h) node {p4}, neither type joined: a cell of column {sim.gcol[g4]} stored; S's copy in flight to it "
             f"freed by its holding", (stored(g4, f4.index), room(p4, f2)), (True, False))
        g5 = cols[4]
        ns["on_frame"](p3, holding(g5, 0, claim=True))
        ns["on_frame"](p, holding(g5, 0, claim=True))
        line(f"(i) a holding of column {sim.gcol[g5]} claiming it whole: from node {p3} (rows only): its claim kept, "
             f"a claimant; from p (columns joined): a claimant",
             ((ns["peer_has"][p3][g5].claim_all, p3 in ns["claims"].get(g5, ())), p in ns["claims"].get(g5, ())),
             ((True, False), True))
    line("penalties", pen, [])


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: relation_types_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
