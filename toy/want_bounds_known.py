#!/usr/bin/env python3
"""A known answer for seacast.md §4.5's two bounds on a WANT: an index the group has not, once its count is
known, and a group beyond the asker's limit of unknown groups (`admitted_group`, seacast-lite.md §8.2's
`MAX_PENDING_GROUPS`). Either is ignored without penalty, and keeps no standing request.

    python3 want_bounds_known.py

The check, on a small custody network (8 nodes, seed 7) that is built and published, not run, with node S and one of
its peers p, each ask given to S's `on_want` as a standing WANT that p sent, for columns S custodies and does not hold:
- (a) a column whose header S holds (`hdr`), at an index beyond its count: no standing request; the control, index 0
  of the same column: kept;
- (b) with p's limit of unknown groups set to one, two columns S knows nothing of yet: the first kept, the second
  ignored; a third column, whose header S holds, kept whatever the limit;
- (c) a column S knows nothing of yet, at an index past the type's most (`MAX_INDICES`): ignored;
- the limit of unknown groups' places, with the limit one: (e) once (b)'s first column resolves (its header known),
  its place frees and another unknown column is kept; (f) when a place's lifetime passes (`GROUP_TTL`, made short
  here), the next admission frees it and drops the asker's standing request for that column; (g) at the close
  (`drop_peer`), the asker's places go, with its standing requests and no empty entry left; (h) a second peer's place past its lifetime, with no WANT after it: the
  heartbeat (`release_wanted_groups`) frees it and drops its standing request, leaving no empty entry; (j) the same
  peer's place for another column past its lifetime, the group's first cell arriving before the next heartbeat
  (`fill`): the opening frees the place first, so the request is not answered; (k) two peers and one unknown
  column: with the second peer's one place taken by another column, the first peer's request for the column, then
  the second's: the second ignored, as a request kept for a group the node has not opened does not exempt it from
  the limit; with room, the second's own place; both places past their lifetimes, the heartbeat drops both
  requests, leaving no entry;
- (d) with the type's most raised past the count, a routed standing WANT for a column S knows nothing of, at an index
  past its count: kept, with its route mark; then the block runs until S stores the column's cells, and the group's
  opening (`fill`, `drop_wants_beyond`) drops both;
- (i) at the source, a standing WANT of a peer's for index 0 of a column, kept before the block is published: the
  publish answers it (`serve_standing`), so the request is gone and the answer counted in `served`;
- penalties: none.
On the document before the bounds, (a) to (d) and (f) fail. (e) and (g) read the limit's places, which that document
does not have, so they pass there; they fail on a version of the limit that never freed a place. (h) fails on the
document before the heartbeat freed places, (j) on the document before a group's opening freed them, and (i) on
the document before the publish answered standing requests. (k) fails on a version of the limit that exempted a
group for which the node kept any request.
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
    sim = build(["--doc", "seacast", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7"])
    S = sim.nodes[2]
    ns = S.ns
    p = min(q for q in S.peers if q != 1)
    mine = sim.custody[S.id]
    cols = [g for c, g in sorted((sim.gcol[g], g) for g in sim.canonical if sim.gtype.get(g) == "column")
            if c in mine]
    ga, gb, gc, gd = cols[:4]                    # and cols[4], cols[5] for (c), (d)
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
    ns["MAX_PENDING_GROUPS"] = float("inf")
    COL = ns["type_of_group"](cols[4])
    ge, gf = cols[4], cols[5]
    ns["on_want"](p, [Wm.FlaggedWant(ge, COL.params.MAX_INDICES, True, 0)])
    line(f"(c) column {sim.gcol[ge]}, count unknown: index {COL.params.MAX_INDICES} (the type's most) kept",
         kept(ns, ge, COL.params.MAX_INDICES, p), False)
    ns["MAX_PENDING_GROUPS"] = 1
    ns["hdr"][gb] = sim.ghdr[gb]                    # (b)'s first column resolves
    ns["on_want"](p, [Wm.FlaggedWant(gc, 0, True, 0)])
    line(f"(e) column {sim.gcol[gb]} resolved: unknown column {sim.gcol[gc]} kept", kept(ns, gc, 0, p), True)
    ns["GROUP_TTL"] = 0.001
    ns["now"] += 0.01                               # S's clock, past the short lifetime
    gh = cols[6]
    ns["on_want"](p, [Wm.FlaggedWant(gh, 0, True, 0)])
    del ns["GROUP_TTL"]
    line(f"(f) column {sim.gcol[gc]}'s place past its lifetime: its standing request kept; column {sim.gcol[gh]} kept",
         (kept(ns, gc, 0, p), kept(ns, gh, 0, p)), (False, True))
    S.drop_peer(p)
    tabs = [ns[t] for t in ("standing", "routed_standing")]
    empty = any(not idx or any(not s for s in idx.values()) for tab in tabs for idx in tab.values())
    left = any(p in s for tab in tabs for idx in tab.values() for s in idx.values())
    line("(g) at the close: p's places kept, empty entries left, p's requests left",
         (p in getattr(S, "want_unknown", {}), empty, left), (False, False, False))
    q = next(x for x in sorted(S.peers) if x not in (1, p))
    gx = cols[7]
    ns["on_want"](q, [Wm.FlaggedWant(gx, 0, True, 0)])
    before = kept(ns, gx, 0, q)
    ns["GROUP_TTL"] = 0.001
    ns["now"] += 0.01                               # S's clock, past the short lifetime
    ns["on_heartbeat"]()
    del ns["GROUP_TTL"]
    line(f"(h) node {q}'s place for column {sim.gcol[gx]}: kept; past its lifetime, after the heartbeat: kept, an "
         f"entry left, the place held", (before, (kept(ns, gx, 0, q), gx in ns["standing"],
                                                  gx in getattr(S, "want_unknown", {}).get(q, {}))),
         (True, (False, False, False)))
    gy = next(g for g in sorted(sim.canonical) if sim.gtype.get(g) == "column" and g not in ns["hdr"]
              and g not in ns["T_of"] and g not in cols)
    spec_auth = ns["authenticable"]
    ns["authenticable"] = lambda g: False if g == gy else spec_auth(g)   # its gate closed, as before its header
    ns["on_want"](q, [Wm.FlaggedWant(gy, 0, True, 0)])
    ns["authenticable"] = spec_auth
    before = kept(ns, gy, 0, q)
    ns["GROUP_TTL"] = 0.001
    ns["now"] += 0.01                               # past the place's lifetime, before the next heartbeat
    r = next(x for x in sorted(S.peers) if x not in (1, p, q))
    ns["fill"](gy, 0, sim.nodes[1].ns["chunks"][gy][0], r)   # the group's first cell arrives: the group opens
    del ns["GROUP_TTL"]
    line(f"(j) node {q}'s place for column {sim.gcol[gy]}: kept; past its lifetime, the group opening before the "
         f"heartbeat: answers to node {q}", (before, ns["served"][q][gy]), (True, 0))
    ns["MAX_PENDING_GROUPS"] = 1
    gz, gw = [g for g in sorted(sim.canonical) if sim.gtype.get(g) == "column" and g not in ns["hdr"]
              and g not in ns["T_of"] and g not in cols and g != gy][:2]
    ns["authenticable"] = lambda g: False if g in (gz, gw) else spec_auth(g)   # gates closed, as before the header
    ns["on_want"](r, [Wm.FlaggedWant(gw, 0, True, 0)])          # r's one place
    ns["on_want"](q, [Wm.FlaggedWant(gz, 0, True, 0)])          # q's: S now keeps a request for column gz
    ns["on_want"](r, [Wm.FlaggedWant(gz, 0, True, 0)])          # r, at its limit, names gz too
    first = (kept(ns, gw, 0, r), kept(ns, gz, 0, q), kept(ns, gz, 0, r))
    ns["MAX_PENDING_GROUPS"] = 2
    ns["on_want"](r, [Wm.FlaggedWant(gz, 0, True, 0)])          # with room, r's own place for gz
    places = (gz in getattr(S, "want_unknown", {}).get(q, {}), gz in getattr(S, "want_unknown", {}).get(r, {}))
    ns["authenticable"] = spec_auth
    ns["GROUP_TTL"] = 0.001
    ns["now"] += 0.01                               # S's clock, past both places' lifetimes
    ns["on_heartbeat"]()
    del ns["GROUP_TTL"]
    line(f"(k) limit 1: node {r} holding a place for column {sim.gcol[gw]}, node {q}'s request for unknown column "
         f"{sim.gcol[gz]}, then node {r}'s for it: kept (gw by {r}, gz by {q}, gz by {r}); with limit 2, {r}'s again: "
         f"places of {q} and {r} for gz; past their lifetimes, after the heartbeat: requests of {q} and {r} kept, an "
         f"entry left", (first, places, (kept(ns, gz, 0, q), kept(ns, gz, 0, r), gz in ns["standing"])),
         ((True, True, False), (True, True), (False, False, False)))
    ns["MAX_PENDING_GROUPS"] = float("inf")
    if "drop_wants_beyond" not in ns:
        line("(d) the sweep as the group opens (drop_wants_beyond)", "not in the document", "present")
    else:
        spec_max, COL.params.MAX_INDICES = COL.params.MAX_INDICES, 1000
        ns["on_want"](q, [Wm.FlaggedWant(gf, 100, True, 1)])
        before = (kept(ns, gf, 100, q), q in ns["routed_standing"][gf][100])
        sim.run(sim.cfg["first"] + 1.5)             # the block runs: S stores column gf's cells, and gf opens
        COL.params.MAX_INDICES = spec_max
        line(f"(d) column {sim.gcol[gf]}, index 100 routed, from node {q}: kept, marked; after the group opened "
             f"(stored {len(ns['chunks'].get(gf, {}))} cells)",
             (before, (kept(ns, gf, 100, q), q in ns["routed_standing"][gf][100])), ((True, True), (False, False)))
    line("penalties", pen, [])


def source_standing():
    import run as R
    import sim as SM
    got, spec_run = {}, R.run
    R.run = lambda cfg, out=None: got.setdefault("sim", SM.Sim(cfg))
    try:
        R.main(["--doc", "seacast", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1", "--seed", "7"])
    finally:
        R.run = spec_run
    sim = got["sim"]
    sim.run(sim.cfg["first"])
    src = sim.nodes[1]
    ns = src.ns
    q = min(src.peers)
    first, spec_pub = [], ns["publish"]

    def publish(block, d, shards):                  # the first column: q's standing WANT for index 0 came first
        if not first:
            first.append(ns["group_of"](block, d))
            ns["standing"][first[0]][0].add(q)
        return spec_pub(block, d, shards)
    ns["publish"] = publish
    sim.publish(1)
    ns["publish"] = spec_pub
    g = first[0]
    line(f"(i) at the source, node {q}'s standing WANT for index 0 of column {sim.gcol[g]}, before the publish: kept "
         f"after it, answers counted", (q in ns["standing"].get(g, {}).get(0, ()), ns["served"][q][g]), (False, 1))


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: want_bounds_known.py")
    main()
    source_standing()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
