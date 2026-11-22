#!/usr/bin/env python3
"""A known answer for seacast-lite.md §8.2's limit of unknown groups per peer (`MAX_PENDING_GROUPS`) on HAVEs and offers,
in seacast-lite.md §4.3's `on_have` and §4.4's `on_ihave`, and seacast.md §4.3's `on_holding` and `on_offer`: a HAVE
(under seacast.md, a holding) or an offer of a group beyond the peer's limit is ignored, without penalty, before
it leaves any state.

    python3 unknown_groups_known.py

The toy sets no such limit (its `admitted` is always true), so the check gives the node an `admitted` that refuses
one group, G, and admits every other. On one node of a small network that is built and not run, from one peer,
under each document:
- a HAVE of G (under seacast.md, a holding that claims G whole): nothing in `peer_has` or `holders`, and under
  seacast.md nothing in `claims`;
- an offer of G (an IHAVE's bitmap; under seacast.md, an offer): nothing in `offered` or `offers`, and no ask;
- the controls, the same for H, a group the node admits: each leaves its state;
- penalties: none.
Under seacast-lite.md, G and H are groups no block commits; under seacast.md, two columns of the published block
in the node's custody, not yet open at the node. On the documents before the rule, the HAVE and the offer of G
leave state.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
NODE = 2
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
    return got["sim"]


def check(doc):
    import wire as Wm
    from bits import bitmap
    seacast = doc == "seacast"
    if seacast:
        sim = build(["--doc", "seacast", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1",
                     "--seed", "7"])
        sim.run(sim.cfg["first"])
        sim.publish(1)
    else:
        sim = build(["--nodes", "5", "--degree", "4", "--msgs", "1", "--payload", "16384", "--seed", "7"])
    node = sim.nodes[NODE]
    ns = node.ns
    p = min(q for q in node.peers if q != 1)
    if seacast:
        G, H = [g for g in sorted(sim.gcol, key=str) if g not in ns["T_of"]
                 and ns["our_interest_for"](p, g).has(1)][:2]   # in the node's custody: offers of it are kept
    else:
        G, H = bytes([0x35]) * 32, bytes([0x36]) * 32

    def group_of(x):
        return x.group if hasattr(x, "group") else ns["group"](x)
    ns["admitted"] = lambda q, x: group_of(x) != G  # G beyond p's unknown groups; every other group admitted

    def have(g):
        if seacast:
            ns["on_holding"](p, ns["Have"](group=g, bits=bitmap({0}), offer=False, claim_all=True, complete=False))
        else:
            ns["on_have"](p, Wm.HaveBitmap(group=g, bits=bitmap({0})))

    def offer(g):
        if seacast:
            return ns["on_offer"](p, ns["Have"](group=g, bits=bitmap({1}), offer=True, claim_all=False,
                                                complete=False))
        return ns["on_ihave"](p, Wm._IHave([Wm.HaveBitmap(group=g, bits=bitmap({1}))]))

    def held_state(g):
        e = ns["peer_has"].get(p, {}).get(g)
        st = (e is not None and e.bits.has(0), p in ns["holders"].get(g, {}).get(0, ()))
        return st + ((p in ns["claims"].get(g, ()),) if seacast else ())

    def offer_state(g):
        o = ns["offered"].get(p, {}).get(g)
        return (o is not None and o.has(1), any(p in ps for a, ps in ns["offers"].items() if group_of(a) == g))

    pen0 = node.penalties
    have(G)
    have(H)
    asks = offer(G)
    offer(H)
    yes = (True,) * (3 if seacast else 2)
    what = "a holding claiming it whole" if seacast else "a HAVE"
    line(f"{doc}: {what} of G, beyond p's unknown groups: in peer_has, holders" + (", claims" if seacast else ""),
         held_state(G), tuple(not x for x in yes))
    line(f"{doc}: an offer of G: in offered, offers; asks", (offer_state(G), asks), ((False, False), []))
    line(f"{doc}: the controls, H admitted: {'the holding' if seacast else 'the HAVE'}'s state; the offer's state",
         (held_state(H), offer_state(H)), (yes, (True, True)))
    line(f"{doc}: penalties", node.penalties - pen0, 0)


def main():
    for doc in ("lite", "seacast"):
        check(doc)


if __name__ == "__main__":
    if sys.argv[1:]:
        sys.exit("usage: unknown_groups_known.py")
    main()
    print("ok" if not bad else "FAIL")
    sys.exit(1 if bad else 0)
