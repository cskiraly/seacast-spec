#!/usr/bin/env python3
"""The controls of the tracer's own checks, each by a fault planted in a run of directed42.py. directed42.py's records
hold the whole state, a share of its samples runs the toy's own enqueue, and its DEFER verdicts reach the deferral
path.

    python3 tracerfaults3.py --made-rows-off TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --alias TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --alias-control TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --installed-flip TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --pending-twice TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --alias-start TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --alias-message TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --defer-chain TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --replaced TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --false-wrapper TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --stale-id TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --level1-in-cell TOYDIR OUT.jsonl.gz [ignored]
    python3 tracerfaults3.py --late-rebind TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --stale-id-callee TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --rebind-after-records TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]
    python3 tracerfaults3.py --limit-fraction TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]

- `--made-rows-off`: the views write only the entry a call touched under a row it made (footprint.MADE_ROWS off).
  A row the toy's enqueue makes then has a lane in no entry. The tracer's check of its log against the tables
  (trace3.py's `account`) must stop it.
- `--alias`: the first entry the toy puts in a lane is also put in the same peer's other lane: one entry object in
  two places. The alias check (trace3.py's `alias_check`, called at the end of each record that touches the queue)
  must stop it. Q11 of footprint_test.py calls the check directly; this run checks that the tracer calls it.
- `--alias-control`: the first entry the toy puts in a lane with a control gets a twin in the same peer's other
  lane: another entry, sharing that control (drop_offer changes a message's ids in place). The alias check must
  stop it.
- `--installed-flip`: the second time a record asks installed_block of one (slot, root), the answer is the other one
  (a block where there was none, or none where there was one). The twin's recursion between on_validated and defer,
  with its fuel of two, assumes one answer within a call; trace3.py's `installed` must stop it.
- `--pending-twice`: the first copy defer keeps is kept again under its root: one (peer, chunk) twice in a list of
  waits. The twin removes a pair as Python's list.remove does, the first equal one, and no pair may be there twice;
  the check at the end of each record that touches `pending` (trace3.py's `pending_check`) must stop it.
- `--alias-start`: at the first record's start where a lane holds an entry with a control, another entry sharing
  that control is put in the same peer's other lane, as if made outside any record. The alias check at the record's
  start must stop it, before the call can consume one side of it.
- `--alias-message`: the first entry the toy puts in a lane with a control gets a twin in the same peer's other lane
  with a control of its own that holds the same message objects. Distinct controls, one message: the check of the
  messages' identity must stop it, which `--alias-control` never reaches.
- `--defer-chain`: where a record's chain already holds two DEFERs and the block is installed, the next validation
  answers DEFER once more. The twin's fuel (deferDepth, 2) would end there; the tracer's count of a record's chain
  of defers must stop it.

- `--replaced`: a traced name (may_ask) is a function of this tool's own at the node, with none of the document's
  code behind it, as a fault or a variant of the toy's would be. The tracer's check of each traced name at its
  install (trace3.py's `own_code`) must stop it, before any record.
- `--false-wrapper`: the same name is a function with a listed wrapper's qualified name that holds another of the
  document's functions in its closure. The check must stop it: a wrapper is listed by its name and by what it
  wraps.

- `--stale-id`: the id a chunk has stored is not the document's message_id of it (its content id answers
  otherwise). The toy's wrapper returns the stored id; the tracer's check at each call of message_id by the block,
  against the document's own function, must stop it.

- `--rebind-after-records`: a traced name (may_ask) bound again after the trace's first record, to a function of this
  tool's own. The names' check at the trace's end must stop it (the one at the nodes line is past).
- `--limit-fraction`: a node's MAX_IHAVE_LENGTH is 2.5. The tracer's check that each limit is a count must stop it
  at its install, where int() would make it 2.

Each must end with a non-zero exit code and the tracer's own line. If the trace is written to the end, the check
checks nothing. Its own line on stderr says which fault, and how many times it was planted.
"""
import functools
import runpy
import sys
import types
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import footprint as F                   # noqa: E402
import trace3 as T                      # noqa: E402: the module directed42.py imports (one sys.modules entry)

PLANTED = [0]


def made_rows_off():
    F.MADE_ROWS = False
    PLANTED[0] = 1


def alias(toy):
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's

    _append = N._Lane.append

    def append(self, x):
        _append(self, x)
        if not PLANTED[0]:              # the fault, once: the entry in the other lane of its queue too
            q = self._q
            other = q.urgent if self is q.normal else q.normal
            list.append(other, x)
            PLANTED[0] += 1

    N._Lane.append = append


def alias_control(toy):
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    import wire as W                    # noqa: E402

    _append = N._Lane.append

    def append(self, x):
        _append(self, x)
        if not PLANTED[0] and getattr(x, "control", None) is not None:   # the fault, once: another entry, its
            q = self._q                                                     #   control the same object
            other = q.urgent if self is q.normal else q.normal
            list.append(other, W.Entry(control=x.control))
            PLANTED[0] += 1

    N._Lane.append = append


def before_install(wrap):
    """Run `wrap(tracer, ns)` on the node's namespace just before the tracer installs itself, so that what `wrap`
    puts there is what the tracer wraps (a block function the tracer then traces, an interface answer it records)."""
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        wrap(self, ns)
        return _install(self, nd, ns)

    T.Tracer3.install = install


def installed_flip():
    def wrap(tr, ns):
        ib = ns["installed_block"]

        def installed_block(slot, root):
            r = ib(slot, root)
            k = (int(slot), bytes(root))
            if not PLANTED[0] and k in getattr(tr, "ib", {}):   # asked before in this record: the other answer, once
                PLANTED[0] += 1
                return None if tr.ib[k] else types.SimpleNamespace(slot=slot, root=root)
            return r

        ns["installed_block"] = installed_block

    before_install(wrap)


def pending_twice():
    def wrap(tr, ns):
        defer = ns["defer"]

        @functools.wraps(defer)
        def twice(p, f):
            pend, root = ns["pending"], f.beacon_block_root
            n = len(pend[root]) if root in pend else 0
            r = defer(p, f)
            if not PLANTED[0] and root in pend and len(pend[root]) > n:     # kept: kept again, once, as defer keeps
                pend[root].append((p, f))
                PLANTED[0] += 1
            return r

        ns["defer"] = twice
        # the check of each traced name (trace3.own_code) would stop this fault's own wrapper first: it is listed
        # for this run, as the wrapper of the document's defer that it is, so that the check of `pending` stops it
        T.WRAPPERS["defer"] = twice.__qualname__

    before_install(wrap)


def alias_start(toy):
    sys.path.insert(0, str(Path(toy).resolve()))
    import wire as W                    # noqa: E402: the pinned toy's

    _check = T.Tracer3.alias_check

    def check(self, rec, nid, args=(), when="end"):
        if when == "start" and not PLANTED[0]:      # the fault, once: an alias there before the call
            raw = rec.roots["queue"][1]
            for p in F._keys(raw):
                pq = F._peek(raw, p)
                for ln in ("urgent", "normal"):
                    for e in list(getattr(pq, ln)):
                        if e.control is not None:
                            other = pq.urgent if ln == "normal" else pq.normal
                            list.append(other, W.Entry(control=e.control))
                            PLANTED[0] += 1
                            return _check(self, rec, nid, args, when)
        return _check(self, rec, nid, args, when)

    T.Tracer3.alias_check = check


def alias_message(toy):
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    import wire as W                    # noqa: E402

    _append = N._Lane.append

    def append(self, x):
        _append(self, x)
        if not PLANTED[0] and getattr(x, "control", None) is not None and x.control.items:   # once: another entry,
            q = self._q                                                     #   its control its own, its messages
            other = q.urgent if self is q.normal else q.normal              #   the same objects
            list.append(other, W.Entry(control=W.Control(list(x.control.items))))
            PLANTED[0] += 1

    N._Lane.append = append


def defer_chain():
    def wrap(tr, ns):
        vc, ib, DEFER = ns["validate_chunk"], ns["installed_block"], ns["DEFER"]
        cur = {"rec": None, "n": 0}

        def validate_chunk(f):
            r = vc(f)
            if cur["rec"] is not tr.ib:             # a new record: tr.ib is made afresh at each record's start
                cur["rec"], cur["n"] = tr.ib, 0
            if r == DEFER:
                cur["n"] += 1
            elif not PLANTED[0] and cur["n"] >= 2 and ib(f.slot, f.beacon_block_root):
                PLANTED[0] += 1                     # once: a third DEFER in the chain, the block installed
                return DEFER
            return r

        ns["validate_chunk"] = validate_chunk

    before_install(wrap)


def replaced():
    def wrap(tr, ns):
        def may_ask(a, p):              # a function of this tool's own under a traced name, as a fault or a variant
            return False                #   of the toy's would be: none of the document's code is behind it
        ns["may_ask"] = may_ask
        PLANTED[0] += 1

    before_install(wrap)


def false_wrapper():
    def wrap(tr, ns):
        other = ns["parked"]            # the document's code, but not may_ask's

        def may_ask(a, p):
            return other(p, a)
        may_ask.__qualname__ = T.WRAPPERS["may_ask"]    # a listed wrapper's name, on a function that wraps another
        ns["may_ask"] = may_ask
        PLANTED[0] += 1

    before_install(wrap)


def stale_id():
    def wrap(tr, ns):
        scenario = ns["content_id"]     # directed42.py's: the chunk's own content id, as its stored id has it

        def content_id(f):              # another content id than the one the chunk's stored id was made with: the
            c = scenario(f)             #   document's message_id of the chunk is then not the id the toy returns
            return bytes([c[0] ^ 1]) + c[1:]
        ns["content_id"] = content_id
        PLANTED[0] += 1

    before_install(wrap)


def after_install(wrap):
    """Run `wrap(tracer, ns)` on the node's namespace just after the tracer installed itself: what the toy does where
    it binds a name after `_override` returns."""
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        r = _install(self, nd, ns)
        wrap(self, ns)
        return r

    T.Tracer3.install = install


def late_rebind():
    """A traced name bound again after the tracer's install (as Node.__init__ and `_v2` bind theirs), to a function of
    this tool's own. The names' second check, at the nodes line, must stop it."""
    def wrap(tr, ns):
        def may_ask(a, p):
            return False
        ns["may_ask"] = may_ask
        PLANTED[0] += 1

    after_install(wrap)


def rebind_after_records():
    """A traced name bound again once the trace has records: the names' check at the trace's end must stop it."""
    nss = []
    after_install(lambda tr, ns: nss.append(ns))
    _write = T.Tracer3.write

    @functools.wraps(_write)
    def write(self, rec):
        r = _write(self, rec)
        if not PLANTED[0] and isinstance(rec, dict) and "fn" in rec and nss:
            def may_ask(a, p):
                return False
            nss[0]["may_ask"] = may_ask
            PLANTED[0] += 1
        return r

    T.Tracer3.write = write


def limit_fraction():
    """A limit that is no count, as a variant could set one: the tracer must refuse it at its install."""
    def wrap(tr, ns):
        ns["MAX_IHAVE_LENGTH"] = 2.5
        PLANTED[0] += 1

    before_install(wrap)


def stale_id_callee():
    """A chunk's stored id made stale where only a call on the tape reads it next: the node's open_group leaves
    another id on the chunk, and the node's store, a callee, asks message_id of it. The tracer's check of message_id
    against the document's own function must stop it there."""
    def wrap(tr, ns):
        og = ns["open_group"]

        def open_group(g, f):
            r = og(g, f)
            m = getattr(f, "mid", None)
            if not PLANTED[0] and m is not None:
                f.mid = m[:36] + bytes([m[36] ^ 1]) + m[37:]
                PLANTED[0] += 1
            return r
        ns["open_group"] = open_group

    before_install(wrap)


def level1_in_cell():
    """The condition on level 1, a replaceable name: a cell whose node runs something else as validate_chunk. A
    directed set's scenario may (in a trace of the whole state); a cell may not. The fault runs the hand-counted
    cell, not directed42.py, with a level 1 of this tool's own at every node."""
    def wrap(tr, ns):
        def validate_chunk(f):
            return "ACCEPT"
        ns["validate_chunk"] = validate_chunk
        PLANTED[0] += 1

    before_install(wrap)


TR = []                                 # the run's tracer, once made (tracer_instance)


def tracer_instance():
    """Keep the run's tracer in TR: the v2 faults reach other nodes' namespaces and the shared depth through it."""
    _init = T.Tracer3.__init__

    @functools.wraps(_init)
    def init(self, *a, **kw):
        _init(self, *a, **kw)
        TR.append(self)

    T.Tracer3.__init__ = init


def early_install_v2(toy):
    """Under v2: the tracer installed where protocol.md has it, inside `Node._override`, before `_v2` and the options'
    bindings, and the install at the end of construction skipped. `_v2` then binds its `promise_due` over the tracer's
    wrapper, a listed wrapper that protocol.md's reading accepts. Under v2 the install is the namespace's last binding:
    the names' check at the nodes line must stop it."""
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    tracer_instance()
    _install = T.Tracer3.install
    early = set()

    @functools.wraps(_install)
    def install(self, nd, ns):
        if id(nd) in early:             # the hook at the end of construction: installed already, inside _override
            return None
        return _install(self, nd, ns)

    T.Tracer3.install = install
    _repoint = T.Tracer3.repoint_aliases

    @functools.wraps(_repoint)
    def repoint_aliases(self, nd, ns):  # the whole hook at the end of construction skipped: its re-pointing too
        if id(nd) in early:
            return None
        return _repoint(self, nd, ns)

    T.Tracer3.repoint_aliases = repoint_aliases
    _over = N.Node._override

    def _override(self, ns):
        _over(self, ns)
        TR[0].install(self, ns)
        early.add(id(self))
        PLANTED[0] += 1

    N.Node._override = _override


def raw_alias_v2():
    """Under v2: the aliases `hdr` and `chunk_id` left as the toy bound them, to the raw objects of before the
    install. The names' check at the nodes line must stop it: a raw `hdr` makes every `hdr[g]` read unlogged."""
    def repoint_aliases(self, nd, ns):
        PLANTED[0] += 1

    T.Tracer3.repoint_aliases = repoint_aliases


def raw_chunk_id_v2():
    """Under v2: `hdr` re-pointed, `chunk_id` left as the toy bound it (the toy's message_id, not the installed one).
    The names' check at the nodes line must stop it at `chunk_id`, `hdr`'s check having passed."""
    def repoint_aliases(self, nd, ns):
        ns["hdr"] = ns["desc"]
        PLANTED[0] += 1

    T.Tracer3.repoint_aliases = repoint_aliases


def before_install_v2(plant):
    """Run `plant(ns)` on the node's namespace just before the tracer installs itself (under v2, at the end of the
    node's construction)."""
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        plant(ns)
        PLANTED[0] += 1
        return _install(self, nd, ns)

    T.Tracer3.install = install


def hdr_other_v2():
    """Under v2: `hdr` bound, before the install, to another object than the toy's `desc` (a copy of it). Re-pointing
    it would hide that; the check before the re-pointing must stop it."""
    def plant(ns):
        ns["hdr"] = dict(ns["desc"])
    before_install_v2(plant)


def alias_missing_v2():
    """Under v2: `chunk_id` taken out of the namespace before the install. The check before the re-pointing must stop
    it (a missing alias is not left alone)."""
    def plant(ns):
        del ns["chunk_id"]
    before_install_v2(plant)


def rebound_scanned_v2():
    """Under v2: a function the scan names in one slot (`popcount`) bound, before the install, in another slot that no
    binding of the toy's names (`popcount_again`). The install check is by slot and function together: it must stop."""
    def plant(ns):
        ns["popcount_again"] = ns["popcount"]
    before_install_v2(plant)


def unscanned_layer_v2(toy):
    """Under v2: a layer over `on_frame` that claims to be the toy's (its code compiled as node.py's, at a line where
    no binding is) and holds the bound `on_frame` in a closure cell, so that the namespace check, which follows the
    layers to v2's own function, passes it. Bound just before the install: the scan of the toy's bindings names no
    such function, and the tracer must stop at the install."""
    node_py = str(Path(toy).resolve() / "node.py")
    g = {}
    exec(compile("def make(doc):\n    def on_frame(p, frame):\n        return doc(p, frame)\n    return on_frame\n",
                 node_py, "exec"), g)
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        ns["on_frame"] = g["make"](ns["on_frame"])
        PLANTED[0] += 1
        return _install(self, nd, ns)

    T.Tracer3.install = install


def other_node_v2():
    """Under v2: at the first table read inside a record at node a, outside any question, node c's traced `N` is
    called. The tracer must stop before the call runs (its argument, None, is never reached)."""
    tracer_instance()
    nss = {}
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        r = _install(self, nd, ns)
        nss[int(nd.id)] = ns
        return r

    T.Tracer3.install = install
    _read = F.Recorder.read

    @functools.wraps(_read)
    def read(self, t, p):
        st = TR[0].vst if TR else None
        if not PLANTED[0] and st and st["depth"] and not st["ext"] and not st["supp"]:
            c = next((i for i in sorted(nss) if i != st["node"]), None)
            if c is not None:
                PLANTED[0] += 1
                nss[c]["N"](None)
        return _read(self, t, p)

    F.Recorder.read = read


SEEN = {}                               # the v2 plants' observations, printed on the fault's line


def watch_records(inside):
    """Count the records written while `inside()` names a (node, name) pair: a record of that name at that node."""
    _write = T.Tracer3.write

    @functools.wraps(_write)
    def write(self, rec):
        at = inside()
        if at and isinstance(rec, dict) and rec.get("fn") == at[1] and int(rec.get("n", -1)) == at[0]:
            SEEN["records inside"] = SEEN.get("records inside", 0) + 1
        return _write(self, rec)

    T.Tracer3.write = write


def bare_in_question_v2(per_node, callee="N"):
    """Under v2: a question at node a (`peer_id_bytes`, its function replaced before the install by a layer of this
    tool's own, which the tracer then wraps as the question) calls a name at node c, once. The tracer-wide depth makes
    that call bare at node c: no record there, and the trace's body that of the run without the plant.
    - `N` (traced): with one of node c's descriptors; a count `"c N"` in the run's bare counts. With `per_node`, each
      install gets a depth state of its own (today's per-node depth, the planted fault): a record of `N` at node c
      starts inside node a's question.
    - `on_iwant` (hand5-own's arguments): node c the node whose `on_iwant` is replaced (the silent node's, which
      answers nothing); a traced name replaced there, counted `"c on_iwant"` as a traced one is.
    - `after` (a tape question, a timer): node c's `after(0, a no-op)`; bare, on no tape, so the body is the plain
      run's (taped on node a's question, it would differ); not counted (no traced name)."""
    tracer_instance()
    nss, at, replaced_at = {}, [None], set()
    watch_records(lambda: at[0])
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        if per_node:
            self.vst = {"depth": 0, "ext": 0, "cur": None, "node": None, "supp": 0}
        st, a = self.vst, int(nd.id)
        nss[a] = ns
        if getattr(getattr(ns["on_iwant"], "__code__", None), "co_filename", None) != T.DOC_FILE:
            replaced_at.add(a)          # the node's own on_iwant (the silent node's), before the tracer wraps it
        doc = ns["peer_id_bytes"]

        def peer_id_bytes(p):
            if not PLANTED[0] and st["depth"] and st["ext"]:
                if callee == "on_iwant":
                    c = next((i for i in sorted(replaced_at) if i != a), None)
                else:
                    c = next((i for i in sorted(nss) if i != a and F.unwrap(nss[i]["desc"])), None)
                if c is not None:
                    PLANTED[0] += 1
                    SEEN["node a, node c"] = f"{a}, {c}"
                    at[0] = (c, callee)
                    try:
                        if callee == "N":
                            nss[c]["N"](next(iter(F.unwrap(nss[c]["desc"]).values())))
                        elif callee == "on_iwant":
                            nss[c]["on_iwant"](a, None)
                        else:
                            nss[c]["after"](0, lambda: None)
                    finally:
                        at[0] = None
                    if callee != "after":
                        SEEN[f"bare c {callee}"] = TR[0].bare.get(f"{c} {callee}", 0)
            return doc(p)
        ns["peer_id_bytes"] = peer_id_bytes
        return _install(self, nd, ns)

    T.Tracer3.install = install


def other_node_tape_v2():
    """Under v2: at the first table read inside a record at node a, outside any question, node c's tape question
    `peer_id_bytes` is called (a tape name, not a traced one). The tracer must stop before the call runs, as it does for
    a traced name (the rule kept stricter than "a traced call")."""
    tracer_instance()
    nss = {}
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        r = _install(self, nd, ns)
        nss[int(nd.id)] = ns
        return r

    T.Tracer3.install = install
    _read = F.Recorder.read

    @functools.wraps(_read)
    def read(self, t, p):
        st = TR[0].vst if TR else None
        if not PLANTED[0] and st and st["depth"] and not st["ext"] and not st["supp"]:
            c = next((i for i in sorted(nss) if i != st["node"]), None)
            if c is not None:
                PLANTED[0] += 1
                nss[c]["peer_id_bytes"](None)
        return _read(self, t, p)

    F.Recorder.read = read


class Planted(Exception):
    """The exception the suppressed-entry plant raises inside the replaced name, and catches outside it."""


def suppressed_entry_v2(toy, off):
    """Under v2, hand5-own's arguments: at the node whose `on_iwant` is replaced (the silent node), a call of it from
    outside any record (from the toy's `Node._write`, which the simulator calls at depth 0). A layer of this tool's own,
    bound before the install and live for that call alone, calls the same node's traced `N` and raises `Planted`, which
    the call's site catches. The tracer must suppress records inside the entry (no record of `N`, a count `"s N"`), and
    restore its state on the raise (`supp` 0 at the catch). With `off`, the layer clears the suppression for its call
    of `N` (depth 0 there, the planted fault): a record of `N` starts inside the replaced name."""
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    tracer_instance()
    live, at, silent = [False], [None], {}
    watch_records(lambda: at[0])
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        fn = ns["on_iwant"]
        if getattr(getattr(fn, "__code__", None), "co_filename", None) != T.DOC_FILE:  # the node's own: replaced
            s = int(nd.id)
            silent[s] = ns
            st = self.vst

            def on_iwant(*a, **kw):
                if live[0]:
                    mode, live[0] = live[0], False
                    d = next(iter(F.unwrap(ns["desc"]).values()))
                    at[0] = (s, "N")
                    try:
                        if off:
                            saved, st["supp"] = st["supp"], 0
                            try:
                                ns["N"](d)
                            finally:
                                st["supp"] = saved
                        else:
                            ns["N"](d)
                    finally:
                        at[0] = None
                    if mode == "raise":
                        raise Planted()
                    return []
                return fn(*a, **kw)
            ns["on_iwant"] = on_iwant
        return _install(self, nd, ns)

    T.Tracer3.install = install
    _w = N.Node._write

    def _write(self, p):            # two entries: the first returns, the second raises (the state restored on both)
        st = TR[0].vst if TR else None
        if (PLANTED[0] < 2 and int(self.id) in silent and st and not st["depth"] and not st["supp"]
                and F.unwrap(self.ns["desc"])):
            PLANTED[0] += 1
            mode = "return" if PLANTED[0] == 1 else "raise"
            live[0] = mode
            try:
                self.ns["on_iwant"](p, None)
            except Planted:
                pass
            SEEN["node s"] = int(self.id)
            SEEN[f"supp after the {mode}"] = st["supp"]
            SEEN["bare s N"] = TR[0].bare.get(f"{int(self.id)} N", 0)
        return _w(self, p)

    N.Node._write = _write


FAULTS = ("--made-rows-off", "--alias", "--alias-control", "--installed-flip", "--pending-twice", "--alias-start",
          "--alias-message", "--defer-chain", "--replaced", "--false-wrapper", "--stale-id", "--level1-in-cell",
          "--late-rebind", "--stale-id-callee", "--rebind-after-records", "--limit-fraction",
          "--early-install-v2", "--raw-alias-v2", "--other-node-v2", "--unscanned-layer-v2", "--raw-chunk-id-v2",
          "--hdr-other-v2", "--alias-missing-v2", "--other-node-tape-v2", "--rebound-scanned-v2")
# the plants under v2 that must not stop the tracer, with their controls: each prints what it saw
PLANTS = ("--bare-in-question-v2", "--bare-in-question-v2-per-node", "--suppressed-entry-v2",
          "--suppressed-entry-v2-off", "--bare-replaced-v2", "--bare-timer-v2")
HAND5 = ["--nodes", "5", "--degree", "4", "--msgs", "1", "--payload", "16384", "--seed", "7"]
HAND5_OWN = HAND5 + ["--rebuilt", "none", "--fault", "sil30"]   # check.sh's v2/hand5-own


def main(argv):
    if len(argv) < 3 or argv[0] not in FAULTS + PLANTS:
        print(f"usage: tracerfaults3.py {'|'.join(FAULTS + PLANTS)} TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]",
              file=sys.stderr)
        return 2
    fault, rest = argv[0], argv[1:]
    if fault.endswith("-v2") or "-v2-" in fault:    # under v2: trace3.py's own run of hand5 (or hand5-own)
        if fault == "--early-install-v2":
            early_install_v2(rest[0])
        elif fault == "--raw-alias-v2":
            raw_alias_v2()
        elif fault == "--other-node-v2":
            other_node_v2()
        elif fault == "--unscanned-layer-v2":
            unscanned_layer_v2(rest[0])
        elif fault == "--raw-chunk-id-v2":
            raw_chunk_id_v2()
        elif fault == "--hdr-other-v2":
            hdr_other_v2()
        elif fault == "--alias-missing-v2":
            alias_missing_v2()
        elif fault.startswith("--bare-in-question-v2"):
            bare_in_question_v2(per_node=fault.endswith("-per-node"))
        elif fault == "--bare-replaced-v2":
            bare_in_question_v2(per_node=False, callee="on_iwant")
        elif fault == "--bare-timer-v2":
            bare_in_question_v2(per_node=False, callee="after")
        elif fault == "--other-node-tape-v2":
            other_node_tape_v2()
        elif fault == "--rebound-scanned-v2":
            rebound_scanned_v2()
        else:
            suppressed_entry_v2(rest[0], off=fault.endswith("-off"))
        args = HAND5_OWN if fault.startswith("--suppressed-entry-v2") or fault == "--bare-replaced-v2" else HAND5
        try:                            # the arguments as check.sh's v2/hand5 and v2/hand5-own have them
            T.main([rest[0], rest[1], *args, "--doc", "v2", "--digest"])
        finally:
            seen = "".join(f"; {k}: {v}" for k, v in SEEN.items())
            print(f"tracerfaults3: {fault[2:]}, planted {PLANTED[0]} time{'s' if PLANTED[0] != 1 else ''}{seen}",
                  file=sys.stderr)
        return 0
    if fault == "--made-rows-off":
        made_rows_off()
    elif fault == "--alias":
        alias(rest[0])
    elif fault == "--alias-control":
        alias_control(rest[0])
    elif fault == "--installed-flip":
        installed_flip()
    elif fault == "--pending-twice":
        pending_twice()
    elif fault == "--alias-start":
        alias_start(rest[0])
    elif fault == "--alias-message":
        alias_message(rest[0])
    elif fault == "--defer-chain":
        defer_chain()
    elif fault == "--replaced":
        replaced()
    elif fault == "--false-wrapper":
        false_wrapper()
    elif fault == "--level1-in-cell":
        level1_in_cell()
    elif fault == "--late-rebind":
        late_rebind()
    elif fault == "--stale-id-callee":
        stale_id_callee()
    elif fault == "--rebind-after-records":
        rebind_after_records()
    elif fault == "--limit-fraction":
        limit_fraction()
    else:
        stale_id()
    sys.argv = [str(HERE / "directed42.py"), *rest]
    try:
        if fault == "--level1-in-cell":     # a cell's trace, not of the whole state: trace3.py's own run of hand5
            T.main([rest[0], rest[1], *HAND5])
        else:
            runpy.run_path(str(HERE / "directed42.py"), run_name="__main__")
    finally:
        print(f"tracerfaults3: {fault[2:]}, planted {PLANTED[0]} time{'s' if PLANTED[0] != 1 else ''}",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
