#!/usr/bin/env python3
"""The chain cases: a v2 trace's nodes line against written expectations of the chain rule, case by case.

    python3 chaincases.py TRACE CASE [CASE ...]
    python3 chaincases.py --cut NAME TRACE OUT
    python3 chaincases.py --rows NAME TRACE [FN]

A CASE is `NODE:NAME:replaced|kept:CHAIN`: at node NODE, NAME is in its entry's `replaced` (replaced) or not
(kept), and its `chains` value is CHAIN, the layers' qualified names joined by commas, outermost first, ending in
`doc` where the walk reaches the document's function; or `-`, no key in `chains` (the document's bare function).
NODE may be `*`: every node of the nodes line. A line a case, "as it must" or "NOT: " and each miss's words (under
`*`, where it holds: "at every node (n)", or the nodes, "(k of n)"), then the count; exit 1 on a miss, 2 on a trace
without a nodes line or a case it cannot read.

`--cut`: a plant for the replay. OUT is TRACE with NAME's chain cut to its first layer, the one bound under the name,
in every entry whose chains hold NAME; nothing else changed. It says how many entries; exit 2 where none.

`--rows`: the rows of the question NAME on the records' tapes, by the answer they hold (a row is [NAME, its
arguments, its answer]); with FN, on the tapes of the records whose `reached` holds FN alone.
"""
import gzip
import json
import sys
from collections import Counter


def lines_of(path):
    with gzip.open(path, "rt", encoding="utf-8") as f:
        return f.read().splitlines()


def nodes_at(lines):
    """The index of the nodes line, before any record; or None."""
    for j, line in enumerate(lines):
        d = json.loads(line)
        if "nodes" in d:
            return j
        if "fn" in d:
            break
    return None


def parse(case):
    parts = case.split(":", 3)
    if len(parts) != 4:
        raise ValueError(case)
    node, name, kind, chain = parts
    if kind not in ("replaced", "kept") or not name or not chain or not (node == "*" or node.isdigit()):
        raise ValueError(case)
    return node, name, kind == "replaced", (None if chain == "-" else chain.split(","))


def check(entries, node, name, replaced, chain):
    """The misses of one case at one node, as words (none: it holds)."""
    own = [e for e in entries if node in e["n"]]
    if len(own) != 1:
        return [f"node {node} is in {len(own)} entries"]
    e, why = own[0], []
    if (name in e.get("replaced", [])) != replaced:
        why.append(f"{name} is {'not ' if replaced else ''}in replaced")
    got = e.get("chains", {}).get(name)
    if got != chain:
        why.append(f"its chain is {json.dumps(got)}, not {json.dumps(chain)}")
    return why


def cases(trace, texts):
    lines = lines_of(trace)
    at = nodes_at(lines)
    if at is None:
        print(f"chaincases: no nodes line in {trace}")
        return 2
    entries = json.loads(lines[at])["nodes"]
    try:
        parsed = [parse(c) for c in texts]
    except ValueError as e:
        print(f"chaincases: a case it cannot read: {e}")
        return 2
    every = sorted(n for e in entries for n in e["n"])
    bad = 0
    for (node, name, replaced, chain), text in zip(parsed, texts):
        nodes = every if node == "*" else [int(node)]
        misses = {}                     # a miss's words: the nodes where it holds, in order
        for n in nodes:
            for w in check(entries, n, name, replaced, chain):
                misses.setdefault(w, []).append(n)
        if misses:
            bad += 1

            def where(ns):
                if node != "*":
                    return ""
                if len(ns) == len(nodes):
                    return f" at every node ({len(nodes)})"
                shown = ", ".join(map(str, ns[:5])) + (", …" if len(ns) > 5 else "")
                return f" at node{'s' if len(ns) != 1 else ''} {shown} ({len(ns)} of {len(nodes)})"
            print(f"{text}: NOT: " + "; ".join(w + where(ns) for w, ns in misses.items()))
        else:
            print(f"{text}: as it must ({len(nodes)} node{'s' if len(nodes) != 1 else ''})")
    print(f"{len(parsed) - bad} of {len(parsed)} chain cases as they must be")
    return 1 if bad else 0


def cut(name, trace, out):
    lines = lines_of(trace)
    at = nodes_at(lines)
    if at is None:
        print(f"chaincases: no nodes line in {trace}")
        return 2
    d = json.loads(lines[at])
    k = 0
    for e in d["nodes"]:
        c = e.get("chains", {}).get(name)
        if c:
            e["chains"][name] = c[:1]
            k += 1
    if not k:
        print(f"chaincases: no entry's chains hold {name}")
        return 2
    lines[at] = json.dumps(d, separators=(",", ":"))
    with gzip.open(out, "wt", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"chaincases: the chain of {name} cut to its first layer in {k} entr{'ies' if k != 1 else 'y'}")
    return 0


def rows(name, trace, fn=None):
    answers, recs = Counter(), 0
    with gzip.open(trace, "rt", encoding="utf-8") as f:
        for line in f:
            if not line.startswith('{"n"'):
                continue
            d = json.loads(line)
            if fn is not None and fn not in (d.get("reached") or ()):
                continue
            recs += 1
            for row in d.get("tape") or ():
                if row and row[0] == name:
                    answers[json.dumps(row[-1])] += 1
    on = "the tapes" if fn is None else f"the tapes of the {recs} records that reach {fn}"
    print(f"chaincases: {name} on {on}: {sum(answers.values())} rows"
          + ("" if not answers else " (" + ", ".join(f"{a}: {k}" for a, k in sorted(answers.items())[:4])
                                      + (", …" if len(answers) > 4 else "") + ")"))
    return 0


def main(argv):
    if len(argv) == 4 and argv[0] == "--cut":
        return cut(*argv[1:])
    if len(argv) in (3, 4) and argv[0] == "--rows":
        return rows(*argv[1:])
    if len(argv) < 2 or argv[0].startswith("--"):
        print("usage: " + "; ".join(x.strip() for x in __doc__.strip().splitlines()[2:5]))
        return 2
    return cases(argv[0], argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
