#!/usr/bin/env python3
"""Is a format-7 trace of this tree's content, and of which kind?

    python3 header3.py TOYDIR TRACE [TRACE ...]

A trace's first line must be this tree's content line, byte for byte (content.py, made over TOYDIR, the documents
beside it and these tools): a trace kept from other tools, another toy or documents with other code is refused,
and the reason names the first name whose hash differs (a document's code, any other file's bytes). The replay makes the same comparison with the file it is given;
this one is made against the tree itself. cells3.py asks it of each trace it has just made.

What the replay does not check of the header, the second line: the tracer's name, and that the functions traced
(`traced`) are the block's (trace3.BLOCK), §6.1's twelve (TRACE3_ONLY=sec61), or, for a trace run with --doc seacast,
the block's names that are seacast-lite.md's all the way down (trace3.seacast_kept), computed here from TOYDIR's documents,
or §6.1's twelve; and that it claims the whole state exactly where it is a directed set's. Its tables (`own`,
`foreign`) are trace3.py's, or for a trace run with --doc seacast seacast.md's manifest's (`want`). Its envelope
is the one both readers hold it to: no member twice, nothing beside the header, no member trace3.py does not write,
the arguments a list of words, and a document word the toy takes (`lite` or `seacast`; a header written before
v0.12.0 names them `v03` and `v2`, and trace3.doc_of reads those as these). A trace that passes is printed with its
kind.

Exit code 0 when every trace passes; otherwise each trace's reasons are printed.
"""
import gzip
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import content                          # noqa: E402
import trace3                           # noqa: E402
import manifest_seacast                      # noqa: E402: gen/manifest_seacast.py (trace3.py puts gen/ on the path)


def want(seacast):
    """The header's fields every trace of these tools has, as trace3.py writes them: under --doc seacast the tables are
    seacast.md's manifest's (its own, seacast-lite.md's and SEACAST's, and its foreign), otherwise trace3.py's own."""
    if seacast:
        return {"format": 7, "tracer": "trace3.py", "own": list(manifest_seacast.OWN),
                "foreign": list(manifest_seacast.FOREIGN)}
    return {"format": 7, "tracer": "trace3.py", "own": list(trace3.OWN), "foreign": list(trace3.FOREIGN)}


KINDS = {tuple(sorted(trace3.BLOCK)): f"the block's {len(trace3.BLOCK)} functions",
         tuple(sorted(trace3.SEC61)): f"§6.1's {len(trace3.SEC61)} alone"}


def seacast_kept_of(toy):
    """SEACAST's kept names, sorted, from TOYDIR's documents, less §7.1's window: the toy's node.py makes their extracted
    code. gen.py holds the manifest's KEPT and NODE_OWN to it."""
    sys.path.insert(0, str(Path(toy).resolve()))
    import node                         # noqa: E402: the pinned toy, from TOYDIR
    return tuple(sorted(n for n in trace3.seacast_kept(trace3.BLOCK, node.SPEC_SRC, node.generate(node.DOC2))
                        if n not in trace3.SEC71))      # the window's six are not traced under SEACAST


def seacast_kind(toy):
    """What a SEACAST trace traces: SEACAST's kept names (seacast_kept_of) and its covered ones (the manifest's COVERED), sorted."""
    return tuple(sorted(set(seacast_kept_of(toy)) | set(manifest_seacast.COVERED)))


def kind_of(toy, traced, args):
    """The name of a traced list's kind, or None. A trace run with --doc seacast has two kinds, SEACAST's kept and §6.1's
    twelve (TRACE3_ONLY=sec61, whose traced names trace3.py does not hold to the manifest's KEPT), and a trace run
    without it never has SEACAST's kept: the block's list under --doc seacast does not pass."""
    t = tuple(traced) if isinstance(traced, list) else None
    if trace3.doc_of(args or []) == "seacast":           # the words of the trace's arguments: see trace3.doc_of
        if t is not None and t == tuple(sorted(trace3.SEC61)):
            return f"§6.1's {len(trace3.SEC61)} alone, under --doc seacast"
        return f"SEACAST's kept and covered, {len(t)} functions" if t is not None and t == seacast_kind(toy) else None
    return KINDS.get(t)


# the header's members, as trace3.py writes them (row_reads under --doc seacast alone), and the document words the toy's
# parser takes (run.py's --doc)
MEMBERS = ("format", "whole", "own", "foreign", "row_reads", "traced", "tracer", "args")
DOCS = ("lite", "seacast")


def head_lines(trace):
    """A trace's first line as text, its header (the second line) or the reason it has none, and what is wrong with
    the second line's envelope: a member twice at any depth (a JSON reader keeps one of the two, and another might
    keep the other), and a member beside the header. Read as bytes, so that a line end is compared as it was
    written: a text reader would turn a CRLF into an LF."""
    trace = Path(trace)
    twice = []

    def pairs(kv):
        seen = set()
        for k, _ in kv:
            if k in seen and k not in twice:
                twice.append(k)
            seen.add(k)
        return dict(kv)
    try:
        with (gzip.open(trace, "rb") if trace.suffix == ".gz" else open(trace, "rb")) as f:
            line1 = f.readline().decode("utf-8", "replace")
            second = json.loads(f.readline().decode("utf-8"), object_pairs_hook=pairs)   # UTF-8, as the tracer
            #                                   writes it: bytes given to json.loads would have their encoding guessed
    except (OSError, ValueError) as e:
        return None, None, f"its first two lines cannot be read: {e}", []
    h = second.get("header") if isinstance(second, dict) else None
    if not isinstance(h, dict):
        return line1, None, "no header on the second line", []
    env = [f"the second line holds a member twice: {k}" for k in twice]
    env += [f"the second line holds more than its header: {k}" for k in second if k != "header"]
    return line1, h, None, env


def header(trace):
    """A trace's header, or the reason it has none."""
    _, h, no, _ = head_lines(trace)
    return h, no


def content_why(toy, line1):
    """Why a trace's first line is not this tree's content line: nothing when it is."""
    mine = content.line(content.content(toy))
    if line1 == mine:
        return []
    try:
        got = json.loads(line1)
        d = content.diff(json.loads(mine), got)
    except (ValueError, KeyError, TypeError, AttributeError):
        return ["content: the first line is no content line"]
    return [f"content: not this tree's: {d[0]}" if d else "content: this tree's names and hashes, written otherwise"]


def check(toy, trace):
    """The reasons a trace's header is not as it must be: none when it is."""
    line1, h, no, env = head_lines(trace)
    if h is None:
        return [no]
    why = content_why(toy, line1) + env
    why += [f"header: a member trace3.py does not write: {k}" for k in h if k not in MEMBERS]
    # the arguments: a list of words, read as the empty list where they are not (the reason given), and a document
    # word, where they name one, that the toy's parser takes
    args = h.get("args", [])
    if not (isinstance(args, list) and all(isinstance(a, str) for a in args)):
        why.append(f"args: not a list of words: {json.dumps(args)[:60]}")
        args = []
    doc = trace3.doc_of(args)
    if doc is not None and doc not in DOCS:
        why.append(f"args: a document trace3.py does not write: {doc}")
    traced = h.get("traced")
    if kind_of(toy, traced, args) is None:
        why.append(f"traced: {traced!r}, must be the block's functions, §6.1's alone, or under --doc seacast SEACAST's kept "
                   "and covered or §6.1's alone, sorted")
    seacast = doc == "seacast"
    for name, v in want(seacast).items():
        got = h.get(name)
        if got == v:
            continue
        why.append(f"{name}: {got!r}, must be {v!r}")
    # the directed records hold the whole state, a cell's do not (directed42.py's, §4.2's; directed4b.py's, its
    # deferral path's)
    whole = args[:1] in (["directed3"], ["directed44"], ["directed42"], ["directed4b"], ["directed7"],
                                             ["directed1"], ["directed6o"], ["directed64"], ["directed64h"], ["directed46"], ["directed43"], ["directed41"], ["directed46d"], ["directed3v"], ["directed52"], ["directed53"], ["directed54"], ["directed71"], ["directed51"],
                                             ["directed_seacast"])   # among them §1's (directed1.py), seacast.md's (directed_seacast.py),
    #                                              drop_offer's (directed6o.py), §6.4's (directed64.py, directed64h.py), §4.6's (directed46.py), §4.3's (directed43.py), §4.1's (directed41.py), §4.6's decode's (directed46d.py), §3's (directed3v.py)
    if h.get("whole") is not whole:
        why.append(f"whole: {h.get('whole')!r}, must be {whole!r} for this kind of trace")
    # the rows the views read on the way down: under --doc seacast exactly trace3.ROW_READS_Seacast, and in no other trace
    if seacast and h.get("row_reads") != list(trace3.ROW_READS_Seacast):
        why.append(f"row_reads: {h.get('row_reads')!r}, must be {list(trace3.ROW_READS_Seacast)!r} under --doc seacast")
    if not seacast and "row_reads" in h:
        why.append(f"row_reads: {h['row_reads']!r} in a trace not run with --doc seacast")
    return why


def main(argv):
    bad = 0
    for t in argv[1:]:
        why = check(argv[0], t)
        bad += bool(why)
        h = header(t)[0]
        kind = "" if why else f", tracing {kind_of(argv[0], h['traced'], h.get('args'))}"
        print(f"{t}: {'as these tools and these documents' + kind if not why else '; '.join(why)}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
