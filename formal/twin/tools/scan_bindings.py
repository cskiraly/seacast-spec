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
- **observer**: it holds the earlier binding of its name (a closure variable assigned from `ns[name]` before it)
  and passes the observer test: its code names no question (CALLS) and no traced function but the earlier binding,
  assigns, deletes or mutates no table nor rebinds a namespace name (following the local functions and node methods
  it calls), and calls the earlier binding once on every path with its own parameters, returning its result, or
  nothing where the document's function returns nothing. `message_id`'s cache is an observer by name (it skips the
  call on a hit).
- **layer**: it holds the earlier binding and fails the test (the reason is given);
- **own**: any other function (a lambda included);
- **value**: anything else (a table, a constant, a class, an expression).
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
    def __init__(self, skip=()):
        self.skip = set(skip)       # forms whose reader is off (the self-test's control)
        self.rows, self.funcs, self.methods = [], [], {}
        self.globals = {}           # (file, name or Class.method) -> Func: the modules' functions and methods
        self.imports = {}           # (file, local name) -> (module file, name), or (module file, None) for a module

    def prepass(self, path):
        """A module's own functions and methods, and its imports of the toy's other modules (path's siblings)."""
        src = path.read_text()
        tree = ast.parse(src)
        mod = Scope(tree, "", None)
        toy = {p.name for p in path.parent.glob("*.py")}
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
                scope.order.append((i, st.name))
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
                scope.order.append((i, st.name))
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
            if isinstance(a, ast.Dict) and "update-dict" not in self.skip:
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
        here = next((i for i, s in enumerate(scope.node.body) if s is st or any(x is st for x in ast.walk(s))), None)
        out = []
        for i, name in scope.order:
            if here is not None and i >= here:
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
                    if isinstance(vv, ast.Subscript) and is_ns(vv.value) and ns_key(vv):
                        scope.captures[tt.id] = ns_key(vv)
                    if isinstance(vv, ast.Lambda):
                        scope.funcs[tt.id] = Func(vv, f"{scope.qual}.<locals>.<lambda>", scope, self.src, self.path)
                        scope.order.append((i, tt.id))
                    if ((isinstance(vv, ast.Call) and isinstance(vv.func, ast.Name) and vv.func.id == "Obj")
                            or (isinstance(vv, ast.Attribute) and vv.attr == "params")):
                        scope.params_objs.add(tt.id)
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
        else:
            r["value"] = {"qual": fn.qual, "file": fn.path.name, "line": fn.line, "sha256": fn.sha}
            self.traced = TRACED_V2 if r["v2_only"] else TRACED     # the traced names where the binding runs
            held = self.held(fn, name)
            if held is None:
                r["class"] = "own"
            else:
                r["holds"] = held
                why = self.observer_test(fn, name, held)
                r["class"] = "observer" if why is None else "layer"
                if why:
                    r["why"] = why
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
    def held(self, fn, name):
        """The closure variable holding the earlier binding of `name`, if the function's code calls one."""
        for n in ast.walk(fn.node):
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name):
                if fn.scope.lookup(n.func.id, "captures") == name:
                    return n.func.id
        return None

    def observer_test(self, fn, name, held):
        if name in BY_NAME:
            return None
        why = self.names_and_writes(fn.node, fn.scope, name, held, seen=set())
        return why or self.calls_once(fn, name, held)

    def names_and_writes(self, node, scope, name, held, seen):
        for n in ast.walk(node):
            if isinstance(n, ast.Subscript) and is_ns(n.value):
                k = ns_key(n)
                if k is not None and k != name and (k in QUESTIONS or k in self.traced):
                    return f"names {'the question' if k in QUESTIONS else 'the traced function'} {k}"
            if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load) and n.id != held:
                k = scope.lookup(n.id, "captures")
                if k is not None and k != name and (k in QUESTIONS or k in self.traced):
                    return f"names {'the question' if k in QUESTIONS else 'the traced function'} {k} (as {n.id})"
            targets = []
            if isinstance(n, (ast.Assign, ast.Delete)):
                targets = n.targets
            elif isinstance(n, (ast.AugAssign, ast.AnnAssign)):
                targets = [n.target]
            for t in targets:
                for tt in (t.elts if isinstance(t, ast.Tuple) else [t]):
                    if self.ns_rooted(tt, scope):
                        return f"writes {ast.unparse(tt)[:60]}"
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr in MUTATORS:
                if self.ns_rooted(n.func.value, scope, bare=True):
                    return f"mutates {ast.unparse(n.func.value)[:60]} by {n.func.attr}"
            # following the local functions and node methods it calls
            if isinstance(n, ast.Call):
                callee = None
                if isinstance(n.func, ast.Name):
                    callee = scope.lookup(n.func.id, "funcs")
                    callee = (callee.node, callee.scope) if callee is not None and not isinstance(callee.node, ast.Lambda) else None
                elif (isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
                      and n.func.value.id in ("self", "node")):
                    m = self.methods.get((self.path.name, "Node", n.func.attr))
                    callee = (m, Scope(m, f"Node.{n.func.attr}", None)) if m is not None else None
                if callee is not None and id(callee[0]) not in seen:
                    seen.add(id(callee[0]))
                    why = self.names_and_writes(callee[0], callee[1], name, held, seen)
                    if why:
                        return f"{why}, in {getattr(callee[0], 'name', '?')}"
        return None

    def ns_rooted(self, e, scope, bare=False):
        """Whether an expression reaches into a namespace name: `ns[...]` itself or anything under it, or anything
        under a closure variable assigned from `ns[...]` that is no function (a captured table). With `bare`, the
        captured variable itself counts too (the receiver of a mutating method)."""
        top = e
        while isinstance(e, (ast.Subscript, ast.Attribute)):
            if isinstance(e, ast.Subscript) and is_ns(e.value):
                return True
            e = e.value
        if isinstance(e, ast.Name) and (bare or e is not top):
            k = scope.lookup(e.id, "captures")
            return k is not None and k not in QUESTIONS | TRACED | CALLABLES
        return False

    def calls_once(self, fn, name, held):
        node = fn.node
        if isinstance(node, ast.Lambda):
            body = [ast.Return(value=node.body)]
        else:
            body = node.body
        sites = [n for n in ast.walk(node) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == held]
        if len(sites) != 1:
            return f"calls {held} {len(sites)} times"
        call = sites[0]
        pos, kwo, var, kw = params_of(node)     # each own parameter passed once, by position or as `k=k`
        given = [a.id if isinstance(a, ast.Name) else None for a in call.args if not isinstance(a, ast.Starred)]
        named = [k.arg for k in call.keywords if k.arg is not None
                 and isinstance(k.value, ast.Name) and k.value.id == k.arg]
        args_ok = (given == pos[:len(given)] and len(named) == len([k for k in call.keywords if k.arg is not None])
                   and sorted(given + named) == sorted(pos + kwo))
        if var is not None:
            args_ok = args_ok and any(isinstance(a, ast.Starred) and isinstance(a.value, ast.Name)
                                      and a.value.id == var.arg for a in call.args)
        if kw is not None:
            args_ok = args_ok and any(k.arg is None and isinstance(k.value, ast.Name) and k.value.id == kw.arg
                                      for k in call.keywords)
        if not args_ok:
            return f"calls {held} with other arguments than its own: {ast.unparse(call)[:60]}"
        top = self.top_statement(body, call)
        if top is None:
            return f"calls {held} on some paths only"
        idx, path = top
        for st in body[:idx]:
            if any(isinstance(n, (ast.Return, ast.Raise)) for n in ast.walk(st)):
                return f"returns or raises before it calls {held}"
        stmt = path[-1]
        returns = [n for st in body for n in self.walk_no_nested(st) if isinstance(n, ast.Return) and n.value is not None]
        if isinstance(stmt, ast.Return) and stmt.value is call:
            return None
        if isinstance(stmt, ast.Assign) and stmt.value is call and len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
            r = stmt.targets[0].id
            later = body[idx + 1:]
            if any(isinstance(n, ast.Name) and n.id == r and isinstance(n.ctx, ast.Store)
                   for st in later for n in ast.walk(st)):
                return f"changes {held}'s result before it returns it"
            if returns and all(isinstance(x.value, ast.Name) and x.value.id == r for x in returns):
                return None
            if not returns and not self.doc_returns(name):
                return None
            return f"does not return {held}'s result"
        if isinstance(stmt, ast.Expr) and stmt.value is call:
            if not returns and not self.doc_returns(name):
                return None
            return f"drops {held}'s result" if self.doc_returns(name) else f"returns a value of its own"
        return f"calls {held} inside {type(stmt).__name__}"

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
    def top_statement(body, call):
        """(index in body, the statements from the top one to the one holding the call) where the call runs on every
        path: reached through the body of a `try` or a `with` only, never a branch, a loop or a handler."""
        for i, st in enumerate(body):
            path = Scanner.find(st, call)
            if path is not None:
                return i, path
        return None

    @staticmethod
    def find(st, call):
        if any(n is call for n in Scanner.own_exprs(st)):
            return [st]
        if isinstance(st, (ast.Try, ast.With)):
            for s in st.body:
                p = Scanner.find(s, call)
                if p is not None:
                    return [st] + p
        return None

    @staticmethod
    def own_exprs(st):
        """The expressions a statement evaluates on every path through it: not its nested statements, and not inside
        a branch of a conditional expression, a short-circuit operand after the first, a comprehension or a lambda."""
        todo = []
        for field, val in ast.iter_fields(st):
            if field in ("body", "orelse", "finalbody", "handlers"):
                continue
            todo += [v for v in (val if isinstance(val, list) else [val]) if isinstance(v, ast.AST)]
        while todo:
            n = todo.pop()
            yield n
            if isinstance(n, ast.IfExp):
                todo.append(n.test)
            elif isinstance(n, ast.BoolOp):
                todo.append(n.values[0])
            elif not isinstance(n, (ast.Lambda, ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
                todo += list(ast.iter_child_nodes(n))

    def doc_returns(self, name):
        """Whether the document's function of that name returns a value (protocol-v2.md's for a v2-only binding is
        not told apart here: both documents' are read, and either returning a value counts)."""
        return name in DOC_RETURNS


QUESTIONS, TRACED, TRACED_V2, CALLABLES, DOC_RETURNS = set(), set(), set(), set(), set()


def load_names(toy):
    """The questions (trace3.py's CALLS), the traced names (BLOCK; under v2 its kept ones, as trace3.py's), the
    documents' functions, and which of them return a value."""
    sys.path.insert(0, str(HERE))
    import trace3 as T                  # noqa: E402
    sys.path.insert(0, str(Path(toy).resolve()))
    import node as N                    # noqa: E402: the pinned toy's
    QUESTIONS.update(T.CALLS)
    TRACED.update(T.BLOCK)
    TRACED_V2.update(n for n in T.v2_kept(T.BLOCK, N.SPEC_SRC, N.generate(N.DOC2)) if n not in T.SEC71)
    for src in (N.SPEC_SRC, N.generate(N.DOC2)):
        for d in ast.parse(src).body:
            if isinstance(d, ast.FunctionDef):
                CALLABLES.add(d.name)
                if any(isinstance(n, ast.Return) and n.value is not None for n in ast.walk(d)):
                    DOC_RETURNS.add(d.name)
    return T, N


def scan(toy, skip=()):
    sc = Scanner(skip)
    files = sorted(Path(toy).glob("*.py"))
    for f in files:                     # every module's own functions and imports first, then the bindings
        sc.prepass(f)
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


def lists(sc, T):
    """The lists the rows give over node.py's bindings of traced names (under v2, of its kept names for a v2-only
    binding), beside trace3.py's hand-kept ones: each name and qualified name the same, or the difference named."""
    rows = [r for r in sc.rows if r["file"] == "node.py" and r["name"] in (TRACED_V2 if r["v2_only"] else TRACED)]
    defined = CALLABLES
    obs = sorted({(r["name"], r["value"]["qual"]) for r in rows if r["class"] == "observer"})
    own = sorted({(r["name"], r["value"]["qual"]) for r in rows if r["class"] == "own" and r["name"] not in defined})
    repl = sorted({r["name"] for r in rows if r["class"] in ("own", "layer") and r["name"] in defined})
    out, other = [], 0
    hand_obs = sorted(T.WRAPPERS.items())
    for x in obs:
        if x in hand_obs:
            out.append(f"observer {x[0]} {x[1]}: as WRAPPERS")
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
    for n in repl:
        if n not in T.REPLACEABLE:
            sites = [f"{r['in']}:{r['line']}{' v2-only' if r['v2_only'] else ''}" for r in rows
                     if r["name"] == n and r["class"] in ("own", "layer")]
            out.append(f"replaced {n}, not REPLACEABLE (the tracer stops a trace where it is replaced): {', '.join(sites)}")
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


def self_test():
    bad = 0
    QUESTIONS.clear(); TRACED.clear()
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "planted.py"
        p.write_text(PLANTED)
        sc = scan(d)
        for form, (name, ln, cls) in WANT.items():
            got = [r for r in sc.rows if r["form"] == form and r["name"] == name and r["line"] == ln]
            ok = len(got) == 1 and got[0]["class"] == cls
            bad += not ok
            print(f"scan_bindings self-test, the form {form}: {name} at line {ln}, {cls}: "
                  f"{'ok' if ok else f'got {[line(r) for r in got]}  <-- FAIL'}")
        for form, (name, ln, cls) in WANT.items():      # the control: each form's reader off, its row missing
            off = scan(d, skip=(form,))
            gone = not [r for r in off.rows if r["form"] == form and r["name"] == name and r["line"] == ln]
            bad += not gone
            print(f"scan_bindings self-test, control: the reader of {form} off, its planted row "
                  f"{'missing, as it must be' if gone else 'still reported  <-- FAIL'}")
        before = {(r["form"], r["name"], r["line"]): r["value"]["sha256"] for r in sc.rows if isinstance(r["value"], dict)}
        p.write_text(PLANTED.replace("            return doc_a(x)\n", "            x = x\n            return doc_a(x)\n"))
        sc2 = scan(d)
        after = {(r["form"], r["name"], r["line"] - (1 if r["line"] > 6 else 0)): r["value"]["sha256"]
                 for r in sc2.rows if isinstance(r["value"], dict)}
        moved = sorted(k for k in before if after.get(k) != before[k])
        ok = moved == [("subscript", "a", 7)]
        bad += not ok
        print(f"scan_bindings self-test, a changed observer body: {'its row alone moved' if ok else f'moved {moved}  <-- FAIL'}")
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
