"""protocol-v2.md's tables (§3): the twin's v2 layer, one entry per table, beside schema.py's.

gen.py appends TABLES_V2 to schema.py's TABLES, so that State.lean, Tables.lean and ReplayTables.lean stay one
each, with one `Cell` (notes/spec-lean/v2-layer/design.md §4.1). A trace under protocol.md has none of these
entries, and they read as missing there. The list a protocol.md trace's header is checked against, `ownTables`,
stays schema.py's; these tables' names are `v2Tables`.

A table's codec follows from two things (design §4.4): what a read of a missing key does in the toy's container
(toy/node.py, `_v2`), and what the code observes of a stored value.
- **Written as missing.** The tracer writes no empty leaf, and the twin's state holds none, where the container
  reads a missing key as the empty value (`LazySet`, `LazyList`, `LazyBits`, `zero`, `false`, `DefaultMap`) and
  the code observes a leaf's content alone (membership, truth, length, iteration of the leaf). The kinds: `bits`,
  `count`, `int`, `peerset`, `flagset`, `bool`, `colours`, `relations`, `indices`, `gis`.
- **With presence.** A stored value is a value, empty or not, where the container raises on a missing key (a
  plain dict; the inner level of `lazy_dict`) or the code observes the key itself (`setdefault`, `.items()`, a
  pop that deletes a stored leaf). The kinds: `time`, `slot`, `typeid`, `ibits`, `join`, `opeerset`, `verdict`.

How a record writes them (design §4.4, agreed with the tracer):
- keys: a type id as its string (`"payload"`, `"column"`, `"row"`); a family as an integer, a natural number or
  `["-", n]`; a block id as 64 hex digits; `backoff`'s inner key as `[colour, direction]`, the direction `"OUT"`,
  `"IN"` or `"BOTH"`; a member of `probe_asks` as an ask key, as protocol.md's tables write one: an ask by index
  `[group, index]`, a structured id its hex digits;
- messages as tagged arrays in §2's field order: `["join", T, interest, custody_count, duty, colours]`,
  `["graft", T, family, colour, direction, answer]`, `["prune", T, family, colour, direction]`, enumerations as
  the toy's strings;
- an `IBits` as an integer in the same signed form; a time as its 64 bits; `probe_ok`'s verdict as `true`, `false`
  or `["none"]`;
- a set as a sorted list. That is a form for comparing states, not an order: where the code iterates a set, the
  order the Python took is on the tape (design §3.1's `order`), and the twin takes it from there.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))    # an isolated Python (-I) puts no directory there itself
from schema import TABLES, Scan, Table                    # noqa: E402

# kinds of value of v2's tables, as schema.py's VALUES (gen.py writes each kind's arms)
VALUES_V2 = {
    # an object type, by its id (`T_of[g]`): a plain dict, tested by `in`
    "typeid":    dict(lean="V2.TypeId", read="option", param="ty", val="typeId"),
    # a bitmap that can be complemented (`interest[g]`, `want_p[p][g]`), an integer in the signed form; a stored 0 is
    # a value (`interest`'s missing key asks `own_interest`, its stored 0 does not)
    "ibits":     dict(lean="V2.IBits", read="option", param="ib", val="ibits"),
    # a JOIN (`join_recv[p][T]`, `join_sent[p][T]`): the inner level of `lazy_dict`, where a missing key raises
    "join":      dict(lean="V2.Join", read="option", param="jn", val="join", parse="joinMsg"),
    # a set of colours (`push_out[p][T][fam]` and its three siblings), sorted; empty is no value
    "colours":   dict(lean="Std.HashSet Nat", read="default", default="{}", param="cs", val="colours",
                      empty="an empty set of colours"),
    # relation messages in order (`owed_relations[p]`); empty is no value
    "relations": dict(lean="List V2.Relation", read="default", default="[]", param="rs", val="relations",
                      parse="relationList", empty="an empty list of relations"),
    # a set of peers whose stored empty value is a value, in a table that keeps no rows (`claims[g]`, iterated by
    # `claims.items()`; `standing[g][i]`, deleted by a pop)
    "opeerset":  dict(lean="Std.HashSet Peer", read="option", param="ps", val="peers"),
    # `probe_ok[g]`: true, false, or a stored None (no verdict), apart from missing
    "verdict":   dict(lean="Option Bool", read="option", param="vd", val="verdict", parse="probeVerdict"),
    # a flag of a table of any number of keys (`lazy2(false)`): false is no value, as `flagset`'s
    "bool":      dict(lean="Bool", read="default", default="false", param="fl", val="flag"),
    # indices in order (`rsample[g]`); empty is no value
    "indices":   dict(lean="List Nat", read="default", default="[]", param="ixs", val="indices",
                      empty="an empty list of indices"),
    # groups and indices in order (`held_samples[b]`); empty is no value
    "gis":       dict(lean="List GI", read="default", default="[]", param="gs", val="gis", parse="giList",
                      empty="an empty list of groups and indices"),
}
# how a key of each of v2's Lean types is read from a record's path (ReplayBase.lean)
PARSE_V2 = {"V2.TypeId": "typeId", "V2.Fam": "intOf", "BlockId": "blockKey", "ColourDir": "colourDir"}

P, G, I = ("p", "Peer"), ("g", "Group"), ("i", "Nat")
TY, FAM, B = ("T", "V2.TypeId"), ("fam", "V2.Fam"), ("b", "BlockId")


def whole(level, doc, used=False, note=None):
    return Scan(f"all{level[0].upper()}{level[1:]}", level, doc, used=used, note=note)


def rel(name, field, what):
    """One of the four relation tables (`lazy3(LazySet)`): the colours per peer, type and family."""
    return Table(name, field, field, [P, TY, FAM], "colours",
                 read=(f"{field}Of", f"`{name}[p][T][fam]`: {what}"), write=(f"set{field[0].upper()}{field[1:]}",
                                                                             f"`{name}[p][T][fam].add(c)`, `.discard(c)`"),
                 scans=[whole(f"{field}All", f"every `{name}`", note=f"every `{name}[p][T][fam]`")])


TABLES_V2 = [
    # per link and object type
    Table("join_recv", "joinRecv", "joinRecv", [P, TY], "join",
          read=("joinRecv?", "`join_recv[p][T]`: what p declared to us, or none (a KeyError in the Python)"),
          write=("setJoinRecv", "`join_recv[p][T] = j`"),
          scans=[whole("joinRecvAll", "every `join_recv`", note="every `join_recv[p][T]`")]),
    Table("join_sent", "joinSent", "joinSent", [P, TY], "join",
          read=("joinSent?", "`join_sent[p][T]`: what we declared to p, or none (a KeyError in the Python)"),
          write=("setJoinSent", "`join_sent[p][T] = j`"),
          scans=[whole("joinSentAll", "every `join_sent`", note="every `join_sent[p][T]`")]),
    rel("push_out", "pushOut", "the colours we push p"),
    rel("push_in", "pushIn", "the colours p pushes us"),
    rel("grafted_out", "graftedOut", "the colours we offered to push p, unanswered"),
    rel("grafted_in", "graftedIn", "the colours we asked p to push us, unanswered"),
    Table("owed_relations", "owedRelations", "owedRelations", [P], "relations",
          read=("owedRelationsOf", "`owed_relations[p]`: the JOINs, GRAFTs and PRUNEs a full queue refused, in order"),
          write=("setOwedRelations", "`owed_relations[p]` after an append or a `pop(0)`"),
          scans=[whole("owedRelations", "every `owed_relations`")]),
    Table("backoff", "backoff", "backoff", [P, TY, FAM, ("cd", "ColourDir")], "time",
          read=("backoff?", "`backoff[p][T][fam].get((c, direction))`: until when we do not graft p, or none"),
          write=("setBackoff", "`backoff[p][T][fam][(c, direction)] = t`"),
          scans=[whole("backoffAll", "every `backoff`", note="every `backoff[p][T][fam][(c, direction)]`")]),
    # per group
    Table("T_of", "tOf", "tOf", [G], "typeid",
          read=("tOf?", "`T_of[g]`, as `g in T_of` or `T_of[g]`: the group's type, or none"),
          write=("setTOf", "`T_of[g] = T`"),
          scans=[whole("tOf", "every `T_of`")]),
    Table("rebuilt", "rebuilt", "rebuilt", [G], "bits",
          read=("rebuiltBits", "`rebuilt[g]`: the chunks from a decode"), write=("setRebuilt", "`rebuilt[g].set(i)`, `|=`"),
          scans=[whole("rebuilt", "every `rebuilt`")]),
    Table("interest", "interest", "interest", [G], "ibits",
          read=("interest?", "`interest[g]` where it is stored, or none (the Python then asks `own_interest(g)`)"),
          write=("setInterest", "`interest[g] = b`, `interest[g] |= b`"),
          scans=[whole("interest", "every `interest`")]),
    Table("known_at", "knownAt", "knownAt", [G], "time",
          read=("knownAt?", "`known_at[g]`, `known_at.setdefault(g, now)`: when the group id became known, or none"),
          write=("setKnownAt", "`known_at[g] = t`, `known_at.setdefault(g, now)` where it is missing"),
          scans=[whole("knownAt", "every `known_at`")]),
    Table("standing", "standing", "standing", [G, I], "opeerset",
          read=("standing?", "`standing[g][i]`, as `standing[g].pop(i, ())` reads it: the peers, or none"),
          write=("setStanding", "`standing[g][i].add(q)`"),
          erase=("eraseStanding", "`standing[g].pop(i, ())` where the entry is there"),
          scans=[whole("standingAll", "every `standing`", note="every `standing[g][i]`")]),
    Table("claims", "claims", "claims", [G], "opeerset",
          read=("claims?", "`claims[g]`: the peers whose claim_all arrived, or none where the group has no entry"),
          write=("setClaims", "`claims[g].add(q)`, `claims[g].discard(q)`: the entry stays, empty or not"),
          # claims_close's `claims.items()`: the groups' order is asked (design §3.2, `keys` of `claims`)
          ordered=True,
          scans=[whole("claims", "every `claims`: `claims.items()`", used=True)]),
    Table("reconsider_at", "reconsiderAt", "reconsiderAt", [G], "time",
          read=("reconsiderAt?", "`reconsider_at.get(g)`: when our later decode duty fires, or none"),
          write=("setReconsiderAt", "`reconsider_at[g] = at`"), erase=("eraseReconsiderAt", "`del reconsider_at[g]`"),
          scans=[whole("reconsiderAt", "every `reconsider_at`")]),
    Table("deferred", "deferred", "deferred", [G], "flagset",
          read=("deferred?", "`deferred[g]`"), write=("setDeferred", "`deferred[g] = True`, or `= False`"),
          scans=[whole("deferred", "every group deferred once on a claim")]),
    Table("duty_at", "dutyAt", "dutyAt", [G], "time",
          read=("dutyAt?", "`duty_at[g]`, `duty_at.get(g, now)`: the duty's own time, or none"),
          write=("setDutyAt", "`duty_at[g] = t`"),
          scans=[whole("dutyAt", "every `duty_at`")]),
    Table("waited", "waited", "waited", [G], "flagset",
          read=("waited?", "`waited[g]`"), write=("setWaited", "`waited[g] = True`, or `= False`"),
          scans=[whole("waited", "every group waited for once")]),
    Table("probe", "probe", "probe", [G], "slot",
          read=("probe?", "`probe[g]`: the index we asked a claimant for, or none"), write=("setProbe", "`probe[g] = i`"),
          scans=[whole("probe", "every `probe`")]),
    Table("probed", "probed", "probed", [G], "slot",
          read=("probed?", "`probed[g]`, `probed.get(g)`: the claimant we asked, or none"),
          write=("setProbed", "`probed[g] = q`"),
          scans=[whole("probed", "every `probed`")]),
    # an ask key, as protocol.md's tables keep one: `gated(a)` tests an ask by index or a structured id, two keys
    # even where they name one chunk
    Table("probe_asks", "probeAsks", "probeAsk", [("a", "Key")], "member",
          read=("probeAsk?", "`a in probe_asks`"), write=("setProbeAsk", "`probe_asks.add(a)`, or `.discard(a)`"),
          scans=[whole("probeAsk", "every member of `probe_asks`")]),
    Table("probe_sent", "probeSent", "probeSent", [G], "member",
          read=("probeSent?", "`g in probe_sent`"), write=("setProbeSent", "`probe_sent.add(g)`, or `.discard(g)`"),
          scans=[whole("probeSent", "every member of `probe_sent`")]),
    Table("probe_ok", "probeOk", "probeOk", [G], "verdict",
          read=("probeOk?", "`probe_ok[g]`, as `g in probe_ok` or `probe_ok[g]`: the verdict (a stored None too), or none"),
          write=("setProbeOk", "`probe_ok[g] = v`"),
          scans=[whole("probeOk", "every `probe_ok`")]),
    Table("rsample", "rsample", "rsample", [G], "indices",
          read=("rsampleOf", "`rsample[g]`: the repair sample's indices, in order"),
          write=("setRsample", "`rsample[g].append(i)`"),
          scans=[whole("rsample", "every `rsample`")]),
    Table("rsample_step", "rsampleStep", "rsampleStep", [G], "count",
          read=("rsampleStep", "`rsample_step[g]`"), write=("setRsampleStep", "`rsample_step[g] = n`"),
          scans=[whole("rsampleStep", "every `rsample_step`")]),
    Table("rsample_asked", "rsampleAsked", "rsampleAsked", [G, I], "peerset",
          read=("rsampleAskedOf", "`rsample_asked[g][i]`: the custodians a sampled cell was asked of"),
          write=("setRsampleAsked", "`rsample_asked[g][i].add(q)`"),
          scans=[whole("rsampleAskedAll", "every `rsample_asked`", note="every `rsample_asked[g][i]`")]),
    Table("rsample_final", "rsampleFinal", "rsampleFinal", [G], "flagset",
          read=("rsampleFinal?", "`rsample_final[g]`"), write=("setRsampleFinal", "`rsample_final[g] = True`, or `= False`"),
          scans=[whole("rsampleFinal", "every group whose last step's re-asks were waited for")]),
    # per peer and group
    Table("served", "served", "served", [P, G], "count",
          read=("servedCount", "`served[p][g]`: the chunks answered"), write=("setServed", "`served[p][g] += 1`"),
          scans=[whole("servedAll", "every `served`", note="every `served[p][g]`")]),
    Table("want_p", "wantP", "wantP", [P, G], "ibits",
          read=("wantP?", "`want_p[p].get(g)`: what p asked us for, or none (`EMPTY` in the Python)"),
          write=("setWantP", "`want_p[p][g] = b`"),
          scans=[whole("wantPAll", "every `want_p`", note="every `want_p[p][g]`")]),
    Table("probe_served", "probeServed", "probeServed", [P, G], "bool",
          read=("probeServed", "`probe_served[p][g]`"), write=("setProbeServed", "`probe_served[p][g] = True`"),
          scans=[whole("probeServedAll", "every `probe_served`", note="every `probe_served[p][g]`")]),
    Table("probe_answers", "probeAnswers", "probeAnswers", [P, G], "bits",
          read=("probeAnswerBits", "`probe_answers[p][g]`"), write=("setProbeAnswers", "`probe_answers[p][g].set(i)`, `.clear()`"),
          scans=[whole("probeAnswersAll", "every `probe_answers`", note="every `probe_answers[p][g]`")]),
    Table("probe_waiting", "probeWaiting", "probeWaiting", [G, P], "slot",
          read=("probeWaiting?", "`probe_waiting[g][p]`: p's first marked ask of the group, or none"),
          write=("setProbeWaiting", "`probe_waiting[g][p] = i`"), erase=("eraseProbeWaiting", "`del probe_waiting[g][p]`"),
          # serve_waiting_probe's `probe_waiting[g].items()`: a group's peers' order is asked (design §3.2)
          ordered_levels=[1],
          scans=[Scan("allProbeWaiting", "probeWaiting", "every `probe_waiting[g]`: `probe_waiting[g].items()`",
                      row=True, used=True),
                 whole("probeWaitingAll", "every `probe_waiting`", note="every `probe_waiting[g][p]`")]),
    # per block
    Table("sampled_from", "sampledFrom", "sampledFrom", [B], "peerset",
          read=("sampledFromOf", "`sampled_from[b]`: the peers asked for a sample of the block"),
          write=("setSampledFrom", "`sampled_from[b].add(q)`"),
          scans=[whole("sampledFrom", "every `sampled_from`")]),
    Table("samples_in_flight", "samplesInFlight", "samplesInFlight", [B], "int",
          read=("samplesInFlight", "`samples_in_flight[b]`: our second-phase sample asks in flight"),
          write=("setSamplesInFlight", "`samples_in_flight[b] += 1`, `-= 1`"),
          scans=[whole("samplesInFlight", "every `samples_in_flight`")]),
    Table("held_samples", "heldSamples", "heldSamples", [B], "gis",
          read=("heldSamplesOf", "`held_samples[b]`: second-phase asks waiting for room, in order"),
          write=("setHeldSamples", "`held_samples[b]` after an append or a `pop(0)`"),
          scans=[whole("heldSamples", "every `held_samples`")]),
    # per peer
    Table("forwarded", "forwarded", "forwarded", [P], "count",
          read=("forwardedCount", "`forwarded[p]`: routed requests from p passed on this slot"),
          write=("setForwarded", "`forwarded[p] += 1`"),
          scans=[whole("forwarded", "every `forwarded`")]),
]


def signed(n):
    """An integer as a record writes one: a natural number, or `["-", n]` below zero (design §4.4)."""
    if isinstance(n, bool) or not isinstance(n, int):
        raise TypeError(f"not an integer of a record: {n!r}")
    return n if n >= 0 else ["-", -n]


def type_id(T):
    """An object type, by its id: the toy's types carry it as `.id` (`"payload"`, `"column"`, `"row"`)."""
    tid = getattr(T, "id", None)
    if not isinstance(tid, str) or not tid:
        raise TypeError(f"not an object type with an id: {T!r}")
    return tid


DIRECTIONS = ("OUT", "IN", "BOTH")


def colour_dir(k):
    c, d = k
    if isinstance(c, bool) or not isinstance(c, int) or c < 0 or d not in DIRECTIONS:
        raise TypeError(f"not a colour and a direction: {k!r}")
    return [c, d]


def python_tables_v2(F, key, fbits, msg):
    """v2's tables as the Python tracer's schema lines (footprint.Table), as `schema.python_tables` gives
    protocol.md's: how each key and each value is written in a record. `key` writes an ask key as protocol.md's
    tables do (an ask by index `[group, index]`, a structured id its hex digits), `fbits` a float as its 64 bits,
    `msg` a JOIN, GRAFT or PRUNE as its tagged array (the tracer's, which knows the toy's messages)."""
    keyenc = {"Key": key, "Peer": int, "Group": lambda g: g.hex(), "Nat": int, "V2.TypeId": type_id,
              "V2.Fam": signed, "BlockId": lambda b: b.hex(), "ColourDir": colour_dir}

    def finite(t):                      # `--prune-backoff` is not validated: a non-finite leaf is refused here
        if not math.isfinite(t):
            raise ValueError(f"a time a record cannot hold: {t!r}")
        return fbits(t)

    valenc = {
        "time": finite,
        "slot": int,
        "bits": lambda b: b.v or None,
        "count": lambda n: n or None,
        "int": lambda n: None if n == 0 else signed(int(n)),
        "peerset": lambda s: sorted(s) or None,
        "flagset": lambda x: True if x else None,
        "member": lambda x: True,
        "typeid": type_id,
        "ibits": lambda b: signed(b.v),
        "join": msg,
        "colours": lambda s: sorted(s) or None,
        "relations": lambda l: [msg(m) for m in l] or None,
        "opeerset": lambda s: sorted(s),
        "verdict": lambda v: ["none"] if v is None else bool(v),
        "bool": lambda x: True if x else None,
        "indices": lambda l: [int(i) for i in l] or None,
        "gis": lambda l: [[g.hex(), int(i)] for g, i in l] or None,
    }
    out = []
    for t in TABLES_V2:
        out.append(F.Table(t.name, [keyenc[ty] for _, ty in t.keys], valenc[t.value], rows=bool(t.rows),
                           ordered=t.ordered, ordered_levels=t.ordered_levels, values_ordered=t.values_ordered,
                           presence_in=t.presence_in))
    return out


def self_test():
    """The encoders' known answers, with stand-ins for the toy's objects (an object type's `.id`, a `Bits`'s `.v`,
    an ask's `.group` and `.index`). The Lean side of the same forms: SpecTwin/V2/Codecs.lean."""
    import struct
    from types import SimpleNamespace as NS
    ok = True

    def case(what, got, want):
        nonlocal ok
        good = got == want
        ok &= good
        print(f"{what}: {got!r}" + ("" if good else f"  <-- must be {want!r}"))

    def raises(what, f, *a):
        nonlocal ok
        try:
            got = f(*a)
            ok = False
            print(f"{what}: {got!r}  <-- must be refused")
        except (TypeError, ValueError) as e:
            print(f"{what}: refused ({e})")

    class F:                                        # footprint.Table's arguments, kept
        class Table:
            def __init__(self, name, keys, value, **kw):
                self.name, self.keys, self.value, self.kw = name, keys, value, kw

    class WantIndex(NS):                            # the toy's ask by index, a stand-in
        pass

    def key(a):                                     # the tracer's ask key (trace61.py's `key`), over the stand-in
        if isinstance(a, WantIndex):
            return [a.group.hex(), a.index]
        if isinstance(a, bytes):
            return a.hex()
        raise TypeError(f"not an ask key: {a!r}")

    fbits = lambda t: struct.unpack("<Q", struct.pack("<d", t))[0]      # noqa: E731
    msg = lambda m: ["join", m.T, "ALL", 0, "NONE", 1]                   # noqa: E731: the tracer's, here a stand-in
    by = {t.name: t for t in python_tables_v2(F, key, fbits, msg)}
    names = [t.name for t in TABLES_V2]
    case("v2's tables", len(names), 36)
    case("no name twice, none of protocol.md's", sorted(set(names) - {t.name for t in TABLES}) == sorted(names), True)
    g, row = bytes(range(32)), NS(id="row")
    case("a family below zero", signed(-1), ["-", 1])
    case("a family of zero", signed(0), 0)
    raises("a bool as an integer", signed, True)
    case("a type id", type_id(row), "row")
    raises("a type without an id", type_id, NS(name="row"))
    case("backoff's key", [k(x) for k, x in zip(by["backoff"].keys, (3, row, -1, (0, "OUT")))],
         [3, "row", ["-", 1], [0, "OUT"]])
    raises("backoff's key with another direction", colour_dir, (0, "out"))
    case("backoff's leaf", by["backoff"].value(1.5), fbits(1.5))
    raises("backoff's leaf, infinite", by["backoff"].value, float("inf"))
    raises("backoff's leaf, not a number", by["backoff"].value, float("nan"))
    case("interest's 0, stored", by["interest"].value(NS(v=0)), 0)
    case("an IBits of every index but two", by["interest"].value(NS(v=-4)), ["-", 4])
    case("a set of colours", by["push_out"].value({2, 0}), [0, 2])
    case("an empty set of colours", by["push_out"].value(set()), None)
    case("claims' empty set, stored", by["claims"].value(set()), [])
    case("probe_ok's stored None", by["probe_ok"].value(None), ["none"])
    case("probe_served's False", by["probe_served"].value(False), None)
    case("rsample, in order", by["rsample"].value([3, 1, 2]), [3, 1, 2])
    case("held_samples", by["held_samples"].value([(g, 3)]), [[g.hex(), 3]])
    # an ask by index and a structured id that name one chunk are two members (a5's round t3)
    sid = g + (3).to_bytes(4, "little") + bytes(20)
    case("a member of probe_asks, by index", by["probe_asks"].keys[0](WantIndex(group=g, index=3)), [g.hex(), 3])
    case("a member of probe_asks, a structured id", by["probe_asks"].keys[0](sid), sid.hex())
    case("the two forms of one chunk's ask, apart",
         by["probe_asks"].keys[0](WantIndex(group=g, index=3)) != by["probe_asks"].keys[0](sid), True)
    # the levels whose iteration order the tracer puts on the tape (design §3.2's `keys` entries)
    case("claims' groups, ordered", (by["claims"].kw["ordered"], tuple(by["claims"].kw["ordered_levels"])), (True, ()))
    case("probe_waiting[g]'s peers, ordered",
         (by["probe_waiting"].kw["ordered"], tuple(by["probe_waiting"].kw["ordered_levels"])), (False, (1,)))
    case("no other v2 table ordered", sorted(t.name for t in TABLES_V2 if t.ordered or t.ordered_levels),
         ["claims", "probe_waiting"])
    case("samples_in_flight below zero", by["samples_in_flight"].value(-1), ["-", 1])
    case("owed_relations, empty", by["owed_relations"].value([]), None)
    case("a JOIN, by the tracer's encoder", by["join_recv"].value(NS(T="row")), ["join", "row", "ALL", 0, "NONE", 1])
    print("ok: every case as it must be" if ok else "cases NOT as they must be")
    return 0 if ok else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    print("usage: schema_v2.py --self-test", file=sys.stderr)
    sys.exit(2)
