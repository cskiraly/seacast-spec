#!/usr/bin/env python3
"""Trace seacast-lite.md's functions (the block, BLOCK below) and §4.2's two readers `held` and `tied_to_root` (the
twin's code over its `mine` and `tied`), with what each call reads and writes (format 7).

Format 7. A trace's first line is its content line (content.py): what it was made from, each file by the sha256 of
its bytes: the two documents, every file of the toy, every file of these tools. Nothing else in a trace names
that, and the line names no commit, path, host or time: the same tree gives the same trace at any place. The
tracer makes sure that what runs is what the line names. Before the toy is imported (`start_check`): its Python
runs isolated (-I), not optimised, writes no bytecode (-B) and looks for bytecode under a prefix that holds no
file (-X pycache_prefix=DIR), and the output lies outside the toy and the tools. At the trace's end
(`loaded_check`): the line made again is the same, and every module loaded from a file is a source the line
names, or the standard library's. --xcheck and --topology are not traced (a dump is an input the line does not
name). layout.py's `python(work)` is the command that meets this.

The second line is the header: the format, `whole`, the tables' names (`own`, `foreign`), the functions traced
and the run's arguments. The third is the one nodes line:
  {"nodes": [{"n": [node, ...], "consts": {...}, "replaced": [name, ...]}, ...]}
one entry per distinct pair of constants and replaced names, with the nodes that have it. A record is replayed with
its own node's constants. At each node every traced name must be seacast-lite.md's own code, a listed wrapper that holds
it, or the node's listed helper (`own_code`); a name on REPLACEABLE that is none of these is a question at that node,
and the node's entry says so.

    python3 trace3.py TOYDIR OUT.jsonl.gz [run.py's arguments ...]

With TRACE3_ONLY=sec61 in its environment it traces §6.1's twelve alone: most of their calls are otherwise inside
an on_ihave record, and these are the baseline's records. The two readers are then not traced, so their reads are
the calling record's. With --doc seacast among run.py's arguments it traces the block's names that are seacast-lite.md's all
the way down (`seacast_kept`, 20 at v0.10). The header's `traced` lists the functions traced, sorted: the block's
(BLOCK), §6.1's twelve, or SEACAST's kept.

As trace61.py (whose encodings this file uses), nothing changes in TOYDIR: each node's namespace is wrapped after
the toy's own overrides, and the cell runs as run.py runs it, printing its digest with --digest, so that a run
shows the tracer perturbs nothing.

The state tables are wrapped too, by footprint.py's recording views, under the schema below. One record per
top-level call of a traced function, per node:
  n, t, fn, args   as in format 2
  reads    the entries of the block's own tables whose first touch in the call was a read, in that order, each
           [table, path, value before the call]; a missing or empty entry has the value null
  scans    the levels read as a whole, each [table, prefix]: every entry under one is in reads
  writes   the entries the call wrote or changed in place, each [table, path, value after the call]
  rest     entries the call did not read, each [table, path, value before the call]: the ones it wrote without
           reading first; and with whole=True (the directed records, whose states are small) every other entry of
           the block's own tables too. The replay loads them beside the reads, and the twin may not read them:
           they are there so that a write that does not do what it notes, or does more, shows.

With whole=True the log is also checked against the state itself, at the two ends of every call (`account`): the
tables as they were before the call must be the record's reads and rest, and as they are after it, those with the
record's writes applied. A write the views did not log, of an entry the call did not otherwise touch, stops the
tracer there. (One to an entry the call had read shows as that entry's changed value, and is recorded as the
write it is.) It is a check of the net change to the own tables: it does not see an unlogged read, a write undone
within the call, or a change in place of another section's value.

The trailer counts the records and the entries of rest, so that a trace cut down does not pass for a whole one.
  tape     what the block asked of the rest of the node, in order: the interface calls as in format 2, and each
           read of another section's table as ["read", table, path, value]; and these:
           - a call on the tape that touched the own tables carries, last, {"cr": [...], "cw": [...]}: the entries
             whose first touch in it was a read, with their values then, and the ones it wrote or changed in place,
             with their values at its end. A call that touched none carries nothing more. Inside a call, other
             sections' tables are its own business: nothing of them goes on the tape;
           - another section's level iterated by the block: ["keys", table, path, [key, ...]], in the Python's order;
             also `list(queue)`, an own table's top level whose order is asked: its rows are read whole, and the
             order is on the tape (["keys", "queue", [], [peer, ...]]);
           - `mesh | {p}` iterated by the block: ["mesh_and", [p], [q, ...]], in the Python's order.
           Every own entry a call on the tape touched first is in `rest`, with its value before the call, and
           `writes` hold the call's whole net change, its callees' writes among them.
  ret, or raises (and raises_key), as in format 2
  reached  the traced functions the call reached, its own among them, sorted
  tables   the own tables its reads, scans and writes name, sorted
These two are the record's last members, in this order: a replay of a subset (--only) picks a record by its line's
end without parsing it.

A path has one element per level of the table: an ask key as trace61.py writes it (hex of a full id, or
[group hex, index]), a peer as the toy's node id, a group as hex, a chunk as [group hex, index]; a promise's one
level is the pair [key, peer]. Floats are their IEEE-754 bits.
"""
import ast
import functools
import gzip
import json
import math
import os
import re
import sys
from collections import Counter, namedtuple
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "gen"))
import content                          # noqa: E402
import footprint as F                   # noqa: E402
import schema                           # noqa: E402: gen/schema.py, the twin's tables, which its Lean is made from too
import schema_seacast                        # noqa: E402: gen/schema_seacast.py, SEACAST's (its DIRECTIONS)
import manifest_seacast                      # noqa: E402: gen/manifest_seacast.py, seacast.md's manifest, which the replay
#                                         reads a SEACAST trace by
import closure_seacast                       # noqa: E402: the closure rule and the call closure, under --doc seacast
from trace61 import CONSTS, SEC61, Tracer, fbits   # noqa: E402

OWN = tuple(t.name for t in schema.TABLES)
SEC44 = ("on_ihave", "over_ihave_limits", "valid_id", "expand", "gated")   # §4.4, and §6.2's gated
READERS = ("held", "tied_to_root")      # §4.2's two readers, the twin's code over its `mine` and `tied`
SEC42 = ("on_chunk", "on_validated", "send_have", "have_bits", "close_promises", "drop_beyond")
SEC42B = ("defer", "tie", "tie_room", "on_block_installed", "drop_tie", "drop_stale_waits")
SEC72 = ("next_to_send", "filter_entry", "with_owed", "rarest", "projected")   # §7.2's writer
# §1's seven
SEC1 = ("group_id", "group_key", "K", "N", "segment_length", "valid_descriptor", "build_group")
SEC2 = ("message_id",)                  # §2's: its content_id is a question at every call
SEC61B = ("drop_offer",)                # §6.1's last
SEC64 = ("on_pace_tick", "send_gossip", "on_heartbeat")  # §6.4 (the pace queue the twin's own table)
SEC46 = ("claim_group", "drop_group",   # §4.6's: `stop_pull` own
         "decode_group", "push_rebuilt")    # level 2 and the repair: the codec, the payload and delivery the node's
SEC43 = ("on_have",)                    # §4.3's: `peer_has` and `holders` the twin's own
SEC3 = ("validate_chunk", "committed_descriptor")   # §3's level 1: a chunk wide where it arrives or waits
SEC41 = ("on_iwant", "respond", "on_frame")     # §4.5's and §4.1's: one record per frame; `serve_count` own
# §5.2's four. One that the simulation or an untraced function calls is a record of its own
SEC52 = ("owe", "note_push", "unpush", "announce")
# §5.3's two
SEC53 = ("guard_fails", "choose_push")
# forward (replaceable), candidates_for_source and on_mesh_join (no caller in the toy: a directed set's)
SEC54 = ("forward", "candidates_for_source", "on_mesh_join")
# §7.1's nine (the window's three tables the twin's own). window_timeout is a timer's record; write_waits is
# called by the node's writer when a write does not complete at once (v0.10.9); front and wake_front are called
# by the window's own alone
SEC71 = ("front", "wake_front", "write_waits", "acquire_slot", "release_unused_slot", "track_in_flight",
         "window_release", "window_timeout", "free_slot")
# §5.1's origin_written, which next_to_send calls at SOURCE_OFFERS = PUBLISH (no cell of check.py runs there:
# hand5-publish and directed7p do), origin_acked, and publish
SEC51 = ("origin_written", "origin_acked",
         "publish")     # the simulation's call, a record a published payload.
#                         With it the block is every function of seacast-lite.md (and `held`, §4.2's reader)
BLOCK = SEC61 + SEC44 + READERS + SEC42 + SEC42B + SEC72 + SEC1 + SEC2 + SEC61B + SEC64 + SEC46 + SEC43 + SEC41 + SEC3 + SEC52 + SEC53 + SEC54 + SEC71 + SEC51
DEFER_DEPTH = 2                         # the twin's deferDepth (Sec42.lean): a record's chain of defers stops at the
                                        #   third, where the twin would crash
CARDS = ("CANCEL", "PROJECT", "RAREST")  # the writer's cards [c8, c12, c9], and FAN_IN [c12]
LIMITS = ("MAX_IHAVE_MESSAGES", "MAX_IHAVE_LENGTH", "MAX_PENDING_GROUPS")   # §8.2: the client's; none where it
#   sets none
FOREIGN = ("known_id",                     # `queue`, `pending_ids` and `stop_pull` are own
           "chunks")     # (`unwanted` is own: on_frame writes it)
#                                             the writer reads §5.2's (`peer_has` and `holders`, §4.3's, are the
#                                             twin's own: on_have asks `g in planned`)
# Under --doc seacast, the tables that keep their rows, whose rows the views read on the way down (footprint.py's
# `row_reads`), as the header's `row_reads` names them; the replay reads them so in a SEACAST trace alone, and this list
# alone. A seacast-lite.md trace has neither
ROW_READS_Seacast = ("owed", "planned", "queue", "tied")
# under SEACAST, the tape's names whose arguments are written as they are at the call, not after it: a guard against a
# callee that changes what it was handed before it returns (SEACAST's send sets its IWANT's `want` before it calls
# enqueue, so there the two forms agree). EAGER_LATE is the planted fault of the self-test (written after the call).
# No name is both here and in CALLS: a question that raises is written with its arguments as they are at exit
EAGER_Seacast = ("enqueue",)
EAGER_LATE = [False]
# Under --doc seacast, the names whose IWANTs enqueued are counted per call in OUT.calls.json, beside the trace: those
# found in the enqueue rows the tape gains between a call's entry and its exit, callees included
IW_NAMES = ("respond", "retry_offer", "ask_parked")


def iwant_asks(x):
    """The asks' counts of the IWANTs in x, an encoded value: each list whose first member is "iwant" and whose second
    is a list, anywhere in x, gives that list's length."""
    if isinstance(x, (list, tuple)):
        if x and x[0] == "iwant" and len(x) >= 2 and isinstance(x[1], (list, tuple)):
            return [len(x[1])] + [n for y in x[2:] for n in iwant_asks(y)]
        return [n for y in x for n in iwant_asks(y)]
    if isinstance(x, dict):
        return [n for y in x.values() for n in iwant_asks(y)]
    return []
# Under --doc seacast, a timer armed inside a question at the node (`after` or `start`, the two kinds): a note of the
# outermost question open there, [kind, delay, target, args], in its row's fourth member (call_log), in the order
# armed. The target is a document's timer of that kind, by its name, or a toy callback of TOY_TIMERS, by its
# qualified name; any other stops the tracer. NOTES_OFF is the self-test's control (the notes' code bypassed)
TIMER_KINDS = ("after", "start")
DOC_TIMERS = {"after": ("retry_offer", "ask_parked", "promise_due", "window_timeout",     # seacast-lite.md's
                        "reconsider", "ask_sample", "resample"),                         # seacast.md's
              "start": ("decode_group",)}
TOY_TIMERS = ("Node._alarm.<locals>.alarm_due",)    # --alarm-wait's (node.py), armed by its filter_entry: (g, i, q, at)
NOTES_OFF = [False]
# §7.1's three, the twin's own. Under seacast-lite.md a cell holds the count and views hold the line and the sends;
# under --doc seacast they are not installed (there the count is bytes and a send's value a pair, and no traced function
# of seacast-lite.md touches them)
WINDOW = ("in_flight", "waiters", "sent")
SEACAST_FILE = "seacast.md (extracted)"  # the toy compiles seacast.md's blocks under this name (node.py, spec2)
# Under --doc seacast, seacast.md's own tables (gen/schema_seacast.py's, in its order): views too, after seacast-lite.md's in
# the header's `own`
OWN_Seacast = tuple(t.name for t in schema_seacast.TABLES_Seacast)
# Under --doc seacast, a table of seacast.md's §3 that is another one's: §3's `hdr` is seacast-lite.md's `desc`, and the
# toy binds both names to one dict (repoint_aliases points `hdr` at desc's view)
ALIASES_Seacast = {"hdr": "desc"}
# A table of schema_seacast.py's that seacast.md's §3 does not declare, with why it is a table all the same. The §3
# scan stops on one that §3 declares after all: the exception is then dropped (want_p's was, at v0.11.1's §3)
UNDECLARED_Seacast = {}


# the calls the block makes on the tape: each a question, answered from the trace, whoever defines it (install's
# `enc` must name these, and only these)
TAPE = ("expired", "connected_topic_peers", "own_order", "listed", "authenticable", "shuffled", "valid_have",
        "penalise", "enqueue", "after", "seen", "accepted", "mark_seen", "live", "open_group",
        "store", "start",
        # the deferral path's questions (defer and tie are the twin's own)
        "installed_block", "admitted", "reserve", "release", "bid_group",
        # the writer's questions, and §7.1's, §4.1's and §5.2's calls it makes
        "has_room", "pop_owed_answer",     # (§7.1's three and unpush are the twin's own)
        # §1's questions: the toy's stand-ins for the hash, the serialization, the codec and the tree
        "sha256", "serialize", "snappy_block_encode", "pad_each", "rs_parity", "merkle_root", "merkle_proof",
        # §6.4's questions (whether a peer is still there; the ids' indices per group, in the order of each group's
        # first id) (§5.2's announce is the twin's own)
        "connected", "group_bits",
        # and on_heartbeat's: the topic's peers, a peer's eligibility for gossip (stock: scores), the sample
        "topic_peers", "gossip_eligible", "sample_without_replacement",
        # the node's helpers that §4.6's two call, each a call with its log
        "close_promises_of_group", "discard_queued", "discard_paced",
        # (on_have's calls of window_release and origin_acked are not on it: both are traced)
        # on_iwant's questions of the node's store, and on_frame's of the stock's prunes
        "resolve", "chunk_of", "handle_graft_prune",
        # decode_group's questions of the codec and of level 3 (push_rebuilt's two calls of §5.2's, note_push
        # and owe, are the twin's own)
        "decode_and_reencode", "payload_of", "deliver",
        # owe's call of the node's writer (§7.2), which the toy's enqueue makes itself
        "wake",
        # the window's question of a writer: whether its write has not completed (§7.1's front, §7.3)
        "writing",
        # the push order's keys: each a question, a candidate at a time
        "tiebreak", "peer_id_bytes",
        # level 1's question of the tree (validate_chunk is the twin's own)
        "verify_merkle_proof",
        # publish's question of the block it publishes under
        "block_root")
# The questions written with their own encoders of arguments and answer (`calls`, in install), so that one that
# raises is on the tape too, its answer {"raises": the exception's type}: serialize of a field beyond its width.
CALLS = ("sha256", "serialize", "snappy_block_encode", "pad_each", "rs_parity", "merkle_root", "merkle_proof",
         "connected", "group_bits", "topic_peers", "gossip_eligible", "sample_without_replacement",
         "close_promises_of_group", "discard_queued", "discard_paced",
         "resolve", "chunk_of", "handle_graft_prune",
         "decode_and_reencode", "payload_of", "deliver", "wake", "writing", "tiebreak", "peer_id_bytes",
         "verify_merkle_proof", "block_root")


def seacast_kept(names, p_src, seacast_src, cut=TAPE):
    """Under --doc seacast: the names of `names` that are seacast-lite.md's all the way down. A def of seacast-lite.md goes if
    seacast.md defines it (SEACAST redefines it), or if it names one that goes, through any def of seacast-lite.md, not
    through the names of `names` alone. A name of `cut` is a call on the tape: a question, answered from the trace
    whoever defines it, so it is not followed, and does not make its caller go. From the documents' own source:
    `p_src` seacast-lite.md's extracted code, `seacast_src` seacast.md's."""
    seacast_defs = {d.name for d in ast.parse(seacast_src).body if isinstance(d, ast.FunctionDef)}
    defs = {d.name: d for d in ast.parse(p_src).body if isinstance(d, ast.FunctionDef)}
    refs = {n: {x.id for x in ast.walk(d) if isinstance(x, ast.Name)} - set(cut) for n, d in defs.items()}
    gone = {n for n in set(defs) | set(names) if n in seacast_defs and n not in cut}
    grew = True
    while grew:
        grew = False
        for n in defs:
            if n not in gone and n not in cut and refs[n] & gone:
                gone.add(n)
                grew = True
    return tuple(n for n in names if n not in gone)


def sec3_block(text):
    """The code block of seacast.md's §3."""
    s = text.index("\n## 3. State\n")
    a = text.index("```python\n", s) + len("```python\n")
    return text[a:text.index("\n```", a)]


def sec3_names(text):
    """The names seacast.md's §3 declares: each line `name: …` of its code block, in order."""
    return [m.group(1) for m in re.finditer(r"^([A-Za-z_]\w*):", sec3_block(text), re.M)]


def split_top(s):
    """`A, B[C, D], E` split at its top-level commas."""
    out, depth, cur = [], 0, ""
    for ch in s:
        depth += (ch == "[") - (ch == "]")
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    return out + [cur.strip()]


def key_count(ann):
    """The keys a table of §3 is read by, from its annotation: each `Dict[K, V]` level is one key, a tuple K
    included, and a `Set[X]` table at the top is keyed by its member. A Set or a List inside the value adds
    nothing. (A schema row may keep a tuple as one key, as backoff's (colour, direction), or split it, as promises':
    the split ones are named, KEYS_SPLIT_Seacast.)"""
    ann = ann.strip()
    if ann.startswith("Set["):
        return 1
    n = 0
    while ann.startswith(("Dict[", "DefaultDict[")):
        n, ann = n + 1, split_top(ann[ann.index("[") + 1:-1])[1]
    return n


def sec3_keys(text):
    """Each name §3 declares, with its key count (key_count over its annotation, the comment cut off)."""
    return {m.group(1): key_count(m.group(2).split("#")[0])
            for m in re.finditer(r"^([A-Za-z_]\w*):\s*(.*)$", sec3_block(text), re.M)}


SCHEMA_KEYS = {t.name: len(t.keys) for t in tuple(schema.TABLES) + tuple(schema_seacast.TABLES_Seacast)}
# A table whose schema row splits a tuple key of §3 into its members: (its keys in §3, in its schema row, why). A
# change to either count gives the scan's usual line
KEYS_SPLIT_Seacast = {"promises": (1, 2, "seacast-lite.md's (§6.1), unchanged: its schema row reads the (ask, peer) tuple as "
                                    "two keys, the ask and the peer")}


def sec3_check(names, seacast=OWN_Seacast, undeclared=UNDECLARED_Seacast, keys=None, arity=None, split=KEYS_SPLIT_Seacast):
    """§3's names against the tables' lists (schema.py's, schema_seacast.py's, FOREIGN, the aliases): what differs, as
    one line each. A name of §3 in no list; a name of schema_seacast.py's not in §3, unless it is named in `undeclared`;
    a named one that §3 declares after all; and, given §3's key counts (`keys`, sec3_keys), a table of the schemas
    that §3 declares with another count of keys than its schema row's (`arity`, by default SCHEMA_KEYS), since a
    table whose shape changes keeps its name; a table named in `split` must have its two counts there."""
    known = set(OWN) | set(seacast) | set(FOREIGN) | set(ALIASES_Seacast)
    out = [f"{n}: in §3, in no list" for n in names if n not in known]
    out += [f"{n}: in schema_seacast.py, not in §3" for n in seacast if n not in names and n not in undeclared]
    out += [f"{n}: named as not in §3, and §3 declares it" for n in undeclared if n in names]
    arity = SCHEMA_KEYS if arity is None else arity
    out += [f"{n}: {k} key{'' if k == 1 else 's'} in §3, {arity[n]} in its schema row"
            for n, k in (keys or {}).items()
            if n in arity and (split[n][:2] != (k, arity[n]) if n in split else arity[n] != k)]
    return out


def manifest_check(traced, m=manifest_seacast, own=OWN + OWN_Seacast, foreign=FOREIGN, node_own=None):
    """Under --doc seacast, the tracer's own lists against seacast.md's manifest (gen/manifest_seacast.py), which the
    replay reads the trace by: the traced names (seacast_kept over the two documents, without §7.1's, and SEACAST's covered
    names) are KEPT, COVERED and NODE_OWN's keys; NODE_OWN is the tracer's; the header's `own` is OWN, in its order,
    and `foreign` is FOREIGN. What differs, as one line each, naming the names. `traced` None (§6.1's twelve alone,
    TRACE3_ONLY=sec61): the traced names are not compared."""
    node_own = NODE_OWN if node_own is None else node_own
    out = []
    want = set(m.KEPT) | set(m.COVERED) | set(m.NODE_OWN)
    if traced is not None and set(traced) != want:
        out.append(f"traced, not in the manifest's KEPT, COVERED or NODE_OWN: {sorted(set(traced) - want)}; in them, "
                   f"not traced: {sorted(want - set(traced))}")
    if dict(m.NODE_OWN) != dict(node_own):
        out.append(f"NODE_OWN is {dict(node_own)!r} here, {dict(m.NODE_OWN)!r} in the manifest")
    if list(m.OWN) != list(own):
        diff = next((i for i, (a, b) in enumerate(zip(m.OWN, own)) if a != b), min(len(m.OWN), len(own)))
        out.append(f"own: {len(own)} tables here, {len(m.OWN)} in the manifest, the first difference at position "
                   f"{diff + 1}")
    if list(m.FOREIGN) != list(foreign):
        out.append(f"foreign is {list(foreign)} here, {list(m.FOREIGN)} in the manifest")
    return out


class MissQuestionView(F.View):
    """`interest` under --doc seacast: the toy's InterestMap answers a group it does not hold by `own_interest_bits(g)`
    and stores nothing (seacast.md §3: ours, computable before any chunk). In a record's own code, not inside a
    question, that miss is the question `own_interest(g)`: the read logged first, with the group missing, then the
    question on the tape with its answer. Inside a question, and outside a record, the miss runs as the toy's.
    `ask(g, raw)` puts the question on the tape and gives its answer."""
    __slots__ = ("_ask",)

    def __init__(self, view, ask):
        super().__init__(view._r, view._t, view._p, view._o)
        object.__setattr__(self, "_ask", ask)

    def __getitem__(self, k):
        if (self._r.on and self._r.callee is None and self._r.observer is None and not self._p
                and k not in self._o):          # (an observer's own read: the toy's miss, unlogged; class 6)
            self._r.read(self._t, (k,))
            return self._ask(k, self._o)
        return super().__getitem__(k)


def tracers_own(fn):
    """Whether a function is one of this file's (the tracer's own wrappers, which functools.wraps marks)."""
    code = getattr(fn, "__code__", None)
    return code is not None and Path(code.co_filename).resolve() == Path(__file__).resolve()


def call_log(cr, cw, timers=()):
    """A question's fourth member: its accesses of the own tables (`cr`, `cw`) and, under SEACAST, the notes of the timers
    it armed (`timers`, in the order armed), written where any of the three is not empty. `timers` is there only where
    the question armed one, so a row whose question armed none is as before."""
    if timers:
        return [{"cr": cr, "cw": cw, "timers": list(timers)}]
    return [{"cr": cr, "cw": cw}] if cr or cw else []


def miss_question(rec, enter=lambda: None, leave=lambda: None):
    """The question `own_interest(g)` of MissQuestionView: the toy's own miss (`__missing__`) run as a question's
    callee, its accesses of the own tables its `cr` and `cw`; on the tape as `["own_interest", [g], bits]`, the
    bits in the signed form, as schema_seacast.py writes `interest`'s. `enter` and `leave` are the tracer's own around a
    question (its depth, and the mesh as the node's); `leave` gives the notes of the timers it armed (call_log)."""
    def ask(g, raw):
        enter()
        rec.begin_callee()
        done = False
        try:
            b = raw.__missing__(g)
            done = True
        finally:
            cr, cw = rec.end_callee()
            timers = leave() or []
            if timers and not done:
                raise SystemExit("trace3: own_interest raised after arming a timer: its row cannot hold the notes")
        rec.tape.append(["own_interest", [g.hex()], schema_seacast.signed(b.v)] + call_log(cr, cw, timers))
        return b
    return ask


_PARSED = {}


def toy_args(argv, toy=None):
    """The toy's own parser and what it reads from argv: run.py's main is called once with argparse's parse_args
    wrapped, so that it builds its parser, parses argv, and stops before it runs anything. So an abbreviation of an
    option, its "=" form, and whatever else that parser takes are read as the toy reads them. `toy`, where given,
    is put first on the module path (a reader of a trace's header; the tracer has it there already). Arguments the
    parser refuses end the process, as they end the toy's run."""
    key = (tuple(argv), str(toy))
    if key in _PARSED:
        return _PARSED[key]
    import argparse
    if toy is not None:
        sys.path.insert(0, str(Path(toy).resolve()))
    import run                          # noqa: E402: the toy's run.py, from TOYDIR

    class Parsed(Exception):
        pass
    got = []
    orig = argparse.ArgumentParser.parse_args

    def probe(self, args=None, namespace=None):
        got.append((self, orig(self, args, namespace)))
        raise Parsed
    argparse.ArgumentParser.parse_args = probe
    try:
        run.main(list(argv))
    except Parsed:
        pass
    finally:
        argparse.ArgumentParser.parse_args = orig
    if len(got) != 1:
        raise SystemExit("trace3: the toy's run.py did not parse its arguments once, as the tracer asks it to")
    _PARSED[key] = got[0]
    return got[0]


def toy_reads_a_dump(argv):
    """Whether the toy, given argv, reads a dump (--topology FILE) or turns on its cross-check recorder (--xcheck),
    as the toy's own parser reads argv (toy_args). --topology is the one option of the toy that reads a file
    (xcheck.load); --xcheck reads none, and is refused for its recorder."""
    ap, a = toy_args(argv)
    return a.topology != ap.get_default("topology") or a.xcheck != ap.get_default("xcheck")


def doc_parsed(argv):
    """The document the toy runs, as its own parser reads argv (toy_args): "seacast" or None."""
    ap, a = toy_args(argv)
    return "seacast" if a.doc == "seacast" else None


OLD_DOCS = {"v2": "seacast", "v03": "lite"}  # the values of --doc before v0.12.0, as the headers written then hold them


def doc_of(argv):
    """The document a trace's arguments name (--doc seacast or --doc=seacast), or None for seacast-lite.md: read from the words
    themselves, so that it reads a directed set's arguments too, which are no toy's command line. For a trace of the
    toy's command line the tracer has already refused arguments where this reading and the toy's parser's differ
    (Tracer3, cli), so a header's arguments read here name the document the toy ran. A header written before v0.12.0
    names the documents by their old values (formal/twin/record/'s SEACAST traces), and is read by OLD_DOCS as the same
    document under its new name."""
    for i, a in enumerate(argv):
        if a == "--doc" and i + 1 < len(argv):
            return OLD_DOCS.get(argv[i + 1], argv[i + 1])
        if a.startswith("--doc="):
            d = a.split("=", 1)[1]
            return OLD_DOCS.get(d, d)
    return None


DOC_FILE = "seacast-lite.md (extracted)"    # the toy compiles seacast-lite.md's blocks under this name (node.py, SPEC)
# A traced name's function at a node is seacast-lite.md's own code, or one of these.
# WRAPPERS: the toy's wrappers of a document's function, each by its qualified name; it must hold the document's
# function of that name in its closure. Read once each (toy/node.py): message_id stores the id on the chunk;
# claim_group notes the completion's time; may_ask, add_offer and close_promises keep the toy's index of a chunk's
# ask keys and an offer's time; over_ihave_limits counts the asks held back; under --doc seacast, promise_due notes a
# broken promise for the invariants. Each then calls the document's function with its own arguments.
WRAPPERS = {"message_id": "Node._override.<locals>.message_id", "claim_group": "Node._override.<locals>.claim_group",
            "may_ask": "Node._override.<locals>.may_ask", "add_offer": "Node._override.<locals>.add_offer",
            "close_promises": "Node._override.<locals>.close_promises",
            "over_ihave_limits": "Node.__init__.<locals>.over_ihave_limits",
            "promise_due": "Node._seacast.<locals>.promise_due"}
# NODE_OWN: a traced name that is no function of the document's, but the node's helper the twin has as its own code
# (`held`, §8's interface, over the twin's `mine`).
NODE_OWN = {"held": "Node._namespace.<locals>.held"}
# REPLACEABLE: the traced names a node may run as something else (a fault, a variant). At such a node the name is
# a question on the tape, and the node's line says so.
REPLACEABLE = ("forward",               # a node that forwards nothing (silent, cap-wait), a scenario's
               "on_iwant",              # a withholder's (check.py's withholders, silent, cap-wait)
               "push_rebuilt",          # and the variants of the repair (--rebuilt none, hold, announce, capped)
               "validate_chunk")        # and, in a directed set alone (REPLACEABLE_WHOLE), a scenario's level 1
# A name replaceable only in a trace of the whole state: no cell runs anything but the document's level 1. The
# directed sets of §4.2 draw its result (a sequence of DEFERs with the block there, a REJECT of a chunk whose proof
# nobody made) to reach on_validated's and defer's paths, as they did while validate_chunk was a question.
REPLACEABLE_WHOLE = ("validate_chunk",)
# The chain rule's lists, under --doc seacast (chain_rule): every layer the toy binds over a traced name, by its file's
# name, its qualified name and its first line, with the name it is listed for and its kind. A qualified name alone
# does not tell layers apart: lambdas share `<lambda>`, and a class's method may make two locals of one name; nor do
# a qualified name and a line without the file, where a fixture lists a function of its own. An observer
# calls the function it holds once, with its own arguments, and returns its result, changing no table and no
# constant (scan_bindings.py's observer test); the node's own helper is a traced name the documents do not define
# (NODE_OWN); a changing layer changes the function on some path, so that the name is a question at that node. Each
# read in toy/node.py, and held to the scan of the toy's bindings by scan_bindings.py --lists.
# Two kinds more, under SEACAST's covered names: a swapped draw, an observer that binds a draw's slot (DRAWS) to the toy's
# own draw around its call, and restores it after (the tracer re-wraps the draw while it is bound, so that it is a
# question on the tape: rewrap_draws); and a layer bound only during a call (inside a toy function's body, restored
# after it), which no install finds bound, and which a record's entry or exit finds and stops at (bindings_check).
# A closure-dependent layer (ClosureKind) has its kind read at each node from a closure value the node is made with:
# `cell`'s truth value picks `if_true` or `if_false`.
OBSERVER, NODE_HELPER, CHANGING = "observer", "node's own", "changing"
SWAPPED_DRAW, DURING_CALL = "swapped draw", "bound during a call"
ClosureKind = namedtuple("ClosureKind", "cell if_true if_false")
DRAWS = ("choice", "sample_without_replacement", "shuffled")    # the draws a toy's layer may swap (K13)
LAYERS = {("node.py", "Node.__init__.<locals>.over_ihave_limits", 207): ("over_ihave_limits", OBSERVER),  # counts
          ("node.py", "Node._namespace.<locals>.held", 703): ("held", NODE_HELPER),         # the asks held back
          ("node.py", "Node._override.<locals>.message_id", 943): ("message_id", OBSERVER),     # a cache: it skips
          ("node.py", "Node._override.<locals>.add_offer", 957): ("add_offer", OBSERVER),       #   the call on a hit
          ("node.py", "Node._override.<locals>.may_ask", 964): ("may_ask", OBSERVER),           # these three keep the
          ("node.py", "Node._override.<locals>.close_promises", 969): ("close_promises", OBSERVER),   # toy's index
          ("node.py", "Node._faults.<locals>.<lambda>", 1102): ("on_iwant", CHANGING),     # a withholder's: no answer
          ("node.py", "Node._peer_promise.<locals>.close_promises", 1177): ("close_promises", OBSERVER),  # answer times
          ("node.py", "Node._seacast.<locals>.promise_due", 1765): ("promise_due", OBSERVER),   # notes a broken promise
          # over SEACAST's covered names. Observers: a count or a note after the call (--alarm's, the member check's, the
          # peer promise's sender, the measurement point, the reach report)
          ("node.py", "Node._hoard_column.<locals>.defer_on_claim", 274): ("defer_on_claim", OBSERVER),
          ("node.py", "Node._member_check.<locals>.repair_verdict", 511): ("repair_verdict", OBSERVER),
          ("node.py", "Node._peer_promise.<locals>.fill", 1170): ("fill", OBSERVER),
          ("node.py", "Node._seacast.<locals>.check_completion", 1721): ("check_completion", OBSERVER),
          ("node.py", "Node._seacast.<locals>.fill", 1756): ("fill", OBSERVER),
          # --alarm-wait's count before the call: type_of_group, which it asks, only reads (scan_bindings.py's follow)
          ("node.py", "Node._alarm.<locals>.serve_standing", 422): ("serve_standing", OBSERVER),
          # the invariants' count of the asks on_want leaves unanswered, by reason, before the call: what it asks
          # (resolve, and probe_of_claim, which reads) changes nothing (scan_bindings.py's follow)
          ("node.py", "Node._seacast.<locals>.on_want", 1729): ("on_want", OBSERVER),
          # swapped draws: the floor's draw on sim.floor_rng; the probed index's on a stream of its own
          ("node.py", "Node._seacast.<locals>.keep_floor", 1686): ("keep_floor", SWAPPED_DRAW),
          ("node.py", "Node._seacast.<locals>.defer_on_claim", 1775): ("defer_on_claim", SWAPPED_DRAW),
          # closure-dependent: --member-check off returns False without the document's call; on, it counts
          ("node.py", "Node._member_check.<locals>.owed_missing", 502): ("owed_missing",
                                                                         ClosureKind("on", OBSERVER, CHANGING)),
          # changing, over one of the eight names the twin asks where a node replaces it (ASKED_Seacast)
          ("node.py", "Node.__init__.<locals>.note_claim", 219): ("note_claim", CHANGING),        # a liar's
          ("node.py", "Node._hoard_column.<locals>.push_rebuilt", 256): ("push_rebuilt", CHANGING),   # a hoarder's
          ("node.py", "Node._repair_variants.<locals>.push_rebuilt", 526): ("push_rebuilt", CHANGING),
          ("node.py", "Node._faults.<locals>.<lambda>", 1110): ("push_rebuilt", CHANGING),        # --fault's
          ("node.py", "Node._rebuilt.<locals>.<lambda>", 1140): ("push_rebuilt", CHANGING),       # --rebuilt's
          ("node.py", "Node._rebuilt.<locals>.push_rebuilt", 1142): ("push_rebuilt", CHANGING),   #   variants
          ("node.py", "Node._rebuilt.<locals>.push_rebuilt", 1149): ("push_rebuilt", CHANGING),
          ("node.py", "Node._seacast.<locals>.<lambda>", 1808): ("push_rebuilt", CHANGING),            # --fault hoard's
          ("node.py", "Node._seacast.<locals>.push_rebuilt", 1810): ("push_rebuilt", CHANGING),        # hoardcol's
          ("node.py", "Node._seacast.<locals>.serve_standing", 1841): ("serve_standing", CHANGING),
          ("node.py", "Node._repair_bias.<locals>.repair_verdict", 471): ("repair_verdict", CHANGING),
          ("node.py", "Node._faults.<locals>.forward", 1106): ("forward", CHANGING),              # a silent node's
          ("node.py", "Node._seacast.<locals>.send_have", 1799): ("send_have", CHANGING),              # a liar's
          # changing, over a name the manifest makes replaceable and the twin cannot ask (NOASK_Seacast): entered outside
          # every record alone (iface_of stops a record's own call of one)
          ("node.py", "Node._alarm.<locals>.filter_entry", 350): ("filter_entry", CHANGING),
          ("node.py", "Node._peer_promise.<locals>.filter_entry", 1191): ("filter_entry", CHANGING),
          ("node.py", "Node._writer_variants.<locals>.choose", 1049): ("choose", CHANGING),
          ("node.py", "Node._rebuilt_seen.<locals>.decode_group", 439): ("decode_group", CHANGING),
          ("node.py", "Node._hoard_column.<locals>.on_want", 260): ("on_want", CHANGING),         # a hoarder's filter
          ("node.py", "Node._alarm.<locals>.on_want", 403): ("on_want", CHANGING),              # --alarm-wait's
          ("node.py", "Node._seacast.<locals>.<lambda>", 1795): ("on_want", CHANGING),          # a withholder's
          ("node.py", "Node._seacast.<locals>.on_want", 1825): ("on_want", CHANGING),           # hoardcol's filter
          # bound during a call: publish's announce under --source-offers off and late
          ("node.py", "Node._no_source_offers.<locals>.publish.<locals>.<lambda>", 997): ("announce", DURING_CALL),
          ("node.py", "Node._late_source_offers.<locals>.publish.<locals>.<lambda>", 1015): ("announce", DURING_CALL)}
# Under SEACAST: the replaceable names (the manifest's, and the directed sets' validate_chunk); the eight the twin asks as
# questions where a node replaces them (its NodeSeacast, Seacast/Replay.lean); and those it cannot ask, which a record's own
# code must not call where they are replaced: the manifest's replaceable covered names but the eight
REPLACEABLE_Seacast = tuple(manifest_seacast.REPLACEABLE) + tuple(manifest_seacast.REPLACEABLE_WHOLE)
ASKED_Seacast = ("forward", "push_rebuilt", "send_have", "serve_standing", "owed_missing", "repair_verdict", "note_claim",
            "known_in_scope")
NOASK_Seacast = tuple(n for n in manifest_seacast.REPLACEABLE if n not in ASKED_Seacast and n not in manifest_seacast.KEPT)
# Under SEACAST, the places where the twin asks the order of a set of peers (its NodeSeacast.order calls): eight iterate
# `suppression_scope(g)` (fill its union with the sender's ack), and serve_standing the set it pops from `standing`.
# A record's own code iterating either set writes ["order", place, [q...]] (OrderProxy); TRACE3_ORDER=off, for the
# cost measure alone, writes none, and shows in no trace
ORDER_PLACES_Seacast = ("fill", "serve_standing", "check_completion", "known_in_scope", "known_across", "reconsider",
                   "origin_written", "offer_at_publish", "origin_acked")
JOIN_FIELDS_Seacast = frozenset(("object_type", "interest", "custody_count", "duty", "colours"))     # seacast.md's Join
# Under SEACAST, the questions an object type answers (its functions, wrapped per node on the type: type_enc_seacast; its
# parameters' three are Tracer3.TYPE_FUNCTIONS, param_enc_seacast), and the manifest's questions whose rows an adapter
# writes (the gossip history's, the mesh's, `interest`'s miss)
TYPE_QUESTIONS_Seacast = ("index_count", "threshold", "verify", "decode", "header_of", "project", "cross", "family",
                     "derived_interest")
COVERED_SET = frozenset(manifest_seacast.COVERED)    # the covered names, whose records records_seacast.py writes under SEACAST
ADAPTED_Seacast = ("gossip_put", "gossip_remove_group", "mesh_has", "own_interest")


def own_code(name, fn):
    """What a traced name's function is at a node: ("own", where) for seacast-lite.md's own code, a listed wrapper that
    holds it, or the node's listed helper; ("replaced", where) for anything else."""
    code = getattr(fn, "__code__", None)
    if code is None:
        return "replaced", f"no Python function ({type(fn).__name__})"
    if code.co_filename == DOC_FILE:
        return ("own", "the document's") if code.co_name == name else ("replaced", f"the document's {code.co_name}")
    qual = getattr(fn, "__qualname__", "?")
    where = f"{qual} ({Path(code.co_filename).name}:{code.co_firstlineno})"
    if NODE_OWN.get(name) == qual and Path(code.co_filename).name == "node.py":
        return "own", where
    if WRAPPERS.get(name) == qual:
        for cell in fn.__closure__ or ():
            try:
                inner = cell.cell_contents
            except ValueError:
                continue
            ic = getattr(inner, "__code__", None)
            if ic is not None and ic.co_filename == DOC_FILE and ic.co_name == name:
                return "own", where
        return "replaced", f"{where}: a listed wrapper's name, without the document's {name} in its closure"
    return "replaced", where


def layers_of(name, fn):
    """A name's layers, outermost first: from fn, the closure cell holding a function of the same name, until none
    does. A layer holds the next as a closure cell (node.py's `doc_on_frame`). A cell the tracer re-wrapped (an
    observer's hand-over, a swapped draw's shim: `_trace3_through`) is read as the layer it holds. Raises ValueError
    where a layer holds two such functions (no layer is guessed) or the chain loops."""
    out, seen = [fn], {id(fn)}
    while True:
        nxt = []
        for cell in getattr(fn, "__closure__", None) or ():
            try:
                inner = cell.cell_contents
            except ValueError:
                continue
            while getattr(inner, "_trace3_through", False):
                inner = inner.__wrapped__
            if inner is not fn and getattr(getattr(inner, "__code__", None), "co_name", None) == name:
                nxt.append(inner)
        if not nxt:
            return out
        if len(nxt) > 1:
            raise ValueError(f"a layer of {name} holds {len(nxt)} functions of that name")
        fn = nxt[0]
        if id(fn) in seen:
            raise ValueError(f"the layers of {name} loop")
        seen.add(id(fn))
        out.append(fn)


def innermost(name, fn):
    """The function a name's layers lead to (`layers_of`), with its ValueErrors."""
    return layers_of(name, fn)[-1]


class ChainStop(Exception):
    """The chain rule's stop: a traced name's layers at a node that the tracer's lists do not class."""


def layer_where(f):
    """A layer as the stops name it: its qualified name, file and first line."""
    code = getattr(f, "__code__", None)
    qual = getattr(f, "__qualname__", None) or type(f).__name__
    return f"{qual} ({Path(code.co_filename).name}:{code.co_firstlineno})" if code is not None else qual


def layer_key(f):
    """A Python function's key in LAYERS: its file's name, its qualified name and its first line."""
    return Path(f.__code__.co_filename).name, f.__qualname__, f.__code__.co_firstlineno


def closure_kind(name, f, ck):
    """A closure-dependent layer's kind at its node: `ck.if_true` where the closure value `ck.cell` is true, else
    `ck.if_false`, the truth value the layer's own test reads. A layer without that cell, or with it empty, stops."""
    names = f.__code__.co_freevars
    if ck.cell not in names:
        raise ChainStop(f"{name}: a closure-dependent layer without its closure value {ck.cell}: {layer_where(f)}")
    try:
        v = f.__closure__[names.index(ck.cell)].cell_contents
    except ValueError:
        raise ChainStop(f"{name}: a closure-dependent layer whose closure value {ck.cell} is empty: "
                        f"{layer_where(f)}") from None
    return ck.if_true if v else ck.if_false


def chain_rule(name, fn, whole=False, lists=None, replaceable=None):
    """Under --doc seacast, a traced name's chain at a node and whether the node replaces it: (chain, replaced).

    The chain is the name's layers (`layers_of`), outermost first, each by its qualified name, ending in `doc` where
    the walk reaches the document's function of that name (seacast-lite.md's or seacast.md's). It is None where the
    name is bound to the document's function itself, or to the node's own helper alone: such a name has no key in
    `chains`. Each layer above `doc` must be listed in `lists` (LAYERS) for this name, by its file's name, its
    qualified name and its first line (layer_key): the toy's in node.py, and a fixture's that the fixture lists
    before the install. The name is replaced where any layer is changing (an observer and a swapped draw are not; a
    closure-dependent layer's kind is read at the node, closure_kind), and only a name of `replaceable` may be
    (REPLACEABLE, or under SEACAST REPLACEABLE_Seacast). A layer listed as bound only during a call stops here. A
    walk that does not reach `doc` ends in a changing layer, or is the node's own helper alone. In a trace of the
    whole state, a REPLACEABLE_WHOLE name bound to a function outside node.py (a directed set's level 1) is changing.
    Anything else raises ChainStop, naming the layer."""
    lists = LAYERS if lists is None else lists
    replaceable = REPLACEABLE if replaceable is None else replaceable
    try:
        ls = layers_of(name, fn)
    except ValueError as e:
        raise ChainStop(str(e)) from None
    code = getattr(ls[-1], "__code__", None)
    doc = code is not None and code.co_filename in (DOC_FILE, SEACAST_FILE) and code.co_name == name
    above = ls[:-1] if doc else ls
    if not above:
        return None, False
    kinds = []
    for f in above:
        c = getattr(f, "__code__", None)
        if c is None:
            raise ChainStop(f"{name}: a layer that is no Python function: {layer_where(f)}")
        if whole and name in REPLACEABLE_WHOLE and Path(c.co_filename).name != "node.py":
            kinds.append(CHANGING)
            continue
        listed = lists.get(layer_key(f))
        if listed is None:
            raise ChainStop(f"{name}: a layer in none of the tracer's lists: {layer_where(f)}")
        if listed[0] != name:
            raise ChainStop(f"{name}: a layer listed for {listed[0]}, not for {name}: {layer_where(f)}")
        kind = listed[1]
        if isinstance(kind, ClosureKind):
            kind = closure_kind(name, f, kind)
        if kind == DURING_CALL:
            raise ChainStop(f"{name}: a layer listed as bound only during a call, bound at the install: "
                            f"{layer_where(f)}")
        kinds.append(kind)
    if NODE_HELPER in kinds:
        if kinds != [NODE_HELPER] or doc:
            raise ChainStop(f"{name}: the node's own helper with other layers: "
                            + ", ".join(layer_where(f) for f in above))
        return None, False
    if not doc and kinds[-1] != CHANGING:
        raise ChainStop(f"{name}: its layers end in {kinds[-1]} {layer_where(above[-1])}, which holds no function "
                        f"of its name")
    replaced = CHANGING in kinds
    if replaced and name not in replaceable:
        f = above[kinds.index(CHANGING)]
        raise ChainStop(f"{name}: a changing layer, {layer_where(f)}, where no node may replace {name}")
    return [getattr(f, "__qualname__", None) for f in above] + (["doc"] if doc else []), replaced


REWRAP = [True]         # the draws' re-wrap (rewrap_draws); off only in a planted fault
# Class 6 (step3.md, its design point): an observer's own code is the node's, not the document function's, so under
# SEACAST its reads go into no record's log and a write of it stops the tracer (footprint's observer mode). OBSERVE: the
# handling (off: the tracer of 7e86ac8, the observer's reads logged); HANDOVER: the re-wrap of each observer's cell
# that holds the next layer, which ends the mode for the document's function (off: the mode runs on through it).
# Each off only in a planted fault (observers_self_test).
OBSERVE, HANDOVER = [True], [True]
# HANDOVER_BOUND: a hand-over hands over only in the mode of the observer whose layer holds it (off: in any observer's
# mode, so that an observer's own call of another observed name ends the caller's mode at that name's document
# function). SIMGUARD: the simulator's own `after`, wrapped at the install (sim_guard), stops an observer's own code
# that arms a timer through it (off: let through). Each off only in a planted fault or a control.
HANDOVER_BOUND, SIMGUARD = [True], [True]


class ObservedLayer:
    """An observer layer of a traced name at a node, in the recorder's observer mode: the stop's words, and its counts
    (the calls entered in records, the reads its own code made, unlogged) for the trace's summary."""
    __slots__ = ("nid", "name", "where", "calls", "reads")

    def __init__(self, nid, name, where):
        self.nid, self.name, self.where, self.calls, self.reads = nid, name, where, 0, 0

    def words(self, what, why="an observer changes no table"):
        return f"trace3: node {self.nid}: the observer {self.where} over {self.name} {what}: {why}"


def observed_chain(name, ls, lists=None):
    """Class 6: a traced name's layers (`layers_of`, the document's function last) where each layer above it is an
    observer (listed, or closure-dependent and one at this node) or a swapped draw (an observer that binds a draw's
    slot, whose own code reads no table); else None (a changing layer makes the name a question; a lone function is
    no chain)."""
    lists = LAYERS if lists is None else lists
    last = getattr(ls[-1], "__code__", None)
    if len(ls) < 2 or last is None or last.co_filename not in (DOC_FILE, SEACAST_FILE) or last.co_name != name:
        return None
    for f in ls[:-1]:
        listed = lists.get(layer_key(f)) if getattr(f, "__code__", None) is not None else None
        if listed is None or listed[0] != name:
            return None
        kind = closure_kind(name, f, listed[1]) if isinstance(listed[1], ClosureKind) else listed[1]
        if kind not in (OBSERVER, SWAPPED_DRAW):
            return None
    return ls


def handover(rec, nxt, nxt_ob, own, doc_on, doc_off):
    """What an observer's cell holds in place of the layer `nxt` it calls: the hand-over from the observer's own code
    to `nxt`, at a boundary (footprint's `observer_boundary`). Into the next observer (`nxt_ob`) the mode goes on, with
    that layer named; into the document's function (`nxt_ob` None) it ends until the function returns (`doc_on` and
    `doc_off`: the record's questions, the mesh's and the gossip history's, around it). Outside the mode (the layer
    called outside a record, or inside a question) it passes the call through, and so it does in the mode of another
    observer than `own`, the one whose layer holds the cell: that observer's own code called this name bare, and its
    mode goes on through the name's layers and its document function. A limit: a name called again from its own
    outermost observer's code meets its own observer here, and is handed over."""
    def h(*a, **k):
        prev = rec.observer
        if prev is None or (HANDOVER_BOUND[0] and prev is not own):
            return nxt(*a, **k)
        rec.observer_boundary()
        rec.observer, rec.obs_seen = nxt_ob, {}
        if nxt_ob is None:
            doc_on()
        else:
            nxt_ob.calls += 1
        done = False
        try:
            r = nxt(*a, **k)
            done = True
            return r
        finally:
            if done and nxt_ob is not None:     # the next observer's own code, after its own hand-over
                rec.observer_boundary()
            if nxt_ob is None:
                doc_off()
            rec.observer, rec.obs_seen = prev, {}
    h._trace3_through, h.__wrapped__ = True, nxt
    return h


def observe(rec, ob, fn, args, kw, doc_on, doc_off):
    """The outermost observer's call (`fn`, the layer bound under the name) in observer mode, inside a record: its
    own code's reads go into no log, and a change of an entry it touched stops at its return."""
    prev = rec.observer
    rec.observer, rec.obs_seen = ob, {}
    ob.calls += 1
    doc_off()
    done = False
    try:
        r = fn(*args, **kw)
        done = True
        return r
    finally:
        if done:
            rec.observer_boundary()
        doc_on()
        rec.observer, rec.obs_seen = prev, {}


def sim_guard(orig, observer_now):
    """The simulator's own `after` (`orig`), wrapped at the install under SEACAST: a timer armed while an observer's own
    code runs (`observer_now()`: the open record's observer, else None) stops the tracer with that observer's words,
    as iface_of stops one armed through the namespace's `after` or `start`; any other goes to the simulator. In the
    document's function an observer hands over to, the mode is the document's, and its timers pass. arm_timer's hook,
    set over it for one question's call, calls it in turn."""
    def after(node, delay, fn, *args):
        ob = observer_now() if SIMGUARD[0] else None
        if ob is not None:
            raise SystemExit(ob.words("arms a timer (sim.after)", "an observer changes nothing"))
        return orig(node, delay, fn, *args)
    after._trace3_guard = True
    return after


def rewrap_observers(rec, nid, name, ls, doc_on, doc_off, lists=None):
    """At the install: each cell of a handled chain's layers (observed_chain) that holds the next layer, re-wrapped as
    the hand-over to it; the outermost layer's ObservedLayer (the mode's entry, sec61's), and every layer's, or None
    where the chain is not handled. A cell already re-wrapped (a swapped draw's shim) is wrapped as it stands."""
    if not OBSERVE[0] or observed_chain(name, ls, lists) is None:
        return None, []
    obs = [ObservedLayer(nid, name, layer_where(f)) for f in ls[:-1]]
    if HANDOVER[0]:
        for i, (f, nxt) in enumerate(zip(ls, ls[1:])):
            cell = cell_holding(f, nxt)
            cell.cell_contents = handover(rec, cell.cell_contents, obs[i + 1] if i + 1 < len(obs) else None, obs[i],
                                          doc_on, doc_off)
    return obs[0], obs


def cell_holding(f, nxt):
    """The closure cell of layer `f` that holds the layer `nxt` (layers_of found it there), itself or re-wrapped by the
    tracer (`_trace3_through`)."""
    for c in f.__closure__ or ():
        try:
            x = c.cell_contents
        except ValueError:
            continue
        while x is not nxt and getattr(x, "_trace3_through", False):
            x = x.__wrapped__
        if x is nxt:
            return c
    raise SystemExit(f"trace3: {layer_where(f)}: no closure cell holds {layer_where(nxt)}")


def rewrap_draws(ns, slots, rewrap):
    """K13: each draw slot (DRAWS) that the toy has bound to its own draw, re-wrapped as the question it is
    (`rewrap`, iface_of over the toy's draw), until the caller puts the toy's back. The slots re-wrapped, with the
    toy's draws found there."""
    found = {}
    for d in DRAWS if REWRAP[0] else ():
        if d not in slots:
            continue
        cur = ns.get(d)
        if cur is not slots[d] and not getattr(cur, "_trace3_rewrap", False):
            found[d] = cur
            ns[d] = rewrap(d, cur)
    return found


def bindings_check(nid, ns, slots, found, fname, at):
    """Under SEACAST, at a record's entry and at its exit (`at`): every slot the install bound (a traced name, a tape
    name, a table's view) still holds the tracer's own binding, or a draw re-wrapped (rewrap_draws; `found`, the
    toy's draws re-wrapped at the entry, put back before the exit's check). Anything else is a binding the toy made
    after the install, between records or during a call, which the twin would not run: a stop naming the slot and
    what it holds. A binding made and restored wholly inside one record passes both (a stated limit; the replay's
    mismatch is its backstop)."""
    for s, w in slots.items():
        cur = ns.get(s)
        if cur is w or (s in found and cur is found[s]) or (s in DRAWS and getattr(cur, "_trace3_rewrap", False)):
            continue
        raise SystemExit(f"trace3: node {nid}: {s} is bound to {layer_where(cur)} at the {at} of {fname}'s record, "
                         f"not to the tracer's own binding: a binding made after the install or during a call, which "
                         f"the twin would not run")


def node_chains(traced, ns, whole=False, lists=None, replaceable=None):
    """Under --doc seacast, a node's replaced names, sorted, and its nodes entry's `chains`, by name: the chain rule over
    each traced name. Raises ChainStop."""
    replaced, chains = [], {}
    for name in traced:
        chain, rep = chain_rule(name, ns.get(name), whole, lists, replaceable)
        if rep:
            replaced.append(name)
        if chain is not None:
            chains[name] = chain
    return sorted(replaced), dict(sorted(chains.items()))


def group_nodes(nodes):
    """The nodes line's entries: one per distinct (constants, replaced names, types, chains), in the order of its
    first node, with the nodes that have it. `types` and `chains` are members only where given (under SEACAST)."""
    entries = []
    for nid, consts, replaced, types, chains in nodes:
        for e in entries:
            if (e["consts"] == consts and e["replaced"] == replaced and e.get("types") == types
                    and e.get("chains") == chains):
                e["n"].append(nid)
                break
        else:
            entries.append({"n": [nid], "consts": consts, "replaced": replaced}
                           | ({} if types is None else {"types": types})
                           | ({} if chains is None else {"chains": chains}))
    return entries


def namespace_check(names, traced, seacast_defs, ns, replaceable=None, layers=False):
    """The namespace against the documents' source: no traced function is SEACAST's, and every name of `names` that
    seacast.md defines (`seacast_defs`) is SEACAST's here. Two derivations of the set, each checking the other. The reason
    the namespace is refused, or None.

    A replaceable name that seacast.md defines may be the node's own here, neither document's: the toy's
    variants of push_rebuilt (--rebuilt none, hold, announce, capped; a silent node's), a silent node's forward.
    Such a name is not traced under SEACAST (SEACAST defines it), and nothing of the check depends on which of the two it is.
    seacast-lite.md's own function under a name SEACAST defines is still refused: SEACAST's block was not run over it. (Without
    the exception, a SEACAST cell whose nodes run their own push_rebuilt could not be traced.)

    With `layers` (under --doc seacast, where the tracer installs at the end of the node's construction, after the toy's
    layers over SEACAST's functions, node.py's `_seacast`), both conditions read the function the name's layers lead to
    (`innermost`), not the layer bound under the name. Until the SEACAST path's kept list and its rule for layers, this
    keeps the check's two derivations under the late install."""
    replaceable = REPLACEABLE if replaceable is None else replaceable
    for name in names:
        fn = ns.get(name)
        if layers:
            try:
                fn = innermost(name, fn)
            except ValueError as e:
                return str(e)
        file = getattr(getattr(fn, "__code__", None), "co_filename", None)
        seacast_here = file == SEACAST_FILE
        if name in traced and seacast_here:
            return f"{name} is traced, but its function here is seacast.md's"
        if name in seacast_defs and not seacast_here:
            if name in replaceable and file != DOC_FILE:
                continue
            return f"seacast.md defines {name}, but its function here is not SEACAST's"
    return None


def seacast_kept_self_test():
    """seacast_kept's cases on planted sources, and namespace_check's on a planted namespace: each must give what it
    states. The namespace's case with a redefined name left in the traced list is the control "a traced list
    computed with one redefined name left in must fail its check"."""
    p = "def a():\n    b()\ndef b():\n    pass\ndef c():\n    d()\ndef d():\n    pass\ndef e():\n    x()\ndef f():\n    c()\n"
    names = ("a", "b", "c", "d", "e", "f")
    cases = [
        ("SEACAST redefines d: d goes, c (calls d) and f (calls c) go with it; e's call of x, no name of theirs, is a "
         "question", seacast_kept(names, p, "def d():\n    pass\n"), ("a", "b", "e")),
        ("SEACAST redefines x alone, which is none of the names: nothing goes", seacast_kept(names, p, "def x():\n    pass\n"),
         names),
        ("SEACAST redefines nothing: nothing goes", seacast_kept(names, p, ""), names),
        ("a name seacast-lite.md does not define (a toy helper) stays unless SEACAST defines it",
         seacast_kept(("a", "h"), p, "def d():\n    pass\n"), ("a", "h")),
        # the closure through every def of seacast-lite.md, cut at the tape's names
        ("a name that reaches a redefined def through a helper outside the names goes",
         seacast_kept(("f", "a"), p, "def d():\n    pass\n", cut=()), ("a",)),
        ("a name that calls a tape name SEACAST redefines stays: the call is a question",
         seacast_kept(("c", "a"), p, "def d():\n    pass\n", cut=("d",)), ("c", "a")),
    ]
    bad = 0
    for what, got, want in cases:
        ok = got == want
        bad += not ok
        print(f"seacast_kept self-test, {what}: {'ok' if ok else f'got {got}, must be {want}  <-- FAIL'}")
    # a namespace as the toy makes one: seacast-lite.md's functions compiled under one file name, SEACAST's under SEACAST_FILE
    ns = {}
    exec(compile(p, "seacast-lite.md (extracted)", "exec"), ns)
    exec(compile("def d():\n    pass\n", SEACAST_FILE, "exec"), ns)
    kept = seacast_kept(names, p, "def d():\n    pass\n")
    own = {}
    exec(compile("def d():\n    pass\n", "node.py", "exec"), own)       # a node's own function under the name
    ncases = [
        ("the computed set, d SEACAST's here: passes", namespace_check(names, kept, {"d"}, ns), None),
        ("the computed set with d, which SEACAST redefines, left in: refused",
         namespace_check(names, kept + ("d",), {"d"}, ns), "d is traced, but its function here is seacast.md's"),
        ("the computed set, but d seacast-lite.md's here (SEACAST's block not run over it): refused",
         namespace_check(names, kept, {"d"}, {**ns, "d": ns["b"]}),
         "seacast.md defines d, but its function here is not SEACAST's"),
        # a replaceable name SEACAST defines may be the node's own (neither document's)
        ("d replaceable and the node's own here (a function of neither document): passes",
         namespace_check(names, kept, {"d"}, {**ns, "d": own["d"]}, replaceable=("d",)), None),
        ("d replaceable, but seacast-lite.md's here: refused",
         namespace_check(names, kept, {"d"}, {**ns, "d": ns["b"]}, replaceable=("d",)),
         "seacast.md defines d, but its function here is not SEACAST's"),
        ("d the node's own here, and not replaceable: refused",
         namespace_check(names, kept, {"d"}, {**ns, "d": own["d"]}, replaceable=()),
         "seacast.md defines d, but its function here is not SEACAST's"),
        ("d replaceable and left in the traced list, SEACAST's here: refused as before",
         namespace_check(names, kept + ("d",), {"d"}, ns, replaceable=("d",)),
         "d is traced, but its function here is seacast.md's"),
    ]
    # under the late install (--doc seacast): toy layers as node.py's _seacast makes them, each holding the next in a cell

    def layer(inner, other=None):
        g = {}
        exec(compile("def make(doc, other):\n    def d(*a):\n        if other:\n            other(*a)\n"
                     "        return doc(*a)\n    return d\n", "node.py", "exec"), g)
        return g["make"](inner, other)
    doc_d, seacast_e = {}, {}
    exec(compile("def d():\n    pass\n", DOC_FILE, "exec"), doc_d)       # seacast-lite.md's function under the name
    exec(compile("def e2():\n    pass\n", SEACAST_FILE, "exec"), seacast_e)         # SEACAST's function of another name
    ncases += [
        ("d bound to a toy layer over SEACAST's d, under SEACAST: passes",
         namespace_check(names, kept, {"d"}, {**ns, "d": layer(ns["d"])}, layers=True), None),
        ("the same without the chain (seacast-lite.md's reading): refused",
         namespace_check(names, kept, {"d"}, {**ns, "d": layer(ns["d"])}),
         "seacast.md defines d, but its function here is not SEACAST's"),
        ("d bound to two toy layers over SEACAST's d, under SEACAST: passes",
         namespace_check(names, kept, {"d"}, {**ns, "d": layer(layer(ns["d"]))}, layers=True), None),
        ("d bound to a toy layer over seacast-lite.md's d, replaceable, under SEACAST: refused",
         namespace_check(names, kept, {"d"}, {**ns, "d": layer(doc_d["d"])}, replaceable=("d",), layers=True),
         "seacast.md defines d, but its function here is not SEACAST's"),
        ("d left in the traced list, bound to a toy layer over SEACAST's d, under SEACAST: refused",
         namespace_check(names, kept + ("d",), {"d"}, {**ns, "d": layer(ns["d"])}, layers=True),
         "d is traced, but its function here is seacast.md's"),
        ("d bound to a toy layer over SEACAST's e2 (another name), under SEACAST: refused",
         namespace_check(names, kept, {"d"}, {**ns, "d": layer(seacast_e["e2"])}, layers=True),
         "seacast.md defines d, but its function here is not SEACAST's"),
        ("d bound to a toy layer holding two functions named d, under SEACAST: refused",
         namespace_check(names, kept, {"d"}, {**ns, "d": layer(ns["d"], own["d"])}, layers=True),
         "a layer of d holds 2 functions of that name"),
    ]
    for what, got, want in ncases:
        ok = got == want
        bad += not ok
        print(f"namespace_check self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    return bad


def forms_self_test():
    """The SEACAST forms of the tracer's encoders (seacast.md's values a record writes where seacast-lite.md's differ),
    on toy objects made for each case, with no run and no replay; and the same objects under seacast-lite.md, in its
    forms. The control: each SEACAST case run again with seacast-lite.md's encoder in the SEACAST one's place must fail, and
    exactly those."""
    sys.path.insert(0, str(HERE.parents[2] / "toy"))
    import bits as B                    # noqa: E402: the toy's, beside this repository's documents
    import wire as Wm                   # noqa: E402

    def tracer(seacast):
        tr = object.__new__(Tracer3)
        tr.Wm, tr.doc_seacast = Wm, seacast
        return tr

    def run(f, seacast):
        try:
            return f(tracer(seacast))
        except (SystemExit, TypeError) as e:
            return f"{type(e).__name__}: {e}"

    g, h = bytes(range(32)), bytes(range(32, 64))
    sid = bytes(range(56))              # a structured id
    gx, sx = g.hex(), sid.hex()

    def iwant(mark):
        c = Wm.IWANT([Wm.WantIndex(g, 3), Wm.FlaggedWant(g, 4, True, 2, probe=True), sid])
        c.items[0].want = mark
        return c

    def holding(claim_all, complete, group=g, v=0b101):
        b = Wm.HaveBitmap(group, B.Bits(v))
        b.claim_all, b.complete = claim_all, complete
        return b

    def have_entry():
        e = B.HaveEntry()
        e.bits, e.ttl, e.claim_all, e.complete = B.Bits(0b1011), 5, True, False
        return e

    class Join(Wm.Container):           # seacast.md's Join: a Container of the document's (node.py's joins)
        pass

    def jn(cls):
        return cls(object_type="column", interest="DERIVED", custody_count=4, duty="FORWARD", colours=1)
    graft = Wm.Container(object_type="row", family=-3, colour=0, direction="OUT", answer=True)
    prune = Wm.Container(object_type="row", family=2, colour=1, direction="BOTH")

    def peer_has(tr):                   # the value peer_has's schema line writes
        (t,) = [t for t in tr.schema(None) if t.name == "peer_has"]
        return t.value(have_entry())

    def tape_iwant(tr, late=False):     # enqueue's arguments on the tape: the mark set after the call (SEACAST's send)
        x = iwant(False)
        EAGER_LATE[0] = late
        try:
            early = tr.at_call("enqueue", tr.enqueue_enc, (7, x), {})
            x.items[0].want = True
            return tr.tape_row(tr.enqueue_enc, True, (7, x), {}, early)
        finally:
            EAGER_LATE[0] = False

    claim_words = "SystemExit: trace3: an IHAVE offers a bitmap with a claim set (claim_all True, complete False)"
    seacast_asks = [[[gx, 3], False, 0, False], [[gx, 4], True, 2, True], [sx, False, 0, False]]
    # (what, the encoding, under SEACAST, under seacast-lite.md); a case whose two forms differ is a SEACAST case
    cases = [
        ("peer_has's entry", peer_has, [11, 5, True, False], [11, 5]),
        ("a lane's IWANT: a plain ask, a flagged ask, a structured id, its mark set",
         lambda tr: tr.qmsg(iwant(True).items[0]), ["iwant", seacast_asks, True], ["iwant", [[gx, 3], [gx, 4], sx]]),
        ("an IWANT on the tape, its mark not set", lambda tr: tr.control(iwant(False)),
         [["iwant", seacast_asks, False]], [["iwant", [[gx, 3], [gx, 4], sx]]]),
        ("a lane's IDONTWANT of a holding with its claims", lambda tr: tr.qmsg(Wm.IDONTWANT(holding(True, True)).items[0]),
         ["idontwant", [["holding", gx, 5, True, True]]], ["idontwant", [["bits", gx, 5]]]),
        ("an IDONTWANT on the tape: a holding, and an opaque id", lambda tr: tr.control(Wm.IDONTWANT([holding(False, True), sid])),
         [["idontwant", [["holding", gx, 5, False, True], sx]]], [["idontwant", [["bits", gx, 5], sx]]]),
        ("a JOIN, the document's class", lambda tr: tr.qmsg(Wm.JOIN([jn(Join)]).items[0]),
         ["join", [["join", "column", "DERIVED", 4, "FORWARD", 1]]],
         "TypeError: trace3: a queue entry's control message the record cannot hold"),
        ("a JOIN, a wire Container", lambda tr: tr.qmsg(Wm.JOIN([jn(Wm.Container)]).items[0]),
         ["join", [["join", "column", "DERIVED", 4, "FORWARD", 1]]],
         "TypeError: trace3: a queue entry's control message the record cannot hold"),
        ("a GRAFT on the tape, its family below zero", lambda tr: tr.control(Wm.GRAFT([graft])),
         [["graft", [["graft", "row", ["-", 3], 0, "OUT", True]]]], "TypeError: not an ask key"),
        ("a PRUNE of SEACAST", lambda tr: tr.qmsg(Wm.PRUNE([prune]).items[0]), ["prune", [["prune", "row", 2, 1, "BOTH"]]],
         "TypeError: trace3: a queue entry's control message the record cannot hold"),
        ("a KeyError on a group", lambda tr: tr.missing_key(g), ["group", gx],
         "TypeError: trace3: a KeyError on a key that is not a peer"),
        ("a KeyError on a type by its id", lambda tr: tr.missing_key("row"), ["type", "row"],
         "TypeError: trace3: a KeyError on a key that is not a peer"),
        ("a KeyError on a type object", lambda tr: tr.missing_key(Wm.Container(id="column")), ["type", "column"],
         "TypeError: trace3: a KeyError on a key that is not a peer"),
        ("a KeyError on a negative integer", lambda tr: tr.missing_key(-2), ["-", 2], -2),
        ("enqueue's IWANT, marked after the call", tape_iwant,
         [[7, [["iwant", seacast_asks, False]], False], True], [[7, [["iwant", [[gx, 3], [gx, 4], sx]]], False], True]),
        # the same under both documents
        ("a KeyError on a peer", lambda tr: tr.missing_key(7), 7, 7),
        ("gossipsub's PRUNE", lambda tr: tr.qmsg(Wm.PRUNE([]).items[0]), ["prune", []], ["prune", []]),
        ("an IHAVE of a bitmap, no claim", lambda tr: tr.qmsg(Wm.IHAVE(holding(False, False)).items[0]),
         ["ihave", [["bits", gx, 5]]], ["ihave", [["bits", gx, 5]]]),
        ("a lane's IHAVE offering a claim", lambda tr: tr.qmsg(Wm.IHAVE(holding(True, False)).items[0]),
         claim_words, claim_words),
        ("an IHAVE on the tape offering a claim", lambda tr: tr.control(Wm.IHAVE([holding(True, False)])),
         claim_words, claim_words),
        ("on_ihave's offer with a claim", lambda tr: tr.args_of("on_ihave", (7, Wm.IHAVE(holding(True, False)).items[0])),
         claim_words, claim_words),
    ]

    def same(got, want):                # a stop's words: its first part, as the case gives it
        if isinstance(want, str) and isinstance(got, str):
            return got.startswith(want)
        return got == want
    bad = 0
    v2cases = []
    for what, f, want2, want1 in cases:
        for seacast, want in ((True, want2), (False, want1)):
            got = run(f, seacast)
            ok = same(got, want)
            bad += not ok
            print(f"forms self-test, {what}, under {'seacast' if seacast else 'seacast-lite.md'}: "
                  f"{'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
        if not same(want1, want2):
            v2cases.append((what, f, want2))
    # the planted fault of the eager encoding: written after the call, the tape holds the mark as set later
    got = run(lambda tr: tape_iwant(tr, late=True), True)
    ok = got == [[7, [["iwant", seacast_asks, True]], False], True]
    bad += not ok
    print(f"forms self-test, the control of the eager encoding (enqueue's argument written after the call): "
          f"{'holds the later mark, ok' if ok else f'got {got!r}  <-- FAIL'}")
    # the control: seacast-lite.md's encoder in the SEACAST one's place fails exactly the SEACAST cases
    failed = [what for what, f, want2 in v2cases if not same(run(f, False), want2)]
    ok = failed == [w for w, _, _ in v2cases]
    bad += not ok
    print(f"forms self-test, the control (seacast-lite.md's encoders in SEACAST's place): "
          f"{f'fails exactly the {len(failed)} SEACAST cases, ok' if ok else f'fails {failed}  <-- FAIL'}")
    # S1-8b, the writer's half: the −1 family in a GRAFT, a PRUNE and counted's need, written ["-", 1]; the planted
    # writer, whose integer writes the int as it is, must fail exactly these three
    import records_seacast                   # noqa: E402: this directory's (it imports this module, loaded by now)
    fam_cases = [
        ("a GRAFT with the −1 family",
         lambda tr: tr.rel_msg(Wm.Container(object_type="column", family=-1, colour=0, direction="IN", answer=False)),
         ["graft", "column", ["-", 1], 0, "IN", False]),
        ("a PRUNE with the −1 family",
         lambda tr: tr.rel_msg(Wm.Container(object_type="column", family=-1, colour=0, direction="IN")),
         ["prune", "column", ["-", 1], 0, "IN"]),
        ("counted's need with the −1 family", lambda tr: records_seacast.need_pairs(tr, {-1: 2, 3: 0}),
         [[["-", 1], 2], [3, 0]]),
    ]
    for what, f, want in fam_cases:
        got = run(f, True)
        ok = got == want
        bad += not ok
        print(f"forms self-test, S1-8b, {what}, under SEACAST: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    _integer = Tracer3.__dict__["integer"]
    Tracer3.integer = staticmethod(lambda i: i)     # the planted writer: the plain int
    try:
        failed = [what for what, f, want in fam_cases if run(f, True) != want]
    finally:
        Tracer3.integer = _integer
    ok = failed == [w for w, _, _ in fam_cases]
    bad += not ok
    print(f"forms self-test, S1-8b's planted writer (the plain int): "
          f"{f'refuses exactly the {len(failed)} cases, ok' if ok else f'refuses {failed}  <-- FAIL'}")
    # the nodes line's type parameters (types_seacast)
    tr = tracer(True)

    class Nd:
        id = 3

    def prm(**kw):
        p = Wm.Container(**kw)
        return tr.type_params(Nd, "row", p)

    class NeverNe(float):               # a float subclass whose own != would decide the integral test
        def __ne__(self, other):
            return False

    class SubInt(int):
        pass
    pcases = [
        ("naturals, booleans, floats (+inf where unbounded), the width, none's two",
         lambda: prm(M=1, EAGER=False, START_DELAY=0.5, SERVE_LIMIT=math.inf, ANNOUNCE_EXTRA="ALL_JOINED",
                     EVIDENCE=None, REPAIR_SAMPLE=[(3, 1), (6, 2)], REPAIR_TO=lambda gg: []),
         {"ANNOUNCE_EXTRA": "ALL_JOINED", "EAGER": False, "EVIDENCE": None, "M": 1, "REPAIR_SAMPLE": [[3, 1], [6, 2]],
          "SERVE_LIMIT": 9218868437227405312, "START_DELAY": fbits(0.5)}),
        ("an M of 0", lambda: prm(M=0), "SystemExit: trace3: node 3: type row: M is no natural above 0"),
        ("an infinite START_DELAY", lambda: prm(START_DELAY=math.inf),
         "SystemExit: trace3: node 3: type row: START_DELAY is no finite number"),
        ("an EVIDENCE type", lambda: prm(EVIDENCE=object()),
         "SystemExit: trace3: node 3: type row: EVIDENCE is an evidence type"),
        ("a parameter the tracer does not know", lambda: prm(NEW_ONE=1),
         "SystemExit: trace3: node 3: type row: NEW_ONE is a parameter the tracer does not know"),
        ("MAX_RELATIONS +inf and MAX_INDICES 8192, both written", lambda: prm(
            M=1, MAX_RELATIONS=math.inf, MAX_INDICES=8192),
         {"M": 1, "MAX_INDICES": 8192, "MAX_RELATIONS": 9218868437227405312}),
        ("a MAX_RELATIONS of 3, written as 3.0's word", lambda: prm(MAX_RELATIONS=3), {"MAX_RELATIONS": fbits(3.0)}),
        ("a MAX_RELATIONS of 0, an empty link's, written as 0.0's word", lambda: prm(MAX_RELATIONS=0),
         {"MAX_RELATIONS": 0}),
        ("a MAX_RELATIONS of NaN", lambda: prm(MAX_RELATIONS=math.nan),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_RELATIONS of -1", lambda: prm(MAX_RELATIONS=-1),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_RELATIONS of -inf", lambda: prm(MAX_RELATIONS=-math.inf),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_RELATIONS of 2.5", lambda: prm(MAX_RELATIONS=2.5),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_INDICES of 0", lambda: prm(MAX_INDICES=0),
         "SystemExit: trace3: node 3: type row: MAX_INDICES is no natural above 0"),
        ("a MAX_INDICES of True", lambda: prm(MAX_INDICES=True),
         "SystemExit: trace3: node 3: type row: MAX_INDICES is no natural above 0"),
        ("a MAX_RELATIONS of True", lambda: prm(MAX_RELATIONS=True),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_RELATIONS of 2^53+1, which a float rounds", lambda: prm(MAX_RELATIONS=2 ** 53 + 1),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_RELATIONS of the int 10^400, beyond any float", lambda: prm(MAX_RELATIONS=10 ** 400),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_RELATIONS of 0.5", lambda: prm(MAX_RELATIONS=0.5),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a MAX_RELATIONS of 2^53, written as its word", lambda: prm(MAX_RELATIONS=2 ** 53),
         {"MAX_RELATIONS": 4845873199050653696}),
        ("a MAX_RELATIONS of -0.0, written as its own word", lambda: prm(MAX_RELATIONS=-0.0),
         {"MAX_RELATIONS": 9223372036854775808}),
        ("a MAX_RELATIONS of the float 1e400, which is +inf", lambda: prm(MAX_RELATIONS=1e400),
         {"MAX_RELATIONS": 9218868437227405312}),
        ("a START_DELAY of 2^53+1, which a float rounds", lambda: prm(START_DELAY=2 ** 53 + 1),
         "SystemExit: trace3: node 3: type row: START_DELAY is no finite number"),
        ("a START_DELAY of the int 10^400, beyond any float", lambda: prm(START_DELAY=10 ** 400),
         "SystemExit: trace3: node 3: type row: START_DELAY is no finite number"),
        ("a MAX_RELATIONS of 2.5 as a float subclass whose != is always false", lambda: prm(MAX_RELATIONS=NeverNe(2.5)),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("a START_DELAY of 3 as a plain int subclass", lambda: prm(START_DELAY=SubInt(3)),
         "SystemExit: trace3: node 3: type row: START_DELAY is no finite number"),
        ("an M of 3 as a plain int subclass", lambda: prm(M=SubInt(3)),
         "SystemExit: trace3: node 3: type row: M is no natural above 0"),
        ("a MAX_RELATIONS of 10^5000, too long to print", lambda: prm(MAX_RELATIONS=10 ** 5000),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf: an int of 16610 bits"),
        ("a MAX_RELATIONS of a list holding 10^5000", lambda: prm(MAX_RELATIONS=[10 ** 5000]),
         "SystemExit: trace3: node 3: type row: MAX_RELATIONS is no count nor +inf"),
        ("SAMPLE_OUTSTANDING, the node's since v0.11.1, as a type's", lambda: prm(SAMPLE_OUTSTANDING=4),
         "SystemExit: trace3: node 3: type row: SAMPLE_OUTSTANDING is a parameter the tracer does not know"),
    ]
    for what, f, want in pcases:
        try:
            got = f()
        except SystemExit as e:
            got = f"SystemExit: {e}"
        ok = same(got, want)
        bad += not ok
        print(f"forms self-test, a type's parameters, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    # the node's constants that seacast.md adds (consts_seacast), on a stub namespace; and its planted check, which
    # writes SERVE_BUDGET by fbits as the other numbers are written, so that +inf is no longer null
    def consts(**kw):
        ns = dict(ANSWERS_FIRST=False, MERGE_HOLDINGS=True, ASK_UPLINK=0.0, SAMPLE_OUTSTANDING=4,
                  SERVE_BUDGET=math.inf)
        ns.update(kw)
        return Tracer3.consts_seacast(Nd, ns)
    base = {"ANSWERS_FIRST": False, "MERGE_HOLDINGS": True, "ASK_UPLINK": fbits(0.0), "SAMPLE_OUTSTANDING": 4}
    ccases = [
        ("SERVE_BUDGET +inf, written null", lambda: consts(), dict(base, SERVE_BUDGET=None)),
        ("SERVE_BUDGET 3, and a whole 2.0 as 2", lambda: [consts(SERVE_BUDGET=3)["SERVE_BUDGET"],
                                                          consts(SERVE_BUDGET=2.0)["SERVE_BUDGET"]], [3, 2]),
        ("SAMPLE_OUTSTANDING 1", lambda: consts(SAMPLE_OUTSTANDING=1)["SAMPLE_OUTSTANDING"], 1),
    ] + [(f"SERVE_BUDGET {v!r}", (lambda v=v: consts(SERVE_BUDGET=v)),
          f"SystemExit: trace3: node 3: SERVE_BUDGET is no count of at least 1 nor +inf: {v!r}")
         for v in (0, True, 2.5, -math.inf)] + [
        (f"SAMPLE_OUTSTANDING {v!r}", (lambda v=v: consts(SAMPLE_OUTSTANDING=v)),
         f"SystemExit: trace3: node 3: SAMPLE_OUTSTANDING is no count of at least 1: {v!r}")
        for v in (0, True, 2.0)]

    def run_c(f):
        try:
            return f()
        except SystemExit as e:
            return f"SystemExit: {e}"
    for what, f, want in ccases:
        got = run_c(f)
        ok = same(got, want)
        bad += not ok
        print(f"forms self-test, the node's SEACAST constants, {what}: "
              f"{'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    _consts_seacast = Tracer3.__dict__["consts_seacast"]

    def planted(nd, ns):
        out = _consts_seacast.__func__(nd, dict(ns, SERVE_BUDGET=3))
        out["SERVE_BUDGET"] = fbits(ns["SERVE_BUDGET"])
        return out
    Tracer3.consts_seacast = staticmethod(planted)
    try:
        failed = [what for what, f, want in ccases if not same(run_c(f), want)]
    finally:
        Tracer3.consts_seacast = _consts_seacast
    want_failed = [w for w, _, _ in ccases if w.startswith("SERVE_BUDGET")]
    ok = failed == want_failed
    bad += not ok
    print(f"forms self-test, the node's SEACAST constants, the planted check (SERVE_BUDGET by fbits): "
          f"{f'fails exactly the {len(failed)} SERVE_BUDGET cases, ok' if ok else f'fails {failed}  <-- FAIL'}")
    return bad


def views_self_test():
    """seacast.md's tables as views, at the recorder's level, on the toy's own containers (bits.py's) and no
    run: the levels whose order is on the tape (`claims`, `probe_waiting[g]`), with two planted faults; the two
    keys of `probe_asks`; `interest`'s miss as the question `own_interest`, with its planted fault; and the §3 scan,
    with its planted controls. The control: each view case run again with the tables of seacast-lite.md's install
    (Tracer3.schema without --doc seacast) must fail, and all of them."""
    sys.path.insert(0, str(HERE.parents[2] / "toy"))
    import bits as B                    # noqa: E402: the toy's, beside this repository's documents
    import wire as Wm                   # noqa: E402

    def tables(seacast):
        tr = object.__new__(Tracer3)
        tr.Wm, tr.doc_seacast = Wm, seacast
        return {t.name: t for t in tr.schema(None)}

    g1, g2, g3 = (bytes([n]) * 32 for n in (1, 2, 3))
    sid = g1 + (3).to_bytes(4, "little") + bytes(20)        # a structured id of g1's chunk 3: 56 bytes

    class SortingRecorder(F.Recorder):  # the planted fault: a recorder that sorts the keys it puts on the tape
        def keys(self, t, prefix, ks):
            return super().keys(t, prefix, sorted(ks))

    def record(ts, names, raw, act, rec=None, unordered=False, hook=True, callee=False):
        """`act(ns)` in an open record over the views of `names` (raw: their containers); its tape, reads and
        writes, and what it returned."""
        rec = rec or F.Recorder()
        tl = [ts[n] for n in names]
        if unordered:                   # the planted fault: the table lines without the ordering flags
            tl = [F.Table(t.name, t.keys, t.value, rows=t.rows, values_ordered=t.values_ordered,
                          presence_in=t.presence_in) for t in tl]
        ns = dict(raw)
        F.install(rec, ns, tl)
        if hook and "interest" in names:
            ns["interest"] = MissQuestionView(ns["interest"], miss_question(rec))
        rec.on, rec.tape = True, []
        if callee:
            rec.begin_callee()
        r = act(ns)
        cr = rec.end_callee()[0] if callee else None
        reads, _, writes = rec.footprint()
        return {"tape": rec.tape, "reads": reads, "writes": writes, "ret": r, "cr": cr}

    def claims_raw():
        c = B.lazy(B.LazySet)
        for g, q in ((g3, 5), (g1, 6), (g2, 7)):            # inserted out of order on purpose
            c[g].add(q)
        return {"claims": c}

    def waiting_raw():
        w = B.lazy(B.lazy_dict)
        for q, i in ((5, 1), (2, 2), (9, 3)):
            w[g1][q] = i
        return {"probe_waiting": w}

    class InterestMap(dict):            # the toy's (node.py's `_seacast`): the ALL fixture, every index for any group
        def __missing__(self, g):
            return B.Bits(-1)

    def interest_raw():
        m = InterestMap()
        m[g2] = B.Bits(0)               # a stored 0: a value, which asks nothing
        return {"interest": m}

    def asks_raw():
        return {"probe_asks": {Wm.WantIndex(g1, 3)}}

    order_claims = [["keys", "claims", [], [g3.hex(), g1.hex(), g2.hex()]]]
    order_waiting = [["keys", "probe_waiting", [g1.hex()], [5, 2, 9]]]
    # (what, the case run over a table set, what it must give)
    vcases = [
        ("claims.items() in a record: the groups' order on the tape, as inserted",
         lambda ts: record(ts, ["claims"], claims_raw(), lambda ns: list(ns["claims"].items()))["tape"], order_claims),
        ("probe_waiting[g].items() in a record: the peers' order on the tape, as inserted",
         lambda ts: record(ts, ["probe_waiting"], waiting_raw(),
                           lambda ns: list(ns["probe_waiting"][g1].items()))["tape"], order_waiting),
        ("probe_asks: an ask by index, stored, and the same chunk's structured id, not stored: two keys read",
         lambda ts: (lambda o: (o["reads"], o["ret"]))(record(
             ts, ["probe_asks"], asks_raw(),
             lambda ns: (Wm.WantIndex(g1, 3) in ns["probe_asks"], sid in ns["probe_asks"]))),
         ([["probe_asks", [[g1.hex(), 3]], True], ["probe_asks", [sid.hex()], None]], (True, False))),
        ("probe_asks.add: a write with no read",
         lambda ts: (lambda o: (o["reads"], o["writes"]))(record(
             ts, ["probe_asks"], asks_raw(), lambda ns: ns["probe_asks"].add(Wm.WantIndex(g2, 4)))),
         ([], [["probe_asks", [[g2.hex(), 4]], True]])),
        ("interest's miss in a record (ALL): read missing, then own_interest on the tape; nothing stored",
         lambda ts: (lambda o: (o["tape"], o["reads"], o["writes"], o["ret"].v))(record(
             ts, ["interest"], interest_raw(), lambda ns: ns["interest"][g1])),
         ([["own_interest", [g1.hex()], ["-", 1]]], [["interest", [g1.hex()], None]], [], -1)),
        ("interest's stored 0 in a record: read, and no question",
         lambda ts: (lambda o: (o["tape"], o["reads"], o["ret"].v))(record(
             ts, ["interest"], interest_raw(), lambda ns: ns["interest"][g2])),
         ([], [["interest", [g2.hex()], 0]], 0)),
        ("interest's miss inside a question: nothing on the tape, the read the question's",
         lambda ts: (lambda o: (o["tape"], o["cr"]))(record(
             ts, ["interest"], interest_raw(), lambda ns: ns["interest"][g1], callee=True)),
         ([], [["interest", [g1.hex()], None]])),
    ]

    def run(f, ts):
        try:
            return f(ts)
        except Exception as e:          # a table the install does not have, and anything else: the case fails
            return f"{type(e).__name__}: {e}"
    bad = 0
    v2t, p1t = tables(True), tables(False)
    for what, f, want in vcases:
        got = run(f, v2t)
        ok = got == want
        bad += not ok
        print(f"views self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    # the planted faults: each must give what its case refuses
    plants = [
        ("claims without the ordering flag: no keys on the tape",
         lambda: record(v2t, ["claims"], claims_raw(), lambda ns: list(ns["claims"].items()), unordered=True)["tape"],
         order_claims),
        ("probe_waiting without its ordered level: no keys on the tape",
         lambda: record(v2t, ["probe_waiting"], waiting_raw(), lambda ns: list(ns["probe_waiting"][g1].items()),
                        unordered=True)["tape"], order_waiting),
        ("a recorder that sorts: claims' groups sorted",
         lambda: record(v2t, ["claims"], claims_raw(), lambda ns: list(ns["claims"].items()),
                        rec=SortingRecorder())["tape"], order_claims),
        ("a recorder that sorts: probe_waiting's peers sorted",
         lambda: record(v2t, ["probe_waiting"], waiting_raw(), lambda ns: list(ns["probe_waiting"][g1].items()),
                        rec=SortingRecorder())["tape"], order_waiting),
        ("interest's miss left to the toy's own __missing__: no own_interest on the tape",
         lambda: record(v2t, ["interest"], interest_raw(), lambda ns: ns["interest"][g1], hook=False)["tape"],
         [["own_interest", [g1.hex()], ["-", 1]]]),
    ]
    for what, f, refused in plants:
        got = f()
        ok = got != refused
        bad += not ok
        print(f"views self-test, planted: {what}: "
              f"{f'gives {got!r}, which its case refuses, ok' if ok else 'not seen  <-- FAIL'}")
    # the control: seacast-lite.md's install has none of these tables, so every view case fails
    failed = [what for what, f, want in vcases if run(f, p1t) != want]
    ok = len(failed) == len(vcases)
    bad += not ok
    print(f"views self-test, the control (seacast-lite.md's install in SEACAST's place): "
          f"{f'fails all {len(failed)} view cases, ok' if ok else f'fails only {failed}  <-- FAIL'}")
    # the §3 scan, on this repository's seacast.md and on copies with a line planted or removed
    text = (HERE.parents[2] / "seacast.md").read_text()
    anchor = re.search(r"^rsample_final:.*\n", text, re.M)

    def with_lines(*lines, drop=False):
        a, b = anchor.span()
        return text[:a] + ("" if drop else anchor.group(0)) + "".join(f"{x}\n" for x in lines) + text[b:]

    def line_of(name, new=None):        # §3 with one table's line replaced by `new`, or removed
        m = re.search(rf"^{name}:.*\n", text, re.M)
        return text[:m.start()] + ("" if new is None else new + "\n") + text[m.end():]

    def scan(t, **kw):                  # the scan as install runs it: names and key counts
        return sec3_check(sec3_names(t), keys=sec3_keys(t), **kw)
    scases = [
        ("this repository's §3", lambda: scan(text), []),
        ("§3 without rsample_final's line", lambda: scan(with_lines(drop=True)),
         ["rsample_final: in schema_seacast.py, not in §3"]),
        ("§3 with a planted table", lambda: scan(with_lines("planted_t: Dict[GroupId, int]")),
         ["planted_t: in §3, in no list"]),
        ("§3 without served_hb's line", lambda: scan(line_of("served_hb")),
         ["served_hb: in schema_seacast.py, not in §3"]),
        ("forwarded's schema row planted back at one key, [P]", lambda: scan(text, arity=dict(SCHEMA_KEYS,
                                                                                          forwarded=1)),
         ["forwarded: 2 keys in §3, 1 in its schema row"]),
        ("§3's forwarded line planted at Dict[PeerId, int]",
         lambda: scan(line_of("forwarded", "forwarded: Dict[PeerId, int]")),
         ["forwarded: 1 key in §3, 2 in its schema row"]),
        ("§3's forwarded line planted at Dict[PeerId, int], the names alone (the scan before v0.11.1)",
         lambda: sec3_check(sec3_names(line_of("forwarded", "forwarded: Dict[PeerId, int]"))), []),
        ("want_p, which §3 declares, named as undeclared by a planted exception",
         lambda: scan(text, undeclared={"want_p": "planted"}), ["want_p: named as not in §3, and §3 declares it"]),
        ("promises' split named no more", lambda: scan(text, split={}),
         ["promises: 1 key in §3, 2 in its schema row"]),
        ("the key counts' rules: a Dict level (a tuple key one), a Set table, a Set or List in the value",
         lambda: [key_count(a) for a in ("Dict[Tuple[Ask, PeerId], float]", "Set[Ask]",
                                         "Dict[GroupId, Dict[int, Set[PeerId]]]",
                                         "Dict[BlockId, List[Tuple[GroupId, int]]]", "Dict[PeerId, Dict[ObjectType, int]]",
                                         "Dict[PeerId, Dict[TypeId, Dict[FamilyId, Dict[Tuple[int, Direction], float]]]]",
                                         "int")], [1, 1, 2, 1, 2, 4, 0]),
    ]
    for what, f, want in scases:
        got = f()
        ok = got == want
        bad += not ok
        print(f"views self-test, the §3 scan, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    print(f"views self-test, the §3 scan names as used and not declared in §3: "
          f"{'; '.join(f'{n} ({why})' for n, why in UNDECLARED_Seacast.items()) or 'none'}")
    return bad


def manifest_self_test():
    """manifest_check (step 2's known answer 4): on the toy as it is, the tracer's lists are the manifest's; each
    planted difference in a copy of the manifest is named. The control: each case run again with a check that finds
    nothing must fail exactly the planted ones."""
    import types
    sys.path.insert(0, str(HERE.parents[2] / "toy"))
    import node as N                    # noqa: E402: the toy beside this repository's documents
    kept = tuple(n for n in seacast_kept(BLOCK, N.SPEC_SRC, N.generate(N.DOC2)) if n not in SEC71)
    traced = kept + tuple(n for n in manifest_seacast.COVERED if n not in kept)     # as Tracer3 traces under SEACAST
    m = manifest_seacast

    def copy(**kw):
        d = {k: getattr(m, k) for k in ("KEPT", "COVERED", "NODE_OWN", "OWN", "FOREIGN")}
        d.update(kw)
        return types.SimpleNamespace(**d)
    own2 = list(m.OWN)
    own2[0], own2[1] = own2[1], own2[0]
    cases = [
        ("the toy as it is, the manifest as it is", lambda chk: chk(traced), []),
        ("§6.1's twelve alone (traced not compared)", lambda chk: chk(None), []),
        ("a KEPT name dropped from the manifest (retry_offer)", lambda chk: chk(traced, copy(
            KEPT=[n for n in m.KEPT if n != "retry_offer"])),
         ["traced, not in the manifest's KEPT, COVERED or NODE_OWN: ['retry_offer']; in them, not traced: []"]),
        ("a name in the manifest's KEPT that is not traced (window_release)", lambda chk: chk(traced, copy(
            KEPT=list(m.KEPT) + ["window_release"])),
         ["traced, not in the manifest's KEPT, COVERED or NODE_OWN: []; in them, not traced: ['window_release']"]),
        # H1: a covered name left out, of the manifest and of the traced names in turn
        ("a COVERED name dropped from the manifest (keep_floor)", lambda chk: chk(traced, copy(
            COVERED=[n for n in m.COVERED if n != "keep_floor"])),
         ["traced, not in the manifest's KEPT, COVERED or NODE_OWN: ['keep_floor']; in them, not traced: []"]),
        ("a COVERED name left out of the traced names (keep_floor)", lambda chk: chk(
            tuple(n for n in traced if n != "keep_floor")),
         ["traced, not in the manifest's KEPT, COVERED or NODE_OWN: []; in them, not traced: ['keep_floor']"]),
        ("NODE_OWN's helper under another qualified name", lambda chk: chk(traced, copy(
            NODE_OWN={"held": "Node._planted.<locals>.held"})),
         [f"NODE_OWN is {dict(NODE_OWN)!r} here, {{'held': 'Node._planted.<locals>.held'}} in the manifest"]),
        ("the manifest's OWN with its first two tables swapped", lambda chk: chk(traced, copy(OWN=own2)),
         [f"own: {len(OWN) + len(OWN_Seacast)} tables here, {len(own2)} in the manifest, the first difference at "
          f"position 1"]),
        ("the manifest's FOREIGN without chunks", lambda chk: chk(traced, copy(FOREIGN=["known_id"])),
         [f"foreign is {list(FOREIGN)} here, ['known_id'] in the manifest"]),
    ]
    bad = 0
    for what, f, want in cases:
        got = f(manifest_check)
        ok = got == want
        bad += not ok
        print(f"manifest self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    # the control: a check that finds nothing passes the cases that expect nothing, and fails each planted one
    fails = [what for what, f, want in cases if f(lambda *a, **k: []) != want]
    planted = [what for what, f, want in cases if want]
    ok = fails == planted
    bad += not ok
    print(f"manifest self-test, the control (a check that finds nothing): {len(fails)} cases fail, the "
          f"{len(planted)} planted ones: {'ok' if ok else f'got {fails!r}  <-- FAIL'}")
    print(f"manifest self-test: {len(traced)} traced names, the manifest's KEPT {len(m.KEPT)}, COVERED "
          f"{len(m.COVERED)} and NODE_OWN {len(m.NODE_OWN)}; own {len(m.OWN)}, foreign {len(m.FOREIGN)}")
    return bad


# The chain rule self-test's stub toy, compiled as node.py's: each function a layer the self-test lists, or leaves
# out, by its file's name, qualified name and first line, as LAYERS lists the toy's.
CHAIN_TOY = '''\
def over(inner):
    def message_id(f):
        return inner(f)
    return message_id


def over_close(inner):
    def close_promises(g, i, of=None):
        return inner(g, i, of=of)
    return close_promises


def peer(inner):
    def close_promises(g, i, of=None):
        return inner(g, i, of=of)
    return close_promises


def pick(inner, skip):
    if skip:
        def on_iwant(p, iw):
            return [] if p == 0 else inner(p, iw)
    else:
        def on_iwant(p, iw):
            return inner(p, iw)
    return on_iwant


def skipping(inner):
    def on_iwant(p, iw):
        return [] if inner else []
    return on_iwant


def both(a, b):
    def on_iwant(p, iw):
        return a(p, iw) + b(p, iw)
    return on_iwant


def withhold():
    return lambda p, iw: []


def helper():
    def held(a):
        return False
    return held


def lone(other):
    def message_id(f):
        return other(f)
    return message_id
'''


def chains_self_test():
    """The chain rule (chain_rule, node_chains) and the nodes line's grouping by `chains`, on stub layers compiled as
    node.py's (CHAIN_TOY) and listed in stub lists by their files' names, qualified names and first lines. Each case
    runs as the tracer has it; a case with a planted fault runs again with it, which must fail the case, and what
    the plant gives is printed."""
    doc, toy, other, lvl = {}, {}, {}, {}
    exec(compile("def message_id(f):\n    return b''\n\n\ndef on_iwant(p, iw):\n    return []\n\n\n"
                 "def close_promises(g, i, of=None):\n    return None\n", DOC_FILE, "exec"), doc)
    exec(compile(CHAIN_TOY, "node.py", "exec"), toy)
    exec(compile(CHAIN_TOY, "fixture.py", "exec"), other)       # the same functions, at the same lines, elsewhere
    exec(compile("def validate_chunk(f):\n    return 'ACCEPT'\n", "directed.py", "exec"), lvl)
    mid_obs, lone = toy["over"](doc["message_id"]), toy["lone"](lambda f: b"")
    mid_other = other["over"](doc["message_id"])
    close_obs = toy["over_close"](doc["close_promises"])
    close_peer = toy["peer"](close_obs)
    iw_obs, iw_chg = toy["pick"](doc["on_iwant"], False), toy["pick"](doc["on_iwant"], True)
    iw_skip, iw_own = toy["skipping"](doc["on_iwant"]), toy["withhold"]()
    two, held = toy["both"](doc["on_iwant"], iw_obs), toy["helper"]()
    key = layer_key
    q = lambda *fs: [f.__qualname__ for f in fs]                   # noqa: E731
    lists = {key(mid_obs): ("message_id", OBSERVER), key(lone): ("message_id", OBSERVER),
             key(close_obs): ("close_promises", OBSERVER), key(close_peer): ("close_promises", OBSERVER),
             key(iw_obs): ("on_iwant", OBSERVER), key(iw_chg): ("on_iwant", CHANGING),
             key(iw_own): ("on_iwant", CHANGING), key(held): ("held", NODE_HELPER)}
    unlisted = {k: v for k, v in lists.items() if k != key(iw_obs)}
    as_changing = lambda f, name: {**lists, key(f): (name, CHANGING)}      # noqa: E731

    def rule(r=chain_rule, wrap=lambda d: d):
        def go(name, fn, whole=False, ls=None):
            return r(name, fn, whole, wrap(lists if ls is None else ls))
        return go

    def W(traced, ns):
        return node_chains(traced, ns, lists=lists)

    # the plants
    class ByQual(dict):         # lists keyed by qualified name alone: the first listed of that name answers
        def get(self, k, d=None):
            return next((v for (_, qual, _), v in self.items() if qual == k[1]), d)

    class NoFile(dict):         # lists keyed by qualified name and first line, in any file
        def get(self, k, d=None):
            return next((v for (_, qual, line), v in self.items() if (qual, line) == k[1:]), d)

    class AnyName(str):         # listed for whatever name it is asked under
        def __ne__(self, other):
            return False

    class Unlisted(dict):       # an unlisted layer classed as changing
        def get(self, k, d=None):
            return dict.get(self, k) or (AnyName("any"), CHANGING)

    def innermost_only(name, fn, whole=False, lists=None):     # the kind read off the function the layers lead to
        c = innermost(name, fn).__code__
        if c.co_filename in (DOC_FILE, SEACAST_FILE) and c.co_name == name:
            return None, False
        return chain_rule(name, fn, whole, lists)

    def interim(traced, ns):    # the earlier writer: the replaced names' chains alone
        rep, ch = W(traced, ns)
        return rep, {n: c for n, c in ch.items() if n in rep}

    def bound_alone(traced, ns):    # the bound layer alone, as own_code sees a name
        rep, ch = W(traced, ns)
        return rep, {n: q(ns[n]) for n in ch}

    def literal(traced, ns):    # the interface's literal rule: a chain for each name not bound to the bare doc
        out = {}
        for n in traced:
            ls = layers_of(n, ns[n])
            c = ls[-1].__code__
            d = c.co_filename in (DOC_FILE, SEACAST_FILE) and c.co_name == n
            if not (d and len(ls) == 1):
                out[n] = q(*(ls[:-1] if d else ls)) + (["doc"] if d else [])
        return [], out

    def no_chains(nodes):       # grouping that ignores chains: an entry keeps its first node's
        entries = []
        for nid, consts, replaced, types, chains in nodes:
            for e in entries:
                if e["consts"] == consts and e["replaced"] == replaced and e.get("types") == types:
                    e["n"].append(nid)
                    break
            else:
                entries.append({"n": [nid], "consts": consts, "replaced": replaced, "chains": chains})
        return entries
    c = {"R": 2}

    def grouped(r, w, g):
        nodes = [(nid, c, [], None, w(["close_promises"], {"close_promises": f})[1])
                 for nid, f in ((1, close_peer), (2, close_obs))]
        return [e["n"] for e in g(nodes)]
    stop = lambda name, why, f: f"stop: {name}: {why}: {layer_where(f)}"     # noqa: E731
    R = rule()
    cases = [   # (what, run(rule, writer, grouping), what it must give, [(the plant, its rule, writer, grouping)])
        ("the document's function bound bare: no chain, not replaced",
         lambda r, w, g: r("message_id", doc["message_id"]), (None, False), []),
        ("a listed observer over the document's message_id: its chain, not replaced",
         lambda r, w, g: w(["message_id"], {"message_id": mid_obs}), ([], {"message_id": q(mid_obs) + ["doc"]}),
         [("the earlier writer (the replaced names' chains alone)", R, interim, group_nodes)]),
        ("two listed observers over close_promises: both in its chain, not replaced",
         lambda r, w, g: w(["close_promises"], {"close_promises": close_peer}),
         ([], {"close_promises": q(close_peer, close_obs) + ["doc"]}),
         [("the bound layer alone, as own_code sees it", R, bound_alone, group_nodes)]),
        ("held, the node's own helper: no chain",
         lambda r, w, g: w(["held", "message_id"], {"held": held, "message_id": doc["message_id"]}), ([], {}),
         [("the interface's literal rule, a chain for each name not bound to the bare doc", R, literal,
           group_nodes)]),
        ("one qualified name, two first lines, an observer and a changing layer",
         lambda r, w, g: [r("on_iwant", iw_obs), r("on_iwant", iw_chg)],
         [(q(iw_obs) + ["doc"], False), (q(iw_chg) + ["doc"], True)],
         [("lists keyed by qualified name alone", rule(wrap=ByQual), W, group_nodes)]),
        ("an unlisted layer stops the tracer",
         lambda r, w, g: r("on_iwant", iw_obs, ls=unlisted),
         stop("on_iwant", "a layer in none of the tracer's lists", iw_obs),
         [("an unlisted layer classed as changing", rule(wrap=Unlisted), W, group_nodes)]),
        ("a listed layer's qualified name and first line in another file: a stop",
         lambda r, w, g: r("message_id", mid_other),
         stop("message_id", "a layer in none of the tracer's lists", mid_other),
         [("lists keyed without the file", rule(wrap=NoFile), W, group_nodes)]),
        ("a layer that holds the document's on_iwant and returns without calling it, unlisted: a stop",
         lambda r, w, g: r("on_iwant", iw_skip), stop("on_iwant", "a layer in none of the tracer's lists", iw_skip),
         [("the kinds read through innermost alone", rule(innermost_only), W, group_nodes)]),
        ("the same layer listed as changing: replaced",
         lambda r, w, g: r("on_iwant", iw_skip, ls=as_changing(iw_skip, "on_iwant")), (q(iw_skip) + ["doc"], True),
         [("the kinds read through innermost alone", rule(innermost_only), W, group_nodes)]),
        ("a changing function that holds nothing of its name: replaced, its chain without doc",
         lambda r, w, g: r("on_iwant", iw_own), (q(iw_own), True), []),
        ("two nodes alike but in their chains: two entries", grouped, [[1], [2]],
         [("grouping that ignores chains", R, W, no_chains)]),
        ("a layer listed for another name: a stop",
         lambda r, w, g: r("message_id", mid_obs, ls={**lists, key(mid_obs): ("close_promises", OBSERVER)}),
         stop("message_id", "a layer listed for close_promises, not for message_id", mid_obs), []),
        ("a changing layer over a name no node may replace: a stop",
         lambda r, w, g: r("message_id", mid_obs, ls=as_changing(mid_obs, "message_id")),
         f"stop: message_id: a changing layer, {layer_where(mid_obs)}, where no node may replace message_id", []),
        ("layers that end in an observer holding no function of its name: a stop",
         lambda r, w, g: r("message_id", lone),
         f"stop: message_id: its layers end in observer {layer_where(lone)}, which holds no function of its name", []),
        ("a layer holding two functions of its name: a stop",
         lambda r, w, g: r("on_iwant", two), "stop: a layer of on_iwant holds 2 functions of that name", []),
        ("a layer that is no Python function: a stop",
         lambda r, w, g: r("message_id", functools.partial(doc["message_id"])),
         "stop: message_id: a layer that is no Python function: partial", []),
        ("in a trace of the whole state, validate_chunk bound to a directed set's function: replaced",
         lambda r, w, g: r("validate_chunk", lvl["validate_chunk"], whole=True), (["validate_chunk"], True), []),
        ("the same outside a trace of the whole state: a stop",
         lambda r, w, g: r("validate_chunk", lvl["validate_chunk"]),
         stop("validate_chunk", "a layer in none of the tracer's lists", lvl["validate_chunk"]), []),
        ("LAYERS' node's own helpers are NODE_OWN",
         lambda r, w, g: {n: qual for (_, qual, _), (n, k) in LAYERS.items() if k == NODE_HELPER}, NODE_OWN, []),
    ]

    def run(f, r, w, g):
        try:
            return f(r, w, g)
        except ChainStop as e:
            return f"stop: {e}"
    bad = 0
    for what, f, want, plants in cases:
        got = run(f, R, W, group_nodes)
        ok = got == want
        bad += not ok
        print(f"chain rule self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
        for plant, r, w, g in plants:
            pgot = run(f, r, w, g)
            ok = pgot != want
            bad += not ok
            print(f"chain rule self-test, {what}, planted {plant}: "
                  + (f"fails it, ok (it gives {pgot!r})" if ok else "passes it  <-- FAIL"))
    return bad


def closure_self_test():
    """closure_seacast's cases and controls, on the toy beside this repository's
    documents, with the manifest and the tracer's parameter schema."""
    sys.path.insert(0, str(HERE.parents[2] / "toy"))
    import node as N                    # noqa: E402: the toy beside this repository's documents
    return closure_seacast.self_test(N, manifest_seacast, Tracer3.params_schema(), Tracer3.TYPE_FUNCTIONS)


def timers_self_test():
    """The notes of the timers a question arms, and a record's own `after` of SEACAST's three timers, on a stub
    simulator, a stub node and stub questions, no toy node: each case compares the whole tape row it expects, or the
    stop's words. Each case's planted fault, run, must fail it. The set's control: the notes' code bypassed (NOTES_OFF:
    `after` and `start` bare inside a question) fails exactly the cases that expect a note or a stop inside a
    question, and passes the others. Then the refusal of --source-offers late under SEACAST, with its planted fault."""
    sys.path.insert(0, str(HERE.parents[2] / "toy"))
    import wire as Wm                   # noqa: E402: the toy's, beside this repository's documents
    g = bytes(range(32))
    gx = g.hex()
    check_time = 0.5                    # the stub's CHECK_TIME
    docs, toy = {}, {}                  # the documents' timers under the documents' names; the toy's under node.py
    exec(compile("def retry_offer(a):\n    pass\ndef ask_parked(a):\n    pass\ndef decode_group(g):\n    pass\n",
                 DOC_FILE, "exec"), docs)
    exec(compile("def reconsider(g, at):\n    pass\ndef ask_sample(g, i, first=False):\n    pass\n"
                 "def resample(g, i, q, first):\n    pass\n", SEACAST_FILE, "exec"), docs)
    exec(compile("def alarm_due(g, i, q, at):\n    pass\ndef _write(p):\n    pass\n", "node.py", "exec"), toy)
    toy["alarm_due"].__qualname__ = "Node._alarm.<locals>.alarm_due"
    toy["_write"].__qualname__ = "Node._write"

    class Sim:                          # the toy's simulator: after(node, delay, fn, *args)
        def __init__(self):
            self.q = []

        def after(self, node, delay, fn, *args):
            self.q.append((delay, fn, args))

    class Node:
        pass

    def run(body, touched=False, patch=None, whole_hook=False):
        """One record at a stub node 1, whose own code asks the question `q(7)`; `q` runs `body(ns, nd)`. The record's
        tape, or the stop's words. `touched`: the question's `cr` holds one read. `patch(tr)`: a planted fault in the
        tracer's own methods. `whole_hook`: the planted fault of the hook set for the whole question."""
        tr = object.__new__(Tracer3)
        tr.Wm, tr.doc_seacast, tr.traced, tr.bare = Wm, True, (), Counter()
        nd = Node()
        nd.id, nd.sim, nd.cfg = 1, Sim(), {}
        st = {"depth": 1, "ext": 0, "cur": {"tape": [], "fn": "x"}, "node": 1, "supp": 0}
        hooked = []

        class Rec:
            def begin_callee(self):
                if whole_hook:          # every timer the question arms, through whatever path, is a note
                    orig = nd.sim.after
                    nd.sim.after = lambda node, d, f, *a: (hooked.append((d, f, a)), orig(node, d, f, *a))[1]

            def end_callee(self):
                if whole_hook:
                    del nd.sim.after
                    st["notes"].extend(tr.note_of(nd, "after", *t) for t in hooked)
                return ([["t", 1]], []) if touched else ([], [])
        if patch is not None:
            patch(tr)
        wrap = functools.partial(tr.iface_of, nd, st, Rec(), (), {}, lambda: None, lambda: None)
        ns = {}

        def after(delay, fn, *args):    # the toy's bindings (node.py's `after` and `start`, and the jittered start)
            nd.sim.after(nd, delay, fn, *args)

        def start(fn, gg):
            nd.sim.after(nd, check_time + 0.125, fn, gg)
        if hasattr(body, "binding"):    # a case's own binding of `after`
            after = body.binding(nd)
        never = lambda r, *a, **k: (_ for _ in ()).throw(AssertionError("a record's own row"))    # noqa: E731
        ns["after"], ns["start"] = wrap("after", after, never), wrap("start", start, never)
        ns["q2"] = wrap("q2", lambda: body(ns, nd), lambda r, *a: [list(a), None])
        q = wrap("q", (lambda p: ns["q2"]()) if getattr(body, "nested", False) else (lambda p: body(ns, nd)),
                 lambda r, *a: [list(a), None])
        try:
            q(7)
        except (SystemExit, TypeError, ValueError, IndexError) as e:
            return f"{type(e).__name__}: {e}"
        return st["cur"]["tape"]

    def row(*timers, touched=False):
        return [["q", [7], None] + call_log([["t", 1]] if touched else [], [], timers)]

    def a_one(ns, nd):
        ns["after"](0.25, docs["retry_offer"], Wm.WantIndex(g, 3))

    def b_two(ns, nd):                  # the second's key sorts before the first's
        ns["after"](0.25, docs["retry_offer"], Wm.WantIndex(g, 5))
        ns["after"](0.75, docs["ask_parked"], Wm.WantIndex(g, 2))

    def c_start(ns, nd):
        ns["start"](docs["decode_group"], g)

    def d_kick(ns, nd):                 # the writer's kick: node.sim.after itself
        nd.sim.after(nd, 0.0, toy["_write"], 3)

    def e_none(ns, nd):
        pass

    def nested(ns, nd):                 # asked by q's callee: q2, which arms the timer
        ns["after"](0.25, docs["retry_offer"], Wm.WantIndex(g, 3))
    nested.nested = True

    def g_alarm(ns, nd):
        ns["after"](0.25, toy["alarm_due"], g, 4, 9, 1.5)

    def g_lambda(ns, nd):
        ns["after"](0.25, lambda: None)

    def h_raise(ns, nd):
        ns["after"](0.25, docs["retry_offer"], Wm.WantIndex(g, 3))
        raise ValueError("the question's own error")

    def i_count(n):                     # an `after` whose binding (its `binding`) schedules n timers
        def body(ns, nd):
            ns["after"](0.25, docs["retry_offer"], Wm.WantIndex(g, 3))

        def binding(nd):
            def after(delay, fn, *args):
                for _ in range(n):
                    nd.sim.after(nd, delay, fn, *args)
            return after
        body.binding = binding
        return body

    def k_inf(ns, nd):                  # a timer with no finite delay: the twin's note reader would refuse its note
        ns["after"](math.inf, docs["retry_offer"], Wm.WantIndex(g, 3))

    def plain_delay(tr):                # the note's delay written as fbits writes any number, +inf's word too
        tr.note_delay = lambda nd, delay: fbits(delay)

    one = ["after", fbits(0.25), "retry_offer", [[gx, 3]]]
    note_c = ["start", fbits(check_time + 0.125), "decode_group", [gx]]
    note_g = ["after", fbits(0.25), "Node._alarm.<locals>.alarm_due", [gx, 4, 9, fbits(1.5)]]
    orig_log = call_log

    def with_log(f):                    # a planted fault in call_log, the module's own function
        def p(tr):
            globals()["call_log"] = f
        return p

    def by_name(tr):                    # a toy callback's target written by its __name__ (the codec as it is)
        orig = tr.note_of

        def note_of(nd, kind, d, t, a):
            n = orig(nd, kind, d, t, a)
            return n[:2] + [t.__name__] + n[3:] if n[2] in TOY_TIMERS else n
        tr.note_of = note_of

    def any_target(tr):
        tr.timer_target = lambda nd, kind, fn: getattr(fn, "__qualname__", "?")

    def check_delay(tr):
        orig = tr.note_of
        tr.note_of = lambda nd, kind, d, t, a: orig(nd, kind, check_time if kind == "start" else d, t, a)

    def keep_last(tr):
        tr.one_timer = lambda nd, kind, seen: seen[-1]

    def per_question(tr):               # notes kept per question: the inner question's own list, dropped
        orig = tr.iface_of

        def iface_of(nd, st, rec, replaced, calls, mesh_on, mesh_off, name, fn, enc):
            w = orig(nd, st, rec, replaced, calls, mesh_on, mesh_off, name, fn, enc)
            if name != "q2":
                return w

            def inner(*a, **k):
                outer, st["notes"] = st["notes"], []
                try:
                    return w(*a, **k)
                finally:
                    st["notes"] = outer
            return inner
        tr.iface_of = iface_of

    def raise_drops(tr):
        tr.raised_with_notes = lambda nd, name, e: None

    # (case, body, its kwargs, what it must give, its planted fault as run() kwargs, whether it expects a note or a
    # stop inside a question)
    cases = [
        ("a, one after", a_one, {}, row(one), dict(patch=with_log(lambda cr, cw, t=(): orig_log(cr, cw, ()))), True),
        ("b, two afters in arming order", b_two, {},
         row(one[:3] + [[[gx, 5]]], ["after", fbits(0.75), "ask_parked", [[gx, 2]]]),
         dict(patch=with_log(lambda cr, cw, t=(): orig_log(cr, cw, sorted(t, key=lambda n: json.dumps(n[3]))))), True),
        ("c, a jittered start", c_start, {}, row(note_c), dict(patch=check_delay), True),
        ("d, the kick: no note", d_kick, {}, row(), dict(whole_hook=True), False),
        ("e, cr and cw alone", e_none, dict(touched=True), row(touched=True),
         dict(touched=True, patch=with_log(lambda cr, cw, t=(): [{"cr": cr, "cw": cw, "timers": list(t)}])), False),
        ("f, a question inside a question", nested, {}, row(one), dict(patch=per_question), True),
        ("g, alarm_due by its qualified name", g_alarm, {}, row(note_g), dict(patch=by_name), True),
        ("g, a lambda target stops", g_lambda, {},
         "SystemExit: trace3: node 1: a timer armed inside a question calls timers_self_test.<locals>.g_lambda.<locals>"
         ".<lambda> (trace3.py:", dict(patch=any_target), True),
        ("h, a raise after arming stops", h_raise, {},
         "SystemExit: trace3: node 1: q raised ValueError after arming a timer", dict(patch=raise_drops), True),
        ("i, an after arming none stops", i_count(0), {},
         "SystemExit: trace3: node 1: an after inside a question armed 0 timers", dict(patch=keep_last), True),
        ("i, an after arming two stops", i_count(2), {},
         "SystemExit: trace3: node 1: an after inside a question armed 2 timers", dict(patch=keep_last), True),
        ("k, an infinite delay stops", k_inf, {},
         "SystemExit: trace3: node 1: a timer armed inside a question has the delay inf, which is no finite number",
         dict(patch=plain_delay), True),
    ]

    def same(got, want):
        if isinstance(want, str) and isinstance(got, str):
            return got.startswith(want)
        return got == want
    bad = 0
    noted = []
    for what, body, kw, want, plant, expects in cases:
        got = run(body, **kw)
        ok = same(got, want)
        bad += not ok
        print(f"timers self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
        try:
            got_p = run(body, **plant)
        finally:
            globals()["call_log"] = orig_log
        ok = not same(got_p, want)
        bad += not ok
        print(f"timers self-test, {what}, its planted fault: {'fails it, ok' if ok else 'passes  <-- FAIL'}; it gives "
              f"{json.dumps(got_p)[:220]}")
        NOTES_OFF[0] = True
        try:
            if not same(run(body, **kw), want):
                noted.append(what)
        finally:
            NOTES_OFF[0] = False
    want_off = [c[0] for c in cases if c[5]]
    ok = noted == want_off
    bad += not ok
    print(f"timers self-test, the control (the notes' code bypassed): "
          f"{f'fails exactly the {len(noted)} cases of a note or a stop, ok' if ok else f'fails {noted}  <-- FAIL'}")
    # j: a record's own `after` of SEACAST's three, each against its row written out by hand from timerSeacastJson's
    # form
    tr = object.__new__(Tracer3)
    tr.Wm, tr.doc_seacast = Wm, True

    def own(fn, *args):
        try:
            return json.dumps(tr.after_row(0.25, fn, *args), separators=(",", ":"))
        except (SystemExit, TypeError) as e:
            return f"{type(e).__name__}: {e}"
    w25 = fbits(0.25)
    jcases = [
        ("reconsider", lambda: own(docs["reconsider"], g, 1.5), f'[{w25},"reconsider",["{gx}",4609434218613702656]]'),
        ("ask_sample", lambda: own(docs["ask_sample"], g, 3), f'[{w25},"ask_sample",["{gx}",3]]'),
        ("resample", lambda: own(docs["resample"], g, 3, 9, True), f'[{w25},"resample",["{gx}",3,9,true]]'),
        ("ask_sample with a third argument stops", lambda: own(docs["ask_sample"], g, 3, True),
         "SystemExit: trace3: ask_sample armed with 3 arguments, where the twin's form has two (g, i)"),
    ]

    def keys_only(name, args):          # the planted fault: seacast-lite.md's codec alone (keys only)
        out = []
        for x in args:
            if not isinstance(x, (bytes, Wm.WantIndex)):
                raise TypeError(f"§6.1 arms timers on keys only, got {x!r}")
            out.append(tr.key(x))
        return out
    for what, f, want in jcases:
        got = f()
        ok = same(got, want)
        bad += not ok
        print(f"timers self-test, j, a record's own after of {what}: "
              f"{'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
        tr.timer_args = keys_only
        try:
            ok = not same(f(), want)
        finally:
            del tr.timer_args
        bad += not ok
        print(f"timers self-test, j, {what}, its planted fault (keys only): "
              f"{'fails it, ok' if ok else 'passes  <-- FAIL'}")
    # --source-offers late, refused under SEACAST alone
    late_words = ("SystemExit: trace3: --source-offers late is the toy's ablation (publish's own offers queued after "
                  "the same instant's pushes), a setting of neither document, whose SOURCE_OFFERS is ACK or PUBLISH: "
                  "not traced under --doc seacast")

    def offers(seacast, mode, plant=False):
        t = object.__new__(Tracer3)
        t.doc_seacast = seacast
        if plant:
            t.source_offers_check = lambda nd: None
        nd = Node()
        nd.id, nd.cfg = 1, {"source_offers": mode}
        try:
            t.source_offers_check(nd)
        except SystemExit as e:
            return f"SystemExit: {e}"
        return None
    modes = ((True, "late"), (True, "on"), (True, "off"), (True, "publish"), (False, "late"))
    ocases = [(f"--source-offers {m} under {'seacast' if seacast else 'seacast-lite.md'}", seacast, m,
               late_words if seacast and m == "late" else None) for seacast, m in modes]
    for what, seacast, m, want in ocases:
        got = offers(seacast, m)
        ok = got == want
        bad += not ok
        print(f"timers self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")
    ok = offers(True, "late", plant=True) != late_words
    bad += not ok
    print(f"timers self-test, --source-offers late under SEACAST, its planted fault (the refusal removed): "
          f"{'fails it, ok' if ok else 'passes  <-- FAIL'}")
    return bad


def questions_self_test():
    """H2: the question writers make the example rows (forms-seacast-examples.tsv, beside this file) byte for byte from
    the rows' own leaves; and with decode's writer planted without its type, its row differs and the case fails."""
    import forms_seacast_examples as X        # noqa: E402: this directory's
    path = HERE / "forms-seacast-examples.tsv"
    want = path.read_text().splitlines()
    leaves = X.leaves_from_tsv(path)

    def made(w=None):
        return [f"{form}\t{row}" for form, row in X.rows(*leaves, w)]

    class NoT(Tracer3):                 # the planted fault: decode's arguments without the type
        def type_enc_seacast(self, T):
            out = super().type_enc_seacast(T)
            dec = out["decode"]
            out["decode"] = lambda r, fr, h: [dec(r, fr, h)[0][1:], dec(r, fr, h)[1]]
            return out
    bad = 0
    got = made()
    ok = got == want
    bad += not ok
    diff = next((f"{a[:100]} / made {b[:100]}" for a, b in zip(want, got) if a != b), f"{len(want)} != {len(got)}")
    print(f"questions self-test, the {len(want)} example rows made by the writers: "
          f"{'ok' if ok else f'differ: {diff}  <-- FAIL'}")
    got_p = made(NoT.__new__(NoT))
    rows_p = [a.split("\t")[0] for a, b in zip(want, got_p) if a != b]
    ok = rows_p == ["decode"]
    bad += not ok
    print(f"questions self-test, its planted fault (decode without its type): "
          f"{'the decode row differs, ok' if ok else f'rows differing: {rows_p}  <-- FAIL'}")
    return bad


def observers_self_test():
    """Class 6 (step3.md, its design point): an observer's own code in the recorder's observer mode, on planted chains
    over two of seacast.md's tables (`stop_pull`, `received`), with no toy node. The document's function is
    compiled as seacast.md's. Its reads and writes are the record's; the observer's reads are in no log, before
    and after the hand-over, and through two observers; a lone document function and a chain with a changing layer
    are not handled; the re-wrap leaves layers_of's chain as it was; outside the mode (as inside a question) the
    layer passes the call through. A write of an observer's own code stops, through a view at once and through a
    bitmap the view handed out at its boundary, with the words naming the node, the layer, the name and the entry.
    Planted faults: the handling off (the observer's read logged), the hand-over off (the document's reads missing,
    its write a stop), the stop off (writes let through), each failing its cases. Through iface_of's wrapper, a timer
    the observer arms stops, and a question it asks runs bare; the control hides the mode from the wrapper, and
    fails both. A question's and a traced name's own call runs bare; their control hides the mode, and must show what
    it then is, the record's question: one row on the tape, and the traced name counted asked; a stop planted before
    that call must not pass for it. Through the simulator's own `after` (sim_guard), a timer the observer arms
    stops, and one the document's function arms after the hand-over reaches the simulator; the guard off and the
    hand-over off each fail theirs. An observer's own call of a second observed name stays in the caller's mode
    through that name's layer and document function: a read there unlogged, a write a stop in the caller's words;
    the hand-over unbound fails both."""
    sys.path.insert(0, str(HERE.parents[2] / "toy"))
    import bits as B                    # noqa: E402: the toy's, beside this repository's documents
    import wire as Wm                   # noqa: E402
    tr = object.__new__(Tracer3)
    tr.Wm, tr.doc_seacast = Wm, True
    ts = {t.name: t for t in tr.schema(None)}
    g = bytes([1]) * 32
    name = "check_completion"
    doc_src = ("def check_completion(g):\n"                 # the document's: a read of received, a write of stop_pull
               "    if received[g].has(0):\n"
               "        stop_pull[g] = True\n")

    def observer(ns, doc, write=None):  # the measurement point's form (node.py's `_seacast`): stop_pull before and after
        def check_completion(g):
            was = ns["stop_pull"][g]
            if write == "view":
                ns["stop_pull"][g] = True
            elif write == "bitmap":
                ns["received"][g].set(5)
            doc(g)
            return was, ns["stop_pull"][g]
        return check_completion

    def outer(ns, inner):               # a second observer over it: a read of received
        def check_completion(g):
            ns["received"][g].has(1)
            return inner(g)
        return check_completion

    def run(make, kind=OBSERVER, mode=True):
        """`make(ns, doc)` the layers over the document's function, in a record (mode: entered by `observe` as
        sec61 does, else the layer called with no mode, as inside a question): the tables the record read and
        wrote, the layers' calls and unlogged reads, layers_of's chain before and after the re-wrap."""
        rec = F.Recorder()
        ns = {"stop_pull": B.DefaultMap(False), "received": B.lazy(B.LazyBits)}
        ns["received"][g].set(0)
        F.install(rec, ns, [ts["stop_pull"], ts["received"]])
        exec(compile(doc_src, SEACAST_FILE, "exec"), ns)
        top = make(ns, ns[name])
        ls = layers_of(name, top)
        lists = {layer_key(f): (name, kind) for f in ls[:-1]}
        ob, obs = rewrap_observers(rec, "stub", name, ls, lambda: None, lambda: None, lists)
        after = layers_of(name, top)
        rec.clear()
        rec.on, rec.tape = True, []
        try:
            if ob is not None and mode:
                observe(rec, ob, top, (g,), {}, lambda: None, lambda: None)
            else:
                top(g)
        finally:
            rec.on = False
        reads, _, writes = rec.footprint()
        return {"read": sorted({e[0] for e in reads}), "wrote": sorted({e[0] for e in writes}),
                "handled": ob is not None, "calls": [o.calls for o in obs], "unlogged": [o.reads for o in obs],
                "chain kept": [id(f) for f in after] == [id(f) for f in ls]}

    bad = 0

    def case(what, f, want):
        nonlocal bad
        try:
            got = f()
        except SystemExit as e:
            got = f"stop: {e}"
        ok = want(got) if callable(want) else got == want
        bad += not ok
        print(f"observers self-test, {what}: {'ok' if ok else f'got {got!r}  <-- FAIL'}")
        return ok

    def fault(what, switch, cases):
        """A planted fault: with `switch` (a module list) off, each of `cases` must fail."""
        nonlocal bad
        switch[0] = False
        try:
            failed = []
            for c in cases:
                try:
                    got = c[1]()
                except SystemExit as e:
                    got = f"stop: {e}"
                failed.append(not (c[2](got) if callable(c[2]) else got == c[2]))
        finally:
            switch[0] = True
        ok = all(failed)
        bad += not ok
        print(f"observers self-test, its planted fault ({what}): "
              f"{'fails its ' + str(len(cases)) + ' cases, ok' if ok else f'passes {failed.count(False)}  <-- FAIL'}")

    def stops(*parts):
        return lambda got: isinstance(got, str) and got.startswith("stop: trace3: node stub: the observer ") \
            and all(p in got for p in parts)

    one = ("one observer: the document's read and write logged, the observer's two reads not",
           lambda: run(observer),
           {"read": ["received"], "wrote": ["stop_pull"], "handled": True, "calls": [1], "unlogged": [2],
            "chain kept": True})
    two = ("two observers: only the document's read and write logged",
           lambda: run(lambda ns, doc: outer(ns, observer(ns, doc))),
           {"read": ["received"], "wrote": ["stop_pull"], "handled": True, "calls": [1, 1], "unlogged": [1, 2],
            "chain kept": True})
    view = ("an observer that writes stop_pull through the view: a stop, its words",
            lambda: run(lambda ns, doc: observer(ns, doc, "view")),
            stops(".observer.<locals>.check_completion (trace3.py:", " over check_completion writes stop_pull[\"",
                  ": an observer changes no table"))
    bitmap = ("an observer that sets a bit of the bitmap the view handed out: a stop at its hand-over, its words",
              lambda: run(lambda ns, doc: observer(ns, doc, "bitmap")),
              stops(" over check_completion changed received[\"", "at its first touch there", "at the boundary"))
    for c in (one, two, view, bitmap):
        case(*c)
    case("a lone document function: not handled, its read and write logged",
         lambda: run(lambda ns, doc: doc),
         {"read": ["received"], "wrote": ["stop_pull"], "handled": False, "calls": [], "unlogged": [],
          "chain kept": True})
    case("a chain with a changing layer: not handled (a question), every read logged",
         lambda: run(observer, kind=CHANGING),
         {"read": ["received", "stop_pull"], "wrote": ["stop_pull"], "handled": False, "calls": [], "unlogged": [],
          "chain kept": True})
    case("the layer called outside the mode (as inside a question): passed through, every read logged",
         lambda: run(observer, mode=False),
         {"read": ["received", "stop_pull"], "wrote": ["stop_pull"], "handled": True, "calls": [0], "unlogged": [0],
          "chain kept": True})
    fault("the handling off: the observer's reads logged", OBSERVE, [one, two])
    fault("the hand-over off: the mode runs on through the document's function", HANDOVER, [one, two])
    fault("the stop off: writes let through", F.OBSERVER_STOP, [view, bitmap])

    def own_iface(kind, hidden=False):
        """An observer's own call of an interface name through iface_of's wrapper, in a record at a stub node 1 (as
        timers_self_test's): `after` (a timer) or a question `q`. Its answer and the record's tape, or the stop.
        `hidden`: the stub recorder's mode not shown to the wrapper (the cases' control)."""
        tr = object.__new__(Tracer3)
        tr.Wm, tr.doc_seacast, tr.traced, tr.bare = Wm, True, (), Counter()
        nd = type("Node", (), {})()
        nd.id, nd.cfg = 1, {}
        st = {"depth": 1, "ext": 0, "cur": {"tape": [], "fn": "x"}, "node": 1, "supp": 0}

        class Rec:
            observer = None if hidden else ObservedLayer("stub", name, "obs (x.py:1)")

            def begin_callee(self):
                pass

            def end_callee(self):
                return [], []
        w = tr.iface_of(nd, st, Rec(), (), {}, lambda: None, lambda: None, kind, lambda *a: "ran",
                        lambda r, *a: [list(a), None])
        return [w(7), st["cur"]["tape"]]
    timer = ("an observer that arms a timer (`after`): a stop, its words",
             lambda: own_iface("after"), stops(" over check_completion arms a timer (after): an observer changes nothing"))
    question = ("an observer that asks a question: run bare, no row on the record's tape",
                lambda: own_iface("q"), ["ran", []])
    for c in (timer, question):
        case(*c)
    failed = []
    for kind, (_, _, want) in (("after", timer), ("q", question)):
        try:
            got = own_iface(kind, hidden=True)
        except SystemExit as e:
            got = f"stop: {e}"
        failed.append(not (want(got) if callable(want) else got == want))
    bad += not all(failed)
    print(f"observers self-test, its control (the mode hidden from iface_of's wrapper): "
          f"{'fails its 2 cases, ok' if all(failed) else f'passes {failed.count(False)}  <-- FAIL'}")

    def recorded(src, make_layers):
        """A record over the two tables, with `src` compiled as seacast.md's and `make_layers(ns, rec)` the top
        layer of check_completion over its layers, entered by `observe`; after it, the record's reads and writes,
        and `make_layers`' own report (its second value), or the stop."""
        rec = F.Recorder()
        ns = {"stop_pull": B.DefaultMap(False), "received": B.lazy(B.LazyBits)}
        ns["received"][g].set(0)
        F.install(rec, ns, [ts["stop_pull"], ts["received"]])
        exec(compile(src, SEACAST_FILE, "exec"), ns)
        top, report = make_layers(ns, rec)
        ls = layers_of(name, top)
        ob, obs = rewrap_observers(rec, "stub", name, ls, lambda: None, lambda: None,
                                   {layer_key(f): (name, OBSERVER) for f in ls[:-1]})
        rec.clear()
        rec.on, rec.tape = True, []
        try:
            if ob is not None:
                observe(rec, ob, top, (g,), {}, lambda: None, lambda: None)
            else:                           # the handling off (a planted fault): the chain called as the record's
                top(g)
        finally:
            rec.on = False
        reads, _, writes = rec.footprint()
        return {"read": sorted({e[0] for e in reads}), "wrote": sorted({e[0] for e in writes}),
                "calls": [o.calls for o in obs], "unlogged": [o.reads for o in obs], **report()}

    def timed(where):
        """The simulator's own `after` guarded (sim_guard, over a stub that counts the timers handed to it): `where`
        "observer", the observer's own code arms a timer by it; "document", the document's function the observer
        hands over to arms one by the namespace's binding of `after` (node.py's form, the simulator's own under it),
        before its write, so that in the observer's mode the guard, not the write, is what stops it."""
        armed = []
        src = doc_src if where != "document" else doc_src.replace("(g):\n", "(g):\n    after(0.0, None)\n", 1)

        def make(ns, rec):
            sim_after = sim_guard(lambda node, delay, fn, *args: armed.append(delay), lambda: rec.observer)
            ns["after"] = lambda delay, fn, *args: sim_after(None, delay, fn, *args)

            def layer(doc):
                def check_completion(g):
                    if where == "observer":
                        sim_after(None, 0.0, None)
                    return doc(g)
                return check_completion
            return layer(ns[name]), lambda: {"armed": len(armed)}
        return recorded(src, make)
    sim_timer = ("an observer that arms a timer by the simulator's after: a stop, its words",
                 lambda: timed("observer"),
                 stops(" over check_completion arms a timer (sim.after): an observer changes nothing"))
    doc_timer = ("an observer hands over to a document function that arms a timer by the namespace's after: no stop, "
                 "the timer reaches the simulator",
                 lambda: timed("document"),
                 {"read": ["received"], "wrote": ["stop_pull"], "calls": [1], "unlogged": [0], "armed": 1})
    for c in (sim_timer, doc_timer):
        case(*c)
    fault("the simulator's guard off: the observer's timer let through", SIMGUARD, [sim_timer])
    fault("the hand-over off: the document's timer is armed in the observer's mode, and the guard stops it", HANDOVER,
          [doc_timer])

    def bound(write):
        """An observer over check_completion whose own code calls a second observed name, fill, bare (as sec61's
        wrapper runs a traced name in the mode): fill's one observer layer over its document function, which reads
        stop_pull, and with `write` also sets a bit of received. Bound, the mode stays the caller's through fill's
        layer and its document function: fill's read unlogged and counted as the caller's, its write a stop."""
        src = doc_src + "def fill(g):\n    stop_pull[g]\n" + ("    received[g].set(7)\n" if write else "")

        def make(ns, rec):
            def fill_layer(doc):
                def fill(g):
                    return doc(g)
                return fill
            ftop = fill_layer(ns["fill"])
            fls = layers_of("fill", ftop)
            _, fobs = rewrap_observers(rec, "stub", "fill", fls, lambda: None, lambda: None,
                                       {layer_key(f): ("fill", OBSERVER) for f in fls[:-1]})

            def layer(doc):
                def check_completion(g):
                    ftop(g)
                    return doc(g)
                return check_completion
            return layer(ns[name]), lambda: {"fill's calls": [o.calls for o in fobs]}
        return recorded(src, make)
    reads_bound = ("an observer's own call of another observed name: its document function's read in the caller's "
                   "mode, unlogged",
                   lambda: bound(False),
                   {"read": ["received"], "wrote": ["stop_pull"], "calls": [1], "unlogged": [1], "fill's calls": [0]})
    writes_bound = ("an observer's own call of another observed name whose document function writes: a stop, the "
                    "caller's words",
                    lambda: bound(True),
                    stops(" over check_completion changed received[\"", ": an observer changes no table"))
    for c in (reads_bound, writes_bound):
        case(*c)
    fault("the hand-over unbound: the other name's hand-over ends the caller's mode", HANDOVER_BOUND,
          [reads_bound, writes_bound])

    def bare(kind, write):
        """The scan's follow (scan_bindings.py): an observer's own call, bare in its mode, of what the scan now
        follows instead of refusing: `kind` "question", a toy's binding of a question (iface_of runs one bare inside
        an observer); "traced", a traced name's document function with no layer at this node (sec61's wrapper runs
        it bare there). The callee reads stop_pull, and with `write` writes it through the view: its read unlogged,
        the record's log the document function's alone; its write a stop in the observer's words, which is what
        stops a trace where the scan's follow passed a callee that writes."""
        body = "    x = stop_pull[g]\n" + ("    stop_pull[g] = True\n" if write else "") + "    return x\n"
        src = doc_src + "def probe(g):\n" + body

        def make(ns, rec):
            def q(g):
                x = ns["stop_pull"][g]
                if write:
                    ns["stop_pull"][g] = True
                return x
            callee = ns["probe"] if kind == "traced" else q

            def layer(doc):
                def check_completion(g):
                    callee(g)
                    return doc(g)
                return check_completion
            return layer(ns[name]), lambda: {}
        return recorded(src, make)
    bare_cases = []
    for kind, what in (("question", "a question"), ("traced", "a traced function")):
        bare_cases.append((f"an observer's own bare call of {what} that only reads: unlogged, the record's log the "
                           f"document function's", lambda kind=kind: bare(kind, False),
                           {"read": ["received"], "wrote": ["stop_pull"], "calls": [1], "unlogged": [1]}))
        bare_cases.append((f"an observer's own bare call of {what} that writes through the view: a stop, the "
                           f"observer's words", lambda kind=kind: bare(kind, True),
                           stops(" over check_completion writes stop_pull[\"", ": an observer changes no table")))
    for c in bare_cases:
        case(*c)
    fault("the stop off: the bare calls' writes let through", F.OBSERVER_STOP, bare_cases[1::2])
    fault("the handling off: the bare calls' reads logged", OBSERVE, bare_cases[0::2])
    # the handling off, read by the logged read itself and not by the counters: the callee's read of stop_pull is the
    # record's
    not_logged = 0
    OBSERVE[0] = False
    try:
        for c in bare_cases[0::2]:
            got = c[1]()
            not_logged += not (isinstance(got, dict) and got["read"] == ["received", "stop_pull"])
    finally:
        OBSERVE[0] = True
    bad += not_logged
    print(f"observers self-test, its planted fault (the handling off), by the logged read: "
          f"{'the callee read of stop_pull logged in its 2 cases, ok' if not not_logged else 'not logged  <-- FAIL'}")

    def through_iface(kind, hidden=False, stop_first=False):
        """An observer's own call, through iface_of's wrapper as the node wraps a toy's binding of a question, of `kind`
        "question" (a question, not traced) or "traced" (a traced name, which the wrapper counts), in a record entered
        by `observe`. The callee reads stop_pull. Its answer, the open record's tape, the wrapper's counts (its
        "observer" bucket, tr.bare) and the record's reads and writes, with the observer's calls and unlogged reads.
        `hidden`: the mode hidden from the wrapper (the control), which then takes the call for the record's
        question. `stop_first`: the control's planted fault, a stop before the call."""
        tr = object.__new__(Tracer3)
        tr.Wm, tr.doc_seacast, tr.bare, tr.calls = Wm, True, Counter(), {}
        tr.traced = ("probe_q",) if kind == "traced" else ()
        nd = type("Node", (), {})()
        nd.id, nd.cfg = 1, {}
        st = {"depth": 1, "ext": 0, "cur": {"tape": [], "fn": "x"}, "node": 1, "supp": 0}
        answers = []

        class Hidden:                   # the record, its observer not shown
            observer = None

            def __init__(self, r):
                self.r = r

            def __getattr__(self, a):
                return getattr(self.r, a)

        def make(ns, rec):
            def q(g):
                return ns["stop_pull"][g]
            w = tr.iface_of(nd, st, Hidden(rec) if hidden else rec, (), {}, lambda: None, lambda: None, "probe_q", q,
                            lambda r, *a: [list(a), None])

            def layer(doc):
                def check_completion(g):
                    if stop_first:
                        raise SystemExit("planted: a stop before the observer's call")
                    answers.append(w(g))
                    return doc(g)
                return check_completion
            return layer(ns[name]), lambda: {
                "answer": answers, "tape": len(st["cur"]["tape"]), "bare": sum(tr.bare.values()),
                "counted": {b: n for b, n in tr.calls.get("probe_q", tr.zero_calls()).items() if n}}
        return recorded(doc_src, make)
    iface_cases = [
        ("an observer's own call of a question through iface_of's wrapper: bare, its read unlogged, no tape row",
         lambda: through_iface("question"),
         {"read": ["received"], "wrote": ["stop_pull"], "calls": [1], "unlogged": [1], "answer": [False], "tape": 0,
          "bare": 0, "counted": {}}),
        ("an observer's own call of a traced name through iface_of's wrapper: the same, counted in its observer bucket",
         lambda: through_iface("traced"),
         {"read": ["received"], "wrote": ["stop_pull"], "calls": [1], "unlogged": [1], "answer": [False], "tape": 0,
          "bare": 0, "counted": {"observer": 1}}),
    ]
    for c in iface_cases:
        case(*c)
    def hidden_outcome(kind, got):
        """The mode hidden from the wrapper, as it must show: the call taken for the record's question, one row on the
        tape, and a traced name counted "asked" once for the record's function (x), a question counted nowhere."""
        return (isinstance(got, dict) and got.get("tape") == 1
                and got.get("counted") == ({"asked": {"x": 1}} if kind == "traced" else {}))

    def hidden_runs(stop_first):
        shown = []
        for kind in ("question", "traced"):
            try:
                got = through_iface(kind, hidden=True, stop_first=stop_first)
            except SystemExit as e:
                got = f"stop: {e}"
            shown.append(hidden_outcome(kind, got))
        return shown
    shown = hidden_runs(False)
    bad += not all(shown)
    said = ("one tape row in its 2 cases, the traced name counted asked, ok" if all(shown)
            else f"not so in {shown.count(False)}  <-- FAIL")
    print(f"observers self-test, its control for iface_of's wrapper (the mode hidden from it): {said}")
    planted = hidden_runs(True)
    bad += any(planted)
    said = ("not taken for the hidden outcome in its 2 cases, ok" if not any(planted)
            else f"taken in {planted.count(True)}  <-- FAIL")
    print(f"observers self-test, the control's planted fault (a stop before the hidden call): {said}")
    return bad


def orders_self_test():
    """R9 (step3.md's R9-2 to R9-5, R9-7 and R9-8): the order proxy and its writer, with a stub record and no toy
    node, each case beside its planted fault. One entry per iteration, an empty set's too (R9-2); a membership
    test, `len` and truth write nothing (R9-3); nothing inside a question, with no record open, or with the order
    off, and a stop at a place the twin does not ask (R9-4); the place is the frame that creates the iterator,
    `any(... for q in s)` included (R9-5); `standing[g].pop(i, ())` hands out a proxy of the popped set, or of the
    empty default (R9-7); and a set of asks listed by its members' encoded keys, whatever their insertion order
    (R9-8). A planted fault that raises fails its case too."""
    sys.path.insert(0, str(HERE.parents[2] / "toy"))
    import wire as Wm                   # noqa: E402: the toy's, beside this repository's documents
    tr = object.__new__(Tracer3)
    tr.Wm, tr.doc_seacast = Wm, True
    ts = {t.name: t for t in tr.schema(None)}
    g1, g2 = bytes([1]) * 32, bytes([2]) * 32
    sid = g1 + (3).to_bytes(4, "little") + bytes(20)        # a structured id of g1's chunk 3: 56 bytes

    class Rec:                          # a stub recorder: on, no callee's log open
        on, callee = True, None

    def state(ext=0, cur=True):
        return {"cur": {"tape": []} if cur else None, "ext": ext, "supp": 0}

    def writer(st, rec=None, on=True):
        return order_writer(rec or Rec(), st, lambda: on, "stub")

    def tape(st):
        return st["cur"]["tape"]

    # seacast.md's places by name, each iterating its set as the document does
    def fill(s):
        return [q for q in s]

    def serve_standing(s):
        return [q for q in s]

    def known_across(s, holder):
        return any(q == holder for q in s)

    def check_completion(s):
        return (9 in s, len(s), bool(s))

    def rebuild(s):                     # a toy function's name: none of the nine
        return [q for q in s]

    bad = 0

    def case(what, got, want):
        nonlocal bad
        ok = got == want
        bad += not ok
        print(f"orders self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")

    def fault(what, f):
        nonlocal bad
        try:
            failed = f()
        except (SystemExit, Exception):
            failed = True
        bad += not failed
        print(f"orders self-test, its planted fault ({what}): {'fails it, ok' if failed else 'NOT failed  <-- FAIL'}")

    s = {9, 16}
    # R9-2
    st = state()
    fill(OrderProxy(s, writer(st)))
    case("an iteration at fill: one entry, in the set's own order", tape(st), [["order", "fill", list(s)]])
    st = state()
    fill(OrderProxy(set(), writer(st)))
    case("an empty set at fill: one entry, empty", tape(st), [["order", "fill", []]])
    st = state()
    fill(OrderProxy({9}, writer(st)) | {16})
    case("the union with the sender's ack: one entry, in the union's own order", tape(st),
         [["order", "fill", list({9} | {16})]])

    def nonempty(st):
        w = writer(st)
        return lambda place, ms: w(place, ms) if ms else None

    def p2():
        st = state()
        fill(OrderProxy(set(), nonempty(st)))
        return tape(st) != [["order", "fill", []]]
    fault("entries only for non-empty sets", p2)
    # R9-3
    st = state()
    r = check_completion(OrderProxy(s, writer(st)))
    case("a membership test, len and truth: nothing on the tape", (tape(st), r), ([], (True, 2, True)))

    class IterContains(OrderProxy):     # the planted fault: a membership test that iterates
        __slots__ = ()

        def __contains__(self, q):
            self.note("check_completion", list(self.s))
            return q in self.s

    def p3():
        st = state()
        check_completion(IterContains(s, writer(st)))
        return tape(st) != []
    fault("a membership test that iterates", p3)
    # R9-4
    st = state(ext=1)
    fill(OrderProxy(s, writer(st)))
    case("an iteration inside a question: nothing on the tape", tape(st), [])
    st = state(cur=False)
    case("an iteration with no record open: nothing, and the set's members", fill(OrderProxy({9}, writer(st))), [9])
    st = state()
    fill(OrderProxy(s, writer(st, on=False)))
    case("an iteration with the order off (TRACE3_ORDER=off): nothing on the tape", tape(st), [])
    try:
        rebuild(OrderProxy({9}, writer(state())))
        got = "no stop"
    except SystemExit as e:
        got = "stopped" if "at none of its places" in str(e) else str(e)
    case("an iteration in a function that is none of the nine places: the tracer stops", got, "stopped")

    def anydepth(st):
        return lambda place, ms: tape(st).append(["order", place, [int(q) for q in ms]])

    def p4():
        st = state(ext=1)
        fill(OrderProxy(s, anydepth(st)))
        return tape(st) != []
    fault("a writer that writes whatever the depth", p4)
    # R9-5
    st = state()
    known_across(OrderProxy(s, writer(st)), 16)
    case("any(... for q in s) in known_across: the place is known_across", tape(st),
         [["order", "known_across", list(s)]])

    class Advancing(OrderProxy):        # the planted fault: the place of the frame that advances the iterator
        __slots__ = ()

        def __iter__(self):
            def gen():
                order = list(self.s)
                self.note(sys._getframe(1).f_code.co_name, order)
                yield from order
            return gen()

    def p5():
        st = state()
        known_across(Advancing(s, writer(st)), 16)
        return tape(st) != [["order", "known_across", list(s)]]
    fault("the place of the frame that advances the iterator", p5)
    # R9-7
    def standing(pop_view):
        rec, st = F.Recorder(), state()
        ns = {"standing": {g1: {3: {5, 2}}}}
        F.install(rec, ns, [ts["standing"]])
        rec.on, rec.tape = True, []
        if pop_view:
            ns["standing"] = OrderPopView(ns["standing"], writer(st, rec))
        a = serve_standing(ns["standing"][g1].pop(3, ()))
        b = serve_standing(ns["standing"][g1].pop(4, ()))
        return tape(st), a, b
    case("standing[g].pop(i, ()) at serve_standing, held and missing: an entry each, the second empty",
         standing(True), ([["order", "serve_standing", list({5, 2})], ["order", "serve_standing", []]],
                          list({5, 2}), []))
    fault("the pop view handing out the raw set", lambda: standing(False)[0] != [
        ["order", "serve_standing", list({5, 2})], ["order", "serve_standing", []]])
    # R9-8
    a1, a2 = Wm.WantIndex(g1, 3), Wm.WantIndex(g2, 4)

    def snap(order):
        rec, raw = F.Recorder(), set()
        for x in order:
            raw.add(x)
        F.install(rec, {"probe_asks": raw}, [ts["probe_asks"]])
        return list(rec.snapshot())
    was = F.SET_ORDER_ENCODED[0]
    try:
        F.SET_ORDER_ENCODED[0] = True
        one, two = snap([a1, a2, sid]), snap([sid, a2, a1])
        case("probe_asks with two asks by index and a structured id, inserted in two orders: one listing, by "
             "encoded key", (one == two, len(one), one == sorted(one)), (True, 3, True))
        F.SET_ORDER_ENCODED[0] = False
        fault("the members sorted by their raw values", lambda: snap([a1, a2, sid]) is None)
    finally:
        F.SET_ORDER_ENCODED[0] = was
    return bad


def close_self_test():
    """Tracer3.close on a stand-in tracer (no toy), its output in a temporary directory: the files beside the trace
    are written before the trailer; a failure there, or in a check at the close, gives the trailer a `stopped` that
    keeps a reason given; the output is closed and the failure raised again. Each case: the trailer's `stopped`, what
    the close raised, which files beside the trace stood when the trailer was written, and which stand after."""
    import tempfile
    bad = 0

    def run(path, given=None, bare_dir=False, calls_fail=False, check_fail=False):
        tr = object.__new__(Tracer3)
        tr.out_path, tr.out = path, gzip.open(path, "wt")
        tr.nodes_written, tr.doc_seacast, tr.counts, tr.rest_total, tr.bare = True, True, Counter({"f": 2}), 0, Counter()
        seen = []

        def final_check():
            if check_fail:
                raise SystemExit("trace3: a planted check")

        def write_calls():
            if calls_fail:
                raise OSError("a planted failure")
            with open(path + ".calls.json", "w") as f:
                f.write("{}\n")

        def write(rec):
            seen.append([x for x in ("bare.json", "calls.json") if os.path.isfile(f"{path}.{x}")])
            Tracer.write(tr, rec)
        tr.final_check, tr.loaded_check, tr.write_calls, tr.write = final_check, lambda: None, write_calls, write
        if bare_dir:
            os.mkdir(path + ".bare.json")
        raised = None
        try:
            tr.close(stopped=given)
        except BaseException as e:
            raised = f"{type(e).__name__}: {e}"
        try:
            with gzip.open(path, "rt") as f:
                stopped = json.loads(f.readlines()[-1])["trailer"].get("stopped")
        except Exception as e:                  # the output not closed, or no trailer
            stopped = f"the output not readable to a trailer: {type(e).__name__}"
        return (stopped, raised, seen, [x for x in ("bare.json", "calls.json") if os.path.isfile(f"{path}.{x}")])

    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "{}.jsonl.gz").format
        isdir = f"IsADirectoryError: [Errno 21] Is a directory: '{p('b')}.bare.json'"
        planted = "OSError: a planted failure"
        check = "SystemExit: trace3: a planted check"
        for what, got, want in (
                ("a, the whole close: no stopped, both files written before the trailer",
                 run(p("a")), (None, None, [["bare.json", "calls.json"]], ["bare.json", "calls.json"])),
                ("b, .bare.json's path a directory: stopped with the error, no calls file, raised",
                 run(p("b"), bare_dir=True), (isdir, isdir, [[]], [])),
                ("c, the calls file's write failing: stopped with it, .bare.json written, raised",
                 run(p("c"), calls_fail=True), (planted, planted, [["bare.json"]], ["bare.json"])),
                ("d, the stop path with c's failure: the first reason stays, c's failure raised",
                 run(p("d"), given="SystemExit: the first stop", calls_fail=True),
                 ("SystemExit: the first stop", planted, [["bare.json"]], ["bare.json"])),
                ("e, final_check failing: stopped with it, no file beside the trace, raised",
                 run(p("e"), check_fail=True), (check, check, [[]], []))):
            ok = got == want
            bad += not ok
            print(f"close self-test, {what}: {'ok' if ok else f'got {got}, must be {want}  <-- FAIL'}")
    return bad


def self_test_seacast():
    bad = (seacast_kept_self_test() + forms_self_test() + views_self_test() + manifest_self_test() + chains_self_test()
           + closure_self_test() + timers_self_test() + questions_self_test() + orders_self_test()
           + observers_self_test() + close_self_test())
    print("ok: every case as it must be" if not bad else f"{bad} cases wrong")
    return 1 if bad else 0


class Tracer3(Tracer):
    def __init__(self, toy, out, argv, whole=False, cli=False):     # not Tracer's: the header differs
        self.whole = whole
        self.only61 = os.environ.get("TRACE3_ONLY") == "sec61"     # §6.1's twelve alone: the baseline's records
        self.order_on = os.environ.get("TRACE3_ORDER") != "off"     # SEACAST's order entries; off for the cost measure
        self.toy = Path(toy).resolve()
        self.start_check(out)           # before the toy is imported
        sys.path.insert(0, str(toy))
        import node as N                # noqa: E402: the pinned toy, from TOYDIR
        import wire as Wm               # noqa: E402
        self.N, self.Wm = N, Wm
        F.ATTR_LEVELS[N.PeerQueue] = ("urgent", "normal")    # a PeerQueue's lanes are its keys
        F.ATTR_READS[N.PeerQueue] = {"has_chunks": ("normal",)}  # next_to_send's `q.has_chunks()`
        # the content line first: what this trace is made from (content.py); written when the output opens, after
        # every check here, so that a run these checks refuse leaves no file. A refusal later, by the toy's own
        # argument checks or at the install, leaves a file whose trailer says the run stopped (close), with 0 records
        # or more, which every reader takes as stopped
        self.content_line = content.line(content.content(self.toy))
        self.counts = Counter()
        self.nodes = []                 # (node, its constants, its replaced names, its types, its chains), as each is
        #                                 installed (the nodes line; types and chains None under seacast-lite.md)
        self.nodes_written = False
        self.bound = []                 # (node, namespace, {traced name: the tracer's wrapper of it there}), for the
        #                                   names' second check (final_check)
        self.type_slots = []            # under SEACAST, (node, a type or its params, attribute, the tracer's question
        #                                   there), for final_check too
        self.type_nodes = []            # under SEACAST, (node, namespace, its types as the install read them), for
        #                                   final_check: the nodes line holds the install's parameters
        self.observers = []             # under SEACAST, every handled observer layer at each node (class 6), its counts
        self.doc_mid = {}               # and m2_check's reference function, a node's own
        self.cur_nid = None             # the node of the record being written (mid_of's reference)
        self.built_objs = {}            # the chunks the record's publish built (built, content_id_asked)
        self.rest_total = 0
        self.doc_message_id = None      # the document's message_id: the tracer's own way to a chunk's id,
        #                                   untraced, storing nothing on the chunk
        # what is traced: §6.1's twelve alone (TRACE3_ONLY=sec61); under --doc seacast, the block's names that are
        # seacast-lite.md's all the way down; otherwise the block
        self.doc_seacast = doc_of(argv) == "seacast"
        F.SET_ORDER_ENCODED[0] = self.doc_seacast    # under SEACAST a set's members are listed by their encoded key
        # under SEACAST, one tracer-wide state of the record and question depth: inside any question, every traced
        # function at every node runs bare, and so does everything inside a replaced name entered outside any
        # record; the calls run bare at another node than the record's, and inside such an entry, are counted, by
        # node and function, in a file beside the trace (OUT.bare.json), not in the trace. Under seacast-lite.md each
        # node keeps its own state, as before
        self.vst = {"depth": 0, "ext": 0, "cur": None, "node": None, "supp": 0} if self.doc_seacast else None
        self.rec_of = {}    # under SEACAST, each node's recorder, by node: the open record's observer mode (sim_guard)
        self.bare = Counter()
        # under SEACAST, every call of a traced name, by where it ran (count_call), the IWANTs that IW_NAMES' calls enqueue
        # (count_iwants), and how often one of IW_NAMES runs inside another: a file beside the trace (OUT.calls.json),
        # not in it, since a record's `reached` names a function once, however often it ran
        self.calls, self.iw, self.inside, self.open_iw = {}, {}, {}, []
        # under SEACAST, the toy's functions a namespace may hold: those the scan of its bindings names (scan_bindings.py),
        # by file, first line and qualified name; checked at each install (unscanned_check)
        self.scanned, self.aliases = None, None     # by slot: the functions the scan binds there, and the slots
        if self.doc_seacast:                             #   it holds the value of (chunk_id = ns["message_id"])
            import scan_bindings                # noqa: E402: this directory's
            self.scanned, self.aliases = {}, {}
            for r in scan_bindings.scan(self.toy).rows:
                if isinstance(r["value"], dict):
                    self.scanned.setdefault(r["name"], set()).add(
                        (r["value"]["file"], r["value"]["line"], r["value"]["qual"]))
                if r.get("alias_of"):
                    self.aliases.setdefault(r["name"], set()).add(r["alias_of"])
        # the toy's command line (cli: this script's own main) is read as the toy's parser reads it (toy_args); a
        # directed set's arguments are no command line of the toy's, and are read by their words
        if (toy_reads_a_dump(argv) if cli else any(a.split("=")[0] in ("--xcheck", "--topology") for a in argv)):
            # --topology reads a dump, an input the content line does not name; and the toy's cross-check recorder
            # keeps `max(peak, ns["in_flight"])`, which hands out the count's cell
            raise SystemExit("trace3: --xcheck and --topology are not traced: a dump is an input the content line "
                             "does not name, and the toy's recorder there keeps the window's count, which is a cell "
                             "of the tracer's here")
        if cli and doc_parsed(argv) != (doc_of(argv) if doc_of(argv) == "seacast" else None):
            raise SystemExit("trace3: the document is given in a form whose words do not name what the toy runs: give "
                             "it as --doc seacast or --doc=seacast, so that the trace's header names it")
        self.seacast_defs = ({d.name for d in ast.parse(N.generate(N.DOC2)).body if isinstance(d, ast.FunctionDef)}
                        if self.doc_seacast else set())
        if self.only61:
            self.traced = SEC61
        elif self.doc_seacast:
            # (under SEACAST the window's count is bytes and a send's value a pair, and the three tables are not
            # installed: the six are not traced there, by name); and SEACAST's covered names, its own functions
            self.kept = tuple(n for n in seacast_kept(BLOCK, N.SPEC_SRC, N.generate(N.DOC2)) if n not in SEC71)
            self.traced = self.kept + tuple(n for n in manifest_seacast.COVERED if n not in self.kept)
        else:
            self.traced = BLOCK
        if not self.doc_seacast or self.only61:
            self.kept = self.traced
        for d in (N.DOC, N.DOC2):       # the documents the toy reads are the two the content line names
            if Path(d).resolve() != self.toy.parent / Path(d).name:
                raise SystemExit(f"trace3: the toy reads a document that is not beside it: {d}")
        if self.doc_seacast:                 # §3's tables against the lists the views are made from (sec3_check)
            doc2 = Path(N.DOC2).read_text()
            off = sec3_check(sec3_names(doc2), keys=sec3_keys(doc2))
            if off:
                raise SystemExit("trace3: seacast.md's §3 and the tables' lists differ: " + "; ".join(off))
            off = manifest_check(None if self.only61 else self.traced)  # the lists the replay reads a SEACAST trace by
            if off:
                raise SystemExit("trace3: the tracer's lists and seacast.md's manifest differ: " + "; ".join(off))
            # the closure rule over COVERED, the call closure over COVERED and KEPT, the type's functions and the
            # context's uses (closure_seacast.py); their counts on stderr, nothing in the trace
            off, lines = closure_seacast.check(closure_seacast.Reading(N.SPEC_SRC, N.generate(N.DOC2)), manifest_seacast,
                                          self.params_schema(), self.TYPE_FUNCTIONS)
            if off:
                raise SystemExit("trace3: seacast.md's code and the closure rule: " + "; ".join(off))
            for ln in lines:
                print(ln, file=sys.stderr)
        # under SEACAST the header's tables are the manifest's, which manifest_check has just held to the tracer's own
        hd = {"format": 7, "whole": whole,
              "own": list(manifest_seacast.OWN) if self.doc_seacast else list(OWN),
              "foreign": list(manifest_seacast.FOREIGN) if self.doc_seacast else list(FOREIGN)}
        if self.doc_seacast:
            hd["row_reads"] = list(ROW_READS_Seacast)
        hd.update({"traced": sorted(self.traced), "tracer": "trace3.py", "args": argv})
        self.out = gzip.open(out, "wt", compresslevel=1)
        self.out_path = str(out)
        self.out.write(self.content_line)
        self.write({"header": hd})

    def write_nodes(self):
        """The nodes line: every node the tracer was installed at, by what the replay needs of it: its
        constants, and the traced names its namespace has replaced (a question there); under SEACAST its types and
        chains too. One entry per distinct tuple (`group_nodes`), in the order of its first node, with the nodes that
        have it. Written once, before the first record; a trace with no record has it before its trailer."""
        self.final_check()
        self.write({"nodes": group_nodes(self.nodes)})
        self.nodes_written = True

    def close(self, stopped=None):
        """The files beside the trace, then the trailer, last. `stopped`: the reason a run stopped, which the trailer
        then carries, so that no reader takes the trace for a whole run's. A failure before the trailer (a check
        here, or a file beside the trace not written) stops the run too: the trailer carries it, unless a reason was
        given, which then stays, and it is raised again once the trailer is written and the output closed."""
        failed = None
        try:
            if not self.nodes_written:
                self.write_nodes()
            else:                       # the traced names once more at the end: a name bound again after the first
                self.final_check()      #   record is seen too
            self.loaded_check()
            if self.doc_seacast:        # the calls run bare at another node, or inside a replaced name entered outside
                with open(self.out_path + ".bare.json", "w") as f:  # any record: a run output beside the trace
                    json.dump(dict(sorted(self.bare.items())), f, sort_keys=True)
                    f.write("\n")
                self.write_calls()
        except BaseException as e:
            failed = e
            if stopped is None:
                stopped = (f"{type(e).__name__}: {e}".splitlines() or [""])[0]
        trailer = {"records": sum(self.counts.values()), "by_fn": dict(sorted(self.counts.items())),
                   "rest": self.rest_total}
        if stopped is not None:
            trailer["stopped"] = stopped
        self.write({"trailer": trailer})
        self.out.close()
        if failed is not None:
            raise failed

    def start_check(self, out):
        """What must hold of this Python before the toy is imported, so that what runs is what the content line
        names. It runs isolated (-I: no PYTHONPATH, no user site, no directory of its own on the path), not
        optimised (-O would take out the tracer's own checks), writes no bytecode (-B), and looks for bytecode
        under a prefix (-X pycache_prefix=DIR) that holds no file: a bytecode file beside a source is then never
        read in the source's place. The output lies outside the toy and the tools, or the line would name it."""
        if not sys.flags.isolated:
            raise SystemExit("trace3: Python does not run isolated (-I): PYTHONPATH could put another module "
                             "in place of one the content line names")
        if sys.flags.optimize:
            raise SystemExit("trace3: Python runs optimised (-O): the tracer's own checks would not run")
        if not sys.dont_write_bytecode:
            raise SystemExit("trace3: Python writes bytecode (run it with -B)")
        self.prefix_check()
        outp = Path(out).resolve()
        if self.toy in outp.parents or HERE in outp.parents:
            raise SystemExit(f"trace3: the output lies under the toy or the tools, which the content line names: {outp}")

    @staticmethod
    def prefix_check():
        pre = sys.pycache_prefix
        if not pre:
            raise SystemExit("trace3: Python has no bytecode prefix (-X pycache_prefix=DIR, an empty directory): "
                             "a bytecode file beside a source could be read in the source's place")
        for _root, _dirs, files in os.walk(pre):
            if files:
                raise SystemExit(f"trace3: the bytecode prefix holds a file: {pre}")

    def loaded_check(self):
        """At the trace's end, what ran is what the content line names: the line made again is the same line (no
        file changed under the run); the bytecode prefix still holds no file; and every module this process loaded
        from a file is a source the line names, or the standard library's. A module from anywhere else (a
        site directory, a path put before the toy's) stops the tracer here."""
        if content.line(content.content(self.toy)) != self.content_line:
            raise SystemExit("trace3: a file the content line names changed while the trace was made")
        self.prefix_check()
        names = set(json.loads(self.content_line)["content"]["files"])
        std = Path(os.__file__).resolve().parent
        for name, m in sorted(sys.modules.items()):
            f = getattr(m, "__file__", None)
            if f is None:               # built in
                continue
            where = Path(f).resolve()
            if self.toy in where.parents:
                key = "toy/" + where.relative_to(self.toy).as_posix()
            elif HERE in where.parents:
                key = content.TOOLS + "/" + where.relative_to(HERE).as_posix()
            elif std in where.parents and "site-packages" not in where.parts and "dist-packages" not in where.parts:
                continue                # the standard library's
            else:
                raise SystemExit(f"trace3: module {name} was loaded from {f}, which is neither the toy's, the "
                                 f"tools' nor the standard library's")
            if key not in names or where.suffix != ".py":
                raise SystemExit(f"trace3: module {name} was loaded from {f}, which the content line does not name "
                                 f"as a source")
            # the program itself (__main__) is run from its source, never from bytecode
            if name != "__main__" and type(getattr(m, "__loader__", None)).__name__ != "SourceFileLoader":
                raise SystemExit(f"trace3: module {name} was not loaded from its source: {f}")
    def account(self, rec, r, before):
        """The log against the state itself (a trace of the whole state): `before` is the own tables as they were
        when the call began, read from the containers."""
        def k(e):
            return (e[0], json.dumps(e[1]))
        said = {k(e): e[2] for e in r["reads"] if e[2] is not None}
        said.update({k(e): e[2] for e in r["rest"]})
        if said != before:
            d = sorted(x for x in set(said) | set(before) if said.get(x) != before.get(x))[:4]
            raise SystemExit(f"trace3: the views' log does not account for the state before {r['fn']}{r['args']} "
                             f"at node {r['n']}: reads and rest differ from the tables at {d}")
        want = dict(before)
        for e in r["writes"]:
            if e[2] is None:
                want.pop(k(e), None)
            else:
                want[k(e)] = e[2]
        after = rec.snapshot()
        if after != want:
            d = sorted(x for x in set(after) | set(want) if after.get(x) != want.get(x))[:4]
            raise SystemExit(f"trace3: the views' log does not account for the state after {r['fn']}{r['args']} "
                             f"at node {r['n']}: the tables differ from reads, rest and writes at {d}")

    # ---- §4.4's arguments and results (the twelve of §6.1: trace61.py)
    def ihave_entry(self, e):
        """An entry of an IHAVE: a full id as a key is written, or ["bits", group, bitmap]."""
        if self.Wm.is_have_bitmap(e):
            return ["bits", e.group.hex(), e.bits.v]
        if isinstance(e, bytes):
            return e.hex()
        raise TypeError(f"not an IHAVE's entry: {e!r}")

    def chunk(self, f):
        """A chunk as the twin reads it: [group, index, slot, root, id], the id as the toy computes it once per chunk
        (toy/node.py's message_id), so the twin never computes one."""
        return [f.group.hex(), int(f.index), int(f.slot), f.beacon_block_root.hex(), self.mid_of(f).hex()]

    def admitted_arg(self, x):
        """What admitted(p, x) is asked of (seacast-lite.md §8): the group a chunk, a HAVE or an offered id names. A HAVE
        is written as an IHAVE's bitmap, ["bits", group, bitmap]; an offered id (what expand yields: a full id, or a
        WantIndex) as an ask key; a chunk as the twin reads it. The four shapes differ: a list of three whose first
        member is "bits", a string or a list of two, and a list of five."""
        if self.Wm.is_have_bitmap(x):
            return self.ihave_entry(x)
        if isinstance(x, (bytes, self.Wm.WantIndex)):
            return self.key(x)
        if all(hasattr(x, k) for k in ("group", "index", "slot", "beacon_block_root")):
            return self.chunk(x)
        raise TypeError(f"not an argument of admitted: {x!r}")

    def wchunk(self, f):
        """A chunk where it arrives or waits: the chunk, and what level 1 reads of it, [descriptor, the proof's
        digests, the data as a blob]. A chunk object without all three (a directed set's, whose level 1 is its
        scenario's: §4.2's sets give a chunk its descriptor alone, for open_group) is written narrow. The document's
        level 1 on such a chunk is then a crash of the twin's, and a mismatch: no cell's chunk lacks any."""
        # (the descriptor is apart from the two: a design B chunk has none on the wire (§2), and level 1 still
        # reads its data and its proof, so it is written with a null descriptor; written narrow, a design B chunk
        # in its wire shape would be the twin's crash)
        d, proof, data = (getattr(f, k, None) for k in ("descriptor", "proof", "data"))
        if proof is None or data is None:
            return self.chunk(f)
        return self.chunk(f) + [[None if d is None else self.descriptor(d), [x.hex() for x in proof], self.blob(data)]]

    def built(self, f):
        """A chunk the block built (publish's `Chunk(...)`), where it is stored: no id yet, and all of its
        content, `[group, index, slot, root, null, [descriptor or null, the proof's digests, the data]]`. In the toy
        the id is on the chunk object once its store has run; the document's chunk has none until message_id is
        called, and the twin's neither. The object is remembered for this record: the `content_id` of the block's
        next message_id of it is written the same way (content_id_asked), once."""
        d = getattr(f, "descriptor", None)
        self.built_objs[id(f)] = f              # held, so that its id() names no other object in this record
        return [f.group.hex(), int(f.index), int(f.slot), f.beacon_block_root.hex(), None,
                [None if d is None else self.descriptor(d), [x.hex() for x in f.proof], self.blob(f.data)]]

    def block(self, b):
        """A block as level 1 reads it: [slot, the bid's group id or None, the bid's descriptor or None]. A block
        with no bid (a directed set's stand-in) commits neither."""
        bid = getattr(getattr(getattr(b, "body", None), "signed_execution_payload_bid", None), "message", None)
        gid = getattr(bid, "execution_payload_segment_group_id", None)
        d = getattr(bid, "execution_payload_segment_descriptor", None)
        return [self.nat(b.slot), None if gid is None else gid.hex(), None if d is None else self.descriptor(d)]

    def mid_of(self, f):
        """A chunk's id for the tracer's own use: the one the chunk has stored, or the document's function's,
        computed here and not stored. So tracing warms no cache of the toy's."""
        m = getattr(f, "mid", None)
        return m if m is not None else self.doc_mid.get(self.cur_nid, self.doc_message_id)(f)

    def content_id_asked(self, tape, f, r, nid):
        """A call of message_id by the block: `content_id(f)` goes on the tape with its answer, the last 20 bytes of
        the id returned, whether the toy's wrapper computed the id or had it stored. And the id returned is the
        document's function's for that chunk, computed again here: a stored id that is not stops the run."""
        self.m2_check(f, r, nid)
        if self.built_objs.pop(id(f), None) is f:       # publish's own message_id of a chunk it built
            form = self.built(f)
            del self.built_objs[id(f)]                  #   (once: the twin's chunk carries the id from here on)
        else:
            form = self.chunk(f)
        tape.append(["content_id", [form], bytes(r)[36:].hex()])

    def m2_check(self, f, r, nid):
        """The check alone: the id message_id returned is the document's function's for that chunk, by the node's own
        function. Also where a call on the tape makes the call: the node's store calls message_id, and a stale
        stored id used there alone would otherwise go unchecked."""
        try:
            want = self.doc_mid.get(nid, self.doc_message_id)(f)
        except Exception as e:
            raise SystemExit(f"trace3: node {nid}: message_id returned a stored id where the document's function "
                             f"raises {type(e).__name__} for that chunk") from e
        if bytes(want) != bytes(r):
            raise SystemExit(f"trace3: node {nid}: message_id returned {bytes(r).hex()}, and the document's function "
                             f"gives {bytes(want).hex()} for that chunk: the id stored on it is not the document's")

    def unscanned_check(self, nd, ns):
        """Under SEACAST, at the install: every namespace name bound to a function of the toy's (its code in the toy's
        directory; a bound method by its function) is one the scan of the toy's bindings binds in that slot, or in a
        slot that slot is an alias of (`chunk_id = ns["message_id"]`). One it does not name there was bound by a form
        the scan does not read, or moved to another slot, and nothing classes it. The documents' functions, the
        tracer's and a fixture's (in this directory) are not the toy's."""
        for name, v in ns.items():
            fn = getattr(v, "__func__", v)
            code = getattr(fn, "__code__", None)
            if (code is None or code.co_filename in (DOC_FILE, SEACAST_FILE)     # the documents' (a relative name, so
                    or not code.co_filename.endswith(".py")                 #   never resolved against the toy's
                    or Path(code.co_filename).resolve().parent != self.toy):  #   directory, the working one)
                continue
            key = (Path(code.co_filename).name, code.co_firstlineno, getattr(fn, "__qualname__", "?"))
            if not any(key in self.scanned.get(s, ()) for s in {name} | self.aliases.get(name, set())):
                raise SystemExit(f"trace3: node {nd.id}: {name} is bound to a function of the toy's that the scan of "
                                 f"its bindings does not name: {key[2]} ({key[0]}:{key[1]})")

    def repoint_aliases(self, nd, ns, pre):
        """Under SEACAST, after the install at the end of construction: two names the toy bound to the raw
        objects before the install are pointed at the installed ones, `hdr` at the view of `desc` (`_seacast`'s
        `hdr=ns["desc"]`) and `chunk_id` at the installed `message_id` (`_seacast` binds the toy's `message_id` wrapper
        to it), and the identities are checked: a raw `hdr` would make every `hdr[g]` read unlogged. Before the
        re-pointing, each alias must be there and bound as the toy binds it (`hdr` the raw `desc` object, `chunk_id`
        the toy's `message_id`, as `pre` holds them, taken before the install, so that a name the install leaves alone
        compares as well as a wrapped one): an alias bound to anything else was bound by something else, and is
        refused, not overwritten."""
        for alias, name in (("hdr", "desc"), ("chunk_id", "message_id")):
            raw = pre.get(name)
            if alias not in ns:
                raise SystemExit(f"trace3: node {nd.id}: {alias} is missing under SEACAST")
            if raw is None or name not in ns:
                raise SystemExit(f"trace3: node {nd.id}: {name} is missing under SEACAST")
            if ns[alias] is not raw:
                raise SystemExit(f"trace3: node {nd.id}: {alias} is not the toy's {name} before the install")
            ns[alias] = ns[name]
            if ns[alias] is not ns[name]:
                raise SystemExit(f"trace3: node {nd.id}: {alias} is not the installed {name}")

    def final_check(self):
        """The traced names once more, when the nodes line is written, and again at the trace's end: install runs
        inside `Node._override`, and the toy binds more after it returns (`Node.__init__`: over_ihave_limits' wrapper; under SEACAST `_seacast`'s names,
        on_frame, promise_due, a liar's send_have; a variant's wrapper of close_promises). A traced name must still
        be the tracer's own wrapper at that node, or a listed wrapper that holds it: anything else runs outside the
        records, unseen where no record calls it and another function's where one does. The names on the tape are
        not held so: a question rebound later is missing from a tape, which the replay refuses, and under SEACAST the toy
        rebinds several that no kept function asks.

        Under SEACAST the install is at the end of the node's construction, the namespace's last binding: every installed
        slot is held, a traced name to the tracer's own wrapper (no listed wrapper over it: one there means an install
        before the toy's bindings), a tape name to its question adapter and a table to its view (so that a slot the toy
        writes back, as `_repair_bias` writes its captured `shuffled`, or a view replaced by its raw table, is seen);
        and the two aliases must still be the installed objects (`repoint_aliases`); and each object type's
        questions still the tracer's."""
        for nd, obj, a, w in self.type_slots:
            if getattr(obj, a, None) is not w:
                raise SystemExit(f"trace3: node {nd.id}: an object type's {a} was bound again after the tracer was "
                                 f"installed: {layer_where(getattr(obj, a, None))}")
        for nd, ns, types in self.type_nodes:   # the parameters as the install read them, which the nodes line holds
            now = self.types_seacast(nd, ns)
            for tid in sorted(set(types) | set(now)):
                was, is_ = types.get(tid), now.get(tid)
                if was is None or is_ is None:
                    raise SystemExit(f"trace3: node {nd.id}: the object type {tid} is "
                                     f"{'new' if was is None else 'gone'} since the tracer's install")
                for p in sorted(set(was) | set(is_)):
                    if was.get(p, "missing") != is_.get(p, "missing"):
                        raise SystemExit(f"trace3: node {nd.id}: type {tid}'s {p} changed after the tracer's install "
                                         f"({was.get(p, 'missing')!r} there, {is_.get(p, 'missing')!r} now): the "
                                         f"nodes line holds a type's parameters as the install read them")
        for nd, ns, bound in self.bound:
            if self.doc_seacast:                     # both aliases there and still the installed objects
                for alias, name in (("hdr", "desc"), ("chunk_id", "message_id")):
                    if name not in ns:
                        raise SystemExit(f"trace3: node {nd.id}: {name} is missing under SEACAST")
                    if alias not in ns or ns[alias] is not ns[name]:
                        raise SystemExit(f"trace3: node {nd.id}: {alias} is not the installed {name}")
            for name, w in bound.items():
                now = ns.get(name)
                if now is w:
                    continue
                if self.doc_seacast:
                    code = getattr(now, "__code__", None)
                    where = (f"{getattr(now, '__qualname__', '?')} ({Path(code.co_filename).name}:{code.co_firstlineno})"
                             if code is not None else f"a {type(now).__name__}")    # a table or a value: its type
                    raise SystemExit(f"trace3: node {nd.id}: {name} was bound again after the tracer was installed, "
                                     f"which under SEACAST must be the namespace's last binding: {where}")
                held = []
                for cell in getattr(now, "__closure__", None) or ():
                    try:
                        held.append(cell.cell_contents)
                    except ValueError:
                        pass
                if WRAPPERS.get(name) == getattr(now, "__qualname__", None) and any(x is w for x in held):
                    continue
                code = getattr(now, "__code__", None)
                where = (f"{getattr(now, '__qualname__', '?')} ({Path(code.co_filename).name}:{code.co_firstlineno})"
                         if code is not None else repr(now))
                raise SystemExit(f"trace3: node {nd.id}: {name} was bound again after the tracer was installed, to "
                                 f"what is neither the tracer's wrapper nor a listed wrapper of it: {where}")

    def control(self, x):
        """A control message on the tape: an IWANT's asks as keys (trace61.py), an IDONTWANT's HAVE as a bitmap.
        Under SEACAST, each message as a lane holds it (qmsg_seacast: one encoder for both)."""
        if not isinstance(x, self.Wm.Control):
            raise TypeError(f"the block enqueues control only, got {x!r}")
        if self.doc_seacast:
            return [self.qmsg_seacast(m) for m in x.items]
        # (announce's IHAVE of a bitmap, written as an IHAVE's entry is; an offer with a claim set stops the tracer)
        return [[m.kind, [self.ihave_entry(b) if m.kind == "idontwant" else self.offer(b) if self.Wm.is_have_bitmap(b)
                          else self.key(b) for b in m.ids]] for m in x.items]

    def args_of(self, fn, args, kw=None):
        kw = kw or {}
        if self.doc_seacast and fn in COVERED_SET:                       # SEACAST's covered names: the forms runSeacast reads
            import records_seacast                                       #   (records_seacast.py, which imports this module)
            return records_seacast.args_seacast(self, fn, args, kw)
        if fn == "choose_push":                                     # §5.3: the document calls it
            names = ("f", "cands", "budget", "at_source")           #   with `budget=` and `at_source=`
            v = dict(zip(names, args))
            if set(v) & set(kw) or set(v) | set(kw) != set(names):
                raise TypeError(f"trace3: choose_push called with {len(args)} arguments and keywords {sorted(kw)}")
            v.update(kw)
            if not isinstance(v["at_source"], bool):
                raise TypeError(f"trace3: choose_push's at_source is no bool: {v['at_source']!r}")
            return [self.chunk(v["f"]), [int(p) for p in v["cands"]], self.nat(v["budget"]), v["at_source"]]
        if kw and not (fn == "close_promises" and set(kw) == {"of"}):
            raise TypeError(f"trace3: {fn} called with keywords {sorted(kw)}")
        if fn in ("on_chunk",):         # a chunk is wide where it arrives or waits
            p, f = args
            return [p, self.wchunk(f)]
        if fn == "on_validated":
            p, f, result = args
            return [p, self.wchunk(f), result]
        if fn == "validate_chunk":      # §3
            (f,) = args
            return [self.wchunk(f)]
        if fn == "committed_descriptor":
            block, f = args
            return [self.block(block), self.wchunk(f)]
        if fn == "send_have":
            p, g = args
            return [p, g.hex()]
        if fn in ("defer", "tie"):                                  # the chunk wide
            p, f = args
            return [p, self.wchunk(f)]
        if fn == "tie_room":
            p, f = args
            return [p, self.chunk(f)]
        if fn == "on_block_installed":
            (root,) = args
            return [root.hex()]
        if fn == "drop_tie":
            p, g, bits = args
            return [p, g.hex(), bits.v]
        if fn == "drop_stale_waits":
            assert not args, args
            return []
        if fn == "next_to_send":
            (p,) = args
            return [p]
        if fn in ("filter_entry", "with_owed"):
            p, e = args
            return [p, self.qentry(e)]
        if fn == "projected":
            p, g = args
            return [p, g.hex()]
        if fn == "rarest":                                          # SEACAST's choose calls it alone, with `queue[p]`:
            (q,) = args                                             #   the peer is the key whose queue it is, in the
            q = F.unwrap(q)                                         #   node's own queue table (by identity)
            ps = [k for k, v in dict.items(self.cur_queue) if v is q]
            if len(ps) != 1:
                raise TypeError(f"trace3: rarest of a queue that is no peer's queue[p] at this node: {q!r}")
            return [ps[0]]
        if fn in ("have_bits", "drop_beyond"):
            (g,) = args
            return [g.hex()]
        if fn == "close_promises":
            g, i, *of = args
            of = kw["of"] if "of" in kw else (of[0] if of else None)
            return [g.hex(), int(i), of]
        if fn == "on_ihave":
            p, ih = args
            return [p, [self.offer(e) for e in ih.ids]]
        if fn == "over_ihave_limits":
            (p,) = args
            return [p]
        if fn in ("expand", "valid_id"):
            (e,) = args
            return [self.ihave_entry(e)]
        if fn in ("gated", "held"):
            (a,) = args
            return [self.key(a)]
        # §1's seven. K and N take what their caller read of `desc`: a descriptor, or None
        if fn == "drop_offer":                                      # §6.1's
            g, i, p = args
            return [g.hex(), self.nat(i), p]
        if fn == "message_id":                                      # §2
            (f,) = args
            try:
                return [self.chunk(f)]
            except OverflowError:       # an index beyond a uint32 has no id (the document's function raises, in
                # the tracer's own computation of the id too): the chunk is written with a null id, so that the
                # call's raise is a record, and not a raise here, before any record
                return [[f.group.hex(), int(f.index), int(f.slot), f.beacon_block_root.hex(), None]]
        if fn in ("group_id", "valid_descriptor"):
            (d,) = args
            return [self.descriptor(d)]
        if fn in ("K", "N"):
            (d,) = args
            return [None if d is None else self.descriptor(d)]
        if fn == "group_key":
            gid, slot = args
            return [gid.hex(), self.nat(slot)]
        if fn == "segment_length":
            d, i = args
            return [self.descriptor(d), self.nat(i)]
        if fn == "build_group":
            (body,) = args
            return [self.blob(body)]
        if fn == "tied_to_root":
            p, a = args
            return [p, self.key(a)]
        if fn == "on_iwant":                                        # §4.5
            p, iw = args
            return [int(p), [self.ask_key(a) for a in iw.ids]]
        if fn == "respond":                                         # §4.1
            p, asks, answers, prunes = args
            return [int(p), [self.key(a) for a in asks], [self.chunk(f) for f in answers], len(self.no_prunes(prunes))]
        if fn == "on_frame":
            p, frame = args
            return [int(p), self.frame(frame)]
        if fn == "on_have":                                         # §4.3: a HAVE's bitmap
            p, h = args
            return [int(p), h.group.hex(), h.bits.v]
        if fn == "push_rebuilt":                                    # §4.6
            g, new = args
            return [g.hex(), [self.nat(i) for i in new]]
        if fn in SEC46:
            (g,) = args
            return [g.hex()]
        if fn in ("on_pace_tick", "on_heartbeat"):                  # §6.4
            assert not args, args
            return []
        if fn == "send_gossip":
            q, ids = args
            return [int(q), [self.key(m) for m in ids]]
        if fn in ("announce", "owe"):                               # §5.2: a bitmap
            p, g, bits = args
            if not isinstance(bits, self.N.B.Bits):
                raise TypeError(f"trace3: {fn}'s bits are no bitmap: {bits!r}")
            return [int(p), g.hex(), bits.v]
        if fn in ("unpush", "note_push"):
            p, g, i = args
            return [int(p), g.hex(), self.nat(i)]
        if fn == "guard_fails":                                     # §5.3
            p, g = args
            return [int(p), g.hex()]
        if fn == "forward":                                         # §5.2's
            f, p = args
            return [self.chunk(f), int(p)]
        if fn == "candidates_for_source":
            (f,) = args
            return [self.chunk(f)]
        if fn == "on_mesh_join":
            (p,) = args
            return [int(p)]
        if fn in ("acquire_slot", "release_unused_slot", "write_waits"):    # §7.1's
            (p,) = args
            return [int(p)]
        if fn in ("front", "wake_front"):
            assert not args and not kw, (args, kw)
            return []
        if fn == "track_in_flight":
            p, f = args
            return [int(p), self.chunk(f)]
        if fn == "window_release":
            p, g, i = args
            return [int(p), g.hex(), self.nat(i)]
        if fn == "window_timeout":                                  # the send's key and the time's bits
            k, at = args
            return [[int(k[0]), k[1].hex(), self.nat(k[2])], fbits(at)]
        if fn == "free_slot":
            assert not args, args
            return []
        if fn == "origin_written":                                  # §5.1's
            (f,) = args
            return [self.chunk(f)]
        if fn == "publish":                                         # the block, the descriptor, the shards
            block, d, shards = args
            return [self.block(block), self.descriptor(d),
                    [[self.nat(x.index), [h.hex() for h in x.proof], self.blob(x.data)] for x in shards]]
        if fn == "origin_acked":
            g, i = args
            return [g.hex(), self.nat(i)]
        return super().args_of(fn, args)

    def ret_of(self, fn, r):
        if self.doc_seacast and fn in COVERED_SET:
            import records_seacast
            return records_seacast.ret_seacast(self, fn, r)
        if fn in ("on_ihave", "expand"):
            return [self.key(a) for a in r]
        if fn == "have_bits":
            return r.v
        if fn == "tie_room":
            assert isinstance(r, bool), (fn, r)
            return r
        if fn == "next_to_send":                                    # an entry, WAIT, or nothing
            return "WAIT" if r is self.WAIT else None if r is None else self.qentry(r)
        if fn in ("filter_entry", "with_owed"):
            return None if r is None else self.qentry(r)
        if fn == "projected":
            assert isinstance(r, bool), (fn, r)
            return r
        if fn == "rarest":
            return int(r)
        if fn in SEC42 or fn in SEC42B or fn in SEC61B or fn in SEC64 or fn in SEC46 or fn in SEC43 or fn in SEC52 or fn in ("respond", "on_frame"):
            assert r is None, (fn, r)
            return None
        if fn in ("choose_push", "candidates_for_source"):          # the targets, the candidates: peers in order
            return [int(p) for p in r]
        if fn in ("forward", "on_mesh_join", "origin_written", "origin_acked", "publish"):
            assert r is None, (fn, r)
            return None
        if fn == "acquire_slot":
            assert isinstance(r, bool), (fn, r)
            return r
        if fn == "front":                                           # the first in line that can write, or none
            return None if r is None else int(r)
        if fn in SEC71:
            assert r is None, (fn, r)
            return None
        if fn in ("over_ihave_limits", "gated", "valid_id", "held", "tied_to_root", "valid_descriptor", "guard_fails"):
            assert isinstance(r, bool), (fn, r)
            return r
        if fn == "on_iwant":                                        # the answers: chunks
            return [self.chunk(f) for f in r]
        if fn == "validate_chunk":                                  # level 1's result
            if r not in ("ACCEPT", "REJECT", "DEFER"):
                raise TypeError(f"trace3: not a result of validate_chunk: {r!r}")
            return r
        if fn == "committed_descriptor":
            return None if r is None else self.descriptor(r)
        if fn in ("group_id", "group_key", "message_id"):           # §1's; §2's id
            return r.hex()
        if fn in ("K", "N"):
            return self.nat(r)
        if fn == "segment_length":
            return self.integer(r)
        if fn == "build_group":
            d, shards = r
            return [self.descriptor(d), [[self.nat(s.index), [x.hex() for x in s.proof], self.blob(s.data)] for s in shards]]
        return super().ret_of(fn, r)

    @staticmethod
    def boolean(r):                     # a question's answer that must be a bool itself, not a truthy value
        if not isinstance(r, bool):
            raise TypeError(f"trace3: not a bool: {r!r}")
        return r

    def drawn(self, a):                 # a member of a list shuffled: a peer or an index as it is, an ask as its key
        return a if isinstance(a, int) and not isinstance(a, bool) else self.key(a)

    @staticmethod
    def store_group(cg):                # `chunks[g]`, the node's store of a group, as decode_and_reencode's argument:
        if isinstance(cg, F.View) and len(cg._p) == 1:      # the group whose row of `chunks` it is
            return cg._p[0].hex()
        raise TypeError(f"trace3: decode_and_reencode's chunks are not a row of `chunks`: {cg!r}")

    def rebuilt(self, r):               # the rebuilt chunks, each under its index, in the dict's order; or None
        return None if r is None else [[self.nat(i), self.chunk(f)] for i, f in r.items()]

    def payload(self, x):               # a payload: nothing (the toy's payload_of), or a blob
        return None if x is None else self.blob(x)

    @staticmethod
    def no_prunes(r):                   # the stock's prunes: none in the toy's runs, and a record holds none's content
        if list(r):
            raise TypeError(f"trace3: prunes, of which a record holds none: {r!r}")
        return []

    def ask_key(self, a):               # an IWANT's id: an ask by index, or a structured id
        if not (isinstance(a, self.Wm.WantIndex) or (isinstance(a, bytes) and len(a) == 56)):
            raise TypeError(f"trace3: an IWANT's id that is neither an ask by index nor a structured id of 56 bytes: {a!r}")
        return self.key(a)

    def frame(self, fr):                # a frame as on_frame sees it: [chunks, ihave, iwant, idontwant]
        if fr.prune or fr.graft or fr.join:
            raise TypeError("trace3: a frame with a PRUNE, a GRAFT or a JOIN: the stock's, of which a record holds none")
        # (since v0.10.4 an IDONTWANT's entry that is no HAVE bitmap is an opaque id, kept in `unwanted[p]`:
        # ihave_entry writes it as its hex, and raises for an entry that is neither a bitmap nor bytes)
        return [[self.wchunk(f) for f in fr.chunks], [self.offer(e) for e in fr.ihave.ids],
                [self.ask_key(a) for a in fr.iwant.ids], [self.ihave_entry(h) for h in fr.idontwant]]

    @staticmethod
    def nothing(r):                     # a call that returns nothing
        if r is not None:
            raise TypeError(f"trace3: a call that returns nothing returned {r!r}")
        return None

    # ---- the values: numbers, descriptors, blobs
    @staticmethod
    def nat(i):
        """A natural number of a record: a Python int, not a bool, not negative."""
        if not isinstance(i, int) or isinstance(i, bool) or i < 0:
            raise TypeError(f"trace3: not a natural number: {i!r}")
        return i

    @staticmethod
    def integer(i):
        """An integer that can be negative: a natural number, or ["-", n] for -n. A record has no number with a
        sign (the replay's strict scan refuses one)."""
        if not isinstance(i, int) or isinstance(i, bool):
            raise TypeError(f"trace3: not an integer: {i!r}")
        return i if i >= 0 else ["-", -i]

    # ---- SEACAST's questions, in the forms the twin asks them (Seacast/Replay.lean's NodeSeacast; forms-seacast-examples.tsv)
    @staticmethod
    def tid(T):
        """An object type by its id."""
        return schema_seacast.type_id(T)

    def hdr_seacast(self, h):
        """A group's header, or none: a descriptor's seven fields, for every type (a column's and a row's carry more,
        which the twin reads through questions alone)."""
        return None if h is None else self.descriptor(h)

    def cover_seacast(self, r):
        """A record of a node or of a link, with the fields it has: {"id", "families", "high"} (V2's coverJson)."""
        out = {"id": self.nat(r.id)} if hasattr(r, "id") else {}
        out["families"] = [self.integer(x) for x in r.families]
        if hasattr(r, "high"):
            out["high"] = self.flag(r.high, "a record's high")
        return out

    def member_seacast(self, x):
        """A member of a draw's list (choice, sample_without_replacement, shuffled), by its Python type: a peer or an
        index as it is; an (index, chunk) pair as [i, f]; a record as cover_seacast writes it; an ask by its key."""
        if isinstance(x, int) and not isinstance(x, bool):
            return x
        if isinstance(x, tuple) and len(x) == 2:
            return [self.nat(x[0]), self.chunk(x[1])]
        if hasattr(x, "families"):
            return self.cover_seacast(x)
        return self.key(x)

    def have_msg_seacast(self, h):
        """A HAVE: ["have", g, bits, offer, claim_all, complete], its bits a natural."""
        return ["have", h.group.hex(), self.nat(h.bits.v), self.flag(h.offer, "a HAVE's offer"),
                self.flag(h.claim_all, "a HAVE's claim_all"), self.flag(h.complete, "a HAVE's complete")]

    def want_seacast(self, w):
        """A WANT: ["want", g, bits, standing, hops, probe], its fields left at their defaults written too."""
        return ["want", w.group.hex(), self.nat(w.bits.v), self.flag(getattr(w, "standing", False), "a WANT's standing"),
                self.nat(getattr(w, "hops", 0)), self.flag(getattr(w, "probe", False), "a WANT's probe")]

    def rel_seacast(self, m):
        """A relation message: ["join", T, interest, custody_count, duty, colours], ["graft", T, family, colour,
        direction, answer] or ["prune", T, family, colour, direction]. A plain Container of exactly a JOIN's fields
        is a JOIN: the toy's custody and row settings store each peer's JOIN in `join_recv` so (node.py's
        set_column_relations)."""
        kind = type(m).__name__
        if kind == "Container" and frozenset(vars(m)) == JOIN_FIELDS_Seacast:
            kind = "Join"
        if kind == "Join":
            return ["join", self.type_word(m.object_type), m.interest, self.nat(m.custody_count), m.duty,
                    self.nat(m.colours)]
        if kind == "Graft":
            return ["graft", self.type_word(m.object_type), self.integer(m.family), self.nat(m.colour), m.direction,
                    self.flag(m.answer, "a GRAFT's answer")]
        if kind == "Prune":
            return ["prune", self.type_word(m.object_type), self.integer(m.family), self.nat(m.colour), m.direction]
        raise TypeError(f"trace3: not a relation message of SEACAST's: {m!r}")

    @staticmethod
    def type_word(t):
        """A message's object type: its id, a string."""
        if not isinstance(t, str):
            raise TypeError(f"trace3: an object type that is not its id: {t!r}")
        return t

    @staticmethod
    def direction_word(d):
        """A relation's direction: "OUT", "IN" or "BOTH", the toy's strings (directionJson)."""
        if not isinstance(d, str) or d not in schema_seacast.DIRECTIONS:
            raise TypeError(f"trace3: not a direction: {d!r}")
        return d

    @staticmethod
    def uplink_word(u):
        """§4.1's uplink class: "FAST" or "HOME" (uplinkClassOf)."""
        if not isinstance(u, str) or u not in ("FAST", "HOME"):
            raise TypeError(f"trace3: not an uplink class: {u!r}")
        return u

    def msg_seacast(self, m):
        """A message `send` takes: a HAVE, a WANT or a relation message (the twin's msgSeacastJson)."""
        kind = type(m).__name__
        return self.have_msg_seacast(m) if kind == "Have" else self.want_seacast(m) if kind == "Want" else self.rel_seacast(m)

    @staticmethod
    def verdict_seacast(r):
        if r not in ("ACCEPT", "REJECT", "DEFER"):
            raise TypeError(f"trace3: not a verdict: {r!r}")
        return r

    def admitted_seacast(self, x, Have):
        """What admitted(p, x) is asked of under SEACAST: a HAVE (on_holding's and on_offer's) as a holding, ["holding",
        group, bits, claim_all, complete], its claims as they are (an offer's both false); a chunk (defer's) as the
        twin reads one. Anything else stops the tracer: the twin reads no other kind."""
        if isinstance(x, Have):
            return self.holding(x)
        if all(hasattr(x, k) for k in ("group", "index", "slot", "beacon_block_root")):
            return self.chunk(x)
        raise SystemExit(f"trace3: admitted is asked of {type(x).__name__} under SEACAST, which is neither a HAVE nor a "
                         f"chunk: {x!r}")

    def questions_enc_seacast(self, Have):
        """Under SEACAST, the namespace's questions that seacast.md adds, but for the object types' and their
        parameters' (type_enc_seacast) and the lookups' (lookups_enc), each as [arguments, answer]; and valid_have, shuffled and
        admitted in their SEACAST forms beside seacast-lite.md's (a SEACAST HAVE; an (index, chunk) pair or a record as a member;
        a HAVE as a holding). `Have` is the node's HAVE class."""
        t, g_, n, i_ = self.tid, (lambda g: g.hex()), self.nat, self.integer
        peers = lambda r: [n(q) for q in r]         # noqa: E731
        fams = lambda r: [i_(x) for x in r]         # noqa: E731
        nothing, boolean = self.nothing, self.boolean
        return {
            "type_of_group": lambda r, g: [[g_(g)], t(r)],
            "type_of": lambda r, tid: [[self.type_word(tid)], t(r)],
            "links": lambda r, T: [[t(T)], peers(r)],
            "link_cover": lambda r, q, T: [[n(q), t(T)], self.cover_seacast(r)],
            "cover_candidates": lambda r, T: [[t(T)], [self.cover_seacast(x) for x in r]],
            "floor_candidates": lambda r, T: [[t(T)], [self.cover_seacast(x) for x in r]],
            "floor_links": lambda r, T, fam: [[t(T), i_(fam)], peers(r)],
            "high_custody": lambda r, q, T: [[n(q), t(T)], boolean(r)],
            "families": lambda r, T: [[t(T)], fams(r)],
            "families_with_duty": lambda r, T: [[t(T)], fams(r)],
            "wants_family": lambda r, T, fam: [[t(T), i_(fam)], boolean(r)],
            "duty_for": lambda r, g: [[g_(g)], self.type_word(r)],
            "route_next": lambda r, T, fam, qs: [[t(T), i_(fam), peers(qs)], peers(r)],
            "block_of": lambda r, g: [[g_(g)], bytes(r).hex()],
            "group_of": lambda r, block, h: [[self.block(block), self.hdr_seacast(h)], bytes(r).hex()],
            "node_id": lambda r, p: [[n(p)], bytes(r).hex()],
            # §4.5's: on_want's admission of p's group, and our_interest_for's own id (its DERIVED case)
            "admitted_group": lambda r, p, g: [[n(p), g_(g)], boolean(r)],
            "own_id": lambda r: [[], bytes(r).hex()],
            # §4.1's upkeep (FormsRows' askOf): the node's types, its JOIN, its candidates and pushers, its uplink
            "runs_type": lambda r, tid: [[self.type_word(tid)], boolean(r)],
            "our_join": lambda r, T: [[t(T)], self.rel_msg(r, "join")],
            "candidates": lambda r, T, fam, c, d: [[t(T), i_(fam), n(c), self.direction_word(d)], peers(r)],
            "in_pushers": lambda r, T, fam, c: [[t(T), i_(fam), n(c)], peers(r)],
            "out_pushees": lambda r, T, fam, c: [[t(T), i_(fam), n(c)], peers(r)],
            "uplink_class": lambda r: [[], self.uplink_word(r)],
            "interest_satisfied": lambda r, g: [[g_(g)], boolean(r)],
            "merge_waiting": lambda r, p, h: [[n(p), self.have_msg_seacast(h)], boolean(r)],
            "deferred_offers": lambda r, p, h: [[n(p), self.have_msg_seacast(h)], self.none_listed(r)],
            "open_group_source": lambda r, g, d: [[g_(g), self.hdr_seacast(d)], nothing(r)],
            "open_link": lambda r, x, T: [[self.cover_seacast(x), t(T)], nothing(r)],
            "open_sampling_link": lambda r, x, T: [[self.cover_seacast(x), t(T)], nothing(r)],
            # v0.11.1's: §3's helper, prose alone (the node's own code answers it), its writes in its log
            "release_wanted_groups": lambda r: [[], nothing(r)],
            # seacast-lite.md §8.2's, asked under SEACAST by on_holding and on_offer of a HAVE, and by defer of a chunk
            "admitted": lambda r, p, x: [[n(p), self.admitted_seacast(x, Have)], boolean(r)],
            "choice": lambda r, xs: [[[self.member_seacast(x) for x in xs]], self.member_seacast(r)],
            "send": lambda r, p, m, urgent=False: [[n(p), self.msg_seacast(m), self.flag(urgent, "send's urgent")],
                                                   boolean(r)],
            # the manifest's CUT: seacast.md's functions the twin does not transcribe, a question at every node
            "window_release": lambda r, p, g, i: [[n(p), g_(g), n(i)], nothing(r)],
            # seacast-lite.md's two, in SEACAST's forms where SEACAST asks them so (seacast-lite.md's form for an IHAVE's entry)
            "valid_have": lambda r, e: [[self.have_msg_seacast(e) if isinstance(e, Have) else self.offer(e)], bool(r)],
            "shuffled": lambda r, xs: [[[self.member_seacast(a) for a in (xs.m if isinstance(xs, MeshQuestion) else xs)]],
                                       [self.member_seacast(a) for a in r]]}

    def swr_seacast(self):
        """sample_without_replacement's encoders under SEACAST (CALLS' form: arguments, answer): its members by their
        type (member_seacast), records (keep_floor's floor candidates) as well as peers."""
        return (lambda xs, k: [[self.member_seacast(q) for q in xs], self.nat(k)],
                lambda r: [self.member_seacast(q) for q in r])

    @staticmethod
    def none_listed(r):                 # deferred_offers' answer: the toy's is always empty, the only form agreed
        if list(r):
            raise TypeError(f"trace3: deferred_offers answered a list that is not empty: {r!r}")
        return []

    def type_enc_seacast(self, T):
        """An object type's nine functions as questions, the type first among the arguments."""
        t, hd, ch, n = self.tid(T), self.hdr_seacast, self.chunk, self.nat
        gis = lambda r: [[g.hex(), n(i)] for g, i in r]     # noqa: E731
        return {
            "index_count": lambda r, h: [[t, hd(h)], n(r)],
            "threshold": lambda r, h: [[t, hd(h)], n(r)],
            "verify": lambda r, f, h: [[t, ch(f), hd(h)], self.verdict_seacast(r)],
            "decode": lambda r, fr, h: [[t, self.store_group(fr), hd(h)], self.rebuilt(r)],
            "header_of": lambda r, f: [[t, ch(f)], hd(r)],
            "project": lambda r, f: [[t, ch(f)], gis(r)],
            "cross": lambda r, g, i: [[t, g.hex(), n(i)], gis(r)],
            "family": lambda r, g: [[t, g.hex()], self.integer(r)],
            "derived_interest": lambda r, g, h, nid, j: [[t, g.hex(), hd(h), bytes(nid).hex(), self.rel_seacast(j)],
                                                         self.integer(r.v)]}

    def param_enc_seacast(self, T):
        """An object type's three parameter functions as questions, the type first among the arguments."""
        t = self.tid(T)
        return {"DECODE_AT_K": lambda r, g: [[t, g.hex()], self.boolean(r)],
                "DECODE_LATER": lambda r, g: [[t, g.hex()], None if r is None else fbits(r)],
                "REPAIR_TO": lambda r, g: [[t, g.hex()], [self.nat(q) for q in r]]}

    def asked_enc_seacast(self):
        """The eight names the twin asks where a node replaces them (ASKED_Seacast), in its NodeSeacast's forms: `forward` with
        its axes or null, `known_in_scope`'s bitmap as a natural."""
        n, nothing = self.nat, self.nothing
        return {
            "forward": lambda r, f, p, axes=None: [[self.chunk(f), n(p),
                                                    None if axes is None else [[g.hex(), n(i)] for g, i in axes]],
                                                   nothing(r)],
            "push_rebuilt": lambda r, g, new: [[g.hex(), [n(i) for i in new]], nothing(r)],
            "send_have": lambda r, p, g: [[n(p), g.hex()], nothing(r)],
            "serve_standing": lambda r, g, i: [[g.hex(), n(i)], nothing(r)],
            "owed_missing": lambda r, g: [[g.hex()], self.boolean(r)],
            "repair_verdict": lambda r, g: [[g.hex()], self.repair_word(r)],
            "note_claim": lambda r, p, g: [[n(p), g.hex()], nothing(r)],
            "known_in_scope": lambda r, g: [[g.hex()], n(r.v)]}

    @staticmethod
    def repair_word(r):
        if r not in ("REPAIRED", "NOT_REPAIRED", "ASKED"):
            raise TypeError(f"trace3: not a repair verdict: {r!r}")
        return r

    def descriptor(self, d):
        """A descriptor, whole: [version, hash_id, encoding, count, segment_size, total_length, root]."""
        return [self.nat(d.version), self.nat(d.hash_id), self.nat(d.encoding), self.nat(d.count),
                self.nat(d.segment_size), self.nat(d.total_length), d.root.hex()]

    def blob(self, b):
        """A blob: [length, tag], the toy's tag with its tuples as lists (a string or an int at its leaves)."""
        def tag(t):
            if isinstance(t, tuple):
                return [tag(x) for x in t]
            if isinstance(t, (str, int)) and not isinstance(t, bool):
                return t
            raise TypeError(f"trace3: a blob's tag the record cannot hold: {t!r}")
        if not isinstance(b, self.Wm.Blob):
            raise TypeError(f"trace3: not a blob: {b!r}")
        return [len(b), tag(b.tag)]

    # ---- §7's queue, the twin's own table
    def lane(self, entries):
        """A lane's value: its entries in order, each [chunk or null, control or null, solicited]. The toy's own
        marks of an entry (`at`, `urgent`) are not written: nothing the documents run reads them."""
        return [self.qentry(e) for e in entries]

    def qentry(self, e):
        c = e.control
        return [self.chunk(e.chunk) if e.chunk is not None else None,
                None if c is None else [self.qmsg(m) for m in c.items], bool(e.solicited)]

    def qmsg(self, m):
        """A control message of an entry, in a lane and in a control on the tape (one encoder for both under SEACAST).
        Under seacast-lite.md: an IWANT's ids as ask keys, an IHAVE's and an IDONTWANT's as IHAVE entries; a PRUNE with
        ids, a GRAFT or a JOIN is refused, as none is queued in the toy's runs (its stock prunes are none). Under
        SEACAST: qmsg_seacast."""
        if self.doc_seacast:
            return self.qmsg_seacast(m)
        if m.kind == "iwant":
            return ["iwant", [self.key(b) for b in m.ids]]
        if m.kind == "ihave":
            return ["ihave", [self.offer(x) for x in m.ids]]
        if m.kind == "idontwant":
            return ["idontwant", [self.ihave_entry(x) for x in m.ids]]
        if m.kind == "prune" and not m.ids:
            return ["prune", []]
        raise TypeError(f"trace3: a queue entry's control message the record cannot hold: {m.kind} {m.ids!r}")

    # ---- SEACAST's forms of a control message (seacast.md §2), under --doc seacast alone
    def qmsg_seacast(self, m):
        """An IWANT is ["iwant", [ask, ...], want], each ask [key, standing, hops, probe] and `want` the message's
        mark as it is when the value is written; an IDONTWANT is ["idontwant", [entry, ...]], each bitmap a holding
        with its claims; an IHAVE is as under seacast-lite.md, and refuses an offer with a claim set; a JOIN, a GRAFT
        or a PRUNE of SEACAST is [kind, [message]], its one message in the tagged form; gossipsub's PRUNE is
        ["prune", []]."""
        if m.kind == "iwant":
            return ["iwant", [self.ask_seacast(a) for a in m.ids], self.flag(m.want, "an IWANT's want")]
        if m.kind == "ihave":
            return ["ihave", [self.offer(x) for x in m.ids]]
        if m.kind == "idontwant":
            return ["idontwant", [self.holding(x) if self.Wm.is_have_bitmap(x) else self.ihave_entry(x)
                                  for x in m.ids]]
        if m.kind == "prune" and not m.ids:
            return ["prune", []]
        if m.kind in ("join", "graft", "prune"):
            if len(m.ids) != 1:
                raise TypeError(f"trace3: a {m.kind} control with {len(m.ids)} messages, where SEACAST's sends one: "
                                f"{m.ids!r}")
            return [m.kind, [self.rel_msg(m.ids[0], m.kind)]]
        raise TypeError(f"trace3: a queue entry's control message the record cannot hold: {m.kind} {m.ids!r}")

    def enqueue_enc(self, r, p, x, urgent=False):
        """The tape's enqueue: [[peer, what, urgent], accepted], what an entry, a control or a chunk."""
        return [[p, ["entry", self.qentry(x)] if isinstance(x, self.Wm.Entry)
                 else self.control(x) if isinstance(x, self.Wm.Control)
                 else ["chunk", self.chunk(x)], bool(urgent)], bool(r)]

    @staticmethod
    def zero_calls():
        return {"record": 0, "in": Counter(), "asked": Counter(), "ext": 0, "outer": 0, "observer": 0}

    def count_call(self, name, branch, host=None):
        """Under SEACAST, a call of a traced name, by where it ran: "record" (it opened one), "in" (its own call inside an
        open record, which the record's `reached` names, by that record's fn, `host`), "asked" (a replaced name asked
        as a question by an open record's own code, by that record's fn), "ext" (inside an interface call), "outer" (a
        replaced name entered outside any record) or "observer" (an observer's own code). Its bare calls are
        .bare.json's, added at the end. Each of sec61's and iface_of's wrappers counts every call it takes."""
        c = self.calls.setdefault(name, self.zero_calls())
        if branch in ("in", "asked"):
            c[branch][host] += 1
        else:
            c[branch] += 1

    def iw_enter(self, name):
        """A call of one of IW_NAMES in a record, entered: each of them open around it, counted once."""
        ins = self.inside.setdefault(name, Counter())
        for o in set(self.open_iw):
            ins[o] += 1
        self.open_iw.append(name)

    def iw_leave(self, name, branch, tape, k, host=None):
        """That call left: the IWANTs in the enqueue rows its record's tape gained since it was entered (k rows); a call
        inside another's record by that record's fn, `host`."""
        self.open_iw.pop()
        self.count_iwants(name, branch, tape[k:], host)

    def count_iwants(self, name, branch, rows, host=None):
        asks = [n for t in rows if isinstance(t, (list, tuple)) and len(t) >= 2 and t[0] == "enqueue"
                for n in iwant_asks(t[1])]
        d = self.iw.setdefault(name, {})
        if branch == "in":                  # the in half by host
            d = d.setdefault("in", {})
            branch = host
        s = d.setdefault(branch, {"calls": 0, "with": 0, "iwants": 0, "asks": Counter()})
        s["calls"] += 1
        s["with"] += 1 if asks else 0
        s["iwants"] += len(asks)
        s["asks"].update(asks)

    def write_calls(self):
        """OUT.calls.json, under SEACAST: count_call's counts with the bare ones, for every traced name (zeros too);
        count_iwants', the record half and the in half by host; and the IW_NAMES inside one another; keys sorted."""
        bare = Counter()
        for k, v in self.bare.items():
            bare[k.split(" ", 1)[1]] += v
        calls = {}
        for n in sorted(set(self.traced) | set(self.calls) | set(bare)):
            c = self.calls.get(n, self.zero_calls())
            calls[n] = {"record": c["record"], "in": dict(sorted(c["in"].items())),
                        "asked": dict(sorted(c["asked"].items())), "bare": bare[n], "ext": c["ext"],
                        "outer": c["outer"], "observer": c["observer"]}

        def part(s):
            return {"calls": s["calls"], "with": s["with"], "iwants": s["iwants"],
                    "asks": {str(a): m for a, m in sorted(s["asks"].items())}}
        iw = {n: {b: part(s) if b == "record" else {h: part(t) for h, t in sorted(s.items())}
                  for b, s in sorted(d.items())}
              for n, d in sorted(self.iw.items())}
        inside = {n: dict(sorted(c.items())) for n, c in sorted(self.inside.items())}
        with open(self.out_path + ".calls.json", "w") as f:
            json.dump({"calls": calls, "iwants": iw, "inside": inside}, f, sort_keys=True)
            f.write("\n")

    def at_call(self, name, enc, args, kw):
        """Under SEACAST, a name of EAGER_Seacast: its arguments' form as they are at the call, before it runs (else None)."""
        if self.doc_seacast and name in EAGER_Seacast and not EAGER_LATE[0]:
            return enc(None, *args, **kw)[0]
        return None

    @staticmethod
    def tape_row(enc, r, args, kw, early):
        """A tape name's [arguments, answer], the arguments as at_call wrote them where it did."""
        row = enc(r, *args, **kw)
        if early is not None:
            row[0] = early
        return row

    # ---- timers: a record's own `after`, and the notes of a question's
    def timer_args(self, name, args):
        """A timer's arguments as a record writes them, by its target's name, for the record's own `after` and for a
        note alike: seacast-lite.md's promise_due and window_timeout by their forms, its other timers by their keys;
        under SEACAST, seacast.md's three as the twin's timerSeacastJson has them: reconsider [g, at's word], ask_sample
        [g, i], resample [g, i, q, first]. An ask_sample armed with a third argument stops the tracer: the twin's form
        has none."""
        key = self.key
        if name == "promise_due":                       # filter_entry's `after(PROMISE, promise_due, a, p, now)`
            a, p, at = args
            return [key(a), int(p), fbits(at)]
        if name == "window_timeout":                    # track_in_flight's `after(WINDOW_TIMEOUT, window_timeout,
            k, at = args                                #   key, now)`
            return [[int(k[0]), k[1].hex(), int(k[2])], fbits(at)]
        if self.doc_seacast and name in ("reconsider", "ask_sample", "resample"):
            g = args[0] if args else None
            if not isinstance(g, bytes):
                raise TypeError(f"trace3: {name}'s timer on no group: {args!r}")
            if name == "reconsider":                    # `after(max(0, at - now), reconsider, g, at)`
                _, at = args
                return [g.hex(), fbits(at)]
            if name == "ask_sample":                    # `after(T.params.SAMPLE_RETRY, ask_sample, g, i)`
                if len(args) != 2:
                    raise SystemExit(f"trace3: ask_sample armed with {len(args)} arguments, where the twin's form "
                                     f"has two (g, i): {args!r}")
                return [g.hex(), self.nat(args[1])]
            _, i, q, first = args                       # `after(…, resample, g, i, q, first)`
            return [g.hex(), self.nat(i), self.nat(q), self.flag(first, "resample's first")]
        out = []
        for x in args:
            if isinstance(x, (bytes, self.Wm.WantIndex)):
                out.append(key(x))
            else:
                raise TypeError(f"§6.1 arms timers on keys only, got {x!r}")
        return out

    def after_row(self, delay, fn, *args):
        """A record's own `after(delay, fn, *args)` on its tape: [delay's word, fn's name, its arguments]."""
        return [fbits(delay), fn.__name__, self.timer_args(fn.__name__, args)]

    def one_timer(self, nd, kind, seen):
        """The one timer an `after` or `start` inside a question armed (arm_timer): none, or two, stops the tracer."""
        if len(seen) != 1:
            raise SystemExit(f"trace3: node {nd.id}: an {kind} inside a question armed {len(seen)} timers, where it "
                             f"arms one")
        return seen[0]

    def timer_target(self, nd, kind, fn):
        """The name a note gives the function its timer calls: a document's timer of that kind (DOC_TIMERS), by its
        name, where the function is the document's or a listed wrapper of it (own_code), the tracer's own wrappers
        looked through; or a toy callback of TOY_TIMERS, by its qualified name. Any other stops the tracer, naming its
        qualified name and first line."""
        f = fn
        while hasattr(f, "__wrapped__") and tracers_own(f):
            f = f.__wrapped__
        code = getattr(f, "__code__", None)
        qual = getattr(f, "__qualname__", None) or type(f).__name__
        where = "no Python function"
        if code is not None:
            name = code.co_name
            if name in DOC_TIMERS[kind] and (code.co_filename in (DOC_FILE, SEACAST_FILE) or own_code(name, f)[0] == "own"):
                return name
            if kind == "after" and qual in TOY_TIMERS and Path(code.co_filename).name == "node.py":
                return qual
            where = f"{Path(code.co_filename).name}:{code.co_firstlineno}"
        raise SystemExit(f"trace3: node {nd.id}: a timer armed inside a question calls {qual} ({where}), neither a "
                         f"document's {kind} target nor a listed toy callback")

    def note_of(self, nd, kind, delay, target, args):
        """The note of a timer armed inside a question: [kind, the delay's word as the simulator was handed it, the
        target (timer_target), its arguments]. A `start`'s are [g]; alarm_due's (g, i, q, at) [g, i, q, at's word];
        a document's timer's as the record's own `after` writes them (timer_args)."""
        name = self.timer_target(nd, kind, target)
        if kind == "start":
            (g,) = args
            enc = [g.hex()]
        elif name in TOY_TIMERS:
            g, i, q, at = args
            enc = [g.hex(), self.nat(i), self.nat(q), fbits(at)]
        else:
            enc = self.timer_args(name, args)
        return [kind, self.note_delay(nd, delay), name, enc]

    @staticmethod
    def note_delay(nd, delay):
        """A note's delay, as its word: a finite number. The twin's note reader refuses another (fbits writes +inf's
        word too, which the LIMITS need), so a timer armed inside a question with such a delay stops the tracer."""
        if not math.isfinite(delay):
            raise SystemExit(f"trace3: node {nd.id}: a timer armed inside a question has the delay {delay!r}, which is "
                             f"no finite number: the twin's note reader refuses it")
        return fbits(delay)

    def arm_timer(self, nd, kind, fn, args, kw):
        """An `after` or `start` called inside a question at the node: it runs with the simulator's `after` hooked
        for this one call, so that a timer armed otherwise (the writer's kick, `node.sim.after` itself) is no note.
        The one timer it armed (one_timer) is the note. Returns the call's answer and the note."""
        sim, seen = nd.sim, []
        had, prev, orig = "after" in vars(sim), vars(sim).get("after"), sim.after

        def hook(node, delay, f, *a):
            seen.append((delay, f, a))
            return orig(node, delay, f, *a)
        sim.after = hook
        try:
            r = fn(*args, **kw)
        finally:
            if had:
                sim.after = prev
            else:
                del sim.after
        delay, target, targs = self.one_timer(nd, kind, seen)
        return r, self.note_of(nd, kind, delay, target, targs)

    @staticmethod
    def raised_with_notes(nd, name, e):
        """A question that raises after arming a timer stops the tracer: no row holds a raise's notes."""
        raise SystemExit(f"trace3: node {nd.id}: {name} raised {type(e).__name__} after arming a timer: a raising "
                         f"question's row cannot hold the notes")

    def source_offers_check(self, nd):
        """Under --doc seacast, a node built with --source-offers late is refused: the toy's ablation, a setting of neither
        document. A seacast-lite.md trace goes as before."""
        if self.doc_seacast and (getattr(nd, "cfg", None) or {}).get("source_offers", "on") == "late":
            raise SystemExit("trace3: --source-offers late is the toy's ablation (publish's own offers queued after "
                             "the same instant's pushes), a setting of neither document, whose SOURCE_OFFERS is ACK or "
                             "PUBLISH: not traced under --doc seacast")

    def iface_of(self, nd, st, rec, replaced, calls, mesh_on, mesh_off, name, fn, enc):
        """A tape name's (or a replaced name's) wrapper at a node: where §6.1's own code calls it, a question, its
        row on the record's tape; elsewhere bare. Under SEACAST, an `after` or `start` inside a question at the node is a
        note of the outermost question there (arm_timer), written in its row (call_log)."""
        tr = self
        counted = tr.doc_seacast and name in tr.traced     # under SEACAST a traced name (replaced here): each of
        #                                                     its calls counted by the path it takes (count_call)

        @functools.wraps(fn)
        def w(*args, **kw):
            ob = getattr(rec, "observer", None) if tr.doc_seacast else None
            if ob is not None:              # asked by an observer's own code (class 6): no question of the record's,
                if name in TIMER_KINDS:     #   bare; a timer it arms changes the node
                    raise SystemExit(ob.words(f"arms a timer ({name})", "an observer changes nothing"))
                if counted:
                    tr.count_call(name, "observer")
                return fn(*args, **kw)
            if tr.doc_seacast:
                foreign = st["depth"] and st["node"] != int(nd.id)     # another node's record is open
                if foreign and not (st["ext"] or st["supp"]):          #   and no question runs: a tape name
                    raise SystemExit(f"trace3: node {nd.id}: {name} is called while node {st['node']}'s record "
                                     f"is open and no question runs")  #   stops as a traced one does
                if foreign or st["supp"]:       # bare: inside a question at another node, or inside a replaced
                    if counted:                 #   name entered outside a record; a traced name (replaced here)
                        tr.bare[f"{nd.id} {name}"] += 1     # counted as sec61 counts its own; a tape name's
                    return fn(*args, **kw)                  #   call goes on no tape
                if not st["depth"] and name in replaced:    # a replaced name entered
                    if counted:                                                 #   outside any record:
                        tr.count_call(name, "outer")                            #   nothing inside it is a
                    st["supp"] += 1                                             #   record
                    try:
                        return fn(*args, **kw)
                    finally:
                        st["supp"] -= 1
                if not st["depth"] and counted:     # a traced name here, with no record open, is a replaced one
                    raise SystemExit(f"trace3: node {nd.id}: {name}, a traced name, reached the replaced names' "
                                     f"wrapper outside any record, not replaced here")
                if st["depth"] and st["ext"] and name in TIMER_KINDS and not NOTES_OFF[0]:     # a timer armed
                    r, note = tr.arm_timer(nd, name, fn, args, kw)          #   inside a question at this node:
                    st["notes"].append(note)                                #   a note of the outermost one
                    return r
            if not st["depth"] or st["ext"]:    # not asked by §6.1's own code
                if counted and st["ext"]:       # inside a question at the record's node
                    tr.count_call(name, "ext")
                return fn(*args, **kw)
            # under SEACAST, a replaced name the twin cannot ask (NOASK_Seacast), called by a record's own code: the twin would
            # run its own function there, where the node ran another
            if tr.doc_seacast and name in NOASK_Seacast:
                raise SystemExit(f"trace3: node {nd.id}: {name} is replaced here, and {st['cur']['fn']}'s record "
                                 f"calls it: the twin has no question for {name}, and would run its own code there")
            if counted:                         # a question asked by the record's own code, by its fn: one row on
                tr.count_call(name, "asked", st["cur"]["fn"])      # the record's tape (calls_seacast.py's asked)
            # the tracer's third state: what the rest of the node reads is behind the tape, but its
            # accesses of the own tables are logged apart, as the callee's `cr` and `cw`
            # under SEACAST an argument of EAGER_Seacast's is written as it was handed over: encoded here, before the call,
            # so that a callee that changes it does not change its form on the tape
            early = tr.at_call(name, enc, args, kw)
            st["ext"] += 1
            if tr.doc_seacast:
                st["notes"] = []
            rec.begin_callee()
            mesh_off()
            raised = None
            try:
                r = fn(*args, **kw)
            except Exception as e:              # a question that raises: on the tape, for CALLS
                raised = e
                raise
            finally:
                st["ext"] -= 1
                cr, cw = rec.end_callee()
                notes = st.pop("notes", [])
                mesh_on()
                if raised is not None and notes:
                    tr.raised_with_notes(nd, name, raised)
                if raised is not None and name in calls:
                    if cr or cw:
                        raise TypeError(f"trace3: {name} raised after touching the own tables")
                    st["cur"]["tape"].append([name, calls[name][0](*args, **kw), {"raises": type(raised).__name__}])
            row = tr.tape_row(enc, r, args, kw, early)
            st["cur"]["tape"].append([name, *row] + call_log(cr, cw, notes))
            return r
        return w

    def missing_key(self, miss, e=None):
        """The key a KeyError names, as a record writes it. Under seacast-lite.md a peer alone, as before. Under SEACAST a group
        is ["group", hex], an object type ["type", id], an integer itself or ["-", n] below zero (a peer, a family
        or a count). Any other key stops the tracer."""
        if self.doc_seacast:
            if isinstance(miss, bytes):
                return ["group", miss.hex()]
            if isinstance(miss, str) and miss:          # a type by its id (a table keyed by `T.id`)
                return ["type", miss]
            if isinstance(getattr(miss, "id", None), str):      # a type object (a table keyed by the type itself)
                return ["type", schema_seacast.type_id(miss)]
            if isinstance(miss, int) and not isinstance(miss, bool):
                return self.integer(miss)
            raise TypeError(f"trace3: a KeyError on a key that is neither a group, an object type nor an integer: "
                            f"{miss!r}") from e
        if not isinstance(miss, int):
            raise TypeError(f"trace3: a KeyError on a key that is not a peer: {miss!r}") from e
        return miss

    @staticmethod
    def flag(x, what):
        """A boolean of a SEACAST form: a Python bool, nothing else."""
        if not isinstance(x, bool):
            raise TypeError(f"trace3: {what} is not a boolean: {x!r}")
        return x

    def lookups_enc(self):
        """§4.5's two lookups, asked by on_want under both documents, in CALLS' form (arguments, answer): resolve(a),
        an ask by its key, answered by an id's hex or null; chunk_of(mid), by the id's hex, answered by a chunk as the
        twin reads one. install's table of the tape's calls and the forms rows (forms_seacast_examples.py) both
        write them by these."""
        return {"resolve": (lambda a: [self.key(a)], lambda r: None if r is None else r.hex()),
                "chunk_of": (lambda mid: [mid.hex()], self.chunk)}

    def ask_seacast(self, a):
        """An ask of a SEACAST IWANT: [key, standing, hops, probe]. A plain ask (a WantIndex, whose class holds the three
        as false, 0 and false) or a structured id (which carries none) is [key, false, 0, false]."""
        k = self.ask_key(a)
        if isinstance(a, bytes):
            return [k, False, 0, False]
        return [k, self.flag(a.standing, "an ask's standing"), self.nat(a.hops), self.flag(a.probe, "an ask's probe")]

    def holding(self, e):
        """A bitmap of a SEACAST IDONTWANT: ["holding", group, bits, claim_all, complete], its claims as they are."""
        return ["holding", e.group.hex(), self.nat(e.bits.v), self.flag(e.claim_all, "a holding's claim_all"),
                self.flag(e.complete, "a holding's complete")]

    def offer(self, e):
        """An entry of an IHAVE, under either document. An offer claims nothing: a bitmap offered with a claim set
        stops the tracer, as an IHAVE's form has no place for the claim (ihave_entry would drop it)."""
        if self.Wm.is_have_bitmap(e) and (e.claim_all or e.complete):
            raise SystemExit(f"trace3: an IHAVE offers a bitmap with a claim set (claim_all {e.claim_all!r}, "
                             f"complete {e.complete!r}): an offer claims nothing, and its form holds no claim")
        return self.ihave_entry(e)

    def rel_msg(self, m, kind=None):
        """A JOIN, a GRAFT or a PRUNE of SEACAST in schema_seacast.py's tagged form, in §2's field order:
        ["join", T, interest, custody_count, duty, colours], ["graft", T, family, colour, direction, answer],
        ["prune", T, family, colour, direction]; the enumerations as the toy's strings, the family signed. It goes
        by the fields, not the class: the toy holds a JOIN as the document's Join and as a wire Container (a
        peer's, set by node.py). A JOIN has interest and colours, a GRAFT a family and an answer, a PRUNE a family
        and none. Where the control's kind is given, the message's must be it."""
        has = functools.partial(hasattr, m)
        got = ("join" if has("interest") and has("colours") else "graft" if has("family") and has("answer")
               else "prune" if has("family") else None)
        if got is None:
            raise TypeError(f"trace3: not a JOIN, a GRAFT or a PRUNE of SEACAST: {m!r}")
        if kind is not None and kind != got:
            raise TypeError(f"trace3: a {kind} control holds a {got}: {m!r}")

        def word(x, what):
            if not isinstance(x, str) or not x:
                raise TypeError(f"trace3: a {got}'s {what} is not a word: {x!r}")
            return x
        t = word(m.object_type, "object type")
        if got == "join":
            return ["join", t, word(m.interest, "interest"), self.nat(m.custody_count), word(m.duty, "duty"),
                    self.nat(m.colours)]
        if m.direction not in schema_seacast.DIRECTIONS:
            raise TypeError(f"trace3: a {got}'s direction is none of {schema_seacast.DIRECTIONS}: {m.direction!r}")
        head = [got, t, self.integer(m.family), self.nat(m.colour), m.direction]
        return head + [self.flag(m.answer, "a GRAFT's answer")] if got == "graft" else head

    # ---- the checks of installed_block's answers and of pending
    def installed(self, slot, root, r):
        """installed_block's answer as the twin reads it (the block as level 1 reads it, or nothing), held to one
        answer, there or not, per (slot, root) in a record: on_validated and defer recurse at most twice only
        while the node answers the same way within one call; the twin's fuel relies on it, and a run that answers
        otherwise stops here. The answer is the block or nothing (§8's interface), and defer reads its truth: an
        answer that is neither (a False, say) would be read as a block here and as none by the Python, so it stops
        the run too."""
        if r is not None and not r:
            raise SystemExit(f"trace3: installed_block({slot}, {root.hex()[:16]}…) answered {r!r}: neither a block nor "
                             f"nothing, as §8's interface has it")
        got = r is not None
        was = self.ib.setdefault((int(slot), bytes(root)), got)
        if was != got:
            raise SystemExit(f"trace3: installed_block({slot}, {root.hex()[:16]}…) answered {was}, then {got}, in one "
                             f"record: the twin's recursion between on_validated and defer assumes one answer")
        return self.block(r) if got else None

    def pending_check(self, rec, nid):
        """No (peer, chunk) waits twice under one root (on_chunk's `mid in pending_ids` stands before defer). The
        twin removes a pair as Python's list.remove does, the first equal one, so a twice-kept pair would matter."""
        raw = rec.roots["pending"][1]
        for root in F._keys(raw):
            seen = set()
            for p, f in F._peek(raw, root):
                k = (int(p), bytes(self.mid_of(f)))
                if k in seen:
                    raise SystemExit(f"trace3: node {nid}: peer {p}'s copy {k[1].hex()[:16]}… waits twice under one "
                                     f"root")
                seen.add(k)

    def alias_check(self, rec, nid, args=(), when="end"):
        """No entry object stands in two places of the node's queue (two lanes, or twice in one), and no entry's
        control, or one of its messages, is another entry's too (drop_offer changes a message's ids in place). A
        value model would miss a change in place of one seen through the other, so a run that aliases stops here.

        Called at a record's start as well as at its end: an alias made outside any record, of which the call
        consumes one side (next_to_send pops one of two entries sharing a control and filters it), would leave one
        owner at the end, and the other lane's change unwritten. At the start, an entry the call is given
        (filter_entry's and with_owed's) counts as a place too."""
        raw = rec.roots["queue"][1]
        seen = {}

        def one(obj, what, at):
            w = seen.setdefault(id(obj), (what, at))
            if w != (what, at):
                raise SystemExit(f"trace3: node {nid}: one queue {what} stands in two places, {w[1]} and {at}, at "
                                 f"the record's {when}: the queue's values would miss a change of it in place")

        def entry(e, at):
            one(e, "entry", at)
            if e.control is not None:
                one(e.control, "entry's control", at)
                for j, m in enumerate(e.control.items):
                    one(m, "control message", at + (j,))
        for i, a in enumerate(args):            # the call's own entries
            if hasattr(a, "control") and hasattr(a, "chunk") and hasattr(a, "solicited"):
                entry(a, ("argument", i))
        for p in F._keys(raw):
            pq = F._peek(raw, p)
            for ln in ("urgent", "normal"):
                for k, e in enumerate(getattr(pq, ln)):
                    entry(e, (p, ln, k))

    def schema(self, ns):
        key = self.key

        def ghex(g):
            return g.hex()

        desc = self.descriptor          # the descriptor whole: the twin's code calls §1's N and K of it, and this
        #                                   encoder calls nothing

        # the twin's own tables: one line each in gen/schema.py; then the other sections' that §6.1 reads
        tables = schema.python_tables(F, key, fbits, lane=self.lane,
                                      waits=lambda w: [[int(p), self.wchunk(f)] for p, f in w] or None,
                                      jobs=lambda js: [[int(q), [key(m) for m in ids], fbits(at)]
                                                       for q, ids, at in js] or None, desc=desc) + [
            F.Table("known_id", [ghex, int], key, foreign=True),
            F.Table("chunks", [ghex, int], self.chunk, foreign=True),      # push_rebuilt's `chunks[g][i]`
        ]
        if self.doc_seacast:                 # a HaveEntry under SEACAST holds the two claims too (gen/schema.py writes §4.3's)
            have = {t.name for t in schema.TABLES if t.value == "have"}
            for t in tables:
                if t.name in have:
                    t.value = self.have_seacast
            # and seacast.md's own tables, as schema_seacast.py writes them (a JOIN, GRAFT or PRUNE as rel_msg does)
            tables += schema_seacast.python_tables_seacast(F, key, fbits, self.rel_msg)
        return tables

    def types_seacast(self, nd, ns):
        """The nodes entry's `types` under SEACAST: each object type `type_of_group` can answer at the node (the node's
        types, and the payload's, its answer for any other group), by id, with its parameters (seacast.md
        §6.3): naturals as numbers, booleans, floats as their 64-bit words (SERVE_LIMIT, FORWARD_LIMIT and
        MAX_RELATIONS may be +inf, MAX_RELATIONS a count where finite, every other float finite), ANNOUNCE_EXTRA as its word, EVIDENCE as null alone, REPAIR_SAMPLE as null
        or its [S, L] steps. A parameter the type lacks is left out, and the twin's read of it is the toy's
        AttributeError; the three functions (DECODE_AT_K, DECODE_LATER, REPAIR_TO) are questions on the tape."""
        tys = dict(getattr(nd, "_types", None) or {})
        p = getattr(nd, "_P", None)
        if not tys or p is None:
            raise SystemExit(f"trace3: node {nd.id}: the toy's object types are not where the tracer reads them "
                             f"(the node's _types and _P)")
        tys.setdefault(schema_seacast.type_id(p), p)
        out = {}
        for tid, T in sorted(tys.items()):
            if schema_seacast.type_id(T) != tid:
                raise SystemExit(f"trace3: node {nd.id}: the type under {tid!r} has the id {T.id!r}")
            off = closure_seacast.type_attrs_check(tid, T)       # its attributes are the closure check's list
            if off:
                raise SystemExit(f"trace3: node {nd.id}: " + "; ".join(off))
            out[tid] = self.type_params(nd, tid, T.params)
        return out

    @classmethod
    def params_schema(cls):
        """The type parameters' names the tracer gives a form (type_params): the closure rule's schema."""
        return set(cls.TYPE_NATS) | set(cls.TYPE_BOOLS) | set(cls.TYPE_FLOATS) | {"ANNOUNCE_EXTRA", "EVIDENCE",
                                                                                  "REPAIR_SAMPLE"}

    TYPE_NATS = ("M", "F_LO", "F_HI", "D_OUT", "D_OUT_FAST", "D_OUT_MAX", "SAMPLE_COVER", "COVER_HIGH", "ROUTE_HOPS",
                 "MAX_INDICES")
    TYPE_POSITIVE = ("M", "MAX_INDICES")    # naturals above 0: a type has one or more objects, a group one or more indices
    # §1.1's parameters the tracer checks and does not write: no function on the twin's lists reads them, and the
    # closure rule's schema (params_schema) leaves them out, so a covered function that read one would stop the
    # tracer. Each: (its bound's test, the words of a value outside it, why it is not written). None now.
    TYPE_UNWRITTEN = {}
    TYPE_BOOLS = ("SYMMETRIC", "EAGER", "REPAIR_BUDGET", "REPAIR_REASK")
    TYPE_FLOATS = ("PRUNE_BACKOFF", "START_DELAY", "SAMPLE_RETRY", "SAMPLE_RETRY2", "DEFER_WINDOW", "SAMPLE_WAIT",
                   "SERVE_LIMIT", "FORWARD_LIMIT", "MAX_RELATIONS")
    TYPE_UNBOUNDED = ("SERVE_LIMIT", "FORWARD_LIMIT", "MAX_RELATIONS")     # may be +inf, as STRIPE_UPLINK may
    # floats that count (§6.3's MAX_RELATIONS, an int in the document, +inf the toy's no limit): a finite value is
    # integral and at least 0; 0 is a link that may carry no pair (relation_limit_known.py's empty link)
    TYPE_COUNTS = ("MAX_RELATIONS",)
    TYPE_FUNCTIONS = ("DECODE_AT_K", "DECODE_LATER", "REPAIR_TO")
    ANNOUNCE_WIDTHS = ("ALL_JOINED", "SAMPLE", "NONE")

    @staticmethod
    def exact_float(v):
        """The float whose word holds v exactly, or None: v's type is int or float itself (no bool, no subclass, whose
        own comparisons would decide), float(v) is taken once, and it equals v. An int above 2^53 that a float rounds
        gives None, as does one too large for any float (OverflowError), and a NaN."""
        if type(v) not in (int, float):
            return None
        try:
            f = float(v)
        except OverflowError:
            return None
        return f if f == v else None

    @staticmethod
    def shown(v):
        """A value in a stop's words, bounded: an int too long for this Python to print (ValueError) as its size in
        bits, another value it cannot print (a list holding such an int) as so, and a longer repr cut to its first
        100 characters."""
        try:
            s = repr(v)
        except ValueError:
            return f"an int of {v.bit_length()} bits" if type(v) is int else "a value too long to print"
        return s if len(s) <= 120 else f"{s[:100]}… ({len(s)} characters)"

    def type_params(self, nd, tid, prm):
        """One type's parameters, each in its form (types_seacast); a parameter of no listed kind stops the tracer, so
        that a new one is given its form before a trace holds it."""
        def stop(name, v, what):
            raise SystemExit(f"trace3: node {nd.id}: type {tid}: {name} is {what}: {self.shown(v)}")
        out = {}
        for name, v in sorted(vars(prm).items()):
            if name in self.TYPE_FUNCTIONS:
                continue
            if name in self.TYPE_UNWRITTEN:
                ok, words, _ = self.TYPE_UNWRITTEN[name]
                if not ok(v):
                    stop(name, v, words)
                continue
            if name in self.TYPE_NATS:
                if type(v) is not int or v < 0 or (name in self.TYPE_POSITIVE and v == 0):
                    stop(name, v, "no natural" + (" above 0" if name in self.TYPE_POSITIVE else ""))
                out[name] = v
            elif name in self.TYPE_BOOLS:
                if not isinstance(v, bool):
                    stop(name, v, "no boolean")
                out[name] = v
            elif name in self.TYPE_COUNTS:
                f = self.exact_float(v)
                if f is None or (math.isinf(f) and f < 0) or (math.isfinite(f) and (f < 0 or not f.is_integer())):
                    stop(name, v, "no count nor +inf")
                out[name] = fbits(f)
            elif name in self.TYPE_FLOATS:
                f = self.exact_float(v)
                if f is None or (math.isinf(f) and not (f > 0 and name in self.TYPE_UNBOUNDED)):
                    stop(name, v, "no finite number" + (" nor +inf" if name in self.TYPE_UNBOUNDED else ""))
                out[name] = fbits(f)
            elif name == "ANNOUNCE_EXTRA":
                if v not in self.ANNOUNCE_WIDTHS:
                    stop(name, v, f"none of {self.ANNOUNCE_WIDTHS}")
                out[name] = v
            elif name == "EVIDENCE":
                if v is not None:
                    stop(name, v, "an evidence type, which no trace holds")
                out[name] = None
            elif name == "REPAIR_SAMPLE":
                if v is None:
                    out[name] = None
                else:
                    steps = [list(s) for s in v]
                    if not steps or any(len(s) != 2 or any(isinstance(x, bool) or not isinstance(x, int) or x < 0
                                                           for x in s) for s in steps):
                        stop(name, v, "neither none nor a list of [S, L] steps of naturals")
                    out[name] = steps
            else:
                stop(name, v, "a parameter the tracer does not know")
        return out

    @staticmethod
    def consts_seacast(nd, ns):
        """The node's constants that seacast.md adds, in the nodes line's order, as the namespace holds them after
        load: ANSWERS_FIRST and MERGE_HOLDINGS (booleans); ASK_UPLINK (bits per second: finite, not negative, 0 never
        scales); SAMPLE_OUTSTANDING (the second phase's asks in flight per block, across types: a count of at least
        1); SERVE_BUDGET (answers to one peer a heartbeat: a count of at least 1, or +inf for none, written null).
        Anything else stops the tracer, in the constant's words."""
        out = {}
        for c in ("ANSWERS_FIRST", "MERGE_HOLDINGS"):
            if not isinstance(ns[c], bool):
                raise SystemExit(f"trace3: node {nd.id}: {c} is no boolean: {ns[c]!r}")
            out[c] = ns[c]
        u = ns["ASK_UPLINK"]
        if isinstance(u, bool) or not isinstance(u, (int, float)) or not math.isfinite(u) or u < 0:
            raise SystemExit(f"trace3: node {nd.id}: ASK_UPLINK is no finite rate: {u!r}")
        out["ASK_UPLINK"] = fbits(u)
        s = ns["SAMPLE_OUTSTANDING"]
        if isinstance(s, bool) or not isinstance(s, int) or s < 1:
            raise SystemExit(f"trace3: node {nd.id}: SAMPLE_OUTSTANDING is no count of at least 1: {s!r}")
        out["SAMPLE_OUTSTANDING"] = s
        b = ns["SERVE_BUDGET"]          # as the client's limits are written (a whole float is its int), but a bool
        if isinstance(b, float) and math.isinf(b) and b > 0:   # or a value below 1 stops
            out["SERVE_BUDGET"] = None
            return out
        try:
            whole = not isinstance(b, bool) and b >= 1 and b == int(b)
        except (OverflowError, ValueError, TypeError):
            whole = False
        if not whole:
            raise SystemExit(f"trace3: node {nd.id}: SERVE_BUDGET is no count of at least 1 nor +inf: {b!r}")
        out["SERVE_BUDGET"] = int(b)
        return out

    def have_seacast(self, e):
        """`peer_has`'s entry under SEACAST: [bits, ttl, claim_all, complete], the claims a holding carried."""
        return [self.nat(e.bits.v), self.nat(int(e.ttl)), self.flag(e.claim_all, "a HaveEntry's claim_all"),
                self.flag(e.complete, "a HaveEntry's complete")]

    # ---- the wrappers, per node
    def install(self, nd, ns):
        self.source_offers_check(nd)
        consts = {c: fbits(ns[c]) for c in CONSTS}
        for c in LIMITS + ("MAX_PLAIN_CHUNKS", "FAN_IN"):     # each a count (a limit may be +inf, none): int() of
            v = ns[c]                                          #   anything else would cut it without a word
            if c in LIMITS and isinstance(v, float) and math.isinf(v) and v > 0:
                continue
            try:
                whole = v >= 0 and v == int(v)
            except (OverflowError, ValueError, TypeError):
                whole = False
            if not whole:
                raise SystemExit(f"trace3: node {nd.id}: {c} is no count: {v!r}")
        consts.update({c: None if math.isinf(ns[c]) else int(ns[c]) for c in LIMITS})
        consts["MAX_PLAIN_CHUNKS"] = int(ns["MAX_PLAIN_CHUNKS"])            # §2, read by valid_id
        consts.update({c: bool(ns[c]) for c in CARDS})                     # the writer's cards
        consts["FAN_IN"] = int(ns["FAN_IN"])
        consts.update({c: self.nat(ns[c]) for c in ("UNIT", "MAX_CHUNKS", "MAX_SEGMENT_SIZE")})   # §1's
        consts.update({c: fbits(ns[c]) for c in ("HEARTBEAT", "GOSSIP_FACTOR")})   # §6.4's
        consts["D_LAZY"] = self.nat(ns["D_LAZY"])
        consts["PACED"] = bool(ns["PACED"])                                # [c15]
        consts["HAVE_TTL"] = self.nat(ns["HAVE_TTL"])                      # §4.3's
        consts["GOSSIP_RETRANSMISSION"] = self.nat(ns["GOSSIP_RETRANSMISSION"])     # §4.5's (stock)
        consts["DESCRIPTOR_IN_CHUNK"] = bool(ns["DESCRIPTOR_IN_CHUNK"])    # §3's choice of design
        consts["PUSH_TTL"] = self.nat(ns["PUSH_TTL"])                      # §5.2's (note_push)
        consts["R"] = self.nat(ns["R"])                                    # §5.1's copies a chunk [c2]
        consts["R_NODE"] = self.nat(ns["R_NODE"])                          # §5.3's guard; by a node's uplink
        consts["GUARD_GRACE"] = fbits(ns["GUARD_GRACE"])                   #   class [c17]
        consts["UPLINK"] = fbits(ns["UPLINK"])                             # §5.1's stripe [c13]; the
        consts["STRIPE_UPLINK"] = fbits(ns["STRIPE_UPLINK"])               #   threshold infinite where card 13 is off
        w = ns.get("W", math.inf)                                          # §7.1's window; none where the
        if not math.isinf(w) and (w != int(w) or w < 0):                   #   node has none (card 14 off)
            raise SystemExit(f"trace3: node {nd.id}: W is no count of slots: {w!r}")
        consts["W"] = None if math.isinf(w) else int(w)
        consts["WINDOW_TIMEOUT"] = fbits(ns["WINDOW_TIMEOUT"])
        if ns["SOURCE_OFFERS"] not in ("ACK", "PUBLISH"):                  # v0.10.4: §5.1's choice of when the
            raise SystemExit(f"trace3: node {nd.id}: SOURCE_OFFERS is {ns['SOURCE_OFFERS']!r}")   # source announces
        consts["SOURCE_OFFERS"] = ns["SOURCE_OFFERS"]
        types = None
        if self.doc_seacast:     # SEACAST's five more, as the namespace holds them after load; and the node's object types
            # the closure rule's lists held to what the node runs: first the enumerations, which a namespace before
            # `_seacast` lacks, as it lacks the constants `_seacast` binds (SAMPLE_OUTSTANDING); then the nodes line's constants
            off = closure_seacast.enum_check(ns)
            if not off:
                consts.update(self.consts_seacast(nd, ns))
                off = closure_seacast.consts_keys_check(consts)
            if off:
                raise SystemExit(f"trace3: node {nd.id}: the closure rule's lists and the node differ: " + "; ".join(off))
            types = self.types_seacast(nd, ns)
            self.type_nodes.append((nd, ns, types))     # read again by final_check
        # what each traced name is at this node, and the node's own line: under SEACAST by the chain rule over its layers
        replaced, chains = [], None
        if self.doc_seacast:
            try:
                replaced, chains = node_chains(self.traced, ns, self.whole, replaceable=REPLACEABLE_Seacast)
            except ChainStop as e:
                raise SystemExit(f"trace3: node {nd.id}: {e}")
        for name in () if self.doc_seacast else self.traced:
            what, where = own_code(name, ns.get(name))
            if what == "replaced" and name in REPLACEABLE_WHOLE and not self.whole:
                raise SystemExit(f"trace3: node {nd.id}: {name} is something else than the document's here ({where}), "
                                 f"which only a trace of the whole state may have: a directed set's scenario")
            if what == "replaced" and name in REPLACEABLE:
                replaced.append(name)
            elif what != "own":
                raise SystemExit(f"trace3: node {nd.id}: {name} is traced, and its function here is neither "
                                 f"seacast-lite.md's own code nor a listed wrapper of it: {where}")
        if self.nodes_written:
            raise SystemExit(f"trace3: node {nd.id} is installed after the trace's first record: its line cannot be "
                             f"written before its records")
        self.nodes.append((int(nd.id), consts, sorted(replaced), types, chains))
        self.WAIT = ns["WAIT"]                                               # next_to_send's "in line" (§7.2)
        if self.doc_message_id is None:     # the document's function, from the toy's wrapper's closure (own_code
            mid_fn = ns["message_id"]       #   found it there, or found the name to be the document's own)
            if getattr(getattr(mid_fn, "__code__", None), "co_filename", None) != DOC_FILE:
                mid_fn = next(c.cell_contents for c in mid_fn.__closure__ or ()
                              if getattr(getattr(c.cell_contents, "__code__", None), "co_filename", None) == DOC_FILE
                              and c.cell_contents.__code__.co_name == "message_id")
            self.doc_message_id = mid_fn
        mid_fn = ns["message_id"]           # and each node's own, by the same way
        if getattr(getattr(mid_fn, "__code__", None), "co_filename", None) != DOC_FILE:
            mid_fn = next(c.cell_contents for c in mid_fn.__closure__ or ()
                          if getattr(getattr(c.cell_contents, "__code__", None), "co_filename", None) == DOC_FILE
                          and c.cell_contents.__code__.co_name == "message_id")
        self.doc_mid[int(nd.id)] = mid_fn
        rec = F.Recorder()
        if self.doc_seacast:
            rec.row_reads = frozenset(ROW_READS_Seacast)
        views = [t for t in self.schema(ns) if not (self.doc_seacast and t.name in WINDOW)]
        F.install(rec, ns, views)
        window = {} if self.doc_seacast else {name: ns[name] for name in WINDOW}    # the installed cell and views: each
        #                                                                         record's end checks they are still there
        st = self.vst if self.doc_seacast else {"depth": 0, "ext": 0, "cur": None}
        key, tr = self.key, self
        if self.doc_seacast:     # an observer's own code that arms a timer by the simulator itself stops as one that arms it
            self.rec_of[int(nd.id)] = rec   # through the namespace: the simulator's `after` wrapped once (sim_guard);
            sim = nd.sim                    # an observer runs only inside a record, at the open record's node
            if not getattr(vars(sim).get("after"), "_trace3_guard", False):
                sim.after = sim_guard(sim.after, lambda: getattr(tr.rec_of.get(st["node"]), "observer", None)
                                      if st["depth"] else None)
        if self.doc_seacast:     # seacast.md's own tables are views over the toy's own objects (`hdr` is pointed at
            for name in OWN_Seacast:     # desc's by repoint_aliases); and interest's miss is the question own_interest
                if not isinstance(ns.get(name), F.View) or ns[name]._o is not rec.roots[name][1]:
                    raise SystemExit(f"trace3: node {nd.id}: {name} is not a view of the toy's table after the install")
            if not hasattr(type(rec.roots["interest"][1]), "__missing__"):
                raise SystemExit(f"trace3: node {nd.id}: interest answers no missing group here (the toy's "
                                 f"InterestMap does, by own_interest_bits)")

            def enter():                    # around the question, as around any other (iface_of)
                st["ext"] += 1
                st["notes"] = []
                mesh_off()

            def leave():
                st["ext"] -= 1
                mesh_on()
                return st.pop("notes", [])
            ns["interest"] = MissQuestionView(ns["interest"], miss_question(rec, enter, leave))

            order_note = order_writer(rec, st, lambda: tr.order_on, nd.id)
            ns["standing"] = OrderPopView(ns["standing"], order_note)

        def own_call(name, fn, args, kw):   # the name's own function in a record: class 6's mode where observed
            ob = obs_of.get(name)
            return fn(*args, **kw) if ob is None else observe(rec, ob, fn, args, kw, mesh_on, mesh_off)

        def sec61(name, fn):
            @functools.wraps(fn)
            def w(*args, **kw):
                if tr.doc_seacast and rec.observer is not None:  # called by an observer's own code (class 6): not the
                    tr.count_call(name, "observer")         #   record's, run bare, its reads unlogged, a write a stop
                    return fn(*args, **kw)
                if tr.doc_seacast and (st["supp"] or (st["depth"] and st["node"] != int(nd.id))):
                    if st["supp"] or st["ext"]:     # inside a question at another node, or inside a replaced name
                        tr.bare[f"{nd.id} {name}"] += 1     # entered outside any record: bare, and counted
                        r = fn(*args, **kw)
                        if name == "message_id":    # m2_check there too, as in any other bare call
                            tr.m2_check(args[0], r, nd.id)
                        return r
                    raise SystemExit(f"trace3: node {nd.id}: {name} is called while node {st['node']}'s record is "
                                     f"open and no question runs")
                if st["ext"]:                       # inside an interface call: not §6.1's own call
                    if tr.doc_seacast:
                        tr.count_call(name, "ext")
                    r = fn(*args, **kw)
                    if name == "message_id":        # m2_check there too: the node's store asks it
                        tr.m2_check(args[0], r, nd.id)
                    return r
                if st["depth"]:
                    st["reached"].add(name)
                    iw = tr.doc_seacast and name in IW_NAMES
                    if tr.doc_seacast:                   # a call inside the open record, by its fn
                        tr.count_call(name, "in", st["cur"]["fn"])
                    if iw:                          # and its IWANTs, from the rows the tape gains while it runs
                        tr.iw_enter(name)
                        k = len(st["cur"]["tape"])
                    st["depth"] += 1
                    if name == "defer":             # a record's chain of defers, bounded as the
                        st["defers"] += 1           #   twin's fuel (deferDepth) is
                        if st["defers"] > DEFER_DEPTH:
                            raise SystemExit(f"trace3: node {nd.id}: a chain of {st['defers']} defers in one record, "
                                             f"past the twin's {DEFER_DEPTH} (deferDepth)")
                    try:
                        r = own_call(name, fn, args, kw)
                        if name == "message_id":    # its content_id, a question at every call
                            tr.content_id_asked(st["cur"]["tape"], args[0], r, nd.id)
                        if tr.doc_seacast and name == "suppression_scope":   # the set the caller iterates, its order
                            return OrderProxy(r, order_note)            #   asked there (a record of its own is not)
                        return r
                    finally:
                        st["depth"] -= 1
                        if name == "defer":
                            st["defers"] -= 1
                        if iw:
                            tr.iw_leave(name, "in", st["cur"]["tape"], k, st["cur"]["fn"])
                found = {}                          # under SEACAST every installed slot checked at the record's entry, a
                if tr.doc_seacast:                       #   draw the toy has bound re-wrapped for the record (K13)
                    found = rewrap_draws(ns, slots, rewrap)
                    bindings_check(nd.id, ns, slots, found, name, "entry")
                if not tr.nodes_written:            # the nodes line, before the first record
                    tr.write_nodes()
                tr.cur_queue = F.unwrap(ns["queue"])    # rarest's peer, by its queue (args_of)
                tr.cur_nid = int(nd.id)
                r_ = {"n": nd.id, "t": fbits(ns["now"]), "fn": name, "args": tr.args_of(name, args, kw), "tape": []}
                tr.ib = {}                          # installed_block's answers in this record
                tr.built_objs = {}                  # the chunks this record's publish built and stored
                before = rec.snapshot() if tr.whole else None

                def finish(**out):
                    rec.on = False
                    if tr.doc_seacast and name in IW_NAMES:      # its IWANTs, from its whole tape
                        tr.iw_leave(name, "record", r_["tape"], 0)
                    if tr.doc_seacast:                   # and at its exit, with the toy's draws put back where the
                        for d, cur in found.items():    # re-wrap still holds them
                            if getattr(ns.get(d), "_trace3_rewrap", False):
                                ns[d] = cur
                        bindings_check(nd.id, ns, slots, found, name, "exit")
                    for wname, wobj in window.items():      # a name of the window's rebound to another object
                        if ns[wname] is not wobj:           #   would go on unlogged
                            raise SystemExit(f"trace3: node {nd.id}: {wname} no longer holds the tracer's own object "
                                             f"at the end of {name}: {type(ns[wname]).__name__}")
                    r_["reads"], r_["scans"], r_["writes"] = rec.footprint()
                    r_["rest"] = rec.rest(tr.whole)
                    if tr.whole:
                        tr.account(rec, r_, before)
                    tr.rest_total += len(r_["rest"])
                    r_.update(out)
                    # last, in this order: which traced functions the call reached, itself among them, and which
                    # of the own tables it touched. The replay checks both; a mutant is replayed only on the
                    # records that name its function or its table (mutants3.py), picked by these two members
                    r_["reached"] = sorted(st["reached"])
                    r_["tables"] = sorted({e[0] for e in r_["reads"]} | {s[0] for s in r_["scans"]}
                                          | {e[0] for e in r_["writes"]})
                    if "queue" in r_["tables"]:      # the queue as values holds only where no entry is aliased
                        tr.alias_check(rec, nd.id)
                    if "pending" in r_["tables"]:    # no copy waits twice under one root
                        tr.pending_check(rec, nd.id)
                    tr.counts[name + (" (raises)" if "raises" in out else "")] += 1
                    tr.write(r_)

                rec.clear()
                if "queue" in rec.roots:            # before the call too, with its own entries, so
                    tr.alias_check(rec, nd.id, args, "start")   # that an alias the call consumes cannot hide
                rec.tape = r_["tape"]
                st["cur"], st["depth"], st["reached"], st["defers"] = r_, 1, {name}, 1 if name == "defer" else 0
                if tr.doc_seacast:
                    st["node"] = int(nd.id)
                    tr.count_call(name, "record")
                    if name in IW_NAMES:
                        tr.iw_enter(name)
                mesh_on()
                rec.on = True
                if name == "rarest" or (tr.doc_seacast and name in ("choose", "pick")):  # SEACAST's choose passes the raw
                    #                             queue it took outside a record, and next_to_send passes choose
                    #                             its own; the view of queue[p] logs the read of the lane
                    args = (ns["queue"][r_["args"][0]],) + tuple(args[1:])
                try:
                    r = own_call(name, fn, args, kw)
                    if name == "message_id":        # its content_id, a question at every call
                        tr.content_id_asked(r_["tape"], args[0], r, nd.id)
                except Exception as e:              # written with the state it left; the exception goes on
                    if isinstance(e, KeyError):     # which key was missing: the place it raised
                        (miss,) = e.args
                        finish(raises=type(e).__name__, raises_key=tr.missing_key(miss, e))
                    else:
                        finish(raises=type(e).__name__)
                    raise
                finally:
                    rec.on = False
                    mesh_off()
                    st["depth"], st["cur"] = 0, None
                    if tr.doc_seacast:
                        st["node"] = None
                finish(ret=tr.ret_of(name, r))
                return r
            return w

        def mesh_on():                              # the block's code sees `mesh` as the question it asks,
            m = ns.get("mesh")                      #   and the gossip history as the node's
            if isinstance(m, set):
                ns["mesh"] = MeshQuestion(m, lambda: st["cur"]["tape"])
            h = ns.get("gossip_history")
            if h is not None and not isinstance(h, GossipQuestion):
                ns["gossip_history"] = GossipQuestion(h, lambda: st["cur"]["tape"], key, tr.chunk)

        def mesh_off():                             # and everything else, the set and the history themselves
            m = ns.get("mesh")
            if isinstance(m, MeshQuestion):
                ns["mesh"] = m.m
            h = ns.get("gossip_history")
            if isinstance(h, GossipQuestion):
                ns["gossip_history"] = h.h

        enc = {     # the tape's calls: TAPE's names, and only those (checked below)
            "expired": lambda r, g: [[g.hex()], bool(r)],
            "connected_topic_peers": lambda r: [[], list(r)],
            "own_order": lambda r, xs, a: [[list(xs), key(a)], list(r)],
            "listed": lambda r, p: [[p], int(r)],
            "authenticable": lambda r, g: [[g.hex()], bool(r)],
            # a draw of ask keys; of peers (the mesh: its own order was put on the tape where shuffled read it)
            # or of indices (push_rebuilt's)
            "shuffled": lambda r, xs: [[[tr.drawn(a) for a in (xs.m if isinstance(xs, MeshQuestion) else xs)]],
                                       [tr.drawn(a) for a in r]],
            "valid_have": lambda r, e: [[tr.offer(e)], bool(r)],          # asked by on_ihave of a bitmap
            "penalise": lambda r, p: [[p], None],
            "enqueue": tr.enqueue_enc,
            "after": lambda r, delay, fn, *args: [tr.after_row(delay, fn, *args), None],
            # §4.2
            "seen": lambda r, m: [[m.hex()], bool(r)],
            "accepted": lambda r, m: [[m.hex()], bool(r)],
            "mark_seen": lambda r, m: [[m.hex()], None],
            "live": lambda r, slot: [[int(slot)], bool(r)],
            "open_group": lambda r, g, f: [[g.hex(), tr.chunk(f)], None],
            # (in a publish record the chunk stored is one the block built: written as built)
            "store": lambda r, g, i, f: [[g.hex(), int(i), tr.built(f) if st["cur"]["fn"] == "publish" else tr.chunk(f)],
                                         None],
            "start": lambda r, fn, g: [[fn.__name__, g.hex()], None],
            # the deferral path's questions (defer and tie are the twin's own)
            "installed_block": lambda r, slot, root: [[int(slot), root.hex()], tr.installed(slot, root, r)],
            "admitted": lambda r, p, x: [[p, tr.admitted_arg(x)], bool(r)],
            "reserve": lambda r, p, f: [[p, tr.chunk(f)], bool(r)],
            "release": lambda r, p, f: [[p, tr.chunk(f)], None],
            "bid_group": lambda r, root: [[root.hex()], None if r is None else r.hex()],
            # the writer's questions and calls
            "has_room": lambda r, p: [[p], bool(r)],
            "pop_owed_answer": lambda r, p: [[p], tr.chunk(r)],
        }
        blobs = lambda xs: [tr.blob(x) for x in xs]     # noqa: E731
        calls = {   # CALLS' questions: how each one's arguments, and its answer, are written
            "sha256": (lambda b: [b.hex()], lambda r: r.hex()),
            "serialize": (lambda d: [tr.descriptor(d)], lambda r: r.hex()),
            "snappy_block_encode": (lambda b: [tr.blob(b)], tr.blob),
            "pad_each": (lambda segs, size: [blobs(segs), tr.nat(size)], blobs),
            "rs_parity": (lambda segs, k: [blobs(segs), tr.nat(k)], blobs),
            "merkle_root": (lambda leaves: [blobs(leaves)], lambda r: r.hex()),
            "merkle_proof": (lambda leaves, i: [blobs(leaves), tr.nat(i)], lambda r: [x.hex() for x in r]),
            # §6.4's
            "connected": (lambda q: [int(q)], tr.boolean),
            "group_bits": (lambda ids: [[key(m) for m in ids]], lambda r: [[g.hex(), b.v] for g, b in r]),
            "topic_peers": (lambda: [], lambda r: [int(q) for q in r]),
            "gossip_eligible": (lambda q: [int(q)], tr.boolean),
            "sample_without_replacement": (lambda xs, k: [[int(q) for q in xs], tr.nat(k)], lambda r: [int(q) for q in r]),
            # §4.6's, on_iwant's and on_frame's
            "close_promises_of_group": (lambda g: [g.hex()], tr.nothing),
            "discard_queued": (lambda g: [g.hex()], tr.nothing),
            "discard_paced": (lambda g: [g.hex()], tr.nothing),
            **tr.lookups_enc(),     # resolve and chunk_of (forms_seacast_examples.py makes their rows by these)
            "handle_graft_prune": (lambda p, frame: [int(p)], tr.no_prunes),
            # decode_group's and push_rebuilt's
            "decode_and_reencode": (lambda cg, d: [tr.store_group(cg), tr.descriptor(d)], tr.rebuilt),
            "payload_of": (lambda rebuilt: [tr.rebuilt(rebuilt)], tr.payload),
            "deliver": (lambda g, payload: [g.hex(), tr.payload(payload)], tr.nothing),
            "wake": (lambda p: [int(p)], tr.nothing),               # owe's
            "writing": (lambda p: [int(p)], tr.boolean),            # the window's front's
            # the push order's keys: a chunk's tie-break for a peer (asked by the chunk's id), a number;
            # a peer's id, bytes
            "tiebreak": (lambda f, p: [tr.mid_of(f).hex(), int(p)], tr.nat),
            "peer_id_bytes": (lambda p: [int(p)], lambda r: bytes(r).hex()),
            "verify_merkle_proof": (lambda root, data, index, count, proof:
                                    [root.hex(), tr.blob(data), tr.nat(index), tr.nat(count), [x.hex() for x in proof]],
                                    tr.boolean),
            "block_root": (lambda b: [tr.block(b)], lambda r: bytes(r).hex()),     # publish's
        }
        if set(calls) != set(CALLS):
            raise SystemExit(f"trace3: the questions with their own encoders are not CALLS': {sorted(set(calls) ^ set(CALLS))}")
        if set(EAGER_Seacast) & set(calls):      # a question's raise writes its arguments as they are at exit (iface)
            raise SystemExit(f"trace3: EAGER_Seacast and CALLS share {', '.join(sorted(set(EAGER_Seacast) & set(calls)))}: a "
                             "question's raise writes its arguments as at exit")
        if tr.doc_seacast:       # a draw over records (keep_floor's floor candidates) as well as over peers
            calls["sample_without_replacement"] = tr.swr_seacast()
        for name, (ea, er) in calls.items():
            enc[name] = lambda r, *a, _ea=ea, _er=er: [_ea(*a), _er(r)]
        if tr.doc_seacast:       # seacast.md's questions of the namespace, and seacast-lite.md's two in their SEACAST forms
            enc.update(tr.questions_enc_seacast(ns["Have"]))
        # the namespace must agree with the documents' source: no traced function of seacast-lite.md's (a kept one) is
        # SEACAST's, and under --doc seacast every name of the block and of SEACAST's covered names that SEACAST defines is SEACAST's here
        # (two derivations of the set, each checking the other)
        if tr.doc_seacast:       # under SEACAST the tape's names are TAPE's, the manifest's QUESTIONS and its CUT (a question
            #                 at every node), but those an adapter writes (TYPE_QUESTIONS_Seacast and the params' are the
            #                 types')
            want = (set(TAPE) | set(manifest_seacast.QUESTIONS) | set(manifest_seacast.CUT)) - set(ADAPTED_Seacast)
            have = set(enc) | set(TYPE_QUESTIONS_Seacast) | set(self.TYPE_FUNCTIONS)
            if have != want:
                raise SystemExit(f"trace3: the tape's calls are not TAPE's and the manifest's QUESTIONS and CUT: "
                                 f"{sorted(have ^ want)}")
        elif set(enc) != set(TAPE):
            raise SystemExit(f"trace3: the tape's calls are not TAPE's: {sorted(set(enc) ^ set(TAPE))}")
        if tr.doc_seacast:
            why = namespace_check(BLOCK + tuple(n for n in manifest_seacast.COVERED if n not in BLOCK), tr.kept,
                                  tr.seacast_defs, ns, replaceable=REPLACEABLE_Seacast, layers=True)
        else:
            why = namespace_check(BLOCK, tr.traced, tr.seacast_defs, ns)
        if why:
            raise SystemExit(f"trace3: node {nd.id}: {why}")
        if tr.doc_seacast:
            tr.unscanned_check(nd, ns)
        # a traced name this node runs as something else: the node's, a call on the tape where the block's
        # code calls it (on_frame's on_iwant), with its log; never a record
        replaced_enc = {"forward": lambda r, f, p: [[tr.chunk(f), int(p)], tr.nothing(r)],
                        "on_iwant": lambda r, p, iw: [[int(p), [tr.ask_key(a) for a in iw.ids]],
                                                      [tr.chunk(f) for f in r]],
                        "push_rebuilt": lambda r, g, new: [[g.hex(), [tr.nat(i) for i in new]], tr.nothing(r)],
                        "validate_chunk": lambda r, f: [[tr.chunk(f)], r]}
        if tr.doc_seacast:   # under SEACAST: the eight the twin asks, in its forms (asked_enc_seacast); on_iwant, a kept name, and the
            #             directed sets' validate_chunk in seacast-lite.md's; and no form for a name the twin cannot ask
            #             (iface_of stops a record's own call of one)
            replaced_enc = ({n: replaced_enc[n] for n in ("on_iwant", "validate_chunk")} | tr.asked_enc_seacast()
                            | {n: None for n in NOASK_Seacast})
            if set(replaced_enc) != set(REPLACEABLE_Seacast):
                raise SystemExit(f"trace3: the replaceable names' encoders are not REPLACEABLE_Seacast's: "
                                 f"{sorted(set(replaced_enc) ^ set(REPLACEABLE_Seacast))}")
        elif set(replaced_enc) != set(REPLACEABLE):
            raise SystemExit("trace3: the replaceable names' encoders are not REPLACEABLE's")
        iface = functools.partial(tr.iface_of, nd, st, rec, replaced, calls, mesh_on, mesh_off)

        def rewrap(d, cur):                 # a draw the toy bound during a call: the question it is, while bound
            w = iface(d, cur, enc[d])
            w._trace3_rewrap = True
            return w

        def swap_shim(inner):               # what a swapped draw's layer calls in place of the function it holds:
            def shim(*a, **k):              #   the draw it has bound re-wrapped around that call (K13)
                found = rewrap_draws(ns, slots, rewrap)
                try:
                    return inner(*a, **k)
                finally:
                    for d, cur in found.items():
                        if getattr(ns.get(d), "_trace3_rewrap", False):
                            ns[d] = cur
            shim._trace3_through, shim.__wrapped__ = True, inner
            return shim
        obs_of = {}                         # class 6: each handled name's outermost observer (sec61 enters the mode)
        if tr.doc_seacast:                       # each swapped draw's layer, by its key in LAYERS (the chain rule has
            for name in tr.traced:          #   passed every layer): its cell that holds the next layer, the shim
                ls = layers_of(name, ns[name])
                for f, nxt in zip(ls, ls[1:]):
                    if LAYERS.get(layer_key(f), (None, None))[1] == SWAPPED_DRAW:
                        cell_holding(f, nxt).cell_contents = swap_shim(nxt)
                ob, obs = rewrap_observers(rec, nd.id, name, ls, mesh_on, mesh_off)
                if ob is not None:          # then each observer chain's cells: the hand-overs (rewrap_observers)
                    obs_of[name] = ob
                    tr.observers.extend(obs)
        for name in tr.traced:
            ns[name] = iface(name, ns[name], replaced_enc[name]) if name in replaced else sec61(name, ns[name])
        for name, e in enc.items():
            ns[name] = iface(name, ns[name], e)
        if tr.doc_seacast:       # each object type's functions and its parameters' three, questions at this node: the
            tys = dict(nd._types)               # types are the node's own objects (the toy makes them per node);
            tys.setdefault(schema_seacast.type_id(nd._P), nd._P)     # one already wrapped is shared, and stops
            for T in tys.values():
                for obj, encs in ((T, tr.type_enc_seacast(T)), (T.params, tr.param_enc_seacast(T))):
                    for a, e in encs.items():
                        f = getattr(obj, a, None)
                        if f is None:           # a parameter the type lacks: the twin's read is the toy's
                            continue            #   AttributeError (types_seacast)
                        if getattr(f, "_trace3_q", False):
                            raise SystemExit(f"trace3: node {nd.id}: the type {tr.tid(T)}'s {a} is wrapped already: "
                                             f"a type another node shares")
                        w = iface(a, f, e)
                        w._trace3_q = True
                        setattr(obj, a, w)
                        tr.type_slots.append((nd, obj, a, w))
        slots = {name: ns[name] for name in tr.traced}          # for final_check: the traced names; under SEACAST,
        if tr.doc_seacast:                                           #   where the install is the namespace's last
            slots.update({name: ns[name] for name in enc})      #   binding, every installed slot (the tape
            slots.update({t.name: ns[t.name] for t in views})   #   names and the views) too
        tr.bound.append((nd, ns, slots))


class GossipQuestion:
    """The gossip history as the block's own code sees it: the node's. `gossip_ids()` is a question on the tape
    with its answer, ["gossip_ids", [], [id...]]. Any other use raises."""
    __slots__ = ("h", "tape", "key", "chunk")

    def __init__(self, h, tape, key, chunk):
        self.h, self.tape, self.key, self.chunk = h, tape, key, chunk

    def put(self, f):                   # forward's `gossip_history.put(f)`, a call that returns
        r = self.h.put(f)               #   nothing
        if r is not None:
            raise TypeError(f"trace3: gossip_history.put returned {r!r}")
        self.tape().append(["gossip_put", [self.chunk(f)], None])

    def gossip_ids(self):
        r = self.h.gossip_ids()
        self.tape().append(["gossip_ids", [], [self.key(m) for m in r]])
        return r

    def remove_group(self, g):          # drop_group's: the stock cache's, a call that returns nothing
        r = self.h.remove_group(g)
        if r is not None:
            raise TypeError(f"trace3: gossip_history.remove_group returned {r!r}")
        self.tape().append(["gossip_remove_group", [g.hex()], None])


class MeshQuestion:
    """`mesh` as the block's own code sees it: `mesh | {p}`, whose iteration is a question on the tape with its
    answer, ["mesh_and", [p], [q...]], in the order the Python iterates the set the untraced code makes; a
    membership test, `q in mesh`, ["mesh_has", [q], the answer]; and its own iteration, `for q in mesh`, ["mesh",
    [], [q...]]. The set itself is not copied, since a copy can iterate in another order. Any other use raises."""
    __slots__ = ("m", "tape")

    def __init__(self, m, tape):
        self.m, self.tape = m, tape

    def __contains__(self, q):
        r = q in self.m
        self.tape().append(["mesh_has", [int(q)], r])
        return r

    def __iter__(self):                 # `for q in mesh`, the peers in the order the set iterates
        order = list(self.m)
        self.tape().append(["mesh", [], [int(q) for q in order]])
        return iter(order)

    def __or__(self, other):
        if not isinstance(other, set):
            raise TypeError(f"trace3: mesh | {other!r}: the mesh question takes a set of peers")
        return _MeshAnd(self, list(other), list(set.__or__(self.m, other)))


class _MeshAnd:
    __slots__ = ("q", "p", "order")

    def __init__(self, q, p, order):
        self.q, self.p, self.order = q, p, order

    def __iter__(self):
        self.q.tape().append(["mesh_and", self.p, list(self.order)])
        return iter(self.order)


class OrderProxy:
    """Under SEACAST, a set of peers whose order the twin asks where the block iterates it (ORDER_PLACES_Seacast): the value
    of a nested `suppression_scope(g)`, and the set `standing[g].pop(i, ())` hands out (OrderPopView). Each
    iteration calls `note(place, members)`, the members in the order the set itself iterates, empty or not, and
    `place` the name of the frame that creates the iterator: in `any(... for q in s)` the function's own, which
    evaluates the generator's outermost iterable. `|` with a set gives the proxy of the real union, which iterates as
    the untraced code's union does. A membership test and `len` note nothing. The set is not copied, since a copy
    can iterate in another order. Any other use raises."""
    __slots__ = ("s", "note")

    def __init__(self, s, note):
        self.s, self.note = s, note

    def __iter__(self):
        order = list(self.s)
        self.note(sys._getframe(1).f_code.co_name, order)
        return iter(order)

    def __contains__(self, q):
        return q in self.s

    def __len__(self):
        return len(self.s)

    def __or__(self, other):
        if not isinstance(other, (set, frozenset)):
            raise TypeError(f"trace3: an ordered set | {other!r}: the order's proxy takes a set of peers")
        return OrderProxy(self.s | other, self.note)


def order_writer(rec, st, on, nid):
    """The note of a node's OrderProxies: an iteration in a record's own code (a record open, the recorder on, no
    question or replaced name running, no callee's log open) and with the order on (`on()`) puts ["order", place,
    [q...]] on the record's tape; anywhere else it writes nothing. A place none of ORDER_PLACES_Seacast stops the trace:
    the twin asks no order there."""
    def note(place, members):
        if (not rec.on or st["cur"] is None or st["ext"] or st["supp"] or rec.callee is not None or not on()
                or getattr(rec, "observer", None) is not None):     # an observer's own iteration (class 6)
            return
        if place not in ORDER_PLACES_Seacast:
            raise SystemExit(f"trace3: node {nid}: a set whose order the twin asks is iterated in {place}, at none "
                             f"of its places ({', '.join(ORDER_PLACES_Seacast)})")
        st["cur"]["tape"].append(["order", place, [int(q) for q in members]])
    return note


class OrderPopView(F.View):
    """`standing` under --doc seacast: an entry popped whole, `standing[g].pop(i, ())`, is handed out as an OrderProxy of
    the popped set, or of the default where the entry is missing, so that serve_standing's iteration notes its order.
    The pop's own log is the view's. Every level below is one of these."""
    __slots__ = ("_note",)

    def __init__(self, view, note):
        super().__init__(view._r, view._t, view._p, view._o)
        object.__setattr__(self, "_note", note)

    def _sub(self, k, v):
        return OrderPopView(F.View(self._r, self._t, self._p + (k,), v), self._note)

    def pop(self, k, *default):
        r = super().pop(k, *default)
        return OrderProxy(r, self._note) if self._leaf() else r


def main(argv):
    toy, out, rest = Path(argv[0]).resolve(), argv[1], argv[2:]
    tr = Tracer3(toy, out, rest, cli=True)
    if tr.doc_seacast:       # under SEACAST, at the end of the node's construction: after _seacast and every option's binding, so that
        orig_init = tr.N.Node.__init__      # the tracer sees each name as it finally stands

        def __init__(self, *a, **kw):
            orig_init(self, *a, **kw)
            pre = {name: self.ns.get(name) for name in ("desc", "message_id")}    # the aliases' targets as the toy
            tr.install(self, self.ns)                                           #   left them, before the install
            tr.repoint_aliases(self, self.ns, pre)

        tr.N.Node.__init__ = __init__
    else:               # under seacast-lite.md, inside _override, as before
        orig = tr.N.Node._override

        def _override(self, ns):
            orig(self, ns)
            tr.install(self, ns)

        tr.N.Node._override = _override
    import run                          # noqa: E402: the toy's run.py, from TOYDIR
    try:
        run.main(rest)
    except BaseException as stop:       # a stop (or any error) in flight: close the trace, its trailer saying why, but
        try:                            #   a later check at the close must not replace the first reason, which is the one raised
            tr.close(stopped=(f"{type(stop).__name__}: {stop}".splitlines() or [""])[0])
        except BaseException as later:  # a stop or any other error at the close: a note (printed before the
            print(f"trace3: (at the close, after the stop) {type(later).__name__}: {later}",   # stop's own line)
                  file=sys.stderr)
        raise
    tr.close()
    print(f"trace3: {sum(tr.counts.values())} records, {dict(sorted(tr.counts.items()))}", file=sys.stderr)
    for line in observers_summary(tr.observers):
        print(line, file=sys.stderr)


def observers_summary(observers):
    """Class 6's counts, one line per observer layer (by its place, over its name), over the nodes that have it: the
    nodes, the calls entered in records, the reads its own code made, unlogged."""
    by = {}
    for ob in observers:
        n, c, r = by.get((ob.where, ob.name), (0, 0, 0))
        by[(ob.where, ob.name)] = (n + 1, c + ob.calls, r + ob.reads)
    return [f"trace3: observer {w} over {name}: nodes {n}, calls in records {c}, reads unlogged {r}"
            for (w, name), (n, c, r) in sorted(by.items())]


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test-seacast"]:
        sys.exit(self_test_seacast())
    main(sys.argv[1:])
