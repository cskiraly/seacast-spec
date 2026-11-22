import SpecTwin.Seacast.DispatchKnown

/-! # The v0.11.1 sync: its known answer

seacast.md's change from v0.10.11 to v0.11.1 in the twin's functions, case by case, written before the code:
G1 to G10 for the six functions that changed and `admitted`'s holding, then S2 for the two new ones. Each record is
a JSON line in the tracer's form, made by hand and replayed by `ReplayKnown`'s `passes` and `failsWith`, or, where
the serving budget matters, at a node whose constants the header's reader (`Header.constsSeacast`) reads from a nodes
entry's `consts`. The module names nothing the sync adds, so it compiles at the commit before the sync too, where
its cases of new behaviour fail: there the reader refuses the two new constants, and the replay runs with
`ReplayKnown`'s. -/

namespace SpecTwin.Seacast.SyncKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.Seacast
open SpecTwin.Seacast.ReplayKnown

/-- A block, and a second group of it. -/
def b : String := String.ofList (List.replicate 64 'd')
def bq : String := s!"\"{b}\""
def g2 : String := String.ofList (List.replicate 64 'c')
def g2q : String := s!"\"{g2}\""

def tog (x T : String) : String := s!"[\"type_of_group\", [{x}], \"{T}\"]"
def bo (x : String) : String := s!"[\"block_of\", [{x}], {bq}]"
def exp (x : String) (v : Bool := false) : String := s!"[\"expired\", [{x}], {v}]"

/-- SEACAST's five constants with this serving budget (a JSON value), read by the header's reader from a nodes entry's
`consts`; `ReplayKnown`'s where the reader refuses them -/
def budgetConsts (budget : String) : ConstsSeacast :=
  let five : List (String × Json) :=
    [("ANSWERS_FIRST", Json.bool false), ("ASK_UPLINK", DispatchKnown.word0), ("MERGE_HOLDINGS", Json.bool false),
     ("SAMPLE_OUTSTANDING", DispatchKnown.jn 1), ("SERVE_BUDGET", (Json.parse budget).toOption.getD Json.null)]
  match Header.constsSeacast (Json.mkObj (DispatchKnown.consts31 ++ five)) with
  | .ok (_, k) => k
  | .error _ => c2

/-- The type `row` has M = 4 and serves 64 chunks a peer and group. -/
def paramsB : TypeId → Option TypeParams := fun T =>
  if T == "row" then some { M := some 4, SERVE_LIMIT := some 64.0 } else none

def replayB (budget l : String) : Except String (Array String × Nat) := do
  runSeacast c0 (budgetConsts budget) paramsB [] traced (← record (← Json.parse l) docSeacast)

def passesB (budget l : String) : Bool :=
  match replayB budget l with
  | .ok (_, 0) => true
  | _ => false

/-! ## G1, `ask_sample`: the second phase's cap is the node's (1 here), not the type's -/

def g1 (inFlight : String) : String :=
  line "ask_sample" s!"[{gq}, 0, false]"
    s!"[[\"mine\", [{gq}], null], [\"samples_in_flight\", [{bq}], {inFlight}], [\"held_samples\", [{bq}], null]]"
    s!"[[\"held_samples\", [{bq}], [[{gq}, 0]]]]" "[]" s!"[{tog gq "row"}, {bo gq}, {exp gq}]" (ret "null")
    "[\"ask_sample\"]" "[\"held_samples\", \"mine\", \"samples_in_flight\"]"

#guard passes (g1 "1")                                            -- G1: one in flight, the cap: held back
#guard failsWith "tape: " (g1 "null")                             -- none in flight: it goes on to links

/-! ## G2 and G3, `resample` -/

-- G2: `b = block_of(g)` alone, no `type_of_group`
def g2r : String :=
  line "resample" s!"[{gq}, 0, 3, true]" s!"[[\"mine\", [{gq}], 1], [\"held_samples\", [{bq}], null]]" "[]" "[]"
    s!"[{bo gq}, {exp gq}]" (ret "null") "[\"resample\"]" "[\"held_samples\", \"mine\"]"

#guard passes g2r                                                 -- G2

-- G3: g expired: the decrement, no park and no re-ask, and the held sample popped and asked all the same
def g3 : String :=
  line "resample" s!"[{gq}, 0, 3, false]"
    s!"[[\"samples_in_flight\", [{bq}], 1], [\"held_samples\", [{bq}], [[{g2q}, 1]]], [\"mine\", [{g2q}], 2]]"
    s!"[[\"samples_in_flight\", [{bq}], null], [\"held_samples\", [{bq}], null]]" "[]"
    s!"[{bo gq}, {exp gq true}, {tog g2q "row"}, {bo g2q}]" (ret "null") "[\"ask_sample\", \"resample\"]"
    "[\"held_samples\", \"mine\", \"samples_in_flight\"]"

#guard passes g3                                                  -- G3

/-! ## G4, `fill` of a group not yet open: `release_wanted_groups`, `open_group`, `drop_wants_beyond`,
`drop_beyond`, then the duplicate's path of `ReplayKnown`'s r5 -/

/-- A descriptor of 4 chunks. -/
def descJ : String := s!"[1, 0, 0, 4, 8, 32, \"{root}\"]"

def g4 : String :=
  line "fill" s!"[{gq}, 3, {chunk3}, 5]"
    (s!"[[\"T_of\", [{gq}], null], [\"desc\", [{gq}], {descJ}], [\"standing\", [{gq}, 5], [7]], " ++
     s!"[\"routed_standing\", [{gq}, 5], [7]], [\"want_p\", [7, {gq}], 34], [\"state\", [{gq}], null], " ++
     s!"[\"received\", [{gq}], 8], [\"deferred\", [{gq}], null]]")
    s!"[[\"standing\", [{gq}, 5], null], [\"routed_standing\", [{gq}, 5], null], [\"want_p\", [7, {gq}], 2]]" "[]"
    (s!"[{exp gq}, [\"release_wanted_groups\", [], null], [\"open_group\", [{gq}, {chunk3}], null], " ++
     s!"{tog gq "row"}, [\"index_count\", [\"row\", {descJ}], 4], [\"keys\", \"tied\", [], []], " ++
     s!"[\"send_have\", [5, {gq}], null]]")
    (ret "null") "[\"N\", \"drop_beyond\", \"drop_wants_beyond\", \"fill\", \"probe_answer\"]"
    ("[\"T_of\", \"asked_at\", \"deferred\", \"desc\", \"offered\", \"offers\", \"received\", \"routed_standing\", " ++
     "\"standing\", \"state\", \"tied\", \"tried\", \"want_p\"]")
    (scans := s!"[[\"standing\", [{gq}]], [\"want_p\", []], [\"offered\", []], [\"offers\", []], [\"tried\", []], " ++
              "[\"asked_at\", []], [\"tied\", []]]")

#guard passes g4 (replaced := ["send_have"])                     -- G4

/-! ## G5, G6 and G10, `on_holding` -/

def hv (bits : Nat) (claimAll : Bool) : String := s!"[\"have\", {gq}, {bits}, false, {claimAll}, false]"
def adm (bits : Nat) (claimAll : Bool) (v : Bool) : String :=
  s!"[\"admitted\", [5, [\"holding\", {gq}, {bits}, {claimAll}, false]], {v}]"

def notAdmitted (fn : String) (claimAll : Bool) (out : String) : String :=
  line fn s!"[5, {hv 5 claimAll}]" "[]" "[]" "[]"
    s!"[{exp gq}, [\"valid_have\", [{hv 5 claimAll}], true], {adm 5 claimAll false}]" (ret out) s!"[\"{fn}\"]" "[]"

#guard passes (notAdmitted "on_holding" false "null")            -- G5: not admitted: nothing of peer_has touched
#guard passes (notAdmitted "on_holding" true "null")             -- G10: the holding form, with its claim
-- the answer is for that holding only: another one's bits are not answered
#guard failsWith "tape: "
  (line "on_holding" s!"[5, {hv 5 false}]" "[]" "[]" "[]"
    s!"[{exp gq}, [\"valid_have\", [{hv 5 false}], true], {adm 4 false false}]" (ret "null") "[\"on_holding\"]" "[]")

-- G6: a claim on a link that has not joined the type: no note_claim; bit 2 new, bit 1 held before and released too
def g6 (links : String) : String :=
  line "on_holding" s!"[5, {hv 6 true}]"
    s!"[[\"peer_has\", [5, {gq}], [2, 3, false, false]], [\"holders\", [{gq}, 2], null], [\"planned\", [{gq}], null]]"
    s!"[[\"peer_has\", [5, {gq}], [6, 3, true, false]], [\"holders\", [{gq}, 2], [5]]]" "[]"
    (s!"[{exp gq}, [\"valid_have\", [{hv 6 true}], true], {adm 6 true true}, {tog gq "row"}, " ++
     s!"[\"links\", [\"row\"], {links}], [\"window_release\", [5, {gq}, 2], null], " ++
     s!"[\"window_release\", [5, {gq}, 1], null]]")
    (ret "null") "[\"joined\", \"on_holding\"]" "[\"holders\", \"peer_has\", \"planned\"]"

#guard passes (g6 "[9]")                                          -- G6
#guard failsWith "reached: " (g6 "[5, 9]")                        -- joined: note_claim entered, not in the record

/-! ## G7, `on_offer` -/

#guard passes (notAdmitted "on_offer" false "[]")                -- G7: not admitted: no asks, no start delay

/-! ## G8 and G9, `serve_standing` -/

-- G8: the route marks go with the requests: `routed_standing[g][3]` erased, no standing request there
def g8 : String :=
  line "serve_standing" s!"[{gq}, 3]" s!"[[\"routed_standing\", [{gq}, 3], [7]], [\"standing\", [{gq}, 3], null]]"
    s!"[[\"routed_standing\", [{gq}, 3], null]]" "[]" "[[\"order\", \"serve_standing\", []]]" (ret "null")
    "[\"serve_standing\"]" "[\"routed_standing\", \"standing\"]"

#guard passes g8                                                  -- G8

/-- One standing request of peer 7 for chunk 3, with `offered_to[7][g]` and `served_hb[7]` as given (JSON), the
answer made or not. -/
def g9 (offered hb : String) (answered : Bool) (hbAfter : Option String) : String :=
  let hbRead := if offered == "null" then s!", [\"served_hb\", [7], {hb}]" else ""
  let reads := s!"[[\"routed_standing\", [{gq}, 3], null], [\"standing\", [{gq}, 3], [7]], " ++
    s!"[\"peer_has\", [7, {gq}], null], [\"served\", [7, {gq}], null], [\"offered_to\", [7, {gq}], {offered}]" ++
    hbRead ++ (if answered then s!", [\"pushed\", [7, {gq}], null]]" else "]")
  let hbWrite := match hbAfter with
    | some v => s!", [\"served_hb\", [7], {v}]"
    | none => ""
  let writes := s!"[[\"standing\", [{gq}, 3], null]" ++
    (if answered then s!"{hbWrite}, [\"served\", [7, {gq}], 1], [\"pushed\", [7, {gq}], [8, 0, 6]]]" else "]")
  let answer := if answered then
      s!", [\"read\", \"chunks\", [{gq}, 3], {chunk3}], [\"enqueue\", [7, [\"entry\", [{chunk3}, null, true]], false], true], " ++
      s!"{tog gq "row"}, [\"cross\", [\"row\", {gq}, 3], []]"
    else ""
  let tables := "[\"offered_to\", \"peer_has\"" ++ (if answered then ", \"pushed\"" else "") ++
    ", \"routed_standing\", \"served\"" ++ (if offered == "null" then ", \"served_hb\"" else "") ++ ", \"standing\"]"
  line "serve_standing" s!"[{gq}, 3]" reads writes "[]"
    (s!"[[\"order\", \"serve_standing\", [7]], {tog gq "row"}" ++ answer ++ "]") (ret "null")
    (if answered then "[\"fills\", \"note_push\", \"serve_standing\"]" else "[\"serve_standing\"]") tables

#guard passesB "1" (g9 "null" "null" true (some "1"))           -- G9: counted, under the budget: counted
#guard passesB "1" (g9 "null" "1" false none)                    -- G9: counted, at the budget: dropped
#guard passesB "1" (g9 "8" "1" true none)                        -- G9: asked on our offer: answered, not counted
#guard !passesB "null" (g9 "null" "1" false none)                -- no budget: never dropped

/-! ## S2, the two new functions -/

def joinedR (links out : String) : String :=
  line "joined" "[5, \"row\"]" "[]" "[]" "[]" s!"[[\"links\", [\"row\"], {links}]]" (ret out) "[\"joined\"]" "[]"

#guard passes (joinedR "[5, 9]" "true")
#guard passes (joinedR "[9]" "false")
#guard failsWith "return value: toy " (joinedR "[9]" "true")

/-- `drop_wants_beyond(g)` at 4 indices: standing requests at 1 and 5, a route mark at each, and three peers'
interest: 7's in g at 1 and 5, 8's in another group, 9's in g below 4. -/
def dwb (w7 : String) (out : List (String × String)) : String :=
  line "drop_wants_beyond" s!"[{gq}]"
    (s!"[[\"desc\", [{gq}], {descJ}], [\"standing\", [{gq}, 1], [7]], [\"standing\", [{gq}, 5], [8]], " ++
     s!"[\"routed_standing\", [{gq}, 5], [8]], [\"want_p\", [7, {gq}], {w7}], [\"want_p\", [8, {g2q}], 32], " ++
     s!"[\"want_p\", [9, {gq}], 3]]")
    (if out == ret "null" then
      s!"[[\"standing\", [{gq}, 5], null], [\"routed_standing\", [{gq}, 5], null], [\"want_p\", [7, {gq}], 2], " ++
      s!"[\"want_p\", [9, {gq}], 3]]"
     else s!"[[\"standing\", [{gq}, 5], null], [\"routed_standing\", [{gq}, 5], null]]")
    s!"[[\"routed_standing\", [{gq}, 1], [7]]]"
    s!"[{tog gq "row"}, [\"index_count\", [\"row\", {descJ}], 4]]" out "[\"drop_wants_beyond\"]"
    "[\"desc\", \"routed_standing\", \"standing\", \"want_p\"]"
    (scans := s!"[[\"standing\", [{gq}]], [\"want_p\", []]]")

#guard passes (dwb "34" (ret "null"))
-- a complemented interest: iterating it raises, as the toy's bitmap does
#guard passes (dwb "[\"-\", 1]" [("raises", "\"ValueError\"")])

end SpecTwin.Seacast.SyncKnown
