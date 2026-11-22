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
#   build     a copy of the twin's sources, built from nothing with `lake build replay SpecTwin.V2` (SpecTwin.V2 for
#             the guard modules, V2/*Known.lean, whose #guards hold only where they are built; a copy of one with a
#             false #guard fails Lean, its control); twin-sources.txt: each
#             source file of the twin, this script and record.sh by sha256 (a link among them is refused; a
#             file whose name ends in .md, prose, is left out of the list); the copy, listed the same way, is
#             that list, and at the end of the run the sources and the copy still are; the forms of v2's
#             questions, each row of tools/forms-v2-examples.tsv read and refused by `replay --forms`, with its
#             three controls (a copy with one wrong row fails, its control)
#   selftests each tool's own cases (content.py, mutants3.py, altered3.py, commentsonly.py, fullid.py, against.py,
#             matrixdiff.py, trace3.py's of the names protocol-v2.md keeps, gen/schema_v2.py's encoders,
#             keptcopy.py's, labcites.py's and scan_bindings.py's); and no line of the twin's sources (the
#             build's copy), of its tools or of the prose beside them (every *.md but out/'s and record/'s)
#             cites the notes beside which they were developed (labcites.py), a citation planted in
#             README.md's copy reported
#   tables    the twin's generated files are the schema's (gen.py, makers.py); V2/Kept.lean's copies of protocol.md's
#             functions are their originals with the named differences alone (keptcopy.py); the views' own cases
#             (footprint_test.py)
#   scope     every function protocol.md's code blocks define has its twin, by name: an `enter "NAME"` in SpecTwin/
#             and a case of the replay's for NAME; counted by section; a twin with one name taken away is refused.
#             And v2's part: every name protocol-v2.md's manifest covers has an `enter` in SpecTwin/V2/ and a case
#             of runV2, and runV2 has no case the manifest does not cover but respond; two controls refused. And
#             v2's questions, both ways: each name of the manifest's QUESTIONS is read by an askCall or a case of
#             the tape reader, and each name the twin asks or reads as a call under protocol-v2.md is a question, a
#             covered or cut function, or the replay's own (keys, order); three controls refused
#   mutants   every mutant's text stands in the twin once (--places), and each type-checks alone against the build
#   screen    every cell's header and nodes line, under both documents, read by the replay; a nodes line without a
#             constant refused
#   cells     `none`, traced and replayed: its digest is golden.txt's (the tracer perturbs nothing)
#   small     hand5 (whole; §6.1's twelve alone; at PUBLISH), late16, and hand5 twice under protocol-v2.md: each
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
#   v2cells   every cell under protocol-v2.md: each digest golden-v2.txt's, each replayed (its records are of the
#             names that are protocol.md's all the way down); the tracer's self-test of those names
#   schemacontrols   the schema's and the makers' checks on planted changes: each must fail them
#   viewcontrols     23 broken views, each failing its own count of the views' cases, as written here; and
#             views_control's own controls: three stubs of the test that fail otherwise than its own failure (a
#             line after the verdict, a line on stderr, exit code 2) refused, the plain one taken
#   tracercontrols   a tracer whose views let an assignment through unlogged, and 30 faults planted in the tracer:
#             each must stop it, with its own words; under v2, nine plants that must not (five, and four controls),
#             each as written (a plant that replaces a function at a node: the nodes line with its chains set
#             aside, that node's chain the plant's), and the controls of the checks' own helpers; and a nodes
#             line without a replaced name's chain, which the replay must refuse with its words; and the chain
#             cases: the nodes line's chains on three cells against written cases (chaincases.py), each cell traced
#             and replayed, and five plants, each caught; and the swapped draws: each layer's draws on the tape of
#             a cell that enters it, and two plants on hand5 (the re-wrap off, which the replay must refuse; the
#             swap left unrestored, which must stop the tracer). With --no-das: the two DAS cells and the plants on
#             them skipped, which each line says; the check is then a part, not a pass
#   seeds     the same bytes whatever Python's hash seed, which is random in every process of an isolated Python:
#             every directed set made again twice, two cells once (46 traces)
#   sizes     sizes.txt: each of the record's traces as the tracer wrote it: bytes, lines, the longest line; and
#             full-id-keys.txt: its records that hold a chunk's full id anywhere but where one stands by design
#             (fullid.py): none in a cell's trace under either document, where the nodes ask by index
#   manifest  record-manifest.txt: the content line's sha256, the Python and the platform, each document's file
#             sha256 (for provenance: the content line names the documents by their code), and the two hashes of
#             each of the record's 55 traces (15 cells, three hand traces, 22 directed sets, 15 v2 cells)
# The steps `replays`, `headers` and the hashes then cover the record's traces.
# With --against DIR too (a record: a directory with a run's record-manifest.txt and content.line), a last step:
#   against   the run's manifest against the record's (against.py): as recorded; or another content and the same
#             bodies, with the files that differ; or not the record's, which fails the run
#
# With --matrix K/N (record.sh --matrix K/N): the Kth of N parts of the mutants' matrix, hours on a server each.
# The twin is built, the 15 cells, the hand traces and the 22 directed sets are traced and replayed as in the
# record's run (no cell under protocol-v2.md: no mutant is replayed there), and then:
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
# v2cells, schemacontrols, viewcontrols and tracercontrols, with the 15 cells' v2 traces among those the steps
# replays and headers read; its pass is "check.sh: PASS (with v2cells, schemacontrols, viewcontrols and
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
RECORD_ALL="build selftests tables scope mutants screen cells v2cells small directed replays headers picks controls perturbed schemacontrols viewcontrols tracercontrols seeds sizes manifest"
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
if [ -n "$V2STEPS" ]; then     # the quick check, the record's two steps of the tracer under protocol-v2.md, and the
  #                              schema's and the views' controls, in RECORD_ALL's order
  [ -z "$RECORD" ] || { echo "check.sh: --v2steps goes without --record or --matrix"; exit 2; }
  ALL="build selftests tables scope mutants screen cells v2cells small directed replays headers picks controls perturbed schemacontrols viewcontrols tracercontrols"
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
mkdir -p "$OUT/traces" "$OUT/directed" "$OUT/v2" || exit 2
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
DAS30="--nodes 30 --degree 8 --msgs 1 --setting rows --supernodes 10 --blobs 4 --seed 7 --doc v2"   # the chain cases'
LATE16="--nodes 16 --degree 8 --msgs 2 --seed 7 --late-block 30,400"
CELLS="announce cap-wait dcb20 hold ihave-limits late-block loss-thin none push push-deep rr-stripe silent withholders without-a without-b"
if [ -n "$FEWCELLS" ]; then
  [ -n "$RECORD" ] && [ -z "$PART" ] || { echo "check.sh: --cells goes with --record"; exit 2; }
  for c in $CELLS_GIVEN; do case " $CELLS " in *" $c "*) ;; *) echo "check.sh: no cell $c"; exit 2 ;; esac; done
  CELLS=$CELLS_GIVEN
fi
SEEDCELLS=$(for c in withholders loss-thin; do case " $CELLS " in *" $c "*) echo "$c" ;; esac; done)   # traced twice
SMALL="traces/late16 v2/hand5 v2/hand5-own"         # the check's small traces that are not the record's
if [ -z "$RECORD" ]; then
  TRACES="traces/none traces/hand5 traces/hand5-sec61 traces/late16 traces/hand5-publish v2/hand5 v2/hand5-own $(for d in $DIRS; do echo "directed/$d"; done)"
elif [ -n "$PART" ]; then       # a matrix part: the record's traces but the cells under protocol-v2.md
  RTRACES="$(for c in $CELLS; do echo "traces/$c"; done) traces/hand5 traces/hand5-sec61 traces/hand5-publish $(for d in $DIRS; do echo "directed/$d"; done)"
  TRACES="$RTRACES $SMALL"
else                    # the record's 55, then the three small ones
  RTRACES="$(for c in $CELLS; do echo "traces/$c"; done) traces/hand5 traces/hand5-sec61 traces/hand5-publish $(for d in $DIRS; do echo "directed/$d"; done) $(for c in $CELLS; do echo "v2/$c"; done)"
  TRACES="$RTRACES $SMALL"
fi
[ -z "$V2STEPS" ] || TRACES="$TRACES $(for c in $CELLS; do echo "v2/$c"; done)"    # v2cells' traces, read too

replay_of() {           # $1: a trace, without its .jsonl.gz: replayed to $1.replay; the status is the replay's
  zcat "$OUT/$1.jsonl.gz" | "$REPLAY" --content "$CONTENT" > "$OUT/$1.replay" 2>&1
  return "${PIPESTATUS[1]}"
}
digest_of() { sed -n '/^digest /{s/^digest \(.\{16\}\).*/\1/p;q}' "$1"; }
bare_none() { [ "$(cat "$1.bare.json" 2> /dev/null)" = "{}" ]; }     # $1: a v2 trace: its run counted no bare call
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
  # the Lean that builds the copy: its version read in the copy, where lean-toolchain holds (elan's default may differ)
  echo "  $(cd "$OUT/twin" && lean --version 2>&1 | head -n 1)"
  # SpecTwin.V2 too: it alone imports the guard modules (V2/*Known.lean), whose #guards hold only where they are built
  (cd "$OUT/twin" && lake build replay SpecTwin.V2) > "$OUT/build.txt" 2>&1 || { grep -v '^✔' "$OUT/build.txt" | head -n 40; no "the build failed"; return; }
  [ -x "$REPLAY" ] || { no "the build left no replay"; return; }
  twin_list "$OUT/twin" 2> /dev/null | cmp -s - "$OUT/twin-sources.txt" || { no "the copy that was built is not the twin's sources as listed"; return; }
  echo "  the twin's sources: $(wc -l < "$OUT/twin-sources.txt") files, the list's sha256 $(sha256sum < "$OUT/twin-sources.txt" | cut -c1-64) (twin-sources.txt)"
  echo "  the replay: sha256 $(sha256sum < "$REPLAY" | cut -c1-64)"
  local k g=()
  for k in "$OUT"/twin/SpecTwin/V2/*Known.lean; do
    k=$(basename "$k" .lean)
    grep -q -E "Built SpecTwin\.V2\.$k( |\$)" "$OUT/build.txt" || { no "the guard module $k was not built (build.txt)"; return; }
    g+=("$k")
  done
  [ ${#g[@]} -gt 0 ] || { no "no guard module under SpecTwin/V2"; return; }
  echo "  the guards: ${#g[@]} modules of SpecTwin.V2 built, each #guard held (${g[*]})"
  # its control: a copy of a guard module with a false #guard, given to Lean beside the built copy, fails
  mkdir -p "$OUT/guard-control"
  { cat "$OUT/twin/SpecTwin/V2/FuelKnown.lean"; printf '\n#guard false\n'; } > "$OUT/guard-control/FuelKnown.lean"
  if ! (cd "$OUT/twin" && lake env lean "$OUT/guard-control/FuelKnown.lean") > "$OUT/guard-control/lean.txt" 2>&1 \
     && grep -q -F 'did not evaluate to `true`' "$OUT/guard-control/lean.txt"; then
    echo "  control, a false #guard in a guard module: it fails, as it must"
  else no "control, a false #guard in a guard module: NOT failed (guard-control/lean.txt)"; fi
  # the forms of v2's questions: each row of the tools' file read and refused by the replay, and the checker's
  # three controls refused (replay --forms, V2/FormsRows.lean); a file that is not there fails, it is not skipped
  local forms="$T/forms-v2-examples.tsv" rows
  [ -f "$forms" ] || { no "no forms file (tools/forms-v2-examples.tsv)"; return; }
  rows=$(grep -c . "$forms")
  "$REPLAY" --forms "$forms" > "$OUT/forms.txt" 2>&1 \
    || { grep -F 'FAIL' "$OUT/forms.txt" | head -n 10 | cut -c1-300; no "the forms: a row not read or not refused, or a control not refused (forms.txt)"; return; }
  [ "$(tail -n 1 "$OUT/forms.txt")" = "rows $rows, controls 3, failed 0" ] \
    || { no "the forms: not $rows rows and 3 controls with none failed (forms.txt)"; return; }
  echo "  the forms: $rows rows read and refused, 3 controls refused (forms-v2-examples.tsv)"
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
trace3.py --self-test-v2 ^ok:
gen/schema_v2.py --self-test ^ok: every case as it must be$
keptcopy.py --self-test ^ok: every case as it must be$
labcites.py --self-test ^labcites self-test, planted: (.*), must be \1$
scan_bindings.py --self-test ^ok: every case as it must be$
EOF_SELF
  rm -f "$OUT/selftest.out"
  [ "$n" = 12 ] || no "not 12 tools' self-tests passed"
  echo "  $n of 12 tools' own cases as they must be (selftests.txt)"
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
  # over close_promises, bound under v2 alone (_v2 calls _peer_promise), is held to LAYERS, which lists it
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
    || no "a copy of protocol.md's Lean in V2/Kept.lean differs from its original beyond the named differences (keptcopy.txt)"
  tail -n 1 "$OUT/keptcopy.txt" | sed 's/^/  /'
  $PY "$T/footprint_test.py" > "$OUT/views.txt" 2>&1 || no "the views' own cases (views.txt)"
  tail -n 1 "$OUT/views.txt" | sed 's/^/  /'
}
s_scope() {             # the twin's scope held to the document: every `def` of protocol.md's code blocks, by name
  $PY - "$(dirname "$TOY")/protocol.md" "$HERE/SpecTwin" > "$OUT/scope.txt" 2>&1 <<'EOF'
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
    print(f"NOT every function of protocol.md's code blocks has its twin: {len(bad)} without")
    sys.exit(1)
print(f"{len(names)} of {len(names)} functions of protocol.md's code blocks have their twin, by name")
EOF
  [ $? = 0 ] || no "a function of protocol.md's code blocks without its twin, or the scope's control (scope.txt)"
  # v2's part: every name the manifest covers has an `enter` in SpecTwin/V2/ and a case of runV2, and every case of
  # runV2 is a covered name or the one kept form that is no covered name (respond)
  $PY - "$T/gen" "$HERE/SpecTwin" >> "$OUT/scope.txt" 2>&1 <<'EOF'
import re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import manifest_v2
twin = Path(sys.argv[2])
covered = list(manifest_v2.COVERED)
entered = set()
for f in sorted((twin / "V2").glob("*.lean")):
    entered |= set(re.findall(r'enter "([A-Za-z_0-9]+)"', f.read_text()))
text = (twin / "V2" / "Replay.lean").read_text()
body = text[text.index("\ndef runV2 "):]                 # runV2's cases, not the tape reader's
cases = set(re.findall(r'^\s*\| "([A-Za-z_0-9]+)", #\[', body, re.M))
FORM_ALONE = {"respond"}

def missing(entered, cases):
    out = [f"{n}: {'no enter' if n not in entered else 'no case of runV2'}"
           for n in covered if n not in entered or n not in cases]
    return out + [f"{c}: a case of runV2 the manifest does not cover" for c in sorted(cases - set(covered) - FORM_ALONE)]
bad = missing(entered, cases)
for b in bad:
    print(f"v2, without its twin: {b}")
gone = covered[0]                            # the controls: each must be refused
ctl1 = missing(entered - {gone}, cases)
ok1 = bool(ctl1) and ctl1[0].startswith(gone + ":")
print(f"control, v2's twin without {gone}: {'refused, as it must be' if ok1 else 'NOT refused  <-- FAIL'}")
ctl2 = missing(entered, cases | {"on_frame"})
ok2 = "on_frame: a case of runV2 the manifest does not cover" in ctl2
print(f"control, runV2 with a case named on_frame: {'refused, as it must be' if ok2 else 'NOT refused  <-- FAIL'}")
if bad or not ok1 or not ok2:
    print(f"NOT every one of protocol-v2.md's covered functions has its twin, or runV2 has a case it does not cover: {len(bad)}")
    sys.exit(1)
print(f"{len(covered)} of {len(covered)} of protocol-v2.md's covered functions have their twin, by name")
EOF
  [ $? = 0 ] || no "a covered function of protocol-v2.md without its twin, a case of runV2 not covered, or v2's scope controls (scope.txt)"
  # v2's questions, both ways: each name of the manifest's QUESTIONS is read by the twin (an askCall, or a case of
  # the tape reader), and each name the twin asks or reads as a call under protocol-v2.md is a question, a covered
  # or cut function, or one of the replay's own entries
  $PY - "$T/gen" "$HERE/SpecTwin" >> "$OUT/scope.txt" 2>&1 <<'EOF'
import re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import manifest_v2
twin = Path(sys.argv[2])
questions = list(manifest_v2.QUESTIONS)
OWN_ENTRIES = {"keys", "order"}               # the replay's own entries under v2: a table's keys, an iteration's order
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
entries = set(CASE.findall(body(twin / "Replay.lean", "entry"))) | set(CASE.findall(body(twin / "V2" / "Replay.lean", "entryV2")))
# The reverse direction reads the names asked under V2/ and by v2's tape reader. A kept function asks through
# Replay.lean's instance, shared with protocol.md's functions, so its questions are not told apart here; gen.py's
# manifest_questions holds them, over the Python's closure of the covered and kept functions.
asked_v2 = asks(sorted((twin / "V2").glob("*.lean")))
calls_v2 = body(twin / "V2" / "Replay.lean", "callNamesV2").split(":=", 1)[1].split("\n\n")[0]
for n in re.findall(r'"([A-Za-z_0-9]+)"', calls_v2) + sorted(CASE.findall(body(twin / "V2" / "Replay.lean", "entryV2"))):
    asked_v2.setdefault(n, "SpecTwin/V2/Replay.lean's tape reader")

def wrong(questions, asked_v2):
    listed = set(questions) | set(manifest_v2.COVERED) | set(manifest_v2.CUT) | OWN_ENTRIES
    out = [f"{n}: in QUESTIONS, read by no askCall and no tape entry of the twin"
           for n in questions if n not in asked and n not in entries]
    return out + [f"{n}: asked by the twin under protocol-v2.md ({p}), in no list of the manifest"
                  for n, p in sorted(asked_v2.items()) if n not in listed]
bad = wrong(questions, asked_v2)
for b in bad:
    print(f"v2's questions: {b}")
by_ask = sum(n in asked for n in questions)
ctl1 = wrong([n for n in questions if n != "links"], asked_v2)
ok1 = any(c.startswith("links: asked by the twin under protocol-v2.md (") for c in ctl1)
print(f"control, QUESTIONS without links: {'refused, as it must be' if ok1 else 'NOT refused  <-- FAIL'}")
ctl2 = wrong(questions, {**asked_v2, "made_up": "a planted askCall"})
ok2 = "made_up: asked by the twin under protocol-v2.md (a planted askCall), in no list of the manifest" in ctl2
print(f"control, an askCall of made_up under V2/: {'refused, as it must be' if ok2 else 'NOT refused  <-- FAIL'}")
ctl3 = wrong(questions + ["made_up"], asked_v2)
ok3 = "made_up: in QUESTIONS, read by no askCall and no tape entry of the twin" in ctl3
print(f"control, QUESTIONS with made_up: {'refused, as it must be' if ok3 else 'NOT refused  <-- FAIL'}")
if bad or not (ok1 and ok2 and ok3) or not questions:
    print(f"NOT every one of protocol-v2.md's questions is read by the twin, or the twin asks one the manifest does not list: {len(bad)}")
    sys.exit(1)
print(f"{len(questions)} of {len(questions)} of protocol-v2.md's questions are read by the twin: {by_ask} by an askCall, "
      f"{len(questions) - by_ask} by a tape entry alone")
print(f"the {len(asked_v2)} names the twin asks or reads as calls under protocol-v2.md are each a question, a covered "
      f"function, a cut one or the replay's own ({', '.join(sorted(OWN_ENTRIES))})")
EOF
  [ $? = 0 ] || no "a question of protocol-v2.md the twin does not read, a name the twin asks that the manifest does not list, or the questions' controls (scope.txt)"
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
  for doc in v03 v2; do
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
s_v2cells() {            # every cell under protocol-v2.md: its digest golden-v2.txt's; the records are protocol.md's names
  $PY "$T/trace3.py" --self-test-v2 > "$OUT/v2-self-test.txt" 2>&1 || no "the tracer's self-test of v2's kept names (v2-self-test.txt)"
  if [ -z "$CELLS" ]; then echo "  no v2 cell (a rehearsal)"; echo ok > "$OUT/cells-v2.txt"; return; fi
  local c
  for c in $CELLS; do rm -f "$OUT/v2/$c.jsonl.gz.bare.json"; done     # no count left from an earlier run counts
  # shellcheck disable=SC2086
  $PY "$T/cells3.py" "$TOY" "$OUT/v2" -j "$J" --doc v2 --replay "$REPLAY" $CELLS > "$OUT/cells-v2.txt" 2>&1 || no "a v2 cell (cells-v2.txt)"
  has -x ok "$OUT/cells-v2.txt" || no "no verdict on the v2 cells"
  [ "$(grep -c ', digest as golden-v2.txt, ' "$OUT/cells-v2.txt")" = "$(echo $CELLS | wc -w)" ] || no "not every v2 cell's digest is golden-v2.txt's"
  echo "  $(grep -c ', digest as golden-v2.txt, ' "$OUT/cells-v2.txt") of $(echo $CELLS | wc -w) v2 cells: digest as golden-v2.txt, replayed (cells-v2.txt)"
}
small() {               # $1: a name; $2: its directory; $3: the tracer's environment setting, or ""; the rest: run.py's arguments
  local name=$1 dir=$2 setting=$3 got plain; shift 3
  rm -f "$OUT/$dir/$name.jsonl.gz" "$OUT/$dir/$name.jsonl.gz.bare.json" "$OUT/$dir/$name.replay"
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
    par small hand5 v2 "" $HAND5 --doc v2
    par small hand5-own v2 "" $HAND5 --rebuilt none --fault sil30 --doc v2; }
  par_end || no "a small cell was not traced, or its digest is not the untraced run's"
  cat "$OUT"/traces/*.digest "$OUT"/v2/*.digest 2> /dev/null | tee "$OUT/digests.txt" | sed 's/^/  /'
  [ "$(grep -c ': the same$' "$OUT/digests.txt")" = 6 ] || no "not six digests the same"
}
one_directed() {
  local d=$1 tool
  tool=$(dirtool "$d")
  rm -f "$OUT/directed/$d.jsonl.gz" "$OUT/directed/$d.replay"
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
s_replays() {
  local t f n=0
  : > "$OUT/replays.txt"
  for t in $TRACES; do
    f=$OUT/$t.replay
    if [ ! -s "$f" ]; then echo "$t: no replay" >> "$OUT/replays.txt"; no "$t has no replay"; continue; fi
    echo "$t: $(grep '^replay: ' "$f" | head -n 1); $(grep "^reads of the Python's that the twin did not make: " "$f" | head -n 1)" >> "$OUT/replays.txt"
    has -E '^replay: [1-9][0-9]* records, [1-9][0-9]* ok, 0 mismatched$' "$f" || { no "$t: a record mismatched, or none read"; continue; }
    has -x "reads of the Python's that the twin did not make: 0" "$f" || { no "$t: a read of the Python's not made"; continue; }
    case $t in v2/*) bare_none "$OUT/$t.jsonl.gz" || { no "$t: its run counted bare calls ($t.jsonl.gz.bare.json)"; continue; } ;; esac
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
  [ "$(grep -c -E "/v2/hand5(-own)?\.jsonl\.gz: .*tracing v2's kept and covered, " "$OUT/headers.txt")" = 2 ] || no "the two small v2 traces must be of v2's kept and covered names"
  [ "$(grep -c -E "/v2/[a-z0-9-]+\.jsonl\.gz: .*tracing v2's kept and covered, " "$OUT/headers.txt")" = "$(grep -c -E '/v2/[a-z0-9-]+\.jsonl\.gz: ' "$OUT/headers.txt")" ] || no "a v2 trace is not of v2's kept and covered names"
  echo "  $(grep -c . "$OUT/headers.txt") headers read (headers.txt)"
  # the question writers' example rows (tools/forms-v2-examples.tsv, which the build step's replay --forms reads),
  # made again by the writers from this run's v2/hand5: so that the file cannot drift from the writers
  if [ -s "$OUT/v2/hand5.jsonl.gz" ]; then
    $PY "$T/forms_v2_examples.py" "$OUT/v2/hand5.jsonl.gz" > "$OUT/forms-v2-examples.tsv" 2> "$OUT/forms-v2-examples.err" \
      || no "the example rows were not made from v2/hand5 (forms-v2-examples.err)"
    [ "$(sha256sum < "$OUT/forms-v2-examples.tsv")" = "$(sha256sum < "$T/forms-v2-examples.tsv")" ] \
      || no "the example rows made from v2/hand5 differ from tools/forms-v2-examples.tsv (forms-v2-examples.tsv)"
    echo "  the example rows made again from v2/hand5: $(grep -c . "$OUT/forms-v2-examples.tsv"), as tools/forms-v2-examples.tsv"
  else
    no "no v2/hand5 to make the example rows from"
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
      "$OUT/directed/directed44.jsonl.gz" "$OUT/directed/directed42.jsonl.gz" "$OUT/v2/hand5.jsonl.gz" \
      $(for d in directed4b directed7 directed1 directed6o directed64 directed64h directed46 directed43 directed41 directed46d directed3v directed52 directed53 directed54 directed7p; do echo "$OUT/directed/$d.jsonl.gz"; done) \
      "$OUT/traces/hand5-publish.jsonl.gz" "$OUT/directed/directed71.jsonl.gz" "$OUT/directed/directed51.jsonl.gz" > "$OUT/c-altered.txt" 2>&1; rc=$?
  if [ "$rc" = 0 ] && ! has -E 'wrong$|<-- ' "$OUT/c-altered.txt" && [ "$(grep -c '^ok: every control of ' "$OUT/c-altered.txt")" -ge 1 ]; then
    echo "  control, altered records, headers and nodes lines: $(grep -c '^ok: every control of ' "$OUT/c-altered.txt") groups, each refused as it must be (c-altered.txt)"
  else no "control, altered records: rc=$rc (c-altered.txt)"; fi
  # 3. a trace cut short: no trailer, so no pass
  zcat "$OUT/traces/hand5.jsonl.gz" | head -n 50 | "$REPLAY" --content "$CONTENT" > "$OUT/c-cut.replay" 2>&1; rc=${PIPESTATUS[2]}
  if [ "$rc" = 1 ] && has -E '^trailer: ' "$OUT/c-cut.replay"; then echo "  control, a trace cut short: refused, as it must be: $(grep -m 1 '^trailer: ' "$OUT/c-cut.replay" | cut -c1-120)"
  else no "control, a trace cut short: rc=$rc, and no line about the trailer"; fi
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
    hand5-peer) echo "$HAND5 --doc v2 --promise-mode peer" ;;
    das-hoardcol-w16) echo "$DAS30 --fault hoardcol20 --rebuilt-seen on --repair-sample 3:1,6:2 --withhold 16" ;;
    das-samplers-mcoff) echo "$DAS30 --samplers 20 --member-check off" ;;  # das-samplers' delivery (its digest):
  esac                  #   its one record that reaches owed_missing, and defer_on_claim's swapped draw
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
      echo '1:defer_on_claim:kept:Node._hoard_column.<locals>.defer_on_claim,Node._v2.<locals>.defer_on_claim,doc' ;;
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
chain_cases() {         # the chain cases: the nodes line's chains on real cells, and five plants, each caught
  local cells plants c p why k all=0 good=0 caught=0 miss stop
  if [ -n "$NODAS" ]; then cells="hand5-peer"; plants="a b e"
  else cells="hand5-peer das-hoardcol-w16 das-samplers-mcoff"; plants="a b c d e"; fi
  mkdir -p "$OUT/chains"; : > "$OUT/c-chains.txt"
  # shellcheck disable=SC2046
  for c in $cells; do par small "$c" chains "" $(chain_args "$c"); done
  for p in $plants; do
    case $p in
      b) par chain_plant b chain-filter-observer-v2 hand5-peer ;;
      c) par chain_plant c chain-bindings-v2 das-hoardcol-w16 ;;
      d) par chain_plant d chain-owed-observer-v2 das-samplers-mcoff ;;
      e) par chain_plant e chain-owed-changing-v2 hand5-peer ;;
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
    elif has -x "nodes: chains: close_promises: its innermost layer is not the document's, and the node has not replaced it" "$OUT/chains/plant-a.replay"; then
      echo "(a) the cut chain: caught: $(cut -c13- "$OUT/chains/plant-a.err"); the replay refused it, with its words" >> "$OUT/c-chains.txt"; caught=$((caught + 1))
    else echo "(a) the cut chain: the replay refused it otherwise than by its words  <-- NOT" >> "$OUT/c-chains.txt"; fi
  else echo "(a) the cut chain: not made  <-- NOT" >> "$OUT/c-chains.txt"; fi
  # (b)-(e): each traced to its end, its cases failing on what the plant changed and on nothing else; (b) and (d), an
  # observer's class where the layer is not one, may instead be stopped by the observer's own check, which then says so
  for p in $plants; do
    case $p in a) continue ;; esac
    if ! has -E "^tracerfaults3: chain-[a-z-]*-v2, planted [1-9][0-9]* times?$" "$OUT/chains/plant-$p.err"; then
      echo "($p) not planted, or its line is not as written  <-- NOT" >> "$OUT/c-chains.txt"; continue
    fi
    if [ "$(cat "$OUT/chains/plant-$p.rc")" != 0 ]; then
      stop=$(grep -m 1 -E '^trace3: node [0-9]+: the observer ' "$OUT/chains/plant-$p.err")
      case $p in
        b|d) if [ -n "$stop" ]; then echo "($p) caught: the tracer stopped: $(echo "$stop" | cut -c1-160)" >> "$OUT/c-chains.txt"; caught=$((caught + 1))
             else echo "($p) the tracer stopped without an observer's words  <-- NOT" >> "$OUT/c-chains.txt"; fi ;;
        *) echo "($p) the tracer stopped  <-- NOT" >> "$OUT/c-chains.txt" ;;
      esac
      continue
    fi
    case $p in
      b) miss=$(plant_misses b hand5-peer); k=1
         want='^\*:filter_entry:replaced:[^ ]*: NOT: filter_entry is not in replaced at every node \([0-9]+\)$' ;;
      c) miss=$(plant_misses c das-hoardcol-w16); k=7     # each hoarder's chain: the lambda, before the layer; and
         #                                                   node 1's two observers in binding order, inner first
         want='^((7|8|11|16|23|24):push_rebuilt:replaced:[^ ]*: NOT: its chain is \[([^]]*, )?"Node\._v2\.<locals>\.<lambda>", ([^]]*, )?"Node\._hoard_column\.<locals>\.push_rebuilt", "doc"\], not \["Node\._hoard_column\.<locals>\.push_rebuilt", "doc"\]|1:defer_on_claim:kept:[^ ]*: NOT: its chain is \["Node\._v2\.<locals>\.defer_on_claim", "Node\._hoard_column\.<locals>\.defer_on_claim", "doc"\], not \["Node\._hoard_column\.<locals>\.defer_on_claim", "Node\._v2\.<locals>\.defer_on_claim", "doc"\])$' ;;
      d) miss=$(plant_misses d das-samplers-mcoff); k=1
         want='^\*:owed_missing:replaced:[^ ]*: NOT: owed_missing is not in replaced at every node \([0-9]+\)$' ;;
      e) miss=$(plant_misses e hand5-peer); k=1
         want='^\*:owed_missing:kept:[^ ]*: NOT: owed_missing is in replaced at every node \([0-9]+\)$' ;;
    esac
    if [ -z "$miss" ]; then echo "($p) its cases all hold  <-- NOT" >> "$OUT/c-chains.txt"
    elif [ "$(echo "$miss" | wc -l)" != "$k" ] || echo "$miss" | grep -v -q -E "$want"; then
      echo "($p) its cases fail otherwise than written: $(echo "$miss" | head -n 2 | cut -c1-200 | tr '\n' '|')  <-- NOT" >> "$OUT/c-chains.txt"
    else
      echo "($p) caught: $k case$([ "$k" = 1 ] || echo s) failing as written ($(echo "$miss" | head -n 1 | sed 's/: NOT: /: /' | cut -c1-140)); $(plant_line "$p")" >> "$OUT/c-chains.txt"
      caught=$((caught + 1))
    fi
  done
  local nplants
  nplants=$(echo $plants | wc -w)
  if grep -q '<-- NOT' "$OUT/c-chains.txt" || [ "$good" != "$all" ] || [ "$caught" != "$nplants" ]; then
    no "the chain cases (c-chains.txt)"
  fi
  local plants_said="$caught plants each caught"
  [ "$caught" = "$nplants" ] || plants_said="$caught of $nplants plants caught"
  if [ -n "$NODAS" ]; then
    echo "  the chain cases: $good of $all on hand5-peer, and $plants_said (--no-das: the DAS cells das-hoardcol-w16 and das-samplers-mcoff, and plants (c) and (d) on them, skipped)"
  else echo "  the chain cases: $good of $all on three cells, and $plants_said"; fi
}
swapped_draws() {       # K13: each swapped draw's draws on the tape of a cell that enters its layer, and two plants
  local hand nd why stop also n=0
  : > "$OUT/c-draws.txt"
  # keep_floor's: v2/hand5 (small's trace), the records that reach keep_floor
  $PY "$T/chaincases.py" --rows sample_without_replacement "$OUT/v2/hand5.jsonl.gz" keep_floor > "$OUT/c-draws-hand5.rows"
  hand=$(sed -n -E 's/.*reach keep_floor: ([0-9]+) rows.*/\1/p' "$OUT/c-draws-hand5.rows")
  if [ "${hand:-0}" -ge 1 ]; then echo "v2/hand5: $(cut -c13- "$OUT/c-draws-hand5.rows")" >> "$OUT/c-draws.txt"
  else echo "v2/hand5: no keep_floor draw on its tapes  <-- NOT" >> "$OUT/c-draws.txt"; fi
  # defer_on_claim@1707's: das-samplers-mcoff (the chain cases' trace), the records that reach defer_on_claim
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
  elif ! has -E "^tracerfaults3: draws-rewrap-off-v2, planted $hand times\$" "$OUT/c-draws-f.err"; then
    echo "(f) the re-wrap off: not planted once for each of hand5's $hand keep_floor draws  <-- NOT" >> "$OUT/c-draws.txt"
  elif replay_of c-draws-f; then
    echo "(f) the re-wrap off: the replay passed it  <-- NOT" >> "$OUT/c-draws.txt"
  elif ! has -E "^replay: [0-9]+ records, [0-9]+ ok, $hand mismatched\$" "$OUT/c-draws-f.replay"; then
    echo "(f) the re-wrap off: the replay mismatched otherwise than at hand5's $hand keep_floor records: $(grep -m 1 '^replay: ' "$OUT/c-draws-f.replay")  <-- NOT" >> "$OUT/c-draws.txt"
  elif ! has -F "tape: sample_without_replacement[[],0] asked, the tape is over logged" "$OUT/c-draws-f.replay"; then
    echo "(f) the re-wrap off: the replay refused it otherwise than by its words  <-- NOT" >> "$OUT/c-draws.txt"
  else
    echo "(f) the re-wrap off: caught: $(grep -m 1 '^replay: ' "$OUT/c-draws-f.replay"); $(grep -m 1 -F 'tape: sample_without_replacement[[],0] asked, the tape is over logged' "$OUT/c-draws-f.replay" | cut -c1-160)" >> "$OUT/c-draws.txt"
    n=$((n + 1))
  fi
  # (g) the swap left unrestored: the record's exit check must stop the tracer, final_check's words after the stop
  rm -f "$OUT/c-draws-g".*
  stop="^trace3: node 1: sample_without_replacement is bound to draws_unrestored_v2\.<locals>\..*<lambda> \(tracerfaults3\.py:[0-9]+\) at the exit of keep_floor's record, not to the tracer's own binding"
  also="^trace3: \(at the close, after the stop\) SystemExit: trace3: node 1: sample_without_replacement was bound again after the tracer was installed, which under v2 must be the namespace's last binding: draws_unrestored_v2\.<locals>\..*<lambda> \(tracerfaults3\.py:[0-9]+\)$"
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
    echo "  the swapped draws: ${hand:-0} keep_floor draws on v2/hand5, and $said (--no-das: das-samplers-mcoff's defer_on_claim draws skipped)"
  else echo "  the swapped draws: ${hand:-0} keep_floor draws on v2/hand5 and ${nd:-0} defer_on_claim draws on das-samplers-mcoff, and $said"; fi
}
s_tracercontrols() {
  local f want bad
  # the tracer's check of its own log: an assignment that goes unlogged must stop it
  if (cd "$TOY" && $PY "$T/unlogged3.py" . "$OUT/c-unlogged.jsonl.gz" --n 20000 --seed 1 > "$OUT/c-unlogged.out" 2> "$OUT/c-unlogged.err"); then
    no "the tracer wrote a trace to its end with every twentieth assignment unlogged"
  elif has -E '^unlogged3: ' "$OUT/c-unlogged.err" && has -E "^trace3: the views' log does not account" "$OUT/c-unlogged.err"; then
    echo "  control, an assignment unlogged: the tracer stopped, as it must"
  else no "the tracer stopped on an unlogged assignment for another reason (c-unlogged.err)"; fi
  # the tracer's own checks: each planted fault must stop it, with its own words
  : > "$OUT/c-tracerfaults.txt"; bad=0
  local also
  for f in made-rows-off alias alias-control installed-flip pending-twice alias-start alias-message defer-chain replaced false-wrapper stale-id level1-in-cell late-rebind stale-id-callee rebind-after-records limit-fraction early-install-v2 raw-alias-v2 other-node-v2 unscanned-layer-v2 raw-chunk-id-v2 hdr-other-v2 alias-missing-v2 other-node-tape-v2 rebound-scanned-v2 rebind-tape-v2 rebind-view-v2 stale-id-bare-v2 close-keyerror-v2 param-after-install-v2; do
    also=
    case $f in
      param-after-install-v2) want="^trace3: node [0-9]*: type payload's EAGER changed after the tracer's install \(True there, False now\): the nodes line holds a type's parameters as the install read them" ;;
      # a slot bound again after the install: the next record's entry check stops it (bindings_check), and
      # final_check's words follow at the close, both stops shown
      rebind-tape-v2) want="^trace3: node [0-9]*: peer_id_bytes is bound to Node\._namespace\.<locals>\.peer_id_bytes \(node\.py:[0-9]*\) at the entry of [a-z_0-9]*'s record, not to the tracer's own binding: a binding made after the install or during a call, which the twin would not run$"
        also="^trace3: \(at the close, after the stop\) SystemExit: trace3: node [0-9]*: peer_id_bytes was bound again after the tracer was installed, which under v2 must be the namespace's last binding" ;;
      rebind-view-v2) want="^trace3: node [0-9]*: offers is bound to OfferMap at the entry of [a-z_0-9]*'s record, not to the tracer's own binding: a binding made after the install or during a call, which the twin would not run$"
        also="^trace3: \(at the close, after the stop\) SystemExit: trace3: node [0-9]*: offers was bound again after the tracer was installed, which under v2 must be the namespace's last binding: a OfferMap$" ;;
      close-keyerror-v2) want="^trace3: node [0-9]*: N is called while node [0-9]*'s record is open and no question runs"
        also="^trace3: \(at the close, after the stop\) KeyError: 'planted at the close'$" ;;   # the close's, a note
      rebound-scanned-v2) want="^trace3: node [0-9]*: popcount_again is bound to a function of the toy's that the scan of its bindings does not name: popcount \(bits\.py:[0-9]*\)" ;;
      other-node-tape-v2) want="^trace3: node [0-9]*: peer_id_bytes is called while node [0-9]*'s record is open and no question runs" ;;
      raw-chunk-id-v2) want="^trace3: node [0-9]*: chunk_id is not the installed message_id" ;;
      hdr-other-v2) want="^trace3: node [0-9]*: hdr is not the toy's desc before the install" ;;
      alias-missing-v2) want="^trace3: node [0-9]*: chunk_id is missing under v2" ;;
      unscanned-layer-v2) want="^trace3: node [0-9]*: on_frame is bound to a function of the toy's that the scan of its bindings does not name: make\.<locals>\.on_frame \(node\.py:2\)" ;;
      early-install-v2) want="^trace3: node [0-9]*: the closure rule's lists and the node differ: ALL is not in the namespace" ;;
        # An install before _v2 is still refused, and refused first by what it lacks: the install-time check of the
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
      replaced) want="^trace3: node [0-9]*: may_ask is traced, and its function here is neither protocol.md's own code nor a listed wrapper of it: replaced\.<locals>" ;;
      false-wrapper) want="^trace3: node [0-9]*: may_ask is traced, and its function here is neither protocol.md's own code nor a listed wrapper of it: .*a listed wrapper's name, without the document's may_ask in its closure" ;;
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
  [ "$(grep -c 'the tracer stopped, as it must' "$OUT/c-tracerfaults.txt")" = 30 ] || no "not 30 planted faults stop the tracer as written (c-tracerfaults.txt)"
  echo "  $(grep -c 'the tracer stopped, as it must' "$OUT/c-tracerfaults.txt") of 30 planted faults stop the tracer with their own words"
  # under v2, the tracer-wide depth's plants, which must not stop it: a call at another node inside a question runs
  # bare and is counted, a replaced name entered outside any record makes no record inside and restores its state on
  # a raise; each plant's body is the plain v2 trace's (the run above), each control's another (a record inside)
  # each plant's count read from the .bare.json the tracer wrote; each plant's body the plain trace's; each control's
  # the plain one with exactly its extra records of N at the named node, its trailer counting them
  # A plant that replaces a function at a node has that function's chain in the node's entry of the nodes line, for
  # the chain tells the truth about the code there: chain names it, and extra_records judges the nodes line with each
  # entry's chains set aside, that node's chain of on_iwant the plant's, every other the plain trace's
  : > "$OUT/c-tracerplants.txt"; bad=0
  local plain line node k want why chain spec also_chain
  for f in bare-in-question-v2 bare-in-question-v2-per-node suppressed-entry-v2 suppressed-entry-v2-off bare-replaced-v2 bare-timer-v2 bare-timer-v2-now hdr-read-v2 hdr-read-v2-raw; do
    chain=
    case $f in      # the plant's own function at the planted node, its chain of on_iwant
      suppressed-entry-v2|suppressed-entry-v2-off) chain='["suppressed_entry_v2.<locals>.install.<locals>.on_iwant"]' ;;
      bare-replaced-v2) chain='["bare_in_question_v2.<locals>.install.<locals>.on_iwant"]' ;;
    esac
    case $f in     # k: the control's extra records of N; - for a plant read by its line alone (its read adds to a record)
      bare-in-question-v2) plain=v2/hand5; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; bare c N: 1$" ;;
      bare-in-question-v2-per-node) plain=v2/hand5; k=1; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; records inside: 1; bare c N: 0$" ;;
      suppressed-entry-v2) plain=v2/hand5-own; k=0; line=", planted 2 times; node s: [0-9]+; entry 1: returned; supp after the return: 0; bare s N: 2; entry 2: raised; supp after the raise: 0$" ;;
      suppressed-entry-v2-off) plain=v2/hand5-own; k=2; line=", planted 2 times; records inside: 2; node s: [0-9]+; entry 1: returned; supp after the return: 0; bare s N: 0; entry 2: raised; supp after the raise: 0$" ;;
      bare-replaced-v2) plain=v2/hand5-own; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; the replaced body ran: 1; bare c on_iwant: 1$" ;;
      bare-timer-v2) plain=v2/hand5; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; the timer scheduled at node c: 1; fired from the simulator, outside the question: 1$" ;;
      bare-timer-v2-now) plain=v2/hand5; k=0; line=", planted 1 time; node a, node c: [0-9]+, [0-9]+; the timer scheduled at node c: 0; fired from the simulator, outside the question: 0$" ;;
      hdr-read-v2) plain=v2/hand5; k=-; line=", planted 1 time; node a: [0-9]+; desc read in its record: 1$" ;;
      hdr-read-v2-raw) plain=v2/hand5; k=0; line=", planted 1 time; node a: [0-9]+; desc read in its record: 0$" ;;
    esac
    rm -f "$OUT/c-tp-$f.jsonl.gz" "$OUT/c-tp-$f.jsonl.gz.bare.json"    # nothing left from an earlier run counts
    if ! (cd "$TOY" && $PY "$T/tracerfaults3.py" "--$f" . "$OUT/c-tp-$f.jsonl.gz" > "$OUT/c-tp-$f.out" 2> "$OUT/c-tp-$f.err"); then
      echo "$f: the run did not end with 0  <-- it must" >> "$OUT/c-tracerplants.txt"; bad=1; continue
    fi
    if ! has -E "^tracerfaults3: $f$line" "$OUT/c-tp-$f.err"; then
      echo "$f: its line is not as written  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; continue
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
  # the check that no v2 trace counts a bare call (s_replays) itself fails on a planted count
  if bare_none "$OUT/c-tp-bare-in-question-v2.jsonl.gz"; then
    echo "control: the check of no bare call passes the plant's count  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
  else echo "control: the check of no bare call fails on the plant's count, as it must" >> "$OUT/c-tracerplants.txt"; fi
  # extra_records' own controls, on traces made from the plain v2/hand5: itself with k 0 passes; two record lines
  # swapped, the trailer's rest changed, another function's count changed: each refused, for its own reason (a
  # fixture not made, or not whole, fails the control)
  rm -f "$OUT/c-er-swapped.jsonl.gz" "$OUT/c-er-rest.jsonl.gz" "$OUT/c-er-other.jsonl.gz"
  if ! $PY - "$OUT/v2/hand5.jsonl.gz" "$OUT/c-er" <<'EOF_ER'
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
  if extra_records "$OUT/v2/hand5.jsonl.gz" "$OUT/v2/hand5.jsonl.gz" 1 N 0 > /dev/null; then
    echo "control: extra_records passes a trace against itself, as it must" >> "$OUT/c-tracerplants.txt"
  else echo "control: extra_records refuses a trace against itself  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  for c in swapped rest other; do
    case $c in swapped) want="is neither the first trace's next line" ;; *) want="the trailer is not the first's" ;; esac
    if ! gzip -t "$OUT/c-er-$c.jsonl.gz" 2> /dev/null; then
      echo "control: the planted $c is not a whole trace  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
    elif why=$(extra_records "$OUT/v2/hand5.jsonl.gz" "$OUT/c-er-$c.jsonl.gz" 1 N 0 2> /dev/null); then
      echo "control: extra_records passes the planted $c  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
    elif [[ $why == *"$want"* ]]; then
      echo "control: extra_records refuses the planted $c, as it must: $why" >> "$OUT/c-tracerplants.txt"
    else echo "control: extra_records refuses the planted $c for another reason: $why  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  done
  # extra_records' chain spec, on traces made from the plain v2/hand5-own, the spec its replaced node's on_iwant with
  # its own chain: itself passes; a record line changed; the nodes line changed outside the chains (the replaced
  # node's replaced emptied, the first entry's IWANT_WINDOW and its payload type's M each plus 1); another entry's
  # chains given a name more; the replaced node's chain of on_iwant changed: each refused, for its own reason.
  # Setting the chains aside removes that one member of each entry and nothing else
  rm -f "$OUT"/c-erc-*.jsonl.gz "$OUT/c-erc.spec"
  if ! $PY - "$OUT/v2/hand5-own.jsonl.gz" "$OUT/c-erc" <<'EOF_ERC'
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
  if [ -n "$cnode" ] && extra_records "$OUT/v2/hand5-own.jsonl.gz" "$OUT/v2/hand5-own.jsonl.gz" "$cnode" N 0 "$cnode" on_iwant "$cchain" > /dev/null; then
    echo "control: extra_records with node $cnode's chain of on_iwant passes v2/hand5-own against itself, as it must" >> "$OUT/c-tracerplants.txt"
  else echo "control: extra_records with node ${cnode:-?}'s chain of on_iwant refuses v2/hand5-own against itself  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  # the spec of a node in no entry (the largest plus 1000), the trace against itself: refused, for that reason
  if [ -z "$cabsent" ]; then
    echo "control: no node in no entry for the chain spec  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
  elif why=$(extra_records "$OUT/v2/hand5-own.jsonl.gz" "$OUT/v2/hand5-own.jsonl.gz" "$cnode" N 0 "$cabsent" on_iwant "$cchain" 2> /dev/null); then
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
    elif why=$(extra_records "$OUT/v2/hand5-own.jsonl.gz" "$OUT/c-erc-$c.jsonl.gz" "$cnode" N 0 "$cnode" on_iwant "$cchain" 2> /dev/null); then
      echo "control: extra_records passes the chain fixture $c  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1
    elif [[ $why == *"$want"* ]]; then
      echo "control: extra_records refuses the chain fixture $c, as it must: $why" >> "$OUT/c-tracerplants.txt"
    else echo "control: extra_records refuses the chain fixture $c for another reason: $why  <-- NOT" >> "$OUT/c-tracerplants.txt"; bad=1; fi
  done
  [ "$bad" = 0 ] || no "a plant under v2 (c-tracerplants.txt)"
  [ "$(grep -c '^[a-z0-9-]*: as it must: ' "$OUT/c-tracerplants.txt")" = 9 ] || no "not 9 plants under v2 as written (c-tracerplants.txt)"
  echo "  $(grep -c '^[a-z0-9-]*: as it must: ' "$OUT/c-tracerplants.txt") of 9 plants under v2 as written (five, and four controls), and the checks' controls"
  # under v2, the nodes line's chains: hand5-own traced with its replaced names' chains left out (tracerfaults3's
  # --chains-omit-v2) is written to the end, and the replay's reader must refuse it, with its own words, naming the
  # first it meets: push_rebuilt, which hand5-own (--rebuilt none) replaces at every node
  rm -f "$OUT/c-chains-omit.jsonl.gz" "$OUT/c-chains-omit.jsonl.gz.bare.json" "$OUT/c-chains-omit.replay"
  if ! (cd "$TOY" && $PY "$T/tracerfaults3.py" --chains-omit-v2 . "$OUT/c-chains-omit.jsonl.gz" > "$OUT/c-chains-omit.out" 2> "$OUT/c-chains-omit.err"); then
    no "the trace of a nodes line without a replaced name's chain did not end with 0 (c-chains-omit.err)"
  elif ! has -E '^tracerfaults3: chains-omit-v2, planted [1-9][0-9]* times?$' "$OUT/c-chains-omit.err"; then
    no "no replaced name's chain was left out (c-chains-omit.err)"
  elif replay_of c-chains-omit; then
    no "the replay passed a nodes line without a replaced name's chain (c-chains-omit.replay)"
  elif has -x "nodes: chains: a replaced name with no chain: push_rebuilt" "$OUT/c-chains-omit.replay"; then
    echo "  a nodes line without its replaced names' chains: refused by the replay, with its words (push_rebuilt)"
  else no "the replay refused a nodes line without a replaced name's chain otherwise than by its words (c-chains-omit.replay)"; fi
  # the chain cases: the nodes line's chains on three cells against written cases, and five plants, each caught:
  # (a) hand5-peer's trace with close_promises' chain cut to its bound layer, which the replay must refuse with its
  # words; (b) filter_entry's peer layer classed as an observer and (e) owed_missing's member-check layer as changing,
  # on hand5-peer; (c) the chains taken from the slots' bindings, on das-hoardcol-w16 (a hoarder's chain then holds
  # --fault hoard's lambda, and an honest node's two observers come inner first); (d) owed_missing's layer as an
  # observer, on das-samplers-mcoff (--member-check off). Each of (b)-(e) must make its cell's cases fail on what it
  # changed and on nothing else (c-chains.txt)
  chain_cases
  # the swapped draws (K13): keep_floor's on v2/hand5 and defer_on_claim's on das-samplers-mcoff, each on its records'
  # tapes; (f) the re-wrap off, which the replay must refuse at each keep_floor record; (g) the swap left unrestored,
  # which the record's exit check must stop (c-draws.txt)
  swapped_draws
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
    echo "documents protocol.md $(sha256sum < "$TOY/../protocol.md" | cut -c1-64) protocol-v2.md $(sha256sum < "$TOY/../protocol-v2.md" | cut -c1-64) (each file's sha256: reported, it decides nothing)"
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
  elif [ -n "$V2STEPS" ]; then echo "check.sh: PASS (with v2cells, schemacontrols, viewcontrols and tracercontrols)"
  else echo "check.sh: PASS"; fi
} 2>&1 | tee "$LOG"
case "$(tail -n 1 "$LOG")" in "check.sh: PASS"|"check.sh: PASS (the record's run)"|"check.sh: PASS (part "*|"check.sh: PASS (with v2cells, schemacontrols, viewcontrols and tracercontrols)") true ;; *) false ;; esac \
  || { { [ "$STEPS" != "$ALL" ] || [ -n "$REHEARSAL" ] || [ -n "$SAMPLE" ] || [ -n "$FEWCELLS" ] || [ -n "$NODAS" ]; } && tail -n 1 "$LOG" | grep -q '^check.sh: these steps passed'; }
