# SEACAST's next version (draft): its bindings

> **DRAFT.** This document is a companion of [`protocol-v2.md`](protocol-v2.md), released with it.
> SEACAST's message encoding and the libp2p stream and Waggle bindings are defined to the byte
> (§1 to §3); the two bindings onto gossipsub's wires are defined to the field (§4, §5), and the
> gossipsub binding's extra fields are defined to the byte. The draft is checked in the toy only:
> no client speaks these bytes yet.

*This document was written on 2026-11-17 from `protocol-v2.md` §7 of that date, which it takes
over whole, and from the bytes of SEACAST's message encoding and of the libp2p stream and Waggle
bindings, decided the same day. `protocol-v2.md` §7 now says what every binding provides and which
capabilities the bindings differ in.*

## 0. How to read this

`protocol-v2.md` defines the protocol on its own messages (its §2) and what any binding must provide
(its §7). This document defines the bindings:
- it says how each binding carries the messages;
- it gives the rules that hold on one binding only;
- it defines SEACAST's message encoding, and the bytes of the libp2p stream and Waggle bindings.

§1 defines SEACAST's message encoding once. The four bindings follow, one section per carrier:
1. **the libp2p stream binding** (§2) is a protocol of its own, on a libp2p stream of its own;
2. **the Waggle binding** (§3) carries the same protocol in Waggle's framing;
3. **the gossipsub binding** (§4) is `protocol.md`'s wire, which the toy runs;
4. **the partial-messages binding** (§5) is gossipsub with the Partial Messages Extension.

A native QUIC binding is being drafted.

§6 has the rules on both of gossipsub's wires, and §7 has the transports of a fetch outside the
links. A node may speak more than one binding, and negotiates per link which one a peer takes.

**Terms.**
- A **message** is one of `protocol-v2.md` §2's.
- A **frame** is the unit a binding writes on the wire, and what it is depends on the binding:
  - on the libp2p stream binding, it is a length prefix and one encoded message (§1.1, §2.2);
  - in Waggle's framing, it is one `ObjectPieces`, which Waggle length-prefixes itself (§3);
  - on gossipsub's wires, it is gossipsub's protobuf `RPC`, which can carry several messages.

  It is not a frame of the layers below (QUIC's, or a stream multiplexer's), which carry these
  frames as bytes. `protocol-v2.md`'s rules speak of messages; its §7 names frames only to say that
  each binding's are its own.

**What is normative:**
- §1 to §3, SEACAST's message encoding and the libp2p stream and Waggle bindings, are normative to
  the byte;
- §4 and §5, the bindings onto gossipsub's wires, are normative to the field, and the gossipsub
  binding's extra fields are normative to the byte;
- §6, the rules on gossipsub's wires, is normative.

The sizes in §1.5 are informative.

**At a glance**, the table below shows the bindings message by message (`M`: `protocol-v2.md` §1.4):

| message | the libp2p stream and Waggle bindings (§1 to §3) | the gossipsub binding (§4) | the partial-messages binding (§5) |
|---|---|---|---|
| JOIN | kind `0x01`, the first message per object type on a link | subscription; a sampler's is none (§6) | `SubOpts(topic, requestsPartial, supportsSendingPartial)` plus an extension field for duty and `M`; a sampler's `(DECLARED, NONE)` is no subscription (§6) |
| GRAFT, PRUNE with colour and direction | kinds `0x02`, `0x03`: an accepted GRAFT is answered by one marked `answer`, and a GRAFT for a relation the receiver holds by a yes again; `PRUNE_BACKOFF` `protocol-v2.md`'s (§4.1 there) | stock, accepted in silence as on the partial-messages binding; under `--upkeep on` the toy runs `protocol-v2.md` §4.1's answered exchange instead, `answer` carried beside the GRAFT, with `PRUNE_BACKOFF` from `--prune-backoff` | gossipsub's GRAFT/PRUNE with an extension field for the colour; direction `BOTH` only; no floor per colour; accepted in silence, as gossipsub's: the sender is in the relation from its GRAFT, and the backoff after a PRUNE keeps the ends together (`protocol-v2.md` §4.1) |
| HAVE, holding | kind `0x04`, flag bit 0 clear | IDONTWANT `HaveBitmap`; `claim_all` and `complete` read from a full bitmap, or carried in a flags byte after the group, under version 4 of the strings (§4; needed for a row member complete at 64; the toy charges no bytes for them) | `partsMetadata.available` plus two flag bits |
| HAVE, offer | kind `0x04`, flag bit 0 set | IHAVE `HaveBitmap` | `partsMetadata.available` to a peer not being pushed |
| WANT | kind `0x05`: `standing` and `probe` in one flags byte, `hops` a byte | IWANT `WantIndex`; `standing` and `probe` in a flags byte after the index, and `hops` a byte, under version 4 of the strings: 43 bytes in all (§4; the toy charges no bytes for them) | `partsMetadata.requests`; `standing`, `hops` and `probe` need an extension field, which also asks for the part where the asker has not subscribed (§6) |
| CHUNK | kind `0x06` for the payload, `0x07` for a cell | a gossipsub message per chunk | `partialMessage` |
| EVIDENCE | kind `0x08`, reserved: none in this version (`[D6]`) | a full message on the rendezvous topic, reserved: none in this version (`[D6]`) | a full message on the rendezvous topic |
| rendezvous | gossipsub topics per family, with the ENR beside them `[D11]` | the topic | the topics |

## 1. SEACAST's message encoding

### 1.1 The encoded message

An **encoded message** is `kind || body`: one byte naming the message's kind, then the message's
SSZ, compressed for the two chunk kinds (§1.3). The same encoded message travels on the stream
(§2.2), in Waggle's framing (§3) and in a fetch outside the links (§7).

| kind | message | body (§1.2) |
|---|---|---|
| `0x01` | JOIN | `JoinMsg` |
| `0x02` | GRAFT | `GraftMsg` |
| `0x03` | PRUNE | `PruneMsg` |
| `0x04` | HAVE, a holding or an offer | `HaveMsg` |
| `0x05` | WANT | `WantMsg` |
| `0x06` | CHUNK of the payload | `protocol.md` §2's `Chunk`, compressed |
| `0x07` | CHUNK of a cell, in a column or a row | `CellChunk`, compressed |
| `0x08` | EVIDENCE | reserved: none in this version (`[D6]`) |

- **Unknown kinds.** A message of an unknown kind is skipped without penalty, so that a later
  version can add kinds. Its frame is held to the largest frame that a known kind allows (§1.4): a
  longer one is a violation.
- **Types not joined.** A message naming an object type the link has not joined is ignored without
  penalty (`protocol-v2.md` §2).
- **Violations.** A body that does not decode, or one over its kind's bound (§1.4), is a violation:
  it is penalised, and the stream is closed.

### 1.2 The types

```python
TypeId = uint8                         # the payload 0, columns 1, rows 2; a new object type takes the next value
FamilyId = uint16                      # the payload 0; a column's index; a row's subnet
Direction = uint8                      # OUT 0, IN 1, BOTH 2
InterestKind = uint8                   # ALL 0, DERIVED 1, DECLARED 2
Duty = uint8                           # NONE 0, FORWARD 1
MAX_HAVE_BYTES = 1024                  # protocol.md §2's: 8 192 indices
Bitmap = ByteList[MAX_HAVE_BYTES]      # protocol.md §2's: index i is bit i % 8 of byte i // 8, least significant
                                       #   bit first; trailing zero bytes dropped

class GroupId(Container):              # one layout for every object type: 35 bytes
    type: TypeId
    key: Bytes32                       # the payload: its group key (protocol.md §1); a column or a row: the block root
    index: uint16                      # the payload: 0; a column: its index; a row: its index (the blob's)

class JoinMsg(Container):              # 0x01
    object_type: TypeId
    fork_digest: ForkDigest            # the fork at which the sender runs the type
    interest: InterestKind
    custody_count: uint64
    duty: Duty
    colours: uint16

class GraftMsg(Container):             # 0x02
    object_type: TypeId
    family: FamilyId
    colour: uint16
    direction: Direction
    answer: boolean

class PruneMsg(Container):             # 0x03
    object_type: TypeId
    family: FamilyId
    colour: uint16
    direction: Direction

class HaveMsg(Container):              # 0x04
    group: GroupId
    flags: Bitvector[8]                # bit 0 offer, bit 1 claim_all, bit 2 complete
    bits: Bitmap

class WantMsg(Container):              # 0x05
    group: GroupId
    flags: Bitvector[8]                # bit 0 standing, bit 1 probe
    hops: uint8
    bits: Bitmap

class CellChunk(Container):            # 0x07
    group: GroupId                     # the column or the row it is sent in
    index: uint32                      # the row in a column, the column in a row
    cell: ByteVector[BYTES_PER_CELL]   # 2 048 bytes
    proof: KZGProof
    header: List[PartialDataColumnHeader, 1]   # with the first eager push of a group on a link (P2)
```

- **The flags.** A flags byte's other bits are zero when sent and ignored when received, so that a
  later flag fits without breaking older readers.
- **The enums.** For `Direction`, `InterestKind` or `Duty`, a value outside that type's list is a
  violation. A `TypeId` a node does not know names a type the link has not joined, and is ignored
  (§1.1).
- **The payload's chunk (`0x06`)** is `protocol.md` §2's `Chunk`, unchanged: its proof is a
  `List[Bytes32, 14]`, and its header is the descriptor it carries under design A; under design B
  the bid carries the descriptor and the chunk does not, a choice `protocol.md` §1 leaves open. It
  is the same bytes in SEACAST's message encoding as on the gossipsub binding, compression aside,
  and its group is `GroupId(0, chunk.group, 0)`.
- **The consensus types:** `ForkDigest`, `KZGProof`, `BYTES_PER_CELL` and `PartialDataColumnHeader`
  are consensus-specs' (the header from Fulu's partial columns, `specs/fulu/partial-columns/
  p2p-interface.md`, at `2ea9d96a`). The header is optional as partial columns make it optional: a
  list of zero or one.
- **The fork** (`protocol-v2.md` §7). A link carries an object type only where both ends' JOINs
  for it name the same `fork_digest`, as their `colours` must match. At a fork a node sends its new
  JOIN.
  - *Open:* this draft leaves open what a link's relations do from the fork until both ends' JOINs
    name the new digest. Also open is how the new JOIN sits with the rule that a node sends its JOIN
    once per link and type, through `send_join` (`protocol-v2.md` §4.1).
- **The header** (`CellChunk.header`), in form (b) (§1.6), goes with the first eager push of a group
  on a link (`protocol-v2.md` §2). It is validated apart from the cell, before the cell is handled
  (`protocol-v2.md` §7): a copy whose id is seen or waiting still brings it. A header that fails its
  checks is rejected, as consensus rejects one, and counts against its sender; one that cannot be
  judged yet, which consensus ignores (a slot ahead, a parent not yet seen), waits and counts
  against no one. Neither marks the cell's id.
  - *An answer carries none:* the asker held the header to ask, as consensus's partial columns also
    reason.
  - *A node that was pushed nothing of a group,* a sampler on its sampling-only links for one, takes
    the header from the block (`on_header_validated`).
  - *Consensus's partial columns also skip it* for a peer that has sent a message of the block, or
    that was sent the header on another topic. Sending it once per block and link, not per group, is
    for later study.
- **A bitmap's length** is the sender's, up to the bound. Bits past the group's count, once known,
  are the violation `protocol-v2.md` makes them (`valid_have`, `drop_beyond`).
- **A chunk's id** (`chunk_id`, `protocol-v2.md` §3) takes the part of `protocol.md` §2's structured
  id, which hashes a topic in, on a binding that has no topics. It is 59 bytes:
  - *the payload's chunk:* the id is the chunk's `GroupId`, its index as a little-endian `uint32`,
    and the first 20 bytes of SHA-256 over the decompressed body;
  - *a cell:* a cell has one id whichever group carries it, so that a copy through the other axis,
    or one with a header, is the same chunk to `seen`. The id is the `GroupId` of its column, its
    row as the index, and the first 20 bytes of SHA-256 over the cell and its proof.
- **A chunk's size** (`wire_size(p, entry)`, `protocol-v2.md` §3) is the size of its frame on the
  stream (§2.2), with the header when its write carries one, so that the window counts what the
  link carries.

### 1.3 Compression

- **The two chunk kinds** (`0x06`, `0x07`) carry their SSZ compressed with snappy's block format, as
  gossip carries chunks and data columns. A partly filled blob's cells are mostly zeros.
- **The decompressed length,** which a snappy block states first, is checked against the kind's
  bound (§1.4) before decompressing.
- **The other kinds** carry their SSZ as it is: a few dozen bytes, mostly a key and a bitmap, which
  snappy would lengthen.

### 1.4 Limits

Each kind has a bound on its body, from its types' static sizes (X6, limits before state):

| kind | the body's bound, uncompressed |
|---|---|
| JOIN, GRAFT, PRUNE | 17, 7, 6 (fixed) |
| HAVE, WANT | 1 064, 1 065 (a full bitmap) |
| CHUNK of the payload | 33 351 under design A (`MAX_SEGMENT_SIZE`, 14 proof steps, the descriptor's 51 bytes); 33 300 under design B, without the descriptor (`protocol.md` §1, open) |
| CHUNK of a cell | 199 091 (the header with `MAX_BLOB_COMMITMENTS_PER_BLOCK` commitments) |

- **On the stream,** a receiver reads a frame's length and kind, and refuses a frame that cannot fit
  its kind's bound before reading the body. A frame of an unknown kind is held to the largest frame
  that a known kind allows. For a chunk kind the frame may be the bound's snappy worst case,
  `32 + n + n / 6`. Its decompressed length is checked against the bound itself.
- **The epoch's own bound** on a cell's header, its `max_blobs_per_block` commitments, is checked at
  level 1, where consensus checks it.
- **`protocol-v2.md` §6.3's limits on state stay as they are:** they limit the groups tracked per
  slot, the relations per link, and the sampling-only links accepted.

### 1.5 Sizes (informative)

A message's size on the stream counts its body, then its kind byte and its length prefix.

| message | body | on the stream |
|---|---|---|
| JOIN | type 1, fork digest 4, interest 1, custody count 8, duty 1, colours 2 | 19 |
| GRAFT | type 1, family 2, colour 2, direction 1, answer 1 | 9 |
| PRUNE | type 1, family 2, colour 2, direction 1 | 8 |
| HAVE, holding or offer | group 35, flags 1, offset 4, bitmap b | 42 + b; 43 + b from b = 87 |
| WANT, one index i | group 35, flags 1, hops 1, offset 4, bitmap ⌊i/8⌋ + 1 | 44 + ⌊i/8⌋; 45 + ⌊i/8⌋ from i = 680 |
| CHUNK, a cell | group 35, index 4, cell 2 048, proof 48, offset 4; header (if sent) 4 + 340 + 48 a blob | 2 142; with a 48-blob header, 4 790 |
| CHUNK, the payload | `protocol.md`'s `Chunk`: 135 under design A (the descriptor's 51 bytes in it), 84 under design B, + 32 a proof step + data | 138 or 139 under design A, 86 to 88 under design B, + 32 a proof step + data |

The table gives a chunk's size before compression.

### 1.6 A cell group's header: three forms

A cell group's header travels in one of three forms. The object type's definition fixes the form
(`header_of`, `protocol-v2.md` §1.1), and no topic mixes two forms. The three forms are the same on
the libp2p stream binding and the gossipsub binding, and each binding says how it carries them
(§2.3, §3, §4, §5).
- **(a) From the block.** No header travels on the wire. A cell waits in `defer` until its block's
  header is validated (`on_header_validated`, `protocol-v2.md` §4.2).
- **(b) In every cell message.** Each cell's message carries the header. A binding that can vary a
  message per link carries it more cheaply, as the libp2p stream binding does once per group and
  link (§2.3): a cell's id leaves the header out (§1.2), so a copy with the header and a copy
  without it are the same chunk.
- **(c) In a header message of its own,** one message per group or one per block carries the
  header. This form needs the header message's own bound (§1.4), deduplication, cells held while
  their header is in flight, and a guard against headers with no cells after them. This version
  defines no bytes for the header message.

In the toy a cell's header is available from its first cell on both wires (`protocol-v2.md` §4.2),
so no cell waits for its block. The libp2p stream binding's wire charges the header on the first
eager push of each group and link, form (b). The gossipsub binding's wire charges no header: that is
form (a) for a node that holds the block before the cells, and the toy does not model a block that
comes after its cells.

**Open: a cell before its block, under form (a).** A cell's message names its group (the block root
and the column or the row, §1.2) but not its slot, and under form (a) no header comes with it.
`protocol-v2.md` §4.2's `on_chunk` checks the slot's live window before the cell can wait in
`defer`, and `tie` keeps the slot too. How a receiver admits, bounds and expires a cell whose slot
it does not know yet, or whether the cell's message names its slot under form (a), is for a later
release.

## 2. The libp2p stream binding

This binding is a protocol of its own, carrying `protocol-v2.md` §2's messages with every rule of
that document: interest without subscription, a push relation per family and colour with a floor
and a direction, the answered GRAFT, and scoring on these messages (`protocol-v2.md` §7's
capabilities, all of them).

### 2.1 The protocol id and the streams

- **The protocol id is `/seacast/2.0.0`.** An incompatible change of these bytes or of the rules
  moves the major version. A compatible addition moves the minor, such as a kind that older readers
  skip (§1.1). A node negotiates per link which binding, and which version, a peer takes.
- **One outbound stream per peer.** Each node opens one stream to each peer with the protocol id,
  and writes its frames there. It reads the peer's frames on the stream the peer opened.
- **The writer's order.** Frames go in the order the writer chooses them (`protocol-v2.md` §4.12),
  each written whole.
- **For later study:** a second outbound stream would carry frames without a chunk, so that a
  holding need not wait behind a chunk being written to the same peer (the urgent lane at the
  transport). The toy does not model it. A node would then read both of a peer's streams alike.

### 2.2 The stream's frames

On this binding's stream, a frame is one encoded message after its length:

    frame := uvarint(len(kind || body)) || kind || body

- The length is libp2p's unsigned varint.
- The length takes at most 3 bytes for every frame §1.4 allows.

### 2.3 A cell group's header

This binding carries the three forms of §1.6 as follows:
- **(a)** no cell carries the header: `CellChunk.header` is empty;
- **(b)** `CellChunk.header` goes with the first eager push of a group on a link (§1.2);
- **(c)** the header message needs a kind of its own, which this version does not define.

## 3. The Waggle binding

Waggle, libp2p's working draft of a pubsub protocol for incrementally reconstructed objects
(`/waggle/1.0`), is a transport:
- it uses one stream per topic to each connected peer;
- it has one message type, `ObjectPieces{objectID, piecesMetadata, pieces}`, whose fields are
  opaque;
- it has no mesh and no scoring.

The Waggle binding carries SEACAST's message encoding in it with every rule of the libp2p stream
binding, as on a stream of its own; only the framing changes.

- **Topics are per object type, never per family.** A Waggle subscription is a stream to the node's
  connected peers, one per topic. With a topic per family, a sampler would subscribe to the families
  it samples and disclose them to every peer (I6). A topic per type says only that the node takes
  part in the type. What it receives is said per link, in its JOIN and its WANTs, and the group
  tells one family's chunks from another's.
- **JOIN** is the first message the node sends that peer on the type's topic. Waggle sends to a peer
  only on the stream of its subscription, so a link forms once both ends have subscribed and each
  has sent its JOIN.
- **Every message is one `ObjectPieces`, carrying one encoded message (§1.1):**
  - `objectID` is the 35 bytes of the `GroupId`, or, for JOIN, GRAFT and PRUNE, which name no
    group, the one byte `0x00`;
  - `piecesMetadata` is the encoded message for every message but a chunk; for a chunk, it is the
    chunk's kind byte alone;
  - `pieces` is a chunk's body, compressed as on the stream; it is empty otherwise.

  Waggle length-prefixes each `ObjectPieces` itself, so the encoded message carries no length. The
  bounds of §1.4 are checked once Waggle has read the `ObjectPieces`.
- **A cell group's header** (§1.6) travels as on the libp2p stream binding (§2.3):
  `CellChunk.header` is empty under form (a) and carries the header under form (b), and form (c)
  needs a message of its own, which this version does not define.
- **Whom a node pushes, tells and asks is `protocol-v2.md` §4's.** SEACAST's rules take the place of
  the draft's dissemination prose (a new piece to the peers whose metadata shows it missing,
  metadata to some others), which lets the application choose the peers ("latency or other
  application-defined criteria").
- **The urgent lane at the transport.** Where the framing keeps the messages without pieces on a
  stream of their own (a second stream, or a second topic per type), a holding, a claim or an
  acknowledgement no longer waits behind a chunk being written to the same peer. One stream per
  peer, as gossipsub has, cannot give this.
- **What it does not give:**
  - Waggle gives no scoring, which the draft leaves to the application and this binding has on its
    own messages (P7);
  - Waggle does not give the fetch outside the links, whose transports are §7's.

Waggle's `ObjectPieces` has the shape of the partial-messages binding's partial message: a group id,
the parts' metadata and the parts. So a client can move between the two by changing mostly where
the topic lives.

## 4. The gossipsub binding

This binding is `protocol.md`'s wire (its §2): chunks travel as gossipsub messages, and holdings,
offers and asks travel as message-id strings inside existing control fields. Nothing here adds a
protobuf field or a gossipsub message type. The toy runs `protocol-v2.md` on it.

- **What it gives up** (`protocol-v2.md` §7's capabilities) is the same as on the partial-messages
  binding (§5).
- **The two ends of a relation** agree through gossipsub's backoff, as on the partial-messages
  binding (§5).
- **The fork** is in the topic's name.
- **A chunk's id** is `protocol.md` §2's structured `message_id`.
- **A cell group's header** (§1.6). A router forwards a message as it was published, to every peer
  alike, so a header cannot go to one link and not another:
  - in form (a), no cell's message carries it;
  - in form (b), every copy of each cell's message carries it;
  - in form (c), the source publishes a header message of its own on each family's topic with the
    group's first cells, and it is forwarded as any message. This version defines no bytes for it.
- **An IDONTWANT's entries** are read as `protocol.md` §4.1 reads them. An IDONTWANT names no
  topic, so beside the `HaveBitmap`s its entries can be stock message ids, such as another topic's.
  An entry is a holding (`protocol-v2.md` §4.3's `on_holding`) if it opens with `HaveBitmap`'s
  MAGIC and a version this binding writes, and holds after them a group and, at version 4, the
  claims' flags byte with no reserved bit set. The versions this binding writes are version 1 of
  `protocol.md` §2, which its `is_have_bitmap` tests, and version 4, below. Any other entry, one
  cut short included, is an opaque id, kept in `unwanted[p]` with stock gossipsub's admission and
  lifetime, where `on_want` reads it (`protocol-v2.md` §4.5); it is not read as a holding. Both are
  handled after the frame's asks, as `protocol-v2.md` §4's `on_frame` handles holdings.
- **An IHAVE's entries** are offers only as `HaveBitmap`s. Any other entry is ignored, without
  penalty, where `protocol.md` §4.4 reads it as a structured id: this draft offers by bitmap only.
- **The extra fields** are carried in version 4 of the strings: a holding's `claim_all` and
  `complete`, and the WANT's `standing`, `hops` and `probe`. The toy charges no bytes for them.
  - *A holding* travels in an IDONTWANT as `"HAVE"` ‖ `0x04` ‖ the group (32) ‖ flags (1: bit 0
    `claim_all`, bit 1 `complete`) ‖ the bitmap. The bitmap is `protocol.md` §2's: least significant
    bit first, trailing zero bytes dropped, at most `MAX_HAVE_BYTES`.
  - *A WANT* travels in an IWANT as `"WANT"` ‖ `0x04` ‖ the group (32) ‖ the index (4) ‖ flags (1:
    bit 0 `standing`, bit 1 `probe`) ‖ `hops` (1): 43 bytes. The index is a little-endian `uint32`,
    as `protocol.md` §2 states for `WantIndex`. The research harness writes it big-endian, a
    difference of that implementation.
  - *An offer* keeps version 1, which has no flags.
  - *The group* is 32 bytes: `protocol.md` §2's group key, which is the whole id of a payload group.
    A column's or a row's `GroupId` also has a type and an index (§1.2), and an IDONTWANT or an
    IWANT names no topic, so how these strings name such a group is left open (below).
  - *An entry with a reserved bit set,* a WANT of the wrong length, or a WANT whose `hops` is over
    its type's `ROUTE_HOPS` (`protocol-v2.md` §6.3) is ignored without penalty. For an IDONTWANT
    entry, ignored means not read as a holding: the entry stays an opaque id, as above.
- **Open: the strings for cell groups, and the versions written.** Five points are left for a later
  release:
  - the 32 bytes that name a column's or a row's group;
  - a cell's id on this binding: `protocol.md` §2's `message_id` names a 32-byte group key, and a
    cell travels on its column's topic and on its row's, where §1.2 gives it one id;
  - which version a node writes when every extra field has its default value, since a `protocol.md`
    node reads version 1 only;
  - how a node under `protocol-v2.md` reads a version 1 `WantIndex`;
  - whether every binding ignores a WANT whose `hops` is over `ROUTE_HOPS`, as this one does.
- **EVIDENCE** would travel as a full gossipsub message on the family's rendezvous topic, as on the
  partial-messages binding (§0's table). None is defined in this version (`[D6]`), so this carrier
  is reserved, as SEACAST's message encoding reserves its kind `0x08` (§1.1).
- **Gossipsub's IHAVE limits:** offers are IHAVEs, so a stock gossipsub client applies its own
  (`protocol-v2.md` §4.3).
- **The mapping** is §0's table, middle column.

## 5. The partial-messages binding

This binding is gossipsub with the Partial Messages Extension: it is the binding for columns while
the extension is the deployed path. It keeps the rollout inside existing topics.

- **What it gives up** (`protocol-v2.md` §7's capabilities):
  - it gives up interest without subscription, but for a sampler's (§6);
  - it gives up the push relation's floor and direction;
  - it gives up the answered GRAFT: when a GRAFT is accepted, it is accepted in silence;
  - it gives up scoring on SEACAST's own messages, and gossipsub's scoring applies.
- **The two ends of a relation agree through gossipsub's backoff.** With the GRAFT accepted in
  silence, what keeps the ends' views of a relation together is gossipsub's backoff after a PRUNE:
  each end holds it from a PRUNE it sends or receives, and refuses the peer's GRAFT within it.
  (`protocol-v2.md`'s own `PRUNE_BACKOFF` is held only by the end that receives a PRUNE, and it
  refuses no GRAFT. It needs neither the hold at both ends nor the refusal, since its GRAFT is
  answered.) The ends must be able to rely on gossipsub's backoff, so it must outlast the link's
  longest round trip at each end that may prune (`protocol-v2.md` §4.1's Rationale). With a
  shorter one, a GRAFT that crosses a PRUNE can reach its peer as the backoff ends and be accepted
  at that end alone; at exactly the round trip it turns on whether a GRAFT at the backoff's last
  instant is within it, which gossipsub does not say. With a longer one, the ends agree in every
  state at rest that `toy/graft_check.py --model` reaches (up to four upkeep steps per end; a
  bounded check, not a proof). A wait added to a node's own GRAFTs after the backoff does not cover
  it, since the disagreement comes from a GRAFT accepted. Gossipsub's recommended backoff of one
  minute meets the bound on any link whose round trip is shorter; this binding sets no backoff of
  its own.
- **What it depends on:** it depends on libp2p's Partial Messages Extension (libp2p specs, pull
  request 685), and consensus-specs' partial columns (`specs/fulu/partial-columns/p2p-interface.md`,
  and Gloas's of the same name). The partial message's group id is theirs, a version byte `0x00`
  and the block root, with the column from the topic.
- **The fork** is in the topic's name, as gossipsub's topics carry it.
- **A cell group's header** (§1.6) travels by the partial columns' own rule, in the partial message
  (§1.2): this is form (b), carried per link.
- **The extension fields** it needs are as follows:
  - the JOIN's duty and `M` travel in an extension field, beside the subscription;
  - a GRAFT's colour travels in an extension field;
  - the WANT's `standing`, `hops` and `probe` travel in an extension field, which also asks for the
    part where the asker has not subscribed (§6).

  Their bytes are the extension's to define, beside its own fields.
- **Gossipsub's IHAVE limits:** offers travel as `partsMetadata`, not as IHAVEs. Whether the
  extension limits them is not checked here (`protocol-v2.md` §4.3).
- **The mapping** is §0's table, right column.

## 6. A sampler on gossipsub's wires

On the gossipsub and partial-messages bindings a JOIN is a subscription, and a subscription is
announced to every peer. A sampler's `(DECLARED, NONE)` therefore cannot be one:
- a subscription to the topic of a family it samples would disclose the sample to every peer (I6);
- and it would make the node a receiver of the whole family, pushed all of it.

A sampler subscribes to nothing for the families it only samples, and these rules make that work:

- **No JOIN on the wire.** The JOIN `(DECLARED, NONE)` that `send_join` sends writes nothing on
  these wires and counts as queued at once, so a sampler's links for a type are the peers from
  which it has received a subscription to one of the type's topics. A peer that has subscribed to
  none of a type's topics is read as `(DECLARED, NONE)` for that type: its WANTs are its interest
  and stand (`protocol-v2.md` §4.5), and nothing is pushed or offered to it; it receives only the
  answers to its WANTs. A node that subscribes to some of the type's topics, a custodian, samples
  another family through the WANT's `standing` flag, which every sampler sets (`protocol-v2.md`
  §4.10).
- **Answers admitted by their WANT.** A node accepts a chunk on a topic it has not subscribed to
  only as the answer to a WANT it sent: the group's chunk at that index, from the peer the WANT
  went to, until the group expires. Nothing else on such a topic is accepted, no other index and no
  other peer; a copy from a peer asked earlier is accepted and acknowledged like any duplicate
  (`protocol-v2.md` §4.10). A forwarder's own WANT for a routed request (`protocol-v2.md` §4.5,
  `route_want`) is admitted the same way, so a forwarder subscribes to nothing new either. Where a
  receive path drops a message on a topic the node has not subscribed to, the admission is an
  exception to that drop, and an admitted chunk is then checked and validated as any other.
- **On the partial-messages binding** the extension ties `requestsPartial` to a subscription, so a
  peer could answer an asker that has not subscribed only with the full message. The WANT's
  extension field also asks for the part as a partial message, and the asker does not downscore a
  partial message it asked for this way as unrequested.

Rejected: the draft rejects approximating `DECLARED` interest by subscribing, either to the sampled
families (the disclosure above) or to every family of the type (every family pushed to the
sampler). The libp2p stream and Waggle bindings need none of this: their JOIN goes per link and
names no sample (`protocol-v2.md` §1.2).

## 7. A fetch outside the links: its transports

`protocol-v2.md` §7 defines the fetch and its privacy rule: a node sends a WANT to a node of the
known node set that is not a link, and that node answers with a CHUNK. The binding decides how the
fetch is carried. The transports considered are these:
- one is an ephemeral libp2p connection, short-lived and admitted above the peer limit (FullDAS's
  "libP2P-ephemeralConnect");
- one is plain UDP (PANDAS's one-hop requests to nodes in a crawled view);
- one is a fast QUIC connection;
- one is a discv5 request in a handshake of two round trips (FullDAS's "new primitive outside of
  the libp2p framework", implemented in its simulator).

Over a datagram, a message in SEACAST's message encoding (§1.1) needs no length prefix: the
datagram's boundary marks it.
