#!/usr/bin/env python3
"""The control of the tracer's check of its own log (trace3.py's `account`) under seacast.md: views that let a write
through without logging it.

    python3 unlogged_seacast.py TOYDIR OUT.jsonl.gz [directed_seacast.py's arguments ...]

The run is directed_seacast.py's, but every fifth assignment to an entry through a view, inside a record, is made
in the toy's container and not logged (unlogged3.py's fault, for SEACAST's nodes). The tracer must stop, with a
non-zero exit code and a line that says the log does not account for the state after the call. If it writes its
trace to the end, the check of the log checks nothing under SEACAST.

What the control cannot show: a fault on an entry the call read before writing it shows as that entry's changed
value and is recorded as the write it is, so that fault alone does not stop the tracer. It stops at the first fault
on an entry the call wrote without reading it.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import directed_seacast                 # noqa: E402
import footprint as F                   # noqa: E402

N = [0]
_set = F.View.__setitem__


def setitem(self, k, v):
    if self._r.on and self._leaf():
        N[0] += 1
        if N[0] % 5 == 0:
            self._o[k] = F.unwrap(v)    # the fault: the write is made, and not logged
            return
    _set(self, k, v)


F.View.__setitem__ = setitem

if __name__ == "__main__":
    try:
        directed_seacast.main(sys.argv[1:])
    finally:
        print(f"unlogged_seacast: {N[0]} assignments through a view, {N[0] // 5} not logged", file=sys.stderr)
