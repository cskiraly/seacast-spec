#!/usr/bin/env python3
"""The twin's files may not cite the notes they were developed beside: this repository faces the public, and a
section number of another document reads as one of the specification's. Every line that holds one of PATTERNS, or
where one stands across the break to the next line, is printed, with a count; the exit status is 1 where there is
any, 0 where there is none. A citation is rewritten as a statement in place.

A path is a directory or a file. A directory's files are read but those under `.lake/` and `__pycache__/`, each
line printed by the file's path under the directory; a file is read itself, printed by the path as given.

    python3 labcites.py [PATH ...]     each PATH, or formal/twin; asks git nothing
    python3 labcites.py --self-test    a clean tree, files and a directory given together, and a tree with a
                                       planted citation of each pattern per file kind and one that wraps a line
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout                                   # noqa: E402

# built from parts, so that this file holds neither pattern itself
PATTERNS = ("design" + " §", "notes" + "/")
SKIP = (".lake", "__pycache__")


LEAD = " \t-#*/"                              # leading spaces and comment marks, left out of a line read after the last


def lines_of(p, name):
    """(name, line number, line) of each line of the file p holding a pattern, or where a pattern stands across the
    break to the next line: this line's text without its end spaces, one space, then the next line's without its
    leading spaces and comment marks. None where p is not text."""
    try:
        text = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    lines = text.splitlines()
    out = []
    for n, line in enumerate(lines, 1):
        after = lines[n].lstrip(LEAD) if n < len(lines) else ""
        joined = line.rstrip() + " " + after
        if any(x in line or (x in joined and x not in after) for x in PATTERNS):
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
        (planted / "A" / "x.lean").write_text(
            f"-- see {D}6\ndef x := 1\n-- ({N}a/b.md)\n")
        (planted / "A" / "w.lean").write_text(        # a citation that wraps: "design" ends a line, its section starts the next
            f"/-- an empty list forwards on none ({D[:-2]}\n  {D[-1]}7). -/\ndef w := 1\n")
        (planted / "t.py").write_text(f"# {N}c.md\nprint(1)  # {D}4.4\n")
        md = Path(d) / "README.md"
        md.write_text(f"# The twin\nIts rules ({D}9).\n")
        given = (str(planted / "t.py"), str(clean), str(md))
        for name, paths, want in (
                ("clean", (clean,), []),
                ("files and a directory", given,
                 [(given[0], 1), (given[0], 2), (given[2], 2)]),
                ("planted", (planted,),
                 [("A/w.lean", 1), ("A/x.lean", 1), ("A/x.lean", 3), ("t.py", 1), ("t.py", 2)])):
            got = [(rel, n) for rel, n, _ in hits(*paths)]
            good = got == want
            ok &= good
            print(f"labcites self-test, {name}: {got}, must be {want}{'' if good else '  <-- FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    sys.exit(report(sys.argv[1:] or [layout.TWIN]))
