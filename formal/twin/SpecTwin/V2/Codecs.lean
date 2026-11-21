import SpecTwin.ReplayTables

/-! # protocol-v2.md's tables as a record writes them: known answers

Each case reads an entry of one of v2's tables as a record writes it (its table, its path and its value, in the
forms of `tools/gen/schema_v2.py`), puts it into an empty state, and reads the state back (`cell`, `val`, `put`,
`valueAt`, all generated). The refusals are the record forms the reader must not take: an empty value where the
codec writes it as missing, an unsorted set, a non-finite time, a direction or a family in another form.
notes/spec-lean/v2-layer/design.md §4.4. -/

namespace SpecTwin.V2.Codecs

open Lean (Json)
open SpecTwin.Replay

/-- An entry read from a record, put into an empty state, and read back: the value the state then holds. -/
def back (table path value : String) : Except String (Option Val) := do
  let c ← cell table (← Json.parse path)
  match ← val c (← Json.parse value) with
  | none => return none
  | some v => return valueAt (← put {} c v) c

def reads (table path value : String) (v : Val) : Bool :=
  match back table path value with
  | .ok (some w) => w == v
  | _ => false

def refused (table path value : String) : Bool :=
  match back table path value with
  | .error _ => true
  | .ok _ => false

/-- A group's key, and a block id of the same form. -/
def g : String := "\"" ++ String.ofList (List.replicate 64 'a') ++ "\""
def gk : Group := String.ofList (List.replicate 64 'a')

/-- A structured id of chunk 3 of `gk`: the group, the index's four bytes little-endian, a content id. -/
def sid : String := String.ofList (List.replicate 64 'a') ++ "03000000" ++ String.ofList (List.replicate 40 '0')

/-- The two forms of one chunk's ask name two cells of `probe_asks` (`gated(a)`'s `a not in probe_asks`). -/
def twoForms : Except String Bool := do
  let a ← cell "probe_asks" (← Json.parse s!"[[{g}, 3]]")
  let b ← cell "probe_asks" (← Json.parse s!"[\"{sid}\"]")
  return a != b

-- per link and object type: a JOIN; the colours of a relation under a signed family; a relation list
#guard reads "join_recv" s!"[5, \"row\"]" "[\"join\", \"row\", \"DERIVED\", 0, \"FORWARD\", 1]"
  (.join { objectType := "row", interest := .derived, custodyCount := 0, duty := .forward, colours := 1 })
#guard refused "join_recv" s!"[5, \"row\"]" "[\"join\", \"row\", \"derived\", 0, \"FORWARD\", 1]"
#guard reads "push_out" "[5, \"row\", [\"-\", 1]]" "[0, 2]" (.colours [0, 2])
#guard refused "push_out" "[5, \"row\", [\"-\", 1]]" "[2, 0]"                 -- a set is written sorted
#guard refused "push_out" "[5, \"row\", [\"-\", 1]]" "[]"                     -- empty: written as missing
#guard refused "push_out" "[5, \"row\", -1]" "[0]"                            -- a family has no JSON sign
#guard reads "owed_relations" "[5]"
  "[[\"graft\", \"row\", [\"-\", 1], 0, \"OUT\", true], [\"prune\", \"column\", 3, 1, \"IN\"]]"
  (.relations [.graft { objectType := "row", family := -1, colour := 0, direction := .outward, answer := true },
               .prune { objectType := "column", family := 3, colour := 1, direction := .inward }])
#guard refused "owed_relations" "[5]" "[]"
-- backoff: four keys, the last a colour and a direction; its leaf a finite time with presence
#guard reads "backoff" "[5, \"row\", [\"-\", 1], [0, \"OUT\"]]" "4609434218613702656" (.time (1.5 : Float).toBits)
#guard refused "backoff" "[5, \"row\", [\"-\", 1], [0, \"OUT\"]]" "9218868437227405312"   -- +inf
#guard refused "backoff" "[5, \"row\", [\"-\", 1], [0, \"out\"]]" "4609434218613702656"
-- per group: a type id; an IBits, whose 0 is a value; a set whose empty value is a value; probe_ok's verdict
#guard reads "T_of" s!"[{g}]" "\"row\"" (.typeId "row")
#guard refused "T_of" s!"[{g}]" "\"\""
#guard reads "interest" s!"[{g}]" "0" (.ibits 0)
#guard reads "interest" s!"[{g}]" "[\"-\", 3]" (.ibits (-3))
#guard reads "claims" s!"[{g}]" "[]" (.peers [])
#guard reads "claims" s!"[{g}]" "[2, 7]" (.peers [2, 7])
#guard refused "claims" s!"[{g}]" "[7, 2]"
#guard reads "standing" s!"[{g}, 3]" "[]" (.peers [])
#guard reads "probe_ok" s!"[{g}]" "[\"none\"]" (.verdict none)
#guard reads "probe_ok" s!"[{g}]" "false" (.verdict (some false))
#guard reads "rsample" s!"[{g}]" "[3, 1, 2]" (.indices [3, 1, 2])          -- a list keeps its order
#guard refused "rsample" s!"[{g}]" "[]"
#guard reads "deferred" s!"[{g}]" "true" .flag
#guard reads "probe" s!"[{g}]" "0" (.slot 0)
#guard reads "probe_asks" s!"[[{g}, 3]]" "true" .flag
-- an ask key either way: by index, or a structured id of the same chunk, which is another member
#guard reads "probe_asks" s!"[\"{sid}\"]" "true" .flag
#guard twoForms.toOption == some true
#guard refused "probe_asks" "[\"abcd\"]" "true"                             -- an id of another length is no ask
-- per peer and group: a flag of two keys, false no value; an IBits with presence
#guard reads "probe_served" s!"[5, {g}]" "true" .flag
#guard refused "probe_served" s!"[5, {g}]" "false"
#guard reads "want_p" s!"[5, {g}]" "0" (.ibits 0)
#guard reads "probe_waiting" s!"[{g}, 5]" "0" (.slot 0)
-- per block: a signed count, 0 no value; groups and indices in order
#guard reads "samples_in_flight" s!"[{g}]" "[\"-\", 1]" (.int (-1))
#guard refused "samples_in_flight" s!"[{g}]" "0"
#guard reads "held_samples" s!"[{g}]" s!"[[{g}, 3], [{g}, 1]]" (.gis [(gk, 3), (gk, 1)])
#guard refused "held_samples" "[\"b\"]" s!"[[{g}, 3]]"                       -- a block id is 64 hex digits

-- a level read whole: `claims.items()`, and one group's `probe_waiting[g].items()`
#guard (level (Json.arr #[.str "claims", .arr #[]])).toOption == some .claims
#guard (level (Json.arr #[.str "probe_waiting", .arr #[.str gk]])).toOption == some (.probeWaiting gk)

end SpecTwin.V2.Codecs
