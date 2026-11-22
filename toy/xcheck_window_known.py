#!/usr/bin/env python3
"""A known answer for `--xcheck`'s window invariant, under either document: no node holds more room in flight than
its window allows, and the line says so.

    python3 xcheck_window_known.py [--doc v2]

The check runs `check.py`'s push cell with `--xcheck` and reads every xcheck line it prints. On each line it asks
that `inv_window` is 0 and that `peak`, the most room any node of the line held in flight, is at most `w`, the
largest window of those nodes. `protocol.md` counts its window in slots of a chunk (`W`, `acquire_slot`), and
`protocol-v2.md` counts it in bytes (`W_BYTES`, `acquire_room`, §4.11), so under `protocol-v2.md` both numbers are
bytes. Before `xcheck.py` was fixed, its recorder read `in_flight` in bytes under `protocol-v2.md` but compared it
with `W` in slots, and it did not see `acquire_room`. Every honest node then counted as over its window
(`inv_window=59` on the lines of 59 nodes, `peak` about 800,000 against `w=69`), and this check failed under
`protocol-v2.md`.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CELL = ["--nodes", "60", "--degree", "30", "--msgs", "3", "--seed", "7", "--xcheck"]   # check.py's push cell
LINE = re.compile(r"^\s*xcheck@\d+ms \[([^\]]+)\]: .*$", re.M)          # run.py indents them by two spaces
FIELD = re.compile(r"\b(inv_window|peak|w)=(\d+)\b")


def main():
    if sys.argv[1:] not in ([], ["--doc", "v2"]):
        print("usage: xcheck_window_known.py [--doc v2]")
        return 2
    doc = sys.argv[1:]
    p = subprocess.run([sys.executable, "-B", "run.py", *CELL, *doc], cwd=HERE, capture_output=True, text=True)
    lines = [(m.group(1), dict((k, int(v)) for k, v in FIELD.findall(m.group(0)))) for m in LINE.finditer(p.stdout)]
    bad = [(name, f) for name, f in lines if f.get("inv_window") != 0 or f.get("peak", 0) > f.get("w", -1)]
    where = " under protocol-v2.md" if doc else ""
    print(f"push cell{where} with --xcheck: rc {p.returncode}, {len(lines)} xcheck lines, "
          f"peak at most {max((f.get('peak', 0) for _, f in lines), default=0)}, "
          f"w {sorted({f.get('w') for _, f in lines})}")
    for name, f in bad[:6]:
        print(f"  [{name}] inv_window={f.get('inv_window')} peak={f.get('peak')} w={f.get('w')}")
    ok = p.returncode == 0 and len(lines) >= 3 and not bad
    print("ok" if ok else "FAIL: a node over its window, a failed run, or fewer than 3 xcheck lines")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
