#!/usr/bin/env python3
"""The timers of `deferred_offers` under v2: a trace's timer notes of that question, against the `retry_offer`
records they arm.

    python3 timers_seacast.py TRACE        exit 0: K1 to K4 hold; 1: one fails (each failure named, up to 5 per check);
                                      2: a trace it cannot read, or not a trace under seacast.md
    python3 timers_seacast.py --self-test  twenty-nine small traces it writes, each with the result written for it
                                      (twenty-three of the checks, six of the header's document)

`deferred_offers` is a question of NodeSeacast's (design.md §5.1). `on_offer` asks it while the group is younger than its
type's START_DELAY (seacast.md's on_offer, [D8]). The toy's binding records the offers and arms one timer per
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
      out), and K4 requires R <= A (each record was armed), but for the heartbeat's retries below. No record is
      matched to one note in particular.
      retry_offer has a second caller with no timer: seacast.md's on_heartbeat retries every offer §4.3's limits held
      back (`for a in held_back.values(): retry_offer(a)`), then clears held_back. on_heartbeat is no record, so
      those calls are records of their own. Under seacast.md on_heartbeat alone calls drop_stale_waits, after the
      retries, so its record follows theirs at the same t and ends the node's held_back: it is the heartbeat's
      marker, and it closes the node's epoch. A record beyond the timers at its key is the heartbeat's when both
      hold: the node's next marker in record order (not merely one at the same t) has the record's t, so that the
      marker closes the epoch the record is in; and its ask was written to held_back at that node (a write
      ["held_back", PATH, ASK], on_offer's) in that epoch, and no other record of that epoch took the same write. A
      record whose epoch no marker closes, or whose epoch's marker has another t, is not the heartbeat's. One write
      excuses one record at most, and the writes of one key in an epoch are one: an excuse is the held value at
      the heartbeat. And since held_back holds one value per chunk and the heartbeat retries each once, K4 fails any
      chunk with two or more records beyond its timers at one (node, t) of a heartbeat, in either branch and
      across epochs (two markers at one t). The limit: a timer lost whose fire falls on a heartbeat, for an ask held
      back in the epoch that heartbeat closes and not yet retried, is taken for the heartbeat's retry.
      A trace that records no on_offer cannot show the second condition: on_offer is held_back's one writer (an
      older head's tracer recorded neither it nor on_heartbeat). There K4 takes the first condition alone, with the bound
      the document gives: at a heartbeat, one record beyond the timers for a chunk at most (its group and index,
      whichever form the ask names it by). In a trace that records on_offer, no write means nothing was held back,
      and the second condition stands. The lines say which of the two a trace took ("held back" or "by the
      heartbeat alone"), and count the chunks at a heartbeat with two or more records beyond their timers. The
      fallback's limit: a lost timer whose fire falls on a heartbeat, in the epoch its node's marker closes, is
      taken for the heartbeat's retry, held back or not.

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
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import trace3                           # noqa: E402: its doc_of reads a header's document, as header3.py does

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


def chunk(a):
    """The chunk an ask names (an ask as JSON), as held_back keys it, written [group, index]: an ask [group, index],
    or a structured id, 56 bytes as hex, whose first 32 bytes are the group and next 4 the index, little-endian (the
    toy's parse_id). Any other ask is a chunk of its own."""
    x = json.loads(a)
    if isinstance(x, list) and len(x) == 2:
        return json.dumps(x)
    if isinstance(x, str) and len(x) == 112:
        try:
            return json.dumps([x[:64], int.from_bytes(bytes.fromhex(x[64:72]), "little")])
        except ValueError:
            pass
    return a


def check(path, out):
    """The checks on one trace; each line of the report goes to out (a list). Returns the exit code."""
    fails = defaultdict(list)
    try:
        fh = gzip.open(path, "rt")
        fh.readline()                                           # the content line
        header = json.loads(fh.readline())["header"]
        nodes = json.loads(fh.readline())["nodes"]
    except (OSError, EOFError, ValueError, KeyError) as e:
        out.append(f"timers_seacast: {path}: not a trace it can read: {e}")
        return 2
    args = header.get("args", [])
    if trace3.doc_of(args) != "seacast":                    # either form, and v2, the name before v0.12.0
        out.append(f"timers_seacast: {path}: not a trace under seacast.md (no --doc seacast in its header's args)")
        return 2
    delays = {}                                                 # node -> {type: START_DELAY}
    for e in nodes:
        for n in e["n"]:
            delays[n] = {T: fl(p["START_DELAY"]) for T, p in (e.get("types") or {}).items()}

    armed = defaultdict(set)                                    # node -> asks armed by a note
    arm = Counter()                                             # (node, ask, due bits) -> notes and own afters
    by_note = Counter()
    recs = Counter()                                            # (node, ask, t bits) -> retry_offer records
    heartbeats = set()                                          # (node, t bits) of a drop_stale_waits record
    held = defaultdict(dict)                                    # node -> held_back since its last heartbeat
    epoch = Counter()                                           # node -> its heartbeats so far
    pend = defaultdict(list)                                    # node -> its open epoch's retry_offer keys
    pend_held = defaultdict(list)                               # node -> those whose ask was held back: (key, ask)
    bound = Counter()                                           # (node, ask, t bits) -> records its node's next
    #                                                             marker closed at their t (the fallback's excuses)
    held_at = defaultdict(set)                                  # (node, ask, t bits) -> (epoch, ask) held back, of
    #                                                             the records so closed (the held branch's excuses)
    held_writes = offer_recs = 0
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
                a = json.dumps(r["args"][0])
                recs[(n, a, tb)] += 1
                pend[n].append((n, a, tb))                      # a candidate until its node's next marker
                if a in held[n].values():                       # held back since this node's last heartbeat
                    pend_held[n].append(((n, a, tb), a))
            for e in r.get("writes") or []:
                if isinstance(e, list) and len(e) == 3 and e[0] == "held_back":
                    if e[2] is None:
                        held[n].pop(json.dumps(e[1]), None)
                    else:
                        held[n][json.dumps(e[1])] = json.dumps(e[2])
                        held_writes += 1
            if r["fn"] == "on_offer":                           # held_back's one writer (seacast.md :1319)
                offer_recs += 1
            if r["fn"] == "drop_stale_waits":                   # the heartbeat, after its retries: held_back cleared
                heartbeats.add((n, tb))
                for key in pend[n]:                             # it closes its node's epoch: the candidates at its
                    if key[2] == tb:                            #   own t are its retries; the others are dropped
                        bound[key] += 1
                for key, a in pend_held[n]:
                    if key[2] == tb:
                        held_at[key].add((epoch[n], a))
                pend[n].clear()
                pend_held[n].clear()
                held[n].clear()
                epoch[n] += 1
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
                    out.append(f"timers_seacast: {path}: node {n} at {t!r}: no single START_DELAY fits t - known_at "
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
        out.append(f"timers_seacast: {path}: a line it cannot read: {e!r}")
        return 2
    if last is None:
        out.append(f"timers_seacast: {path}: no record")
        return 2

    late_n = late_o = 0
    for key, a in arm.items():
        if fl(key[2]) > last:
            late_n += by_note[key]
            late_o += a - by_note[key]
        elif recs[key] < a:
            fails["K3"].append(f"node {key[0]}: {key[1]} due at {fl(key[2])!r}: {a} armed ({by_note[key]} by a note), "
                               f"{recs[key]} record(s) there")
    retried = 0                                                 # records the heartbeat's: beyond the timers, excused
    taken = set()                                               # (node, heartbeat, ask): each write excuses one
    beat_only = offer_recs == 0                                 # no on_offer recorded: the heartbeat alone
    how = "by the heartbeat alone" if beat_only else "held back"
    over = Counter()                                            # (node, chunk, t bits) -> records beyond the timers
    for key, r_ in recs.items():
        if arm[key] < r_:
            over[(key[0], chunk(key[1]), key[2])] += r_ - arm[key]
    many = sum(1 for (n, c, tb), x in over.items() if x > 1 and (n, tb) in heartbeats)
    capped = set()                                              # the cap, in either branch: the heartbeat retries
    for (n, c, tb), x in over.items():                          #   each chunk once, so two records beyond the
        if x > 1 and (n, tb) in heartbeats:                     #   timers at one (node, t) fail, across epochs too
            capped.add((n, c, tb))
            fails["K4"].append(f"node {n}: {x} retry_offer records for chunk {c} at {fl(tb)!r} beyond their timers at "
                               f"a heartbeat (at most one is the heartbeat's)")
    if beat_only:
        exc = Counter()                                         # (node, chunk, t bits) -> records a marker closed
        for key, r_ in recs.items():
            if arm[key] < r_:
                exc[(key[0], chunk(key[1]), key[2])] += min(bound[key], r_ - arm[key])
        for (n, c, tb), x in over.items():
            hb = min(1, exc[(n, c, tb)])                        # the heartbeat retries each chunk once
            retried += hb
            if x > hb and (n, c, tb) not in capped:
                fails["K4"].append(f"node {n}: {x} retry_offer record(s) for chunk {c} at {fl(tb)!r} beyond its "
                                   f"timers" + (f", 1 retried at a heartbeat, {how}" if hb else ""))
    else:
        for key, r_ in recs.items():
            if arm[key] < r_:
                hb = 0
                for h_ in sorted(held_at.get(key, ())):         # only records their node's next marker closed
                    if arm[key] + hb < r_ and (key[0],) + h_ not in taken:
                        taken.add((key[0],) + h_)
                        hb += 1
                retried += hb
                if arm[key] + hb < r_:
                    fails["K4"].append(f"node {key[0]}: {r_} retry_offer record(s) for {key[1]} at {fl(key[2])!r}, "
                                       f"{arm[key]} armed there"
                                       + (f", {hb} retried at a heartbeat, {how}" if hb else ""))
    nrec = sum(recs.values())
    multi = sum(1 for key, a in arm.items() if a > 1 and fl(key[2]) <= last)

    def line(check_, ok):
        if fails[check_]:
            out.append(f"timers_seacast: {check_} FAILS: {len(fails[check_])} failure(s)")
            out.extend(f"  {check_}: {w}" for w in fails[check_][:LIMIT])
        else:
            out.append(f"timers_seacast: {check_}: {ok}")

    line("K1", f"{whole} entries checked whole, {alone} by their notes alone (interest not read); {notes} asks armed")
    line("K2", f"{notes} notes, each delay max(0, known_at + START_DELAY - t) + 1e-6")
    line("K3", f"{notes - late_n} notes and {owns - late_o} own afters fire as retry_offer records at their due; "
               f"{late_n + late_o} due after the last record")
    k4how = f"({retried}, by the heartbeat alone)" if beat_only else f"for an ask held back ({retried})"
    line("K4", f"{nrec} retry_offer records, each armed, or retried at a heartbeat {k4how}: as many armed as records "
               f"at each key, {multi} keys with two or more armed")
    if beat_only:
        out.append(f"timers_seacast: held_back: {held_writes} writes; {retried} records retried at a heartbeat, by the "
                   f"heartbeat alone (the trace records no on_offer: at most one a chunk); {many} chunks at a heartbeat "
                   f"with two or more records beyond their timers")
    else:
        out.append(f"timers_seacast: held_back: {held_writes} writes; {retried} records retried at a heartbeat for an "
                   f"ask held back; {many} chunks at a heartbeat with two or more records beyond their timers")
    out.append(f"timers_seacast: enqueue: {enqueue_entries} entries, {enqueue_timed} with timers")
    out.append(f"timers_seacast: alarm_due: {alarm_notes} notes name it; promise_due: {promise_recs} records")
    out.append(f"timers_seacast: start: {start_notes} notes of kind start (a start inside a question)")
    out.append(f"timers_seacast: other notes: {dict(other) if other else 'none'}")
    if any(fails.values()):
        out.append(f"timers_seacast: the timers of deferred_offers FAIL on {path}")
        return 1
    out.append(f"timers_seacast: the timers of deferred_offers hold on {path}: {notes} notes, {owns} own afters, {nrec} "
               f"retry_offer records ({late_n + late_o} armed past the last record; {retried} retried at a heartbeat, "
               f"{how})")
    return 0


# --- the self-test: twenty-three small traces, one node (0), one row group G, START_DELAY 1.0 -----------------
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


def _retry_id(t, i):
    """A retry_offer record whose ask names chunk (G, i) by its structured id: group, index (4 bytes), 20 more."""
    return _rec(t, "retry_offer", (), [G + i.to_bytes(4, "little").hex() + "00" * 20])


def _held(t, i):
    """on_offer's record holding index i back: its write of held_back."""
    r = _rec(t)
    r["writes"] = [["held_back", [[G, i]], [G, i]]]
    return r


def _beat(t):
    """The heartbeat's drop_stale_waits record, after its retries."""
    return _rec(t, "drop_stale_waits", (), [])


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
    ("u9 a record at a heartbeat, its ask held back", [_held(0.25, 3), _retry(0.7, 3), _beat(0.7)], set()),
    ("u10 a record at a heartbeat, another ask held back", [_held(0.25, 4), _retry(0.7, 3), _beat(0.7)], {"K4"}),
    ("u11 two records at a heartbeat for one write", [_held(0.25, 3), _retry(0.7, 3), _retry(0.7, 3), _beat(0.7)],
     {"K4"}),
    ("u12 a record, its ask held back, no heartbeat", [_held(0.25, 3), _retry(0.7, 3)], {"K4"}),
    ("u13 a write an earlier heartbeat cleared", [_held(0.25, 3), _beat(0.5), _retry(0.7, 3), _beat(0.7)], {"K4"}),
    ("u14 no on_offer recorded, a record at a heartbeat", [_rec(0.25, "on_holding"), _retry(0.7, 3), _beat(0.7)],
     set()),
    ("u15 no on_offer recorded, two records at a heartbeat", [_rec(0.25, "on_holding"), _retry(0.7, 3),
                                                              _retry(0.7, 3), _beat(0.7)], {"K4"}),
    ("u16 no on_offer recorded, one chunk by index and by id at a heartbeat",
     [_rec(0.25, "on_holding"), _retry(0.7, 3), _retry_id(0.7, 3), _beat(0.7)], {"K4"}),
    ("u17 on_offer recorded, no write, a record at a heartbeat", [_rec(0.25), _retry(0.7, 3), _beat(0.7)], {"K4"}),
    ("u18 one key written twice in an epoch, two records at its heartbeat",
     [_held(0.25, 3), _held(0.5, 3), _retry(0.7, 3), _retry(0.7, 3), _beat(0.7)], {"K4"}),
    ("u19 a marker, then a hold and a record at its t (the record after the marker)",
     [_beat(0.7), _held(0.7, 3), _retry(0.7, 3)], {"K4"}),
    ("u20 two epochs closed at one t, a hold and a record in each",
     [_held(0.25, 3), _retry(0.7, 3), _beat(0.7), _held(0.7, 3), _retry(0.7, 3), _beat(0.7)], {"K4"}),
    ("u21 as u20, the second epoch left open",
     [_held(0.25, 3), _retry(0.7, 3), _beat(0.7), _held(0.7, 3), _retry(0.7, 3)], {"K4"}),
    ("u22 no on_offer recorded, a marker, then a record at its t",
     [_rec(0.25, "on_holding"), _beat(0.7), _retry(0.7, 3)], {"K4"}),
    ("u23 no on_offer recorded, two epochs closed at one t, a record in each",
     [_rec(0.25, "on_holding"), _retry(0.7, 3), _beat(0.7), _retry(0.7, 3), _beat(0.7)], {"K4"}),
]
# the header's document in either form and under its name before v0.12.0, u1's records: (name, args, exit)
HEADERS = [
    ("h1 --doc=seacast", ["--doc=seacast"], 0),
    ("h2 --doc v2 (before v0.12.0)", ["--doc", "v2"], 0),
    ("h3 --doc=v2", ["--doc=v2"], 0),
    ("h4 --doc lite", ["--doc", "lite"], 2),
    ("h5 --doc=v03 (before v0.12.0)", ["--doc=v03"], 2),
    ("h6 no --doc", [], 2),
]


def _write(p, records, args=("--doc", "seacast")):
    with gzip.open(p, "wt") as fh:
        fh.write(json.dumps({"content": "self-test"}) + "\n")
        fh.write(json.dumps({"header": {"args": list(args)}}) + "\n")
        fh.write(json.dumps({"nodes": [{"n": [0], "types": {"row": {"START_DELAY": bits(1.0)},
                                                            "payload": {"START_DELAY": 0}}}]}) + "\n")
        for r in records:
            fh.write(json.dumps(r) + "\n")
        fh.write(json.dumps({"trailer": {"records": len(records)}}) + "\n")


def self_test():
    good = 0
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "u.jsonl.gz")
        for name, records, must in CASES:
            _write(p, records)
            out = []
            rc = check(p, out)
            failed = {w.split()[1] for w in out if " FAILS: " in w}
            ok = rc == (1 if must else 0) and failed == must
            good += ok
            print(f"timers_seacast: self-test: {name}: exit {rc}, failed {sorted(failed) or 'none'}"
                  f"{'' if ok else ' <-- NOT as it must be: ' + str(sorted(must))}")
            if not ok:
                print("\n".join("    " + w for w in out))
        for name, args, want in HEADERS:
            _write(p, CASES[0][1], args)
            out = []
            rc = check(p, out)
            ok = rc == want and (want == 0 or any("not a trace under seacast.md" in w for w in out))
            good += ok
            print(f"timers_seacast: self-test: {name}: exit {rc}{'' if ok else f' <-- NOT as it must be: exit {want}'}")
            if not ok:
                print("\n".join("    " + w for w in out))
    total = len(CASES) + len(HEADERS)
    print(f"timers_seacast: self-test: {good} of {total} cases as they must be")
    return 0 if good == total else 1


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
