#!/usr/bin/env python3
"""Directed records under seacast.md: the toy's functions called in SEACAST nodes' namespaces on drawn states, each
call logged by trace3.py's tracer with the node's whole state (`whole=True`).

    python3 directed_seacast.py TOYDIR OUT.jsonl.gz [--set NAME] [--n N] [--seed S]

A set names a frame, the nodes its records are made at, and its scenarios; each record picks one of the set's
scenarios. The frames:
- **H:** hand5's nodes (`--nodes 5 --degree 4 --msgs 1 --payload 16384 --seed 7 --doc seacast`), nothing published;
- **H+:** H, with the config's MAX_PENDING_GROUPS 1 and SERVE_BUDGET 2 (run.py has no option for either);
- **D:** DAS30's nodes (`--nodes 30 --degree 8 --msgs 1 --setting rows --supernodes 10 --blobs 4 --seed 7 --doc
  seacast`) with `--forward-limit 2`, after the simulator's publish of one block with every column withheld, so that
  its column and row groups exist and the proposer pushes nothing. That publish runs node 1's own traced functions,
  whose records come first in the trace and are printed apart, as the setup;
- **R:** H, with the config's MAX_RELATIONS 2 (run.py has no option for it) and `--prune-backoff 1`;
- **W:** `--nodes 17 --degree 16 --msgs 1 --payload 16384 --seed 7 --doc seacast`, so that a node has 16 peers;
- **WU:** W with `--upkeep on`, so that the default type is symmetric and `candidates` runs.
A frame that names its peer count stops before the first record if a recording node has another.

The nodes are built by the toy's run.py, with the tracer installed as trace3.py's main installs it under SEACAST: at
the end of each node's construction, so that it sees every name as the node finally binds it. The simulator never
runs: no event happens, and a timer a call arms stays in its queue.

A scenario draws the tables its function reads, through the views or the toy's own containers but outside any record,
so that nothing of the drawing is logged. It then sets `now` and calls the name the install wrapped. It rebinds
nothing: the install wrapped the node's traced names, questions and type functions, and a name rebound after it would
be refused at the close (final_check) or missing from the tape, which the replay refuses. So a question's answer is
the node's own, from the drawn state, and every random draw is the toy's, on the tape. The window's three tables are
not installed under SEACAST, and no scenario draws them. In every set but `control`, each record starts from the
state the build left (on D, after the publish): the tables the scenarios touch are put back to that state first, and
the asker places of `admitted_group` (`node.want_unknown`, no table) are emptied.

What this cannot reach: a branch behind a refused control message. The toy's queues admit every entry under
SEACAST (node.py's enqueue), and --loss-data refuses chunks alone, so `send` of a WANT, a HAVE or a relation message
is always true here.

The sets:
- **control** (H, nodes 2 to 4): `note_claim(p, g)` for groups the simulator does not know, whose type is the node's
  default one. The drawn state is g's descriptor (a count of 1 to 8), `mine[g]` (all of the group's indices in about
  a fifth of the draws), `claims[g]` (empty, p alone, or p with one or two other peers), `reconsider_at[g]` (about
  three quarters), `state[g]` (COMPLETE in about 70 %) and `deferred[g]` (about a quarter). Where every condition
  holds, note_claim calls defer_on_claim, which asks one claimant for an index we lack.
- **serve_h** (H, nodes 2 to 4), **serve_hplus** (H+, nodes 2 to 4) and **serve_d** (D, nodes 2 to 30), the serving
  of §4.5, S1 to S20: `on_want(p, asks)`, and
  in one scenario `route_want(p, g, i, 1)`, each on a state whose path through on_want, outside and route_want is one
  and the same for every record of the scenario (the scenarios' docstrings). By default p is a link of g's type,
  with JOINs both ways of interest ALL and duty FORWARD; the ask is one plain ask of an index below the group's count;
  nothing of g is held, stored, served or claimed; and g is not ours. On H and H+, g is one of three groups the
  simulator does not know, of the default type, with a drawn descriptor of 1 to 8 chunks, and no group is
  authenticable (no block was published); on D, g is one of the published block's column or row groups, with the
  simulator's own header.
- **upkeep_h** (H), **upkeep_r** (R), **upkeep_w** (W) and **upkeep_wu** (WU), nodes 2 to 4, the relations of
  §4.1, J1 to M4: `on_join`, `on_graft`, `on_prune`, `maintain_relations` and, in one scenario, `graft` itself, each
  on a state whose path is one and the same for every record of the scenario. By default the type is the default
  one, P, the family 0 and the colour 0; p is a link of P, with JOINs both ways as built (interest ALL, duty
  FORWARD); and no peer is in any relation of ours, has a GRAFT of ours unanswered, or is in a backoff, and nothing
  is owed: each record starts with the six relation tables empty at its node (the toy's static mesh fills
  `push_in` and `push_out` at the build) and the JOIN tables as built.
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
DAS30 = ["--nodes", "30", "--degree", "8", "--msgs", "1", "--setting", "rows", "--supernodes", "10", "--blobs", "4",
         "--seed", "7", "--doc", "seacast", "--forward-limit", "2"]
W16 = ["--nodes", "17", "--degree", "16", "--msgs", "1", "--payload", "16384", "--seed", "7", "--doc", "seacast"]
GROUPS = [bytes([0x31 * (j + 1)]) * 32 for j in range(3)]     # groups the simulator does not know: the default type
ROOT = bytes([0xa1]) * 32
# the tables the serving scenarios draw or their calls write, put back before each record (chunks and known_id
# among them: a stored chunk is the toy's `store`'s two writes)
RESET = ("join_recv", "join_sent", "owed_relations", "desc", "state", "mine", "peer_has", "origin", "served",
         "probe_waiting", "probe_served", "standing", "routed_standing", "want_p", "unwanted", "serve_count",
         "served_hb", "offered_to", "forwarded", "park", "T_of", "chunks", "known_id")
# the relation tables, emptied before each record of the relation scenarios; the JOIN tables are put back as built
RELATIONS = ("push_in", "push_out", "grafted_in", "grafted_out", "backoff", "owed_relations")
CTX = {}                              # the frame: the simulator, the toy's modules, the tracer


def build(tr, argv, config=None, publish=False):
    """The simulator's nodes, the tracer installed in each at the end of its construction (trace3.py's main under
    SEACAST), and the simulator not run. `config` is put in the toy's config before the nodes are built; `publish`
    publishes one block after."""
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

    def make(cfg, out=sys.stdout):
        cfg.update(config or {})
        return got.setdefault("sim", S.Sim(cfg))

    run.run = make
    run.main(argv)
    sim = got["sim"]
    if publish:                         # every column withheld for the publish alone (sim.py reads `withhold` there and
        w = sim.cfg["withhold"]         #   at construction, node.py never): the groups, their headers and the cells
        sim.cfg["withhold"] = S.COLUMNS     #   (sim.canonical) are made, and the proposer pushes nothing, so that
        try:                                #   its thousands of pushes are no setup records; nodes 2 to 30 are as
            sim.publish_block(1)            #   they would be after a full publish, since no event runs
        finally:
            sim.cfg["withhold"] = w
    return sim


def save(nid, name, raw):
    """A table of RESET as the build left it: empty, or for the two JOIN tables, each peer's row of entries by type,
    the type objects and the entries themselves kept (a copy of a type would be another key of the same id)."""
    if not raw:
        return {}
    if name in ("join_recv", "join_sent"):
        return {k: dict(v) for k, v in raw.items()}
    raise SystemExit(f"directed_seacast: node {nid}: {name} is not empty after the build, and only the JOIN tables "
                     f"are put back whole")


def restore(raw, saved):
    """The table put back to `saved` in the toy's own containers: a row's container is the one the node has."""
    for k in [k for k in raw if k not in saved]:
        del raw[k]
    for k, row in saved.items():
        cur = raw[k]
        cur.clear()
        cur.update(row)


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


# ---- the serving scenarios' helpers: the defaults every on_want scenario starts from

def join(T, interest, duty="FORWARD", custody=0):
    """A JOIN entry as the node's construction makes one (node.py's `_seacast_das`)."""
    return CTX["Wm"].Container(object_type=T.id, interest=interest, custody_count=custody, duty=duty, colours=1)


def link(ns, p, T):
    """p a link of T, its JOIN and ours of interest ALL and duty FORWARD, and no JOIN of T owed to it."""
    ns["join_recv"][p][T] = join(T, "ALL")
    ns["join_sent"][p][T] = join(T, "ALL")


def ask(g, i, standing=False, hops=0, probe=False):
    """An ask as the toy's `send` writes a WANT's (node.py): flagged where a field is set, else plain."""
    Wm = CTX["Wm"]
    return Wm.FlaggedWant(g, i, standing, hops, probe) if standing or hops or probe else Wm.WantIndex(g, i)


def store(ns, g, i):
    """A chunk of g at index i stored as the toy's `store` stores one: `chunks[g][i]` the chunk, `known_id[g][i]`
    its id, which is its group, index and content id (seacast-lite.md's message_id), kept on the chunk as the toy's
    cache keeps it."""
    Wm = CTX["Wm"]
    f = types.SimpleNamespace(slot=1, beacon_block_root=ROOT, group=g, index=i,
                              data=types.SimpleNamespace(tag=("directed", i)))
    f.mid = g + i.to_bytes(4, "little") + Wm.content_id(f)
    ns["chunks"][g][i] = f
    ns["known_id"][g][i] = f.mid
    return f


def on_h(rng, nd, ns, desc=True):
    """H's defaults: p, a group of the default type P with a descriptor of 1 to 8 chunks, and an index below it."""
    P = nd._P
    p, g = rng.choice(sorted(nd.peers)), rng.choice(GROUPS)
    link(ns, p, P)
    n = rng.randrange(1, 9)
    if desc:
        ns["desc"][g] = descriptor(n)
    return p, g, rng.randrange(n), n, P


def on_d(rng, nd, ns, kind):
    """D's defaults: p, one of the published block's groups of the kind ("column" or "row") with the simulator's
    own header, and an index below its count."""
    sim = CTX["sim"]
    g = rng.choice(CTX[kind])
    T = nd._types[kind]
    p = rng.choice(sorted(nd.peers))
    link(ns, p, T)
    ns["desc"][g] = sim.ghdr[g]
    return p, g, rng.randrange(sim.ghdr[g].count), T


def only_links(ns, nd, T, keep):
    """The node's links of T are `keep` alone: every other peer's JOIN of T taken back."""
    for q in sorted(nd.peers):
        if q not in keep:
            F.unwrap(ns["join_recv"])[q].pop(T, None)


# ---- the serving scenarios, S1 to S20: each record's path, in the twin's labels

def s1(rng, nd, ns, B):
    """S1: p no link of P: our JOIN not received from it, ours not sent, or ours owed. -> on_want: a type the link has
    not joined."""
    p, g, i, n, P = on_h(rng, nd, ns)
    r = rng.random()
    if r < 1 / 3:
        F.unwrap(ns["join_recv"])[p].pop(P, None)
    elif r < 2 / 3:
        F.unwrap(ns["join_sent"])[p].pop(P, None)
    else:
        ns["owed_relations"][p].append(ns["Join"](object_type=P.id, interest="ALL", custody_count=0, duty="FORWARD",
                                                  colours=1))
    return "on_want", (p, [ask(g, i)])


def s2(rng, nd, ns, B):
    """S2: an index at or past the group's count, or with no descriptor at or past P's MAX_INDICES (8192). -> on_want:
    an index the group cannot have."""
    if rng.random() < 0.5:
        p, g, i, n, P = on_h(rng, nd, ns)
        i = n + rng.randrange(3)
    else:
        p, g, i, n, P = on_h(rng, nd, ns, desc=False)
        i = 8192 + rng.randrange(3)
    return "on_want", (p, [ask(g, i)])


def s3(rng, nd, ns, B):
    """S3: p claims the index. -> outside: not authenticable; on_want: an ask of a chunk p claimed."""
    p, g, i, n, P = on_h(rng, nd, ns)
    F.unwrap(ns["peer_has"])[p][g].bits = B.Bits(1 << i)     # its HAVE's bitmap: the entry joins its map (bits.py)
    return "on_want", (p, [ask(g, i)])


def s4(rng, nd, ns, B):
    """S4: p's probe of an index we claim. -> outside: not authenticable; on_want: a probe kept until we decode."""
    p, g, i, n, P = on_h(rng, nd, ns)
    ns["mine"][g] = B.Bits(1 << i)
    return "on_want", (p, [ask(g, i, probe=True)])


def s5(rng, nd, ns, B):
    """S5: a standing ask. -> outside: not authenticable; on_want: standing until the chunk arrives."""
    p, g, i, n, P = on_h(rng, nd, ns)
    return "on_want", (p, [ask(g, i, standing=True)])


def s6(rng, nd, ns, B):
    """S6: the defaults. -> outside: not authenticable; on_want: nothing to answer with."""
    p, g, i, n, P = on_h(rng, nd, ns)
    return "on_want", (p, [ask(g, i)])


def s7(rng, nd, ns, B):
    """S7: a stored chunk, asked twice in one frame. -> outside: not authenticable; on_want: answered; on_want: an
    index answered in this frame."""
    p, g, i, n, P = on_h(rng, nd, ns)
    store(ns, g, i)
    return "on_want", (p, [ask(g, i), ask(g, i)])


def s8(rng, nd, ns, B):
    """S8: a stored chunk whose id p has said it holds. -> outside: not authenticable; on_want: unwanted."""
    p, g, i, n, P = on_h(rng, nd, ns)
    ns["unwanted"][p].add(store(ns, g, i).mid)
    return "on_want", (p, [ask(g, i)])


def s9(rng, nd, ns, B):
    """S9: a stored chunk served to p three times. -> outside: not authenticable; on_want: served too often."""
    p, g, i, n, P = on_h(rng, nd, ns)
    ns["serve_count"][p][store(ns, g, i).mid] = 3
    return "on_want", (p, [ask(g, i)])


def s10(rng, nd, ns, B):
    """S10 (H+): a group we know nothing of, p's one place of unknown groups taken by another. -> outside: not
    authenticable; on_want: a group not admitted."""
    p, g, i, n, P = on_h(rng, nd, ns, desc=False)
    nd.want_unknown[p] = {rng.choice([h for h in GROUPS if h != g]): ns["now"]}
    return "on_want", (p, [ask(g, i)])


def s11(rng, nd, ns, B):
    """S11 (H+): a stored chunk, p's budget of this heartbeat spent. -> outside: not authenticable; on_want: over the
    budget."""
    p, g, i, n, P = on_h(rng, nd, ns)
    store(ns, g, i)
    ns["served_hb"][p] = 2
    return "on_want", (p, [ask(g, i)])


def s12(rng, nd, ns, B):
    """S12 (D): a column group of ours. -> outside: our own group; on_want: nothing to answer with."""
    p, g, i, T = on_d(rng, nd, ns, "column")
    ns["origin"][g] = B.Bits(0)
    return "on_want", (p, [ask(g, i)])


def s13(rng, nd, ns, B):
    """S13 (D): a column group in our interest as declared to p: ALL, or DERIVED from a custody of every column. ->
    outside: in our interest; on_want: nothing to answer with."""
    p, g, i, T = on_d(rng, nd, ns, "column")
    if rng.random() < 0.5:
        ns["join_sent"][p][T] = join(T, "DERIVED", custody=128)
    return "on_want", (p, [ask(g, i)])


def s14(rng, nd, ns, B):
    """S14 (D): a column group outside our interest as declared to p: DECLARED with no duty, or DERIVED from a custody
    of none. -> outside: outside our interest; on_want: outside what we serve p."""
    p, g, i, T = on_d(rng, nd, ns, "column")
    ns["join_sent"][p][T] = join(T, "DECLARED", duty="NONE") if rng.random() < 0.5 else join(T, "DERIVED", custody=0)
    return "on_want", (p, [ask(g, i)])


def s15(rng, nd, ns, B):
    """S15 (D): a row group served to p up to the row type's limit, 64. -> outside: in our interest; on_want: past the
    serving limit."""
    p, g, i, T = on_d(rng, nd, ns, "row")
    ns["served"][p][g] = 64
    return "on_want", (p, [ask(g, i)])


def s16(rng, nd, ns, B):
    """S16 (D): a routed ask of a column group, p's forwarded asks at the limit, 2. -> outside: routed to a forwarding
    node; route_want: past the limit; on_want: nothing to answer with."""
    p, g, i, T = on_d(rng, nd, ns, "column")
    ns["forwarded"][p][T] = 2
    return "on_want", (p, [ask(g, i, hops=1)])


def s17(rng, nd, ns, B):
    """S17 (D): a routed ask of a column group, p the node's only link of the type. -> outside: routed to a forwarding
    node; route_want: no route; on_want: nothing to answer with."""
    p, g, i, T = on_d(rng, nd, ns, "column")
    only_links(ns, nd, T, {p})
    return "on_want", (p, [ask(g, i, hops=1)])


def s18(rng, nd, ns, B):
    """S18 (D): a standing routed ask of a column group, and one other link q of the type, a forwarding one: serving
    the index (one hop left), or found by route_next (two). -> outside: routed to a forwarding node; route_want:
    passed on; on_want: standing until the chunk arrives."""
    p, g, i, T = on_d(rng, nd, ns, "column")
    q = rng.choice([x for x in sorted(nd.peers) if x != p])
    only_links(ns, nd, T, {p, q})
    if rng.random() < 0.5:
        ns["join_recv"][q][T] = join(T, "ALL")
        hops = 1
    else:
        ns["join_recv"][q][T] = join(T, "DECLARED")
        hops = 2
    ns["join_sent"][q][T] = join(T, "ALL")
    return "on_want", (p, [ask(g, i, standing=True, hops=hops)])


def s19(rng, nd, ns, B):
    """S19 (D): a cell of the published block stored at both its places, its column group's and its row group's, with
    one id; asked at both in one frame. -> outside: in our interest; on_want: answered; outside: in our interest;
    on_want: an id answered in this frame."""
    sim, Wm = CTX["sim"], CTX["Wm"]
    cg = rng.choice(CTX["column"])
    b = rng.randrange(sim.ghdr[cg].count)
    f = sim.canonical[cg][b]            # the block's cell, as the simulator made it
    mid = cg + b.to_bytes(4, "little") + Wm.content_id(f)     # its id: its group, index and content id
    rg, c = sim.grow[(sim.ghdr[cg].block, b)], sim.gcol[cg]
    p = rng.choice(sorted(nd.peers))
    for g, i, kind in ((cg, b, "column"), (rg, c, "row")):
        link(ns, p, nd._types[kind])
        ns["desc"][g] = sim.ghdr[g]
        ns["chunks"][g][i] = f
        ns["known_id"][g][i] = mid
    return "on_want", (p, [ask(cg, b), ask(rg, c)])


def s20(rng, nd, ns, B):
    """S20: route_want called itself, on a link whose JOIN of P from us has no duty. -> route_want: not a forwarding
    link."""
    p, g, i, n, P = on_h(rng, nd, ns)
    ns["join_sent"][p][P] = join(P, "ALL", duty="NONE")
    return "route_want", (p, g, i, 1)


# ---- the relation scenarios' helpers: the type P, the family 0 and the colour 0 unless a row says otherwise

def rel(ns, kind, T_id, d, fam=0, c=0, answer=False):
    """A GRAFT or a PRUNE as the toy's own classes make one (seacast.md §4.1's `Graft(...)`, `Prune(...)`)."""
    if kind == "Graft":
        return ns["Graft"](object_type=T_id, family=fam, colour=c, direction=d, answer=answer)
    return ns["Prune"](object_type=T_id, family=fam, colour=c, direction=d)


def on_rel(rng, nd):
    """The defaults: p, one of the node's peers, a link of P as built, and P."""
    return rng.choice(sorted(nd.peers)), nd._P


def holds(ns, table, q, P, fam=0, c=0):
    """`table[q][P][fam]` holds the colour c: one of the four sets of seacast.md §4.1, written as the toy's add."""
    ns[table][q][P][fam].add(c)


def not_a_link(rng, ns, p, P):
    """p no link of P, as S1 draws it: its JOIN not received, ours not sent, or ours owed, a third each."""
    r = rng.random()
    if r < 1 / 3:
        F.unwrap(ns["join_recv"])[p].pop(P, None)
    elif r < 2 / 3:
        F.unwrap(ns["join_sent"])[p].pop(P, None)
    else:
        ns["owed_relations"][p].append(ns["Join"](object_type=P.id, interest="ALL", custody_count=0, duty="FORWARD",
                                                  colours=1))


def two_pairs(rng, ns, p, P, owed=None):
    """p holds two pairs of P other than (0, 0), at R's limit of two: (1, 0) pushed to us, and (2, 0) pushed by us
    or, in about half the draws (`owed` None), a GRAFT of ours for it still owed."""
    holds(ns, "push_in", p, P, fam=1)
    if owed is None:
        owed = rng.random() < 0.5
    if owed:
        ns["owed_relations"][p].append(rel(ns, "Graft", P.id, "IN", fam=2))
    else:
        holds(ns, "push_out", p, P, fam=2)


def others(rng, nd, p, lo, hi):
    """lo to hi of the node's peers other than p, drawn."""
    qs = [q for q in sorted(nd.peers) if q != p]
    return rng.sample(qs, rng.randint(lo, hi))


# ---- the relation scenarios, J1 to M4: each record's path, in the twin's labels

def j1(rng, nd, ns, B):
    """J1: a JOIN of a type the node does not run. -> on_join: a type the node does not run."""
    p, P = on_rel(rng, nd)
    return "on_join", (p, ns["Join"](object_type="column", interest="ALL", custody_count=0, duty="FORWARD",
                                     colours=1))


def j2(rng, nd, ns, B):
    """J2: a JOIN of P with two colours, P's M being 1. -> on_join: colours not the type's."""
    p, P = on_rel(rng, nd)
    return "on_join", (p, ns["Join"](object_type=P.id, interest="ALL", custody_count=0, duty="FORWARD", colours=2))


def j3(rng, nd, ns, B):
    """J3: a JOIN of P before ours went. -> on_join: answered."""
    p, P = on_rel(rng, nd)
    F.unwrap(ns["join_sent"])[p].pop(P, None)
    return "on_join", (p, ns["Join"](object_type=P.id, interest="ALL", custody_count=0, duty="FORWARD", colours=1))


def g1(rng, nd, ns, B):
    """G1: a GRAFT of a type the node does not run. -> on_graft: a type the node does not run."""
    p, P = on_rel(rng, nd)
    return "on_graft", (p, rel(ns, "Graft", "column", "OUT"))


def g2(rng, nd, ns, B):
    """G2: a GRAFT of P from no link of P. -> on_graft: a link that has not joined the type."""
    p, P = on_rel(rng, nd)
    not_a_link(rng, ns, p, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "OUT"))


def g3(rng, nd, ns, B):
    """G3 (R): p's GRAFT of a third pair, p at the limit of two. -> relation_room: at the limit; on_graft: no room."""
    p, P = on_rel(rng, nd)
    two_pairs(rng, ns, p, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "OUT"))


def g4(rng, nd, ns, B):
    """G4: p pushes us already. -> relation_room: the pair held; on_graft: pushes to us held, yes again."""
    p, P = on_rel(rng, nd)
    holds(ns, "push_in", p, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "OUT"))


def g5(rng, nd, ns, B):
    """G5: p pushes us already, and the GRAFT is a yes or answers ours. -> relation_room: the pair held; on_graft:
    pushes to us held, no answer."""
    p, P = on_rel(rng, nd)
    holds(ns, "push_in", p, P)
    answer = rng.random() < 0.5
    if not answer:
        holds(ns, "grafted_in", p, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "OUT", answer=answer))


def g6(rng, nd, ns, B):
    """G6: the defaults. -> relation_room: below the limit; on_graft: pushes to us, yes."""
    p, P = on_rel(rng, nd)
    return "on_graft", (p, rel(ns, "Graft", P.id, "OUT"))


def g7(rng, nd, ns, B):
    """G7 (W): 12 to 14 other peers push us already, P's F_HI being 12. -> relation_room: below the limit; on_graft:
    pushes to us, no."""
    p, P = on_rel(rng, nd)
    for q in others(rng, nd, p, 12, 14):
        holds(ns, "push_in", q, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "OUT"))


def g8(rng, nd, ns, B):
    """G8: we push p already. -> relation_room: the pair held; on_graft: our pushes held, yes again."""
    p, P = on_rel(rng, nd)
    holds(ns, "push_out", p, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "IN"))


def g9(rng, nd, ns, B):
    """G9: we push p already, and the GRAFT is a yes or answers ours. -> relation_room: the pair held; on_graft: our
    pushes held, no answer."""
    p, P = on_rel(rng, nd)
    holds(ns, "push_out", p, P)
    answer = rng.random() < 0.5
    if not answer:
        holds(ns, "grafted_out", p, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "IN", answer=answer))


def g10(rng, nd, ns, B):
    """G10: p asks us to push it. -> relation_room: below the limit; on_graft: our pushes, yes."""
    p, P = on_rel(rng, nd)
    return "on_graft", (p, rel(ns, "Graft", P.id, "IN"))


def g11(rng, nd, ns, B):
    """G11: p asks us to push it, our JOIN of P to p of no duty. -> relation_room: below the limit; on_graft: our
    pushes, no."""
    p, P = on_rel(rng, nd)
    ns["join_sent"][p][P] = join(P, "ALL", duty="NONE")
    return "on_graft", (p, rel(ns, "Graft", P.id, "IN"))


def g12(rng, nd, ns, B):
    """G12 (WU): a symmetric GRAFT, up to 5 other peers in the relation both ways. -> relation_room: below the limit;
    on_graft: symmetric, yes."""
    p, P = on_rel(rng, nd)
    for q in others(rng, nd, p, 0, 5):
        holds(ns, "push_in", q, P)
        holds(ns, "push_out", q, P)
    return "on_graft", (p, rel(ns, "Graft", P.id, "BOTH"))


def g13(rng, nd, ns, B):
    """G13 (WU): a symmetric GRAFT that answers ours, or a yes to a relation held. -> relation_room: the pair held;
    on_graft: symmetric, taken without an answer."""
    p, P = on_rel(rng, nd)
    answer = False
    if rng.random() < 0.5:
        holds(ns, "grafted_in" if rng.random() < 0.5 else "grafted_out", p, P)
    else:
        holds(ns, "push_in", p, P)
        answer = True
    return "on_graft", (p, rel(ns, "Graft", P.id, "BOTH", answer=answer))


def g14(rng, nd, ns, B):
    """G14 (WU): a symmetric GRAFT, our JOIN of P to p of no duty. -> relation_room: below the limit; on_graft:
    symmetric, no."""
    p, P = on_rel(rng, nd)
    ns["join_sent"][p][P] = join(P, "ALL", duty="NONE")
    return "on_graft", (p, rel(ns, "Graft", P.id, "BOTH"))


def q1(rng, nd, ns, B):
    """Q1: a PRUNE of a type the node does not run. -> on_prune: a type the node does not run."""
    p, P = on_rel(rng, nd)
    return "on_prune", (p, rel(ns, "Prune", "column", "BOTH"))


def q2(rng, nd, ns, B):
    """Q2: a PRUNE of P from no link of P. -> on_prune: a link that has not joined the type."""
    p, P = on_rel(rng, nd)
    not_a_link(rng, ns, p, P)
    return "on_prune", (p, rel(ns, "Prune", P.id, "BOTH"))


def q3(rng, nd, ns, B):
    """Q3: a PRUNE of a relation held both ways, and one backoff of the family 1, run out a second ago. -> on_prune:
    a backoff run out; relation_room: the pair held; on_prune: pushes to us end, no backoff; on_prune: our pushes
    end, no backoff."""
    p, P = on_rel(rng, nd)
    holds(ns, "push_in", p, P)
    holds(ns, "push_out", p, P)
    ns["backoff"][p][P][1][(0, "IN")] = ns["now"] - 1
    return "on_prune", (p, rel(ns, "Prune", P.id, "BOTH"))


def q4(rng, nd, ns, B):
    """Q4 (R): a PRUNE of a third pair, p at the limit of two. -> relation_room: at the limit; on_prune: no room."""
    p, P = on_rel(rng, nd)
    two_pairs(rng, ns, p, P)
    return "on_prune", (p, rel(ns, "Prune", P.id, "OUT"))


def q5(rng, nd, ns, B):
    """Q5 (R): a PRUNE of a relation held both ways, R's backoff 1. -> relation_room: the pair held; on_prune: pushes
    to us end, a backoff; on_prune: our pushes end, a backoff."""
    p, P = on_rel(rng, nd)
    holds(ns, "push_in", p, P)
    holds(ns, "push_out", p, P)
    return "on_prune", (p, rel(ns, "Prune", P.id, "BOTH"))


def a1(rng, nd, ns, B):
    """A1 (R): graft called itself, p at the limit of two. -> relation_room: at the limit; graft: no room."""
    p, P = on_rel(rng, nd)
    two_pairs(rng, ns, p, P, owed=False)
    return "graft", (p, P, 0, 0, "IN")


def both_ways(ns, qs, P):
    for q in qs:
        holds(ns, "push_in", q, P)
        holds(ns, "push_out", q, P)


def m1(rng, nd, ns, B):
    """M1 (WU): 0 to 5 peers in the relation both ways, and no peer's JOIN of P of duty FORWARD, so no candidate. ->
    maintain_relations: below the floor."""
    P = nd._P
    for q in sorted(nd.peers):
        ns["join_recv"][q][P] = join(P, "ALL", duty="NONE")
    both_ways(ns, rng.sample(sorted(nd.peers), rng.randint(0, 5)), P)
    return "maintain_relations", (P,)


def m2(rng, nd, ns, B):
    """M2 (WU): 6 to 10 peers in the relation both ways, and one more that only pushes us. -> maintain_relations: a
    half-held relation grafted; relation_room: the pair held; graft: sent."""
    P = nd._P
    qs = rng.sample(sorted(nd.peers), rng.randint(7, 11))
    both_ways(ns, qs[1:], P)
    holds(ns, "push_in", qs[0], P)
    return "maintain_relations", (P,)


def m3(rng, nd, ns, B):
    """M3 (WU): 12 to 15 peers in the relation both ways, P's F_HI being 12. -> maintain_relations: at the cap."""
    P = nd._P
    both_ways(ns, rng.sample(sorted(nd.peers), rng.randint(12, 15)), P)
    return "maintain_relations", (P,)


def m4(rng, nd, ns, B):
    """M4 (W): 13 to 15 peers push us, P's F_HI being 12. -> maintain_relations: past the cap, one way."""
    P = nd._P
    for q in rng.sample(sorted(nd.peers), rng.randint(13, 15)):
        holds(ns, "push_in", q, P)
    return "maintain_relations", (P,)


SETS = {     # name: (frame, the nodes its records are made at, its scenarios, what each record starts from)
    "control": ("H", (2, 3, 4), {"note_claim": note_claim}, None),
    "serve_h": ("H", (2, 3, 4), {"S1": s1, "S2": s2, "S3": s3, "S4": s4, "S5": s5, "S6": s6, "S7": s7, "S8": s8,
                                 "S9": s9, "S20": s20}, "serve"),
    "serve_hplus": ("H+", (2, 3, 4), {"S10": s10, "S11": s11}, "serve"),
    "serve_d": ("D", tuple(range(2, 31)), {"S12": s12, "S13": s13, "S14": s14, "S15": s15, "S16": s16, "S17": s17,
                                           "S18": s18, "S19": s19}, "serve"),
    "upkeep_h": ("H", (2, 3, 4), {"J1": j1, "J2": j2, "J3": j3, "G1": g1, "G2": g2, "G4": g4, "G5": g5, "G6": g6,
                                  "G8": g8, "G9": g9, "G10": g10, "G11": g11, "Q1": q1, "Q2": q2, "Q3": q3},
                 "upkeep"),
    "upkeep_r": ("R", (2, 3, 4), {"G3": g3, "Q4": q4, "Q5": q5, "A1": a1}, "upkeep"),
    "upkeep_w": ("W", (2, 3, 4), {"G7": g7, "M4": m4}, "upkeep"),
    "upkeep_wu": ("WU", (2, 3, 4), {"G12": g12, "G13": g13, "G14": g14, "M1": m1, "M2": m2, "M3": m3}, "upkeep"),
}
# what a record starts from: the tables put back as the build left them (all but the JOIN tables empty then), and
# the tables emptied
STARTS = {"serve": (RESET, ()), "upkeep": (("join_recv", "join_sent"), RELATIONS)}
FRAMES = {   # name: (run.py's arguments, the config's additions, a block published, each recording node's peers)
    "H": (HAND5, None, False, 4), "H+": (HAND5, {"MAX_PENDING_GROUPS": 1, "SERVE_BUDGET": 2}, False, 4),
    "D": (DAS30, None, True, None), "R": (HAND5 + ["--prune-backoff", "1"], {"MAX_RELATIONS": 2}, False, 4),
    "W": (W16, None, False, 16), "WU": (W16 + ["--upkeep", "on"], None, False, 16)}


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("toy")
    ap.add_argument("out")
    ap.add_argument("--set", default="control", choices=sorted(SETS))
    ap.add_argument("--n", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args(argv)
    frame, nodes, scenarios, start = SETS[a.set]
    toy = Path(a.toy).resolve()
    tr = trace3.Tracer3(toy, a.out, ["directed_seacast", "--doc", "seacast", f"--n={a.n}", f"--seed={a.seed}",
                                     f"--set={a.set}"], whole=True)
    try:
        args, config, publish, npeers = FRAMES[frame]
        sim = build(tr, args, config, publish)
        setup = dict(tr.counts)
        if npeers is not None and any(len(sim.nodes[k].peers) != npeers for k in nodes):
            raise SystemExit(f"directed_seacast: frame {frame}: the recording nodes' peers are "
                             f"{[len(sim.nodes[k].peers) for k in nodes]}, not {npeers} each")
        import bits as B                # noqa: E402: the pinned toy's
        import random
        import wire as Wm               # noqa: E402
        CTX.update(sim=sim, Wm=Wm, tr=tr, column=sorted(g for g, t in sim.gtype.items() if t == "column"),
                   row=sorted(g for g, t in sim.gtype.items() if t == "row"))
        kept, emptied = STARTS[start] if start else ((), ())
        saved = {k: {name: save(k, name, F.unwrap(sim.nodes[k].ns[name])) for name in kept} for k in nodes}
        rng = random.Random(a.seed)
        calls = Counter()
        keys = sorted(scenarios)
        for _ in range(a.n):
            k = rng.choice(nodes)
            nd = sim.nodes[k]
            ns = nd.ns
            ns["now"] = rng.choice([1.0, 3.25])
            key = rng.choice(keys)
            if start:                   # the build's state, and no asker places; nothing an earlier record queued
                for name in kept:
                    restore(F.unwrap(ns[name]), saved[k][name])
                for name in emptied:
                    F.unwrap(ns[name]).clear()
                nd.want_unknown.clear()
                queues = F.unwrap(ns["queue"])
                for q in nd.peers:
                    if q in queues:
                        queues[q].urgent.clear()
                        queues[q].normal.clear()
            name, fargs = scenarios[key](rng, nd, ns, B)
            ns[name](*fargs)
            calls[key] += 1
    except BaseException as stop:       # trace3.py's main: the trace closed with the first reason in its trailer
        try:
            tr.close(stopped=(f"{type(stop).__name__}: {stop}".splitlines() or [""])[0])
        except BaseException as later:
            print(f"directed_seacast: (at the close, after the stop) {type(later).__name__}: {later}", file=sys.stderr)
        raise
    tr.close()
    if setup:
        print(f"directed_seacast: setup: {sum(setup.values())} records, {dict(sorted(setup.items()))}",
              file=sys.stderr)
    for key in sorted(calls, key=lambda s: (len(s), s)):
        print(f"directed_seacast: {key}: {calls[key]}", file=sys.stderr)
    print(f"directed_seacast: {sum(tr.counts.values())} records, {dict(sorted(tr.counts.items()))}", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
