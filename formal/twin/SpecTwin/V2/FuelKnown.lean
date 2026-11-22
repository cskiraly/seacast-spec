import SpecTwin.V2.ReplayKnown

/-! # `resample`'s fuel: its known answer

`held_samples[b]` is kept per block, and `SAMPLE_OUTSTANDING` per object type. `resample` loops while the block holds
samples and its own type's cap is not reached, and `ask_sample` appends a popped sample back where the sample's type's
cap is reached. Where that cap is below `resample`'s, and the block's samples in flight lie between the two, a turn
changes nothing: the Python's loop does not end, and the twin's, which has `n·(n+1)+1` turns for the n samples held
at the first guard, crashes by name. No tracer record holds such a case, since the toy would not return; the records
here are made by hand, in the tracer's form, and replayed by `runV2` as `ReplayKnown`'s are. -/

namespace SpecTwin.V2.FuelKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.V2

/-- Two groups of one block: g of type `row`, g2 of type `col`. -/
def g : String := String.ofList (List.replicate 64 'a')
def g2 : String := String.ofList (List.replicate 64 'c')
def b : String := String.ofList (List.replicate 64 'b')
def q (s : String) : String := s!"\"{s}\""

/-- At the node, `row`'s cap is 1 and `col`'s is `colCap`. -/
def params (colCap : Nat) : TypeId → Option TypeParams := fun T =>
  if T == "row" then some { SAMPLE_OUTSTANDING := some 1 }
  else if T == "col" then some { SAMPLE_OUTSTANDING := some colCap }
  else none

def replay (l : String) (colCap : Nat) : Except String (Array String × Nat) := do
  runV2 ReplayKnown.c0 ReplayKnown.c2 (params colCap) [] ReplayKnown.traced (← record (← Json.parse l) docV2)

def tog (x T : String) : String := s!"[\"type_of_group\", [{q x}], \"{T}\"]"
def bo (x : String) : String := s!"[\"block_of\", [{q x}], {q b}]"
def exp (x : String) : String := s!"[\"expired\", [{q x}], false]"

/-- The tape: g's type, block and `expired`, then for each turn g2's, which `ask_sample` asks. -/
def tape (turns : Nat) : String :=
  "[" ++ ", ".intercalate ([tog g "row", bo g, exp g] ++
    (List.replicate turns [tog g2 "col", bo g2, exp g2]).flatten) ++ "]"

/-- `resample(g, 0, 3, True)`: `mine[g]` holds index 0; `held_samples[b]` holds g2's index 0; nothing in flight. -/
def spin : String :=
  ReplayKnown.line "resample" s!"[{q g}, 0, 3, true]"
    s!"[[\"mine\", [{q g}], 1], [\"held_samples\", [{q b}], [[{q g2}, 0]]], [\"samples_in_flight\", [{q b}], null], [\"mine\", [{q g2}], null]]"
    "[]" "[]" (tape 3) (ReplayKnown.ret "null") "[\"ask_sample\", \"resample\"]"
    "[\"held_samples\", \"mine\", \"samples_in_flight\"]"

/-- The same call with no sample held. -/
def none_held : String :=
  ReplayKnown.line "resample" s!"[{q g}, 0, 3, true]"
    s!"[[\"mine\", [{q g}], 1], [\"held_samples\", [{q b}], null]]"
    "[]" "[]" (tape 0) (ReplayKnown.ret "null") "[\"resample\"]" "[\"held_samples\", \"mine\"]"

def failsWith (pre : String) (x : Except String (Array String × Nat)) : Bool :=
  match x with
  | .error e => e.startsWith pre
  | .ok _ => false

-- F1: three turns (n = 1) that change nothing, then the twin's crash, by its name
#guard failsWith "crash: twin: resample ran out of fuel (n·(n+1)+1 turns for the n samples held at the first guard)"
  (replay spin 0)
-- F2: with col's cap 1, ask_sample goes on to `links`, which the tape does not hold there: a tape error, not the fuel
#guard failsWith "tape: " (replay spin 1)
#guard !failsWith "crash: twin: resample ran out of fuel" (replay spin 1)
-- F3: no sample held: the loop ends at once, and the record passes
#guard (match replay none_held 0 with
  | .ok (_, 0) => true
  | _ => false)

end SpecTwin.V2.FuelKnown
