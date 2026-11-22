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

/-- A row read, and then refused with a wrong form of its answer: the answer as read and written back, and the
refusal's message. -/
def checkRow (name : String) (row : Json) : Except String (String × String) := do
  let form := formOf name
  let #[.str q, .arr args, ans] ← row.getArr? | throw s!"not a row [name, args, answer]: {row.compress}"
  let ask ← askOf form args
  let v ← onTape [row] ask
  if v != ans then throw s!"the answer read back as {v.compress}, not the row's {ans.compress}"
  let bad := Json.arr #[Json.str q, Json.arr args, ← wrongAnswer form ans]
  match onTape [bad] ask with
  | .ok w => throw s!"a wrong answer read, as {w.compress}: {bad.compress}"
  | .error e =>
    if e.startsWith s!"tape: {q}: its answer: " then return (v.compress, e)
    throw s!"a wrong answer refused, but not by its reader: {e}"

end SpecTwin.V2.FormsRows
