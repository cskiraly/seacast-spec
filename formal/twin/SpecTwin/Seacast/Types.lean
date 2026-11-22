/-! # The types of SEACAST's messages and tables (seacast.md §2, §3)

The abstract messages of seacast.md §2, the values their fields take, and the other types SEACAST's tables hold.
They sit below `Basic.lean`, which imports this file and names `Relation` in a queue entry's control (a JOIN,
GRAFT or PRUNE queued by `send`), and below the generated `State.lean`, whose v2 tables hold them
(`owed_relations`, `join_recv`, `join_sent`, `interest`). So this file uses core Lean only, and writes a group as
the `String` that `Basic.lean`'s `Group` is. (A WANT's asks with their flags, `AskSeacast`, hold a `Key`, so they are
`Basic.lean`'s.)

A bitmap of a message is a natural number: a bitmap that arrives from outside the node (a HAVE's, a WANT's,
`sample`'s argument) is never negative in a record, and the tracer refuses one that is. The toy would take a
negative HAVE in places, but no run makes one. -/

namespace SpecTwin.Seacast

/-- A bitmap that can be complemented: a Python int (`Bits.v`), negative where it holds every index but finitely
many. Its operations are in `V2/Basic.lean`. -/
abbrev IBits := Int

/-- An object type, by its id (`"payload"`, `"column"`, `"row"` in the toy): two types are equal where their ids
are. -/
abbrev TypeId := String

/-- A family (§1.3), the relation key: an int, since the toy's row family under custody alone is `-1`. -/
abbrev Fam := Int

/-- `InterestKind`: the Python's `ALL`, `DERIVED`, `DECLARED`. -/
inductive InterestKind where
  | all
  | derived
  | declared
  deriving BEq, Repr, Inhabited

/-- `Duty`: the Python's `FORWARD`, `NONE`. -/
inductive Duty where
  | forward
  | none
  deriving BEq, Repr, Inhabited

/-- `Direction`: the Python's `OUT`, `IN`, `BOTH` (`in` is a word of Lean's). -/
inductive Direction where
  | outward
  | inward
  | both
  deriving BEq, Repr, Inhabited, Hashable

/-- `AnnounceWidth`: the Python's `ALL_JOINED`, `SAMPLE`, `NONE` (§1.1's `ANNOUNCE_EXTRA`). -/
inductive AnnounceWidth where
  | allJoined
  | sample
  | none
  deriving BEq, Repr, Inhabited

/-- A link's uplink class: the Python's `FAST`, `HOME`. -/
inductive UplinkClass where
  | fast
  | home
  deriving BEq, Repr, Inhabited

/-- `repair_verdict`'s answer (§4.6): the Python's `REPAIRED`, `NOT_REPAIRED`, `ASKED`. -/
inductive RepairVerdict where
  | repaired
  | notRepaired
  | asked
  deriving BEq, Repr, Inhabited

/-- `Join` (§2): per link and object type, sent by both ends. -/
structure Join where
  objectType : TypeId
  interest : InterestKind
  custodyCount : Nat
  duty : Duty
  colours : Nat
  deriving BEq, Repr, Inhabited

/-- `Graft` (§2): relation maintenance, per family and colour; also the yes to one. -/
structure Graft where
  objectType : TypeId
  family : Fam
  colour : Nat
  direction : Direction
  answer : Bool
  deriving BEq, Repr, Inhabited

/-- `Prune` (§2): the no to a GRAFT, or the end of a relation. -/
structure Prune where
  objectType : TypeId
  family : Fam
  colour : Nat
  direction : Direction
  deriving BEq, Repr, Inhabited

/-- A relation message, as `send` queues it under upkeep and `owed_relations` holds it. -/
inductive Relation where
  | join (m : Join)
  | graft (m : Graft)
  | prune (m : Prune)
  deriving BEq, Repr, Inhabited

/-- `Have` (§2): what the sender holds. An offer's two claims are false. -/
structure Have where
  group : String
  bits : Nat
  offer : Bool
  claimAll : Bool
  complete : Bool
  deriving BEq, Repr, Inhabited

/-- `Want` (§2): "send me these", to this peer only. -/
structure Want where
  group : String
  bits : Nat
  standing : Bool
  hops : Nat
  probe : Bool
  deriving BEq, Repr, Inhabited

/-- A message `send(p, msg, urgent)` takes. -/
inductive MsgSeacast where
  | have (m : Have)
  | want (m : Want)
  | relation (m : Relation)
  deriving BEq, Repr, Inhabited

end SpecTwin.Seacast
