import SpecTwin.V2.KeptKnown

/-! # A record's values in the forms of its document: known answers

The cases were written before the readers took the document. Each reads a value as a record writes it, under
protocol-v2.md (`Form.v2`) or `protocol.md` (`Form.v1`), and either reads the value it states or is refused with a
message that starts as quoted. Under each document the other's forms are refused. Each position of a record has
one reader, injective there: an IWANT that `protocol.md`'s code enqueues on its own reads into `Msg.iwant`, the one
constructor in that place, and a lane's IWANT under v2 into `.iwantV2`. -/

namespace SpecTwin.V2.FormsKnown

open Lean (Json)
open SpecTwin.Replay
open SpecTwin.V2

def readsAs {α} [BEq α] (x : Except String α) (v : α) : Bool :=
  match x with
  | .ok w => w == v
  | .error _ => false

def refusedWith {α} (pre : String) (x : Except String α) : Bool :=
  match x with
  | .error e => e.startsWith pre
  | .ok _ => false

/-- A group's key, as JSON and as a `Group`, and the structured id of chunk 3 of the group. -/
def g : String := String.ofList (List.replicate 64 'a')
def gq : String := s!"\"{g}\""
def gk : Group := g
def sid : String := g ++ "03000000" ++ String.ofList (List.replicate 40 '0')
def sidKey : Key := (Key.ofId sid).getD (.want gk 0)

#guard match Key.ofId sid with
  | some k => k.group == gk && k.index == 3
  | none => false

/-- An entry's value read from a record (`cell`, `val`), under the document `f`. -/
def valIn (table path value : String) (f : Form) : Except String (Option Val) := do
  val (← cell table (← Json.parse path)) (← Json.parse value) f

def ctlIn (s : String) (f : Form) : Except String Ctl := do ctl (← Json.parse s) f

def msgIn (s : String) (f : Form) : Except String Msg := do msg (← Json.parse s) f

/-! ## 1. `peer_has`'s entry -/

def ph (v : String) (f : Form) : Except String (Option Val) := valIn "peer_has" s!"[5, {gq}]" v f

#guard readsAs (ph "[2, 3, true, false]" .v2) (some (.have { bits := 2, ttl := 3, claimAll := true, complete := false }))
#guard readsAs (ph "[2, 3, false, true]" .v2) (some (.have { bits := 2, ttl := 3, claimAll := false, complete := true }))
#guard refusedWith "not an entry of peer_has under protocol-v2.md, [bits, ttl, claim_all, complete]: " (ph "[2, 3]" .v2)
-- the claims are JSON booleans
#guard refusedWith "not an entry of peer_has under protocol-v2.md, [bits, ttl, claim_all, complete]: "
  (ph "[2, 3, 1, 0]" .v2)
#guard readsAs (ph "[2, 3]" .v1) (some (.have { bits := 2, ttl := 3 }))
#guard refusedWith "not an entry of peer_has: " (ph "[2, 3, false, false]" .v1)

/-! ## 2. A lane's controls -/

-- an IWANT under v2: unmarked with a flagged ask; marked with a plain ask; an ask by structured id
#guard readsAs (ctlIn s!"[\"iwant\", [[[{gq}, 3], true, 2, false]], false]" .v2)
  (.iwantV2 false [{ key := .want gk 3, standing := true, hops := 2, probe := false }])
#guard readsAs (ctlIn s!"[\"iwant\", [[[{gq}, 3], false, 0, false]], true]" .v2) (.iwantV2 true [{ key := .want gk 3 }])
#guard readsAs (ctlIn s!"[\"iwant\", [[\"{sid}\", false, 0, false]], false]" .v2) (.iwantV2 false [{ key := sidKey }])
#guard refusedWith "under protocol-v2.md an IWANT is [\"iwant\", asks, want]: " (ctlIn s!"[\"iwant\", [[{gq}, 3]]]" .v2)
#guard refusedWith "not an ask with its flags: " (ctlIn s!"[\"iwant\", [[[{gq}, 3], false, 0]], false]" .v2)
#guard refusedWith "not a bool: " (ctlIn s!"[\"iwant\", [[[{gq}, 3], false, 0, false]], 0]" .v2)
-- an IWANT under protocol.md
#guard readsAs (ctlIn s!"[\"iwant\", [[{gq}, 3]]]" .v1) (.iwant [.want gk 3])
#guard refusedWith "not a control message of a queue entry: "
  (ctlIn s!"[\"iwant\", [[[{gq}, 3], false, 0, false]], false]" .v1)

-- an IDONTWANT under v2: a holding with its claims; a stock id beside one; a bitmap without claims refused
def stock : String := String.ofList (List.replicate 40 'b')
#guard readsAs (ctlIn s!"[\"idontwant\", [[\"holding\", {gq}, 5, true, true]]]" .v2)
  (.idontwant [.holding gk 5 true true])
#guard readsAs (ctlIn s!"[\"idontwant\", [\"{stock}\", [\"holding\", {gq}, 5, false, false]]]" .v2)
  (.idontwant [.other stock, .holding gk 5 false false])
#guard refusedWith "under protocol-v2.md an IDONTWANT's bitmap is a holding: "
  (ctlIn s!"[\"idontwant\", [[\"bits\", {gq}, 5]]]" .v2)
-- an IDONTWANT under protocol.md: a holding refused
#guard refusedWith "not an IHAVE's entry: " (ctlIn s!"[\"idontwant\", [[\"holding\", {gq}, 5, false, false]]]" .v1)

-- an IHAVE, under either document: a bitmap, and a holding refused
#guard readsAs (ctlIn s!"[\"ihave\", [[\"bits\", {gq}, 5]]]" .v2) (.ihave [.bitmap gk 5])
#guard readsAs (ctlIn s!"[\"ihave\", [[\"bits\", {gq}, 5]]]" .v1) (.ihave [.bitmap gk 5])
#guard refusedWith "not an IHAVE's entry: " (ctlIn s!"[\"ihave\", [[\"holding\", {gq}, 5, true, false]]]" .v2)
#guard refusedWith "not an IHAVE's entry: " (ctlIn s!"[\"ihave\", [[\"holding\", {gq}, 5, true, false]]]" .v1)

-- the relation controls under v2, each with its one message; gossipsub's PRUNE without one
def joinJ : String := "[\"join\", \"row\", \"DERIVED\", 0, \"FORWARD\", 1]"
def joinV : Relation :=
  .join { objectType := "row", interest := .derived, custodyCount := 0, duty := .forward, colours := 1 }
#guard readsAs (ctlIn s!"[\"join\", [{joinJ}]]" .v2) (.relation joinV)
#guard readsAs (ctlIn "[\"graft\", [[\"graft\", \"row\", [\"-\", 1], 0, \"OUT\", true]]]" .v2)
  (.relation (.graft { objectType := "row", family := -1, colour := 0, direction := .outward, answer := true }))
#guard readsAs (ctlIn "[\"prune\", [[\"prune\", \"column\", 3, 1, \"IN\"]]]" .v2)
  (.relation (.prune { objectType := "column", family := 3, colour := 1, direction := .inward }))
#guard readsAs (ctlIn "[\"prune\", []]" .v2) .prune
#guard refusedWith "a relation control holds one message: " (ctlIn "[\"join\", []]" .v2)
#guard refusedWith "a relation control holds one message: " (ctlIn s!"[\"join\", [{joinJ}, {joinJ}]]" .v2)
#guard refusedWith "a relation control's message is of another kind: " (ctlIn s!"[\"graft\", [{joinJ}]]" .v2)
-- under protocol.md a relation control is refused
#guard refusedWith "not a control message of a queue entry: " (ctlIn s!"[\"join\", [{joinJ}]]" .v1)

-- a whole lane of peer 5
def lane1 : String := s!"[[null, [[\"iwant\", [[[{gq}, 3], false, 0, false]], true]], false]]"
#guard readsAs (valIn "queue" "[5, \"normal\"]" lane1 .v2)
  (some (.lane [{ chunk := none, control := some [.iwantV2 true [{ key := .want gk 3 }]], solicited := false }]))
#guard refusedWith "not a control message of a queue entry: " (valIn "queue" "[5, \"normal\"]" lane1 .v1)

/-! ## 3. The nodes line's `types` -/

def w60 : Nat := (60.0 : Float).toBits.toNat
def w64 : Nat := (64.0 : Float).toBits.toNat
def wHalf : Nat := (0.5 : Float).toBits.toNat
def wInf : Nat := 9218868437227405312          -- +∞
def wNaN : Nat := 9221120237041090560          -- a NaN
def wNegInf : Nat := 18442240474082181120      -- −∞

#guard (Float.ofBits wInf.toUInt64) == (1.0 : Float) / 0
#guard (Float.ofBits wNaN.toUInt64).isNaN
#guard (Float.ofBits wNegInf.toUInt64) == -(1.0 : Float) / 0

def payload (members : String) : String := "{\"payload\": {" ++ members ++ "}}"
def typesIn (s : String) : Except String (List (TypeId × TypeParams)) := do typesOf (← Json.parse s)
def payloadOf (s : String) : Option TypeParams :=
  match typesIn s with
  | .ok l => l.lookup "payload"
  | .error _ => none

def full : String :=
  payload (s!"\"M\": 4, \"SYMMETRIC\": true, \"PRUNE_BACKOFF\": {w60}, \"ANNOUNCE_EXTRA\": \"SAMPLE\", " ++
    s!"\"EVIDENCE\": null, \"REPAIR_SAMPLE\": [[8, 2], [16, 4]], \"SERVE_LIMIT\": {w64}, " ++
    s!"\"FORWARD_LIMIT\": {wInf}, \"SAMPLE_WAIT\": {wHalf}, \"REPAIR_REASK\": false")

def bitsOf (x : Option Float) : Option Nat := x.map (·.toBits.toNat)

#guard (payloadOf full).map (·.M) == some (some 4)
#guard (payloadOf full).map (·.SYMMETRIC) == some (some true)
#guard (payloadOf full).map (bitsOf ·.PRUNE_BACKOFF) == some (some w60)
#guard (payloadOf full).map (·.ANNOUNCE_EXTRA) == some (some .sample)
#guard (payloadOf full).map (·.EVIDENCE) == some (some none)
#guard (payloadOf full).map (·.REPAIR_SAMPLE) == some (some (some [(8, 2), (16, 4)]))
#guard (payloadOf full).map (bitsOf ·.SERVE_LIMIT) == some (some w64)
#guard (payloadOf full).map (bitsOf ·.FORWARD_LIMIT) == some (some wInf)
#guard (payloadOf full).map (bitsOf ·.SAMPLE_WAIT) == some (some wHalf)
#guard (payloadOf full).map (·.REPAIR_REASK) == some (some false)
-- every other parameter is left out
#guard (payloadOf full).map (fun p =>
  p.F_LO.isNone && p.F_HI.isNone && p.D_OUT.isNone && p.D_OUT_FAST.isNone && p.D_OUT_MAX.isNone &&
  p.EAGER.isNone && p.REPAIR_BUDGET.isNone && p.DEFER_WINDOW.isNone && p.START_DELAY.isNone &&
  p.SAMPLE_RETRY.isNone && p.SAMPLE_RETRY2.isNone && p.SAMPLE_OUTSTANDING.isNone && p.SAMPLE_COVER.isNone &&
  p.COVER_HIGH.isNone && p.ROUTE_HOPS.isNone) == some true
-- a missing member and null differ
#guard (payloadOf (payload "\"REPAIR_SAMPLE\": null")).map (·.REPAIR_SAMPLE) == some (some none)
#guard (payloadOf (payload "\"M\": 4")).map (·.REPAIR_SAMPLE) == some none
-- refused, each naming its type and parameter
#guard refusedWith "types: payload: M: " (typesIn (payload "\"M\": 0"))
#guard refusedWith "types: payload: M: " (typesIn (payload "\"M\": [\"-\", 2]"))
#guard refusedWith "types: payload: D_OUT: " (typesIn (payload "\"D_OUT\": 1.5"))
#guard refusedWith "types: payload: SYMMETRIC: " (typesIn (payload "\"SYMMETRIC\": 1"))
#guard refusedWith "types: payload: PRUNE_BACKOFF: " (typesIn (payload s!"\"PRUNE_BACKOFF\": {wInf}"))
#guard refusedWith "types: payload: FORWARD_LIMIT: " (typesIn (payload s!"\"FORWARD_LIMIT\": {wNaN}"))
#guard refusedWith "types: payload: SERVE_LIMIT: " (typesIn (payload s!"\"SERVE_LIMIT\": {wNegInf}"))
#guard refusedWith "types: payload: ANNOUNCE_EXTRA: " (typesIn (payload "\"ANNOUNCE_EXTRA\": \"all_joined\""))
#guard refusedWith "types: payload: EVIDENCE: " (typesIn (payload "\"EVIDENCE\": \"row\""))
#guard refusedWith "types: payload: REPAIR_SAMPLE: " (typesIn (payload "\"REPAIR_SAMPLE\": [[8]]"))
#guard refusedWith "types: payload: not a type parameter: W_BYTES" (typesIn (payload "\"W_BYTES\": 1"))
#guard refusedWith "types: no payload type" (typesIn "{\"row\": {\"M\": 4}}")

/-! ## 4. A header as its descriptor -/

def rootA : String := String.ofList (List.replicate 64 'c')
def rootB : String := String.ofList (List.replicate 64 'd')
def descJ (r : String) : String := s!"[1, 2, 3, 4, 5, 6, \"{r}\"]"

def roundTrip (s : String) : Bool :=
  match Json.parse s with
  | .ok j => match descriptor j with
    | .ok d => descriptorJson d == j
    | .error _ => false
  | .error _ => false

#guard roundTrip (descJ rootA)
-- the toy header's form, with a field more, is refused
#guard refusedWith "not a descriptor: " (do descriptor (← Json.parse s!"[1, 2, 3, 4, 5, 6, \"{rootA}\", 7]"))
-- two headers that differ in their root alone differ
#guard match (do return (← descriptor (← Json.parse (descJ rootA))) != (← descriptor (← Json.parse (descJ rootB))) :
    Except String Bool) with
  | .ok b => b
  | .error _ => false

/-! ## 5. What an `enqueue` holds -/

/-- An IWANT of chunk 3, enqueued on its own, in v2's form: `marked` its mark, `standing` its ask's flag. -/
def iw (marked standing : Bool) : String := s!"[[\"iwant\", [[[{gq}, 3], {standing}, 0, false]], {marked}]]"

#guard readsAs (msgIn (iw false false) .v2) (.iwant [.want gk 3])
#guard refusedWith "an IWANT enqueued on its own is protocol.md's, unmarked: " (msgIn (iw true false) .v2)
#guard refusedWith "an IWANT enqueued on its own is protocol.md's, its asks plain: " (msgIn (iw false true) .v2)
#guard refusedWith "under protocol-v2.md an IWANT is [\"iwant\", asks, want]: " (msgIn s!"[[\"iwant\", [[{gq}, 3]]]]" .v2)
#guard readsAs (msgIn s!"[[\"iwant\", [[{gq}, 3]]]]" .v1) (.iwant [.want gk 3])
#guard refusedWith "not an IWANT, nor an IDONTWANT or an IHAVE of one bitmap: " (msgIn (iw false false) .v1)
-- `respond`'s entry: a lane's IWANT, then gossipsub's PRUNE
#guard readsAs
  (msgIn s!"[\"entry\", [null, [[\"iwant\", [[[{gq}, 3], false, 0, false]], false], [\"prune\", []]], false]]" .v2)
  (.entry { chunk := none, control := some [.iwantV2 false [{ key := .want gk 3 }], .prune], solicited := false })
-- an IDONTWANT of one bitmap has no v2 form here
#guard refusedWith "not an IDONTWANT of one bitmap: "
  (msgIn s!"[[\"idontwant\", [[\"holding\", {gq}, 5, false, false]]]]" .v2)
#guard refusedWith "under protocol-v2.md an IDONTWANT's bitmap is a holding: "
  (msgIn s!"[[\"idontwant\", [[\"bits\", {gq}, 5]]]]" .v2)

end SpecTwin.V2.FormsKnown
