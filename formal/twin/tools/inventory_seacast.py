#!/usr/bin/env python3
"""The calls summary held to the inventory: every trace it can meet, by class and need (formal/twin/inventory.tsv).

    python3 -I inventory_seacast.py --needs N [--partial] INVENTORY C-REACHED          the check
    python3 -I inventory_seacast.py --must --needs N [--partial] INVENTORY C-REACHED   the must lines whose need the
                                                                                       run had, a path a line
    python3 -I inventory_seacast.py --self-test                  thirty-six small cases it writes

N: the needs the run was invoked for, declared by its caller (check.sh, from its flags), never read from the output:
`-`, or das and seacastcells joined by commas, each at most once, in that order. --partial is required when N is
short of das,seacastcells, and refused with it: a run with fewer needs is a partial one, said twice.

INVENTORY: `#` lines are comments; every other line is `path TAB class TAB need TAB why`, sorted by its bytes, each
path once and without white space. class: must, stopped, plant or copy. need: `-` (every run), das or seacastcells.
C-REACHED: the calls summary's file, whose first line is `needs: WORDS`, the needs the run had (das and seacastcells,
each at most once, in that order), or `needs: -`; WORDS must be N's, with spaces. A trace there is read when it has a
line `PATH (format ...`, and skipped when it has a line `skipped: PATH: CLASS: WHY`; a skip line without a class has
none. A path read twice, or skipped twice, is refused.

The check, for each path:
- a listed path whose need the run had is present, read or skipped;
- a listed path whose need the run lacked is absent (a trace beyond the run's needs is one an earlier run left);
- a must path is read, and any other skipped with its own class;
- every path present is listed.
Exit 0 with one line when each holds, 1 with one line `inventory: NOT: PATH: WHY` for each path that fails, 2 with
`inventory: refused: WHY` for an inventory, a needs line or a declaration not in its form, or a needs line that is not
the declaration.
"""
import re
import sys
from collections import Counter

CLASSES = ("must", "stopped", "plant", "copy")
NEEDS = ("-", "das", "seacastcells")
WORDS = ("das", "seacastcells")      # the needs line's words, in their order


class Refused(Exception):
    pass


def read_inventory(text):
    """The inventory's lines, (path, class, need, why), in order; Refused where it is not in its form."""
    lines = []
    for i, line in enumerate(text.splitlines(), 1):
        if line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) != 4:
            raise Refused(f"line {i} has {len(f)} fields, not four")
        path, cls, need, why = f
        if not path or not why:
            raise Refused(f"line {i}: an empty path or why")
        if re.search(r"\s", path):          # the calls summary names a path by \S+
            raise Refused(f"line {i}: a path with white space: {path!r}")
        if cls not in CLASSES:
            raise Refused(f"line {i}: an unknown class: {cls}")
        if need not in NEEDS:
            raise Refused(f"line {i}: an unknown need: {need}")
        lines.append((path, cls, need, why))
    twice = sorted(p for p, n in Counter(p for p, *_ in lines).items() if n > 1)
    if twice:
        raise Refused(f"a path twice: {twice[0]}")
    paths = [p for p, *_ in lines]
    if paths != sorted(paths, key=lambda p: p.encode()):
        raise Refused("the paths are not sorted by their bytes")
    return lines


def needs_words(words, what=""):
    """The needs' words as a list, held to their grammar: ["-"], or das and seacastcells, each at most once, in that
    order. `what` begins a refusal's words."""
    if words != ["-"]:
        for w in words:
            if w not in WORDS:
                raise Refused(f"{what}an unknown needs word: {w!r}")
        if len(set(words)) != len(words):
            raise Refused(f"{what}a needs word twice")
        if words != [w for w in WORDS if w in words]:
            raise Refused(f"{what}the needs words out of their order")
    return words


def declared(arg, partial):
    """The declaration (--needs N, --partial) as the needs line's words with spaces."""
    words = needs_words(arg.split(","), "the declared needs: ")
    if words == list(WORDS) and partial:
        raise Refused("--partial with the full needs (das,seacastcells)")
    if words != list(WORDS) and not partial:
        raise Refused(f"a declaration short of the full needs (needs: {' '.join(words)}) without --partial")
    return " ".join(words)


def read_reached(text, decl):
    """(the needs line's words as written, the needs had, the paths read, {path skipped: its class or None}). The
    needs line must be the declaration `decl` (the words with spaces)."""
    lines = text.splitlines()
    if not lines or not lines[0].startswith("needs: "):
        raise Refused("the calls summary's first line is not its needs line")
    said = lines[0][len("needs: "):]
    words = needs_words(said.split(" "))
    if said != decl:
        raise Refused(f"the calls summary's needs line (needs: {said}) is not the declared needs (needs: {decl})")
    needs = set() if words == ["-"] else set(words)
    read, skipped = set(), {}
    for line in lines[1:]:
        if line.startswith("skipped: "):
            m = re.match(r"^skipped: (\S+): (\S+): (.+)$", line)
            p, c = (m.group(1), m.group(2)) if m else (line.split(" ")[1].rstrip(":"), None)
            if p in skipped:                # a summary names each trace once
                raise Refused(f"the calls summary skips {p} twice")
            skipped[p] = c
            continue
        m = re.match(r"^(\S+) \(format ", line)
        if m:
            if m.group(1) in read:
                raise Refused(f"the calls summary reads {m.group(1)} twice")
            read.add(m.group(1))
    return said, needs, read, skipped


def check(inv, needs, read, skipped):
    """The failing paths, each with why, in the paths' order; and the listed paths absent and not needed."""
    nots, absent = [], 0
    listed = {p: (cls, need) for p, cls, need, _ in inv}
    for p in sorted((read | set(skipped)) - set(listed), key=lambda p: p.encode()):
        nots.append((p, "not listed"))
    for p, cls, need, _ in inv:
        had = need == "-" or need in needs
        if p not in read and p not in skipped:
            if had:
                nots.append((p, f"listed with need {need}, which the run had, and absent"))
            else:
                absent += 1
            continue
        if not had:
            nots.append((p, f"listed with need {need}, which the run lacked, and present"))
        elif p in read and p in skipped:
            nots.append((p, "read and skipped"))
        elif p in read:
            if cls != "must":
                nots.append((p, f"listed as {cls}, read"))
        elif cls == "must":
            nots.append((p, f"listed as must, skipped ({skipped[p] or 'no class'})"))
        elif skipped[p] != cls:
            nots.append((p, f"listed as {cls}, skipped as {skipped[p] or 'no class'}"))
    return nots, absent


def run(inv_text, reached_text, out, needs_arg="das,seacastcells", partial=False):
    try:
        decl = declared(needs_arg, partial)
        inv = read_inventory(inv_text)
        said, needs, read, skipped = read_reached(reached_text, decl)
    except Refused as e:
        out.append(f"inventory: refused: {e}")
        return 2
    nots, absent = check(inv, needs, read, skipped)
    if nots:
        out.extend(f"inventory: NOT: {p}: {why}" for p, why in nots)
        return 1
    n = Counter(cls for _, cls, _, _ in inv)
    out.append(f"inventory: {len(inv)} lines ({n['must']} must, {n['stopped']} stopped, {n['plant']} plant, "
               f"{n['copy']} copy); needs: {said}; {len(read)} read and {len(skipped)} skipped, each as its line "
               f"says; {absent} not needed and absent")
    return 0


# --- the self-test: a small inventory, a summary that holds against it, and one change per case -----------------
INV = [("chains/a", "must", "-"), ("chains/b", "must", "das"), ("chains/c", "stopped", "-"),
       ("chains/d", "plant", "das"), ("chains/e", "copy", "-"), ("seacast/f", "must", "seacastcells")]
READ = ["chains/a", "chains/b", "seacast/f"]
SKIP = {"chains/c": "stopped", "chains/d": "plant", "chains/e": "copy"}
FULL = "needs: das seacastcells"


def inv_text(rows):
    return "# a comment\n" + "".join("\t".join(r) + "\n" for r in rows)


def reached_text(needs, read, skip):
    return "\n".join(([needs] if needs is not None else [])
                     + [f"{p} (format 7, doc seacast): 1 records; reached: x 1" for p in read]
                     + [f"skipped: {p}: {c}: why" if c else f"skipped: {p}: why" for p, c in skip.items()]) + "\n"


def without(read, skip, *paths):
    return [p for p in read if p not in paths], {p: c for p, c in skip.items() if p not in paths}


def cases():
    """(name, inventory text, summary text, exit, the path a NOT must name, or the refusal's words)."""
    base = (inv_text([r + ("why",) for r in INV]))
    out = [("the inventory and a summary that holds", base, reached_text(FULL, READ, SKIP), 0, None)]
    s = dict(SKIP, **{"chains/a": "stopped"})
    out.append(("a must line skipped", base, reached_text(FULL, [p for p in READ if p != "chains/a"], s), 1, "chains/a"))
    out.append(("a needed must line absent", base, reached_text(FULL, *without(READ, SKIP, "chains/a")), 1, "chains/a"))
    out.append(("a trace not listed, read", base, reached_text(FULL, READ + ["chains/z"], SKIP), 1, "chains/z"))
    out.append(("a trace not listed, skipped", base, reached_text(FULL, READ, dict(SKIP, **{"chains/z": "plant"})),
                1, "chains/z"))
    for p in ("chains/c", "chains/d", "chains/e"):
        r, s = without(READ, SKIP, p)
        out.append((f"a {SKIP[p]} line read", base, reached_text(FULL, r + [p], s), 1, p))
    out.append(("a skip with another class", base, reached_text(FULL, READ, dict(SKIP, **{"chains/d": "copy"})), 1,
                "chains/d"))
    # the needs filter: a line whose need the run lacked is absent; one whose need it had is present
    out.append(("das lines absent under needs: seacastcells", base,
                reached_text("needs: seacastcells", *without(READ, SKIP, "chains/b", "chains/d")), 0, None))
    out.append(("a das line absent under the full needs", base,
                reached_text(FULL, *without(READ, SKIP, "chains/b")), 1, "chains/b"))
    out.append(("seacastcells lines absent under needs: das", base,
                reached_text("needs: das", *without(READ, SKIP, "seacast/f")), 0, None))
    out.append(("a seacastcells line absent under the full needs", base,
                reached_text(FULL, *without(READ, SKIP, "seacast/f")), 1, "seacast/f"))
    out.append(("das and seacastcells lines absent under needs: -", base,
                reached_text("needs: -", *without(READ, SKIP, "chains/b", "chains/d", "seacast/f")), 0, None))
    out.append(("a - line absent under needs: -", base,
                reached_text("needs: -", *without(READ, SKIP, "chains/a", "chains/b", "chains/d", "seacast/f")), 1,
                "chains/a"))
    out.append(("a das line read under needs: seacastcells", base,
                reached_text("needs: seacastcells", *without(READ, SKIP, "chains/d")), 1, "chains/b"))
    out.append(("a das line skipped under needs: seacastcells", base,
                reached_text("needs: seacastcells", *without(READ, SKIP, "chains/b")), 1, "chains/d"))
    # refused: the inventory's form, then the needs line's
    good = reached_text(FULL, READ, SKIP)
    rows = [r + ("why",) for r in INV]
    out.append(("an inventory not sorted", inv_text([rows[1], rows[0]] + rows[2:]), good, 2, "not sorted"))
    out.append(("a path twice", inv_text(rows[:1] + rows), good, 2, "a path twice"))
    out.append(("an unknown class", inv_text([("chains/a", "read", "-", "why")] + rows[1:]), good, 2, "unknown class"))
    out.append(("an unknown need", inv_text([("chains/a", "must", "dass", "why")] + rows[1:]), good, 2, "unknown need"))
    out.append(("a line of three fields", inv_text([("chains/a", "must", "-")] + rows[1:]), good, 2, "3 fields"))
    out.append(("a line of five fields", inv_text([("chains/a", "must", "-", "why", "more")] + rows[1:]), good, 2,
                "5 fields"))
    out.append(("a path with white space", inv_text([("chains/a x",) + rows[0][1:]] + rows[1:]), good, 2,
                "a path with white space"))
    out.append(("no needs line", base, reached_text(None, READ, SKIP), 2, "not its needs line"))
    out.append(("a trace read twice", base, reached_text(FULL, READ + ["chains/a"], SKIP), 2,
                "reads chains/a twice"))
    out.append(("a trace skipped twice", base, good + "skipped: chains/c: stopped: why\n", 2,
                "skips chains/c twice"))
    out.append(("an unknown needs word", base, reached_text("needs: das cells", READ, SKIP), 2, "unknown needs word"))
    out.append(("a needs word twice", base, reached_text("needs: das das seacastcells", READ, SKIP), 2, "twice"))
    # the declaration (--needs, --partial): the needs line must be it, and it must be in its form
    seacast_only = reached_text("needs: seacastcells", *without(READ, SKIP, "chains/b", "chains/d"))
    out.append(("the line needs: seacastcells under the full declaration (an edited summary)", base, seacast_only, 2,
                "is not the declared needs", ("das,seacastcells", False)))
    out.append(("the full line under the declaration seacastcells, --partial", base, good, 2,
                "is not the declared needs", ("seacastcells", True)))
    out.append(("the declaration seacastcells without --partial", base, seacast_only, 2, "without --partial",
                ("seacastcells", False)))
    out.append(("the full declaration with --partial", base, good, 2, "--partial with the full needs",
                ("das,seacastcells", True)))
    out.append(("the declaration das,das", base, good, 2, "the declared needs: a needs word twice", ("das,das", True)))
    out.append(("the declaration seacastcells,das", base, good, 2, "the declared needs: the needs words out of their",
                ("seacastcells,das", False)))
    out.append(("an empty declaration", base, good, 2, "the declared needs: an unknown needs word", ("", True)))
    return out


def as_declared(reached):
    """A case's declaration where it gives none: its needs line's, where that line is in its form; else the full
    needs."""
    first = reached.split("\n", 1)[0]
    try:
        words = needs_words(first[len("needs: "):].split(" ")) if first.startswith("needs: ") else list(WORDS)
    except Refused:
        words = list(WORDS)
    return ",".join(words), words != list(WORDS)


def self_test():
    good = 0
    cs = cases()
    for name, inv, reached, want, what, *dec in cs:
        out = []
        rc = run(inv, reached, out, *(dec[0] if dec else as_declared(reached)))
        if want == 1:
            ok = rc == 1 and any(w.startswith(f"inventory: NOT: {what}: ") for w in out)
        elif want == 2:
            ok = rc == 2 and len(out) == 1 and out[0].startswith("inventory: refused: ") and what in out[0]
        else:
            ok = rc == 0 and len(out) == 1
        good += ok
        print(f"inventory_seacast: self-test: {name}: exit {rc}: {out[0] if out else 'no line'}"
              f"{'' if ok else f'  <-- NOT as it must be: exit {want}' + (f', naming {what}' if what else '')}")
    print(f"inventory_seacast: self-test: {good} of {len(cs)} cases as they must be")
    return 0 if good == len(cs) else 1


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    must = argv[:1] == ["--must"]
    if must:
        argv = argv[1:]
    partial = "--partial" in argv[2:3]
    if len(argv) != 4 + partial or argv[0] != "--needs":
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    needs_arg, (inv_path, reached_path) = argv[1], argv[2 + partial:]
    with open(inv_path) as f:
        inv_t = f.read()
    with open(reached_path) as f:
        reached_t = f.read()
    if must:
        try:
            decl = declared(needs_arg, partial)
            inv = read_inventory(inv_t)
            _, needs, _, _ = read_reached(reached_t, decl)
        except Refused as e:
            print(f"inventory: refused: {e}")
            return 2
        for p, cls, need, _ in inv:
            if cls == "must" and (need == "-" or need in needs):
                print(p)
        return 0
    out = []
    rc = run(inv_t, reached_t, out, needs_arg, partial)
    print("\n".join(out))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
