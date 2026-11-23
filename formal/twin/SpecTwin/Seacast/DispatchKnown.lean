import SpecTwin.Header
import SpecTwin.Seacast.ReplayKnown

/-! # The dispatch by document: its known answer

The readers of `Header.lean` and the route of `Seacast/Replay.lean`, case by case, written before them. A reader passes
where it gives `.ok`, with the value named, and fails where its error starts with the quoted words. The header's
cases are of `readHeader`, whose failures are the lines the replay prints. The nodes line's are of `nodesLineSeacast`
under seacast.md and of `nodesLine` under seacast-lite.md. -/

namespace SpecTwin.Seacast.DispatchKnown

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

def hdSeacast (traced : List String := traced43) (more : List (String × Json) := []) : Json :=
  header Manifest.own Manifest.foreign traced (args ["--doc", "seacast"] ++ more)
def hdLite (more : List (String × Json) := []) : Json := header ownTables ["known_id", "chunks"] traced43 more

def fails (hd : Json) (only? : Option String := none) : List String := (readHeader hd only?).failures

-- B1, the document
#guard formIs (headerForm (Json.mkObj [])) .lite
#guard formIs (headerForm (Json.mkObj (args ["--seed", "3"]))) .lite
#guard formIs (headerForm (Json.mkObj (args ["--doc", "lite"]))) .lite
#guard formIs (headerForm (Json.mkObj (args ["--doc=seacast"]))) .seacast
#guard formIs (headerForm (Json.mkObj (args ["--doc", "seacast"]))) .seacast
#guard failsWith "header: a document this replay does not read: v3" (headerForm (Json.mkObj (args ["--doc", "v3"])))
#guard failsWith "header: args is not a list of strings: null" (headerForm (Json.mkObj [("args", Json.null)]))
#guard failsWith "header: args is not a list of strings: [42]" (headerForm (Json.mkObj [("args", Json.arr #[jn 42])]))
-- the values of --doc before v0.12.0, as the headers of traces written then hold them: the same documents
#guard formIs (headerForm (Json.mkObj (args ["--doc", "v2"]))) .seacast
#guard formIs (headerForm (Json.mkObj (args ["--doc=v2"]))) .seacast
#guard formIs (headerForm (Json.mkObj (args ["--doc", "v03"]))) .lite
#guard formIs (headerForm (Json.mkObj (args ["--doc=v03"]))) .lite
-- the document word of each header argument list, old values and new, the first --doc of a doubled one; trace3.py's
-- doc_of reads the same table the same way (OLD_DOCS)
#guard docOf [] == none
#guard docOf ["--doc", "v03"] == some "lite" && docOf ["--doc", "lite"] == some "lite"
#guard docOf ["--doc", "v2"] == some "seacast" && docOf ["--doc", "seacast"] == some "seacast"
#guard docOf ["--doc=v2"] == some "seacast" && docOf ["--doc=v03"] == some "lite"
#guard docOf ["--doc", "v3"] == some "v3"
#guard docOf ["--doc", "v2", "--doc", "v03"] == some "seacast" && docOf ["--doc", "seacast", "--doc", "lite"] == some "seacast"
#guard docOf ["--doc", "v03", "--doc", "v2"] == some "lite"
#guard (readHeader (hdSeacast traced43 [("args", strs ["--doc", "v3"])]) none).failures.head?
  == some "header: a document this replay does not read: v3"

-- B2, the tables
#guard fails (hdSeacast) == []
#guard (readHeader hdSeacast none).form == .seacast
#guard fails (hdLite) == []
#guard (readHeader hdLite none).form == .lite
#guard fails (header ownTables ["known_id", "chunks"] traced43 (args ["--doc", "seacast"]))
  == ["header: the tables are not this twin's (own, foreign)"]
#guard fails (header Manifest.own Manifest.foreign traced43 [])
  == ["header: the tables are not this twin's (own, foreign)"]
#guard Manifest.own.length == 75 && Manifest.own.take 36 == ownTables      -- SEACAST's 39 since v0.11.1's three

-- B3, traced under v2
#guard fails (hdSeacast (sortBy (· < ·) ("announce" :: traced43))) == []
#guard fails (hdSeacast (sortBy (· < ·) ("on_frame" :: traced43)))
  == ["header: traced names that seacast.md's manifest does not list: on_frame"]
#guard fails (hdSeacast (sortBy (· < ·) ("window_release" :: traced43)))
  == ["header: traced holds window_release, which is cut at every node"]
#guard fails (hdLite [("traced", strs (sortBy (· < ·) ("on_frame" :: traced43)))]) == []   -- not seacast-lite.md's check

-- B4, --only under v2
#guard fails hdSeacast (some "fn=respond") == []
#guard fails hdSeacast (some "fn=announce")
  == ["subset: --only fn=announce: not a function the header lists as traced, nor a table of the twin's own"]
#guard fails hdSeacast (some "table=probe") == []
#guard fails hdLite (some "table=probe")
  == ["subset: --only table=probe: not a function the header lists as traced, nor a table of the twin's own"]
#guard fails hdLite (some "table=offers") == []

-- B5, row_reads with the document of B1
#guard (readHeader (hdSeacast traced43 [("row_reads", strs rowTables)]) none).rowReads == rowTables
#guard fails (hdLite [("row_reads", strs rowTables)]) == ["header: row_reads in a trace of seacast-lite.md"]

/-! ## The nodes line -/

def word0 : Json := jn 0

/-- `seacast-lite.md`'s 31 constants, each of its kind: floats as the word of 0.0, limits `null`, naturals 1, booleans
false, `SOURCE_OFFERS` `"ACK"`. -/
def consts31 : List (String × Json) :=
  constNames.map fun k =>
    if ["IWANT_WINDOW", "RETRY_SLACK", "PROMISE", "PARK_TTL", "HEARTBEAT", "GOSSIP_FACTOR", "GUARD_GRACE", "UPLINK",
        "STRIPE_UPLINK", "WINDOW_TIMEOUT"].contains k then (k, word0)
    else if ["MAX_IHAVE_MESSAGES", "MAX_IHAVE_LENGTH", "MAX_PENDING_GROUPS", "W"].contains k then (k, Json.null)
    else if ["CANCEL", "PROJECT", "RAREST", "PACED", "DESCRIPTOR_IN_CHUNK"].contains k then (k, Json.bool false)
    else if k == "SOURCE_OFFERS" then (k, Json.str "ACK")
    else (k, jn 1)

/-- SEACAST's five: `SAMPLE_OUTSTANDING` 4, as the toy's, and `SERVE_BUDGET` null, no limit. -/
def seacastFive : List (String × Json) :=
  [("ANSWERS_FIRST", Json.bool false), ("ASK_UPLINK", word0), ("MERGE_HOLDINGS", Json.bool false),
   ("SAMPLE_OUTSTANDING", jn 4), ("SERVE_BUDGET", Json.null)]

/-- The 36 with these members put in their place (a member given as `none` left out). -/
def consts36 (change : List (String × Option Json) := []) : Json :=
  Json.mkObj ((consts31 ++ seacastFive).filterMap fun (k, v) =>
    match change.lookup k with
    | some (some w) => some (k, w)
    | some none => none
    | none => some (k, v))

def payload : Json := Json.mkObj [("payload", Json.mkObj [])]

/-- C1's entry, with these members put in its place (a member given as `none` left out). -/
def entry (change : List (String × Option Json) := []) : Json :=
  let base : List (String × Json) :=
    [("n", Json.arr #[jn 0, jn 1]), ("consts", consts36), ("replaced", strs []), ("types", payload),
     ("chains", Json.mkObj [])]
  Json.mkObj (base.filterMap fun (k, v) =>
    match change.lookup k with
    | some (some w) => some (k, w)
    | some none => none
    | none => some (k, v))

def line2 (e : Json) (whole : Bool := false) (traced : List String := traced43) :
    Except String (List (Nat × NodeSeacastCfg)) :=
  nodesLineSeacast (Json.arr #[e]) whole traced

def chains (l : List (String × List String)) : Json := Json.mkObj (l.map fun (k, v) => (k, strs v))

-- C1, an entry that passes: two nodes, the payload's parameters found by its id, none for a type not named
#guard passes (line2 (entry))
#guard (match line2 (entry) with
  | .ok l => l.map (·.1) == [1, 0] && l.all fun (_, cfg) =>
      (cfg.types.lookup "payload").isSome && (cfg.types.lookup "row").isNone && cfg.replaced == []
  | .error _ => false)

-- C2, the constants under v2
#guard failsWith "nodes: consts: no ANSWERS_FIRST" (line2 (entry [("consts", some (consts36 [("ANSWERS_FIRST", none)]))]))
#guard failsWith "nodes: consts: ASK_UPLINK is a finite float, not negative: "            -- −1.0
  (line2 (entry [("consts", some (consts36 [("ASK_UPLINK", some (jn 13830554455654793216))]))]))
#guard failsWith "nodes: consts: ASK_UPLINK is a finite float, not negative: "            -- +∞
  (line2 (entry [("consts", some (consts36 [("ASK_UPLINK", some (jn 9218868437227405312))]))]))
#guard failsWith "nodes: consts: ANSWERS_FIRST is true or false: "
  (line2 (entry [("consts", some (consts36 [("ANSWERS_FIRST", some (jn 1))]))]))
#guard (match line2 (entry [("consts", some (consts36 [("ASK_UPLINK", some (jn 4607182418800017408)),
                                                        ("MERGE_HOLDINGS", some (Json.bool true))]))]) with   -- 1.0
  | .ok ((_, cfg) :: _) => cfg.c2.ASK_UPLINK == 1.0 && cfg.c2.MERGE_HOLDINGS && !cfg.c2.ANSWERS_FIRST
  | _ => false)
#guard failsWith "nodes: consts: not a member of it: ANSWERS_FIRST"                       -- under seacast-lite.md
  (nodesLine (Json.arr #[Json.mkObj [("n", Json.arr #[jn 0]), ("consts", consts36), ("replaced", strs [])]]))
#guard passes
  (nodesLine (Json.arr #[Json.mkObj [("n", Json.arr #[jn 0]), ("consts", Json.mkObj consts31), ("replaced", strs [])]]))

-- C2b, v0.11.1's two constants: SAMPLE_OUTSTANDING a JSON integer of at least 1; SERVE_BUDGET one too, or null for
-- no limit. Each refused value in its own guard, as the tracer could write it.
def js (s : String) : Json := match Json.parse s with
  | .ok j => j
  | .error _ => Json.str s!"unparsed: {s}"
def soIs (v : String) : Except String (List (Nat × NodeSeacastCfg)) :=
  line2 (entry [("consts", some (consts36 [("SAMPLE_OUTSTANDING", some (js v))]))])
def sbIs (v : String) : Except String (List (Nat × NodeSeacastCfg)) :=
  line2 (entry [("consts", some (consts36 [("SERVE_BUDGET", some (js v))]))])
#guard failsWith "nodes: consts: no SAMPLE_OUTSTANDING" (line2 (entry [("consts", some (consts36 [("SAMPLE_OUTSTANDING", none)]))]))
#guard failsWith "nodes: consts: no SERVE_BUDGET" (line2 (entry [("consts", some (consts36 [("SERVE_BUDGET", none)]))]))
#guard failsWith "nodes: consts: SAMPLE_OUTSTANDING is a natural number, at least 1: " (soIs "0")
#guard failsWith "nodes: consts: SAMPLE_OUTSTANDING is a natural number, at least 1: " (soIs "4.0")
#guard failsWith "nodes: consts: SAMPLE_OUTSTANDING is a natural number, at least 1: " (soIs "true")
#guard failsWith "nodes: consts: SAMPLE_OUTSTANDING is a natural number, at least 1: " (soIs "null")
#guard failsWith "nodes: consts: SAMPLE_OUTSTANDING is a natural number, at least 1: " (soIs "\"4\"")
#guard failsWith "nodes: consts: SERVE_BUDGET is null or a natural number, at least 1: " (sbIs "0")
#guard failsWith "nodes: consts: SERVE_BUDGET is null or a natural number, at least 1: " (sbIs "2.0")
#guard failsWith "nodes: consts: SERVE_BUDGET is null or a natural number, at least 1: " (sbIs "true")
#guard (match soIs "1" with
  | .ok ((_, cfg) :: _) => cfg.c2.SAMPLE_OUTSTANDING == 1 && cfg.c2.SERVE_BUDGET == none
  | _ => false)
#guard (match line2 (entry [("consts", some (consts36 [("SERVE_BUDGET", some (jn 3))]))]) with
  | .ok ((_, cfg) :: _) => cfg.c2.SAMPLE_OUTSTANDING == 4 && cfg.c2.SERVE_BUDGET == some 3
  | _ => false)
-- a v2 header of before the sync, whose type still carries the cap, is refused (fv-67's note 2)
#guard failsWith "nodes: types: payload: not a type parameter: SAMPLE_OUTSTANDING"
  (line2 (entry [("types", some (Json.mkObj [("payload", Json.mkObj [("SAMPLE_OUTSTANDING", jn 4)])]))]))

-- C3, the members
#guard failsWith "nodes: no types" (line2 (entry [("types", none)]))
#guard failsWith "nodes: no chains" (line2 (entry [("chains", none)]))
#guard failsWith "nodes: not a member of it: chains"                                      -- under seacast-lite.md
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
#guard routeSeacast "announce" == .seacast
#guard ["on_pace_tick", "on_block_installed", "respond"].all (routeSeacast · == .form)
#guard ["with_owed", "build_group", "outstanding", "held"].all (routeSeacast · == .kept)
#guard ["on_frame", "on_heartbeat", "next_to_send", "wake_front", "track_in_flight", "window_release", "window_timeout",
        "no_such_function"].all (routeSeacast · == .refused)
#guard Manifest.kept.all fun f => routeSeacast f == .kept || routeSeacast f == .form
#guard Manifest.nodeOwn.all fun (f, _) => routeSeacast f == .kept
#guard Manifest.covered.all fun f => routeSeacast f == .seacast || routeSeacast f == .form
#guard fnsSeacast.length == 70                                                  -- v0.11.1's joined, drop_wants_beyond

-- D2, runSeacast by the route: a kept name `keptSeacast` did not hold before (`valid_id`, of an entry not 56 bytes long) goes
-- to `Replay.run`; a name v2 redefines is refused
#guard ReplayKnown.passes
  (ReplayKnown.line "valid_id" "[\"abcd\"]" "[]" "[]" "[]" "[]" (ReplayKnown.ret "false") "[\"valid_id\"]" "[]")
#guard ReplayKnown.failsWith "return value: "
  (ReplayKnown.line "valid_id" "[\"abcd\"]" "[]" "[]" "[]" "[]" (ReplayKnown.ret "true") "[\"valid_id\"]" "[]")
#guard ReplayKnown.failsWith "not a function of the twin under seacast.md: on_frame"
  (ReplayKnown.line "on_frame" "[1, []]" "[]" "[]" "[]" "[]" (ReplayKnown.ret "null") "[\"on_frame\"]" "[]")

-- D4, a subset's pick by the tape reads the list of the trace's document
def tapeLine : String := "{\"tape\": [[\"send_have\", \"[1]\", \"null\"], [\"forward\", \"[]\", \"null\"]]}"
#guard asks .seacast tapeLine "send_have"
#guard !asks .lite tapeLine "send_have"
#guard asks .lite tapeLine "forward" && asks .seacast tapeLine "forward"
#guard !asks .seacast "{\"tape\": [[\"window_release\", \"[]\", \"null\"]]}" "window_release"

end SpecTwin.Seacast.DispatchKnown
