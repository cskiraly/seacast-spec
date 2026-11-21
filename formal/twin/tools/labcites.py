#!/usr/bin/env python3
"""The twin's files may not cite the notes they were developed beside: this repository faces the public, and a
section number of another document reads as one of the specification's. Every line of a file under formal/twin
(but `.lake/` and `__pycache__/`) that holds one of PATTERNS is printed, with a count; the exit status is 1 where
there is any, 0 where there is none. A citation is rewritten as a statement in place.

    python3 labcites.py [DIR]          DIR, or formal/twin; asks git nothing
    python3 labcites.py --self-test    a clean tree, and one with a planted citation of each pattern per file kind
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout                                   # noqa: E402

# built from parts, so that this file holds neither pattern itself
PATTERNS = ("design" + " §", "notes" + "/")
SKIP = (".lake", "__pycache__")


def hits(root):
    """(path relative to root, line number, line) of every line holding a pattern, in path order."""
    root = Path(root)
    out = []
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root)
        if not p.is_file() or any(part in SKIP for part in rel.parts):
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue                            # not text
        for n, line in enumerate(text.splitlines(), 1):
            if any(x in line for x in PATTERNS):
                out.append((str(rel), n, line))
    return out


def report(root):
    found = hits(root)
    for rel, n, line in found:
        print(f"{rel}:{n}: {line.strip()}")
    files = len({rel for rel, _, _ in found})
    print(f"labcites: {len(found)} lines in {files} files")
    return 1 if found else 0


def self_test():
    ok = True
    D, N = "design" + " \u00a7", "notes" + "/"   # the plants, written apart from PATTERNS so that a wrong pattern fails
    with tempfile.TemporaryDirectory() as d:
        clean, planted = Path(d) / "clean", Path(d) / "planted"
        for t in (clean, planted):
            (t / "A").mkdir(parents=True)
            (t / "A" / "x.lean").write_text("-- the receive path (protocol-v2.md §4.2)\ndef x := 1\n")
            (t / "t.py").write_text("# the notes of a function\nprint(1)\n")
            (t / ".lake").mkdir()
            (t / ".lake" / "skip.lean").write_text(f"-- {D}1 and {N}x, under .lake\n")
        (planted / "A" / "x.lean").write_text(
            f"-- see {D}6\ndef x := 1\n-- ({N}a/b.md)\n")
        (planted / "t.py").write_text(f"# {N}c.md\nprint(1)  # {D}4.4\n")
        for name, root, want in (("clean", clean, []),
                                 ("planted", planted, [("A/x.lean", 1), ("A/x.lean", 3), ("t.py", 1), ("t.py", 2)])):
            got = [(rel, n) for rel, n, _ in hits(root)]
            good = got == want
            ok &= good
            print(f"labcites self-test, {name}: {got}, must be {want}{'' if good else '  <-- FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    sys.exit(report(sys.argv[1] if sys.argv[1:] else layout.TWIN))
