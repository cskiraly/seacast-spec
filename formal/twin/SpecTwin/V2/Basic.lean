import SpecTwin.Basic
import SpecTwin.V2.Types

/-! # The v2 layer's basic types: bitmaps that can be complemented (protocol-v2.md §3)

`EVERY_INDEX` is the toy's `Bits(-1)`, and interest flows into bitmaps through `&`, `|` and `~` on Python ints, so a
bitmap that interest reaches is an `IBits`, an `Int` read in two's complement, as Python reads it. Core Lean has
`~~~` on `Int` but no `&&&` or `|||`, so the operations are defined here through `Nat`'s, on the two cases of an
`Int`: `ofNat a`, whose set bits are `a`'s, and `negSucc m`, which is `~m`, whose set bits are every bit `m` lacks.
The `#guard` cases below are Python's own values (`python3 -c`), over both signs.

The typing rule (notes/spec-lean/v2-layer/design.md §2): `Bits & IBits` is a `Bits` (`Bits.andI`), since one side
is not negative; `IBits & ~Bits` and `IBits | Bits` are `IBits`. -/

namespace SpecTwin.V2

/-- A `Bits` as an `IBits` (`IBits` is in `V2/Types.lean`). -/
def IBits.ofBits (b : Bits) : IBits := Int.ofNat b

/-- `~a` -/
def IBits.not : IBits → IBits
  | .ofNat a => .negSucc a
  | .negSucc m => .ofNat m

/-- `a & b` -/
def IBits.and : IBits → IBits → IBits
  | .ofNat a, .ofNat b => .ofNat (a &&& b)
  | .ofNat a, .negSucc m => .ofNat (Bits.minus a m)            -- `a & ~m`
  | .negSucc m, .ofNat b => .ofNat (Bits.minus b m)
  | .negSucc m, .negSucc n => .negSucc (m ||| n)              -- `~m & ~n == ~(m | n)`

/-- `a | b` -/
def IBits.or : IBits → IBits → IBits
  | .ofNat a, .ofNat b => .ofNat (a ||| b)
  | .ofNat a, .negSucc m => .negSucc (Bits.minus m a)          -- `a | ~m == ~(m & ~a)`
  | .negSucc m, .ofNat b => .negSucc (Bits.minus m b)
  | .negSucc m, .negSucc n => .negSucc (m &&& n)              -- `~m | ~n == ~(m & n)`

/-- `a & ~b` -/
def IBits.minus (a b : IBits) : IBits := IBits.and a (IBits.not b)

/-- `a.has(i)`: `(a >> i) & 1 == 1` -/
def IBits.has : IBits → Nat → Bool
  | .ofNat a, i => a.testBit i
  | .negSucc m, i => !(m.testBit i)

/-- `not a` (`Bits.__bool__`): no index at all. -/
def IBits.empty (a : IBits) : Bool := a == 0

/-- `b & a`, a `Bits` masked by an `IBits`: never negative, so a `Bits` again. -/
def Bits.andI (b : Bits) : IBits → Bits
  | .ofNat a => b &&& a
  | .negSucc m => Bits.minus b m

/-- An `IBits` where the Python iterates or counts it: none for a negative one, where the toy raises `ValueError`
("iterating a complemented bitmap", `toy/bits.py:74-77`; "popcount of a complemented bitmap", `toy/bits.py:89-93`).
The caller crashes with that message at the Python's place. -/
def IBits.toBits? : IBits → Option Bits
  | .ofNat a => some a
  | .negSucc _ => none

/-- A type's 25 constant parameters: §1.1's `TypeParams` less its three functions (`DECODE_AT_K`, `DECODE_LATER`,
`REPAIR_TO`, which are questions), and the three the code reads beyond the class (`REPAIR_SAMPLE`, `SAMPLE_WAIT`,
`REPAIR_REASK`). Each is optional: the toy gives its payload and row types no `SAMPLE_RETRY2`,
`SAMPLE_OUTSTANDING`, `SAMPLE_COVER`, `COVER_HIGH`, `ROUTE_HOPS` or `FORWARD_LIMIT` (`toy/node.py:1231-1243`,
`toy/node.py:1318-1339`), and a read of a missing one raises `AttributeError` there, as it crashes here. The two
limits that can be unbounded are floats, infinity for none. -/
structure TypeParams where
  M : Option Nat := none
  F_LO : Option Nat := none
  F_HI : Option Nat := none
  D_OUT : Option Nat := none
  D_OUT_FAST : Option Nat := none
  D_OUT_MAX : Option Nat := none
  SYMMETRIC : Option Bool := none
  PRUNE_BACKOFF : Option Float := none
  ANNOUNCE_EXTRA : Option AnnounceWidth := none
  EAGER : Option Bool := none
  REPAIR_BUDGET : Option Bool := none
  DEFER_WINDOW : Option Float := none
  START_DELAY : Option Float := none
  SERVE_LIMIT : Option Float := none
  SAMPLE_RETRY : Option Float := none
  SAMPLE_RETRY2 : Option Float := none
  SAMPLE_OUTSTANDING : Option Nat := none
  SAMPLE_COVER : Option Nat := none
  COVER_HIGH : Option Nat := none
  ROUTE_HOPS : Option Nat := none
  FORWARD_LIMIT : Option Float := none
  /-- Present and none in this version (§1.5): the nodes line refuses any other value. -/
  EVIDENCE : Option (Option TypeId) := none
  /-- The repair sample's steps `[(S1, L1), …]`, or none (§4.6's `repair_verdict`). -/
  REPAIR_SAMPLE : Option (Option (List (Nat × Nat))) := none
  SAMPLE_WAIT : Option Float := none
  REPAIR_REASK : Option Bool := none
  deriving Repr, Inhabited

/-! ## Python's values -/

-- and
#guard IBits.and (0) (0) == (0)
#guard IBits.and (0) (255) == (0)
#guard IBits.and (0) (-13) == (0)
#guard IBits.and (5) (12) == (4)
#guard IBits.and (5) (-6) == (0)
#guard IBits.and (12) (5) == (4)
#guard IBits.and (12) (-1) == (12)
#guard IBits.and (12) (-256) == (0)
#guard IBits.and (255) (0) == (0)
#guard IBits.and (255) (255) == (255)
#guard IBits.and (255) (-13) == (243)
#guard IBits.and (-1) (12) == (12)
#guard IBits.and (-1) (-6) == (-6)
#guard IBits.and (-6) (5) == (0)
#guard IBits.and (-6) (-1) == (-6)
#guard IBits.and (-6) (-256) == (-256)
#guard IBits.and (-13) (0) == (0)
#guard IBits.and (-13) (255) == (243)
#guard IBits.and (-13) (-13) == (-13)
#guard IBits.and (-256) (12) == (0)
#guard IBits.and (-256) (-6) == (-256)
-- or
#guard IBits.or (0) (5) == (5)
#guard IBits.or (0) (-1) == (-1)
#guard IBits.or (0) (-256) == (-256)
#guard IBits.or (5) (0) == (5)
#guard IBits.or (5) (255) == (255)
#guard IBits.or (5) (-13) == (-9)
#guard IBits.or (12) (12) == (12)
#guard IBits.or (12) (-6) == (-2)
#guard IBits.or (255) (5) == (255)
#guard IBits.or (255) (-1) == (-1)
#guard IBits.or (255) (-256) == (-1)
#guard IBits.or (-1) (0) == (-1)
#guard IBits.or (-1) (255) == (-1)
#guard IBits.or (-1) (-13) == (-1)
#guard IBits.or (-6) (12) == (-2)
#guard IBits.or (-6) (-6) == (-6)
#guard IBits.or (-13) (5) == (-9)
#guard IBits.or (-13) (-1) == (-1)
#guard IBits.or (-13) (-256) == (-13)
#guard IBits.or (-256) (0) == (-256)
#guard IBits.or (-256) (255) == (-1)
#guard IBits.or (-256) (-13) == (-13)
-- minus
#guard IBits.minus (0) (12) == (0)
#guard IBits.minus (0) (-6) == (0)
#guard IBits.minus (5) (5) == (0)
#guard IBits.minus (5) (-1) == (0)
#guard IBits.minus (5) (-256) == (5)
#guard IBits.minus (12) (0) == (12)
#guard IBits.minus (12) (255) == (0)
#guard IBits.minus (12) (-13) == (12)
#guard IBits.minus (255) (12) == (243)
#guard IBits.minus (255) (-6) == (5)
#guard IBits.minus (-1) (5) == (-6)
#guard IBits.minus (-1) (-1) == (0)
#guard IBits.minus (-1) (-256) == (255)
#guard IBits.minus (-6) (0) == (-6)
#guard IBits.minus (-6) (255) == (-256)
#guard IBits.minus (-6) (-13) == (8)
#guard IBits.minus (-13) (12) == (-13)
#guard IBits.minus (-13) (-6) == (1)
#guard IBits.minus (-256) (5) == (-256)
#guard IBits.minus (-256) (-1) == (0)
#guard IBits.minus (-256) (-256) == (0)
-- has
#guard IBits.has (0) 0 == false
#guard IBits.has (0) 2 == false
#guard IBits.has (0) 3 == false
#guard IBits.has (0) 9 == false
#guard IBits.has (5) 0 == true
#guard IBits.has (5) 2 == true
#guard IBits.has (5) 3 == false
#guard IBits.has (5) 9 == false
#guard IBits.has (12) 0 == false
#guard IBits.has (12) 2 == true
#guard IBits.has (12) 3 == true
#guard IBits.has (12) 9 == false
#guard IBits.has (255) 0 == true
#guard IBits.has (255) 2 == true
#guard IBits.has (255) 3 == true
#guard IBits.has (255) 9 == false
#guard IBits.has (-1) 0 == true
#guard IBits.has (-1) 2 == true
#guard IBits.has (-1) 3 == true
#guard IBits.has (-1) 9 == true
#guard IBits.has (-6) 0 == false
#guard IBits.has (-6) 2 == false
#guard IBits.has (-6) 3 == true
#guard IBits.has (-6) 9 == true
#guard IBits.has (-13) 0 == true
#guard IBits.has (-13) 2 == false
#guard IBits.has (-13) 3 == false
#guard IBits.has (-13) 9 == true
#guard IBits.has (-256) 0 == false
#guard IBits.has (-256) 2 == false
#guard IBits.has (-256) 3 == false
#guard IBits.has (-256) 9 == true
-- not
#guard IBits.not (0) == (-1)
#guard IBits.not (5) == (-6)
#guard IBits.not (12) == (-13)
#guard IBits.not (255) == (-256)
#guard IBits.not (-1) == (0)
#guard IBits.not (-6) == (5)
#guard IBits.not (-13) == (12)
#guard IBits.not (-256) == (255)
-- Bits & IBits
#guard Bits.andI 0 (0) == 0
#guard Bits.andI 0 (5) == 0
#guard Bits.andI 0 (12) == 0
#guard Bits.andI 0 (255) == 0
#guard Bits.andI 0 (-1) == 0
#guard Bits.andI 0 (-6) == 0
#guard Bits.andI 0 (-13) == 0
#guard Bits.andI 0 (-256) == 0
#guard Bits.andI 5 (0) == 0
#guard Bits.andI 5 (5) == 5
#guard Bits.andI 5 (12) == 4
#guard Bits.andI 5 (255) == 5
#guard Bits.andI 5 (-1) == 5
#guard Bits.andI 5 (-6) == 0
#guard Bits.andI 5 (-13) == 1
#guard Bits.andI 5 (-256) == 0
#guard Bits.andI 12 (0) == 0
#guard Bits.andI 12 (5) == 4
#guard Bits.andI 12 (12) == 12
#guard Bits.andI 12 (255) == 12
#guard Bits.andI 12 (-1) == 12
#guard Bits.andI 12 (-6) == 8
#guard Bits.andI 12 (-13) == 0
#guard Bits.andI 12 (-256) == 0
#guard Bits.andI 255 (0) == 0
#guard Bits.andI 255 (5) == 5
#guard Bits.andI 255 (12) == 12
#guard Bits.andI 255 (255) == 255
#guard Bits.andI 255 (-1) == 255
#guard Bits.andI 255 (-6) == 250
#guard Bits.andI 255 (-13) == 243
#guard Bits.andI 255 (-256) == 0

/-! ## The new constructors in `protocol.md`'s pure case analyses (D1)

`QEntry.asks` reads every IWANT, marked or not, as the toy's `entry.iwants()` does, and drops the flags; a
relation and a holding hold no ask. `Ctl.isEmpty` is the toy's `_Msg.empty`: an IWANT with no asks is empty, a
relation never is (notes/spec-lean/v2-layer/design.md §4.3). -/

private def k1 : Key := .want "g" 1
private def k2 : Key := .want "g" 2
private def rel : Relation := .prune { objectType := "payload", family := -1, colour := 0, direction := .outward }
private def ctlE (cs : List Ctl) : QEntry := { chunk := none, control := some cs, solicited := false }

#guard (ctlE [.iwantV2 true [{ key := k1, standing := true, hops := 2 }, { key := k2 }]]).asks == [k1, k2]
#guard (ctlE [.iwantV2 false [{ key := k1, probe := true }]]).asks == [k1]
#guard (ctlE [.iwant [k2], .iwantV2 true [{ key := k1 }]]).asks == [k2, k1]
#guard (ctlE [.relation rel, .idontwant [.holding "g" 5 true false]]).asks == []
#guard (ctlE [.iwantV2 true []]).asks == []
#guard (Ctl.iwantV2 true []).isEmpty
#guard !(Ctl.iwantV2 false [{ key := k1 }]).isEmpty
#guard !(Ctl.relation rel).isEmpty
#guard (Ctl.idontwant [.holding "g" 0 false false]).isEmpty == false
#guard (Ctl.idontwant []).isEmpty
#guard (ctlE [.iwantV2 true []]).isEmpty
#guard !(ctlE [.relation rel]).isEmpty

end SpecTwin.V2
