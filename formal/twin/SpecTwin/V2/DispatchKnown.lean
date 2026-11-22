import SpecTwin.Header
import SpecTwin.V2.ReplayKnown

/-! # The dispatch by document: its known answer

The readers of `Header.lean` and the route of `V2/Replay.lean`, case by case, written before them. A reader passes
where it gives `.ok`, with the value named, and fails where its error starts with the quoted words. The header's
cases are of `readHeader`, whose failures are the lines the replay prints. The nodes line's are of `nodesLineV2`
under protocol-v2.md and of `nodesLine` under protocol.md. -/

namespace SpecTwin.V2.DispatchKnown

open Lean (Json)
open SpecTwin SpecTwin.Replay SpecTwin.Header

def passes {α} (x : Except String α) : Bool := x matches .ok _

def failsWith {α} (pre : String) (x : Except String α) : Bool :=
  match x with
  | .error e => e.startsWith pre
  | .ok _ => false

def strs (l : List String) : Json := Json.arr (l.map Json.str).toArray

def jn (k : Nat) : Json := Lean.toJson k

def formIs (x : Except String Form) (f : Form) : Bool :=
  match x with
  | .ok g => g == f
  | .error _ => false

/-! ## The header -/

def args (l : List String) : List (String × Json) := [("args", strs l)]

/-- The traced names of today's v2 traces: the manifest's kept names and `held`, sorted (43). -/
def traced43 : List String := sortBy (· < ·) (Manifest.kept ++ ["held"])

/-- A header of format 7 with these tables, traced names and arguments, and members besides. -/
def header (own foreign traced : List String) (more : List (String × Json)) : Json :=
  Json.mkObj ([("format", jn 7), ("whole", Json.bool false), ("own", strs own), ("foreign", strs foreign),
               ("traced", strs traced), ("tracer", Json.str "trace3.py")] ++ more)

def hdV2 (traced : List String := traced43) (more : List (String × Json) := []) : Json :=
  header Manifest.own Manifest.foreign traced (args ["--doc", "v2"] ++ more)
def hdV1 (more : List (String × Json) := []) : Json := header ownTables ["known_id", "chunks"] traced43 more

def fails (hd : Json) (only? : Option String := none) : List String := (readHeader hd only?).failures

-- B1, the document
#guard formIs (headerForm (Json.mkObj [])) .v1
#guard formIs (headerForm (Json.mkObj (args ["--seed", "3"]))) .v1
#guard formIs (headerForm (Json.mkObj (args ["--doc", "v03"]))) .v1
#guard formIs (headerForm (Json.mkObj (args ["--doc=v2"]))) .v2
#guard formIs (headerForm (Json.mkObj (args ["--doc", "v2"]))) .v2
#guard failsWith "header: a document this replay does not read: v3" (headerForm (Json.mkObj (args ["--doc", "v3"])))
#guard failsWith "header: args is not a list of strings: null" (headerForm (Json.mkObj [("args", Json.null)]))
#guard failsWith "header: args is not a list of strings: [42]" (headerForm (Json.mkObj [("args", Json.arr #[jn 42])]))
#guard (readHeader (hdV2 traced43 [("args", strs ["--doc", "v3"])]) none).failures.head?
  == some "header: a document this replay does not read: v3"

-- B2, the tables
#guard fails (hdV2) == []
#guard (readHeader hdV2 none).form == .v2
#guard fails (hdV1) == []
#guard (readHeader hdV1 none).form == .v1
#guard fails (header ownTables ["known_id", "chunks"] traced43 (args ["--doc", "v2"]))
  == ["header: the tables are not this twin's (own, foreign)"]
#guard fails (header Manifest.own Manifest.foreign traced43 [])
  == ["header: the tables are not this twin's (own, foreign)"]
#guard Manifest.own.length == 72 && Manifest.own.take 36 == ownTables

-- B3, traced under v2
#guard fails (hdV2 (sortBy (· < ·) ("announce" :: traced43))) == []
#guard fails (hdV2 (sortBy (· < ·) ("on_frame" :: traced43)))
  == ["header: traced names that protocol-v2.md's manifest does not list: on_frame"]
#guard fails (hdV2 (sortBy (· < ·) ("window_release" :: traced43)))
  == ["header: traced holds window_release, which is cut at every node"]
#guard fails (hdV1 [("traced", strs (sortBy (· < ·) ("on_frame" :: traced43)))]) == []   -- not protocol.md's check

-- B4, --only under v2
#guard fails hdV2 (some "fn=respond") == []
#guard fails hdV2 (some "fn=announce")
  == ["subset: --only fn=announce: not a function the header lists as traced, nor a table of the twin's own"]
#guard fails hdV2 (some "table=probe") == []
#guard fails hdV1 (some "table=probe")
  == ["subset: --only table=probe: not a function the header lists as traced, nor a table of the twin's own"]
#guard fails hdV1 (some "table=offers") == []

-- B5, row_reads with the document of B1
#guard (readHeader (hdV2 traced43 [("row_reads", strs rowTables)]) none).rowReads == rowTables
#guard fails (hdV1 [("row_reads", strs rowTables)]) == ["header: row_reads in a trace of protocol.md"]

/-! ## The nodes line -/

def word0 : Json := jn 0

/-- `protocol.md`'s 31 constants, each of its kind: floats as the word of 0.0, limits `null`, naturals 1, booleans
false, `SOURCE_OFFERS` `"ACK"`. -/
def consts31 : List (String × Json) :=
  constNames.map fun k =>
    if ["IWANT_WINDOW", "RETRY_SLACK", "PROMISE", "PARK_TTL", "HEARTBEAT", "GOSSIP_FACTOR", "GUARD_GRACE", "UPLINK",
        "STRIPE_UPLINK", "WINDOW_TIMEOUT"].contains k then (k, word0)
    else if ["MAX_IHAVE_MESSAGES", "MAX_IHAVE_LENGTH", "MAX_PENDING_GROUPS", "W"].contains k then (k, Json.null)
    else if ["CANCEL", "PROJECT", "RAREST", "PACED", "DESCRIPTOR_IN_CHUNK"].contains k then (k, Json.bool false)
    else if k == "SOURCE_OFFERS" then (k, Json.str "ACK")
    else (k, jn 1)

def v2Three : List (String × Json) := [("ANSWERS_FIRST", Json.bool false), ("ASK_UPLINK", word0), ("MERGE_HOLDINGS", Json.bool false)]

/-- The 34 with these members put in their place (a member given as `none` left out). -/
def consts34 (change : List (String × Option Json) := []) : Json :=
  Json.mkObj ((consts31 ++ v2Three).filterMap fun (k, v) =>
    match change.lookup k with
    | some (some w) => some (k, w)
    | some none => none
    | none => some (k, v))

def payload : Json := Json.mkObj [("payload", Json.mkObj [])]

/-- C1's entry, with these members put in its place (a member given as `none` left out). -/
def entry (change : List (String × Option Json) := []) : Json :=
  let base : List (String × Json) :=
    [("n", Json.arr #[jn 0, jn 1]), ("consts", consts34), ("replaced", strs []), ("types", payload),
     ("chains", Json.mkObj [])]
  Json.mkObj (base.filterMap fun (k, v) =>
    match change.lookup k with
    | some (some w) => some (k, w)
    | some none => none
    | none => some (k, v))

def line2 (e : Json) (whole : Bool := false) (traced : List String := traced43) :
    Except String (List (Nat × NodeV2Cfg)) :=
  nodesLineV2 (Json.arr #[e]) whole traced

def chains (l : List (String × List String)) : Json := Json.mkObj (l.map fun (k, v) => (k, strs v))

-- C1, an entry that passes: two nodes, the payload's parameters found by its id, none for a type not named
#guard passes (line2 (entry))
#guard (match line2 (entry) with
  | .ok l => l.map (·.1) == [1, 0] && l.all fun (_, cfg) =>
      (cfg.types.lookup "payload").isSome && (cfg.types.lookup "row").isNone && cfg.replaced == []
  | .error _ => false)

-- C2, the constants under v2
#guard failsWith "nodes: consts: no ANSWERS_FIRST" (line2 (entry [("consts", some (consts34 [("ANSWERS_FIRST", none)]))]))
#guard failsWith "nodes: consts: ASK_UPLINK is a finite float, not negative: "            -- −1.0
  (line2 (entry [("consts", some (consts34 [("ASK_UPLINK", some (jn 13830554455654793216))]))]))
#guard failsWith "nodes: consts: ASK_UPLINK is a finite float, not negative: "            -- +∞
  (line2 (entry [("consts", some (consts34 [("ASK_UPLINK", some (jn 9218868437227405312))]))]))
#guard failsWith "nodes: consts: ANSWERS_FIRST is true or false: "
  (line2 (entry [("consts", some (consts34 [("ANSWERS_FIRST", some (jn 1))]))]))
#guard (match line2 (entry [("consts", some (consts34 [("ASK_UPLINK", some (jn 4607182418800017408)),
                                                        ("MERGE_HOLDINGS", some (Json.bool true))]))]) with   -- 1.0
  | .ok ((_, cfg) :: _) => cfg.c2.ASK_UPLINK == 1.0 && cfg.c2.MERGE_HOLDINGS && !cfg.c2.ANSWERS_FIRST
  | _ => false)
#guard failsWith "nodes: consts: not a member of it: ANSWERS_FIRST"                       -- under protocol.md
  (nodesLine (Json.arr #[Json.mkObj [("n", Json.arr #[jn 0]), ("consts", consts34), ("replaced", strs [])]]))
#guard passes
  (nodesLine (Json.arr #[Json.mkObj [("n", Json.arr #[jn 0]), ("consts", Json.mkObj consts31), ("replaced", strs [])]]))

-- C3, the members
#guard failsWith "nodes: no types" (line2 (entry [("types", none)]))
#guard failsWith "nodes: no chains" (line2 (entry [("chains", none)]))
#guard failsWith "nodes: not a member of it: chains"                                      -- under protocol.md
  (nodesLine (Json.arr #[Json.mkObj [("n", Json.arr #[jn 0]), ("consts", Json.mkObj consts31),
                                     ("replaced", strs []), ("chains", Json.mkObj [])]]))

-- C4, chains' form
#guard failsWith "nodes: chains: not a map of names: " (line2 (entry [("chains", some (strs ["doc"]))]))
#guard failsWith "nodes: chains: close_promises: not a non-empty list of names: "
  (line2 (entry [("chains", some (Json.mkObj [("close_promises", Json.arr #[])]))]))
#guard failsWith "nodes: chains: close_promises: not a non-empty list of names: "
  (line2 (entry [("chains", some (Json.mkObj [("close_promises", Json.arr #[Json.str "doc", jn 3])]))]))

-- C5, chains' three checks
#guard failsWith "nodes: chains: a name the header does not list as traced: announce"
  (line2 (entry [("chains", some (chains [("announce", ["doc"])]))]))
#guard failsWith "nodes: chains: a replaced name with no chain: on_iwant"
  (line2 (entry [("replaced", some (strs ["on_iwant"]))]))
#guard failsWith "nodes: chains: close_promises: its innermost layer is not the document's, and the node has not replaced it"
  (line2 (entry [("chains", some (chains [("close_promises", ["Node._peer_promise.<locals>.close_promises", "Node.x"])]))]))
#guard passes (line2 (entry [("replaced", some (strs ["on_iwant"])),
                             ("chains", some (chains [("on_iwant", ["Node._silent.<locals>.on_iwant"])]))]))
#guard passes (line2 (entry [("chains", some (chains [("close_promises", ["Node._peer_promise.<locals>.close_promises",
                                                         "Node._override.<locals>.close_promises", "doc"])]))]))
#guard passes (line2 (entry [("replaced", some (strs ["filter_entry"])),
                             ("chains", some (chains [("filter_entry", ["Node._peer_promise.<locals>.filter_entry", "doc"])]))])
  false (sortBy (· < ·) ("filter_entry" :: traced43)))

-- C6, the replaced names under v2
#guard failsWith "nodes: a replaced function the twin has no question for: outstanding"
  (line2 (entry [("replaced", some (strs ["outstanding"]))]))
#guard failsWith "nodes: node 0 has replaced window_release, which is cut at every node"
  (line2 (entry [("replaced", some (strs ["window_release"]))]))
#guard failsWith "nodes: node 0 has replaced [publish], which the header does not list as traced"
  (line2 (entry [("replaced", some (strs ["publish"]))]))
#guard failsWith "nodes: node 0 has replaced [validate_chunk], which only a trace of the whole state may"
  (line2 (entry [("replaced", some (strs ["validate_chunk"]))]))
#guard passes (line2 (entry [("replaced", some (strs ["validate_chunk"])),
                             ("chains", some (chains [("validate_chunk", ["Node._directed.<locals>.validate_chunk"])]))]) true)

-- C7, types
#guard failsWith "nodes: types: no payload type: " (line2 (entry [("types", some (Json.mkObj []))]))
#guard failsWith "nodes: types: payload: M: "
  (line2 (entry [("types", some (Json.mkObj [("payload", Json.mkObj [("M", jn 0)])]))]))

/-! ## The dispatch -/

-- D1, the route
#guard routeV2 "announce" == .v2
#guard ["on_pace_tick", "on_block_installed", "respond"].all (routeV2 · == .form)
#guard ["with_owed", "build_group", "outstanding", "held"].all (routeV2 · == .kept)
#guard ["on_frame", "on_heartbeat", "next_to_send", "wake_front", "track_in_flight", "window_release", "window_timeout",
        "no_such_function"].all (routeV2 · == .refused)
#guard Manifest.kept.all fun f => routeV2 f == .kept || routeV2 f == .form
#guard Manifest.nodeOwn.all fun (f, _) => routeV2 f == .kept
#guard Manifest.covered.all fun f => routeV2 f == .v2 || routeV2 f == .form
#guard fnsV2.length == 68

-- D2, runV2 by the route: a kept name `keptV2` did not hold before (`valid_id`, of an entry not 56 bytes long) goes
-- to `Replay.run`; a name v2 redefines is refused
#guard ReplayKnown.passes
  (ReplayKnown.line "valid_id" "[\"abcd\"]" "[]" "[]" "[]" "[]" (ReplayKnown.ret "false") "[\"valid_id\"]" "[]")
#guard ReplayKnown.failsWith "return value: "
  (ReplayKnown.line "valid_id" "[\"abcd\"]" "[]" "[]" "[]" "[]" (ReplayKnown.ret "true") "[\"valid_id\"]" "[]")
#guard ReplayKnown.failsWith "not a function of the twin under protocol-v2.md: on_frame"
  (ReplayKnown.line "on_frame" "[1, []]" "[]" "[]" "[]" "[]" (ReplayKnown.ret "null") "[\"on_frame\"]" "[]")

-- D4, a subset's pick by the tape reads the list of the trace's document
def tapeLine : String := "{\"tape\": [[\"send_have\", \"[1]\", \"null\"], [\"forward\", \"[]\", \"null\"]]}"
#guard asks .v2 tapeLine "send_have"
#guard !asks .v1 tapeLine "send_have"
#guard asks .v1 tapeLine "forward" && asks .v2 tapeLine "forward"
#guard !asks .v2 "{\"tape\": [[\"window_release\", \"[]\", \"null\"]]}" "window_release"

end SpecTwin.V2.DispatchKnown
