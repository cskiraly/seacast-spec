import SpecTwin.Seacast.ReplayKnown

/-! # `resample`'s fuel: its known answer

`held_samples[b]` is kept per block, and `SAMPLE_OUTSTANDING` is the node's, one cap for every type. `resample`
loops while the block holds samples and the cap is not reached, and `ask_sample` holds a popped sample back only
where the cap is reached. The loop's guard and that test read the same number, and nothing changes
`samples_in_flight` between them, so a popped sample is never held again: the twin's loop has `n+1` turns for the n
samples held at the first guard, n removals and one exit test, and running out of them is a crash of the twin's own
name. (Before the cap was the node's, a type's cap below the loop's could hold a sample back on every turn, and the
Python's loop did not end.) The records here are made by hand, in the tracer's form, and replayed by `runSeacast` as
`ReplayKnown`'s are. -/

namespace SpecTwin.Seacast.FuelKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.Seacast

/-- Two groups of one block: g of type `row`, g2 of type `col`. -/
def g : String := String.ofList (List.replicate 64 'a')
def g2 : String := String.ofList (List.replicate 64 'c')
def b : String := String.ofList (List.replicate 64 'b')
def q (s : String) : String := s!"\"{s}\""

/-- At `ReplayKnown`'s node: its constants, `SAMPLE_OUTSTANDING` 1 among them. -/
def replay (l : String) : Except String (Array String × Nat) := do
  runSeacast ReplayKnown.c0 ReplayKnown.c2 ReplayKnown.params [] ReplayKnown.traced (← record (← Json.parse l) docSeacast)

def tog (x T : String) : String := s!"[\"type_of_group\", [{q x}], \"{T}\"]"
def bo (x : String) : String := s!"[\"block_of\", [{q x}], {q b}]"
def exp (x : String) : String := s!"[\"expired\", [{q x}], false]"

/-- The tape: g's block and `expired`, then for each turn g2's type and block, which `ask_sample` asks before it
finds the index held. -/
def tape (turns : Nat) : String :=
  "[" ++ ", ".intercalate ([bo g, exp g] ++ (List.replicate turns [tog g2 "col", bo g2]).flatten) ++ "]"

/-- `resample(g, 0, 3, True)`: `mine[g]` holds index 0; `held_samples[b]` holds g2's indices 0 and 1, which
`mine[g2]` holds; nothing in flight. -/
def drain : String :=
  ReplayKnown.line "resample" s!"[{q g}, 0, 3, true]"
    (s!"[[\"mine\", [{q g}], 1], [\"held_samples\", [{q b}], [[{q g2}, 0], [{q g2}, 1]]], " ++
     s!"[\"samples_in_flight\", [{q b}], null], [\"mine\", [{q g2}], 3]]")
    s!"[[\"held_samples\", [{q b}], null]]" "[]" (tape 2) (ReplayKnown.ret "null") "[\"ask_sample\", \"resample\"]"
    "[\"held_samples\", \"mine\", \"samples_in_flight\"]"

/-- `resample(g, 0, 3, False)` with two in flight: one ends, and the one left fills the cap of 1. -/
def capped : String :=
  ReplayKnown.line "resample" s!"[{q g}, 0, 3, false]"
    (s!"[[\"mine\", [{q g}], 1], [\"held_samples\", [{q b}], [[{q g2}, 0]]], " ++
     s!"[\"samples_in_flight\", [{q b}], 2]]")
    s!"[[\"samples_in_flight\", [{q b}], 1]]" "[]" (tape 0) (ReplayKnown.ret "null") "[\"resample\"]"
    "[\"held_samples\", \"mine\", \"samples_in_flight\"]"

/-- The same call as `drain` with no sample held. -/
def none_held : String :=
  ReplayKnown.line "resample" s!"[{q g}, 0, 3, true]"
    s!"[[\"mine\", [{q g}], 1], [\"held_samples\", [{q b}], null]]"
    "[]" "[]" (tape 0) (ReplayKnown.ret "null") "[\"resample\"]" "[\"held_samples\", \"mine\"]"

def passes (x : Except String (Array String × Nat)) : Bool :=
  match x with
  | .ok (_, 0) => true
  | _ => false

def failsWith (pre : String) (x : Except String (Array String × Nat)) : Bool :=
  match x with
  | .error e => e.startsWith pre
  | .ok _ => false

-- F1: two samples held (n = 2), each popped and found held, then the empty list: n+1 turns, all of the fuel
#guard passes (replay drain)
-- F2: the cap reached at the first guard: nothing popped
#guard passes (replay capped)
-- F3: no sample held: the loop ends at once
#guard passes (replay none_held)

end SpecTwin.Seacast.FuelKnown
