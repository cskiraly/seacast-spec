#!/usr/bin/env python3
"""The calls summary of one v2 trace: its `reached` names, the IWANTs that respond, retry_offer and ask_parked enqueue,
counted by their records and by their calls, and three controls of the calls file trace3.py writes beside the trace.

    python3 -I calls_seacast.py [--any] OUT REL        (REL: a trace under OUT, without .jsonl.gz: seacast/hand5, chains/X)

It reads OUT/REL.jsonl.gz, OUT/REL.jsonl.gz.calls.json and, where there is one, the replay's report OUT/REL.replay.
It prints four lines, or one line `skipped: REL: WHY` for a plant (plant-*), a copy (fam-*), a trace under another
document, a trace with no trailer (a run that stopped) or one with no calls file. --any reads a plant or a copy too.

1. `REL (format F, doc D): R records; reached: NAME n, ...`: every name in a record's `reached`, with the records
   that hold it (a record's own fn among them).
2. `REL: respond R records, I with an IWANT; retry_offer X records, Y IWANTs enqueued (asks {...}); ask_parked Z
   records, W IWANTs enqueued`: by the records of each name, from their tapes. An IWANT is a list whose first member
   is "iwant" and whose second is a list (its asks), anywhere in an `enqueue` tape row's arguments.
3. `REL: calls: NAME T (record r, in {HOST: n}, bare b, ext e, observer o), I with an IWANT, Y IWANTs enqueued (asks
   {...}); ...; one inside another: {...}`: by the calls of each name, from the calls file. T is the sum of the five,
   and I and Y count the calls in a record of its own and those inside another.
4. `REL: controls: ...`, which hold, or NOT with the first ones that fail:
   - K4a: each name's records in the calls file are the trailer's (raises included) and the replay's fn line's;
   - reach: for each record fn F and name X other than F, X's calls inside F's records are at least the records of F
     whose `reached` holds X, and none where none does: the trace's `reached` against the calls file;
   - by-fn: the record half of the calls file's IWANT counts is line 2's.
Exit 0 when the controls hold or the trace is skipped, 1 when one fails, 2 on a usage error.
"""
import gzip
import json
import re
import sys
from collections import Counter
from pathlib import Path

FNS = ("respond", "retry_offer", "ask_parked")


def iwants(x):
    """The asks' counts of the IWANTs in x, a JSON value."""
    if isinstance(x, list):
        if x and x[0] == "iwant" and len(x) >= 2 and isinstance(x[1], list):
            return [len(x[1])] + [n for y in x[2:] for n in iwants(y)]
        return [n for y in x for n in iwants(y)]
    if isinstance(x, dict):
        return [n for y in x.values() for n in iwants(y)]
    return []


def enqueued(rec):
    """The asks' counts of the IWANTs a record's enqueue rows carry."""
    return [n for t in rec.get("tape", []) if isinstance(t, list) and len(t) >= 2 and t[0] == "enqueue"
            for n in iwants(t[1])]


def doc_of(args):
    for j, a in enumerate(args):
        if a == "--doc" and j + 1 < len(args):
            return args[j + 1]
    return "seacast-lite.md"


def main(argv):
    anyname = argv[:1] == ["--any"]
    if anyname:
        argv = argv[1:]
    if len(argv) != 2:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    out, rel = Path(argv[0]), argv[1]
    base = rel.rsplit("/", 1)[-1]
    if not anyname and base.startswith("plant-"):
        print(f"skipped: {rel}: a plant")
        return 0
    if not anyname and base.startswith("fam-"):
        print(f"skipped: {rel}: a copy (families_seacast.py)")
        return 0
    trace = out / f"{rel}.jsonl.gz"
    side = out / f"{rel}.jsonl.gz.calls.json"
    header = trailer = None
    n = 0
    reached, fns, reach = Counter(), Counter(), Counter()
    resp_iwant, retry, parked = 0, [], []
    try:
        f = gzip.open(trace, "rt")
        for line in f:
            r = json.loads(line)
            if not isinstance(r, dict):
                continue
            if "header" in r:
                header = r["header"]
                continue
            if "trailer" in r:
                trailer = r["trailer"]
                continue
            if "fn" not in r:
                continue
            n += 1
            fn = r["fn"]
            fns[fn] += 1
            for x in r.get("reached", []):
                reached[x] += 1
                if x != fn:
                    reach[(fn, x)] += 1
            if fn in FNS:
                e = enqueued(r)
                if fn == "respond" and e:
                    resp_iwant += 1
                elif fn == "retry_offer":
                    retry += e
                elif fn == "ask_parked":
                    parked += e
        f.close()
    except (OSError, EOFError, json.JSONDecodeError) as e:      # a run that stopped may leave its file cut
        print(f"skipped: {rel}: not readable to its end ({type(e).__name__})")
        return 0
    if header is None:
        print(f"skipped: {rel}: no header")
        return 0
    doc = doc_of(header.get("args", []))
    if doc != "seacast":
        print(f"skipped: {rel}: doc {doc}")
        return 0
    if trailer is None:
        print(f"skipped: {rel}: no trailer (the run stopped)")
        return 0
    if not side.is_file():
        print(f"skipped: {rel}: no calls file")
        return 0
    cf = json.loads(side.read_text())
    calls, iw, inside = cf["calls"], cf["iwants"], cf["inside"]

    print(f"{rel} (format {header.get('format')}, doc {doc}): {n} records; reached: "
          + ", ".join(f"{x} {c}" for x, c in sorted(reached.items())))
    print(f"{rel}: respond {fns['respond']} records, {resp_iwant} with an IWANT; retry_offer {fns['retry_offer']} "
          f"records, {len(retry)} IWANTs enqueued (asks {dict(sorted(Counter(retry).items()))}); ask_parked "
          f"{fns['ask_parked']} records, {len(parked)} IWANTs enqueued")

    def whole(name):
        """name's calls, by branch, and its IWANT counts over its record and inside calls."""
        c = calls.get(name, {"record": 0, "in": {}, "bare": 0, "ext": 0, "observer": 0})
        tot = c["record"] + sum(c["in"].values()) + c["bare"] + c["ext"] + c["observer"]
        w = k = 0
        asks = Counter()
        for b in iw.get(name, {}).values():
            w += b["with"]
            k += b["iwants"]
            asks.update({int(a): m for a, m in b["asks"].items()})
        return (f"{name} {tot} (record {c['record']}, in {c['in']}, bare {c['bare']}, ext {c['ext']}, observer "
                f"{c['observer']}), {w} with an IWANT, {k} IWANTs enqueued (asks {dict(sorted(asks.items()))})")
    nested = {x: o for x, o in inside.items() if o}
    print(f"{rel}: calls: " + "; ".join(whole(x) for x in FNS) + f"; one inside another: {nested}")

    bad = []
    # K4a: records, by the calls file, the trailer and the replay's fn lines
    by_fn = Counter()
    for k, v in trailer.get("by_fn", {}).items():
        by_fn[k[:-len(" (raises)")] if k.endswith(" (raises)") else k] += v
    rep = out / f"{rel}.replay"
    rfn = None
    if rep.is_file():
        rfn = {m.group(1): int(m.group(2)) for m in re.finditer(r"^fn (\S+): (\d+) records", rep.read_text(), re.M)}
    for x in sorted(set(by_fn) | {x for x, c in calls.items() if c["record"]}):
        got = calls.get(x, {}).get("record", 0)
        if got != by_fn[x]:
            bad.append(f"K4a: {x}'s records {got} in the calls file, {by_fn[x]} in the trailer")
        elif rfn is not None and got != rfn.get(x, 0):
            bad.append(f"K4a: {x}'s records {got} in the calls file, {rfn.get(x, 0)} in the replay")
    if rfn is not None:
        for x in sorted(set(rfn) - set(by_fn)):
            bad.append(f"K4a: {x}: {rfn[x]} records in the replay, none in the trailer")
    # reach: X's calls inside F's records against the records of F that reached X
    for (fn, x), c in sorted(reach.items()):
        got = calls.get(x, {}).get("in", {}).get(fn, 0)
        if got < c:
            bad.append(f"reach: {x} inside {fn}: {got} calls, {c} records of {fn} reached it")
    for x, c in sorted(calls.items()):
        for fn, m in sorted(c["in"].items()):
            if m and fn != x and not reach[(fn, x)]:
                bad.append(f"reach: {x} inside {fn}: {m} calls, no record of {fn} reached it")
    # by-fn: the calls file's record half against the tapes' counts by fn
    rec = {x: iw.get(x, {}).get("record", {"calls": 0, "with": 0, "iwants": 0, "asks": {}}) for x in FNS}
    for x in FNS:
        if rec[x]["calls"] != fns[x]:
            bad.append(f"by-fn: {x}: {rec[x]['calls']} record calls counted for IWANTs, {fns[x]} records")
    if rec["respond"]["with"] != resp_iwant:
        bad.append(f"by-fn: respond: {rec['respond']['with']} with an IWANT in the calls file, {resp_iwant} on the "
                   f"tapes")
    for x, e in (("retry_offer", retry), ("ask_parked", parked)):
        want = {str(a): m for a, m in sorted(Counter(e).items())}
        if rec[x]["iwants"] != len(e) or rec[x]["asks"] != want:
            bad.append(f"by-fn: {x}: {rec[x]['iwants']} IWANTs (asks {rec[x]['asks']}) in the calls file, {len(e)} "
                       f"(asks {want}) on the tapes")
    pairs = len(reach)
    if bad:
        print(f"{rel}: controls: NOT: " + "; ".join(bad[:4]) + (f"; and {len(bad) - 4} more" if len(bad) > 4 else ""))
        return 1
    print(f"{rel}: controls: K4a ({len(by_fn)} names{', with the replay' if rfn is not None else ''}), reach "
          f"({pairs} pairs), by-fn: hold")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
