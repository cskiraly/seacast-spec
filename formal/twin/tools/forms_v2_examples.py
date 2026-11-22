"""One example tape row per form of the questions the tracer writes under protocol-v2.md, made by the tracer's own
writers (trace3.py's questions_enc_v2, type_enc_v2, param_enc_v2, swr_v2): the 39 forms of v2's 36 questions
(`choice` has four, and `send` has a row for each kind of message it takes), and protocol.md's three questions in
the forms v2 asks them. Each line is the twin's form name (V2/Replay.lean's NodeV2), a tab, and the row,
[name, arguments, answer], as compact JSON. The replay reads each row with its question and refuses a wrong form of
each answer (`replay --forms FILE`, in check.sh's build step).

The leaves are well-formed, not a consistent state. A group, a narrow chunk of index 0 with its slot, root and id, and
a descriptor are read from a v2 trace: the first narrow chunk of index 0 and the first descriptor in the trace's
order. The second chunk is the first with index 1 (its id's index field changed); a node id is the toy's
(sim.peer_id(4)); the rest are made up here. check.sh's small step makes the file again from its own v2/hand5 trace
and compares it with tools/forms-v2-examples.tsv, so that the rows cannot drift from the writers.

    python3 forms_v2_examples.py TRACE.jsonl.gz > forms-v2-examples.tsv     # the rows, from a trace's leaves
    python3 forms_v2_examples.py --check FILE.tsv                           # FILE's rows made again from its leaves
"""
import gzip
import hashlib
import json
import sys
from pathlib import Path
from types import SimpleNamespace as NS

sys.path.insert(0, str(Path(__file__).resolve().parent))
import footprint as F                   # noqa: E402
import trace3                           # noqa: E402

c = lambda x: json.dumps(x, separators=(",", ":"))     # noqa: E731
HEX = set("0123456789abcdef")


def is_hex(x, n):
    return isinstance(x, str) and len(x) == n and set(x) <= HEX


def is_nat(x):
    return isinstance(x, int) and not isinstance(x, bool) and x >= 0


def narrow_chunk(x):
    return (isinstance(x, list) and len(x) == 5 and is_hex(x[0], 64) and is_nat(x[1]) and is_nat(x[2])
            and is_hex(x[3], 64) and is_hex(x[4], 112))


def descriptor(x):
    return isinstance(x, list) and len(x) == 7 and all(is_nat(v) for v in x[:6]) and is_hex(x[6], 64)


def first(tree, test):
    """The first value of `tree` (JSON, in its order, depth first) that passes `test`, or None."""
    if test(tree):
        return tree
    for v in (tree.values() if isinstance(tree, dict) else tree if isinstance(tree, list) else ()):
        hit = first(v, test)
        if hit is not None:
            return hit
    return None


def leaves_from_trace(path):
    """(the narrow chunk of index 0, the descriptor): each the first in the trace's records, in order."""
    f0 = d = None
    with gzip.open(path, "rt") as fh:
        for line in fh:
            rec = json.loads(line)
            f0 = f0 or first(rec, lambda x: narrow_chunk(x) and x[1] == 0)
            d = d or first(rec, descriptor)
            if f0 and d:
                return f0, d
    raise SystemExit(f"forms_v2_examples: {path}: no narrow chunk of index 0, or no descriptor")


def leaves_from_tsv(path):
    """The same two leaves, from a file's `verify` row: [T, f, h]."""
    for line in Path(path).read_text().splitlines():
        form, row = line.split("\t")
        if form == "verify":
            return json.loads(row)[1][1], json.loads(row)[1][2]
    raise SystemExit(f"forms_v2_examples: {path}: no verify row")


class Have:                             # the messages, by their class's name, as msg_v2 tells them apart
    def __init__(self, **kw):
        self.__dict__.update(kw)


class Want(Have):
    pass


class Graft(Have):
    pass


class Join(Have):
    pass


def rows(f0, d, w=None):
    """The rows, as (form name, the row's compact JSON), made by the writers of `w` (a Tracer3; a bare one by
    default, which needs no toy: every leaf here is a stub)."""
    w = w or trace3.Tracer3.__new__(trace3.Tracer3)
    G, idx, slot, ROOT, MID = f0
    assert idx == 0 and MID.startswith(G + "00000000"), f0
    g, root = bytes.fromhex(G), bytes.fromhex(ROOT)
    chunk = lambda i, mid: NS(group=g, index=i, slot=slot, beacon_block_root=root, mid=bytes.fromhex(mid))  # noqa
    fa, fb = chunk(0, MID), chunk(1, G + "01000000" + MID[72:])
    D = NS(version=d[0], hash_id=d[1], encoding=d[2], count=d[3], segment_size=d[4], total_length=d[5],
           root=bytes.fromhex(d[6]))
    P, COL, ROW = NS(id="payload"), NS(id="column"), NS(id="row")
    nid = hashlib.sha256(b"peer" + (4).to_bytes(4, "little")).digest()
    bits = lambda v: NS(v=v)            # noqa: E731
    have = Have(group=g, bits=bits(3), offer=False, claim_all=True, complete=False)
    offer = Have(group=g, bits=bits(3), offer=True, claim_all=False, complete=False)
    want = Want(group=g, bits=bits(1), standing=True, hops=1, probe=False)
    graft = Graft(object_type="column", family=5, colour=0, direction="OUT", answer=False)
    join = Join(object_type="column", interest="DERIVED", custody_count=4, duty="FORWARD", colours=1)
    c1, c2 = NS(id=7, families=[3, 40], high=False), NS(id=9, families=[12], high=True)
    fl = NS(id=7, families=[3, 40])
    block = NS(slot=1, body=NS(signed_execution_payload_bid=NS(message=NS(
        execution_payload_segment_group_id=g, execution_payload_segment_descriptor=D))))
    store = F.View(None, None, (g,), {})    # `chunks[g]`, a row of the node's store (decode's argument)
    q = w.questions_enc_v2(Have)
    ty = {t.id: w.type_enc_v2(t) for t in (P, COL, ROW)}
    pm = {t.id: w.param_enc_v2(t) for t in (P, COL, ROW)}
    swr_a, swr_r = w.swr_v2()
    # (form, tape name, its encoder, the Python answer, the Python arguments, keywords)
    table = [
        ("typeOfGroup", "type_of_group", q["type_of_group"], P, (g,), {}),
        ("typeOf", "type_of", q["type_of"], COL, ("column",), {}),
        ("indexCount", "index_count", ty["payload"]["index_count"], 2, (D,), {}),
        ("threshold", "threshold", ty["payload"]["threshold"], 1, (None,), {}),
        ("verify", "verify", ty["payload"]["verify"], "ACCEPT", (fa, D), {}),
        ("decode", "decode", ty["payload"]["decode"], {0: fa, 1: fb}, (store, D), {}),
        ("headerOf", "header_of", ty["payload"]["header_of"], D, (fa,), {}),
        ("project", "project", ty["payload"]["project"], [(g, 0)], (fa,), {}),
        ("cross", "cross", ty["column"]["cross"], [(g, 3)], (g, 0), {}),
        ("family", "family", ty["row"]["family"], -1, (g,), {}),
        ("derivedInterest", "derived_interest", ty["column"]["derived_interest"], bits(-1), (g, D, nid, join), {}),
        ("decodeAtK", "DECODE_AT_K", pm["row"]["DECODE_AT_K"], True, (g,), {}),
        ("decodeLater", "DECODE_LATER", pm["row"]["DECODE_LATER"], 1.5, (g,), {}),
        ("repairTo", "REPAIR_TO", pm["column"]["REPAIR_TO"], [4, 2], (g,), {}),
        ("send (a HAVE)", "send", q["send"], True, (4, have), {"urgent": True}),
        ("send (a WANT)", "send", q["send"], False, (4, want), {}),
        ("send (a relation)", "send", q["send"], True, (4, graft), {}),
        ("links", "links", q["links"], [2, 4, 7], (COL,), {}),
        ("linkCover", "link_cover", q["link_cover"], NS(families=[3, 40], high=True), (4, COL), {}),
        ("coverCandidates", "cover_candidates", q["cover_candidates"], [c1, c2], (COL,), {}),
        ("floorCandidates", "floor_candidates", q["floor_candidates"], [fl], (COL,), {}),
        ("floorLinks", "floor_links", q["floor_links"], [2, 4], (COL, 3), {}),
        ("highCustody", "high_custody", q["high_custody"], False, (4, COL), {}),
        ("families", "families", q["families"], range(3), (COL,), {}),
        ("familiesWithDuty", "families_with_duty", q["families_with_duty"], [3, 40], (COL,), {}),
        ("wantsFamily", "wants_family", q["wants_family"], True, (COL, 3), {}),
        ("dutyFor", "duty_for", q["duty_for"], "FORWARD", (g,), {}),
        ("routeNext", "route_next", q["route_next"], [2, 4], (COL, 3, [2, 4]), {}),
        ("blockOf", "block_of", q["block_of"], root, (g,), {}),
        ("groupOf", "group_of", q["group_of"], g, (block, D), {}),
        ("nodeId", "node_id", q["node_id"], nid, (4,), {}),
        ("interestSatisfied", "interest_satisfied", q["interest_satisfied"], False, (g,), {}),
        ("mergeWaiting", "merge_waiting", q["merge_waiting"], True, (4, have), {}),
        ("deferredOffers", "deferred_offers", q["deferred_offers"], [], (4, offer), {}),
        ("openGroupSource", "open_group_source", q["open_group_source"], None, (g, D), {}),
        ("openLink", "open_link", q["open_link"], None, (fl, COL), {}),
        ("openSamplingLink", "open_sampling_link", q["open_sampling_link"], None, (c1, COL), {}),
        ("choicePeer", "choice", q["choice"], 4, ([2, 4, 7],), {}),
        ("choiceOfSet", "choice", q["choice"], 7, ([7, 2],), {}),
        ("choiceNat", "choice", q["choice"], 1, ([0, 1],), {}),
        ("choiceCover", "choice", q["choice"], c2, ([c1, c2],), {}),
        # protocol.md's writers that v2 asks in another form
        ("validHaveV2", "valid_have", q["valid_have"], True, (have,), {}),
        ("sampleCovers", "sample_without_replacement", lambda r, xs, k: [swr_a(xs, k), swr_r(r)], [c2], ([c1, c2], 1),
         {}),
        ("shuffledPairs", "shuffled", q["shuffled"], [(1, fb), (0, fa)], ([(0, fa), (1, fb)],), {}),
    ]
    return [(form, c([name, *enc(r, *args, **kw)])) for form, name, enc, r, args, kw in table]


def main(argv):
    if argv[:1] == ["--check"] and len(argv) == 2:
        want = Path(argv[1]).read_text().splitlines()
        got = [f"{form}\t{row}" for form, row in rows(*leaves_from_tsv(argv[1]))]
        bad = [(a, b) for a, b in zip(want, got) if a != b] + ([("rows", f"{len(want)} != {len(got)}")]
                                                               if len(want) != len(got) else [])
        for a, b in bad:
            print(f"differs: {a[:120]}\n   made: {b[:120]}")
        print(f"forms_v2_examples: {len(got)} rows made again, {len(bad)} differ")
        return 1 if bad else 0
    if len(argv) != 1:
        raise SystemExit(__doc__)
    for form, row in rows(*leaves_from_trace(argv[0])):
        print(f"{form}\t{row}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
