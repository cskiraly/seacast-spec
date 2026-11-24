#!/bin/bash
# The quick check of the twin: the twin built from nothing, small traces of the toy replayed through it, and the
# controls, which must fail but for a few of the content line's, which must pass. About ten minutes on eight
# cores.
#
#   bash formal/twin/check.sh [--toy DIR] [--out DIR] [-j N] [--steps a,b,...]
#   bash formal/twin/record.sh [the same options]     the record's run: this script with --record (below)
#
# --toy    the toy's directory (default: SPEC_TOY, or the repository's toy/)
# --out    where everything it makes goes (default: formal/twin/out/check; removed first)
# -j       how many traces, or how many compilations, at a time (default: 4)
# --steps  only these steps, in this order, on what earlier runs left in --out (a part is no pass: it says so)
# `lake`, `lean` and `python3` are the ones on PATH. It runs under the caller's limits and writes its output under
# --out; the self-tests of content.py and matrixdiff.py write fixtures to the system's temporary directory, and
# matrixdiff.py's are left there.
#   perturbed a tracer that perturbs what the toy reads (perturb3.py), on the cell `push`: another digest than
#             golden.txt's, or the digests of the cells show nothing
# It asks git nothing: a trace names what it was made from by its content line (tools/content.py), and every replay
# here is given the line of this tree, made once at the start and once more at the end, which must be the same.
#
# The steps, and what each must show:
#   build     a copy of the twin's sources, built from nothing with `lake build replay SpecTwin.Seacast` (SpecTwin.Seacast for
#             the guard modules, Seacast/*Known.lean, whose #guards hold only where they are built; a copy of one with a
#             false #guard fails Lean, its control); twin-sources.txt: each
#             source file of the twin, this script and record.sh by sha256 (a link among them is refused; a
#             file whose name ends in .md, prose, is left out of the list); the copy, listed the same way, is
#             that list, and at the end of the run the sources and the copy still are; the forms of SEACAST's
#             questions, each row of tools/forms-seacast-examples.tsv read and refused by `replay --forms`, with its
#             three controls (a copy with one wrong row fails, its control)
#   selftests each tool's own cases (content.py, mutants3.py, altered3.py, commentsonly.py, fullid.py, against.py,
#             matrixdiff.py, trace3.py's of the names seacast.md keeps, gen/schema_seacast.py's encoders,
#             keptcopy.py's, labcites.py's, scan_bindings.py's, timers_seacast.py's, calls_seacast.py's and inventory_seacast.py's); and no line of the twin's sources (the
#             build's copy), of its tools or of the prose beside them (every *.md but out/'s and record/'s)
#             cites the notes beside which they were developed (labcites.py), a citation planted in
#             README.md's copy reported
#   tables    the twin's generated files are the schema's (gen.py, makers.py); Seacast/Kept.lean's copies of seacast-lite.md's
#             functions are their originals with the named differences alone (keptcopy.py); the record writers'
#             arities are runSeacast's cases', each count a case takes given by a stub call (records_seacast.py), with two
#             planted controls; the views' own cases (footprint_test.py)
#   scope     every function seacast-lite.md's code blocks define has its twin, by name: an `enter "NAME"` in SpecTwin/
#             and a case of the replay's for NAME; counted by section; a twin with one name taken away is refused.
#             And SEACAST's part: every name seacast.md's manifest covers has an `enter` in SpecTwin/Seacast/ and a case
#             of runSeacast, and runSeacast has no case the manifest does not cover but respond; two controls refused. And
#             SEACAST's questions, both ways: each name of the manifest's QUESTIONS is read by an askCall or a case of
#             the tape reader, and each name the twin asks or reads as a call under seacast.md is a question, a
#             covered or cut function, or the replay's own (keys, order); three controls refused
#   mutants   every mutant's text stands in the twin once (--places), and each type-checks alone against the build
#   screen    every cell's header and nodes line, under both documents, read by the replay; a nodes line without a
#             constant refused
#   cells     `none`, traced and replayed: its digest is golden.txt's (the tracer perturbs nothing)
#   small     hand5 (whole; §6.1's twelve alone; at PUBLISH), late16, and hand5 twice under seacast.md: each
#             traced and replayed, its digest the untraced run's with the same arguments
#   directed  the 22 directed sets, traced and replayed
#   replays   every replay above read a trace that is not empty, to its trailer, with no record mismatched and no
#             read of the Python's left unmade
#   headers   every trace's first line is this tree's content line, and its header of the kind its name says
#             (header3.py); hashes.txt: each trace's two hashes (the whole, and from its second line on)
#   picks     the replay's pick of a replaced name's records, and a directed set's draw (fixcontrols.py)
#   controls  each must FAIL, for its reason, but for the content line's cases that must pass (below): a mutant
#             that compiles (one record or more mismatched); altered
#             records, wrong content lines, headers and malformed nodes lines (altered3.py); a trace cut short; a trace of another tree, and a tracer started so that what runs
#             need not be what its content line names (contentcontrols.py). A build error or a tree it cannot
#             read fails the control, never passes it.
#
# With --record (record.sh): the record's run, hours on a server. The same steps under the same contract, and:
#   cells     every cell of the toy's check.py, not `none` alone: each digest golden.txt's, each replayed
#   seacastcells   every cell under seacast.md: each digest golden-seacast.txt's, each replayed (its records are of the
#             names that are seacast-lite.md's all the way down); the tracer's self-test of those names
#   schemacontrols   the schema's and the makers' checks on planted changes: each must fail them
#   viewcontrols     23 broken views, each failing its own count of the views' cases, as written here; and
#             views_control's own controls: three stubs of the test that fail otherwise than its own failure (a
#             line after the verdict, a line on stderr, exit code 2) refused, the plain one taken
#   tracercontrols   a tracer whose views let an assignment through unlogged, and 31 faults planted in the tracer:
#             each must stop it, with its own words; under SEACAST, ten plants that must not (five, and five controls),
#             each as written (a plant that replaces a function at a node: the nodes line with its chains set
#             aside, that node's chain the plant's), and the controls of the checks' own helpers; and a nodes
#             line without a replaced name's chain, which the replay must refuse with its words; and the chain
#             cases: the nodes line's chains on three cells against written cases (chaincases.py), each cell traced
#             and replayed, and five plants, each caught (owed_missing's observer by its replay too); and an answer
#             flipped by a layer the tracer lists (owed_missing's, on das-samplers): listed an observer, the replay
#             must refuse each record it flipped; listed as changing, the control, it must replay; and the swapped
#             draws: each layer's draws on the tape of a cell that enters it, and two plants on hand5 (the re-wrap
#             off, which the replay must refuse; the swap left unrestored, which must stop the tracer); and a record
#             writer whose arguments are not runSeacast's case's, on_chunk's without p, whose records the replay must
#             refuse, each and no other. With
#             --no-das: the DAS cells and the plants on them skipped, which each line says; the check is then a
#             part, not a pass
#   seeds     the same bytes whatever Python's hash seed, which is random in every process of an isolated Python:
#             every directed set made again twice, two cells once (46 traces)
#   sizes     sizes.txt: each of the record's traces as the tracer wrote it: bytes, lines, the longest line; and
#             full-id-keys.txt: its records that hold a chunk's full id anywhere but where one stands by design
#             (fullid.py): none in a cell's trace under either document, where the nodes ask by index
#   manifest  record-manifest.txt: the content line's sha256, the Python and the platform, each document's file
#             sha256 (for provenance: the content line names the documents by their code), and the two hashes of
#             each of the record's 55 traces (15 cells, three hand traces, 22 directed sets, 15 SEACAST cells)
# The steps `replays`, `headers` and the hashes then cover the record's traces.
# With --against DIR too (a record: a directory with a run's record-manifest.txt and content.line), a last step:
#   against   the run's manifest against the record's (against.py): as recorded; or another content and the same
#             bodies, with the files that differ; or not the record's, which fails the run
#
# With --matrix K/N (record.sh --matrix K/N): the Kth of N parts of the mutants' matrix, hours on a server each.
# The twin is built, the 15 cells, the hand traces and the 22 directed sets are traced and replayed as in the
# record's run (no cell under seacast.md: no mutant is replayed there), and then:
#   matrix    every Nth mutant from the Kth (mutants3.py --part), each built and replayed on the records that
#             reach its function or touch its table: first on the directed sets, where each must be told from
#             the twin; then on the 15 cells with hand5 and hand5-publish. In matrix/out: the two reports, a line
#             per mutant and trace for each (the pairs), the builds' hashes, and what ties a part to its traces
#             (the content line, the traces' two hashes, the replay's hash). `mutants3.py --merge OUT PART1 PART2 …`
#             reads the parts as one matrix and refuses parts that did not run the same content on the same traces.
# --cells "C1 C2 …" with --record: a rehearsal of the record's steps over these cells alone (or over none, with
# ""): every count is then of these, and its last line says it is no record.
# --sample drafts with it: a draft's run, never a matrix: every mutant of the part on the directed sets, and on the
# cells the drafts' sample alone (tools/sample_drafts.txt: each mutant with its reason; mutants3.py --sample-make,
# --sample-check); its part is marked (matrix/out/SAMPLE), and `mutants3.py --merge` refuses it.
# --rehearsal "M1 M2 …" with it: these mutants alone, on the hand traces and the directed sets alone (no cell):
# a trial of the step and of the merge (`mutants3.py --merge … --rehearsal M1,M2,…`), never a part of a matrix.
#
# With --v2steps (not with --record or --matrix, which run them all): the quick check and four of the record's steps,
# seacastcells, schemacontrols, viewcontrols and tracercontrols, with the 15 cells' SEACAST traces among those the steps
# replays and headers read; its pass is "check.sh: PASS (with seacastcells, schemacontrols, viewcontrols and
# tracercontrols)". Without it the steps and the traces are the quick check's.
#
# It prints "check.sh: PASS" and exits 0 only if every step ran and showed what it must.
set -u
HERE=$(cd "$(dirname "$0")" && pwd) || exit 2
ROOT=$(cd "$HERE/../.." && pwd) || exit 2
T=$HERE/tools
TOY=${SPEC_TOY:-$ROOT/toy}
OUT=$HERE/out/check
J=4
ALL="build selftests tables scope mutants screen cells small directed replays headers picks controls perturbed"
RECORD_ALL="build selftests tables scope mutants screen cells seacastcells small directed replays headers picks controls perturbed schemacontrols viewcontrols tracercontrols seeds sizes manifest"
MATRIX_ALL="build mutants cells small directed replays headers matrix"
RECORD=
PART=
REHEARSAL=
SAMPLE=
FEWCELLS=
CELLS_GIVEN=
AGAINST=
STEPS=
V2STEPS=
NODAS=
while [ $# -gt 0 ]; do
  case "$1" in
    --toy) TOY=$2; shift ;;
    --out) OUT=$2; shift ;;
    -j) J=$2; shift ;;
    --steps) STEPS=$(echo "$2" | tr ',' ' '); shift ;;
    --record) RECORD=1 ;;
    --matrix) RECORD=1; PART=$2; shift ;;
    --rehearsal) REHEARSAL=$2; shift ;;
    --sample) SAMPLE=$2; shift ;;
    --cells) FEWCELLS=yes; CELLS_GIVEN=$2; shift ;;
    --against) AGAINST=$2; shift ;;
    --v2steps) V2STEPS=1 ;;
    --no-das) NODAS=1 ;;
    *) echo "usage: check.sh [--record | --matrix K/N [--rehearsal \"M1 M2 ...\"] | --v2steps] [--toy DIR] [--out DIR] [-j N] [--steps a,b,...] [--no-das]"; exit 2 ;;
  esac
  shift
done
TOY=$(cd "$TOY" 2> /dev/null && pwd) || { echo "check.sh: no toy at $TOY"; exit 2; }
[ -f "$TOY/run.py" ] || { echo "check.sh: no toy at $TOY (no run.py there)"; exit 2; }
export SPEC_TOY=$TOY
[ -z "$RECORD" ] || { ALL=$RECORD_ALL; [ "$OUT" != "$HERE/out/check" ] || OUT=$HERE/out/record; }
if [ -n "$AGAINST" ]; then
  [ -n "$RECORD" ] || { echo "check.sh: --against goes with --record"; exit 2; }
  AGAINST=$(cd "$AGAINST" 2> /dev/null && pwd) || { echo "check.sh: no record at the directory given with --against"; exit 2; }
  ALL="$ALL against"
fi
if [ -n "$V2STEPS" ]; then     # the quick check, the record's two steps of the tracer under seacast.md, and the
  #                              schema's and the views' controls, in RECORD_ALL's order
  [ -z "$RECORD" ] || { echo "check.sh: --v2steps goes without --record or --matrix"; exit 2; }
  ALL="build selftests tables scope mutants screen cells seacastcells small directed replays headers picks controls perturbed schemacontrols viewcontrols tracercontrols"
fi
if [ -n "$PART" ]; then
  case "$PART" in [1-8]/[1-8]) ;; *) echo "check.sh: --matrix K/N, with N from 1 to 8 and K from 1 to N"; exit 2 ;; esac
  ALL=$MATRIX_ALL; [ "$OUT" != "$HERE/out/record" ] || OUT=$HERE/out/matrix-${PART%/*}-of-${PART#*/}
  [ -z "$REHEARSAL" ] || ALL="build small directed matrix"
  case "$SAMPLE" in ""|drafts) ;; *) echo "check.sh: --sample is drafts"; exit 2 ;; esac
elif [ -n "$REHEARSAL" ]; then echo "check.sh: --rehearsal goes with --matrix K/N"; exit 2
elif [ -n "$SAMPLE" ]; then echo "check.sh: --sample goes with --matrix K/N"; exit 2; fi
[ -n "$STEPS" ] || STEPS=$ALL
for s in $STEPS; do case " $ALL " in *" $s "*) ;; *) echo "check.sh: no step $s (the steps: $ALL)"; exit 2 ;; esac; done
if [ "$STEPS" = "$ALL" ]; then rm -rf "$OUT"; fi
mkdir -p "$OUT/traces" "$OUT/directed" "$OUT/seacast" || exit 2
OUT=$(cd "$OUT" && pwd)
LOG=$OUT/check.txt
REPLAY=$OUT/twin/.lake/build/bin/replay
CONTENT=$OUT/content.line               # this tree's content line: what every replay here is given
case "$OUT" in *[[:space:]]*) echo "check.sh: --out has white space in its path: $OUT"; exit 2 ;; esac
# every Python here runs isolated (-I: no PYTHONPATH, no user site), with no site directory, writing no bytecode,
# and looking for bytecode under a directory that stays empty: the tracers refuse to start otherwise (trace3.py)
rm -rf "$OUT/pyc"; mkdir -p "$OUT/pyc" || exit 2
PY="python3 -I -S -B -X pycache_prefix=$OUT/pyc"
PYPLAIN="python3 -E -s -S -B"           # the toy run as its own program, untraced: its directory is on its path
fail=
no() { echo "  FAIL: $*"; fail="$fail $step"; }
has() { grep -q "$@"; }                 # has [-x|-E] PATTERN FILE

DIRS="directed directed44 directed44u directed42 directed4b directed7 directed7u directed1 directed6o directed64 directed64h directed46 directed43 directed41 directed46d directed3v directed52 directed53 directed54 directed7p directed71 directed51"
dirtool() {             # a directed set's tool, and its own options
  case $1 in
    directed) echo "directed3.py" ;; directed44u) echo "directed44.py --no-limits" ;;
    directed7) echo "directed7.py --cards on" ;; directed7u) echo "directed7.py --cards off" ;;
    directed7p) echo "directed7.py --source-offers publish" ;;
    *) echo "$1.py" ;;
  esac
}
HAND5="--nodes 5 --degree 4 --msgs 1 --payload 16384 --seed 7"
DAS30="--nodes 30 --degree 8 --msgs 1 --setting rows --supernodes 10 --blobs 4 --seed 7 --doc seacast"   # the chain cases'
LATE16="--nodes 16 --degree 8 --msgs 2 --seed 7 --late-block 30,400"
CELLS="announce cap-wait dcb20 hold ihave-limits late-block loss-thin none push push-deep rr-stripe silent withholders without-a without-b"
ALLCELLS=$CELLS         # every cell: the calls summary's need seacastcells is all of them, made into this OUT
if [ -n "$FEWCELLS" ]; then
  [ -n "$RECORD" ] && [ -z "$PART" ] || { echo "check.sh: --cells goes with --record"; exit 2; }
  for c in $CELLS_GIVEN; do case " $CELLS " in *" $c "*) ;; *) echo "check.sh: no cell $c"; exit 2 ;; esac; done
  CELLS=$CELLS_GIVEN
fi
SEEDCELLS=$(for c in withholders loss-thin; do case " $CELLS " in *" $c "*) echo "$c" ;; esac; done)   # traced twice
SMALL="traces/late16 seacast/hand5 seacast/hand5-own seacast/hand5-publish"         # the check's small traces that are not the record's
if [ -z "$RECORD" ]; then
  TRACES="traces/none traces/hand5 traces/hand5-sec61 traces/late16 traces/hand5-publish seacast/hand5 seacast/hand5-own seacast/hand5-publish $(for d in $DIRS; do echo "directed/$d"; done)"
elif [ -n "$PART" ]; then       # a matrix part: the record's traces but the cells under seacast.md
  RTRACES="$(for c in $CELLS; do echo "traces/$c"; done) traces/hand5 traces/hand5-sec61 traces/hand5-publish $(for d in $DIRS; do echo "directed/$d"; done)"
  TRACES="$RTRACES $SMALL"
else                    # the record's 55, then the three small ones
  RTRACES="$(for c in $CELLS; do echo "traces/$c"; done) traces/hand5 traces/hand5-sec61 traces/hand5-publish $(for d in $DIRS; do echo "directed/$d"; done) $(for c in $CELLS; do echo "seacast/$c"; done)"
  TRACES="$RTRACES $SMALL"
fi
[ -z "$V2STEPS" ] || TRACES="$TRACES $(for c in $CELLS; do echo "seacast/$c"; done)"    # seacastcells' traces, read too

replay_of() {           # $1: a trace, without its .jsonl.gz: replayed to $1.replay; the status is the replay's, kept in
  zcat "$OUT/$1.jsonl.gz" | "$REPLAY" --content "$CONTENT" > "$OUT/$1.replay" 2>&1      #   $1.replay.rc
  local rc=${PIPESTATUS[1]}
  echo "$rc" > "$OUT/$1.replay.rc"
  return "$rc"
}
parsed_whole() {        # $1: a replay's report: no line its strict reader or its parser refused (Main.lean's two phrases)
  [ -f "$1" ] && ! has -E '^(lines refused before they were parsed|line [0-9]+: not a line the tracer writes)' "$1"
}
digest_of() { sed -n '/^digest /{s/^digest \(.\{16\}\).*/\1/p;q}' "$1"; }
bare_none() { [ "$(cat "$1.bare.json" 2> /dev/null)" = "{}" ]; }     # $1: a SEACAST trace: its run counted no bare call
extra_records() {       # $1: a trace; $2: another; $3: a node; $4: a function; $5: k: the second's body is the first's,
  $PY - "$@" <<'EOF'    #   in order, with exactly k records inserted, each of that function at that node, and its
import gzip             #   trailer the first's with those k counted, nothing else changed. [$6 $7 $8: a node, a name
import json             #   and a chain (JSON): the nodes line judged with its chains set aside, that node's chain of
import sys              #   that name the given one; without them, the nodes line the first's byte for byte]
a_p, b_p, node, fn, k = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], int(sys.argv[5])
spec = sys.argv[6:]


def body(p):            # an unreadable file (a CRC error too) raises here, and the check fails
    with gzip.open(p, "rt") as f:
        lines = f.read().splitlines()[1:]
    return lines[:-1], json.loads(lines[-1])["trailer"]


def inserted(line):
    try:
        r = json.loads(line)
    except ValueError:
        return False
    return isinstance(r, dict) and r.get("fn") == fn and int(r.get("n", -1)) == node


def canon(x):           # a value as JSON writes it, keys sorted: false and 0, or 1 and 1.0, are not the same here
    return json.dumps(x, sort_keys=True)


def nodes_rule(la, lb):
    """The nodes line. Without a spec, the first's byte for byte. With one, each entry's `chains` set aside and
    nothing else: the rest equal as JSON values (a Boolean is no number); every entry's chains the first's, but the
    planted node's chain of the name, which is the spec's (a plant's own function there: the chain tells the truth
    about the code at that node). The spec's node is in exactly one entry of each line."""
    if not spec:
        return None if la == lb else "the nodes line differs from the first's"
    cnode, cname, cwant = int(spec[0]), spec[1], json.loads(spec[2])
    ea, eb = json.loads(la)["nodes"], json.loads(lb)["nodes"]
    for es in (ea, eb):
        k = sum(cnode in e["n"] for e in es)
        if k != 1:
            return (f"the spec's node {cnode} is in no entry of the nodes line" if k == 0 else
                    f"the spec's node {cnode} is in {k} entries of the nodes line")
    ca, cb = [e.pop("chains", None) for e in ea], [e.pop("chains", None) for e in eb]
    if canon(ea) != canon(eb):
        return "the nodes line differs outside its chains"
    for e, x, y in zip(ea, ca, cb):
        if cnode in e["n"]:
            got = (y or {}).get(cname)
            if canon(got) != canon(cwant):
                return f"the planted node's chain of {cname} is {json.dumps(got)}, not {json.dumps(cwant)}"
            x, y = {n: c for n, c in (x or {}).items() if n != cname}, {n: c for n, c in (y or {}).items() if n != cname}
        if canon(x) != canon(y):
            return "a chain other than the planted node's differs from the first's"
    return None


a, ta = body(a_p)
b, tb = body(b_p)
i = extra = 0
why = nodes_rule(a[1], b[1]) if len(a) > 1 and len(b) > 1 else "a trace without its nodes line"
a, b = a[:1] + a[2:], b[:1] + b[2:]     # the header, then the records: the nodes line judged above
for line in b if why is None else ():   # b is a, in order, with lines inserted that are records of fn at node
    if i < len(a) and line == a[i]:
        i += 1
    elif inserted(line):
        extra += 1
    else:
        at = i + extra
        why = (f"line {at + 2 if at == 0 else at + 3} is neither the first trace's next line nor an inserted record of "
               f"{fn} at node {node}")
        break
want = dict(ta, records=ta["records"] + k, by_fn=dict(ta["by_fn"], **{fn: ta["by_fn"].get(fn, 0) + k}))
if why is None and i != len(a):
    why = f"{len(a) - i} of the first trace's lines missing"
if why is None and extra != k:
    why = f"{extra} records inserted, not {k}"
if why is None and tb != want:
    why = f"the trailer is not the first's with {k} more {fn}"
print("ok" if why is None else why)
sys.exit(0 if why is None else 1)
EOF
}
PIDS=
par() {                 # "$@" in the background, at most J such at a time
  while [ "$(jobs -rp | wc -l)" -ge "$J" ]; do wait -n; done
  "$@" &
  PIDS="$PIDS $!"
}
par_end() { local p rc=0; for p in $PIDS; do wait "$p" || rc=1; done; PIDS=; return $rc; }

twin_list() {           # $1: a directory with the twin's sources: "sha256  name" for each, sorted; a link is refused
  $PY - "$HERE" "$1" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import content, layout
from pathlib import Path
top, out = Path(sys.argv[2]), {}
try:
    for e in sorted(top.iterdir()):
        if e.name in layout.NOT_SOURCES or e.name == "out":
            continue
        if e.is_symlink():
            raise content.Refused(f"a link: {e.name}")
        if e.is_dir():
            out.update(content.walk(e, e.name))     # which leaves out a file whose name ends in .md, as below
        elif e.name.endswith(".md"):
            continue                                # prose (README.md), by its name, left out of the list
        else:
            import hashlib
            out[e.name] = hashlib.sha256(e.read_bytes()).hexdigest()
except content.Refused as x:
    sys.exit(f"the twin's sources: refused: {x}")
for n in sorted(out):
    print(f"{out[n]}  {n}")
EOF
}
s_build() {
  rm -rf "$OUT/twin"
  twin_list "$HERE" > "$OUT/twin-sources.txt" 2> "$OUT/twin-sources.err" || { no "the twin's sources could not be listed (twin-sources.err)"; return; }
  $PY - "$HERE" "$OUT/twin" <<'EOF' || { no "the twin's sources could not be copied"; return; }
import shutil, sys
sys.path.insert(0, sys.argv[1] + "/tools")
import layout
shutil.copytree(sys.argv[1], sys.argv[2], ignore=shutil.ignore_patterns(*layout.NOT_SOURCES, "out"))
EOF
  echo "  $(cd "$OUT/twin" && lean --version 2>&1 | head -n 1)"     # the Lean the build uses: elan resolves it by the copy's lean-toolchain
  # SpecTwin.Seacast too: it alone imports the guard modules (Seacast/*Known.lean), whose #guards hold only where they are built
  (cd "$OUT/twin" && lake build replay SpecTwin.Seacast) > "$OUT/build.txt" 2>&1 || { grep -v '^✔' "$OUT/build.txt" | head -n 40; no "the build failed"; return; }
  [ -x "$REPLAY" ] || { no "the build left no replay"; return; }
  twin_list "$OUT/twin" 2> /dev/null | cmp -s - "$OUT/twin-sources.txt" || { no "the copy that was built is not the twin's sources as listed"; return; }
  echo "  the twin's sources: $(wc -l < "$OUT/twin-sources.txt") files, the list's sha256 $(sha256sum < "$OUT/twin-sources.txt" | cut -c1-64) (twin-sources.txt)"
  echo "  the replay: sha256 $(sha256sum < "$REPLAY" | cut -c1-64)"
  local k g=()
  for k in "$OUT"/twin/SpecTwin/Seacast/*Known.lean; do
    k=$(basename "$k" .lean)
    grep -q -E "Built SpecTwin\.Seacast\.$k( |\$)" "$OUT/build.txt" || { no "the guard module $k was not built (build.txt)"; return; }
    g+=("$k")
  done
  [ ${#g[@]} -gt 0 ] || { no "no guard module under SpecTwin/Seacast"; return; }
  echo "  the guards: ${#g[@]} modules of SpecTwin.Seacast built, each #guard held (${g[*]})"
  # its control: a copy of a guard module with a false #guard, given to Lean beside the built copy, fails
  mkdir -p "$OUT/guard-control"
  { cat "$OUT/twin/SpecTwin/Seacast/FuelKnown.lean"; printf '\n#guard false\n'; } > "$OUT/guard-control/FuelKnown.lean"
  if ! (cd "$OUT/twin" && lake env lean "$OUT/guard-control/FuelKnown.lean") > "$OUT/guard-control/lean.txt" 2>&1 \
     && grep -q -F 'did not evaluate to `true`' "$OUT/guard-control/lean.txt"; then
    echo "  control, a false #guard in a guard module: it fails, as it must"
  else no "control, a false #guard in a guard module: NOT failed (guard-control/lean.txt)"; fi
  # the forms of SEACAST's questions: each row of the tools' file read and refused by the replay, and the checker's
  # three controls refused (replay --forms, Seacast/FormsRows.lean); a file that is not there fails, it is not skipped
  local forms="$T/forms-seacast-examples.tsv" rows
  [ -f "$forms" ] || { no "no forms file (tools/forms-seacast-examples.tsv)"; return; }
  rows=$(grep -c . "$forms")
  "$REPLAY" --forms "$forms" > "$OUT/forms.txt" 2>&1 \
    || { grep -F 'FAIL' "$OUT/forms.txt" | head -n 10 | cut -c1-300; no "the forms: a row not read or not refused, or a control not refused (forms.txt)"; return; }
  [ "$(tail -n 1 "$OUT/forms.txt")" = "rows $rows, controls 3, failed 0" ] \
    || { no "the forms: not $rows rows and 3 controls with none failed (forms.txt)"; return; }
  echo "  the forms: $rows rows read and refused, 3 controls refused (forms-seacast-examples.tsv)"
  # its control: a copy of the file with the typeOf row's answer made 5 fails, naming that row
  $PY - "$forms" "$OUT/forms-control.tsv" <<'EOF' || { no "control, a wrong row in the forms: the copy could not be made"; return; }
import json, sys
out = []
for line in open(sys.argv[1], encoding="ascii").read().splitlines():
    name, _, row = line.partition("\t")
    if name == "typeOf":
        r = json.loads(row)
        r[2] = 5
        line = name + "\t" + json.dumps(r, separators=(",", ":"))
    out.append(line)
open(sys.argv[2], "w", encoding="ascii").write("\n".join(out) + "\n")
EOF
  if ! "$REPLAY" --forms "$OUT/forms-control.tsv" > "$OUT/forms-control.txt" 2>&1 \
     && grep -q -F "$(printf 'typeOf\tFAIL\ttape: type_of: its answer: not a type id: 5')" "$OUT/forms-control.txt"; then
    echo "  control, a wrong row in the forms: it fails, naming the row, as it must"
  else no "control, a wrong row in the forms: NOT failed for that row (forms-control.txt)"; fi
}
s_selftests() {         # each tool's own cases: exit code 0, its own closing line, and (altered3.py's, which closes with no verdict) no case marked `<-- must be`
  local t n=0
  : > "$OUT/selftests.txt"
  while read -r t opt last; do
    if $PY "$T/$t" "$opt" > "$OUT/selftest.out" 2>&1 && tail -n 1 "$OUT/selftest.out" | grep -q -E -e "$last" && ! grep -q -e '<-- must be ' "$OUT/selftest.out"; then
      echo "$t $opt: $(tail -n 1 "$OUT/selftest.out" | cut -c1-120)" >> "$OUT/selftests.txt"; n=$((n + 1))
    else echo "$t $opt: NOT as it must be: $(tail -n 1 "$OUT/selftest.out" | cut -c1-160)" >> "$OUT/selftests.txt"; no "the self-test of $t (selftests.txt)"; fi
  done <<'EOF_SELF'
content.py --self-test ^content self-test: every case as it must be$
mutants3.py --self-test ^ok: every case of the table check as it must be$
altered3.py --self-test ^altered3 self-test, .*$
commentsonly.py --self-test ^self-test: ([0-9]+) of \1 known answers
fullid.py --self-test ^ok: every case as it must be$
against.py --self-test ^ok: every case as it must be$
matrixdiff.py --self-test ^ok: every case as it must be$
trace3.py --self-test-seacast ^ok:
gen/schema_seacast.py --self-test ^ok: every case as it must be$
keptcopy.py --self-test ^ok: every case as it must be$
labcites.py --self-test ^labcites self-test, planted: (.*), must be \1$
scan_bindings.py --self-test ^ok: every case as it must be$
timers_seacast.py --self-test ^timers_seacast: self-test: ([0-9]+) of \1 cases as they must be$
calls_seacast.py --self-test ^calls_seacast: self-test: ([0-9]+) of \1 cases as they must be$
inventory_seacast.py --self-test ^inventory_seacast: self-test: ([0-9]+) of \1 cases as they must be$
EOF_SELF
  rm -f "$OUT/selftest.out"
  [ "$n" = 15 ] || no "not 15 tools' self-tests passed"
  echo "  $n of 15 tools' own cases as they must be (selftests.txt)"
  # the twin's text: its sources as the build copied them, its tools, and the prose beside them (every *.md but
  # out/'s, record/'s and .lake/'s, which the copy leaves out; tools/' own are read with tools/): none cites the
  # notes beside which it was developed
  local md lc=$OUT/labcites-control n
  md=$(cd "$HERE" && find . \( -path ./out -o -path ./record -o -path ./tools -o -name .lake \) -prune \
    -o -name '*.md' -type f -print | LC_ALL=C sort | sed "s#^\./#$HERE/#")
  # shellcheck disable=SC2086
  $PY "$T/labcites.py" "$OUT/twin" "$T" $md > "$OUT/labcites.txt" 2>&1 \
    || no "a file of the twin, of its tools or beside them cites the notes beside which it was developed (labcites.txt)"
  tail -n 1 "$OUT/labcites.txt" | sed 's/^/  /'
  # its control: a lab citation planted in README.md's copy is reported, on that line (the line is built from parts,
  # since the guard reads this script)
  mkdir -p "$lc"
  { cat "$HERE/README.md"; printf '%s §9, planted\n' "design"; } > "$lc/README.md"
  n=$(wc -l < "$lc/README.md")
  if ! $PY "$T/labcites.py" "$lc/README.md" > "$lc/labcites.txt" 2>&1 \
     && [ "$(tail -n 1 "$lc/labcites.txt")" = "labcites: 1 lines in 1 files" ] \
     && head -n 1 "$lc/labcites.txt" | grep -q -F -e "$lc/README.md:$n: "; then
    echo "  control, a lab citation planted in README.md's copy: reported, as it must be"
  else no "the guard did not report a lab citation planted in README.md's copy ($lc/labcites.txt)"; fi
  # the scan's lists beside trace3.py's hand-kept ones: no difference. The observer the peer-promise mode binds
  # over close_promises, bound under SEACAST alone (_seacast calls _peer_promise), is held to LAYERS, which lists it
  $PY "$T/scan_bindings.py" "$TOY" --lists > "$OUT/scan-lists.txt" 2>&1; local lrc=$?
  if [ "$lrc" = 0 ] && [ "$(grep -c 'NOT' "$OUT/scan-lists.txt")" = 0 ] \
      && has -x "observer close_promises Node._peer_promise.<locals>.close_promises: v2-only, an observer in LAYERS (the chain rule's)" "$OUT/scan-lists.txt" \
      && has -x "the lists as trace3.py's" "$OUT/scan-lists.txt"; then
    echo "  the scan's lists: trace3.py's (scan-lists.txt)"
  else no "the scan's lists differ from trace3.py's (scan-lists.txt)"; fi
}
s_tables() {
  { $PY "$T/gen/gen.py" --check "$OUT/twin" && $PY "$T/gen/makers.py" --check "$OUT/twin"; } > "$OUT/tables.txt" 2>&1 \
    || no "a generated file is not the schema's, or a Tables value is made elsewhere (tables.txt)"
  tail -n 1 "$OUT/tables.txt" | sed 's/^/  /'
  $PY "$T/keptcopy.py" --twin "$OUT/twin" > "$OUT/keptcopy.txt" 2>&1 \
    || no "a copy of seacast-lite.md's Lean in Seacast/Kept.lean differs from its original beyond the named differences (keptcopy.txt)"
  tail -n 1 "$OUT/keptcopy.txt" | sed 's/^/  /'
  # the record writers' arities against runSeacast's cases (records_seacast.py): each stub call's count one the case takes,
  # each count the case takes given by a stub call; and its two controls, each a plant that must give exactly the
  # differences written here
  local rv=$OUT/twin/SpecTwin/Seacast/Replay.lean c why said
  (cd "$T" && $PY records_seacast.py "$rv") > "$OUT/arities.txt" 2>&1 \
    || no "a record writer's arity is not runSeacast's case's (arities.txt)"
  [ "$(tail -n 1 "$OUT/arities.txt")" = "records_seacast: 77 covered names, 0 difference(s)" ] \
    || no "the arity check's last line is not 77 covered names and no difference (arities.txt)"
  # its default path (no argument: the tree's own Replay.lean) gives the same lines as the build's copy
  (cd "$T" && $PY records_seacast.py) > "$OUT/arities-default.txt" 2>&1
  if cmp -s "$OUT/arities-default.txt" "$OUT/arities.txt"; then rm -f "$OUT/arities-default.txt"
  else no "records_seacast.py with no argument does not print arities.txt (arities-default.txt)"; fi
  tail -n 1 "$OUT/arities.txt" | sed 's/^/  /'
  for c in forward on_chunk; do
    why=$(cd "$T" && $PY - "$rv" "$c" "$T" <<'EOF'
import sys
sys.path.insert(0, sys.argv[3])         # the tools' directory (isolated mode adds none)
import records_seacast as R                  # noqa: E402
rv, c = sys.argv[1], sys.argv[2]
if c == "forward":                      # forward's stub calls cut to the first, one(f, 4): its 3 is given by none
    stand_in = R.stand_in

    def cut():
        tr, stubs = stand_in()
        calls, r = stubs["forward"]
        stubs["forward"] = (calls[:1], r)
        return tr, stubs
    R.stand_in = cut
    want = ["forward: runSeacast's case takes 3 args, which no stub call gives"]
else:                                   # on_chunk's writer without p: a count of 1, and the case's 2 given by none
    params, _, ret = R.TABLE["on_chunk"]
    R.TABLE["on_chunk"] = (params, lambda tr, p, f: [tr.wchunk(f)], ret)
    want = ["on_chunk: args_seacast gives 1 args, runSeacast's case takes 2",
            "on_chunk: runSeacast's case takes 2 args, which no stub call gives"]
got = R.arity_check(rv)
print("as it must be" if got == want else f"not as written: {got}")
EOF
)
    case $c in forward) said="forward's stub calls cut to the first: refused, as it must be (forward 3)" ;;
               *) said="on_chunk's writer without p: refused, as it must be (on_chunk 1 against 2)" ;; esac
    if [ "$why" = "as it must be" ]; then echo "  control, $said"
    else no "control of the arity check, $c: ${why:-no answer}"; fi
  done
  $PY "$T/footprint_test.py" > "$OUT/views.txt" 2>&1 || no "the views' own cases (views.txt)"
  tail -n 1 "$OUT/views.txt" | sed 's/^/  /'
}
s_scope() {             # the twin's scope held to the document: every `def` of seacast-lite.md's code blocks, by name
  $PY - "$(dirname "$TOY")/seacast-lite.md" "$HERE/SpecTwin" > "$OUT/scope.txt" 2>&1 <<'EOF'
import ast, re, sys
from collections import Counter
from pathlib import Path
doc, twin = Path(sys.argv[1]), Path(sys.argv[2])
defs, sec, block = [], None, None             # (name, section) of every top-level def, in the document's order
for line in doc.read_text().split("\n"):
    if block is None:
        m = re.match(r"#{2,3} (\d+(?:\.\d+)?)[. ]", line)
        if m:
            sec = m.group(1)
        if line.strip() == "```python":
            block = []
    elif line.strip() == "```":
        defs += [(n.name, sec) for n in ast.parse("\n".join(block)).body if isinstance(n, ast.FunctionDef)]
        block = None
    else:
        block.append(line)
entered = set()
for f in sorted(twin.glob("*.lean")):
    entered |= set(re.findall(r'enter "([A-Za-z_0-9]+)"', f.read_text()))
cases = set(re.findall(r'^\s*\| "([A-Za-z_0-9]+)", #\[', (twin / "Replay.lean").read_text(), re.M))

def missing(entered, cases):
    return [f"{n} (§{s}): {'no enter' if n not in entered else 'no case of the replay'}"
            for n, s in defs if n not in entered or n not in cases]
names = [n for n, _ in defs]
bad = missing(entered, cases)
if not defs or len(set(names)) != len(names):
    bad.append(f"the document's defs cannot be read as {len(names)} distinct names")
for b in bad:
    print(f"without its twin: {b}")
by = Counter(s for _, s in defs)
order = sorted(by, key=lambda s: [int(x) for x in s.split(".")])
print("by section: " + ", ".join(f"§{s} {by[s]}" for s in order))
more = sorted(entered & cases - set(names))
print(f"the twin's functions with no def in the code blocks: {', '.join(more) or 'none'}")
gone = names[0]                              # the control: a twin with one name taken away must be refused
ctl = missing(entered - {gone}, cases)
print(f"control, the twin without {gone}: {'refused, as it must be' if ctl and gone in ctl[0] else 'NOT refused  <-- FAIL'}")
if bad or not ctl:
    print(f"NOT every function of seacast-lite.md's code blocks has its twin: {len(bad)} without")
    sys.exit(1)
print(f"{len(names)} of {len(names)} functions of seacast-lite.md's code blocks have their twin, by name")
EOF
  [ $? = 0 ] || no "a function of seacast-lite.md's code blocks without its twin, or the scope's control (scope.txt)"
  # SEACAST's part: every name the manifest covers has an `enter` in SpecTwin/Seacast/ and a case of runSeacast, and every case of
  # runSeacast is a covered name or the one kept form that is no covered name (respond)
  $PY - "$T/gen" "$HERE/SpecTwin" >> "$OUT/scope.txt" 2>&1 <<'EOF'
import re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import manifest_seacast
twin = Path(sys.argv[2])
covered = list(manifest_seacast.COVERED)
entered = set()
for f in sorted((twin / "Seacast").glob("*.lean")):
    entered |= set(re.findall(r'enter "([A-Za-z_0-9]+)"', f.read_text()))
text = (twin / "Seacast" / "Replay.lean").read_text()
body = text[text.index("\ndef runSeacast "):]                 # runSeacast's cases, not the tape reader's
cases = set(re.findall(r'^\s*\| "([A-Za-z_0-9]+)", #\[', body, re.M))
FORM_ALONE = {"respond"}

def missing(entered, cases):
    out = [f"{n}: {'no enter' if n not in entered else 'no case of runSeacast'}"
           for n in covered if n not in entered or n not in cases]
    return out + [f"{c}: a case of runSeacast the manifest does not cover" for c in sorted(cases - set(covered) - FORM_ALONE)]
bad = missing(entered, cases)
for b in bad:
    print(f"SEACAST, without its twin: {b}")
gone = covered[0]                            # the controls: each must be refused
ctl1 = missing(entered - {gone}, cases)
ok1 = bool(ctl1) and ctl1[0].startswith(gone + ":")
print(f"control, SEACAST's twin without {gone}: {'refused, as it must be' if ok1 else 'NOT refused  <-- FAIL'}")
ctl2 = missing(entered, cases | {"on_frame"})
ok2 = "on_frame: a case of runSeacast the manifest does not cover" in ctl2
print(f"control, runSeacast with a case named on_frame: {'refused, as it must be' if ok2 else 'NOT refused  <-- FAIL'}")
if bad or not ok1 or not ok2:
    print(f"NOT every one of seacast.md's covered functions has its twin, or runSeacast has a case it does not cover: {len(bad)}")
    sys.exit(1)
print(f"{len(covered)} of {len(covered)} of seacast.md's covered functions have their twin, by name")
EOF
  [ $? = 0 ] || no "a covered function of seacast.md without its twin, a case of runSeacast not covered, or SEACAST's scope controls (scope.txt)"
  # SEACAST's questions, both ways: each name of the manifest's QUESTIONS is read by the twin (an askCall, or a case of
  # the tape reader), and each name the twin asks or reads as a call under seacast.md is a question, a covered
  # or cut function, or one of the replay's own entries
  $PY - "$T/gen" "$HERE/SpecTwin" >> "$OUT/scope.txt" 2>&1 <<'EOF'
import re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import manifest_seacast
twin = Path(sys.argv[2])
questions = list(manifest_seacast.QUESTIONS)
OWN_ENTRIES = {"keys", "order"}               # the replay's own entries under SEACAST: a table's keys, an iteration's order
ASK = re.compile(r'askCall[A-Za-z]* "([A-Za-z_0-9]+)"')
CASE = re.compile(r'^\s*\| "([A-Za-z_0-9]+)", #\[', re.M)

def body(f, name):                            # a def's text, to the next line that starts a def
    text = f.read_text()
    i = text.index(f"\ndef {name} ")
    j = text.find("\ndef ", i + 1)
    return text[i:j if j > 0 else len(text)]

def asks(files):                              # each name an askCall reads, with its first place
    out = {}
    for f in files:
        for k, line in enumerate(f.read_text().split("\n"), 1):
            for n in ASK.findall(line):
                out.setdefault(n, f"{f.relative_to(twin.parent)}:{k}")
    return out
asked = asks(sorted(twin.rglob("*.lean")))
entries = set(CASE.findall(body(twin / "Replay.lean", "entry"))) | set(CASE.findall(body(twin / "Seacast" / "Replay.lean", "entrySeacast")))
# The reverse direction reads the names asked under Seacast/ and by SEACAST's tape reader. A kept function asks through
# Replay.lean's instance, shared with seacast-lite.md's functions, so its questions are not told apart here; gen.py's
# manifest_questions holds them, over the Python's closure of the covered and kept functions.
asked_seacast = asks(sorted((twin / "Seacast").glob("*.lean")))
calls_seacast = body(twin / "Seacast" / "Replay.lean", "callNamesSeacast").split(":=", 1)[1].split("\n\n")[0]
for n in re.findall(r'"([A-Za-z_0-9]+)"', calls_seacast) + sorted(CASE.findall(body(twin / "Seacast" / "Replay.lean", "entrySeacast"))):
    asked_seacast.setdefault(n, "SpecTwin/Seacast/Replay.lean's tape reader")

def wrong(questions, asked_seacast):
    listed = set(questions) | set(manifest_seacast.COVERED) | set(manifest_seacast.CUT) | OWN_ENTRIES
    out = [f"{n}: in QUESTIONS, read by no askCall and no tape entry of the twin"
           for n in questions if n not in asked and n not in entries]
    return out + [f"{n}: asked by the twin under seacast.md ({p}), in no list of the manifest"
                  for n, p in sorted(asked_seacast.items()) if n not in listed]
bad = wrong(questions, asked_seacast)
for b in bad:
    print(f"SEACAST's questions: {b}")
by_ask = sum(n in asked for n in questions)
ctl1 = wrong([n for n in questions if n != "links"], asked_seacast)
ok1 = any(c.startswith("links: asked by the twin under seacast.md (") for c in ctl1)
print(f"control, QUESTIONS without links: {'refused, as it must be' if ok1 else 'NOT refused  <-- FAIL'}")
ctl2 = wrong(questions, {**asked_seacast, "made_up": "a planted askCall"})
ok2 = "made_up: asked by the twin under seacast.md (a planted askCall), in no list of the manifest" in ctl2
print(f"control, an askCall of made_up under Seacast/: {'refused, as it must be' if ok2 else 'NOT refused  <-- FAIL'}")
ctl3 = wrong(questions + ["made_up"], asked_seacast)
ok3 = "made_up: in QUESTIONS, read by no askCall and no tape entry of the twin" in ctl3
print(f"control, QUESTIONS with made_up: {'refused, as it must be' if ok3 else 'NOT refused  <-- FAIL'}")
if bad or not (ok1 and ok2 and ok3) or not questions:
    print(f"NOT every one of seacast.md's questions is read by the twin, or the twin asks one the manifest does not list: {len(bad)}")
    sys.exit(1)
print(f"{len(questions)} of {len(questions)} of seacast.md's questions are read by the twin: {by_ask} by an askCall, "
      f"{len(questions) - by_ask} by a tape entry alone")
print(f"the {len(asked_seacast)} names the twin asks or reads as calls under seacast.md are each a question, a covered "
      f"function, a cut one or the replay's own ({', '.join(sorted(OWN_ENTRIES))})")
EOF
  [ $? = 0 ] || no "a question of seacast.md the twin does not read, a name the twin asks that the manifest does not list, or the questions' controls (scope.txt)"
  sed 's/^/  /' "$OUT/scope.txt"
}
s_mutants() {
  $PY "$T/mutants3.py" --places --twin "$OUT/twin" > "$OUT/mutants-places.txt" 2>&1 || no "a mutant's text does not stand in the twin (mutants-places.txt)"
  tail -n 1 "$OUT/mutants-places.txt" | sed 's/^/  /'
  $PY "$T/mutants3.py" --typecheck "$OUT/twin" "$OUT/typecheck" -j "$J" > "$OUT/mutants-typecheck.txt" 2>&1 || no "a mutant does not type-check (mutants-typecheck.txt)"
  has -x "control, a change that does not type-check: rc=1: it fails, as it must" "$OUT/mutants-typecheck.txt" || no "the type-check's own control"
  tail -n 2 "$OUT/mutants-typecheck.txt" | sed 's/^/  /'
}
s_screen() {
  local f doc
  for doc in lite seacast; do
    f=$OUT/nodeslines-$doc.txt
    $PY "$T/cells3.py" "$TOY" "$OUT/nodeslines-$doc" -j "$J" --replay "$REPLAY" --doc "$doc" --nodes-lines > "$f" 2>&1 || no "a header or a nodes line refused under $doc ($f)"
    has -x ok "$f" || no "no verdict under $doc"
    [ "$(grep -c ': its header and nodes line read by the replay$' "$f")" = 15 ] || no "not 15 cells read under $doc"
    has -x "control, a nodes line without PROMISE: refused, and seen" "$f" || no "the nodes line's control under $doc"
    echo "  $doc: $(grep -c ': its header and nodes line read by the replay$' "$f") cells' header and nodes line read; $(grep '^control' "$f")"
  done
}
s_cells() {
  if [ -z "$RECORD" ]; then
    $PY "$T/cells3.py" "$TOY" "$OUT/traces" -j 1 --replay "$REPLAY" none > "$OUT/cells.txt" 2>&1 || no "none (cells.txt)"
    has -x ok "$OUT/cells.txt" || no "no verdict on none"
    head -n 1 "$OUT/cells.txt" | cut -c1-200 | sed 's/^/  /'
  else                  # every cell of check.py: its digest golden.txt's, its first two lines, its replay
    if [ -z "$CELLS" ]; then echo "  no cell (a rehearsal)"; echo ok > "$OUT/cells.txt"; return; fi
    # shellcheck disable=SC2086
    $PY "$T/cells3.py" "$TOY" "$OUT/traces" -j "$J" --replay "$REPLAY" $CELLS > "$OUT/cells.txt" 2>&1 || no "a cell (cells.txt)"
    has -x ok "$OUT/cells.txt" || no "no verdict on the cells"
    [ "$(grep -c ', digest as golden.txt, ' "$OUT/cells.txt")" = "$(echo $CELLS | wc -w)" ] || no "not every cell's digest is golden.txt's"
    [ "$(grep -c . "$OUT/cells.txt")" = "$(( $(echo $CELLS | wc -w) + 1 ))" ] || no "cells.txt is not a line a cell and the verdict (check.py's cells are not this script's CELLS)"
    echo "  $(grep -c ', digest as golden.txt, ' "$OUT/cells.txt") of $(echo $CELLS | wc -w) cells: digest as golden.txt, replayed (cells.txt)"
  fi
}
s_seacastcells() {            # every cell under seacast.md: its digest golden-seacast.txt's; the records are seacast-lite.md's names
  rm -f "$OUT/seacastcells.cells"       # the cells made into this OUT, written once they pass: the need seacastcells
  $PY "$T/trace3.py" --self-test-seacast > "$OUT/seacast-self-test.txt" 2>&1 || no "the tracer's self-test of SEACAST's kept names (seacast-self-test.txt)"
  if [ -z "$CELLS" ]; then echo "  no SEACAST cell (a rehearsal)"; echo ok > "$OUT/cells-seacast.txt"; return; fi
  local c
  for c in $CELLS; do rm -f "$OUT/seacast/$c.jsonl.gz.bare.json" "$OUT/seacast/$c.jsonl.gz.calls.json"; done     # no count left from an earlier run counts
  # shellcheck disable=SC2086
  $PY "$T/cells3.py" "$TOY" "$OUT/seacast" -j "$J" --doc seacast --replay "$REPLAY" $CELLS > "$OUT/cells-seacast.txt" 2>&1 || no "a SEACAST cell (cells-seacast.txt)"
  has -x ok "$OUT/cells-seacast.txt" || no "no verdict on the SEACAST cells"
  [ "$(grep -c ', digest as golden-seacast.txt, ' "$OUT/cells-seacast.txt")" = "$(echo $CELLS | wc -w)" ] || no "not every SEACAST cell's digest is golden-seacast.txt's"
  echo "  $(grep -c ', digest as golden-seacast.txt, ' "$OUT/cells-seacast.txt") of $(echo $CELLS | wc -w) SEACAST cells: digest as golden-seacast.txt, replayed (cells-seacast.txt)"
  # shellcheck disable=SC2086
  if has -x ok "$OUT/cells-seacast.txt" && [ "$(grep -c ', digest as golden-seacast.txt, ' "$OUT/cells-seacast.txt")" = "$(echo $CELLS | wc -w)" ]; then
    echo $CELLS > "$OUT/seacastcells.cells"
  fi
}
small() {               # $1: a name; $2: its directory; $3: the tracer's environment setting, or ""; the rest: run.py's arguments
  local name=$1 dir=$2 setting=$3 got plain; shift 3
  rm -f "$OUT/$dir/$name.jsonl.gz" "$OUT/$dir/$name.jsonl.gz.bare.json" "$OUT/$dir/$name.jsonl.gz.calls.json" "$OUT/$dir/$name.replay" "$OUT/$dir/$name.replay.rc"
  (cd "$TOY" && env $setting $PY "$T/trace3.py" . "$OUT/$dir/$name.jsonl.gz" "$@" --digest > "$OUT/$dir/$name.out" 2> "$OUT/$dir/$name.err") || return 1
  replay_of "$dir/$name"
  (cd "$TOY" && $PYPLAIN run.py "$@" --digest > "$OUT/$dir/$name.plain" 2>&1)
  got=$(digest_of "$OUT/$dir/$name.out"); plain=$(digest_of "$OUT/$dir/$name.plain")
  echo "$dir/$name: digest traced ${got:-none}, untraced ${plain:-none}: $([ -n "$got" ] && [ "$got" = "$plain" ] && echo the same || echo DIFFERENT)" > "$OUT/$dir/$name.digest"
  [ -n "$got" ] && [ "$got" = "$plain" ]
}
s_small() {
  # shellcheck disable=SC2086
  { par small hand5 traces "" $HAND5
    par small hand5-sec61 traces TRACE3_ONLY=sec61 $HAND5
    par small late16 traces "" $LATE16
    par small hand5-publish traces "" $HAND5 --source-offers publish
    par small hand5 seacast "" $HAND5 --doc seacast
    par small hand5-own seacast "" $HAND5 --rebuilt none --fault sil30 --doc seacast
    par small hand5-publish seacast "" $HAND5 --doc seacast --source-offers publish; }   # H7b: the source's offers at publish
  par_end || no "a small cell was not traced, or its digest is not the untraced run's"
  cat "$OUT"/traces/*.digest "$OUT"/seacast/*.digest 2> /dev/null | tee "$OUT/digests.txt" | sed 's/^/  /'
  [ "$(grep -c ': the same$' "$OUT/digests.txt")" = 7 ] || no "not seven digests the same"
}
one_directed() {
  local d=$1 tool
  tool=$(dirtool "$d")
  rm -f "$OUT/directed/$d.jsonl.gz" "$OUT/directed/$d.replay" "$OUT/directed/$d.replay.rc"
  # shellcheck disable=SC2046
  (cd "$TOY" && $PY "$T/${tool%% *}" . "$OUT/directed/$d.jsonl.gz" --n 20000 --seed 1 $(case "$tool" in *" "*) echo "${tool#* }" ;; esac) \
      > "$OUT/directed/$d.out" 2> "$OUT/directed/$d.err") || return 1
  replay_of "directed/$d"
}
s_directed() {
  local d
  for d in $DIRS; do par one_directed "$d"; done
  par_end || no "a directed set was not traced, or its replay did not end with status 0"
  echo "  $(ls "$OUT"/directed/*.jsonl.gz 2> /dev/null | wc -l) of 22 directed sets traced"
}
by_cells3() {           # $1: a trace of TRACES: replayed by cells3.py, as a cell of check.py, whose verdict requires the
  case $1 in traces/*|seacast/*) case " $CELLS none " in *" ${1#*/} "*) return 0 ;; esac ;; esac   #   replay's code 0
  return 1
}
s_replays() {
  local t f n=0
  : > "$OUT/replays.txt"
  for t in $TRACES; do
    f=$OUT/$t.replay
    if [ ! -s "$f" ]; then echo "$t: no replay" >> "$OUT/replays.txt"; no "$t has no replay"; continue; fi
    echo "$t: $(grep '^replay: ' "$f" | head -n 1); $(grep "^reads of the Python's that the twin did not make: " "$f" | head -n 1)" >> "$OUT/replays.txt"
    if ! by_cells3 "$t" && [ "$(cat "$OUT/$t.replay.rc" 2> /dev/null)" != 0 ]; then
      no "$t: the replay exited $(cat "$OUT/$t.replay.rc" 2> /dev/null || echo '?')"; continue
    fi
    parsed_whole "$f" || { no "$t: the parser refused a line of it"; continue; }
    has -E '^replay: [1-9][0-9]* records, [1-9][0-9]* ok, 0 mismatched$' "$f" || { no "$t: a record mismatched, or none read"; continue; }
    has -x "reads of the Python's that the twin did not make: 0" "$f" || { no "$t: a read of the Python's not made"; continue; }
    case $t in seacast/*) bare_none "$OUT/$t.jsonl.gz" || { no "$t: its run counted bare calls ($t.jsonl.gz.bare.json)"; continue; } ;; esac
    has -E "^content: as --content's, [0-9]+ names\$" "$f" || { no "$t: its content line was not compared, or is not this tree's"; continue; }
    if grep -E '^(content|header|nodes|trailer|consts|subset): ' "$f" | grep -v -e '^header: {' -e "^content: as --content's, " | grep -q .; then no "$t: the replay refused a line of the envelope"; continue; fi
    n=$((n + 1))
  done
  echo "  $n of $(echo $TRACES | wc -w) replays: every record of a trace that is not empty, none mismatched, no read left unmade (replays.txt)"
}
s_headers() {
  # shellcheck disable=SC2046
  $PY "$T/header3.py" "$TOY" $(for t in $TRACES; do echo "$OUT/$t.jsonl.gz"; done) > "$OUT/headers.txt" 2>&1 || no "a header is not these tools' and these documents' (headers.txt)"
  [ "$(grep -c "tracing §6.1's 12 alone\$" "$OUT/headers.txt")" = 1 ] && has -E "/hand5-sec61\.jsonl\.gz: .*tracing §6.1's 12 alone\$" "$OUT/headers.txt" \
    || no "hand5-sec61 alone must be of §6.1's twelve"
  [ "$(grep -c -E "/seacast/hand5(-own)?\.jsonl\.gz: .*tracing SEACAST's kept and covered, " "$OUT/headers.txt")" = 2 ] || no "the two small SEACAST traces must be of SEACAST's kept and covered names"
  [ "$(grep -c -E "/seacast/[a-z0-9-]+\.jsonl\.gz: .*tracing SEACAST's kept and covered, " "$OUT/headers.txt")" = "$(grep -c -E '/seacast/[a-z0-9-]+\.jsonl\.gz: ' "$OUT/headers.txt")" ] || no "a SEACAST trace is not of SEACAST's kept and covered names"
  echo "  $(grep -c . "$OUT/headers.txt") headers read (headers.txt)"
  # the question writers' example rows (tools/forms-seacast-examples.tsv, which the build step's replay --forms reads),
  # made again by the writers from this run's seacast/hand5: so that the file cannot drift from the writers
  if [ -s "$OUT/seacast/hand5.jsonl.gz" ]; then
    $PY "$T/forms_seacast_examples.py" "$OUT/seacast/hand5.jsonl.gz" > "$OUT/forms-seacast-examples.tsv" 2> "$OUT/forms-seacast-examples.err" \
      || no "the example rows were not made from seacast/hand5 (forms-seacast-examples.err)"
    [ "$(sha256sum < "$OUT/forms-seacast-examples.tsv")" = "$(sha256sum < "$T/forms-seacast-examples.tsv")" ] \
      || no "the example rows made from seacast/hand5 differ from tools/forms-seacast-examples.tsv (forms-seacast-examples.tsv)"
    echo "  the example rows made again from seacast/hand5: $(grep -c . "$OUT/forms-seacast-examples.tsv"), as tools/forms-seacast-examples.tsv"
  else
    no "no seacast/hand5 to make the example rows from"
  fi
  # each trace's two hashes, by its name under --out: two runs of one tree, on any machine, give the same file
  # shellcheck disable=SC2046
  (cd "$OUT" && $PY "$T/content.py" --hashes $(for t in $TRACES; do echo "$t.jsonl.gz"; done) > hashes.txt 2> hashes.err) || no "a trace's hashes (hashes.err)"
  echo "  hashes.txt: $(wc -l < "$OUT/hashes.txt") traces, the file's sha256 $(sha256sum < "$OUT/hashes.txt" | cut -c1-64)"
}
s_picks() {
  { $PY "$T/fixcontrols.py" pick "$REPLAY" "$CONTENT" "$OUT/directed/directed42.jsonl.gz" validate_chunk
    $PY "$T/fixcontrols.py" pick "$REPLAY" "$CONTENT" "$OUT/directed/directed41.jsonl.gz" on_iwant
    $PY "$T/fixcontrols.py" pick "$REPLAY" "$CONTENT" "$OUT/directed/directed46d.jsonl.gz" push_rebuilt
    $PY "$T/fixcontrols.py" draw "$OUT/directed/directed3v.jsonl.gz"; } > "$OUT/picks.txt" 2>&1 || no "a pick or the draw (picks.txt)"
  [ "$(grep -c . "$OUT/picks.txt")" = 4 ] || no "not four lines in picks.txt"
  sed 's/^/  /' "$OUT/picks.txt" | cut -c1-200
}
cut_controls() {        # a trace cut short: no trailer, so no pass; and a line the parser refuses: seacast/hand5 with one
  #                       line that is not JSON just before its trailer, which the replay counts and exits 1 on, and
  #                       which replay_clean refuses by the replay's status, and by the parser's line where the status
  #                       reads 0
  local rc n r w1 w2
  zcat "$OUT/traces/hand5.jsonl.gz" | head -n 50 | "$REPLAY" --content "$CONTENT" > "$OUT/c-cut.replay" 2>&1; rc=${PIPESTATUS[2]}
  if [ "$rc" = 1 ] && has -E '^trailer: ' "$OUT/c-cut.replay" && parsed_whole "$OUT/c-cut.replay"; then echo "  control, a trace cut short: refused, as it must be: $(grep -m 1 '^trailer: ' "$OUT/c-cut.replay" | cut -c1-120)"
  else no "control, a trace cut short: rc=$rc, and no line about the trailer, or a line the parser refused"; fi
  rm -f "$OUT"/c-refused.*
  n=$(zcat "$OUT/seacast/hand5.jsonl.gz" | wc -l)
  zcat "$OUT/seacast/hand5.jsonl.gz" | awk -v n="$n" 'NR == n { print "not JSON" } { print }' | gzip -n > "$OUT/c-refused.jsonl.gz"
  cp "$OUT/seacast/hand5.jsonl.gz.bare.json" "$OUT/c-refused.jsonl.gz.bare.json" 2> /dev/null
  replay_of c-refused; rc=$?
  w1=$(replay_clean c-refused)
  echo 0 > "$OUT/c-refused.replay.rc"
  w2=$(replay_clean c-refused)
  r=$(sed -n -E 's/^replay: ([0-9]+) records, [0-9]+ ok, 0 mismatched$/\1/p' "$OUT/seacast/hand5.replay" 2> /dev/null)
  if [ "$rc" = 1 ] && [ -n "$r" ] && [ "$(zcat "$OUT/c-refused.jsonl.gz" | wc -l)" = $((n + 1)) ] \
      && has -x "replay: $r records, $r ok, 0 mismatched" "$OUT/c-refused.replay" \
      && has -E "^line $n: not a line the tracer writes: " "$OUT/c-refused.replay" \
      && has -x "lines refused before they were parsed, or by the parser: 1" "$OUT/c-refused.replay" \
      && [ "$w1" = "the replay exited 1" ] && [ "$w2" = "the parser refused a line of it" ]; then
    echo "  control, a line the parser refuses: refused twice, as it must be ($w1; $w2)"
  else no "control, a line the parser refuses: rc=$rc; replay_clean: '$w1', and with the status 0: '$w2' (c-refused.replay)"; fi
}
s_controls() {
  local rc
  # 1. a mutant that compiles, replayed over §6.1's directed set: it must be built, and told by a mismatched record
  rm -rf "$OUT/c-mutant"; mkdir -p "$OUT/c-mutant/traces"
  cp "$OUT/directed/directed.jsonl.gz" "$OUT/c-mutant/traces/" 2> /dev/null
  $PY "$T/mutants3.py" "$OUT/c-mutant/traces" "$OUT/c-mutant/work" -j 1 --twin "$OUT/twin" window-le > "$OUT/c-mutant.txt" 2>&1; rc=$?
  if [ "$rc" = 0 ] && has -E '^1 of 1 mutants told from the twin by these traces' "$OUT/c-mutant.txt" && ! has 'no verdict' "$OUT/c-mutant.txt"; then
    echo "  control, a mutant that compiles (window-le): told, as it must be: $(grep -m 1 '^window-le: ' "$OUT/c-mutant.txt" | cut -c1-150)"
  else no "control, a mutant that compiles: rc=$rc, not told by a mismatched record (c-mutant.txt)"; fi
  # 2. altered records, wrong headers, malformed nodes lines: every one refused (altered3.py's own table)
  #    (the traces in the order altered3.py takes them: each group of its controls is of one set's records)
  # shellcheck disable=SC2046
  SPEC_TWIN_REPLAY=$REPLAY $PY "$T/altered3.py" "$OUT/traces/hand5-sec61.jsonl.gz" "$OUT/c-altered" "$OUT/directed/directed.jsonl.gz" "$OUT/traces/hand5.jsonl.gz" \
      "$OUT/directed/directed44.jsonl.gz" "$OUT/directed/directed42.jsonl.gz" "$OUT/seacast/hand5.jsonl.gz" \
      $(for d in directed4b directed7 directed1 directed6o directed64 directed64h directed46 directed43 directed41 directed46d directed3v directed52 directed53 directed54 directed7p; do echo "$OUT/directed/$d.jsonl.gz"; done) \
      "$OUT/traces/hand5-publish.jsonl.gz" "$OUT/directed/directed71.jsonl.gz" "$OUT/directed/directed51.jsonl.gz" > "$OUT/c-altered.txt" 2>&1; rc=$?
  if [ "$rc" = 0 ] && ! has -E 'wrong$|<-- ' "$OUT/c-altered.txt" && [ "$(grep -c '^ok: every control of ' "$OUT/c-altered.txt")" -ge 1 ]; then
    echo "  control, altered records, headers and nodes lines: $(grep -c '^ok: every control of ' "$OUT/c-altered.txt") groups, each refused as it must be (c-altered.txt)"
  else no "control, altered records: rc=$rc (c-altered.txt)"; fi
  # 3. a trace cut short, and a line the parser refuses (cut_controls)
  cut_controls
  # 4. the content line: a trace of another tree refused, the same tree at another place the same bytes, edits of
  #    prose and READMEs leaving the line as it was, and a tracer started so that what runs need not be what the
  #    line names refused (contentcontrols.py's own table)
  $PY "$T/contentcontrols.py" "$TOY" "$OUT/c-content" "$REPLAY" "$OUT/traces/hand5-sec61.jsonl.gz" > "$OUT/c-content.txt" 2>&1; rc=$?
  if [ "$rc" = 0 ] && ! has '<-- ' "$OUT/c-content.txt" && has -x "ok: every control of the content line as it must be" "$OUT/c-content.txt"; then
    echo "  control, the content line: $(grep -c '^content, ' "$OUT/c-content.txt") cases, each as it must be (c-content.txt)"
  else no "control, the content line: rc=$rc (c-content.txt)"; fi
}

VIEWS_TEST=          # the views' test views_control runs: footprint_test.py, or a stub of its own controls
VIEWS_REPORT=        # where views_control writes its line: views-controls.txt, or its own controls' file
views_control() {       # $1: footprint_test.py's option; $2: what is broken; $3: how many cases it must fail
  local f=$OUT/views$1.txt n rc=0 test=${VIEWS_TEST:-$T/footprint_test.py} rep=${VIEWS_REPORT:-$OUT/views-controls.txt}
  $PY "$test" "$1" > "$f" 2> "$f.err" || rc=$?
  n=$(grep -c -F 'FAIL' "$f")
  if [ "$rc" = 1 ] && [ ! -s "$f.err" ] && [ "$(tail -n 1 "$f")" = "footprint_test: a case is NOT as the contract says" ] && [ "$n" = "$3" ]; then
    echo "control, views that $2: $n cases fail, as they must" >> "$rep"
  else
    echo "control, views that $2: rc=$rc, $n cases fail (it must be $3 and the test's own verdict)  <-- NOT" >> "$rep"; return 1
  fi
}
views_control_controls() {      # views_control itself, on three stubs of the test that fail otherwise than its own
  local kind ok=0                #   failure: each must be refused, though each prints the count and the verdict
  mkdir -p "$OUT/views-stubs"; : > "$OUT/views-stubs.txt"
  for kind in line-after stderr exit2; do
    cat > "$OUT/views-stubs/$kind.py" <<EOF_STUB
import sys
print("case, one: NOT  <-- FAIL")
print("case, two: NOT  <-- FAIL")
print("footprint_test: a case is NOT as the contract says")
kind = "$kind"
if kind == "line-after":
    print("one line more, after the verdict")
if kind == "stderr":
    print("a line on stderr", file=sys.stderr)
sys.exit(2 if kind == "exit2" else 1)
EOF_STUB
    if VIEWS_TEST=$OUT/views-stubs/$kind.py VIEWS_REPORT=$OUT/views-stubs.txt views_control "--stub-$kind" "fail otherwise ($kind)" 2; then
      echo "a stub that fails otherwise ($kind): taken  <-- it must be refused" >> "$OUT/views-stubs.txt"
    else ok=$((ok + 1)); echo "a stub that fails otherwise ($kind): refused, as it must be" >> "$OUT/views-stubs.txt"; fi
  done
  # and the stub's form passes where it fails as the test does, so a refusal above is for its one difference
  cat > "$OUT/views-stubs/plain.py" <<'EOF_STUB'
import sys
print("case, one: NOT  <-- FAIL")
print("case, two: NOT  <-- FAIL")
print("footprint_test: a case is NOT as the contract says")
sys.exit(1)
EOF_STUB
  if VIEWS_TEST=$OUT/views-stubs/plain.py VIEWS_REPORT=$OUT/views-stubs.txt views_control "--stub-plain" "fail as the test does" 2; then
    ok=$((ok + 1)); echo "the stub that fails as the test does: taken, as it must be" >> "$OUT/views-stubs.txt"
  else echo "the stub that fails as the test does: refused  <-- it must be taken" >> "$OUT/views-stubs.txt"; fi
  [ "$ok" = 4 ] || no "views_control's own controls (views-stubs.txt)"
  echo "  views_control's own controls: $ok of 4 as they must be (views-stubs.txt)"
}
s_perturbed() {
  local got want
  want=$(awk '$1 == "push" {print substr($2, 1, 16)}' "$TOY/golden.txt")
  # shellcheck disable=SC2046
  (cd "$TOY" && $PY "$T/perturb3.py" . "$OUT/c-perturbed.jsonl.gz" $($PY -c 'import sys; sys.path.insert(0, "."); import check; print(" ".join(check.BASE + check.CELLS["push"]))') --digest \
      > "$OUT/c-perturbed.out" 2> "$OUT/c-perturbed.err")
  got=$(digest_of "$OUT/c-perturbed.out")
  if [ -n "$want" ] && [ -n "$got" ] && [ "$got" != "$want" ] && has -E '^perturb3: ' "$OUT/c-perturbed.err"; then
    echo "  control, a tracer that perturbs: push's digest is $got, golden.txt's $want: another, as it must be"
  else no "control, a tracer that perturbs: digest ${got:-none}, golden.txt's ${want:-none}, or the perturbing view did not say it ran"; fi
}
s_schemacontrols() {    # the generator's check and the makers' check: each planted change must fail them
  { $PY "$T/gen/gen.py" --control "$OUT/twin" "$OUT/c-schema" && $PY "$T/gen/makers.py" --control "$OUT/twin" "$OUT/c-makers"; } > "$OUT/c-schema.txt" 2>&1 \
    || no "the controls of the schema's checks (c-schema.txt)"
  grep -E '^ok: |wrong$' "$OUT/c-schema.txt" | sed 's/^/  /'
}
s_viewcontrols() {      # each broken view must fail its own cases, as many as written here
  local opt n what bad=0
  : > "$OUT/views-controls.txt"
  while read -r opt n what; do
    views_control "$opt" "$what" "$n" || bad=1
  done <<'EOF_VIEWS'
--broken 13 do not log 'k in t'
--broken-level 3 do not note at the assignment what a level brings
--broken-alloc 7 store the row a read of a missing one hands out
--broken-copy 11 hand out a fresh entry of no table for a missing one
--broken-callee 26 keep no log apart for a call on the tape
--broken-keys 1 put no keys on the tape for another section's level
--broken-mesh 1 answer the mesh question in rising order
--broken-rows 19 observe no row above an entry touched
--broken-bread 2 take no block's read after a callee's or an observation
--broken-order 4 keep a callee's own order of touches
--broken-lanes 11 do not take a PeerQueue's lane as a key
--broken-ordered 4 put no order of an ordered level on the tape
--broken-alias 1 have an alias check that refuses nothing
--broken-made-rows 3 write only the touched entry of a row made in the call
--broken-ordered-levels 3 ask no order below a table's top level
--broken-attr-reads 2 know no method's reads
--broken-cw-writes 1 leave out of a call's writes a callee's write the block undid
--broken-list 11 log nothing of a list of the namespace
--broken-values-order 1 ask no order of a table's values
--broken-cell 3 log the count's += and -= as a write alone
--broken-line 4 log the line's changes as a write alone
--broken-pop-miss 5 take a pop that finds nothing as a write too
--broken-row-reads 11 read no row on the way down where a trace's header asks for it
EOF_VIEWS
  [ "$bad" = 0 ] || no "a broken view does not fail its cases as written (views-controls.txt)"
  [ "$(grep -c ', as they must$' "$OUT/views-controls.txt")" = 23 ] || no "not 23 broken views fail as written (views-controls.txt)"
  views_control_controls
  echo "  $(grep -c ', as they must$' "$OUT/views-controls.txt") of 23 broken views fail their cases, as they must"
}
chain_args() {          # $1: a cell of the chain cases: run.py's arguments
  case $1 in
    hand5-peer) echo "$HAND5 --doc seacast --promise-mode peer" ;;
    das-hoardcol-w16) echo "$DAS30 --fault hoardcol20 --rebuilt-seen on --repair-sample 3:1,6:2 --withhold 16" ;;
    das-samplers-mcoff) echo "$DAS30 --samplers 20 --member-check off" ;;  # das-samplers' delivery (its digest):
    #                     its one record that reaches owed_missing, and defer_on_claim's swapped draw
    das-samplers) echo "$DAS30 --samplers 20" ;;  # the member check on: the flipped answer's cell, (h) and (i)
    # the replaced names' rows (R3-9): a cell for each name that only these runs replace inside a record
    das-claim) echo "$DAS30 --fault claim10" ;;                # send_have, at the liars
    das-keeper-ignore) echo "$DAS30 --keeper-claims ignore" ;; # note_claim, at the supernodes
    das-hoardcol-bias) echo "$DAS30 --fault hoardcol20 --rebuilt-seen on --repair-sample 3:1,6:2 --withhold 16 --repair-bias 0.5" ;;
    #                     control (m): the bias layer restores a shuffled taken before the install, and the tracer stops
    # the alarm's cell (alarm_cell): --alarm-wait's filter_entry, a replaced name, entered outside every record at the
    # honest nodes; its custodians alarm, and no member asks a claimant, so alarm_due is never armed
    das-alarm) echo "--doc seacast --setting rows --nodes 30 --degree 8 --msgs 1 --row-subnets 4 --blobs 4 --withhold 64 --fault hoardcol20 --rebuilt-seen on --repair-sample 3:1,6:2 --alarm-wait 3.5 --seed 22" ;;
    # piece D's stops: seacast/hand5's arguments (plant (p)'s control), and with --source-offers off (point 6)
    hand5-v2) echo "$HAND5 --doc seacast" ;;
    hand5-off) echo "$HAND5 --doc seacast --source-offers off" ;;
    # piece E's carried 7: a custody cell whose churn makes keep_floor open a link, at node a, inside whose question
    # node c's on_open sends a JOIN and a relation
    custody-floor-churn1) echo "--nodes 30 --degree 8 --msgs 1 --setting custody --blobs 4 --seed 7 --doc seacast --upkeep on --keep-floor on --churn 1" ;;
  esac
}
chain_expect() {        # $1: a cell of the chain cases: its cases (chaincases.py's), one a line
  local n
  case $1 in
    hand5-peer) printf '%s\n' \
      '*:close_promises:kept:Node._peer_promise.<locals>.close_promises,Node._override.<locals>.close_promises,doc' \
      '*:filter_entry:replaced:Node._peer_promise.<locals>.filter_entry,doc' \
      '*:owed_missing:kept:Node._member_check.<locals>.owed_missing,doc' ;;
    das-hoardcol-w16)   # the hoarders, each a case; and node 1, honest, on the document's own push_rebuilt, and
      #                   its two observers over defer_on_claim, outermost first (the walk's order, not the bindings')
      for n in 7 8 11 16 23 24; do echo "$n:push_rebuilt:replaced:Node._hoard_column.<locals>.push_rebuilt,doc"; done
      echo '1:push_rebuilt:kept:-'
      echo '1:defer_on_claim:kept:Node._hoard_column.<locals>.defer_on_claim,Node._seacast.<locals>.defer_on_claim,doc' ;;
    das-samplers-mcoff) echo '*:owed_missing:replaced:Node._member_check.<locals>.owed_missing,doc' ;;
  esac
}
cases_of() {            # $1: a trace; $2: a cell of the chain cases: its cases on that trace; the status chaincases.py's
  local -a cs
  mapfile -t cs < <(chain_expect "$2")
  $PY "$T/chaincases.py" "$1" "${cs[@]}"
}
replay_clean() {        # $1: a trace, without .jsonl.gz: its replay as s_replays reads one, but for bare calls; why
  local f=$OUT/$1.replay  #   not, on stdout. A chain cell may run a replaced name outside every record (filter_entry
  #                         under --promise-mode peer, decode_group under --rebuilt-seen on): its callees run bare and
  #                         are counted, the stated limit; the count is reported (bare_count), not refused
  [ -s "$f" ] || { echo "no replay"; return 1; }
  [ "$(cat "$f.rc" 2> /dev/null)" = 0 ] || { echo "the replay exited $(cat "$f.rc" 2> /dev/null || echo '?')"; return 1; }
  parsed_whole "$f" || { echo "the parser refused a line of it"; return 1; }
  has -E '^replay: [1-9][0-9]* records, [1-9][0-9]* ok, 0 mismatched$' "$f" || { echo "a record mismatched, or none read"; return 1; }
  has -x "reads of the Python's that the twin did not make: 0" "$f" || { echo "a read of the Python's not made"; return 1; }
  [ -s "$OUT/$1.jsonl.gz.bare.json" ] || { echo "its run wrote no .bare.json"; return 1; }
  has -E "^content: as --content's, [0-9]+ names\$" "$f" || { echo "its content line was not compared, or is not this tree's"; return 1; }
  if grep -E '^(content|header|nodes|trailer|consts|subset): ' "$f" | grep -v -e '^header: {' -e "^content: as --content's, " | grep -q .; then
    echo "the replay refused a line of the envelope"; return 1
  fi
}
bare_count() {          # $1: a trace, without .jsonl.gz: its run's bare calls, all nodes and names, from its .bare.json
  $PY -c 'import json, sys; print(sum(json.load(open(sys.argv[1])).values()))' "$OUT/$1.jsonl.gz.bare.json" 2> /dev/null || echo "?"
}
chain_plant() {         # $1: a plant's letter; $2: tracerfaults3.py's option; $3: its cell: traced, its status kept;
  local p=$1 f=$2 c=$3  #   replayed where it ran to its end
  rm -f "$OUT/chains/plant-$p".*
  # shellcheck disable=SC2046
  (cd "$TOY" && $PY "$T/tracerfaults3.py" "--$f" . "$OUT/chains/plant-$p.jsonl.gz" $(chain_args "$c") \
      > "$OUT/chains/plant-$p.out" 2> "$OUT/chains/plant-$p.err")
  echo $? > "$OUT/chains/plant-$p.rc"
  if [ "$(cat "$OUT/chains/plant-$p.rc")" = 0 ]; then replay_of "chains/plant-$p"; fi
  return 0
}
plant_misses() {        # $1: a plant's letter; $2: its cell: the plant's trace's cases that are NOT, on stdout
  cases_of "$OUT/chains/plant-$1.jsonl.gz" "$2" > "$OUT/chains/plant-$1.cases"
  grep ': NOT: ' "$OUT/chains/plant-$1.cases"
}
plant_line() {          # $1: a plant's letter: its planted count and its replay's line, for the report
  echo "$(grep -m 1 -E '^tracerfaults3: ' "$OUT/chains/plant-$1.err" | cut -c16-120); its replay: $(grep -m 1 '^replay: ' "$OUT/chains/plant-$1.replay" 2> /dev/null || echo none); bare calls counted: $(bare_count "chains/plant-$1")"
}
chain_cases() {         # the chain cases: the nodes line's chains on real cells, and five plants, each caught; and
  #                       a flipped answer, refused as an observer and replayed as a change
  local cells plants flips c p why k all=0 good=0 caught=0 miss stop dhow="" want_stop
  if [ -n "$NODAS" ]; then cells="hand5-peer"; plants="a b e"; flips=
  else cells="hand5-peer das-hoardcol-w16 das-samplers-mcoff"; plants="a b c d e"; flips="h i"; fi
  mkdir -p "$OUT/chains"; : > "$OUT/c-chains.txt"
  # shellcheck disable=SC2046
  for c in $cells; do par small "$c" chains "" $(chain_args "$c"); done
  for p in $plants $flips; do
    case $p in
      b) par chain_plant b chain-filter-observer-v2 hand5-peer ;;
      c) par chain_plant c chain-bindings-v2 das-hoardcol-w16 ;;
      d) par chain_plant d chain-owed-observer-v2 das-samplers-mcoff ;;
      e) par chain_plant e chain-owed-changing-v2 hand5-peer ;;
      h) par chain_plant h owed-flipped-observer-v2 das-samplers ;;
      i) par chain_plant i owed-flipped-changing-v2 das-samplers ;;
    esac
  done
  par_end || true       # each cell's digest and each plant's status are read below
  # each cell: traced with the untraced run's digest, replayed clean, and its cases as written
  for c in $cells; do
    k=$(chain_expect "$c" | wc -l); all=$((all + k))
    if ! grep -q ': the same$' "$OUT/chains/$c.digest" 2> /dev/null; then
      echo "$c: not traced, or its digest is not the untraced run's  <-- NOT" >> "$OUT/c-chains.txt"; continue
    fi
    if ! why=$(replay_clean "chains/$c"); then echo "$c: its replay: $why  <-- NOT" >> "$OUT/c-chains.txt"; continue; fi
    cases_of "$OUT/chains/$c.jsonl.gz" "$c" > "$OUT/chains/$c.cases"
    good=$((good + $(grep -c ': as it must (' "$OUT/chains/$c.cases")))
    if grep -q ': NOT: ' "$OUT/chains/$c.cases"; then
      echo "$c: $(tail -n 1 "$OUT/chains/$c.cases")  <-- NOT" >> "$OUT/c-chains.txt"; continue
    fi
    echo "$c: $(tail -n 1 "$OUT/chains/$c.cases"); $(grep -m 1 '^replay: ' "$OUT/chains/$c.replay"); digest the untraced run's; bare calls counted: $(bare_count "chains/$c")" >> "$OUT/c-chains.txt"
    if [ "$c" = das-samplers-mcoff ]; then  # the off layer's rows: none, and the cell would not test what it is for
      $PY "$T/chaincases.py" --rows owed_missing "$OUT/chains/$c.jsonl.gz" > "$OUT/chains/$c.rows"
      echo "$c: $(cut -c13- "$OUT/chains/$c.rows")" >> "$OUT/c-chains.txt"
      has -E 'on the tapes: [1-9][0-9]* rows' "$OUT/chains/$c.rows" || echo "$c: no owed_missing row on its tapes  <-- NOT" >> "$OUT/c-chains.txt"
    fi
  done
  # (a) hand5-peer's trace, close_promises' chain cut to its bound layer: the replay must refuse it with its words
  if [ -f "$OUT/chains/hand5-peer.jsonl.gz" ] \
      && $PY "$T/chaincases.py" --cut close_promises "$OUT/chains/hand5-peer.jsonl.gz" "$OUT/chains/plant-a.jsonl.gz" > "$OUT/chains/plant-a.err"; then
    if replay_of chains/plant-a; then
      echo "(a) the cut chain: the replay passed it  <-- NOT" >> "$OUT/c-chains.txt"
    elif ! parsed_whole "$OUT/chains/plant-a.replay"; then
      echo "(a) the cut chain: the parser refused a line of it, not the twin  <-- NOT" >> "$OUT/c-chains.txt"
    elif has -x "nodes: chains: close_promises: its innermost layer is not the document's, and the node has not replaced it" "$OUT/chains/plant-a.replay"; then
      echo "(a) the cut chain: caught: $(cut -c13- "$OUT/chains/plant-a.err"); the replay refused it, with its words" >> "$OUT/c-chains.txt"; caught=$((caught + 1))
    else echo "(a) the cut chain: the replay refused it otherwise than by its words  <-- NOT" >> "$OUT/c-chains.txt"; fi
  else echo "(a) the cut chain: not made  <-- NOT" >> "$OUT/c-chains.txt"; fi
  # (b)-(e): each traced to its end, its cases failing on what the plant changed and on nothing else; (b) and (d), an
  # observer's class where the layer is not one, may instead be stopped by the observer's own check, which then says
  # so, naming the planted layer (ObservedLayer.words)
  for p in $plants; do
    case $p in a) continue ;; esac
    if ! has -E "^tracerfaults3: chain-[a-z-]*-v2, planted [1-9][0-9]* times?$" "$OUT/chains/plant-$p.err"; then
      echo "($p) not planted, or its line is not as written  <-- NOT" >> "$OUT/c-chains.txt"; continue
    fi
    if [ "$(cat "$OUT/chains/plant-$p.rc")" != 0 ]; then
      case $p in
        b) want_stop='Node\._peer_promise\.<locals>\.filter_entry \(node\.py:[0-9]+\) over filter_entry' ;;
        d) want_stop='Node\._member_check\.<locals>\.owed_missing \(node\.py:[0-9]+\) over owed_missing' ;;
        *) want_stop= ;;
      esac
      stop=$(grep -m 1 -E "^trace3: node [0-9]+: the observer $want_stop " "$OUT/chains/plant-$p.err")
      case $p in
        b|d) if [ -n "$stop" ]; then echo "($p) caught: the tracer stopped: $(echo "$stop" | cut -c1-160)" >> "$OUT/c-chains.txt"; caught=$((caught + 1))
               [ "$p" = d ] && dhow=stop
             else echo "($p) the tracer stopped without the planted layer's words, as an observer  <-- NOT" >> "$OUT/c-chains.txt"; fi ;;
        *) echo "($p) the tracer stopped  <-- NOT" >> "$OUT/c-chains.txt" ;;
      esac
      continue
    fi
    case $p in
      b) miss=$(plant_misses b hand5-peer); k=1
         want='^\*:filter_entry:replaced:[^ ]*: NOT: filter_entry is not in replaced at every node \([0-9]+\)$' ;;
      c) miss=$(plant_misses c das-hoardcol-w16); k=7     # each hoarder's chain: the lambda, before the layer; and
         #                                                   node 1's two observers in binding order, inner first
         want='^((7|8|11|16|23|24):push_rebuilt:replaced:[^ ]*: NOT: its chain is \[([^]]*, )?"Node\._seacast\.<locals>\.<lambda>", ([^]]*, )?"Node\._hoard_column\.<locals>\.push_rebuilt", "doc"\], not \["Node\._hoard_column\.<locals>\.push_rebuilt", "doc"\]|1:defer_on_claim:kept:[^ ]*: NOT: its chain is \["Node\._seacast\.<locals>\.defer_on_claim", "Node\._hoard_column\.<locals>\.defer_on_claim", "doc"\], not \["Node\._hoard_column\.<locals>\.defer_on_claim", "Node\._seacast\.<locals>\.defer_on_claim", "doc"\])$' ;;
      d) miss=$(plant_misses d das-samplers-mcoff); k=1
         want='^\*:owed_missing:replaced:[^ ]*: NOT: owed_missing is not in replaced at every node \([0-9]+\)$' ;;
      e) miss=$(plant_misses e hand5-peer); k=1
         want='^\*:owed_missing:kept:[^ ]*: NOT: owed_missing is in replaced at every node \([0-9]+\)$' ;;
    esac
    if [ -z "$miss" ]; then echo "($p) its cases all hold  <-- NOT" >> "$OUT/c-chains.txt"
    elif [ "$(echo "$miss" | wc -l)" != "$k" ] || echo "$miss" | grep -v -q -E "$want"; then
      echo "($p) its cases fail otherwise than written: $(echo "$miss" | head -n 2 | cut -c1-200 | tr '\n' '|')  <-- NOT" >> "$OUT/c-chains.txt"
    elif [ "$p" = d ] && ! { has -E '^replay: [0-9]+ records, [0-9]+ ok, 1 mismatched$' "$OUT/chains/plant-d.replay" \
        && has -x "reads of the Python's that the twin did not make: 0" "$OUT/chains/plant-d.replay" \
        && has -E '^mismatch reconsider: tape: type_of_group\["[0-9a-f]{64}"\] asked, the tape is over logged: 1$' "$OUT/chains/plant-d.replay" \
        && parsed_whole "$OUT/chains/plant-d.replay"; }; then
      # (d)'s replay half: the twin runs the document's owed_missing where the toy's layer ran none of it, so it asks
      # a question the record's tape does not hold, at the one record that calls owed_missing, and nowhere else
      echo "(d) its replay does not refuse its one record with its words: $(grep -m 1 '^replay: ' "$OUT/chains/plant-d.replay" 2> /dev/null)  <-- NOT" >> "$OUT/c-chains.txt"
    else
      echo "($p) caught: $k case$([ "$k" = 1 ] || echo s) failing as written ($(echo "$miss" | head -n 1 | sed 's/: NOT: /: /' | cut -c1-140)); $(plant_line "$p")" >> "$OUT/c-chains.txt"
      caught=$((caught + 1))
      [ "$p" = d ] && dhow=replay
    fi
  done
  # (h), (i): owed_missing's answer flipped on das-samplers by a layer of tracerfaults3's own, which calls the member
  # check's (so the document's) and returns the opposite. (h), listed an observer: the replay must refuse each record
  # whose call it flipped, with rule 2's words (the twin returns where the toy went on), and nothing else (a mismatch
  # line holds the function and its error's first two parts by ":", so not the rest of the tape). (i), listed
  # as changing, its control: the call a question with the flipped answer on the tape, the replay clean. The two run
  # the same toy, the listing alone differing: the same digest, records and flipped calls, or the listing reached it
  # (h) is held further: no owed_missing row on its tapes (an observer's call is on none), its planted layers one at
  # each node, and, where the replay names each refused record (20 at most), those records (i)'s with the flipped row
  local flip="the flipped answer:" kf ni="" ki="" di="" chain="owed_flipped_seacast.<locals>.plant.<locals>.owed_missing,Node._member_check.<locals>.owed_missing,doc"
  local nn
  nn=$(echo "$DAS30" | sed -n -E 's/.*--nodes ([0-9]+) .*/\1/p')
  for p in ${flips:+i h}; do            # (i) first: (h) is held to its counts and digest
    if [ "$(cat "$OUT/chains/plant-$p.rc" 2> /dev/null)" != 0 ]; then
      echo "($p) the flipped answer: the run did not end with 0  <-- NOT" >> "$OUT/c-chains.txt"; continue
    fi
    kf=$(sed -n -E "s/^tracerfaults3: owed-flipped-[a-z]+-v2, planted $nn times; flipped: ([1-9][0-9]*)\$/\1/p" "$OUT/chains/plant-$p.err")
    if [ -z "$kf" ]; then echo "($p) the flipped answer: not planted once at each of the cell's $nn nodes, or no call flipped  <-- NOT" >> "$OUT/c-chains.txt"; continue; fi
    [ "$p" = h ] && k=kept || k=replaced
    if ! $PY "$T/chaincases.py" "$OUT/chains/plant-$p.jsonl.gz" "*:owed_missing:$k:$chain" > "$OUT/chains/plant-$p.cases"; then
      echo "($p) the flipped answer: owed_missing not $k with the flip's chain at every node: $(head -n 1 "$OUT/chains/plant-$p.cases" | cut -c1-200)  <-- NOT" >> "$OUT/c-chains.txt"; continue
    fi
    case $p in
      h) $PY "$T/chaincases.py" --rows owed_missing "$OUT/chains/plant-h.jsonl.gz" > "$OUT/chains/plant-h.rows"
         if [ -z "$ni" ] || [ "$kf" != "$ki" ] || [ "$(sed -n -E 's/^replay: ([0-9]+) records.*/\1/p' "$OUT/chains/plant-h.replay")" != "$ni" ] \
             || [ "$(sed -n 's/^digest \(.\{16\}\).*/\1/p' "$OUT/chains/plant-h.out" | head -n 1)" != "$di" ]; then
           echo "(h) the flipped answer, listed an observer: not (i)'s run (records $ni, flipped $ki, digest $di): its listing reached the toy, or (i) failed  <-- NOT" >> "$OUT/c-chains.txt"
         elif ! has -x "chaincases: owed_missing on the tapes: 0 rows; by node {}; nodes replacing it: 0, with rows: 0; rows at other nodes: 0" "$OUT/chains/plant-h.rows"; then
           echo "(h) the flipped answer, listed an observer: owed_missing on its tapes, where an observer's call is on none: $(cut -c13- "$OUT/chains/plant-h.rows" | cut -c1-120)  <-- NOT" >> "$OUT/c-chains.txt"
         elif [ "$kf" -le 20 ] && ! $PY "$T/chaincases.py" --flipped owed_missing "$OUT/chains/plant-i.jsonl.gz" "$OUT/chains/plant-h.replay" > "$OUT/chains/plant-h.flipped"; then
           echo "(h) the flipped answer, listed an observer: the records its replay names are not (i)'s with the flipped row: $(cut -c13- "$OUT/chains/plant-h.flipped" | cut -c1-200)  <-- NOT" >> "$OUT/c-chains.txt"
         elif has -E "^replay: [0-9]+ records, [0-9]+ ok, $kf mismatched\$" "$OUT/chains/plant-h.replay" \
             && has -x "reads of the Python's that the twin did not make: 0" "$OUT/chains/plant-h.replay" \
             && [ "$(grep '^mismatch ' "$OUT/chains/plant-h.replay" | grep -c -v -E '^mismatch reconsider: tape: the toy asked more: [0-9]+$')" = 0 ] \
             && [ "$(sed -n -E 's/^mismatch reconsider: tape: the toy asked more: ([0-9]+)$/\1/p' "$OUT/chains/plant-h.replay")" = "$kf" ] \
             && parsed_whole "$OUT/chains/plant-h.replay"; then
           echo "(h) the flipped answer, listed an observer: refused at its $kf record$([ "$kf" = 1 ] || echo s), on (i)'s run: $(grep -m 1 '^replay: ' "$OUT/chains/plant-h.replay"); $(grep -m 1 '^mismatch ' "$OUT/chains/plant-h.replay" | cut -c1-120)$([ "$kf" -le 20 ] || echo "; its records not compared with (i)'s: the replay names 20 at most")" >> "$OUT/c-chains.txt"
           flip="$flip refused as an observer at its $kf record$([ "$kf" = 1 ] || echo s) of the same run"
         else echo "(h) the flipped answer, listed an observer: not refused at its $kf flipped record(s) alone, by rule 2's words: $(grep -m 1 '^replay: ' "$OUT/chains/plant-h.replay" 2> /dev/null)  <-- NOT" >> "$OUT/c-chains.txt"; fi ;;
      i) $PY "$T/chaincases.py" --rows owed_missing "$OUT/chains/plant-i.jsonl.gz" > "$OUT/chains/plant-i.rows"
         if ! why=$(replay_clean chains/plant-i); then echo "(i) the flipped answer, listed as changing: its replay: $why  <-- NOT" >> "$OUT/c-chains.txt"
         elif ! has -E "on the tapes: $kf rows \\(true: $kf\\); by node \\{[^}]*\\}; nodes replacing it: $nn, with rows: [1-9][0-9]*; rows at other nodes: 0\$" "$OUT/chains/plant-i.rows"; then
           echo "(i) the flipped answer, listed as changing: not its $kf flipped answers on the tapes: $(cut -c13- "$OUT/chains/plant-i.rows")  <-- NOT" >> "$OUT/c-chains.txt"
         else
           ni=$(sed -n -E 's/^replay: ([0-9]+) records.*/\1/p' "$OUT/chains/plant-i.replay"); ki=$kf
           di=$(sed -n 's/^digest \(.\{16\}\).*/\1/p' "$OUT/chains/plant-i.out" | head -n 1)
           if [[ ! $di =~ ^[0-9a-f]{16}$ ]]; then     # an empty digest would match (h)'s empty one
             echo "(i) the flipped answer, listed as changing: no digest of 16 hex digits in its run's output: ${di:-none}  <-- NOT" >> "$OUT/c-chains.txt"
             ni=""
           else
             echo "(i) the flipped answer, listed as changing (the control): $(grep -m 1 '^replay: ' "$OUT/chains/plant-i.replay"); $(cut -c13- "$OUT/chains/plant-i.rows"); digest ${di:-none}" >> "$OUT/c-chains.txt"
             flip="$flip replayed as a change,"
           fi
         fi ;;
    esac
  done
  local nplants
  nplants=$(echo $plants | wc -w)
  if grep -q '<-- NOT' "$OUT/c-chains.txt" || [ "$good" != "$all" ] || [ "$caught" != "$nplants" ]; then
    no "the chain cases (c-chains.txt)"
  fi
  local plants_said="$caught plants each caught"
  [ "$caught" = "$nplants" ] || plants_said="$caught of $nplants plants caught"
  if [ -n "$NODAS" ]; then
    echo "  the chain cases: $good of $all on hand5-peer, and $plants_said (--no-das: the DAS cells das-hoardcol-w16 and das-samplers-mcoff, plants (c) and (d) on them, and the flipped answer on das-samplers, skipped)"
  else
    case $dhow in       # how (d) was caught: its cases and its replay, or the tracer's stop at its layer
      replay) dhow="(d) by its replay too" ;;
      stop) dhow="(d) by the tracer's stop" ;;
      *) dhow="(d) not caught" ;;
    esac
    echo "  the chain cases: $good of $all on three cells, and $plants_said, $dhow; $flip"
  fi
}
swapped_draws() {       # K13: each swapped draw's draws on the tape of a cell that enters its layer, and two plants
  local hand nd why stop also n=0
  : > "$OUT/c-draws.txt"
  # keep_floor's: seacast/hand5 (small's trace), the records that reach keep_floor
  $PY "$T/chaincases.py" --rows sample_without_replacement "$OUT/seacast/hand5.jsonl.gz" keep_floor > "$OUT/c-draws-hand5.rows"
  hand=$(sed -n -E 's/.*reach keep_floor: ([0-9]+) rows.*/\1/p' "$OUT/c-draws-hand5.rows")
  if [ "${hand:-0}" -ge 1 ]; then echo "seacast/hand5: $(cut -c13- "$OUT/c-draws-hand5.rows")" >> "$OUT/c-draws.txt"
  else echo "seacast/hand5: no keep_floor draw on its tapes  <-- NOT" >> "$OUT/c-draws.txt"; fi
  # defer_on_claim@1775's: das-samplers-mcoff (the chain cases' trace), the records that reach defer_on_claim
  if [ -z "$NODAS" ]; then
    if [ -f "$OUT/chains/das-samplers-mcoff.replay" ] && replay_clean chains/das-samplers-mcoff > /dev/null; then
      $PY "$T/chaincases.py" --rows choice "$OUT/chains/das-samplers-mcoff.jsonl.gz" defer_on_claim > "$OUT/c-draws-samplers.rows"
      nd=$(sed -n -E 's/.*reach defer_on_claim: ([0-9]+) rows.*/\1/p' "$OUT/c-draws-samplers.rows")
      if [ "${nd:-0}" -ge 1 ]; then echo "das-samplers-mcoff: $(cut -c13- "$OUT/c-draws-samplers.rows")" >> "$OUT/c-draws.txt"
      else echo "das-samplers-mcoff: no defer_on_claim draw on its tapes  <-- NOT" >> "$OUT/c-draws.txt"; fi
    else echo "das-samplers-mcoff: not traced, or its replay not clean (the chain cases')  <-- NOT" >> "$OUT/c-draws.txt"; fi
  fi
  # (f) the re-wrap off: the trace written to its end, every keep_floor record without its draw, which the replay
  # must refuse there and nowhere else, with its words, the first at node 1's keep_floor
  rm -f "$OUT/c-draws-f".*
  if ! (cd "$TOY" && $PY "$T/tracerfaults3.py" --draws-rewrap-off-v2 . "$OUT/c-draws-f.jsonl.gz" > "$OUT/c-draws-f.out" 2> "$OUT/c-draws-f.err"); then
    echo "(f) the re-wrap off: the run did not end with 0  <-- NOT" >> "$OUT/c-draws.txt"
  elif ! has -E "^tracerfaults3: draws-rewrap-off-v2, planted $hand times?\$" "$OUT/c-draws-f.err"; then
    echo "(f) the re-wrap off: not planted once for each of hand5's $hand keep_floor draws  <-- NOT" >> "$OUT/c-draws.txt"
  elif replay_of c-draws-f; then
    echo "(f) the re-wrap off: the replay passed it  <-- NOT" >> "$OUT/c-draws.txt"
  elif ! parsed_whole "$OUT/c-draws-f.replay"; then
    echo "(f) the re-wrap off: the parser refused a line of it, not the twin  <-- NOT" >> "$OUT/c-draws.txt"
  elif ! has -E "^replay: [0-9]+ records, [0-9]+ ok, $hand mismatched\$" "$OUT/c-draws-f.replay"; then
    echo "(f) the re-wrap off: the replay mismatched otherwise than at hand5's $hand keep_floor records: $(grep -m 1 '^replay: ' "$OUT/c-draws-f.replay")  <-- NOT" >> "$OUT/c-draws.txt"
  elif [ "$(grep -c '^mismatch ' "$OUT/c-draws-f.replay")" != 1 ] \
      || ! has -x -F "mismatch keep_floor: tape: sample_without_replacement[[],0] asked, the tape is over logged: $hand" "$OUT/c-draws-f.replay"; then
    echo "(f) the re-wrap off: the replay refused it otherwise than by its words alone, keep_floor's at each of its $hand records  <-- NOT" >> "$OUT/c-draws.txt"
  else
    echo "(f) the re-wrap off: caught: $(grep -m 1 '^replay: ' "$OUT/c-draws-f.replay"); $(grep -m 1 -F 'tape: sample_without_replacement[[],0] asked, the tape is over logged' "$OUT/c-draws-f.replay" | cut -c1-160)" >> "$OUT/c-draws.txt"
    n=$((n + 1))
  fi
  # (g) the swap left unrestored: the record's exit check must stop the tracer, final_check's words after the stop
  rm -f "$OUT/c-draws-g".*
  stop="^trace3: node 1: sample_without_replacement is bound to draws_unrestored_seacast\.<locals>\..*<lambda> \(tracerfaults3\.py:[0-9]+\) at the exit of keep_floor's record, not to the tracer's own binding"
  also="^trace3: \(at the close, after the stop\) SystemExit: trace3: node 1: sample_without_replacement was bound again after the tracer was installed, which under SEACAST must be the namespace's last binding: draws_unrestored_seacast\.<locals>\..*<lambda> \(tracerfaults3\.py:[0-9]+\)$"
  if (cd "$TOY" && $PY "$T/tracerfaults3.py" --draws-unrestored-v2 . "$OUT/c-draws-g.jsonl.gz" > "$OUT/c-draws-g.out" 2> "$OUT/c-draws-g.err"); then
    echo "(g) the swap unrestored: the tracer wrote its trace to its end  <-- NOT" >> "$OUT/c-draws.txt"
  elif has -E "^tracerfaults3: draws-unrestored-v2, planted [1-9][0-9]* times?\$" "$OUT/c-draws-g.err" && has -E "$stop" "$OUT/c-draws-g.err" && has -E "$also" "$OUT/c-draws-g.err"; then
    echo "(g) the swap unrestored: caught: $(grep -m 1 -E "$stop" "$OUT/c-draws-g.err" | cut -c1-200)" >> "$OUT/c-draws.txt"
    n=$((n + 1))
  else echo "(g) the swap unrestored: the tracer stopped without the words it must give  <-- NOT" >> "$OUT/c-draws.txt"; fi
  if grep -q '<-- NOT' "$OUT/c-draws.txt"; then no "the swapped draws (c-draws.txt)"; fi
  local said="2 plants each caught"
  [ "$n" = 2 ] || said="$n of 2 plants caught"
  if [ -n "$NODAS" ]; then
    echo "  the swapped draws: ${hand:-0} keep_floor draws on seacast/hand5, and $said (--no-das: das-samplers-mcoff's defer_on_claim draws skipped)"
  else echo "  the swapped draws: ${hand:-0} keep_floor draws on seacast/hand5 and ${nd:-0} defer_on_claim draws on das-samplers-mcoff, and $said"; fi
}
stop_cell() {           # $1: a directory under $OUT; $2: a cell of chain_args: traced alone there, its status kept (a
  local d=$1 c=$2       #   cell the tracer must stop)
  rm -f "$OUT/$d/$c".*
  # shellcheck disable=SC2046
  (cd "$TOY" && $PY "$T/trace3.py" . "$OUT/$d/$c.jsonl.gz" $(chain_args "$c") --digest > "$OUT/$d/$c.out" 2> "$OUT/$d/$c.err")
  echo $? > "$OUT/$d/$c.rc"
  return 0
}
arities_plant() {       # a record writer whose arguments are not runSeacast's case's: on_chunk's writer without p, on
  #                       seacast/hand5, traced to its end (the tracer checks no arity); the replay must refuse each
  #                       on_chunk record, as no function of the twin with those arguments, and no other (c-arity.*,
  #                       at the out directory's top, so that the calls summary does not read it)
  local f=c-arity n total
  rm -f "$OUT/$f".*
  read -r total n < <(gzip -dc "$OUT/seacast/hand5.jsonl.gz" 2> /dev/null | tail -n 1 | $PY -c 'import json, sys
t = json.loads(sys.stdin.read())["trailer"]
print(t["records"], t["by_fn"].get("on_chunk", 0))' 2> /dev/null)
  if [ -z "$n" ] || [ "$n" = 0 ]; then no "the record writers' arities: no on_chunk record in seacast/hand5's trailer"; return 0; fi
  if ! (cd "$TOY" && $PY "$T/tracerfaults3.py" --on-chunk-without-p-v2 . "$OUT/$f.jsonl.gz" > "$OUT/$f.out" 2> "$OUT/$f.err"); then
    no "the record writers' arities: the plant's run did not end with 0 ($f.err)"; return 0
  fi
  if ! has -x "tracerfaults3: on-chunk-without-p-v2, planted $n times" "$OUT/$f.err"; then
    no "the record writers' arities: not planted at each of seacast/hand5's $n on_chunk records ($f.err)"; return 0
  fi
  replay_of "$f"
  if ! parsed_whole "$OUT/$f.replay" || ! has -x "replay: $total records, $((total - n)) ok, $n mismatched" "$OUT/$f.replay" \
      || [ "$(grep -c '^mismatch ' "$OUT/$f.replay")" != 1 ] \
      || ! has -x -F "mismatch on_chunk: not a function of the twin under seacast.md, or not its arguments: on_chunk: $n" "$OUT/$f.replay"; then
    no "the record writers' arities: the replay did not refuse exactly the $n on_chunk records, by their arguments ($f.replay)"; return 0
  fi
  echo "  the record writers' arities: on_chunk's writer without p, traced on seacast/hand5 to its end, refused by the replay at its $n on_chunk records and at no other"
}
rows_to() {             # $1: a name; $2: a trace, without .jsonl.gz: the name's rows on its tapes, to rows/NAME.rows
  $PY "$T/chaincases.py" --rows "$1" "$OUT/$2.jsonl.gz" > "$OUT/rows/$1.rows" 2>&1
}
replaced_rows() {       # R3-9: each name the twin asks with rows on a fixture's tapes, where a node replaces it; plant
  #                       (k), a row with an argument left out, which the replay must refuse; and control (m), the
  #                       bias cell, which the record's exit check must stop
  local names="forward push_rebuilt" name fx n calls c d plain k=0 counts= why rec pr m nr nw sum stop also mwant caught=0 stopped=0
  local untied=
  rm -rf "$OUT/rows"; mkdir -p "$OUT/rows"; : > "$OUT/c-rows.txt"
  if [ -z "$NODAS" ]; then
    names="forward push_rebuilt serve_standing owed_missing send_have note_claim repair_verdict known_in_scope"
    # shellcheck disable=SC2046
    { for c in das-claim das-keeper-ignore das-alarm; do par small "$c" rows "" $(chain_args "$c"); done
      par chain_plant j known-replaced-v2 das-samplers-mcoff
      par chain_plant l verdict-replaced-v2 das-hoardcol-w16
      par stop_cell rows das-hoardcol-bias; }
    par_end || true     # each run's status and digest are read below
  fi
  fixture() {           # $1: a name: its fixture, a trace without .jsonl.gz
    case $1 in
      forward|push_rebuilt) echo seacast/hand5-own ;;
      serve_standing) echo chains/das-hoardcol-w16 ;;
      owed_missing) echo chains/das-samplers-mcoff ;;
      send_have) echo rows/das-claim ;;
      note_claim) echo rows/das-keeper-ignore ;;
      repair_verdict) echo chains/plant-l ;;
      known_in_scope) echo chains/plant-j ;;
    esac
  }
  for name in $names; do par rows_to "$name" "$(fixture "$name")"; done
  par_end || true
  for name in $names; do
    fx=$(fixture "$name")
    n=$(sed -n -E "s/^chaincases: $name on the tapes: ([0-9]+) rows.*/\\1/p" "$OUT/rows/$name.rows")
    case $name in
      send_have|note_claim)     # a cell of its own: traced with the untraced run's digest
        if ! grep -q ': the same$' "$OUT/$fx.digest" 2> /dev/null; then
          echo "$name: $fx not traced, or its digest is not the untraced run's  <-- NOT" >> "$OUT/c-rows.txt"; continue
        fi ;;
      repair_verdict|known_in_scope)    # a plant of its own on a chain cell: the cell's run, each call a row
        d=${fx#chains/plant-}
        calls=$(sed -n -E "s/^tracerfaults3: [a-z]+-replaced-v2, planted [1-9][0-9]* times?; calls: ([0-9]+)\$/\\1/p" "$OUT/$fx.err" 2> /dev/null)
        c=$([ "$d" = l ] && echo das-hoardcol-w16 || echo das-samplers-mcoff)
        plain=$(sed -n -E 's/^[^ ]+: digest traced [^ ]+, untraced ([^ :]+): the same$/\1/p' "$OUT/chains/$c.digest" 2> /dev/null)
        if [ "$(cat "$OUT/$fx.rc" 2> /dev/null)" != 0 ] || [ -z "$calls" ]; then
          echo "$name: plant ($d) did not end with 0, or its line is not as written  <-- NOT" >> "$OUT/c-rows.txt"; continue
        elif [ -z "$plain" ] || [ "$(digest_of "$OUT/$fx.out")" != "$plain" ]; then
          echo "$name: plant ($d)'s digest is not $c's untraced one (${plain:-none})  <-- NOT" >> "$OUT/c-rows.txt"; continue
        elif [ "$n" != "$calls" ]; then
          echo "$name: plant ($d)'s ${n:-no} rows are not its $calls calls  <-- NOT" >> "$OUT/c-rows.txt"; continue
        fi ;;
    esac
    if ! why=$(replay_clean "$fx"); then echo "$name: $fx's replay: $why  <-- NOT" >> "$OUT/c-rows.txt"; continue; fi
    # each row at a node whose group in the nodes line replaces the name; C4's three liars and C5's three keepers
    # each with rows
    read -r nr nw < <(sed -n -E 's/.*; nodes replacing it: ([0-9]+), with rows: ([0-9]+); rows at other nodes: [0-9]+$/\1 \2/p' "$OUT/rows/$name.rows")
    if [ "${n:-0}" -ge 1 ] && ! has -E '; rows at other nodes: 0$' "$OUT/rows/$name.rows"; then
      echo "$name on $fx: rows at nodes that do not replace it: $(cut -c13- "$OUT/rows/$name.rows")  <-- NOT" >> "$OUT/c-rows.txt"
      untied=1
    elif [ "${n:-0}" -ge 1 ] && { [ "$name" = send_have ] || [ "$name" = note_claim ]; } && { [ -z "$nr" ] || [ "$nr" != "$nw" ]; }; then
      echo "$name on $fx: a node that replaces it has no row: $(cut -c13- "$OUT/rows/$name.rows")  <-- NOT" >> "$OUT/c-rows.txt"
      untied=1
    elif [ "${n:-0}" -ge 1 ]; then
      echo "$name on $fx: $(cut -c13- "$OUT/rows/$name.rows"); $(grep -m 1 '^replay: ' "$OUT/$fx.replay"); bare calls counted: $(bare_count "$fx")" >> "$OUT/c-rows.txt"
      k=$((k + 1)); counts="$counts${counts:+, }$name $n"
    else echo "$name on $fx: no row on its tapes  <-- NOT" >> "$OUT/c-rows.txt"; fi
  done
  # (k) push_rebuilt's last argument left out of each of its rows on seacast/hand5-own: the replay must refuse each such
  # record, with C8's words (the run's: the entry unparenthesised, its fields three spaces apart), and nothing else; the
  # records refused are counted apart from the rows, from chaincases' own line (a record may hold two rows)
  pr=$(sed -n -E 's/^chaincases: push_rebuilt on the tapes: ([0-9]+) rows.*/\1/p' "$OUT/rows/push_rebuilt.rows")
  rec=$(sed -n -E 's/^replay: ([0-9]+) records.*/\1/p' "$OUT/seacast/hand5-own.replay" 2> /dev/null)
  mwant='^mismatch decode_group: tape: push_rebuilt\["[0-9a-f]{64}",\[[0-9,]*\]\] asked, SpecTwin\.Replay\.Entry\.call   "push_rebuilt"   "\[\\"[0-9a-f]{64}\\"\]"   "null" logged: [0-9]+$'
  if [ -z "$pr" ] || [ "$pr" = 0 ] || [ -z "$rec" ]; then
    echo "(k) the argument left out: no push_rebuilt row on seacast/hand5-own, or no replay of it  <-- NOT" >> "$OUT/c-rows.txt"
  elif ! $PY "$T/chaincases.py" --drop-arg push_rebuilt "$OUT/seacast/hand5-own.jsonl.gz" "$OUT/rows/plant-k.jsonl.gz" > "$OUT/rows/plant-k.err" 2>&1 \
      || ! m=$(sed -n -E "s/^chaincases: the last argument of push_rebuilt left out in $pr rows?, in ([1-9][0-9]*) records?\$/\\1/p" "$OUT/rows/plant-k.err") \
      || [ -z "$m" ]; then
    echo "(k) the argument left out: not made, or not in each of the $pr rows  <-- NOT" >> "$OUT/c-rows.txt"
  elif replay_of rows/plant-k; then
    echo "(k) the argument left out: the replay passed it  <-- NOT" >> "$OUT/c-rows.txt"
  elif ! parsed_whole "$OUT/rows/plant-k.replay"; then
    echo "(k) the argument left out: the parser refused a line of it, not the twin  <-- NOT" >> "$OUT/c-rows.txt"
  elif ! has -x "replay: $rec records, $((rec - m)) ok, $m mismatched" "$OUT/rows/plant-k.replay" \
      || ! has -x "reads of the Python's that the twin did not make: 0" "$OUT/rows/plant-k.replay"; then
    echo "(k) the argument left out: not refused at its $m records alone: $(grep -m 1 '^replay: ' "$OUT/rows/plant-k.replay")  <-- NOT" >> "$OUT/c-rows.txt"
  elif sum=$(sed -n -E 's/^mismatch .* logged: ([0-9]+)$/\1/p' "$OUT/rows/plant-k.replay" | awk '{s += $1} END {print s + 0}') \
      && { [ "$(grep '^mismatch ' "$OUT/rows/plant-k.replay" | grep -c -v -E "$mwant")" != 0 ] || [ "$sum" != "$m" ]; }; then
    echo "(k) the argument left out: refused otherwise than by its words: $(grep -m 1 '^mismatch ' "$OUT/rows/plant-k.replay" | cut -c1-160)  <-- NOT" >> "$OUT/c-rows.txt"
  else
    echo "(k) the argument left out: caught: $(grep -m 1 '^replay: ' "$OUT/rows/plant-k.replay"); $(grep -m 1 '^mismatch ' "$OUT/rows/plant-k.replay" | cut -c1-160); $pr rows in $m records" >> "$OUT/c-rows.txt"
    caught=1
  fi
  # (m) the bias cell: --repair-bias's layer restores the shuffled it took before the install (node.py's _repair_bias),
  # so the record's exit check must stop the tracer at node 2's first reconsider that asks repair_verdict, with
  # final_check's words after the stop: plant (g)'s pair, made by the toy's own layer
  stop="^trace3: node 2: shuffled is bound to Node\\._namespace\\.<locals>\\.shuffled \\(node\\.py:[0-9]+\\) at the exit of reconsider's record, not to the tracer's own binding: a binding made after the install or during a call, which the twin would not run\$"
  also="^trace3: \\(at the close, after the stop\\) SystemExit: trace3: node 2: shuffled was bound again after the tracer was installed, which under SEACAST must be the namespace's last binding: Node\\._namespace\\.<locals>\\.shuffled \\(node\\.py:[0-9]+\\)\$"
  if [ -z "$NODAS" ]; then
    if [ "$(cat "$OUT/rows/das-hoardcol-bias.rc" 2> /dev/null)" = 0 ] || [ ! -f "$OUT/rows/das-hoardcol-bias.rc" ]; then
      echo "(m) the bias cell: not run, or the tracer wrote its trace to its end  <-- NOT" >> "$OUT/c-rows.txt"
    elif has -E "$stop" "$OUT/rows/das-hoardcol-bias.err" && has -E "$also" "$OUT/rows/das-hoardcol-bias.err"; then
      echo "(m) the bias cell: stopped, as it must: $(grep -m 1 -E "$stop" "$OUT/rows/das-hoardcol-bias.err" | cut -c1-200)" >> "$OUT/c-rows.txt"
      stopped=1
    else echo "(m) the bias cell: the tracer stopped without the words it must give  <-- NOT" >> "$OUT/c-rows.txt"; fi
  fi
  if grep -q '<-- NOT' "$OUT/c-rows.txt"; then no "the replaced names' rows (c-rows.txt)"; fi
  local said="plant (k) caught" bias="the bias cell stopped at its binding, as it must"
  [ "$caught" = 1 ] || said="plant (k) not caught"
  [ "$stopped" = 1 ] || bias="the bias cell not stopped as it must be"
  local tied="each name's rows at nodes that replace it alone, and at each of das-claim's 3 liars and das-keeper-ignore's 3 keepers"
  [ -n "$NODAS" ] && tied="each name's rows at nodes that replace it alone"
  [ -z "$untied" ] || tied="a name's rows at a node that does not replace it, or a liar or keeper without rows"
  if [ -n "$NODAS" ]; then
    echo "  the replaced names' rows: $k of 8 names with rows where a node replaces them ($counts), each replay clean; $tied; $said (--no-das: the six DAS names and the bias cell skipped)"
  else echo "  the replaced names' rows: $k of 8 names with rows where a node replaces them ($counts), each replay clean; $tied; $said; $bias: a cell with --repair-bias cannot be traced, because the toy's layer restores a shuffled captured at build (node.py:457, :493)"; fi
}
whole_replay() {        # whole_replay RC N FILE: a replay of N records, whole: exit 0 and FILE's summary line N of N ok
  [ "$1" = 0 ] && [ -n "$2" ] && has -x -F "replay: $2 records, $2 ok, 0 mismatched" "$3"
}
stops() {               # piece D: point 5's stop, plant (p), and its control; point 6's stop (D3), with its entry check
  #                       removed (q), and with both checks removed (D5's control); every cell local
  local n5= f5= nc= fc= rec= nq= plain got why s5 s6 s7 ok5=0 okc=0 ok3=0 okq=0 okr=0
  local line5='s/^tracerfaults3: noask-in-record-v2, planted 1 time; node: ([0-9]+); record: ([a-z_0-9]+)$/\1 \2/p'
  local w6="^trace3: node 1: announce is bound to Node\\._no_source_offers\\.<locals>\\.publish\\.<locals>\\.<lambda> \\(node\\.py:[0-9]+\\) at the"
  local w6b=" of group_id's record, not to the tracer's own binding: a binding made after the install or during a call, which the twin would not run\$"
  # D3's records: hand5-off's trace stops at the entry of node 1's group_id record (D3's stop point) after 53 records,
  # its trailer's by_fn build_group 1, drop_stale_waits 25, group_id 1, group_key 1, keep_floor 25, as traced at
  # 861bca0. Its copy without the stopped key must replay these, a count the trailer under test does not give: a
  # tracer that lost records before the stop and counted what it kept would pass on the trailer's own count. A change
  # of the toy or the tracer that moves the records before the stop fails here, and the count is then set anew
  local D3_RECORDS=53
  mkdir -p "$OUT/chains"; : > "$OUT/c-stops.txt"
  par chain_plant p noask-in-record-v2 hand5-peer
  par chain_plant pc noask-in-record-v2 hand5-v2
  par chain_plant q entry-check-off-v2 hand5-off
  par chain_plant d5 bindings-checks-off-v2 hand5-off
  par stop_cell chains hand5-off
  par_end || true       # each run's status is read below
  # (p) on hand5-peer, where filter_entry is replaced: the record's call of it must stop the tracer, with point 5's
  # words, at the node and record its plant line names
  read -r n5 f5 < <(sed -n -E "$line5" "$OUT/chains/plant-p.err" 2> /dev/null)
  if [ -z "$n5" ] || [ "$(cat "$OUT/chains/plant-p.rc" 2> /dev/null)" = 0 ]; then
    echo "(p) point 5, on hand5-peer: not planted once, or the tracer wrote its trace to its end  <-- NOT" >> "$OUT/c-stops.txt"
  elif ! has -F -x "trace3: node $n5: filter_entry is replaced here, and $f5's record calls it: the twin has no question for filter_entry, and would run its own code there" "$OUT/chains/plant-p.err"; then
    echo "(p) point 5, on hand5-peer: the tracer stopped without point 5's words at node $n5's $f5 record  <-- NOT" >> "$OUT/c-stops.txt"
  else echo "(p) point 5, on hand5-peer: stopped, as it must, at node $n5's $f5 record" >> "$OUT/c-stops.txt"; ok5=1; fi
  # (p)'s control on seacast/hand5, where filter_entry is the document's: the call is the record's own, its writes ones the
  # twin's function does not make, so the replay must refuse that record and no other
  read -r nc fc < <(sed -n -E "$line5" "$OUT/chains/plant-pc.err" 2> /dev/null)
  rec=$(sed -n -E 's/^replay: ([0-9]+) records.*/\1/p' "$OUT/chains/plant-pc.replay" 2> /dev/null)
  if [ -z "$nc" ] || [ "$(cat "$OUT/chains/plant-pc.rc" 2> /dev/null)" != 0 ]; then
    echo "(p)'s control, on hand5-v2: not planted once, or the run did not end with 0  <-- NOT" >> "$OUT/c-stops.txt"
  elif [ -z "$rec" ] || ! has -x "replay: $rec records, $((rec - 1)) ok, 1 mismatched" "$OUT/chains/plant-pc.replay" \
      || ! has -x "reads of the Python's that the twin did not make: 0" "$OUT/chains/plant-pc.replay" \
      || ! parsed_whole "$OUT/chains/plant-pc.replay"; then
    echo "(p)'s control, on hand5-v2: not refused at one record alone: $(grep -m 1 '^replay: ' "$OUT/chains/plant-pc.replay" 2> /dev/null)  <-- NOT" >> "$OUT/c-stops.txt"
  elif [ "$(grep -c '^mismatch ' "$OUT/chains/plant-pc.replay")" != 1 ] || ! has -E "^mismatch $fc: .*: 1\$" "$OUT/chains/plant-pc.replay" \
      || ! has -E "^example: node $nc at [^ ]+ $fc\\[" "$OUT/chains/plant-pc.replay"; then
    echo "(p)'s control, on hand5-v2: refused otherwise than at node $nc's $fc record: $(grep -m 1 '^mismatch ' "$OUT/chains/plant-pc.replay" | cut -c1-160)  <-- NOT" >> "$OUT/c-stops.txt"
  else
    echo "(p)'s control, on hand5-v2: refused at node $nc's $fc record alone, as it must (one mismatch, there; its reason quoted, not checked): $(grep -m 1 '^replay: ' "$OUT/chains/plant-pc.replay"); $(grep -m 1 '^mismatch ' "$OUT/chains/plant-pc.replay" | cut -c1-160)" >> "$OUT/c-stops.txt"
    okc=1
  fi
  # D3: hand5-off, the source's announce bound to the layer's lambda through publish: the first record inside publish
  # must stop the tracer at its entry
  if [ "$(cat "$OUT/chains/hand5-off.rc" 2> /dev/null)" = 0 ] || [ ! -f "$OUT/chains/hand5-off.rc" ]; then
    echo "D3 point 6, on hand5-off: not run, or the tracer wrote its trace to its end  <-- NOT" >> "$OUT/c-stops.txt"
  elif has -E "$w6 entry$w6b" "$OUT/chains/hand5-off.err"; then
    echo "D3 point 6, on hand5-off: stopped, as it must: $(grep -m 1 -E "$w6 entry$w6b" "$OUT/chains/hand5-off.err" | cut -c1-200)" >> "$OUT/c-stops.txt"; ok3=1
  else echo "D3 point 6, on hand5-off: the tracer stopped without the words it must give  <-- NOT" >> "$OUT/c-stops.txt"; fi
  # D3's trace given to the replay: its trailer says it stopped, and the replay must refuse it at that key (Main.lean's
  # envelope: "trailer: not a member of it: stopped"), so that a stopped run is never replayed as a whole one; its
  # control, a copy without the key, which must replay whole (whole_replay, with N D3_RECORDS, which its trailer must
  # also give) and not name the key
  local rcs rcc ncc
  rm -f "$OUT/c-stopped.replay" "$OUT/c-stopped-control.replay" "$OUT/c-stopped-control.jsonl.gz"
  if ! $PY -c 'import gzip, json, sys
t = json.loads(gzip.open(sys.argv[1], "rt").read().splitlines()[-1]).get("trailer") or {}
sys.exit(0 if "stopped" in t else 1)' "$OUT/chains/hand5-off.jsonl.gz" 2> /dev/null; then
    echo "D3's trace, replayed: its trailer does not say it stopped  <-- NOT" >> "$OUT/c-stops.txt"
  else
    zcat "$OUT/chains/hand5-off.jsonl.gz" | "$REPLAY" --content "$CONTENT" > "$OUT/c-stopped.replay" 2>&1; rcs=${PIPESTATUS[1]}
    $PY -c 'import gzip, json, sys
lines = gzip.open(sys.argv[1], "rt").read().splitlines(True)
t = json.loads(lines[-1]); del t["trailer"]["stopped"]
lines[-1] = json.dumps(t, separators=(",", ":")) + "\n"
with gzip.open(sys.argv[2], "wt") as f:
    f.write("".join(lines))' "$OUT/chains/hand5-off.jsonl.gz" "$OUT/c-stopped-control.jsonl.gz"
    zcat "$OUT/c-stopped-control.jsonl.gz" | "$REPLAY" --content "$CONTENT" > "$OUT/c-stopped-control.replay" 2>&1; rcc=${PIPESTATUS[1]}
    ncc=$($PY -c 'import gzip, json, sys
print(json.loads(gzip.open(sys.argv[1], "rt").read().splitlines()[-1])["trailer"]["records"])' "$OUT/c-stopped-control.jsonl.gz" 2> /dev/null)
    if [ "$rcs" = 0 ] || ! has -F "trailer: not a member of it: stopped" "$OUT/c-stopped.replay"; then
      echo "D3's trace, replayed: not refused at its trailer's stopped key (rc $rcs; c-stopped.replay)  <-- NOT" >> "$OUT/c-stops.txt"
    elif [ "$ncc" != "$D3_RECORDS" ] || ! whole_replay "$rcc" "$D3_RECORDS" "$OUT/c-stopped-control.replay" \
        || has -F "trailer: not a member of it: stopped" "$OUT/c-stopped-control.replay"; then
      echo "D3's trace, replayed: its copy without the key not replayed whole as D3's $D3_RECORDS records, or the key named there (rc $rcc, trailer $ncc; c-stopped-control.replay)  <-- NOT" >> "$OUT/c-stops.txt"
    else
      echo "D3's trace, replayed: refused at its trailer's stopped key, as it must (rc $rcs: $(grep -m 1 -F 'trailer: not a member of it: stopped' "$OUT/c-stopped.replay" | cut -c1-120)); its copy without the key: rc 0, \"replay: $ncc records, $ncc ok, 0 mismatched\", $ncc its trailer's records, the key not named" >> "$OUT/c-stops.txt"
    fi
  fi
  # (q): the entry check skipped, the same record's exit check must stop it, with the same words but "exit"
  nq=$(sed -n -E 's/^tracerfaults3: entry-check-off-v2, planted ([1-9][0-9]*) times?$/\1/p' "$OUT/chains/plant-q.err" 2> /dev/null)
  if [ -z "$nq" ] || [ "$(cat "$OUT/chains/plant-q.rc" 2> /dev/null)" = 0 ]; then
    echo "(q) the entry check off, on hand5-off: not planted, or the tracer wrote its trace to its end  <-- NOT" >> "$OUT/c-stops.txt"
  elif has -E "$w6 exit$w6b" "$OUT/chains/plant-q.err" && ! has -E "$w6 entry$w6b" "$OUT/chains/plant-q.err"; then
    echo "(q) the entry check off, on hand5-off: stopped at the exit, as it must ($nq entry checks skipped)" >> "$OUT/c-stops.txt"; okq=1
  else echo "(q) the entry check off, on hand5-off: the tracer stopped without the exit's words  <-- NOT" >> "$OUT/c-stops.txt"; fi
  # D5's control: both checks skipped, the trace runs to its end with the untraced run's digest, and replays clean
  # shellcheck disable=SC2046
  (cd "$TOY" && $PYPLAIN run.py $(chain_args hand5-off) --digest > "$OUT/chains/hand5-off.plain" 2>&1)
  plain=$(digest_of "$OUT/chains/hand5-off.plain"); got=$(digest_of "$OUT/chains/plant-d5.out" 2> /dev/null)
  if [ "$(cat "$OUT/chains/plant-d5.rc" 2> /dev/null)" != 0 ] || ! has -E '^tracerfaults3: bindings-checks-off-v2, planted [1-9][0-9]* times?$' "$OUT/chains/plant-d5.err"; then
    echo "D5's control, on hand5-off: not planted, or the run did not end with 0  <-- NOT" >> "$OUT/c-stops.txt"
  elif [ -z "$plain" ] || [ "$got" != "$plain" ]; then
    echo "D5's control, on hand5-off: its digest ${got:-none} is not the untraced run's (${plain:-none})  <-- NOT" >> "$OUT/c-stops.txt"
  elif ! why=$(replay_clean chains/plant-d5); then
    echo "D5's control, on hand5-off: its replay: $why  <-- NOT" >> "$OUT/c-stops.txt"
  else
    echo "D5's control, on hand5-off: written to its end, digest $got both ways, $(grep -m 1 '^replay: ' "$OUT/chains/plant-d5.replay"); bare calls counted: $(bare_count chains/plant-d5); the lambda's calls not counted" >> "$OUT/c-stops.txt"; okr=1
  fi
  if grep -q '<-- NOT' "$OUT/c-stops.txt"; then no "the stops (c-stops.txt)"; fi
  s5="point 5's at node $n5's $f5 record, with its words"; [ "$ok5" = 1 ] || s5="point 5's not as it must be"
  if [ "$okc" = 1 ]; then s5="$s5, and its control refused at its planted record alone (node $nc's $fc, of $rec records; the reason quoted, not checked)"
  else s5="$s5, and its control not as it must be"; fi
  s6="point 6's at node 1's group_id record, at its entry, and at its exit with the entry check removed"
  [ "$ok3" = 1 ] && [ "$okq" = 1 ] || s6="point 6's not as it must be"
  s7="with both checks removed, the trace written to its end with the untraced digest and replayed clean (the stated limit, from the toy's code, not counted: the toy's source publishes columns alone, so no cell calls the lambda)"
  [ "$okr" = 1 ] || s7="with both checks removed, not as it must be"
  echo "  the stops: $s5; $s6; $s7"
}
carried() {             # piece E: R7's tracer-wide depth on a real cell (carried 7) and its plant (r); a replaced name
  #                       entered outside every record on a real cell (carried 9) and its plants (s) and (t); local
  local c= why s= e1= e2= e3= ok3=0 n3=
  local ls='s/^tracerfaults3: suppressed-filter-v2, planted 2 times; node s: ([0-9]+); entry 1: returned; supp after the return: 0; bare s held: 2; entry 2: raised; supp after the raise: 0$/\1/p'
  local lt='s/^tracerfaults3: suppressed-filter-v2-off, planted 2 times; records inside: 2; node s: ([0-9]+); entry 1: returned; supp after the return: 0; bare s held: 0; entry 2: raised; supp after the raise: 0$/\1/p'
  local st t
  mkdir -p "$OUT/chains"; : > "$OUT/c-carried.txt"
  # shellcheck disable=SC2046
  par small custody-floor-churn1 chains "" $(chain_args custody-floor-churn1)
  par chain_plant r per-node-depth-v2 custody-floor-churn1
  par chain_plant s suppressed-filter-v2 hand5-peer
  par chain_plant t suppressed-filter-v2-off hand5-peer
  par_end || true       # each run's status is read below
  # E1: node a's keep_floor opens a link inside its question, where node c's on_open runs: no record there, its
  # send_join and send_relation counted bare at node c, once each, and nothing else; the digest both ways, the replay
  # clean. (E1's "c's join_sent read by c's next record" has no fixture in this cell: carried.)
  c=$(sed -n -E 's/^\{"([0-9]+) send_join": 1, "([0-9]+) send_relation": 1\}$/\1 \2/p' "$OUT/chains/custody-floor-churn1.jsonl.gz.bare.json" 2> /dev/null)
  if ! has -E ': the same$' "$OUT/chains/custody-floor-churn1.digest" 2> /dev/null; then
    echo "E1 carried 7, on custody-floor-churn1: not traced, or its digest not the untraced run's  <-- NOT" >> "$OUT/c-carried.txt"; c=
  elif [ -z "$c" ] || [ "${c% *}" != "${c#* }" ]; then
    echo "E1 carried 7, on custody-floor-churn1: its bare counts are not one node's send_join 1 and send_relation 1: $(cat "$OUT/chains/custody-floor-churn1.jsonl.gz.bare.json" 2> /dev/null)  <-- NOT" >> "$OUT/c-carried.txt"; c=
  elif ! why=$(replay_clean chains/custody-floor-churn1); then
    echo "E1 carried 7, on custody-floor-churn1: its replay: $why  <-- NOT" >> "$OUT/c-carried.txt"; c=
  else
    c=${c% *}
    echo "E1 carried 7, on custody-floor-churn1: as it must: the digest both ways, $(grep -m 1 '^replay: ' "$OUT/chains/custody-floor-churn1.replay"); bare calls at node $c alone, send_join 1 and send_relation 1" >> "$OUT/c-carried.txt"
    e1="node $c's send_join and send_relation inside another node's question counted bare, once each, the trace replayed clean"
  fi
  # (r): a depth state per install (the planted fault): node c's send_join becomes a record of its own inside the
  # question, the bare counts empty, the body E1's with exactly that record inserted. The replay accepts it (each
  # record checked on the Python's reads): R7 is the tracer's rule, read here by the body and the counts (the limit).
  # The record also carries node c's own now, not the question's (trace3.py's record takes ns["now"]): at 77ebf26,
  # 5.93 s against the 6.4 s of the records around it. The replay takes a record's t as that record's now alone, and
  # no check of it compares record times across nodes
  if [ -z "$c" ]; then
    echo "(r) per-node depth, on custody-floor-churn1: not read, for E1 is not as it must be  <-- NOT" >> "$OUT/c-carried.txt"
  elif [ "$(cat "$OUT/chains/plant-r.rc" 2> /dev/null)" != 0 ] || ! has -x "tracerfaults3: per-node-depth-v2, planted 30 times" "$OUT/chains/plant-r.err"; then
    echo "(r) per-node depth, on custody-floor-churn1: not planted at each of the 30 installs, or the run did not end with 0  <-- NOT" >> "$OUT/c-carried.txt"
  elif [ "$(cat "$OUT/chains/plant-r.jsonl.gz.bare.json" 2> /dev/null)" != "{}" ]; then
    echo "(r) per-node depth, on custody-floor-churn1: its .bare.json is not {}  <-- NOT" >> "$OUT/c-carried.txt"
  elif ! why=$(extra_records "$OUT/chains/custody-floor-churn1.jsonl.gz" "$OUT/chains/plant-r.jsonl.gz" "$c" send_join 1); then
    echo "(r) per-node depth, on custody-floor-churn1: the body not E1's and 1 record of send_join at node $c: $why  <-- NOT" >> "$OUT/c-carried.txt"
  elif ! why=$(replay_clean chains/plant-r); then
    echo "(r) per-node depth, on custody-floor-churn1: its replay: $why (the stated limit no longer holds)  <-- NOT" >> "$OUT/c-carried.txt"
  else
    echo "(r) per-node depth, on custody-floor-churn1: as it must: .bare.json {}; the body E1's and 1 record of send_join at node $c, its trailer counting it; $(grep -m 1 '^replay: ' "$OUT/chains/plant-r.replay")" >> "$OUT/c-carried.txt"
    e2="per-node depth (r): that send_join a record (its node and function checked, its t not), the counts empty, the body E1's with it alone inserted"
  fi
  # E3: hand5-peer (chain_cases' trace), each node's filter_entry replaced and entered outside every record: node 2's
  # held inside it counted bare, once. (s): node s's replaced filter_entry entered from Node._write, calling node s's
  # held, returning and then raising: no record inside, the two counted, the state restored on both, the body
  # hand5-peer's. (t): the suppression cleared for that call (the planted fault): two records of held at node s. Each
  # plant's nodes line is hand5-peer's but for its layer, first in the chain of filter_entry (one entry, every node)
  st='["suppressed_filter_seacast.<locals>.install.<locals>.filter_entry", "Node._peer_promise.<locals>.filter_entry", "doc"]'
  if ! $PY -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1])).get("2 held") == 1 else 1)' "$OUT/chains/hand5-peer.jsonl.gz.bare.json" 2> /dev/null; then
    echo "E3 carried 9, on hand5-peer: its bare counts lack \"2 held\": 1  <-- NOT" >> "$OUT/c-carried.txt"
  else echo "E3 carried 9, on hand5-peer: as it must: \"2 held\": 1 among its bare counts, the trace written to its end" >> "$OUT/c-carried.txt"; ok3=1; fi
  for t in s t; do
    s=$(sed -n -E "$([ "$t" = s ] && echo "$ls" || echo "$lt")" "$OUT/chains/plant-$t.err" 2> /dev/null)
    if [ -z "$s" ] || [ "$(cat "$OUT/chains/plant-$t.rc" 2> /dev/null)" != 0 ]; then
      echo "($t) on hand5-peer: its line is not as written, or the run did not end with 0  <-- NOT" >> "$OUT/c-carried.txt"; continue
    fi
    # the plant's bare counts: hand5-peer's, with (s)'s two calls of held at node s, (t)'s none
    if ! $PY -c 'import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
k, more = sys.argv[3] + " held", int(sys.argv[4])
if more:
    a[k] = a.get(k, 0) + more
sys.exit(0 if a == b else 1)' "$OUT/chains/hand5-peer.jsonl.gz.bare.json" "$OUT/chains/plant-$t.jsonl.gz.bare.json" "$s" "$([ "$t" = s ] && echo 2 || echo 0)" 2> /dev/null; then
      echo "($t) on hand5-peer: its bare counts are not hand5-peer's with $([ "$t" = s ] && echo "2 more" || echo "no more") held at node $s  <-- NOT" >> "$OUT/c-carried.txt"; continue
    fi
    # k 0 names N, as the step-1 plants do: with k 0, extra_records counts the named function in the trailer, at 0
    if [ "$t" = s ]; then why=$(extra_records "$OUT/chains/hand5-peer.jsonl.gz" "$OUT/chains/plant-s.jsonl.gz" "$s" N 0 "$s" filter_entry "$st")
    else why=$(extra_records "$OUT/chains/hand5-peer.jsonl.gz" "$OUT/chains/plant-t.jsonl.gz" "$s" held 2 "$s" filter_entry "$st"); fi
    if [ "$why" != ok ]; then
      echo "($t) on hand5-peer: the body not hand5-peer's$([ "$t" = t ] && echo " and 2 records of held at node $s"): $why  <-- NOT" >> "$OUT/c-carried.txt"
    elif ! why=$(replay_clean "chains/plant-$t"); then
      echo "($t) on hand5-peer: its replay: $why  <-- NOT" >> "$OUT/c-carried.txt"
    else
      echo "($t) on hand5-peer: as it must: $(grep -m 1 -E '^tracerfaults3: ' "$OUT/chains/plant-$t.err" | cut -c16-200); $(grep -m 1 '^replay: ' "$OUT/chains/plant-$t.replay")" >> "$OUT/c-carried.txt"
      ok3=$((ok3 + 1)); n3=$s
    fi
  done
  if grep -q '<-- NOT' "$OUT/c-carried.txt"; then no "the carried cases (c-carried.txt)"; fi
  [ -n "$e1" ] || e1="carried 7 not as it must be"
  if [ -n "$e2" ]; then e2="$e2, the replay accepting it (the stated limit: R7 is the tracer's rule; that record carries node c's own now, not the question's, and no replay check compares record times across nodes)"; else e2="(r) not as it must be"; fi
  if [ "$ok3" = 3 ]; then e3="node 2's held inside hand5-peer's replaced filter_entry counted bare; (s) at node $n3, the state restored on return and on raise; (t), the suppression cleared, two records of held inside"
  else e3="carried 9, (s) or (t) not as it must be"; fi
  echo "  the carried cases: $e1; $e2; $e3"
}
f_cases() {             # piece F: S1-8a's count (carried), S1-8b in both halves, S1-C5's line; local, after carried
  local churn=chains/custody-floor-churn1 nb r0 nsr m rc tl lines refused rows s8a s8b s5 c fw
  local ok8a=0 okw=0 oks=0 okp=0 ok5=0 okc=0
  local tline="node [0-9]+'s send_relation to [0-9]+: a GRAFT of the −1 family; a counted record put in after it, at node [0-9]+; node [0-9]+'s send_relation to [0-9]+: a PRUNE of the −1 family; the trailer counts the record put in; the copy's lines ([0-9]+), ([0-9]+), ([0-9]+)\$"
  : > "$OUT/c-fcases.txt"
  # The backoff codec's case (its #guard refuses +inf as the leaf, Seacast/Codecs.lean), carried: no record of churn1
  # (carried's trace) names backoff among its tables. seacast.md's readers of it are relation_room (called by
  # maintain_relations, graft, on_graft and on_prune) and on_prune, its one writer; none of these is traced, so none
  # is a function the twin replays: carried until one is. A count above 0 fails, for the carried status must be read again
  nb=$($PY - "$OUT/$churn.jsonl.gz" 2> /dev/null <<'EOF_BO'
import gzip
import json
import sys
n = 0
with gzip.open(sys.argv[1], "rt") as f:
    for line in f:
        if line.startswith('{"n"') and "backoff" in (json.loads(line).get("tables") or ()):
            n += 1
print(n)
EOF_BO
)
  if [ "$nb" = 0 ]; then
    echo "S1-8a on custody-floor-churn1: as it must: 0 records read or write backoff; carried" >> "$OUT/c-fcases.txt"; ok8a=1
  else echo "S1-8a on custody-floor-churn1: ${nb:-no count} records read or write backoff, not 0: the carried status must be read again  <-- NOT" >> "$OUT/c-fcases.txt"; fi
  # S1-8b, the writer's half: --self-test-seacast's four lines (its own run, for the selftests step keeps no output)
  $PY "$T/trace3.py" --self-test-seacast > "$OUT/c-fcases-selftest.txt" 2>&1
  if has -x "ok: every case as it must be" "$OUT/c-fcases-selftest.txt" \
      && has -x -F "forms self-test, S1-8b, a GRAFT with the −1 family, under SEACAST: ok" "$OUT/c-fcases-selftest.txt" \
      && has -x -F "forms self-test, S1-8b, a PRUNE with the −1 family, under SEACAST: ok" "$OUT/c-fcases-selftest.txt" \
      && has -x -F "forms self-test, S1-8b, counted's need with the −1 family, under SEACAST: ok" "$OUT/c-fcases-selftest.txt" \
      && has -x -F "forms self-test, S1-8b's planted writer (the plain int): refuses exactly the 3 cases, ok" "$OUT/c-fcases-selftest.txt"; then
    echo "S1-8b, the writer: as it must: the −1 family written [\"-\", 1] in a GRAFT, a PRUNE and counted's need; the plain-int writer refused in exactly the 3 cases" >> "$OUT/c-fcases.txt"; okw=1
  else echo "S1-8b, the writer: --self-test-seacast's S1-8b lines not as they must be (c-fcases-selftest.txt)  <-- NOT" >> "$OUT/c-fcases.txt"; fi
  # S1-8b, the reader's half, on churn1 (no trace at hand holds a PRUNE or a record of counted): families_seacast.py's
  # copies, signed and plain. Signed: every record ok, counted's among them; plain: the strict scan refuses exactly
  # the three lines the tool changed, and the trailer then counts three records more than were read
  r0=$(sed -n -E 's/^replay: ([0-9]+) records, .*/\1/p' "$OUT/$churn.replay" 2> /dev/null)
  nsr=$(sed -n -E 's/^fn send_relation: ([0-9]+) records, .*/\1/p' "$OUT/$churn.replay" 2> /dev/null)
  for m in signed plain; do
    rm -f "$OUT/chains/fam-$m".*
    if $PY "$T/families_seacast.py" "$m" "$OUT/$churn.jsonl.gz" "$OUT/chains/fam-$m.jsonl.gz" > "$OUT/chains/fam-$m.out" 2>&1; then
      replay_of "chains/fam-$m"; echo $? > "$OUT/chains/fam-$m.rc"
    fi
  done
  if [ -z "$r0" ] || [ -z "$nsr" ]; then
    echo "S1-8b, the reader: churn1's replay gives no record count  <-- NOT" >> "$OUT/c-fcases.txt"
  elif ! has -E "^families_seacast: signed: $tline" "$OUT/chains/fam-signed.out" || [ "$(cat "$OUT/chains/fam-signed.rc" 2> /dev/null)" != 0 ]; then
    echo "S1-8b, the reader, signed: the copy not made as written, or its replay did not end with 0  <-- NOT" >> "$OUT/c-fcases.txt"
  elif ! has -x "replay: $((r0 + 1)) records, $((r0 + 1)) ok, 0 mismatched" "$OUT/chains/fam-signed.replay" \
      || ! has -x "reads of the Python's that the twin did not make: 0" "$OUT/chains/fam-signed.replay" \
      || ! has -x "fn counted: 1 records, 1 ok" "$OUT/chains/fam-signed.replay" \
      || ! has -x "fn send_relation: $nsr records, $nsr ok" "$OUT/chains/fam-signed.replay" \
      || ! has -E "^content: as --content's, " "$OUT/chains/fam-signed.replay" \
      || has -E '^(lines refused |trailer: )' "$OUT/chains/fam-signed.replay"; then
    echo "S1-8b, the reader, signed: not every record ok: $(grep -m 1 '^replay: ' "$OUT/chains/fam-signed.replay" 2> /dev/null)  <-- NOT" >> "$OUT/c-fcases.txt"
  else
    echo "S1-8b, the reader, signed: as it must: $(grep -m 1 '^replay: ' "$OUT/chains/fam-signed.replay"); counted's record and the $nsr send_relation records ok" >> "$OUT/c-fcases.txt"; oks=1
  fi
  lines=$(sed -n -E "s/^families_seacast: plain: $tline/\\1 \\2 \\3/p" "$OUT/chains/fam-plain.out" 2> /dev/null)
  refused=$(sed -n -E 's/^line ([0-9]+): not a line the tracer writes: a number with a sign, at [0-9]+$/\1/p' "$OUT/chains/fam-plain.replay" 2> /dev/null | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$r0" ] || [ -z "$lines" ] || [ "$(cat "$OUT/chains/fam-plain.rc" 2> /dev/null)" = 0 ]; then
    echo "S1-8b, the reader, plain: the copy not made as written, or its replay ended with 0  <-- NOT" >> "$OUT/c-fcases.txt"
  elif [ "$refused" != "$lines" ] || ! has -x "lines refused before they were parsed, or by the parser: 3" "$OUT/chains/fam-plain.replay"; then
    echo "S1-8b, the reader, plain: the lines refused for a number with a sign are ${refused:-none}, not the copy's $lines  <-- NOT" >> "$OUT/c-fcases.txt"
  elif ! has -x "replay: $((r0 - 2)) records, $((r0 - 2)) ok, 0 mismatched" "$OUT/chains/fam-plain.replay" \
      || ! has -x "trailer: $((r0 + 1)) records written, $((r0 - 2)) read" "$OUT/chains/fam-plain.replay"; then
    echo "S1-8b, the reader, plain: the other records or the trailer's count not as they must be: $(grep -m 1 '^replay: ' "$OUT/chains/fam-plain.replay" 2> /dev/null)  <-- NOT" >> "$OUT/c-fcases.txt"
  else
    echo "S1-8b, the reader, plain: as it must: its lines $lines refused, each \"not a line the tracer writes: a number with a sign\"; $(grep -m 1 '^replay: ' "$OUT/chains/fam-plain.replay"); trailer: $((r0 + 1)) records written, $((r0 - 2)) read" >> "$OUT/c-fcases.txt"; okp=1
  fi
  # families_seacast.py's input: it takes only a whole run's trace, or its copy would hold a prefix as a whole run's.
  # Three copies of seacast/hand5 (the small step's): cut before its trailer; its trailer line cut to 20 characters,
  # with no newline (a trailer whose write failed); its trailer saying the run stopped. Each must be refused, with
  # exit 1 and its words. The copies and what families_seacast.py leaves of each are under fcases/, which no reader of
  # the run's traces scans: under chains/, the calls summary read them as traces the inventory does not list
  local fc=$OUT/fcases
  mkdir -p "$fc"
  rm -f "$fc/fam-cut".* "$fc/fam-cutline".* "$fc/fam-stop".* "$fc/fam-copies.out"
  $PY - "$OUT/seacast/hand5.jsonl.gz" "$fc" > "$fc/fam-copies.out" 2>&1 <<'EOF_FC'
import gzip
import json
import sys
src, d = sys.argv[1], sys.argv[2]
prev = None
with gzip.open(src, "rt") as f, gzip.open(f"{d}/fam-cut.in.jsonl.gz", "wt", compresslevel=1) as cut, \
        gzip.open(f"{d}/fam-cutline.in.jsonl.gz", "wt", compresslevel=1) as cutline, \
        gzip.open(f"{d}/fam-stop.in.jsonl.gz", "wt", compresslevel=1) as stop:
    for line in f:
        if prev is not None:
            for o in (cut, cutline, stop):
                o.write(prev)
        prev = line
    t = json.loads(prev)["trailer"]
    assert "stopped" not in t, "seacast/hand5's trailer says its run stopped"
    cutline.write(prev[:20])
    stop.write(json.dumps({"trailer": dict(t, stopped="SystemExit: a planted stop")}, separators=(",", ":")) + "\n")
EOF_FC
  okc=1 fw=""
  for c in cut cutline stop; do
    $PY "$T/families_seacast.py" signed "$fc/fam-$c.in.jsonl.gz" "$fc/fam-$c.jsonl.gz" > "$fc/fam-$c.out" 2>&1
    rc=$?
    case $c in
      cut) tl="no trailer: a trace cut short is not a whole run's" ;;
      cutline) tl="the trailer line is cut: a trace cut short is not a whole run's" ;;
      stop) tl="the trailer says the run stopped (SystemExit: a planted stop); a stopped run's records are not a whole run's" ;;
    esac
    if [ "$rc" != 1 ] || ! has -x -F "families_seacast: $fc/fam-$c.in.jsonl.gz: $tl" "$fc/fam-$c.out"; then okc=0; fi
    fw="$fw $c $rc,"
  done
  if [ "$okc" = 1 ]; then
    echo "families_seacast.py's input: as it must: it refuses seacast/hand5 cut before its trailer (\"no trailer\"), with its trailer line cut (\"the trailer line is cut\") and with a trailer that says the run stopped (\"the trailer says the run stopped\"), each with exit 1" >> "$OUT/c-fcases.txt"
  else echo "families_seacast.py's input: its exits on seacast/hand5's copies:${fw%,}; not each 1 with its words (fcases/fam-cut.out, fam-cutline.out, fam-stop.out)  <-- NOT" >> "$OUT/c-fcases.txt"; fi
  # S1-C5 (cases 2 and 3 carried as unreachable from the document): seacast/hand5 (the small step's) enters origin_acked
  # 8 times, in its two branches, inside records that replay with 0 reads not made; and its non-leaf reads logged
  # with the row absent, per table (the tape's row-absent form), by the schema's key counts
  rows=$($PY - "$T/gen" "$OUT/seacast/hand5.jsonl.gz" 2> /dev/null <<'EOF_RA'
import gzip
import json
import sys
from collections import Counter
sys.path.insert(0, sys.argv[1])
import schema                           # noqa: E402: the spec's gen/
import schema_seacast                        # noqa: E402
depth = {t.name: len(t.keys) for t in schema.TABLES}
depth.update({t.name: len(t.keys) for t in schema_seacast.TABLES_Seacast})
c = Counter()
with gzip.open(sys.argv[2], "rt") as f:
    for line in f:
        if not line.startswith('{"n"'):
            continue
        for r in json.loads(line).get("reads") or ():
            if (r and isinstance(r[0], str) and len(r) >= 3 and isinstance(r[1], list) and r[0] in depth
                    and len(r[1]) < depth[r[0]] and r[2] is None):
                c[r[0]] += 1
print(", ".join(f"{t} {n}" for t, n in sorted(c.items())))
EOF_RA
)
  if ! has -x "branch origin_acked: acknowledged before: 6" "$OUT/seacast/hand5.replay" 2> /dev/null \
      || ! has -x "branch origin_acked: the holding grows: 2" "$OUT/seacast/hand5.replay" \
      || ! has -x "reads of the Python's that the twin did not make: 0" "$OUT/seacast/hand5.replay"; then
    echo "S1-C5 on seacast/hand5: origin_acked's branches not 6 and 2, or a read not made, or no replay  <-- NOT" >> "$OUT/c-fcases.txt"
  elif [ "$rows" != "owed 87, planned 32, promises 2, queue 1" ]; then
    echo "S1-C5 on seacast/hand5: the reads with the row absent are ${rows:-none}, not owed 87, planned 32, promises 2, queue 1  <-- NOT" >> "$OUT/c-fcases.txt"
  else
    echo "S1-C5 on seacast/hand5: as it must: origin_acked entered 8 times (6 acknowledged before, 2 the holding grows), 0 reads not made; the reads with the row absent: $rows" >> "$OUT/c-fcases.txt"; ok5=1
  fi
  if grep -q '<-- NOT' "$OUT/c-fcases.txt"; then no "F's three (c-fcases.txt)"; fi
  s8a="the backoff codec's case carried: no record of custody-floor-churn1 reads or writes backoff (its readers relation_room and on_prune and its writer on_prune are not traced, nor are their callers)"
  [ "$ok8a" = 1 ] || s8a="the backoff codec's case not as it must be"
  s8b="S1-8b: the writer writes the −1 family as [\"-\", 1] in a GRAFT, a PRUNE and need, and a plain-int writer is refused; on churn1 the reader replays the three ($((r0 + 1)) records, all ok) and refuses the plain int at their 3 lines"
  if [ "$okc" = 1 ]; then s8b="$s8b; it refuses a trace cut before its trailer or in it, and one whose trailer says the run stopped"; fi
  [ "$okw$oks$okp" = 111 ] || s8b="S1-8b not as it must be"
  if [ "$okc" != 1 ]; then s8b="$s8b; families_seacast.py's input not refused as it must be"; fi
  s5="S1-C5: origin_acked entered 8 times on seacast/hand5, 0 reads not made; the rows absent: $rows; cases 2 and 3 carried as unreachable"
  [ "$ok5" = 1 ] || s5="S1-C5 not as it must be"
  echo "  F's three: $s8a; $s8b; $s5"
}
h4_plant() {            # H4's plant (n): trace3.py's LAYERS without the silent node's layer of forward, on hand5-own's
  local f=$OUT/c-h4     #   arguments: the scan's lists name it, and the tracer stops at the silent node's install
  rm -f "$f".*
  (cd "$TOY" && $PY "$T/tracerfaults3.py" --layer-missing-v2 . "$f.jsonl.gz" > "$f.out" 2> "$f.err"); echo $? > "$f.rc"
  if [ "$(cat "$f.rc")" = 0 ] || ! has -x -F "tracerfaults3: layer-missing-v2, planted 1 time" "$f.err"; then
    no "H4's plant (n): not planted once, or the tracer wrote its trace to its end (c-h4.err)"
    echo "  H4's plant (n): not as it must be"
  elif [ "$(grep -c '^tracerfaults3: scan: .*NOT' "$f.err")" != 1 ] \
      || ! has -x -F "tracerfaults3: scan: layer forward Node._faults.<locals>.forward@1106: changing, NOT so in LAYERS" "$f.err" \
      || ! has -x -F "tracerfaults3: scan: 1 differences from trace3.py's lists" "$f.err"; then
    no "H4's plant (n): the scan's lists do not name the layer left out, alone (c-h4.err)"
    echo "  H4's plant (n): not as it must be"
  elif ! has -x -F "trace3: node 3: forward: a layer in none of the tracer's lists: Node._faults.<locals>.forward (node.py:1106)" "$f.err"; then
    no "H4's plant (n): the tracer stopped without the words it must give (c-h4.err)"
    echo "  H4's plant (n): not as it must be"
  else
    echo "  H4's plant (n): the silent node's layer of forward left out of LAYERS: the scan names it, the one difference, and the tracer stops at node 3's install, with its words"
  fi
}
timers_one() {             # $1: clean, or a plant's numeral; $2: tracerfaults3.py's option: das-samplers-mcoff traced with
  local f=$OUT/timers/$1   #   it (clean: the chain cases' trace), then timers_seacast.py on the trace; a plant's trace removed
  rm -f "$f".*
  if [ "$1" = clean ]; then
    (cd "$T" && $PY timers_seacast.py "$OUT/chains/das-samplers-mcoff.jsonl.gz") > "$f.timers" 2>&1; echo $? > "$f.trc"
    return 0
  fi
  # shellcheck disable=SC2046
  (cd "$TOY" && $PY "$T/tracerfaults3.py" "--$2" . "$f.jsonl.gz" $(chain_args das-samplers-mcoff) > "$f.out" 2> "$f.err")
  echo $? > "$f.rc"
  (cd "$T" && $PY timers_seacast.py "$f.jsonl.gz") > "$f.timers" 2>&1; echo $? > "$f.trc"
  rm -f "$f.jsonl.gz" "$f.jsonl.gz.bare.json"
  return 0
}
timers_check() {        # the timers of deferred_offers: timers_seacast.py holds on das-samplers-mcoff's trace, and refuses
  #                       each of its three plants by the checks the plant breaks and by no other (c-timers.txt)
  local p opt want got counts bad=
  if [ -n "$NODAS" ]; then echo "  deferred_offers' timers: --no-das: das-samplers-mcoff and the three plants on it skipped"; return 0; fi
  rm -rf "$OUT/timers"; mkdir -p "$OUT/timers"
  par timers_one clean
  par timers_one i timers-note-dropped-v2
  par timers_one ii timers-delay-no-eps-v2
  par timers_one iii timers-note-per-index-v2
  par_end || true       # each one's status is read below
  : > "$OUT/c-timers.txt"
  for p in clean i ii iii; do
    { echo "== $p"; [ -f "$OUT/timers/$p.err" ] && grep -E '^tracerfaults3: ' "$OUT/timers/$p.err"; cat "$OUT/timers/$p.timers"; } >> "$OUT/c-timers.txt"
  done
  counts=$(sed -n 's/^timers_seacast: the timers of deferred_offers hold on .*: \([0-9]*\) notes, \([0-9]*\) own afters, \([0-9]*\) retry_offer records .*/\1 notes, \2 own afters, \3 records/p' "$OUT/timers/clean.timers")
  [ "$(cat "$OUT/timers/clean.trc")" = 0 ] && [ -n "$counts" ] || bad="$bad clean"
  for p in i ii iii; do
    case $p in
      i) opt=timers-note-dropped-v2; want="K1 K4" ;;
      ii) opt=timers-delay-no-eps-v2; want="K2" ;;
      iii) opt=timers-note-per-index-v2; want="K1" ;;
    esac
    got=$(grep -o -E '^timers_seacast: K[1-4] FAILS' "$OUT/timers/$p.timers" | grep -o -E 'K[1-4]' | tr '\n' ' ' | sed 's/ $//')
    if [ "$(cat "$OUT/timers/$p.rc")" != 0 ] || ! has -E "^tracerfaults3: $opt, planted [1-9][0-9]* times?" "$OUT/timers/$p.err" \
        || [ "$(cat "$OUT/timers/$p.trc")" != 1 ] || [ "$got" != "$want" ] || ! has '^timers_seacast: the timers of deferred_offers FAIL on ' "$OUT/timers/$p.timers"; then
      bad="$bad ($p)"
    fi
  done
  if [ -n "$bad" ]; then
    no "deferred_offers' timers: not as they must be:$bad (c-timers.txt)"
    echo "  deferred_offers' timers: not as they must be:$bad"
  else
    echo "  deferred_offers' timers: holds on das-samplers-mcoff ($counts); plants (i), (ii) and (iii) each refused by their checks"
  fi
}
calls_one() {           # $1: a trace under OUT, without .jsonl.gz: calls_seacast.py's lines for it, in reached/
  local g=$OUT/reached/${1//\//__}
  $PY "$T/calls_seacast.py" "$OUT" "$1" > "$g.txt" 2> "$g.err"; echo $? > "$g.rc"
}
calls_plant() {         # $1: a plant's letter, $2: its fault, the rest: its cell's arguments (none: hand5's, the plant's
  #                       own): its trace, and calls_seacast.py over it
  local l=$1 f=$OUT/reached/plant-$1 q=$2; shift 2
  (cd "$TOY" && $PY "$T/tracerfaults3.py" "--$q" . "$f.jsonl.gz" "$@" > "$f.out" 2> "$f.err"); echo $? > "$f.rc"
  $PY "$T/calls_seacast.py" --any "$OUT" "reached/plant-$l" > "$f.txt" 2>&1; echo $? > "$f.crc"
}
calls_control() {       # plant (w)'s control: its cell's arguments traced by trace3.py, and calls_seacast.py over it
  local f=$OUT/reached/plant-wc
  # shellcheck disable=SC2086
  (cd "$TOY" && $PY "$T/trace3.py" . "$f.jsonl.gz" $LATE16 --doc seacast --digest > "$f.out" 2> "$f.err"); echo $? > "$f.rc"
  $PY "$T/calls_seacast.py" --any "$OUT" reached/plant-wc > "$f.txt" 2>&1; echo $? > "$f.crc"
}
das_paths() {           # the inventory's paths of need das, one a line, in its order
  awk -F '\t' '!/^#/ && $3 == "das" { print $1 }' "$HERE/inventory.tsv"
}
das_stamp() {           # the need das: the inventory's DAS traces made since tracercontrols started (none under --no-das)
  local p
  [ -z "$NODAS" ] || return 0
  for p in $(das_paths); do
    [ "$OUT/$p.jsonl.gz" -nt "$OUT/tracercontrols.start" ] && echo "$p"
  done > "$OUT/das.traces"
  return 0
}
needs_declared() {      # the needs this invocation declares, from its flags alone, never from its outputs: das unless
  #                       --no-das; seacastcells when the whole list of steps (ALL: --record's or --v2steps') makes the
  #                       SEACAST cells and the cells are every cell, compared as the stamp compares them (--cells with
  #                       fewer gives none). --steps does not change it: a run of some steps is held to the needs of
  #                       the whole list it is a part of, and its OUT must hold what the other steps made. The needs
  #                       line's words, or - for none
  local w=
  [ -n "$NODAS" ] || w=das
  # shellcheck disable=SC2086,SC2116
  case " $ALL " in *" seacastcells "*) [ "$(echo $CELLS)" = "$(echo $ALLCELLS)" ] && w="$w${w:+ }seacastcells" ;; esac
  echo "${w:--}"
}
needs_stamped() {       # the needs this OUT's traces were made for: das when das.traces lists every DAS path, and
  #                       seacastcells when seacastcells.cells lists every cell; the same words
  local w=
  # shellcheck disable=SC2086
  [ -f "$OUT/das.traces" ] && [ "$(cat "$OUT/das.traces")" = "$(das_paths)" ] && w=das
  # shellcheck disable=SC2086
  [ "$(cat "$OUT/seacastcells.cells" 2> /dev/null)" = "$(echo $ALLCELLS)" ] && w="$w${w:+ }seacastcells"
  echo "${w:--}"
}
needs_check() {         # c-reached.txt's first line, the declared needs; a FAIL when the stamps are other needs
  local d s
  d=$(needs_declared); s=$(needs_stamped)
  echo "needs: $d" > "$OUT/c-reached.txt"
  [ "$d" = "$s" ] || no "the needs this invocation declares ($d) are not those its outputs are stamped with ($s) (das.traces, seacastcells.cells)"
}
inv_needs() {           # inventory_seacast.py's declaration: --needs, the declared needs joined by commas, and --partial
  #                       when they are short of das and seacastcells
  local d
  d=$(needs_declared)
  echo "--needs ${d// /,}$([ "$d" = "das seacastcells" ] || echo " --partial")"
}
calls_summary() {       # piece (b): each SEACAST trace's reached names, and the IWANTs respond, retry_offer and ask_parked
  #                       enqueue, by their records and by their calls, with the calls file's four controls
  #                       (c-reached.txt, which the pull carries); plants (u), (v) and (w), each refused by its control
  #                       alone, and (w)'s control; the IWANT makers, from the documents (c-iwant-makers.txt); and
  #                       every trace held to formal/twin/inventory.tsv by inventory_seacast.py, the needs line first
  #                       (c-inventory.txt; the inventory's copy, inventory.tsv, which the pull carries too)
  local rel rels g n=0 s=0 bad= p ok=0 why= inv=
  rm -rf "$OUT/reached"; mkdir -p "$OUT/reached"
  rm -f "$OUT/c-inventory.txt"
  cp "$HERE/inventory.tsv" "$OUT/inventory.tsv" && cmp -s "$HERE/inventory.tsv" "$OUT/inventory.tsv" \
    || no "the inventory not copied whole (inventory.tsv)"
  rels=$(cd "$OUT" && for d in seacast chains rows; do ls "$d"/*.jsonl.gz 2> /dev/null; done | sed 's/\.jsonl\.gz$//' | LC_ALL=C sort)
  for rel in $rels; do par calls_one "$rel"; done
  par calls_plant u calls-nested-off-v2
  par calls_plant v calls-iwants-off-v2
  # shellcheck disable=SC2086
  par calls_plant w calls-paired-off-v2 $LATE16 --doc seacast       # the paired omission, on a cell of its own
  par calls_control
  par_end || true       # each one's status is read below
  needs_check
  for rel in $rels; do
    g=$OUT/reached/${rel//\//__}
    cat "$g.txt" >> "$OUT/c-reached.txt"
    if [ "$(cat "$g.rc")" != 0 ] || [ -s "$g.err" ]; then bad="$bad $rel"
    elif has '^skipped: ' "$g.txt"; then s=$((s + 1))
    else n=$((n + 1)); fi
  done
  if [ -n "$bad" ]; then
    echo "c-reached: $n traces read, $s skipped; the controls fail, or the tool did, in:$bad" >> "$OUT/c-reached.txt"
    no "the calls summary: the controls fail, or the tool did, in:$bad (c-reached.txt)"
  else
    echo "c-reached: $n traces read, $s skipped; the controls hold in every one" >> "$OUT/c-reached.txt"
  fi
  for p in u:calls-nested-off-v2:reach v:calls-iwants-off-v2:by-fn w:calls-paired-off-v2:by-fn; do
    local l=${p%%:*} q=${p#*:} f c
    c=${q#*:}; q=${q%%:*}; f=$OUT/reached/plant-$l
    if [ "$(cat "$f.rc")" != 0 ] || ! has -x -E "tracerfaults3: $q, planted [1-9][0-9]* times?" "$f.err"; then
      why="$why ($l) not planted, or its run stopped;"
    elif [ "$(cat "$f.crc")" != 1 ] || ! has -E "^reached/plant-$l: controls: NOT: $c: " "$f.txt" \
        || has -E "^reached/plant-$l: controls: NOT: .*(K4a|asked|$( [ "$c" = reach ] && echo by-fn || echo reach)): " "$f.txt"; then
      why="$why ($l) not refused by $c alone;"
    else
      ok=$((ok + 1))
    fi
  done
  f=$OUT/reached/plant-wc               # (w)'s control: the same cell, no plant: the controls hold
  if [ "$(cat "$f.rc")" = 0 ] && [ "$(cat "$f.crc")" = 0 ] && has -E "^reached/plant-wc: controls: K4a .*: hold$" "$f.txt"; then
    ok=$((ok + 1))
  else
    why="$why (w)'s control does not hold;"
  fi
  if [ -n "$why" ]; then
    no "the calls summary's plants:$why (reached/plant-*.txt)"
  fi
  # P1 and P2, the IWANT makers, from the documents (calls_seacast.py --makers)
  local mk=
  $PY "$T/calls_seacast.py" --makers "$ROOT" > "$OUT/c-iwant-makers.txt" 2>&1 && mk=ok \
    || no "the IWANT makers are not FNS's, one site each under no loop (c-iwant-makers.txt)"
  # every trace met as its inventory line says, by class and need (inventory_seacast.py)
  # shellcheck disable=SC2046
  $PY "$T/inventory_seacast.py" $(inv_needs) "$OUT/inventory.tsv" "$OUT/c-reached.txt" > "$OUT/c-inventory.txt" 2>&1 && inv=ok \
    || no "the calls summary against the inventory (c-inventory.txt)"
  if [ -z "$bad" ] && [ "$ok" = 4 ] && [ -n "$mk" ] && [ -n "$inv" ]; then
    echo "  the calls summary: $n traces read, $s skipped, the controls hold in each (c-reached.txt); plants (u), (v) and (w) each refused by their control alone, (w)'s control holding; the IWANT makers: respond, retry_offer and ask_parked, one site each under no loop (c-iwant-makers.txt); the inventory: $(grep -v -c '^#' "$OUT/inventory.tsv") lines, each as it must be (c-inventory.txt)"
  else
    echo "  the calls summary: not as it must be"
  fi
}
timers_all_one() {      # $1: a trace under OUT, without .jsonl.gz: timers_seacast.py's lines for it, in timersall/
  local g=$OUT/timersall/${1//\//__}
  (cd "$T" && $PY timers_seacast.py "$OUT/$1.jsonl.gz") > "$g.txt" 2>&1; echo $? > "$g.rc"
}
reached_count() {       # the count of traces the calls summary read: c-reached.txt's one c-reached: line, its last, with
  #                       either of its endings; nothing otherwise
  [ "$(grep -c '^c-reached: ' "$OUT/c-reached.txt" 2> /dev/null)" = 1 ] || return 0
  tail -n 1 "$OUT/c-reached.txt" | sed -n -E 's/^c-reached: ([0-9]+) traces read, [0-9]+ skipped; (the controls hold in every one|the controls fail, or the tool did, in:.*)$/\1/p'
}
timers_all() {          # deferred_offers' timers over exactly the inventory's must traces whose need the run had, each
  #                       read by the calls summary (plants, copies and runs that stopped are other lines; a must
  #                       trace the summary did not read is a NOT): each holds, or stops at the type's lookup (two
  #                       START_DELAYs fit: a stated limit, counted apart), and none fails; no enqueue entry carries a
  #                       timer; a start inside a question counted, a search; then the alarm's cell (c-timers-all.txt)
  local rel rels g chk= total line notes w s a hb h=0 hn=0 h0=0 st=0 stn= fl= ws=0 as=0 sn= nread unread=
  rm -rf "$OUT/timersall"; mkdir -p "$OUT/timersall"
  # shellcheck disable=SC2046
  rels=$($PY "$T/inventory_seacast.py" --must $(inv_needs) "$OUT/inventory.tsv" "$OUT/c-reached.txt" 2> /dev/null) \
    || no "deferred_offers' timers: the inventory's must lines not read (inventory_seacast.py --must)"
  for rel in $rels; do
    if ! has -E "^$rel \\(format " "$OUT/reached/${rel//\//__}.txt" 2> /dev/null; then unread="$unread $rel"; continue; fi
    chk="$chk $rel"; par timers_all_one "$rel"
  done
  [ -z "$unread" ] || no "deferred_offers' timers: must traces the calls summary did not read:$unread (c-reached.txt)"
  par_end || true       # each one's status is read below
  : > "$OUT/c-timers-all.txt"
  for rel in $chk; do
    g=$OUT/timersall/${rel//\//__}
    line=$(sed -n 's/^timers_seacast: the timers of deferred_offers hold on .*: \([0-9]*\) notes, \([0-9]*\) own afters, \([0-9]*\) retry_offer records .*/\1 notes, \2 own afters, \3 records/p' "$g.txt")
    w=$(sed -n 's/^timers_seacast: enqueue: [0-9]* entries, \([0-9]*\) with timers$/\1/p' "$g.txt")
    s=$(sed -n 's/^timers_seacast: start: \([0-9]*\) notes of kind start .*/\1/p' "$g.txt")
    a=$(sed -n 's/^timers_seacast: alarm_due: \([0-9]*\) notes name it; .*/\1/p' "$g.txt")
    hb=$(sed -n 's/^timers_seacast: the timers of deferred_offers hold on .*; \([0-9]*\) retried at a heartbeat, \(held back\|by the heartbeat alone\))$/\2: \1/p' "$g.txt")
    if [ "$(cat "$g.rc")" = 0 ] && [ -n "$line" ] && [ -n "$w" ] && [ -n "$s" ] && [ -n "$a" ] && [ -n "$hb" ]; then
      h=$((h + 1)); notes=${line%% *}
      if [ "$notes" -gt 0 ]; then hn=$((hn + 1)); else h0=$((h0 + 1)); fi
      ws=$((ws + w)); as=$((as + a))
      [ "$s" = 0 ] || sn="$sn $rel ($s)"
      echo "$rel: holds: $line; retried at a heartbeat, $hb; enqueue entries with timers: $w; start notes: $s; alarm_due notes: $a" >> "$OUT/c-timers-all.txt"
    elif [ "$(cat "$g.rc")" = 2 ] && has -E '^timers_seacast: .*: no single START_DELAY fits t - known_at .*; K2 cannot be checked$' "$g.txt"; then
      st=$((st + 1)); stn="$stn $rel"
      echo "$rel: stopped at the type's lookup, a stated limit: $(grep -m 1 'no single START_DELAY fits' "$g.txt" | cut -c1-200)" >> "$OUT/c-timers-all.txt"
    else
      fl="$fl $rel"
      echo "$rel: FAILS (exit $(cat "$g.rc")): $(tail -n 1 "$g.txt" | cut -c1-200)  <-- NOT" >> "$OUT/c-timers-all.txt"
    fi
  done
  total=$(echo $chk | wc -w)
  nread=$(reached_count)
  [ "$total" -gt 0 ] || no "deferred_offers' timers over every trace: no trace to check"
  if [ -z "$nread" ]; then
    no "deferred_offers' timers over every trace: c-reached.txt does not end in its one c-reached: line, so the count of traces the calls summary read is not known (c-reached.txt)"
  elif [ "$total" != "$nread" ]; then
    no "deferred_offers' timers over every trace: $total checked, where the calls summary read $nread (c-timers-all.txt)"
  fi
  [ -z "$fl" ] || no "deferred_offers' timers over every trace: failed in:$fl (c-timers-all.txt)"
  [ "$ws" = 0 ] || no "deferred_offers' timers over every trace: $ws enqueue entries carry a timer (c-timers-all.txt)"
  echo "  deferred_offers' timers over the inventory's $total must traces, each read by the calls summary: $h hold ($hn with notes, $h0 with none), $st stopped at the type's lookup${stn:+ (in:$stn)}, $(echo $fl | wc -w) fail; enqueue entries with timers: $ws; start notes: ${sn:+in$sn}${sn:-none} (c-timers-all.txt)"
  if [ -n "$NODAS" ]; then echo "  the alarm's cell: --no-das: skipped (a DAS cell)"; else alarm_cell "$as"; fi
}
alarm_cell() {          # $1: alarm_due's notes over every trace: the alarm's cell (--alarm-wait, rows/das-alarm), traced
  #                       by the rows step: its digest the untraced run's and its replay clean; its custodians alarm; at
  #                       the honest nodes its filter_entry, a replaced name, is entered outside every record, so
  #                       probe_settled, which filter_entry alone calls, runs bare; promise_due's records still come.
  #                       A limit, not a check: no cell found asks a claimant (a member asks one only while it defers on
  #                       a verified claim, node.py's _alarm; ten seeds of this cell, with and without the repair sample,
  #                       none did), so no trace holds an alarm_due note and a toy callback's note path stays
  #                       unexercised; the 0 asks and the 0 notes are required, so that a change that arms it is read
  local f=$OUT/rows/das-alarm g=$OUT/timersall/rows__das-alarm sent asks ps pd an why= line
  sent=$(sed -n -E 's/^  alarm: ([0-9]+) sent by .*/\1/p' "$f.out" 2> /dev/null)
  asks=$(sed -n -E 's/^  alarm: .*; ([0-9]+) asks of a claimant .*/\1/p' "$f.out" 2> /dev/null)
  ps=$($PY -c 'import json, sys; print(json.load(open(sys.argv[1]))["calls"]["probe_settled"]["bare"])' "$f.jsonl.gz.calls.json" 2> /dev/null)
  pd=$(sed -n 's/^timers_seacast: alarm_due: [0-9]* notes name it; promise_due: \([0-9]*\) records$/\1/p' "$g.txt" 2> /dev/null)
  an=$(sed -n 's/^timers_seacast: alarm_due: \([0-9]*\) notes name it; .*/\1/p' "$g.txt" 2> /dev/null)
  if ! has ': the same$' "$f.digest" 2> /dev/null; then why="not traced, or its digest is not the untraced run's"
  elif ! why=$(replay_clean rows/das-alarm); then why="its replay: $why"
  elif [ -z "$sent" ] || [ "$sent" = 0 ]; then why="no alarm sent"
  elif [ "$asks" != 0 ]; then why="a member asked a claimant (${asks:-?}): alarm_due may be armed, and the limit is no longer as stated"
  elif [ -z "$ps" ] || [ "$ps" = 0 ]; then why="probe_settled ran bare ${ps:-?} times: filter_entry was not entered outside a record"
  elif [ -z "$pd" ] || [ "$pd" = 0 ]; then why="no promise_due record"
  elif [ "$an" != 0 ] || [ "$1" != 0 ]; then why="a note names alarm_due (${an:-?} here, $1 over every trace)"
  fi
  if [ -n "$why" ]; then
    echo "the alarm's cell (rows/das-alarm): $why  <-- NOT" >> "$OUT/c-timers-all.txt"
    no "the alarm's cell (rows/das-alarm): $why (c-timers-all.txt)"
  else
    line="the alarm's cell (rows/das-alarm): digest the untraced run's; $(grep -m 1 '^replay: ' "$f.replay"); $sent alarms sent; filter_entry entered outside every record at the alarm's nodes (probe_settled bare $ps); promise_due $pd records; a limit, not a check: no member asks a claimant (0 asks), so alarm_due is never armed (0 notes)"
    echo "$line" >> "$OUT/c-timers-all.txt"
    echo "  $line"
  fi
}
s_tracercontrols() {
  local f want bad nm
  # the need das: the DAS traces this invocation makes, written by das_stamp before the calls summary reads; none
  # until then, whatever the flags
  rm -f "$OUT/das.traces"; touch "$OUT/tracercontrols.start"
  # the tracer's check of its own log: an assignment that goes unlogged must stop it
  if (cd "$TOY" && $PY "$T/unlogged3.py" . "$OUT/c-unlogged.jsonl.gz" --n 20000 --seed 1 > "$OUT/c-unlogged.out" 2> "$OUT/c-unlogged.err"); then
    no "the tracer wrote a trace to its end with every twentieth assignment unlogged"
  elif has -E '^unlogged3: ' "$OUT/c-unlogged.err" && has -E "^trace3: the views' log does not account" "$OUT/c-unlogged.err"; then
    echo "  control, an assignment unlogged: the tracer stopped, as it must"
  else no "the tracer stopped on an unlogged assignment for another reason (c-unlogged.err)"; fi
  # the tracer's own checks: each planted fault must stop it, with its own words
  : > "$OUT/c-tracerfaults.txt"; bad=0
  local also
  for f in made-rows-off alias alias-control installed-flip pending-twice alias-start alias-message defer-chain replaced false-wrapper stale-id level1-in-cell late-rebind stale-id-callee rebind-after-records limit-fraction early-install-v2 raw-alias-v2 other-node-v2 unscanned-layer-v2 raw-chunk-id-v2 hdr-other-v2 alias-missing-v2 other-node-tape-v2 rebound-scanned-v2 rebind-tape-v2 rebind-view-v2 stale-id-bare-v2 close-keyerror-v2 param-after-install-v2 observer-timer-v2; do
    also=
    case $f in
      observer-timer-v2) want="^trace3: node [0-9]*: the observer Node\._seacast\.<locals>\.check_completion \(node\.py:[0-9]+\) over check_completion arms a timer \(sim\.after\): an observer changes nothing$" ;;
      param-after-install-v2) want="^trace3: node [0-9]*: type payload's EAGER changed after the tracer's install \(True there, False now\): the nodes line holds a type's parameters as the install read them" ;;
      # a slot bound again after the install: the next record's entry check stops it (bindings_check), and
      # final_check's words follow at the close, both stops shown
      rebind-tape-v2) want="^trace3: node [0-9]*: peer_id_bytes is bound to Node\._namespace\.<locals>\.peer_id_bytes \(node\.py:[0-9]*\) at the entry of [a-z_0-9]*'s record, not to the tracer's own binding: a binding made after the install or during a call, which the twin would not run$"
        also="^trace3: \(at the close, after the stop\) SystemExit: trace3: node [0-9]*: peer_id_bytes was bound again after the tracer was installed, which under SEACAST must be the namespace's last binding" ;;
      rebind-view-v2) want="^trace3: node [0-9]*: offers is bound to OfferMap at the entry of [a-z_0-9]*'s record, not to the tracer's own binding: a binding made after the install or during a call, which the twin would not run$"
        also="^trace3: \(at the close, after the stop\) SystemExit: trace3: node [0-9]*: offers was bound again after the tracer was installed, which under SEACAST must be the namespace's last binding: a OfferMap$" ;;
      close-keyerror-v2) want="^trace3: node [0-9]*: N is called while node [0-9]*'s record is open and no question runs"
        also="^trace3: \(at the close, after the stop\) KeyError: 'planted at the close'$" ;;   # the close's, a note
      rebound-scanned-v2) want="^trace3: node [0-9]*: popcount_again is bound to a function of the toy's that the scan of its bindings does not name: popcount \(bits\.py:[0-9]*\)" ;;
      other-node-tape-v2) want="^trace3: node [0-9]*: peer_id_bytes is called while node [0-9]*'s record is open and no question runs" ;;
      raw-chunk-id-v2) want="^trace3: node [0-9]*: chunk_id is not the installed message_id" ;;
      hdr-other-v2) want="^trace3: node [0-9]*: hdr is not the toy's desc before the install" ;;
      alias-missing-v2) want="^trace3: node [0-9]*: chunk_id is missing under SEACAST" ;;
      unscanned-layer-v2) want="^trace3: node [0-9]*: on_frame is bound to a function of the toy's that the scan of its bindings does not name: make\.<locals>\.on_frame \(node\.py:2\)" ;;
      early-install-v2) want="^trace3: node [0-9]*: the closure rule's lists and the node differ: ALL is not in the namespace" ;;
        # An install before _seacast is still refused, and refused first by what it lacks: the install-time check of the
        # closure rule's lists. The last-binding check keeps its coverage through rebind-tape-v2 and rebind-view-v2,
        # which reach it. If a later install-time check moves the first stop again, these words move with it.
      raw-alias-v2) want="^trace3: node [0-9]*: hdr is not the installed desc" ;;
      other-node-v2) want="^trace3: node [0-9]*: N is called while node [0-9]*'s record is open and no question runs" ;;
      made-rows-off) want="^trace3: the views' log does not account for the state" ;;
      alias) want="^trace3: node [0-9]*: one queue entry stands in two places" ;;
      alias-control) want="^trace3: node [0-9]*: one queue entry's control stands in two places" ;;
      installed-flip) want="^trace3: installed_block\([0-9]*, [0-9a-f]*…\) answered (True, then False|False, then True), in one record" ;;
      pending-twice) want="^trace3: node [0-9]*: peer [0-9]*'s copy [0-9a-f]*… waits twice under one root" ;;
      alias-start) want="^trace3: node [0-9]*: one queue entry's control stands in two places, .*, at the record's start" ;;
      alias-message) want="^trace3: node [0-9]*: one queue control message stands in two places" ;;
      defer-chain) want="^trace3: node [0-9]*: a chain of 3 defers in one record, past the twin's 2" ;;
      replaced) want="^trace3: node [0-9]*: may_ask is traced, and its function here is neither seacast-lite.md's own code nor a listed wrapper of it: replaced\.<locals>" ;;
      false-wrapper) want="^trace3: node [0-9]*: may_ask is traced, and its function here is neither seacast-lite.md's own code nor a listed wrapper of it: .*a listed wrapper's name, without the document's may_ask in its closure" ;;
      late-rebind) want="^trace3: node [0-9]*: may_ask was bound again after the tracer was installed, to what is neither the tracer's wrapper nor a listed wrapper of it: late_rebind\.<locals>" ;;
      rebind-after-records) want="^trace3: node [0-9]*: may_ask was bound again after the tracer was installed, to what is neither the tracer's wrapper nor a listed wrapper of it: rebind_after_records\.<locals>" ;;
      limit-fraction) want="^trace3: node [0-9]*: MAX_IHAVE_LENGTH is no count: 2\.5" ;;
      level1-in-cell) want="^trace3: node [0-9]*: validate_chunk is something else than the document's here \(.*\), which only a trace of the whole state may have" ;;
      *) want="^trace3: node [0-9]*: message_id returned [0-9a-f]{112}, and the document's function gives [0-9a-f]{112} for that chunk" ;;
    esac
    if (cd "$TOY" && $PY "$T/tracerfaults3.py" "--$f" . "$OUT/c-tf-$f.jsonl.gz" --n 20000 --seed 1 > "$OUT/c-tf-$f.out" 2> "$OUT/c-tf-$f.err"); then
      echo "$f: the tracer wrote its trace to the end  <-- it must not" >> "$OUT/c-tracerfaults.txt"; bad=1
    elif has -E "^tracerfaults3: $f, planted [1-9][0-9]* times?(;|\$)" "$OUT/c-tf-$f.err" && has -E "$want" "$OUT/c-tf-$f.err" \
        && { [ -z "$also" ] || has -E "$also" "$OUT/c-tf-$f.err"; }; then
      echo "$f: the tracer stopped, as it must: $(grep -m 1 -E "$want" "$OUT/c-tf-$f.err" | cut -c1-100)" >> "$OUT/c-tracerfaults.txt"
    else echo "$f: the tracer stopped without the words it must give  <-- NOT" >> "$OUT/c-tracerfaults.txt"; bad=1; fi
  done
  [ "$bad" = 0 ] || no "a planted fault of the tracer's (c-tracerfaults.txt)"
  [ "$(grep -c 'the tracer stopped, as it must' "$OUT/c-tracerfaults.txt")" = 31 ] || no "not 31 planted faults stop the tracer as written (c-tracerfaults.txt)"
  echo "  $(grep -c 'the tracer stopped, as it must' "$OUT/c-tracerfaults.txt") of 31 planted faults stop the tracer with their own words"
  # under SEACAST, the tracer-wide depth's plants, which must not stop it: a call at another node inside a question runs
  # bare and is counted, a replaced name entered outside any record makes no record inside and restores its state on
  # a raise; each plant's body is the plain SEACAST trace's (the run above), each control's another (a record inside)
  # each plant's count read from the .bare.json the tracer wrote; each plant's body the plain trace's; each control's
  # the plain one with exactly its extra records of N at the named node, its trailer counting them
  # A plant that replaces a function at a node has that function's chain in the node's entry of the nodes line, for
  # the chain tells the truth about the code there: chain names it, and extra_records judges the nodes line with each
  # entry's chains set aside, that node's chain of on_iwant the plant's, every other the plain trace's
  : > "$OUT/c-tracerplants.txt"; bad=0
  local plain line node k want why chain spec also_chain pl co
  for f in bare-in-question-v2 bare-in-question-v2-per-node suppressed-entry-v2 suppressed-entry-v2-off bare-replaced-v2 bare-timer-v2 bare-timer-v2-now hdr-read-v2 hdr-read-v2-raw observer-timer-v2-off; do
    chain=
    case $f in      # the plant's own function at the planted node, its chain of on_iwant
      suppressed-entry-v2|suppressed-entry-v2-off) chain='["suppressed_entry_seacast.<locals>.install.<locals>.on_iwant"]' ;;
      bare-replaced-v2) chain='["bare_in_question_seacast.<locals>.install.<locals>.on_iwant"]' ;;
    esac
    case $f in     # k: the control's extra records of N; - for a plant read by its line alone (its read adds to a record)
      bare-in-question-v2) plain=seacast/hand5; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; bare c N: 1$" ;;
      bare-in-question-v2-per-node) plain=seacast/hand5; k=1; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; records inside: 1; bare c N: 0$" ;;
      suppressed-entry-v2) plain=seacast/hand5-own; k=0; line=", planted 2 times; node s: [0-9]+; entry 1: returned; supp after the return: 0; bare s N: 2; entry 2: raised; supp after the raise: 0$" ;;
      suppressed-entry-v2-off) plain=seacast/hand5-own; k=2; line=", planted 2 times; records inside: 2; node s: [0-9]+; entry 1: returned; supp after the return: 0; bare s N: 0; entry 2: raised; supp after the raise: 0$" ;;
      bare-replaced-v2) plain=seacast/hand5-own; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; the replaced body ran: 1; bare c on_iwant: 1$" ;;
      bare-timer-v2) plain=seacast/hand5; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; the timer scheduled at node c: 1; fired from the simulator, outside the question: 1$" ;;
      bare-timer-v2-now) plain=seacast/hand5; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; the timer scheduled at node c: 0; fired from the simulator, outside the question: 0$" ;;
      hdr-read-v2) plain=seacast/hand5; k=-; line=", planted 1 time; node a: [0-9]+; desc read in its record: 1; the record's own reads of it: 0$" ;;
      hdr-read-v2-raw) plain=seacast/hand5; k=0; line=", planted 1 time; node a: [0-9]+; desc read in its record: 0; the record's own reads of it: 0$" ;;
      # the simulator's guard off (the control of the planted fault observer-timer-v2): a timer armed at each
      # assignment of a node's completed, and the body seacast/hand5's; one assignment for each group completed
      observer-timer-v2-off) plain=seacast/hand5; k=0; line=", planted [1-9][0-9]* times?; completions: [1-9][0-9]*$" ;;
    esac
    rm -f "$OUT/c-tp-$f.jsonl.gz" "$OUT/c-tp-$f.jsonl.gz.bare.json"    # nothing left from an earlier run counts
    if ! (cd "$TOY" && $PY "$T/tracerfaults3.py" "--$f" . "$OUT/c-tp-$f.jsonl.gz" > "$OUT/c-tp-$f.out" 2> "$OUT/c-tp-$f.err"); then
      echo "$f: the run did not end with 0  <-- it must" >> "$OUT/c-tracerplants.txt"; bad=1; continue
    fi
    if ! has -E "^tracerfaults3: $f$line" "$OUT/c-tp-$f.err"; then
      echo "$f: its line is not as written  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; continue
    fi
    if [ "$f" = observer-timer-v2-off ]; then       # one assignment of completed for each group completed
      pl= co=
      read -r pl co < <(sed -n -E 's/^tracerfaults3: [a-z0-9-]+, planted ([0-9]+) times?; completions: ([0-9]+)$/\1 \2/p' "$OUT/c-tp-$f.err")
      if [ -z "$pl" ] || [ "$pl" != "$co" ]; then
        echo "$f: planted ${pl:-?} times, and ${co:-?} completions: not one assignment for each  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; continue
      fi
    fi
    if ! gzip -t "$OUT/c-tp-$f.jsonl.gz" 2> /dev/null || ! gzip -t "$OUT/$plain.jsonl.gz" 2> /dev/null; then
      echo "$f: its trace or $plain's does not decompress whole  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; continue
    fi
    node=$(sed -n -E 's/.*(node a, node c: [0-9]+, |node s: )([0-9]+).*/\2/p' "$OUT/c-tp-$f.err" | head -n 1)
    case $f in      # the .bare.json, exactly
      bare-in-question-v2) want="{\"$node N\": 1}" ;;
      suppressed-entry-v2) want="{\"$node N\": 2}" ;;
      bare-replaced-v2) want="{\"$node on_iwant\": 1}" ;;
      *) want="{}" ;;
    esac
    if [ "$(cat "$OUT/c-tp-$f.jsonl.gz.bare.json" 2> /dev/null)" != "$want" ]; then
      echo "$f: its .bare.json is not $want  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; continue
    fi
    spec=() also_chain=
    if [ -n "$chain" ]; then spec=("$node" on_iwant "$chain"); also_chain=", but node $node's chain of on_iwant, the plant's"; fi
    if [ "$k" = - ]; then           # read by its line alone
      echo "$f: as it must: $(grep -m 1 -E '^tracerfaults3: ' "$OUT/c-tp-$f.err" | cut -c16-160); .bare.json $want" >> "$OUT/c-tracerplants.txt"
    elif [ "$k" = 0 ]; then         # a plant: the plain trace's body (a plant that names no node c or s: node 0,
      #                               which no node is, so that no record counts as inserted, as k 0 requires)
      if why=$(extra_records "$OUT/$plain.jsonl.gz" "$OUT/c-tp-$f.jsonl.gz" "${node:-0}" N 0 "${spec[@]}"); then
        echo "$f: as it must: $(grep -m 1 -E '^tracerfaults3: ' "$OUT/c-tp-$f.err" | cut -c16-160); .bare.json $want; the body $plain's$also_chain" >> "$OUT/c-tracerplants.txt"
      else echo "$f: the body not $plain's$also_chain: $why  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
    elif why=$(extra_records "$OUT/$plain.jsonl.gz" "$OUT/c-tp-$f.jsonl.gz" "$node" N "$k" "${spec[@]}"); then
      echo "$f: as it must: $(grep -m 1 -E '^tracerfaults3: ' "$OUT/c-tp-$f.err" | cut -c16-160); the body $plain's and $k records of N at node $node, its trailer counting them$also_chain" >> "$OUT/c-tracerplants.txt"
    else echo "$f: the body not $plain's and $k records of N at node $node$also_chain: $why  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  done
  # the check that no SEACAST trace counts a bare call (s_replays) itself fails on a planted count
  if bare_none "$OUT/c-tp-bare-in-question-v2.jsonl.gz"; then
    echo "control: the check of no bare call passes the plant's count  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
  else echo "control: the check of no bare call fails on the plant's count, as it must" >> "$OUT/c-tracerplants.txt"; fi
  # extra_records' own controls, on traces made from the plain seacast/hand5: itself with k 0 passes; two record lines
  # swapped, the trailer's rest changed, another function's count changed: each refused, for its own reason (a
  # fixture not made, or not whole, fails the control)
  rm -f "$OUT/c-er-swapped.jsonl.gz" "$OUT/c-er-rest.jsonl.gz" "$OUT/c-er-other.jsonl.gz"
  if ! $PY - "$OUT/seacast/hand5.jsonl.gz" "$OUT/c-er" <<'EOF_ER'
import gzip
import json
import sys
src, out = sys.argv[1], sys.argv[2]
with gzip.open(src, "rt") as f:
    lines = f.read().splitlines()
recs = [j for j, x in enumerate(lines) if x.startswith('{"n"')]
t = json.loads(lines[-1])
other = next(fn for fn in t["trailer"]["by_fn"] if fn != "N")
cases = {"swapped": lines[:recs[0]] + [lines[recs[1]], lines[recs[0]]] + lines[recs[1] + 1:]}
for name, change in (("rest", lambda d: d["trailer"].update(rest=d["trailer"]["rest"] + 1)),
                     ("other", lambda d: d["trailer"]["by_fn"].update({other: d["trailer"]["by_fn"][other] + 1}))):
    d = json.loads(lines[-1])
    change(d)
    cases[name] = lines[:-1] + [json.dumps(d, separators=(",", ":"))]
for name, ls in cases.items():
    with gzip.open(f"{out}-{name}.jsonl.gz", "wt") as f:
        f.write("\n".join(ls) + "\n")
EOF_ER
  then
    echo "control: extra_records' fixtures were not made  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
  fi
  if extra_records "$OUT/seacast/hand5.jsonl.gz" "$OUT/seacast/hand5.jsonl.gz" 1 N 0 > /dev/null; then
    echo "control: extra_records passes a trace against itself, as it must" >> "$OUT/c-tracerplants.txt"
  else echo "control: extra_records refuses a trace against itself  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  for c in swapped rest other; do
    case $c in swapped) want="is neither the first trace's next line" ;; *) want="the trailer is not the first's" ;; esac
    if ! gzip -t "$OUT/c-er-$c.jsonl.gz" 2> /dev/null; then
      echo "control: the planted $c is not a whole trace  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
    elif why=$(extra_records "$OUT/seacast/hand5.jsonl.gz" "$OUT/c-er-$c.jsonl.gz" 1 N 0 2> /dev/null); then
      echo "control: extra_records passes the planted $c  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
    elif [[ $why == *"$want"* ]]; then
      echo "control: extra_records refuses the planted $c, as it must: $why" >> "$OUT/c-tracerplants.txt"
    else echo "control: extra_records refuses the planted $c for another reason: $why  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  done
  # extra_records' chain spec, on traces made from the plain seacast/hand5-own, the spec its replaced node's on_iwant with
  # its own chain: itself passes; a record line changed; the nodes line changed outside the chains (the replaced
  # node's replaced emptied, the first entry's IWANT_WINDOW and its payload type's M each plus 1); another entry's
  # chains given a name more; the replaced node's chain of on_iwant changed: each refused, for its own reason.
  # Setting the chains aside removes that one member of each entry and nothing else
  rm -f "$OUT"/c-erc-*.jsonl.gz "$OUT/c-erc.spec"
  if ! $PY - "$OUT/seacast/hand5-own.jsonl.gz" "$OUT/c-erc" <<'EOF_ERC'
import gzip
import json
import sys
src, out = sys.argv[1], sys.argv[2]
with gzip.open(src, "rt") as f:
    lines = f.read().splitlines()
NL = 2                  # the nodes line: after the content line and the header
nodes = json.loads(lines[NL])["nodes"]
at = next(j for j, e in enumerate(nodes) if "on_iwant" in e["replaced"])
node, chain = nodes[at]["n"][0], nodes[at]["chains"]["on_iwant"]
rec = next(j for j, x in enumerate(lines) if x.startswith('{"n"') and json.loads(x)["fn"] != "N")
bk = next(c for c, v in nodes[0]["consts"].items() if isinstance(v, bool))     # the first Boolean constant
absent = max(n for e in nodes for n in e["n"]) + 1000                          # a node in no entry


def with_nodes(change):
    d = json.loads(lines[NL])
    change(d["nodes"])
    return lines[:NL] + [json.dumps(d, separators=(",", ":"))] + lines[NL + 1:]


r = json.loads(lines[rec])
r["args"] = r["args"] + [0]
cases = {
    "record": lines[:rec] + [json.dumps(r, separators=(",", ":"))] + lines[rec + 1:],
    "replaced": with_nodes(lambda ns: ns[at].update(replaced=[])),
    "const": with_nodes(lambda ns: ns[0]["consts"].update(IWANT_WINDOW=ns[0]["consts"]["IWANT_WINDOW"] + 1)),
    "type": with_nodes(lambda ns: ns[0]["types"]["payload"].update(M=ns[0]["types"]["payload"]["M"] + 1)),
    "const-bool": with_nodes(lambda ns: ns[0]["consts"].update({bk: int(ns[0]["consts"][bk])})),
    "other-chain": with_nodes(lambda ns: ns[0]["chains"].update(may_ask=["planted"])),
    "planted-chain": with_nodes(lambda ns: ns[at]["chains"].update(on_iwant=chain + ["planted"])),
}
assert at != 0, "the replaced node's entry is the first"
for name, ls in cases.items():
    with gzip.open(f"{out}-{name}.jsonl.gz", "wt") as f:
        f.write("\n".join(ls) + "\n")
with open(f"{out}.spec", "w") as f:
    f.write(f"{node}\n{json.dumps(chain)}\n{absent}\n")
EOF_ERC
  then
    echo "control: extra_records' chain fixtures were not made  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
  fi
  local cnode cchain cabsent
  cnode=$(sed -n 1p "$OUT/c-erc.spec" 2> /dev/null); cchain=$(sed -n 2p "$OUT/c-erc.spec" 2> /dev/null)
  cabsent=$(sed -n 3p "$OUT/c-erc.spec" 2> /dev/null)
  if [ -n "$cnode" ] && extra_records "$OUT/seacast/hand5-own.jsonl.gz" "$OUT/seacast/hand5-own.jsonl.gz" "$cnode" N 0 "$cnode" on_iwant "$cchain" > /dev/null; then
    echo "control: extra_records with node $cnode's chain of on_iwant passes seacast/hand5-own against itself, as it must" >> "$OUT/c-tracerplants.txt"
  else echo "control: extra_records with node ${cnode:-?}'s chain of on_iwant refuses seacast/hand5-own against itself  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  # the spec of a node in no entry (the largest plus 1000), the trace against itself: refused, for that reason
  if [ -z "$cabsent" ]; then
    echo "control: no node in no entry for the chain spec  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
  elif why=$(extra_records "$OUT/seacast/hand5-own.jsonl.gz" "$OUT/seacast/hand5-own.jsonl.gz" "$cnode" N 0 "$cabsent" on_iwant "$cchain" 2> /dev/null); then
    echo "control: extra_records passes the spec of node $cabsent, in no entry  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
  elif [[ $why == *"the spec's node $cabsent is in no entry of the nodes line"* ]]; then
    echo "control: extra_records refuses the spec of node $cabsent, in no entry, as it must: $why" >> "$OUT/c-tracerplants.txt"
  else echo "control: extra_records refuses the spec of node $cabsent, in no entry, for another reason: $why  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  for c in record replaced const type const-bool other-chain planted-chain; do
    case $c in
      record) want="is neither the first trace's next line" ;;
      replaced|const|type|const-bool) want="the nodes line differs outside its chains" ;;
      other-chain) want="a chain other than the planted node's differs from the first's" ;;
      planted-chain) want="the planted node's chain of on_iwant is" ;;
    esac
    if [ -z "$cnode" ] || ! gzip -t "$OUT/c-erc-$c.jsonl.gz" 2> /dev/null; then
      echo "control: the chain fixture $c is not a whole trace  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
    elif why=$(extra_records "$OUT/seacast/hand5-own.jsonl.gz" "$OUT/c-erc-$c.jsonl.gz" "$cnode" N 0 "$cnode" on_iwant "$cchain" 2> /dev/null); then
      echo "control: extra_records passes the chain fixture $c  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
    elif [[ $why == *"$want"* ]]; then
      echo "control: extra_records refuses the chain fixture $c, as it must: $why" >> "$OUT/c-tracerplants.txt"
    else echo "control: extra_records refuses the chain fixture $c for another reason: $why  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  done
  [ "$bad" = 0 ] || no "a plant under SEACAST (c-tracerplants.txt)"
  [ "$(grep -c '^[a-z0-9-]*: as it must: ' "$OUT/c-tracerplants.txt")" = 10 ] || no "not 10 plants under SEACAST as written (c-tracerplants.txt)"
  echo "  $(grep -c '^[a-z0-9-]*: as it must: ' "$OUT/c-tracerplants.txt") of 10 plants under SEACAST as written (five, and five controls), and the checks' controls"
  # under SEACAST, the nodes line's chains: hand5-own traced with its replaced names' chains left out (tracerfaults3's
  # --chains-omit-v2) is written to the end, and the replay's reader must refuse it, with its own words, naming the
  # first it meets: a name that a node of the line replaces with no chain there (hand5-own, --rebuilt none: push_rebuilt
  # at every node, and forward and on_iwant at its silent node)
  rm -f "$OUT/c-chains-omit.jsonl.gz" "$OUT/c-chains-omit.jsonl.gz.bare.json" "$OUT/c-chains-omit.replay" "$OUT/c-chains-omit.replay.rc"
  if ! (cd "$TOY" && $PY "$T/tracerfaults3.py" --chains-omit-v2 . "$OUT/c-chains-omit.jsonl.gz" > "$OUT/c-chains-omit.out" 2> "$OUT/c-chains-omit.err"); then
    no "the trace of a nodes line without a replaced name's chain did not end with 0 (c-chains-omit.err)"
  elif ! has -E '^tracerfaults3: chains-omit-v2, planted [1-9][0-9]* times?$' "$OUT/c-chains-omit.err"; then
    no "no replaced name's chain was left out (c-chains-omit.err)"
  elif replay_of c-chains-omit; then
    no "the replay passed a nodes line without a replaced name's chain (c-chains-omit.replay)"
  elif ! parsed_whole "$OUT/c-chains-omit.replay"; then
    no "the nodes line without a replaced name's chain: the parser refused a line of it, not the twin (c-chains-omit.replay)"
  elif nm=$(sed -n -E 's/^nodes: chains: a replaced name with no chain: ([A-Za-z_][A-Za-z0-9_]*)$/\1/p' "$OUT/c-chains-omit.replay"); [ -z "$nm" ]; then
    no "the replay refused a nodes line without a replaced name's chain otherwise than by its words (c-chains-omit.replay)"
  elif ! $PY -c 'import gzip, json, sys
for line in gzip.open(sys.argv[1], "rt", encoding="utf-8"):
    if line.startswith("{\"nodes\""):    # the name the replay names: replaced at a node of the trace, with no chain there
        sys.exit(0 if any(sys.argv[2] in (e.get("replaced") or ()) and sys.argv[2] not in (e.get("chains") or {})
                          for e in json.loads(line)["nodes"]) else 1)
sys.exit(2)' "$OUT/c-chains-omit.jsonl.gz" "$nm"; then
    no "the replay named $nm, which no node of the nodes line replaces without its chain (c-chains-omit.replay)"
  else echo "  a nodes line without its replaced names' chains: refused by the replay, with its words ($nm)"; fi
  # the chain cases: the nodes line's chains on three cells against written cases, and five plants, each caught:
  # (a) hand5-peer's trace with close_promises' chain cut to its bound layer, which the replay must refuse with its
  # words; (b) filter_entry's peer layer classed as an observer and (e) owed_missing's member-check layer as changing,
  # on hand5-peer; (c) the chains taken from the slots' bindings, on das-hoardcol-w16 (a hoarder's chain then holds
  # --fault hoard's lambda, and an honest node's two observers come inner first); (d) owed_missing's layer as an
  # observer, on das-samplers-mcoff (--member-check off). Each of (b)-(e) must make its cell's cases fail on what it
  # changed and on nothing else (c-chains.txt)
  chain_cases
  # the swapped draws (K13): keep_floor's on seacast/hand5 and defer_on_claim's on das-samplers-mcoff, each on its records'
  # tapes; (f) the re-wrap off, which the replay must refuse at each keep_floor record; (g) the swap left unrestored,
  # which the record's exit check must stop (c-draws.txt)
  swapped_draws
  # a record writer's arguments not runSeacast's case's: on_chunk's without p, which the replay must refuse (c-arity.*)
  arities_plant
  # the replaced names' rows (R3-9): each of the eight names the twin asks, with rows on a fixture's tapes where a
  # node replaces it (repair_verdict's and known_in_scope's fixtures are plants (l) and (j), layers of tracerfaults3's
  # own); (k) a row with an argument left out, which the replay must refuse; (m) the bias cell, which the record's
  # exit check must stop (c-rows.txt)
  replaced_rows
  # the stops (piece D): point 5's, a record's own call of a replaced name the twin cannot ask (plant (p) on
  # hand5-peer), and its control on seacast/hand5; point 6's, a binding live across a record, on seacast/hand5 under
  # --source-offers off: at the entry (D3), at the exit with the entry check removed (q), and with both removed, the
  # trace written to its end, a stated limit (c-stops.txt)
  stops
  # the carried cases (piece E): R7's tracer-wide depth on custody-floor-churn1, where node c's calls inside another
  # node's question run bare, and its planted fault (r), a depth per node, whose record the replay accepts (a stated
  # limit); a replaced name entered outside every record on hand5-peer, and its plants (s) and (t) (c-carried.txt)
  carried
  # F's three (piece F): S1-8a's count on churn1 (carried); S1-8b's writer (--self-test-seacast) and reader (families_seacast.py
  # on churn1, signed and plain, and its refusal of seacast/hand5 cut short or stopped); S1-C5's line on seacast/hand5
  # (c-fcases.txt)
  f_cases
  # H4's plant (n): one of LAYERS' changing layers left out, which the scan names and at whose install the tracer
  # stops (c-h4.err)
  h4_plant
  # the timers of deferred_offers: timers_seacast.py on das-samplers-mcoff's trace, and its three plants, each refused by
  # the checks it breaks (c-timers.txt)
  timers_check
  # the need das: the inventory's DAS traces this invocation made (das.traces)
  das_stamp
  # piece (b): each SEACAST trace's reached names and its IWANTs by records and by calls, with the calls file's controls,
  # last, so that every SEACAST trace of the run is made (c-reached.txt); held to the inventory (c-inventory.txt)
  calls_summary
  # deferred_offers' timers over the inventory's must traces, each read by the calls summary, and the alarm's cell
  # (c-timers-all.txt)
  timers_all
}
again_directed() {      # $1: a directed set; $2: 1 or 2: made again, in a process of its own
  local d=$1 tool
  tool=$(dirtool "$d")
  # shellcheck disable=SC2046
  (cd "$TOY" && $PY "$T/${tool%% *}" . "$OUT/seeds/$d-again$2.jsonl.gz" --n 20000 --seed 1 $(case "$tool" in *" "*) echo "${tool#* }" ;; esac) > /dev/null 2>&1)
}
seed_cells() {          # the seeds' cells, traced and replayed once more: their report to a file of its own
  # shellcheck disable=SC2086
  $PY "$T/cells3.py" "$TOY" "$OUT/seeds" -j 2 --replay "$REPLAY" $SEEDCELLS > "$OUT/seeds/cells.txt" 2>&1
}
s_seeds() {             # the same bytes whatever Python's hash seed: every directed set made again twice, two cells once
  local d s a b n=0 want h1 h2
  # The tracers' Python runs isolated and reads no PYTHONHASHSEED: its hash seed is random in every process. That
  # is what this step stands on, so it is shown first: two processes hash one string differently.
  h1=$($PY -c 'import sys; print(sys.flags.hash_randomization, hash("the same string"))')
  h2=$($PY -c 'import sys; print(sys.flags.hash_randomization, hash("the same string"))')
  case "$h1" in "1 "*) [ "$h1" != "$h2" ] || no "two Python processes hash a string alike: the hash seed is not random here" ;;
    *) no "Python's hash randomization is off: a retrace shows nothing" ;; esac
  rm -rf "$OUT/seeds"; mkdir -p "$OUT/seeds"; : > "$OUT/same-content.txt"
  for d in $DIRS; do for s in 1 2; do par again_directed "$d" "$s"; done; done
  # shellcheck disable=SC2086
  [ -z "$SEEDCELLS" ] || par seed_cells
  par_end || no "a trace could not be made again"
  for d in $DIRS; do for s in 1 2; do
    a=$(zcat "$OUT/directed/$d.jsonl.gz" | sha256sum | cut -c1-64); b=$(zcat "$OUT/seeds/$d-again$s.jsonl.gz" 2> /dev/null | sha256sum | cut -c1-64)
    echo "$d, made again ($s), and the run's own: $b, $a: $([ "$a" = "$b" ] && echo equal || echo DIFFERENT)" >> "$OUT/same-content.txt"
    [ "$a" = "$b" ] && n=$((n + 1))
  done; done
  for d in $SEEDCELLS; do
    a=$(zcat "$OUT/traces/$d.jsonl.gz" | sha256sum | cut -c1-64); b=$(zcat "$OUT/seeds/$d.jsonl.gz" 2> /dev/null | sha256sum | cut -c1-64)
    echo "$d, traced twice: $a, $b: $([ "$a" = "$b" ] && echo equal || echo DIFFERENT)" >> "$OUT/same-content.txt"
    [ "$a" = "$b" ] && n=$((n + 1))
  done
  want=$(( 2 * $(echo $DIRS | wc -w) + $(echo $SEEDCELLS | wc -w) ))
  [ "$n" = "$want" ] || no "not $want comparisons equal (same-content.txt)"
  echo "  $n of $want traces made again, each in a process with a hash seed of its own, have the same bytes (same-content.txt)"
}
size_one() {            # $1: a trace: its size's line and its full-id line, each to a file of its own
  local t=$1 k f nb nl big n rc
  k=$(echo "$t" | tr '/' '-'); f=$OUT/sizes/$k
  zcat "$OUT/$t.jsonl.gz" > "$f.jsonl" 2> /dev/null || { rm -f "$f.jsonl"; return 1; }
  nb=$(wc -c < "$f.jsonl"); nl=$(wc -l < "$f.jsonl")
  big=$(LC_ALL=C awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$f.jsonl")
  echo "$t: $nb bytes, $nl lines, the longest $big bytes" > "$f.size"
  n=$($PY "$T/fullid.py" "$f.jsonl"); rc=$?
  rm -f "$f.jsonl"
  echo "$t: ${n:-no count} lines with a full id outside its places (fullid.py's exit code $rc)" > "$f.fullid"
  [ "$rc" = 0 ]
}
s_sizes() {
  local t k n
  $PY "$T/fullid.py" --self-test > "$OUT/fullid-self-test.txt" 2>&1 || no "fullid.py's own cases (fullid-self-test.txt)"
  rm -rf "$OUT/sizes"; mkdir -p "$OUT/sizes" || { no "the sizes' directory"; return; }
  for t in $RTRACES; do par size_one "$t"; done
  par_end || no "a trace could not be read, or fullid.py did not count it"
  : > "$OUT/sizes.txt"; : > "$OUT/full-id-keys.txt"
  for t in $RTRACES; do
    k=$(echo "$t" | tr '/' '-')
    cat "$OUT/sizes/$k.size" >> "$OUT/sizes.txt" 2> /dev/null || no "$t has no size"
    cat "$OUT/sizes/$k.fullid" >> "$OUT/full-id-keys.txt" 2> /dev/null || { no "$t has no full-id count"; continue; }
    case "$t" in traces/hand5*|directed/*) ;; *)        # a cell under either document: its nodes ask by index
      n=$(sed -n 's/^[^:]*: \([0-9]*\) lines with a full id .*/\1/p' "$OUT/sizes/$k.fullid")
      [ "$n" = 0 ] || no "$t: ${n:-no count of} lines with a full id where the nodes ask by index" ;; esac
  done
  [ "$(grep -c . "$OUT/sizes.txt")" = "$(echo $RTRACES | wc -w)" ] || no "not every trace in sizes.txt"
  echo "  sizes.txt: $(grep -c . "$OUT/sizes.txt") traces, $(awk '{ s += $2 } END { printf "%d", s }' "$OUT/sizes.txt") bytes in all; the largest: $(sort -t' ' -k2,2n "$OUT/sizes.txt" | tail -n 1)"
  echo "  full-id-keys.txt: $(grep -c ': 0 lines' "$OUT/full-id-keys.txt") traces with none"
}
s_matrix() {            # part $PART of the mutants, on the directed sets first, then on the cells and the hand traces
  local m=$OUT/matrix o=$OUT/matrix/out c d rc mc
  mc="$CELLS hand5 hand5-publish"; [ -z "$REHEARSAL" ] || mc="hand5 hand5-publish"
  rm -rf "$m"; mkdir -p "$m/cells" "$m/directed" "$o" || { no "the matrix's directory"; return; }
  for c in $mc; do ln -s "$OUT/traces/$c.jsonl.gz" "$m/cells/$c.jsonl.gz" || no "no trace of $c for the matrix"; done
  for d in $DIRS; do ln -s "$OUT/directed/$d.jsonl.gz" "$m/directed/$d.jsonl.gz" || no "no directed set $d for the matrix"; done
  # shellcheck disable=SC2086
  $PY "$T/mutants3.py" "$m/directed" "$m/work" -j "$J" --twin "$OUT/twin" --part "$PART" --hashes "$o/mutants.sha256" \
      --pairs "$o/mutants-directed-pairs.txt" $REHEARSAL > "$o/mutants-directed.txt" 2>&1; rc=$?
  [ "$rc" = 0 ] || no "the mutants on the directed sets: rc=$rc (matrix/out/mutants-directed.txt)"
  tail -n 1 "$o/mutants-directed.txt" | grep -q -E '^([0-9]+) of \1 mutants told from the twin by these traces: ' \
    || no "not every mutant of the part is told by a directed set"
  # shellcheck disable=SC2086
  $PY "$T/mutants3.py" "$m/cells" "$m/work" -j "$J" --twin "$OUT/twin" --part "$PART" --reuse \
      --pairs "$o/mutants-pairs.txt" ${SAMPLE:+--sample "$SAMPLE"} $REHEARSAL > "$o/mutants-cells.txt" 2>&1; rc=$?
  [ "$rc" = 0 ] || no "the mutants on the cells: rc=$rc (matrix/out/mutants-cells.txt)"
  # a draft's sample: every mutant of the part on the directed sets, the sample alone on the cells; marked, so
  # that no merge reads it as a matrix's part
  [ -z "$SAMPLE" ] || echo "$SAMPLE" > "$o/SAMPLE"
  if grep -q "'other'" "$o/mutants-directed.txt" "$o/mutants-cells.txt"; then no "a mismatch of a kind the reports do not name ('other')"; fi
  # what ties the part to what it ran and to its traces
  cp "$CONTENT" "$o/content.line" || no "the content line into the part"
  if [ -n "$REHEARSAL" ]; then echo "a rehearsal: no cell traced" > "$o/cells.txt"; else cp "$OUT/cells.txt" "$o/cells.txt" || no "cells.txt into the part"; fi
  sha256sum < "$REPLAY" | cut -c1-64 > "$o/replay.sha256"
  # shellcheck disable=SC2046
  (cd "$OUT" && $PY "$T/content.py" --hashes $(for c in $mc; do echo "traces/$c.jsonl.gz"; done) > "$o/traces.sha256" \
    && $PY "$T/content.py" --hashes $(for d in $DIRS; do echo "directed/$d.jsonl.gz"; done) > "$o/directed.sha256") || no "the traces' hashes into the part"
  (cd "$o" && sha256sum content.line traces.sha256 cells.txt replay.sha256 directed.sha256 mutants.sha256 mutants-pairs.txt \
      mutants-directed-pairs.txt mutants-cells.txt mutants-directed.txt > outputs.sha256) || no "the part's outputs.sha256"
  echo "  the directed sets: $(tail -n 1 "$o/mutants-directed.txt" | cut -c1-110)"
  echo "  the cells: $(tail -n 1 "$o/mutants-cells.txt" | cut -c1-110)"
}
s_against() {           # the run's manifest against the record's
  local rc
  $PY "$T/against.py" "$AGAINST" "$OUT" > "$OUT/against.txt" 2>&1; rc=$?
  case $rc in
    0|3) echo "  $(tail -n 1 "$OUT/against.txt" | cut -c1-200) (against.txt)" ;;
    *) no "the run is not the record's, or one of the two cannot be read (against.py's exit code $rc; against.txt): $(tail -n 1 "$OUT/against.txt" | cut -c1-120)" ;;
  esac
}
s_manifest() {           # the record's 55 traces by their two hashes, with what they were made from and by
  local f=$OUT/record-manifest.txt
  { echo "content $(sha256sum < "$CONTENT" | cut -c1-64)"
    echo "python $($PY -c 'import sys, platform; print(platform.python_version(), platform.machine(), sys.platform)')"
    echo "replay $(sha256sum < "$REPLAY" | cut -c1-64)"
    echo "twin $(sha256sum < "$OUT/twin-sources.txt" | cut -c1-64) ($(wc -l < "$OUT/twin-sources.txt") files: twin-sources.txt)"
    echo "documents seacast-lite.md $(sha256sum < "$TOY/../seacast-lite.md" | cut -c1-64) seacast.md $(sha256sum < "$TOY/../seacast.md" | cut -c1-64) (each file's sha256: reported, it decides nothing)"
    $PY -c 'import sys, hashlib; sys.path.insert(0, sys.argv[1]); import mutants3 as M; n = list(M.MUTANTS); print("mutants", len(n), hashlib.sha256("\n".join(n).encode()).hexdigest(), "(their names, in the tool'"'"'s order)")' "$T"
    # shellcheck disable=SC2046
    (cd "$OUT" && $PY "$T/content.py" --hashes $(for t in $RTRACES; do echo "$t.jsonl.gz"; done))
  } > "$f" 2> "$OUT/record-manifest.err" || no "the manifest (record-manifest.err)"
  [ "$(grep -c -E '^[0-9a-f]{64}  [0-9a-f]{64}  ' "$f")" = "$(echo $RTRACES | wc -w)" ] || no "not $(echo $RTRACES | wc -w) traces in the manifest"
  echo "  record-manifest.txt: $(grep -c -E '^[0-9a-f]{64}  [0-9a-f]{64}  ' "$f") traces; the traces' lines alone: sha256 $(grep -E '^[0-9a-f]{64}  ' "$f" | sha256sum | cut -c1-64)"
}

{
  date '+start %F %T %Z'
  echo "the toy: $TOY"
  $PY "$T/content.py" --toy "$TOY" > "$CONTENT" || { echo "check.sh: no content line of this tree (content.py)"; fail=" setup"; }
  echo "the content line: $(wc -c < "$CONTENT") bytes, sha256 $(sha256sum < "$CONTENT" | cut -c1-64)"
  for step in $STEPS; do
    [ -z "$fail" ] || [ "$fail" != " setup" ] || break
    echo "== $step: $(date '+%T')"
    case $step in build) ;; *) [ -x "$REPLAY" ] || { no "no replay built (the step build comes first)"; continue; } ;; esac
    "s_$step"
  done
  # the tree at the end is the tree at the start, and the bytecode directory is still empty
  $PY "$T/content.py" --toy "$TOY" | cmp -s - "$CONTENT" || { step=end; no "a file the content line names changed while the check ran"; }
  [ -z "$(find "$OUT/pyc" -type f | head -n 1)" ] || { step=end; no "a bytecode file was written to $OUT/pyc"; }
  if [ -s "$OUT/twin-sources.txt" ]; then     # the twin's sources, and the copy that was built, as at the build
    twin_list "$HERE" 2> /dev/null | cmp -s - "$OUT/twin-sources.txt" || { step=end; no "a source of the twin, or this script, changed since the build"; }
    twin_list "$OUT/twin" 2> /dev/null | cmp -s - "$OUT/twin-sources.txt" || { step=end; no "the built copy of the twin changed since the build"; }
  fi
  date '+end %F %T %Z'
  if [ -n "$fail" ]; then echo "check.sh: FAIL ($(echo $fail | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//'))"
  elif [ "$STEPS" != "$ALL" ]; then echo "check.sh: these steps passed ($STEPS): a part, not a pass$([ -z "$NODAS" ] || echo "; --no-das")"
  elif [ -n "$NODAS" ]; then echo "check.sh: these steps passed ($STEPS): --no-das, tracercontrols' DAS cells skipped: a part, not a pass"
  elif [ -n "$REHEARSAL" ]; then echo "check.sh: these steps passed ($STEPS): a rehearsal of the matrix's step, not a part"
  elif [ -n "$SAMPLE" ]; then echo "check.sh: these steps passed ($STEPS): part $PART of a draft's sample ($SAMPLE), not a matrix"
  elif [ -n "$PART" ]; then echo "check.sh: PASS (part $PART of the matrix)"
  elif [ -n "$FEWCELLS" ]; then echo "check.sh: these steps passed ($STEPS): a rehearsal over the cells [$CELLS], not a record"
  elif [ -n "$RECORD" ]; then echo "check.sh: PASS (the record's run)"
  elif [ -n "$V2STEPS" ]; then echo "check.sh: PASS (with seacastcells, schemacontrols, viewcontrols and tracercontrols)"
  else echo "check.sh: PASS"; fi
} 2>&1 | tee "$LOG"
case "$(tail -n 1 "$LOG")" in "check.sh: PASS"|"check.sh: PASS (the record's run)"|"check.sh: PASS (part "*|"check.sh: PASS (with seacastcells, schemacontrols, viewcontrols and tracercontrols)") true ;; *) false ;; esac \
  || { { [ "$STEPS" != "$ALL" ] || [ -n "$REHEARSAL" ] || [ -n "$SAMPLE" ] || [ -n "$FEWCELLS" ] || [ -n "$NODAS" ]; } && tail -n 1 "$LOG" | grep -q '^check.sh: these steps passed'; }
