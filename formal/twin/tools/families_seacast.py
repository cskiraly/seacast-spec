#!/usr/bin/env python3
"""S1-8b, the replay's reader half: a copy of a directed set's trace under seacast.md with the −1 family in a GRAFT,
a PRUNE and counted's need, written ["-", 1] (signed) or as the plain int (plain, which the replay's strict scan must
refuse), and two planted copies whose replay must fail.

    python3 families_seacast.py signed|plain|argsonly|writekept IN.jsonl.gz OUT.jsonl.gz

send_relation writes no record of its own: its calls fall inside the records of the relation functions. IN's
records of on_graft hold them, by yes() and no(), and each takes the family from the message it receives
(seacastdirected/upkeep_h's do). The copy changes two of them:
- the first record of on_graft that answers with one GRAFT and writes a table keyed by the family;
- the first record of on_graft that answers with one PRUNE.
In each, the received message's family f, of type T, is made −1 at every place it holds by position: the message's
family (args[1], and the sent message of the `send` row); the family argument of the questions in_pushers,
out_pushees and wants_family ([T, f, ...]); the family key [p, T, f, ...] of push_in, push_out, grafted_in,
grafted_out and backoff, in reads, writes, rest, scans and the questions' logs; and an owed GRAFT's or PRUNE's family
in owed_relations. A record that asks `family`, whose answer is a family, is refused: this rule cannot change it.
After the first, a record of counted is put in, at its node and time, written by records_seacast.py's encoders: need
{-1: 2, 3: 0}; a node's record with id 7, families [-1, 3] and high false; the type column; and the return that
counted computes from them, [-1] (the short families the record covers; high false, so no cap). It has no reads,
scans, writes or rest. The trailer counts it.

The modes: signed and plain as above; argsonly, the signed −1 in the two records' args alone (each record's replay
must fail); writekept, signed but the GRAFT's record's writes keyed by the family left at f (its replay must fail on
the state). Every other line is copied as it is. One line on stdout says what was changed, and where.

IN must be a whole run's trace, or the copy would hold a prefix as if it were one. It is refused, with exit 1 and
its words, when its trailer says the run stopped, when its trailer line is not JSON (cut while it was written), when
it has no trailer, when its stream ends before its end marker, and when a line follows its trailer."""
import gzip
import json
import sys
from pathlib import Path
from types import SimpleNamespace as NS

sys.path.insert(0, str(Path(__file__).resolve().parent))
import records_seacast                       # noqa: E402: this directory's

SIGNED, PLAIN = ["-", 1], -1
MODES = ("signed", "plain", "argsonly", "writekept")
KEYED = ("push_in", "push_out", "grafted_in", "grafted_out", "backoff")     # [p, T, family, ...]
QUESTIONS = ("in_pushers", "out_pushees", "wants_family")                  # [T, family, ...]
RELATIONS = ("graft", "prune")


def swap(x, old, new):
    """x with every value equal to old (a list, compared as JSON values compare) replaced by new; the count."""
    if x == old:
        return new, 1
    if isinstance(x, list):
        out, n = [], 0
        for y in x:
            y, k = swap(y, old, new)
            out.append(y)
            n += k
        return out, n
    if isinstance(x, dict):
        out, n = {}, 0
        for key, y in x.items():
            y, k = swap(y, old, new)
            out[key] = y
            n += k
        return out, n
    return x, 0


def answers(r):
    """The kinds of relation message the record's tape sends, in order."""
    return [e[1][1][0] for e in r["tape"] if e[0] == "send" and isinstance(e[1][1], list) and e[1][1]
            and e[1][1][0] in RELATIONS]


def keyed(x, T, f):
    """Whether a logged entry [table, key, ...] is keyed by type T's family f."""
    return (isinstance(x, list) and len(x) >= 2 and x[0] in KEYED and isinstance(x[1], list) and len(x[1]) >= 3
            and x[1][1] == T and x[1][2] == f)


def family_writes(r, T, f):
    return [x for x in r["writes"] if keyed(x, T, f)]


def edit(r, fam, mode):
    """The record's family made fam at its places, as the mode says; the places, in the record's order."""
    m = r["args"][1]
    T, f = m[1], m[2]
    if any(e[0] == "family" for e in r["tape"]):
        raise SystemExit(f"families_seacast: node {r['n']}'s on_graft asks `family`, whose answer this rule cannot "
                         f"change")
    where = []

    def at(place):
        if place not in where:
            where.append(place)
    m[2] = fam
    at("args")
    if mode == "argsonly":
        return T, f, where

    def entry(x, part):
        if keyed(x, T, f):
            x[1][2] = fam
            at(f"{part} {x[0]}")
        if isinstance(x, list) and len(x) >= 3 and x[0] == "owed_relations" and isinstance(x[2], list):
            for o in x[2]:
                if isinstance(o, list) and len(o) >= 3 and o[0] in RELATIONS and o[1] == T and o[2] == f:
                    o[2] = fam
                    at(f"{part} owed_relations")
    for e in r["tape"]:
        if e[0] == "send" and isinstance(e[1][1], list) and e[1][1] and e[1][1][0] in RELATIONS \
                and e[1][1][1] == T and e[1][1][2] == f:
            e[1][1][2] = fam
            at("send")
        if e[0] in QUESTIONS and e[1][0] == T and e[1][1] == f:
            e[1][1] = fam
            at(e[0])
        if len(e) > 3 and isinstance(e[3], dict):
            for k in ("cr", "cw"):
                for x in e[3].get(k) or ():
                    entry(x, f"{e[0]}'s log")
    for part in ("reads", "writes", "rest", "scans"):
        if mode == "writekept" and part == "writes":
            continue
        for x in r.get(part) or ():
            entry(x, part)
    return T, f, where


def counted(n, t, fam):
    """A record of counted at node n and time t, by records_seacast.py's encoders; fam is how −1 is written."""
    tr, _ = records_seacast.stand_in()
    need, rec, T = {-1: 2, 3: 0}, NS(id=7, families=[-1, 3], high=False), NS(id="column", name="column")
    ret = [f for f in rec.families if need[f] > 0]          # counted's own rule (seacast.md), high false
    r = {"n": n, "t": t, "fn": "counted", "args": records_seacast.args_seacast(tr, "counted", (need, rec, T)), "tape": [],
         "reads": [], "scans": [], "writes": [], "rest": [], "ret": records_seacast.ret_seacast(tr, "counted", ret),
         "reached": ["counted"], "tables": []}
    if fam != SIGNED:
        r["args"], _ = swap(r["args"], SIGNED, fam)
        r["ret"], _ = swap(r["ret"], SIGNED, fam)
    return r


def main(argv):
    if len(argv) != 3 or argv[0] not in MODES:
        print("usage: families_seacast.py signed|plain|argsonly|writekept IN.jsonl.gz OUT.jsonl.gz", file=sys.stderr)
        return 2
    mode, src, dst = argv
    fam = PLAIN if mode == "plain" else SIGNED
    want, said, at = ["graft", "prune"], [], []
    whole = "a trace cut short is not a whole run's"
    trailer = False                     # the trailer read: no line may follow it
    with gzip.open(src, "rt") as f, gzip.open(dst, "wt", compresslevel=1) as out:
        k = 0                           # the copy's lines written so far

        def put(s, changed=False):
            nonlocal k
            out.write(s)
            k += 1
            if changed:
                at.append(k)
        try:
            for line in f:
                if trailer:
                    raise SystemExit(f"families_seacast: {src}: a line after the trailer")
                if line.startswith('{"trailer"'):
                    try:
                        tl = json.loads(line)
                    except json.JSONDecodeError:
                        raise SystemExit(f"families_seacast: {src}: the trailer line is cut: {whole}") from None
                    if "stopped" in tl["trailer"]:
                        raise SystemExit(f"families_seacast: {src}: the trailer says the run stopped "
                                         f"({tl['trailer']['stopped']}); a stopped run's records are not a whole run's")
                    if want:
                        raise SystemExit(f"families_seacast: no record of on_graft answered with one "
                                         f"{want[0].upper()}" + (" and writing a table keyed by the family"
                                                                 if want[0] == "graft" else ""))
                    by = dict(tl["trailer"]["by_fn"], counted=tl["trailer"]["by_fn"].get("counted", 0) + 1)
                    tl["trailer"] = dict(tl["trailer"], records=tl["trailer"]["records"] + 1,
                                         by_fn=dict(sorted(by.items())))
                    put(json.dumps(tl, separators=(",", ":")) + "\n")
                    trailer = True
                    continue
                if not want or not line.startswith('{"n":') or '"fn":"on_graft"' not in line:
                    put(line)
                    continue
                r = json.loads(line)
                a = answers(r)
                m = r["args"][1]
                if r["fn"] != "on_graft" or a != [want[0]] \
                        or (want[0] == "graft" and not family_writes(r, m[1], m[2])):
                    put(line)
                    continue
                how = mode if mode != "writekept" else ("writekept" if want[0] == "graft" else "signed")
                T, f0, where = edit(r, fam, how)
                put(json.dumps(r, separators=(",", ":")) + "\n", True)
                said.append(f"node {r['n']}'s on_graft from {r['args'][0]}, answered with a {want[0].upper()}: "
                            f"its family {f0} of {T} made the −1 family at " + ", ".join(where))
                if want[0] == "graft":
                    put(json.dumps(counted(r["n"], r["t"], fam), separators=(",", ":")) + "\n", True)
                    said.append(f"a counted record put in after it, at node {r['n']}")
                want.pop(0)
        except EOFError:
            raise SystemExit(f"families_seacast: {src}: not readable to its end (EOFError): {whole}") from None
    if not trailer:
        raise SystemExit(f"families_seacast: {src}: no trailer: {whole}")
    print(f"families_seacast: {mode}: " + "; ".join(said) + "; the trailer counts the record put in; the copy's lines "
          + ", ".join(map(str, at)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
