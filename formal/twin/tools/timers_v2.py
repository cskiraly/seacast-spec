#!/usr/bin/env python3
"""The timers of `deferred_offers` under v2: a trace's timer notes of that question, against the `retry_offer`
records they arm.

    python3 timers_v2.py TRACE        exit 0: K1 to K4 hold; 1: one fails (each failure named, up to 5 per check);
                                      2: a trace it cannot read, or not a trace under protocol-v2.md
    python3 timers_v2.py --self-test  seven small traces it writes, each with the result written for it

`deferred_offers` is a question of NodeV2's (design.md §5.1). `on_offer` asks it while the group is younger than its
type's START_DELAY (protocol-v2.md's on_offer, [D8]). The toy's binding records the offers and arms one timer per
newly wanted index: `after(max(0, known_at[g] + START_DELAY - now) + 1e-6, retry_offer, a)`, once per ask
(node._retry_armed, never cleared). The trace writes each such timer as a note on the question's tape entry, in its
log's `timers`: ["after", DELAY, "retry_offer", [ASK]]. A record's own `after` is a tape entry of its own:
["after", [DELAY, TARGET, ARGS], null]. Times and delays are a float's bits; an ask is [GROUP, INDEX].

  K1  one note per newly armed ask. The asks an entry must arm are the offer's indices that are wanted and not held,
      by the entry's reads of interest[g] and mine[g], and that are not yet armed at that node (by an earlier
      note). Where interest[g] was not read, it is the node's own interest, which the trace does not give
      (InterestMap.__missing__ in the toy): there each note's ask is checked to be offered, not held and not yet
      armed, and the line counts those entries apart.
  K2  each note's delay is max(0, known_at[g] + START_DELAY - t) + 1e-6, computed in floats from the record's t, the
      entry's read of known_at[g] (absent: 0.0) and START_DELAY of the group's type at that node (the nodes line).
      The trace does not name the group's type there. The type taken is one whose START_DELAY exceeds
      t - known_at[g], which is on_offer's condition for asking at all; types of one START_DELAY give one delay. If
      no START_DELAY fits, or two different ones do, the checker stops.
  K3, K4  a count per key (node, ask, due): the due of a note or an own after is the arming t plus its delay, added
      as floats as the simulator adds them; a record's is its t. With A the notes and own afters due at a key and R
      the retry_offer records there, K3 requires R >= A (each armed timer fires; a key past the last record is left
      out), and K4 requires R <= A (each record was armed). No record is matched to one note in particular.

The other lines are counts of the trace's other timers: the `enqueue` entries with timers, the notes that name
`alarm_due`, the records of `promise_due`, the notes of kind `start` (a `start` inside a question), and any other
note.
"""
import gzip
import json
import os
import struct
import sys
import tempfile
from collections import Counter, defaultdict

LIMIT = 5                     # failures named per check


def fl(b):
    return struct.unpack("<d", struct.pack("<q", b))[0]


def bits(x):
    return struct.unpack("<q", struct.pack("<d", x))[0]


def bitmap(v):
    """A read of a Bitmap: an int, the -1 family ["-", 1] (every index), or null (absent: empty)."""
    if v is None:
        return 0
    if v == ["-", 1]:
        return -1
    if isinstance(v, int) and not isinstance(v, bool):
        return v
    raise ValueError(f"not a bitmap: {v!r}")


def check(path, out):
    """The checks on one trace; each line of the report goes to out (a list). Returns the exit code."""
    fails = defaultdict(list)
    try:
        fh = gzip.open(path, "rt")
        fh.readline()                                           # the content line
        header = json.loads(fh.readline())["header"]
        nodes = json.loads(fh.readline())["nodes"]
    except (OSError, EOFError, ValueError, KeyError) as e:
        out.append(f"timers_v2: {path}: not a trace it can read: {e}")
        return 2
    args = header.get("args", [])
    if not any(args[j:j + 2] == ["--doc", "v2"] for j in range(len(args))):
        out.append(f"timers_v2: {path}: not a trace under protocol-v2.md (no --doc v2 in its header's args)")
        return 2
    delays = {}                                                 # node -> {type: START_DELAY}
    for e in nodes:
        for n in e["n"]:
            delays[n] = {T: fl(p["START_DELAY"]) for T, p in (e.get("types") or {}).items()}

    armed = defaultdict(set)                                    # node -> asks armed by a note
    arm = Counter()                                             # (node, ask, due bits) -> notes and own afters
    by_note = Counter()
    recs = Counter()                                            # (node, ask, t bits) -> retry_offer records
    notes = owns = whole = alone = 0
    enqueue_entries = enqueue_timed = alarm_notes = start_notes = promise_recs = 0
    other = Counter()
    last = None
    try:
        for line in fh:
            r = json.loads(line)
            if "fn" not in r:
                continue
            n, tb = r["n"], r["t"]
            t = fl(tb)
            last = t if last is None else max(last, t)
            if r["fn"] == "retry_offer":
                recs[(n, json.dumps(r["args"][0]), tb)] += 1
            if r["fn"] == "promise_due":
                promise_recs += 1
            for e in r.get("tape") or []:
                if not isinstance(e, list) or not e:
                    continue
                if e[0] == "after" and isinstance(e[1], list):          # the record's own after
                    if e[1][1] == "retry_offer":
                        owns += 1
                        arm[(n, json.dumps(e[1][2][0]), bits(t + fl(e[1][0])))] += 1
                    continue
                log = e[-1] if isinstance(e[-1], dict) else {}
                timers = log.get("timers") or []
                if e[0] == "enqueue":
                    enqueue_entries += 1
                    enqueue_timed += bool(timers)
                for tm in timers:
                    if tm[0] == "start":
                        start_notes += 1
                    if len(tm) > 2 and tm[2] == "alarm_due":
                        alarm_notes += 1
                    if not (e[0] == "deferred_offers" and tm[0] == "after" and tm[2] == "retry_offer"):
                        other[(e[0], tm[0], tm[2] if len(tm) > 2 else None)] += 1
                if e[0] != "deferred_offers":
                    continue
                have = e[1][1]                                     # ["have", g, bits, ...]
                g, offered = have[1], have[2]
                rd = {x[0]: x[2] for x in log.get("cr", []) if x[1] and x[1][-1] == g}
                interest_read = rd.get("interest") is not None
                mine = bitmap(rd.get("mine"))
                known_at = fl(rd["known_at"]) if rd.get("known_at") is not None else 0.0
                ours = [tm for tm in timers if tm[0] == "after" and tm[2] == "retry_offer"]
                asks = [tm[3][0] for tm in ours]
                got = [a[1] for a in asks]
                for a in asks:
                    if a[0] != g:
                        fails["K1"].append(f"node {n} at {t!r}: a note's ask {a} is not of the offer's group {g}")
                if interest_read:
                    whole += 1
                    s = offered & bitmap(rd["interest"]) & ~mine
                    want = [i for i in range(s.bit_length()) if s >> i & 1 and json.dumps([g, i]) not in armed[n]]
                    if sorted(got) != want or len(set(got)) != len(got):
                        fails["K1"].append(f"node {n} at {t!r}: notes for {sorted(got)}, asks newly armed {want}")
                else:
                    alone += 1
                    for i in got:
                        if not offered >> i & 1 or mine >> i & 1 or json.dumps([g, i]) in armed[n]:
                            fails["K1"].append(f"node {n} at {t!r}: a note for index {i} not offered, held or armed "
                                               f"already (interest not read)")
                    if len(set(got)) != len(got):
                        fails["K1"].append(f"node {n} at {t!r}: two notes for one ask (interest not read)")
                if not ours:
                    continue
                sds = {sd for sd in delays.get(n, {}).values() if t - known_at < sd}
                if len(sds) != 1:
                    out.append(f"timers_v2: {path}: node {n} at {t!r}: no single START_DELAY fits t - known_at "
                               f"({sorted(sds)}); K2 cannot be checked")
                    return 2
                sd = sds.pop()
                want_d = max(0.0, known_at + sd - t) + 1e-6          # the binding's order: known_at + START_DELAY - now
                for tm, a in zip(ours, asks):
                    notes += 1
                    k = json.dumps(a)
                    armed[n].add(k)
                    if bits(want_d) != tm[1]:
                        fails["K2"].append(f"node {n} at {t!r}: {a}'s delay {fl(tm[1])!r}, not {want_d!r}")
                    key = (n, k, bits(t + fl(tm[1])))
                    arm[key] += 1
                    by_note[key] += 1
    except (OSError, EOFError, ValueError, KeyError, IndexError, TypeError) as e:
        out.append(f"timers_v2: {path}: a line it cannot read: {e!r}")
        return 2
    if last is None:
        out.append(f"timers_v2: {path}: no record")
        return 2

    late_n = late_o = 0
    for key, a in arm.items():
        if fl(key[2]) > last:
            late_n += by_note[key]
            late_o += a - by_note[key]
        elif recs[key] < a:
            fails["K3"].append(f"node {key[0]}: {key[1]} due at {fl(key[2])!r}: {a} armed ({by_note[key]} by a note), "
                               f"{recs[key]} record(s) there")
    for key, r_ in recs.items():
        if arm[key] < r_:
            fails["K4"].append(f"node {key[0]}: {r_} retry_offer record(s) for {key[1]} at {fl(key[2])!r}, {arm[key]} "
                               f"armed there")
    nrec = sum(recs.values())
    multi = sum(1 for key, a in arm.items() if a > 1 and fl(key[2]) <= last)

    def line(check_, ok):
        if fails[check_]:
            out.append(f"timers_v2: {check_} FAILS: {len(fails[check_])} failure(s)")
            out.extend(f"  {check_}: {w}" for w in fails[check_][:LIMIT])
        else:
            out.append(f"timers_v2: {check_}: {ok}")

    line("K1", f"{whole} entries checked whole, {alone} by their notes alone (interest not read); {notes} asks armed")
    line("K2", f"{notes} notes, each delay max(0, known_at + START_DELAY - t) + 1e-6")
    line("K3", f"{notes - late_n} notes and {owns - late_o} own afters fire as retry_offer records at their due; "
               f"{late_n + late_o} due after the last record")
    line("K4", f"{nrec} retry_offer records, each armed: as many armed as records at each key, {multi} keys with two "
               f"or more armed")
    out.append(f"timers_v2: enqueue: {enqueue_entries} entries, {enqueue_timed} with timers")
    out.append(f"timers_v2: alarm_due: {alarm_notes} notes name it; promise_due: {promise_recs} records")
    out.append(f"timers_v2: start: {start_notes} notes of kind start (a start inside a question)")
    out.append(f"timers_v2: other notes: {dict(other) if other else 'none'}")
    if any(fails.values()):
        out.append(f"timers_v2: the timers of deferred_offers FAIL on {path}")
        return 1
    out.append(f"timers_v2: the timers of deferred_offers hold on {path}: {notes} notes, {owns} own afters, {nrec} "
               f"retry_offer records ({late_n + late_o} armed past the last record)")
    return 0


# --- the self-test: seven small traces, one node (0), one row group G, START_DELAY 1.0 --------------------------
G = "aa" * 32


def _delay(t, known_at=0.0, eps=True):
    return max(0.0, known_at + 1.0 - t) + (1e-6 if eps else 0.0)


def _due(t, known_at=0.0, eps=True):
    return t + _delay(t, known_at, eps)                     # as the simulator adds them


def _entry(t, offered, armed_idx, known_at=0.0, interest=["-", 1], mine=0, eps=True):
    """A deferred_offers tape entry at t, arming armed_idx, with its reads."""
    cr = [["interest", [G], interest], ["known_at", [G], bits(known_at)], ["mine", [G], mine]]
    timers = [["after", bits(_delay(t, known_at, eps)), "retry_offer", [[G, i]]] for i in armed_idx]
    return ["deferred_offers", [5, ["have", G, offered, True, False, False]], [], {"cr": cr, "cw": [], "timers": timers}]


def _own(t, i):
    """A record's own after of retry_offer for index i, with the delay a note at t has."""
    return ["after", [bits(_delay(t)), "retry_offer", [[G, i]]], None]


def _rec(t, fn="on_offer", tape=(), args=None):
    return {"n": 0, "t": bits(t), "fn": fn, "args": args or [5], "tape": list(tape), "reads": [], "scans": [],
            "writes": [], "rest": [], "ret": None, "reached": [fn], "tables": []}


def _retry(t, i):
    return _rec(t, "retry_offer", (), [[G, i]])


CASES = [  # (name, records, the checks that must fail)
    ("u1 one note, one record", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3])]), _retry(_due(0.25), 3)], set()),
    ("u2 two notes at one key, two records", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3]), _entry(0.25, 1 << 3, [3])]),
                                              _retry(_due(0.25), 3), _retry(_due(0.25), 3)], {"K1"}),
    ("u3 a note and an own after at one key, one record", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3]), _own(0.25, 3)]),
                                                           _retry(_due(0.25), 3)], {"K3"}),
    ("u4 one note, two records at its key", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3])]), _retry(_due(0.25), 3),
                                             _retry(_due(0.25), 3)], {"K4"}),
    ("u5 a delay without its + 1e-6", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3], eps=False)]),
                                       _retry(_due(0.25, eps=False), 3)], {"K2"}),
    ("u6 a note for an ask already armed", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3])]),
                                            _rec(0.5, tape=[_entry(0.5, 1 << 3, [3])]), _retry(_due(0.25), 3),
                                            _retry(_due(0.5), 3)], {"K1"}),
    ("u7 a note due after the last record", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3])]), _rec(0.5)], set()),
    ("u8 a note and an own after at one key, two records", [_rec(0.25, tape=[_entry(0.25, 1 << 3, [3]),
                                                                             _own(0.25, 3)]),
                                                            _retry(_due(0.25), 3), _retry(_due(0.25), 3)], set()),
]


def self_test():
    good = 0
    with tempfile.TemporaryDirectory() as d:
        for name, records, must in CASES:
            p = os.path.join(d, "u.jsonl.gz")
            with gzip.open(p, "wt") as fh:
                fh.write(json.dumps({"content": "self-test"}) + "\n")
                fh.write(json.dumps({"header": {"args": ["--doc", "v2"]}}) + "\n")
                fh.write(json.dumps({"nodes": [{"n": [0], "types": {"row": {"START_DELAY": bits(1.0)},
                                                                    "payload": {"START_DELAY": 0}}}]}) + "\n")
                for r in records:
                    fh.write(json.dumps(r) + "\n")
                fh.write(json.dumps({"trailer": {"records": len(records)}}) + "\n")
            out = []
            rc = check(p, out)
            failed = {w.split()[1] for w in out if " FAILS: " in w}
            ok = rc == (1 if must else 0) and failed == must
            good += ok
            print(f"timers_v2: self-test: {name}: exit {rc}, failed {sorted(failed) or 'none'}"
                  f"{'' if ok else ' <-- NOT as it must be: ' + str(sorted(must))}")
            if not ok:
                print("\n".join("    " + w for w in out))
    print(f"timers_v2: self-test: {good} of {len(CASES)} cases as they must be")
    return 0 if good == len(CASES) else 1


def main(argv):
    if argv[1:] == ["--self-test"]:
        return self_test()
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[2].strip())
        return 2
    out = []
    rc = check(argv[1], out)
    print("\n".join(out))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
