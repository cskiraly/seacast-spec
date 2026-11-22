#!/usr/bin/env python3
"""A cell with its payload type pull-only, traced: seacast.md §4.7's publish of a pull-only type (EAGER off),
which offers every chunk at publish (`offer_at_publish`) and which no cell of the toy's options reaches.

    python3 -I -S -B -X pycache_prefix=DIR pull_only.py TOYDIR OUT.jsonl.gz RUN-ARGS...     (RUN-ARGS with --doc seacast)

trace3.py's own run (its `main`), with one change: at the end of each node's construction, before the tracer's
install there, the node's payload type is made pull-only (`EAGER = False`), as the toy's pull_source_known.py makes
it after the sim is built. The tracer reads a type's parameters at the install, into the nodes line, so the change
is made before it: the nodes line gives `"EAGER": false` for every node's payload type. The header's `args` are the
run's, after this file's name, so that the trace does not read as the plain cell's.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import trace3                           # noqa: E402

PROG = "pull_only.py"


def main(argv):
    install, write = trace3.Tracer3.install, trace3.Tracer3.write

    def pull_only_install(self, nd, ns):
        if not self.doc_seacast:
            raise SystemExit(f"{PROG}: the run is not under --doc seacast, where a type's EAGER is read")
        nd._types["payload"].params.EAGER = False
        return install(self, nd, ns)

    def marked_write(self, obj):
        if "header" in obj:
            obj = {"header": {**obj["header"], "args": [PROG] + list(obj["header"]["args"])}}
        return write(self, obj)

    trace3.Tracer3.install, trace3.Tracer3.write = pull_only_install, marked_write
    trace3.main(argv)


if __name__ == "__main__":
    main(sys.argv[1:])
