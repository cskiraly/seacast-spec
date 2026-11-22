"""seacast.md's closure rule and the call-closure check, for trace3.py under --doc seacast and for gen.py's comparison
of the manifest's QUESTIONS with the code.

The closure rule. Every global that a COVERED function loads is in one class: a view (the manifest's OWN and
FOREIGN), a listed alias (CLOSURE_ALIASES), a constant of the nodes line (NODES_LINE_Seacast), a function in the
manifest's lists (COVERED, KEPT, NODE_OWN's keys, CUT), a question (the manifest's QUESTIONS), a listed enumeration
(ENUMS_Seacast), a builtin of PURE_BUILTINS_Seacast, a pure operation (PURE_Seacast), a constructor (CONSTRUCTORS_Seacast), or the
record's context (CONTEXT_Seacast). The attributes read off a type's `.params` are checked too: a value against the
parameter schema the tracer gives, a call against the type's parameter functions and QUESTIONS.

The call-closure check. Over COVERED and KEPT, a global load of a function the documents define must be a function
in the manifest's lists, a question or an alias. The twin runs COVERED and KEPT functions as its own code, so a call
out of them reaches either code the twin has or a question on the tape. Visiting every COVERED and KEPT function,
and not the covered ones alone, makes the check transitive.

The type's functions and the context. Over COVERED and KEPT, every attribute call named like one of the type's nine
functions (TYPE_CALLS_Seacast) must be a question in QUESTIONS, and a read of one that is not a call is a read the check
cannot follow. Every use of a context global must be in CONTEXT_USES_Seacast (a question) or CONTEXT_REASONS_Seacast (a named
reason why it touches no node state). The limit, as stated when this was decided: methods on a view go through the
view's proxy, so the view logs their effect; methods on a local or on a message argument act on values the record
already holds.

How a global load is found. A load is a name read in a function, outside annotations, that no scope between the
load and the function binds. The scopes are the function's own (its arguments and the names it binds) and those of
each lambda and comprehension around the load. A comprehension's first iterable, and a lambda's defaults, are read
in the scope outside it. Python's symtable checks this reading: the names it finds global must be the ones symtable
calls global and referenced in the function's tables, but for names read in annotations alone. A difference stops
the check. So does a function whose scopes the reading does not follow: one with a global or nonlocal statement, a
decorator, a default that is not a constant, a nested class, an async part or a match statement.

`derive_questions` gives what the code asks, without the registry. Its four groups are: the globals of COVERED
functions that no class but a question takes; the `.params` calls; the type's functions called; and the context
uses' questions. gen.py holds QUESTIONS less QUESTIONS_UNLOADED to it, and the tracer's checks hold the code to
QUESTIONS.

The install's checks hold the classes' lists to what a node runs: `enum_check` (each enumeration's value),
`consts_keys_check` (the nodes entry's constants are NODES_LINE_Seacast) and `type_attrs_check` (a type object's
attributes are TYPE_ATTRS_Seacast).
"""
import ast
import symtable
from types import SimpleNamespace

CLOSURE_ALIASES = {
    "hdr": "desc, a view, under the name seacast.md's code gives it",
    "chunk_id": "message_id, a traced function, under the name seacast.md's code gives it (chunk_id = message_id)"}
# the nodes entry's constants under v2, as trace3.py's install writes them: trace61's four, the client's three limits,
# MAX_PLAIN_CHUNKS, the writer's three cards and FAN_IN, §1's three, §6.4's two, the twelve after them, and SEACAST's five
NODES_LINE_Seacast = (
    "IWANT_WINDOW", "RETRY_SLACK", "PROMISE", "PARK_TTL",
    "MAX_IHAVE_MESSAGES", "MAX_IHAVE_LENGTH", "MAX_PENDING_GROUPS", "MAX_PLAIN_CHUNKS",
    "CANCEL", "PROJECT", "RAREST", "FAN_IN",
    "UNIT", "MAX_CHUNKS", "MAX_SEGMENT_SIZE", "HEARTBEAT", "GOSSIP_FACTOR",
    "D_LAZY", "PACED", "HAVE_TTL", "GOSSIP_RETRANSMISSION", "DESCRIPTOR_IN_CHUNK", "PUSH_TTL", "R", "R_NODE",
    "GUARD_GRACE", "UPLINK", "STRIPE_UPLINK", "W", "WINDOW_TIMEOUT", "SOURCE_OFFERS",
    "ANSWERS_FIRST", "MERGE_HOLDINGS", "ASK_UPLINK", "SAMPLE_OUTSTANDING", "SERVE_BUDGET")
# the toy's enumerations (node.py's namespace and _seacast): each label a string equal to its name, but the two bitmaps,
# given as ("Bits", their int)
ENUMS_Seacast = dict({k: k for k in (
    "ACCEPT", "REJECT", "DEFER", "COLLECTING", "DECODING", "COMPLETE", "INVALID", "REPAIRED", "ASKED", "NOT_REPAIRED",
    "ACK", "PUBLISH", "ALL", "DERIVED", "DECLARED", "FORWARD", "NONE", "IN", "OUT", "BOTH", "ALL_JOINED", "SAMPLE",
    "FAST", "HOME")}, EVERY_INDEX=("Bits", -1), EMPTY=("Bits", 0))
# the builtins a covered function may load: functions of their arguments alone. Any other builtin (getattr, globals,
# vars, print, ...) is in no class: it reaches state or effects by another way than a view
PURE_BUILTINS_Seacast = (
    "abs", "all", "any", "bool", "dict", "divmod", "enumerate", "filter", "float", "frozenset", "int", "isinstance",
    "iter", "len", "list", "map", "max", "min", "next", "range", "reversed", "round", "set", "sorted", "str", "sum",
    "tuple", "zip", "True", "False", "None")
PURE_Seacast = ("popcount", "all_bits", "bitmap",        # bits.py's
           "group", "group_index", "index")         # node.py's, each a function of its argument alone
CONSTRUCTORS_Seacast = ("Ask", "Entry", "Graft", "Have", "Join", "Prune", "Want", "WantIndex")
CONTEXT_Seacast = ("now", "mesh", "gossip_history")
# each use of a context global, by its receiver and its kind (`uses`), that is a question on the tape
CONTEXT_USES_Seacast = {("gossip_history", ".put()"): "gossip_put",
                   ("gossip_history", ".remove_group()"): "gossip_remove_group",
                   ("mesh", "in"): "mesh_has"}
# each use that is no question, with the reason that it touches no node state
CONTEXT_REASONS_Seacast = {("now", "value"): "the record's clock, a number; it is read as a value, and no method of it "
                                        "is called"}
TYPE_CALLS_Seacast = ("cross", "decode", "derived_interest", "family", "header_of", "index_count", "project", "threshold",
                 "verify")
TYPE_ATTRS_Seacast = ("name", "id", "params") + TYPE_CALLS_Seacast

COMPS = (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)
STOPS = tuple(getattr(ast, k) for k in ("Global", "Nonlocal", "ClassDef", "AsyncFunctionDef", "Await", "AsyncFor",
                                        "AsyncWith", "Match") if hasattr(ast, k))


def _arg_names(args):
    return {a.arg for a in args.posonlyargs + args.args + args.kwonlyargs} | {
        a.arg for a in (args.vararg, args.kwarg) if a is not None}


def _binds(node, out):
    """The names `node`'s scope binds, read from inside it: stores and deletes, a nested def's name, an except's and an
    import's names; inside a comprehension only its walruses, which bind in the function around it; nothing inside a
    lambda or a nested def."""
    for ch in ast.iter_child_nodes(node):
        if isinstance(ch, ast.Name) and isinstance(ch.ctx, (ast.Store, ast.Del)):
            out.add(ch.id)
        elif isinstance(ch, ast.FunctionDef):
            out.add(ch.name)
        elif isinstance(ch, ast.Lambda):
            continue
        elif isinstance(ch, COMPS):
            _walruses(ch, out)
            continue
        elif isinstance(ch, ast.ExceptHandler) and ch.name:
            out.add(ch.name)
        elif isinstance(ch, ast.alias):
            out.add((ch.asname or ch.name).split(".")[0])
        if not isinstance(ch, ast.FunctionDef):
            _binds(ch, out)


def _walruses(comp, out):
    for n in ast.walk(comp):
        if isinstance(n, ast.NamedExpr) and isinstance(n.target, ast.Name):
            out.add(n.target.id)


def _comp_binds(comp):
    out = set()
    for g in comp.generators:
        for n in ast.walk(g.target):
            if isinstance(n, ast.Name):
                out.add(n.id)
    return out


def _annotation_ids(fn):
    s = set()
    for n in ast.walk(fn):
        if isinstance(n, ast.AnnAssign):
            s |= {id(x) for x in ast.walk(n.annotation)}
        if isinstance(n, ast.arg) and n.annotation is not None:
            s |= {id(x) for x in ast.walk(n.annotation)}
        if isinstance(n, (ast.FunctionDef, ast.Lambda)) and getattr(n, "returns", None) is not None:
            s |= {id(x) for x in ast.walk(n.returns)}
    return s


class Reading:
    """The two documents' top-level functions, seacast.md's over seacast-lite.md's of the same name, each with its
    symtable, and each function's global loads (`loads`), read once. `annotations=False` reads annotations as loads:
    the self-test's control. `drop` names globals whose loads the reading leaves out: the self-test's planted miss,
    which the comparison with symtable must find."""

    def __init__(self, p_src, seacast_src, annotations=True, drop=()):
        self.skip_annotations = annotations
        self.drop = frozenset(drop)
        self.defs = {}
        for src in (p_src, seacast_src):
            tree = ast.parse(src)
            tables = {}
            for t in symtable.symtable(src, "<document>", "exec").get_children():
                if str(t.get_type()).lower().endswith("function"):
                    tables[(t.get_name(), t.get_lineno())] = t
            for d in tree.body:
                if isinstance(d, ast.FunctionDef):
                    self.defs[d.name] = (d, tables.get((d.name, d.lineno)))
        self._loads = {}

    def loads(self, name):
        """The function's global loads, as (the Name node, its parent), and what stops the reading of it (a
        structure it does not follow, or a difference from symtable)."""
        if name not in self._loads:
            self._loads[name] = self._read(name)
        return self._loads[name]

    def _read(self, name):
        fn, table = self.defs[name]
        stops = []
        if fn.decorator_list:
            stops.append(f"{name}: a decorator")
        for x in fn.args.defaults + [k for k in fn.args.kw_defaults if k is not None]:
            if not isinstance(x, ast.Constant):
                stops.append(f"{name}: a default that is not a constant: {ast.unparse(x)[:40]}")
        for n in ast.walk(fn):
            if isinstance(n, STOPS):
                stops.append(f"{name}: a {type(n).__name__} at line {n.lineno}")
            if isinstance(n, ast.FunctionDef) and n is not fn:
                stops.append(f"{name}: a nested def at line {n.lineno}")
            if isinstance(n, ast.Lambda) and any(not isinstance(x, ast.Constant) for x in
                                                 n.args.defaults + [k for k in n.args.kw_defaults if k is not None]):
                stops.append(f"{name}: a lambda's default that is not a constant, at line {n.lineno}")
        if table is None:
            stops.append(f"{name}: no symtable of its own")
        if stops:
            return [], stops
        ann = _annotation_ids(fn) if self.skip_annotations else set()
        parents = {}
        for n in ast.walk(fn):
            for ch in ast.iter_child_nodes(n):
                parents[id(ch)] = n
        out = []

        def visit(node, chain):
            if isinstance(node, ast.Name):
                if (isinstance(node.ctx, ast.Load) and id(node) not in ann and node.id not in self.drop
                        and not any(node.id in b for b in chain)):
                    out.append((node, parents.get(id(node))))
                return
            if isinstance(node, ast.Lambda):
                b = _arg_names(node.args)
                _binds(node, b)
                visit(node.body, chain + (b,))
                return
            if isinstance(node, COMPS):
                inner = chain + (_comp_binds(node),)
                for i, g in enumerate(node.generators):
                    visit(g.iter, chain if i == 0 else inner)
                    visit(g.target, inner)
                    for c in g.ifs:
                        visit(c, inner)
                for f in ("elt", "key", "value"):
                    if hasattr(node, f):
                        visit(getattr(node, f), inner)
                return
            if isinstance(node, ast.arguments):
                return                          # a lambda's defaults are constants (stopped otherwise)
            for ch in ast.iter_child_nodes(node):
                if ch is fn.returns or ch is fn.args:
                    continue
                visit(ch, chain)

        own = _arg_names(fn.args)
        _binds(fn, own)
        for st in fn.body:
            visit(st, (own,))
        # symtable's reading: the names global and referenced in the function's tables
        sym, todo = set(), [table]
        while todo:
            t = todo.pop()
            sym |= {s.get_name() for s in t.get_symbols() if s.is_global() and s.is_referenced()}
            todo += t.get_children()
        mine = {n.id for n, _ in out}
        # the names read in annotations (the arguments', the return's, an annotated assignment's): symtable may count
        # them as global and referenced, where the reading skips them; every other global of symtable's is read
        anns = _annotation_ids(fn)
        annotated = {n.id for n in ast.walk(fn) if isinstance(n, ast.Name) and id(n) in anns} - mine
        if not mine <= sym or not (sym - mine) <= annotated:
            return [], [f"{name}: the scopes' reading and symtable differ: read as global, not by symtable: "
                        f"{sorted(mine - sym)}; global in symtable, not read: {sorted((sym - mine) - annotated)}"]
        return out, []


def _manifest(m):
    """The manifest's lists as a namespace of sets (a module, a namespace or a dict)."""
    get = (lambda k: m[k]) if isinstance(m, dict) else (lambda k: getattr(m, k))
    return SimpleNamespace(**{k: set(get(k)) for k in ("COVERED", "KEPT", "NODE_OWN", "CUT", "OWN", "FOREIGN",
                                                       "QUESTIONS", "QUESTIONS_UNLOADED")})


def _not_question(k, mm):
    """The class of a global that is no question, or None."""
    if k in mm.OWN or k in mm.FOREIGN:
        return "view"
    if k in CLOSURE_ALIASES:
        return "alias"
    if k in NODES_LINE_Seacast:
        return "nodes-line constant"
    if k in mm.COVERED or k in mm.KEPT or k in mm.NODE_OWN or k in mm.CUT:
        return "listed function"
    if k in ENUMS_Seacast:
        return "enumeration"
    if k in PURE_BUILTINS_Seacast or k in PURE_Seacast or k in CONSTRUCTORS_Seacast:
        return "builtin or pure"
    if k in CONTEXT_Seacast:
        return "context"
    return None


def _undefined(rd, mm, over):
    return [f"{f} in {key}, not a function of the documents" for key, names in over
            for f in sorted(names) if f not in rd.defs]


def _stops(rd, names):
    out = []
    for f in sorted(names):
        if f in rd.defs:
            out += rd.loads(f)[1]
    return out


def _parents(fn):
    p = {}
    for n in ast.walk(fn):
        for ch in ast.iter_child_nodes(n):
            p[id(ch)] = n
    return p


def _context_kind(n, up, par):
    if isinstance(up, ast.Attribute) and up.value is n:
        top = par.get(id(up))
        return f".{up.attr}()" if isinstance(top, ast.Call) and top.func is up else f".{up.attr}"
    # a membership test: the comparator of its own `in` or `not in`, and the last one (a comparator before the last
    # is also the left side of the next comparison: `p in mesh == x` compares mesh as a value too)
    if (isinstance(up, ast.Compare) and up.comparators and up.comparators[-1] is n
            and isinstance(up.ops[-1], (ast.In, ast.NotIn))):
        return "in"
    if isinstance(up, (ast.For, ast.comprehension)) and up.iter is n:
        return "iterated"
    if isinstance(up, ast.Subscript) and up.value is n:
        return "subscript"
    if isinstance(up, ast.Call) and up.func is n:
        return "called"
    return "value"


def _use(recv, kind):
    return recv + kind if kind.startswith(".") else f"{recv} ({kind})"


def groups(rd, m, context_over=("COVERED", "KEPT")):
    """The four groups of what the code asks, each {name: the functions that ask it}, and what the reading leaves
    out: (globals, params_calls, params_values, params_odd, type_calls, type_odd, context, context_uses, classes).
    `context` is {question: functions}; `context_uses` lists (receiver, kind, function) of every context use;
    `classes` is {class: the names in it} of COVERED's globals that are no question."""
    mm = _manifest(m)
    cov = sorted(f for f in mm.COVERED if f in rd.defs)
    both = sorted(f for f in mm.COVERED | mm.KEPT if f in rd.defs)
    ctx = sorted(f for f in set().union(*(getattr(mm, k) for k in context_over)) if f in rd.defs)
    g1, classes = {}, {}
    pcalls, pvals, podd = {}, {}, []
    for f in cov:
        for n, _ in rd.loads(f)[0]:
            c = _not_question(n.id, mm)
            if c is None:
                g1.setdefault(n.id, set()).add(f)
            else:
                classes.setdefault(c, set()).add(n.id)
        fn = rd.defs[f][0]
        par = _parents(fn)
        for n in ast.walk(fn):
            if isinstance(n, ast.Attribute) and n.attr == "params":
                up = par.get(id(n))
                if not (isinstance(up, ast.Attribute) and up.value is n):
                    podd.append(f"a read of .params the check cannot follow, in {f}: {ast.unparse(up)[:60]}")
                    continue
                top = par.get(id(up))
                if isinstance(top, ast.Call) and top.func is up:
                    pcalls.setdefault(up.attr, set()).add(f)
                else:
                    pvals.setdefault(up.attr, set()).add(f)
    tcalls, todd = {}, []
    for f in both:
        fn = rd.defs[f][0]
        par = _parents(fn)
        for n in ast.walk(fn):
            if isinstance(n, ast.Attribute) and n.attr in TYPE_CALLS_Seacast:
                up = par.get(id(n))
                if isinstance(up, ast.Call) and up.func is n:
                    tcalls.setdefault(n.attr, set()).add(f)
                else:
                    todd.append(f"a read of the type's function {n.attr} that is not a call, in {f}: "
                                f"{ast.unparse(up)[:60]}")
    cq, cuses = {}, []
    for f in ctx:
        par = _parents(rd.defs[f][0])
        for n, up in rd.loads(f)[0]:
            if n.id in CONTEXT_Seacast:
                kind = _context_kind(n, up, par)
                cuses.append((n.id, kind, f))
                q = CONTEXT_USES_Seacast.get((n.id, kind))
                if q:
                    cq.setdefault(q, set()).add(f)
    return g1, pcalls, pvals, podd, tcalls, todd, cq, cuses, classes


def derive_questions(rd, m):
    """What the code asks, without the registry: {name: the functions that ask it}, over the four groups; and the
    names of COVERED and KEPT that the documents do not define."""
    mm = _manifest(m)
    g1, pcalls, _, _, tcalls, _, cq, _, _ = groups(rd, m)
    out = {}
    for g in (g1, pcalls, tcalls, cq):
        for k, v in g.items():
            out.setdefault(k, set()).update(v)
    return out, _undefined(rd, mm, (("COVERED", mm.COVERED), ("KEPT", mm.KEPT)))


def closure_check(rd, m, schema_values, type_functions):
    """The closure rule over COVERED: what breaks it, one line each, and its counts."""
    mm = _manifest(m)
    out = _undefined(rd, mm, (("COVERED", mm.COVERED),)) + _stops(rd, mm.COVERED)
    g1, pcalls, pvals, podd, _, _, _, _, classes = groups(rd, m)
    out += [f"{k}, loaded by {', '.join(sorted(v))}, is in no class of the closure rule"
            for k, v in sorted(g1.items()) if k not in mm.QUESTIONS]
    out += [f".params.{a}, read by {', '.join(sorted(v))}, is not in the parameter schema"
            for a, v in sorted(pvals.items()) if a not in schema_values]
    out += [f".params.{a}(), called by {', '.join(sorted(v))}, is not one of the type's parameter functions"
            for a, v in sorted(pcalls.items()) if a not in type_functions]
    out += [f".params.{a}(), called by {', '.join(sorted(v))}, is not a question in QUESTIONS"
            for a, v in sorted(pcalls.items()) if a in type_functions and a not in mm.QUESTIONS]
    out += podd
    counts = {c: len(v) for c, v in classes.items()}
    counts["question"] = len(g1)
    return out, counts, (len(pvals), len(pcalls))


def call_closure_check(rd, m, visit=("COVERED", "KEPT")):
    """Over the functions of `visit`: each global load of a function the documents define that is in no list of the
    manifest, no question and no alias, as `CALLER -> CALLEE`. `visit=("COVERED",)` is the self-test's control."""
    mm = _manifest(m)
    names = set().union(*(getattr(mm, k) for k in visit))
    listed = mm.COVERED | mm.KEPT | mm.NODE_OWN | mm.CUT
    out = _undefined(rd, mm, tuple((k, getattr(mm, k)) for k in visit)) + _stops(rd, names)
    edges = sorted({(f, n.id) for f in names if f in rd.defs for n, _ in rd.loads(f)[0]
                    if n.id in rd.defs and n.id not in listed and n.id not in mm.QUESTIONS
                    and n.id not in CLOSURE_ALIASES})
    out += [f"the call closure: {f} -> {k}: {k} is a function of the documents in no list and no question"
            for f, k in edges]
    return out, len(edges)


def type_call_check(rd, m):
    """Over COVERED and KEPT, each of the type's functions called as an attribute is a question."""
    mm = _manifest(m)
    _, _, _, _, tcalls, todd, _, _, _ = groups(rd, m)
    out = [f"the type's function {a}, called by {', '.join(sorted(v))}, is not a question in QUESTIONS"
           for a, v in sorted(tcalls.items()) if a not in mm.QUESTIONS] + todd
    return out, (len(tcalls), sum(len(v) for v in tcalls.values()))


def context_check(rd, m, over=("COVERED", "KEPT")):
    """Each use of a context global, over `over`, is a question in QUESTIONS (CONTEXT_USES_Seacast) or
    has its named reason (CONTEXT_REASONS_Seacast). `over=("COVERED",)` is the self-test's control."""
    mm = _manifest(m)
    _, _, _, _, _, _, _, cuses, _ = groups(rd, m, context_over=over)
    out, counts = [], {}
    for recv, kind, f in cuses:
        q = CONTEXT_USES_Seacast.get((recv, kind))
        if q is not None:
            if q not in mm.QUESTIONS:
                out.append(f"{_use(recv, kind)} in {f}: its question {q} is not in QUESTIONS")
        elif (recv, kind) not in CONTEXT_REASONS_Seacast:
            out.append(f"{_use(recv, kind)} in {f}: a use of the record's context in neither CONTEXT_USES_Seacast nor "
                       f"CONTEXT_REASONS_Seacast")
        counts[_use(recv, kind)] = counts.get(_use(recv, kind), 0) + 1
    return sorted(set(out), key=out.index), counts


def check(rd, m, schema_values, type_functions):
    """The four checks at a v2 trace's start: what breaks them, and the lines of their counts."""
    bad, counts, (nv, nc) = closure_check(rd, m, schema_values, type_functions)
    b19, edges = call_closure_check(rd, m)
    bt, (tn, tp) = type_call_check(rd, m)
    bc, cc = context_check(rd, m)
    order = ("view", "alias", "nodes-line constant", "listed function", "question", "enumeration", "builtin or pure",
             "context")
    lines = [f"closure_seacast: the closure rule: {sum(counts.values())} globals of COVERED ("
             + ", ".join(f"{c} {counts.get(c, 0)}" for c in order) + f"); .params {nv} values and {nc} calls",
             f"closure_seacast: the call closure: {edges} edges out of the lists",
             f"closure_seacast: the type's functions: {tn} names in {tp} (name, caller) pairs",
             f"closure_seacast: the context uses, {sum(cc.values())}: "
             + ", ".join(f"{k} {v}" for k, v in sorted(cc.items()))]
    return bad + b19 + bt + bc, lines


def enum_check(ns):
    """Each listed enumeration has its value in the node's namespace."""
    out = []
    for k, want in ENUMS_Seacast.items():
        if k not in ns:
            out.append(f"{k} is not in the namespace")
            continue
        v = ns[k]
        if isinstance(want, tuple):
            ok = type(v).__name__ == want[0] and getattr(v, "v", None) == want[1]
            have = f"{type(v).__name__}({getattr(v, 'v', '?')})" if hasattr(v, "v") else repr(v)
            if not ok:
                out.append(f"{k} is {have}, not {want[0]}({want[1]})")
        elif not (type(v) is str and v == want):
            out.append(f"{k} is {v!r}, not {want!r}")
    return out


def consts_keys_check(consts):
    """The nodes entry's constants are NODES_LINE_Seacast, name for name."""
    have, want = set(consts), set(NODES_LINE_Seacast)
    return ([f"the nodes line has {k}, which NODES_LINE_Seacast does not list" for k in sorted(have - want)]
            + [f"NODES_LINE_Seacast lists {k}, which the nodes line does not have" for k in sorted(want - have)])


def type_attrs_check(tid, t):
    """A type object's attributes are TYPE_ATTRS_Seacast, name for name."""
    have, want = set(vars(t)), set(TYPE_ATTRS_Seacast)
    return ([f"type {tid}: attribute {a}, not in TYPE_ATTRS_Seacast" for a in sorted(have - want)]
            + [f"type {tid}: no attribute {a}" for a in sorted(want - have)])


def self_test(N, m, schema_values, type_functions):
    """The checks' cases, on synthetic sources and on the toy's documents with copies of the
    lists, each with the findings it must give; then the controls: a check that finds nothing fails exactly the
    planted cases, a reading that does not skip annotations fails exactly the annotations case, a call closure over
    COVERED alone fails exactly the transitive case, and a context check over COVERED alone fails exactly the KEPT
    case. Returns the number of lines wrong."""
    import copy
    p_src, seacast_src = N.SPEC_SRC, N.generate(N.DOC2)
    base = {k: copy.deepcopy(list(getattr(m, k)) if k != "QUESTIONS_UNLOADED" else dict(getattr(m, k)))
            for k in ("COVERED", "KEPT", "NODE_OWN", "CUT", "OWN", "FOREIGN", "QUESTIONS", "QUESTIONS_UNLOADED")}
    real = {True: Reading(p_src, seacast_src), False: Reading(p_src, seacast_src, annotations=False)}

    def man(**kw):
        d = copy.deepcopy(base)
        for k, v in kw.items():
            d[k] = v(d[k]) if callable(v) else v
        return d

    def synth(src, covered=(), kept=()):
        return src, man(COVERED=list(covered), KEPT=list(kept))

    def without(name):
        return lambda xs: [x for x in xs if x != name]

    tf_without_repair = tuple(x for x in type_functions if x != "REPAIR_TO")
    Bits = N.Bits
    good_ns = {k: (Bits(v[1]) if isinstance(v, tuple) else v) for k, v in ENUMS_Seacast.items()}
    good_consts = dict.fromkeys(NODES_LINE_Seacast, 0)

    def tobj(extra=(), drop=()):
        o = SimpleNamespace(**{a: None for a in TYPE_ATTRS_Seacast if a not in drop})
        for a in extra:
            setattr(o, a, None)
        return o

    # each case: (what, kind, its input, the findings it must give); kind names the check
    cases = [
        ("a covered function that loads FOO, in no class", "closure",
         synth("def c():\n    return FOO + 1\n", ["c"]),
         ["FOO, loaded by c, is in no class of the closure rule"]),
        ("a name in annotations alone", "closure",
         synth("def c(x: Bitmap) -> Bitmap:\n    y: FamilyId = x\n    return y\n", ["c"]), []),
        ("a name stored locally before it is loaded", "closure",
         synth("def c():\n    FOO = 1\n    return FOO\n", ["c"]), []),
        (".params.BAR, outside the schema", "closure",
         synth("def c(T):\n    return T.params.BAR\n", ["c"]),
         [".params.BAR, read by c, is not in the parameter schema"]),
        (".params.REPAIR_TO(...) with REPAIR_TO taken out of the type's parameter functions", "closure-tf",
         synth("def c(T):\n    return T.params.REPAIR_TO(1)\n", ["c"]),
         [".params.REPAIR_TO(), called by c, is not one of the type's parameter functions"]),
        ("p = T.params, then p.M", "closure",
         synth("def c(T):\n    p = T.params\n    return p.M\n", ["c"]),
         ["a read of .params the check cannot follow, in c: p = T.params"]),
        ("the call closure, direct: the documents with fill taken out of COVERED", "calls",
         (None, man(COVERED=without("fill"))),
         ["the call closure: decode_group -> fill: fill is a function of the documents in no list and no question",
          "the call closure: on_validated -> fill: fill is a function of the documents in no list and no question"]),
        ("the call closure, transitive: r (covered) calls k (kept), k calls u, in no list", "calls",
         synth("def r():\n    return k()\n\ndef k():\n    return u()\n\ndef u():\n    return 1\n", ["r"], ["k"]),
         ["the call closure: k -> u: u is a function of the documents in no list and no question"]),
        ("enum_check, COMPLETE bound to 'complete'", "enum", dict(good_ns, COMPLETE="complete"),
         ["COMPLETE is 'complete', not 'COMPLETE'"]),
        ("enum_check, EMPTY bound to Bits(1)", "enum", dict(good_ns, EMPTY=Bits(1)),
         ["EMPTY is Bits(1), not Bits(0)"]),
        ("consts_keys_check, a key added", "consts", dict(good_consts, EXTRA=0),
         ["the nodes line has EXTRA, which NODES_LINE_Seacast does not list"]),
        ("consts_keys_check, a key taken out", "consts",
         {k: v for k, v in good_consts.items() if k != "HEARTBEAT"},
         ["NODES_LINE_Seacast lists HEARTBEAT, which the nodes line does not have"]),
        ("(a): the documents with decode taken out of QUESTIONS", "types",
         (None, man(QUESTIONS=without("decode"))),
         ["the type's function decode, called by decode_group, is not a question in QUESTIONS"]),
        ("f = T.decode in a covered function", "types",
         synth("def c(T):\n    f = T.decode\n    return f(1)\n", ["c"]),
         ["a read of the type's function decode that is not a call, in c: f = T.decode"]),
        ("the addition: a covered function calling gossip_history.clear()", "context",
         synth("def c():\n    gossip_history.clear()\n", ["c"]),
         ["gossip_history.clear() in c: a use of the record's context in neither CONTEXT_USES_Seacast nor "
          "CONTEXT_REASONS_Seacast"]),
        ("the addition: a kept function calling gossip_history.clear()", "context",
         synth("def c():\n    gossip_history.clear()\n", [], ["c"]),
         ["gossip_history.clear() in c: a use of the record's context in neither CONTEXT_USES_Seacast nor "
          "CONTEXT_REASONS_Seacast"]),
        ("f(mesh)", "context", synth("def c(f):\n    return f(mesh)\n", ["c"]),
         ["mesh (value) in c: a use of the record's context in neither CONTEXT_USES_Seacast nor CONTEXT_REASONS_Seacast"]),
        ("for q in mesh", "context", synth("def c():\n    for q in mesh:\n        pass\n", ["c"]),
         ["mesh (iterated) in c: a use of the record's context in neither CONTEXT_USES_Seacast nor CONTEXT_REASONS_Seacast"]),
        ("now.x", "context", synth("def c():\n    return now.x\n", ["c"]),
         ["now.x in c: a use of the record's context in neither CONTEXT_USES_Seacast nor CONTEXT_REASONS_Seacast"]),
        ("the documents with gossip_put taken out of QUESTIONS", "context",
         (None, man(QUESTIONS=without("gossip_put"))),
         ["gossip_history.put() in forward: its question gossip_put is not in QUESTIONS"]),
        ("type_attrs_check, a tenth function added", "attrs", tobj(extra=("extra",)),
         ["type payload: attribute extra, not in TYPE_ATTRS_Seacast"]),
        ("type_attrs_check, verify taken out", "attrs", tobj(drop=("verify",)),
         ["type payload: no attribute verify"]),
        ("the documents with held, a key of NODE_OWN, added to COVERED", "closure",
         (None, man(COVERED=lambda xs: xs + ["held"])),
         ["held in COVERED, not a function of the documents"]),
        ("a covered function with a global statement", "closure",
         synth("def c():\n    global FOO\n    FOO = 1\n    return FOO\n", ["c"]),
         ["c: a Global at line 2"]),
        ("a reading that misses c's load of FOO (planted): the comparison with symtable finds it", "closure-miss",
         synth("def c():\n    return FOO + 1\n", ["c"]),
         ["c: the scopes' reading and symtable differ: read as global, not by symtable: []; global in symtable, "
          "not read: ['FOO']"]),
        ("1 in s == mesh: mesh compared with ==, not tested for a member", "context",
         synth("def c(s):\n    return 1 in s == mesh\n", ["c"]),
         ["mesh (value) in c: a use of the record's context in neither CONTEXT_USES_Seacast nor CONTEXT_REASONS_Seacast"]),
        ("p in mesh == x: mesh the left side of == too", "context",
         synth("def c(p, x):\n    return p in mesh == x\n", ["c"]),
         ["mesh (value) in c: a use of the record's context in neither CONTEXT_USES_Seacast nor CONTEXT_REASONS_Seacast"]),
    ]

    def run(kind, arg, ann=True, visit=("COVERED", "KEPT"), over=("COVERED", "KEPT"), stub=False):
        """A case's findings. `stub`: every check replaced by one that finds nothing, the case's input made as it
        is otherwise (the control of the planted cases)."""
        none = lambda *a, **k: ([], [])       # noqa: E731
        if kind in ("enum", "consts", "attrs"):
            f = {"enum": enum_check, "consts": consts_keys_check,
                 "attrs": lambda t: type_attrs_check("payload", t)}[kind]
            return [] if stub else f(arg)
        src, mm = arg
        rd = (real[ann] if src is None else
              Reading("", src, annotations=ann, drop=("FOO",) if kind == "closure-miss" else ()))
        if kind in ("closure", "closure-miss"):
            return (none if stub else closure_check)(rd, mm, schema_values, type_functions)[0]
        if kind == "closure-tf":
            return (none if stub else closure_check)(rd, mm, schema_values, tf_without_repair)[0]
        if kind == "calls":
            return (none if stub else call_closure_check)(rd, mm, visit=visit)[0]
        if kind == "types":
            return (none if stub else type_call_check)(rd, mm)[0]
        return (none if stub else context_check)(rd, mm, over=over)[0]

    bad = 0
    for what, kind, arg, want in cases:
        got = run(kind, arg)
        ok = got == want
        bad += not ok
        print(f"closure self-test, {what}: {'ok' if ok else f'got {got!r}, must be {want!r}  <-- FAIL'}")

    def control(label, fails, must):
        nonlocal bad
        ok = fails == must
        bad += not ok
        print(f"closure self-test, the control ({label}): {len(fails)} cases fail"
              f"{', as they must' if ok else f': {fails}, must be {must}  <-- FAIL'}")

    planted = [w for w, _, _, want in cases if want]
    control("a check that finds nothing", [w for w, k, a, want in cases if run(k, a, stub=True) != want], planted)
    control("a reading that does not skip annotations",
            [w for w, k, a, want in cases if run(k, a, ann=False) != want], [cases[1][0]])
    control("a call closure over COVERED alone",
            [w for w, k, a, want in cases if k == "calls" and run(k, a, visit=("COVERED",)) != want],
            [cases[7][0]])
    control("a context check over COVERED alone",
            [w for w, k, a, want in cases if k == "context" and run(k, a, over=("COVERED",)) != want],
            [cases[15][0]])
    # the documents as they are, with the lists as they are: no finding
    found, lines = check(real[True], m, schema_values, type_functions)
    ok = not found
    bad += not ok
    print(f"closure self-test, the documents and the lists as they are: "
          f"{'no finding' if ok else f'{found}  <-- FAIL'}")
    for ln in lines:
        print(f"  {ln}")
    return bad
