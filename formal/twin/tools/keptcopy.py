#!/usr/bin/env python3
"""The kept copies' check: each function of `SpecTwin/Seacast/Kept.lean` is its original in seacast-lite.md's Lean, with the
named differences alone.

Under seacast.md the Python runs `on_pace_tick` and `on_block_installed` as seacast-lite.md writes them, and they
call SEACAST's `send_gossip` and `on_validated`, since the Python binds a name when it calls it. The twin binds a name
when the function is defined, so `Seacast/Kept.lean` holds a copy of each, written in SEACAST's monad and calling SEACAST's
functions. It also holds a copy of `respond`, whose IWANT a record under v2 writes in SEACAST's form, so that the copy
builds SEACAST's constructor. This check keeps each copy from drifting from its original.

    python3 keptcopy.py [--twin DIR]     the check: one line per function, then a closing line; exit 0 or 1
    python3 keptcopy.py --self-test      its own cases: each must give the verdict it states

For each function, the check takes the original's text from its `def` line to its last line (the line before the
next line at column 0 that is not blank, without the blank lines before it), and the copy's text the same way. It
applies each named difference to the original's text, as a replacement of one text by another, and fails if the
text to replace stands in the original a number of times other than the one stated. It then compares the result
with the copy's text, line by line, and fails on any difference, which it prints. A function missing on either
side fails too.
"""
import difflib
import sys
from pathlib import Path

TWIN = Path(__file__).resolve().parent.parent
COPY = "SpecTwin/Seacast/Kept.lean"

M2 = "the monad: M2"
V1 = "a function of seacast-lite.md's Lean, through lite"
LATE = "a call the Python binds late: SEACAST's function"
IWANT = "the IWANT it builds: SEACAST's, unmarked, its asks plain"

# the no-bid branch of on_block_installed: today's, never reached under seacast-lite.md, and SEACAST's, which enters ledger
NOBID_OLD = """\
  | none =>                                                 -- a block of columns: `ledger(None)` reads `offered`
    let _ ← connectedTopicPeers                             --   under a group no table has, and finds nothing.
    branch "on_block_installed: no group committed"         --   No record holds those reads (the tracer writes a
                                                            --   group's key), so none reaches this way"""
NOBID_NEW = """\
  | none =>                                                 -- a block of columns, reached under v2: the Python's
    enter "ledger"                                          --   `ledger(None)` is entered, asks the peers, and
    let _ ← connectedTopicPeers                             --   reads `offered[q][None]`, which the tracer does
    branch "on_block_installed: no group committed"         --   not write; no table holds a group of None, so
                                                            --   it returns no ask"""

# each copied function: its original's file, and the named differences as (what, old text, new text, times)
FUNCTIONS = {
    "paceTurns": ("SpecTwin/Sec64.lean", [
        (M2, "def paceTurns : Nat → M m Unit", "def paceTurns : Nat → M2 m Unit", 1),
        ("the context: seacast-lite.md's, as SEACAST's base", "      let ctx ← read\n", "      let ctx := (← read).base\n", 1),
        (LATE, "        sendGossip job.q job.ids", "        Seacast.sendGossip job.q job.ids", 1),
    ]),
    "onPaceTick": ("SpecTwin/Sec64.lean", [
        (M2, "def onPaceTick : M m Unit", "def onPaceTick : M2 m Unit", 1),
        (LATE, "  paceTurns (← paceJobs .jobs).length", "  Seacast.paceTurns (← paceJobs .jobs).length", 1),
    ]),
    "onBlockInstalled": ("SpecTwin/Sec42.lean", [
        (M2, "def onBlockInstalled (root : Root) : M m Unit", "def onBlockInstalled (root : Root) : M2 m Unit", 1),
        (V1, "(← messageId f)", "(← lite (messageId f))", 1),
        (LATE + " (SEACAST's on_validated takes no fuel)", "onValidated deferDepth p f (← validateChunk f)",
         "Seacast.onValidated p f (← lite (validateChunk f))", 1),
        (V1, "← popTiedRoot root", "← lite (popTiedRoot root)", 1),
        (V1, "        dropTie p g bits ", "        lite (dropTie p g bits) ", 1),
        (V1, "← N (← desc g)", "← lite (N (← desc g))", 1),
        (V1, "addOffer (.want g i) p", "lite (addOffer (.want g i) p)", 1),
        (V1, "← ledger g0", "← lite (ledger g0)", 1),
        (V1, "      retryOffer a\n", "      lite (retryOffer a)\n", 1),
        ("the no-bid branch: ledger entered", NOBID_OLD, NOBID_NEW, 1),
    ]),
    "respond": ("SpecTwin/Sec41.lean", [
        (M2, "def respond (p : Peer) (asks : List Key) (answers : List ChunkF) (prunes : Nat) : M m Unit",
         "def respond (p : Peer) (asks : List Key) (answers : List ChunkF) (prunes : Nat) : M2 m Unit", 1),
        (IWANT,
         "  let control : Option (List Ctl) := if !asks.isEmpty || prunes > 0 then some [.iwant asks, .prune] else none\n",
         "  let control : Option (List Ctl) :=\n"
         "    if !asks.isEmpty || prunes > 0 then some [.iwantSeacast false (asks.map fun k => { key := k }), .prune] else none\n",
         1),
    ]),
}


def body(text, name):
    """The function's text from its `def` line to its last line, or None if the text has no `def NAME`."""
    lines = text.split("\n")
    start = next((k for k, l in enumerate(lines) if l.startswith(f"def {name} ") or l == f"def {name}"), None)
    if start is None:
        return None
    end = next((k for k in range(start + 1, len(lines)) if lines[k] and not lines[k][0].isspace()), len(lines))
    while end > start and not lines[end - 1].strip():
        end -= 1
    return "\n".join(lines[start:end]) + "\n"


def check(texts):
    """The verdict on the copies, given each file's text by its path: (ok, lines)."""
    out, ok = [], True
    for name, (orig, diffs) in FUNCTIONS.items():
        o, c = body(texts[orig], name), body(texts[COPY], name)
        if o is None or c is None:
            out.append(f"keptcopy: {name}: no `def {name}` in {orig if o is None else COPY}")
            ok = False
            continue
        bad = False
        for what, old, new, times in diffs:
            n = o.count(old)
            if n != times:
                out.append(f"keptcopy: {name}: the difference \"{what}\" applies {n} times to {orig}, not {times}: "
                           f"{old.strip()!r}")
                bad = True
                continue
            o = o.replace(old, new)
        if not bad and o != c:
            out.append(f"keptcopy: {name}: the copy differs from its original ({orig}) beyond the named differences:")
            out += ["  " + l.rstrip("\n") for l in difflib.unified_diff(
                o.splitlines(True), c.splitlines(True), f"{orig} with the differences", COPY, n=1)]
            bad = True
        if bad:
            ok = False
        else:
            out.append(f"keptcopy: {name}: as its original ({orig}), with {len(diffs)} named differences")
    out.append(f"keptcopy: {len(FUNCTIONS)} copies as their originals" if ok else "keptcopy: FAIL")
    return ok, out


def read_texts(twin):
    paths = {COPY} | {orig for orig, _ in FUNCTIONS.values()}
    return {p: (twin / p).read_text() for p in paths}


def self_test():
    texts = read_texts(TWIN)

    def planted(path, old, new):
        t = dict(texts)
        assert t[path].count(old) == 1, (path, old)
        t[path] = t[path].replace(old, new)
        return t

    cases = [
        ("the tree as it is", texts, True, "keptcopy: 4 copies as their originals"),
        ("a copy changed in one more place", planted(COPY, 'branch "on_block_installed: a tie released"',
                                                     'branch "on_block_installed: a tie let go"'),
         False, "keptcopy: onBlockInstalled: the copy differs"),
        ("a copy without the no-bid branch's enter", planted(COPY, '    enter "ledger"   ', '                 '),
         False, "keptcopy: onBlockInstalled: the copy differs"),
        ("an original changed where no difference applies",
         planted("SpecTwin/Sec64.lean", 'branch "on_pace_tick: a stale job dropped"',
                 'branch "on_pace_tick: a stale job skipped"'),
         False, "keptcopy: paceTurns: the copy differs"),
        ("an original where a difference no longer applies",
         planted("SpecTwin/Sec42.lean", "    setPendingId (← messageId f) false                      --",
                 "    setPendingId (← messageIdOf f) false                    --"),
         False, "keptcopy: onBlockInstalled: the difference \"" + V1 + "\" applies 0 times"),
        ("a copy whose function is missing", planted(COPY, "def onPaceTick : M2 m Unit", "def onPaceTock : M2 m Unit"),
         False, "keptcopy: onPaceTick: no `def onPaceTick` in " + COPY),
    ]
    good = True
    for what, t, want_ok, want_line in cases:
        ok, out = check(t)
        hit = any(l.startswith(want_line) for l in out)
        fine = ok == want_ok and hit
        good &= fine
        print(f"keptcopy self-test, {what}: {'passes' if ok else 'fails'}, "
              f"{'with' if hit else 'WITHOUT'} the line {want_line!r}{'' if fine else '  <-- must be otherwise'}")
    print("ok: every case as it must be" if good else "keptcopy self-test: FAIL")
    return 0 if good else 1


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    twin = TWIN
    if argv[:1] == ["--twin"] and len(argv) == 2:
        twin = Path(argv[1]).resolve()
    elif argv:
        print(__doc__.split("\n\n")[1])
        return 2
    ok, out = check(read_texts(twin))
    print("\n".join(out))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
