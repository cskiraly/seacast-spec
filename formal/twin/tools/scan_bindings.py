#!/usr/bin/env python3
"""The toy's bindings of namespace names, read from its source: one row per binding, with its class.

    python3 scan_bindings.py TOYDIR             the rows, one per line
    python3 scan_bindings.py TOYDIR --json      the rows as JSON lines, each with its bound function's source hash
    python3 scan_bindings.py TOYDIR --lists     the lists the rows give, beside trace3.py's hand-kept ones
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
  a node attribute so assigned, `self._doc_x = ns["x"]`) and passes the observer test: its code names no question
  (trace3.py's TAPE, and protocol-v2.md's: the names its functions call that no document defines and that the toy
  binds under v2 alone) and no traced function but the earlier binding; it assigns, deletes or mutates no table,
  through its own aliases too, following the local functions, lambdas and node methods it calls with the tables it
  hands them; on a table, or on what a table's method returns, it calls only the methods that read it, and it hands
  a table to no call the test cannot follow (a builtin but those that only read, `len`, `sorted`, ...); the functions
  and lambdas made inside it are read as its own code; it rebinds no namespace name (a scalar too: a layer
  that changes a node constant around the call, as the peer promise's `filter_entry` sets PROMISE, is a changing
  layer); and it calls the earlier binding once on every path (branches, `try`, `with`, loops walked; a statement
  the walk does not follow, `match` among them, holds no call and no return; a `try`'s `else` with handlers neither),
  never in a function made inside it, the earlier binding's name bound nowhere in its body,
  with its own parameters unchanged (a handler's, a pattern's or a walrus's name counts) and nothing more, returning
  its result, or nothing where the document's function returns nothing (a least fixpoint over both documents:
  `return f(...)` of a function that returns nothing returns nothing). `message_id`'s cache is an observer by name
  (it skips the call on a hit). What the test cannot establish is not an observer: an unknown effect denies.
- **layer**: it holds the earlier binding and fails the test (the reason is given);
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
A binding in a method that `Node.__init__` calls only under `if self.v2` (and in what such a method calls), or inside
such a branch of `__init__`, is marked v2-only: under protocol.md it never runs.
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
# the methods that only read a table (a dict, a set, a list, a deque): any other call on a table, or on what one of
# its methods returns, is one the test cannot establish as a read, and denies
READONLY_METHODS = {"get", "keys", "values", "items", "copy", "count", "index", "issubset", "issuperset", "isdisjoint",
                    "union", "intersection", "difference", "symmetric_difference", "__contains__", "__len__",
                    "__iter__", "__getitem__"}
# the builtins that only read what they are handed: any other builtin handed a table denies (setattr, map, ...)
READONLY_BUILTINS = {"len", "list", "tuple", "set", "frozenset", "dict", "sorted", "reversed", "iter", "next",
                     "enumerate", "zip", "sum", "min", "max", "any", "all", "isinstance", "bool", "int", "float", "str",
                     "repr", "hash", "id", "type", "abs", "round", "range", "callable", "bytes", "hasattr"}
# the toy's own methods taken as reads (a bitmap's `has`), each only where the scan finds that every definition of
# that name in the toy's classes only reads: no field or element assigned or deleted, and no call but these reads,
# the methods above and the builtins above (`Scanner.toy_reads`); else it is no read
TOY_READS = {"has"}
BY_NAME = {"message_id": "a cache: it skips the call on a hit"}     # observers by name


def is_ns(e):
    return (isinstance(e, ast.Name) and e.id == "ns") or (isinstance(e, ast.Attribute) and e.attr == "ns")


def ns_key(e):
    """For `ns[...]`: the literal key, or None for a computed one."""
    k = e.slice
    return k.value if isinstance(k, ast.Constant) and isinstance(k.value, str) else None


def first_line(fn):
    """The line Python gives the function's code (co_firstlineno): the first decorator's, else the def's."""
    return min([d.lineno for d in getattr(fn, "decorator_list", ())] + [fn.lineno])


class Func:
    """A function the toy defines: its node, qualified name, the scope it is made in and its source's hash."""
    def __init__(self, node, qual, scope, src, path):
        self.node, self.qual, self.scope, self.path = node, qual, scope, path
        self.line = first_line(node)
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

    def lookup(self, name, attr):
        s = self
        while s is not None:
            d = getattr(s, attr)
            if name in d:
                return d[name]
            s = s.parent
        return None

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
        self.globals = {}           # (file, name or Class.method) -> Func: the modules' functions and methods
        self.imports = {}           # (file, local name) -> (module file, name), or (module file, None) for a module

    def prepass(self, path):
        """A module's own functions and methods, and its imports of the toy's other modules (path's siblings)."""
        src = path.read_text()
        tree = ast.parse(src)
        mod = Scope(tree, "", None)
        toy = {p.name for p in path.parent.glob("*.py")}
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
                self.globals[(path.name, st.name)] = Func(st, st.name, mod, src, path)
            elif isinstance(st, ast.ClassDef):
                for m in st.body:
                    if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        q = f"{st.name}.{m.name}"
                        self.globals[(path.name, q)] = Func(m, q, Scope(st, st.name, mod), src, path)
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
        self.src, self.path = src, path
        for cls in tree.body:       # a class's methods by name, for the observer test's call following
            if isinstance(cls, ast.ClassDef):
                for m in cls.body:
                    if isinstance(m, ast.FunctionDef):
                        self.methods[(path.name, cls.name, m.name)] = m
        self.v2_methods, self.v2_lines = self.v2_only(tree)
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
                    elif isinstance(vv, (ast.Name, ast.Attribute)) and self.resolve(vv, scope) is not None:
                        scope.funcs[tt.id] = self.resolve(vv, scope)    # another name of a function (x = topic_peers)
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
        r["v2_only"] = self.in_v2(scope, at.lineno)
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
                docs = ("v2",) if r["v2_only"] else ("protocol.md", "v2")     # the documents it runs under
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
                    else:                   # an observer under one, not the other
                        r["class"] = "per-document"
                        r["by_document"] = {d: "observer" if w is None else f"layer ({w})" for d, w in by.items()}
        self.rows.append(r)

    def in_v2(self, scope, line):
        s = scope
        while s is not None and not isinstance(s.node, ast.ClassDef):
            if isinstance(s.node, ast.FunctionDef) and s.parent is not None and isinstance(s.parent.node, ast.ClassDef):
                if s.node.name in self.v2_methods:
                    return True
                if s.node.name == "__init__":
                    return any(a <= line <= b for a, b in self.v2_lines)
            s = s.parent
        return False

    @staticmethod
    def v2_only(tree):
        """The methods `Node.__init__` calls only under `if self.v2`, with what they call; and those branches'
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
            if (isinstance(st, ast.If) and isinstance(st.test, ast.Attribute) and st.test.attr == "v2"
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
               "branch", "arguments", "result", "rebind", "by-name")

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
        return s

    def observer_test(self, fn, name, held, doc):
        """None for an observer, or why it is not one, under one document's namespace ("protocol.md" or "v2": its
        questions, its traced names, and whether its function of that name returns a value)."""
        if name in BY_NAME and "by-name" not in self.off:
            return None
        self.questions = QUESTIONS_V2 if doc == "v2" else QUESTIONS_DOC
        self.traced = TRACED_V2 if doc == "v2" else TRACED
        if doc == "v2":                     # v2's namespace: its own function of the name, else protocol.md's
            self.returns = RETURNS_V2 if name in DEFS_V2 else RETURNS_DOC
        else:
            self.returns = RETURNS_DOC if name in DEFS_DOC else RETURNS_V2
        own = self.own_scope(fn.node, fn.qual, fn.scope)
        return self.names_and_writes(fn.node, own, name, held, set()) or self.paths(fn.node, own, name, held)

    def table_arg(self, call, scope):
        return next((a for a in list(call.args) + [k.value for k in call.keywords]
                     if self.ns_rooted(a, scope, bare=True)), None)

    def names_and_writes(self, node, scope, name, held, seen):
        """Why the code names a question or a traced function, or writes, deletes or mutates a table, following the
        local functions and node methods it calls (with the tables it hands them); or None. The functions and lambdas
        defined inside it are read as its own code, whether or not they run: a closure needs no argument to reach a
        table."""
        for n in ast.walk(node):
            k = None
            if isinstance(n, ast.Subscript) and is_ns(n.value):
                k = ns_key(n)
            elif isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load) and n.id != held:
                k = scope.lookup(n.id, "captures")
            if k is not None and k != name:
                if k in self.questions and "question" not in self.off:
                    return f"names the question {k}"
                if k in self.traced and "traced" not in self.off:
                    return f"names the traced function {k}"
            targets = []
            if isinstance(n, (ast.Assign, ast.Delete)):
                targets = n.targets
            elif isinstance(n, (ast.AugAssign, ast.AnnAssign)):
                targets = [n.target]
            for t in targets:
                for tt in (t.elts if isinstance(t, ast.Tuple) else [t]):
                    clause = "delete" if isinstance(n, ast.Delete) else "assign"
                    if clause not in self.off and self.ns_rooted(tt, scope):
                        return f"{'deletes' if clause == 'delete' else 'writes'} {ast.unparse(tt)[:60]}"
            if not isinstance(n, ast.Call):
                continue
            if isinstance(n.func, ast.Attribute) and n.func.attr in MUTATORS and "mutate" not in self.off:
                if self.ns_rooted(n.func.value, scope, bare=True):
                    return f"mutates {ast.unparse(n.func.value)[:60]} by {n.func.attr}"
            if (isinstance(n.func, ast.Attribute) and n.func.attr not in MUTATORS | self.reads
                    and "mutate" not in self.off and self.ns_rooted(n.func.value, scope, bare=True)):
                return (f"calls {n.func.attr} on {ast.unparse(n.func.value)[:60]}, which the test does not establish "
                        f"as a read")
            if self.is_held(n, held):
                continue
            callee, clause = None, None
            if isinstance(n.func, ast.Name):
                f = scope.lookup(n.func.id, "funcs")
                if f is not None:       # a local function or lambda, followed
                    callee, clause = (f.node, f.scope, f.qual), "local-fn"
                elif f is None and scope.lookup(n.func.id, "captures") is not None:
                    continue            # a namespace function (named, and so checked, above)
                elif f is None and n.func.id in READONLY_BUILTINS:
                    continue            # a builtin that only reads (any other is unfollowed, below)
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
                key = (id(callee[0]), frozenset(tables))
                if key in seen:
                    continue
                seen.add(key)
                inner = self.own_scope(callee[0], callee[2], callee[1], tables)
                why = self.names_and_writes(callee[0], inner, name, held, seen)
                if why:
                    return f"{why}, in {getattr(callee[0], 'name', '?')}"
            elif "unfollowed" not in self.off:
                a = self.table_arg(n, scope)
                if a is not None:
                    return f"hands {ast.unparse(a)[:40]} to {ast.unparse(n.func)[:40]}, which the test does not follow"
        return None

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
                    break               # a function's result: not a table's
                e = e.func.value
            else:
                e = e.value
        if isinstance(e, ast.Name) and (bare or e is not top):
            k = scope.lookup(e.id, "captures")
            return k is not None and k not in self.questions | self.traced | CALLABLES
        return bare and isinstance(top, ast.Subscript) and is_ns(top.value)

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


QUESTIONS_DOC, QUESTIONS_V2, TRACED, TRACED_V2, CALLABLES = set(), set(), set(), set(), set()
DEFS_DOC, DEFS_V2, RETURNS_DOC, RETURNS_V2 = set(), set(), set(), set()
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
    the questions the environment answers (protocol-v2.md's `type_of_group`, `send`, `choice`, ...)."""
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
    """The questions (trace3.py's TAPE, and protocol-v2.md's calls of names no document defines), the traced names
    (BLOCK; under v2 its kept ones, as trace3.py's), the documents' functions, and which of them return a value."""
    sys.path.insert(0, str(HERE))
    import trace3 as T                  # noqa: E402
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    doc = {d.name: d for d in ast.parse(N.SPEC_SRC).body if isinstance(d, ast.FunctionDef)}
    v2 = {d.name: d for d in ast.parse(N.generate(N.DOC2)).body if isinstance(d, ast.FunctionDef)}
    DEFS_DOC.update(doc)
    DEFS_V2.update(v2)
    CALLABLES.update(doc, v2)
    RETURNS_DOC.update(returning(doc))
    RETURNS_V2.update(returning({**doc, **v2}))
    QUESTIONS_DOC.update(T.TAPE)
    QUESTIONS_V2.update(T.TAPE)
    # protocol-v2.md's questions: the names its functions call that no document defines, and that the toy binds in
    # code that runs under v2 alone (type_of_group, send, choice); the toy's helpers bound for both documents (group,
    # group_index) are computed in place, as under protocol.md, and are no questions. Provisional until the twin's
    # question registry for v2 is read
    v2_bound = {r["name"] for r in scan(toy).rows if r["v2_only"]}
    QUESTIONS_V2.update(questions_of(v2, set(doc) | set(v2)) & v2_bound)
    TRACED.update(T.BLOCK)
    TRACED_V2.update(n for n in T.v2_kept(T.BLOCK, N.SPEC_SRC, N.generate(N.DOC2)) if n not in T.SEC71)
    return T, N


def scan(toy, skip=(), off=()):
    sc = Scanner(skip, off)
    files = sorted(Path(toy).glob("*.py"))
    for f in files:                     # every module's own functions and imports first, then the bindings
        sc.prepass(f)
    sc.reads = READONLY_METHODS | sc.toy_reads()
    for f in files:
        sc.scan_file(f)
    return sc


def line(r):
    v = r["value"]
    val = f"{v['qual']}@{v['line']} {v['sha256'][:12]}" if isinstance(v, dict) else repr(v)
    extra = f" holds {r['holds']}" if "holds" in r else ""
    why = f" ({r['why']})" if "why" in r else ""
    return (f"{r['file']}:{r['line']} {r['in']} {r['form']}{'/' + r['via'] if 'via' in r else ''} {r['name']} = "
            f"{val}{extra} {r['class']}{why}{' v2-only' if r['v2_only'] else ''}")


def fn_key(v):
    """A function value's key in trace3.py's LAYERS: its file's name, its qualified name and its first line."""
    return v["file"], v["qual"], v["line"]


def at(fl, q, ln):
    """A LAYERS key as the lines name it: qualified name@line in node.py, the file named only for another."""
    return f"{q}@{ln}" if fl == "node.py" else f"{q}@{fl}:{ln}"


def lists(sc, T):
    """The lists the rows give over node.py's bindings of traced names (under v2, of its kept names for a v2-only
    binding), beside trace3.py's hand-kept ones: each name and qualified name the same, or the difference named."""
    rows = [r for r in sc.rows if r["file"] == "node.py" and r["name"] in (TRACED_V2 if r["v2_only"] else TRACED)]
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
    v2_obs = {(r["name"], r["value"]["qual"]) for r in rows     # qualified name and first line, with their kinds
              if layers is not None and r["v2_only"] and r["class"] == "observer"
              and layers.get(fn_key(r["value"])) == (r["name"], T.OBSERVER)}
    for x in obs:
        if x in hand_obs:
            out.append(f"observer {x[0]} {x[1]}: as WRAPPERS")
        elif x in v2_obs:
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
            sites = [f"{r['in']}:{r['line']}{' v2-only' if r['v2_only'] else ''}" for r in rows
                     if r["name"] == n and r["class"] in ("own", "layer")]
            out.append(f"replaced {n}, not REPLACEABLE (the tracer stops a trace where it is replaced): {', '.join(sites)}")
    if layers is not None:  # LAYERS against every node.py binding of a name traced under v2, function by function:
        kind = {"observer": T.OBSERVER, "own": T.CHANGING, "layer": T.CHANGING}     # an observer; the node's own
        want = {}                                                                   #   helper; any other is changing
        for r in sc.rows:
            if r["file"] != "node.py" or r["name"] not in TRACED_V2 or not isinstance(r["value"], dict):
                continue
            k = T.NODE_HELPER if r["class"] == "own" and r["name"] not in defined else kind.get(r["class"])
            if k is not None:           # a class of more than one kind is named above
                want[fn_key(r["value"])] = (r["name"], k)
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
        d_finally, d_handler, d_with, d_effect, d_v2q = ns["c_finally"], ns["c_handler"], ns["c_with"], ns["c_effect"], ns["c_v2q"]
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

        def c_v2q(x):
            ns["v2q"](x)
            return d_v2q(x)

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
                  c_handler=c_handler, c_with=c_with, c_effect=c_effect, c_v2q=c_v2q, c_put=c_put,
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
            ns["v2q"](x)
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
    sets = (QUESTIONS_DOC, QUESTIONS_V2, TRACED, TRACED_V2, DEFS_DOC, RETURNS_DOC)
    saved = [set(s) for s in sets]
    names = set(BREAKS) | set(PASSES) | set(NOT_SPLIT) | {"c_closed", "c_v2q", "c_doc"}
    for s, v in zip(sets, ({"askq"}, {"askq", "v2q"}, {"trf"}, {"trf"}, names,
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
            got = [r for r in rows if r["name"] == "c_v2q"]
            ok = (len(got) == 1 and got[0]["class"] == "per-document"
                  and got[0]["by_document"]["protocol.md"] == "observer"
                  and got[0]["by_document"]["v2"].startswith("layer"))
            report("c_v2q per document: an observer under protocol.md, a layer under v2 (a v2 question)", ok,
                   f"got {[(r['class'], r.get('by_document')) for r in got]}")
            got = [r for r in rows if r["name"] == "c_closed"]
            ok = (len(got) == 1 and got[0]["class"] == "closure-dependent"
                  and got[0]["closure"] == {"on": "not on", "true": "own", "false": "observer"})
            report("c_closed closure-dependent: own where `not on`, an observer where not", ok,
                   f"got {[(r['class'], r.get('closure')) for r in got]}")
            got = [r for r in rows if r["name"] == "c_doc"]
            ok = (len(got) == 1 and got[0]["class"] == "closure-dependent"
                  and got[0]["closure"] == {"on": "not on", "true": "own",
                                            "false": {"protocol.md": "observer", "v2": "layer"}})
            report("c_doc closure-dependent, its branches per document: own where `not on`; where not, an observer "
                   "under protocol.md and a layer under v2 (a v2 question)", ok,
                   f"got {[(r['class'], r.get('closure')) for r in got]}")
        # the lists count a row of a traced name that has no one class; the control, the same row an observer
        # in WRAPPERS, counts none
        T = type("T", (), {"WRAPPERS": {}, "NODE_OWN": {}, "REPLACEABLE": (), "REPLACEABLE_WHOLE": ()})
        row = {"file": "node.py", "line": 5, "in": "Node.p", "form": "subscript", "name": "trf", "v2_only": False,
               "value": {"qual": "Node.p.<locals>.trf", "file": "node.py", "line": 6, "sha256": "0" * 64}}
        for c in ("closure-dependent", "per-document"):
            out, other = lists(type("S", (), {"rows": [dict(row, **{"class": c})]}), T)
            report(f"the lists count a {c} row of a traced name", other == 1 and out[0].startswith(f"{c} trf "),
                   f"got {other}: {out}")
        T.WRAPPERS = {"trf": "Node.p.<locals>.trf"}
        out, other = lists(type("S", (), {"rows": [dict(row, **{"class": "observer"})]}), T)
        report("control: the same row an observer in WRAPPERS, none counted", other == 0, f"got {other}: {out}")
    finally:
        for s, v in zip(sets, saved):
            s.clear()
            s.update(v)
    print("ok: every case as it must be" if not bad else f"{bad} cases wrong")
    return 1 if bad else 0


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
    else:
        for r in sc.rows:
            print(line(r))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
