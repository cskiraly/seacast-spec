#!/usr/bin/env python3
"""A known answer for protocol-v2.md §2's rule on object types a link has not joined, in §4.1's code (`runs_type`,
`joined_on`): a JOIN for an object type the node does not run, and a GRAFT or a PRUNE for one the link has not joined,
leave no state, draw no answer and no penalty.

    python3 relation_types_known.py

The check, on a small rows network (8 nodes, seed 7, columns and rows, `--upkeep on`, so that the links are the JOINs'
`links(T)`) that is built and published, not run, with node S and one of its peers p, the link having JOINs both
ways for both types. Each message is given to S's own
handler as if p had sent it, and S's sends to p are recorded:
- (a) a JOIN for an object type S does not run: nothing stored in `join_recv`, no JOIN sent back;
- (b) with p's JOIN for rows taken back (the link has not joined rows), a GRAFT for a row family: no relation, no
  GRAFT pending, nothing sent;
- (c) the same link, a PRUNE for that family: no backoff set;
- (d) the control: a GRAFT for a column family the link has joined is handled: S answers it;
- (e) with S's own JOIN for columns owed to a second peer (not yet queued), that peer's GRAFT for a column family:
  ignored, as the link is not yet one of `links(T)`;
- (f) a WANT for a cell of the row S serves, on the link of (b), which has not joined rows: ignored, no standing
  request, no error;
- (g) the control: with only S's JOIN for rows owed to the second peer, its GRAFT for a column family: answered.
On the document before the rule, (a), (b), (c), (e) and (f) fail.
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
    ns["on_prune"](p, ns["Prune"](object_type="row", family=fam, colour=0, direction="IN"))
    line(f"(c) the same link, a PRUNE for row family {fam}: backoff set",
         bool(ns["backoff"][p][ROW][fam]), False)

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
    line("penalties", pen, [])


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: relation_types_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
