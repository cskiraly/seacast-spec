#!/usr/bin/env python3
"""The records of protocol-v2.md's covered functions: each one's "args" and "ret" as the twin's `runV2` reads them.

trace3.py's Tracer3 writes one record per traced call. Under --doc v2, for a name of `manifest_v2.COVERED`, its
`args_of` and `ret_of` hand the call to `args_v2(tr, fn, args, kw)` and `ret_v2(tr, fn, r)` here. `runV2`
(SpecTwin/V2/Replay.lean) has one case per name, `| "name", #[a, b, ...] =>`, which fixes the arguments' array and
how each argument and the return are read; TABLE below writes exactly that, one entry per name, in COVERED's order.

- The arguments are bound to the name's parameters as protocol-v2.md's `def` has them (protocol.md's for
  `on_pace_tick` and `on_block_installed`), so that a keyword is put in its place; any other shape of the call is a
  TypeError, and so is any leaf the twin's reader would not take. `forward` and `ask_sample` have two cases in
  runV2, with and without their last (default) argument: the record has the last one exactly where the call gave it.
- The leaves are Tracer3's encoders where theirs is what the twin reads (`tr.chunk`, `tr.wchunk`, `tr.descriptor`,
  `tr.key`, `tr.ask_v2`, `tr.qentry` under v2, `tr.rel_msg`, `tr.nat`, `tr.integer`, `tr.flag`, `tr.nothing`), and
  small functions here, each named for the Lean reader it matches, where the tracer has none: a HAVE, a node's
  record, a type by its id, a direction, a bitmap, groups and indices, a time as its word.
- A chunk is wide (`tr.wchunk`) where it arrives or waits, as under protocol.md: `on_chunk`, `on_validated`,
  `defer` (`defer` stores it in `pending`, whose rows are written wide). Everywhere else it is narrow (`tr.chunk`):
  the twin enqueues `forward`'s and `push_rebuilt_as_source`'s chunk and compares it with the tape's narrow one.

`python3 records_v2.py ../SpecTwin/V2/Replay.lean` is the arity check (check.sh's tables step): for each covered name
it runs args_v2 on stub arguments and compares the array's length with runV2's case, and requires each length runV2's
cases take to be given by some stub call; it compares the table's parameters with the document's `def`, and runs
ret_v2 on a stub return. It imports no toy and builds no Tracer3: its tracer is a stand-in that has
Tracer3's own encoders bound onto a stub object, with stub classes for the toy's wire and node modules.
"""
import ast
import inspect
import json
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))           # an isolated Python (-I) puts no directory there itself
sys.path.insert(0, str(HERE / "gen"))
import footprint as F                   # noqa: E402: a queue's view, unwrapped (as trace3's rarest)
import manifest_v2                      # noqa: E402: gen/manifest_v2.py, COVERED
import schema_v2                        # noqa: E402: gen/schema_v2.py, type_id and DIRECTIONS
from trace61 import fbits               # noqa: E402

ROOT = HERE.parents[2]                  # the spec repository: protocol-v2.md and protocol.md
_UNSET = object()                       # a default argument the call left out


# ---- the leaves the tracer has no helper for, each named for the Lean reader it matches

def group(g):                           # Replay.groupKey: 64 hex digits
    if not isinstance(g, bytes) or len(g) != 32:
        raise TypeError(f"records_v2: not a group: {g!r}")
    return g.hex()


def root_key(b):                        # rootKey: a block root, 64 hex digits
    if not isinstance(b, bytes) or len(b) != 32:
        raise TypeError(f"records_v2: not a block root: {b!r}")
    return b.hex()


def peer(tr, p):                        # nat: a peer, the toy's node id
    return tr.nat(p)


def opt_peer(tr, p):                    # optOf nat: a peer, or none (a decode's own chunk, no sender)
    return None if p is None else tr.nat(p)


def peers(tr, xs):                      # peers: a list, in the Python's order (a set's too: compared as a set there)
    return [tr.nat(q) for q in xs]


def type_id(T):                         # typeId: an object type by its id
    return schema_v2.type_id(T)


def direction(d):                       # direction: "OUT", "IN" or "BOTH", as the toy's strings
    if not isinstance(d, str) or d not in schema_v2.DIRECTIONS:
        raise TypeError(f"records_v2: not a direction: {d!r}")
    return d


def bits_nat(tr, b):                    # nat: a bitmap of held or sent indices, its natural number
    if not isinstance(b, tr.N.B.Bits):
        raise TypeError(f"records_v2: not a bitmap: {b!r}")
    return tr.nat(b.v)


def bits_int(tr, b):                    # intOf: an interest, which can be every index (Bits(-1)) and its complements
    if not isinstance(b, tr.N.B.Bits):
        raise TypeError(f"records_v2: not a bitmap: {b!r}")
    return tr.integer(b.v)


def gi_list(tr, xs):                    # giList: [[group, index], ...]
    out = []
    for x in xs:
        if not isinstance(x, (tuple, list)) or len(x) != 2:
            raise TypeError(f"records_v2: not a group and an index: {x!r}")
        out.append([group(x[0]), tr.nat(x[1])])
    return out


def word(x, what):                      # floatOf, bits64: a time or a float as its 64-bit IEEE word, finite
    if isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x):
        raise TypeError(f"records_v2: {what} is not a finite number: {x!r}")
    return fbits(x)


def have(tr, h):                        # haveOf: ["have", g, bits, offer, claim_all, complete]
    return ["have", group(getattr(h, "group", None)), bits_nat(tr, getattr(h, "bits", None)),
            tr.flag(getattr(h, "offer", None), "a HAVE's offer"),
            tr.flag(getattr(h, "claim_all", None), "a HAVE's claim_all"),
            tr.flag(getattr(h, "complete", None), "a HAVE's complete")]


def cover(tr, r):
    """coverOf: a record of a node or of a link, {"id": p, "families": [...], "high": b}, with the fields it has
    (link_cover's has no id, floor_candidates' no flag). Any other attribute has no place in the form."""
    extra = set(getattr(r, "__dict__", {})) - {"id", "families", "high"}
    if extra or not hasattr(r, "families"):
        raise TypeError(f"records_v2: not a node's record of id, families and high: {r!r} ({sorted(extra)})")
    out = {}
    if hasattr(r, "id"):
        out["id"] = tr.nat(r.id)
    out["families"] = [tr.integer(f) for f in r.families]
    if hasattr(r, "high"):
        out["high"] = tr.flag(r.high, "a node's record's high")
    return out


def need_pairs(tr, need):               # pairs intOf intOf: counted's need, [[family, count], ...], the dict's order
    if not isinstance(need, dict):
        raise TypeError(f"records_v2: counted's need is not a dict: {need!r}")
    return [[tr.integer(f), tr.integer(n)] for f, n in need.items()]


def mids(xs):                           # mid: a gossip id, a chunk's structured id (56 bytes) as its 112 hex digits
    out = []
    for m in xs:
        if not isinstance(m, bytes) or len(m) != 56:
            raise TypeError(f"records_v2: a gossip id that is no structured id: {m!r}")
        out.append(m.hex())
    return out


def index_chunks(tr, xs):               # pairs nat chunkF: rebuilt chunks with their indices, each chunk narrow
    out = []
    for x in xs:
        if not isinstance(x, (tuple, list)) or len(x) != 2:
            raise TypeError(f"records_v2: not an index and a chunk: {x!r}")
        out.append([tr.nat(x[0]), tr.chunk(x[1])])
    return out


def gi_ask(tr, gi):
    """optOf askV2Of: group_index(a)'s result. None; an ask by index with its flags (a WantIndex, a FlaggedWant:
    tr.ask_v2); or a structured id's group and index (the toy's GroupIndex), which the twin's groupIndex makes an
    ask by index with no flags: [[group, index], false, 0, false]."""
    if gi is None:
        return None
    if isinstance(gi, tr.Wm.WantIndex):
        return tr.ask_v2(gi)
    if isinstance(gi, tr.N.GroupIndex):
        return [[group(gi.group), tr.nat(gi.index)], tr.flag(gi.standing, "a group index's standing"),
                tr.nat(gi.hops), tr.flag(gi.probe, "a group index's probe")]
    raise TypeError(f"records_v2: not a group index: {gi!r}")


def queue_peer(tr, q):                  # nat: the peer whose queue q is, in the node's queue table by identity (rarest)
    q = F.unwrap(q)
    ps = [k for k, v in dict.items(tr.cur_queue) if v is q]
    if len(ps) != 1:
        raise TypeError(f"records_v2: a queue that is no peer's queue[p] at this node: {q!r}")
    return tr.nat(ps[0])


def verdict(x):                         # verdict: level 1's result
    if x not in ("ACCEPT", "REJECT", "DEFER"):
        raise TypeError(f"records_v2: not a result of level 1: {x!r}")
    return x


def repair_verdict(x):                  # repairVerdictOf
    if x not in ("REPAIRED", "NOT_REPAIRED", "ASKED"):
        raise TypeError(f"records_v2: not a repair verdict: {x!r}")
    return x


def promise(tr, r):                     # probePromiseOf: null, or [[key, peer], time]
    if r is None:
        return None
    if not (isinstance(r, tuple) and len(r) == 2 and isinstance(r[0], tuple) and len(r[0]) == 2):
        raise TypeError(f"records_v2: not a promise ((ask, peer), time): {r!r}")
    (a, p), t = r
    return [[tr.key(a), tr.nat(p)], word(t, "a promise's time")]


# ---- the returns

def none(tr, r):                        # none_: JSON null
    return tr.nothing(r)


def boolean(tr, r):                     # boolOf
    return tr.flag(r, "the return")


def nat(tr, r):                         # nat
    return tr.nat(r)


def forward_args(tr, f, from_peer, axes=_UNSET):        # two cases: the axes where the call gave them
    out = [tr.chunk(f), peer(tr, from_peer)]
    return out if axes is _UNSET else out + [None if axes is None else gi_list(tr, axes)]


def ask_sample_args(tr, g, i, first=_UNSET):            # two cases: `first` where the call gave it
    out = [group(g), tr.nat(i)]
    return out if first is _UNSET else out + [tr.flag(first, "ask_sample's first")]


def relation_args(tr, p, T, fam, c, d):                 # prune, yes, no: [p, T, family, colour, direction]
    return [peer(tr, p), type_id(T), tr.integer(fam), tr.nat(c), direction(d)]


def g_only(tr, g):
    return [group(g)]


def g_i(tr, g, i):
    return [group(g), tr.nat(i)]


def p_g(tr, p, g):
    return [peer(tr, p), group(g)]


def p_g_i(tr, p, g, i):
    return [peer(tr, p), group(g), tr.nat(i)]


def g_at(tr, g, at):
    return [group(g), word(at, "a time")]


# name: (the Python's parameters, its record's "args", its record's "ret"), in COVERED's order
TABLE = {
    # §1.4 and §4.1
    "colour_of": ("g, i", g_i, nat),
    "send_relation": ("p, m", lambda tr, p, m: [peer(tr, p), tr.rel_msg(m)], none),
    "send_join": ("p, j", lambda tr, p, j: [peer(tr, p), tr.rel_msg(j, "join")], none),
    "prune": ("q, T, fam, c, d", relation_args, none),
    "yes": ("p, T, fam, c, d", relation_args, none),
    "no": ("p, T, fam, c, d", relation_args, none),
    "queue_owed_relations": ("p", lambda tr, p: [peer(tr, p)], none),
    "interest_of_peer": ("p, g", p_g, bits_int),
    "wants_from_me": ("p, g", p_g, bits_int),
    "serves": ("q, g, i", p_g_i, boolean),
    "counted": ("need, r, T", lambda tr, need, r, T: [need_pairs(tr, need), cover(tr, r), type_id(T)],
                lambda tr, r: [tr.integer(f) for f in r]),
    "keep_coverage": ("T", lambda tr, T: [type_id(T)], none),
    "keep_floor": ("T", lambda tr, T: [type_id(T)], none),
    # §4.2, §4.4, §4.7 to §4.9
    "fills": ("g, i", g_i, gi_list),
    "note_push": ("p, g, i", p_g_i, none),
    "suppression_scope": ("g", g_only, peers),      # a set, in the Python's order: runV2 compares it as a set
    "holding_of": ("g, bits", lambda tr, g, bits: [group(g), bits_nat(tr, bits)], have),
    "send_have": ("p, g", p_g, none),
    "announce": ("p, g, bits", lambda tr, p, g, bits: [peer(tr, p), group(g), bits_nat(tr, bits)], none),
    "announce_extra": ("g, i", g_i, peers),
    "join_push": ("p, T, fam, c", lambda tr, p, T, fam, c: [peer(tr, p), type_id(T), tr.integer(fam), tr.nat(c)],
                  none),
    "source_pool": ("T, g, c", lambda tr, T, g, c: [type_id(T), group(g), tr.nat(c)], peers),
    "unpush": ("p, g, i", p_g_i, none),
    "candidates_for_source": ("f", lambda tr, f: [tr.chunk(f)], peers),
    "origin_written": ("f", lambda tr, f: [tr.chunk(f)], none),
    "offer_at_publish": ("g, d", lambda tr, g, d: [group(g), tr.descriptor(d)], none),   # a header's seven fields
    "origin_acked": ("g, i", g_i, none),
    "send_gossip": ("q, ids", lambda tr, q, ids: [peer(tr, q), mids(ids)], none),
    "projected": ("p, g", p_g, boolean),
    # the probe, §4.5's standing answers, §4.6's repair checks
    "gated": ("a", lambda tr, a: [tr.key(a)], boolean),
    "settle_probe": ("g, verdict", lambda tr, g, verdict: [group(g), None if verdict is None
                                                           else tr.flag(verdict, "settle_probe's verdict")], none),
    "probe_answer": ("g, i, p", lambda tr, g, i, p: [group(g), tr.nat(i), opt_peer(tr, p)], none),
    "probe_promise": ("g, i", g_i, promise),
    "probe_waits": ("a, p", lambda tr, a, p: [tr.ask_v2(a), peer(tr, p)], boolean),
    "probe_settled": ("a", lambda tr, a: [tr.ask_v2(a)], boolean),
    "probe_of_claim": ("p, gi", lambda tr, p, gi: [peer(tr, p), gi_ask(tr, gi)], boolean),
    "serve_probe": ("p, g, f", lambda tr, p, g, f: [peer(tr, p), group(g), tr.chunk(f)], none),
    "serve_standing": ("g, i", g_i, none),
    "serve_waiting_probe": ("g, i", g_i, none),
    "known_in_scope": ("g", g_only, bits_nat),
    "known_across": ("g", g_only, bits_nat),
    "ask_custodian": ("g, i", g_i, boolean),
    "repair_verdict": ("g", g_only, lambda tr, r: repair_verdict(r)),
    "owed_missing": ("g", g_only, boolean),
    # fill, §4.6's completion, decoding and claims, filter_entry
    "push_rebuilt_as_source": ("g2, items", lambda tr, g2, xs: [group(g2), index_chunks(tr, xs)], none),
    "push_rebuilt": ("g, new", lambda tr, g, new: [group(g), [tr.nat(i) for i in new]], none),
    "fill": ("g, i, f, p", lambda tr, g, i, f, p: [group(g), tr.nat(i), tr.chunk(f), opt_peer(tr, p)], none),
    "arm": ("g, at", g_at, none),
    "check_completion": ("g", g_only, none),
    "defer_on_claim": ("g", g_only, none),
    "reconsider": ("g, at", g_at, none),
    "decode_group": ("g", g_only, none),
    "claims_close": ("p", lambda tr, p: [peer(tr, p)], none),
    "note_claim": ("p, g", p_g, none),
    "filter_entry": ("p, entry", lambda tr, p, entry: [peer(tr, p), tr.qentry(entry)],   # v2's forms (tr.doc_v2)
                     lambda tr, r: None if r is None else tr.qentry(r)),
    # forward, §4.2's chunk, §4.3's holding and offer
    "forward": ("f, from_peer, axes=None", forward_args, none),
    "on_validated": ("p, f, result", lambda tr, p, f, result: [peer(tr, p), tr.wchunk(f), verdict(result)], none),
    "defer": ("p, f", lambda tr, p, f: [peer(tr, p), tr.wchunk(f)], none),
    "on_chunk": ("p, f", lambda tr, p, f: [peer(tr, p), tr.wchunk(f)], none),
    "on_holding": ("p, h", lambda tr, p, h: [peer(tr, p), have(tr, h)], none),
    "on_offer": ("p, h", lambda tr, p, h: [peer(tr, p), have(tr, h)], lambda tr, r: [tr.key(a) for a in r]),
    # §4.10, §4.12, §4.13
    "ask_scale": ("", lambda tr: [], lambda tr, r: word(r, "ask_scale's return")),
    "own_chunk": ("e", lambda tr, e: [tr.qentry(e)], boolean),
    "pick": ("q, ks", lambda tr, q, ks: [queue_peer(tr, q), [tr.nat(k) for k in ks]], nat),
    "choose": ("q", lambda tr, q: [queue_peer(tr, q)], nat),
    "ask_sample": ("g, i, first=False", ask_sample_args, none),
    "resample": ("g, i, q, first", lambda tr, g, i, q, first: [group(g), tr.nat(i), peer(tr, q),
                                                               tr.flag(first, "resample's first")], none),
    "sample": ("g, bits", lambda tr, g, bits: [group(g), bits_nat(tr, bits)], none),
    # protocol.md's two that call v2's functions, in their v2 forms
    "on_pace_tick": ("", lambda tr: [], none),
    "on_block_installed": ("root", lambda tr, root: [root_key(root)], none),
}

if set(TABLE) != set(manifest_v2.COVERED):
    raise SystemExit(f"records_v2: the table's names are not manifest_v2.COVERED: missing "
                     f"{sorted(set(manifest_v2.COVERED) - set(TABLE))}, "
                     f"extra {sorted(set(TABLE) - set(manifest_v2.COVERED))}")


def signature(params):
    """The Python's parameters, "a, b, c=None", as a signature that binds a call's arguments and keywords."""
    ps = []
    for p in filter(None, (x.strip() for x in params.split(","))):
        name, eq, default = p.partition("=")
        ps.append(inspect.Parameter(name.strip(), inspect.Parameter.POSITIONAL_OR_KEYWORD,
                                    default=ast.literal_eval(default.strip()) if eq else inspect.Parameter.empty))
    return inspect.Signature(ps)


SIGS = {name: signature(params) for name, (params, _, _) in TABLE.items()}


def args_v2(tr, fn, args, kw=None):
    """A covered function's record "args", from the call's positional arguments and keywords. Only the arguments
    the call gave are bound, so that a default left out stays out (forward's axes, ask_sample's first)."""
    if fn not in TABLE:
        raise TypeError(f"records_v2: not a covered name: {fn}")
    kw = kw or {}
    try:
        bound = SIGS[fn].bind(*args, **kw)
    except TypeError as e:
        raise TypeError(f"records_v2: {fn} called with {len(args)} arguments and keywords {sorted(kw)}, where its "
                        f"parameters are ({TABLE[fn][0]}): {e}") from None
    return TABLE[fn][1](tr, *bound.arguments.values())     # in the parameters' order, the call's own given


def ret_v2(tr, fn, r):
    """A covered function's record "ret", from the Python's return value."""
    if fn not in TABLE:
        raise TypeError(f"records_v2: not a covered name: {fn}")
    return TABLE[fn][2](tr, r)


# ---- the arity check

HELPERS = ("nat", "integer", "flag", "nothing", "chunk", "wchunk", "descriptor", "blob", "mid_of", "key", "ask_key",
           "ask_v2", "qentry", "qmsg", "qmsg_v2", "rel_msg", "offer", "holding", "ihave_entry")


def stand_in():
    """The tracer for the check: Tracer3's own encoders (HELPERS, trace61's `key` among them), bound onto a stub
    object whose `Wm` and `N` hold stub classes for the toy's (wire.WantIndex, wire.Blob, node.GroupIndex,
    bits.Bits). No toy is imported and no Tracer3 is built. With the stub values: {name: ([(args, kw), ...], a
    return)}, each name's call shapes and a return to run ret_v2 on."""
    import trace3                       # noqa: E402: imports no toy at module level
    from types import SimpleNamespace as NS

    class Bits:
        def __init__(self, v=0):
            self.v = v

    class WantIndex:
        standing, hops, probe = False, 0, False

        def __init__(self, group, index):
            self.group, self.index = group, index

    class FlaggedWant(WantIndex):
        def __init__(self, group, index, standing, hops, probe=False):
            super().__init__(group, index)
            self.standing, self.hops, self.probe = standing, hops, probe

    class GroupIndex:
        standing, hops, probe = False, 0, False

        def __init__(self, group, index):
            self.group, self.index = group, index

    class Blob:
        def __init__(self, n, tag):
            self.n, self.tag = n, tag

        def __len__(self):
            return self.n

    class HaveBitmap:
        pass

    raw = {}
    for n in HELPERS:
        c = next((c for c in trace3.Tracer3.__mro__ if n in vars(c)), None)
        if c is None:
            raise SystemExit(f"records_v2: trace3.Tracer3 has no {n}")
        raw[n] = vars(c)[n]             # a function, or a staticmethod as it is
    tr = type("StandIn", (), raw)()
    tr.Wm = NS(WantIndex=WantIndex, Blob=Blob, HaveBitmap=HaveBitmap,
               is_have_bitmap=lambda x: isinstance(x, HaveBitmap))
    tr.N = NS(B=NS(Bits=Bits), GroupIndex=GroupIndex)
    tr.doc_v2, tr.doc_mid, tr.cur_nid, tr.doc_message_id = True, {}, None, None
    queue = NS(normal=[], urgent=[])
    tr.cur_queue = {4: queue, 7: NS()}

    g, g2, root = bytes(range(32)), bytes(range(1, 33)), bytes(32)
    d = NS(version=2, hash_id=0, encoding=1, count=2, segment_size=11660, total_length=11660, root=bytes(range(2, 34)))
    f = NS(group=g, index=0, slot=1, beacon_block_root=root, mid=g + bytes(24), descriptor=d, proof=[bytes(32)],
           data=Blob(11660, ("payload", 1)))
    T = NS(id="column", name="column")
    h = NS(group=g, bits=Bits(3), offer=False, claim_all=True, complete=False)
    entry = NS(chunk=f, control=None, solicited=True)
    ask, flagged = WantIndex(g, 1), FlaggedWant(g, 1, True, 1, False)
    rec = NS(id=7, families=[3, 40], high=False)
    join = NS(object_type="column", interest="DERIVED", custody_count=4, duty="FORWARD", colours=1)
    graft = NS(object_type="column", family=5, colour=0, direction="OUT", answer=False)
    one = lambda *a, **k: [(a, k)]      # noqa: E731
    stubs = {
        "colour_of": (one(g, 1), 0), "send_relation": (one(4, graft), None), "send_join": (one(4, join), None),
        "prune": (one(7, T, 5, 0, "IN"), None), "yes": (one(4, T, -1, 0, "BOTH"), None),
        "no": (one(4, T, 5, 0, "OUT"), None), "queue_owed_relations": (one(4), None),
        "interest_of_peer": (one(4, g), Bits(-1)), "wants_from_me": (one(4, g), Bits(-4)),
        "serves": (one(7, g, 1), True), "counted": (one({3: 1, 40: 0}, rec, T), [3]),
        "keep_coverage": (one(T), None), "keep_floor": (one(T), None),
        "fills": (one(g, 1), [(g, 1), (g2, 0)]), "note_push": (one(4, g, 1), None),
        "suppression_scope": (one(g), {2, 4}), "holding_of": (one(g, Bits(3)), h), "send_have": (one(4, g), None),
        "announce": (one(4, g, Bits(2)), None), "announce_extra": (one(g, 1), [2]),
        "join_push": (one(4, T, 5, 0), None), "source_pool": (one(T, g, 0), [2, 4]),
        "unpush": (one(4, g, 1), None), "candidates_for_source": (one(f), [2]), "origin_written": (one(f), None),
        "offer_at_publish": (one(g, d), None), "origin_acked": (one(g, 1), None),
        "send_gossip": (one(4, [f.mid]), None), "projected": (one(4, g), False),
        "gated": (one(ask), False), "settle_probe": (one(g, None), None), "probe_answer": (one(g, 1, None), None),
        "probe_promise": (one(g, 1), ((ask, 4), 1.5)), "probe_waits": (one(flagged, 4), False),
        "probe_settled": (one(f.mid), False), "probe_of_claim": (one(4, GroupIndex(g, 1)), False),
        "serve_probe": (one(4, g, f), None), "serve_standing": (one(g, 1), None),
        "serve_waiting_probe": (one(g, 1), None), "known_in_scope": (one(g), Bits(3)),
        "known_across": (one(g), Bits(1)), "ask_custodian": (one(g, 1), True),
        "repair_verdict": (one(g), "ASKED"), "owed_missing": (one(g), False),
        "push_rebuilt_as_source": (one(g2, [(0, f)]), None), "push_rebuilt": (one(g, [0, 1]), None),
        "fill": (one(g, 0, f, 4), None), "arm": (one(g, 2.5), None), "check_completion": (one(g), None),
        "defer_on_claim": (one(g), None), "reconsider": (one(g, 2.5), None), "decode_group": (one(g), None),
        "claims_close": (one(4), None), "note_claim": (one(4, g), None), "filter_entry": (one(4, entry), entry),
        "forward": (one(f, 4) + one(f, 4, [(g, 0)]) + one(f, 4, axes=None), None),
        "on_validated": (one(4, f, "ACCEPT"), None), "defer": (one(4, f), None), "on_chunk": (one(4, f), None),
        "on_holding": (one(4, h), None), "on_offer": (one(4, h), [ask]),
        "ask_scale": (one(), 1.0), "own_chunk": (one(entry), True), "pick": (one(queue, [0, 2]), 0),
        "choose": (one(queue), 0), "ask_sample": (one(g, 1) + one(g, 1, first=True) + one(g, 1, False), None),
        "resample": (one(g, 1, 4, True), None), "sample": (one(g, Bits(6)), None),
        "on_pace_tick": (one(), None), "on_block_installed": (one(root), None),
    }
    if set(stubs) != set(TABLE):
        raise SystemExit(f"records_v2: the check's stubs are not the table's names: "
                         f"{sorted(set(stubs) ^ set(TABLE))}")
    return tr, stubs


def runv2_cases(text):
    """runV2's argument arrays by name, from its `| "name", #[a, b, ...] =>` cases: {name: {length, ...}}."""
    body = text[text.index("def runV2"):]
    out = {}
    for m in re.finditer(r'^\s*\|\s*"(\w+)",\s*#\[([^\]]*)\]\s*=>', body, re.M):
        out.setdefault(m.group(1), set()).add(len([x for x in m.group(2).split(",") if x.strip()]))
    return out


def doc_params(*texts):
    """Each top-level `def`'s parameters in the documents' code, the first document's first: {name: "a, b=None"}."""
    out = {}
    for text in texts:
        for m in re.finditer(r"^def (\w+)\(([^)]*)\)", text, re.M):
            ps = []
            for p in filter(None, (x.strip() for x in m.group(2).split(","))):
                name, eq, default = p.partition("=")
                ps.append(name.split(":")[0].strip() + ("=" + default.strip() if eq else ""))
            out.setdefault(m.group(1), ", ".join(ps))
    return out


def check_lines(replay_lean_path, root=ROOT):
    """(ok, line) per covered name: args_v2's length on each stub call against runV2's case, each length the case
    takes against the stub calls' lengths, the table's parameters against the document's `def`, and ret_v2 on a stub
    return."""
    cases = runv2_cases(Path(replay_lean_path).read_text())
    docs = doc_params((root / "protocol-v2.md").read_text(), (root / "protocol.md").read_text())
    tr, stubs = stand_in()
    out = []
    for name in manifest_v2.COVERED:
        calls, r = stubs[name]
        want, bad = cases.get(name, set()), []
        if not want:
            bad.append("no case in runV2")
        if docs.get(name) != TABLE[name][0]:
            bad.append(f"the table's parameters ({TABLE[name][0]}) are not the document's ({docs.get(name)})")
        got = []
        for args, kw in calls:
            try:
                n = len(json.loads(json.dumps(args_v2(tr, name, args, kw))))
            except Exception as e:      # noqa: BLE001: any failure of a writer on its stub is a difference
                bad.append(f"args_v2 on {len(args)} arguments and keywords {sorted(kw)}: {type(e).__name__}: {e}")
                continue
            got.append(n)
            if want and n not in want:
                bad.append(f"args_v2 gives {n} args, runV2's case takes {' or '.join(map(str, sorted(want)))}")
        for n in sorted(want - set(got)):   # each count runV2 takes is given by some stub call: a case none
            bad.append(f"runV2's case takes {n} args, which no stub call gives")    # exercises is not checked
        try:
            json.dumps(ret_v2(tr, name, r))
        except Exception as e:          # noqa: BLE001
            bad.append(f"ret_v2 on a stub return: {type(e).__name__}: {e}")
        if bad:
            out.extend((False, f"{name}: {b}") for b in bad)
        else:
            ns = sorted(set(got))
            s = "s" if len(ns) > 1 else ""
            out.append((True, f"{name}: {' and '.join(map(str, ns))} args, as runV2's case{s}"))
    return out


def arity_check(replay_lean_path):
    """The differences between the record writers and runV2's cases (empty when all agree)."""
    return [line for ok, line in check_lines(replay_lean_path) if not ok]


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else str(HERE.parent / "SpecTwin" / "V2" / "Replay.lean")
    lines = check_lines(path)
    for _, line in lines:
        print(line)
    off = sum(not ok for ok, _ in lines)
    print(f"records_v2: {len(manifest_v2.COVERED)} covered names, {off} difference(s)")
    sys.exit(1 if off else 0)
