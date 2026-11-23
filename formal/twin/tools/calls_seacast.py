#!/usr/bin/env python3
"""The calls summary of one v2 trace: its `reached` names, the IWANTs that respond, retry_offer and ask_parked enqueue,
counted by their records and by their calls, the replaced names' calls, and four controls of the calls file trace3.py
writes beside the trace.

    python3 -I calls_seacast.py [--any] OUT REL        (REL: a trace under OUT, without .jsonl.gz: seacast/hand5, chains/X)
    python3 -I calls_seacast.py --makers ROOT          the IWANT makers in ROOT's documents (P1, P2 below)
    python3 -I calls_seacast.py --self-test

It reads OUT/REL.jsonl.gz, OUT/REL.jsonl.gz.calls.json and, where there is one, the replay's report OUT/REL.replay.
It prints six lines, or one line `skipped: REL: CLASS: WHY`, in this order: a plant (plant-*; class plant) or a copy
(fam-*; copy), by its name; a run that stopped (stopped): a file not readable to its end, or with no header; a trace
under another document (doc); a run that stopped: no trailer, or a trailer that says it stopped; a trace with no
calls file (nocalls). --any reads a plant or a copy too, and never a run that stopped. The classes are those of
formal/twin/inventory.tsv, which inventory_seacast.py holds the summary to; doc and nocalls are in no line of it.

1. `REL (format F, doc D): R records; reached: NAME n, ...`: every name in a record's `reached`, with the records
   that hold it (a record's own fn among them).
2. `REL: respond R records, I with an IWANT; retry_offer X records, Y IWANTs enqueued (asks {...}); ask_parked Z
   records, W IWANTs enqueued`: by the records of each name, from their tapes. An IWANT is a list whose first member
   is "iwant" and whose second is a list (its asks), anywhere in an `enqueue` tape row's arguments.
3. `REL: calls: NAME T (record r, in {HOST: n}, bare b, ext e, observer o), I with an IWANT, Y IWANTs enqueued (asks
   {...}); ...; one inside another: {...}`: by the calls of each name, from the calls file. T is the sum of its
   branches (asked and outer among them, which are 0 for the three: none is replaceable), and I and Y count the calls
   in a record of its own and those inside another's.
4. `REL: by-fn: PART; ...`: the calls file's IWANT counts held to the tapes, a part each, as (calls, with, iwants,
   asks). For each of the three in turn, its record part, then its in parts by host (only where its calls inside the
   host are not 0); then the summed parts, by host:
   - `X record (C, W, I, ASKS): exact`: C is X's records; W, I and ASKS come from their tapes, and W = I where no other
     of the three ran inside the record (P2);
   - `X in H (C, W, I, ASKS): calls at least L, the rest exact`: C is the calls file's calls of X inside H's records;
     W = I (P2), and I and ASKS come from the tapes of H's records whose `reached` holds X and no other of the three;
     L is the larger of those records and I. The tapes do not tell how many calls of X a record made beyond these;
   - `X and Y in H (I, ASKS): summed`: H's records where two or more of the three ran (inside one another, or one
     inside a record of another), whose IWANTs the tapes do not split among them.
5. `REL: replaced: NAME (record r, in {...}, asked {HOST: n}, bare b, ext e, outer o, observer v); ...`: each name a
   node may replace (manifest_seacast's REPLACEABLE and REPLACEABLE_WHOLE) with a call counted; or `none called`.
6. `REL: controls: ...`, which hold, or NOT with the first ones that fail:
   - K4a: each name's records in the calls file are the trailer's (raises included) and the replay's fn line's;
   - by-fn: each part as line 4 says, from the tapes. An IWANT on a record whose fn is not one of the three, and
     whose `reached` holds none of them, fails it: by P1 an IWANT comes only from a call of one of the three. asked or
     outer for one of the three fails it (none is replaceable);
   - asked: for each traced name (each name of the calls file) and record fn H, the rows the name heads on the tapes
     of H's records are its asked count inside H: a question asked by a record's own code writes one row there;
   - reach, a consistency check: for each record fn F and name X other than F, X's calls inside F's records are at
     least the records of F whose `reached` holds X, and none where none does.
Exit 0 when the controls hold or the trace is skipped, 1 when one fails, 2 on a usage error.

The premises (step 4's): P1, an IWANT is made only by respond, retry_offer and ask_parked; P2, each makes at most one
a call: its one `IWANT(` site lies under no loop. --makers derives both from ROOT's documents (content.DOCS): every
`IWANT(` in a code block, its enclosing def, no `for` or `while` between them, one site a def. It prints one line,
`IWANT makers: X (DOC:LINE), ...; one site each, under no loop; DOC: none; as FNS`, with exit 0, or `IWANT makers: NOT:
WHY` with exit 1.
"""
import gzip
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import trace3                           # noqa: E402: its doc_of reads a header's document, as header3.py does
import content                          # noqa: E402: its DOCS, the documents --makers reads

FNS = ("respond", "retry_offer", "ask_parked")
REPLACEABLE = frozenset(trace3.REPLACEABLE_Seacast)
ZERO = {"calls": 0, "with": 0, "iwants": 0, "asks": {}}


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
    """The document a header's args name, as trace3.doc_of reads them (either form, and the names before v0.12.0),
    with lite where they name none (the toy's default, seacast-lite.md)."""
    return trace3.doc_of(args) or "lite"


def hist(c):
    return str(dict(sorted(c.items())))


def tup(s):
    """A part of the calls file's iwants as (calls, with, iwants, asks), the asks keyed by their counts."""
    return s["calls"], s["with"], s["iwants"], {int(a): m for a, m in s["asks"].items()}


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
        print(f"skipped: {rel}: plant: a plant")
        return 0
    if not anyname and base.startswith("fam-"):
        print(f"skipped: {rel}: copy: a copy (families_seacast.py)")
        return 0
    trace = out / f"{rel}.jsonl.gz"
    side = out / f"{rel}.jsonl.gz.calls.json"
    header = trailer = None
    n = 0
    reached, fns, reach = Counter(), Counter(), Counter()
    resp_iwant, retry, parked = 0, [], []
    whole = {x: [0, 0, Counter()] for x in FNS}    # X's records: with an IWANT, IWANTs, asks (their whole tapes)
    p2 = Counter()                      # X's records where none other of the three ran, with two IWANTs or more
    alone = {}                          # (X, H): H's records reaching X and none other of the three: [n, I, asks]
    summed = {}                         # H: its records where two or more of the three ran: [names, n, I, asks]
    orphan = {}                         # H: the first record (its n) with an IWANT, reaching none of the three
    heads = Counter()                   # (a row's head, the record's fn)
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
            for t in r.get("tape", []):
                if isinstance(t, list) and t and isinstance(t[0], str):
                    heads[(t[0], fn)] += 1
            e = enqueued(r)
            if fn in FNS:
                if fn == "respond" and e:
                    resp_iwant += 1
                elif fn == "retry_offer":
                    retry += e
                elif fn == "ask_parked":
                    parked += e
                w = whole[fn]
                w[0] += 1 if e else 0
                w[1] += len(e)
                w[2].update(e)
            m = (set(r.get("reached", [])) & set(FNS)) - {fn}      # the three that ran inside the record
            if fn in FNS and not m:
                p2[fn] += len(e) > 1
            elif fn not in FNS and len(m) == 1:
                s = alone.setdefault((m.pop(), fn), [0, 0, Counter()])
                s[0] += 1
                s[1] += len(e)
                s[2].update(e)
            elif fn not in FNS and not m:
                if e and fn not in orphan:
                    orphan[fn] = r.get("n")
            else:
                s = summed.setdefault(fn, [set(), 0, 0, Counter()])
                s[0] |= m | ({fn} if fn in FNS else set())
                s[1] += 1
                s[2] += len(e)
                s[3].update(e)
        f.close()
    except (OSError, EOFError, json.JSONDecodeError) as e:      # a run that stopped may leave its file cut
        print(f"skipped: {rel}: stopped: not readable to its end ({type(e).__name__})")
        return 0
    if header is None:
        print(f"skipped: {rel}: stopped: no header")
        return 0
    doc = doc_of(header.get("args", []))
    if doc != "seacast":
        print(f"skipped: {rel}: doc: {doc}")
        return 0
    if trailer is None:
        print(f"skipped: {rel}: stopped: no trailer")
        return 0
    if "stopped" in trailer:            # trace3.py's close after a stop: the records are a prefix of a run's
        print(f"skipped: {rel}: stopped: {trailer['stopped']}")
        return 0
    if not side.is_file():
        print(f"skipped: {rel}: nocalls: no calls file")
        return 0
    for (x, h), (k, i, a) in list(alone.items()):     # a host with a summed record: its records reaching one of
        if h in summed:                                 # the three alone are summed with them
            s = summed[h]
            s[0].add(x)
            s[1] += k
            s[2] += i
            s[3].update(a)
            del alone[(x, h)]
    cf = json.loads(side.read_text())
    calls, iw, inside = cf["calls"], cf["iwants"], cf["inside"]
    nil = {"record": 0, "in": {}, "asked": {}, "bare": 0, "ext": 0, "outer": 0, "observer": 0}

    print(f"{rel} (format {header.get('format')}, doc {doc}): {n} records; reached: "
          + ", ".join(f"{x} {c}" for x, c in sorted(reached.items())))
    print(f"{rel}: respond {fns['respond']} records, {resp_iwant} with an IWANT; retry_offer {fns['retry_offer']} "
          f"records, {len(retry)} IWANTs enqueued (asks {dict(sorted(Counter(retry).items()))}); ask_parked "
          f"{fns['ask_parked']} records, {len(parked)} IWANTs enqueued")

    def line3(name):
        """name's calls, by branch, and its IWANT counts over its record and inside calls."""
        c = dict(nil, **calls.get(name, {}))
        tot = (c["record"] + sum(c["in"].values()) + sum(c["asked"].values()) + c["bare"] + c["ext"] + c["outer"]
               + c["observer"])
        parts = [iw.get(name, {}).get("record", ZERO)] + list(iw.get(name, {}).get("in", {}).values())
        asks = Counter()
        for b in parts:
            asks.update({int(a): m for a, m in b["asks"].items()})
        return (f"{name} {tot} (record {c['record']}, in {c['in']}, bare {c['bare']}, ext {c['ext']}, observer "
                f"{c['observer']}), {sum(b['with'] for b in parts)} with an IWANT, {sum(b['iwants'] for b in parts)} "
                f"IWANTs enqueued (asks {dict(sorted(asks.items()))})")
    nested = {x: o for x, o in inside.items() if o}
    print(f"{rel}: calls: " + "; ".join(line3(x) for x in FNS) + f"; one inside another: {nested}")

    bad = []
    # by-fn: the record halves; the in parts, by host; the summed parts, by host
    parts, inparts = [], 0
    for x in FNS:
        c, (w, i, a) = tup(iw.get(x, {}).get("record", ZERO)), whole[x]
        if c != (fns[x], w, i, dict(a)):
            bad.append(f"by-fn: {x}'s records {c} in the calls file, {(fns[x], w, i, dict(a))} on the tapes")
        if p2[x]:
            bad.append(f"by-fn: {x}: {p2[x]} records with two IWANTs or more, none other of the three in them (P2)")
        parts.append(f"{x} record ({fns[x]}, {w}, {i}, {hist(a)}): exact")
        cin = dict(nil, **calls.get(x, {}))["in"]
        ins = iw.get(x, {}).get("in", {})
        for h in sorted(set(k for k, v in cin.items() if v) | set(ins) | {hh for xx, hh in alone if xx == x}):
            if h in summed:
                continue                # its IWANTs are the host's summed part's
            m, ci, t = cin.get(h, 0), tup(ins.get(h, ZERO)), alone.get((x, h))
            if t is None:
                bad.append(f"by-fn: {x} inside {h}: {m} calls, no record of {h} reached it")
                continue
            low = max(t[0], t[1])
            if ci != (m, t[1], t[1], dict(t[2])) or m < low:
                bad.append(f"by-fn: {x} inside {h}: {ci} in the calls file, its calls {m}; on the tapes {t[1]} "
                           f"IWANTs (asks {hist(t[2])}), calls at least {low}")
            parts.append(f"{x} in {h} ({m}, {t[1]}, {t[1]}, {hist(t[2])}): calls at least {low}, the rest exact")
            inparts += 1
    for h, (names, k, i, a) in sorted(summed.items()):
        got = [tup(iw.get(y, {}).get("in", {}).get(h, ZERO))[2] for y in sorted(names) if y != h]
        if any(g > i for g in got) or (h not in FNS and sum(got) < i):
            bad.append(f"by-fn: inside {h}: the calls file's IWANTs {got} for {sorted(names)}, {i} on the tapes "
                       f"of its {k} records where they ran together")
        parts.append(f"{' and '.join(sorted(names))} in {h} ({i}, {hist(a)}): summed")
    for h, r in sorted(orphan.items()):
        bad.append(f"by-fn: an IWANT on a record of {h} that reached none of the three (n {r})")
    for x in FNS:
        c = dict(nil, **calls.get(x, {}))
        if any(c["asked"].values()) or c["outer"]:
            bad.append(f"by-fn: {x}, which no node replaces, asked {c['asked']}, outer {c['outer']}")
    # asked: each traced name's questions inside H against the rows it heads on H's records' tapes
    pairs = set()
    for name, c in sorted(calls.items()):
        rows = {h: k for (hd, h), k in heads.items() if hd == name}
        for h in sorted(set(rows) | set(c.get("asked", {}))):
            pairs.add((name, h))
            if rows.get(h, 0) != c.get("asked", {}).get(h, 0):
                bad.append(f"asked: {name} inside {h}: {c.get('asked', {}).get(h, 0)} questions in the calls file, "
                           f"{rows.get(h, 0)} rows on the tapes")
    # the replaced names' counts
    rep = []
    for name in sorted(REPLACEABLE & set(calls)):
        c = dict(nil, **calls[name])
        if c["record"] or any(c["in"].values()) or any(c["asked"].values()) or c["bare"] or c["ext"] or c["outer"] \
                or c["observer"]:
            rep.append(f"{name} (record {c['record']}, in {c['in']}, asked {c['asked']}, bare {c['bare']}, ext "
                       f"{c['ext']}, outer {c['outer']}, observer {c['observer']})")
    print(f"{rel}: by-fn: " + "; ".join(parts))
    print(f"{rel}: replaced: " + ("; ".join(rep) or "none called"))
    # K4a: records, by the calls file, the trailer and the replay's fn lines
    by_fn = Counter()
    for k, v in trailer.get("by_fn", {}).items():
        by_fn[k[:-len(" (raises)")] if k.endswith(" (raises)") else k] += v
    rep_f = out / f"{rel}.replay"
    rfn = None
    if rep_f.is_file():
        rfn = {m.group(1): int(m.group(2)) for m in re.finditer(r"^fn (\S+): (\d+) records", rep_f.read_text(), re.M)}
    for x in sorted(set(by_fn) | {x for x, c in calls.items() if c["record"]}):
        got = calls.get(x, {}).get("record", 0)
        if got != by_fn[x]:
            bad.insert(0, f"K4a: {x}'s records {got} in the calls file, {by_fn[x]} in the trailer")
        elif rfn is not None and got != rfn.get(x, 0):
            bad.insert(0, f"K4a: {x}'s records {got} in the calls file, {rfn.get(x, 0)} in the replay")
    if rfn is not None:
        for x in sorted(set(rfn) - set(by_fn)):
            bad.insert(0, f"K4a: {x}: {rfn[x]} records in the replay, none in the trailer")
    # reach, a consistency check: X's calls inside F's records against the records of F that reached X
    for (fn, x), c in sorted(reach.items()):
        got = calls.get(x, {}).get("in", {}).get(fn, 0)
        if got < c:
            bad.append(f"reach: {x} inside {fn}: {got} calls, {c} records of {fn} reached it")
    for x, c in sorted(calls.items()):
        for fn, m in sorted(c["in"].items()):
            if m and fn != x and not reach[(fn, x)]:
                bad.append(f"reach: {x} inside {fn}: {m} calls, no record of {fn} reached it")
    if bad:
        print(f"{rel}: controls: NOT: " + "; ".join(bad[:4]) + (f"; and {len(bad) - 4} more" if len(bad) > 4 else ""))
        return 1
    print(f"{rel}: controls: K4a ({len(by_fn)} names{', with the replay' if rfn is not None else ''}), by-fn (3 record "
          f"halves exact, {inparts} in-half parts with their calls bounded below, {len(summed)} summed), asked "
          f"({len(pairs)} pairs), reach ({len(reach)} pairs, a consistency check): hold")
    return 0


def makers(root):
    """P1 and P2 from root's documents: (the line, the exit code)."""
    sites, outside, loops, none = {}, [], [], []
    for doc in content.DOCS:
        inb, stack, hits = False, [], 0
        for i, line in enumerate((Path(root) / doc).read_text().splitlines(), 1):
            s = line.strip()
            if s.startswith("```"):
                inb, stack = not inb, []
                continue
            if not inb or not s or s.startswith("#"):
                continue
            code = s.split("#", 1)[0]
            ind = len(line) - len(line.lstrip())
            while stack and stack[-1][0] >= ind:
                stack.pop()
            d = re.match(r"(?:async\s+)?def (\w+)\(", code)
            if d:
                stack.append((ind, "def", d.group(1)))
            elif re.match(r"(?:for|while)\b", code):
                stack.append((ind, "loop", None))
            if not re.search(r"\bIWANT\(", code):
                continue
            hits += 1
            where = f"{doc}:{i}"
            k = max((j for j, e in enumerate(stack) if e[1] == "def"), default=None)
            if k is None:
                outside.append(where)
                continue
            if any(e[1] == "loop" for e in stack[k + 1:]) or re.search(r"\b(?:for|while)\b", code):
                loops.append(f"{stack[k][2]} ({where})")
            sites.setdefault(stack[k][2], []).append(where)
        if not hits:
            none.append(doc)
    bad = [f"an IWANT( outside any def ({w})" for w in outside]
    bad += [f"{x}'s IWANT( under a loop" + w[len(x):] for w in loops for x in [w.split(" ", 1)[0]]]
    bad += [f"{x} makes IWANTs at {len(w)} sites ({', '.join(w)})" for x, w in sorted(sites.items()) if len(w) > 1]
    if set(sites) != set(FNS):
        bad.append(f"the makers {sorted(sites)}, not FNS {sorted(FNS)}")
    if bad:
        return "IWANT makers: NOT: " + "; ".join(bad), 1
    return ("IWANT makers: " + ", ".join(f"{x} ({w[0]})" for x, w in sorted(sites.items()))
            + "; one site each, under no loop" + "".join(f"; {d}: none" for d in none) + "; as FNS"), 0


# --- the self-test: one small trace under each of eight args forms (args, its first line), then the classes
DOCS = [
    (["--doc", "seacast"], "seacast/t (format 7, doc seacast): 1 records"),
    (["--doc=seacast"], "seacast/t (format 7, doc seacast): 1 records"),
    (["--doc", "v2"], "seacast/t (format 7, doc seacast): 1 records"),
    (["--doc=v2"], "seacast/t (format 7, doc seacast): 1 records"),
    (["--doc", "lite"], "skipped: seacast/t: doc: lite"),
    (["--doc=v03"], "skipped: seacast/t: doc: lite"),
    ([], "skipped: seacast/t: doc: lite"),
    (["--doc", "v3"], "skipped: seacast/t: doc: v3"),
]
TRAILER = {"records": 1, "by_fn": {"x": 1}, "rest": 0}
# the classes by name and the runs that stopped: (case, REL, trailer or None, --any, the one line it must print)
CLASSES = [
    ("a trailer that says the run stopped", "seacast/t", dict(TRAILER, stopped="SystemExit: x"), False,
     "skipped: seacast/t: stopped: SystemExit: x"),
    ("the same under --any", "seacast/t", dict(TRAILER, stopped="SystemExit: x"), True,
     "skipped: seacast/t: stopped: SystemExit: x"),
    ("no trailer", "seacast/t", None, False, "skipped: seacast/t: stopped: no trailer"),
    ("a plant's name", "seacast/plant-t", TRAILER, False, "skipped: seacast/plant-t: plant: a plant"),
    ("a copy's name", "seacast/fam-t", TRAILER, False, "skipped: seacast/fam-t: copy: a copy (families_seacast.py)"),
]


def cell(name, **kw):
    c = {"record": 0, "in": {}, "asked": {}, "bare": 0, "ext": 0, "outer": 0, "observer": 0}
    c.update(kw)
    return c


def ask(*asks):
    """An enqueue row for each count: an IWANT of that many asks."""
    return [["enqueue", ["p", ["iwant", [f"a{j}" for j in range(k)]], False]] for k in asks]


def byfn_base():
    """A trace that holds: respond's record with an IWANT, retry_offer's without, and one record of
    on_block_installed in which retry_offer ran twice, enqueueing an IWANT each, and forward was asked."""
    recs = [{"fn": "respond", "reached": ["respond"], "tape": ask(1)},
            {"fn": "retry_offer", "reached": ["retry_offer"], "tape": []},
            {"fn": "on_block_installed", "reached": ["on_block_installed", "retry_offer"],
             "tape": ask(1, 1) + [["forward", ["p"], None]]}]
    calls = {"respond": cell("respond", record=1), "retry_offer": cell("retry_offer", record=1,
             **{"in": {"on_block_installed": 2}}), "ask_parked": cell("ask_parked"),
             "on_block_installed": cell("on_block_installed", record=1),
             "forward": cell("forward", asked={"on_block_installed": 1})}
    iws = {"respond": {"record": {"calls": 1, "with": 1, "iwants": 1, "asks": {"1": 1}}},
           "retry_offer": {"record": dict(ZERO, calls=1), "in": {"on_block_installed": {"calls": 2, "with": 2, "iwants": 2,
                                                                              "asks": {"1": 2}}}}}
    return recs, calls, iws


def byfn_cases():
    """(case, a change to the base, the exit, the words its line 6 must hold, or line 4's for a holding case)."""
    def orphan(r, c, w):
        r.append({"fn": "on_chunk", "reached": ["on_chunk"], "tape": ask(1)})
        c["on_chunk"] = cell("on_chunk", record=1)

    def nest(r, c, w):
        r.append({"fn": "on_block_installed", "reached": ["on_block_installed", "retry_offer", "ask_parked"],
                  "tape": ask(1, 1)})
        c["on_block_installed"]["record"] = 2
        c["retry_offer"]["in"]["on_block_installed"] = 3
        c["ask_parked"]["in"] = {"on_block_installed": 1}
        w["retry_offer"]["in"]["on_block_installed"] = {"calls": 3, "with": 3, "iwants": 3, "asks": {"1": 3}}
        w["ask_parked"] = {"in": {"on_block_installed": {"calls": 1, "with": 1, "iwants": 1, "asks": {"1": 1}}}}

    def part(**kw):
        return lambda r, c, w: w["retry_offer"]["in"]["on_block_installed"].update(kw)

    def below(r, c, w):
        c["retry_offer"]["in"]["on_block_installed"] = 1
        w["retry_offer"]["in"]["on_block_installed"]["calls"] = 1

    def no_part(r, c, w):
        c["retry_offer"]["in"] = {}
        del w["retry_offer"]["in"]
    return [
        ("by-fn: an in part that holds", lambda r, c, w: None, 0,
         "retry_offer in on_block_installed (2, 2, 2, {1: 2}): calls at least 2, the rest exact"),
        ("by-fn: an orphan IWANT", orphan, 1, "by-fn: an IWANT on a record of on_chunk that reached none"),
        ("by-fn: an in part's IWANTs one off", part(iwants=3), 1, "by-fn: retry_offer inside on_block_installed"),
        ("by-fn: an in part's with not its IWANTs", part(**{"with": 1}), 1,
         "by-fn: retry_offer inside on_block_installed"),
        ("by-fn: an in part's calls below L", below, 1, "by-fn: retry_offer inside on_block_installed"),
        ("by-fn: a host on the tapes with no in part", no_part, 1, "by-fn: retry_offer inside on_block_installed"),
        ("by-fn: a record half's with not the tapes'", lambda r, c, w: w["respond"]["record"].update({"with": 0}), 1,
         "by-fn: respond's records"),
        ("by-fn: nesting, summed", nest, 0, "ask_parked and retry_offer in on_block_installed (4, {1: 4}): summed"),
        ("asked: one off", lambda r, c, w: c["forward"]["asked"].update(on_block_installed=2), 1,
         "asked: forward inside on_block_installed"),
        ("asked: a question row with no asked count", lambda r, c, w: c["forward"].update(asked={}), 1,
         "asked: forward inside on_block_installed"),
        ("by-fn: outer for one of the three", lambda r, c, w: c["retry_offer"].update(outer=1), 1,
         "by-fn: retry_offer, which no node replaces"),
    ]


MAKERS_DOC = """# code
```python
def respond(p, asks):
    control = IWANT(asks) if asks else None   # one site
def retry_offer(a):
    if ok(a): enqueue(pick, IWANT([a]), urgent=False)
def ask_parked(a):
    for q in qs:
        note(q)
    if ok(a) and enqueue(pick, IWANT([a]), urgent=False):
        pass
```
"""
MAKERS = [
    ("makers: as FNS", MAKERS_DOC, 0, "IWANT makers: ask_parked (seacast-lite.md:10), respond (seacast-lite.md:4), "
     "retry_offer (seacast-lite.md:6); one site each, under no loop; seacast.md: none; as FNS"),
    ("makers: another def makes one", MAKERS_DOC.replace("        pass", "        pass\ndef other(a):\n"
                                                         "    enqueue(a, IWANT([a]))"), 1, "not FNS"),
    ("makers: a site under a loop", MAKERS_DOC.replace("    if ok(a): enqueue", "    for b in bs:\n"
                                                       "        enqueue"), 1, "retry_offer's IWANT( under a loop"),
    ("makers: a site outside any def", MAKERS_DOC.replace("        pass\n```", "        pass\nx = IWANT([1])\n```"), 1,
     "outside any def"),
]


def self_test():
    import contextlib
    import copy
    import io
    import tempfile
    good = total = 0

    def run(out, rel, args, trailer, anyname, recs, calls, iws):
        with gzip.open(out / f"{rel}.jsonl.gz", "wt") as f:
            for x in [{"content": "self-test"}, {"header": {"args": args, "format": 7}}, {"nodes": []}] + \
                    [dict(r, n=j, t=0) for j, r in enumerate(recs)]:
                f.write(json.dumps(x) + "\n")
            if trailer is not None:
                f.write(json.dumps({"trailer": trailer}) + "\n")
        (out / f"{rel}.jsonl.gz.calls.json").write_text(json.dumps({"calls": calls, "iwants": iws, "inside": {}}))
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = main((["--any"] if anyname else []) + [str(out), rel])
        return rc, buf.getvalue().splitlines()
    cases = ([(" ".join(a) or "(no --doc)", "seacast/t", a, TRAILER, False, w) for a, w in DOCS]
             + [(n, rel, ["--doc", "seacast"], tr, an, w) for n, rel, tr, an, w in CLASSES])
    with tempfile.TemporaryDirectory() as d:
        out = Path(d)
        (out / "seacast").mkdir()
        for name, rel, args, trailer, anyname, want in cases:
            rc, lines = run(out, rel, args, trailer, anyname, [{"fn": "x", "reached": ["x"], "tape": []}],
                            {"x": cell("x", record=1)}, {})
            if want.startswith("skipped: "):
                ok = rc == 0 and lines == [want]
            else:
                ok = rc == 0 and len(lines) == 6 and lines[0].startswith(want) and lines[5].endswith(": hold")
            good += ok
            total += 1
            print(f"calls_seacast: self-test: {name}: {lines[0] if lines else 'no line'}"
                  f"{'' if ok else '  <-- NOT as it must be: ' + want}")
        for name, change, want, words in byfn_cases():
            recs, calls, iws = copy.deepcopy(byfn_base())
            change(recs, calls, iws)
            by = Counter(r["fn"] for r in recs)
            rc, lines = run(out, "seacast/b", ["--doc", "seacast"], {"records": len(recs), "by_fn": dict(by),
                            "rest": 0}, False, recs, calls, iws)
            if want == 0:
                ok = rc == 0 and len(lines) == 6 and words in lines[3] and lines[5].endswith(": hold")
                shown = lines[3] if len(lines) > 3 else (lines[-1] if lines else "no line")
            else:
                ok = rc == 1 and len(lines) == 6 and lines[5].startswith("seacast/b: controls: NOT: ") \
                    and words in lines[5]
                shown = lines[5] if len(lines) > 5 else (lines[-1] if lines else "no line")
            good += ok
            total += 1
            print(f"calls_seacast: self-test: {name}: exit {rc}: {shown[:200]}"
                  f"{'' if ok else '  <-- NOT as it must be: exit ' + str(want) + ', ' + words}")
        for name, text, want, words in MAKERS:
            root = out / "makers"
            root.mkdir(exist_ok=True)
            (root / content.DOCS[0]).write_text(text)
            (root / content.DOCS[1]).write_text("# no code\n")
            line, rc = makers(root)
            ok = rc == want and (line == words if want == 0 else line.startswith("IWANT makers: NOT: ") and words in line)
            good += ok
            total += 1
            print(f"calls_seacast: self-test: {name}: exit {rc}: {line}"
                  f"{'' if ok else '  <-- NOT as it must be: exit ' + str(want) + ', ' + words}")
    print(f"calls_seacast: self-test: {good} of {total} cases as they must be")
    return 0 if good == total else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    if sys.argv[1:2] == ["--makers"] and len(sys.argv) == 3:
        text, code = makers(sys.argv[2])
        print(text)
        sys.exit(code)
    sys.exit(main(sys.argv[1:]))
