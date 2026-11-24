#!/usr/bin/env python3
"""Directed records under seacast.md: the toy's functions called in SEACAST nodes' namespaces on drawn states, each
call logged by trace3.py's tracer with the node's whole state (`whole=True`).

    python3 directed_seacast.py TOYDIR OUT.jsonl.gz [--n N] [--seed S]

The nodes are hand5's, as the toy's run.py builds them with `--doc seacast`. The tracer is installed as trace3.py's
main installs it under SEACAST, at the end of each node's construction, so that it sees every name as the node
finally binds it. The simulator is built and never run: no event happens, and a timer a call arms stays in its
queue.

A scenario draws the own tables its function reads, through the views but outside any record, so that nothing of
the drawing is logged. It then sets `now` and calls the name the install wrapped. It rebinds nothing: the install
wrapped the node's traced names, questions and type functions, and a name rebound after it would be refused at the
close (final_check) or missing from the tape, which the replay refuses. So a question's answer is the node's own,
from the drawn state, and every random draw is the toy's, on the tape. The window's three tables are not installed
under SEACAST, and no scenario draws them.

What this cannot reach: a branch behind a refused control message. The toy's queues admit every entry under
SEACAST (node.py's enqueue), and --loss-data refuses chunks alone, so `send` of a WANT, a HAVE or a relation message
is always true here. defer_on_claim's refusal is one such branch.

The scenarios, one per function:
- **note_claim** (the set's control): `note_claim(p, g)` at nodes 2, 3 and 4, for groups the simulator does not know,
  whose type is the node's default one. The drawn state is g's descriptor (a count of 1 to 8), `mine[g]` (all of the
  group's indices in about a fifth of the draws), `claims[g]` (empty, p alone, or p with one or two other peers),
  `reconsider_at[g]` (about three quarters), `state[g]` (COMPLETE in about 70 %) and `deferred[g]` (about a quarter).
  Where every condition holds, note_claim calls defer_on_claim, which asks one claimant for an index we lack.
"""
import argparse
import sys
import types
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import footprint as F                   # noqa: E402
import trace3                           # noqa: E402

HAND5 = ["--nodes", "5", "--degree", "4", "--msgs", "1", "--payload", "16384", "--seed", "7", "--doc", "seacast"]
GROUPS = [bytes([0x31 * (j + 1)]) * 32 for j in range(3)]     # groups the simulator does not know: the default type


def build(tr):
    """The simulator's nodes, the tracer installed in each at the end of its construction (trace3.py's main under
    SEACAST), and the simulator not run."""
    orig_init = tr.N.Node.__init__

    def __init__(self, *a, **kw):
        orig_init(self, *a, **kw)
        pre = {name: self.ns.get(name) for name in ("desc", "message_id")}    # the aliases' targets as the toy
        tr.install(self, self.ns)                                           #   left them, before the install
        tr.repoint_aliases(self, self.ns, pre)

    tr.N.Node.__init__ = __init__
    import run                          # noqa: E402: the pinned toy's
    import sim as S                     # noqa: E402
    got = {}
    run.run = lambda cfg, out=sys.stdout: got.setdefault("sim", S.Sim(cfg))
    run.main(HAND5)
    return got["sim"]


def descriptor(count):
    """A whole descriptor of `count` chunks, as seacast-lite.md's sets draw one: N is its count."""
    return types.SimpleNamespace(version=2, hash_id=0, encoding=1, root=bytes([0xd0]) * 32, count=count,
                                 total_length=count, segment_size=1)


def note_claim(rng, nd, ns, B):
    """The control: note_claim(p, g) on a drawn state (the module's docstring)."""
    peers = sorted(nd.peers)
    p, g = rng.choice(peers), rng.choice(GROUPS)
    for name in ("claims", "reconsider_at", "state", "deferred", "mine", "desc", "duty_at", "probe", "probed",
                 "tried", "offered", "probe_asks", "probe_ok"):
        ns[name].clear()
    ns["offers"]._d.clear()
    ns["offers"].listed.clear()
    queues = F.unwrap(ns["queue"])      # what an earlier record queued, in the toy's own queues
    for q in peers:
        if q in queues:
            queues[q].urgent.clear()
            queues[q].normal.clear()
    n = rng.randrange(1, 9)
    ns["desc"][g] = descriptor(n)
    full = (1 << n) - 1
    ns["mine"][g] = B.Bits(full if rng.random() < 0.2 else rng.randrange(full))
    r = rng.random()
    if r < 0.6:                         # p a claimant already, alone or with others
        others = [q for q in peers if q != p]
        for q in [p] + rng.sample(others, rng.randrange(0, 3)):
            ns["claims"][g].add(q)
    elif r < 0.8:                       # another claims g, not p
        ns["claims"][g].add(rng.choice([q for q in peers if q != p]))
    if rng.random() < 0.75:
        ns["reconsider_at"][g] = ns["now"] + rng.choice([0.0, 0.5, 2.0])
    r = rng.random()
    ns["state"][g] = (ns["COMPLETE"] if r < 0.7 else ns["COLLECTING"] if r < 0.85 else ns["DECODING"]
                      if r < 0.95 else ns["INVALID"])
    if rng.random() < 0.25:
        ns["deferred"][g] = True
    return "note_claim", (p, g)


SCENARIOS = {"note_claim": note_claim}


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("toy")
    ap.add_argument("out")
    ap.add_argument("--n", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args(argv)
    toy = Path(a.toy).resolve()
    tr = trace3.Tracer3(toy, a.out, ["directed_seacast", "--doc", "seacast", f"--n={a.n}", f"--seed={a.seed}"],
                        whole=True)
    try:
        sim = build(tr)
        import bits as B                # noqa: E402: the pinned toy's
        import random
        rng = random.Random(a.seed)
        calls = Counter()
        fns = sorted(SCENARIOS)
        for _ in range(a.n):
            k = rng.choice((2, 3, 4))
            nd = sim.nodes[k]
            ns = nd.ns
            ns["now"] = rng.choice([1.0, 3.25])
            name, args = SCENARIOS[rng.choice(fns)](rng, nd, ns, B)
            ns[name](*args)
            calls[name] += 1
    except BaseException as stop:       # trace3.py's main: the trace closed with the first reason in its trailer
        try:
            tr.close(stopped=(f"{type(stop).__name__}: {stop}".splitlines() or [""])[0])
        except BaseException as later:
            print(f"directed_seacast: (at the close, after the stop) {type(later).__name__}: {later}", file=sys.stderr)
        raise
    tr.close()
    print(f"directed_seacast: {sum(tr.counts.values())} records, {dict(sorted(tr.counts.items()))}; "
          f"calls made {dict(sorted(calls.items()))}", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
