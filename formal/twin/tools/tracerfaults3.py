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
import copy
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
    """A traced name bound again after the tracer's install (as Node.__init__ and `_seacast` bind theirs), to a function of
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


def early_install_seacast(toy):
    """Under v2: the tracer installed where seacast-lite.md has it, inside `Node._override`, before `_seacast` and the options'
    bindings, and the install at the end of construction skipped. `_seacast` then binds its `promise_due` over the tracer's
    wrapper, a listed wrapper that seacast-lite.md's reading accepts. The install must be refused there, and it is refused
    first by what the namespace lacks before `_seacast`: the install-time check of the closure rule's lists. (Under v2 the
    install is also the namespace's last binding; rebind-tape-v2 and rebind-view-v2 reach that check.)"""
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
    def repoint_aliases(self, nd, ns, pre):     # the whole hook at the end of construction skipped: its
        if id(nd) in early:                     #   re-pointing too
            return None
        return _repoint(self, nd, ns, pre)

    T.Tracer3.repoint_aliases = repoint_aliases
    _over = N.Node._override

    def _override(self, ns):
        _over(self, ns)
        PLANTED[0] += 1                 # the plant is the early call itself: counted before it, which may stop the run
        TR[0].install(self, ns)
        early.add(id(self))             # after it: install() above returns at once for a node in `early`

    N.Node._override = _override


def raw_alias_seacast():
    """Under v2: the aliases `hdr` and `chunk_id` left as the toy bound them, to the raw objects of before the
    install. The names' check at the nodes line must stop it: a raw `hdr` makes every `hdr[g]` read unlogged."""
    def repoint_aliases(self, nd, ns, pre):
        PLANTED[0] += 1

    T.Tracer3.repoint_aliases = repoint_aliases


def raw_chunk_id_seacast():
    """Under v2: `hdr` re-pointed, `chunk_id` left as the toy bound it (the toy's message_id, not the installed one).
    The names' check at the nodes line must stop it at `chunk_id`, `hdr`'s check having passed."""
    def repoint_aliases(self, nd, ns, pre):
        ns["hdr"] = ns["desc"]
        PLANTED[0] += 1

    T.Tracer3.repoint_aliases = repoint_aliases


def before_install_seacast(plant):
    """Run `plant(ns)` on the node's namespace just before the tracer installs itself (under v2, at the end of the
    node's construction)."""
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        plant(ns)
        PLANTED[0] += 1
        return _install(self, nd, ns)

    T.Tracer3.install = install


def hdr_other_seacast():
    """Under v2: `hdr` bound, before the install, to another object than the toy's `desc` (a copy of it). Re-pointing
    it would hide that; the check before the re-pointing must stop it."""
    def plant(ns):
        ns["hdr"] = dict(ns["desc"])
    before_install_seacast(plant)


def alias_missing_seacast():
    """Under v2: `chunk_id` taken out of the namespace before the install. The check before the re-pointing must stop
    it (a missing alias is not left alone)."""
    def plant(ns):
        del ns["chunk_id"]
    before_install_seacast(plant)


def rebound_scanned_seacast():
    """Under v2: a function the scan names in one slot (`popcount`) bound, before the install, in another slot that no
    binding of the toy's names (`popcount_again`). The install check is by slot and function together: it must stop."""
    def plant(ns):
        ns["popcount_again"] = ns["popcount"]
    before_install_seacast(plant)


def rebind_tape_seacast():
    """Under v2: a tape name bound again after the install to the function the tracer wrapped as its question (as
    `_repair_bias` writes back its captured `shuffled`). final_check, which under v2 holds every installed slot, must
    stop it."""
    def wrap(tr, ns):
        q = ns["peer_id_bytes"]
        ns["peer_id_bytes"] = getattr(q, "__wrapped__", q)
        PLANTED[0] += 1
    after_install(wrap)


def rebind_view_seacast():
    """Under v2: a table's view replaced, after the install, by its raw table (`offers`). final_check must stop it:
    the table would go on unlogged."""
    def wrap(tr, ns):
        ns["offers"] = F.unwrap(ns["offers"])
        PLANTED[0] += 1
    after_install(wrap)


def param_after_install_seacast():
    """Under v2: a type's parameter changed after the install (the payload type made pull-only, as the toy's
    pull_source_known.py does after the sim is built). The nodes line holds the parameters the install read, so the
    twin would run the type as it was; final_check, which reads them again, must stop it."""
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        r = _install(self, nd, ns)
        nd._types["payload"].params.EAGER = not nd._types["payload"].params.EAGER
        PLANTED[0] += 1
        return r

    T.Tracer3.install = install


def close_keyerror_seacast():
    """Under v2: a stop (a traced call at another node in an open record, as `--other-node-v2`), and an ordinary
    exception raised at the trace's close after it. The stop's reason must be the one raised; the close's is a note."""
    other_node_seacast()
    _close = T.Tracer3.close

    @functools.wraps(_close)
    def close(self, *args, **kwargs):   # the stop's reason passed on as the tracer's close takes it
        try:
            _close(self, *args, **kwargs)
        finally:
            raise KeyError("planted at the close")

    T.Tracer3.close = close


def chains_omit_seacast():
    """Under v2, a plant for the replay: the nodes line's chains walked as trace3.py's writer walks them (the chain
    rule), and written without any replaced name's chain. The trace is written to the end; the twin's reader must
    refuse it ("nodes: chains: a replaced name with no chain")."""
    _nc = T.node_chains

    @functools.wraps(_nc)
    def node_chains(traced, ns, whole=False, lists=None, replaceable=None):
        replaced, chains = _nc(traced, ns, whole, lists, replaceable)
        PLANTED[0] += len(replaced)
        return replaced, {n: c for n, c in chains.items() if n not in replaced}

    T.node_chains = node_chains


# The chain cases' plants (check.sh's tracercontrols, "the chain cases"): each runs on the cell whose run.py arguments
# follow OUT, and each must make the cases on that cell fail as check.sh writes.
FILTER_ENTRY_PEER = ("node.py", "Node._peer_promise.<locals>.filter_entry", 1191)
OWED_MISSING = ("node.py", "Node._member_check.<locals>.owed_missing", 502)


def layer_classed_seacast(key, kind):
    """Under v2, a plant of the chain rule's lists: the layer `key` of LAYERS classed `kind` at every node, whatever its
    listing says (a closure-dependent layer's cell no longer read). Counted once for each node where the name's layers
    hold that layer."""
    assert key in T.LAYERS, f"LAYERS lists no {key}: the toy moved"
    name = T.LAYERS[key][0]
    T.LAYERS[key] = (name, kind)
    _nc = T.node_chains

    @functools.wraps(_nc)
    def node_chains(traced, ns, whole=False, lists=None, replaceable=None):
        try:
            ls = T.layers_of(name, ns.get(name))
        except ValueError:
            ls = []
        PLANTED[0] += any(getattr(f, "__code__", None) is not None and T.layer_key(f) == key for f in ls)
        return _nc(traced, ns, whole, lists, replaceable)

    T.node_chains = node_chains


class BoundLog(dict):
    """A node's namespace that logs each binding of a function under a name while the node is built, in order (by
    item, `update` or `setdefault`; the documents' own definitions too, which exec makes by item)."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.bound, self.logging = [], True

    def __setitem__(self, k, v):
        if self.logging and callable(v):
            self.bound.append((k, v))
        super().__setitem__(k, v)

    def update(self, *a, **kw):
        for k, v in dict(*a, **kw).items():
            self[k] = v

    def setdefault(self, k, v=None):
        if k not in self:
            self[k] = v
        return self[k]


def chains_bindings_seacast(toy):
    """Under v2, a plant of the chain rule's walk: each traced name's chain taken from the bindings of its slot while the
    node was built, in binding order (each function bound after the last of the document's under that name, then
    `doc`), instead of the closure walk. Where a layer was bound over another that it does not hold (--fault hoard's
    lambda under a hoarder's push_rebuilt), that binding is in the chain. Only a chain the walk ends in `doc` is
    taken so. Counted once for each chain the bindings change.

    The namespace is the toy's, copied into a BoundLog; the closure cell of `Node._namespace` that holds it (its own
    functions' `ns`) is pointed at the copy, so that the toy's code and the document's both run on the one object."""
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    _namespace = N.Node._namespace

    @functools.wraps(_namespace)
    def namespace(self):
        old = _namespace(self)
        new = BoundLog(old)
        for v in old.values():
            for cell in getattr(v, "__closure__", None) or ():
                try:
                    if cell.cell_contents is old:
                        cell.cell_contents = new
                except ValueError:
                    continue
        for v in old.values():          # no closure of the toy's left on the old dict
            for cell in getattr(v, "__closure__", None) or ():
                try:
                    assert cell.cell_contents is not old, "a closure still holds the toy's first namespace"
                except ValueError:
                    continue
        return new

    N.Node._namespace = namespace
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        ns.logging = False              # the tracer's own bindings are not the node's
        return _install(self, nd, ns)

    T.Tracer3.install = install
    _nc = T.node_chains

    def doc_fn(name, f):
        c = getattr(f, "__code__", None)
        return c is not None and c.co_filename in (T.DOC_FILE, T.SEACAST_FILE) and c.co_name == name

    @functools.wraps(_nc)
    def node_chains(traced, ns, whole=False, lists=None, replaceable=None):
        replaced, chains = _nc(traced, ns, whole, lists, replaceable)
        log = ns.bound
        for name, chain in chains.items():
            fs = [f for k, f in log if k == name]
            last = max((j for j, f in enumerate(fs) if doc_fn(name, f)), default=None)
            if last is None or chain[-1] != "doc":
                continue
            new = [getattr(f, "__qualname__", None) for f in fs[last + 1:]] + ["doc"]
            if new != chain:
                chains[name] = new
                PLANTED[0] += 1
        return replaced, chains

    T.node_chains = node_chains


def draws_rewrap_off_seacast():
    """Under v2, K13's plant: the swapped draws' re-wrap off (`REWRAP[0]` false). Inside a swapped draw's layer the
    document then calls the toy's draw as the layer bound it, and the record's tape lacks the draw. Nothing in the
    tracer asks whether a swapped draw reached the tape: the trace is written to its end, and the replay must refuse
    it at the first record whose draw is missing. Counted once for each call of `rewrap_draws` that skips a draw the
    toy has bound."""
    T.REWRAP[0] = False
    _rd = T.rewrap_draws

    @functools.wraps(_rd)
    def rewrap_draws(ns, slots, rewrap):
        PLANTED[0] += sum(1 for d in T.DRAWS if d in slots and ns.get(d) is not slots[d]
                          and not getattr(ns.get(d), "_trace3_rewrap", False))
        return _rd(ns, slots, rewrap)

    T.rewrap_draws = rewrap_draws


def draws_unrestored_seacast():
    """Under v2, K13's plant: a swapped draw's layer that does not put the slot back. At every node, a layer of this
    tool's own over `keep_floor` (holding the toy's, and listed in LAYERS as a swapped draw), bound before the
    install: it binds `sample_without_replacement` to a draw of its own, calls the layer it holds, and leaves the slot
    so. The check of every installed slot at the record's exit must stop it, final_check's words following at the
    close."""
    def plant(ns):
        inner = ns["keep_floor"]

        def keep_floor(T_):
            ns["sample_without_replacement"] = lambda xs, k: list(xs)[:k]     # never called: the toy's layer binds
            return inner(T_)                                                #   its own over it for the document
        T.LAYERS[T.layer_key(keep_floor)] = ("keep_floor", T.SWAPPED_DRAW)
        ns["keep_floor"] = keep_floor

    before_install_seacast(plant)


def on_chunk_without_p_seacast():
    """Under v2, the plant of a record writer whose arguments are not those of runSeacast's case: records_seacast.py's writer of
    `on_chunk` leaves the peer out, and writes the chunk alone. The tracer checks no record's arity, so the trace is
    written to its end, and the replay must refuse each on_chunk record, as no function of the twin with those
    arguments. Counted once for each on_chunk record written so."""
    import records_seacast as R              # noqa: E402: this directory's, as trace3.py imports it
    params, _, ret = R.TABLE["on_chunk"]

    def without_p(tr, p, f):
        PLANTED[0] += 1
        return [tr.wchunk(f)]

    R.TABLE["on_chunk"] = (params, without_p, ret)


def observer_timer_seacast(off):
    """Under v2, the plant of an observer's own code that arms a timer by the simulator itself, not through the
    namespace's `after` (which iface_of stops). At every node, `completed` (the toy's: by group, the time of its
    completion) becomes a dict whose item assignment first arms a timer of a no-op by `node.sim.after`.
    check_completion's observer assigns it in its own code (node.py's `_seacast`), so the guard over the simulator's `after`
    (sim_guard) must stop the tracer there, in that observer's words. With `off` (the control), the guard is off
    (SIMGUARD): the run goes to its end, and its body is the plain run's, the no-op being no traced name. Counted once
    for each assignment, before its timer (which may stop the run); "completions" is the number of groups completed
    at every node at the run's end."""
    if off:
        T.SIMGUARD[0] = False
    held, total = [], Count()

    def noop():
        pass

    class Completed(dict):
        def __setitem__(self, g, t):
            PLANTED[0] += 1
            self.node.sim.after(self.node, 0.0, noop)
            super().__setitem__(g, t)
            total.n = sum(len(c) for c in held)

    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        c = Completed(nd.completed)
        c.node = nd
        held.append(c)
        nd.completed = c
        return _install(self, nd, ns)

    T.Tracer3.install = install
    SEEN["completions"] = total


def owed_flipped_seacast(kind):
    """Under v2, a plant of a layer's listing that changes only a return: at every node, a layer of this tool's own over
    `owed_missing`, bound before the install and holding the toy's (the member check's, which with the check on calls
    the document's): it calls the layer it holds and returns the opposite. It is listed in LAYERS as `kind`. Listed an
    observer, the record holds the document's questions and reads, and the twin, running the document's function on
    them, gets the answer the toy did not: the replay must refuse each record whose call was flipped, and the tracer,
    whose observer mode stops writes and timers but not a changed return, does not see it. Listed as changing (the
    control), the call is a question with the flipped answer on the tape, and the replay passes. Counted once for each
    node (planted) and once for each call ("flipped")."""
    SEEN["flipped"] = 0

    def plant(ns):
        inner = ns["owed_missing"]

        def owed_missing(g):
            SEEN["flipped"] += 1
            return not inner(g)
        T.LAYERS[T.layer_key(owed_missing)] = ("owed_missing", kind)
        ns["owed_missing"] = owed_missing

    before_install_seacast(plant)


def known_replaced_seacast():
    """Under v2, R3-9's plant (j): a fixture for the rows of `known_in_scope`, which no layer of the toy's binds. At
    every node, a layer of this tool's own over `known_in_scope`, bound before the install and holding the document's:
    it calls it and returns its answer unchanged, and it is listed in LAYERS as changing. So the run is the cell's own
    (the same digest), and each call of `known_in_scope` inside a record is a question, its answer on the tape as the
    twin asks it. Counted once for each node (planted) and once for each call ("calls")."""
    SEEN["calls"] = 0

    def plant(ns):
        inner = ns["known_in_scope"]

        def known_in_scope(g):
            SEEN["calls"] += 1
            return inner(g)
        T.LAYERS[T.layer_key(known_in_scope)] = ("known_in_scope", T.CHANGING)
        ns["known_in_scope"] = known_in_scope

    before_install_seacast(plant)


def verdict_replaced_seacast():
    """Under v2, R3-9's plant (l): a fixture for the rows of `repair_verdict`, as (j) is for `known_in_scope`. The toy's
    one layer that replaces it, `--repair-bias`'s, cannot be traced: it restores a `shuffled` it took before the
    install (node.py's `_repair_bias`), and the record's exit check stops it. At every node, a layer of this tool's own
    over `repair_verdict`, bound before the install and holding what the node held (the member check's observer over
    the document's): it calls it and returns its answer unchanged, and it is listed in LAYERS as changing. So the run is
    the cell's own (the same digest), and each call of `repair_verdict` inside a record is a question, its answer on the
    tape. Counted once for each node (planted) and once for each call ("calls")."""
    SEEN["calls"] = 0

    def plant(ns):
        inner = ns["repair_verdict"]

        def repair_verdict(g):
            SEEN["calls"] += 1
            return inner(g)
        T.LAYERS[T.layer_key(repair_verdict)] = ("repair_verdict", T.CHANGING)
        ns["repair_verdict"] = repair_verdict

    before_install_seacast(plant)


CHAIN_PLANTS = ("--chain-filter-observer-v2", "--chain-bindings-v2", "--chain-owed-observer-v2",
                "--chain-owed-changing-v2", "--owed-flipped-observer-v2", "--owed-flipped-changing-v2",
                "--known-replaced-v2", "--verdict-replaced-v2")


def noask_in_record_seacast():
    """Under v2, piece D's plant (p), point 5: at the first table read inside a record, outside any question or
    suppression, at a node whose queue holds an entry with a chunk, that node's own `filter_entry` is called once, with
    the entry's peer and the entry, both read through the tracer's view (so the reads are the record's). Where the node
    replaces `filter_entry` (hand5-peer, `--promise-mode peer`), the twin has no question for it: the tracer must stop
    before the call runs, with point 5's words. Where it is the document's (seacast/hand5, the control), the call is the
    record's own, and its writes (`sent_to`, or the entry's chunk cleared) are ones the twin's function does not make:
    the replay must refuse that record alone. Counted once, for the call; its node and record on the line."""
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
        if not PLANTED[0] and st and st["depth"] and not st["ext"] and not st["supp"] and st["node"] in nss:
            ns = nss[st["node"]]
            raw = F.unwrap(ns["queue"])
            hit = next(((q, lane, j) for q in sorted(raw) for lane in ("urgent", "normal")
                        for j, e in enumerate(getattr(raw[q], lane)) if e.chunk is not None), None)
            if hit is not None:
                q, lane, j = hit
                PLANTED[0] += 1
                SEEN["node"], SEEN["record"] = st["node"], st["cur"]["fn"]
                ns["filter_entry"](q, getattr(ns["queue"][q], lane)[j])
        return _read(self, t, p)

    F.Recorder.read = read


def bindings_checks_off_seacast(both):
    """Under v2, piece D's plant (q) (`both` false) and point 6's control (`both` true): trace3's record binding check
    (`bindings_check`) skipped at each record's entry, or at its entry and its exit. Under `--source-offers off`, the
    layer's lambda over `announce`, live through publish, is then met at the exit of the record it is bound across (q),
    or not at all (the control: no cell calls it). Counted once for each check skipped."""
    _check = T.bindings_check

    def bindings_check(nid, ns, slots, found, fname, at):
        if at == "entry" or both:
            PLANTED[0] += 1
            return None
        return _check(nid, ns, slots, found, fname, at)
    T.bindings_check = bindings_check


def per_node_depth_seacast():
    """Under v2, piece E's plant (r), E2: each install gets a depth state of its own (step 1's per-node depth, the
    planted fault), and the plant makes no call of its own. On a cell where a question at node a reaches node c's
    traced code (custody-floor-churn1: node a's `keep_floor` opens a link, and node c's `on_open` sends its JOIN and a
    relation inside a's `open_link` question), those calls at c are then records of c's own, which start inside a's
    question: the bare counts then hold none of them, and the body has them inserted. The replay accepts them, for it
    checks each record on the Python's own reads: R7 is the tracer's rule (check.sh's carried cases). Counted once
    for each install."""
    tracer_instance()
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        self.vst = {"depth": 0, "ext": 0, "cur": None, "node": None, "supp": 0}
        PLANTED[0] += 1
        return _install(self, nd, ns)

    T.Tracer3.install = install


def calls_nested_off_seacast():
    """Under v2, plant (u): the calls sidecar (OUT.calls.json) counts no call made inside an open record. The trace and
    its replay are unchanged; calls_seacast.py's reach control must refuse the sidecar, since records of one function
    reach another whose calls inside them are then 0. Counted once for each call left out."""
    tracer_instance()
    _count = T.Tracer3.count_call

    @functools.wraps(_count)
    def count_call(self, name, branch, host=None):
        if branch == "in":
            PLANTED[0] += 1
            return None
        return _count(self, name, branch, host)

    T.Tracer3.count_call = count_call


def calls_iwants_off_seacast():
    """Under v2, plant (v): the calls sidecar counts no IWANT, nor any call of respond, retry_offer or ask_parked
    among its IWANT counts. calls_seacast.py's by-fn control must refuse it where those names' records enqueue one (seacast/
    hand5's respond). Counted once for each call left out."""
    tracer_instance()

    def count_iwants(self, name, branch, rows):
        PLANTED[0] += 1

    T.Tracer3.count_iwants = count_iwants


def timers_note_dropped_seacast():
    """Under v2, timers_seacast.py's plant (i), on das-samplers-mcoff: the first note of a `retry_offer` timer in a question that
    read `interest[g]` is left out of the question's row. The timer is still armed, and its record is written.
    timers_seacast.py's K1 (an ask newly armed with no note) and K4 (a record that nothing armed) must refuse the trace.
    Counted once."""
    _call_log = T.call_log

    def call_log(cr, cw, timers=()):
        if not PLANTED[0] and any(x[0] == "interest" and x[2] is not None for x in cr):
            ts = list(timers)
            j = next((k for k, tm in enumerate(ts) if tm[0] == "after" and tm[2] == "retry_offer"), None)
            if j is not None:
                SEEN["dropped"] = ts.pop(j)[3]
                PLANTED[0] += 1
                timers = ts
        return _call_log(cr, cw, timers)

    T.call_log = call_log


def timers_seacast_node(toy):
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's (one sys.modules entry with trace3's)
    return N


def timers_delay_no_eps_seacast(toy):
    """Under v2, timers_seacast.py's plant (ii), on das-samplers-mcoff: the toy's `deferred_offers` arms its timers without the
    `+ 1e-6`, as `after(max(0.0, due), …)`. It is node.py's own function with that one constant made 0.0 (its code
    object's constants), bound at the end of `_seacast`, before the tracer's install. The timers fire where their notes
    say, so timers_seacast.py's K3 and K4 hold, and K2 must refuse every note. Counted once per node."""
    N = timers_seacast_node(toy)
    _seacast = N.Node._seacast

    @functools.wraps(_seacast)
    def v2(self, ns):
        _seacast(self, ns)
        f = ns["deferred_offers"]
        consts = f.__code__.co_consts
        hits = [k for k, c in enumerate(consts) if type(c) is float and c == 1e-6]
        if len(hits) != 1:
            raise SystemExit(f"tracerfaults3: deferred_offers has {len(hits)} constants 1e-6, not one")
        code = f.__code__.replace(co_consts=tuple(0.0 if k == hits[0] else c for k, c in enumerate(consts)))
        g = types.FunctionType(code, f.__globals__, f.__name__, f.__defaults__, f.__closure__)
        g.__qualname__, g.__kwdefaults__ = f.__qualname__, f.__kwdefaults__
        ns["deferred_offers"] = g
        PLANTED[0] += 1

    N.Node._seacast = v2


class NeverArmed(set):
    """A node's `_retry_armed` under plant (iii): it keeps what is added, and says that no ask is in it."""
    def __contains__(self, a):
        if set.__contains__(self, a):
            PLANTED[0] += 1             # an ask armed already, armed again
        return False


def timers_note_per_index_seacast(toy):
    """Under v2, timers_seacast.py's plant (iii), on das-samplers-mcoff: `deferred_offers` arms a timer for every wanted
    index it is offered, without the toy's `_retry_armed` test, through a `_retry_armed` that says no ask is in it
    (NeverArmed), set at the end of the node's construction, before the tracer's install. timers_seacast.py's K1 must
    refuse the trace, once for each ask armed again, whether or not the entry read interest[g]; K2, K3 and K4 hold.
    Counted once for each ask armed again."""
    N = timers_seacast_node(toy)
    _init = N.Node.__init__

    @functools.wraps(_init)
    def init(self, *a, **kw):
        _init(self, *a, **kw)
        self._retry_armed = NeverArmed(self._retry_armed)

    N.Node.__init__ = init


SILENT_FORWARD =("node.py", "Node._faults.<locals>.forward", 1106)    # LAYERS' key of the silent node's forward


def layer_missing_seacast(toy):
    """Under v2, H4's plant (n): trace3.py's LAYERS without the silent node's layer of `forward` (node.py's
    `Node._faults.<locals>.forward`), which hand5-own's arguments bind at the silent node alone. First the scan's
    lists against the lists so changed (scan_bindings.py's `--lists`): each of its lines that names a difference, and
    its last line, on stderr, each after "tracerfaults3: scan: ". Then the run, whose install at the silent node must
    stop the tracer, with its words."""
    if SILENT_FORWARD not in T.LAYERS:
        raise SystemExit(f"tracerfaults3: {SILENT_FORWARD} is not in trace3.py's LAYERS")
    del T.LAYERS[SILENT_FORWARD]
    PLANTED[0] += 1
    import scan_bindings as S           # noqa: E402: this directory's; it imports the same trace3 module
    Tn, _ = S.load_names(toy)
    if Tn is not T:
        raise SystemExit("tracerfaults3: scan_bindings.py loaded another trace3 module than this tool's")
    out, other = S.lists(S.scan(Path(toy).resolve()), Tn)
    for ln in out:
        if "NOT" in ln:
            print(f"tracerfaults3: scan: {ln}", file=sys.stderr)
    print(f"tracerfaults3: scan: {other} differences from trace3.py's lists" if other else
          "tracerfaults3: scan: the lists as trace3.py's", file=sys.stderr)


def suppressed_filter_seacast(toy, off):
    """Under v2, piece E's E3 (carried 9), as `--suppressed-entry-v2` is for hand5-own's `on_iwant`: on hand5-peer,
    where each node replaces `filter_entry` (`--promise-mode peer`) and the toy enters it outside every record. At such
    a node, a call of its replaced `filter_entry` from outside any record (from the toy's `Node._write`, which the
    simulator calls at depth 0). A layer of this tool's own, bound before the install and live for that call alone,
    calls the same node's traced `held` with a stored chunk's id, and returns, or raises `Planted`, which the call's
    site catches. The tracer must suppress records inside the entry (no record of `held`, a count "s held") and restore
    its state on the raise (`supp` 0 at the catch). With `off`, the layer clears the suppression for its call of
    `held` (depth 0 there, the planted fault): a record of `held` starts inside the replaced name."""
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    tracer_instance()
    live, at, peers = [False], [None], {}
    watch_records(lambda: at[0])

    def stored(ns):                     # a chunk stored at the node with its id cached, or None
        for row in F.unwrap(ns["chunks"]).values():
            for f in (row.values() if hasattr(row, "values") else row):
                if getattr(f, "mid", None):
                    return f
        return None
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        fn = ns["filter_entry"]
        if getattr(getattr(fn, "__code__", None), "co_filename", None) != T.DOC_FILE:  # the node's own: replaced
            s = int(nd.id)
            peers[s] = ns
            st = self.vst

            def filter_entry(*a, **kw):
                if live[0]:
                    mode, live[0] = live[0], False
                    m = stored(ns).mid
                    at[0] = (s, "held")
                    try:
                        if off:
                            saved, st["supp"] = st["supp"], 0
                            try:
                                ns["held"](m)
                            finally:
                                st["supp"] = saved
                        else:
                            ns["held"](m)
                    finally:
                        at[0] = None
                    if mode == "raise":
                        raise Planted()
                    return None
                return fn(*a, **kw)
            ns["filter_entry"] = filter_entry
            T.LAYERS[T.layer_key(filter_entry)] = ("filter_entry", T.CHANGING)
        return _install(self, nd, ns)

    T.Tracer3.install = install
    _w = N.Node._write

    def _write(self, p):            # two entries: the first returns, the second raises (the state restored on both)
        st = TR[0].vst if TR else None
        if (PLANTED[0] < 2 and int(self.id) in peers and st and not st["depth"] and not st["supp"]
                and stored(self.ns) is not None):
            PLANTED[0] += 1
            mode = "return" if PLANTED[0] == 1 else "raise"
            live[0] = mode
            try:
                self.ns["filter_entry"](p, None)
                happened = "returned"
            except Planted:
                happened = "raised"
            SEEN["node s"] = int(self.id)
            SEEN[f"entry {PLANTED[0]}"] = happened      # what the call did, not what was asked of it
            SEEN[f"supp after the {mode}"] = st["supp"]
            SEEN["bare s held"] = TR[0].bare.get(f"{int(self.id)} held", 0)
        return _w(self, p)

    N.Node._write = _write


CELL_PLANTS_Seacast = ("--noask-in-record-v2", "--entry-check-off-v2", "--bindings-checks-off-v2",  # on a cell's arguments
                  "--per-node-depth-v2", "--suppressed-filter-v2", "--suppressed-filter-v2-off",
                  "--timers-note-dropped-v2", "--timers-delay-no-eps-v2", "--timers-note-per-index-v2")   # timers_seacast.py's (i)-(iii)


def hdr_read_seacast(raw):
    """Under v2: at the first read of a table other than `desc` inside a record at node a (no question running), a read
    through `hdr` (`hdr[g]`, g a group node a holds a descriptor of and the record has not touched). Not at a read of
    `desc` itself: a record whose first read is `desc[g]` (v0.11.1's drop_wants_beyond) holds that read whatever the
    plant does, and the control could not tell. With `hdr` re-pointed at the installed
    view, the record as written holds the read of `desc` at g: the line says "desc read in its record: 1". With `raw`
    (the control), that one read goes through `hdr` as the toy bound it, the raw table (kept from before the tracer
    re-pointed it), while `hdr` is re-pointed everywhere else, as in a plain run: the read goes unlogged, "desc read
    in its record: 0", and the body is the plain run's."""
    tracer_instance()
    nss, toy_hdr = {}, {}
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        r = _install(self, nd, ns)
        nss[int(nd.id)] = ns
        return r

    T.Tracer3.install = install
    if raw:
        _repoint = T.Tracer3.repoint_aliases

        def repoint_aliases(self, nd, ns, pre):
            toy_hdr[int(nd.id)] = ns["hdr"]     # the toy's own, for the planted read alone
            return _repoint(self, nd, ns, pre)

        T.Tracer3.repoint_aliases = repoint_aliases
    want, inrec = [None, None], Count()     # the open record and the read's path; whether the record holds it
    own, pg, planting = Count(), [None], [False]    # the control's premise: the record's own reads of desc[g] (by
    #                                                 any route: a read or a scan) after the plant, the planted read
    #                                                 itself kept out; the planted group; the planted read running
    _write = T.Tracer3.write

    @functools.wraps(_write)
    def write(self, rec):
        if rec is want[0]:
            inrec.n = int(any(e[0] == "desc" and e[1] == want[1] for e in rec.get("reads", [])))
        return _write(self, rec)

    T.Tracer3.write = write
    _read = F.Recorder.read

    @functools.wraps(_read)
    def read(self, t, p):
        st = TR[0].vst if TR else None
        if not PLANTED[0] and st and st["depth"] and not st["ext"] and not st["supp"] and t.name != "desc":
            a = st["node"]
            g = next((x for x in F.unwrap(nss[a]["desc"]) if ("desc", (x,)) not in self.first), None)
            if g is not None:
                PLANTED[0] += 1
                want[:] = [st["cur"], self.roots["desc"][0].path((g,))]
                pg[0], planting[0] = g, True
                try:
                    (toy_hdr[a] if raw else nss[a]["hdr"])[g]
                finally:
                    planting[0] = False
                SEEN["node a"] = a
                SEEN["desc read in its record"] = inrec
                SEEN["the record's own reads of it"] = own
        return _read(self, t, p)

    F.Recorder.read = read
    _touch1 = F.Recorder._touch1

    @functools.wraps(_touch1)
    def touch1(self, t, p, rw):
        st = TR[0].vst if TR else None
        if (PLANTED[0] and not planting[0] and rw == "r" and t.name == "desc" and tuple(p) == (pg[0],)
                and st and st["cur"] is want[0]):
            own.n += 1
        return _touch1(self, t, p, rw)

    F.Recorder._touch1 = touch1


def unscanned_layer_seacast(toy):
    """Under v2: a layer over `on_frame` that claims to be the toy's (its code compiled as node.py's, at a line where
    no binding is) and holds the bound `on_frame` in a closure cell, so that the namespace check, which follows the
    layers to SEACAST's own function, passes it. Bound just before the install: the scan of the toy's bindings names no
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


def other_node_seacast():
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


class Count:
    """A count printed by its value at the run's end (an effect that happens after the plant's call)."""
    def __init__(self):
        self.n = 0

    def __str__(self):
        return str(self.n)


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


def bare_in_question_seacast(per_node, callee="N"):
    """Under v2: a question at node a (`peer_id_bytes`, its function replaced before the install by a layer of this
    tool's own, which the tracer then wraps as the question) calls a name at node c, once. The tracer-wide depth makes
    that call bare at node c: no record there, and the trace's body that of the run without the plant.
    - `N` (traced): with one of node c's descriptors; a count `"c N"` in the run's bare counts. With `per_node`, each
      install gets a depth state of its own (today's per-node depth, the planted fault): a record of `N` at node c
      starts inside node a's question.
    - `on_iwant` (hand5-own's arguments): node c the node whose `on_iwant` is replaced (the silent node's, which
      answers nothing); a traced name replaced there, counted `"c on_iwant"` as a traced one is.
    - `after` (a tape question, a timer): node c's `after(0, a callback)`; bare, on no tape, so the body is the plain
      run's (taped on node a's question, it would differ); not counted (no traced name). Its line counts the
      simulator's events pushed for node c with the callback (`Sim.after`), and the callback's runs called by the
      simulator's loop (`Sim.run`) with no question or record open: one each.
    - `after-now` (the control of `after`): the callback run at once, inside the question, and not scheduled (the
      planted fault): none of either."""
    tracer_instance()
    nss, at, replaced_at = {}, [None], set()
    ran, fired = Count(), Count()       # the replaced body's runs, the timer's firings: printed at the run's end
    sched, cb, sims = Count(), [None], []
    watch_records(lambda: at[0])

    def stored(c):                      # a chunk stored at node c with its id cached, or None
        for row in F.unwrap(nss[c]["chunks"]).values():
            for f in (row.values() if hasattr(row, "values") else row):
                if getattr(f, "mid", None):
                    return f
        return None
    _install = T.Tracer3.install

    @functools.wraps(_install)
    def install(self, nd, ns):
        if per_node:
            self.vst = {"depth": 0, "ext": 0, "cur": None, "node": None, "supp": 0}
        st, a = self.vst, int(nd.id)
        nss[a] = ns
        if callee.startswith("after") and not sims:     # the simulator's own scheduling, seen once per run
            sims.append(type(nd.sim))
            _after = sims[0].after

            def after(sim, node, delay, fn, *args):
                if fn is cb[0] and node is not None and int(node.id) == cb[1]:
                    sched.n += 1
                return _after(sim, node, delay, fn, *args)
            sims[0].after = after
        own = ns["on_iwant"]
        if getattr(getattr(own, "__code__", None), "co_filename", None) != T.DOC_FILE:
            replaced_at.add(a)          # the node's own on_iwant (the silent node's), before the tracer wraps it
            if callee == "on_iwant":    # its body marks that the plant's call reached it
                def on_iwant(p, iw, _own=own, _a=a):
                    if at[0] == (_a, "on_iwant"):
                        ran.n += 1
                    return _own(p, iw)
                ns["on_iwant"] = on_iwant
                T.LAYERS[T.layer_key(on_iwant)] = ("on_iwant", T.CHANGING)
        doc = ns["peer_id_bytes"]

        def peer_id_bytes(p):
            if not PLANTED[0] and st["depth"] and st["ext"]:
                if callee == "on_iwant":
                    c = next((i for i in sorted(replaced_at) if i != a), None)
                elif callee == "stale-id":
                    c = next((i for i in sorted(nss) if i != a and stored(i) is not None), None)
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
                            SEEN["the replaced body ran"] = ran
                            nss[c]["on_iwant"](a, None)
                        elif callee == "stale-id":      # a copy of a stored chunk, its cached id made stale
                            f = copy.copy(stored(c))
                            m = f.mid
                            f.mid = m[:36] + bytes([m[36] ^ 1]) + m[37:]
                            nss[c]["message_id"](f)
                        else:
                            def timer():        # fired by the simulator's loop, with nothing open: counted
                                caller = sys._getframe(1).f_code
                                if (caller.co_name == "run" and Path(caller.co_filename).name == "sim.py"
                                        and not st["depth"] and not st["ext"]):
                                    fired.n += 1
                            cb[:] = [timer, c]
                            SEEN["the timer scheduled at node c"] = sched
                            SEEN["fired from the simulator, outside the question"] = fired
                            if callee == "after":
                                nss[c]["after"](0, timer)
                            else:               # the control: run at once, not scheduled
                                timer()
                    finally:
                        at[0] = None
                    if not callee.startswith("after"):
                        SEEN[f"bare c {callee}"] = TR[0].bare.get(f"{c} {callee}", 0)
            return doc(p)
        ns["peer_id_bytes"] = peer_id_bytes
        return _install(self, nd, ns)

    T.Tracer3.install = install


def other_node_tape_seacast():
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


def suppressed_entry_seacast(toy, off):
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
            T.LAYERS[T.layer_key(on_iwant)] = ("on_iwant", T.CHANGING)
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
                happened = "returned"
            except Planted:
                happened = "raised"
            SEEN["node s"] = int(self.id)
            SEEN[f"entry {PLANTED[0]}"] = happened      # what the call did, not what was asked of it
            SEEN[f"supp after the {mode}"] = st["supp"]
            SEEN["bare s N"] = TR[0].bare.get(f"{int(self.id)} N", 0)
        return _w(self, p)

    N.Node._write = _write


FAULTS = ("--made-rows-off", "--alias", "--alias-control", "--installed-flip", "--pending-twice", "--alias-start",
          "--alias-message", "--defer-chain", "--replaced", "--false-wrapper", "--stale-id", "--level1-in-cell",
          "--late-rebind", "--stale-id-callee", "--rebind-after-records", "--limit-fraction",
          "--early-install-v2", "--raw-alias-v2", "--other-node-v2", "--unscanned-layer-v2", "--raw-chunk-id-v2",
          "--hdr-other-v2", "--alias-missing-v2", "--other-node-tape-v2", "--rebound-scanned-v2",
          "--rebind-tape-v2", "--rebind-view-v2", "--stale-id-bare-v2", "--close-keyerror-v2",
          "--param-after-install-v2", "--observer-timer-v2")
# the plants under v2 that must not stop the tracer, with their controls: each prints what it saw
PLANTS = ("--bare-in-question-v2", "--bare-in-question-v2-per-node", "--suppressed-entry-v2",
          "--suppressed-entry-v2-off", "--bare-replaced-v2", "--bare-timer-v2", "--bare-timer-v2-now", "--hdr-read-v2",
          "--hdr-read-v2-raw", "--observer-timer-v2-off", "--on-chunk-without-p-v2", "--chains-omit-v2") + CHAIN_PLANTS + (
          "--draws-rewrap-off-v2", "--draws-unrestored-v2") + CELL_PLANTS_Seacast + (  # K13's two: the first must not
          "--layer-missing-v2",         # stop it, the second must; pieces D's and E's; H4's plant (n), on hand5-own;
          "--calls-nested-off-v2", "--calls-iwants-off-v2")     # piece (b)'s (u) and (v), on hand5
HAND5 =["--nodes", "5", "--degree", "4", "--msgs", "1", "--payload", "16384", "--seed", "7"]
HAND5_OWN = HAND5 + ["--rebuilt", "none", "--fault", "sil30"]   # check.sh's seacast/hand5-own


def main(argv):
    if len(argv) < 3 or argv[0] not in FAULTS + PLANTS:
        print(f"usage: tracerfaults3.py {'|'.join(FAULTS + PLANTS)} TOYDIR OUT.jsonl.gz [directed42.py's arguments ...]",
              file=sys.stderr)
        return 2
    fault, rest = argv[0], argv[1:]
    if fault.endswith("-v2") or "-v2-" in fault:    # under v2: trace3.py's own run of hand5 (or hand5-own)
        if fault == "--early-install-v2":
            early_install_seacast(rest[0])
        elif fault == "--raw-alias-v2":
            raw_alias_seacast()
        elif fault == "--other-node-v2":
            other_node_seacast()
        elif fault == "--unscanned-layer-v2":
            unscanned_layer_seacast(rest[0])
        elif fault == "--raw-chunk-id-v2":
            raw_chunk_id_seacast()
        elif fault == "--hdr-other-v2":
            hdr_other_seacast()
        elif fault == "--alias-missing-v2":
            alias_missing_seacast()
        elif fault.startswith("--bare-in-question-v2"):
            bare_in_question_seacast(per_node=fault.endswith("-per-node"))
        elif fault == "--bare-replaced-v2":
            bare_in_question_seacast(per_node=False, callee="on_iwant")
        elif fault == "--bare-timer-v2":
            bare_in_question_seacast(per_node=False, callee="after")
        elif fault == "--bare-timer-v2-now":
            bare_in_question_seacast(per_node=False, callee="after-now")
        elif fault == "--other-node-tape-v2":
            other_node_tape_seacast()
        elif fault == "--rebound-scanned-v2":
            rebound_scanned_seacast()
        elif fault == "--rebind-tape-v2":
            rebind_tape_seacast()
        elif fault == "--rebind-view-v2":
            rebind_view_seacast()
        elif fault == "--stale-id-bare-v2":
            bare_in_question_seacast(per_node=False, callee="stale-id")
        elif fault == "--close-keyerror-v2":
            close_keyerror_seacast()
        elif fault == "--param-after-install-v2":
            param_after_install_seacast()
        elif fault.startswith("--hdr-read-v2"):
            hdr_read_seacast(raw=fault.endswith("-raw"))
        elif fault.startswith("--observer-timer-v2"):
            observer_timer_seacast(off=fault.endswith("-off"))
        elif fault == "--on-chunk-without-p-v2":
            on_chunk_without_p_seacast()
        elif fault == "--chains-omit-v2":
            chains_omit_seacast()
        elif fault == "--chain-filter-observer-v2":
            layer_classed_seacast(FILTER_ENTRY_PEER, T.OBSERVER)
        elif fault == "--chain-bindings-v2":
            chains_bindings_seacast(rest[0])
        elif fault == "--chain-owed-observer-v2":
            layer_classed_seacast(OWED_MISSING, T.OBSERVER)
        elif fault == "--chain-owed-changing-v2":
            layer_classed_seacast(OWED_MISSING, T.CHANGING)
        elif fault == "--owed-flipped-observer-v2":
            owed_flipped_seacast(T.OBSERVER)
        elif fault == "--owed-flipped-changing-v2":
            owed_flipped_seacast(T.CHANGING)
        elif fault == "--known-replaced-v2":
            known_replaced_seacast()
        elif fault == "--verdict-replaced-v2":
            verdict_replaced_seacast()
        elif fault == "--noask-in-record-v2":
            noask_in_record_seacast()
        elif fault in ("--entry-check-off-v2", "--bindings-checks-off-v2"):
            bindings_checks_off_seacast(both=fault == "--bindings-checks-off-v2")
        elif fault == "--per-node-depth-v2":
            per_node_depth_seacast()
        elif fault.startswith("--suppressed-filter-v2"):
            suppressed_filter_seacast(rest[0], off=fault.endswith("-off"))
        elif fault == "--layer-missing-v2":
            layer_missing_seacast(rest[0])
        elif fault == "--calls-nested-off-v2":
            calls_nested_off_seacast()
        elif fault == "--calls-iwants-off-v2":
            calls_iwants_off_seacast()
        elif fault == "--timers-note-dropped-v2":
            timers_note_dropped_seacast()
        elif fault == "--timers-delay-no-eps-v2":
            timers_delay_no_eps_seacast(rest[0])
        elif fault == "--timers-note-per-index-v2":
            timers_note_per_index_seacast(rest[0])
        elif fault == "--draws-rewrap-off-v2":
            draws_rewrap_off_seacast()
        elif fault == "--draws-unrestored-v2":
            draws_unrestored_seacast()
        else:
            suppressed_entry_seacast(rest[0], off=fault.endswith("-off"))
        if fault in CHAIN_PLANTS + CELL_PLANTS_Seacast:      # the cell's own arguments, after OUT, --doc seacast among them
            args = rest[2:]
            if not any(args[j:j + 2] == ["--doc", "seacast"] for j in range(len(args))):
                print("tracerfaults3: a chain plant runs under v2: its cell's arguments need --doc seacast", file=sys.stderr)
                return 2
        else:
            args = (HAND5_OWN if fault.startswith("--suppressed-entry-v2") or fault in ("--bare-replaced-v2",
                                                                                         "--chains-omit-v2",
                                                                                         "--layer-missing-v2")
                    else HAND5) + ["--doc", "seacast"]
        try:                            # the arguments as check.sh's seacast/hand5 and seacast/hand5-own have them
            T.main([rest[0], rest[1], *args, "--digest"])
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
