# SEACAST: the protocol on its own notions

> This document defines SEACAST, and its decisions are taken (§8). It is checked in the toy only;
> no client runs it, and the research harness's simulations ran only designs that it contains as
> settings (§6.2). It is not model-checked, except that §4.1's JOIN and answered GRAFT (messages
> defined in §2) were checked exhaustively for one link and one relation in small bounds.

*SEACAST stands for Segmented, Encoded, Availability-sampled broadCAST (the E could also read
Elastic). The name dates from 2026-10-19; `seacast-lite.md`'s protocol, now SEACAST Lite, was
published at v0.4 as Informed Diffusion, which now names SEACAST's diffusion part (§0, "The
parts"). Up to v0.11.1 this file was `protocol-v2.md` and `seacast-lite.md` was `protocol.md`. The
toy runs this document with `--doc seacast`.*

*This document began as draft 1, of 2026-10-07. It is a sibling of [`seacast-lite.md`](seacast-lite.md),
which defines SEACAST Lite; SEACAST contains that protocol as its tier 4 setting, with the
differences that §6.1 lists. That document was draft v0.3 when this was written and has been
v0.13.0-rc.1 since 2026-11-25, with the same section numbers. Below, `seacast-lite.md` means that document
as it is now, and "v0.3" means draft v0.3 itself, for its own rules.*

*Each later version of `seacast-lite.md` is carried into this document in the same way; §5 maps what
carries over, and [`seacast-decisions.md`](seacast-decisions.md) lists the versions
carried.*

*This document defines the notions, the messages, the state and the event handlers; the scheduling
that tier 4 (§6.2) measured carries over unchanged where §5 says so. Every design decision is
marked `[D1]` … `[D12]`, and [`seacast-decisions.md`](seacast-decisions.md) records where
each bites and what was decided (§8). The toy runs this document on top of `seacast-lite.md`'s
(`toy/run.py --doc seacast`): `seacast-lite.md`'s blocks are loaded first, this document's after them, and
the tier 4 setting is checked against its own recorded cells, which §6.1 compares with
`seacast-lite.md`'s. Draft 0 (2026-10-06) was written without running; draft 1 is what executing it
changed.*

*[`seacast-figures.md`](seacast-figures.md) gives the figures behind this document's
reasons, each with its conditions.*

## 0. How to read this

**How it is organized.**
- §1 to §3 define the notions (§1), the messages (§2) and the state a node keeps (§3).
- §4 defines what a node does at each event: joining and keeping its relations, the arrival of each
  message, forwarding, completion and repair, publishing, the heartbeat, sampling and sending.
- §5 maps what carries over from `seacast-lite.md` unchanged.
- §6 gives the settings: `seacast-lite.md` as one, the five designs, and the parameters, limits and
  constants.
- §7 says what every binding provides, and what the bindings differ in.
- §8 points to the record of the decisions.
- The glossary, after §8, defines the document's terms and its labels.

**Three companion documents** go with this one:
- [`seacast-bindings.md`](seacast-bindings.md) defines the bindings: how each carries the
  messages, SEACAST's message encoding, and the bytes of the libp2p stream and Waggle bindings.
- [`seacast-decisions.md`](seacast-decisions.md) records each decision: when it was taken,
  what was not taken and why, and the runs behind it.
- [`seacast-figures.md`](seacast-figures.md) gives the figures behind the reasons, the toy's
  and a few of the research harness's, each with its conditions.

Gossipsub bundles its notions: a *topic* is the namespace, the unit of subscription, the unit of
the mesh, the scope of scoring and the rendezvous; a *subscription* means "everything here", is
announced to every peer and invites GRAFTs; the *mesh* is one symmetric pusher set per topic and the
scope of IDONTWANT; *gossip* is message ids sent to a few random non-mesh peers per heartbeat.
`seacast-lite.md` runs inside those notions and loosens them from within: it uses chunks as messages,
carries HAVE bitmaps inside IDONTWANT and IHAVE and asks by index inside IWANT, and its source
stripes over every connection. This document unbundles them. What a node receives (*interest*), what
it does for others (*duty*), whom it pushes to and for which indices (the *push relation*, per
family and colour: §1.1, §1.4), whom it tells what it holds (the *announce relation*), and where it
finds peers (*rendezvous*) are five separate things, each with its own parameter. Variant C of the
posts, one topic per index with everyone subscribed, and `seacast-lite.md`, one topic with one mesh, are
two settings of the same protocol (§6).

**What is assumed and not restated.** The consensus-side objects and their verification are
assumed: the payload's descriptor committed in the bid and its Merkle tree over Reed–Solomon chunks
(`seacast-lite.md` §1), the `DataColumnSidecar` header and the KZG cell proofs (Fulu `das-core`, the
partial-columns spec), and RowDAS's rows (EIP-8371). Rendezvous and discovery are assumed: how a
node finds peers that share an object type and a family (gossipsub topics where they exist, the
ENR's `cgc` and node ids); this document assumes a set of connected peers per object type and
defines what happens on those connections. On the bindings that run on libp2p, the libp2p
connection and its framing are assumed. The native QUIC binding, a draft, runs on a QUIC connection
of its own, with framing of its own (`seacast-bindings.md` §7). Gossipsub itself is *not*
assumed: what it provided, the pusher set, suppression, announcements and pulls, is defined here,
and the bindings (§7, `seacast-bindings.md`) say how the result is carried on gossipsub's wire
where that is the deployed path. `seacast-lite.md`'s code is assumed where §5 says a function carries
over: this document redefines what changes and names what it keeps.

**What is normative.** Sections 1 to 3, the notions, the messages and the state, are what both ends
of a link must agree on. Section 4 combines each node's local scheduling with the meaning of the
messages: what a holding, an offer, an ask, a claim and an acknowledgement promise. A client may
schedule differently without breaking interoperability, provided those meanings hold. Section 5
names `seacast-lite.md`'s scheduling that carries over, section 6 the settings, section 7 the
bindings and section 8 the decisions, with what was not taken.

**The parts.** SEACAST has six parts, named for what they do. Three carry message semantics that
both ends must share; two are local policy, which a client may change while the meanings hold; the
last says how the messages travel. Named mechanisms inside a part keep their own names.

| part | what it does | sections | mechanisms inside |
|---|---|---|---|
| joins and relations | declares interest and duty per link; keeps the push and announce relations per family and colour, with their directions and floors, and a sampler's coverage floor | §1.2–1.4, §4.1 | coloured push relations |
| Informed Diffusion | pushes chunks into interest, tells holdings and offers, answers and makes asks | §1.5, §4.2–4.5, §4.10 | standing sample requests, routed sample requests (§4.10) |
| completion and repair | the claims, completion per interest, decoding at K, rebuilt chunks, deferral, the probe, evidence | §1.5, §4.6 | |
| informed scheduling *(local)* | what a node sends next and when: the window in bytes, the projection, the next entry, pacing, the ask window | §4.9, §4.11–4.13 | the byte window |
| source distribution *(local)* | how a source releases a group: batch order, striping, its paced holding; any node holding chunks first is a source (§1.6) | §4.7 | striped publishing |
| wire bindings | how the messages travel: the libp2p stream, Waggle, gossipsub and partial-messages bindings (`seacast-bindings.md` §2 to §5), and the native QUIC binding as a draft (§7 there) | §7; `seacast-bindings.md` | |

The heartbeat (§4.8) drives three of them: relation upkeep, announcement gossip and pacing.
Outside the parts, and assumed above, are the object type's interface (§1.1: indices,
verification, decoding, projection across groups) and peer discovery, with the connectivity that
repair's floor and sampling's coverage floor ask of it (§4.6, `REPAIR_FLOOR`; §1.3,
`SAMPLE_COVER`). *Colour* partitions a group's indices; it is not a subnet. *Family* is the key of
a relation, not necessarily a custody group.

**Conventions.** The code is Python-like pseudocode in the style of the consensus specs, as in
`seacast-lite.md`. A comment `# [c8]` marks a card of the posts (`seacast-lite.md`'s introduction lists the
cards and the posts), and `# [D5]` marks one of §8's decisions, where it bites. State and helpers
keep `seacast-lite.md`'s names wherever the object is the same (`peer_has`, `pushed`, `holders`,
`mine`, `received`); the header of a group is `seacast-lite.md`'s `desc`, read here as `hdr`. New
helpers are listed in §3.

**Requirement labels.** The requirement labels the text cites, such as I3 or R5, and the tag [P4]
are defined in the glossary.

**Numbers.** The figures measured for this draft, each with its conditions, are in
[`seacast-figures.md`](seacast-figures.md), grouped by the section that cites them.

## 1. Notions

### 1.1 Objects, groups, chunks, families

An **object type** `T` is the consensus side's contribution: what an index space is, how one chunk
is verified alone (level 1), how a set of chunks is checked for consistency and what a holder of
enough chunks can rebuild (level 2, one operation: decode, re-encode, compare), how a receiver
learns the header that the verifier needs, and how a chunk maps onto groups.

```python
class ObjectType:                                    # T: one kind of object, a protocol parameter
    name: str
    index_count: Callable[[Header], int]             # N: indices of a group, from its header
    threshold: Callable[[Header], int]               # K: chunks from which the whole object follows
    verify: Callable[[Chunk, Optional[Header]], Result]   # level 1, one chunk: ACCEPT | REJECT | DEFER
    decode: Callable[[Dict[int, Chunk], Header], Optional[Dict[int, Chunk]]]   # level 2: every
                                                     #   chunk of the group, or None if inconsistent
    header_of: Callable[[Chunk], Optional[Header]]   # what the chunk or the block supplies; None: gate closed
    project: Callable[[Chunk], List[Tuple[GroupId, int]]]   # every (group, index) one chunk fills
    cross: Callable[[GroupId, int], List[Tuple[GroupId, int]]]   # the other (group, index) pairs of the chunk
                                                     #   at index i of g, from the ids alone (R4)
    family: Callable[[GroupId], FamilyId]            # the relation key (§1.3)
    derived_interest: Callable[[GroupId, Optional[Header], NodeId, Join], Bitmap]   # from the group id and a
                                                     #   node id: custody, or all; computable before the header
    params: TypeParams                               # §6.3: the decisions' values sit here

class TypeParams:                                    # per object type; values in §6.3
    M: int                                           # colours of the push relation           [D10]
    F_LO: int                                        # in-pushers per family and colour: the floor [D10]
    F_HI: int                                        # and the cap                             [D10]
    D_OUT: int                                       # out-pushees per family and colour       [D10]
    D_OUT_FAST: int                                  # the same for a fast uplink              [c17]
    D_OUT_MAX: int                                   # what a node accepts to push for others
    SYMMETRIC: bool                                  # one relation both ways, kept as gossipsub keeps its mesh (§4.1)
    PRUNE_BACKOFF: float                             # seconds before a relation a PRUNE named is grafted again (§4.1)
    MAX_RELATIONS: int                               # the families × colours one link carries at most (§6.3, X6)
    MAX_INDICES: int                                 # the most indices a group of the type has, before its count is known (§4.5)
    ANNOUNCE_EXTRA: AnnounceWidth                    # ALL_JOINED | SAMPLE | NONE              [D5]
    EAGER: bool                                      # chunks of this type are pushed; False: holdings and offers only (rows, EIP-8371),
                                                     #   at the source too: it offers every chunk at publish (§4.7)
    DECODE_AT_K: Callable[[GroupId], bool]           # repair: who decodes at K, claiming all        [D4]
    DECODE_LATER: Callable[[GroupId], Optional[float]]   # repair: who decodes later if the group is still short, and when (from known_at) [D4]
    REPAIR_TO: Callable[[GroupId], List[PeerId]]     # repair: whom rebuilt chunks of a group go to  [D4]
    REPAIR_BUDGET: bool                              # repair: each rebuilt chunk to R_NODE of them lacking it, offered
                                                     #   to the rest (§1.6: its rebuilder is its source); False: seacast-lite.md's,
                                                     #   every peer short of K up to its shortfall   [D4]
    DEFER_WINDOW: float                              # repair: how long a peer's claim defers our own decode (R5) [D4]
    REPAIR_SAMPLE: Optional[List[Tuple[int, int]]]   # repair: the sample's steps [(S1, L1), (S2, L2), ...] after a
                                                     #   verified claim; None: off (§4.6, R5)
    SAMPLE_WAIT: float                               # repair: the wait for each step's cells (§4.6)
    REPAIR_REASK: bool                               # repair: a lost cell re-asked of another peer (§4.6)
    START_DELAY: float                               # seconds before the first ask             [D8]
    SERVE_LIMIT: int                                 # chunks served per peer and group         (R6)
    SAMPLE_RETRY: float                              # a sampler's first wait, before asking another peer (§4.10)
    SAMPLE_RETRY2: float                             # its wait on each later peer (§4.10)          [D12]
    SAMPLE_COVER: int                                # links serving each family, for a node that samples (§1.3) [D12]
    COVER_HIGH: int                                  # families a peer of high custody counts for in it (§1.3) [D12]
    ROUTE_HOPS: int                                  # forwarding steps a sampler's routed request may take (§4.10) [D12]
    FORWARD_LIMIT: int                               # routed requests passed on per peer and slot (§4.5, X6) [D12]
    EVIDENCE: Optional[ObjectType]                   # the fraud-proof object, if any           [D6]
```

| | payload (`seacast-lite.md`) | column (PeerDAS) | row (RowDAS) |
|---|---|---|---|
| a group | one descriptor's chunks, at one slot | one column of one block | one row of one block |
| group id | `group_key(group_id(descriptor), slot)`, the key of `seacast-lite.md` §1 | `(block_root, column)` | `(block_root, row)` |
| N | `descriptor.count` | the blob count | `NUMBER_OF_COLUMNS` = 128 |
| K | `ceil(total_length / segment_size)` | N: no code across blobs | 64 |
| `verify` | `seacast-lite.md`'s `validate_chunk`: the Merkle path to the committed root, and since v0.10 the copy's slot its block's; DEFER before the block | `verify_cell_kzg_proof_batch`, one cell index, many commitments, and the copy's slot its header's (REJECT otherwise, as v0.10's `validate_chunk`); DEFER before the header | the same, one commitment, many cell indices, and the same slot check |
| `decode` | `seacast-lite.md`'s `decode_and_reencode`: any K chunks to all N, or None if the root differs; a coded group's root commits the bytes its builder's compressor produced from the body, and whether a canonical compressor should fix those bytes is open (`seacast-lite.md` §1, "Open: the compressed bytes") | the cells present, if all are; nothing is rebuilt within a column (§4.6) | `recover_cells_and_kzg_proofs` from 64 |
| `header_of` | the descriptor: carried by the chunk and checked against the bid's group id (design A, which the toy runs), or carried by the bid itself (design B), so none before the block is installed (the gate, §4.2); `seacast-lite.md` §1 leaves the choice open ("Open: getting the descriptor"), and the installed block confirms it either way | `PartialDataColumnHeader`, validated once per block on any group | the same header |
| `project` | `[(g, i)]` | `[((root, c), b), ((root, row b), c)]` | the same two |
| `cross` | none | index b of column c: `((root, row b), c)` | index c of row b: `((root, c), b)` |
| `family` | one family | the column index | the row's subnet (EIP-8371: `ROW_SUBNET_COUNT` subnets, a node's one from its id, rows mapped to subnets per slot) |
| `derived_interest` | all | all of the column if `c ∈ get_custody_groups(node_id, cgc)`, else none | all of the row if it is the node's row subnet, else none |

A **group** `g` is one instance of an object type: its id is computable before any chunk of it
exists (`seacast-lite.md` §1; partial columns; the RowDAS design §4), so a receiver can hold state for
it, exchange bitmaps about it and ask for it before it holds anything. Its **header** arrives
through the object type's gate and is what the verifier needs. A **chunk** is one index of a group
with the proof that verifies it alone; `project` says which (group, index) pairs it fills, one for
the payload and two for a cell, which belongs to a column and to a row (R4). A **family** is the key
on which relations are formed (§1.3): where interest is structured, as custody is, a node needs
pushers for each family it has duty in, and the rendezvous is per family (one topic per column).

### 1.2 Interest and duty

**Interest** is what a node is to receive of a group (FullDAS). It comes in three kinds, declared
per link and object type at JOIN (§2):

- `ALL`: the whole object; completion is K distinct chunks and a decode where the type has a code,
  or every index where it has none;
- `DERIVED`: computed by both ends from the node id and the JOIN's `custody_count`
  (`T.derived_interest`), so a custodian never has to say what it wants;
- `DECLARED`: told per group and per peer, in a WANT (§2); a sample is declared this way. The WANT
  may precede the chunks: it is a standing request, answered when the peer holds them (§4.10), so a
  sampler needs no offer and no promise timer, and the peer learns nothing about the sampler's
  other samples.

A node may also have interest in a group that it declares on no link, when its interest on another
axis brings every chunk of that group: a supernode, custodian of every column, holds every row
whole once its columns arrive, so it keeps every row with interest `ALL` and no peer offers it row
cells or counts it among a row's members (§4.6, the second phase).

**Duty** is what a node does for others, and the node declares it at JOIN. With `FORWARD`, the node
holds push and announce relations for the object type and forwards what it receives into others'
interest; with `NONE`, it receives only. Serving is independent of duty: any node answers asks for
what it holds, within the serving limit (§4.5). A node with duty `FORWARD` also takes a routed
sample request for what it does not hold, and passes it one step on (§4.10). A sampler joins as
`(DECLARED, NONE)`; a custodian joins as `(DERIVED, FORWARD)`; every node on the payload joins as
`(ALL, FORWARD)`. Interest and duty are per link, so one node may be a custodian towards its custody
peers and a sampler towards others; nothing a node declares on one link is announced on another.

### 1.3 Links, joins and relations

A **link** is a connection on which both ends have exchanged a JOIN for an object type. On a link a
node keeps, per object type and family, two **relations**:

- the **push relation** `push_out[p][T][fam]`: the set of colours (§1.4) for which this node pushes
  chunks of that family to `p` eagerly, and `push_in[p][T][fam]`: the colours for which `p` pushes
  to this node. They are negotiated by GRAFT and PRUNE (§2, §4.1) with a direction, so they need
  not be symmetric: a node's uplink sizes its out-relations (card 17), and its need sizes its
  in-relations;
- the **announce relation**: whom this node tells what it holds. It always contains every peer that
  may push to it, since that is what makes a holding a suppression and an acknowledgement, and every
  peer it pushes to, which it offers what it chose not to push; beyond that its width is a
  parameter `[D5]`.

The **suppression scope** of a group is the set of peers that may push it to us. `seacast-lite.md`'s
mesh is the case where both relations are the same symmetric set of eight and the scope is the mesh.
A type whose relation is symmetric (`SYMMETRIC`, as `seacast-lite.md`'s mesh, §6.1) keeps it as one
relation both ways, grafted and pruned with direction `BOTH` (§4.1).

**Sampling links and the coverage floor** `[D12]`. A sample is served by a peer whose interest holds
it (§4.10), so a node that samples an object type keeps, for every family of the type, at least
`SAMPLE_COVER` links that serve it (a parameter of the object type, set at two covers; §6.3): links
whose peer's interest holds every index of the family's groups, a custodian of the column by its
derived interest or a peer with interest `ALL`.
- **Every link counts**, whatever it was opened for, but a peer of **high custody** (more than the
  base custody count, or interest `ALL`: a supernode, a row reconstructor, a source) counts for at
  most `COVER_HIGH` families.
- **What the node's links leave short, the rendezvous closes with sampling-only links**, on which
  the node joins as `(DECLARED, NONE)` (§1.2; on gossipsub's wires, a connection with no
  subscription, §7). It closes what it can at each heartbeat, taking first a candidate that covers
  the most families still short; a family that no candidate covers waits for the next heartbeat
  (`keep_coverage`, §4.1). Such a link carries no relation, no push and no offer, since the peer's
  interest towards the node is empty until a WANT names a sample; it costs the peer a connection and
  what it serves, within its serving limit.
- **The links are chosen by custody computed from node ids** (`T.derived_interest` from the id and
  the custody count the rendezvous gives, the ENR's `cgc`; §4.1, `keep_coverage`), before and
  independently of any sample, for every family alike. A node's custody counts, not what it holds
  as a source (§1.6).
- **This floor is on links, not on a relation:** §1.4's floor counts in-pushers per colour. What it
  misses, a link that does not deliver or a family no link serves yet, goes to §4.10's second phase.

**Routing neighbours** (option) `[D12]`. A sample that no link serves goes out as a routed request
(§4.10), passed from node to node toward the column's custodians within a hop limit. Where the
rendezvous keeps, for each node with duty `FORWARD`, `ROUTE_FLOOR` links to custodians of the
families at structured distances from its own (FullDAS's topic routing: hypercube-style, columns `c
+ 2^j mod 128` for each column `c` it custodies; or Kademlia-style, a column in each XOR bucket `j`
of `c`), each step goes to the link nearest the sample's family by that distance, computed from node
ids. Without such neighbours the sampler's step goes to any link with duty `FORWARD` that does not
serve the sample, and one step reaches the family when that link passes the request on to a link of
its own that serves the index: it does so if its own duty is `FORWARD`, within its `FORWARD_LIMIT`
for the asker, to such a link other than the asker that it has not parked for the group (§4.5,
`route_want`). That is the trivial structure, which needs no routing neighbours; its one forwarding
step is the request's default. With steps left (the request's `hops` above 1 when it arrives:
`ROUTE_HOPS` above 1 at the sampler), a forwarder that has no such link may pass the request on
toward the family in turn, to another forwarding link, under the same duty and limit (§4.5).

#### Rationale

**A floor built for diversity, not for the fewest links.** Its aim is that the node's samples, one
per peer (§4.10), find distinct peers that serve them, so that no peer learns the node's whole
sample. One link to a node that custodies every column would otherwise cover them all and serve
every sample; this is why a peer of high custody counts for at most `COVER_HIGH` families. Links
chosen before and independently of any sample reveal nothing about what the node will sample
(FullDAS's independence of the sample). A source's holding does not count because a proposer holds
every column of its own block only, and proposers rotate. Two covers were decided on 2026-11-03
(`[D12]`, §8).

**What the floor buys, and what it costs, in the toy.** Without it, a sample of a column none of the
node's links custodies is never served. In the toy's 500-node graphs, some samplers of eight cells
have such a sample at 70 links, and nearly all do at 16. With the floor, on the same graphs, one
cover by the fewest links adds a few sampling-only links at 70 links and many more at 16 (§6.3);
the diversity floor of two covers adds more again (§6.3, §8; seacast-figures.md, §1.3).

**One forwarding step usually reaches the family.** A custodian's floor per column (§1.4) makes it
likely that one of a forwarding link's own links custodies the sample's family: in the toy's graphs
the floor gives a custodian many more links than a degree of 16 (seacast-figures.md, §1.3).

### 1.4 Colours and the floor

Each index of a group has a **colour**, `colour_of(g, i)`, one of `M[T]` `[D10]`. A chunk is pushed
eagerly only on links whose push relation for its family holds its colour. With `M = 1` every link
carries every index: this is `seacast-lite.md`'s mesh. With `M = N` each index has its own pusher set:
these are variant C's independent meshes, on one neighbourhood. In between, each link carries a
share of the indices and a node's pushers for a given index are a subset of its links, which is
where path diversity comes from without multiplying topics.

```python
def colour_of(g, i) -> int:
    return i % type_of_group(g).params.M             # [D10] a keyed permutation per group is a variant
```

A node keeps, per family it has duty in and per colour, at least `F_LO` and at most `F_HI` peers in
its in-relation: this is the **floor** per colour. Each colour keeps its floor by GRAFTs of its
own (`maintain_relations`, §4.1), so no colour is chosen over another. The floor needs links to
form on: a node also keeps, per family it has duty in, at least `F_LO` links to peers whose
interest holds the family, and opens more where churn leaves it short (`keep_floor`, §4.1).

### 1.5 Holdings, offers, claims, completion and evidence

A node says two different things about what it holds, and they are not interchangeable. A
**holding** ("I hold these, verified") goes to whoever may push to us: it suppresses pushes, it
acknowledges the chunk just received (the window, `seacast-lite.md` §7.1), and it counts the sender as a
holder for rarest-first and cancel. An **offer** ("you may ask me for these") goes to a peer we
chose not to push a chunk to, or to a peer outside the relation: it feeds that peer's offer table
and nothing else. A pusher's holding is not an offer, since it may be pushing that very chunk; an
offer is not a holding count, since what the pull discipline needs is who can serve. `seacast-lite.md`
carries the two in IDONTWANT and IHAVE; here they are one message with a flag (§2) and two handlers
(§4.3).

A holding carries two **claims** besides its bitmap `[D3]`: `claim_all`, the sender holds or can
produce every index (it has reached K and will decode: `seacast-lite.md`'s decode claim, made at K,
before the decode, because a group whose chunks do not form a codeword fails at every node), and
`complete`, the sender's interest in this group is satisfied, so nothing more need be pushed or
announced to it. Both are unverified; the window and serving treat them as such, and a claim not
followed by the chunks it implies counts against the claimant (R5).

**Completion** is per interest. A node with interest `ALL` is complete at K distinct chunks. A
custodian is complete at every index of its column. A row member is complete at K cells (it stops
pulling and exposes what it has, EIP-8371), and it decodes only if its duty says so. A sampler is
complete when its declared indices have arrived.

**Evidence** is an object a node may publish about a group it found inconsistent at level 2, if the
object type defines one `[D6]`; this document carries it and does not define it. No object type
defines one in this version (§8).

### 1.6 Roles are derived, not declared

A **source** is any node that holds chunks of a group before its peers do: the builder with the
whole payload, or a node that built columns from its mempool at block arrival (I8, X8). The source
rules of `seacast-lite.md` §5.1 (batch order, striping and the window) apply to what such a node pushes
first; whether a node is a source is read from its holdings and its peers' holdings, not announced.
A **forwarding node** is any node with duty `FORWARD`. A **reconstructor** is a node whose repair
rule (§4.6) says it decodes a group or a block it does not need whole for itself.

## 2. Messages

The messages are abstract; the bindings carry them on wires (§7, `seacast-bindings.md`). Every
message names its object type or group, and a receiver ignores, without penalty, a JOIN for an
object type it does not run, and a GRAFT, PRUNE, offer or WANT for one it has not joined on that
link; a JOIN for a type the node runs is how a link joins it (§4.1). Chunks and holdings are
taken on any link: a cell is in groups of two types, so an answer or an acknowledgement can name
the group of either (a cell stored from its column and asked for in its row comes back naming its
column); a chunk is verified against its group's header; and holdings of groups the node does not
know are bounded (`seacast-lite.md` §8.2). A fetch outside the links (§7) has no JOIN: its WANT is
answered without one.

```python
class Join(Container):                   # per link and object type, sent by both ends   [D11]
    object_type: TypeId
    interest: InterestKind               # ALL | DERIVED | DECLARED
    custody_count: uint64                # the input to derived interest (the ENR's cgc), else 0
    duty: Duty                           # FORWARD | NONE
    colours: uint16                      # M[T] as the sender runs it; a mismatch is no link for T

class Graft(Container):                  # relation maintenance, per family and colour; also the yes to one (§4.1)
    object_type: TypeId
    family: FamilyId
    colour: uint16
    direction: Direction                 # OUT: "I will push you this colour"; IN: "push me this colour"; BOTH
    answer: boolean                      # True: the yes to the receiver's GRAFT, not answered where it is held (§4.1)

class Prune(Container):                  # the no to a GRAFT, or the end of a relation, at both ends (§4.1)
    object_type: TypeId
    family: FamilyId
    colour: uint16
    direction: Direction                 # the sender's view, as a GRAFT's: OUT "I stop pushing you"; IN "stop pushing me"

class Have(Container):                   # what the sender holds, verified                   [c7]
    group: GroupId
    bits: Bitmap
    offer: boolean                       # True: "you may ask me for these"; False: a holding (§1.5)
    claim_all: boolean                   # [c10] the decode claim; holdings only              [D3]
    complete: boolean                    # my interest in this group is satisfied; holdings only [D3]

class Want(Container):                   # "send me these", to this peer only                [D2]
    group: GroupId
    bits: Bitmap
    standing: boolean                    # also when they arrive, not only if held now (§4.10)  [D12]
    hops: uint8                          # forwarding steps the request may still take (§4.10); 0: none [D12]
    probe: boolean                       # the probe of a claim: answered whatever the sender holds (§4.6)   (R5)

class ChunkMsg(Container):
    group: GroupId
    index: uint32
    data: bytes
    proof: Proof
    header: Optional[Header]             # with the first eager push of a group on a link (P2)

class Evidence(Container):               # [D6]
    group: GroupId
    body: bytes
```

- **One message, two kinds.** `offer = False` is a holding (`seacast-lite.md`'s IDONTWANT with a
  bitmap, on the urgent lane); `offer = True` is an offer (`seacast-lite.md`'s IHAVE with a bitmap,
  paced). §4.3 handles them differently and §1.5 says why.
- **WANT is per recipient** (the RowDAS design's reading of `requests`): what the sender asks *this*
  peer for, not what it lacks, and the peer sends it what it holds of that now and, for a standing
  WANT (below), the rest when it arrives, within the group's lifetime (§4.10). The ask discipline of
  `seacast-lite.md` §6.1 sends one index per peer at a time and carries over for pulls against offers; a
  bitmap lets a client batch, and a sampler declares its indices in one. There is no third bitmap
  for need `[D2]`: a peer with `DERIVED` or `ALL` interest needs no WANT to declare what both ends
  can compute (its pulls on offers are asks, §4.3), and a declared interest is only ever told to the
  peers it is asked of (I6). Two fields say how long a WANT stands and how far it goes `[D12]`:
  `standing`, answered when the chunks arrive as well as from what is held (a sampler's WANT always
  is, on a `DECLARED` link whether or not it says so); `hops`, the forwarding steps the request may
  still take: a receiver that does not hold the chunks passes it to one of its links with one step
  fewer (§4.10). A pull against an offer, the probe and the repair sample (§4.6) set neither. A
  third field, `probe`, marks the one ask that verifies a peer's claim (§4.6): the claimant answers
  it whatever the asker's holdings say, once per asker and group. SEACAST's message encoding carries
  `standing` and `probe` in one flags byte (`seacast-bindings.md` §1.2).
- **A cell group's header travels in one of three forms**, which the object type's definition fixes
  (`seacast-bindings.md` §1.6, and §7): from the block, in every cell message, or in a header
  message of its own. On the libp2p stream binding, the second form carries the header once per
  group and link, so cells can be verified before the block (P2). The payload's header is the
  descriptor, which every chunk carries under design A and the bid under design B, a choice
  `seacast-lite.md` §1 leaves open; the installed block confirms it, as in `seacast-lite.md`.

## 3. State

```python
# per link and object type (new)
join_recv: Dict[PeerId, Dict[TypeId, Join]]           # what p declared to us
join_sent: Dict[PeerId, Dict[TypeId, Join]]           # what we declared to p
push_out: Dict[PeerId, Dict[TypeId, Dict[FamilyId, Set[int]]]]   # colours we push p, per family
push_in: Dict[PeerId, Dict[TypeId, Dict[FamilyId, Set[int]]]]    # colours p pushes us, per family
grafted_out: Dict[PeerId, Dict[TypeId, Dict[FamilyId, Set[int]]]]   # colours we offered to push p, unanswered (§4.1)
grafted_in: Dict[PeerId, Dict[TypeId, Dict[FamilyId, Set[int]]]]    # colours we asked p to push us, unanswered
owed_relations: Dict[PeerId, List[Container]]                    # per link: JOINs, GRAFTs and PRUNEs a full queue refused, in order
backoff: Dict[PeerId, Dict[TypeId, Dict[FamilyId, Dict[Tuple[int, Direction], float]]]]   # until when we do not graft p
                                                                 #   again for a relation its PRUNE named (§4.1)

# per group (seacast-lite.md §8.1's, plus three)
T_of: Dict[GroupId, ObjectType]                       # new: the group's type, from its id
hdr: Dict[GroupId, Header]                            # seacast-lite.md's desc, once the gate opened
state: Dict[GroupId, GroupState]                      # COLLECTING | DECODING | COMPLETE | INVALID
received: Dict[GroupId, Bitmap]                       # chunks from the network
rebuilt: Dict[GroupId, Bitmap]                        # new: chunks from a decode
mine: Dict[GroupId, Bitmap]                           # what we claim: received, rebuilt, or all N at K
chunks: Dict[GroupId, Dict[int, Chunk]]
interest: Dict[GroupId, Bitmap]                       # new: ours, per group (§1.2); ALL reads as every index
stop_pull: Dict[GroupId, bool]                        # [c6]
origin: Dict[GroupId, Bitmap]                         # v0.4's: for a group we publish, the chunks acknowledged so far (§4.7) [P4]
planned: Dict[GroupId, Dict[int, Set[PeerId]]]        # v0.9's: for a group we publish, each chunk's push targets [c3]
known_at: Dict[GroupId, float]                        # new: when the group id became known; START_DELAY runs from here [D8]

# per peer and group (seacast-lite.md's, plus flags and one counter)
peer_has: Dict[PeerId, Dict[GroupId, HaveEntry]]      # bits, ttl; and claim_all, complete (§1.5)
holders: Dict[GroupId, Dict[int, Set[PeerId]]]        # [c9] distinct live holders, from holdings only
pushed: Dict[PeerId, Dict[GroupId, PushEntry]]        # bits, first_push, ttl               [c16]
sent_to: Dict[PeerId, Dict[GroupId, Bitmap]]          # [c12]
served: Dict[PeerId, Dict[GroupId, int]]              # new: chunks answered (R6)
served_hb: Dict[PeerId, int]                          # new: answers to p this heartbeat that SERVE_BUDGET counts (§4.5)
offered_to: Dict[PeerId, Dict[GroupId, Bitmap]]       # new: what we offered p, whose asks the budget does not count
want_p: Dict[PeerId, Dict[GroupId, Bitmap]]           # new: a DECLARED peer's interest, from its WANTs (§1.2, §4.5)
promises: Dict[Tuple[Ask, PeerId], float]             # seacast-lite.md §6.1, unchanged
offers: Dict[Ask, List[PeerId]]
tried: Dict[Ask, Dict[PeerId, float]]
asked_at: Dict[Ask, float]
park: Dict[PeerId, Dict[GroupId, float]]
standing: Dict[GroupId, Dict[int, Set[PeerId]]]       # new: WANTs for chunks we do not hold yet (§4.10)
routed_standing: Dict[GroupId, Dict[int, Set[PeerId]]]   # new: those a routed request made (§4.5's exemption)
sampled_from: Dict[BlockId, Set[PeerId]]              # new: the peers asked for a sample of a block, one each (I6) [D12]
samples_in_flight: Dict[BlockId, int]                 # new: our second-phase sample asks in flight, across types
held_samples: Dict[BlockId, List[Tuple[GroupId, int]]]   # new: second-phase asks waiting for room, across types
forwarded: Dict[PeerId, Dict[ObjectType, int]]        # new: routed requests from p passed on, per type and slot (X6)
claims: Dict[GroupId, Set[PeerId]]                    # new: peers whose claim_all arrived (R5, §4.6)
reconsider_at: Dict[GroupId, float]                   # new: when our later decode duty fires, if armed (§4.6)
deferred: Dict[GroupId, bool]                         # new: we deferred it once on a claim (R5)
duty_at: Dict[GroupId, float]                         # new: the duty's own time when the claim deferred it (R5)
waited: Dict[GroupId, bool]                           # new: we waited once for chunks held on another axis (§4.6)
probe: Dict[GroupId, int]                             # new: the index we asked a claimant for, to verify the claim (R5)
probed: Dict[GroupId, PeerId]                         # new: the claimant we asked
probe_asks: Set[Ask]                                  # new: those asks, exempt from stop-pull until settled (§4.6)
probe_sent: Set[GroupId]                              # new: groups whose probe's WANT was written (§4.6)
probe_ok: Dict[GroupId, Optional[bool]]               # new: the probe's verdict, once: True if the claimant's own copy came;
                                                      #   None: no verdict, the probe not written in time or
                                                      #   the claimant gone (§4.6)
probe_served: Dict[PeerId, Dict[GroupId, bool]]       # new: as a claimant, p's probe of the group answered (§4.6)
probe_answers: Dict[PeerId, Dict[GroupId, Bitmap]]    # new: those answers until written, by the chunk's own group
probe_waiting: Dict[GroupId, Dict[PeerId, int]]       # new: as a claimant still decoding, p's first marked ask of the
                                                      #   group, until the cell is stored (§4.6)
rsample: Dict[GroupId, List[int]]                     # new: the repair sample's indices, asked of custodians (R5, option)
rsample_step: Dict[GroupId, int]                      # new: how many of REPAIR_SAMPLE's steps were asked
rsample_asked: Dict[GroupId, Dict[int, Set[PeerId]]]  # new: the custodians each sampled cell was asked of
rsample_final: Dict[GroupId, bool]                    # new: the last step's re-asks were waited for
```

Lifetimes are `seacast-lite.md` §8.1's. Per-group state lives `GROUP_TTL` past the last chunk or the
completion, or until its slot leaves the node's live window (`seacast-lite.md` §8.1) if that comes
first, and leaves a tombstone until the window has passed the slot. The probe's tables
(`probe_ok`, and `probe_served`, `probe_answers` and `probe_waiting` for every peer) go with the
group's state, and a peer's entries in them also go with its connection (a bit of `probe_answers`
whose answer is never written stays until then). A peer's claims go with its connection
(`claims_close`, §4.6). Per-peer entries live `HAVE_TTL` and `PUSH_TTL` heartbeats or until the
connection closes. What the node offered a peer (`offered_to`) lives with the group's state or until
the connection closes, and the serving budget's count (`served_hb`) starts again at each heartbeat.
Relations live until PRUNE or disconnection; a GRAFT of ours lives until it is
answered, until a PRUNE of either end ends it or until the connection closes; an owed JOIN, GRAFT
or PRUNE (§4.1) lives until the writer queues it or the connection closes; and a backoff lives
until it runs out or the connection closes. A writer's place in the window's line (`waiters`,
§4.11) is the node's state, not the connection's. The writer leaves the line when it takes room
(`acquire_room`). It also leaves when it has nothing to send and when the connection closes:
`leave_line` takes it out, and the first writer in line that can write then tries again if room is
free (`wake_front`). `forwarded` starts again at each slot. An expired group is not taken up again.
The receive and publish paths check it as `seacast-lite.md`'s do, `fill` checks it on every axis a
chunk projects onto, and the paths that act on a projected group (`forward`, `push_rebuilt`, the
repair sample's `ask_custodian`) skip an expired axis; `check_completion` finds no state to act on.
A dropped group's later chunks are not stored, forwarded, offered or kept for heartbeat gossip on
that axis (`fill`, `forward`, `push_rebuilt`), as `seacast-lite.md`'s `on_validated` returns for one.
Offered, such a chunk would draw asks that the node does not answer, and an asker's promise could
break against an honest node. The sampler's `sample`, `resample` and `ask_sample` check it (§4.10),
so a draw or a retry after the expiry makes no park, interest or WANT again. Reading a missing entry
allocates nothing; the admission checks of `seacast-lite.md` §8.2 and the limits of §6.3 come first. A
group with no entry in `interest` reads as the node's own interest in it, from what it declared:
every index under `ALL`, its derived interest under `DERIVED` (every index of a column it
custodies, or of its own subnet's row, and none of another), the cells it drew to sample under
`DECLARED`, whether or not it has asked a peer for them yet (§4.10), and, for a supernode, every
row besides (§4.6, the second phase). A
node may hold state for a group it has no interest in, when it holds chunks of it or a peer's
interest names it (a reconstructor's non-custodied columns, R4); the number of such groups per slot
is bounded (§6.3).

**Helpers not written out**, beyond `seacast-lite.md` §8.1's, are these: `type_of_group(g)` (the object
type a group id names), `links(T)` (the peers with a JOIN for `T` both ways: theirs received, ours
queued rather than owed, §4.1; none for a type the node does not run), `our_join(T)` (the JOIN
the node sends for `T`: its interest, custody count, duty and `M`, §1.2), `joined_types()`,
`joined_peers()` (the peers in `links(T)` for some `T` in `joined_types()`), `related(q)` (`q` holds a
relation of ours: it is in `in_pushers(T, fam, c)` or `out_pushees(T, fam, c)` for some type, family and
colour; stock's `q in mesh`),
`runs_type(tid)` (the node runs the object type `tid` names), `node_id(p)`, `own_id()` (the node's
own id),
`in_pushers(T, fam, c)` and
`out_pushees(T, fam, c)` (the peers whose relation holds that colour), `candidates(T, fam, c, d)`
(joined peers with duty whose interest holds the family, by `link_cover`; not yet in the relation of
colour `c` and direction `d`, with `BOTH` in neither; with no GRAFT of ours for it unanswered; and
out of its backoff, with `BOTH` for both directions; §4.1),
`families_with_duty(T)`, `wants_family(T, fam)`, `duty_for(g)`, `uplink_class()` (card 17),
`send(p, msg, urgent)` (a message into the bounded per-peer queue of `seacast-lite.md` §7; the binding's
job; true if the queue admitted it, as v0.5's `enqueue`; the asks of a `Want` sent through it are
marked `want`, a local mark that goes on no wire, where those the pull discipline queues on an
offer, `respond`, `retry_offer` and `ask_parked`'s, are not; the two kinds go in separate ask
messages of an entry), `Ask(g, i)` (an ask's key, `seacast-lite.md`'s `WantIndex`), `chunk_id(f)`
(`seacast-lite.md`'s `message_id`), `open_group(g, f)` (as `seacast-lite.md`'s, and records `T_of`,
`interest`, `known_at`), `open_group_source(g, h)`, `group_of(block, h)` (the group a source
publishes, by §1.1's table: for the payload the key of `seacast-lite.md` §1, for a column or a row its
id), `interest_satisfied(g)` (§1.5), `deferred_offers(p, h)` (§4.3), `publish_evidence(g, body)`,
`sampled_types()` (the object types the node samples), `families(T)` (every family of the type: the
128 columns), `link_cover(q, T)` (§4.1: the families whose every index `q`'s interest holds, from
its JOIN and node id, and whether `q` is of high custody, §1.3), `high_custody(q, T)` (§1.3: `q`'s
custody count above the type's base custody count, or its interest `ALL`), `cover_candidates(T)`
(§4.1: the rendezvous's nodes not yet linked, each with the same two from its node id and custody
count, before any connection), `open_sampling_link(r, T)` (§4.1: connect and JOIN as
`(DECLARED, NONE)`, through `send_join`), `floor_links(T, fam)` (§4.1: the peers the node is
connected to with its JOIN for `T` sent, a link or one forming, whose interest holds `fam` by their
node id and the custody count the rendezvous gives), `floor_candidates(T)` (§4.1: as
`cover_candidates`, the rendezvous's nodes not yet linked, each with the families its custody
holds), `open_link(r, T)` (§4.1: connect and JOIN with `our_join(T)`, through `send_join`),
`route_next(T, fam, qs)` (§1.3, §4.10: of the links `qs`, those nearest `fam` by the routing
neighbours' distance between their computed custody and `fam`; all of them where the rendezvous
keeps no such rule), `block_of(g)` (the block a cell group belongs to; `g` itself for a type without
blocks), `wire_size(p, entry)` (§4.11: the bytes the entry's chunk takes on the wire to `p`, the
binding's: with a header where its write carries one), `cell_groups(root)` (the column and row
groups of a block, from their ids alone), `admitted_group(p, g)` (§4.5: a group named in `p`'s
WANT is within `p`'s own limit of unknown groups named in WANTs, `MAX_PENDING_GROUPS`; a group the
node has opened, at its first valid chunk (`hdr`), always is; a place frees as §4.5 says),
`release_wanted_groups()` (§4.5: frees each such place whose group has resolved or whose lifetime
has passed, and for the latter drops the asker's standing requests, route marks and interest bits
for the group, removing the entries it empties) and `offers_in(e)` (the offers a queue entry
carries, each as a group and its
bitmap, whichever path queued them).

## 4. Events

Validation runs off the receive path as in `seacast-lite.md` §4.1. The order of handling one frame (a
binding's unit on the wire, which may carry several messages; `seacast-bindings.md` §0) is
`seacast-lite.md`'s: chunks, then offers (which produce asks), then asks (which produce answers), then
GRAFT and PRUNE, then holdings, then the response.

```python
def on_frame(p, frame):
    for f in frame.chunks: on_chunk(p, f)                             # §2: chunks and holdings on any link
    offers = [h for h in frame.haves                                  # §2: an offer for a type the link has not
              if h.offer and joined(p, type_of_group(h.group))]       #   joined is ignored, without penalty; the asks,
                                                                      #   GRAFTs and PRUNEs check it in their handlers
    if offers: ihave_frames[p] += 1                                   # offer-bearing frames, for §4.3's limits
    asks = [a for h in offers for a in on_offer(p, h)]                # §4.3
    answers = on_want(p, frame.asks)                                  # §4.5
    for gr in frame.grafts: on_graft(p, gr)                           # §4.1: it sends its own answers
    for pr in frame.prunes: on_prune(p, pr)
    for h in frame.haves:
        if not h.offer: on_holding(p, h)                              # §4.3
    respond(p, asks, answers, [])                                     # seacast-lite.md §4.1; a GRAFT's answer goes on its own
```

### 4.1 Joining, and keeping the relations

```python
def on_join(p, j: Join):
    if not runs_type(j.object_type): return            # §2: a type the node does not run: no state, no penalty
    T = type_of(j.object_type)
    if j.colours != T.params.M: return                 # no SEACAST for T on this link; the stock path remains
    join_recv[p][T] = j
    if T not in join_sent[p]: send_join(p, our_join(T))   # the answer, unless ours went first

def joined(p, T) -> bool:                              # §2: the link joined T: p's JOIN received, ours queued, not
    return p in links(T)                               #   owed (§4.1's links)

def send_join(p, j: Join):                             # every JOIN of ours, once per link and type: when the node opens
    join_sent[p][type_of(j.object_type)] = j           #   the link, a sampling link's included, or in answer to p's;
    send_relation(p, j)                                #   owed as a GRAFT is, so ahead of the type's GRAFTs and PRUNEs

def interest_of_peer(p, g) -> Bitmap:                  # what p is to receive of g, as far as we know
    T = type_of_group(g); j = join_recv[p][T]
    if j.interest == ALL: return EVERY_INDEX
    if j.interest == DERIVED: return T.derived_interest(g, hdr.get(g), node_id(p), j)
    return want_p[p].get(g, EMPTY)                      # DECLARED: only what p asked us for

def wants_from_me(p, g) -> Bitmap:                     # [I3] pushes and offers go into interest
    e = peer_has[p][g]
    if e.complete: return EMPTY
    return interest_of_peer(p, g) & ~e.bits & ~pushed[p][g]

def maintain_relations(T):                             # at the heartbeat, per family we have duty in
    for fam in families_with_duty(T):
        for c in range(T.params.M):
            ins = in_pushers(T, fam, c)
            if T.params.SYMMETRIC:                     # one relation both ways, kept as gossipsub keeps its mesh:
                if len(ins) < T.params.F_LO:           #   below the floor, graft up to D_OUT
                    cs = [q for q in candidates(T, fam, c, BOTH) if relation_room(q, T, fam, c)]   # §6.3
                    for q in cs[: T.params.D_OUT - len(ins)]:
                        graft(q, T, fam, c, BOTH)
                elif len(ins) >= T.params.F_HI:        #   at the cap, where on_graft refuses, prune down to D_OUT
                    for q in sample_without_replacement(ins, len(ins) - T.params.D_OUT):   # at random
                        prune(q, T, fam, c, BOTH)
                half = set(in_pushers(T, fam, c)) ^ set(out_pushees(T, fam, c))   # held one way only, by lost
                for q in sorted(half):                 #   state: grafted again at any count, and the other end
                    if c not in grafted_in[q][T][fam] and c not in grafted_out[q][T][fam]:   # makes it whole
                        graft(q, T, fam, c, BOTH)      #   or refuses it (on_graft), so the ends agree
                continue
            if len(ins) < T.params.F_LO:               # the floor per colour                [D10]
                cs = [q for q in candidates(T, fam, c, IN) if relation_room(q, T, fam, c)]
                for q in cs[: T.params.F_LO - len(ins)]:
                    graft(q, T, fam, c, IN)            # "push me": counted once q says yes
            if len(ins) > T.params.F_HI:
                for q in ins[T.params.F_HI:]:
                    prune(q, T, fam, c, IN)            # "stop pushing me"
            outs = out_pushees(T, fam, c)
            target = T.params.D_OUT_FAST if uplink_class() == FAST else T.params.D_OUT    # [c17]
            cs = [q for q in candidates(T, fam, c, OUT) if relation_room(q, T, fam, c)]
            for q in cs[: max(0, target - len(outs))]:
                graft(q, T, fam, c, OUT)               # "I will push you": pushed once q says yes

def graft(q, T, fam, c, d):                            # our GRAFT: nothing is counted until q answers it
    if not relation_room(q, T, fam, c): return         # §6.3: our own relations stay under the link's limit too
    if d in (IN, BOTH): grafted_in[q][T][fam].add(c)
    if d in (OUT, BOTH): grafted_out[q][T][fam].add(c)
    send_relation(q, Graft(object_type=T.id, family=fam, colour=c, direction=d, answer=False))

def prune(q, T, fam, c, d):                            # our PRUNE: the relation ends at our end at once
    if d in (IN, BOTH): push_in[q][T][fam].discard(c); grafted_in[q][T][fam].discard(c)
    if d in (OUT, BOTH): push_out[q][T][fam].discard(c); grafted_out[q][T][fam].discard(c)
    send_relation(q, Prune(object_type=T.id, family=fam, colour=c, direction=d))

def yes(p, T, fam, c, d):                              # an accepted GRAFT's answer, from our side: not answered where held
    send_relation(p, Graft(object_type=T.id, family=fam, colour=c, direction=d, answer=True))

def no(p, T, fam, c, d):                               # a refused GRAFT's answer, from our side
    send_relation(p, Prune(object_type=T.id, family=fam, colour=c, direction=d))

def on_graft(p, gr: Graft):                            # each direction answered: a GRAFT is yes, a PRUNE no
    if not runs_type(gr.object_type) or not joined(p, type_of(gr.object_type)): return   # §2: no state, no answer
    T = type_of(gr.object_type); fam, c = gr.family, gr.colour
    if not relation_room(p, T, fam, c): return         # §6.3: a new relation over the link's limit: ignored, unanswered
    if T.params.SYMMETRIC:                             # one relation both ways: decided as one, one answer
        asked = c in grafted_in[p][T][fam] or c in grafted_out[p][T][fam]   # the yes to ours, or a crossing
        grafted_in[p][T][fam].discard(c); grafted_out[p][T][fam].discard(c)
        held = c in push_in[p][T][fam] or c in push_out[p][T][fam]   # either way: held, made whole again
        if held or (len(in_pushers(T, fam, c)) < T.params.F_HI and wants_family(T, fam)
                    and join_sent[p][T].duty == FORWARD):
            push_in[p][T][fam].add(c)
            if not asked and not (held and gr.answer): yes(p, T, fam, c, BOTH)   # held: yes again, unless a yes
            join_push(p, T, fam, c)                    # and push_out: what we hold is announced
        else:
            no(p, T, fam, c, BOTH)
        return
    if gr.direction in (OUT, BOTH):                    # p will push us colour c
        asked = c in grafted_in[p][T][fam]             # the yes to our "push me", or a GRAFT that crossed it
        grafted_in[p][T][fam].discard(c)
        if c in push_in[p][T][fam]:                    # held: yes again, unless it answers ours or is a yes
            if not asked and not gr.answer: yes(p, T, fam, c, IN)
        elif len(in_pushers(T, fam, c)) < T.params.F_HI and wants_family(T, fam):
            push_in[p][T][fam].add(c)
            if not asked: yes(p, T, fam, c, IN)        # yes: "push me"
        else:
            no(p, T, fam, c, IN)                       # no: "stop pushing me"
    if gr.direction in (IN, BOTH):                     # p asks us to push it colour c
        asked = c in grafted_out[p][T][fam]            # the yes to our "I will push you", or one that crossed it
        grafted_out[p][T][fam].discard(c)
        if c in push_out[p][T][fam]:                   # held: yes again, unless it answers ours or is a yes
            if not asked and not gr.answer: yes(p, T, fam, c, OUT)
        elif join_sent[p][T].duty == FORWARD and len(out_pushees(T, fam, c)) < T.params.D_OUT_MAX:
            if not asked: yes(p, T, fam, c, OUT)       # yes: "I will push you"
            join_push(p, T, fam, c)                    # in the relation at our end: what we hold is announced
        else:
            no(p, T, fam, c, OUT)                      # no: "I will not push you"

def relation_room(p, T, fam, c) -> bool:               # §6.3, X6: the link has (fam, c) in some state already, or
    held = {(f, k) for m in (push_in, push_out, grafted_in, grafted_out)   #   fewer pairs of T than MAX_RELATIONS:
            for f, ks in m[p][T].items() for k in ks}  #   relations, our GRAFTs not yet answered, backoffs not yet
                                                       #   run out, and our GRAFTs and PRUNEs still owed
    held |= {(f, k) for f, bo in backoff[p][T].items() for (k, d), until in bo.items() if until > now}
    held |= {(m.family, m.colour) for m in owed_relations[p]   # a GRAFT or PRUNE of ours still owed to p
             if not isinstance(m, Join) and m.object_type == T.id}
    return (fam, c) in held or len(held) < T.params.MAX_RELATIONS

def join_push(p, T, fam, c):                           # p joins our push relation for colour c: what we hold of
    if c in push_out[p][T][fam]: return                #   it is announced (seacast-lite.md §5.4's on_mesh_join);
    push_out[p][T][fam].add(c)                         #   a GRAFT that adds nothing runs nothing
    for g in list(chunks):
        if expired(g) or state[g] == INVALID or type_of_group(g) != T or T.family(g) != fam: continue
        announce(p, g, bitmap({i for i in chunks[g] if colour_of(g, i) == c}))   # stored, received or rebuilt,
                                                       #   minus what p holds, was pushed or does not want (§4.4)

def on_prune(p, pr: Prune):                            # p's no, or p's end of the relation: ours ends too
    if not runs_type(pr.object_type) or not joined(p, type_of(pr.object_type)): return   # §2: no backoff, no penalty
    T = type_of(pr.object_type); fam, c = pr.family, pr.colour
    for f in list(backoff[p][T]):                      # §3: a backoff lives until it runs out, and no longer,
        bo = backoff[p][T][f]                          #   with the entries that empties
        for k in [k for k, until in bo.items() if until <= now]: del bo[k]
        if not bo: del backoff[p][T][f]
    if not relation_room(p, T, fam, c): return         # §6.3: a new pair over the link's limit: no backoff
    d = BOTH if T.params.SYMMETRIC else pr.direction   # a symmetric relation ends both ways
    until = now + T.params.PRUNE_BACKOFF               # and is not grafted again before then
    if d in (OUT, BOTH):                               # "I stop pushing you", "I will not push you"
        push_in[p][T][fam].discard(c); grafted_in[p][T][fam].discard(c)
        if until > now: backoff[p][T][fam][(c, IN)] = until   # our "push me" waits; none when the backoff is 0
    if d in (IN, BOTH):                                # "stop pushing me"
        push_out[p][T][fam].discard(c); grafted_out[p][T][fam].discard(c)
        if until > now: backoff[p][T][fam][(c, OUT)] = until   # our "I will push you" waits

def send_relation(p, m):                               # a JOIN, GRAFT or PRUNE is never lost to a full queue: one
    if owed_relations[p] or not send(p, m, urgent=isinstance(m, Join)):   #   refused, and every later one, is
        owed_relations[p].append(m)                    #   owed in order; a JOIN keeps the urgent lane
        wake(p)

def queue_owed_relations(p):                           # the writer, before anything else (§4.11)
    while owed_relations[p] and has_room(p):
        m = owed_relations[p].pop(0)
        send(p, m, urgent=isinstance(m, Join))

def serves(q, g, i) -> bool:                           # §1.3: q's interest holds index i of g, so q will hold it
    T = type_of_group(g)
    return join_recv[q][T].interest != DECLARED and interest_of_peer(q, g).has(i)

def counted(need, r, T) -> List[FamilyId]:            # §1.3: the short families r covers; one of high custody
    short = [fam for fam in r.families if need[fam] > 0]   #   counts for at most COVER_HIGH of them (diversity)
    return short[: T.params.COVER_HIGH] if r.high else short

def keep_coverage(T):                                  # at the heartbeat, for a type we sample (§1.3)     [D12]
    need = {fam: T.params.SAMPLE_COVER for fam in families(T)}
    for q in links(T):                                 # every link counts, whatever it was opened for
        for fam in counted(need, link_cover(q, T), T): need[fam] -= 1
    while any(n > 0 for n in need.values()):
        cs = [r for r in cover_candidates(T) if counted(need, r, T)]   # node ids and custody counts: before connecting
        if not cs: return                              # nobody for those families now; the next heartbeat retries
        best = max(len(counted(need, r, T)) for r in cs)
        r = choice([r for r in cs if len(counted(need, r, T)) == best])   # most families covered, at random among equals
        open_sampling_link(r, T)                       # JOIN (DECLARED, NONE): no relation, no push, no offer
        for fam in counted(need, r, T): need[fam] -= 1

def keep_floor(T):                                     # at the heartbeat: the links §1.4's floor forms on
    for fam in families_with_duty(T):
        short = T.params.F_LO - len(floor_links(T, fam))   # a link counts from its opening, joined or not
        if short <= 0: continue
        rs = [r for r in floor_candidates(T) if fam in r.families]   # node ids and custody counts: before connecting
        for r in sample_without_replacement(rs, min(short, len(rs))):
            open_link(r, T)                            # JOIN; maintain_relations grafts on it
```

Scoring GRAFT floods is the client's, as in gossipsub, and so is the backoff after a PRUNE on
gossipsub's wires (§7); what this document fixes is that a relation exists only after both ends
agreed it, and how each end learns that. A PRUNE names its direction from its sender's side, as a
GRAFT does, so `on_graft` refuses an offer to push with `IN` and a request to be pushed with `OUT`.

**A GRAFT is answered.** A node that accepts a GRAFT says so with its own GRAFT for the same
relation, from its side: an offer to push it is answered "push me", a request to be pushed "I will
push you". A node that refuses it answers with a PRUNE, as before. One GRAFT goes unanswered: one
for a pair of family and colour new to a link that is at its limit of relations (`MAX_RELATIONS`,
below).
- **Each end's relation.** The answering end is in the relation from its yes. The GRAFT's sender
  keeps its GRAFT unanswered (`grafted_out`, `grafted_in`) and is in the relation from the yes it
  receives: only then does it push, count the pusher, or send it holdings. A GRAFT of the other end
  that crosses its own on the wire is that yes, so two ends that graft each other at once agree
  without a third message. A yes that comes when the relation is no longer wanted is refused, as a
  GRAFT would be. An unanswered GRAFT counts for nothing: its peer is not grafted again meanwhile,
  and the next heartbeat grafts another candidate while the floor is short.
- **A PRUNE ends the relation at both ends**: at its sender's at once, at the receiver's when it
  arrives, and with it any GRAFT of the receiver's for that relation still unanswered. A GRAFT that
  reaches a node with nothing of its relation is a new one and is answered; one that reaches a node
  holding the relation is answered yes again (below).
- **Order.** The answer rests on a link's GRAFTs and PRUNEs arriving in the order they were sent.
  The queue keeps control in its order (§4.12). One that a full queue refuses is owed, every later
  one waits behind it, and the writer queues them in that order once there is room
  (`send_relation`, `queue_owed_relations`, §4.11), so none is lost while the connection lasts. A
  binding that merges entries puts at most one GRAFT or PRUNE of a relation in one frame.
- **For a moment, not at rest,** the ends can differ where a PRUNE crosses a later GRAFT of the
  same relation: the PRUNE also ends that GRAFT at its sender, while the other end may accept it.
  For as long as the yes takes to arrive, one end is in a relation the other has left; the yes then
  reaches an end with nothing of the relation and is decided as a new GRAFT.
- **On gossipsub's wires** (§7) no answer comes, since a stock peer accepts in silence. There a
  GRAFT's sender is in the relation from its GRAFT and runs `join_push` at once, as `seacast-lite.md`
  §5.4 does, and the two ends' agreement rests on gossipsub's backoff after a PRUNE.

**A GRAFT for a relation already held is answered yes again.** A node that holds a relation and
receives a GRAFT for it answers yes again (`yes`), where it answered nothing
before, unless that GRAFT is the yes to its own GRAFT or is itself a yes.
- **A yes is marked.** A yes is itself a GRAFT, so an end that answered every GRAFT for a relation
  it holds would answer a yes. Where a PRUNE crosses a later GRAFT (above), both ends then hold the
  relation and would answer each other's yes for ever. So a GRAFT says whether it is a yes
  (`answer`, §2), and a yes for a relation its receiver holds is not answered. A yes that reaches
  an end with nothing of the relation is still decided as a new GRAFT, and answered as one.

**A symmetric relation.** A type with `SYMMETRIC` keeps one relation both ways per family and
colour; gossipsub's mesh is such a type, with `M = 1`, `F_LO = Dlo`, `F_HI = Dhi` and `D_OUT = D`
(§6.1). Its GRAFTs and PRUNEs have direction `BOTH`. A GRAFT is decided as one at the receiver, by
its cap `F_HI`, its own part in the family and its duty, and answered with one GRAFT or one PRUNE; a
PRUNE ends both directions. A GRAFT for a relation the receiver holds in either direction makes it
whole there and is answered yes again (above). The node keeps the relation as gossipsub's heartbeat
keeps its mesh: below `F_LO` it grafts up to `D_OUT`, and at `F_HI` it prunes down to `D_OUT`,
choosing at random. A relation it holds in one direction only, by lost state or a peer's error, it
grafts again at any count, unless its own GRAFT for it is unanswered: the other end makes it whole
and answers yes, or refuses it, and the ends agree either way. Without this, a relation held one way
stays so wherever no count calls for a GRAFT or a PRUNE: an end grafts only a peer outside the
relation, below its floor, and prunes only at its cap.
- **One-way relations** are kept as before. A node keeps its in-relation between `F_LO` and `F_HI`
  and its out-relation at `D_OUT`.

**A candidate's interest holds the family.** `candidates` takes only peers whose interest holds the
family (`link_cover`), in both directions: a peer asked to push the family receives it only then,
and a peer offered it wants it only then.

**The backoff after a PRUNE.** A PRUNE that a node receives starts a backoff for the relation it
names, from the receiver's side: the peer, type, family, colour and direction. Until the backoff
runs out, `candidates` passes that peer over for that relation. A GRAFT the peer sends meanwhile is
decided as any other. `PRUNE_BACKOFF` is stated by its bounds (§6.3). A PRUNE for a pair new to a
link at its limit of relations starts no backoff (below). A backoff that has run out is dropped, at
the latest when the peer's next PRUNE is handled (`on_prune`), and a `PRUNE_BACKOFF` of zero keeps
none.
- **Its bounds.** The backoff lasts at least a round trip, so that a peer that refused is not asked
  again before its refusal could change. It lasts at most as long as a node may stay below its
  floor once its candidates have refused: a deficit lasts until a GRAFT after the backoff is
  accepted.
- **Agreement is not touched.** The backoff only holds back when a node grafts, never how a GRAFT
  or PRUNE is handled. On gossipsub's wires the backoff is gossipsub's (§7).

**A JOIN is owed too.** A node sends its JOIN for an object type once per link, through `send_join`:
when it opens the link, a sampling link's included (`open_sampling_link`), or in answer to the
peer's (`on_join`).
- **Owed as a GRAFT is.** A JOIN that a full queue refuses is owed, every later JOIN, GRAFT and
  PRUNE of the connection waits behind it, and the writer queues it on the urgent lane, where a
  JOIN goes, once there is room. `join_sent` records it at once, sent or owed, so the node never
  sends two.
- **No link before it.** The node counts the peer as a link for the type (`links`) only once its
  own JOIN is queued, so its JOIN reaches the peer before any GRAFT, holding, offer or WANT of the
  type.
- **On gossipsub's wires** a JOIN is a subscription (§7): both ends send theirs when the
  connection opens, and one made later goes to every peer, so none is an answer. A sampler's
  `(DECLARED, NONE)` writes nothing there, so it is never owed (`seacast-bindings.md` §6).

**A JOIN for a type the node does not run, and a GRAFT or PRUNE for a type not joined, leave no
state,** as §2 says. A JOIN for an object type the node does not run is ignored
(`runs_type`): the node stores nothing and sends no JOIN back. A GRAFT or a PRUNE for a type the
link has not joined (`joined`: the link is one of `links(T)`, the peer's JOIN received and the
node's own queued, not owed) is ignored too: no relation, no pending GRAFT, no backoff and no
answer; so is a WANT (§4.5). None of them is penalised. Without the check, a peer could make the
node hold JOINs for types it does not run, and relations and backoffs for types it never joined with
that peer.

**A link has at most `MAX_RELATIONS` pairs of family and colour of a type** (§6.3), counting every
state a pair can be in at the node: a relation either way, a GRAFT of its own not yet answered, a
backoff not yet run out, and a GRAFT or PRUNE of its own still owed to the peer (`relation_room`).
Once the link is at the limit, a GRAFT for a pair new to it is ignored, with no answer, so that
refusals for new pairs cannot pile up among the owed messages; a PRUNE for a new pair sets no
backoff; and the node's own upkeep grafts none: it passes over a candidate whose link has no room
(`maintain_relations`, `graft`). None is penalised. A pair the link already has is handled as
before. The bound is at least the families of the node's own interest times `M`, so it never
refuses what an honest peer asks, since an honest peer grafts only a family the other end's
interest holds.

**Open: the answers owed for one pair.** A GRAFT repeated for a pair the link already has is
answered each time, and while the writer is blocked each answer is owed, so one pair can account
for many owed messages. Merging an owed answer with a later one for the same pair, keeping the
exchange's order, is left to a later version.

**A peer that joins a push relation is announced what the node holds.**
- **What is announced** (`join_push`) is what the node stores of each live group of the relation's
  family, received or rebuilt, of the relation's colour, minus what the peer holds, was pushed or
  does not want (`announce`). This announcement omits the decode claim and anything of an expired
  or dropped group.
- **When.** It runs where a relation in which the node pushes comes into being at its end: at a
  GRAFT it accepts, and at the yes to its own (`on_graft` either way), a round trip after
  `seacast-lite.md`, which runs it at the node's own GRAFT at once. On gossipsub's wires it runs there
  too, as in `seacast-lite.md`. A GRAFT that adds nothing runs nothing. Relations end with the
  connection, so a reconnection is announced again once it is grafted again.

**`keep_coverage` reads custody, never a sample:** it runs before the node knows what it will
sample, and whatever it samples. A node of high custody counts for at most `COVER_HIGH` families. A
sampling-only link that has served nothing for a while is not pruned for that; how long the floor's
links are kept, and whether they rotate, is the rendezvous's (§8).

**The floor's links.** `keep_floor` keeps, for each family a node has duty in, at least `F_LO` links
to peers whose interest holds the family: the links that §1.4's floor per colour forms on. A link
counts from its opening, joined or not, so that a node opens no second link while the first one's
JOINs cross. The links it opens are drawn at random from the rendezvous's nodes whose custody holds
the family, each with the node's own JOIN, and `maintain_relations` grafts on them.
- How long its links are kept, and whether they rotate, is the rendezvous's, as for the coverage
  floor.

#### Rationale

**A refusal names its direction from its sender's side** (decided 2026-11-01). The refusals had
echoed the GRAFT's direction, which undid the opposite relation at the grafter.

**A GRAFT is answered** (decided 2026-11-04).
- **Why.** Silence cannot tell a yes from a GRAFT not yet read, refused by a full queue or ignored.
  Counted at once, a GRAFT that is never accepted leaves its sender pushing a peer that does not
  count it, or counting a pusher that does not push, and the floor per colour (§1.4) is only as
  good as its count. Gossipsub keeps the two ends' views together with its backoff after a PRUNE,
  which must outlast the round trip at both ends. Here the agreement rests on no timer, and the
  backoff only paces the next GRAFT. The cost is a control message per accepted GRAFT, and an offer
  to push takes effect a round trip after the GRAFT, where silence let it start at once; a request
  to be pushed takes effect when the pusher says yes, as before. A peer that agrees and then does
  not push is not caught by this, as it was not before.
- **Checked** (`toy/graft_check.py`): the check runs this section's functions as written, on two
  nodes, from the link's first JOIN, sent by either end or both, for one relation over an ordered
  connection with queues of one entry and other traffic taking their room, with each end's upkeep
  grafting or pruning up to three times and every GRAFT accepted or refused at will. In every state
  with nothing queued, owed or on the wire, the two ends agree and no GRAFT is unanswered, and every
  exchange ends. The check fails where it should: on the text before this rule
  (`toy/controls/graft-unanswered.md`), where the GRAFT's sender recorded nothing (the ends disagree
  in nearly half of such states at two upkeep steps), and on this rule without the owing, with an
  owed message overtaken, without the yes, or with a PRUNE that leaves the receiver's GRAFT standing
  (seacast-figures.md, §4.1). The toy's recorded cells keep their relations static and do not
  run this; under `--upkeep on` it runs this section on the wire.
- **Compared** (`toy/graft_check.py --model`: one relation in the abstract, without queues, four
  upkeep steps per end): with the relation counted at the GRAFT, many states at rest disagree
  without a backoff, and none do with a backoff longer than the round trip; with the GRAFT answered,
  none do (seacast-figures.md, §4.1).

**A GRAFT for a relation already held is answered yes again** (decided 2026-11-09).
- **Why.** From ends that agree, the rules keep them agreed (Checked, above). Where they diverge,
  one end in a relation the other has left through lost state or a peer's error, the other end's
  GRAFT for that relation went unanswered: its sender kept it unanswered and never grafted that peer
  again for the relation, while the receiver counted a pusher that did not push, or pushed a peer
  that did not count it. When the sender receives the repeated yes, it joins the relation it asked
  for, and the ends agree.
- **Checked** (`toy/graft_check.py --diverged`). The check starts from linked ends that disagree:
  one counts a pusher that does not push, or pushes a peer that does not count it; with `--both`,
  the two ends hold the relation in any way but whole at both or at neither. At three upkeep steps,
  every state at rest once an upkeep has acted agrees, with no GRAFT unanswered, and every exchange
  ends (seacast-figures.md, §4.1). The text before (`toy/controls/held-graft-unanswered.md`)
  fails: a GRAFT for a relation the receiver holds goes unanswered in some states at rest, at two
  steps. Without the mark, the check finds an exchange that never ends, at two steps. One end's
  PRUNE crosses the other's later GRAFT, the first end accepts that GRAFT, the second decides its
  yes as a new GRAFT, and the two then answer each other's yes for ever.

**A symmetric relation** (decided 2026-11-09).
- **Why at `F_HI`.** Gossipsub's heartbeat prunes a mesh above `D_high` down to `D`, and a mesh gets
  there because, at `D_high`, gossipsub v1.1 refuses only a GRAFT from an inbound connection. Here
  `on_graft` refuses at `F_HI` for every peer, so a prune that waited for more than `F_HI` would
  never run: the relations would rest wherever the GRAFTs left them, near `F_HI`, and cost more
  bytes wherever every relation is pushed (tier 1). In the toy (the payload at 60 nodes, under
  `--upkeep on` with links replaced, one seed), with a prune only above `F_HI` no node was ever
  pruned, and nodes ended at the cap, `F_HI`. With the prune at `F_HI`, no node ended at the cap,
  and the relations per node averaged fewer (seacast-figures.md, §4.1).
- **Why at random.** A capped relation is first come, first served: a full node refuses later
  GRAFTs, and near peers' GRAFTs arrive first, so the relations lean on near peers. Gossipsub's
  prune keeps `D_score` peers by score and the rest at random; scoring is the client's, and the draw
  is this rule's.
- **Checked** (`toy/graft_check.py --both`: both ends graft the relation below `F_LO` and prune it
  at `F_HI`). At three upkeep steps, in every state at rest, the ends agree in both directions and
  each end holds both or neither, with no GRAFT unanswered, and every exchange ends. In every state
  at rest of these runs and of `--both --diverged` (above), an end that holds the relation one way
  acts on it with its count between its floor and its cap. The text without that step fails there:
  in some states at rest, at three steps, an end holds the relation one way and neither end's
  upkeep acts. In the first such state that the check records, one end counts the other as a pusher
  and the other holds nothing (seacast-figures.md, §4.1).

**A candidate's interest holds the family** (decided 2026-11-09).
- **Why.** Before, `candidates` took any joined peer with duty, so a column's relations could form
  with peers that neither receive nor want the column, and they carried nothing. The toy has read it
  this way since its upkeep was built.

**The backoff after a PRUNE** (decided 2026-11-09).
- **Why.** Before, the backoff was the client's, and the libp2p stream binding has no client under
  it, so `candidates` asked again, at the next heartbeat, a peer that had just refused. Where most
  of a short node's candidates are at their cap for the relation, a draw at random keeps landing on
  them: with one-way relations capped near their targets the refused GRAFTs repeat at every
  heartbeat, and the relations can take many heartbeats to rest, or not rest within a run.
- **Checked.** Since the backoff touches only when a node grafts, every state `toy/graft_check.py`
  reaches with it is one it reaches without, and the check runs at a backoff of 0.

**A JOIN is owed too** (decided 2026-11-04).
- **Why.** Before, a JOIN that a full queue refused was lost, and with it the link for the type,
  until the connection closed: the peer never had the node's JOIN, so it never counted the node as
  a link. Such a JOIN is one that opens the type, or answers the peer's, on a connection already
  busy with another type.
- **Checked** with the GRAFT (`toy/graft_check.py`, above): at rest, once either end has sent its
  JOIN, both ends hold each other's, and no GRAFT or PRUNE ever reaches a node that has no link for
  it. The check fails on the text before (`toy/controls/join-lost.md`), where a JOIN a full queue
  refused was lost (in some states at rest, at two upkeep steps, a JOIN was sent and the link did
  not form; seacast-figures.md, §4.1), and where `send_join` records its JOIN but does not owe
  it (a GRAFT then reaches a node that has no link for it).

**A peer that joins a push relation is announced what the node holds** (2026-10-26, from
`seacast-lite.md` §5.4's `on_mesh_join`).
- **Why.** Offers come from `forward`, at a chunk's arrival, to the relation for its colour (§4.4).
  Nothing else offers the chunk to a peer that joins the relation after the chunk was forwarded.
  Nothing else offers a peer whose connection closed what the old connection lost, either.
  Heartbeat gossip offers the last three heartbeats' chunks only to peers outside the relations,
  and only for a type whose `ANNOUNCE_EXTRA` is `SAMPLE` (§4.8). A holding is not an offer (§4.3).
  Derived interest lets a custodian be asked without an offer (§4.5), but only samplers, routed
  requests, the repair sample and a custodian's alarm ask that way (§4.6, §4.10).
- **The toy's recorded cells** keep their relations static and do not run this; under
  `--upkeep on` it runs.

**`keep_coverage` reads custody, never a sample.** The links it opens say nothing about the sample
(§1.3). With a node of high custody counted for at most `COVER_HIGH` families, the floor rests on
many peers of ordinary custody rather than on one that claims everything: custody counts are
self-declared, and a node that claims every column would otherwise attract every sampler's floor,
its samples and its load. A sampling-only link is not pruned for serving nothing, since its use is
the samples it may serve.

**The floor's links** (decided 2026-11-09).
- **Why.** Nothing kept that floor at runtime before. `maintain_relations` grafts only among the
  links the node has, and only `keep_coverage` opened links, for a sampler's floor (§1.3). Yet the
  draft assumes it: the rendezvous is per family (§1.1), and §8's route leans on custodians keeping
  a floor per column.
- **Measured** in the toy, in its custody setting at 500 nodes with links replaced during the run
  (seacast-figures.md, §4.1): without the rule, at every seed, some of the nodes at the ends of
  a closed link had not, by the run's end, come back to the number of their (family, colour) pairs
  below `F_LO` that they had before the close; with the rule, far fewer fell short. Against the
  same cells without churn, it also removed most of churn's excess in the share of (node, family,
  colour) below `F_LO`, but not all of it. It cost more JOINs and GRAFTs per node and message gap,
  the more so the more links were replaced. Every node completed, and the warm block's 99th
  percentile moved within the toy's noise. These runs predate 2026-11-16. Since then, the toy's
  close also drops the closed peer's offers, tries, promises and ties, and keeps its park (§3's
  lifetimes, `seacast-lite.md` §8.1). They were not run again.

### 4.2 A chunk arrives

```python
def on_chunk(p, f):
    mid = chunk_id(f)
    if seen(mid) or mid in pending_ids:                # a duplicate, a chunk rejected before, or one waiting
        if accepted(mid):                              # (R5) the claimant's copy passes its probe, a duplicate too
            for (g, i) in type_of_group(f.group).project(f): probe_answer(g, i, p)
            send_have(p, f.group)                      # [c14] duplicates are acknowledged too
        elif mid in pending_ids: tie(p, f)             # another copy of one that waits: its sender too
        return
    if expired(f.group) or not live(f.slot): return    # past its lifetime or live window (seacast-lite.md §8.1)
    T = type_of_group(f.group)
    on_validated(p, f, T.verify(f, T.header_of(f)))   # level 1; DEFER while the gate is closed

def on_validated(p, f, result):
    if expired(f.group) or not live(f.slot): return    # expired or out of the window meanwhile (seacast-lite.md §8.1)
    if result == DEFER: return defer(p, f)             # seacast-lite.md §4.2: the bounded per-peer store
    mark_seen(chunk_id(f))                             # accepted or rejected: never validated again
    if result == REJECT: return penalise(p)            # level 1 failures are the sender's
    T = type_of_group(f.group)
    new = [(g, i) for (g, i) in T.project(f) if not received[g].has(i)]   # a second id for a received index: only acknowledged (fill), as seacast-lite.md
    for (g, i) in T.project(f): fill(g, i, f, p)       # (R4) one arrival fills every group it belongs to
    acting = [(g, i) for (g, i) in new if not expired(g) and state[g] != INVALID]   # a dropped group is not acted on (§4.6)
    if any(duty_for(g) == FORWARD for (g, i) in acting): forward(f, p, acting)   # §4.4: on any axis we serve; never waits for level 2
    for (g, i) in T.project(f): check_completion(g)    # §4.6

def fill(g, i, f, p):
    if expired(g): return                              # an expired group is not taken up again (seacast-lite.md §8.1)
    if g not in T_of:
        release_wanted_groups()                        # §4.5: a place that ran out goes before its group opens
        open_group(g, f)                               # hdr[g], T_of[g], interest[g], known_at[g]
        drop_wants_beyond(g)                           # §4.5: its count is known now
        drop_beyond(g)                                 # what named an index it has not goes (seacast-lite.md §4.2, §8.2)
    if state[g] == INVALID: return                     # a dropped group (§4.6)
    if received[g].has(i) or rebuilt[g].has(i):        # a copy of a chunk we hold: acknowledge it
        probe_answer(g, i, p)                          # (R5) a duplicate from the claimant passes its probe too
        return send_have(p, g) if p is not None else None
    store(g, i, f)
    (received if p is not None else rebuilt)[g].set(i) # from the network, or from our own decode (§4.6, R4)
    probe_answer(g, i, p)                              # (R5) the claimant's own copy passes its probe
    kept = probe_promise(g, i)                         # (R5) another peer's copy leaves the probe's promise open
    close_promises(g, i)                               # [c5] the chunk arrived, from anyone
    if kept: promises[kept[0]] = kept[1]
    serve_standing(g, i)                               # §4.10: WANTs that preceded it are answered now
    serve_waiting_probe(g, i)                          # (R5) and a probe that reached us while we decoded
    claim = not mine[g].has(i)                         # not yet claimed (a node past K claimed everything)
    if claim: mine[g].set(i)                           # [c7] only chunks that passed level 1
    ack = {p} if p is not None else set()              # [c14] the sender's acknowledgement
    for q in (suppression_scope(g) | ack) if claim else ack:
        send_have(q, g)                                # [c7] the holding to our pushers, [c14] the sender's ack

def suppression_scope(g) -> Set[PeerId]:
    T = type_of_group(g); fam = T.family(g)
    return {q for q in links(T) if push_in[q][T][fam]}   # whoever may push this family to us

def send_have(p, g):                                   # [c7] a holding: the whole bitmap, urgent
    h = holding_of(g, have_bits(g))
    if g in origin and MERGE_HOLDINGS and merge_waiting(p, h): return   # [P4] merged (§4.7)
    send(p, h, urgent=True)

def holding_of(g, bits) -> Have:                       # §1.5: the two claims are not the same
    n = type_of_group(g).index_count(hdr[g])
    if g in origin:                                    # [P4] a group we publish claims only what has arrived:
        whole = done = popcount(bits) >= n             #   both claims once every chunk is known to, none before
    else:
        whole, done = state[g] == DECODING or popcount(mine[g]) >= n, stop_pull[g]
    return Have(group=g, bits=bits, offer=False, claim_all=whole, complete=done)
```

`have_bits(g)` is v0.4's (§4.2 there): what we hold, or for a group we publish what is known to
have arrived (§4.7). `merge_waiting(p, h)` is the binding's, used only where the node merges
(`MERGE_HOLDINGS`, §6.3, permitted): if a holding of `h.group` to `p` is still in our queue, it now
names its own bits and `h`'s, with `h`'s claims, and the call returns True.

**A second copy of a received index goes no further,** axis by axis. A copy under an id the node has
seen is acknowledged if that id was stored (`on_chunk`). One under an id it has not seen goes
through level 1; where it passes, on an axis whose index the node has already received it is
acknowledged there (`fill`, which also answers a waiting probe) and not forwarded there, as
`seacast-lite.md` §4.2 does with "a second copy of an index under another id". `on_validated` forwards
only on the live axes, with duty `FORWARD`, whose index it had not received before the copy, and the
copy is kept for heartbeat gossip only if it is forwarded on some axis. An index held only as
rebuilt, or one the node published, is not received, so a copy of it is forwarded. A network arrival
sets every live axis received at once, but for an axis that already held the index as rebuilt: there
`fill` acknowledges the copy and leaves the axis as it was, and `on_validated` still forwards on it.
Any other axis left without the index beside one that has it received is one expired or dropped at
that arrival, which `on_validated` does not act on.

The gate is the object type's. For the payload, it is the installed block (its descriptor comes
from the bid; `validate_chunk` returns DEFER before it); for cells, it is a validated header, which
may precede the block. A deferred chunk is held in the bounded per-peer store of `seacast-lite.md` §4.2
and §8.2 and resumes when the gate opens. `authenticable(g)` is the gate of `g`'s type: nothing of
`g` is asked for before it opens, and what was offered meanwhile is asked for when it does. For the
payload, that is at v0.5's `on_block_installed` (its §3, §4.4); for cells, it is when the binding
first validates a block's header:

```python
def defer(p, f):                                      # seacast-lite.md §4.2's, at the gate of f's type: the block for
    T = type_of_group(f.group)                        #   the payload, the cell header for cells
    result = T.verify(f, T.header_of(f))
    if result != DEFER: return on_validated(p, f, result)   # the gate opened in the meantime
    if not admitted(p, f): return                     # a group beyond the peer's unknown groups (seacast-lite.md §8.2):
                                                      #   ignored, neither kept nor tied
    tie(p, f)                                         # kept or refused, its sender is tied to the root it names
    if reserve(p, f):                                 # a per-peer reservation in the bounded store (seacast-lite.md §8.2)
        pending[f.beacon_block_root].append((p, f))
        pending_ids.add(chunk_id(f))
    # refused: the copy is not kept, so a later copy is evaluated afresh; its sender stays tied

def on_header_validated(root):                       # (P2) a block's cell header, validated once: the cells'
    groups = dict.fromkeys(cell_groups(root))         #   gate, as installation is the payload's (seacast-lite.md §4.2);
                                                      #   a dict, not a set, only so that the last pass runs in
                                                      #   cell_groups' order, the same on every run; it adds no rule
    cells = [(p, f) for p, f in pending[root] if f.group in groups]
    pending[root] = [(p, f) for p, f in pending[root] if f.group not in groups]   # the payload waits for the block
    for p, f in cells:                                # the cells that waited resume level 1
        pending_ids.discard(chunk_id(f)); release(p, f)
        T = type_of_group(f.group)
        on_validated(p, f, T.verify(f, T.header_of(f)))
    for p, held in tied[root].items():                # their senders' ties for the root's cell groups release:
        for g in [g for g in held if g in groups]:    #   parks lift, last-resort counts clear, each an offer again
            bits = held.pop(g)
            if expired(g): continue
            park[p].pop(g, None)
            offers = joined(p, type_of_group(g))      # §2: an offer only on a link that joined g's type,
            for i in bits:                            #   which is the one a WANT for it may go to
                asked_parked[(g, i)].discard(p)
                if g in hdr and i >= type_of_group(g).index_count(hdr[g]):   # an index the group, known now,
                    continue                          #   has not is dropped (seacast-lite.md §8.2), the others kept
                if offers and not mine[g].has(i): add_offer(Ask(g, i), p)
    for p in [p for p, held in tied[root].items() if not held]:   # a sender with nothing left tied under
        del tied[root][p]; tie_slot.pop((root, p), None)          #   the root: its tie's slot goes too (§8.1)
    if not tied[root]: tied.pop(root, None)
    for g in groups:                                  # every column and row group of the block
        drop_outside(g)                               # §4.5: the asks that came before the header, tested now
        for a in ledger(g): retry_offer(a)            # offered meanwhile, or released, asked for now (v0.5 §4.4)
```

**A copy that waits ties its sender,** as in `seacast-lite.md` §4.2 and §6.1.
- **The tie.** A deferred copy, kept or refused, ties its sender to the root it names, for its group
  and index (`tie`); so does another copy of one that waits (`on_chunk`, as in `seacast-lite.md`). The
  sender is not asked for that index while it waits: not by `on_offer`, nor by `seacast-lite.md`'s
  `retry_offer`, `last_resort` or `ask_parked`, which this document takes as they are, nor by
  `filter_entry` (§4.6).
- **The release.** The gate's opening releases the ties: each sender's park for the group lifts,
  the count of the last resort (`seacast-lite.md` §6.1) for its indices clears, and each index is its
  offer again; an index the group does not have, once its count is known, is dropped instead. A
  cell's copy can tie a sender whose link has not joined the group's type (a cell answered in its
  row while naming its column, §2): its park lifts and its count clears, but its indices are not
  offers, since a WANT for that type would be ignored on that link. A
  sender with nothing left tied under the root loses the slot its ties recorded (`tie_slot`). For
  the payload this is at the block's installation (`on_block_installed`); for cells it is at the
  header (`on_header_validated`, above).
- **What waits is bounded** as in `seacast-lite.md` §4.2 and §8.1, since v0.10, for both object types.
  A copy of a group beyond its sender's limit of unknown groups is ignored, neither kept nor tied
  (`defer`). When a group opens, at its first valid chunk, what named an index beyond its count
  goes: offers, asks, promises, tries and ties (`drop_beyond`, from `fill`). And at each heartbeat,
  what waits for a gate that never opens goes once its slot leaves the live window or its group
  expires (`drop_stale_waits`, from `on_heartbeat`).
- **Tables by group and index** (a note, not a rule). The pseudocode finds what names one chunk by
  scanning whole tables: `drop_beyond` when a group opens, and `seacast-lite.md`'s `close_promises` at
  every arrival, over every promise, offer, try and ask the node holds. That keeps it short, and the
  result is the same either way. An implementation is expected to index these tables by group and
  index, so that an arrival costs a lookup, not a pass over everything the node tracks.
- **Ordering.** `defer` here waits for the gate of the chunk's own type; `seacast-lite.md`'s waited
  for the block alone. Cells leave the store and their ties at the header, so a binding validates
  a block's cell header no later than it installs the block.
- **The second-ask rule.** A node makes no second ask of a peer for a chunk while an earlier one is
  outstanding, queued or promised (`outstanding`, `seacast-lite.md` §6.1): `on_offer` passes over such a
  peer.
- **An ask goes with its announcer's offers** (`seacast-lite.md` §6.1). Where a peer's offers of a chunk
  are dropped, with its tie (`drop_tie`) or 30 s after its last offer of the group, an ask of the
  chunk still queued to it is removed and its promise for the chunk closes (`drop_offer`). This
  document drops offers only on `seacast-lite.md`'s paths, so the rule applies to both object types as
  written.

#### Rationale

**A copy that waits ties its sender** (2026-10-26, from `seacast-lite.md` v0.8). With it, v0.5's offer
of a refused copy is gone.

**A block's cell header before the block** (decided 2026-11-01). The installation would otherwise
resume the cells with the payload's check and drop their ties as forgeries.

**An ask goes with its announcer's offers** (from `seacast-lite.md` v0.8, 2026-10-28). If the node
kept the ask, the ask would leave the peer outstanding. `on_offer` would pass over the peer's next
offer. While this peer is unparked, a parked announcer's offer would draw no last resort. Once the
peer's promise fell due, nothing would ask either peer again, and the pull would stall.

**In the toy** cells carry their header, so their gate is open from the first cell and neither
`defer` nor `on_header_validated` runs there; `toy/seacast_carried_known.py` calls the latter by hand.

### 4.3 A holding or an offer arrives

```python
def on_holding(p, h: Have):                            # seacast-lite.md §4.3's on_have
    if expired(h.group): return                        # past its active lifetime: ignored
    if not valid_have(h): return penalise(p)           # length, and indices within N once known
    if not admitted(p, h): return                      # a group beyond p's unknown groups (seacast-lite.md §8.2): ignored
    e = peer_has[p][h.group]                           # created at p's first holding for the group
    newly = h.bits & ~e.bits
    e.bits |= h.bits
    e.ttl = HAVE_TTL                                   # heartbeats; refreshed by each holding from p
    e.claim_all = e.claim_all or h.claim_all           # [c10]
    e.complete = e.complete or h.complete              # nothing more need go to p for this group (§1.5)
    if h.claim_all and joined(p, type_of_group(h.group)):   # (R5) §4.6: it may defer a decode duty of ours;
        note_claim(p, h.group)                         #   not on a link that has not joined the type (§2)
    for i in newly:
        holders[h.group][i].add(p)                     # [c9] distinct live holders
        window_release(p, h.group, i)                  # [c14] a slot to p frees when p holds i, from anyone
        if h.group in planned: origin_acked(h.group, i)   # [c3, P4] a copy of i exists elsewhere (§4.7)
    for i in h.bits & ~newly:                          # [c14] a bit p held already: a copy written to it since (a
        window_release(p, h.group, i)                  #   probe's answer, §4.6, or any without cancel) frees its slot

def on_offer(p, h: Have):                              # seacast-lite.md §4.4's on_ihave over one group's bitmap; returns asks
    g = h.group
    if expired(g): return []
    if not valid_have(h):                              # held to a holding's limits, as seacast-lite.md §4.4 holds an
        penalise(p); return []                         #   IHAVE's bitmap: ignored, and counted (§8.2)
    if not admitted(p, h): return []                   # a group beyond p's unknown groups (seacast-lite.md §8.2): ignored
    if now - known_at[g] < type_of_group(g).params.START_DELAY:   # [D8] (R7) a secondary axis waits
        return deferred_offers(p, h)                   # recorded as offers; asked when the delay has run
    candidates = []
    for i in h.bits & interest[g] & ~mine[g]:          # offered, wanted, and not held
        a = Ask(g, i)
        add_offer(a, p)                                # [c5] the offer table (v0.5 §6.1)
        if gated(a) or not authenticable(g): continue  # [c6] stop-pull; the gate first (v0.5 §3, §4.2 here)
        if tied_to_root(p, a): continue                # its copy waits for its gate (seacast-lite.md §4.2)
        if parked(p, a): last_resort(a); continue      # [c5] park; every announcer parked: v0.5 §6.1
        if outstanding(p, a): continue                 # an ask of it to p is open (seacast-lite.md §6.1)
        candidates.append(a)
    asks = []
    for a in shuffled(candidates):                     # seacast-lite.md §6.1: one ask per index at a time
        if over_ihave_limits(p): held_back[(group(a), index(a))] = a   # retried at the next heartbeat (§4.8)
        elif may_ask(a, p):
            asks.append(a)
            ihave_asked[p] += 1                        # an ask in reply to p's offers
    return asks
```

**A holding** (`on_holding`) plays the role of `seacast-lite.md` §4.3's HAVE. A holding of an expired
group is ignored, and a malformed one is ignored and counts against its sender: one beyond a
holding's length, or naming an index at or beyond the group's count once the count is known
(`seacast-lite.md` §8.2). A holding of a group beyond the peer's limit of unknown groups
(`MAX_PENDING_GROUPS`, `seacast-lite.md` §8.2) is ignored, without penalty. Otherwise the node adds its
bits to what it knows the peer holds (`peer_has`), whose lifetime each holding from the peer for the
group refreshes (`HAVE_TTL`), and keeps the peer's two claims once set (§1.5): it holds or can
produce every index (`claim_all`, card 10), and its interest in the group is satisfied, so nothing
more need be pushed or offered to it (`complete`). A claim of the whole group can defer one of the
node's own decode duties (`note_claim`, §4.6), if the link has joined the group's type: the probe
that checks the claim is a WANT, which a link that has not joined the type ignores (§2). On a link
that has not, the claim is kept as a plain holding: its bits and its `claim_all` go into `peer_has`,
as any holding's do (so, once the link has joined the type, the peer may be asked for any index,
`may_be_asked`), and the peer is no claimant (`claims`). The subnet's view of the row then counts
its bits if it is in the suppression scope (`known_in_scope`), and the repair sample may draw it
under the sample's own conditions (`ask_custodian`). The peer becomes a claimant only at a holding
that claims the group whole and comes on a link that has joined the type. For each index the peer
newly holds, the node counts the peer as a holder (card 9), frees the window's room taken by any
copy it sent the peer at that index (card 14, §4.11), and, for a group it publishes, takes it as the
chunk's acknowledgement (`origin_acked`, §4.7), which acts once per chunk and does nothing at
`SOURCE_OFFERS = PUBLISH`. An index the peer held already frees the window's room too: a copy can
be written to a peer that holds it (a probe's answer whatever the peer holds, §4.6, and any copy
without cancel, card 8), and its acknowledgement repeats the bit.

**An offer** (`on_offer`) plays the role of `seacast-lite.md` §4.4's IHAVE over one group's bitmap. An
offer of an expired group is ignored, and one beyond a holding's limits is ignored and counts
against its sender, as `seacast-lite.md` holds an IHAVE's bitmap (§8.2). An offer of a group beyond the
peer's limit of unknown groups is ignored, without penalty, as its holdings are. Within the type's
start delay after the group became known (`START_DELAY`, a secondary axis's `[D8]`), each index the
peer offers, the node wants and does not hold is recorded as an offer, and asked once the delay has
run, under the checks of `seacast-lite.md` §6.1's retry (`deferred_offers`). Otherwise each such index
is recorded as an offer (card 5), whatever follows, and becomes a candidate unless stop-pull holds
it back (card 6), the group's gate has not opened (`authenticable`, §4.2), the peer's copy of it
waits for its gate (`seacast-lite.md` §4.2), the peer is parked for the group (then the last resort,
`seacast-lite.md` §6.1, which acts once every untied announcer of the index is parked: it asks the
parked announcers once more each, one at a time, each after a wait of `PROMISE` × 2ⁿ, where n is the
number of parked announcers it has already queued such an ask to for the chunk), or an ask of it to
the peer is open. The candidates are taken in random order. While the peer is over an IHAVE limit,
each is held back (below); otherwise it is asked of the peer if `may_ask` allows (`seacast-lite.md`
§6.1: one ask per index at a time).

- **An offer from any link is an offer.** The announce relation decides who learns what a node
  holds; `seacast-lite.md` §6.1's pull decides whom the node asks, when it moves on and whom it parks.
  Offers never touch `peer_has`, `holders`, cancel or the window, and holdings never feed the offer
  table except in one case: a claim of a whole group that defers a decode duty is taken as an offer
  of the index its probe asks for, from that claimant (`defer_on_claim`, §4.6).
- **Gossipsub's two IHAVE limits apply to offers** (`seacast-lite.md` §4.4). They delay asks and lose no
  offer.
  - `MAX_IHAVE_MESSAGES` counts the offer-bearing frames from a peer within a heartbeat
    (`on_frame`, §4), and `MAX_IHAVE_LENGTH` counts the asks made of the peer in reply to its
    offers. Both count per peer over every object type, as one connection carries them all.
  - Over either limit, the peer's offers are still recorded. What the node would ask of it is held
    back to the next heartbeat (§4.8), which runs `seacast-lite.md`'s retry for it, with the retry's
    checks.
  - Only asks in reply to offers count against the limits: the retry, the last resort, the asks at a
    gate's release and those after the start delay `[D8]` do not.
- **The limits' values are the client's** (`seacast-lite.md` §8.2). `seacast-lite.md` §8.3 gives reference
  values for gossipsub's: 4096 offer-bearing frames and 5000 ids asked, per peer and heartbeat. What
  the values mean depends on the binding (§7, `seacast-bindings.md` §4, §5):
  - on the gossipsub binding, offers are IHAVEs, so a stock gossipsub client applies its own limits;
  - on the libp2p stream binding, the values are the client's alone (§6.3 says which to avoid);
  - on the partial-messages binding, offers travel as `partsMetadata`, not as IHAVEs.

**Open: offers on the partial-messages binding.** Whether the extension limits offers is not checked
here.

#### Rationale

**The reference values hold no ask back in the toy.** At 4096 frames and 5000 ids, the toy's 60-node
cells hold back no ask, under this draft's tier 4 setting, variant C (`c`) and custody, with and
without samplers, nor under the rows setting, with and without half the columns withheld. The
busiest peer stayed well below both values in a heartbeat, in every setting
(seacast-figures.md, §4.3).

### 4.4 A node forwards

```python
def forward(f, from_peer, axes=None):                                      # axes: those on_validated acts on
    for (g, i) in (type_of_group(f.group).project(f) if axes is None else axes):   # (R4) each axis with its own type
        T = type_of_group(g)
        if expired(g) or state[g] == INVALID: continue                     # an expired or dropped axis is not acted on (seacast-lite.md §8.1, §4.6)
        if duty_for(g) != FORWARD: continue                                # no duty on this axis: we only serve asks
        fam, c = T.family(g), colour_of(g, i)
        pushers = [q for q in links(T) if c in push_out[q][T][fam]]        # the relation for this colour
        holding = [q for q in pushers if peer_has[q][g].has(i)]            # [c4] the sender, normally
        cands = [q for q in pushers if q not in holding and q != from_peer
                 and interest_of_peer(q, g).has(i) and not peer_has[q][g].complete]   # [I3] into interest only
        budget = max(0, R_NODE - len(holding)) if T.params.EAGER else 0    # [c3, c4, c11, c17]; rows: offers only
        targets = choose_push(f, cands, budget, at_source=False)           # seacast-lite.md §5.3 unchanged
        for q in targets:
            if enqueue(q, f, urgent=False): note_push(q, g, i)             # [c7, c16]
            else: owe(q, g, bitmap({i}))                                   # [c3] refused: offered instead (v0.5)
        for q in cands:
            if q not in targets: announce(q, g, bitmap({i}))               # [c3] offered instead
        for q in announce_extra(g, i):                                     # [D5] width beyond the relation
            announce(q, g, bitmap({i}))
    if state[f.group] != INVALID: gossip_history.put(f)                    # heartbeat gossip (§4.8); never a dropped group's (§4.6)

def announce(p, g, bits):                                                  # [c3, c7] an offer
    b = bits & ~pushed[p][g] & ~peer_has[p][g].bits & interest_of_peer(p, g)   # an empty bitmap is not sent
    if b and not send(p, Have(group=g, bits=b, offer=True, claim_all=False, complete=False), urgent=False):
        owe(p, g, b)                                                       # refused by a full queue: owed (v0.5)

def announce_extra(g, i) -> List[PeerId]:                                  # [D5]
    T = type_of_group(g); fam = T.family(g)
    if T.params.ANNOUNCE_EXTRA != ALL_JOINED: return []                    # SAMPLE: the heartbeat's paced gossip (§4.8)
    related = {q for q in links(T) if push_out[q][T][fam] or push_in[q][T][fam]}
    return [q for q in links(T) if q not in related and wants_from_me(q, g).has(i)]

def fills(g, i) -> List[Tuple[GroupId, int]]:         # (R4) every (group, index) the chunk at index i of g fills,
    return [(g, i)] + type_of_group(g).cross(g, i)     #   from the ids alone: the chunk need not be stored

def note_push(p, g, i):                                # seacast-lite.md §5.2's, under every group the chunk fills (R4):
    for (g2, i2) in fills(g, i):                       #   a chunk noted through one group is not offered or
        e = pushed[p][g2]                              #   repaired to that peer again through another
        if e.empty(): e.first_push = now               # the guard's clock (§5.3 there), per group
        e.set(i2); e.ttl = PUSH_TTL
```

**A forwarding node's rules are `seacast-lite.md` §5.2 and §5.3** with two changes: the candidates
are the push relation for the chunk's colour instead of the mesh, filtered by the peer's interest;
and the offer's width beyond the relation is a parameter: `ALL_JOINED` for columns and rows, `NONE`
permitted for columns (`[D5]`, §8). With `M = 1`, interest `ALL` everywhere and
`ANNOUNCE_EXTRA = SAMPLE`, the two functions are `seacast-lite.md`'s `forward` and `announce`.

### 4.5 An ask arrives, and serving

```python
def on_want(p, asks):                                  # seacast-lite.md §4.5's on_iwant, plus the serving limit (R6)
    answers = {}                                       # by id: one answer per id per frame
    probes = {(gi.group, gi.index): gi for gi in map(group_index, asks) if gi and gi.probe}   # (R5) the frame's probes
    taken = set()                                      # §4.5: the indices answered in this frame
    for a in asks:
        gi = group_index(a)
        if gi and (gi.group, gi.index) in taken: continue   # §4.5: an index is answered once a frame
        if gi and not joined(p, type_of_group(gi.group)): continue   # §2: a type the link has not joined
        if gi and expired(gi.group): continue          # past its active lifetime: ignored, no penalty
        if gi and gi.index >= index_bound(gi.group): continue   # §4.5: an index the group cannot have: ignored
        hops = gi.hops if gi and join_sent[p][type_of_group(gi.group)].duty == FORWARD else 0   # §4.5: routed
                                                       #   only through a forwarding node; to any other, no hops
        if (gi and outside(p, gi.group, gi.index, hops > 0)   # §4.5: not ours to serve p: ignored, with no
                and not peer_has[p][gi.group].has(gi.index)): continue   #   penalty and no state (p's claim: below)
        if gi and not admitted_group(p, gi.group): continue   # §4.5: beyond p's unknown groups named in WANTs
        declared = gi and join_recv[p][type_of_group(gi.group)].interest == DECLARED
        if declared and not (hops > 0 and not our_interest_for(p, gi.group).has(gi.index)):
            want_p[p][gi.group] = want_p[p].get(gi.group, EMPTY) | bitmap({gi.index})   # its WANT is its
                                                       #   interest (§1.2), but for a routed one outside ours
        flagged = probe_of_claim(p, gi) or (           # (R5) p's probe of our claim: answered whatever p holds; a
            gi is not None and probe_of_claim(p, probes.get((gi.group, gi.index))))   # plain ask of an index the
                                                       #   frame also probes is that probe, if it would pass as one
        if gi and peer_has[p][gi.group].has(gi.index) and not flagged:
            penalise(p)                                # it asks for a chunk it claimed: the claim wins
            continue
        if gi and served[p][gi.group] >= type_of_group(gi.group).params.SERVE_LIMIT:
            continue                                   # (R6) refused without penalty
        mid = resolve(a)                               # [c7] our chunk at that index: received or rebuilt
        if mid is None:                                # gi carries its WANT's fields (§2)
            passed = gi and hops > 0 and route_want(p, gi.group, gi.index, hops)   # §4.10: one step on
            if flagged and p not in probe_waiting[gi.group]:   # (R5) claimed, not stored: we are decoding; the
                probe_waiting[gi.group][p] = gi.index  #   first per asker and group is answered when it is (§4.6),
                standing[gi.group][gi.index].discard(p)   #   once: in place of p's standing WANT of that index,
                routed_standing[gi.group][gi.index].discard(p)   #   whether it came before the probe or after it
            elif (gi and (declared or gi.standing) and probe_waiting[gi.group].get(p) != gi.index
                  and (hops == 0 or passed or our_interest_for(p, gi.group).has(gi.index))):
                standing[gi.group][gi.index].add(p)    # §4.10: answered when the chunk arrives; a routed one
                if hops > 0: routed_standing[gi.group][gi.index].add(p)   #   outside our interest only if passed on
            continue
        if mid in answers:                             # §4.5: an id is answered once a frame, and counted once; a
            if flagged: serve_probe(p, gi.group, answers[mid])   #   probe of the cell through its other type takes
            continue                                   #   its exemption on the answer already chosen (R5)
        if mid in unwanted[p] and not flagged: continue    # (R5) nor does a receipt of p's stop the probe's answer
        if serve_count[p][mid] >= GOSSIP_RETRANSMISSION: continue   # stock: 3 answers per id per peer
        counted = not flagged and not (gi and offered_to[p][gi.group].has(gi.index))   # §4.5: the budget counts
                                                       #   an answer given: not a probe's, not one on our offer
        if counted and served_hb[p] >= SERVE_BUDGET: continue   # over it: refused without penalty
        if counted: served_hb[p] += 1
        serve_count[p][mid] += 1
        if gi: served[p][gi.group] += 1
        if flagged: serve_probe(p, gi.group, chunk_of(mid))  # (R5) answered: the probe's one exemption, taken
        answers[mid] = chunk_of(mid)
        if gi: taken.add((gi.group, gi.index))
    return list(answers.values())                      # [c14] one chunk per queue entry (seacast-lite.md §4.1)

def serve_standing(g, i):                              # §4.10: the chunk a WANT waited for is here
    routed_standing[g].pop(i, None)                    # §4.5: the route marks go with the requests
    for q in standing[g].pop(i, ()):
        if peer_has[q][g].has(i) or served[q][g] >= type_of_group(g).params.SERVE_LIMIT: continue
        counted = not offered_to[q][g].has(i)          # §4.5: the budget counts it, unless it asked on our offer
        if counted and served_hb[q] >= SERVE_BUDGET: continue   # over it: dropped, without penalty
        if counted: served_hb[q] += 1
        served[q][g] += 1
        if not enqueue(q, Entry(chunk=chunks[g][i], solicited=True), urgent=False):   # an answer, like any
            owed_answers[q][g].set(i)                  #   other: refused by a full queue, owed (v0.5 §7.2)
        note_push(q, g, i)                             # so that no offer follows it (§4.4)

def serve_waiting_probe(g, i):                         # (R5) the cell a kept probe waited for is stored, received or
    for q in [q for q, j in probe_waiting[g].items() if j == i]:   # rebuilt: answered as on_want answers a probe,
        del probe_waiting[g][q]                        #   with its one exemption
        if probe_served[q][g] or served[q][g] >= type_of_group(g).params.SERVE_LIMIT: continue
        served[q][g] += 1
        serve_probe(q, g, chunks[g][i])
        if not enqueue(q, Entry(chunk=chunks[g][i], solicited=True), urgent=False):   # an answer, like any
            owed_answers[q][g].set(i)                  #   other: refused by a full queue, owed (v0.5 §7.2)
        note_push(q, g, i)                             # so that no offer follows it (§4.4)

def route_want(p, g, i, hops):                         # §4.10: a routed sample request we cannot answer, one step on
    T = type_of_group(g)
    if join_sent[p][T].duty != FORWARD or forwarded[p][T] >= T.params.FORWARD_LIMIT:
        return False                                   # (X6) refused without penalty: the sampler's wait moves it on
    qs, left = [q for q in links(T) if q != p and serves(q, g, i) and not parked(q, Ask(g, i))], 0
    if not qs and hops > 1:                            # no link serves it: one more step, toward the family
        qs, left = route_next(T, T.family(g), [q for q in links(T) if q != p
                                               and join_recv[q][T].duty == FORWARD]), hops - 1
    if not qs: return False                            # no route: silence, as above
    if not send(choice(qs), Want(group=g, bits=bitmap({i}), standing=True, hops=left), urgent=False):
        return False                                   # a full queue refused it: not passed on, not counted
    forwarded[p][T] += 1
    return True                                        # passed on

def may_be_asked(p, g, i, routed=False) -> bool:       # (P7) scoring reads interest
    T = type_of_group(g)
    return (offered_us(p, g, i) or interest_of_peer(p, g).has(i) or peer_has[p][g].claim_all
            or routed and join_recv[p][T].duty == FORWARD)   # [D12] a routed request may go to any forwarding node

def outside(p, g, i, routed) -> bool:                  # §4.5: may_be_asked as p reads us is false, once we can tell:
    T = type_of_group(g)                               #   the gate is open, so our interest in g is known
    if not authenticable(g) or g in origin or mine[g].has(i): return False   # held, or claimed whole (decoding)
    if routed and join_sent[p][T].duty == FORWARD: return False   # [D12] a routed request to a forwarding node
    return not our_interest_for(p, g).has(i)           # never offered: an offer names only what we hold

def index_bound(g) -> int:                             # §4.5: the group's count once known, else the most indices
    T = type_of_group(g)                               #   a group of its type has
    return T.index_count(hdr[g]) if g in hdr else T.params.MAX_INDICES

def drop_wants_beyond(g):                              # §4.5: the count now known, what was kept before it loses the
    n = type_of_group(g).index_count(hdr[g])           #   indices past it: standing requests and their route marks,
    for i in [i for i in standing[g] if i >= n]:       #   and a DECLARED peer's interest bits
        standing[g].pop(i, None); routed_standing[g].pop(i, None)
    for q in [q for q in want_p if g in want_p[q]]:
        want_p[q][g] = want_p[q][g] & ~bitmap({i for i in want_p[q][g] if i >= n})

def our_interest_for(p, g) -> Bitmap:                  # §4.5: our interest in g as we declared it to p
    T = type_of_group(g); j = join_sent[p][T]
    if j.interest == ALL: return EVERY_INDEX
    if j.interest == DERIVED: return T.derived_interest(g, hdr.get(g), own_id(), j)
    return EMPTY                                       # DECLARED: a sampler is asked only for what it holds

def drop_outside(g):                                   # §4.5: what came before the gate, tested once it opens: a
    for i in list(standing[g]):                        #   standing request, and the index a DECLARED peer's WANT
        for q in [q for q in standing[g][i] if outside(q, g, i, q in routed_standing[g][i])]:   # added to its
            standing[g][i].discard(q); routed_standing[g][i].discard(q)                         #   interest
    for q in [q for q in want_p if g in want_p[q]]:
        want_p[q][g] = want_p[q][g] & ~bitmap({i for i in want_p[q][g]
                                               if outside(q, g, i, q in routed_standing[g][i])})
```

**A node serves what it holds**, received or rebuilt, to anyone who asks, within the serving limit
per peer and group `[R6]`, whatever the asker's duty. An ask may go to a peer that offered the index
or whose derived interest includes it (a custodian can be asked without offering, PeerDAS's "knows
exactly what a peer should be able to respond to"); an ask outside both is ignored (below), unless
it is a routed request and goes to a peer with duty `FORWARD`. A promise is made by an offer, and a
broken one parks the peer for the group (`seacast-lite.md` §6.1). A `DECLARED` peer's WANT is also its
interest: `want_p[p][g]` is set from it before the asks are answered, and what the peer does not
hold yet is kept as a standing request (§4.10). An ask by derived interest makes no promise with a
timer either: an ask marked `want` (§3), one sent in a WANT and not on an offer, starts none,
except a claim's probe (`filter_entry`, §4.6). The custodian answers from what it holds, and keeps
the ask for later only as a standing request: a `DECLARED` peer's WANT, or one marked `standing`. A
claimant still decoding also keeps the probe of its claim (`probe_waiting`, §4.6). A standing
request is answered when the chunk is stored, received or rebuilt (`serve_standing`, from `fill`,
`decode_group` and `publish`). Standing requests live with the group's state (`GROUP_TTL`) and
count against the serving limit when answered. A WANT for a type the link has not joined is ignored
(§2, `joined`).

**An ask outside what a node serves is ignored** once the group's gate is open (`outside`; the gate
is `authenticable`, §4.2). Such an ask is for an index the node does not hold, outside its interest
as it declared it to the asker (`our_interest_for`, from `join_sent[p][T]`), in a group it has not
claimed whole, and it is not a routed request to a node whose duty towards the asker is `FORWARD`
(`[D12]`). The node answers nothing, keeps no standing request and no bit of a `DECLARED` peer's
interest for it, and does not penalise the asker. An offer names only what the node holds, and its
holdings only grow within the group's lifetime, so the test needs no record of the node's offers. A
node that claimed the group whole and is still decoding holds every index in `mine`. An ask that
comes before the gate is kept as any ask is, and tested when the gate opens (`drop_outside`, from
`on_header_validated`), its standing request and its interest bit alike; a routed one is marked
(`routed_standing`), so that the test still exempts it, and the mark goes with the standing request.
An ask for an index the asker itself claimed is penalised as before.
- *Why no penalty.* The asker's view can lag the node's honestly: a header the asker holds first, a
  JOIN or an offer in flight. In the toy's custody runs with samplers, the asks a strict test would
  call outside were all such races: a sampler's standing WANT reaching a custodian before the
  custodian had validated the header, for a column it custodies (seacast-figures.md, §4.5). The
  rule therefore ignores without penalty, and tests what came before the gate once the gate opens.
  Without the rule, such an ask kept a standing request, or a bit of a `DECLARED` peer's interest,
  that the node could never answer until `GROUP_TTL`: a table any peer could grow.

**A WANT is held to two bounds** before it can leave any state, as `seacast-lite.md` §8.2 holds HAVEs
and offers.
- *Its index.* An index at or past the group's count, once the node knows it (`hdr`), is ignored;
  before the count is known, an index at or past the most a group of the type has
  (`TypeParams.MAX_INDICES`, `index_bound`) is. When the count becomes known, as the group opens,
  the standing requests, their route marks and the `DECLARED` peers' interest bits kept before it
  lose the indices past it (`drop_wants_beyond`, from `fill` and from `publish`).
- *Its group.* A group the node has not opened (at its first valid chunk, `hdr`) counts against
  the asker's limit of unknown groups named in WANTs (`admitted_group`), whatever else the node
  keeps for it, another peer's standing request included: `MAX_PENDING_GROUPS` of them, counted
  apart from the unknown groups of the asker's HAVEs and offers (`seacast-lite.md` §8.2). An ask takes a
  place only once it has passed the test of what the node serves. A group frees its place when it
  resolves, when the connection closes, or when its lifetime would have passed (`GROUP_TTL` after it
  was first named), and then the asker's standing requests and interest bits for it go too. The node frees
  places at each heartbeat at the latest, and before a group opens, so that a place that ran out is
  not answered when its group comes (`release_wanted_groups`). An ask beyond the limit is
  ignored. The limit is at least the column and row groups that an honest sampler or forwarder asks
  for before the groups open at the node within a place's lifetime: those of the blocks in the
  node's live window, and more where `GROUP_TTL` outlasts the window.

Neither is penalised, and neither keeps a standing request or a bit of a `DECLARED` peer's interest.
Without them, a WANT for an index that does not exist kept a standing request that nothing could
answer, and WANTs for groups that never come kept entries that `expired` never reaches, since such a
group has no lifetime.

**A node answers one peer at most `SERVE_BUDGET` chunks a heartbeat** across groups (`served_hb`),
as `[R6]`'s limit bounds one group. An answer counts in the heartbeat in which the node decides to
give it, whether it is then written, queued or owed; a standing request's answer counts when its
chunk arrives. Not counted: an answer to an ask on the node's own offer, and one to a claim's probe.
The node records its offers to the peer as its writer writes them (`noted`, `offers_in`), whichever
path queued them, an announcement or an offer owed through a full queue; without that exemption, a
node that had spent its budget would offer chunks and then refuse them. Nor is an answer the node
does not give counted: one the stock limit of three answers per id refuses. An id asked twice in one
frame is answered once, and counted once, against the budget, the stock limit and `[R6]`'s. A plain
ask of an index that the same frame also probes is handled as that probe, if the probe would pass as
one (§4.6's cap): the one answer, at the first of the two asks, is the probe's, with its exemptions,
and the asks between them are handled in their order. A probe that would not pass leaves the plain
ask as it is, its standing request included. A cell asked through both its types in one frame, a
plain ask in one and a probe that would pass in the other, is one id and is answered once. The ask
that gives the answer is charged for it: the first of the two that is not refused, against its own
group's `SERVE_LIMIT` and, if it is a plain ask not on the node's offer, the budget. A probe read
after a plain ask gave the answer takes the probe's exemption for that answer, unless the probe's
group has reached `SERVE_LIMIT` by then (an ask between the two can take the last answer): the
probe is then refused at the limit, as any probe there is (§4.6). The stock limit
holds for the answers `on_want` gives; a standing request's answer and a kept probe's are given once
each, as before. An ask over the
budget is refused, and a standing request's answer dropped, without penalty; the node does not retry
a dropped answer, and the asker's wait moves it on (§4.10). The budget starts again at each
heartbeat. Its bound (§6.3) covers what honest peers ask through one peer in a heartbeat other than
on the node's offers. Without it, where `SERVE_LIMIT` is unbounded, a peer could have a node answer
every chunk it holds up to three times an id, every heartbeat.

**A routed sample request** (a WANT with `hops` above zero, §4.10) may also go to a peer with duty
`FORWARD` that neither offered the index nor custodies it `[D12]`. That peer answers it from what it
holds, and, at most `FORWARD_LIMIT` times per asking peer and slot, passes it one step on: to a link
that serves the index, with `hops` 0, or, where none does and steps are left, to the link nearest
the index's family (`route_next`, §1.3's routing neighbours) with one step fewer. It keeps the
request standing for the rest only if it passed it on, or if its own interest holds the index; so
the routed standing requests outside its interest that a peer can add at a forwarder in a slot are
bounded by `FORWARD_LIMIT`; those already standing stay, across the slot's reset, until they are
answered or dropped with the asker's state for their group. A request
is passed on, and counted against `FORWARD_LIMIT`, only once the next peer's queue admits it
(`route_want` says whether it did). A routed request outside the forwarder's interest adds no bit to
a `DECLARED` asker's interest there, before the gate or after it. Each WANT it sends is its own and
standing, and what comes back is answered on as any standing request, so the cell returns the way
the request went, and each node on the way sees only the one before it. A forwarder that has no such
link, or is past its limit, says nothing, and is not penalised: the sampler's wait moves it on. Its
interest does not grow: what it asked for on a sampler's behalf comes to it as an answer, not as a
push into its interest (I3). The fields are the asker's to set and cost the receiver only what it
answers and passes on; a routed request to a peer without duty `FORWARD` is read as a WANT without
`hops`.

### 4.6 Completion, the claims, decoding and repair

```python
def check_completion(g):
    T = type_of_group(g)
    if state[g] != COLLECTING or interest[g].empty() or not interest_satisfied(g): return
    stop_pull[g] = True                                # [c6] no further asks for the group
    if T.params.DECODE_AT_K(g):                        # [c10] the decode claim at K, before decoding   [D4]
        state[g] = DECODING
        mine[g] = all_bits(T.index_count(hdr[g]))
    else:
        state[g] = COMPLETE                            # e.g. a row member at K: complete, no claim_all (R2)
        later = T.params.DECODE_LATER(g)               # a later duty, if the group is still short then   [D4]
        if later is not None: arm(g, known_at[g] + later)
    for q in suppression_scope(g): send_have(q, g)     # complete; and claim_all when decoding
    close_promises_of_group(g)                         # [c5] nobody owes us chunks of this group
    if state[g] == DECODING: start(decode_group, g)    # level 2, off the chunk path

def arm(g, at):                                        # a decode duty that fires unless the group fills first
    reconsider_at[g] = at
    after(max(0, at - now), reconsider, g, at)

def known_in_scope(g) -> Bitmap:                       # what we and our relation peers hold of g, by their holdings
    known = mine[g].copy()
    for q in suppression_scope(g):
        if q in claims[g]: continue                    # (R5) an unverified claim counts for nothing here
        known |= peer_has[q][g].bits
    return known

def known_across(g) -> Bitmap:                         # (R4) what our relation peers on the other axis hold of g
    T = type_of_group(g); known = mine[g].copy()
    for i in range(T.index_count(hdr[g])):
        if known.has(i): continue
        for (g2, i2) in T.cross(g, i):                 # a supernode's columns: every index of every row
            if any(peer_has[q][g2].has(i2) for q in suppression_scope(g2)):
                known.set(i); break
    return known

def repair_verdict(g):                                 # (R5, option) IncrementalDAS on the claimant's repair: cells
    T = type_of_group(g); steps = T.params.REPAIR_SAMPLE   #   of g we lack, asked of their columns' custodians;
    k = rsample_step[g]                                #   [(S1, L1), (S2, L2), ...], each sample containing the last
    if k > 0:                                          # step k's sample was asked SAMPLE_WAIT ago
        lost = [i for i in rsample[g] if not (received[g].has(i) or rebuilt[g].has(i))]
        if len(lost) <= steps[k - 1][1]: return REPAIRED   # at most L_k of S_k missing: the repair followed
        if k == len(steps) and rsample_final[g]: return NOT_REPAIRED   # the last re-asks were waited for
        reasked = [i for i in lost if T.params.REPAIR_REASK and ask_custodian(g, i)]   # a lost cell of another
        if k == len(steps):                            #   custodian: a silent one is not a missing repair
            if not reasked: return NOT_REPAIRED
            rsample_final[g] = True; return ASKED      # the last step: one more wait, for the re-asks only
    want = steps[k][0] - len(rsample[g])               # extend the sample, never a fresh one (IncrementalDAS)
    for i in shuffled([i for i in range(T.index_count(hdr[g]))
                       if not (received[g].has(i) or rebuilt[g].has(i)) and i not in rsample[g]]):
        if want == 0: break
        if ask_custodian(g, i): rsample[g].append(i); want -= 1
    rsample_step[g] = k + 1
    return ASKED if rsample[g] else REPAIRED            # nothing left to sample: nothing the repair could owe

def ask_custodian(g, i) -> bool:                       # (R5, option) cell i of g, of a custodian of its column not
    T = type_of_group(g); (g2, i2) = T.cross(g, i)[0]  #   yet asked for it and not a claimant (REPAIR_FLOOR keeps
    if expired(g2): return False                       #   the node a link to one per column); an expired column
    qs = [q for q in links(type_of_group(g2))          #   is not asked for (seacast-lite.md §8.1)
          if interest_of_peer(q, g2).has(i2) and q not in claims[g] and q not in rsample_asked[g][i]]
    if not qs: return False
    q = choice(qs); rsample_asked[g][i].add(q)
    send(q, Want(group=g2, bits=bitmap({i2})), urgent=False)   # answered if the custodian holds it
    return True

def owed_missing(g) -> bool:                           # (R5) the member check: a chunk of g that is ours on the other
    T = type_of_group(g)                               #   axis is still missing (the row's cells in our custody
    return any(interest[g2].has(i2) and not (received[g].has(i) or rebuilt[g].has(i))   # columns, which a
               for i in range(T.index_count(hdr[g])) for (g2, i2) in T.cross(g, i))     #   claimant's repair brings)

def reconsider(g, at):
    T = type_of_group(g)
    if reconsider_at.get(g) != at or state[g] != COMPLETE: return   # re-armed since, or decoding already
    del reconsider_at[g]
    if deferred[g] and g not in probe_ok:              # (R5) the verdict, once: only the claimant's own copy
        if g in probe_sent:                            #   passes it, whichever peer brought the cell; a probe
            settle_probe(g, False); penalise(probed[g])   # not written by now gets none, and our own repair
        else: settle_probe(g, None)                    #   goes on below (§4.6)
    if popcount(known_in_scope(g)) >= T.index_count(hdr[g]): return # whole in the subnet's view: nothing to rebuild
    if (deferred[g] and received[g].has(probe[g]) and wants_family(T, T.family(g))   # (R5) the claim held, on a
            and not owed_missing(g)):                        #   row we take part in, and its repair reached us; on a
        if T.params.REPAIR_SAMPLE is None: return            #   row kept on no link, only cells held count
        verdict = repair_verdict(g)                          # (R5, option) the repair sampled across the columns
        if verdict == REPAIRED: return
        if verdict == ASKED: return arm(g, now + T.params.SAMPLE_WAIT)  # the sample asked or extended: re-armed
                                                                        # NOT_REPAIRED: rebuild
    if not waited[g] and not deferred[g] and popcount(known_in_scope(g) | known_across(g)) >= T.index_count(hdr[g]):
        waited[g] = True                                            # (R4) held on the other axis: on its way, so
        return arm(g, now + T.params.DEFER_WINDOW)                  #   wait once; a false holding costs one window
    if claims[g] and not deferred[g]: return defer_on_claim(g)      # (R5) a claim arrived: one deferral, the one wait
    state[g] = DECODING                                             # the late decode claim, as at K
    mine[g] = all_bits(T.index_count(hdr[g]))
    for q in suppression_scope(g): send_have(q, g)
    start(decode_group, g)

def claims_close(p):                                   # (R5) p's connection closed: its claims go, so a probe draws
    for g in [g for g, qs in claims.items() if p in qs]:   #   among connected claimants; our probe of p, not yet
        claims[g].discard(p)                           #   judged, gets no verdict, its promise gone with the
        if deferred[g] and probed.get(g) == p and g not in probe_ok:   # connection, and the deferral ends:
            settle_probe(g, None)                      #   no verdict, and our own repair is reconsidered at the
            arm(g, max(now, duty_at.get(g, now)))      #   duty's own time, at once if that has passed

def note_claim(p, g):                                  # (R5) from on_holding: p claims every index of g
    claims[g].add(p)
    if (g in reconsider_at and state[g] == COMPLETE and not deferred[g]
            and popcount(mine[g]) < type_of_group(g).index_count(hdr[g])): defer_on_claim(g)

def defer_on_claim(g):                                 # (R5) verify the claim by one ask, and wait for it
    T = type_of_group(g)
    deferred[g] = True
    duty_at[g] = reconsider_at.get(g, now)             # the duty's own time: a probe with no verdict returns to it
    lack = [i for i in range(T.index_count(hdr[g])) if not mine[g].has(i)]
    i = choice(lack)                                   # an index we lack, at random: the claimant cannot tell which
    probe[g] = i
    q = probed[g] = choice(list(claims[g]))
    a = Ask(g, i)
    add_offer(a, q); tried[a][q] = now                 # a claim is an offer of every index (seacast-lite.md §6.1's tables)
    probe_asks.add(a)                                  # past stop-pull and the ask window: gated exempts it
    if not send(q, Want(group=g, bits=bitmap({i}), probe=True), urgent=False):   # marked: answered whatever we hold
        settle_probe(g, None)                          # refused by a full queue, never written: no verdict, and our
        return arm(g, max(now, duty_at[g]))            #   own repair is reconsidered at the duty's own time (§4.6)
    arm(g, max(reconsider_at.get(g, now), now + T.params.DEFER_WINDOW))   # its promise starts at its write
                                                       #   (filter_entry); not written by then: no verdict either

def gated(a): return stop_pull[group(a)] and a not in probe_asks    # [c6] seacast-lite.md §6.2, with the probe exempt

def settle_probe(g, verdict):                          # (R5) the verdict, once (True passed, False failed, None no
    probe_ok[g] = verdict                              #   verdict); settled, the probe's ask is gated again, so the
    probe_asks.discard(Ask(g, probe[g]))               #   probed cell is pulled past stop-pull no more (§4.6)

def probe_answer(g, i, p):                             # (R5) the claimant's own copy of the probed index, first or a
    if deferred[g] and probe.get(g) == i and p is not None and p == probed.get(g) and g not in probe_ok:
        settle_probe(g, True)                          #   duplicate, passes the probe and keeps its promise
        promises.pop((Ask(g, i), p), None)

def probe_promise(g, i):                               # (R5) the probe's promise, still open: another peer's copy
    if not deferred[g] or probe.get(g) != i or g in probe_ok: return None   #   does not close it; once the
    k = (Ask(g, i), probed[g])                         #   probe is judged or given no verdict, a promise under
    return (k, promises[k]) if k in promises else None #   its key is a plain ask's, which any copy closes

def probe_waits(a, p) -> bool:                         # (R5) a is our probe of p, flagged and not yet answered or
    gi = group_index(a)                                #   judged: our queue writes it even if another peer's copy
    return (gi is not None and gi.probe and deferred[gi.group] and probed.get(gi.group) == p   # came first
            and probe.get(gi.group) == gi.index and gi.group not in probe_ok)

def probe_settled(a) -> bool:                          # (R5) a is our probe, judged or given no verdict: if still
    gi = group_index(a)                                #   queued, it is not written (§4.6)
    return gi is not None and gi.probe and gi.group in probe_ok

def probe_of_claim(p, gi) -> bool:                     # (R5) as the claimant: p's flagged ask of an index we claim,
    return (gi is not None and gi.probe and mine[gi.group].has(gi.index)   #   while no flagged ask of the group
            and not probe_served[p][gi.group]          #   from p was answered; a later one is a plain ask (the cap),
            and probe_waiting[gi.group].get(p, gi.index) == gi.index)   # as is one of another index while p's is kept

def serve_probe(p, g, f):                              # (R5) f answers p's probe of g: the cap is taken, and card 8
    probe_served[p][g] = True                          #   lets that answer through once, whatever p holds
    probe_answers[p][f.group].set(f.index)

def filter_entry(p, entry):                            # seacast-lite.md §7.2's, but for the lines marked (R5) and want's
    f = entry.chunk
    if f:
        exempt = entry.solicited and probe_answers[p][f.group].has(f.index)   # (R5) our answer to p's probe
        if CANCEL and not exempt and peer_has[p][f.group].has(f.index):    # [c8] it became a duplicate
            entry.chunk = None
        elif PROJECT and not entry.solicited and projected(p, f.group):    # [c12]
            entry.chunk = None
            unpush(p, f.group, f.index)                        # [c3] not made: offered instead (§5.2)
        else:
            sent_to[p][f.group].set(f.index)
            if exempt: probe_answers[p][f.group].clear(f.index)   # (R5) spent by the answer written, once
    for c in entry.iwants():                                   # the asker drops asks for chunks it
        c.ids = [a for a in c.ids                              #   now holds, no longer pulls, or of a
                 if (not held(a) or probe_waits(a, p))         # (R5) but our waiting probe of p
                 and not probe_settled(a)                      # (R5) and a probe settled while queued,
                 and not gated(a) and not expired(group(a))    #   group past its lifetime,
                 and not tied_to_root(p, a)]                   #   and asks to a peer whose copy waits
        for a in c.ids:                                        # [c5] the promise starts at the write
            if probe_waits(a, p) and group(a) not in probe_sent:   # (R5) our probe, written now: its promise
                W = type_of_group(group(a)).params.DEFER_WINDOW    #   and the verdict's wait start here (§4.6)
                probe_sent.add(group(a))
                promises[(a, p)] = now; after(W, promise_due, a, p, now)   # broken: the claimant is parked
                arm(group(a), max(reconsider_at.get(group(a), now), now + W))
            elif (a, p) not in promises and (not c.want or probe_waits(a, p)):   # an ask not made on an offer
                promises[(a, p)] = now                         #   (want, §3) starts none, but a probe (§4.5, §4.10)
                after(PROMISE, promise_due, a, p, now)         # 400 ms
    return entry if not entry.is_empty() else None             # control rides on and survives

def decode_group(g):                                   # level 2, off the chunk path
    T = type_of_group(g)
    whole = T.decode(chunks[g], hdr[g])                # every chunk of the group, or None
    if expired(g): return                              # the group passed its lifetime meanwhile (v0.5 §8.1)
    if whole is None: return drop_group(g)             # [D6] and publish_evidence(g, …) if T.params.EVIDENCE
    new = [i for i in whole if not received[g].has(i)] # rebuilt, and not received meanwhile
    filled = []                                        # the other groups the rebuilt chunks fill, in order
    for i in new:
        store(g, i, whole[i]); rebuilt[g].set(i)       # servable from now on
        serve_standing(g, i)                           # §4.10: WANTs that preceded it are answered now, as in fill
        serve_waiting_probe(g, i)                      # (R5) a probe that reached us while we decoded (§4.6)
        for (g2, i2) in T.project(whole[i]):           # (R4) a rebuilt chunk fills its other groups too
            if g2 == g: continue
            fill(g2, i2, whole[i], None)
            if g2 not in filled: filled.append(g2)
    state[g] = COMPLETE
    push_rebuilt(g, new)                               # [c10] repair: level 2 has passed
    for g2 in filled: check_completion(g2)             # (R4) as on_chunk does: a filled group may be complete
    deliver(g, payload_of(whole))                      # level 3: the application's checks

def push_rebuilt(g, new):                              # [c10] seacast-lite.md §4.6 over each group a rebuilt chunk fills
    T = type_of_group(g)
    by_group = {}
    for i in new:
        for (g2, i2) in T.project(chunks[g][i]): by_group.setdefault(g2, []).append((i2, chunks[g][i]))
    for g2, items in by_group.items():
        if expired(g2) or state[g2] == INVALID: continue   # an expired or dropped axis is not acted on (seacast-lite.md §8.1, §4.6)
        T2 = type_of_group(g2); k = T2.threshold(hdr[g2])
        if T2.params.REPAIR_BUDGET and T2.params.EAGER:
            push_rebuilt_as_source(g2, items); continue
        for q in shuffled(T2.params.REPAIR_TO(g2)):    # peers whose interest includes them (I3)   [D4]
            e = peer_has[q][g2]
            known = e.bits | pushed[q][g2]             # what q claimed, and what we chose to push it
            short = k - popcount(known)                # q's shortfall: none after its decode claim
            if short <= 0 or e.complete: continue
            want = interest_of_peer(q, g2)                               # [I3] into interest only
            lacks = shuffled([x for x in items if not known.has(x[0]) and want.has(x[0])])   # at random, so
            for i2, f in lacks[:short]:                                  #   that decoded neighbours differ
                if not T2.params.EAGER: announce(q, g2, bitmap({i2})); continue   # rows: offered, pulled when wanted
                if enqueue(q, f, urgent=False): note_push(q, g2, i2)
                else: owe(q, g2, bitmap({i2}))                           # refused: offered instead (v0.5)

def push_rebuilt_as_source(g2, items):                 # [D4] REPAIR_BUDGET: a rebuilt chunk as its source pushes one (§1.6)
    T2 = type_of_group(g2)
    for i2, f in items:
        cands = [q for q in shuffled(T2.params.REPAIR_TO(g2))
                 if not (peer_has[q][g2].bits | pushed[q][g2]).has(i2) and not peer_has[q][g2].complete
                 and interest_of_peer(q, g2).has(i2)]                    # [I3] lacking it, into interest only
        for q in cands[:R_NODE]:                                         # the per-chunk budget [c17]
            if enqueue(q, f, urgent=False): note_push(q, g2, i2)
            else: owe(q, g2, bitmap({i2}))                               # refused: offered instead (v0.5)
        for q in cands[R_NODE:]: announce(q, g2, bitmap({i2}))           # [c3] offered to the rest
```

- **Two claims.** `complete` says "stop sending me this group"; `claim_all` says "I can serve any
  index of it". A row member that stops at 64 cells and exposes them sends the first and not the
  second (R2); a payload node at K sends both.
- **Who decodes, and when** `[D4]`. `DECODE_AT_K` is the duty that decodes the moment K chunks are
  in, with the claim before the decode: every node has it on the payload, and on a row a row
  reconstructor has it on the row of its own subnet (EIP-8371's first phase). `DECODE_LATER` is the
  duty that waits: a member of the row's subnet decodes at the third phase's delay from the block
  root if the row is still short of 128 then, with a jitter so that the first to decode cancels the
  others; the second phase, a supernode over every row, is the same rule with a shorter delay.
  "Still short" is read in the subnet's view: what the member holds together with what the holdings
  of its relation peers show (`known_in_scope`), so that a row whose cells all exist among the
  members is not rebuilt by a member that stopped at 64, while a withheld column's cells, which no
  member holds, are. A duty armed this way fires unless the group became whole in that view
  meanwhile ("a node MUST cancel a pending reconstruction of a row that completes through other
  means", EIP-8371).
- **Deferral on a claim, verified by one ask** (R5). A peer's `claim_all` for a group whose later
  duty is armed defers the duty once, by at least `DEFER_WINDOW` (a probe that ends without a
  verdict returns the duty to its own time, below), and the receiver asks one claimant, drawn at
  random among the peers whose claim of the group it holds, for one index it lacks, drawn at random
  (a claim is a promise: §4.5 `may_be_asked`). The duty and the claimant are judged apart. If the
  chunk arrives, from anyone, the claim is verified for the duty, and a row member's duty ends when
  the window has run; a node that keeps the row on no link goes by the cells it holds (below). The
  claimant passes only on its own copy, an answer or a push: if none has come when the deferred
  duty fires, with its probe written and the claimant still connected (below), the claimant is
  penalised, once, and another peer's copy leaves its promise open, so that `seacast-lite.md`'s pull
  discipline parks it when the promise breaks. That holds only while the probe waits: once it is
  judged or given no verdict, a promise under its key is a plain ask's, which any copy closes
  (`probe_promise`), and the probe's ask is no longer exempt from stop-pull (`settle_probe`), so the
  member pulls the probed cell from nobody after the verdict, as it pulls no other cell of the row
  once complete. The probe's promise is the deferral window itself, not `seacast-lite.md`'s `PROMISE`
  of 400 ms. A claim counts for nothing in the subnet's view of the row (`known_in_scope`),
  verified or not; a verified claim ends a member's duty through the deferral instead. A claim that
  came on a link that has not joined the row type makes no claimant: it counts as a plain holding,
  until a holding from the peer that claims the row whole comes on a link that has joined the row
  type (§4.3). The probe is an ask past completion, so
  until it is settled it is exempt from stop-pull (card 6) and from the one-ask-per-index window;
  and it counts against the claimant's serving limit like any answer: the draw of the claimant does
  not look at the limit, so a member that has already pulled `SERVE_LIMIT`
  chunks from the claimant it draws has its probe refused, and that claimant is judged as one that
  does not answer: it is penalised, the probe having been written, unless its own push of the cell
  comes in time. A client may prefer a claimant it has pulled less from, or keep one ask in
  reserve.
- **The probe is marked, and its cell drawn at random** (R5). Three rules keep the verdict on the
  claimant fair to an honest one and hard to meet for a dishonest one. Three more say when the
  probe's wait starts, and what a claimant still decoding and a claimant's departure do.
  - *The mark.* The probe's WANT sets `probe` (§2). The claimant answers the first such ask per
    asker and group, of an index it claims, whatever the asker's holdings say: neither the claim
    rule (§4.5) nor a receipt of the asker's refuses it, and card 8 lets the answer through once
    (`filter_entry`, `seacast-lite.md` §7.2's with the probe's lines). The exemption is the answer's
    alone: it is taken when the claimant answers, only for an index it claims, and spent when that
    answer is written, so a push of the same cell neither uses it nor passes card 8. A second marked
    ask of the group, after one was answered, is a plain ask. The mark costs no byte: it is one more
    bit beside `standing` in version 4 of the strings on the gossipsub binding
    (`seacast-bindings.md` §4) and in Partial Messages, and SEACAST's message encoding carries
    `standing` and `probe` in one flags byte (`seacast-bindings.md` §1.2).
  - *The asker's queue keeps the probe.* While the probe waits, the asker's queue writes its marked
    WANT even when another peer's copy came first and the asker holds the cell (`probe_waits`). The
    writer's other checks on an ask still apply: it drops an ask past the group's lifetime, and one
    to a claimant whose copy of the index waits for its gate (`filter_entry`).
  - *The cell at random.* The probed index is drawn uniformly among those the member lacks.
  - *The probe's wait starts at its write*, as every promise does (`seacast-lite.md` §6.1). The probe's
    promise starts when its WANT is first written (`filter_entry`) and lasts `DEFER_WINDOW`; once
    that promise is gone, a write of it again while it waits starts v0.5's plain one, as any ask on
    an offer does; the wait for the verdict lasts until the later of the end of that first promise
    and the duty's own time, the time it was armed for when the claim deferred it (`duty_at`). A
    probe that is not written gets no penalty, and no verdict unless the claimant's own copy of the
    probed cell comes first, which passes it as it passes any probe; without a verdict, the member's
    own repair is reconsidered (`reconsider`):
    - if a full queue refuses the probe, the repair is reconsidered at the duty's own time, at once
      if that has passed (`send`'s result);
    - if the probe is still unwritten when the duty next fires, `DEFER_WINDOW` after the decision or
      at the duty's own time if that is later, the repair is reconsidered then. Settled while still
      queued, the probe is not written later (`probe_settled`): no verdict waits on it any more.

    The second bounds the deferral: the verdict, or the reconsideration without one, comes at most
    one window past the later of the duty's own time and one window after the decision
    (`max(duty_at, decision + DEFER_WINDOW) + DEFER_WINDOW`): otherwise a claimant that stopped
    reading its connection would keep the probe queued and hold the member's repair off without
    end, which the probe exists to prevent.
  - *A claimant still decoding answers when the cell is stored.* A claimant that decodes claims
    every index at once, before it has stored the cells it rebuilds, so a probe can find nothing to
    answer (`resolve`). The claimant keeps the first marked ask per asker and group of a claimed
    index it has not stored (`probe_waiting`), and answers it, with its exemption, when the cell is
    stored, received or rebuilt (`serve_waiting_probe`, from `fill` and `decode_group`). It answers
    it once: while it is kept, neither the same marked ask repeated nor a standing WANT of the same
    index from the same asker, sent before it or after it, is kept as a standing WANT as well, which
    would send the cell twice and charge the serving limit twice, or spend the last slot without the
    exemption, so that the claimant's own queue could cancel the answer as a duplicate once the
    asker's holding names the cell. Nor, while it is kept, does the same asker's marked ask of
    another index of the group take the exemption: it is a plain ask (`probe_of_claim`), so the kept
    probe keeps it for when its cell is stored. It is answered then if the asker has not reached
    `SERVE_LIMIT` in the group by then (`serve_waiting_probe`). A decode that fails stores nothing,
    so its claimant is judged as one that does not answer.
  - *A claimant that leaves is not judged.* A peer's claims go with its connection (`claims_close`),
    so the probed claimant is drawn among connected ones. A probe of a claimant whose connection
    closes before the verdict gets none, neither a pass nor a penalty: its answer can no longer
    come, and its promise went with the connection (`seacast-lite.md` §8.1). The deferral then ends, and
    the member's own repair is reconsidered at the duty's own time, at once if that has passed
    (`reconsider`, which rebuilds unless the group is whole in the subnet's view or the repair
    reached it): the claim, unverified, returns the duty to its own time, or to the close if that
    time has passed, so the members whose pending probe chose a departed claimant do not all
    rebuild at the same instant. As after any deferral, the member does not then take the one wait
    for the other axis (R4), so its rebuild can come up to one window sooner than with no claim. No
    second claimant is probed: one deferral per group, as before.
- **The verdict, by what the node can see** (R5: re-arm "if the cells do not follow"; with sampling
  the repair, below, an option). A row member, a node that takes part in the row's family
  (`wants_family`: the row of its own subnet), has a subnet's view of the row (`known_in_scope`),
  and a verified claim ends its duty when the window has run, whoever made it, subject to the
  member check (below). A node that keeps the row on no link, a supernode on the rows of the other
  subnets (interest declared on no link, §1.2) and on every row under custody alone, goes by the
  cells it holds: a claimant that answers the probe and sends nothing else costs it one window, not
  the row. A deferral is the duty's one wait (no `known_across` wait follows it), and only a probe
  the claimant's own copy did not answer counts against it.
- **The member check** (R5; `owed_missing`). A verified claim ends a member's duty only once the
  row's cells in the member's own custody columns have arrived: those are the cells the claimant's
  repair owes it (§4.6 below: rebuilt cells go to the custodians lacking them), so an honest
  claimant delivers them within the window and a claimant that repairs nothing does not. Otherwise
  the member goes by the cells it holds and rebuilds the row, telling its subnet peers as for any
  decode. The check needs nothing new on the wire: the member reads its own holdings at the moment
  it would have stopped.
- **Sampling the repair** (R5, option: `REPAIR_SAMPLE`, `SAMPLE_WAIT`). The member check asks
  whether the member's own share of the repair came; RowDAS's rule asks whether the cells followed,
  into every column. A member cannot see the other columns, but it can sample them, as a node
  samples a block, and IncrementalDAS gives the test its shape ("LossyDAS: lossy, incremental, and
  diagonal sampling for data availability", ethresear.ch 2024, https://ethresear.ch/t/18963): after
  a verified claim and a passed member check, the member asks cells of the row that it lacks, up to
  `S1`, each of a linked peer whose interest holds the cell, on a live column, and that is not a
  claimant (`ask_custodian`; `REPAIR_FLOOR` keeps the member a link to a custodian of each column it
  does not custody, which may be the claimant), and re-arms its duty for `SAMPLE_WAIT`. With at most
  `L1` of them missing, the repair followed and the duty ends; otherwise it extends the sample
  toward `S2` cells containing the first and re-arms once more, and with more than `L2` missing it
  rebuilds. A step that finds fewer cells to ask than its target is judged by the same `L_k` on the
  cells asked, and a sample that has found no cell to ask at all counts as followed: the duty ends
  (`repair_verdict`). It extends the sample, never drawing a fresh one, as IncrementalDAS does. The
  cells a member lacks past K are the withheld columns', the ones only a repair brings, and the
  claimant cannot know which the sample picks.
  - *Re-asking a lost cell* (`REPAIR_REASK`) separates an unresponsive custodian from a missing
    repair: when a step fails, each missing cell is re-asked, with the extension, of another
    eligible peer, if the column is live and a linked peer whose interest holds the cell, not a
    claimant and not yet asked for it, is left (`ask_custodian`; a WANT a full queue refuses counts
    as asked). At the last step the re-asks get one more wait, after which the member rebuilds if
    more than `L_k` are still missing; with no re-ask made, it rebuilds at once.
- **Rebuilt cells marked seen** (option: `REBUILT_SEEN`, only with `REPAIR_SAMPLE`). `decode_group`
  stores what it rebuilds without `mark_seen`, where `publish` marks a source's chunks seen. So a
  copy of a rebuilt cell that another rebuilder pushes is validated again and forwarded on every
  axis where the node has duty `FORWARD`. With the rebuilt cell marked seen, such a copy is a
  duplicate, which is acknowledged and forwarded no further.
- **A custodian's alarm** (option: `ALARM_WAIT`, with `ALARM_NEXT` and `ALARM_MAX`; for networks
  without an honest supernode). The sample allows a lost cell at its last step, since a custodian
  may not yet hold a repaired cell when asked. So a claimant that repairs every withheld column of
  its row but one passes every member's sample with certainty, and the custodians of that column
  stay short. Only they see which cell is missing.
  - *The alarm.* At `ALARM_WAIT` after `known_at`, with a jitter, an honest custodian that still
    lacks a cell of a custody column, one that no peer's holding shows, sends a standing WANT for
    that cell's row, at the column's index, to a member of the row's subnet among its links that
    joined the row type, since another link ignores the WANT (§2). While the cell is missing it asks
    another member every `ALARM_NEXT`, up to `ALARM_MAX`.
  - *The member.* A member that deferred on a verified claim asks that claimant for the index once,
    with the probe's promise (`DEFER_WINDOW`), started at the ask's write, as the probe's is. A
    broken promise counts against the claimant, and the member rebuilds the row and repairs it as
    after any decode. A claimant that cannot be asked, because its connection has closed or a full
    queue refuses the ask, or whose connection closes before the ask is written or before the
    promise ends, is not judged, and the member rebuilds the row if the cell is still missing.
    Nothing new goes on the wire: the alarm is a standing WANT, and a member that rebuilds the row
    answers it from `decode_group` as any standing WANT, unless the custodian's holding names the
    cell by then or it has reached `SERVE_LIMIT` in the group (`serve_standing`, §4.5).
  - *Its wait* is stated by its bound: it is above the honest custodians' tail on the network, or
    the alarm fires without a fault. A rescue comes a round trip, `DEFER_WINDOW` and a decode after
    the wait, later than the sample's, so the alarm backs the sample up rather than replacing it.
- **Repair across groups** (R4). A rebuilt chunk fills every group it belongs to (`fill` on the
  other axis) and `push_rebuilt` works group by group: for a row, the rebuilt cells of row b go into
  the column groups of their columns, to the custodians `REPAIR_TO` names that lack them, which is
  "the push into non-custodied columns is the whole of the relief" (the RowDAS design); the row's
  own members, complete at 64, are not pushed what they do not want. For the payload, `project` is
  the identity and this is `seacast-lite.md`'s `push_rebuilt`. PeerDAS's reconstruction is the second
  phase without row subnets (below). A push, and an answer to a standing WANT or a kept probe, is
  noted under every group the chunk fills (`note_push`, §4.4; `unpush` clears it for a source's push
  its queue refuses and for a push the writer skips by projection), so a chunk noted through one of
  its groups is not offered or repaired to that peer again through another, nor pushed to it by a
  source (`wants_from_me`). The note does not keep a forwarding node from pushing the chunk to that
  peer (`choose_push` only ranks by it), and an answer from `on_want`, a probe's included, is not
  noted.
- **A rebuilt chunk names the block its sources name** (`seacast-lite.md` §4.6, v0.8). Otherwise,
  under two blocks of a slot, a rebuilt copy naming the other block would wait for good at a
  neighbour that installed only the first.
  - A rebuilt payload chunk does so by `decode_and_reencode`, as `seacast-lite.md` defines it.
  - A rebuilt cell does so by construction. Its group id carries the root (§1.1), and `project`
    keeps it, so a rebuilt cell of row b fills the column groups of the same block.
  - The rule keeps honest copies on the source's block only as long as no node relabels a chunk
    (`seacast-lite.md` §4.6, "Open: relabelled copies", with its options; 2026-10-28). The payload is
    exposed as there. A cell relabelled under the other block is a cell of that block's groups,
    which its id carries. It cannot stand in for the source's copy or tie its sender for this
    block's groups: for cells this is that list's option of a group per block root. The cells'
    case is by inspection: neither the toy nor a model runs relabelled copies.
- **A rebuilt chunk completes the groups it fills** (R4). `decode_group` checks the completion of
  every other group its rebuilt chunks filled, as `on_chunk` does after an arrival. A member whose
  custody column lacked only cells of the row it rebuilt holds the whole column after its own
  decode.
- **Every member keeps a link to each column** (`REPAIR_FLOOR`, decided). A row is gathered from the
  columns and repaired into them, so a member needs, for every column, a link to a node that
  custodies it: to pull that column's cell of its row, and to push the cell it rebuilt. `REPAIR_TO`
  names custodians among the node's links, and EIP-8371 reaches the other columns through
  gossipsub's fanout ("after reconstruction, a node SHOULD use the Gossipsub fanout mechanism to
  provide cells from the reconstructed blob to peers across column subnets it is not subscribed
  to"), which uses connected peers only. So the rendezvous keeps, for every node that may rebuild,
  at least `REPAIR_FLOOR` links to custodians of each column it does not custody, as `SOURCE_FLOOR`
  keeps a proposer's links to the columns it publishes (§4.7). Opening a link through the rendezvous
  only when a rebuilt cell has nowhere to go is an option: it costs a lookup and a handshake while
  the cell waits, and it does not help a member gather a row.
- **A supernode keeps every row** (the second phase, R3). A node that custodies every column
  receives every cell of every row with its columns, so it keeps every row group, filled from its
  columns (R4), with interest `ALL` declared on no link (§1.2). Its duty on a row outside its own
  subnet is `DECODE_LATER` at the second phase's delay, shorter than the third's: if the row is
  still short then, it rebuilds the row, and the rebuilt cells go into the columns as any
  rebuilder's do. EIP-8371 puts this phase on supernodes because "only a node subscribed to all
  column subnets can observe rows completing elsewhere and cancel the redundant work": a row rebuilt
  elsewhere reaches a supernode as column cells. A node with 64 to 127 columns never holds the cells
  of the columns it lacks, so it cannot tell a row rebuilt elsewhere from one still short, and it
  keeps no second-phase duty here (the EIP's MAY, left out). Under custody alone, without row
  subnets, the same rule is PeerDAS's reconstruction ("If the node obtains 50%+ of all the columns,
  it SHOULD reconstruct the full data matrix … Nodes MAY delay this reconstruction"), with the delay
  made the rule's: a supernode keeps the rows, no other node does, and it rebuilds only the rows its
  columns have not completed by then.
- **A row held on the columns is on its way** (R4). The subnet's view (`known_in_scope`) holds only
  the row's own axis, and at the second phase's timer a supernode may still be receiving its 128
  columns. A chunk held on one axis is held on the other, so the duty also reads what its relation
  peers on the other axis hold (`known_across`; `T.cross` names a chunk's other (group, index) pairs
  from the ids alone): for a supernode, the bitmaps of its peers on every column, which is
  EIP-8371's "observing the bitmaps of all column subnets". A row whole in that view but not in the
  node's holdings is on its way: the duty waits once, `DEFER_WINDOW`, and fires then if the row is
  still short in the node's holdings, so a false holding delays a rebuild by one window and no
  more. A member reads the same view over its custody columns.
- **A rebuilder pushes as a source** (`REPAIR_BUDGET`, an option, off). A rebuilder holds the
  rebuilt chunks before its peers do, so it is their source (§1.6), and the option has it push each
  one to `R_NODE` of the peers lacking it and offer it to the rest, as a source does, instead of
  pushing it to every peer short of it. It stays an option.
- **Whom rebuilt cells go to** (`REPAIR_TO`, options). The push stays. Three forms are options:
  offering the cells to the nodes that keep every row instead of pushing them; offering every
  rebuilt cell, as a row's are; and leaving the keepers out.

#### Rationale

**Deferral on a claim, verified by one ask.**
- *The probe's promise* is the window, not `PROMISE`: a reconstructor that has just decoded is
  pushing a row's worth of rebuilt cells through its window. In the toy its answer to a probe left
  later than `PROMISE` after the probe was decided, so with the shorter promise honest claimants
  were parked and penalised (seacast-figures.md, §4.6, "The deferral").
- *A claim outside the subnet's view.* Executing the toy's liar fault (seacast-figures.md,
  §4.6, "The probe") showed that a false claim counted there made the row look whole to every
  member of its subnet and suppressed the third phase, the suppression the RowDAS design warned of.
- *The probe exempt.* Without the exemptions, the one-ask-per-index window dropped the probe in the
  toy and penalised honest reconstructors.
- *Defer and re-arm.* The RowDAS design asked for "defer and re-arm" because a bitmap takes a round
  trip and cancelling on a claim outright lets any peer suppress reconstruction; the probe makes the
  re-arm a verdict on the claimant rather than a timer, at the cost of one cell.

**The probe is marked, and its cell drawn at random** (decided 2026-11-15; the probe's wait from its
write, a claimant still decoding and a claimant that leaves since 2026-11-16; `probe_of_claim` since
2026-11-17).
- *Why the mark.* The probed cell often reaches the asker from another peer during the wait, on its
  other axis, and the asker's holding then names it; without the mark, the claimant's queue
  cancelled its own answer as a duplicate, and an honest claimant failed its probe.
- *Why the asker's queue keeps it.* Otherwise the asker dropped its own probe, and the claimant
  could pass only on a push.
- *Why at random.* The lowest index the member lacks, which an earlier draft took, can be read from
  the member's announced holdings, so a claimant could keep exactly that cell and withhold the
  rest; when the index is drawn at random, the claimant cannot tell which cell will be asked.
- *Why from its write.* Starting the wait at the decision instead penalised a claimant for a WANT
  it never received.
- *Why the claimant keeps the probe.* Dropped, the probe would go unanswered, and an honest claimant
  whose decode outlasts the probe's round trip would be penalised. An honest member sends one probe
  per group; before, a faulty asker's second marked ask, of a stored cell, took the exemption, and
  the kept one went unanswered.
- *Measured* results come from five cells (seacast-figures.md,
  "A cell, the median and the tail") of the toy's rows, honest and under liars or hoarders, run on
  this section's rules as they stood on 2026-11-18 (seacast-figures.md, §4.6, "The probe"). No
  verdict on an honest or hoarding claimant failed. Every probe got a verdict and was written: none
  was still unwritten when its window ran out, and no probe reached a claimant still decoding (the
  toy's queues refuse nothing, and these cells close no connection). Liars almost never passed their
  probe in two of the three liar cells, and passed more often in the one with supernodes, each time
  on a copy the liar pushed (a toy liar answers no ask). The mark cost a few duplicate cells: exempt
  answers written over a holding the asker had sent. At the median a probe was written when it was
  decided, and its longest wait was far shorter than `DEFER_WINDOW`. One run of the liars' 16-subnet
  cell delivers no block to almost all of its nodes, as it did before, and decides no probe; the
  figures include it. Against the runs with the rules of 2026-11-16 (below), every run changed its
  events, and the copies of a few runs moved; those moves of the copies were not traced.
- *Measured with the rules of 2026-11-16*, before four later fixes (a probe settled while queued, a
  kept probe answered once, the duty's own time, a settled probe's promise) and the later changes to
  the draft, the same cells showed this: no verdict on an honest or hoarding claimant failed; liars
  almost never passed in two of the liar cells, and passed more often in the one with supernodes;
  the mark cost a few duplicate cells; one probe, in the supernodes' cell, passed before it was
  written, on the claimant's own copy; the run that delivers no block decided a few probes; and the
  longest wait from decision to write was a small part of the window (seacast-figures.md, §4.6,
  "The probe").
- *Measured before 2026-11-16*, and before v0.10's order of the announcers beyond the list
  (`seacast-lite.md` §6.1), these runs used the same five cells. That order moves a run of the
  supernodes' cell and, bracketed but not run at that change, another. Judged by the claimant's own
  copy without the mark and the kept WANT, a few verdicts on honest claimants failed, all in the
  hoarders' cell; with them, none did. When any peer's copy passed the claimant, liars passed far
  more often in every liar cell, by a count that is a lower bound. Against the earlier rule's runs
  (the lowest index, any peer's copy passing), the copies stayed close in most runs and were lighter
  in one run of the hoarders' cell and in two of the supernodes' cell. Almost all of the difference
  was data, and it was not traced further (seacast-figures.md, §4.6, "The probe").
- *The random index's cost, and what is not measured.* In the runs measured before 2026-11-16,
  liars passed a little more often with the random index than with the lowest. In the traced runs,
  which hold all such passes, the liar had by then already sent the member the lowest lacked cell
  in most of them and held it unsent in the rest; in none had it neither (seacast-figures.md,
  §4.6, "The probe"). The excess fits the draw choosing a cell already on its way, but that is not
  proven. The toy's liars do not aim at the cell they expect to be asked, so these runs measure the
  draw's side effects, not its purpose; nor does any fault send marked asks, which the cap bounds to
  one exempt answer per asker and group.
- The figures file gives the rules and the transport that each figure in this section ran with
  (seacast-figures.md, §4.6).

**The verdict, by what the node can see** (decided 2026-10-10). Draft 1 ended a row member's duty on
a verified claim; the rule above keeps that, subject to the member check.
- *The wording.* An earlier wording told the two apart by a non-empty suppression scope (some peer
  pushes the row to the node). A member that no peer pushed its row to then counted as keeping the
  row on no link and rebuilt after a verified claim. In the toy that added member decodes with 32
  subnets, where a subnet has few members, and none with 16. With this wording the row cells with
  supernodes (honest, and half the columns withheld with 16 and with 32 subnets) and the withheld
  custody cell with a fifth of the nodes hoarding run as under draft 1, event for event on every
  seed, and so do almost all seed-cells of the row cells with supernodes and a fifth or half
  hoarding (seacast-figures.md, §4.6, "The verdict").
- *Draft 1, and a first version.* Draft 1 ended the duty of both, a row member and a node that
  keeps the row on no link, on the probed cell; when the toy's rebuilders stopped pushing to
  supernodes (an exploration), supernodes deferred on a claim that came in an acknowledgement,
  received the probed cell, and ended one cell short of a column. A first version of this rule
  counted a verified claim only from a peer in the node's view, and row members decoded several
  times as many rows for no change in time or bytes (seacast-figures.md, §4.6, "The verdict"):
  their claimants were mostly supernodes rebuilding the row in the second phase, which have no
  relation on it, so their claims reach a member in the acknowledgement of a column chunk (§4.2,
  `fill`).
- *What it leaves to the member check.* A claimant that rebuilds a row, answers the probe and pushes
  nothing (the toy's `--fault hoard`) passes the probe and ends the members' duties. Where an honest
  supernode keeps the row, its second phase repairs the row, under this rule and under draft 1's
  alike: in the runs traced, no supernode ended its duty on a verified claim, presumably because a
  claim on a row reaches a supernode outside the subnet only in the acknowledgement of a cell the
  supernode sent, which a hoarder sends while still short. Where none does, the row is lost: without
  supernodes, a fifth of the nodes hoarding left custodians short in every run of the toy's withheld
  row cell, each time a subnet whose honest members had deferred to a hoarding reconstructor
  (seacast-figures.md, §4.6, "The verdict"); the member check (above) closed this in those runs
  wherever the subnet had an honest member, against a claimant that repairs nothing.

**The member check** (decided 2026-10-09). It was measured in the toy's withheld row cell
(seacast-figures.md, §4.6, "The member check"):
- *What it addresses: a claimant that rebuilds, passes the probe and repairs nothing* (the toy's
  `--fault hoard`). Without supernodes, with a fifth or half of the nodes hoarding, custodians were
  left short on every seed without the check, and with it they were left short on a few seeds at a
  fifth and on most at half. Every seed on which each subnet has an honest member completes.
- *And a false claim the cell's arrival let through.* For the duty, the claim holds when the probed
  cell arrives, from anyone; a claimant that never answers ends the duty when another peer brings
  the cell in time, though it is itself penalised (above). Among the toy's liars (`--fault claim`,
  which claim their row and answer no ask) without supernodes, this happened a few times per run on
  some seeds, and each time the member check sent the member to rebuild instead of trusting the liar
  (traced on some of those seeds; measured when that cell also passed the claimant). In the traces,
  the few (node, row) pairs left short, with and without the check, are the liars' own rows, which
  the toy's liars never rebuild: the check moved their count only slightly (seacast-figures.md,
  §4.6, "The member check").
- *What it does not address.* It does not address a subnet whose members all misbehave: nobody
  honest is there to check. A member whose custody columns are all among the published ones holds
  its cells whatever the claimant does (a small share of members where half the columns are
  withheld), so the check passes for it, though the other members of its subnet still check. A
  claimant that pushes each member exactly its custody cells of the row and withholds the rest
  passes the check (the toy's `--fault hoardm`: without supernodes, a fifth of the nodes doing so
  left custodians short on every seed); sampling the repair samples for it. Where an honest
  supernode keeps the row, its second phase already repairs what a hoarder withholds, and the check
  never fired there (seacast-figures.md, §4.6, "The member check").
- *What it costs.* Where nobody misbehaves, it costs nothing: in each cell run without a fault
  (rows honest with and without supernodes, withheld with 16 subnets with and without, withheld
  with 32 with supernodes) it never fired and every event is the same. A rescued block completes
  later than a block without hoarders, since the member rebuilds at the third phase after a
  deferral; its bytes are not higher, since hoarders push nothing. In the traced runs with hoarders
  or liars every firing was on a misbehaving claimant's claim: a needless rebuild, an honest
  claimant's repair still on its way when the window ends, was not seen at 60 nodes. It is the case
  to watch at larger scale, where repair travels further (seacast-figures.md, §4.6,
  "The member check").

**Sampling the repair.** The sample is extended, never redrawn, since the larger sample could have
been drawn at once ("toss a coin until you like the result" is the alternative the post rules
out); allowing losses is LossyDAS's answer to a custodian that has not yet received a repaired cell
when asked. It was measured in the toy's withheld row cell (seacast-figures.md, §4.6,
"Sampling the repair"):
- *Against a claimant that repairs only the members' cells* (a fifth of the nodes, without
  supernodes): the member check alone left custodians short on every seed. The lenient form,
  `(3, 1), (6, 2)`, left fewer short, and the strict forms, `(4, 0), (8, 1)` and `(6, 0), (12, 1)`,
  left short only the seeds on which a subnet has no honest member. In a traced run every failed
  sample was on a hoarder's claim. The lenient form passed partial repairs: the hoarding members'
  own pushes had filled some columns, and most of the sampled cells came. A rescued block completes
  later than a block without the fault, with the rebuild waiting out the deferral and two sample
  steps, and later than a block the member check alone rescues from a claimant that repairs nothing
  (seacast-figures.md, §4.6, "Sampling the repair").
- *Where nobody misbehaves* no sample failed in any form, with or without supernodes, and the times
  and bytes are within the seeds' spread; the cost is the sampled cells, a few per node and block
  (seacast-figures.md, §4.6, "Sampling the repair"). With supernodes every cell completed in
  every form.
- *Where custodians do not answer.* The toy's liars answer no ask, so a sample cell asked of one is
  lost: with a fifth of the nodes lying, `(4, 0), (8, 1)` failed on honest claimants in many
  verdicts, and in almost all of them in a run with supernodes, where a liar is a supernode and so a
  custodian of every column. The strict forms had members rebuild more rows per run, without
  changing completion (seacast-figures.md, §4.6, "Sampling the repair").
- *Re-asking a lost cell* (`REPAIR_REASK`) was measured over the same seeds. Among liars the strict
  forms' failed samples fell to none at the median, though not in every run, and members rebuilt
  about as many rows as with the member check alone. Where no cell was lost (no fault, and a
  claimant that repairs nothing) the runs are the same event for event. Against a claimant that
  repairs only the members' cells, `(4, 0), (8, 1)` and `(6, 0), (12, 1)` still leave short only the
  seeds without an honest member, and a rescued block completes later, by about the one more wait;
  `(3, 1), (6, 2)` stays lenient (seacast-figures.md, §4.6, "Sampling the repair").
- *At 500 nodes* (`(4, 0), (8, 1)` with re-ask against the member check alone): where nobody
  misbehaves, with and without supernodes, the member check never fired, no sample failed, and times
  and bytes are similar. The sample asked a few cells per node and block without supernodes, and far
  fewer with them, since a supernode's second phase makes most rows whole in the members' view
  first. A fifth of the nodes repairing only the members' cells left nobody short at this size even
  with the member check alone. With the sample, two seeds are similar, and on the third every failed
  sample was on one row the hoarder had not repaired. Its members rebuilt it after the deferral, two
  sample steps and the re-ask's wait, and the block's last custody cells came seconds later than in
  the run with the member check alone, where an honest node had rebuilt that row earlier (the runs
  diverge from the first block, and which node it was is not traced). The rescue path's length,
  `DEFER_WINDOW` plus two `SAMPLE_WAIT` and the re-ask's, is the cost to cut; a shorter wait was not
  measured (seacast-figures.md, §4.6, "Sampling the repair").

**Rebuilt cells marked seen** (kept as an option, 2026-11-01).
- *It needs the sample.* The forwarded copies also repair by accident: two hoarding reconstructors
  that forward each other's rebuilt cells fill columns that neither repairs on purpose. With the
  cells marked seen, such hoarders leave more columns unrepaired: in one network of the toy's
  500-node rows, a network model gives several times as many, and the runs matched the model
  (seacast-figures.md, §4.6, "Rebuilt cells marked seen"). The member check, which looks only
  at the member's own columns, misses them, and the sample catches them. With the member check
  alone, the option left more custodians short in the runs that measured it, so it is never on
  without the sample.
- *Measured at ten seeds* in the toy's 500-node rows, without supernodes, against a fifth of the
  nodes repairing only the members' cells: the member check alone left blocks short, the sample
  left fewer short, and the sample with rebuilt cells marked seen left none short. In honest cells
  the two together cost slightly more copies and control, against neither, with no direction in
  time (seacast-figures.md, §4.6, "Rebuilt cells marked seen").

**A custodian's alarm** (kept on 2026-11-01 for networks without an honest supernode).
- *Its wait, in the toy.* The measurements set the wait above the latest custodian's completion in
  the toy's 500-node rows without a fault (seacast-figures.md, §4.6, "A custodian's alarm", with
  the settings and the rules each run had).
- *Measured again on the rules as they stood* (2026-11-18), these figures come from the 500-node
  cells of the one-column hoarder (seacast-figures.md, §4.6, "A custodian's alarm"). Without
  the alarm some blocks were short: the same blocks as before but one, which now completes. With it
  none was, for as many alarms and rebuilds as before. In honest cells and under false claims
  (rebuilt cells not marked seen) no alarm fired. The figures of the ten-seed runs below were not
  measured again.
- *Measured at ten seeds*, before the member's changes of 2026-11-17, these runs had the sample and
  rebuilt cells marked seen. A fifth of the nodes repaired all but one withheld column per subnet,
  with no supernodes. Without the alarm some blocks were short; with it, none was, and every alarm
  and rebuild came at the short seeds. With supernodes none was short without it, since a
  supernode's second phase rebuilds the row: the alarm is for networks without one. In honest
  cells, with the builder at 1 Gbps or at home, no alarm fired, and the latest custodian completed
  before the alarm's wait. Under false claims by a fifth of the nodes, a few alarms fired and no
  rebuild followed (seacast-figures.md, §4.6, "A custodian's alarm").
- *Not measured:* the wait on thinner links, where the honest tail is longer, is not measured, and
  neither is the alarm since the probed cell is drawn at random. These runs probed the lowest index
  a member lacked, which was never the hidden column; drawn at random, the probe can ask for it, and
  a claimant that serves it to nobody then fails the probe itself.

**Repair across groups** (`note_push` under every group the chunk fills since 2026-11-17).

**A rebuilt chunk completes the groups it fills.** Draft 1 filled the column without the check, so
the member never completed it: it neither stopped pulling it nor told its peers, and the toy counted
it short (in a run of the repair floor's measurement below, before the fix; seacast-figures.md,
§4.6, "The repair floor").

**Every member keeps a link to each column.** In the toy's withheld row cell, without the floor
several runs left custodians short, and each was a missing link. In all but one of them, a column
with two custodians missed a cell because neither was linked to the only member that rebuilt the
row; the deferral on a claim, which cancels a second decode once the first is verified, makes a
single rebuilder common. In the other, a subnet had two members, linked only to each other among
members, and each gathered its rows from the columns' custodians one cell short: neither was linked
to the only custodian of one published column, so neither row was ever rebuilt. With
`REPAIR_FLOOR = 1` every run completed, and the links it added left completion times and bytes
within the seeds' spread (§6.2; seacast-figures.md, §4.6, "The repair floor").

**A supernode keeps every row.** In the toy, a few supernodes on datacenter links complete every
custodian on every seed of the custody cell whose proposer withholds half the columns, which nothing
else recovers. They complete the withheld row cell with 32 subnets, which its subnets without
members left short, and they complete the cell with 16 subnets much sooner. The cost is bytes, most
of it duplicate pushes of the fast class: with a budget of `R` for cells the copies are fewer and
the tails are shorter (§6.2; §6.3, `R_NODE`, for later study; seacast-figures.md, §4.6,
"Supernodes").

**A row held on the columns is on its way.** Without the wait, on home links, supernodes in the
toy's honest row cell rebuilt many rows that nobody had withheld, and the cell's tail grew. With the
wait, no supernode rebuilt a row in any honest custody or row run. In the withheld cells the
supernodes still rebuild most rows more than once; a jitter longer than a rebuilt row's trip to the
other supernodes would cancel more of them; such a longer jitter was not measured. For a member it
changed no event of the row cells without supernodes that were checked (seacast-figures.md,
§4.6, "Supernodes").

**A rebuilder pushes as a source.** Without supernodes, in the withheld 16-subnet row cell, where
members on home links rebuild, it is better on every count: fewer repair pushes, fewer copies, and a
shorter tail, at the median over the seeds and at the worst seed. With supernodes on datacenter
links, whose budget is the fast class's six, it saves copies and costs time at the tail, and in the
custody cell both the saving and the cost are small. With the fast class's budget off for cells
(§6.3, `R_NODE`) it saves more copies in the 16-subnet cell, for a later median and tail
(seacast-figures.md, §4.6, "A rebuilder pushes as a source").

**Whom rebuilt cells go to.** A supernode keeps every row, so a rebuilder's push into a column
reaches it too, and where several nodes rebuild a row their pushes cross in flight: at 500 nodes
most of the rebuilt cells pushed in the withheld custody cell arrived as duplicates, the whole of
that cell's extra cost over the honest one. The duplicates are bounded by what a node's own peers
push it, so no estimate of the network's size is needed to bound them. In the toy with supernodes,
offering the cells to the nodes that keep every row instead of pushing them saves copies at no cost
in time; offering every rebuilt cell, as a row's are, saves more and costs time at the median;
leaving the keepers out saves as much as offering to them, but lengthens the custody cell's tail,
since a supernode left out has only its own rebuild, after a deferral (seacast-figures.md, §4.6,
"Whom rebuilt cells go to").

### 4.7 The source

```python
def publish(block, d, shards):                         # the payload's builder; seacast-lite.md §5.1 over the relation
    g = group_of(block, d)                             # §1.1's table: the payload's key, a column's id
    if expired(g) or not live(block.slot): return      # too late: past its live window (seacast-lite.md §8.1)
    release_wanted_groups()                            # §4.5: a place that ran out goes before its group opens
    open_group_source(g, d)                            # hdr[g] = d; T_of, interest, known_at
    drop_wants_beyond(g)                               # §4.5: its count is known now
    T = type_of_group(g)
    for s in shards:                                   # the source holds every chunk from the start
        f = Chunk(slot=block.slot, beacon_block_root=block_root(block), group=g,
                  descriptor=d, index=s.index, proof=s.proof, data=s.data)    # descriptor: design A (B open, seacast-lite.md §1)
        store(g, s.index, f); mark_seen(chunk_id(f))
        gossip_history.put(f)                          # heartbeat gossip may offer it (§4.8)
    mine[g] = all_bits(N(d)); state[g] = COMPLETE; stop_pull[g] = True
    for s in shards: serve_standing(g, s.index)        # §4.10: WANTs that came before the chunks are answered now
    if not T.params.EAGER: return offer_at_publish(g, d)   # a pull-only type: nothing pushed (§4.7)
    origin[g] = bitmap(set())                          # [P4] our holding names the chunks acknowledged so far (§4.7): none yet
    plan = []
    for i in range(N(d)):                              # index order; each chunk's targets see earlier plans
        f = chunks[g][i]
        targets = choose_push(f, candidates_for_source(f), budget=R, at_source=True)   # seacast-lite.md §5.3
        for p in targets: note_push(p, g, i)
        plan.append((f, targets))
    led = set()
    for copy in range(R):                              # the first copy of every chunk before any second  [c2]
        for f, targets in plan:
            if copy < len(targets):
                p = targets[copy]
                if p not in led:                       # [P4] a peer's first chunk from us follows our holding
                    led.add(p)                         #   naming it, as a forwarding node's holding precedes its pushes
                    send(p, holding_of(g, origin[g] | bitmap({f.index})), urgent=True)
                if not enqueue(p, f, urgent=False): unpush(p, g, f.index)   # refused: offered instead (v0.5 §5.2)
    planned[g] = {f.index: set(targets) for f, targets in plan}   # [c3] the relation peers not chosen to be
                                                       #   pushed a chunk are offered it at its acknowledgement
    if SOURCE_OFFERS == PUBLISH:                       # the source's own choice (§4.7, §6.3): those offers now,
        for f, targets in plan:                        #   and its holding grows at each chunk's first write
            for p in source_pool(T, g, colour_of(g, f.index)):
                if p not in targets: announce(p, g, bitmap({f.index}))

def origin_written(f):                                 # SOURCE_OFFERS = PUBLISH: a chunk of a group we publish
    g = f.group                                        #   leaves for the first time; it joins our holding, which
    if g not in origin or origin[g].has(f.index): return   #   goes where origin_acked's goes (§4.2)
    origin[g].set(f.index)
    for q in suppression_scope(g): send_have(q, g)

def offer_at_publish(g, d):                            # a pull-only type's source (EAGER off) pushes nothing, so no
    origin[g] = all_bits(N(d))                         #   acknowledgement can come: every chunk is offered at once, to
    for q in suppression_scope(g): send_have(q, g)     #   the peers origin_acked would offer it to, and our holding
    T = type_of_group(g); offers = {}                  #   names every chunk, which the offers show anyway
    for i in range(N(d)):
        for q in source_pool(T, g, colour_of(g, i)): offers.setdefault(q, set()).add(i)
    for q, idx in offers.items(): announce(q, g, bitmap(idx))

def origin_acked(g, i):                                # [c3, P4] a chunk of a group we publish is acknowledged:
    if SOURCE_OFFERS == PUBLISH: return                #   (none at PUBLISH: the offers left at publish, §4.7)
    if origin[g].has(i): return                        #   a peer's holding names it (§4.3), or
    origin[g].set(i)                                   #   a copy's room timed out first (§4.11). It joins our
    for q in suppression_scope(g): send_have(q, g)     #   holding, which goes where a forwarding node's goes (§4.2)
    T = type_of_group(g); fam = T.family(g); c = colour_of(g, i)   # [c3] the relation peers not chosen to be
    for p in [q for q in source_pool(T, g, c) if q not in planned[g][i]]:
        announce(p, g, bitmap({i}))                    #   pushed it are offered it; a refused push is owed (v0.7)

def candidates_for_source(f):
    T = type_of_group(f.group); g = f.group; fam = T.family(g); c = colour_of(g, f.index)
    if UPLINK >= STRIPE_UPLINK: pool = links(T)                                   # [c13] every link
    else: pool = source_pool(T, g, c)                                             # the relation, as the other nodes do
    return [q for q in pool if wants_from_me(q, g).has(f.index)]

def source_pool(T, g, c):                              # whom a source pushes below STRIPE_UPLINK, and offers to
    fam = T.family(g)
    rel = [q for q in links(T) if c in push_out[q][T][fam]]
    return rel or links(T)                             # none in fam for colour c: the links, filtered by interest
                                                       #   by the caller, as gossipsub's fanout (below)

def unpush(p, g, i):                                   # [c3] a chosen push that will not be made: not counted, under
    for (g2, i2) in fills(g, i): pushed[p][g2].clear(i2)   # every group note_push marked, and owed to a relation peer,
                                                       #   or at a source to a peer of the
    if p in mesh or (g in origin and p in source_pool(type_of_group(g), g, colour_of(g, i))):   # pool as it stands
        owe(p, g, bitmap({i}))                         #   now (v0.5 §5.2's, with the fallback links)
```

**What carries over.** Batch order (card 2) and striping (card 13) are `seacast-lite.md` §5.1
unchanged, and the window (card 14) is `seacast-lite.md`'s counted in bytes (§4.11). So is v0.7's
single offer: the source offers a chunk only to the peers of its pool (the relation for the chunk's
colour, or the fallback links, below) not chosen to be pushed it, and a peer whose push its queue
refuses is owed the chunk instead, so these two paths never offer a peer the same chunk twice; a
join (`join_push`, §4.1) or heartbeat gossip (§4.8) may offer it again. The generalisation is that
the candidates are the links that want the chunk, which for a pre-seeded peer (a node with the
blobs from its mempool, I8) is decided by the holding it sent before any data, so a source holding
*part* of a group pushes only what its peers lack.

**A refused push to a fallback link is owed.** `seacast-lite.md`'s `unpush` (v0.5 §5.2) owes a push the
queue refuses to a mesh peer; there the mesh is the set the source pushes and offers to. With no
relation in the family for the chunk's colour that set is the fallback links (`source_pool`), so
`unpush` here owes a peer of the source's pool too, the pool as it stands when the push is refused.
As for a relation peer, the owed offer may leave before the chunk's acknowledgement, and at a slow
source an asker that waits past the promise parks it for the group.

**When the source offers** [c3] (v0.9 §5.1). A chunk is *acknowledged* at the first holding naming
it, from any peer (§4.3), or, if none comes, at the first window timeout of any copy of it (§4.11; a
closed connection drops the room of its copy, `seacast-lite.md` §8.1), as `seacast-lite.md`'s glossary has
it.
- **A source offers a chunk at its acknowledgement** by default (`SOURCE_OFFERS = ACK`), for every
  object type a source pushes, the rule v0.9 had for every source. The offers trail the pushes by
  about a round trip.
- **Offering at publish is the source's choice** (`SOURCE_OFFERS = PUBLISH`). No rule at another
  node needs either setting: a receiver takes an offer whenever it comes. The setting changes how a
  group spreads, as any default does (`seacast-lite.md` §8.3): what other nodes are asked and pushed,
  and when they complete. A source whose offers draw asks it cannot answer in time is parked by its
  askers for the group, a cost it bears itself. At `PUBLISH` the source offers each chunk at
  publish, by the rule it would use at the acknowledgement, to its pool as it stands then, and its
  holding grows at each chunk's first write (`origin_written`), as before v0.9; an acknowledgement
  then does nothing (`origin_acked`), not even for a chunk a peer rebuilt before the source wrote
  it. A source that wants P4's cover toward its pool offers at the acknowledgement (below). A client
  may key the choice on its uplink, as striping is (`STRIPE_UPLINK`); this document does not
  (below).
- **A chunk that no peer wants** is pushed to no one and never acknowledged. That costs nothing: its
  offers would have gone to no one either.
- **A pull-only type's source** (`EAGER` off) pushes nothing, so no acknowledgement can come. It
  offers every chunk at publish, by the rule it would use at the acknowledgement, to its pool as it
  stands then, and its holding names every chunk (`offer_at_publish`). With no pushes, the offers
  have nothing to race. They name the source to those peers, which [P4]'s paced holding does not
  hide. No setting publishes a pull-only type: rows come from cross-fill or a rebuild.

**Open: a chunk that is never acknowledged,** as `seacast-lite.md` §5.1 names it. At
`SOURCE_OFFERS = ACK` the source offers a chunk to the rest of its pool only at the chunk's
acknowledgement, and a chunk has none while no holding naming it reaches the source and no copy of
it times out in the window (§4.11). That happens when each of its chosen pushes was refused or
skipped by projection, stays queued to a peer that does not read, or went with its connection
before a holding or the timeout (`seacast-lite.md` §8.1). A refused or skipped push to a relation peer,
or to a fallback link where the chunk's colour has no relation, is offered to that peer instead
(above); one to any other link, which only a striping source pushes, is forgotten (`unpush`, as
`seacast-lite.md` §5.2). A holding naming the chunk comes once a peer that holds a copy claims it to
the source: a copy delivered before its connection closed and forwarded, a rebuilt copy, or a
decode claim, which names every chunk of a coded group (§4.2, §4.6). Until then the source offers
the chunk only once a peer has asked for it and the source's answer is acknowledged: a peer
offered the chunk in place of its push, at a join (`join_push`, §4.1) or, for a type whose
`ANNOUNCE_EXTRA` is `SAMPLE`, by heartbeat gossip outside its relations (§4.8), or a peer that asks
without an offer, by the source's custody or as a routed request (§4.5, §4.10). No rule bounds
that wait within the group's lifetime. At `PUBLISH` the chunk is offered at publish.

**A source's links in a family it does not custody.** A proposer holds every column of its block but
custodies few of them (§1.3), and no rule forms a relation in a family a node has no duty in. A
source never waits for links: it publishes at once to the links it has. On top of its fanout, three
layers keep its chunks moving:
- **The fanout.** Below `STRIPE_UPLINK` a source pushes and offers a chunk to its relation peers for
  the chunk's family. With no relation in the family for the chunk's colour, it uses the links whose
  interest holds the chunk (`source_pool`), as gossipsub's fanout reaches a topic its publisher has
  not joined. A push to one of them that a full queue refuses is owed, as to a relation peer
  (`unpush`). The fallback holds for the payload too, where `seacast-lite.md`'s source with no
  mesh peer sends nothing (§6.1).
- **1. Links kept for the families it will publish** (`SOURCE_FLOOR`, a parameter). A node keeps at
  least `SOURCE_FLOOR` links to custodians of each family it will publish, opened through the
  rendezvous as `keep_floor` opens its own (§4.1). A proposer knows its slot in advance and can open
  them before it. 0 leaves the source to the hunt. Whether the floor pays depends on what the hunt
  costs, on the network and on the binding, so it has no default.
- **2. A hunt when a chunk has nowhere to go.** A source with no link whose interest holds a family
  it publishes reaches a custodian through the binding's means, while the rest of its chunks go out:
  a lookup at the rendezvous and a new connection, or a send outside the links over the transports
  of §7's fetch outside the links. It costs a lookup or a handshake while those chunks wait: one
  round trip where the node already knows a custodian's record, more where it must look one up.
- **3. The code.** A column that reaches no custodian from its source is a withheld column, and the
  rows rebuild it where rows are kept (§4.6: the row setting, or supernodes under custody; under
  custody alone no node rebuilds a column).

**The source's holding is paced** [P4], as in v0.4 §5.1 and for the same reason: a holding that
names every chunk before any has left can come only from the source.
- **What it names.** A group's holding names the chunks acknowledged so far, at `ACK`. A chunk joins
  it at its acknowledgement (above), for every object type a source pushes, and the holding then
  goes to the suppression scope, as a forwarding node's does when a chunk arrives (§4.2).
- **A pushed peer.** Before its first push to a peer, the source sends the peer a holding naming
  that chunk, urgent, so that the holding goes just ahead of the push; it does so once per peer,
  whether or not the queue admitted either (`led`).
- **Per group.** The rule is per group, so a proposer paces the holding of each column group it
  publishes.
- **The claims.** The two claims (§1.5) follow the paced bitmap: a source claims neither
  `claim_all` nor `complete` for a group it publishes until every chunk of it is acknowledged. That
  is what v0.4 does by reading its decode claim from a full bitmap.
- **Not covered: a pre-seeded node** (I8). It holds part of a group before its peers but did not
  publish it, and its first holding names what it holds, which is what lets its peers skip it.

**Merging the source's holdings** (`MERGE_HOLDINGS`, §4.2, permitted). v0.4 allows holdings that
would leave together to be merged into one; here a holding still in the source's queue takes the
newer chunks instead of a second holding going out.

**Open: fewer holdings.** Keeping the source's holdings back for a set time, or sending them to
fewer of the scope's peers, which v0.4 does not provide for, is for later study.

#### Rationale

**v0.7's single offer** (since 2026-11-04). Among the toy's recorded cells then, only the thin lossy
one (`loss-thin`), whose queues refuse some chunks at admission, met the second offer. There the
single offer sends fewer offers, and the warm medians (seacast-figures.md,
"A cell, the median and the tail"), of completion and of copies, stay as they were
(seacast-figures.md, §4.7).

**A refused push to a fallback link is owed** (decided 2026-11-14). Without it, a fallback target
whose push was refused would be neither pushed the chunk nor offered it at the acknowledgement,
whose offers skip the planned targets (`origin_acked`). When every copy was refused, no copy is in
the window either, so the acknowledgement itself waits for a holding that names the chunk, such as a
decode claim, or for a later copy, an answer to an ask, to time out. Two alternatives were not
taken: an offer to a refused fallback target at the chunk's acknowledgement, which then comes that
late; and leaving the gap.

**When the source offers** (v0.9 §5.1, taken for every object type on 2026-11-11; the source's
choice since 2026-11-18).

**Offering at the acknowledgement, by default.** Offered at publish, the offers race the pushes: a
transport that takes the whole batch at once lets every offer leave at once, the relation asks for
chunks whose pushes are still queued, and the source answers on top of its pushes. The
acknowledgement is the one event the source sees whatever the transport holds (§4.11).

**Offering at publish, the source's choice** (decided 2026-11-18). Two things decide it:
- *Its uplink.* The offers draw asks on top of its pushes. In the toy's custody cell, a 1 Gbps
  proposer that offers at publish completes its block sooner at the median than one that offers at
  the acknowledgement, on the toy's 60-node graph and on the research harness's 100-node one, with
  writes completing at once and with one write at a time. It also answers several times as many
  asks. A 50 Mbps proposer that offers at publish completes its block later, at 60 nodes and at 500
  (below; seacast-figures.md, §4.7).
- *Its privacy.* Every chunk offered at once, by the one node that holds them all, names the source
  to those peers, and the paced holding [P4] then hides nothing from them. Toward the peers outside
  its pool (the relation for the chunk's colour, or with none the fallback links, `source_pool`) the
  settings are alike: for a type whose `ANNOUNCE_EXTRA` is `SAMPLE`, its heartbeat gossip draws on
  every chunk at either setting, since `publish` puts each in the gossip history (§4.8), and for one
  at `ALL_JOINED` or `NONE` there is none. A source that wants P4's cover toward its pool offers at
  the acknowledgement.

Copies do not decide it: offering at publish adds a little to the copies of the block received per
node, data and control, on the toy's 60-node graph, and saves a little on the research harness's
100-node one (seacast-figures.md, §4.7). A client may key the choice on its uplink, as striping
is (`STRIPE_UPLINK`); this document does not, since a fast source may still want P4.

**A pull-only type's source** (decided 2026-11-18).

**A chunk that is never acknowledged, in the toy.** The recorded cells do not churn, and a churn
cell bounds it only where every copy of one chunk is lost with its connection; no toy knob closes a
source's links in the middle of a message.

**The acknowledgement against the document before, in the toy.** These are the results at 60
nodes (seacast-figures.md, §4.7):
- **The payload** completes as soon or a little sooner, and its source saves bytes where the
  transport takes the batch at once (below, "The source's offers, card 3 at the source").
- **A 50 Mbps proposer's custody block** completes sooner at the median, on most seeds.
- **A column's source** uploads less and is asked far less. With §4.11's rule it saves about as
  much, against that rule alone. The rows' proposer uploads fewer copies of its block.
- **The cost.** The rows complete later, on every seed, and later than with no source offers at
  all; the rows with liars complete later too. A 1 Gbps proposer's custody block completes later.
- **Why the rows pay at 60 nodes.** At one seed the proposer's relation peers pulled from it, while
  it pushed, the cells it did not push them. Offered each cell only at its acknowledgement, they
  completed much later. The other nodes moved little.

These are the results at 500 nodes (seacast-figures.md, §4.7):
- **Against the document before,** at one seed: the payload (tier 4 in the all-home network), the
  rows and a 50 Mbps proposer's custody block complete sooner at the median, and the custody block
  of a 1 Gbps proposer completes a little later (a fifth of the nodes sampling).
- **Against offers per type** (below):
  - the rows complete a little later at the median, and with §4.11's rule later on every seed;
  - a 1 Gbps proposer's block completes a little later;
  - the block of a 50 Mbps proposer completes sooner, at the median and at the tail;
  - a column's source uploads less, and is asked far less.
- **The relation peers at 500 nodes.** At one seed, a far smaller share of the nodes pulls many
  cells from the rows' proposer with offers per type than at 60 nodes in the document before. With
  the offers at the acknowledgement they complete a little later at the median. The two of them
  that completed first complete much later. The nodes that pull nothing from the proposer move
  little.
- **So the rows' cost is a 60-node finding.**

**The alternative: offers per type** (decided 2026-11-10, replaced 2026-11-11). A field per object
type had the payload's source offer at the acknowledgement and a column's at publish.
- **What it kept:** it kept the rows' early completion at 60 nodes, against offers at the
  acknowledgement for every type, with and without §4.11's rule; and a 1 Gbps proposer's earlier
  block, at 60 nodes and at 500 (seacast-figures.md, §4.7).
- **What it gave up:** at 500 nodes it gave up the saving in upload of a column's source and a
  50 Mbps proposer's earlier block, for the rows' small gain there, with and without §4.11's rule
  (seacast-figures.md, §4.7).

One rule for every type, as v0.9 has it, was taken instead; since 2026-11-18 any source may offer at
publish (`SOURCE_OFFERS`, above).

**A source's links in a family it does not custody** (decided 2026-11-13; found 2026-11-09, writing
`candidates`' interest rule, §4.1).
- *In the toy.* Its setup gives the proposer a relation with every custodian it links to, which are
  the fallback's peers. Its custody and row settings use a `SOURCE_FLOOR` of 2, at setup
  (`--source-floor`). The hunt is not measured. At 500 nodes, with half the columns withheld, every
  custodian completed through the rows (seacast-figures.md, §4.7).
- *Not taken:* the alternative of holding the publish until the links are there would delay every
  family for one that the code can recover. No layer reaches a column that no node but the source
  custodies, and the toy's 60-node cells have such columns (seacast-figures.md, §4.7); routed
  sample requests do (§4.10).

**The source's holding is paced** [P4].
- **Why not at the write.** Until v0.9 a chunk joined at its first write, as it still does at
  `PUBLISH`. Where the transport takes a batch at once, that named chunks which had not left (v0.9
  §5.1).
- **The signs that remain.** These remain here too, from v0.4's list and `seacast-lite.md` §5.1's:
  - the source offers every chunk, at `ACK` about a round trip after its first copy;
  - its holding tends to grow faster than anyone's;
  - it offers the chunks of the group that have the relation's colour at once to a peer that joins
    its relation (`join_push`, §4.1);
  - it is usually everyone's first sender;
  - and, at either setting, for a type whose `ANNOUNCE_EXTRA` is `SAMPLE`, its heartbeat gossip
    draws on every chunk of the group for the peers it samples outside its relations at each of its
    next three heartbeats, less what `announce` leaves out, since `publish` puts every chunk in the
    gossip history (§4.8), at `ACK` without waiting for any chunk's acknowledgement. Keeping a
    source's chunks out of the gossip history until they are acknowledged is left, as in
    `seacast-lite.md` §5.4, to the work on the source's privacy.
- **The cost of the later holding.** It names a chunk about a round trip later than at the write.
  A relation peer that got the chunk from a forwarder may push it back to the source until the
  holding arrives; cancel drops what is still queued. In the toy's all-home payload cells at 60
  nodes, with writes that complete at once, a few of a payload's chunks come back a message at the
  median of the seeds, and many more at one seed. With §4.11's rule fewer come back at the median.
  The 1 Gbps builder's cell has more come back either way, and no column's cells come back
  (seacast-figures.md, §4.7).

What P4 costs here depends on how many groups a source publishes. For the payload, one group, it
costs nothing (§6.1). A proposer of 128 column groups sends a holding per cell to each peer in that
column's scope, and on a 50 Mbps uplink those bytes take time of their own. In the toy at 60 nodes,
with a 50 Mbps proposer, the custody block completes later, at the median and at the tail, and so
do the row cells. With a 1 Gbps proposer the cost is small. Its peers, no longer told that it holds
every cell, also offer it cells. Under the liar fault P4 leaves more row members short (not
traced). With v0.5 merged (2026-10-21) few pairs stay short, and on most seeds none. It is v0.5's
last resort (its §6.1): when every announcer of a cell is parked, each is asked once more, at waits
that double. In a toy check at three seeds, without it the members stay short as before v0.5, while
asking announcers beyond the first sixteen changes nothing; the doubling waits are why those rows
complete late. The other cells move little (seacast-figures.md, §4.7).

The costs above were measured with the holding at the write. At the acknowledgement P4 sends as many
holdings, a round trip later. Moved there alone, with a column's offers still at publish, the
holding moves the toy's column cells little at the median: the rows, the rows with liars, and the
custody block with a 50 Mbps and with a 1 Gbps proposer (seacast-figures.md, §4.7).

The offers at the acknowledgement then move them as above.

**Merging the source's holdings** (measured with the holding at the write) takes back little of P4's
cost. With writes that complete at once, only holdings made in the same instant are in the queue
together: a small share of the slow proposer's holdings merge, and the custody block and the rows
gain a little, at the median and at the tail. With a transport that takes one write per connection
at a time (the toy's `--send-buffer 1`), a holding also waits while another entry to the same peer
goes out: more holdings merge, and the custody block gains a larger share of P4's cost, which is
smaller there; the rows gain as little at the median. Copies move by 0.01 at most, and under the
liar fault merging leaves slightly fewer pairs short than P4 alone (both before v0.5).
Most holdings would leave alone anyway: at one seed, most find no earlier holding of their group
still waiting, in the queue or in the transport. Taking back more needs fewer holdings, which v0.4
does not provide for: holding them back for a set time, or sending them to fewer of the scope's
peers; both are for later study (seacast-figures.md, §4.7).

**The source's offers, card 3 at the source,** cost a home builder bytes.
- **At publish**, in the toy's tier 4 cells (seacast-figures.md, §4.7):
  - they drew asks that the builder answered after its first copies, and most of those answers
    arrived as duplicates;
  - without the offers a 50 Mbps builder uploads fewer copies of the message, and its cells' medians
    move little;
  - a 1 Gbps builder uploads far fewer copies, but completes a little later;
  - a 1 Gbps proposer of columns completes later, since its offers let peers pull from it while its
    uplink has room.
- **At the acknowledgement**, with writes that complete at once (seacast-figures.md, §4.7):
  - the payload's offers draw fewer asks;
  - a 50 Mbps builder uploads fewer copies of the message, and so does a 1 Gbps builder;
  - the medians move little, and none is later.

  So most of those bytes are saved where the transport takes the batch at once, and none need saving
  where it keeps §4.11's rule: there the offers wait behind the pushes either way, and they draw
  about as many asks (seacast-figures.md, §4.7).
- **A column's offers wait for the acknowledgement too** (above). A fast proposer pays for it: its
  block completes later at 60 nodes, and a little later at 500, than with its offers at publish
  (seacast-figures.md, §4.7).
  - A fast proposer can take it back by offering at publish (`SOURCE_OFFERS`, above). With the
    offers keyed on the configured uplink, as striping is, its block completed a little sooner at
    60 nodes than in the document before; at 500 nodes the cost is the small one above
    (seacast-figures.md, §4.7). The order of a source's queue is §4.12's.

### 4.8 The heartbeat

```python
def on_heartbeat():
    ihave_frames.clear(); ihave_asked.clear()                 # §4.3's limits start again, and the
    for a in held_back.values(): retry_offer(a)               #   retry runs for what they held back,
    held_back.clear()                                         #   which they do not count
    served_hb.clear()                                         # §4.5's serving budget starts again
    release_wanted_groups()                                   # §4.5: the places of unknown groups named in WANTs
    drop_stale_waits()                                        # seacast-lite.md §4.2: copies and ties past their window
    ids = gossip_history.gossip_ids()                         # stock: ids of the last 3 heartbeats
    for T in joined_types(): keep_floor(T)                    # §4.1, links for the floor per family
    for T in joined_types(): maintain_relations(T)            # §4.1
    for T in sampled_types(): keep_coverage(T)                # §4.1, the coverage floor   [D12]
    eligible = [q for q in joined_peers() if not related(q) and gossip_eligible(q)]   # stock: scores
    n = min(len(eligible), max(D_LAZY, floor(GOSSIP_FACTOR * len(eligible))))
    for q in sample_without_replacement(eligible, n):
        if PACED: pace_queue.append((q, ids, now))            # [c15]
        else: send_gossip(q, ids)

def send_gossip(q, ids):                                       # [c7] offers, per group
    for g, bits in group_bits(ids):
        if type_of_group(g).params.ANNOUNCE_EXTRA == SAMPLE:   # [D5] ALL_JOINED offered at forward time already
            announce(q, g, bits)                               # minus pushed[q], minus peer_has[q] (§4.4)
```

At each heartbeat, as in `seacast-lite.md` §6.4, §4.3's IHAVE limits start again and what they held
back is retried, TTLs expire, the links for the floor per family, the relations and a sampler's
coverage floor are maintained, and heartbeat gossip goes out. The gossip offers the last three
heartbeats' chunks, less what each peer holds, was pushed or lies outside its interest
(`announce`), to a sample of the joined peers outside the node's relations that stock scoring
admits: one peer per pace tick with card 15 (`on_pace_tick` unchanged), and all at once without
it. It offers only groups of a type whose `ANNOUNCE_EXTRA` is `SAMPLE` (`send_gossip`): a type at
`ALL_JOINED` is offered at forward time instead, and one at `NONE` is not offered beyond its
relations `[D5]`. The window of `seacast-lite.md` §7.1 is per node across every group of every object
type (X3).

### 4.9 The window's projection, per object type

```python
def projected(p, g):                                           # [c12] seacast-lite.md §7.2, read per object type
    T, h = type_of_group(g), hdr[g]
    if T.threshold(h) == T.index_count(h): return False         # no code: every index is needed, nothing is projected
    has, sent = peer_has[p][g].bits, sent_to[p][g]
    return popcount(has) + FAN_IN * popcount(sent & ~has) >= T.threshold(h)
```

**Projection applies to types with a code only.** Card 12 drops a push, never an answer, to a peer
that is projected to reach K from what it holds and what is on its way, on the premise that any K
chunks complete a coded group. For a group whose K equals its N, as a column's, `projected` is
false: every index is needed, and nothing is projected.

#### Rationale

**Why only with a code.** A column has no code across its cells (K = N), so the premise fails: a
dropped cell is a cell the peer still needs, and in a thin family nobody else may be pushing it.
Executing the custody setting (§6.2) found this: with `seacast-lite.md`'s `projected` a custodian ended
short of exactly the cells its pushers had projected away, and nobody offered them, since a planned
push is not announced.

### 4.10 A sampler pulls

```python
def sample(g, bits):                                   # at block arrival: the application's draw, never narrowed to
    if expired(g): return                              #   what our links serve; ours from now on (§1.5), unless
    interest[g] |= bits                                #   the group is past its lifetime (seacast-lite.md §8.1)
    for i in bits: ask_sample(g, i, first=True)        # the first phase: every sample at once, one peer each

def ask_sample(g, i, first=False):                     # one sample to one peer, never one asked for another
    T, b = type_of_group(g), block_of(g)               #   sample of the block (I6): a link that serves it, else
                                                       #   a routed request through another (§4.5, route_want)
    if mine[g].has(i) or expired(g): return
    if not first and samples_in_flight[b] >= SAMPLE_OUTSTANDING:   # the node's cap per block, across the block's types
        return held_samples[b].append((g, i))          # LiteDAS's cap: asked when a second-phase ask ends
    fresh = [q for q in links(T) if q not in sampled_from[b] and not parked(q, Ask(g, i))]
    direct = [q for q in fresh if serves(q, g, i) and not high_custody(q, T)]
    via = route_next(T, T.family(g), [q for q in fresh if not serves(q, g, i)
                                      and join_recv[q][T].duty == FORWARD])
    high = [q for q in fresh if serves(q, g, i) and high_custody(q, T)]
    order = [(direct, 0), (via, T.params.ROUTE_HOPS)] + ([] if first else [(high, 0)])   # high custody: the fallback
    cands, hops = next(((c, h) for c, h in order if c), (None, 0))
    if cands is None:
        if first: after(T.params.SAMPLE_RETRY, ask_sample, g, i)   # only high custody serves it: the second phase
        return                                         # nobody left to ask: missing, for the application's verdict
    q = choice(cands)
    sampled_from[b].add(q)
    if not first: samples_in_flight[b] += 1
    send(q, Want(group=g, bits=bitmap({i}), standing=True, hops=hops), urgent=False)   # no promise timer (§4.5)
    after(T.params.SAMPLE_RETRY if first else T.params.SAMPLE_RETRY2, resample, g, i, q, first)

def resample(g, i, q, first):                          # the wait ran out
    b = block_of(g)
    if not first: samples_in_flight[b] -= 1
    if not expired(g) and not mine[g].has(i):          # once g is past its lifetime, no state is made again for it
        park[q][g] = now + PARK_TTL                    # it held or should have held it (a first hop may have had no route)
        ask_sample(g, i)                               # the second phase: another peer, a short wait
    while held_samples[b] and samples_in_flight[b] < SAMPLE_OUTSTANDING:   # the room left goes to the held samples,
        ask_sample(*held_samples[b].pop(0))            #   even if g has expired; each pass takes the oldest off the list
```

**A sampler's interest is `DECLARED` and its duty `NONE`** (§1.2). It learns the group ids from the
block, as everyone does, and declares each sample to one peer: a link of ordinary custody that
serves it (§1.3: a custodian of the column), or, where none is left, another link, as a routed
request; or, only in the second phase, a peer of high custody, as the fallback.

**The declaration is a WANT and nothing else:** no JOIN names the sample, no holding of ours reaches
anyone but the sender of a chunk (the acknowledgement of §4.2), and a peer learns only the sample it
was asked for. Nor does the WANT start a promise: `SAMPLE_RETRY` and `SAMPLE_RETRY2` are the WANT's
own timers (the repair sample's WANT of §4.6 likewise). `filter_entry` starts v0.5's promise for an
ask the pull discipline makes on an offer and not for one marked `want` (§3: sent as a `Want`), but
a claim's probe, which keeps its own (§4.6). Under the alarm option the member's ask of the
claimant takes the probe's promise too (§4.6), which the option, having no code block here, starts.

**One sample per peer.** A peer is asked for at most one sample of a block, so that no peer learns
more than one of the node's samples; §8 gives the reasons, selective disclosure first.

**The WANT is standing:** the peer answers from what it holds and, for the rest, when the chunks
arrive (§4.5), so the WANT may go out at block arrival, before any cell has reached the custodian;
in the toy it does. The duplicate that a peer may still deliver after the sampler moved on is
acknowledged like any duplicate.

**A custodian bounds what one peer pulls from it per group** with `SERVE_LIMIT` (R6): the answers
it gives the peer are counted per group the asks name (`served`). Its bound is what an honest peer
may need from it (§6.3): it is K for a row, so at that value a peer is answered at most K asks in a
row's group; it is the index count for a column, so the limit alone does not keep a "sampler" from
pulling from one custodian a column it did not join. Since a cell is stored under its row and its
column, a row's cells asked through their column groups count against the columns, not the row.

**Two phases** `[D12]`. The first phase declares every sample at once, one peer each, and waits
`SAMPLE_RETRY`, a long wait: on the honest path the custodian receives the cell within it, and the
sample arrives once, one hop after the cell reached the custodian. A sample still missing then goes
to the second phase: the peer asked is parked for the group, and the sample is declared to another
peer that has not been asked for one, a link of ordinary custody that serves it while one is left, a
routed request through another link after, a peer of high custody last, each with a short wait
`SAMPLE_RETRY2`. At most `SAMPLE_OUTSTANDING` such asks are in flight per block, counted across the
block's sampled types; `SAMPLE_OUTSTANDING` is a setting of the node, not of a type. When a
second-phase ask's wait ends, its slot frees. If that ask's sample is still missing and its group
has not expired, the sample's ask of its next peer takes the slot first, when a peer is left to ask.
The block's held samples are then tried in the order they were held while room is left, even when
the group of the ask whose wait ended has expired. A sample with no peer to declare it to in the
first phase (no link of ordinary custody not yet asked serves it, and none routes it) is not
declared then, and goes to the second phase after the same wait. The hunt for a sample ends when it
arrives, when no link is left to ask (each has been asked for a sample, is parked for the group, or
neither serves the sample nor forwards) or when the group expires, so an unavailable block costs a
bounded number of asks. Where the
binding offers a fetch from a node that is not a link (§7), the second phase may use it before a
routed request, under the same rule: one sample per node.

**Routed sample requests** `[D12]`: a routed request is a sample request with a hop limit. Where no
link serves a sample, from the first phase on, the WANT goes as a routed request, `hops` set to
`ROUTE_HOPS`, to a link with duty `FORWARD` that does not serve it, the nearest to the sample's
family where routing neighbours are kept (§1.3); each node on the way answers from what it holds
and passes the request one step on (§4.5, `route_want`). The default is one forwarding step
(`ROUTE_HOPS` = 1), two hops: the first hop asks a link of its own that serves the sample. A larger
limit lets the request travel further where one step does not reach a custodian, within each
forwarder's `FORWARD_LIMIT`. The cell comes back the way the request went, and each hop verifies it
(level 1) as any chunk. Each node on the way learns the sampled cell, and the custodian learns that
the node before it wants it, not who sampled it; so a node spreads its samples over different
paths, one sample per first hop (one sample per peer, above).

**The verdict** is the application's, as are the sample's size and when it decides: a sample that
has not arrived by then is missing, whether no peer had it or none could be reached, and the
coverage floor and the routed requests are what make the second case rare. LossyDAS's and
IncrementalDAS's verdicts are the form this section expects: a sample of `S` passes with at most
`L` missing, and a failed one is extended, never redrawn, and its new samples are declared as in
the first phase (§4.6's `REPAIR_SAMPLE` steps likewise). The draw is never narrowed to the columns
the node's links serve. How many samples a node takes is the application's: FullDAS's cells per
slot, or PeerDAS's eight columns.

#### Rationale

**From LiteDAS.** One sample per peer is LiteDAS's ("asking each from distinct nodes"), and so are
the two phases' timing ("an initial period to handle the happy path, and a second period to handle
potential issues") and the cap on the second phase's asks in flight ("use timeouts and the number of
outstanding queries to avoid traffic explosion").

**No promise for a sampler's WANT** (decided): v0.5 starts a promise when an ask is written (its
§7.2); a sampler's WANT, as the repair sample's, has only its own timers, while a claim's probe has
the promise of §4.6.

**Routed requests, from FullDAS:** they are its topic routing and its query forwarding as one
mechanism ("A node can take one of it's peers according to Topic Routing, and send to it a
forwardable query. We’ll get the sample in 2 hops").

**How far one step reaches, in the toy's graphs** (`toy/sampler_graph.py c`): a sampler's own links
serve nearly every (sampler, column) pair at 70 links and little more than half at 16, and a path
of two hops exists for every other pair. One step to the link whose computed custody is nearest the
column left few pairs unreached at 16 links where custodians keep their floor per column, and many
more without that floor; the second phase meets such a miss through another first hop, and the
routing rules meet it by construction (§6.3, `ROUTE_FLOOR`). Beyond one step: without the floor, the
Kademlia-style rule reached most pairs within two hops and the rest in three. A first hop drawn at
random, as here without the rules, was not measured (seacast-figures.md, §4.10).

**Not taken: narrowing the draw** to the columns the node's links serve was not taken. A sample
drawn among what a neighbourhood offers is a sample that neighbourhood steers, which breaks the
independence the guarantee rests on (FullDAS: "the more the block producer and its 'accomplices'
knows about the sample selection of a node, the easier it is to introduce correlation and thus fool
someone").

### 4.11 The window, in bytes

```python
W_BYTES = W * CHUNK_BYTES             # seacast-lite.md's W slots of CHUNK_BYTES: the payload's capacity is unchanged  [c14, X3]
in_flight = 0                         # bytes taken: held by a writer for the chunk it is about to send, or travelling
waiters = deque()                     # peer writers waiting for room, first come first served
sent = {}                             # (peer, group, index) -> (send time, bytes)

def wake_front():                     # seacast-lite.md §7.1's, over the window in bytes: room is free, so the first
    if in_flight >= W_BYTES: return   #   in line that can write tries again (§7.2 there)
    q = front()
    if q is not None: wake(q)

def write_waits(p):                   # seacast-lite.md §7.1's: p's write has not completed, so the line skips p
    if p in waiters: wake_front()     #   and the first writer in line that can write tries again, if room is free

def acquire_room(p, need) -> bool:    # True: p's writer may send `need` bytes now; False: it waits in line
    global in_flight
    fits = in_flight + need <= W_BYTES or in_flight == 0          # an empty window always takes one chunk
    if fits and front() in (None, p):                            # no writer that can write is ahead of p
        if p in waiters: waiters.remove(p)                       #   (seacast-lite.md §7.1's front, writing)
        in_flight += need
        wake_front()                                             # room remains: the next in line tries too
        return True
    if p not in waiters: waiters.append(p)                       # a writer keeps its place while it waits
    return False

def leave_line(p):                    # p's writer has nothing to send now
    if p in waiters:
        waiters.remove(p)
        wake_front()

def track_in_flight(p, f, need):      # the room now travels with chunk f
    key = (p, f.group, f.index)
    if key in sent: return free_room(need)        # a second copy still in flight: back at once
    sent[key] = (now, need)
    after(WINDOW_TIMEOUT, window_timeout, key, now)

def window_release(p, g, i):          # p holds chunk i, from anyone (§4.3)
    e = sent.pop((p, g, i), None)
    if e is not None: free_room(e[1])

def window_timeout(key, at):
    e = sent.get(key)
    if e is not None and e[0] == at:
        del sent[key]
        free_room(e[1])
        if key[1] in planned: origin_acked(key[1], key[2])    # [c3, P4] no holding came in time: released anyway (§4.7)

def noted(p, e):                                       # §4.5: the offers an entry carries, recorded as it is written,
    for g, bits in offers_in(e):                       #   whichever path queued them (announce, owe): asks on them
        offered_to[p][g] = offered_to[p][g] | bits     #   are outside the serving budget
    return e

def free_room(need):
    global in_flight
    in_flight -= need
    wake_front()                                  # the first writer in line that can write tries again

def next_to_send(p):                  # seacast-lite.md §7.2, with the chunk chosen before the room is taken
    q = queue[p]
    while True:
        queue_owed_relations(p)                                # JOINs, GRAFTs and PRUNEs a full queue refused, in order (§4.1)
        if owed_answers[p] and has_room(p):                    # an answer a full queue refused (v0.5 §4.1)
            enqueue(p, Entry(chunk=pop_owed_answer(p), solicited=True), urgent=False)
        if q.urgent: return noted(p, with_owed(p, q.urgent.pop(0)))   # HAVEs, acks, decode claims: first
        if not q.normal:
            out = with_owed(p, Entry()) if owed[p] else None   # owed offers on their own (v0.5 §7.2)
            if out: return noted(p, out)
            leave_line(p); return None                         # nothing to send
        k = choose(q)                                          # §4.12; chosen first: its size is what the window counts
        entry = q.normal[k]
        need = wire_size(p, entry) if entry.chunk else 0       # control takes no room
        if need and not acquire_room(p, need): return WAIT     # [c14] in line, FIFO over peers; an urgent arrival
        q.normal.pop(k)                                        #   wakes the writer, which keeps its place
        out = filter_entry(p, entry)                           # [c8, c12], and stale asks
        if need and not (out and out.chunk): free_room(need)   # the chunk did not leave: the room goes back
        if out:
            if out.chunk:
                track_in_flight(p, out.chunk, need)            # [c14] the room travels with the chunk
                if SOURCE_OFFERS == PUBLISH: origin_written(out.chunk)   # §4.7: the holding at the first write
            return noted(p, with_owed(p, out))                 # owed offers ride along
```

**The window keeps about one round trip of the uplink in flight,** whatever the chunks' sizes: a
payload chunk of 12 KB takes six times the room of a cell, and `W_BYTES` is `seacast-lite.md`'s `W`
slots of `CHUNK_BYTES`, so the payload's cells see the same capacity as before. Two things change
besides the unit. The writer chooses the entry before taking room, since the room depends on the
chunk, and control takes no room. And an empty window always admits one chunk, so a chunk larger
than the window is not stuck. `rarest` and `projected` (§4.9) are as before, and `filter_entry` is
§4.6's; `wire_size(p, entry)` (§3) is the binding's: the bytes the entry's chunk takes on the wire
to `p`, with the header that a first push of a cell's group carries on the libp2p stream binding in
form (b) (`seacast-bindings.md` §1.6, §2.3).

**The line skips a writer mid-write,** as `seacast-lite.md` §7.1's does. Writers wait for room first
come, first served over peers, and keep their place while they wait. A writer whose write has not
completed (`writing`, as `seacast-lite.md` §7.3 and its helpers define it) keeps its place but not the
front: `acquire_room` admits the first waiter whose writer can write (`front`), and every window
wake goes to that one (`wake_front`, here over the window in bytes: only while room is free).
Without this, a peer that stops reading while its writer heads the line holds all free room, and the
node sends no chunk to any other peer.

**A writer in line whose control write waits wakes the next,** as `seacast-lite.md` §7.1's does. A
writer in line may write control, which takes no room: an urgent entry, owed offers on their own, or
a control-only entry of the normal lane. It keeps its place in line. When the transport does not
take that write at once (`seacast-lite.md` §7.3), the writer calls `write_waits` as it starts to wait,
and the window wake lets the first writer in line that can write try again, if room is free. A write
that completes at once does not call `write_waits`. A client that cannot tell when a write starts
to wait, as with a blocking write call, may call `write_waits` before a control write from the line,
once it has marked the write pending (`writing(p)` true, as from `next_to_send`'s return). That is
safe: `front` then skips the writer, and admission is unchanged: a writer takes room only while
room is free, and never ahead of a writer in line that can write. Its cost is a change of
schedule: the early call can queue an extra run for the next writer even when the write then
completes at once.

**Open: room left unused after a queue edit.** A writer takes room only if its chosen entry
fits: `in_flight + need <= W_BYTES`, or the window is empty (`acquire_room`). The first writer in
line that can write may wait with a chunk that does not fit, say 12 KB with about 3 KB free. If a
later discard (a dropped or expired group) leaves it a smaller entry that would fit, say a 2 KB
cell, the discard itself queues no run for that writer. The cell waits until another event wakes
the writer, for example an urgent entry for its peer, another writer leaving the line, or room that
a holding or a window timeout frees. Waking the front writer when a discard changes its entry is a
rule change, for a later release.

**Below the writer** (v0.9 §7.3, as written). A writer should hand a chunk to the transport only
while the connection has less than one chunk unsent. The backlog then waits in the queue, where
cancel, projection and §4.12's order act on it.
- **v0.9 §7.3 says the rest:** what the rule bounds and what it does not, what follows when it is
  not kept, how quic-go and TCP keep it, and the note for operators on the access link's queue.
- **Two chunk sizes.** Cells and payload chunks share a connection, so the rule reads either as one
  write per connection at a time or, in bytes, as less than one payload chunk unsent; either serves.
- **A timed-out copy.** A copy's room that times out (`window_timeout`) also acknowledges the chunk
  at its source (§4.7).

#### Rationale

**The window's unit (X3, decided 2026-11-13, §8).** `seacast-lite.md` §7.1 counts the window in slots
of `CHUNK_BYTES` (12 000 bytes, the payload's chunk),
`W = ceil(uplink_bytes_per_s · (RTT_REF + TARGET) / CHUNK_BYTES)`. A cell is 2 096 bytes, so the
same slot count carries a sixth of the bytes per round trip. In the toy, a proposer of 128 column
groups was held by its own window to a small share of its uplink, at 50 Mbps and at 1 Gbps, and a
reconstructor's answer to a probe left late behind its burst of rebuilt cells
(seacast-figures.md, §4.11). One window over every object type (X3) is therefore counted in
bytes here, and a chunk takes its own length of it; slots per object type would be the alternative,
with the same capacity question at every boundary between types.

**The entry before the room.** `seacast-lite.md` takes a slot first and chooses after, which also
makes a control-only entry at the head of the queue wait for a chunk's slot.

**What the unit changes, in the toy** (seacast-figures.md, §4.11). At 60 nodes, the custody
setting's block completes sooner, at the median and at the tail, with a 1 Gbps proposer. With a
50 Mbps proposer it completes at about the uplink's own bound, where the slot window took several
times as long, and a little sooner with §4.12's source rule. The sampling cell's samples arrive
sooner. Under half the columns withheld every custodian completes through the rows sooner, with
every claim verified and none re-armed, since a reconstructor's answers no longer queue behind its
rebuilt cells. In the honest row cell no member decodes at the third phase at all, where several
did under the slot window, because the column path is done before the phase and the subnet's view
is whole. At 500 nodes the custody block and the withheld block complete sooner too, at the median
and at the tail. Tier 4 moves little (§6.1).

**Below the writer, in the toy.** The toy runs the rule as one write per connection at a time
(`--send-buffer 1`). Read in bytes instead, as less than one payload chunk unsent, the rule moves
the column cells little at the median, at one seed (seacast-figures.md, §4.11).
- **Its effect,** with §4.7's rules, in the toy at 60 nodes (seacast-figures.md, §4.11):
  - the 50 Mbps payload cells complete sooner, on nearly every seed, with fewer copies;
  - the rows complete a little sooner at the median, on more than half the seeds, and the rows with
    liars complete sooner at the median, on more than half the seeds. With a column's offers at
    publish (§4.7's alternative) the rule brought them sooner by more;
  - a 50 Mbps proposer's custody block completes later, on most seeds, and later at the tail;
  - the 1 Gbps cells move little;
  - at 500 nodes, the payload completes sooner with fewer copies, at one seed, and the rows complete
    a little sooner, on every seed.

**The line skips a writer mid-write** (2026-11-20, from `seacast-lite.md` v0.10.7's §7.1).
- *The case.* The line admitted only its first writer, and every freed room woke only it. A writer
  whose write has not completed cannot take room, so a peer that stops reading while its writer
  heads the line held every free byte. On 2026-11-20 `toy/line_stall_known.py --doc seacast` showed it on
  the `push` cell's network: with the source's line head stalled, the other peers' chunks waited in
  an empty window, and none was sent to them from 600 ms after the stall to the end of the check
  (seacast-figures.md, §4.11). With the rule none was held up. The check counts the sends to the
  other peers from 600 ms after the stall on (past `WINDOW_TIMEOUT`), and accepts queues left empty.
- *The wake when a control write waits* (since `seacast-lite.md` v0.10.9's §7.1). A burst of urgent
  entries woke writers in line that each blocked on its write, and free room went to nobody.
  `seacast-lite.md`'s monitor (its W2) found this in `loss-thin`. So a writer in line whose control
  write does not complete at once wakes the first writer in line that can write, as it starts to
  wait (`write_waits`), as `seacast-lite.md`'s does. Here control has a third path, a control-only entry
  of the normal lane, which takes no room and reaches the lane's head when a writer's queued chunks
  are discarded (a dropped or expired group). The wake acts at the write, whatever the entry, so it
  covers that path with the other two. A client whose write call blocks may call `write_waits`
  before a control write from the line instead, once it has marked the write pending. The early call
  can queue an extra run even for a write that completes at once. Admission is unchanged: a writer
  takes room only while room is free, and never ahead of a writer in line that can write.
  `toy/write_wait_known.py --doc seacast` checks five cases on each of the three paths, with p the writer
  that writes control and q the other writer in line: q has no run queued when `next_to_send`
  returns p's control; q has one after p's write starts to wait, and only after the control reached
  the transport and `write_waits(p)` was called with the write pending; q has none when p is not in
  line or when no room is free, the window full or above its cap; and a write that completes at once
  calls no `write_waits`. In the first, the second and the fourth, p keeps its place at the head of
  the line. `seacast-lite.md` has no such third path: its control-only entry goes through
  `release_unused_slot`, which gives back the writer's slot and also takes the writer out of the
  line when it holds none, so there a control-only entry is never written from the line.
  `wake_front` is this document's own, since its room is counted in bytes (`W_BYTES`), where
  `seacast-lite.md`'s counts slots.
- *Replaced: the wake before the write* (v0.10.7's). It woke the next writer in line before every
  control write of a writer in line, whether or not the write then waited. A write that completes at
  once leaves its writer able to write, and waking another then would change the schedule of the
  node's writers where nothing else changes.
- *The recorded cells* (`golden-seacast.txt`, against v0.10.6's). Twelve move in their digest only:
  `push`, `hold`, `announce`, `none`, `withholders`, `silent`, `cap-wait`, `dcb20`, `rr-stripe`,
  `without-a`, `ihave-limits` and `push-deep`. Two move in their numbers too: `loss-thin` and
  `late-block` (seacast-figures.md, §4.11). `without-b` is the same. The figures in this
  document measured before 2026-11-20 ran without the rule. With the wake at the wait (v0.10.9),
  `rr-stripe` and `push-deep` move in their digest only, back to their values before v0.10.7. Every
  other cell kept its recorded digest, `loss-thin` and `late-block` among them: there the wake moved
  within the same writer event. The wake before the write could reorder writers' runs that fell at
  the same time, and their frames to different peers.

### 4.12 Which entry goes next

```python
def choose(q) -> int:                 # the normal entry the writer sends next (§4.11)
    if q.normal[0].chunk is None: return 0                     # control at the head goes at once: it takes no room
    own = [k for k, e in enumerate(q.normal) if own_chunk(e)]
    if own: return pick(q, own)                                # [X3] a source's own chunks first, over the whole queue
    if ANSWERS_FIRST:                                          # an option, off in every setting (below)
        asked = [k for k, e in enumerate(q.normal) if e.solicited]
        if asked: return pick(q, asked)                        # answers before pushes
    return rarest(q) if RAREST else 0                          # [c9] v0.3: chunks up to the first control-only entry

def own_chunk(e) -> bool:             # a push of a chunk this node held before any peer: it is the group's source (§1.6)
    f = e.chunk
    return (f is not None and not e.solicited
            and not received[f.group].has(f.index) and not rebuilt[f.group].has(f.index))

def pick(q, ks) -> int:               # [c9] the rarest of these entries, the earliest on a tie; without card 9 the earliest
    if not RAREST: return ks[0]
    return min(ks, key=lambda k: (len(holders[q.normal[k].chunk.group][q.normal[k].chunk.index]), k))
```

**A source's own chunks go first.** The writer sends urgent entries first (§4.11). If a
control-only entry heads the normal queue, the writer chooses it next. Otherwise, if the queue
holds pushes of chunks that the node held before any peer (`own_chunk`), the writer chooses among
those pushes, across the whole queue and past offers and answers. With card 9 it takes the rarest,
the earliest on a tie. Without card 9 it takes the earliest.

**The writer can send answers before pushes** (`ANSWERS_FIRST`, an option, off). With the option
on, the writer chooses among queued answers after the node's own chunks and before any other push,
by the same rule of rarity and queue order. The option is the one to try where answers wait behind
long runs of pushes.

#### Rationale

**A source's own chunks first.** v0.3's order is rarest-first (card 9), and it reorders only the
chunks ahead of the first control-only entry. v0.3's source queued each group's offers after that
group's pushes (v0.3 §5.1). With one group, the offers follow every push, and rarest-first sees all
of them. A proposer, though, publishes all 128 column groups of a block at the same instant. It
queues the pushes and the offers of one group before those of the next. The first group's offers
then sit in every peer's queue ahead of the other groups' pushes, so rarest-first sees one group's
chunks at a time. The offers leave early and draw asks, and the answers and the second copies take
the proposer's window from its first copies. Taking the source's own chunks first, over the whole
queue, keeps them ahead. The rule was chosen with one window, counted in bytes over every group
(§4.11): the window part of X3. Its clearest gain in the toy was in custody with a 50 Mbps proposer.
The single-group cells checked ran exactly as under v0.3's order, and elsewhere the rule changed
nothing that the seeds could tell apart (seacast-figures.md, §4.12).

**Not taken: v0.3's order, and two other cures for the same cause.** v0.3's order is not taken for
the reason above. Dropping the source's offers, or queueing them after all of the block's pushes,
gains about as much with a 50 Mbps proposer. With a fast proposer, both delay completion at the
median, since its offers let custodians pull from it while its uplink has room
(seacast-figures.md, §4.12).

**Answers first, as an option.** An answer is a chunk its receiver asked for, so it is never a
guess, and the asker is timing it. For a pull on an offer, the asker may ask another holder after
the ask window (§4.13). If the promise is still open `PROMISE` after the ask's write, the asker
parks the asked peer for the group (§4.13). A sampler's WANT has its own timers (§4.10). A push has
no such clock. Under v0.3's order an asked chunk is rarely the rarest, since a peer of the
answering node holds it, so its answer waits behind fresh pushes. In the toy, the option moved
median completion little in most tier 4 cells, and shortened the asks' round trip at the 99th
percentile in most cells. With cards 8, 9, 12 and 15 off, answers waited behind long runs of
pushes, and the option cut their wait at the 99th percentile (seacast-figures.md, §4.12).

**Not taken: three other forms of answers first.** Each cost time in some cells of the toy
(seacast-figures.md, §4.12). The first sends the oldest answer first, ahead of a source's own
chunks too: it takes a slow proposer's uplink from its first copies. The second does that, and also
puts the answer's writer ahead of the window's line of writers (§4.11): it starves the other writers
at thin links. The third puts an answer first only once it has waited 100 ms.

### 4.13 The ask window follows the uplink

```python
def ask_scale() -> float:
    """1 at ASK_UPLINK and above; ASK_UPLINK / UPLINK below it (5 at 10 Mbps)."""
    return max(1.0, ASK_UPLINK / UPLINK)


IWANT_WINDOW = IWANT_WINDOW * ask_scale()      # 200 ms at 50 Mbps and above, 1 s at 10 Mbps
```

**The ask window stretches as the uplink falls.** `seacast-lite.md` puts two clocks on an ask (§6.1
there). At `IWANT_WINDOW` (200 ms) plus `RETRY_SLACK` after the ask, its retry asks an announcer,
an untried one first, if the chunk is still missing, under the retry's checks (`retry_offer`). The
ask's promise, from its write, parks the asked peer for the group if it is still open after
`PROMISE` (400 ms). Here the ask window stretches in proportion as the node's own uplink falls
below `ASK_UPLINK`, and stays as `seacast-lite.md` set it above it. The promise does not change.
- **Whose uplink:** it is the asker's own, the one figure a node is configured with (card 14 sizes
  its window from it, card 17 its push degree). The asked peer's link is not known; a home node
  asking a datacenter peer waits longer than it needs to before moving on, which costs time only
  when that peer does not answer.
- **The floor** is `seacast-lite.md`'s value: at 50 Mbps and above the ask window is `seacast-lite.md`'s.
- **The promise stays at 400 ms**, so a peer that does not answer is still parked as soon as in
  `seacast-lite.md`, and the asker moves on from it later only by the window. A slow honest peer can
  now be parked before the asker has moved on from it (the promise is shorter than the window below
  25 Mbps). A promise per peer that follows its observed answer times is permitted as local policy
  (§8).

#### Rationale

**Why the window follows the uplink.** `seacast-lite.md`'s two clocks are fixed. Both were set where
answers come back within a round trip or two, at 50 Mbps. On a thinner link an answer waits longer
behind the answerer's queue, the window runs out before it arrives, the second ask's answer
competes with the first for the same thin uplinks, and both arrive: the bytes stop falling with the
bandwidth and the tail grows.

**The promise's length** (decided 2026-11-13, §8). Stretching the promise with the window too was
checked and rejected: with 30 % withholders at 10 Mbps it lengthened the tail at the median of
paired seeds in the research harness, since withholders then went unparked for the whole payload.
Under the rule as it stands (the window stretched, the promise at 400 ms), the toy's count of
parked pairs stayed below `seacast-lite.md`'s on clean, withholding and mixed networks, since fewer
asks go out, but rose with 10 % of chunks lost (lost answers break promises)
(seacast-figures.md, §4.13).

**Evidence** (the research harness of the posts) comes from runs against `seacast-lite.md`'s fixed
window on the same seed (seacast-figures.md, §4.13). At 10 Mbps per node every seed was faster
and leaner, and the tail was shorter at the median and the copies were fewer. At 25 Mbps every
seed had fewer copies, but only slightly fewer, and the tail was unchanged within the seeds'
spread. With 30 % withholders at 10 Mbps the tail was shorter and the copies were fewer. The toy's
checks (mixed network, silent peers, loss) are in §6.3, `ASK_UPLINK`.

## 5. What carries over from `seacast-lite.md` unchanged

| `seacast-lite.md` | here | note |
|---|---|---|
| §1 the payload, the code, the commitment | the payload object type's `verify`, `decode`, `header_of` | the leaf rule unchanged in this version; a fraud proof would change it (`[D6]`, §8) |
| §3 the three levels | level 1 = `T.verify`, level 2 = `T.decode`, level 3 = the application | per object type (I7) |
| §4.1 `respond` | called from §4's `on_frame` | asks ride on the first answer; an answer a full queue refuses is owed (v0.5) |
| §4.2 `defer`, `tie`, `on_block_installed`, the bounded store | §4.2 | the gate is the type's (`authenticable`; `defer` here waits for it, and `on_header_validated` releases a block's cells and their ties); a copy that waits, kept or refused, and another copy of one that waits, tie their senders to the root they name (v0.8), no longer an offer (v0.5); v0.10's bounds on what waits in this document's own `defer`, `fill` (`drop_beyond`), `on_heartbeat` (`drop_stale_waits`) and `on_header_validated` (an index the group has not, `tie_slot`), since 2026-11-16; a second id for a received index only acknowledged, as there, on each axis (`on_validated`, since 2026-11-19) |
| §3 level 1's slot check (v0.10) | §1's table, `verify` of each type | a payload copy's slot is its block's (`validate_chunk`), a cell's its header's (since 2026-11-16) |
| §4.4 an IHAVE's bitmap held to a HAVE's limits (v0.10) | §4.3 `on_offer` | an offer's bitmap, ignored and counted beyond them (since 2026-11-16) |
| §4.4 gossipsub's IHAVE limits (v0.7): `over_ihave_limits`, `ihave_frames`, `ihave_asked`, `held_back` | §4 `on_frame`, §4.3 `on_offer`, §4.8 | counted per offer-bearing frame and per ask in reply to offers, per peer over every object type; what they hold back is retried at the next heartbeat (since 2026-10-27) |
| §4.6 `drop_group` | §4.6 | plus evidence `[D6]`; a later chunk is not forwarded or offered on the dropped axis, where the draft did (§4.4 `on_validated`, `forward`; since 2026-11-18) |
| §5.1 batch order, striping, the paced source HAVE [P4] | §4.7 | candidates filtered by interest; P4 per group, its claims with the bitmap; v0.7's single offer (since 2026-11-04); a pull-only type's source pushes nothing and offers every chunk at publish (`offer_at_publish`, since 2026-11-18); any source may offer at publish, its own choice (`SOURCE_OFFERS`, since 2026-11-18) |
| §5.3 `choose_push`, `guard_fails`, `note_push` | §4.4, §4.7 | candidates come from the relation |
| §5.4 `on_mesh_join` (v0.8) | §4.1 `join_push` | at a GRAFT the node accepts into a push relation, the relation's colour, and at the yes to its own GRAFT, a round trip after v0.8's (§4.1); on gossipsub's wires at its own GRAFT, as v0.8 |
| §6.1 `may_ask`, `retry_offer`, `promise_due`, `parked`, the offer table | from §4.3's `on_offer` | offers from any link; `IWANT([a])` read as a WANT, a pull on an offer (not `want`, §3); start delay `[D8]`; `IWANT_WINDOW` scaled by the node's uplink (§4.13); v0.5's offers kept per connection and group (`add_offer`, `announcers`) and its last resort when every announcer is parked (`last_resort`, `ask_parked`); v0.8's ties and no second ask of a peer while one is outstanding (`tied_to_root`, `outstanding`; §4.2 here), and the asks that go with an announcer's dropped offers (`drop_offer`, 2026-10-28) |
| v0.5 §5.2, §7.2 `owe`, `unpush`, `with_owed` | §4.4 to §4.7, §4.11 | a push or an offer a full queue refuses, or a push the writer skips by projection, can be owed (`owe`, `unpush`), and what is still owed rides the next write to the peer, less what that write's filter drops; `unpush` is §4.7's, where a source also owes a peer of its pool as it stands then; `mesh` in it reads as the peers of the push relation |
| §6.2 `gated` | `on_offer`, `filter_entry` | per interest |
| §6.4 `on_pace_tick` | §4.8 | |
| §7.2 `filter_entry`, `rarest` | `send`, `enqueue`; §4.12 | `rarest` unchanged; the writer takes a source's own chunks first (§4.12); `filter_entry` is this document's (§4.6): v0.5's promise starts when an ask on an offer is written; an ask sent as a `Want` (`want`, §3), a sampler's, a routed request's or the repair sample's, starts none (§4.10), but a claim's probe starts one (§4.6), and under the alarm option the member's ask of the claimant too |
| §7.1 the window, §7.2 `next_to_send` | §4.11 | one window per node over every object type, counted in bytes; the entry is chosen before the room is taken; JOINs, GRAFTs and PRUNEs a full queue refused are queued first, in order (§4.1); the line skips a writer mid-write, and a writer in line whose control write does not complete at once wakes the first writer in line that can write as it starts to wait, if room is free, as `seacast-lite.md`'s do (`front`, `write_waits`; `wake_front` this document's own, in bytes; since 2026-11-20, the wake at the wait since v0.10.9) |
| §7.2 `projected` | §4.9 | reads the type's K; off for a type without a code |
| §8.2 limits | §6.3 | plus relations and groups per slot |

**The versions carried.** Each later version of `seacast-lite.md` is carried into this document; the
list of versions, with what each brought and when it was carried, is in
[`seacast-decisions.md`](seacast-decisions.md) ("The versions of `seacast-lite.md` carried").

## 6. Settings

### 6.1 `seacast-lite.md` as a setting

| notion here | in `seacast-lite.md` |
|---|---|
| object type | the payload only; one family |
| JOIN | subscription to the payload's topic: interest `ALL`, duty `FORWARD`, `M = 1` |
| push relation | the mesh: `SYMMETRIC` (`direction = BOTH`), `F_LO = 6`, `F_HI = 12`, `D_OUT = 8`; `PRUNE_BACKOFF` the client's (gossipsub's backoff) |
| announce relation | the mesh, plus `ANNOUNCE_EXTRA = SAMPLE` (heartbeat gossip to `max(D_LAZY, GOSSIP_FACTOR · n)` non-mesh peers, paced) |
| suppression scope | the mesh |
| holding / offer | IDONTWANT with a `HaveBitmap` / IHAVE with a `HaveBitmap` |
| WANT | IWANT with a `WantIndex`, one index at a time |
| claims | `claim_all` = the decode claim (all N bits); `complete` = the same, since interest is all |
| repair | `(everyone, at once, the mesh peers)` |
| `START_DELAY`, `SERVE_LIMIT` | 0, unbounded (the stock per-id limit remains) |
| evidence | none |
| wire | `seacast-lite.md` §2's magic strings (`seacast-bindings.md` §4) |

**Five differences in the rules, which no recorded cell exercises.**
- *A source with an empty mesh.* A source with no mesh peer for the payload offers its chunks to its
  links whose interest holds them, and owes them a refused push (§4.7, `source_pool`); below
  `STRIPE_UPLINK` it also pushes to them, as a column's source does with no relation in the family.
  `seacast-lite.md`'s source offers to its mesh only and, below `STRIPE_UPLINK`, pushes to it only: with
  an empty mesh it offers nothing at publish, a slower one makes no push, and its chunks enter its
  heartbeat gossip. This document keeps the fallback for every object type, since a source never
  waits for links (§4.7). No recorded cell has a source with an empty mesh.
- *More ids for a rebuilt index.* At an index held only as rebuilt, both documents forward the first
  copy that arrives under an id the node has not seen. `seacast-lite.md` stores it, so a copy under yet
  another id is a second copy of a received index, only acknowledged; here `fill` stores none of
  them, so each such copy enters forwarding (`forward`, where the choice of peers still applies).
  A repeat of a seen id at such an index is acknowledged where that id was stored (`accepted`):
  there, that is the id of the first network copy, which `seacast-lite.md` stores over the rebuilt one;
  here, it is the rebuilt chunk's own id, since `fill` stores none. Where the two ids are the same,
  both acknowledge it; where they differ, each acknowledges its own and ignores the other. No
  recorded cell has two ids for one index.
- *An IHAVE entry by id.* On the gossipsub binding this document takes offers as bitmaps only
  (`seacast-bindings.md` §4), where `seacast-lite.md` records a valid structured id in an IHAVE as
  an offer, which can draw an ask under its §4.4's checks. No recorded cell names an id in an IHAVE.
- *An id asked twice in one frame.* Here it is answered once and charged once against the stock
  limit of three answers per id (§4.5); `seacast-lite.md`'s `on_iwant` charges each repeat. The recorded
  cells did not move with it.
- *A link that has not joined the type.* Here an offer, a WANT, a GRAFT or a PRUNE for an object
  type the link has not joined is ignored (§2). In this setting every link has joined the payload's
  type, so no recorded cell has such a link.

**One difference in the rules, which a recorded cell shows.** A holding that reports an index the
peer had reported already frees the window's room of a copy written to it since (§4.3,
`on_holding`); `seacast-lite.md`'s `on_have` frees it for new bits only, so that room waits for
`WINDOW_TIMEOUT`. Only a run without cancel (card 8) writes such copies, and of the recorded cells
`without-a` moves with it: p50 432 to 429 ms, p99 517 to 518 ms, copies 3.99 to 3.97
(seacast-figures.md, §6.1).

The other differences the recorded cells show are in the scheduling (§4.11 to §4.13), which moves
times and copies by measured amounts (seacast-figures.md, §6.1).

**The regression.** The toy's fifteen cells are the regression for this setting, recorded for this
document in `toy/golden-seacast.txt` (`toy/check.py --doc seacast`) and compared against `seacast-lite.md`'s own
recording with `toy/check.py --doc seacast --golden golden.txt`. Since 2026-10-27 a thirteenth cell,
`ihave-limits`, sets stock gossipsub's two IHAVE limits (10 offer-bearing frames and 5000 asks;
§4.3). The other cells set none. Since 2026-11-15 there are two more: `late-block`, where 18 of the
60 nodes install each block 400 ms after its publish (`seacast-lite.md` §4.2's deferral and ties; this
document runs its own `defer`), and `push-deep`, the `push` cell with the earlier transport
(`--send-buffer 0`), whose line is the `push` cell's before the transport changed.

#### Rationale

**The distance to the recordings, by date.** The figures file gives the amounts
(seacast-figures.md, §6.1).
- Checked on 2026-10-07: with v0.3's window (slots of one payload chunk) every cell but `rr-stripe`
  reproduced v0.3's completion times and bytes exactly, and `rr-stripe` differed by a few ms at the
  median; the residue was the order of same-instant sends (this document iterates the relation in
  peer order where v0.3 iterated the mesh set). With the window in bytes (§4.11) the cells move
  little, by milliseconds at the median and the tail and by hundredths of a copy, either way, which
  is the two structural changes of §4.11 and not the unit: a control-only entry at the head of a
  queue no longer waits for a chunk's slot, and the chunk is chosen before the room is taken. So
  this document contains v0.3 to within those amounts, and with v0.3's window exactly but for
  `rr-stripe`'s residue.
- Since v0.4's P4 came in (2026-10-21, §4.7) the comparison is with v0.4's recording (`golden.txt`):
  eleven cells stay close to it, and `loss-thin`, at a 20 Mbps uplink, is a little later at the
  median and lighter in copies, the one cell where §4.13's scaled ask window applies; without P4 the
  medians had been well behind v0.4's.
- With v0.5 merged (2026-10-21; every cell of both recordings moves) the comparison is with v0.5's:
  eleven cells stay close to it, and `loss-thin` is a little later at the median and lighter in
  copies, as before the merge.
- With the group's key (2026-10-23, `seacast-lite.md` §1; both recordings move again, as under any
  renaming: `toy/README.md`) eleven cells stay close, and `loss-thin` is later at the median and
  lighter in copies.
- Since `seacast-lite.md` §5.1 announces only to the mesh peers it did not choose for a chunk
  (2026-10-25), its `loss-thin` runs differently with the same medians and copies, so these
  distances stand.
- With ties and no second ask of a peer at once (2026-10-26, `seacast-lite.md` §4.2, §6.1; both
  recordings move) eleven cells stay close, and `loss-thin` is a little later at the median and
  lighter in copies.
- Asks that go with their announcer's dropped offers (2026-10-28, `seacast-lite.md` §6.1) change no
  event in any cell of either recording: nothing was tied in the toy then, and its offers expire
  only after their group has completed.
- With v0.9's rules (2026-11-10, §4.7: the source's holding and its offers at the acknowledgement;
  every cell of both recordings moves), eleven cells stay close to v0.9's own recording, and
  `loss-thin` is a little later at the median and lighter in copies.
- With the toy's transport keeping `seacast-lite.md` §7.3's rule (2026-11-15, one entry at a time per
  connection; every cell of both recordings moves but `rr-stripe`, whose uplink has no send buffer),
  eleven cells stay close to `seacast-lite.md`'s recording, and `loss-thin` is later at the median and
  lighter in copies.

**`ihave-limits` against `seacast-lite.md`.**
- Under v0.9's rules and the toy's transport since 2026-11-15, in that day's recordings, this
  document held back slightly fewer asks to the next heartbeat than `seacast-lite.md` did. It was a
  little sooner at the median and a little later at the tail, with a few hundredths of a copy more.
  With the earlier transport (`--send-buffer 0`) it held back slightly fewer too, and it was a
  little sooner at the median and at the tail (seacast-figures.md, §6.1).
- Before §4.3 carried the limits, it held back none and ran as without them.

**Draft 0** did not reproduce the cells at all: it filtered a forwarding node's push candidates by
what it had already pushed, which `seacast-lite.md` does not, and it shuffled the relation peers for
repair in a different order than `seacast-lite.md`'s mesh set, so its random draws diverged; draft 1
fixed both.

### 6.2 The five designs as settings

| setting | object types | `M` | interest | duty | announce extra | repair | start delay | what it tests |
|---|---|---|---|---|---|---|---|---|
| tier 4 | payload | 1 | ALL | FORWARD | SAMPLE | everyone decodes at K; rebuilt chunks to relation peers short of K | 0 | the regression (§6.1) |
| variant C | payload | N | ALL | FORWARD | SAMPLE per colour | same | 0 | independent pusher sets per index on one neighbourhood; the floor |
| PeerDAS custody | column (rows kept by supernodes) | 1 | DERIVED (`cgc`) | FORWARD | ALL_JOINED | nobody decodes a column (no code); supernodes (every column) keep the rows and rebuild a row still short at the second phase's delay, PeerDAS's reconstruction delayed; rebuilt cells to the custodians lacking them | 0 | thin families, pre-seeded sources, cross-group repair, a proposer withholding half the columns |
| RowDAS | column, row | 1 | DERIVED (columns: `cgc`; rows: the node's subnet) | FORWARD | ALL_JOINED | rows not pushed (`EAGER` off); at K: row reconstructors (64 columns or more) on their subnet's row; later: supernodes on every other row at the second phase's delay, any member on its subnet's row at the third's, each with jitter; a row held on the columns waits once; rebuilt cells to the custodians lacking them; one claim defers once, verified by a probe | rows: 1 s (`[D8]`; RowDAS: a slot fraction) | cross-fill, the two claims, deferral on a claim, a proposer withholding half the columns, subnets without members |
| FullDAS sampling | column | 1 | DECLARED | NONE | none | none | 0 | interest without duty: a standing WANT per sample, retried at another link (§4.10); the custodians' serving load |

**All five run in the toy** (`toy/run.py --doc seacast --setting t4|c|custody|rows`, custody with
`--samplers` for the sampling row). Each setting is a settings file for the toy, and the invariants
the toy checks for every setting (`toy/invariants.py`) are these: every node completes its interest
given a source; nothing is pushed outside interest; upload stays within the duty bounds; a claim
whose probe goes unanswered is detected; one cell fills both groups; the tier 4 setting reproduces
its own recorded cells (§6.1). All six are checked: the first three on every run, the claim and
cross-fill ones under the row setting, the last by `check.py --doc seacast`.

#### Rationale

**Variant C** as a setting of this document completes the toy's check cell faster in the tail and at
more bytes than the tier 4 setting, the direction the harness measured, with the toy's sizes
(`toy/README.md`).

**The custody setting** runs a block of 32 blobs as 128 column groups from one proposer to
custodians of 8 columns each, with a mesh per column on the custodians' subgraph; every custodian
completes, nothing is pushed outside interest and no node pushes a chunk above its budget, and
executing it found two things in the carried-over code: the window's line of writers stalled while
slots were free (`seacast-lite.md` §7.1, fixed there, since it is `seacast-lite.md`'s window) and card 12's
projection assumes a code (§4.9). With supernodes (`--supernodes`), custodians of every column that
keep the rows and rebuild a row still short at the second phase's delay, the custody cell whose
proposer withholds half the columns completes on every seed run, where without them nearly every
custodian stays short; this is PeerDAS's reconstruction, delayed (§4.6; seacast-figures.md,
§6.2).

**The sampling setting** runs on top of custody (`--samplers`): a share of the nodes declare eight
cells per block to one custodian each, and every reachable sample completes, a little before the
custodians' columns do, with the custodians serving a handful of chunks each to samplers; executing
it is what made the WANT a standing request (§4.5, §4.10), since a sampler's WANT reaches the
custodian before the cell does, and a pull with a promise timer would have parked every custodian it
asked.

**The row setting** runs EIP-8371's rows on top of custody: each node has one designated subnet,
rows are pull-only, members complete at 64, reconstructors of 64 columns decode at K and any member
decodes later, and a proposer withholds half the columns, so that only the rows can fill them. At
the recorded seed every custodian completes through the rows, and on every seed run with a
custodian link per column for every member (§4.6's repair floor; without it some runs left
custodians short, each for a missing link), every cell sits in both of its groups (R4), and a liar
fault shows a false claim detected by the probe (R5; seacast-figures.md, §6.2). Executing it
changed the document in eight places: a chunk a node rebuilt is filled into its other groups as
rebuilt and acknowledged to nobody, and completes them (`decode_group` checks them as `on_chunk`
does); repair respects `EAGER`, so rebuilt row cells are offered to row members and pushed only
into the columns; the claim in a holding is "I hold or can produce every index", not "my interest
is satisfied", since a member complete at 64 was read as claiming 128; the probe is exempt from
stop-pull and the ask window and its promise is the deferral window; an unverified claim counts for
nothing in the subnet's view, or a liar suppresses the third phase; and "still incomplete" is read
in that view, or every member short of 128 rebuilds a row the network already has; and every
member keeps a link to each column (`REPAIR_FLOOR`), or a row is neither gathered nor repaired
where no member has one. With three supernodes the second phase completes the 32-subnet withheld
cell on every seed run, a cell some of whose subnets have no member (short without them at the
recorded seed), and much shortens the withheld cells' time (seacast-figures.md, §6.2); it
changed the document in two more places: a supernode keeps every row with interest declared on no
link (§1.2), and a row whole on its columns' bitmaps but not in the node's holdings waits once
before it is rebuilt (`known_across`), or a supernode still receiving its columns rebuilds rows
nobody withheld.

### 6.3 Parameters, limits and constants

| name | per | meaning | status |
|---|---|---|---|
| `M` | object type | colours of the push relation; 1 … N | `[D10]`: a parameter with no default (decided). Measured at 1 (tier 4, `seacast-lite.md`) and at N (variant C); 1 < M < N is open (below) |
| `F_LO`, `F_HI` | object type | in-pushers per family and colour: floor and cap (`seacast-lite.md`: 6, 12) | `[D10]` |
| `D_OUT`, `D_OUT_FAST`, `D_OUT_MAX` | object type | out-pushees per family and colour by uplink class (`seacast-lite.md`: 8; card 17's classes) | `[D10]` |
| `SYMMETRIC` | object type | one relation both ways per family and colour, grafted and pruned with `BOTH`: below `F_LO` grafted up to `D_OUT`, at `F_HI` pruned down to `D_OUT` at random (§4.1); False: in- and out-relations apart | `seacast-lite.md`'s mesh: True (§6.1), with `F_LO ≤ D_OUT < F_HI`, since at `D_OUT = F_HI` the prune makes no room; one-way relations are an option `[D10]` |
| `PRUNE_BACKOFF` | object type | how long after a PRUNE that a node receives it does not graft that peer again for the relation the PRUNE named (§4.1) | stated by its bounds: at least a round trip, at most how long a node may stay below its floor once its candidates have refused; on gossipsub's wires gossipsub's backoff (§7) |
| `R_NODE`, `R` | node | the per-chunk push budget (`seacast-lite.md`: 2, 6 fast; the source's plan) | `seacast-lite.md` §8.3's open item on size; for cells, open (below) |
| `ANNOUNCE_EXTRA` | object type | ALL_JOINED, SAMPLE or NONE beyond the relations | `[D5]`, decided: `ALL_JOINED` for columns and rows, as in every measurement; `NONE` permitted for columns, never for rows (§8); the payload `SAMPLE`, `seacast-lite.md`'s heartbeat gossip (§6.1) |
| `EAGER` | object type | chunks of the type are pushed eagerly; False: holdings and offers only (rows), at the source too, which offers every chunk at publish (§4.7) | – |
| `DECODE_AT_K`, `DECODE_LATER` | object type | who decodes at K; who decodes later and when (from `known_at`), e.g. EIP-8371's phases | `[D4]`, decided: EIP-8371's phases (§4.6), the second phase's delay shorter than the third's; the second at 1 s and the third at 2 s, each with up to 0.2 s of jitter, in the toy and in the research harness |
| `REPAIR_TO` | object type | whom rebuilt chunks of a group go to (`seacast-lite.md`: the mesh; columns: custodians lacking them) | `[D4]`, decided: pushed to the custodians lacking them, as measured. Options measured (§4.6, "Whom rebuilt cells go to"): the cells offered, not pushed, to the nodes that keep every row, or every rebuilt cell offered |
| `REPAIR_BUDGET` | object type | each rebuilt chunk to `R_NODE` of those lacking it and offered to the rest, as its source pushes a chunk (§1.6); off: to every peer short of K, `seacast-lite.md`'s | `[D4]`: an option, off (decided) |
| `REPAIR_FLOOR` | object type | links the rendezvous keeps, for a node that may rebuild, to custodians of each family it does not hold (the rebuilders' fanout, §4.6) | `[D4]`; decided, stated by its bound: at least 1; 1 in every measurement of the rows |
| `SOURCE_FLOOR` | object type | links a node keeps to custodians of each family it will publish, opened through the rendezvous (§4.7, the first of the source's three layers) | a parameter with no default (decided): 0 leaves the source to the hunt and the code; the toy's custody and row settings use 2, at setup |
| `DEFER_WINDOW` | object type | how long a peer's claim defers our own decode while one ask verifies it, and that ask's promise (R5) | `[D4]`, decided: 1 s, in the toy and in the research harness |
| `REPAIR_SAMPLE`, `SAMPLE_WAIT`, `REPAIR_REASK` | object type | after a verified claim, the steps `[(S1, L1), (S2, L2), …]` of a sample of the cells we lack, asked of their columns' custodians, each step extending the last and passing with at most `L_k` of `S_k` missing; the wait before each step is judged; and whether a lost cell is re-asked of another custodian, with the extension or, at the last step, in one more wait (R5) | option, off (`None`, `False`); kept as an option, on together with `REBUILT_SEEN` where a node defends against hoarding claimants; measured in §4.6 |
| `REBUILT_SEEN` | object type | a chunk the node rebuilt is marked seen, so a pushed copy of it is a duplicate and is not forwarded again (§4.6) | option, off; only with `REPAIR_SAMPLE`, never alone; measured in §4.6 |
| `ALARM_WAIT`, `ALARM_NEXT`, `ALARM_MAX` | object type | a custodian's alarm: how long after `known_at` a custodian lacking a cell of its custody asks a member of the row's subnet; how long before it asks another; and how many it asks (§4.6) | option, off; for networks without an honest supernode. The wait is stated by its bound: above the honest custodians' tail on the network. The measurements use 3.5 s, 1.5 s and 3 |
| `START_DELAY` | object type | seconds from the group id being known to the first ask | `[D8]`, decided: 1 s for rows, as in every measurement of the toy and the research harness; 0 for the payload and columns. Shorter for rows at a cost: with liars, row members are left short (§8) |
| `SERVE_LIMIT` | object type | chunks served per peer and group (R6) | stated by its bound: at least what an honest peer's interest may need from the node in the group, K for a row member (it completes at K) and the index count for a column's custodian; a sampler asks one cell per peer and block. Rows: 64 (K) in the toy and the research harness; columns: no limit in the measurements |
| `SERVE_BUDGET` | node, per peer | answers given one peer in a heartbeat, across groups, counted in the heartbeat the node decides each (a standing request's when its chunk arrives); the answers to asks on the node's own offers, recorded as they are written, and to a claim's probe not counted; an ask over it is refused, and a standing request's answer dropped and not retried, without penalty (§4.5) | stated by its bound (`seacast-lite.md` §8.3's kinds): at least what honest peers ask through one peer in a heartbeat other than on the node's offers: per block, a sampler's one cell, and the routed requests a forwarder passes on for the samplers it serves (`FORWARD_LIMIT` for each), with the standing answers that a block's cells release in one heartbeat; the cells of a row member's repair sample with its re-asks (`REPAIR_REASK`), and a custodian's alarm asks (§4.6); and a peer's asks by derived interest at a block's arrival. No limit in the measurements |
| `PROMISE` | node | how long an offer's promise runs before a broken one parks the peer for the group (`seacast-lite.md` §6.1: 400 ms), one value for every object type in the code (`filter_entry`) | the payload's promise stays at 400 ms (§4.13); a promise per peer that follows its answer times is permitted as local policy, with 400 ms the default (§8, decided); a longer promise for cells, so one per object type, is open (below) |
| `SAMPLE_RETRY` | object type | seconds a sampler waits for its first-phase standing request before the second phase asks another peer (§4.10) | `[D12]`, stated by its bound: longer than the honest path's latest sample, the custodians' tail plus a hop; 2 s in every measurement, LiteDAS suggests 4 s; a shorter wait is open (below) |
| `SAMPLE_RETRY2` | object type | the second phase's wait per peer (§4.10, LiteDAS) | `[D12]`, stated by its bound: at least a routed request's round trip (two hops out and back); 0.5 s in every measurement, no other value tried |
| `SAMPLE_OUTSTANDING` | node | the second phase's asks in flight per block, counted across the block's sampled types (§4.10, LiteDAS) | `[D12]`, stated by its bound: at least 1; 4 in every measurement, no other value tried |
| `SAMPLE_COVER` | object type | links serving each family that a node keeps for a type it samples, sampling-only links closing what its other links leave short (§1.3, §4.1) | `[D12]`; 2, decided, built for diversity (`COVER_HIGH`), and at least 1 (§1.3). One cover is an option |
| `COVER_HIGH` | object type | families a peer of high custody counts for in the coverage floor (§1.3, §4.1) | `[D12]`; 1, decided, as in the measurements |
| `ROUTE_FLOOR` | object type | links a node with duty `FORWARD` keeps to custodians at the routing neighbours' distances (§1.3) | `[D12]`; an option, off |
| `ROUTE_HOPS` | object type | forwarding steps a sampler's routed request may take (§4.10) | `[D12]`; 1, decided (FullDAS's two hops), and at least 1. More is an option where one step does not reach a custodian |
| `FORWARD_LIMIT` | object type | routed requests a node passes on per peer and slot (§4.5, §4.10) | `[D12]`; X6: a bound, each node's within it (`seacast-lite.md` §8.3's kinds), decided, stated: at least the routed requests that can reach the node over one link in the slot, summed over the blocks whose samples an asking peer may still be hunting: one per block under `ROUTE_HOPS` 1 and one sample per peer, since a sampler routes at most one request per first hop and block; more under `ROUTE_HOPS` above 1, since requests a sampler sends through different first hops can meet at one forwarder and leave over the same link. The count is per object type, as the parameter is, and bounds the requests newly passed on in a slot; the standing requests they leave stay across the reset until answered or dropped with the asker's state for their group (§4.5) |
| `EVIDENCE` | object type | the fraud-proof object, if any | `[D6]`: none in this version (decided); the hook stays |
| `ANSWERS_FIRST` | node | queued answers by rarity before pushes, after a source's own chunks (§4.12) | an option, off in every setting; a wash in three-seed toy checks |
| `SOURCE_OFFERS` | node | when a source offers each chunk to the peers of its pool (§4.7) it did not choose to push it to: `ACK`, at the chunk's acknowledgement; `PUBLISH`, at publish, its holding growing at each chunk's first write (§4.7) | a default, `ACK`, `seacast-lite.md` §5.1's rule; `PUBLISH` is the source's own choice: sooner for a fast source, later for a slow one, and it names the source (§4.7); decided |
| groups tracked per slot | node | state for groups we hold or peers want, beyond our interest | X6: a bound, each node's within it (`seacast-lite.md` §8.3's kinds), stated: at least the groups the chunks a node holds or rebuilds project onto (R4, §3), which for a row member or a reconstructor is up to every column of the block, for each block in its live window. The value is the client's; no limit in the measurements |
| `MAX_RELATIONS`, relations per link | object type, per link | pairs of family and colour a link may have at the node in any state: a relation, a GRAFT of the node's own not yet answered, a backoff not yet run out, a GRAFT or PRUNE of the node's own still owed; over it, a GRAFT for a new pair is ignored without an answer, a PRUNE for one sets no backoff, and the node's upkeep grafts none, without penalty (`relation_room`, §4.1) | X6: a bound, each node's within it (`seacast-lite.md` §8.3's kinds), stated: at least the families of the node's own interest times `M`, per object type, since an honest peer grafts a relation only for a family the other end's interest holds (`candidates`, §4.1). The value is the client's; no limit in the measurements |
| `MAX_INDICES` | object type | the most indices a group of the type has, which bounds a WANT's index before the group's count is known (§4.5) | a limit: the payload's `MAX_PLAIN_CHUNKS` (`seacast-lite.md` §8.3), a column's the most blobs a block commits, a row's `NUMBER_OF_COLUMNS` (128) |
| sampling-only links accepted | node | inbound links joined `(DECLARED, NONE)` that a node accepts (§1.3) | `[D12]`; X6: a bound, each node's within it (`seacast-lite.md` §8.3's kinds), stated: high enough that the network's samplers each keep `SAMPLE_COVER` links per family they sample. The value is the client's; no limit in the measurements, and the serving load not measured |
| `ASK_UPLINK` | node | the uplink at and above which `IWANT_WINDOW` keeps `seacast-lite.md`'s value; below it the window scales by `ASK_UPLINK / UPLINK` (§4.13); 50 Mbps | scaling by the asked peer's link is open (below) |
| `IWANT_WINDOW` | node | `seacast-lite.md` §8.3's 200 ms, scaled by `ask_scale()` (§4.13) | – |
| `MERGE_HOLDINGS` | node | a holding of a group the node publishes that is still in its queue takes the newer chunks instead of a second holding (§4.2; v0.4 §5.1 allows it) | permitted: a source may merge (local policy, as v0.4 words it); the toy keeps it off so that its recorded cells stay comparable |
| `HAVE_TTL`, `PUSH_TTL`, `GROUP_TTL`, `PARK_TTL`, offers, `GUARD_GRACE`, `RTT_REF`, `TARGET`, `WINDOW_TIMEOUT`, pace tick, `GOSSIP_RETRANSMISSION` | – | `seacast-lite.md` §8.3 unchanged | – |
| `MAX_IHAVE_MESSAGES`, `MAX_IHAVE_LENGTH` | node, per peer and heartbeat | gossipsub's two IHAVE limits on offers: offer-bearing frames, and asks in reply to them. Over either, asks wait for the next heartbeat (§4.3). The values are the client's (`seacast-lite.md` §8.2); on the gossipsub binding a stock gossipsub client sets 10 and 5000 (`seacast-bindings.md` §4) | `seacast-lite.md` §8.3's reference values are 4096 frames and 5000 ids per peer and heartbeat; this draft chooses no values of its own for its bindings. *Recommended* on the libp2p stream binding: not gossipsub's 10 (below) |

**Open, for later study:**
- *`M`:* the values 1 < M < N are open.
- *`R_NODE`, `R` for cells* (to be evaluated carefully): it is open whether cells keep the fast
  class's 6 or take `R` (2), which would make the budget per object type. Not yet evaluated are
  larger families (500 nodes and more), fast nodes other than supernodes, the payload's fast class
  in the same network, and the harness.
- *`PROMISE` for cells* (to be evaluated carefully): a longer promise for cells is open. Not yet
  evaluated are the longer promise for cells under withholding; more seeds and 500 nodes for cells;
  and what peer scoring reads from a broken promise.
- *`SAMPLE_RETRY`:* a shorter wait is open.
- *`ASK_UPLINK`:* it is open whether a node should scale by the asked peer's link where it knows it.
- *The IHAVE limits:* the trade of latency for copies against the other knobs that make it, the ask
  window (§4.13) first, is open. Not yet tested are 500 nodes, seeds other than 7 outside the rows
  setting, and a peer that floods offers.

#### Rationale

**When each was decided.** On 2026-11-01 the decisions were `REPAIR_SAMPLE` with its steps kept as
an option, `REBUILT_SEEN` only with it, and the alarm for networks without an honest supernode. On
2026-11-13 they were `M`, `DECODE_AT_K` and `DECODE_LATER`, `REPAIR_TO`, `REPAIR_BUDGET`,
`REPAIR_FLOOR`, `SOURCE_FLOOR`, `DEFER_WINDOW`, `EVIDENCE`, and the promise per peer. On 2026-11-14
they were `ANNOUNCE_EXTRA`, `START_DELAY`, and the bounds on groups tracked per slot, relations per
link and sampling-only links accepted. On 2026-11-18 the decision was `SOURCE_OFFERS`.

**`R_NODE`, `R` for cells, in the toy.** In the toy's 60-node cells so far, supernodes on datacenter
links, in the fast class, pushed mostly duplicates into columns of few custodians: more copies per
node in the honest custody and row cells, and a longer tail in the honest row cell. With cells at
`R`, the honest row cell's tail and copies are back near those without supernodes, the withheld
cells are as fast or faster at the tail for fewer copies, and the honest custody cell gives up a
few tens of ms at the median and at the tail for fewer copies (seacast-figures.md, §6.3).

**`PROMISE`, in the toy.** So far the toy shows this: in the honest row cell the 400 ms promise
broke thousands of times per run and parked hundreds of honest (peer, group) pairs. Nearly every
broken promise was a column ask that the asked node answered later, behind the rows' pulls on its
uplink, and none was a refusal. At 0.8 s it broke only a few times, with completion times moving
little and bytes unchanged, since the asker moves on after `IWANT_WINDOW` either way and the
promise decides only whom it parks. For the payload, the promise was evaluated with §4.13
(2026-10-19): a promise stretched with the ask window on thin links lets withholders go unparked
for the payload (with 30 % withholders at 10 Mbps it lengthened the tail in the research harness;
silent peers, who announce nothing and so are never asked, were not hurt in the toy), so the
payload's promise stays at 400 ms (seacast-figures.md, §6.3).

**`SAMPLE_RETRY`.** In the toy's 500-node cells the custodians' 99th percentile was well within
`SAMPLE_RETRY`'s wait. Under 30 % withholders the samplers' median follows that wait
(seacast-figures.md, §6.3).

**`SAMPLE_COVER`.** It is at least 1: without a floor some samplers of eight cells hold a sample no
link serves at 70 links, and nearly all do at 16 (§1.3). In the toy's 500-node cells, two covers
left no sampler short, honest or under 30 % withholders, at 70 links and at 16. One cover did as
well at 70; at 16 it left some samplers short under withholders, and it raised the honest samples'
99th percentile well above that with two covers. For the floor of the fewest links, with high
custody counted in full, in the toy's graphs (`toy/sampler_graph.py a`) one cover adds a few
links on top of 70 and more on top of 16, two covers add more again, and one link to a node
custodying every column covers all; where a tenth of the nodes custody 64 columns, the floor adds
none on top of 70 and few on top of 16. For the diversity floor, with covers counted by distinct
links (`toy/sampler_match.py`), nearly every draw of eight samples finds eight distinct serving
links with two covers, at 16 links and at 70; three covers do better still, and they are the floor
that holds for sixteen samples; one cover falls well short of that at 16 links, and a little short
at 70 (seacast-figures.md, §6.3).

**`COVER_HIGH`.** At 0, the share of draws that find distinct servers is nearly that at 1, with
eight samples and with sixteen, at a link more. With one supernode link counted in full and no
other rule, a draw rarely finds eight distinct servers at 16 links (seacast-figures.md, §6.3).

**`ROUTE_FLOOR`.** In the same graphs, without a per-column floor at 16 links: the hypercube rule
brings every (sampler, column) pair within two hops, and the Kademlia-style rule brings most pairs
within two and the rest in three, for fewer links added per custodian (seacast-figures.md,
§6.3).

**`ROUTE_HOPS` above 1** serves where one step does not reach a custodian, as for the pairs that the
Kademlia-style rule reaches only in three hops; in a 60-node cell one request that took a second
step brought its sample early, where with one step it had waited for the second phase
(seacast-figures.md, §6.3).

**`FORWARD_LIMIT`.** In the toy's 60-node cells (one seed, two covers, routed requests on), a limit
of 1 changed no event, honest or under 30 % withholders; with half the columns withheld it refused
a small share of the forwards, and the same samples arrived (seacast-figures.md, §6.3).

**Sampling-only links accepted.** On average the bound is the samplers' added links over the nodes
that serve them: in the toy's graphs, with a fifth of 500 nodes sampling, that comes to a few links
per other node, more at 16 links than at 70 (`SAMPLE_COVER`, above), and a limit at the average
would refuse some, as the draws are not even (seacast-figures.md, §6.3).

**`ASK_UPLINK`.** In the toy, in the research harness's setting, against `seacast-lite.md`'s fixed
window, the copies are fewer in every cell; the tail is a little shorter in the all-home network at
12.5 Mbps, with 30 % silent peers, and in the mixed-bandwidth network at 6 Mbps with a home builder
and with a datacenter builder, and about the same with 30 % withholders; with 10 % of chunks lost
it is a little longer (a lost answer is waited for until the longer window closes;
seacast-figures.md, §6.3).

**`MERGE_HOLDINGS`.** In the toy (§4.7), for a 50 Mbps proposer of 128 column groups, it takes back
a small part of what P4 costs at the custody block's median, with writes that complete at once and
with one write per connection at a time; the copies are unchanged (seacast-figures.md, §6.3).

**The IHAVE limits.** A low message limit trades latency for copies. Offers come chunk by chunk, so
it holds back many asks. An ask held back is likely often never made, because by the heartbeat the
chunk has come by push: that saves a duplicate pull (not counted). In the toy's `ihave-limits`
cell (60 nodes, one seed, under v0.9's rules; `toy/run.py --doc seacast --ihave-limits M,5000`),
against no limit, a limit of 10 frames costs the most time at the median for a small saving in
copies, 20 costs less time and saves the most, 40 costs and saves little, and 100 changes neither
(seacast-figures.md, §6.3). The 5000 asks never bound. On the libp2p stream binding, not
gossipsub's 10, since in that cell 20 saves more copies for less delay. On the gossipsub binding,
batching a peer's offers into fewer frames avoids the delay, and with it the saving. At
`seacast-lite.md` §8.3's reference values (4096 frames, 5000 ids, per peer and heartbeat), no ask was
held back in the toy's 60-node cells under the tier 4 setting, variant C and custody (with and
without samplers), nor under the rows setting (with and without half the columns withheld), and
each ran as with no limit; the busiest peer stayed well below both values (§4.3;
seacast-figures.md, §4.3). What the limits protect is mostly bounded already: one ask per index
at a time (`seacast-lite.md` §6.1), asks only for groups an installed block commits (§4.2), and the
offer table's limits (`seacast-lite.md` §8.2).

## 7. Bindings `[D1]`

The protocol is defined on its own messages (§2). A **binding** carries them between two nodes. The
bindings, their bytes and the rules that hold on one binding only are in
[`seacast-bindings.md`](seacast-bindings.md). It has four, one per carrier, and a fifth as
a draft:
- the libp2p stream binding carries them on a libp2p stream of its own
  (`seacast-bindings.md` §2);
- the Waggle binding carries the same protocol in Waggle's framing (`seacast-bindings.md` §3);
- the gossipsub binding uses `seacast-lite.md`'s wire (`seacast-bindings.md` §4);
- the partial-messages binding uses gossipsub with the Partial Messages Extension
  (`seacast-bindings.md` §5);
- the native QUIC binding, a draft, carries them directly on QUIC, with a stream per chunk
  (`seacast-bindings.md` §7).

A node may speak more than one binding, and negotiates per link which one a peer takes. This
section says what every binding provides, and what the rules do where a binding lacks a capability.

**What every binding provides:**
- *Links:* a binding gives a link per connected peer, with its open and its close, which start and
  end §3's per-connection lifetimes.
- *Whole messages:* a binding delivers each message whole, never a part of one. How a binding marks
  where each ends is its own: its frames.
- *The queue and the write:*
  - `send(p, msg, urgent)` puts a message into the per-peer queue (§3), or reports that a full queue
    refused it;
  - the writer chooses the next entry when it writes (§4.12);
  - a write completes as §4.11's "Below the writer" says.
- *Limits before state:* each message kind's size has a bound, checked before the receiver holds
  any state for the message (X6), after the binding's own bound on its frame.
- *The header:* a cell group's header travels in one of three forms, which the object type's
  definition fixes (`seacast-bindings.md` §1.6): (a) from the block, with none on the wire;
  (b) in every cell message; (c) in a header message of its own. In all three, a cell is verified
  only once its header is validated, and a cell that comes before its header waits for it (§4.2).
  A binding validates a block's cell header no later than it installs the block (§4.2). It
  validates a header a chunk carries apart from the chunk, before the chunk is handled. A copy whose
  id is already seen or waiting still brings its header (`on_header_validated`), and a header that
  fails never marks the chunk's id as seen, so an honest copy of the chunk is still taken.
- *The fork:* a link carries an object type only where both ends run it at the same fork, since a
  type's header and limits change at forks.
- *A chunk's id and size:* a binding gives `chunk_id(f)`, and `wire_size(p, entry)`, the bytes its
  write to `p` will take, a header included (§3).

**The order, on every binding but the native QUIC binding.** What a node writes to a peer arrives
in the order written, for each object type at least (Waggle's framing has a stream per type). The
native QUIC binding, a draft, does not order a chunk with any other message. Which rules rely on
that order is one of its open questions (`seacast-bindings.md` §7.9). The rule that the source
sends a holding just ahead of its first push (§4.7) relies on that order.

Rendezvous and discovery are outside the bindings (§0).

**The capabilities the bindings differ in**, and what the rules do without each, are these:

| capability | the libp2p stream and Waggle bindings | the partial-messages binding | the gossipsub binding | the native QUIC binding (a draft) | without it |
|---|---|---|---|---|---|
| interest without subscription: a JOIN per link, `DECLARED` interest told only to the peers asked (§1.2) | yes | for a sampler only | for a sampler only | yes | a sampler subscribes to nothing, its WANTs are its interest, and their answers are admitted by their WANT (`seacast-bindings.md` §6) |
| relations per family and colour, with a direction and a floor per colour (§1.3, §4.1) | yes | `BOTH` only, a colour field, no floor per colour | stock: `BOTH`, one colour | yes | the relation is the topic's mesh |
| the answered GRAFT, and `PRUNE_BACKOFF` this document's (§4.1) | yes | no: accepted in silence, gossipsub's backoff | no (the toy runs it under `--upkeep on`) | yes | a GRAFT's sender is in the relation from its GRAFT, and the ends' agreement rests on the backoff after a PRUNE (§4.1) |
| a holding's claims; the WANT's `standing`, `hops` and `probe` (§2) | yes | in extension fields | in version 4 of the strings (`seacast-bindings.md` §4), charged nothing in the toy | yes | – (every binding carries them) |
| EVIDENCE (§2) | its kind reserved | a full message on the rendezvous topic | reserved: a full message on the rendezvous topic | its kind reserved | none in this version (`[D6]`) |
| a frame of one message, or several (§4's `on_frame`) | one | several (gossipsub's frame) | several | one; a chunk's frame is its stream | the handling order of one frame is §4's; where a frame holds one message, the IHAVE limits (§4.3) count messages, and one answer per id per frame (§4.5) is one per message |
| merging queued entries (`merge_waiting`, §4.2, permitted; §4.1's one GRAFT or PRUNE of a relation per frame) | the client's | the client's | the client's | the client's | – (a choice, not a capability) |
| how a cell's header travels (§2), in the form the object type's definition fixes (`seacast-bindings.md` §1.6) | (a) no header in the cell; (b) with the first eager push of its group on a link; (c) a kind of its own, not defined in this version (`seacast-bindings.md` §2.3); the toy runs (b) | (b), by the partial columns' own rule, carried per link | (a) none; (b) in every copy of each cell's message; (c) a header message of its own on each family's topic, its bytes not defined in this version (`seacast-bindings.md` §4); the toy charges no header there, as in (a) | as on the libp2p stream binding; (c) on the control stream, before the group's first chunk stream (`seacast-bindings.md` §7.2) | – |
| an urgent lane at the transport, beside the writer's (§4.12) | for later study (a second stream) | no | no | yes, where the implementation orders streams (`seacast-bindings.md` §7.4) | the writer's urgent lane alone, as one stream per peer gives |
| scoring on these messages (P7) | yes | gossipsub's | gossipsub's | yes | gossipsub's scoring of its own messages |
| a chunk ordered with the messages written before and after it | yes (on Waggle, within its type) | yes, between frames | yes, between frames | no: each chunk has a stream of its own | *Open:* which rules rely on it (`seacast-bindings.md` §7.9) |
| a written chunk can be cancelled | no | no | no | yes, by a reset of its stream | cancel reaches only queued chunks (`[c8]`) |
| a chunk's lost bytes leave a gap only in that chunk's delivery | no: on the libp2p stream binding, every later frame on the stream waits; on Waggle over QUIC, the later messages of the chunk's type wait | no | no | yes: lost bytes leave a gap only on their own stream | lost bytes hold up every later frame on their stream until they are resent, and on TCP every later byte on the connection; on every binding, loss can also slow the connection's sending (congestion control) |

**Where the gains are.** The libp2p stream and Waggle bindings are where X2's gains are had:
interest without subscription, a push relation per family and colour with a floor and a direction,
and scoring on these messages. The partial-messages binding gives up the first two, but for a
sampler's interest, and keeps the rollout inside existing topics; it is the binding for columns
while the extension is the deployed path. A mixed network needs a bridge between a binding and the
stock path that does not double the bytes; it is outside this version (`[D1]`, §8).

**A fetch outside the links** `[D12]` (possible, binding-dependent). A binding may offer one
capability beyond its links: fetching a sample quickly from a node of the known node set that is
not a link. The sampler computes the custody of such a node from its node id.
- *What it gives:* it reaches a custodian directly where §4.10 would route. That is one hop instead
  of two, nothing disclosed to a forwarder, and fewer links kept for the coverage floor, which
  matters most where a node's connection budget is small (at 16 links the floor of the fewest links
  nearly doubles a node's links, §6.3; seacast-figures.md, §1.3).
- *What the protocol needs:* it needs only the notion of such a fetch, a WANT answered by a CHUNK
  from a node that is not a link, and its privacy rule: one sample per node, as on links (§4.10).
  The serving limit and the second phase's cap apply as on a link.
- *How it is carried* is the binding's (`seacast-bindings.md` §8), so the protocol's rules
  do not depend on it.

## 8. Decisions, and where they bite

The design decisions `[D1]` to `[D12]`, and the others this draft took, are recorded in
[`seacast-decisions.md`](seacast-decisions.md): for each, the rule decided and where it
bites here, when it was decided, what was not taken and why, and the runs behind it. The code's
comments cite the labels where each decision bites.

## Glossary

This glossary lists the document's own terms, each with the section that defines it. The terms it
uses as `seacast-lite.md` does, such as announcer, budget, card and tier, expired, last resort, park,
promise, stop-pull and tie, are in [`seacast-lite.md`](seacast-lite.md)'s glossary.

- **acknowledgement**: the holding a node sends the peer a chunk came from (§1.5, §4.2). It frees
  the room the copy took in the sender's window (§4.3, §4.11). At a source, a chunk is acknowledged
  at the first holding naming it from any peer, or else at the first window timeout of a copy of it
  (§4.7).
- **announce relation**: the peers a node tells what it holds: every peer that can push to it, every
  peer it pushes to, and beyond them a width that `ANNOUNCE_EXTRA` sets (§1.3, `[D5]`).
- **ask**: a request for one index of a group, keyed `Ask(g, i)` (`seacast-lite.md`'s `WantIndex`; §3)
  and carried in a WANT (§2). Asks on offers follow `seacast-lite.md` §6.1's pull discipline (§4.3).
- **ask window**: `seacast-lite.md`'s `IWANT_WINDOW`, how long one ask of a chunk counts as in flight;
  its retry comes `RETRY_SLACK` after the window. It stretches as the node's uplink falls below
  `ASK_UPLINK` (§4.13).
- **axis**: one of the groups a chunk lies in: a cell lies on its column and on its row (`project`,
  §1.1, R4). The rules that act per axis (`fill`, `forward`, an expired or dropped group) act on
  each of these groups apart (§3, §4.2).
- **backoff**: after a PRUNE it receives, the time during which a node does not graft that peer
  again for the relation the PRUNE named (`PRUNE_BACKOFF`, §4.1); none for a pair new to a link at
  its limit of relations (`MAX_RELATIONS`).
- **cell**: the chunk of the column and row types: one blob's 2 048 bytes at one column, with its
  proof (§1.1, `seacast-bindings.md` §1.2). In `seacast-figures.md`, a cell of the toy is
  also one run of one configuration (that file's preamble).
- **chunk**: one index of a group, with the proof that verifies it alone. A payload chunk fills one
  (group, index) pair, and a cell two, in its column and in its row (`project`, §1.1, R4).
- **claim**: either of the two flags a holding carries besides its bitmap (§1.5, `[D3]`).
  `claim_all`: the sender holds or can produce every index, `seacast-lite.md`'s decode claim, made at K
  before the decode. `complete`: the sender's interest in the group is satisfied. Both are
  unverified; a probe verifies a `claim_all` that defers a decode (§4.6).
- **claimant**: a peer whose `claim_all` for a group has arrived on a link that has joined the
  group's type (`claims`; on another link a claim is kept as a plain holding, §4.3). A claim can
  defer a decode duty the node has armed, at most once per group, and the node's probe then asks
  one connected claimant, drawn at random, for one index to verify it (§4.6, R5).
- **colour**: one of `M` values that partition a group's indices (`colour_of`, §1.4, `[D10]`). A
  chunk is pushed eagerly only on links whose push relation for its family holds its colour. A
  colour is not a subnet (§0).
- **completion**: the point at which a node's interest in a group is satisfied: K distinct chunks
  for interest `ALL`, every index of its column for a custodian, K cells for a row member, and its
  declared indices for a sampler (§1.5).
- **coverage floor**: at least `SAMPLE_COVER` links serving each family, which a node keeps for a
  type it samples; a peer of high custody counts for at most `COVER_HIGH` families (§1.3, §4.1,
  `[D12]`).
- **custodian**: a node whose interest in a column is derived from its node id and custody count;
  on the column it is `(DERIVED, FORWARD)` (§1.2).
- **deferral**: two things. A copy of a group whose gate has not opened is deferred: kept in a
  bounded per-peer store until the gate opens, or refused, and either way it ties its sender (§4.2).
  A peer's `claim_all` defers a node's armed later decode of the group once, by at least
  `DEFER_WINDOW`, while a probe verifies the claim (§4.6, R5).
- **duty**: what a node does for others, declared per link at JOIN. With `FORWARD` it holds push and
  announce relations and forwards what it receives into others' interest; with `NONE` it receives
  only (§1.2).
- **evidence**: an object a node can publish about a group it found inconsistent at level 2, where
  the object type defines one. This document carries it and does not define it, and no object type
  defines one in this version (§1.5, `[D6]`).
- **family**: the key on which relations are formed: one for the payload, the column index for a
  column, the row's subnet for a row (`family`, §1.1). It is not necessarily a custody group (§0).
- **floor**: the rule that a node keeps, per family it has duty in and per colour, at least `F_LO`
  and at most `F_HI` peers in its in-relation (§1.4, `[D10]`). `keep_floor` keeps the links it forms
  on (§4.1). The coverage floor, `REPAIR_FLOOR` and `SOURCE_FLOOR` are floors on links (§1.3, §4.6,
  §4.7).
- **forwarding node**: any node with duty `FORWARD` (§1.6). §4.4 says whom it pushes and offers a
  chunk to.
- **frame**: a binding's unit on the wire, which can carry several messages (§4,
  `seacast-bindings.md` §0).
- **gate**: the event after which a group's chunks can be verified and asked for: the installed
  block for the payload, a validated header for cells (`authenticable`, §4.2).
- **GRAFT**, **PRUNE**: the messages that form and end a relation for one family and colour, with a
  direction, `OUT`, `IN` or `BOTH` (§2). A GRAFT is answered, by a GRAFT marked as the yes
  (`answer`) or by a PRUNE, except on gossipsub's wires and for a pair new to a link at its limit
  of relations (`MAX_RELATIONS`); a PRUNE ends the relation at both ends (§4.1).
- **group**: one instance of an object type, such as one column of one block. Its id is computable
  before any chunk of it exists (§1.1).
- **HAVE**: the message that carries a bitmap of one group's chunks, as a holding or as an offer by
  its `offer` flag, with the two claims on a holding (§2).
- **header**: what the verifier needs for a group, arriving through the gate of its object type: the
  descriptor for the payload, the `PartialDataColumnHeader` for cells (`header_of`, §1.1). It is
  `seacast-lite.md`'s `desc`, read here as `hdr` (§0).
- **high custody**: a custody count above the base one, or interest `ALL` (§1.3). A peer of high
  custody counts for at most `COVER_HIGH` families in the coverage floor.
- **holding**: a HAVE saying that its sender holds these chunks, verified (`offer` unset), as
  `seacast-lite.md`'s IDONTWANT with a bitmap (§2). It goes to the suppression scope: it suppresses
  pushes, acknowledges the chunk just received, and counts its sender as a holder (§1.5, §4.3).
- **interest**: what a node is to receive of a group, declared per link and object type at JOIN, in
  three kinds: `ALL`, the whole object; `DERIVED`, computed by both ends from the node id and
  custody count; `DECLARED`, told per group and per peer in a WANT (§1.2).
- **JOIN**: the message each end of a connection sends once per object type, with its interest,
  custody count, duty and number of colours (§2, `[D11]`). On gossipsub's wires it is a subscription
  (§4.1).
- **K, N**: per object type, the chunks from which the whole object follows (`threshold`) and the
  indices of a group (`index_count`). A column has no code, so its K is its N (§1.1).
- **level 1, level 2**: per object type, the check of one chunk alone (`verify`) and the check of a
  set's consistency, by decoding, re-encoding and comparing (`decode`) (§1.1). Level 3 is the
  application (§5).
- **link**: a connection on which both ends have exchanged a JOIN for an object type (§1.3). A node
  counts a peer as a link once the peer's JOIN has arrived and its own is queued (`links`, §3).
- **object type** (`T`): the consensus side's contribution: an index space, how one chunk is
  verified alone, how a set is checked and rebuilt, how a receiver learns the header, and how a
  chunk maps onto groups (§1.1). §1.1's table gives the payload, the column and the row.
- **offer**: a HAVE saying that its sender can be asked for these chunks (`offer` set), as
  `seacast-lite.md`'s IHAVE with a bitmap (§2). It goes to a peer the sender chose not to push a chunk
  to, or to a peer outside the relation, and feeds that peer's offer table and nothing else (§1.5,
  §4.3).
- **owed**: as in `seacast-lite.md`, and also a JOIN, GRAFT or PRUNE that a full queue refused, queued
  in order once there is room (§4.1), and a push to a fallback link that a full queue refused
  (§4.7).
- **phase**: two different things. A sampler's first phase declares every sample at once and waits
  `SAMPLE_RETRY`; its second declares each sample still missing to another peer (§4.10, `[D12]`).
  EIP-8371's three phases rebuild a row: a row reconstructor at K, then, if the row is still short,
  a supernode, and later any member of its subnet (§4.6, `[D4]`).
- **probe**: the one ask that verifies a peer's `claim_all`, of one claimant for one index the asker
  lacks, both drawn at random. The WANT's `probe` field marks it, and the claimant answers it
  whatever the asker's holdings say, once per asker and group (§2, §4.6, R5).
- **pull-only type**: an object type whose chunks are not pushed, only told in holdings and offers,
  at the source too (`EAGER` off): the rows (§1.1, §4.7).
- **push relation**: per link, object type and family, the colours for which a node pushes chunks
  to the peer (`push_out`) and those for which the peer pushes to it (`push_in`). GRAFT and PRUNE
  negotiate it with a direction, so it is not necessarily symmetric (§1.3, §4.1).
- **reconstructor**: a node whose repair rule says it decodes a group or a block that it does not
  need whole for itself (§1.6, §4.6).
- **relation**: either of the two a node keeps per link, object type and family: the push relation
  and the announce relation (§1.3).
- **rendezvous**: where a node finds peers that share an object type and a family: gossipsub topics
  where they exist, the ENR's `cgc` and node ids. It is assumed, not defined here (§0, `[D11]`).
- **repair**: sending the chunks a node rebuilt to the peers that `REPAIR_TO` names, group by group,
  into every group each chunk fills (§4.6, `[D4]`).
- **routed sample request**: a sampler's WANT with `hops` above zero, sent where no link serves the
  sample to a link with duty `FORWARD`. Each node on the way answers from what it holds and passes
  it one step on, and the cell comes back the way the request went (§4.5, §4.10, `[D12]`).
- **routing neighbours**: an option of the rendezvous: for each node with duty `FORWARD`,
  `ROUTE_FLOOR` links to custodians of families at structured distances from its own, toward which
  a routed request steps (§1.3, `[D12]`).
- **row member**: a node that takes part in a row's family: the row of its own subnet
  (`wants_family`, §4.6). It completes at K cells (§1.5).
- **sampler**: a node's role on a link joined with interest `DECLARED` and duty `NONE`; the same
  node can be a custodian on other links. It declares each sample to one peer, and asks each peer
  for at most one sample of a block (§1.2, §4.10).
- **sampling-only link**: a link opened where a node's other links leave its coverage floor short,
  joined as `(DECLARED, NONE)`; it carries no relation, no push and no offer (§1.3).
- **serving**: answering an ask from what a node holds, received or rebuilt, within `SERVE_LIMIT`
  chunks per peer and group (§4.5, R6). It does not depend on duty (§1.2).
- **source**: any node that holds chunks of a group before its peers do, such as the builder, or a
  node that built columns from its mempool. The role is read from holdings, not announced (§1.6,
  X8). §4.7 gives its rules.
- **source pool**: the peers a source offers a chunk to and, below `STRIPE_UPLINK`, pushes it to:
  its push relation for the chunk's colour or, with none for that colour in the family, the links
  whose interest holds the chunk, its fallback links (`source_pool`, §4.7).
- **standing request**: a WANT that the peer answers from what it holds and, for the rest, when the
  chunks arrive, within the group's lifetime (`standing`; §2, §4.5). A sampler's WANT on a
  `DECLARED` link is always one (§2).
- **subnet's view**: what a row member holds of a row, together with what the holdings of its
  relation peers show; no claim counts in it (`known_in_scope`, §4.6).
- **supernode**: a custodian of every column. It keeps every row with interest `ALL` declared on no
  link, and rebuilds a row still short at EIP-8371's second phase (§1.2, §4.6).
- **suppression scope**: the peers that can push a group to a node; its holdings go to them (§1.3,
  §1.5).
- **WANT**: the message that asks one peer for chunks of a group, by bitmap: what the sender asks
  that peer for, not what it lacks (§2, `[D2]`). Its fields make it a standing request, a routed
  sample request or a probe.
- **window**: `seacast-lite.md` §7.1's sending window, one per node over every group of every object
  type, counted in bytes (`W_BYTES`): a chunk takes its size on the wire (`wire_size`), and control
  takes none (§4.8, §4.11, X3). The ask window is another (§4.13).

**Requirement labels.** The draft was written against a list of requirements; the labels it cites
are these ([P4] is v0.4's tag, its §5.1: the source's holding names only the chunks it has sent;
since v0.9, it names only the chunks acknowledged so far, §4.7).

| label | requirement |
|---|---|
| I3 | pushes, announcements and gossip go into interest only |
| I6 | a sample is disclosed only to the peers asked for it |
| I7 | level 1 verifies a chunk alone, level 2 checks the consistency of a set; both per object type |
| I8 | a node may hold chunks it did not receive through the protocol |
| P2 | a chunk is held until its header is validated, and the header travels once |
| P7 | scoring reads interest |
| R2 | a row member's interest is K of 128 cells, a decoder's is all |
| R3 | reconstruction duty is designated and phased |
| R4 | a chunk may belong to two groups, and a verified cell fills both |
| R5 | a claim defers others' reconstruction, and silence after it re-arms them |
| R6 | what a peer may pull is bounded by what it may want |
| R7 | rows must not cost the column path traffic |
| X2 | the protocol is its own, where that gains over an extension of gossipsub |
| X3 | one window and one duty rule over every group |
| X6 | limits before state, for every object type |
| X8 | the source is a role, not a node |

**Decision labels.** Each label names one of the design decisions that
[`seacast-decisions.md`](seacast-decisions.md) records (§8):
- `[D1]` identity and bindings
- `[D2]` two bitmaps, WANT per recipient, no need bitmap
- `[D3]` two claims
- `[D4]` repair's parameters
- `[D5]` the announce relation's width
- `[D6]` the payload's consistency route
- `[D7]` groups per column and per row, cross-fill
- `[D8]` the row pull delay
- `[D9]` one document or a sibling
- `[D10]` colours
- `[D11]` join = (interest, duty); topics as rendezvous
- `[D12]` a sampler's reach
