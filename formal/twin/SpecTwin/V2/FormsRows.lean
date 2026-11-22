import SpecTwin.V2.Replay

/-! # A question's row, read and refused: the forms of v2's questions

A row is one tape entry of a question, `[name, args, answer]`, under one form of `NodeV2`'s questions, named by its
method (`send (a HAVE)` is `send`). `checkRow` reads a row twice, as `runV2` reads a record's tape:
1. The row's arguments are read with the twin's readers into the twin's values, and the form's question is asked
   with them in `NodeV2 R`, over a tape of that one row (`tapeItem` under `docV2`). `askCall` compares the
   question's arguments, as the twin writes them, with the row's. The answer is read by the form's reader, the
   tape must be used up, and the value read, written back in the answer's form, must be the row's answer.
   `choiceOfSet` is asked with the row's list reversed, so that its comparison as a set is what passes it.
2. The same row with its answer replaced by a wrong form of it (`wrongAnswer`) must be refused by the answer's
   reader, with a message that starts `tape: {name}: its answer: `.

A row's leaves need not be one consistent state: what is checked is the forms. -/

namespace SpecTwin.V2.FormsRows

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.V2

/-- A WANT: `["want", g, bits, standing, hops, probe]`. -/
def wantOf (j : Json) : Except String Want := do
  let #[.str "want", g, b, s, h, p] ← j.getArr? | throw s!"not a WANT: {j.compress}"
  return { group := ← Replay.groupKey g, bits := ← nat b, standing := ← boolOf s, hops := ← nat h,
           probe := ← boolOf p }

/-- A message `send` takes: a HAVE, a WANT or a relation. -/
def msgV2Of (j : Json) : Except String MsgV2 :=
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

/-- The form of a row's name: `send (a HAVE)` is `send`. -/
def formOf (name : String) : String := (name.splitOn " (").headD name

/-- A form's question, asked with the arguments read from its row; its answer written back in the row's form. -/
def askOf (form : String) (args : Array Json) : Except String (R Json) := do
  match form, args with
  | "typeOfGroup", #[g] => do
    let g ← Replay.groupKey g
    return Json.str <$> NodeV2.typeOfGroup (m := R) g
  | "typeOf", #[t] => do
    let t ← typeId t
    return Json.str <$> NodeV2.typeOf (m := R) t
  | "indexCount", #[t, h] => do
    let t ← typeId t; let h ← optOf descriptor h
    return natJson <$> NodeV2.indexCount (m := R) t h
  | "threshold", #[t, h] => do
    let t ← typeId t; let h ← optOf descriptor h
    return natJson <$> NodeV2.threshold (m := R) t h
  | "verify", #[t, f, h] => do
    let t ← typeId t; let f ← chunkF f; let h ← optOf descriptor h
    return verdictJson <$> NodeV2.verify (m := R) t f h
  | "decode", #[t, g, h] => do
    let t ← typeId t; let g ← Replay.groupKey g; let h ← optOf descriptor h
    return optJson pairsJson <$> NodeV2.decode (m := R) t g h
  | "headerOf", #[t, f] => do
    let t ← typeId t; let f ← chunkF f
    return optJson descriptorJson <$> NodeV2.headerOf (m := R) t f
  | "project", #[t, f] => do
    let t ← typeId t; let f ← chunkF f
    return gisJson <$> NodeV2.project (m := R) t f
  | "cross", #[t, g, i] => do
    let t ← typeId t; let g ← Replay.groupKey g; let i ← nat i
    return gisJson <$> NodeV2.cross (m := R) t g i
  | "family", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return intJson <$> NodeV2.family (m := R) t g
  | "derivedInterest", #[t, g, h, nid, j] => do
    let t ← typeId t; let g ← Replay.groupKey g; let h ← optOf descriptor h; let nid ← hex nid
    let j ← joinMsg j
    return intJson <$> NodeV2.derivedInterest (m := R) t g h nid j
  | "decodeAtK", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return Json.bool <$> NodeV2.decodeAtK (m := R) t g
  | "decodeLater", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return optJson floatJson <$> NodeV2.decodeLater (m := R) t g
  | "repairTo", #[t, g] => do
    let t ← typeId t; let g ← Replay.groupKey g
    return natsJson <$> NodeV2.repairTo (m := R) t g
  | "send", #[p, x, u] => do
    let p ← nat p; let x ← msgV2Of x; let u ← boolOf u
    return Json.bool <$> NodeV2.send (m := R) p x u
  | "links", #[t] => do
    let t ← typeId t
    return natsJson <$> NodeV2.links (m := R) t
  | "linkCover", #[q, t] => do
    let q ← nat q; let t ← typeId t
    return coverJson <$> NodeV2.linkCover (m := R) q t
  | "coverCandidates", #[t] => do
    let t ← typeId t
    return coversJson <$> NodeV2.coverCandidates (m := R) t
  | "floorCandidates", #[t] => do
    let t ← typeId t
    return coversJson <$> NodeV2.floorCandidates (m := R) t
  | "floorLinks", #[t, fam] => do
    let t ← typeId t; let fam ← intOf fam
    return natsJson <$> NodeV2.floorLinks (m := R) t fam
  | "highCustody", #[q, t] => do
    let q ← nat q; let t ← typeId t
    return Json.bool <$> NodeV2.highCustody (m := R) q t
  | "families", #[t] => do
    let t ← typeId t
    return famsJson <$> NodeV2.families (m := R) t
  | "familiesWithDuty", #[t] => do
    let t ← typeId t
    return famsJson <$> NodeV2.familiesWithDuty (m := R) t
  | "wantsFamily", #[t, fam] => do
    let t ← typeId t; let fam ← intOf fam
    return Json.bool <$> NodeV2.wantsFamily (m := R) t fam
  | "dutyFor", #[g] => do
    let g ← Replay.groupKey g
    return dutyJson <$> NodeV2.dutyFor (m := R) g
  | "routeNext", #[t, fam, qs] => do
    let t ← typeId t; let fam ← intOf fam; let qs ← peers qs
    return natsJson <$> NodeV2.routeNext (m := R) t fam qs
  | "blockOf", #[g] => do
    let g ← Replay.groupKey g
    return Json.str <$> NodeV2.blockOf (m := R) g
  | "groupOf", #[b, h] => do
    let b ← Replay.blockOf b; let h ← descriptor h
    return Json.str <$> NodeV2.groupOf (m := R) b h
  | "nodeId", #[p] => do
    let p ← nat p
    return Json.str <$> NodeV2.nodeId (m := R) p
  | "interestSatisfied", #[g] => do
    let g ← Replay.groupKey g
    return Json.bool <$> NodeV2.interestSatisfied (m := R) g
  | "validHaveV2", #[h] => do
    let h ← haveOf h
    return Json.bool <$> NodeV2.validHaveV2 (m := R) h
  | "mergeWaiting", #[p, h] => do
    let p ← nat p; let h ← haveOf h
    return Json.bool <$> NodeV2.mergeWaiting (m := R) p h
  | "deferredOffers", #[p, h] => do
    let p ← nat p; let h ← haveOf h
    return (fun ks => Json.arr (ks.map keyJson).toArray) <$> NodeV2.deferredOffers (m := R) p h
  | "openGroupSource", #[g, d] => do
    let g ← Replay.groupKey g; let d ← descriptor d
    return unitJson <$> NodeV2.openGroupSource (m := R) g d
  | "openLink", #[r, t] => do
    let r ← coverOf r; let t ← typeId t
    return unitJson <$> NodeV2.openLink (m := R) r t
  | "openSamplingLink", #[r, t] => do
    let r ← coverOf r; let t ← typeId t
    return unitJson <$> NodeV2.openSamplingLink (m := R) r t
  | "choicePeer", #[xs] => do
    let xs ← peers xs
    return natJson <$> NodeV2.choicePeer (m := R) xs
  | "choiceOfSet", #[xs] => do
    let xs ← peers xs
    return natJson <$> NodeV2.choiceOfSet (m := R) xs.reverse
  | "choiceNat", #[xs] => do
    let xs ← natList xs
    return natJson <$> NodeV2.choiceNat (m := R) xs
  | "choiceCover", #[xs] => do
    let xs ← (← arr xs).mapM coverOf
    return coverJson <$> NodeV2.choiceCover (m := R) xs
  | "sampleCovers", #[xs, k] => do
    let xs ← (← arr xs).mapM coverOf; let k ← nat k
    return coversJson <$> NodeV2.sampleCovers (m := R) xs k
  | "shuffledPairs", #[xs] => do
    let xs ← pairs "index and chunk" nat chunkF xs
    return pairsJson <$> NodeV2.shuffledPairs (m := R) xs
  | _, _ => throw s!"not a form of v2's questions, or not its arguments: {form} {(Json.arr args).compress}"

/-- The question run over a tape of these rows, each read as a record's tape entry is under protocol-v2.md. The
tape must be used up. -/
def onTape {α} (rows : List Json) (q : R α) : Except String α := do
  let tape ← rows.mapM (tapeItem · docV2)
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
  | "validHaveV2" => p "\"true\""
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
  | _ => throw s!"no wrong answer for the form {form}"

/-- The labels of v2's question forms, one row each, in the order of `tools/forms-v2-examples.tsv` (spec 287d575):
the checker's own list, so that a file with a row missing, twice or relabelled is refused (`formsMain`). -/
def labels : List String :=
  ["typeOfGroup", "typeOf", "indexCount", "threshold", "verify", "decode", "headerOf", "project", "cross", "family",
   "derivedInterest", "decodeAtK", "decodeLater", "repairTo", "send (a HAVE)", "send (a WANT)", "send (a relation)",
   "links", "linkCover", "coverCandidates", "floorCandidates", "floorLinks", "highCustody", "families",
   "familiesWithDuty", "wantsFamily", "dutyFor", "routeNext", "blockOf", "groupOf", "nodeId", "interestSatisfied",
   "mergeWaiting", "deferredOffers", "openGroupSource", "openLink", "openSamplingLink", "choicePeer", "choiceOfSet",
   "choiceNat", "choiceCover", "validHaveV2", "sampleCovers", "shuffledPairs"]

/-- A `send` row's kind, and the wire tags its message may carry (the message's first member). -/
def sendKind : String → Option (String × List String)
  | "send (a HAVE)" => some ("HAVE", ["have"])
  | "send (a WANT)" => some ("WANT", ["want"])
  | "send (a relation)" => some ("relation", ["join", "graft", "prune"])
  | _ => none

/-- A row read, and then refused with a wrong form of its answer: the answer as read and written back, and the
refusal's message. A `send` row's message must carry its label's wire tag first. -/
def checkRow (name : String) (row : Json) : Except String (String × String) := do
  let form := formOf name
  let #[.str q, .arr args, ans] ← row.getArr? | throw s!"not a row [name, args, answer]: {row.compress}"
  if let some (kind, tags) := sendKind name then
    let m := args[1]?.getD Json.null
    let .ok (.str tag) := m.getArrVal? 0 | throw s!"{name}: the message has no wire tag: {m.compress}"
    if !tags.contains tag then throw s!"{name}: the message is not a {kind}: {tag}"
  let ask ← askOf form args
  let v ← onTape [row] ask
  if v != ans then throw s!"the answer read back as {v.compress}, not the row's {ans.compress}"
  let bad := Json.arr #[Json.str q, Json.arr args, ← wrongAnswer form ans]
  match onTape [bad] ask with
  | .ok w => throw s!"a wrong answer read, as {w.compress}: {bad.compress}"
  | .error e =>
    if e.startsWith s!"tape: {q}: its answer: " then return (v.compress, e)
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
  [("1, send's urgent flipped", "tape: send[", do onTape [sendRow] (← askOf "send" (a.set! 2 flipped))),
   ("2, highCustody's row as linkCover", "tape: link_cover[",
     do onTape [hcRow] (← askOf "linkCover" (argsOf hcRow))),
   ("3, typeOf's row twice", "the tape is not used up", do onTape [toRow, toRow] (← askOf "typeOf" (argsOf toRow)))]

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

end SpecTwin.V2.FormsRows
