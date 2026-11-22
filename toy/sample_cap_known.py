#!/usr/bin/env python3
"""A known answer for protocol-v2.md §4.10's second phase: a sampler keeps one count and one cap per block across
the block's sampled types (`SAMPLE_OUTSTANDING`, a setting of the node). When a second-phase ask's wait ends and the
same sample's next ask does not take the freed slot, the block's held samples are tried for it in order, even when
the timed-out sample's group has expired.

    python3 sample_cap_known.py

The check builds a small custody network with samplers (8 nodes, seed 7, half of them samplers), publishes one
block without running it, and drives one sampler's `resample` and `ask_sample` directly on two column groups A and B
of the block. B is given its own copy of the column type's parameters, so that the block holds two types. For a
document with a cap per type, the two caps are set to legal values (4 and 1 in (a), 4 and 4 in (b)). Every table
still reads B's type as the column type. A wrapper of `ask_sample` stops a refill loop that runs past 100 calls, and
`send` only records what the sampler asked.
- (a) The node's cap is 2, two second-phase asks are in flight, B, A and B are held in that order, and A's sample
  has arrived when A's wait ends. The refill asks the first held sample and stops at the cap: one ask is recorded,
  B's, the count is back at 2, and A and B stay held in their order. With a cap per type, A's cap of 4 lets the loop
  pop B, B's cap of 1 puts it back without an ask, and the loop does not end.
- (b) The node's cap is 4, the last second-phase ask in flight is A's, A has expired when its wait ends, and B's
  sample is held. The refill asks B. With the early return that `resample` had for an expired group, B would stay
  held with no ask in flight, and nothing would ever ask it.
"""
import contextlib
import io
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
        with contextlib.redirect_stdout(io.StringIO()):  # the run's banner
            R.main(args)
    finally:
        R.run = spec_run
    sim = got["sim"]
    sim.run(sim.cfg["first"])
    sim.publish(1)                                       # the block's samples are scheduled, not yet drawn
    return sim


class Retyped:
    """The column type with parameters of its own: the same type to every table that keys by it."""
    def __init__(self, T, params):
        self._T, self.params = T, params

    def __getattr__(self, k):
        return getattr(self._T, k)

    def __hash__(self):
        return hash(self._T)

    def __eq__(self, o):
        return o is self._T or o is self


class Runaway(Exception):
    pass


def setup(seed_cap_a, cap_b, node_cap):
    import copy
    sim = build(["--doc", "v2", "--setting", "custody", "--nodes", "8", "--degree", "6", "--msgs", "1",
                 "--seed", "7", "--samplers", "50"])
    S = sim.nodes[min(sim.cfg["sampler_ids"])]
    ns = S.ns
    cols = sorted((sim.gcol[g], g) for g in sim.canonical if sim.gtype.get(g) == "column")
    T = ns["type_of_group"](cols[0][1])

    def served(g, i, taken=()):                          # links of ordinary custody that serve (g, i), not yet asked
        return [q for q in ns["links"](T) if q not in taken and ns["serves"](q, g, i) and not ns["high_custody"](q, T)]
    pairs = [(g, i) for _, g in cols for i in range(4) if served(g, i)]
    ga = pairs[0][0]
    gb = next(g for g, _ in pairs if g != ga)
    a_idx = [i for g, i in pairs if g == ga]
    b_idx = [i for g, i in pairs if g == gb]
    b = ns["block_of"](ga)
    assert ns["block_of"](gb) == b, "A and B are of one block"
    if hasattr(T.params, "SAMPLE_OUTSTANDING"):
        T.params.SAMPLE_OUTSTANDING = seed_cap_a
    pb = copy.copy(T.params)
    pb.SAMPLE_OUTSTANDING = cap_b
    tb = Retyped(T, pb)
    spec_type = ns["type_of_group"]
    ns["type_of_group"] = lambda g: tb if g == gb else spec_type(g)
    ns["SAMPLE_OUTSTANDING"] = node_cap
    sent, calls = [], [0]
    ns["send"] = lambda q, m, urgent=False: sent.append((q, m.group, sorted(m.bits)))
    spec_ask = ns["ask_sample"]

    def ask_sample(g, i, first=False):
        calls[0] += 1
        if calls[0] > 100:
            raise Runaway()
        return spec_ask(g, i, first)
    ns["ask_sample"] = ask_sample
    return sim, S, ns, ga, gb, a_idx, b_idx, b, sent


def case_a():
    sim, S, ns, ga, gb, a_idx, b_idx, b, sent = setup(4, 1, 2)
    print(f"sampler node {S.id}: A = column {sim.gcol[ga]}, B = column {sim.gcol[gb]}, of one block")
    nm = {ga: "A", gb: "B"}
    j = a_idx[0]
    ns["mine"][ga] = ns["mine"][ga] | ns["bitmap"]({j})  # A's sample arrived
    ns["samples_in_flight"][b] = 2
    held = [(gb, b_idx[0]), (ga, a_idx[1] if len(a_idx) > 1 else j), (gb, b_idx[1] if len(b_idx) > 1 else b_idx[0])]
    ns["held_samples"][b].extend(held)
    q = next(iter(ns["links"](ns["type_of_group"](ga))))
    try:
        ns["resample"](ga, j, q, False)
        got = (len(sent), [(nm[g], i) for _, g, (i,) in sent], ns["samples_in_flight"][b],
               [(nm[g], i) for g, i in ns["held_samples"][b]])
    except Runaway:
        got = "the refill loop ran past 100 calls"
    line("(a) cap 2, two in flight, held B, A, B; A's wait ends with its sample: asks, count, held",
         got, (1, [(nm[g], i) for g, i in held[:1]], 2, [(nm[g], i) for g, i in held[1:]]))


def case_b():
    sim, S, ns, ga, gb, a_idx, b_idx, b, sent = setup(4, 4, 4)
    j = a_idx[0]
    spec_expired = ns["expired"]
    ns["expired"] = lambda g: True if g == ga else spec_expired(g)
    ns["samples_in_flight"][b] = 1
    ns["held_samples"][b].append((gb, b_idx[0]))
    q = next(iter(ns["links"](ns["type_of_group"](ga))))
    try:
        ns["resample"](ga, j, q, False)
        got = ([({ga: "A", gb: "B"}[g], i) for _, g, (i,) in sent], ns["samples_in_flight"][b],
               [({ga: "A", gb: "B"}[g], i) for g, i in ns["held_samples"][b]])
    except Runaway:
        got = "the refill loop ran past 100 calls"
    line("(b) A's wait ends after A expired, B held: asks, count, held", got, ([("B", b_idx[0])], 1, []))


def main():
    if sys.argv[1:]:
        print("usage: sample_cap_known.py")
        return 2
    case_a()
    case_b()
    print("ok" if not bad else f"FAIL: {bad} case(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
