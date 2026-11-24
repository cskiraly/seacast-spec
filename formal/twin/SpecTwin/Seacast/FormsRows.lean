import SpecTwin.Seacast.Replay

/-! # A question's row, read and refused: the forms of SEACAST's questions

A row is one tape entry of a question, `[name, args, answer]`, under one form of `NodeSeacast`'s or `SeacastLater`'s
questions, named by its method (`send (a HAVE)` is `send`). An order's row is `["order", place, members]`, and an own
level's keys `["keys", table, path, keys]` (`rowParts`). `checkRow` reads a row twice, as `runSeacast` reads a record's
tape:
1. The row's arguments are read with the twin's readers into the twin's values, and the form's question is asked
   with them in `NodeSeacast R`, over a tape of that one row (`tapeItem` under `docSeacast`). `askCall` compares the
   question's arguments, as the twin writes them, with the row's. The answer is read by the form's reader, the
   tape must be used up, and the value read, written back in the answer's form, must be the row's answer.
   `choiceOfSet` and the three orders are asked with the row's members reversed, so that only a permutation of them
   passes.
2. The same row with its answer replaced by a wrong form of it (`wrongAnswer`) must be refused by the answer's
   reader, with a message that starts `tape: {name}: its answer: `. `shuffledPeers`' row is `seacast-lite.md`'s
   `shuffled` entry, refused by that entry's reader in its own words (`refusalOf`).

A row's leaves need not be one consistent state: what is checked is the forms. -/

namespace SpecTwin.Seacast.FormsRows

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.Seacast

/-- A WANT: `["want", g, bits, standing, hops, probe]`. -/
def wantOf (j : Json) : Except String Want := do
  let #[.str "want", g, b, s, h, p] ← j.getArr? | throw s!"not a WANT: {j.compress}"
  return { group := ← Replay.groupKey g, bits := ← nat b, standing := ← boolOf s, hops := ← nat h,
           probe := ← boolOf p }

/-- A message `send` takes: a HAVE, a WANT or a relation. -/
def msgSeacastOf (j : Json) : Except String MsgSeacast :=
  match j.getArrVal? 0 with
  | .ok (.str "have") => do return .have (← haveOf j)
  | .ok (.str "want") => do return .want (← wantOf j)
  | _ => do return .relation (← relation j)

def verdictJson : Verdict → Json
  | .accept => Json.str "ACCEPT"
  | .reject => Json.str "REJECT"
  | .defer => Json.str "DEFER"

def pairJson (p : Nat × ChunkF) : Json := Json.arr #[(p.1 : Json), chunkJson p.2]
def pairsJson (l : List (Nat × ChunkF)) : Json := Json.arr (l.map pairJson).toArray
def gisJson (l : List GI) : Json := Json.arr (l.map giJson).toArray
def coversJson (l : List Cover) : Json := Json.arr (l.map coverJson).toArray
def famsJson (l : List Fam) : Json := Json.arr (l.map intJson).toArray
def natJson (n : Nat) : Json := (n : Json)
def unitJson (_ : Unit) : Json := Json.null
def groupsJson (l : List Group) : Json := Json.arr (l.map Json.str).toArray

def repairVerdictJson : RepairVerdict → Json
  | .repaired => Json.str "REPAIRED"
  | .notRepaired => Json.str "NOT_REPAIRED"
  | .asked => Json.str "ASKED"

def uplinkClassJson : UplinkClass → Json
  | .fast => Json.str "FAST"
  | .home => Json.str "HOME"

/-- An `after` row's timer, read back from its name and its arguments: the inverse of `timerSeacastJson`. -/
def timerSeacastOf (f : String) (xs : Json) : Except String TimerSeacast := do
  match f, ← xs.getArr? with
  | "reconsider", #[g, t] => return .reconsider (← Replay.groupKey g) (← floatOf t)
  | "ask_sample", #[g, i] => return .askSample (← Replay.groupKey g) (← nat i)
  | "resample", #[g, i, q, b] => return .resample (← Replay.groupKey g) (← nat i) (← nat q) (← boolOf b)
  | _, _ => throw s!"not one of SEACAST's timers: {f} {xs.compress}"

/-- The form of a row's name: `send (a HAVE)` is `send`. -/
def formOf (name : String) : String := (name.splitOn " (").headD name

/-- A form's question, asked with the arguments read from its row; its answer written back in the row's form. An
order's question also takes the members the twin holds: the row's answer, reversed, so that only a permutation of
them passes. -/
def askOf (form : String) (args : Array Json) (ans : Json) : Except String (R Json) := do
  match form, args with
  | "typeOfGroup", #[g] => do
    let g ← Replay.groupKey g
    return Json.str <$> NodeSeacast.typeOfGroup (m := R) g
  | "typeOf", #[t] => do
    let t ← typeId t
    return Json.str <$> NodeSeacast.typeOf (m := R) t
  | "indexCount", #[t, h] => do
    let t ← typeId t; let h ← optOf descriptor h
    return natJson <$> NodeSeacast.indexCount (m := R) t h
  | "threshold", #[t, h] => do
    let t ← typeId t; let h ← optOf descriptor h
    return natJson <$> NodeSeacast.threshold (m := R) t h
  | "verify", #[t, f, h] => do
    let t ← typeId t; let f ← chunkF f; let h ← optOf descriptor h
    return verdictJson <$> NodeSeacast.verify (m := R) t f h
  | "decode", #[t, g, h] => do
    let t ← typeId t; let g ← Replay.groupKey g; let h ← optOf descriptor h
    return optJson pairsJson <$> NodeSeacast.decode (m := R) t g h
  | "headerOf", #[t, f] => do
    let t ← typeId t; let f ← chunkF f
    return optJson descriptorJson <$> NodeSeacast.headerOf (m := R) t f
  | "project", #[t, f] => do
    let t ← typeId t; let f ← chunkF f
    return gisJson <$> NodeSeacast.project (m := R) t f
  | "cross", #[t, g, i] => do
    let t ← typeId t; let g ← Replay.groupKey g; let i ← nat i
    return gisJson <$> NodeSeacast.cross (m := R) t g i
  | "family", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return intJson <$> NodeSeacast.family (m := R) t g
  | "derivedInterest", #[t, g, h, nid, j] => do
    let t ← typeId t; let g ← Replay.groupKey g; let h ← optOf descriptor h; let nid ← hex nid
    let j ← joinMsg j
    return intJson <$> NodeSeacast.derivedInterest (m := R) t g h nid j
  | "decodeAtK", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return Json.bool <$> NodeSeacast.decodeAtK (m := R) t g
  | "decodeLater", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return optJson floatJson <$> NodeSeacast.decodeLater (m := R) t g
  | "repairTo", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return natsJson <$> NodeSeacast.repairTo (m := R) t g
  | "send", #[p, x, u] => do
    let p ← nat p; let x ← msgSeacastOf x; let u ← boolOf u
    return Json.bool <$> NodeSeacast.send (m := R) p x u
  | "links", #[t] => do
    let t ← typeId t
    return natsJson <$> NodeSeacast.links (m := R) t
  | "linkCover", #[q, t] => do
    let q ← nat q; let t ← typeId t
    return coverJson <$> NodeSeacast.linkCover (m := R) q t
  | "coverCandidates", #[t] => do
    let t ← typeId t
    return coversJson <$> NodeSeacast.coverCandidates (m := R) t
  | "floorCandidates", #[t] => do
    let t ← typeId t
    return coversJson <$> NodeSeacast.floorCandidates (m := R) t
  | "floorLinks", #[t, fam] => do
    let t ← typeId t; let fam ← intOf fam
    return natsJson <$> NodeSeacast.floorLinks (m := R) t fam
  | "highCustody", #[q, t] => do
    let q ← nat q; let t ← typeId t
    return Json.bool <$> NodeSeacast.highCustody (m := R) q t
  | "families", #[t] => do
    let t ← typeId t
    return famsJson <$> NodeSeacast.families (m := R) t
  | "familiesWithDuty", #[t] => do
    let t ← typeId t
    return famsJson <$> NodeSeacast.familiesWithDuty (m := R) t
  | "wantsFamily", #[t, fam] => do
    let t ← typeId t; let fam ← intOf fam
    return Json.bool <$> NodeSeacast.wantsFamily (m := R) t fam
  | "dutyFor", #[g] => do
    let g ← Replay.groupKey g
    return dutyJson <$> NodeSeacast.dutyFor (m := R) g
  | "routeNext", #[t, fam, qs] => do
    let t ← typeId t; let fam ← intOf fam; let qs ← peers qs
    return natsJson <$> NodeSeacast.routeNext (m := R) t fam qs
  | "blockOf", #[g] => do
    let g ← Replay.groupKey g
    return Json.str <$> NodeSeacast.blockOf (m := R) g
  | "groupOf", #[b, h] => do
    let b ← Replay.blockOf b; let h ← descriptor h
    return Json.str <$> NodeSeacast.groupOf (m := R) b h
  | "nodeId", #[p] => do
    let p ← nat p
    return Json.str <$> NodeSeacast.nodeId (m := R) p
  | "interestSatisfied", #[g] => do
    let g ← Replay.groupKey g
    return Json.bool <$> NodeSeacast.interestSatisfied (m := R) g
  | "validHaveSeacast", #[h] => do
    let h ← haveOf h
    return Json.bool <$> NodeSeacast.validHaveSeacast (m := R) h
  | "mergeWaiting", #[p, h] => do
    let p ← nat p; let h ← haveOf h
    return Json.bool <$> NodeSeacast.mergeWaiting (m := R) p h
  | "deferredOffers", #[p, h] => do
    let p ← nat p; let h ← haveOf h
    return (fun ks => Json.arr (ks.map keyJson).toArray) <$> NodeSeacast.deferredOffers (m := R) p h
  | "openGroupSource", #[g, d] => do
    let g ← Replay.groupKey g; let d ← descriptor d
    return unitJson <$> NodeSeacast.openGroupSource (m := R) g d
  | "openLink", #[r, t] => do
    let r ← coverOf r; let t ← typeId t
    return unitJson <$> NodeSeacast.openLink (m := R) r t
  | "openSamplingLink", #[r, t] => do
    let r ← coverOf r; let t ← typeId t
    return unitJson <$> NodeSeacast.openSamplingLink (m := R) r t
  | "choicePeer", #[xs] => do
    let xs ← peers xs
    return natJson <$> NodeSeacast.choicePeer (m := R) xs
  | "choiceOfSet", #[xs] => do
    let xs ← peers xs
    return natJson <$> NodeSeacast.choiceOfSet (m := R) xs.reverse
  | "choiceNat", #[xs] => do
    let xs ← natList xs
    return natJson <$> NodeSeacast.choiceNat (m := R) xs
  | "choiceCover", #[xs] => do
    let xs ← (← arr xs).mapM coverOf
    return coverJson <$> NodeSeacast.choiceCover (m := R) xs
  | "sampleCovers", #[xs, k] => do
    let xs ← (← arr xs).mapM coverOf; let k ← nat k
    return coversJson <$> NodeSeacast.sampleCovers (m := R) xs k
  | "shuffledPairs", #[xs] => do
    let xs ← pairs "index and chunk" nat chunkF xs
    return pairsJson <$> NodeSeacast.shuffledPairs (m := R) xs
  | "afterSeacast", #[d, .str f, xs] => do
    let d ← floatOf d; let t ← timerSeacastOf f xs
    return unitJson <$> NodeSeacast.afterSeacast (m := R) d t
  | "releaseWantedGroups", #[] =>
    return unitJson <$> NodeSeacast.releaseWantedGroups (m := R)
  | "shuffledPeers", #[xs] => do
    let xs ← peers xs
    return natsJson <$> NodeSeacast.shuffledPeers (m := R) xs
  | "order", #[.str place] => do
    let xs ← peers ans
    return natsJson <$> NodeSeacast.order (m := R) place xs.reverse
  | "probeWaitingOrder", #[.str "probe_waiting", .arr #[g]] => do
    let g ← Replay.groupKey g; let xs ← peers ans
    return natsJson <$> NodeSeacast.probeWaitingOrder (m := R) g xs.reverse
  | "claimsOrder", #[.str "claims", .arr #[]] => do
    let gs ← (← arr ans).mapM Replay.groupKey
    return groupsJson <$> NodeSeacast.claimsOrder (m := R) gs.reverse
  | "ownInterest", #[g] => do
    let g ← Replay.groupKey g
    return intJson <$> NodeSeacast.ownInterest (m := R) g
  | "windowRelease", #[p, g, i] => do
    let p ← nat p; let g ← Replay.groupKey g; let i ← nat i
    return unitJson <$> SeacastLater.windowRelease (m := R) p g i
  | "forwardNode", #[f, p, axes] => do
    let f ← chunkF f; let p ← nat p; let axes ← optOf giList axes
    return unitJson <$> NodeSeacast.forwardNode (m := R) f p axes
  | "pushRebuiltNode", #[g, xs] => do
    let g ← Replay.groupKey g; let xs ← natList xs
    return unitJson <$> NodeSeacast.pushRebuiltNode (m := R) g xs
  | "sendHaveNode", #[p, g] => do
    let p ← nat p; let g ← Replay.groupKey g
    return unitJson <$> NodeSeacast.sendHaveNode (m := R) p g
  | "serveStandingNode", #[g, i] => do
    let g ← Replay.groupKey g; let i ← nat i
    return unitJson <$> NodeSeacast.serveStandingNode (m := R) g i
  | "owedMissingNode", #[g] => do
    let g ← Replay.groupKey g
    return Json.bool <$> NodeSeacast.owedMissingNode (m := R) g
  | "repairVerdictNode", #[g] => do
    let g ← Replay.groupKey g
    return repairVerdictJson <$> NodeSeacast.repairVerdictNode (m := R) g
  | "noteClaimNode", #[p, g] => do
    let p ← nat p; let g ← Replay.groupKey g
    return unitJson <$> NodeSeacast.noteClaimNode (m := R) p g
  | "knownInScopeNode", #[g] => do
    let g ← Replay.groupKey g
    return natJson <$> NodeSeacast.knownInScopeNode (m := R) g
  | "ownId", #[] => do
    return Json.str <$> NodeSeacast.ownId (m := R)
  | "admittedGroup", #[p, g] => do
    let p ← nat p; let g ← Replay.groupKey g
    return Json.bool <$> NodeSeacast.admittedGroup (m := R) p g
  -- seacast-lite.md's two questions as on_want asks them: an ask's key, and an id
  | "resolve", #[a] => do
    let a ← key a
    return optJson keyJson <$> Node61.resolve (m := R) a
  | "chunkOf", #[a] => do
    let a ← mid a
    return chunkJson <$> Node61.chunkOf (m := R) a
  -- §4.1's upkeep: the node's types, its JOIN, its candidates and pushers, and its uplink
  | "runsType", #[t] => do
    let t ← typeId t
    return Json.bool <$> NodeSeacast.runsType (m := R) t
  | "ourJoin", #[t] => do
    let t ← typeId t
    return joinJson <$> NodeSeacast.ourJoin (m := R) t
  | "candidates", #[t, fam, c, d] => do
    let t ← typeId t; let fam ← intOf fam; let c ← nat c; let d ← direction d
    return natsJson <$> NodeSeacast.candidates (m := R) t fam c d
  | "inPushers", #[t, fam, c] => do
    let t ← typeId t; let fam ← intOf fam; let c ← nat c
    return natsJson <$> NodeSeacast.inPushers (m := R) t fam c
  | "outPushees", #[t, fam, c] => do
    let t ← typeId t; let fam ← intOf fam; let c ← nat c
    return natsJson <$> NodeSeacast.outPushees (m := R) t fam c
  | "uplinkClass", #[] => do
    return uplinkClassJson <$> NodeSeacast.uplinkClass (m := R)
  | _, _ => throw s!"not a form of SEACAST's questions, or not its arguments: {form} {(Json.arr args).compress}"

/-- The question run over a tape of these rows, each read as a record's tape entry is under seacast.md. The
tape must be used up. -/
def onTape {α} (rows : List Json) (q : R α) : Except String α := do
  let tape ← rows.mapM (tapeItem · docSeacast)
  let (r, s) := Id.run (q.run.run { tape })
  let v ← r
  if !s.tape.isEmpty then throw s!"the tape is not used up: {s.tape.length} left"
  return v

/-- One wrong form of a form's answer: a value its reader refuses. `ans` is the row's answer. -/
def wrongAnswer (form : String) (ans : Json) : Except String Json := do
  let p (s : String) : Except String Json := Json.parse s
  match form with
  | "typeOfGroup" => p "5"
  | "typeOf" => p "\"\""
  | "indexCount" => p "\"2\""
  | "threshold" => p "true"
  | "verify" => p "\"accept\""
  | "decode" => p "[[0]]"
  | "headerOf" => p "[2,0,1]"
  | "project" => p "[5]"
  | "cross" => p "[[3]]"
  | "family" => p "[\"-\",0]"
  | "derivedInterest" => p "[\"+\",1]"
  | "decodeAtK" => p "1"
  | "decodeLater" => p "9218868437227405312"        -- +∞'s word
  | "repairTo" => p "[4,4]"
  | "send" => p "null"
  | "links" => p "[2,2]"
  | "linkCover" => p "{\"families\":[3],\"high\":true,\"id\":4}"
  | "coverCandidates" => p "[{\"families\":[3,40],\"id\":7}]"
  | "floorCandidates" => p "[{\"families\":[3],\"high\":false,\"id\":7}]"
  | "floorLinks" => p "[2,\"4\"]"
  | "highCustody" => p "\"false\""
  | "families" => p "[[\"-\",0]]"
  | "familiesWithDuty" => p "[3,null]"
  | "wantsFamily" => p "0"
  | "dutyFor" => p "\"BOTH\""
  | "routeNext" => p "[2,2]"
  | "blockOf" => p "\"abc\""
  | "groupOf" => p "5"
  | "nodeId" => p "\"7fe\""
  | "interestSatisfied" => p "null"
  | "validHaveSeacast" => p "\"true\""
  | "mergeWaiting" => p "1"
  | "deferredOffers" => p "[5]"
  | "openGroupSource" => p "true"
  | "openLink" => p "{}"
  | "openSamplingLink" => p "0"
  | "choicePeer" => p "\"4\""
  | "choiceOfSet" => p "[7]"
  | "choiceNat" => p "[\"-\",1]"
  | "choiceCover" => p "{\"families\":[12],\"high\":true,\"id\":9,\"x\":0}"
  | "sampleCovers" => p "[9]"
  | "shuffledPairs" => match ans with      -- the answer's first pair alone
    | .arr xs => match xs[0]? with
      | some x => pure (Json.arr #[x])
      | none => throw "shuffledPairs: an empty answer has no first pair"
    | _ => throw s!"shuffledPairs: not a list of pairs: {ans.compress}"
  | "afterSeacast" | "releaseWantedGroups" | "windowRelease" | "forwardNode" | "pushRebuiltNode" | "sendHaveNode"
  | "serveStandingNode" | "noteClaimNode" => p "1"
  | "shuffledPeers" => match ans with     -- the answer with its first member again at the end
    | .arr xs => match xs[0]? with
      | some x => pure (Json.arr (xs.push x))
      | none => throw "shuffledPeers: an empty answer has no first member"
    | _ => throw s!"shuffledPeers: not a list of peers: {ans.compress}"
  | "order" => p "[\"7\"]"
  | "probeWaitingOrder" => p "[[7]]"
  | "claimsOrder" => p "[5]"
  | "ownInterest" => p "[\"+\",1]"
  | "owedMissingNode" => p "0"
  | "repairVerdictNode" => p "\"repaired\""
  | "knownInScopeNode" => p "[\"-\",1]"
  -- §4.5's four, each refused by its reader's own check, not by the JSON's kind or shape: own_id's hex digits;
  -- resolve's structured id; chunk_of's id asked (a narrow chunk, well formed, of the all-zero group's index 0)
  | "ownId" => p "\"7fe\""
  | "admittedGroup" => p "\"true\""
  | "resolve" => p "\"abcd\""
  | "chunkOf" =>
    let z (n : Nat) := String.ofList (List.replicate n '0')
    p s!"[\"{z 64}\", 0, 0, \"{String.ofList (List.replicate 64 'b')}\", \"{z 112}\"]"
  -- §4.1's upkeep's six, each refused by its reader's own check: a peer twice in a list of peers, a JOIN's array
  -- with another tag, an uplink class outside the two
  | "runsType" => p "1"
  | "ourJoin" => p "[\"graft\",\"payload\",\"ALL\",0,\"FORWARD\",1]"
  | "candidates" => p "[2,2]"
  | "inPushers" => p "[3,3]"
  | "outPushees" => p "[4,4]"
  | "uplinkClass" => p "\"SLOW\""
  | _ => throw s!"no wrong answer for the form {form}"

/-- The words a wrong answer must be refused with: its reader's, after the question's name. `shuffledPeers`' row
is `seacast-lite.md`'s `shuffled` entry, whose reader refuses an answer that is not a permutation of the question
before any question is asked. -/
def refusalOf (form q : String) : String :=
  if form == "shuffledPeers" then "shuffled's answer is not a permutation of its question: "
  else s!"tape: {q}: its answer: "

/-- The labels of SEACAST's question forms, one row each, in the order of `tools/forms-seacast-examples.tsv`: the checker's
own list, so that a file with a row missing, twice or relabelled is refused (`formsMain`). The first 44 are the
file's at spec 287d575; the next 18 cover the methods of `NodeSeacast` and `SeacastLater` that had no row; the next 4
are the questions §4.5's serving adds: `own_id` and `admitted_group`, and `seacast-lite.md`'s `resolve` and `chunk_of` as
`on_want` asks them; the last 6 are §4.1's upkeep's: `runs_type`, `our_join`, `candidates`, `in_pushers`,
`out_pushees` and `uplink_class`. -/
def labels : List String :=
  ["typeOfGroup", "typeOf", "indexCount", "threshold", "verify", "decode", "headerOf", "project", "cross", "family",
   "derivedInterest", "decodeAtK", "decodeLater", "repairTo", "send (a HAVE)", "send (a WANT)", "send (a relation)",
   "links", "linkCover", "coverCandidates", "floorCandidates", "floorLinks", "highCustody", "families",
   "familiesWithDuty", "wantsFamily", "dutyFor", "routeNext", "blockOf", "groupOf", "nodeId", "interestSatisfied",
   "mergeWaiting", "deferredOffers", "openGroupSource", "openLink", "openSamplingLink", "choicePeer", "choiceOfSet",
   "choiceNat", "choiceCover", "validHaveSeacast", "sampleCovers", "shuffledPairs",
   -- the forms that had no row before seacast.md v0.11.1's sync, with one `afterSeacast` label per v2 timer
   "afterSeacast (reconsider)", "afterSeacast (ask_sample)", "afterSeacast (resample)", "releaseWantedGroups", "shuffledPeers",
   "order", "probeWaitingOrder", "claimsOrder", "ownInterest", "windowRelease",
   "forwardNode", "pushRebuiltNode", "sendHaveNode", "serveStandingNode", "owedMissingNode", "repairVerdictNode",
   "noteClaimNode", "knownInScopeNode",
   -- §4.5's serving: two of SEACAST's questions, and two of seacast-lite.md's that on_want asks
   "ownId", "admittedGroup", "resolve", "chunkOf",
   -- §4.1's upkeep: the six questions its relations ask
   "runsType", "ourJoin", "candidates", "inPushers", "outPushees", "uplinkClass"]

/-- A `send` row's kind, and the wire tags its message may carry (the message's first member). -/
def sendKind : String → Option (String × List String)
  | "send (a HAVE)" => some ("HAVE", ["have"])
  | "send (a WANT)" => some ("WANT", ["want"])
  | "send (a relation)" => some ("relation", ["join", "graft", "prune"])
  | _ => none

/-- An `afterSeacast` row's timer, by its label: the name its arguments must carry second. -/
def afterTimer : String → Option String
  | "afterSeacast (reconsider)" => some "reconsider"
  | "afterSeacast (ask_sample)" => some "ask_sample"
  | "afterSeacast (resample)" => some "resample"
  | _ => none

/-- A row's parts: the question's name on the tape, its arguments as the question writes them, its answer, and the
row rebuilt around another answer. An order's row is `["order", place, members]`, and an own level's keys
`["keys", table, path, keys]`. Every other row is `[name, args, answer]`, with the call's log of cells as a fourth
member where the record has one; the rebuilt row keeps it. -/
def rowParts (row : Json) : Except String (String × Array Json × Json × (Json → Json)) :=
  match row with
  | .arr #[.str "order", place, ms] =>
    pure ("order", #[place], ms, fun a => Json.arr #[Json.str "order", place, a])
  | .arr #[.str "keys", t, path, ks] =>
    pure ("keys", #[t, path], ks, fun a => Json.arr #[Json.str "keys", t, path, a])
  | .arr #[.str q, .arr args, ans] =>
    pure (q, args, ans, fun a => Json.arr #[Json.str q, Json.arr args, a])
  | .arr #[.str q, .arr args, ans, log@(.obj _)] =>
    pure (q, args, ans, fun a => Json.arr #[Json.str q, Json.arr args, a, log])
  | _ => throw s!"not a row [name, args, answer]: {row.compress}"

/-- A row read, and then refused with a wrong form of its answer: the answer as read and written back, and the
refusal's message. A `send` row's message must carry its label's wire tag first, and an `afterSeacast` row its label's
timer. -/
def checkRow (name : String) (row : Json) : Except String (String × String) := do
  let form := formOf name
  let (q, args, ans, rebuild) ← rowParts row
  if let some (kind, tags) := sendKind name then
    let m := args[1]?.getD Json.null
    let .ok (.str tag) := m.getArrVal? 0 | throw s!"{name}: the message has no wire tag: {m.compress}"
    if !tags.contains tag then throw s!"{name}: the message is not a {kind}: {tag}"
  if let some t := afterTimer name then
    let f := args[1]?.getD Json.null
    if f != Json.str t then throw s!"{name}: the timer is not {t}: {f.compress}"
  let ask ← askOf form args ans
  let v ← onTape [row] ask
  if v != ans then throw s!"the answer read back as {v.compress}, not the row's {ans.compress}"
  let bad := rebuild (← wrongAnswer form ans)
  match onTape [bad] ask with
  | .ok w => throw s!"a wrong answer read, as {w.compress}: {bad.compress}"
  | .error e =>
    if e.startsWith (refusalOf form q) then return (v.compress, e)
    throw s!"a wrong answer refused, but not by its reader: {e}"

/-- The checker's three controls, on a file's rows. Each must fail, with a message that starts as given:
1. `send (a HAVE)` asked with its `urgent` flipped, over the row as it is: the question asked is not the row's;
2. the `highCustody` row run as the form `linkCover`, which takes the same arguments: a row under another form;
3. the `typeOf` row twice on the tape: the tape is not used up. -/
def controls (rows : Array (String × Json)) : List (String × String × Except String Json) :=
  let row (name : String) : Json := ((rows.find? (·.1 == name)).map (·.2)).getD Json.null
  let argsOf (j : Json) : Array Json := match j.getArrVal? 1 with
    | .ok (.arr a) => a
    | _ => #[]
  let sendRow := row "send (a HAVE)"
  let a := argsOf sendRow
  let flipped : Json := match (a[2]? : Option Json) with
    | some (Json.bool b) => Json.bool !b
    | _ => Json.null
  let hcRow := row "highCustody"
  let toRow := row "typeOf"
  [("1, send's urgent flipped", "tape: send[",
     do onTape [sendRow] (← askOf "send" (a.set! 2 flipped) Json.null)),
   ("2, highCustody's row as linkCover", "tape: link_cover[",
     do onTape [hcRow] (← askOf "linkCover" (argsOf hcRow) Json.null)),
   ("3, typeOf's row twice", "the tape is not used up",
     do onTape [toRow, toRow] (← askOf "typeOf" (argsOf toRow) Json.null))]

/-- `replay --forms FILE`. Each line of FILE is a form's name, a tab and its row as compact JSON. Before any row is
read, the names must be the checker's `labels`, each once: a file with another name, a name twice or a label with
no row is refused with one line and exit 1. Then each row is read and refused (`checkRow`), and the three controls
are run on the same rows. One line is printed for each, and a last line with the counts. The exit code is 1 on any
miss, and on a file that is not there. -/
def formsMain (file : String) : IO UInt32 := do
  if !(← System.FilePath.pathExists file) then
    IO.println s!"replay: --forms {file}: no such file"
    return 1
  let mut failed := 0
  let mut rows : Array (String × Json) := #[]
  for l in ← IO.FS.lines file do
    if l.isEmpty then continue
    match l.splitOn "\t" with
    | [name, row] => match Json.parse row with
      | .ok j => rows := rows.push (name, j)
      | .error e => IO.println s!"{name}\tFAIL\tthe row is not JSON: {e}"; failed := failed + 1
    | _ => IO.println s!"FAIL\tnot a line of a name, a tab and a row: {l}"; failed := failed + 1
  -- the labels, before any row is read: each of the checker's once, and no other
  let names := rows.toList.map (·.1)
  let mut seen : List String := []
  for n in names do
    if !labels.contains n then
      IO.println s!"forms: not one of the {labels.length} labels: {n}"
      return 1
    if seen.contains n then
      IO.println s!"forms: a label twice: {n}"
      return 1
    seen := n :: seen
  if let some n := labels.find? (!names.contains ·) then
    IO.println s!"forms: no row for {n}"
    return 1
  for (name, j) in rows do
    match checkRow name j with
    | .ok (v, e) => IO.println s!"{name}\tread ok\t{v}\trefused\t{e}"
    | .error e => IO.println s!"{name}\tFAIL\t{e}"; failed := failed + 1
  for (label, pre, x) in controls rows do
    match x with
    | .ok v => IO.println s!"control {label}\tFAIL\tread, as {v.compress}"; failed := failed + 1
    | .error e =>
      if e.startsWith pre then IO.println s!"control {label}\trefused\t{e}"
      else IO.println s!"control {label}\tFAIL\trefused otherwise: {e}"; failed := failed + 1
  IO.println s!"rows {rows.size}, controls 3, failed {failed}"
  return if failed == 0 then 0 else 1

end SpecTwin.Seacast.FormsRows
