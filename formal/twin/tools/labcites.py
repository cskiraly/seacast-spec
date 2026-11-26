#!/usr/bin/env python3
"""The twin's files may not cite the notes they were developed beside, nor name the reviews, sessions and plans
behind them: this repository faces the public, a section number of another document reads as one of the
specification's, and a name from the work behind the files means nothing to their reader. Every line that holds
one of PATTERNS or of NAMES, or where one stands across the break to the next line, is printed, with a count; the
exit status is 1 where there is any, 0 where there is none. A citation is rewritten as a statement in place, and
a line with a name is rewritten without it.

PATTERNS are two strings. NAMES are seven regular expressions, matched case-sensitively: a review model's name;
the word for one who reviews; a session's handle or a branch name of the work; a short handle of a digit and a
hex letter before "'s"; a review round; a review label in parentheses; and a plan's piece. A guard by form misses
what has no form here: a short handle of digits alone, which reads as "card 10's" does; a handle under another
prefix; a name written another way; and a commit message, which no file holds.

What it reads is what it is given. check.sh gives it the twin's sources as the build copied them, tools/ with
gen/, and the prose beside them (every *.md but out/'s, record/'s and .lake/'s); it reads neither refine nor toy/.

A path is a directory or a file. A directory's files are read but those under `.lake/` and `__pycache__/`, each
line printed by the file's path under the directory; a file is read itself, printed by the path as given.

    python3 labcites.py [PATH ...]     each PATH, or formal/twin; asks git nothing
    python3 labcites.py --self-test    a clean tree with near misses of the names, files and a directory given
                                       together, and a tree with a planted citation of each pattern per file
                                       kind, a planted name of each kind, two of them in a tools/ .py file's
                                       comments, and a citation and a name that each wrap a line
"""
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout                                   # noqa: E402

# built from parts, so that this file holds neither pattern itself
PATTERNS = ("design" + " §", "notes" + "/")
# a model's name has one letter in brackets, so that this file does not hold the name itself; the others do not
# match their own text
NAMES = tuple(re.compile(x) for x in (
    r"\b(C[o]dex|F[a]ble|Cl[a]ude|O[p]us|S[o]nnet|G[P]T|G[e]mini)\b",               # a review model's name
    r"\b[Rr]eviewers?\b",                                                          # one who reviews
    r"\bfv-[0-9a-f]{2}\b|\b(segmentation-lab|spec-lean|protocol-v2)-[a-z0-9]",     # a handle, a branch name
    r"(^|[ (])(fv|[0-9][a-f]|[a-f][0-9])'s\b",                                     # a short handle
    r"\bround [a-z]?[0-9]+[a-z]?\b",                                               # a review round
    r"(^|\s)\((r[0-9]+[a-z]*|x[0-9][a-d]?|t[0-9]|s[0-9])\)",                       # a review label
    r"\bpiece [A-Z0-9]\b"))                                                        # a plan's piece
# each a test of a text: a pattern's, then a name's
MATCHERS = tuple((lambda s, x=x: x in s) for x in PATTERNS) + tuple(r.search for r in NAMES)
SKIP = (".lake", "__pycache__")


LEAD = " \t-#*/"                              # leading spaces and comment marks, left out of a line read after the last


def lines_of(p, name):
    """(name, line number, line) of each line of the file p holding a pattern or a name, or where one stands across
    the break to the next line and is not in that line itself: across the break is in this line's text without its
    end spaces, one space, then the next line's without its leading spaces and comment marks. None where p is not
    text."""
    try:
        text = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    lines = text.splitlines()
    out = []
    for n, line in enumerate(lines, 1):
        nxt = lines[n] if n < len(lines) else ""
        joined = line.rstrip() + " " + nxt.lstrip(LEAD)
        if any(m(line) or (m(joined) and not m(nxt)) for m in MATCHERS):
            out.append((name, n, line))
    return out


def found_in(paths):
    """(the path's place among those given, name, line number, line) of every line holding a pattern: the paths in
    the order given, a directory's files in path order."""
    out = []
    for k, given in enumerate(paths):
        root = Path(given)
        if root.is_file():
            out += [(k, *h) for h in lines_of(root, str(given))]
            continue
        for p in sorted(root.rglob("*")):
            rel = p.relative_to(root)
            if p.is_file() and not any(part in SKIP for part in rel.parts):
                out += [(k, *h) for h in lines_of(p, str(rel))]
    return out


def hits(*paths):
    """(name, line number, line) of every line holding a pattern: a directory's file by its path under the
    directory, a file by the path as given."""
    return [h[1:] for h in found_in(paths)]


def report(paths):
    found = found_in(paths)
    for _, name, n, line in found:
        print(f"{name}:{n}: {line.strip()}")
    files = len({(k, name) for k, name, _, _ in found})
    print(f"labcites: {len(found)} lines in {files} files")
    return 1 if found else 0


def self_test():
    ok = True
    D, N = "design" + " \u00a7", "notes" + "/"   # the plants, written apart from PATTERNS so that a wrong pattern fails
    with tempfile.TemporaryDirectory() as d:
        clean, planted = Path(d) / "clean", Path(d) / "planted"
        for t in (clean, planted):
            (t / "A").mkdir(parents=True)
            (t / "A" / "x.lean").write_text("-- the receive path (seacast.md §4.2)\ndef x := 1\n")
            (t / "A" / "v.lean").write_text("-- the twin's design\n-- of the receive path\ndef v := 1\n")
            (t / "t.py").write_text("# the notes of a function\nprint(1)\n")
            (t / ".lake").mkdir()
            (t / ".lake" / "skip.lean").write_text(f"-- {D}1 and {N}x, under .lake\n")
            (t / "A" / "u.lean").write_text(          # near misses of the names, hits in neither tree
                "-- a C1's bound (§4.10's), card 10's, depth(s1), a round trip, the reviewed text, a piece of it\n"
                "-- offers-15 and plant-d3\ndef u := 1\n")
        (planted / "A" / "x.lean").write_text(
            f"-- see {D}6\ndef x := 1\n-- ({N}a/b.md)\n")
        (planted / "A" / "w.lean").write_text(        # a citation that wraps: "design" ends a line, its section starts the next
            f"/-- an empty list forwards on none ({D[:-2]}\n  {D[-1]}7). -/\ndef w := 1\n")
        (planted / "t.py").write_text(f"# {N}c.md\nprint(1)  # {D}4.4\n")
        # a name of each kind, written with an `@` inside that the plant drops, so that this file holds none of them;
        # the last of A/n.lean's wraps: "piece" ends a line, its letter starts the next
        (planted / "A" / "n.lean").write_text(
            "-- as Co@dex found\ndef n := 1\n-- the review@er's ask\n-- spec-lean@-zz's rule\n-- in round@ 3\n"
            "/-- a list (r@2) -/\n-- the rest of piece\n-- D's lines\n".replace("@", ""))
        (planted / "tools").mkdir()
        (planted / "tools" / "n.py").write_text(         # names in a tools/ .py file's comments
            "import sys\n# d@9's case\nprint(1)  # piece@ E\n".replace("@", ""))
        md = Path(d) / "README.md"
        md.write_text(f"# The twin\nIts rules ({D}9).\n")
        given = (str(planted / "t.py"), str(clean), str(md))
        for name, paths, want in (
                ("clean", (clean,), []),
                ("files and a directory", given,
                 [(given[0], 1), (given[0], 2), (given[2], 2)]),
                ("planted", (planted,),
                 [("A/n.lean", 1), ("A/n.lean", 3), ("A/n.lean", 4), ("A/n.lean", 5), ("A/n.lean", 6),
                  ("A/n.lean", 7), ("A/w.lean", 1), ("A/x.lean", 1), ("A/x.lean", 3), ("t.py", 1), ("t.py", 2),
                  ("tools/n.py", 2), ("tools/n.py", 3)])):
            got = [(rel, n) for rel, n, _ in hits(*paths)]
            good = got == want
            ok &= good
            print(f"labcites self-test, {name}: {got}, must be {want}{'' if good else '  <-- FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    sys.exit(report(sys.argv[1:] or [layout.TWIN]))
