#!/usr/bin/env python3
"""The toy's bindings of namespace names, read from its source: one row per binding, with its class.

    python3 scan_bindings.py TOYDIR             the rows, one per line
    python3 scan_bindings.py TOYDIR --json      the rows as JSON lines, each with its bound function's source hash
    python3 scan_bindings.py TOYDIR --lists     the lists the rows give, beside trace3.py's hand-kept ones
    python3 scan_bindings.py TOYDIR --followed  the code each observer verdict rests on beyond its row's own body
    python3 scan_bindings.py TOYDIR --pins FILE that code against FILE's (followed-pins.txt): a line per difference
    python3 scan_bindings.py --self-test        one planted binding per form, each reported; each form's reader off
                                                in turn, its row missing; a changed body, its row's hash alone moved

A binding is any of the forms the toy uses to put a name in a node's namespace: `ns[name] = v` (a subscript), a
tuple target holding such subscripts, `ns.update(name=v)` (a keyword), `ns.update({name: v})` (a dict key),
`ns.update({k: v for k, v in locals().items() if …})` (a `locals()` export, resolved to the enclosing function's
functions made before it, less the comprehension's exclusions), `ns.setdefault(name, v)`, a subscript whose key is
not a literal (a computed key), an attribute set on a parameter object (an `Obj()` or a `.params`), and the
namespace's own making, `ns = {name: v, …}` (a namespace literal). A namespace is a name `ns`, or an attribute `.ns`.
A bound value is read as a function where it names one: a local function or lambda, a function of the same module,
one imported from another of the toy's modules (`from bits import popcount`, `wire as Wm` and `Wm.sha256`), or a
method of the enclosing class (`self.m`, `node.m`).

Each function bound has a class:
- **observer**: it holds the earlier binding of its name (a closure variable assigned from `ns[name]` before it, or
  a node attribute so assigned, `self._doc_x = ns["x"]`) and passes the observer test: its code names a question
  (trace3.py's TAPE, and seacast.md's: the names its functions call that no document defines and that the toy
  binds under v2 alone) or a traced function other than the earlier binding only in a direct call, and the body
  each such call reaches is read by the same test (on_want's layer calls `probe_of_claim` and `resolve`); it
  assigns, deletes or mutates no table,
  through its own aliases too, following the local functions, lambdas and node methods it calls with the tables it
  hands them; on a table, or on what a table's method returns, it calls only the methods that read it, and it hands
  a table to no call the test cannot follow (a builtin but those it takes as reads, `len`, `sorted`, ...); the functions
  and lambdas made inside it are read as its own code; it rebinds no namespace name (a scalar too: a layer
  that changes a node constant around the call, as the peer promise's `filter_entry` sets PROMISE, is a changing
  layer); and it calls the earlier binding once on every path (branches, `try`, `with`, loops walked; a statement
  the walk does not follow, `match` among them, holds no call and no return; a `try`'s `else` with handlers neither),
  never in a function made inside it, the earlier binding's name bound nowhere in its body,
  with its own parameters unchanged (a handler's, a pattern's or a walrus's name counts) and nothing more, returning
  its result, or nothing where the document's function returns nothing (a least fixpoint over both documents:
  `return f(...)` of a function that returns nothing returns nothing). `message_id`'s cache is an observer by name
  (it skips the call on a hit). The test is a reading of the syntax, not a proof. What it can miss: an effect in a
  form it does not read as one. In followed code, `e = self._have[g]; e |= g` passes, and the toy's bitmaps (`Bits`)
  join in place in `__ior__`. The code that a row's observer verdict rests on beyond its own body is pinned by its
  source (`--followed`, `--pins`), and a change there fails check.sh's scope step until the row is read again.
- **layer**: it holds the earlier binding and fails the test (the reason is given); one that passes it where it
  may name and bind a draw's slot (DRAWS: `choice`, `sample_without_replacement`, `shuffled`) is marked a swapped
  draw, which the tracer re-wraps while it is bound;
- **closure-dependent**: its first statement branches on a value the node is made with (no parameter of its own,
  no field, call or element, each name bound exactly once in the nearest enclosing function that binds it and
  rebound by no `nonlocal` or `global` there; a module's global is state): its class per branch is given, under
  each document it may run under where the two differ (`owed_missing`'s `--member-check`: `not on`, own; else,
  observer), and the node's own value is read where classes are first read;
- **per-document**: an observer under one document and a layer under the other, its class under each given. A
  row's classes are conditional on the document: the scan does not establish which run reaches a binding (a
  fixture whose callers make v2 nodes alone is classed under both documents);
- **own**: any other function (a lambda included);
- **value**: anything else (a table, a constant, a class, an expression); a name that holds another slot's value
  (`chunk_id = ns["message_id"]`) is marked as its alias.
Each clause of the test can be switched off (`scan(…, off=…)`), so that the self-test shows each one doing its part.
A binding in a method that `Node.__init__` calls only under `if self.seacast` (and in what such a method calls), or
inside such a branch of `__init__`, is marked v2-only: under seacast-lite.md it never runs.
"""
import ast
import hashlib
import json
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
FORMS = ("subscript", "tuple", "update-keyword", "update-dict", "locals-export", "setdefault", "computed-key",
         "parameter-attribute", "namespace-literal")
MUTATORS = {"add", "append", "appendleft", "extend", "extendleft", "insert", "pop", "popleft", "popitem", "remove",
            "discard", "clear", "update", "setdefault", "sort", "reverse", "__setitem__", "__delitem__", "set", "unset",
            "difference_update", "intersection_update", "symmetric_difference_update"}
# the methods that only read a dict, a set, a list or a deque, taken as reads of a table: any other call on a
# table, or on what one of its methods returns, is one the test cannot establish as a read, and denies
READONLY_METHODS = {"get", "keys", "values", "items", "copy", "count", "index", "issubset", "issuperset", "isdisjoint",
                    "union", "intersection", "difference", "symmetric_difference", "__contains__", "__len__",
                    "__iter__", "__getitem__"}
# the builtins taken as reads of what they are handed: any other builtin handed a table denies (setattr, map, ...).
# What this can miss: a builtin that runs what it is handed; `sorted(g, key=node.consume_draw)` passes
READONLY_BUILTINS = {"len", "list", "tuple", "set", "frozenset", "dict", "sorted", "reversed", "iter", "next",
                     "enumerate", "zip", "sum", "min", "max", "any", "all", "isinstance", "bool", "int", "float", "str",
                     "repr", "hash", "id", "type", "abs", "round", "range", "callable", "bytes", "hasattr"}
# the toy's own methods taken as reads (a bitmap's `has`), each only where the scan finds that every definition of
# that name in the toy's classes only reads: no field or element assigned or deleted, and no call but these reads,
# the methods above and the builtins above (`Scanner.toy_reads`); else it is no read
TOY_READS = {"has"}
BY_NAME = {"message_id": "a cache: it skips the call on a hit"}     # observers by name
# the draws a layer may swap (trace3.py's DRAWS, held to it by lists): a layer that passes the observer test where
# it may name and bind these slots is a swapped draw
DRAWS = ("choice", "sample_without_replacement", "shuffled")
# the pure operations a followed body may call, as (the name called on, the attribute): each reads only what it is
# handed and changes nothing. An entry is added by a dated amendment to the known answer that names its reason
PURE_CALLS = {("int", "from_bytes")}    # a new int from the bytes handed
NS_ALIASES = {}                         # file name -> the names that file binds to the namespace (`nsc = nc.ns`)
NS_FILE = [None]                        # the file whose aliases is_ns reads: the one scanned, or the one followed into


def own_nodes(node):
    """The nodes of a function's (or lambda's) own scope: its body, less the bodies of the functions, lambdas and
    classes made in it, which are yielded themselves (their names are bound in it)."""
    todo = list(node.body) if isinstance(node.body, list) else [node.body]
    while todo:
        n = todo.pop()
        yield n
        if not isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef)):
            todo.extend(ast.iter_child_nodes(n))


def is_ns(e):
    return ((isinstance(e, ast.Name) and (e.id == "ns" or e.id in NS_ALIASES.get(NS_FILE[0], ())))
            or (isinstance(e, ast.Attribute) and e.attr == "ns"))


def ns_key(e):
    """For `ns[...]`: the literal key, or None for a computed one."""
    k = e.slice
    return k.value if isinstance(k, ast.Constant) and isinstance(k.value, str) else None


def first_line(fn):
    """The line Python gives the function's code (co_firstlineno): the first decorator's, else the def's."""
    return min([d.lineno for d in getattr(fn, "decorator_list", ())] + [fn.lineno])


SOURCES = {}        # a function's or lambda's node, by id -> (its file or document, its qualified name, the source)
KEPT = []           # every tree named in SOURCES, kept, so that no id is reused


def name_bodies(tree, label, src):
    """Each function and lambda of a tree, named for the followed code's listing: its file or document, its qualified
    name (Python's __qualname__; a lambda `<lambda>`; a second of a name in one scope numbered #2) and its source."""
    KEPT.append(tree)
    stack = [(tree, "", {})]
    while stack:
        node, prefix, counts = stack.pop()
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda)):
            n = getattr(node, "name", "<lambda>")
            counts[n] = counts.get(n, 0) + 1
            q = prefix + n + (f"#{counts[n]}" if counts[n] > 1 else "")
            SOURCES[id(node)] = (label, q, src)
            prefix, counts = q + ("." if isinstance(node, ast.ClassDef) else ".<locals>."), {}
        stack.extend((c, prefix, counts) for c in reversed(list(ast.iter_child_nodes(node))))


def body_of(node):
    """A walked body's file or document, its qualified name and its source's sha256 (a body no tree named: "?")."""
    label, qual, src = SOURCES.get(id(node), ("?", f"{getattr(node, 'name', '<lambda>')}@{node.lineno}", None))
    seg = (ast.get_source_segment(src, node) or "") if src is not None else ast.unparse(node)
    return label, qual, hashlib.sha256(seg.encode()).hexdigest()


class Func:
    """A function the toy defines: its node, qualified name, the scope it is made in and its source's hash."""
    def __init__(self, node, qual, scope, src, path):
        self.node, self.qual, self.scope, self.path = node, qual, scope, path
        self.line = first_line(node)
        self.static = False                     # a static method: its first parameter is no receiver
        seg = ast.get_source_segment(src, node) or ""
        self.sha = hashlib.sha256(seg.encode()).hexdigest()


class Scope:
    """A function's body as the scan sees it: its local functions by name, its `v = ns["x"]` captures, and its
    parameter objects."""
    def __init__(self, node, qual, parent):
        self.node, self.qual, self.parent = node, qual, parent
        self.funcs = {}             # local name -> Func (defs, and lambdas assigned to a name)
        self.captures = {}          # local name -> the namespace name it was assigned from
        self.params_objs = set()    # local names bound to an Obj() or a .params
        self.order = []             # (statement index, local name) for locals() exports, in order of definition
        self.rebound = set()        # local names last bound to something the scan does not read as a function
        self.fresh = set()          # (followed code) local names bound only to a new object: a display, a
        #                             comprehension, a new container, a toy class's constructor; `self` in __init__
        self.bound = set()          # (followed code) every name the function binds: a call of one is no module's

    def lookup(self, name, attr):
        s = self
        while s is not None:
            if attr == "funcs" and name in s.rebound:
                return None         # rebound after its def (rq = wrap(rq)), or a decorated def: not read
            d = getattr(s, attr)
            if name in d:
                return d[name]
            s = s.parent
        return None

    def shadowed(self, name):
        """Whether the nearest scope that binds `name` binds it to what the scan does not read as a function."""
        s = self
        while s is not None:
            if name in s.rebound:
                return True
            if name in s.funcs:
                return False
            s = s.parent
        return False

    def is_param_obj(self, name):
        s = self
        while s is not None:
            if name in s.params_objs:
                return True
            s = s.parent
        return False


def params_of(fn):
    a = fn.args
    return [x.arg for x in a.posonlyargs + a.args], [x.arg for x in a.kwonlyargs], a.vararg, a.kwarg


class Scanner:
    def __init__(self, skip=(), off=()):
        self.skip = set(skip)       # forms whose reader is off (the self-test's control)
        self.off = set(off)         # clauses of the observer test that are off (the self-test's control)
        self.rows, self.funcs, self.methods = [], [], {}
        self.reads = set(READONLY_METHODS)  # with the toy's reads that hold (scan(), toy_reads)
        self.attr_captures = {}     # (file, attribute) -> the namespace name a node attribute was assigned from
        self.traced, self.questions = TRACED, QUESTIONS_DOC
        self.exempt = ()            # the slots the observer test lets a layer name and bind (observer_test)
        self.walked_now = None      # the bodies the running observer test walks (names_and_writes)
        self.observed = []          # the bodies walked by a row's tests that gave an observer verdict (row)
        self.followed = []          # (row, {(file or document, qualified name): sha256}) of each row whose observer
        #                             verdict rests on code beyond its own body
        self.globals = {}           # (file, name or Class.method) -> Func: the modules' functions and methods
        self.imports = {}           # (file, local name) -> (module file, name), or (module file, None) for a module
        self.collect = None         # the pre-pass (scan): every binding's function by name, None where a value
        self.bound_by = {}          # its result, for the observer test's follow: name -> [Func or None]; None's key
        #                             holds the computed keys' (which may bind any name)
        self.depth = 0              # the observer test's depth: 0 in the layer's own code, more in what it follows
        self.doc = None             # the document the observer test runs under
        self.classes = {}           # (file, class name) -> its ClassDef: a module's own classes (a constructor)
        self.all_classes = []       # every class of the toy, one made inside a function too
        self.reads_anywhere = set() # the read methods a followed body may call on anything: READONLY_METHODS and
        #                             toy_reads, less a name a toy class defines with a body that does more than read

    def prepass(self, path):
        """A module's own functions and methods, and its imports of the toy's other modules (path's siblings)."""
        src = path.read_text()
        tree = ast.parse(src)
        name_bodies(tree, path.name, src)
        mod = Scope(tree, "", None)
        toy = {p.name for p in path.parent.glob("*.py")}
        aliases = set()                     # the names this file binds to the namespace, read as `ns` in it
        for n in ast.walk(tree):
            if isinstance(n, ast.Assign) and "ns-alias" not in self.skip:
                for t in n.targets:
                    pairs = (list(zip(t.elts, n.value.elts)) if isinstance(t, ast.Tuple) and isinstance(n.value, ast.Tuple)
                             and len(t.elts) == len(n.value.elts) else [(t, n.value)])
                    aliases |= {tt.id for tt, vv in pairs if isinstance(tt, ast.Name) and tt.id != "ns"
                                and ((isinstance(vv, ast.Name) and vv.id == "ns")
                                     or (isinstance(vv, ast.Attribute) and vv.attr == "ns"))}
        NS_ALIASES[path.name] = aliases
        self.all_classes.extend(n for n in ast.walk(tree) if isinstance(n, ast.ClassDef))
        for n in ast.walk(tree):            # node attributes assigned from the namespace (self._doc_x = ns["x"])
            if isinstance(n, ast.Assign):
                for t in n.targets:
                    pairs = (list(zip(t.elts, n.value.elts)) if isinstance(t, ast.Tuple) and isinstance(n.value, ast.Tuple)
                             and len(t.elts) == len(n.value.elts) else [(t, n.value)])
                    for tt, vv in pairs:
                        if (isinstance(tt, ast.Attribute) and isinstance(tt.value, ast.Name)
                                and tt.value.id in ("self", "node") and isinstance(vv, ast.Subscript)
                                and is_ns(vv.value) and ns_key(vv)):
                            self.attr_captures[(path.name, tt.attr)] = ns_key(vv)
        for st in tree.body:
            if isinstance(st, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if not st.decorator_list or "decorated" in self.skip:   # a decorated function: not read
                    self.globals[(path.name, st.name)] = Func(st, st.name, mod, src, path)
            elif isinstance(st, ast.ClassDef):
                self.classes[(path.name, st.name)] = st
                for m in st.body:
                    if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        static = [d for d in m.decorator_list if isinstance(d, ast.Name) and d.id == "staticmethod"]
                        if len(static) < len(m.decorator_list) and "decorated" not in self.skip:
                            continue        # a method decorated with anything but staticmethod: not read
                        q = f"{st.name}.{m.name}"
                        f = self.globals[(path.name, q)] = Func(m, q, Scope(st, st.name, mod), src, path)
                        f.static = bool(static) and "static" not in self.skip    # (its reader off: a receiver)
            elif isinstance(st, ast.ImportFrom) and not st.level and f"{st.module}.py" in toy:
                for a in st.names:
                    self.imports[(path.name, a.asname or a.name)] = (f"{st.module}.py", a.name)
            elif isinstance(st, ast.Import):
                for a in st.names:
                    if f"{a.name}.py" in toy:
                        self.imports[(path.name, a.asname or a.name)] = (f"{a.name}.py", None)

    def resolve(self, value, scope):
        """The function a bound value names, or None."""
        if isinstance(value, ast.Lambda):
            return Func(value, f"{scope.qual}.<locals>.<lambda>", scope, self.src, self.path)
        here = self.path.name
        if isinstance(value, ast.Name):
            f = scope.lookup(value.id, "funcs")
            if f is not None:
                return f
            if scope.shadowed(value.id):
                return None
            f = self.globals.get((here, value.id))
            if f is not None:
                return f
            imp = self.imports.get((here, value.id))
            return self.globals.get(imp) if imp and imp[1] is not None else None
        if isinstance(value, ast.Attribute) and isinstance(value.value, ast.Name):
            imp = self.imports.get((here, value.value.id))
            if imp and imp[1] is None:
                return self.globals.get((imp[0], value.attr))
            if value.value.id in ("self", "node"):
                s = scope
                while s is not None and not isinstance(s.node, ast.ClassDef):
                    s = s.parent
                if s is not None:
                    return self.globals.get((here, f"{s.qual}.{value.attr}"))
        return None

    # -- the walk ---------------------------------------------------------------------------------------------
    def scan_file(self, path):
        src = path.read_text()
        tree = ast.parse(src)
        name_bodies(tree, path.name, src)
        self.src, self.path = src, path
        NS_FILE[0] = path.name
        if self.collect is not None:        # the pre-pass: each node's parent, for a computed key's loop
            self.parents = {id(c): p for p in ast.walk(tree) for c in ast.iter_child_nodes(p)}
        for cls in tree.body:       # a class's methods by name, for the observer test's call following
            if isinstance(cls, ast.ClassDef):
                for m in cls.body:
                    if isinstance(m, ast.FunctionDef) and (not m.decorator_list or "decorated" in self.skip):
                        self.methods[(path.name, cls.name, m.name)] = m     # (a decorated one: not followed)
        self.seacast_methods, self.seacast_lines = self.seacast_only(tree)
        self.body(tree.body, Scope(tree, "", None), cls=None)

    def body(self, stmts, scope, cls):
        for i, st in enumerate(stmts):
            self.stmt(st, scope, cls, i)

    def stmt(self, st, scope, cls, i):
        if isinstance(st, ast.ClassDef):
            if isinstance(scope.node, ast.Module):
                qual = st.name
            elif isinstance(scope.node, ast.ClassDef):
                qual = f"{scope.qual}.{st.name}"
            else:                       # a class made inside a function: a local (callable, so a locals() export)
                qual = f"{scope.qual}.<locals>.{st.name}"
                scope.funcs[st.name] = None
                scope.order.append((st.lineno, st.name))
            self.body(st.body, Scope(st, qual, scope), cls=st.name)
            return
        if isinstance(st, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if isinstance(scope.node, ast.Module):
                qual = st.name
            elif isinstance(scope.node, ast.ClassDef):
                qual = f"{scope.qual}.{st.name}"
            else:
                qual = f"{scope.qual}.<locals>.{st.name}"
            f = Func(st, qual, scope, self.src, self.path)
            self.funcs.append(f)
            if not isinstance(scope.node, (ast.Module, ast.ClassDef)):
                scope.funcs[st.name] = f
                scope.order.append((st.lineno, st.name))
                if st.decorator_list and "decorated" not in self.skip:
                    scope.rebound.add(st.name)      # what the decorator returns is not this body
                else:
                    scope.rebound.discard(st.name)
            inner = Scope(st, qual, scope)
            self.body(st.body, inner, cls=None)
            return
        self.visit_exprs(st, scope)
        if isinstance(st, ast.Assign):
            self.assign(st, st.targets, st.value, scope, i)
        elif isinstance(st, (ast.AugAssign, ast.AnnAssign)) and st.value is not None:
            self.assign(st, [st.target], st.value, scope, i)
        for field in ("body", "orelse", "finalbody"):
            sub = getattr(st, field, None)
            if isinstance(sub, list) and sub and isinstance(sub[0], ast.stmt):
                self.body(sub, scope, cls)
        for h in getattr(st, "handlers", ()) or ():
            self.body(h.body, scope, cls)

    def visit_exprs(self, st, scope):
        """The calls in a statement's own expressions (not its nested statements): update and setdefault."""
        nodes = []
        for field, val in ast.iter_fields(st):
            if field in ("body", "orelse", "finalbody", "handlers"):
                continue
            for v in (val if isinstance(val, list) else [val]):
                if isinstance(v, ast.AST):
                    nodes.append(v)
        for top in nodes:
            for n in ast.walk(top):
                if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and is_ns(n.func.value):
                    if n.func.attr == "update":
                        self.update(n, scope, st)
                    elif n.func.attr == "setdefault" and "setdefault" not in self.skip and n.args:
                        k = n.args[0]
                        name = k.value if isinstance(k, ast.Constant) and isinstance(k.value, str) else None
                        v = n.args[1] if len(n.args) > 1 else None
                        if name is None:
                            self.row(n, "computed-key", f"<{ast.unparse(k)}>", v, scope, via="setdefault")
                        else:
                            self.row(n, "setdefault", name, v, scope)

    def update(self, call, scope, st):
        for kw in call.keywords:
            if kw.arg is not None and "update-keyword" not in self.skip:
                self.row(call, "update-keyword", kw.arg, kw.value, scope)
            elif kw.arg is None and "update-starred" not in self.skip:     # ns.update(**d)
                d = kw.value
                if isinstance(d, ast.Dict) and all(isinstance(k, ast.Constant) and isinstance(k.value, str)
                                                   for k in d.keys):
                    for k, v in zip(d.keys, d.values):      # a literal's keys, as update-dict's
                        self.row(call, "update-dict", k.value, v, scope)
                else:                                       # any other: a key the scan cannot name
                    self.row(call, "computed-key", f"<**{ast.unparse(d)[:60]}>", None, scope, via="update")
        for a in call.args:
            if isinstance(a, ast.Dict):     # a dict's keys read here alone (its reader off: no row of it at all)
                if "update-dict" in self.skip:
                    continue
                for k, v in zip(a.keys, a.values):
                    if isinstance(k, ast.Constant) and isinstance(k.value, str):
                        self.row(call, "update-dict", k.value, v, scope)
                    elif k is not None and "computed-key" not in self.skip:
                        self.row(call, "computed-key", f"<{ast.unparse(k)}>", v, scope, via="update")
            elif isinstance(a, ast.DictComp) and self.is_locals(a):
                if "locals-export" not in self.skip:
                    for name in self.exported(a, scope, st):
                        self.row(call, "locals-export", name, ast.Name(id=name, ctx=ast.Load()), scope)
            elif "computed-key" not in self.skip:
                self.row(call, "computed-key", f"<{ast.unparse(a)[:80]}>", None, scope, via="update")

    @staticmethod
    def is_locals(dc):
        g = dc.generators[0]
        it = g.iter
        return (isinstance(it, ast.Call) and isinstance(it.func, ast.Attribute) and it.func.attr == "items"
                and isinstance(it.func.value, ast.Call) and isinstance(it.func.value.func, ast.Name)
                and it.func.value.func.id == "locals")

    def exported(self, dc, scope, st):
        """A locals() export: the enclosing function's functions and classes made before the statement, less the
        names the comprehension's conditions leave out (`k not in (...)`, `not k.startswith("_")`)."""
        g = dc.generators[0]
        excluded, no_underscore = set(), False
        for cond in g.ifs:
            for n in ast.walk(cond):
                if isinstance(n, ast.Compare) and any(isinstance(o, ast.NotIn) for o in n.ops):
                    for c in n.comparators:
                        if isinstance(c, (ast.Tuple, ast.List, ast.Set)):
                            excluded |= {e.value for e in c.elts if isinstance(e, ast.Constant)}
                if (isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "startswith"
                        and n.args and isinstance(n.args[0], ast.Constant) and n.args[0].value == "_"):
                    no_underscore = True
        out = []                        # every local made before the statement (by line): a def, a class, a
        for ln, name in scope.order:    #   lambda, or any name assigned (an alias as chunk_id, a class as Ask)
            if ln >= st.lineno or name in out:
                continue
            if name in excluded or (no_underscore and name.startswith("_")):
                continue
            out.append(name)
        return out

    def assign(self, st, targets, value, scope, i):
        # the captures (v = ns["x"]; a, b = ns["x"], ns["y"]) and the parameter objects (P = Obj(); c = t.params)
        for t in targets:
            pairs = [(t, value)]
            if isinstance(t, ast.Tuple) and isinstance(value, ast.Tuple) and len(t.elts) == len(value.elts):
                pairs = list(zip(t.elts, value.elts))
            for tt, vv in pairs:
                if isinstance(tt, ast.Name):
                    if (isinstance(vv, ast.Lambda) or self.resolve(vv, scope) is not None
                            or (isinstance(vv, ast.Subscript) and is_ns(vv.value) and ns_key(vv))
                            or (isinstance(vv, ast.Attribute) and isinstance(vv.value, ast.Name)
                                and ((self.path.name, vv.value.id) in self.imports
                                     or (self.path.name, vv.attr) in self.attr_captures))):
                        scope.order.append((st.lineno, tt.id))     # a local that can be callable: a locals() export
                    if isinstance(vv, ast.Subscript) and is_ns(vv.value) and ns_key(vv):
                        scope.captures[tt.id] = ns_key(vv)
                    elif (isinstance(vv, ast.Attribute) and isinstance(vv.value, ast.Name)
                          and vv.value.id in ("self", "node") and (self.path.name, vv.attr) in self.attr_captures):
                        scope.captures[tt.id] = self.attr_captures[(self.path.name, vv.attr)]   # x = self._doc_x
                    if isinstance(vv, ast.Lambda):
                        scope.funcs[tt.id] = Func(vv, f"{scope.qual}.<locals>.<lambda>", scope, self.src, self.path)
                        scope.rebound.discard(tt.id)
                    elif isinstance(vv, (ast.Name, ast.Attribute)) and self.resolve(vv, scope) is not None:
                        scope.funcs[tt.id] = self.resolve(vv, scope)    # another name of a function (x = topic_peers)
                        scope.rebound.discard(tt.id)
                    elif "rebound" not in self.skip:
                        scope.rebound.add(tt.id)    # bound to what the scan does not read as a function (rq = wrap(rq))
                    if ((isinstance(vv, ast.Call) and isinstance(vv.func, ast.Name) and vv.func.id == "Obj")
                            or (isinstance(vv, ast.Attribute) and vv.attr == "params")):
                        scope.params_objs.add(tt.id)
                elif (isinstance(tt, ast.Attribute) and isinstance(tt.value, ast.Name) and tt.value.id in ("self", "node")
                      and isinstance(vv, ast.Subscript) and is_ns(vv.value) and ns_key(vv)):
                    self.attr_captures[(self.path.name, tt.attr)] = ns_key(vv)   # self._doc_x = ns["x"]
        # the bindings: the namespace's own making (ns = {...}), then the targets
        if "namespace-literal" not in self.skip and isinstance(value, ast.Dict):
            for t in targets:
                if isinstance(t, ast.Name) and t.id == "ns":
                    for k, v in zip(value.keys, value.values):
                        if isinstance(k, ast.Constant) and isinstance(k.value, str):
                            self.row(st, "namespace-literal", k.value, v, scope)
        for t in targets:
            if isinstance(t, ast.Tuple):
                vals = value.elts if isinstance(value, ast.Tuple) and len(value.elts) == len(t.elts) else [None] * len(t.elts)
                for tt, vv in zip(t.elts, vals):
                    self.target(st, tt, vv, scope, "tuple")
            else:
                self.target(st, t, value, scope, "subscript")

    def target(self, st, t, value, scope, form):
        if isinstance(t, ast.Subscript) and is_ns(t.value):
            name = ns_key(t)
            if name is None:
                if "computed-key" not in self.skip:
                    self.row(st, "computed-key", f"<{ast.unparse(t.slice)}>", value, scope, via=form)
            elif form not in self.skip:
                self.row(st, form, name, value, scope)
        elif isinstance(t, ast.Attribute) and "parameter-attribute" not in self.skip:
            obj = t.value
            if ((isinstance(obj, ast.Name) and scope.is_param_obj(obj.id))
                    or (isinstance(obj, ast.Attribute) and obj.attr == "params")):
                self.row(st, "parameter-attribute", f"{ast.unparse(obj)}.{t.attr}", value, scope)

    # -- a row ------------------------------------------------------------------------------------------------
    def row(self, at, form, name, value, scope, via=None):
        fn = self.resolve(value, scope) if value is not None else None
        r = {"file": self.path.name, "line": at.lineno, "in": scope.qual, "form": form, "name": name}
        if via:
            r["via"] = via
        r["seacast_only"] = self.in_seacast(scope, at.lineno)
        if self.collect is not None:        # the pre-pass: the binding's function (or None, a value), by name
            keys = [name] if form != "computed-key" else self.loop_keys(at, name)
            for k in keys if keys is not None else [None]:      # None: a key the scan cannot name
                self.collect.setdefault(k, []).append(fn)
            self.rows.append(r)
            return
        if fn is None:
            r["value"] = ast.unparse(value)[:80] if value is not None else None
            r["class"] = "value"
            if isinstance(value, ast.Name) and scope.lookup(value.id, "captures"):     # x = ns["y"]; ns["z"] = x
                r["alias_of"] = scope.lookup(value.id, "captures")
        else:
            r["value"] = {"qual": fn.qual, "file": fn.path.name, "line": fn.line, "sha256": fn.sha}
            held = self.held(fn, name)
            if held is None:
                r["class"] = "own"
            else:
                r["holds"] = held
                docs = ("seacast",) if r["seacast_only"] else ("seacast-lite.md", "seacast")     # the documents it runs under
                self.observed = []
                split = self.closure_split(fn, name, held, docs)
                if split is not None:       # its class per branch on a closure value (the node's, read later), each
                                            #   branch's per document where the two differ
                    r["class"], r["closure"] = "closure-dependent", split
                else:
                    by = {d: self.observer_test(fn, name, held, d) for d in docs}
                    if len({w is None for w in by.values()}) == 1:  # one class under each document
                        why = next(iter(by.values()))
                        r["class"] = "observer" if why is None else "layer"
                        if why:
                            r["why"] = why
                            # a swapped draw: a layer that is an observer but for binding a draw's slot (and
                            # naming it) under each document
                            if all(self.observer_test(fn, name, held, d, DRAWS) is None for d in docs):
                                r["swapped_draw"] = True
                    else:                   # an observer under one, not the other
                        r["class"] = "per-document"
                        r["by_document"] = {d: "observer" if w is None else f"layer ({w})" for d, w in by.items()}
                bodies = {}
                for b in self.observed:
                    label, qual, sha = body_of(b)
                    bodies[(label, qual)] = sha
                if set(bodies) - {body_of(fn.node)[:2]}:
                    self.followed.append((r, bodies))
        self.rows.append(r)

    def in_seacast(self, scope, line):
        s = scope
        while s is not None and not isinstance(s.node, ast.ClassDef):
            if isinstance(s.node, ast.FunctionDef) and s.parent is not None and isinstance(s.parent.node, ast.ClassDef):
                if s.node.name in self.seacast_methods:
                    return True
                if s.node.name == "__init__":
                    return any(a <= line <= b for a, b in self.seacast_lines)
            s = s.parent
        return False

    @staticmethod
    def seacast_only(tree):
        """The methods `Node.__init__` calls only under `if self.seacast`, with what they call; and those branches'
        lines."""
        node_cls = next((c for c in tree.body if isinstance(c, ast.ClassDef) and c.name == "Node"), None)
        if node_cls is None:
            return set(), []
        methods = {m.name: m for m in node_cls.body if isinstance(m, ast.FunctionDef)}
        init = methods.get("__init__")
        if init is None:
            return set(), []

        def calls(n):
            return {c.func.attr for c in ast.walk(n) if isinstance(c, ast.Call) and isinstance(c.func, ast.Attribute)
                    and isinstance(c.func.value, ast.Name) and c.func.value.id == "self" and c.func.attr in methods}
        def closure(roots):
            out, todo = set(roots), list(roots)
            while todo:
                for c in calls(methods[todo.pop()]) - out:
                    out.add(c)
                    todo.append(c)
            return out
        v2, lines = set(), []
        for st in ast.walk(init):
            if (isinstance(st, ast.If) and isinstance(st.test, ast.Attribute) and st.test.attr == "seacast"
                    and isinstance(st.test.value, ast.Name) and st.test.value.id == "self"):
                for b in st.body:
                    v2 |= calls(b)
                lines.append((st.body[0].lineno, st.body[-1].end_lineno))
        outside = {c.func.attr for c in ast.walk(init) if isinstance(c, ast.Call) and isinstance(c.func, ast.Attribute)
                   and isinstance(c.func.value, ast.Name) and c.func.value.id == "self" and c.func.attr in methods
                   and not any(a <= c.lineno <= b for a, b in lines)}
        return closure(v2) - closure(outside), lines     # reached outside every v2 branch too: not v2-only

    # -- the observer test ------------------------------------------------------------------------------------
    # the observer test, clause by clause; each clause can be switched off (`self.off`), for the self-test's controls
    CLAUSES = ("question", "traced", "assign", "delete", "mutate", "unfollowed", "local-fn", "node-method", "twice",
               "branch", "arguments", "result", "rebind", "by-name",
               # the follow: a question or traced function the layer calls is followed by the same test
               # (off: refused by name, as before); a draw, a name with a binding the scan does not read, and the
               # layer's own name in what it follows are each refused
               "follow", "draw", "unread", "own-name",
               # followed code, refused where the follow does not read it as one of its kinds, in the forms it reads:
               # a store or mutator on what the followed function did not make ("effect");
               # a call of no kind the follow reads ("call"); a followed call's answer under the test ("answer"); and
               # the kinds it reads: its own new objects ("fresh"), a toy class's constructor ("ctor": its guard,
               # "ctor-guard", and its __init__, "ctor-init"), a listed pure operation ("pure"), its file's own function
               # ("module-fn")
               "effect", "call", "answer", "fresh", "ctor", "ctor-guard", "ctor-init", "pure", "module-fn",
               # and the swapped draw's test: a draw's slot called in the layer's own code, outside its stand-in
               "draw-call")

    def is_held(self, n, held):
        return isinstance(n, ast.Call) and ast.unparse(n.func) == held

    def held(self, fn, name):
        """The earlier binding of `name` the function calls, as its call's text: a closure variable assigned from
        `ns[name]` before it, or a node attribute so assigned (`self._doc_push_rebuilt = ns["push_rebuilt"]`)."""
        for n in ast.walk(fn.node):
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name):
                if fn.scope.lookup(n.func.id, "captures") == name:
                    return n.func.id
            if (isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
                    and n.func.value.id in ("self", "node")
                    and self.attr_captures.get((self.path.name, n.func.attr)) == name):
                return ast.unparse(n.func)
        return None

    def own_scope(self, node, qual, parent, tables=()):
        """A function's own scope for the test: its parameters shadow the enclosing captures, except those named in
        `tables` (a followed callee's parameters given a table); its local aliases of a table are captures too."""
        s = Scope(node, qual, parent)
        pos, kwo, var, kw = params_of(node)         # a lambda's too
        for p in pos + kwo + [x.arg for x in (var, kw) if x is not None]:
            s.captures[p] = "<table>" if p in tables else None
        assigns = sorted((n for n in ast.walk(node) if isinstance(n, ast.Assign)),      # its nested functions' too:
                         key=lambda n: (n.lineno, n.col_offset))                        #   they are read with it
        for n in assigns:                   # in source order: an alias of an alias is one
            for t in n.targets:
                pairs = (list(zip(t.elts, n.value.elts)) if isinstance(t, ast.Tuple) and isinstance(n.value, ast.Tuple)
                         and len(t.elts) == len(n.value.elts) else [(t, n.value)])
                for tt, v in pairs:
                    if not isinstance(tt, ast.Name):
                        continue
                    if isinstance(v, ast.Subscript) and is_ns(v.value) and ns_key(v):
                        s.captures[tt.id] = ns_key(v)
                    elif isinstance(v, ast.Name) and s.lookup(v.id, "captures") is not None:
                        s.captures[tt.id] = s.lookup(v.id, "captures")
                    elif self.ns_rooted(v, s, bare=True):     # a row or a field of a table: an alias into it
                        s.captures[tt.id] = "<table>"
        # for followed code: every name its own scope binds, and those bound only to a new object (each store of the
        # name an assignment of one; a parameter, a loop's or a with's target, a walrus is none). A parameter anywhere
        # in it, a nested function's or lambda's too, is never fresh
        params = {a.arg for a in ast.walk(node) if isinstance(a, ast.arg)}
        stores, new = {}, {}
        for n in own_nodes(node):
            if isinstance(n, ast.Name) and isinstance(n.ctx, (ast.Store, ast.Del)):
                stores[n.id] = stores.get(n.id, 0) + 1
            elif isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                stores[n.name] = stores.get(n.name, 0) + 1
            if isinstance(n, (ast.Assign, ast.AnnAssign)) and n.value is not None:
                for t in (n.targets if isinstance(n, ast.Assign) else [n.target]):
                    if isinstance(t, ast.Name) and self.new_object(n.value):
                        new[t.id] = new.get(t.id, 0) + 1
            if isinstance(n, ast.AugAssign) and isinstance(n.target, ast.Name):
                new[n.target.id] = new.get(n.target.id, 0) + 1     # x += …: the same object
        s.bound = set(stores) | params
        if "fresh" not in self.off:
            s.fresh = {k for k, c in new.items() if c == stores.get(k)} - params
        if self.depth:                      # followed code's own functions and named lambdas, each bound once (3b)
            for n in own_nodes(node):
                if (isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and not n.decorator_list
                        and stores.get(n.name) == 1):
                    s.funcs[n.name] = Func(n, f"{qual}.<locals>.{n.name}", s, self.src, self.path)
                elif (isinstance(n, ast.Assign) and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name)
                      and isinstance(n.value, ast.Lambda) and stores.get(n.targets[0].id) == 1):
                    s.funcs[n.targets[0].id] = Func(n.value, f"{qual}.<locals>.<lambda>", s, self.src, self.path)
        return s

    def new_object(self, v):
        """Whether an expression makes a new object: a display, a comprehension, a constant, a new container from a
        builtin, or a toy class's constructor (which the call itself is checked as, rule 3)."""
        if isinstance(v, (ast.List, ast.Dict, ast.Set, ast.Tuple, ast.ListComp, ast.DictComp, ast.SetComp,
                          ast.GeneratorExp, ast.Constant, ast.JoinedStr)):
            return True
        return (isinstance(v, ast.Call) and isinstance(v.func, ast.Name)
                and (v.func.id in ("list", "dict", "set", "tuple", "frozenset", "sorted", "bytearray")
                     or (self.path.name, v.func.id) in self.classes))

    def own_object(self, e, scope):
        """Whether a store's object is the followed function's own new object: a name bound only to one."""
        return isinstance(e, ast.Name) and e.id in scope.fresh

    def constructor(self, c, name, seen):
        """A toy class's constructor, called in followed code: why it may do more than make a new object, or None.
        Refused: a class with a decorator (a dataclass's default_factory among them), a base, a keyword (a metaclass),
        or any method defined by `def` but its __init__: __new__, __post_init__ and __init_subclass__ among them, and
        every method a store, a mutator or an operator on the new object would run unfollowed (__setattr__,
        __setitem__, append, …). The guard reads the class's `def` statements alone. Else its own __init__, if it has
        one, is followed by the same test, with its receiver taken to be the new object.

        What it can miss: a statement of the class body that is no `def`: an `__init__` bound to a lambda that
        clears `node.pending` passes, and so does an assigned `__setattr__ = hook`. And a receiver that is not the
        new object: `self = shared` in `__init__`, then `self.count = 1`, passes."""
        if "ctor-guard" not in self.off and (
                c.decorator_list or c.bases or c.keywords
                or any(isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef)) and m.name != "__init__"
                       for m in c.body)):
            return f"calls {c.name}, a class whose making the follow does not read"
        init = next((m for m in c.body if isinstance(m, ast.FunctionDef) and m.name == "__init__"), None)
        if init is None or "ctor-init" in self.off:
            return None
        key = ("ctor", id(init))
        if key in seen:
            return None
        seen.add(key)
        inner = self.own_scope(init, f"{c.name}.__init__", Scope(c, c.name, None))
        ps = params_of(init)[0]
        if ps:
            inner.fresh.add(ps[0])      # self: the object being made
        why = self.names_and_writes(init, inner, name, None, seen)
        return f"{why}, in {c.name}.__init__" if why else None

    def in_bound_draw(self, call, layer):
        """Whether a call of a draw's slot is inside a function the layer binds into a draw's slot (a swapped draw's
        stand-in, which hands later draws to the slot's earlier binding), and not in the layer's own code."""
        parents = {id(c): p for p in ast.walk(layer) for c in ast.iter_child_nodes(p)}
        p, fn = parents.get(id(call)), None
        while p is not None and p is not layer:
            if isinstance(p, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
                fn = p
                break
            p = parents.get(id(p))
        if fn is None:
            return False
        for a in ast.walk(layer):
            if isinstance(a, ast.Assign) and any(isinstance(t, ast.Subscript) and is_ns(t.value) and ns_key(t) in DRAWS
                                                 for t in a.targets):
                if a.value is fn or (isinstance(a.value, ast.Name) and getattr(fn, "name", None) == a.value.id):
                    return True
        return False

    def read_methods_anywhere(self):
        """READONLY_METHODS less a name some toy class defines (decorated or not) with a body that does more than
        read, and toy_reads: the read methods followed code may call on any object."""
        defs = {}
        for c in self.all_classes:
            for m in c.body:
                if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    defs.setdefault(m.name, []).append(m)
        return {m for m in READONLY_METHODS if all(self.only_reads(d) for d in defs.get(m, ()))} | self.toy_reads()

    def observer_test(self, fn, name, held, doc, exempt=()):
        """None for an observer, or why it is not one, under one document's namespace ("seacast-lite.md" or "seacast": its
        questions, its traced names, and whether its function of that name returns a value). The slots of `exempt`
        may be named and bound (the swapped draw's test: DRAWS)."""
        self.exempt = exempt
        if name in BY_NAME and "by-name" not in self.off:
            return None
        self.doc, self.depth = doc, 0
        self.questions = QUESTIONS_Seacast if doc == "seacast" else QUESTIONS_DOC
        self.traced = TRACED_Seacast if doc == "seacast" else TRACED
        if doc == "seacast":                     # SEACAST's namespace: its own function of the name, else seacast-lite.md's
            self.returns = RETURNS_Seacast if name in DEFS_Seacast else RETURNS_DOC
        else:
            self.returns = RETURNS_DOC if name in DEFS_DOC else RETURNS_Seacast
        own = self.own_scope(fn.node, fn.qual, fn.scope)
        self.walked_now = []
        try:
            why = self.names_and_writes(fn.node, own, name, held, set()) or self.paths(fn.node, own, name, held)
        finally:
            walked, self.walked_now = self.walked_now, None
        if why is None and not exempt:      # an observer verdict: the bodies it rests on (the followed code's listing)
            self.observed += walked
        return why

    def table_arg(self, call, scope):
        return next((a for a in list(call.args) + [k.value for k in call.keywords]
                     if self.ns_rooted(a, scope, bare=True)), None)

    def names_and_writes(self, node, scope, name, held, seen):
        """Why the code names a question or a traced function, or writes, deletes or mutates a table, following the
        local functions and node methods it calls (with the tables it hands them); or None. The functions and lambdas
        defined inside it are read as its own code, whether or not they run: a closure needs no argument to reach a
        table. A question or a traced function the code calls directly is not refused by its name but followed
        (`follow`), by this same test; named in any other way, it is refused as before. In what is followed
        (`self.depth` > 0), a document function it calls is followed too, and a `global` or `nonlocal`, and the
        layer's own name, are refused."""
        if self.walked_now is not None:
            self.walked_now.append(node)
        calls = {id(c.func) for c in ast.walk(node) if isinstance(c, ast.Call)}    # the functions called directly
        for n in ast.walk(node):
            k = None
            if isinstance(n, ast.Subscript) and is_ns(n.value):
                k = ns_key(n)
            elif isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load) and n.id != held:
                k = scope.lookup(n.id, "captures")
            if k is not None and self.depth and k == name and "own-name" not in self.off:
                return f"names {k}, the layer's own name"
            if k is not None and k != name and (k not in self.exempt or self.depth):
                q = k in self.questions and "question" not in self.off
                t = k in self.traced and "traced" not in self.off
                if (q or t) and ("follow" in self.off or id(n) not in calls):   # a direct call: followed at the call
                    return f"names the question {k}" if q else f"names the traced function {k}"
            if isinstance(n, (ast.Global, ast.Nonlocal)) and self.depth and "assign" not in self.off:
                return f"declares {type(n).__name__.lower()} {', '.join(n.names)}"
            targets = []
            if isinstance(n, (ast.Assign, ast.Delete)):
                targets = n.targets
            elif isinstance(n, (ast.AugAssign, ast.AnnAssign)):
                targets = [n.target]
            for t in targets:
                for tt in (t.elts if isinstance(t, ast.Tuple) else [t]):
                    clause = "delete" if isinstance(n, ast.Delete) else "assign"
                    if (isinstance(tt, ast.Subscript) and is_ns(tt.value) and ns_key(tt) in self.exempt
                            and clause == "assign" and not self.depth):
                        continue        # an exempt slot bound (a swapped draw's), in the layer's own code alone
                    if clause not in self.off and self.ns_rooted(tt, scope):
                        return f"{'deletes' if clause == 'delete' else 'writes'} {ast.unparse(tt)[:60]}"
            if (self.depth and "effect" not in self.off and isinstance(n, (ast.Attribute, ast.Subscript))
                    and isinstance(n.ctx, (ast.Store, ast.Del)) and not self.own_object(n.value, scope)):
                # followed code: an attribute or a subscript stored or deleted, in any statement (an assignment, an
                # augmented one, a del, a for's or a with's target, a nested or starred target), only on its own new
                # object, the store's immediate object a name bound only to one
                return (f"{'deletes' if isinstance(n.ctx, ast.Del) else 'writes'} {ast.unparse(n)[:60]}, which the "
                        f"follow cannot establish as its own new object")
            if not isinstance(n, ast.Call):
                continue
            k = self.called_name(n.func, scope, held)
            if (k in DRAWS and k in self.exempt and not self.depth and "draw-call" not in self.off
                    and not self.in_bound_draw(n, node)):
                return f"calls the draw {k}"    # the swapped draw's test: a slot bound, and called only by its stand-in
            if k is not None and k != name and (k not in self.exempt or self.depth) and "follow" not in self.off:
                q = k in self.questions and "question" not in self.off
                t = k in self.traced and "traced" not in self.off
                if q or t or (self.depth and k in CALLABLES):
                    why = self.follow(k, n, scope, name, held, seen)
                    if why:
                        return why
                    continue
            if isinstance(n.func, ast.Attribute) and n.func.attr in MUTATORS and "mutate" not in self.off:
                if self.ns_rooted(n.func.value, scope, bare=True):
                    return f"mutates {ast.unparse(n.func.value)[:60]} by {n.func.attr}"
            if (isinstance(n.func, ast.Attribute) and n.func.attr not in MUTATORS | self.reads
                    and "mutate" not in self.off and self.ns_rooted(n.func.value, scope, bare=True)):
                return (f"calls {n.func.attr} on {ast.unparse(n.func.value)[:60]}, which the test does not establish "
                        f"as a read")
            if self.depth and isinstance(n.func, ast.Attribute) and n.func.attr in MUTATORS:
                if "effect" not in self.off and not (isinstance(n.func.value, ast.Name)
                                                     and n.func.value.id in scope.fresh):
                    return (f"mutates {ast.unparse(n.func.value)[:60]} by {n.func.attr}, which the follow cannot "
                            f"establish as its own new object")
                continue                # its own new object's (or the clause off)
            if self.is_held(n, held):
                continue
            callee, clause = None, None
            if isinstance(n.func, ast.Name):
                f = scope.lookup(n.func.id, "funcs")
                if f is not None:       # a local function or lambda, followed
                    callee, clause = (f.node, f.scope, f.qual), "local-fn"
                elif f is None and scope.lookup(n.func.id, "captures") is not None:
                    if self.depth and "call" not in self.off:
                        return f"calls {n.func.id}, a namespace name the follow does not read"
                    continue            # a namespace function (named, and so checked, above)
                elif f is None and n.func.id in READONLY_BUILTINS:
                    continue            # a builtin taken as a read (any other is unfollowed, below)
                elif self.depth and n.func.id not in scope.bound and not scope.shadowed(n.func.id):
                    g = self.globals.get((self.path.name, n.func.id))
                    if g is not None and "." not in g.qual and "module-fn" not in self.off:
                        callee, clause = (g.node, g.scope, g.qual), "local-fn"     # its file's own function
                    elif (self.path.name, n.func.id) in self.classes and "ctor" not in self.off:
                        why = self.constructor(self.classes[(self.path.name, n.func.id)], name, seen)
                        if why:
                            return why
                        continue        # a new object of a toy class
            elif (isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
                  and n.func.value.id in ("self", "node")):
                m = self.methods.get((self.path.name, "Node", n.func.attr))
                if m is not None:
                    callee, clause = (m, None, f"Node.{n.func.attr}"), "node-method"
            elif isinstance(n.func, ast.Attribute) and self.ns_rooted(n.func.value, scope, bare=True):
                continue                # a table's own method (a mutating one handled above)
            if callee is not None:      # (any other object's method, or a module's function: unfollowed, below)
                if clause in self.off:
                    continue
                params = params_of(callee[0])[0][1 if clause == "node-method" else 0:]     # after the receiver
                tables = {p for p, a in zip(params, n.args) if self.ns_rooted(a, scope, bare=True)}
                tables |= {kw.arg for kw in n.keywords if kw.arg and self.ns_rooted(kw.value, scope, bare=True)}
                key = (id(callee[0]), frozenset(tables), self.depth > 0)   # walked again where followed
                if key in seen:
                    continue
                seen.add(key)
                inner = self.own_scope(callee[0], callee[2], callee[1], tables)
                why = self.names_and_writes(callee[0], inner, name, held, seen)
                if why:
                    return f"{why}, in {getattr(callee[0], 'name', '?')}"
            elif "unfollowed" not in self.off and self.table_arg(n, scope) is not None:
                a = self.table_arg(n, scope)
                return f"hands {ast.unparse(a)[:40]} to {ast.unparse(n.func)[:40]}, which the test does not follow"
            elif self.depth and "call" not in self.off:     # followed code: a call of no kind the follow reads
                f = n.func
                if k is not None and k == name:
                    continue            # the layer's own name: refused by name (own-name)
                if isinstance(f, ast.Attribute) and f.attr in self.reads_anywhere:
                    continue            # a read method, which no toy class defines as more than a read
                if (isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name)
                        and (f.value.id, f.attr) in PURE_CALLS and "pure" not in self.off):
                    continue            # a listed pure operation
                return f"calls {ast.unparse(f)[:60]}, which the follow cannot establish as a read"
        return None

    def loop_keys(self, at, name):
        """The names a computed key `<k>` binds, when `k` is the variable of a `for` around the binding that runs
        over a literal tuple or list of strings (or of tuples, `k` in the same place of each); else None."""
        k = name[1:-1]
        if not k.isidentifier():
            return None
        p = self.parents.get(id(at))
        while p is not None:
            if isinstance(p, ast.For) and isinstance(p.iter, (ast.Tuple, ast.List)):
                t = p.target
                at_ = [None] if isinstance(t, ast.Name) and t.id == k else \
                    [j for j, e in enumerate(t.elts) if isinstance(e, ast.Name) and e.id == k] \
                    if isinstance(t, (ast.Tuple, ast.List)) else []
                if at_ and "loop-rebind" not in self.skip and any(
                        isinstance(x, ast.Name) and x.id == k and isinstance(x.ctx, ast.Store)
                        for b in p.body for x in ast.walk(b)):
                    return None             # the body binds the variable again: the key at the binding is unknown
                if at_:
                    j = at_[0]
                    out = []
                    for e in p.iter.elts:
                        if j is not None:
                            e = e.elts[j] if isinstance(e, (ast.Tuple, ast.List)) and j < len(e.elts) else None
                        if not (isinstance(e, ast.Constant) and isinstance(e.value, str)):
                            return None
                        out.append(e.value)
                    return out
            if isinstance(p, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)) or \
                    (isinstance(p, (ast.For, ast.comprehension)) and k in
                     {n.id for n in ast.walk(p.target) if isinstance(n, ast.Name)}):
                return None                 # bound by a loop the scan does not read, or outside the function
            p = self.parents.get(id(p))
        return None

    def called_name(self, f, scope, held):
        """The namespace name a call's function is (`ns["x"](...)`, or a local `x` captured from `ns["x"]`, or in a
        document's code a global `x`), or None: a local function, the held binding, anything else."""
        if isinstance(f, ast.Subscript) and is_ns(f.value):
            k = ns_key(f)
        elif isinstance(f, ast.Name) and f.id != held and scope.lookup(f.id, "funcs") is None:
            k = scope.lookup(f.id, "captures")
        else:
            return None
        return k if isinstance(k, str) and not k.startswith("<") else None

    def follow(self, k, call, scope, name, held, seen):
        """Why the question, traced function or (in what is followed) document function `k`, which the code calls
        directly, is not one that only reads by this same test; or None. It is read through the documents' function
        of that name (seacast.md's under seacast.md, else seacast-lite.md's), and through every binding of the name
        in the toy's files (the pre-pass, `self.bound_by`), each with the tables the call hands it, transitively;
        each once per name and tables handed. Refused: a draw (DRAWS); a name the toy binds to a value the scan does
        not read as a function, or that has neither a binding nor a definition; any name at all where the toy binds
        a computed key the scan cannot name (it may bind this one); and a table handed through * or **, where the
        parameter it reaches is not known."""
        if k in DRAWS and "draw" not in self.off:
            return f"names the draw {k}"
        if self.bound_by.get(None) and "unread" not in self.off:
            return f"names {k}, and the toy binds a computed key the scan cannot name"
        if ((any(isinstance(a, ast.Starred) for a in call.args) or any(kw.arg is None for kw in call.keywords))
                and self.table_arg(call, scope) is not None and "unfollowed" not in self.off):
            return f"hands a table to {k} through * or **"
        pos = frozenset(i for i, a in enumerate(call.args) if self.ns_rooted(a, scope, bare=True))
        kws = frozenset(kw.arg for kw in call.keywords if kw.arg and self.ns_rooted(kw.value, scope, bare=True))
        key = ("follow", k, pos, kws)
        if key in seen:
            return None
        seen.add(key)
        targets = []
        d = (FNS_Seacast.get(k) or FNS_DOC.get(k)) if self.doc == "seacast" else FNS_DOC.get(k)
        if d is not None:
            targets.append((d, self.doc_scope(d), None, d.name))
        for f in self.bound_by.get(k, ()):
            if f is None:
                if "unread" not in self.off:
                    return f"names {k}, which the toy binds to a value the scan does not read as a function"
                continue
            targets.append((f.node, f.scope, f, f.qual))
        if not targets:
            return None if "unread" in self.off else f"names {k}, which has no binding or definition the scan reads"
        for body, parent, f, qual in targets:
            ps, kwo, _, _ = params_of(body)
            if f is not None and isinstance(f.scope.node, ast.ClassDef) and not f.static:
                ps = ps[1:]                 # a method bound by `self.m`: its parameters after the receiver
            tables = {ps[i] for i in pos if i < len(ps)} | (set(kws) & set(ps + kwo))
            saved, saved_ns = self.path, NS_FILE[0]
            if f is not None:
                self.path = f.path          # its file's methods, node attributes and aliases of the namespace
                NS_FILE[0] = f.path.name
            self.depth += 1
            try:
                inner = self.own_scope(body, qual, parent, tables)
                why = self.names_and_writes(body, inner, name, None, seen)   # the held binding is the layer's alone
            finally:
                self.depth -= 1
                self.path, NS_FILE[0] = saved, saved_ns
            if why:
                return f"{why}, in {k}"
        return None

    @staticmethod
    def doc_scope(d):
        """The scope a document's function is read in: each global it loads (not its own parameter or local, not a
        builtin) is a namespace name, as `ns[...]` is in the toy's code, so its tables are tables and its questions,
        traced and document functions are named."""
        local = {a.arg for a in ast.walk(d) if isinstance(a, ast.arg)}
        local |= {n.id for n in ast.walk(d) if isinstance(n, ast.Name) and isinstance(n.ctx, (ast.Store, ast.Del))}
        s = Scope(d, "", None)
        s.captures = {n.id: n.id for n in ast.walk(d) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)
                      and n.id not in local and n.id not in BUILTIN_NAMES}
        return s

    def ns_rooted(self, e, scope, bare=False):
        """Whether an expression reaches into a namespace name: `ns[...]` itself or anything under it, or anything
        under a variable that holds a table (captured from `ns[...]`, aliased, or a followed callee's parameter given
        one). With `bare`, the variable itself counts too (a method's receiver, a call's argument). What a method of
        a table returns is under the table (`ns["t"].get(k)`: a row, which can be changed in place)."""
        top = e
        while isinstance(e, (ast.Subscript, ast.Attribute, ast.Call)):
            if isinstance(e, ast.Subscript) and is_ns(e.value):
                return True
            if isinstance(e, ast.Call):
                if not isinstance(e.func, ast.Attribute):
                    if self.answer_of_followed(e, scope):
                        return True     # a followed call's answer: under the test as a table is
                    break               # any other function's result: not a table's
                e = e.func.value
            else:
                e = e.value
        if isinstance(e, ast.Name) and (bare or e is not top):
            k = scope.lookup(e.id, "captures")
            return k is not None and k not in self.questions | self.traced | CALLABLES
        return bare and isinstance(top, ast.Subscript) and is_ns(top.value)

    def answer_of_followed(self, call, scope):
        """Whether a call is one the follow reads (a question's, a traced function's, or in followed code a document
        function's), so that its answer is under the test as a table is."""
        if "answer" in self.off or "follow" in self.off:
            return False
        k = self.called_name(call.func, scope, None)
        return k is not None and (k in self.questions or k in self.traced or (self.depth and k in CALLABLES))

    def toy_reads(self):
        """The names of TOY_READS that the toy's classes define, each definition only reading."""
        out = set()
        for name in TOY_READS:
            defs = [f.node for (_, q), f in self.globals.items() if "." in q and q.rsplit(".", 1)[1] == name]
            if defs and all(self.only_reads(d) for d in defs):
                out.add(name)
        return out

    @staticmethod
    def only_reads(d):
        for n in ast.walk(d):
            if isinstance(n, (ast.Attribute, ast.Subscript)) and isinstance(n.ctx, (ast.Store, ast.Del)):
                return False
            if isinstance(n, (ast.Global, ast.Nonlocal)):
                return False
            if isinstance(n, ast.Call) and not (
                    (isinstance(n.func, ast.Attribute) and n.func.attr in READONLY_METHODS | TOY_READS)
                    or (isinstance(n.func, ast.Name) and n.func.id in READONLY_BUILTINS)):
                return False
        return True

    def binds(self, node, held):
        """Whether the function binds the earlier binding's name in its own body (an assignment, a parameter, a
        handler's or a pattern's name, an import, a definition, a `global` or `nonlocal`), or for a node attribute
        (`self._doc_x`) assigns or deletes it anywhere in it: its call is then not the earlier binding's."""
        if "." in held:
            return any(isinstance(n, ast.Attribute) and isinstance(n.ctx, (ast.Store, ast.Del))
                       and ast.unparse(n) == held for n in ast.walk(node))
        return bool(self.bindings(node, held)) or any(isinstance(n, (ast.Global, ast.Nonlocal)) and held in n.names
                                                    for n in self.walk_no_nested(node))

    def args_ok(self, call, node, params):
        """Why the earlier binding's call does not pass the function's own parameters exactly, or None."""
        pos, kwo, var, kw = params_of(node)
        given = [a.id if isinstance(a, ast.Name) else None for a in call.args if not isinstance(a, ast.Starred)]
        stars = [a for a in call.args if isinstance(a, ast.Starred)]
        named = [k for k in call.keywords if k.arg is not None]
        dstar = [k for k in call.keywords if k.arg is None]
        ok = (given == pos[:len(given)]
              and all(isinstance(k.value, ast.Name) and k.value.id == k.arg for k in named)
              and sorted(given + [k.arg for k in named]) == sorted(pos + kwo)
              and len(stars) == (var is not None) and all(isinstance(s.value, ast.Name) and s.value.id == var.arg
                                                          for s in stars)
              and len(dstar) == (kw is not None) and all(isinstance(d.value, ast.Name) and d.value.id == kw.arg
                                                         for d in dstar))
        return None if ok else f"calls it with other arguments than its own: {ast.unparse(call)[:60]}"

    def paths(self, node, scope, name, held):
        """Why the earlier binding is not called once on every path with the function's own parameters, its result
        returned (or nothing returned where the document's function returns nothing), or None."""
        body = [ast.Return(value=node.body)] if isinstance(node, ast.Lambda) else node.body
        pos, kwo, var, kw = params_of(node)
        params = set(pos + kwo + [x.arg for x in (var, kw) if x is not None])
        if "arguments" not in self.off:
            for c in [n for n in ast.walk(node) if self.is_held(n, held)]:
                why = self.args_ok(c, node, params)
                if why:
                    return why
        if "rebind" not in self.off and self.binds(node, held):     # then its call is not the earlier binding's
            return f"binds {held} again in its own body"
        if "twice" not in self.off and any(self.is_held(n, held) for d in ast.walk(node)
                                           if d is not node and isinstance(d, (ast.FunctionDef, ast.AsyncFunctionDef,
                                                                                ast.Lambda))
                                           for n in ast.walk(d)):
            return f"calls {held} in a function defined in it"     # a call the walk below cannot count
        st = {"count": 0, "res": None, "assigned": set()}
        why, ended = self.walk(body, st, held, params, name in self.returns)
        if why:
            return why
        if not ended:
            if st["count"] == 0 and "branch" not in self.off:
                return f"calls {held} on some paths only"
            if st["count"] > 1 and "twice" not in self.off:
                return f"calls {held} {st['count']} times on a path"
            if name in self.returns and "result" not in self.off and st["count"]:    # a path with no call has no
                                                                                    #   result to drop (the branch's)
                return f"drops {held}'s result"
        return None

    def calls_in(self, node, st, held, params):
        """Count the earlier binding's calls a statement or expression makes on every path through it; why, if one is
        made on some paths only, a second time, or after a parameter is rebound."""
        always = set(id(n) for n in self.own_exprs(node)) if isinstance(node, ast.stmt) else set(
            id(n) for n in self.every_path(node))
        walrus = {w.target.id for w in ast.walk(node) if isinstance(w, ast.NamedExpr)}     # beside the call: its order
        for n in ast.walk(node):                                                            #   in the line not read
            if not self.is_held(n, held):
                continue
            if id(n) not in always and "branch" not in self.off:
                return f"calls {held} on some paths only"
            if st["count"] and "twice" not in self.off:
                return f"calls {held} twice"
            if (st["assigned"] | walrus) & params and "arguments" not in self.off:
                return f"rebinds its parameter {sorted((st['assigned'] | walrus) & params)[0]} before it calls {held}"
            st["count"] += 1
        return None

    def note_assigns(self, s, st):
        """The names a statement may assign: each counts as rebound, and the result variable is no longer the
        earlier binding's result: a name assigned (a walrus's too), a handler's or a pattern's name, an import."""
        for n in self.walk_no_nested(s):
            names = []
            if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Store):
                names = [n.id]
            elif isinstance(n, (ast.ExceptHandler, ast.MatchAs, ast.MatchStar)) and n.name:
                names = [n.name]
            elif isinstance(n, ast.MatchMapping) and n.rest:
                names = [n.rest]
            elif isinstance(n, ast.alias):
                names = [n.asname or n.name.split(".")[0]]
            for x in names:
                st["assigned"].add(x)
                if x == st["res"]:
                    st["res"] = None

    def walk(self, stmts, st, held, params, rv):
        """Walk a statement list on every path; (why, whether every path through it has returned)."""
        for s in stmts:
            if isinstance(s, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                continue
            if isinstance(s, ast.If):
                why = self.calls_in(s.test, st, held, params)
                if why:
                    return why, False
                self.note_assigns(ast.Expr(value=s.test), st)     # a walrus in the test assigns
                a = {"count": st["count"], "res": st["res"], "assigned": set(st["assigned"])}
                b = {"count": st["count"], "res": st["res"], "assigned": set(st["assigned"])}
                wa, ea = self.walk(s.body, a, held, params, rv)
                if wa:
                    return wa, False
                wb, eb = self.walk(s.orelse, b, held, params, rv)
                if wb:
                    return wb, False
                if ea and eb:
                    return None, True
                live = [x for x, e in ((a, ea), (b, eb)) if not e]
                if len({x["count"] for x in live}) > 1 and "branch" not in self.off:
                    return f"calls {held} on some paths only", False
                st.update(count=live[0]["count"],       # only what every live path shares: a result variable
                          res=live[0]["res"] if len({x["res"] for x in live}) == 1 else None,     # held on all
                          assigned=set().union(*(x["assigned"] for x in live)))
                continue
            if isinstance(s, (ast.For, ast.AsyncFor, ast.While)):
                if any(self.is_held(n, held) for n in ast.walk(s)) and "branch" not in self.off:
                    return f"calls {held} in a loop", False
                if any(isinstance(n, (ast.Return, ast.Raise)) for n in self.walk_no_nested(s)):
                    return "returns or raises inside a loop", False
                self.note_assigns(s, st)
                continue
            if isinstance(s, ast.Try):
                if s.handlers and any(self.is_held(n, held) for b in s.body for n in ast.walk(b)):
                    return f"calls {held} inside a try with handlers", False
                if any(self.is_held(n, held) or isinstance(n, (ast.Return, ast.Raise))
                       for b in s.finalbody for n in self.walk_no_nested(b)):
                    return "calls, returns or raises in a finally", False
                if any(isinstance(n, (ast.Return, ast.Raise)) for h in s.handlers for b in h.body
                       for n in self.walk_no_nested(b)):
                    return "returns or raises in a handler", False
                if any(self.is_held(n, held) for h in s.handlers for b in h.body for n in ast.walk(b)):
                    return f"calls {held} in a handler", False
                if (s.handlers and "branch" not in self.off      # a handler's path does not run the else
                        and any(self.is_held(n, held) or isinstance(n, (ast.Return, ast.Raise))
                                for b in s.orelse for n in self.walk_no_nested(b))):
                    return "calls, returns or raises in a try's else, which a handler's path skips", False
                for h in s.handlers:            # a handler may run: what it assigns is assigned, its name too
                    self.note_assigns(h, st)
                for part in (s.body, s.orelse):
                    why, ended = self.walk(part, st, held, params, rv)
                    if why or ended:
                        return why, ended
                self.note_assigns(ast.Module(body=s.finalbody, type_ignores=[]), st)
                continue
            if isinstance(s, (ast.With, ast.AsyncWith)):
                for it in s.items:
                    why = self.calls_in(it.context_expr, st, held, params)
                    if why:
                        return why, False
                    self.note_assigns(ast.Expr(value=it.context_expr), st)
                    if it.optional_vars is not None:    # `with … as x` assigns x
                        self.note_assigns(ast.Expr(value=it.optional_vars), st)
                why, ended = self.walk(s.body, st, held, params, rv)
                if why or ended:
                    return why, ended
                continue
            if isinstance(s, ast.Raise):
                return "raises", False
            if isinstance(s, ast.Return):
                v = s.value
                why = self.calls_in(v, st, held, params) if v is not None else None
                if why:
                    return why, False
                if st["count"] == 0 and "branch" not in self.off:
                    return f"returns before it calls {held}", False
                if "result" in self.off:
                    return None, True
                if self.is_held(v, held) or (isinstance(v, ast.Name) and v.id == st["res"]):
                    return None, True
                if not rv and (v is None or (isinstance(v, ast.Constant) and v.value is None)):
                    return None, True
                return f"does not return {held}'s result", True
            if any(isinstance(c, ast.stmt) for c in self.walk_no_nested(s) if c is not s):  # a compound statement
                if "branch" not in self.off and any(                                        #   the walk does not
                        self.is_held(n, held) or isinstance(n, (ast.Return, ast.Raise))    #   follow (match: its
                        for n in self.walk_no_nested(s)):                                   #   arms are statements
                    return f"a {type(s).__name__} statement the test cannot follow holds the call or a return", False
                self.note_assigns(s, st)
                continue
            why = self.calls_in(s, st, held, params)
            if why:
                return why, False
            defines = (isinstance(s, ast.Assign) and self.is_held(s.value, held) and len(s.targets) == 1
                       and isinstance(s.targets[0], ast.Name))
            if (not defines and st["res"] is not None and "result" not in self.off
                    and any(isinstance(n, ast.Name) and n.id == st["res"] and isinstance(n.ctx, ast.Store)
                            for n in ast.walk(s))):
                return f"changes {held}'s result before it returns it", False
            self.note_assigns(s, st)
            if defines:
                st["res"] = s.targets[0].id
        return None, False

    @staticmethod
    def walk_no_nested(st):
        todo = [st]
        while todo:
            n = todo.pop()
            yield n
            for c in ast.iter_child_nodes(n):
                if not isinstance(c, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef)):
                    todo.append(c)

    @staticmethod
    def every_path(e):
        """The sub-expressions an expression evaluates on every path: not a branch of a conditional expression, a
        short-circuit operand after the first, a comprehension or a lambda."""
        todo = [e]
        while todo:
            n = todo.pop()
            yield n
            if isinstance(n, ast.IfExp):
                todo.append(n.test)
            elif isinstance(n, ast.BoolOp):
                todo.append(n.values[0])
            elif not isinstance(n, (ast.Lambda, ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
                todo += list(ast.iter_child_nodes(n))

    @staticmethod
    def own_exprs(st):
        """The expressions a statement evaluates on every path through it (not its nested statements)."""
        for field, val in ast.iter_fields(st):
            if field in ("body", "orelse", "finalbody", "handlers"):
                continue
            for v in (val if isinstance(val, list) else [val]):
                if isinstance(v, ast.AST):
                    yield from Scanner.every_path(v)

    def closure_split(self, fn, name, held, docs):
        """A layer whose first statement branches on a closure value alone (no parameter of its own): its class per
        branch, as {"on": the test's text, "true": class, "false": class}, or None. Such a layer is
        classified per node by that value; the scan gives both, and the node's own value is read where classes are.
        A branch's class is given under each document the row runs under, as {document: class} where they differ.
        A value the node is made with: each name of the test bound exactly once (a parameter, or one assignment) in
        the nearest enclosing function that binds it, declared `nonlocal` or `global` in no function made in that
        one, bound to no container and mutated by no method there; a module's global, or a name bound twice, is
        state, and splits nothing."""
        node = fn.node
        if isinstance(node, ast.Lambda) or not node.body or not isinstance(node.body[0], ast.If):
            return None
        test = node.body[0].test
        own = set(params_of(node)[0] + params_of(node)[1])
        if any(isinstance(n, (ast.Attribute, ast.Call, ast.Subscript, ast.NamedExpr, ast.Await)) for n in ast.walk(test)):
            return None                 # a field, a call or an element: state or an effect, no construction value
        names = {n.id for n in ast.walk(test) if isinstance(n, ast.Name)}
        if not names or names & own or any(fn.scope.lookup(x, "captures") for x in names):
            return None
        for x in names:                 # each bound once, in the nearest enclosing function that binds it
            s = fn.scope
            while s is not None and not (isinstance(s.node, (ast.FunctionDef, ast.AsyncFunctionDef))
                                         and self.bindings(s.node, x)):
                s = s.parent
            if s is None or self.bindings(s.node, x) != 1:
                return None             # a module's global, or a name bound more than once
            if any(isinstance(n, (ast.Global, ast.Nonlocal)) and x in n.names for n in ast.walk(s.node)):
                return None             # a function made there rebinds it
        s = fn.scope                    # a value the node is made with, not state: no name of the test bound to a
        while s is not None:            #   container or mutated by a method in an enclosing function
            if isinstance(s.node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                for n in self.walk_no_nested(s.node):
                    if isinstance(n, ast.Assign):
                        for t in n.targets:
                            pairs = (list(zip(t.elts, n.value.elts)) if isinstance(t, ast.Tuple)
                                     and isinstance(n.value, ast.Tuple) and len(t.elts) == len(n.value.elts)
                                     else [(t, n.value)])
                            for tt, vv in pairs:
                                if isinstance(tt, ast.Name) and tt.id in names and (
                                        isinstance(vv, (ast.List, ast.Dict, ast.Set, ast.ListComp, ast.DictComp,
                                                        ast.SetComp))
                                        or (isinstance(vv, ast.Call) and isinstance(vv.func, ast.Name) and vv.func.id
                                            in ("list", "dict", "set", "deque", "Counter", "defaultdict"))):
                                    return None
                    if (isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr in MUTATORS
                            and isinstance(n.func.value, ast.Name) and n.func.value.id in names):
                        return None
            s = s.parent
        out = {"on": ast.unparse(test)}
        for truth in (True, False):
            branch = node.body[0].body if truth else node.body[0].orelse
            ends = bool(branch) and isinstance(branch[-1], (ast.Return, ast.Raise))   # the rest is not reached
            alt = ast.FunctionDef(name=node.name, args=node.args,
                                  body=(list(branch) if ends else list(branch) + node.body[1:]) or [ast.Pass()],
                                  decorator_list=[], returns=None, type_comment=None, type_params=[])
            ast.copy_location(alt, node)
            ast.fix_missing_locations(alt)
            KEPT.append(alt)                # the branch is the function's own body, by its name and source
            SOURCES[id(alt)] = SOURCES.get(id(node), ("?", f"{node.name}@{node.lineno}", None))
            f2 = Func(alt, fn.qual, fn.scope, self.src, self.path)
            h = self.held(f2, name)
            by = {d: "own" if h is None else ("observer" if self.observer_test(f2, name, h, d) is None else "layer")
                  for d in docs}
            out[str(truth).lower()] = by[docs[0]] if len(set(by.values())) == 1 else by
        return out if out["true"] != out["false"] else None

    def bindings(self, fn_node, x):
        """How many times a function binds the name in its own body: its parameters, each assignment (an augmented
        one, a loop's or a `with`'s target, a walrus), each handler's or pattern's name, import and definition."""
        pos, kwo, var, kw = params_of(fn_node)
        k = (pos + kwo + [a.arg for a in (var, kw) if a is not None]).count(x)
        for n in self.walk_no_nested(fn_node):
            if isinstance(n, ast.Name) and isinstance(n.ctx, (ast.Store, ast.Del)) and n.id == x:
                k += 1
            elif isinstance(n, (ast.ExceptHandler, ast.MatchAs, ast.MatchStar)) and n.name == x:
                k += 1
            elif isinstance(n, ast.MatchMapping) and n.rest == x:
                k += 1
            elif isinstance(n, ast.alias) and (n.asname or n.name.split(".")[0]) == x:
                k += 1
            for c in ast.iter_child_nodes(n):
                if isinstance(c, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and c.name == x:
                    k += 1
        return k


QUESTIONS_DOC, QUESTIONS_Seacast, TRACED, TRACED_Seacast, CALLABLES = set(), set(), set(), set(), set()
TRACED_V2_KEPT = set()      # TRACED_Seacast's kept names alone: seacast-lite.md's lists (WRAPPERS, REPLACEABLE) are of these
DEFS_DOC, DEFS_Seacast, RETURNS_DOC, RETURNS_Seacast = set(), set(), set(), set()
FNS_DOC, FNS_Seacast = {}, {}   # each document's top-level functions, name -> its def: what the observer test follows
#                                 when a layer calls a traced function (Scanner.follow)
BUILTIN_NAMES = set(dir(__import__("builtins")))


def returning(defs):
    """The functions of `defs` (name -> FunctionDef, in one namespace) that return a value: a least fixpoint, where
    `return f(...)` of a function of `defs` returns a value only if `f` does, and `return` or `return None` none."""
    rv, changed = set(), True
    while changed:
        changed = False
        for name, d in defs.items():
            if name in rv:
                continue
            for n in Scanner.walk_no_nested(d):
                if not isinstance(n, ast.Return) or n.value is None:
                    continue
                v = n.value
                if isinstance(v, ast.Constant) and v.value is None:
                    continue
                if isinstance(v, ast.Call) and isinstance(v.func, ast.Name) and v.func.id in defs and v.func.id not in rv:
                    continue
                rv.add(name)
                changed = True
                break
    return rv


def questions_of(defs, defined):
    """The names a document's functions call that no document defines, no builtin is, and no function binds locally:
    the questions the environment answers (seacast.md's `type_of_group`, `send`, `choice`, ...)."""
    out = set()
    for d in defs.values():
        local = {a.arg for a in d.args.args + d.args.kwonlyargs + [x for x in (d.args.vararg, d.args.kwarg) if x]}
        local |= {n.id for n in ast.walk(d) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Store)}
        for n in ast.walk(d):
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name):
                x = n.func.id
                if x not in defined and x not in BUILTIN_NAMES and x not in local:
                    out.add(x)
    return out


def load_names(toy):
    """The questions (trace3.py's TAPE, and seacast.md's calls of names no document defines), the traced names
    (BLOCK; under v2 its kept ones, as trace3.py's), the documents' functions, and which of them return a value."""
    sys.path.insert(0, str(HERE))
    import trace3 as T                  # noqa: E402
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    doc_src, v2_src = N.SPEC_SRC, N.generate(N.DOC2)
    doc_tree, v2_tree = ast.parse(doc_src), ast.parse(v2_src)
    name_bodies(doc_tree, "seacast-lite.md", doc_src)
    name_bodies(v2_tree, "seacast.md", v2_src)
    doc = {d.name: d for d in doc_tree.body if isinstance(d, ast.FunctionDef)}
    v2 = {d.name: d for d in v2_tree.body if isinstance(d, ast.FunctionDef)}
    DEFS_DOC.update(doc)
    DEFS_Seacast.update(v2)
    FNS_DOC.update(doc)
    FNS_Seacast.update(v2)
    CALLABLES.update(doc, v2)
    RETURNS_DOC.update(returning(doc))
    RETURNS_Seacast.update(returning({**doc, **v2}))
    QUESTIONS_DOC.update(T.TAPE)
    QUESTIONS_Seacast.update(T.TAPE)
    # seacast.md's questions: the names its functions call that no document defines, and that the toy binds in
    # code that runs under v2 alone (type_of_group, send, choice); the toy's helpers bound for both documents (group,
    # group_index) are computed in place, as under seacast-lite.md, and are no questions. Provisional until the twin's
    # question registry for v2 is read
    seacast_bound = {r["name"] for r in scan(toy).rows if r["seacast_only"]}
    QUESTIONS_Seacast.update(questions_of(v2, set(doc) | set(v2)) & seacast_bound)
    # and the manifest's questions that are namespace names (not the type's functions and parameters, attributes)
    QUESTIONS_Seacast.update(set(T.manifest_seacast.QUESTIONS) - set(T.TYPE_QUESTIONS_Seacast)
                             - set(T.Tracer3.TYPE_FUNCTIONS))
    TRACED.update(T.BLOCK)
    TRACED_V2_KEPT.update(n for n in T.seacast_kept(T.BLOCK, N.SPEC_SRC, N.generate(N.DOC2)) if n not in T.SEC71)
    TRACED_Seacast.update(TRACED_V2_KEPT, T.manifest_seacast.COVERED)    # under v2 the kept names and SEACAST's covered ones
    return T, N


def scan(toy, skip=(), off=()):
    files = sorted(Path(toy).glob("*.py"))
    NS_ALIASES.clear()
    pre = Scanner(skip, off)            # the pre-pass: every binding of every name, before any row is classed, so that
    pre.collect = {}                    #   the observer test can follow a name through all of them, in any file
    for f in files:
        pre.prepass(f)
    pre.reads = READONLY_METHODS | pre.toy_reads()
    for f in files:
        pre.scan_file(f)
    sc = Scanner(skip, off)
    sc.bound_by = pre.collect
    if "pre-methods" not in skip:       # every file's methods, before any row: a follow into any file finds them
        sc.methods = dict(pre.methods)
    for f in files:                     # every module's own functions and imports first, then the bindings
        sc.prepass(f)
    sc.reads = READONLY_METHODS | sc.toy_reads()
    sc.reads_anywhere = sc.read_methods_anywhere()
    for f in files:
        sc.scan_file(f)
    return sc


def line(r):
    v = r["value"]
    val = f"{v['qual']}@{v['line']} {v['sha256'][:12]}" if isinstance(v, dict) else repr(v)
    extra = f" holds {r['holds']}" if "holds" in r else ""
    why = f" ({r['why']})" if "why" in r else ""
    return (f"{r['file']}:{r['line']} {r['in']} {r['form']}{'/' + r['via'] if 'via' in r else ''} {r['name']} = "
            f"{val}{extra} {r['class']}{why}{' v2-only' if r['seacast_only'] else ''}")


def fn_key(v):
    """A function value's key in trace3.py's LAYERS: its file's name, its qualified name and its first line."""
    return v["file"], v["qual"], v["line"]


def at(fl, q, ln):
    """A LAYERS key as the lines name it: qualified name@line in node.py, the file named only for another."""
    return f"{q}@{ln}" if fl == "node.py" else f"{q}@{fl}:{ln}"


def closure_kind_of(split, T):
    """A closure-dependent row's split as trace3.py's ClosureKind: a test `X` or `not X` on one closure value X, each
    branch's class one under both documents (an observer; own or a layer, changing). None for any other split."""
    test, cls = split["on"], {"observer": T.OBSERVER, "own": T.CHANGING, "layer": T.CHANGING}
    t, f = cls.get(split["true"]) if isinstance(split["true"], str) else None, \
        cls.get(split["false"]) if isinstance(split["false"], str) else None
    if t is None or f is None:
        return None
    if test.isidentifier():
        return T.ClosureKind(test, t, f)
    if test.startswith("not ") and test[4:].isidentifier():
        return T.ClosureKind(test[4:], f, t)
    return None


def lists(sc, T):
    """The lists the rows give over node.py's bindings of traced names (under v2, of its kept names for a v2-only
    binding), beside trace3.py's hand-kept ones: each name and qualified name the same, or the difference named."""
    rows = [r for r in sc.rows if r["file"] == "node.py" and r["name"] in (TRACED_V2_KEPT if r["seacast_only"] else TRACED)]
    defined = CALLABLES
    obs = sorted({(r["name"], r["value"]["qual"]) for r in rows if r["class"] == "observer"})
    own = sorted({(r["name"], r["value"]["qual"]) for r in rows if r["class"] == "own" and r["name"] not in defined})
    repl = sorted({r["name"] for r in rows if r["class"] in ("own", "layer") and r["name"] in defined})
    out, other = [], 0
    for r in rows:                      # a class the lists cannot hold: the trace's lists take one class a name
        if r["class"] in ("closure-dependent", "per-document"):
            other += 1
            out.append(f"{r['class']} {r['name']} {r['value']['qual']}: NOT one class, which trace3.py's lists need "
                       f"({r['file']}:{r['line']})")
    hand_obs = sorted(T.WRAPPERS.items())
    layers = getattr(T, "LAYERS", None)     # under v2, the chain rule's lists: the toy's layers by file's name,
    seacast_obs = {(r["name"], r["value"]["qual"]) for r in rows     # qualified name and first line, with their kinds
              if layers is not None and r["seacast_only"] and r["class"] == "observer"
              and layers.get(fn_key(r["value"])) == (r["name"], T.OBSERVER)}
    for x in obs:
        if x in hand_obs:
            out.append(f"observer {x[0]} {x[1]}: as WRAPPERS")
        elif x in seacast_obs:
            out.append(f"observer {x[0]} {x[1]}: v2-only, an observer in LAYERS (the chain rule's)")
        else:
            other += 1
            out.append(f"observer {x[0]} {x[1]}: NOT in WRAPPERS")
    for x in hand_obs:
        if x not in obs:
            other += 1
            out.append(f"WRAPPERS {x[0]} {x[1]}: NOT an observer the scan finds")
    for x in own:
        out.append(f"node-own {x[0]} {x[1]}: " + ("as NODE_OWN" if T.NODE_OWN.get(x[0]) == x[1] else "NOT in NODE_OWN"))
        other += T.NODE_OWN.get(x[0]) != x[1]
    for n, q in T.NODE_OWN.items():
        if (n, q) not in own:
            other += 1
            out.append(f"NODE_OWN {n} {q}: NOT found")
    for n in T.REPLACEABLE:
        if n in repl:
            out.append(f"replaceable {n}: replaced by the toy (as REPLACEABLE)")
        elif n in T.REPLACEABLE_WHOLE:
            out.append(f"replaceable {n}: not replaced by the toy; REPLACEABLE_WHOLE, the directed sets' "
                       f"(formal/twin/tools), outside the scan")
        else:
            other += 1
            out.append(f"replaceable {n}: NOT replaced by the toy")
    for n in T.REPLACEABLE_WHOLE:       # the other direction: a whole-state-only name is replaceable, and no cell's
        if n not in T.REPLACEABLE or n in repl:     #   toy replaces it
            other += 1
            out.append(f"REPLACEABLE_WHOLE {n}: NOT " + ("in REPLACEABLE" if n not in T.REPLACEABLE else
                                                         "the directed sets' alone: the toy replaces it"))
    for n in repl:
        if n not in T.REPLACEABLE:
            sites = [f"{r['in']}:{r['line']}{' v2-only' if r['seacast_only'] else ''}" for r in rows
                     if r["name"] == n and r["class"] in ("own", "layer")]
            out.append(f"replaced {n}, not REPLACEABLE (the tracer stops a trace where it is replaced): {', '.join(sites)}")
    # LAYERS against every node.py binding of a name traced under v2, function by function: an observer; the node's
    # own helper; a function bound inside another's body, during its call (a binding in a local function that runs
    # at the construction would be named so too, and the install would stop on it: loud); a swapped draw; a
    # closure-dependent layer by its split; any other is changing
    if layers is not None:
        kind = {"observer": T.OBSERVER, "own": T.CHANGING, "layer": T.CHANGING}
        want = {}
        if tuple(DRAWS) != tuple(T.DRAWS):
            other += 1
            out.append(f"DRAWS: {list(DRAWS)} here, {list(T.DRAWS)} in trace3.py")
        for r in sc.rows:
            if r["file"] != "node.py" or r["name"] not in TRACED_Seacast or not isinstance(r["value"], dict):
                continue
            if r["class"] == "own" and r["name"] not in defined:
                k = T.NODE_HELPER
            elif "<locals>" in r["in"]:
                k = T.DURING_CALL
            elif r.get("swapped_draw"):
                k = T.SWAPPED_DRAW
            elif r["class"] == "closure-dependent":
                k = closure_kind_of(r["closure"], T)
            else:
                k = kind.get(r["class"])
            if k is not None:
                want[fn_key(r["value"])] = (r["name"], k)
            elif r not in rows:         # (one in `rows` is named above)
                other += 1
                out.append(f"{r['class']} {r['name']} {r['value']['qual']}: NOT one kind, which LAYERS needs "
                           f"({r['file']}:{r['line']})")
        for (fl, q, ln), v in sorted(want.items(), key=lambda kv: (kv[0][0], kv[0][2])):
            if layers.get((fl, q, ln)) == v:
                out.append(f"layer {v[0]} {at(fl, q, ln)}: {v[1]}, as LAYERS")
            else:
                other += 1
                out.append(f"layer {v[0]} {at(fl, q, ln)}: {v[1]}, NOT so in LAYERS"
                           + (f" (there {layers[(fl, q, ln)]})" if (fl, q, ln) in layers else ""))
        for (fl, q, ln), v in sorted(layers.items(), key=lambda kv: (kv[0][0], kv[0][2])):
            if (fl, q, ln) not in want:
                other += 1
                out.append(f"LAYERS {v[0]} {at(fl, q, ln)}: NOT a binding the scan finds of a name traced under v2")
    return out, other


# -- the self-test: one planted binding per form, each form's reader off in turn, a changed body ----------------
PLANTED = '''\
class Node:
    def plant(self, ns):
        doc_a = ns["a"]

        def a(x):
            return doc_a(x)
        ns["a"] = a
        ns["b"], ns["c"] = (lambda y: y), (lambda z: z)
        ns.update(d=lambda: 1)
        ns.update({"e": len})

        def f():
            pass
        ns.update({k: v for k, v in locals().items() if callable(v) and k not in ("a", "doc_a")})
        ns.setdefault("g", 0)
        key = "h"
        ns[key] = 1
        P = Obj()
        P.verify = lambda f: True

    def make(self):
        ns = {"i": self.other}
        return ns

    def other(self):
        pass
'''
WANT = {"subscript": ("a", 7, "observer"), "tuple": ("b", 8, "own"), "update-keyword": ("d", 9, "own"),
        "update-dict": ("e", 10, "value"), "locals-export": ("f", 14, "own"), "setdefault": ("g", 15, "value"),
        "computed-key": ("<key>", 17, "value"), "parameter-attribute": ("P.verify", 19, "own"),
        "namespace-literal": ("i", 22, "own")}


# one planted layer per clause of the observer test (each breaks that clause alone), the cases that must pass, and a
# layer branching on a closure value; the names: askq a question, trf a traced function, tbl a table; every c_* name
# a function of the document that returns a value, but c_none
LAYERS = '''\
GLOBAL_ON = True


class Bits:
    def has(self, i):
        return (self.v >> i) & 1 == 1


class Node:
    def meth(self, x):
        self.ns["tbl"].clear()

    def edit(self, t):
        t.clear()

    def plant(self, ns):
        def helper(t):
            t.pop(0)
        d_question, d_traced, d_assign, d_delete = ns["c_question"], ns["c_traced"], ns["c_assign"], ns["c_delete"]
        d_mutate, d_unfollowed, d_localfn, d_method = ns["c_mutate"], ns["c_unfollowed"], ns["c_localfn"], ns["c_method"]
        d_twice, d_branch, d_args, d_result = ns["c_twice"], ns["c_branch"], ns["c_args"], ns["c_result"]
        d_extra, d_fallthrough, d_arms, d_plain = ns["c_extra"], ns["c_fallthrough"], ns["c_arms"], ns["c_plain"]
        d_none, d_mid = ns["c_none"], ns["message_id"]
        d_qualified, d_aliasrow, d_methodarg, d_brres = ns["c_qualified"], ns["c_aliasrow"], ns["c_methodarg"], ns["c_brres"]
        d_finally, d_handler, d_with, d_effect, d_seacastq = ns["c_finally"], ns["c_handler"], ns["c_with"], ns["c_effect"], ns["c_seacastq"]
        d_put, d_setattr, d_getmut, d_nested = ns["c_put"], ns["c_setattr"], ns["c_getmut"], ns["c_nested"]
        d_lambda, d_lamq, d_outlam, d_reads = ns["c_lambda"], ns["c_lamq"], ns["c_outlam"], ns["c_reads"]
        d_tryelse, d_match, d_handleras, d_walrus = ns["c_tryelse"], ns["c_match"], ns["c_handleras"], ns["c_walrus"]
        d_rebind, d_again, d_has = ns["c_rebind"], ns["c_again"], ns["c_has"]
        clr = lambda: ns["tbl"].clear()

        def c_put(x):
            ns["tbl"].put(x)
            return d_put(x)

        def c_setattr(x):
            setattr(ns["tbl"], "k", 1)
            return d_setattr(x)

        def c_getmut(x):
            ns["tbl"].get(x).append(1)
            return d_getmut(x)

        def c_nested(x):
            def bump():
                ns["tbl"].clear()
            bump()
            return d_nested(x)

        def c_lambda(x):
            (lambda: ns["tbl"].clear())()
            return d_lambda(x)

        def c_lamq(x):
            foreign(lambda: ns["askq"]())
            return d_lamq(x)

        def c_outlam(x):
            clr()
            return d_outlam(x)

        def c_reads(x):
            if ns["tbl"].get(x) and len(ns["tbl"]) and sorted(ns["tbl"]):
                pass
            return d_reads(x)

        def c_tryelse(x):
            try:
                int(x)
            except ValueError:
                pass
            else:
                return d_tryelse(x)
            return 0

        def c_match(x):
            match x:
                case 0:
                    return 0
                case _:
                    pass
            return d_match(x)

        def c_handleras(x):
            try:
                pass
            except ValueError as x:
                pass
            return d_handleras(x)

        def c_walrus(x):
            if (x := x + 1):
                pass
            return d_walrus(x)

        def c_rebind(x):
            d_rebind = replace
            return d_rebind(x)

        def c_again(x):
            def again():
                d_again(x)
            again()
            return d_again(x)

        def c_has(x):
            if ns["tbl"].has(x):
                pass
            return d_has(x)

        def c_qualified(x):
            foreign.process(ns["tbl"])
            return d_qualified(x)

        def c_aliasrow(x):
            r = ns["tbl"][x]
            del r[x]
            return d_aliasrow(x)

        def c_methodarg(x):
            self.edit(ns["tbl"])
            return d_methodarg(x)

        def c_brres(x):
            if x:
                r = d_brres(x)
            else:
                d_brres(x)
                r = 0
            return r

        def c_finally(x):
            try:
                r = d_finally(x)
            finally:
                r = 0
            return r

        def c_handler(x):
            try:
                pass
            except ValueError:
                x = 0
            return d_handler(x)

        def c_with(x):
            with ctx() as x:
                pass
            return d_with(x)

        def c_effect(x):
            if ns["askq"]():
                return 0
            return d_effect(x)

        def c_seacastq(x):
            ns["seacastq"](x)
            return d_seacastq(x)

        def c_question(x):
            ns["askq"](x)
            return d_question(x)

        def c_traced(x):
            ns["trf"](x)
            return d_traced(x)

        def c_assign(x):
            ns["tbl"][x] = 1
            return d_assign(x)

        def c_delete(x):
            o = ns["tbl"]
            del o[x]
            return d_delete(x)

        def c_mutate(x):
            ns["tbl"].add(x)
            return d_mutate(x)

        def c_unfollowed(x):
            foreign(ns["tbl"])
            return d_unfollowed(x)

        def c_localfn(x):
            helper(ns["tbl"])
            return d_localfn(x)

        def c_method(x):
            self.meth(x)
            return d_method(x)

        def c_twice(x):
            d_twice(x)
            return d_twice(x)

        def c_branch(x):
            if x:
                return d_branch(x)

        def c_args(x):
            x = x + 1
            return d_args(x)

        def c_result(x):
            d_result(x)

        def c_extra(x):
            return d_extra(x, 2)

        def c_fallthrough(x):
            r = d_fallthrough(x)
            if r:
                return r

        def c_arms(x):
            if x:
                return d_arms(x)
            else:
                return d_arms(x)

        def c_plain(x):
            v = d_plain(x)
            return v

        def c_none(x):
            d_none(x)

        def message_id(f):
            if f:
                return d_mid(f)
            return 0
        ns.update(c_question=c_question, c_traced=c_traced, c_assign=c_assign, c_delete=c_delete, c_mutate=c_mutate,
                  c_unfollowed=c_unfollowed, c_localfn=c_localfn, c_method=c_method, c_twice=c_twice,
                  c_branch=c_branch, c_args=c_args, c_result=c_result, c_extra=c_extra, c_fallthrough=c_fallthrough,
                  c_arms=c_arms, c_plain=c_plain, c_none=c_none, message_id=message_id, c_qualified=c_qualified,
                  c_aliasrow=c_aliasrow, c_methodarg=c_methodarg, c_brres=c_brres, c_finally=c_finally,
                  c_handler=c_handler, c_with=c_with, c_effect=c_effect, c_seacastq=c_seacastq, c_put=c_put,
                  c_setattr=c_setattr, c_getmut=c_getmut, c_nested=c_nested, c_lambda=c_lambda, c_lamq=c_lamq,
                  c_outlam=c_outlam, c_reads=c_reads, c_tryelse=c_tryelse, c_match=c_match, c_handleras=c_handleras,
                  c_walrus=c_walrus, c_rebind=c_rebind, c_again=c_again, c_has=c_has)

    def closure(self, ns, on):
        d_closed = ns["c_closed"]

        def c_closed(x):
            if not on:
                return 0
            return d_closed(x)
        ns["c_closed"] = c_closed

    def closure_global(self, ns):
        d_global = ns["c_global"]

        def c_global(x):
            if not GLOBAL_ON:
                return 0
            return d_global(x)
        ns["c_global"] = c_global

    def closure_sibling(self, ns):
        on = True
        d_sibling = ns["c_sibling"]

        def c_sibling(x):
            if not on:
                return 0
            return d_sibling(x)

        def flip():
            nonlocal on
            on = False
        ns["c_sibling"] = c_sibling

    def closure_param(self, ns, on):
        on = not on
        d_param = ns["c_param"]

        def c_param(x):
            if not on:
                return 0
            return d_param(x)
        ns["c_param"] = c_param

    def closure_doc(self, ns, on):
        d_doc = ns["c_doc"]

        def c_doc(x):
            if not on:
                return 0
            ns["seacastq"](x)
            return d_doc(x)
        ns["c_doc"] = c_doc
'''
BREAKS = {"c_question": "question", "c_traced": "traced", "c_assign": "assign", "c_delete": "delete",
          "c_mutate": "mutate", "c_unfollowed": "unfollowed", "c_localfn": "local-fn", "c_method": "node-method",
          "c_twice": "twice", "c_branch": "branch", "c_args": "arguments", "c_result": "result",
          "c_extra": "arguments", "c_fallthrough": "result", "c_qualified": "unfollowed", "c_aliasrow": "delete",
          "c_methodarg": "node-method", "c_brres": "result", "c_finally": "result", "c_handler": "arguments",
          "c_with": "arguments", "c_put": "mutate", "c_setattr": "unfollowed", "c_getmut": "mutate",
          "c_nested": "mutate", "c_lambda": "mutate", "c_lamq": "question", "c_outlam": "local-fn",
          "c_tryelse": "branch", "c_match": "branch", "c_handleras": "arguments", "c_walrus": "arguments",
          "c_rebind": "rebind", "c_again": "twice"}
PASSES = ("c_arms", "c_plain", "c_none", "message_id", "c_reads", "c_has")
# a branch on a call's answer, a module's global, a name a sibling rebinds through `nonlocal`, a parameter assigned
# again: no construction value, so no class per branch (each a layer, whole)
NOT_SPLIT = ("c_effect", "c_global", "c_sibling", "c_param")

# The follow's cases: (o) observers whose callees only read; (l) layers whose callees do not. The questions are
# rq, rq2, wq, uq, dq, deep1, deep2, ownq, vq, nq and choice (a draw); the traced names tr_r, tr_w, tr_rb, whose
# document code is FOLLOW_DOC's
FOLLOW_DOC = '''\
def tr_r(g):
    return mine.get(g) is not None and g in seen


def tr_w(g):
    seen[g] = True
    return True


def tr_rb(g):
    return g in seen
'''
FOLLOW = '''\
class Node:
    def plant(self, ns):
        def rq(g):
            return ns["tbl"].get(g)

        def rq2(g):
            return ns["rq"](g) is not None

        def wq(g):
            ns["tbl"][g] = 1

        def uq(g):
            foreign(ns["tbl"])

        def dq(g):
            return ns["choice"]([g])

        def choice(xs):
            return xs[0]

        def deep1(g):
            return ns["deep2"](g)

        def deep2(g):
            ns["tbl"].clear()

        def ownq(g):
            return ns["f_own"](g)

        def tr_rb(g):
            ns["tbl"].pop(g)
            return True
        ns.update(rq=rq, rq2=rq2, wq=wq, uq=uq, dq=dq, choice=choice, deep1=deep1, deep2=deep2, ownq=ownq,
                  tr_rb=tr_rb)
        ns["vq"] = some_value
        d_o1, d_o2, d_o3, d_l1, d_l2 = ns["f_o1"], ns["f_o2"], ns["f_o3"], ns["f_l1"], ns["f_l2"]
        d_l3, d_l3b, d_l4, d_l4b, d_l5 = ns["f_l3"], ns["f_l3b"], ns["f_l4"], ns["f_l4b"], ns["f_l5"]
        d_l6, d_l6b, d_own = ns["f_l6"], ns["f_l6b"], ns["f_own"]

        def f_o1(x):
            ns["rq"](x)
            return d_o1(x)

        def f_o2(x):
            ns["tr_r"](x)
            return d_o2(x)

        def f_o3(x):
            ns["rq2"](x)
            return d_o3(x)

        def f_l1(x):
            ns["wq"](x)
            return d_l1(x)

        def f_l2(x):
            ns["uq"](x)
            return d_l2(x)

        def f_l3(x):
            ns["dq"](x)
            return d_l3(x)

        def f_l3b(x):
            ns["choice"]([x])
            return d_l3b(x)

        def f_l4(x):
            ns["tr_w"](x)
            return d_l4(x)

        def f_l4b(x):
            ns["tr_rb"](x)
            return d_l4b(x)

        def f_l5(x):
            ns["deep1"](x)
            return d_l5(x)

        def f_l6(x):
            ns["vq"](x)
            return d_l6(x)

        def f_l6b(x):
            ns["nq"](x)
            return d_l6b(x)

        def f_own(x):
            ns["ownq"](x)
            return d_own(x)
        ns.update(f_o1=f_o1, f_o2=f_o2, f_o3=f_o3, f_l1=f_l1, f_l2=f_l2, f_l3=f_l3, f_l3b=f_l3b, f_l4=f_l4,
                  f_l4b=f_l4b, f_l5=f_l5, f_l6=f_l6, f_l6b=f_l6b, f_own=f_own)
'''
# each observer, and with the follow off a layer
FOLLOW_OBSERVERS = ("f_o1", "f_o2", "f_o3")
# each layer: the clause whose refusal makes it one (off, an observer), and the end of its reason. Where followed code's
# fail-closed clause (effect, call) refuses it too, both are named: the first alone off, it is still a layer, by the
# second
FOLLOW_LAYERS = {
    "f_l1": (("assign", "effect"), "writes ns['tbl'][g], in wq"),   # (l1) a callee that writes a table
    "f_l2": (("unfollowed", "call"), "which the test does not follow, in uq"),  # (l2) one that hands a table to a call
    "f_l3": ("draw", "names the draw choice, in dq"),               # (l3) one that asks a draw
    "f_l3b": ("draw", "names the draw choice"),                     # (l3) a layer that names one itself
    "f_l4": (("assign", "effect"), "writes seen[g], in tr_w"),      # (l4) a traced callee whose document code writes
    "f_l4b": (("mutate", "effect"), "by pop, in tr_rb"),            # (l4) one whose document code reads, a binding not
    "f_l5": (("mutate", "effect"), "by clear, in deep2, in deep1"), # (l5) the write two calls deep
    "f_l6": ("unread", "which the toy binds to a value the scan does not read as a function"),  # (l6) a value
    "f_l6b": ("unread", "which has no binding or definition the scan reads"),                   # (l6) no binding
    "f_own": ("own-name", "names f_own, the layer's own name, in ownq"),     # (l7) the layer's own name followed
}
# a computed key the scan cannot name may bind any question: every follow refused; the control, its key the
# variable of a loop over literal names, which are not followed names
FOLLOW_UNNAMED = '''\
def setter(ns, k):
    ns[k] = lambda g: None
'''
FOLLOW_NAMED = '''\
def setter(ns):
    for k in ("a_name", "b_name"):
        ns[k] = lambda g: None
'''


def follow_self_test(report):
    """The follow's cases (FOLLOW), each with its planted fault (a clause off). It sets the name
    sets itself; self_test restores them."""
    qs = {"rq", "rq2", "wq", "uq", "dq", "deep1", "deep2", "ownq", "vq", "nq", "choice"}
    doc = {d.name: d for d in ast.parse(FOLLOW_DOC).body}
    rows_ = {f"f_{c}" for c in ("o1", "o2", "o3", "l1", "l2", "l3", "l3b", "l4", "l4b", "l5", "l6", "l6b", "own")}
    for s, v in ((QUESTIONS_DOC, qs), (QUESTIONS_Seacast, qs), (TRACED, set(doc)), (TRACED_Seacast, set(doc)),
                 (DEFS_DOC, rows_ | set(doc)), (RETURNS_DOC, rows_ | set(doc)), (CALLABLES, rows_ | set(doc)),
                 (FNS_DOC, doc), (FNS_Seacast, {})):
        s.clear()
        s.update(v)

    def got(rows, name):
        r = [r for r in rows if r["name"] == name and r["form"] == "update-keyword"]
        return (r[0]["class"], r[0].get("why", "")) if len(r) == 1 else (f"{len(r)} rows", "")
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "follow.py").write_text(FOLLOW)
        rows = scan(d).rows
        no_follow = scan(d, off=("follow",)).rows
        for name in FOLLOW_OBSERVERS:
            c, why = got(rows, name)
            report(f"the follow: {name} an observer (its callee only reads)", c == "observer", f"got {c} ({why})")
            c, why = got(no_follow, name)
            report(f"control: {name} with the follow off a layer, by name", c == "layer" and why.startswith("names "),
                   f"got {c} ({why})")
        for name, (clause, end) in FOLLOW_LAYERS.items():
            c, why = got(rows, name)
            report(f"the follow: {name} a layer, \"…{end}\"", c == "layer" and why.endswith(end), f"got {c} ({why})")
            clauses = clause if isinstance(clause, tuple) else (clause,)
            c, why = got(scan(d, off=clauses).rows, name)
            report(f"control: {name} with the clause{'s' if len(clauses) > 1 else ''} {' and '.join(clauses)} off an "
                   f"observer", c == "observer", f"got {c} ({why})")
            if len(clauses) > 1:        # the old clause alone off: the fail-closed one still refuses it
                c, why = got(scan(d, off=clauses[:1]).rows, name)
                report(f"the follow: {name} with {clauses[0]} alone off still a layer, by {clauses[1]}",
                       c == "layer" and ("cannot establish" in why), f"got {c} ({why})")
        (Path(d) / "setter.py").write_text(FOLLOW_UNNAMED)
        c, why = got(scan(d).rows, "f_o1")
        report("the follow: a computed key the scan cannot name, f_o1 a layer", c == "layer" and
               why == "names rq, and the toy binds a computed key the scan cannot name", f"got {c} ({why})")
        (Path(d) / "setter.py").write_text(FOLLOW_NAMED)
        c, why = got(scan(d).rows, "f_o1")
        report("control: the computed key a loop's over literal names, f_o1 an observer", c == "observer",
               f"got {c} ({why})")
        (Path(d) / "setter.py").write_text(FOLLOW_NAMED.replace('"b_name"', '"rq"').replace(
            "lambda g: None", "lambda g: ns['tbl'].clear()"))
        c, why = got(scan(d).rows, "f_o1")
        report("the follow: a loop's literal key binds rq to a writer, f_o1 a layer", c == "layer" and
               why.endswith("by clear, in rq"), f"got {c} ({why})")
        (Path(d) / "setter.py").unlink()

        def mark(rows, name):
            r = [r for r in rows if r["name"] == name and r["form"] == "update-keyword"]
            return r[0].get("swapped_draw", False) if len(r) == 1 else f"{len(r)} rows"
        # (l3b) calls a draw in its own code and binds no stand-in: no swapped draw (the tracer would re-wrap it)
        report("the follow: f_l3b, a layer that calls a draw itself, is no swapped draw", mark(rows, "f_l3b") is False,
               f"got {mark(rows, 'f_l3b')}")
        m = mark(scan(d, off=("draw-call",)).rows, "f_l3b")
        report("control: f_l3b with the clause draw-call off a swapped draw", m is True, f"got {m}")


# fail-closed followed code: each reviewer's probe (r2n), planted where a question's binding or a document function
# the follow reads holds it. FC_DOC is the document's code, FC the toy's
FC_DOC = '''\
def tr_chain(g):
    return tr_w2(g)


def tr_w2(g):
    seen[g] = True
    return True
'''
FC = '''\
def mod_fn(b):
    return b[0]


class Made:
    def __init__(self, a, b):
        self.a = a
        self.b = b


REGISTRY = []


class Registered:
    def __init__(self, a):
        self.a = a
        REGISTRY.append(self)


class Hooked:
    def __init__(self, a):
        self.a = a

    def __setattr__(self, k, v):
        REGISTRY.append(v)


class WithNew:
    def __new__(cls, a):
        return object.__new__(cls)


@dataclass
class Data:
    a: int = 0


class Node:
    @staticmethod
    def m_static(xs):
        xs.clear()

    def plant(self, ns):
        node = self
        hp = ns["hp"]
        nsx = node.ns

        def q_timer(g):
            node.sim.after(1.0, g)

        def q_rng(g):
            return node.sim.floor_rng.random() < g

        def q_field(g):
            self._seen.add(g)

        def q_store(g):
            node.count += 1

        def q_target(g):
            for node.last in g:
                pass

        def q_nested(g):
            [a, (b, node.held)] = g

        def q_hook(g):
            return Hooked(g)

        def q_arg(asks):
            asks.clear()

        def q_helper(g):
            return hp(g)

        def q_loop(g):
            for lane in node.queues.values():
                lane.clear()

        def q_cond(g, c=True):
            (node.a if c else node.b).append(g)

        q_default = lambda g, t=ns["tbl"]: t.pop(g, None)

        def q_star(g):
            def inner(*xs):
                xs[0].clear()
            inner(ns["tbl"])

        def q_global(g):
            global counter
            return g

        def q_fresh(g):
            out = []
            out.append(Made(g, 1))
            out.append(int.from_bytes(g, "little"))
            out.append(mod_fn(g))
            return out

        def q_reg(g):
            return Registered(g)

        def q_new(g):
            return WithNew(g)

        def q_data(g):
            return Data(g)

        def q_any(g):
            return ns["tbl"].get(g)

        def q_upd(g):
            return ns["tbl"].get(g)

        def q_upd_w(g):
            ns["tbl"][g] = 1

        def q_alias(g):
            return ns["tbl"].get(g)

        def q_alias_w(g):
            ns["tbl"][g] = 1

        def q_reb(g):
            return ns["tbl"].get(g)
        q_reb = wrap(q_reb)

        @wrap
        def q_dec(g):
            return ns["tbl"].get(g)

        def q_shadow(g):
            def mk():
                pool = []
                return pool
            pool.append(g)
        ns.update(q_shadow=q_shadow, q_target=q_target, q_nested=q_nested, q_hook=q_hook)
        ns.update(q_timer=q_timer, q_rng=q_rng, q_field=q_field, q_store=q_store, q_arg=q_arg, q_helper=q_helper,
                  q_loop=q_loop, q_cond=q_cond, q_default=q_default, q_star=q_star, q_global=q_global,
                  q_fresh=q_fresh, q_reg=q_reg, q_new=q_new, q_data=q_data, q_any=q_any, q_upd=q_upd,
                  q_alias=q_alias, q_reb=q_reb, q_dec=q_dec)
        ns["q_any"] = some_value
        ns.update(**{"q_upd": q_upd_w})
        nsx["q_alias"] = q_alias_w
        ns["q_static"] = self.m_static
        ns["tog"] = lambda g: ns["types"].get(g)
        d_timer, d_rng, d_field, d_store, d_arg = ns["c_timer"], ns["c_rng"], ns["c_field"], ns["c_store"], ns["c_arg"]
        d_helper, d_loop, d_cond, d_default = ns["c_helper"], ns["c_loop"], ns["c_cond"], ns["c_default"]
        d_star, d_global, d_fresh, d_reg, d_new = ns["c_star"], ns["c_global"], ns["c_fresh"], ns["c_reg"], ns["c_new"]
        d_data, d_any, d_upd, d_alias, d_reb = ns["c_data"], ns["c_any"], ns["c_upd"], ns["c_alias"], ns["c_reb"]
        d_reb2, d_dec, d_static, d_result, d_doc = ns["c_reb2"], ns["c_dec"], ns["c_static"], ns["c_result"], ns["c_doc"]
        d_shadow, d_target, d_nested, d_hook = ns["c_shadow"], ns["c_target"], ns["c_nested"], ns["c_hook"]

        def c_shadow(x):
            ns["q_shadow"](x)
            return d_shadow(x)

        def c_target(x):
            ns["q_target"](x)
            return d_target(x)

        def c_nested(x):
            ns["q_nested"](x)
            return d_nested(x)

        def c_hook(x):
            ns["q_hook"](x)
            return d_hook(x)

        def c_timer(x):
            ns["q_timer"](x)
            return d_timer(x)

        def c_rng(x):
            ns["q_rng"](x)
            return d_rng(x)

        def c_field(x):
            ns["q_field"](x)
            return d_field(x)

        def c_store(x):
            ns["q_store"](x)
            return d_store(x)

        def c_arg(x):
            ns["q_arg"](x)
            return d_arg(x)

        def c_helper(x):
            ns["q_helper"](x)
            return d_helper(x)

        def c_loop(x):
            ns["q_loop"](x)
            return d_loop(x)

        def c_cond(x):
            ns["q_cond"](x)
            return d_cond(x)

        def c_default(x):
            ns["q_default"](x)
            return d_default(x)

        def c_star(x):
            ns["q_star"](x)
            return d_star(x)

        def c_global(x):
            ns["q_global"](x)
            return d_global(x)

        def c_fresh(x):
            ns["q_fresh"](x)
            return d_fresh(x)

        def c_reg(x):
            ns["q_reg"](x)
            return d_reg(x)

        def c_new(x):
            ns["q_new"](x)
            return d_new(x)

        def c_data(x):
            ns["q_data"](x)
            return d_data(x)

        def c_any(x):
            ns["q_any"](x)
            return d_any(x)

        def c_upd(x):
            ns["q_upd"](x)
            return d_upd(x)

        def c_alias(x):
            ns["q_alias"](x)
            return d_alias(x)

        def c_reb(x):
            ns["q_reb"](x)
            return d_reb(x)

        def c_reb2(x):
            ns["q_reb2"](x)
            return d_reb2(x)

        def c_dec(x):
            ns["q_dec"](x)
            return d_dec(x)

        def c_static(x):
            ns["q_static"](ns["tbl"])
            return d_static(x)

        def c_result(x):
            ns["tog"](x).params.DECODE_LATER(x)
            return d_result(x)

        def c_doc(x):
            ns["tr_chain"](x)
            return d_doc(x)
        ns.update(c_timer=c_timer, c_rng=c_rng, c_field=c_field, c_store=c_store, c_arg=c_arg, c_helper=c_helper,
                  c_loop=c_loop, c_cond=c_cond, c_default=c_default, c_star=c_star, c_global=c_global,
                  c_fresh=c_fresh, c_reg=c_reg, c_new=c_new, c_data=c_data, c_any=c_any, c_upd=c_upd,
                  c_alias=c_alias, c_reb=c_reb, c_reb2=c_reb2, c_dec=c_dec, c_static=c_static, c_result=c_result,
                  c_doc=c_doc, c_shadow=c_shadow, c_target=c_target, c_nested=c_nested, c_hook=c_hook)

    def plant2(self, ns):
        def q_reb2(g):
            return ns["tbl"].get(g)
        q_reb2 = wrap(q_reb2)
        ns.update({k: v for k, v in locals().items() if callable(v) and k not in ("self", "ns")})
'''
# each layer: the end of its reason, and its control: the clauses off (off) or the readers skipped (skip) under which
# it reads an observer
FC_LAYERS = {
    # F1's three, Codex and Fable: a timer, a draw stream, a node field; a field stored; a mutable argument
    "c_timer": ("calls node.sim.after, which the follow cannot establish as a read, in q_timer", {"off": ("call",)}),
    "c_rng": ("calls node.sim.floor_rng.random, which the follow cannot establish as a read, in q_rng",
              {"off": ("call",)}),
    "c_field": ("mutates self._seen by add, which the follow cannot establish as its own new object, in q_field",
                {"off": ("effect",)}),
    "c_store": ("writes node.count, which the follow cannot establish as its own new object, in q_store",
                {"off": ("effect",)}),
    "c_arg": ("mutates asks by clear, which the follow cannot establish as its own new object, in q_arg",
              {"off": ("effect",)}),
    # the inventory (F2, F3, F5): ns.update(**{…}), an alias of the namespace, a rebinding to a call's result (bound,
    # and exported by locals()), a decorator
    "c_upd": ("writes ns['tbl'][g], in q_upd", {"skip": ("update-starred",)}),
    "c_alias": ("writes ns['tbl'][g], in q_alias", {"skip": ("ns-alias",)}),
    "c_reb": ("names q_reb, which the toy binds to a value the scan does not read as a function", {"skip": ("rebound",)}),
    "c_reb2": ("names q_reb2, which the toy binds to a value the scan does not read as a function",
               {"skip": ("rebound",)}),
    "c_dec": ("names q_dec, which the toy binds to a value the scan does not read as a function",
              {"skip": ("decorated",)}),
    # F11's: a captured helper, a loop's target, a conditional receiver, a default, *args, a static method, a result,
    # "any" unread, global, a document function reached from a followed one
    "c_helper": ("calls hp, a namespace name the follow does not read, in q_helper", {"off": ("call",)}),
    "c_loop": ("mutates lane by clear, which the follow cannot establish as its own new object, in q_loop",
               {"off": ("effect",)}),
    "c_cond": ("by append, which the follow cannot establish as its own new object, in q_cond", {"off": ("effect",)}),
    "c_default": ("mutates t by pop, which the follow cannot establish as its own new object, in q_default",
                  {"off": ("effect",)}),
    "c_star": ("mutates xs[0] by clear, which the follow cannot establish as its own new object, in inner, in q_star",
               {"off": ("effect",)}),
    "c_result": ("calls DECODE_LATER on ns['tog'](x).params, which the test does not establish as a read",
                 {"off": ("answer",)}),
    "c_any": ("names q_any, which the toy binds to a value the scan does not read as a function", {"off": ("unread",)}),
    "c_global": ("declares global counter, in q_global", {"off": ("assign",)}),
    "c_doc": ("writes seen[g], in tr_w2, in tr_chain", {"off": ("assign", "effect")}),
    # a name a nested function binds to a new object is not the followed function's own: its free `pool` is no fresh one
    "c_shadow": ("mutates pool by append, which the follow cannot establish as its own new object, in q_shadow",
                 {"off": ("effect",)}),
    # a store in a for's target, and in a nested list target
    "c_target": ("writes node.last, which the follow cannot establish as its own new object, in q_target",
                 {"off": ("effect",)}),
    "c_nested": ("writes node.held, which the follow cannot establish as its own new object, in q_nested",
                 {"off": ("effect",)}),
    # a toy class's constructor (fv-67's guards): an __init__ with an effect, a __new__, a decorated class
    "c_reg": ("mutates REGISTRY by append, which the follow cannot establish as its own new object, in "
              "Registered.__init__, in q_reg", {"off": ("ctor-init",)}),
    "c_new": ("calls WithNew, a class whose making the follow does not read, in q_new", {"off": ("ctor-guard",)}),
    "c_data": ("calls Data, a class whose making the follow does not read, in q_data", {"off": ("ctor-guard",)}),
    # a class whose __setattr__ runs at its __init__'s store: refused by the guard; with it off, __init__'s own store on
    # self passes and the hook is not followed (the guard is what refuses it)
    "c_hook": ("calls Hooked, a class whose making the follow does not read, in q_hook", {"off": ("ctor-guard",)}),
}
# the fresh object: an observer, and with each allowance off a layer (the allowance is what passes it)
FC_FRESH = {"fresh": "mutates out by append", "ctor": "calls Made", "pure": "calls int.from_bytes",
            "module-fn": "calls mod_fn"}
# whole-scan cases, each in a file of its own beside FC: (file, text, the reader whose skip makes c_fresh an observer)
FC_UNNAMED = {
    "a computed key by **": ("star.py", "def setter(ns, extra):\n    ns.update(**extra)\n", "update-starred"),
    "a loop that binds its variable": ("loopkey.py", 'def setter(ns, w):\n    for k in ("harmless",):\n'
                                       '        k = "q_fresh"\n        ns[k] = w\n', "loop-rebind"),
}
# file order: a layer in one file follows a binding in another that calls self.m, a method of that other file
FO_LAYER = '''\
class Node:
    def plant_a(self, ns):
        d_fo = ns["c_fo"]

        def c_fo(x):
            ns["q_fo"](x)
            return d_fo(x)
        ns.update(c_fo=c_fo)
'''
FO_BINDING = '''\
class Node:
    def m_fo(self, g):
        self.ns["tbl"].clear()

    def plant_z(self, ns):
        def q_fo(g):
            self.m_fo(g)
        ns.update(q_fo=q_fo)
'''


def fail_closed_self_test(report):
    """Fail-closed followed code's cases (FC), each with its control. It sets the name sets itself; self_test
    restores them."""
    layers = set(FC_LAYERS) | {"c_fresh", "c_static"}
    qs = {n for n in ("timer", "rng", "field", "store", "arg", "helper", "loop", "cond", "default", "star", "global",
                      "fresh", "reg", "new", "data", "any", "upd", "alias", "reb", "reb2", "dec", "static", "shadow",
                      "target", "nested", "hook")}
    qs = {f"q_{n}" for n in qs} | {"tog"}
    doc = {d.name: d for d in ast.parse(FC_DOC).body}
    for s, v in ((QUESTIONS_DOC, qs), (QUESTIONS_Seacast, qs), (TRACED, {"tr_chain"}), (TRACED_Seacast, {"tr_chain"}),
                 (DEFS_DOC, layers | set(doc)), (RETURNS_DOC, layers | set(doc)), (CALLABLES, layers | set(doc)),
                 (FNS_DOC, doc), (FNS_Seacast, {})):
        s.clear()
        s.update(v)

    def got(rows, name):
        r = [r for r in rows if r["name"] == name and r["form"] == "update-keyword"]
        return (r[0]["class"], r[0].get("why", "")) if len(r) == 1 else (f"{len(r)} rows", "")
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "fc.py").write_text(FC)
        rows = scan(d).rows
        for name, (end, ctl) in FC_LAYERS.items():
            c, why = got(rows, name)
            report(f"fail-closed: {name} a layer, \"…{end[-70:]}\"", c == "layer" and why.endswith(end),
                   f"got {c} ({why})")
            c, why = got(scan(d, **ctl).rows, name)
            report(f"control: {name} with {ctl} an observer", c == "observer", f"got {c} ({why})")
        c, why = got(rows, "c_static")       # a static method: its first parameter is the table handed, no receiver
        report("fail-closed: c_static a layer, \"mutates xs by clear, in q_static\"",
               c == "layer" and why == "mutates xs by clear, in q_static", f"got {c} ({why})")
        c, why = got(scan(d, skip=("static",)).rows, "c_static")
        report("control: c_static with the static reader off, xs no table (another reason)",
               c == "layer" and why != "mutates xs by clear, in q_static", f"got {c} ({why})")
        c, why = got(rows, "c_fresh")
        report("fail-closed: c_fresh an observer (its own list, a toy constructor, int.from_bytes, its file's function)",
               c == "observer", f"got {c} ({why})")
        for clause, start in FC_FRESH.items():
            c, why = got(scan(d, off=(clause,)).rows, "c_fresh")
            report(f"control: c_fresh with the allowance {clause} off a layer, \"{start}…\"",
                   c == "layer" and why.startswith(start), f"got {c} ({why})")
        for what, (fname, text, reader) in FC_UNNAMED.items():
            (Path(d) / fname).write_text(text)
            c, why = got(scan(d).rows, "c_fresh")
            report(f"fail-closed: {what}, c_fresh a layer", c == "layer" and
                   why == "names q_fresh, and the toy binds a computed key the scan cannot name", f"got {c} ({why})")
            c, why = got(scan(d, skip=(reader,)).rows, "c_fresh")
            report(f"control: {what}, its reader {reader} off, c_fresh an observer", c == "observer", f"got {c} ({why})")
            (Path(d) / fname).unlink()
    for s, v in ((QUESTIONS_DOC, {"q_fo"}), (QUESTIONS_Seacast, {"q_fo"}), (TRACED, set()), (TRACED_Seacast, set()),
                 (DEFS_DOC, {"c_fo"}), (RETURNS_DOC, {"c_fo"}), (CALLABLES, {"c_fo"}), (FNS_DOC, {}),
                 (FNS_Seacast, {})):
        s.clear()
        s.update(v)
    want = "mutates self.ns['tbl'] by clear, in m_fo, in q_fo"
    for first, second in (("a.py", "z.py"), ("z.py", "a.py")):     # the layer's file scanned first, then last
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / first).write_text(FO_LAYER)
            (Path(d) / second).write_text(FO_BINDING)
            c, why = got(scan(d).rows, "c_fo")
            report(f"fail-closed: file order, the layer in {first}, the method in {second}: \"…{want}\"",
                   c == "layer" and why == want, f"got {c} ({why})")
            if first == "a.py":
                c, why = got(scan(d, skip=("pre-methods",)).rows, "c_fo")
                report("control: the pre-pass's method map off, the method in the later file not followed",
                       c == "layer" and why != want, f"got {c} ({why})")


def self_test():
    bad = 0

    def report(what, ok, got=""):
        nonlocal bad
        bad += not ok
        print(f"scan_bindings self-test, {what}: {'ok' if ok else f'{got}  <-- FAIL'}")

    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "planted.py"
        p.write_text(PLANTED)
        sc = scan(d)
        for form, (name, ln, cls) in WANT.items():
            got = [r for r in sc.rows if r["form"] == form and r["name"] == name and r["line"] == ln]
            report(f"the form {form}: {name} at line {ln}, {cls}", len(got) == 1 and got[0]["class"] == cls,
                   f"got {[line(r) for r in got]}")
        for form, (name, ln, cls) in WANT.items():      # the control: each form's reader off, no row at its line
            left = [r for r in scan(d, skip=(form,)).rows if r["line"] == ln]
            report(f"control: the reader of {form} off, no row at line {ln}", not left,
                   f"still {[line(r) for r in left]}")
        before = {(r["form"], r["name"], r["line"]): r["value"]["sha256"] for r in sc.rows if isinstance(r["value"], dict)}
        p.write_text(PLANTED.replace("            return doc_a(x)\n", "            x = x\n            return doc_a(x)\n"))
        after = {(r["form"], r["name"], r["line"] - (1 if r["line"] > 6 else 0)): r["value"]["sha256"]
                 for r in scan(d).rows if isinstance(r["value"], dict)}
        moved = sorted(k for k in before if after.get(k) != before[k])
        report("a changed observer body: its row's hash alone moved, the rows the same",
               moved == [("subscript", "a", 7)] and set(before) == set(after), f"moved {moved}")
    sets = (QUESTIONS_DOC, QUESTIONS_Seacast, TRACED, TRACED_Seacast, DEFS_DOC, RETURNS_DOC)
    saved = [set(s) for s in sets]
    more = (CALLABLES, FNS_DOC, FNS_Seacast)       # the follow's cases set these too (follow_self_test)
    saved_more = [type(s)(s) for s in more]
    names = set(BREAKS) | set(PASSES) | set(NOT_SPLIT) | {"c_closed", "c_seacastq", "c_doc"}
    for s, v in zip(sets, ({"askq"}, {"askq", "seacastq"}, {"trf"}, {"trf"}, names,
                           names - {"c_none", "message_id"})):
        s.clear()
        s.update(v)
    try:
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "layers.py").write_text(LAYERS)

            def cls(rows, name):
                got = [r for r in rows if r["name"] == name and r["form"] in ("update-keyword", "subscript")]
                return got[0]["class"] if len(got) == 1 else f"{len(got)} rows"
            rows = scan(d).rows
            for name, clause in BREAKS.items():         # each a layer, and an observer with its clause off
                report(f"{name} (breaks {clause}) a layer", cls(rows, name) == "layer", f"got {cls(rows, name)}")
                c = cls(scan(d, off=(clause,)).rows, name)
                report(f"control: {name} with the clause {clause} off an observer", c == "observer", f"got {c}")
            for name in PASSES:
                report(f"{name} an observer", cls(rows, name) == "observer", f"got {cls(rows, name)}")
            c = cls(scan(d, off=("by-name",)).rows, "message_id")
            report("control: message_id with the rule by name off a layer", c == "layer", f"got {c}")
            for name in NOT_SPLIT:
                report(f"{name} not split, a layer", cls(rows, name) == "layer", f"got {cls(rows, name)}")
            (Path(d) / "layers.py").write_text(LAYERS.replace("        return (self.v >> i) & 1 == 1\n",
                                                              "        self.v = 0\n"))
            c = cls(scan(d).rows, "c_has")
            report("control: a toy's `has` that writes is no read, c_has a layer", c == "layer", f"got {c}")
            (Path(d) / "layers.py").write_text(LAYERS)
            got = [r for r in rows if r["name"] == "c_seacastq"]
            ok = (len(got) == 1 and got[0]["class"] == "per-document"
                  and got[0]["by_document"]["seacast-lite.md"] == "observer"
                  and got[0]["by_document"]["seacast"].startswith("layer"))
            report("c_seacastq per document: an observer under seacast-lite.md, a layer under seacast.md "
                   "(a seacast.md question)", ok,
                   f"got {[(r['class'], r.get('by_document')) for r in got]}")
            got = [r for r in rows if r["name"] == "c_closed"]
            ok = (len(got) == 1 and got[0]["class"] == "closure-dependent"
                  and got[0]["closure"] == {"on": "not on", "true": "own", "false": "observer"})
            report("c_closed closure-dependent: own where `not on`, an observer where not", ok,
                   f"got {[(r['class'], r.get('closure')) for r in got]}")
            got = [r for r in rows if r["name"] == "c_doc"]
            ok = (len(got) == 1 and got[0]["class"] == "closure-dependent"
                  and got[0]["closure"] == {"on": "not on", "true": "own",
                                            "false": {"seacast-lite.md": "observer", "seacast": "layer"}})
            report("c_doc closure-dependent, its branches per document: own where `not on`; where not, an observer "
                   "under seacast-lite.md and a layer under seacast.md (a seacast.md question)", ok,
                   f"got {[(r['class'], r.get('closure')) for r in got]}")
        # the lists count a row of a traced name that has no one class; the control, the same row an observer
        # in WRAPPERS, counts none
        T = type("T", (), {"WRAPPERS": {}, "NODE_OWN": {}, "REPLACEABLE": (), "REPLACEABLE_WHOLE": ()})
        row = {"file": "node.py", "line": 5, "in": "Node.p", "form": "subscript", "name": "trf", "seacast_only": False,
               "value": {"qual": "Node.p.<locals>.trf", "file": "node.py", "line": 6, "sha256": "0" * 64}}
        for c in ("closure-dependent", "per-document"):
            out, other = lists(type("S", (), {"rows": [dict(row, **{"class": c})]}), T)
            report(f"the lists count a {c} row of a traced name", other == 1 and out[0].startswith(f"{c} trf "),
                   f"got {other}: {out}")
        T.WRAPPERS = {"trf": "Node.p.<locals>.trf"}
        out, other = lists(type("S", (), {"rows": [dict(row, **{"class": "observer"})]}), T)
        report("control: the same row an observer in WRAPPERS, none counted", other == 0, f"got {other}: {out}")
        follow_self_test(report)
        fail_closed_self_test(report)
    finally:
        for s, v in zip(sets + more, saved + saved_more):
            s.clear()
            s.update(v)
    print("ok: every case as it must be" if not bad else f"{bad} cases wrong")
    return 1 if bad else 0


PINS_HEAD = ["# The code each observer verdict rests on beyond the row's own body, by its source's sha256: written",
             "# by `scan_bindings.py TOYDIR --followed`. check.sh's scope step compares it (`--pins`): after a",
             "# difference, read the row again, then write this file anew."]


def followed(sc):
    """The followed code's listing: each row whose observer verdict, under some document or in some branch, rests on
    code beyond the row's own body (a followed question or traced function, a function or method it calls), and
    every body its observer tests walked, its own among them, by its file or document, its qualified name and its
    source's sha256. A change in one of these bodies, of a kind the test does not read, may leave the row an
    observer that is no longer one; the pin (`pins`) makes the change fail until the row is read again.

    What it can miss: code the test reads for every row alike and does not walk for one. on_want calls
    `e.has(gi.index)`, and the toy's `has` methods are read once for all rows (toy_reads), so a change there that
    the test still takes as a read moves no pinned hash. (One it no longer takes as a read takes `has` out of the
    reads: each row that calls it is then no observer, and the pin names it as no longer such a row.) And the
    statements of a class around a followed `__init__` that are no `def`: on_want's row pins
    `GroupIndex.__init__`, not the class, so an assigned `__setattr__` in its body moves no pin."""
    rows = {}
    for r, bodies in sc.followed:
        key = f"row {r['file']} {r['in']} {r['name']} = {r['value']['qual']} ({r['form']})"
        rows.setdefault(key, {}).update(bodies)
    out = list(PINS_HEAD)
    for key in sorted(rows):
        out.append(key)
        out += [f"  {label} {qual} {sha}" for (label, qual), sha in sorted(rows[key].items())]
    return out


def pins(sc, path):
    """The differences between the followed code's listing and a pinned one, one line each naming its row; and how
    many rows the listing holds."""
    def blocks(lines):
        out, cur = {}, None
        for x in lines:
            if not x or x.startswith("#"):
                continue
            if x.startswith("row "):
                cur = out.setdefault(x, {})
            else:
                label, qual, sha = x.split()
                cur[(label, qual)] = sha
        return out
    now, was = blocks(followed(sc)), blocks(Path(path).read_text().splitlines())
    diffs = []
    for row in sorted(set(now) | set(was)):
        if row not in was:
            diffs.append(f"pins: {row}: its observer verdict rests on code beyond its own body, and it is not pinned")
        elif row not in now:
            diffs.append(f"pins: {row}: pinned, and no longer a row whose observer verdict rests on code beyond it")
        else:
            for k in sorted(set(now[row]) | set(was[row])):
                b = " ".join(k)
                if k not in was[row]:
                    diffs.append(f"pins: {row}: {b} walked, not pinned")
                elif k not in now[row]:
                    diffs.append(f"pins: {row}: {b} pinned, not walked")
                elif now[row][k] != was[row][k]:
                    diffs.append(f"pins: {row}: {b} changed (pinned {was[row][k][:12]}, now {now[row][k][:12]}): "
                                 f"read the row again")
    return diffs, len(now)


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    if not argv or argv[0].startswith("-"):
        print(__doc__, file=sys.stderr)
        return 2
    toy = Path(argv[0]).resolve()
    T, _ = load_names(toy)
    sc = scan(toy)
    if "--json" in argv[1:]:
        for r in sc.rows:
            print(json.dumps(r, sort_keys=True))
    elif "--lists" in argv[1:]:
        out, other = lists(sc, T)
        print("\n".join(out))
        print(f"{other} differences from trace3.py's lists" if other else "the lists as trace3.py's")
        return 1 if other else 0
    elif "--followed" in argv[1:]:
        print("\n".join(followed(sc)))
    elif "--pins" in argv[1:]:
        if argv.index("--pins") + 1 >= len(argv):
            print(__doc__, file=sys.stderr)
            return 2
        f = argv[argv.index("--pins") + 1]
        diffs, n = pins(sc, f)
        print("\n".join(diffs + [f"pins: {len(diffs)} differences from {f}" if diffs
                                 else f"pins: the followed code of {n} rows as pinned"]))
        return 1 if diffs else 0
    else:
        for r in sc.rows:
            print(line(r))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
