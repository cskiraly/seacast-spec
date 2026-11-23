#!/usr/bin/env python3
"""The chain cases: a v2 trace's nodes line against written expectations of the chain rule, case by case.

    python3 chaincases.py TRACE CASE [CASE ...]
    python3 chaincases.py --cut NAME TRACE OUT
    python3 chaincases.py --rows NAME TRACE [FN]
    python3 chaincases.py --drop-arg NAME TRACE OUT
    python3 chaincases.py --flipped NAME TRACE REPORT

A CASE is `NODE:NAME:replaced|kept:CHAIN`: at node NODE, NAME is in its entry's `replaced` (replaced) or not
(kept), and its `chains` value is CHAIN, the layers' qualified names joined by commas, outermost first, ending in
`doc` where the walk reaches the document's function; or `-`, no key in `chains` (the document's bare function).
NODE may be `*`: every node of the nodes line. A line a case, "as it must" or "NOT: " and each miss's words (under
`*`, where it holds: "at every node (n)", or the nodes, "(k of n)"), then the count; exit 1 on a miss, 2 on a trace
without a nodes line or a case it cannot read.

`--cut`: a plant for the replay. OUT is TRACE with NAME's chain cut to its first layer, the one bound under the name,
in every entry whose chains hold NAME; nothing else changed. It says how many entries; exit 2 where none.

`--rows`: the rows of the question NAME on the records' tapes, by the answer they hold (a row is [NAME, its
arguments, its answer], and a fourth member, the question's log, where it touched the node's tables); with FN, on
the tapes of the records whose `reached` holds FN alone. Then by the record's node, with the nodes whose group in the
nodes line replaces NAME: how many, how many of them have rows, and the rows at any other node.

`--drop-arg`: a plant for the replay (R3-9). OUT is TRACE with the last argument of each row of the question NAME on
the records' tapes left out, and nothing else changed: a record line without such a row is written as it was read,
and one with it is written again in the tracer's form (compact JSON). It says how many rows in how many records;
exit 2 where none, or where a row has no argument to leave out.

`--flipped`: the records of TRACE that hold a row of the question NAME on their tapes, against the records that
REPORT, a replay's report of another trace of the same run, names in its `example:` lines. Each record is (node,
function, its arguments as compact JSON); the record's time is left out. One line: the two counts, and "the same"
or the records in one and not the other. Exit 0 where the two sets are equal and not empty, 1 where they differ, 2
where REPORT has more than 20 example lines (the replay names only its first 20 records and each reason's first) or
an example line it cannot read.
"""
import re
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
    answers, recs, by, replacing = Counter(), 0, Counter(), set()
    with gzip.open(trace, "rt", encoding="utf-8") as f:
        for line in f:
            if line.startswith('{"nodes"'):     # the nodes line: the nodes whose group replaces the name
                replacing |= {n for g in json.loads(line)["nodes"] if name in (g.get("replaced") or ())
                              for n in g["n"]}
                continue
            if not line.startswith('{"n"'):
                continue
            d = json.loads(line)
            if fn is not None and fn not in (d.get("reached") or ()):
                continue
            recs += 1
            for row in d.get("tape") or ():
                if row and row[0] == name:
                    answers[json.dumps(row[2])] += 1
                    by[d["n"]] += 1
    on = "the tapes" if fn is None else f"the tapes of the {recs} records that reach {fn}"
    print(f"chaincases: {name} on {on}: {sum(answers.values())} rows"
          + ("" if not answers else " (" + ", ".join(f"{a}: {k}" for a, k in sorted(answers.items())[:4])
                                      + (", …" if len(answers) > 4 else "") + ")")
          + f"; by node {{{', '.join(f'{n}: {k}' for n, k in sorted(by.items()))}}}; nodes replacing it: "
            f"{len(replacing)}, with rows: {len(replacing & set(by))}; rows at other nodes: "
            f"{sum(k for n, k in by.items() if n not in replacing)}")
    return 0


def drop_arg(name, trace, out):
    lines = lines_of(trace)
    k = recs = 0
    for j, line in enumerate(lines):
        if not line.startswith('{"n"'):
            continue
        d = json.loads(line)
        rows = [row for row in d.get("tape") or () if row and row[0] == name]
        if not rows:
            continue
        for row in rows:
            if not isinstance(row[1], list) or not row[1]:
                print(f"chaincases: a {name} row with no argument to leave out, in record line {j + 1}")
                return 2
            row[1] = row[1][:-1]
        k += len(rows)
        recs += 1
        lines[j] = json.dumps(d, separators=(",", ":"))
    if not k:
        print(f"chaincases: no {name} row on the tapes")
        return 2
    with gzip.open(out, "wt", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"chaincases: the last argument of {name} left out in {k} row{'s' if k != 1 else ''}, "
          f"in {recs} record{'s' if recs != 1 else ''}")
    return 0


EXAMPLE = re.compile(r"^example: node (\d+) at \S+ ([A-Za-z_][A-Za-z0-9_]*)(\[.*?\]): ")


def flipped(name, trace, report):
    on_tapes = set()
    with gzip.open(trace, "rt", encoding="utf-8") as f:
        for line in f:
            if not line.startswith('{"n"'):
                continue
            d = json.loads(line)
            if any(row and row[0] == name for row in d.get("tape") or ()):
                on_tapes.add((d["n"], d["fn"], json.dumps(d["args"], separators=(",", ":"))))
    named = set()
    with open(report, encoding="utf-8") as f:
        examples = [line.rstrip("\n") for line in f if line.startswith("example: ")]
    if len(examples) > 20:
        print(f"chaincases: {len(examples)} example lines: the replay names only its first 20 records")
        return 2
    for line in examples:
        m = EXAMPLE.match(line)
        if m is None:
            print(f"chaincases: an example line not read: {line[:120]}")
            return 2
        named.add((int(m.group(1)), m.group(2), m.group(3)))
    same = on_tapes == named and bool(on_tapes)
    show = lambda xs: ", ".join(f"node {n} {fn}{a}"[:100] for n, fn, a in sorted(xs)[:3])   # noqa: E731
    print(f"chaincases: {name}: {len(on_tapes)} record{'s' if len(on_tapes) != 1 else ''} with its rows on the "
          f"tapes, {len(named)} named by the report's examples: "
          + ("the same" if same else f"not the same (on the tapes only: {show(on_tapes - named) or 'none'}; "
                                     f"in the examples only: {show(named - on_tapes) or 'none'})"))
    return 0 if same else 1


def main(argv):
    if len(argv) == 4 and argv[0] == "--flipped":
        return flipped(*argv[1:])
    if len(argv) == 4 and argv[0] == "--cut":
        return cut(*argv[1:])
    if len(argv) == 4 and argv[0] == "--drop-arg":
        return drop_arg(*argv[1:])
    if len(argv) in (3, 4) and argv[0] == "--rows":
        return rows(*argv[1:])
    if len(argv) < 2 or argv[0].startswith("--"):
        print("usage: " + "; ".join(x.strip() for x in __doc__.strip().splitlines()[2:7]))
        return 2
    return cases(argv[0], argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
