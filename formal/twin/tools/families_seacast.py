#!/usr/bin/env python3
"""S1-8b, the replay's reader half: a copy of a v2 trace with the −1 family in a GRAFT, a PRUNE and counted's need,
each where the tracer writes it, written ["-", 1] (signed) or as the plain int (plain, which the replay's strict scan
must refuse). No trace at hand holds a PRUNE or a record of counted, so the copy holds them as the tracer would
have written them, each record consistent with its own arguments and reads.

    python3 families_seacast.py signed|plain IN.jsonl.gz OUT.jsonl.gz

IN holds at least two records of send_relation, each sending a GRAFT (custody-floor-churn1's trace does):
- the first's GRAFT is given the family −1 wherever it is written: its arguments, the `send` row of its tape and
  that row's log, its writes;
- the second's GRAFT is made a PRUNE of the same type, colour and direction, with the family −1, in the same places,
  and the queue's control that holds it a PRUNE's (the document's send_relation sends a PRUNE as it sends a GRAFT,
  on the normal lane);
- after the first, a record of counted is put in, at its node and time, written by records_seacast.py's encoders: need
  {-1: 2, 3: 0}; a node's record with id 7, families [-1, 3] and high false; the type column; and the return that
  counted computes from them, [-1] (the short families the record covers; high false, so no cap). It has no reads,
  scans, writes or rest. The trailer counts it.
Every other line is copied as it is. One line on stdout says what was changed.

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


def places(r, msg):
    """Where a message occurs in a record: the parts that hold it, in the record's order."""
    return [part for part in ("args", "tape", "writes") if swap(r.get(part), msg, None)[1]]


def edit(r, kind, fam):
    """The record's sent message, a GRAFT, given the family fam, and made a PRUNE if kind is "prune": in its
    arguments, its tape and its writes; and the queue's control that holds it, of the same kind. The places."""
    msg = r["args"][1]
    if not (isinstance(msg, list) and len(msg) == 6 and msg[0] == "graft"):
        raise SystemExit(f"families_seacast: the send_relation record at node {r['n']} does not send a GRAFT: {msg!r}")
    new = (["graft", msg[1], fam] + msg[3:]) if kind == "graft" else ["prune", msg[1], fam, msg[3], msg[4]]
    where = places(r, msg)
    if where != ["args", "tape", "writes"]:
        raise SystemExit(f"families_seacast: the GRAFT of node {r['n']}'s send_relation is not in its args, tape and "
                         f"writes alone: {where}")
    for part in ("args", "tape", "writes"):
        r[part], _ = swap(r[part], msg, new)
        if kind == "prune":             # the queue's control: ["graft", [msg]] becomes ["prune", [msg]]
            r[part], _ = swap(r[part], ["graft", [new]], ["prune", [new]])
    if kind == "prune" and swap([r["tape"], r["writes"]], ["graft", [new]], None)[1]:
        raise SystemExit("families_seacast: a GRAFT's control still holds the PRUNE")
    return where


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
    if len(argv) != 3 or argv[0] not in ("signed", "plain"):
        print("usage: families_seacast.py signed|plain IN.jsonl.gz OUT.jsonl.gz", file=sys.stderr)
        return 2
    mode, src, dst = argv
    fam = SIGNED if mode == "signed" else PLAIN
    done, said, at = 0, [], []
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
                    if done != 2:
                        raise SystemExit(f"families_seacast: {done} records of send_relation, not 2 or more")
                    by = dict(tl["trailer"]["by_fn"], counted=tl["trailer"]["by_fn"].get("counted", 0) + 1)
                    tl["trailer"] = dict(tl["trailer"], records=tl["trailer"]["records"] + 1,
                                         by_fn=dict(sorted(by.items())))
                    put(json.dumps(tl, separators=(",", ":")) + "\n")
                    trailer = True
                    continue
                if done >= 2 or not line.startswith('{"n":') or '"fn":"send_relation"' not in line:
                    put(line)
                    continue
                r = json.loads(line)
                if r["fn"] != "send_relation":
                    put(line)
                    continue
                kind = "graft" if done == 0 else "prune"
                edit(r, kind, fam)
                put(json.dumps(r, separators=(",", ":")) + "\n", True)
                said.append(f"node {r['n']}'s send_relation to {r['args'][0]}: a {kind.upper()} of the −1 family")
                if done == 0:
                    put(json.dumps(counted(r["n"], r["t"], fam), separators=(",", ":")) + "\n", True)
                    said.append(f"a counted record put in after it, at node {r['n']}")
                done += 1
        except EOFError:
            raise SystemExit(f"families_seacast: {src}: not readable to its end (EOFError): {whole}") from None
    if not trailer:
        raise SystemExit(f"families_seacast: {src}: no trailer: {whole}")
    print(f"families_seacast: {mode}: " + "; ".join(said) + "; the trailer counts the record put in; the copy's lines "
          + ", ".join(map(str, at)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
