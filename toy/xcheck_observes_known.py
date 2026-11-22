#!/usr/bin/env python3
"""A known answer for `--xcheck`: the recorder that prints the harness's xcheck line only observes, under either
document. A run with `--xcheck` processes the same events as the same run without it.

    python3 xcheck_observes_known.py [--doc seacast]

The check runs `check.py`'s push cell twice with `--digest` (which hashes every event the simulator processes),
once with `--xcheck` and once without, and asks that both complete and give the same digest. xcheck wraps some of
the document's functions to count what they do (`xcheck.Recorder._wrap_node`); a wrapper that changed a call, or
did not take a call as the document makes it, would change the digest or stop the run. Under `seacast.md`, the
wrapper of `track_in_flight` took seacast-lite.md's two arguments, not the three of `seacast.md` (`need`, the room
the chunk takes), and the run with `--xcheck` stopped at the first chunk written: the check fails there.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CELL = ["--nodes", "60", "--degree", "30", "--msgs", "3", "--seed", "7", "--digest"]   # check.py's push cell
DIGEST = re.compile(r"^digest ([0-9a-f]{64})$", re.M)


def digest(args):
    p = subprocess.run([sys.executable, "-B", "run.py", *CELL, *args], cwd=HERE, capture_output=True, text=True)
    m = DIGEST.search(p.stdout)
    return p.returncode, (m.group(1) if m else None), (p.stderr.strip().splitlines() or [""])[-1]


def main():
    if sys.argv[1:] not in ([], ["--doc", "seacast"]):
        print("usage: xcheck_observes_known.py [--doc seacast]")
        return 2
    doc = sys.argv[1:]
    rc0, d0, _ = digest(doc)
    rc1, d1, err = digest(doc + ["--xcheck"])
    print(f"push cell{' under seacast.md' if doc else ''}: without --xcheck rc {rc0} digest {(d0 or '-')[:16]}; "
          f"with --xcheck rc {rc1} digest {(d1 or '-')[:16]}" + (f" ({err})" if rc1 else ""))
    ok = rc0 == 0 and rc1 == 0 and d0 is not None and d0 == d1
    print("ok" if ok else "FAIL: --xcheck changed the run or stopped it")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
