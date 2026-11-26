# SEACAST Lite: its rationale

This file holds the rationale, evidence and history that accompany [`seacast-lite.md`](seacast-lite.md). It states no rule: the rules are in `seacast-lite.md`, and where the two differ, `seacast-lite.md` holds. Its sections carry `seacast-lite.md`'s numbers and titles, and its text stands as it was written there: "this document" and the section numbers in it refer to `seacast-lite.md`, and "above" and "below" may point to this file or to `seacast-lite.md`.

## 1. The payload, the code and the commitment [c1, c6]

### Rationale

**The slot in the group's key.** An honest builder never commits one descriptor at two slots, since
the payload carries its slot's timestamp. A dishonest one could. With the slot in the key, its
commitment at a later slot names a new group, so it cannot make a group that has expired live again.

**Where the descriptor travels.** The choice between design A, the descriptor in the chunk, and
design B, the descriptor in the bid (open above), decides the four things below. It does not decide
when a chunk is accepted: under either design only the installed block's bid says which group is
committed, so a copy waits for its block in both (§3, §4.2).

*When a node knows a group's shape.* The descriptor gives the group's chunk count, the chunks' size
and the code. Every limit set by a group's count (on bitmaps, ids and ties: §2, §4.2, §4.4, §8.2)
holds once a node has the descriptor; before, the same limits use `MAX_PLAIN_CHUNKS`, what any group
can have. This document's code gives a receiver the descriptor when the group's first chunk passes
level 1, under either design (`open_group`, §4.2), and the source has it from `publish` (§5.1).
Under B the installed block's bid holds the descriptor, so a node could apply these limits from the
installation, without waiting for any of the group's chunks. Under A it could apply them from the
group's first copy, even one that waits for its block, once that copy's descriptor is checked
against the key it names (below).

*What a copy shows before its block.* Under A a copy carries the descriptor, and an honest copy's
key is that descriptor's hash at the copy's slot (`group_key`). A node could therefore check a copy
that waits: its descriptor against its key, and its index, length and proof against its descriptor.
These checks do not authenticate: a group made up whole passes them, and only the block tells it
apart. Under B a copy that waits carries nothing to check it against. This document's level 1 does
none of this before the block (§3).

*What the bid fixes.* Either design adds one field to the bid (above). Under A it is a 32-byte group
id whatever the descriptor holds: a field added to the descriptor later changes `Chunk`, which
carries the descriptor (§2), and not the bid's layout. Under B the descriptor's layout is part of
the bid's, so a field added to it changes `ExecutionPayloadBid`, a consensus container, and no
chunk. Under both it changes what `group_id` hashes, and so the groups' keys, and every node needs
the new layout (§0).

*What a chunk carries.* Under A each of the group's N chunks carries the descriptor, 51 bytes as
serialized (§2). Under B no chunk carries it, and each bid that commits the group carries its 51
bytes in place of the 32-byte group id. At these chunk sizes the bytes do not decide it: 51 bytes
against a chunk of about 12 KB, at 1 MiB and the default `UNIT`, is under half a percent, and the
share grows as chunks get smaller.

## 2. The wire [c1, c7]

### Rationale

**A structured id.** It lets a receiver match an announcement to a group and an index before it
holds the chunk, and match both to a bid once its block is installed. The content id is computed
over the decompressed chunk, so different snappy encodings of one chunk share an id, and different
contents claiming one index do not.

**What a stock peer would see.** The protobuf schema is unchanged, but the meaning is not. A stock
peer takes a bitmap in an IDONTWANT for an id that matches nothing, which is harmless. A bitmap in an
IHAVE it takes for an ordinary id: it asks for it, and counts the unanswered ask as a broken
promise. Hence the scope of §0: every peer on the topic runs this protocol.

## 3. Validation: three levels, and what each gates [c1, c6, c10]

A node cannot validate a payload before it forwards pieces of it; that is where the speed comes
from. Validation therefore comes in three levels, and only the first fits a chunk.

### Rationale

**The decode claim before level 2.** Only the builder can fail level 2, and then it fails at every
node, so a claim made at K can only be wrong about a group that every node drops. What a node
claimed of such a group were authentic pieces, so it has nothing to retract.

**What bounds the damage: the builder's cost.** A chunk authenticates only against the bid an
installed beacon block carries, so at most one payload per winning bid crosses the network: one per
block. Chunks committed to a losing bid never validate. Under Gloas, a bid's pending payment that
reaches the same-slot attestation quorum is queued for withdrawal whether or not its payload ever
arrives: if it is not settled earlier, at the end of the epoch after the bid's. A builder that
commits to an invalid payload therefore pays for the slot and gets nothing for it. One case moves
the cost: a proposer that signs a second block for the slot is slashed, and the slashing clears that
slot's pending payment. The nodes that forwarded the payload could not have known it was invalid,
which is why it never counts against them.

**No ask before the block.** An answer could not be checked before the block is installed anyway:
asked for early, it would wait in the deferred store, a provider's answer spent on a copy that
cannot be checked yet.

## 4. Receiving

### 4.2 A chunk arrives

#### Rationale

**A held index, not a held id.** A node claims a chunk once its proof checks because a held index is
stronger evidence than a held id: it covers any chunk claiming that index. Not evaluated yet:
claiming a chunk that arrives ahead of its block by its exact id, on arrival. That is safe, because
an id covers only those bytes.

**Why ties.** Without them, a push the store refuses is lost: its sender counts it as pushed and
offers it to nobody, so a node whose only peer pushed it that chunk never completes. And a node on
the proposer's other block (§3), whose copies all wait for the builder's block, would spend its
providers' parks, the last resort's asks and their answers on copies that cannot validate, and could
stall once it switches to that block.

**What a forger can do.** It affects only its own promise and the asks to itself. An installation
releases its own root's ties, once, so a proposer that signs m blocks for the slot allows at most m
releases at a node.

### 4.4 An IHAVE arrives [c3, c5, c7]

#### Rationale

**Every entry read, every offer kept.** Ignoring an IHAVE, or the rest of one, as stock gossipsub
does, could lose a node's only offer of a chunk: nothing ensures that an announcement is repeated,
and heartbeat gossip is for peers outside the mesh. A limit therefore delays asks, to the next
heartbeat's retry, and loses no offer.

**Why `expand` looks up `known_id`.** For a bitmap, `expand` asks by index, and so does `ledger`
(§6.1): the lookup of `known_id` in both never gives an id as this document stands. An id is
recorded only for a chunk the node stored, every stored chunk is in `mine`, and neither asks for a
chunk in `mine`. The lookup is kept for a node that knows a chunk's id without holding the chunk,
which nothing here brings about.

### 4.5 An IWANT arrives

#### Rationale

**Why an honest ask comes before the claim.** Claims are made only for chunks that passed level 1,
and within a group's active lifetime (§8.1) a node's holdings only grow.

**Why an expired group stays expired.** A node's claims of the group can outlive the expiry: a HAVE
still queued leaves after it, and a peer keeps a claim for `HAVE_TTL`. Taking the group up again
could contradict them.

### 4.6 Decode, the claim, repair and the levels above [c6, c10]

#### Rationale

**The claim before decoding.** Every chunk that passed level 1 is an authentic leaf under the
committed root. If the N leaves form a codeword, every node's decode succeeds and the claim is true.
If they do not, any K of them rebuild a codeword that differs somewhere, so every node's check fails,
and the claim was about a group every node drops. What waits for level 2 is everything that hands
out rebuilt data: delivery, and the rebuilt chunks. *What a forwarding node checks, and when it
decodes* (2026) maps the alternatives. Forwarding need not wait either: the chunks a node received
were authentic whatever levels 2 and 3 find.

**Why push, and not hold or announce.** A builder may release only the K chunks needed to decode.
Every node then needs every one of them, the slowest to reach it included, and the other K exist
only in the nodes that have decoded. Completion times spread out, and a builder that releases late,
near a deadline such as the payload timeliness vote, can use the spread to split the network.
Repair puts the other K back as soon as the first nodes decode, so that a node still short can again
complete on any K of the N. Holding the rebuilt chunks would not do it: the claim is not an
announcement, and asks go to announcers (§6.1), so a node that only held its rebuilt chunks would
never be asked for them, which is the same as rebuilding nothing. An announcement would add an ask
and an answer, three link delays instead of one, so it helps mainly where other asks fail. It can
also be baited: an announcement is a promise nobody can check before asking, and a withholding node
or a liar draws asks it never answers until the park stops them (§6.1). Where every chunk is released
and the other nodes are honest, a rebuilt chunk is one more copy of a plentiful one, and repair has
little to do. *What a forwarding node checks, and when it decodes* (2026) measures how much of the
spread repair takes back, against withholding nodes and silent nodes, and what it does on a full
release.

**A shortfall, not card 4's budget.** Card 4's budget cannot be reused for repair: late in a
diffusion most mesh peers have claimed every chunk, and the budget would shrink to nothing. The
chunks are picked at random so that decoded neighbours tend to push different ones. A random delay
before the push, so that decoded neighbours do not all push at once, was not taken: *What a
forwarding node checks, and when it decodes* found it changed nothing measurable on a full release,
and did not try it with only K chunks released.

**Nothing marks a rebuilt chunk.** Once the group has passed level 2, a rebuilt chunk is an authentic
leaf, as a forwarded one is.

**Keeping the root its chunks name.** The roots can differ only when a proposer signs two blocks of
a slot whose bids commit the group: the group's chunks may then name either root, which their ids
cover, and a node cannot tell which one the source's chunk names at an index it never received. A
rebuilt chunk naming the other block would wait for good at a neighbour that installed only the
block the chunks name, and its sender, which counted the push, would send nothing more for the
index. A source names one block, so with this rule every honest copy of a group names it, as long
as no node relabels a chunk: honest nodes forward a relabelled copy, and rebuild from it (above). A
rebuilt chunk that named a block whose bid commits another group would never pass level 1: a
receiver without that block defers it until the block installs, then rejects it.

**A decode that outlives its group.** This document does not bound a decode's duration (§8.1), and
a group past its active lifetime keeps only its tombstone, so the decode's result has nothing left
to act on.

## 5. Publishing and forwarding

### 5.1 The source [c2, c13]

#### Rationale

**Striping's threshold.** Striping pays only when the source can send faster than its mesh peers
can pass the chunks on. The source knows neither their uplinks nor how much of its own it can count
on, so the threshold sits where the gain is measured (§8.3).

**Announcing at the acknowledgement, by default.** Announced at publish, the offers race the pushes.
A transport that takes a writer's entries at once (a deep library buffer, a socket's send buffer, a
router's queue) can let a peer's announcements leave while pushes, to it and to other peers, still
wait in the transport or in the node's queues; the mesh then asks for chunks whose pushes have not
left, and the source answers on top of its pushes. The acknowledgement is the one event the source
sees whatever the transport holds (§7.3).

**Announcing at publish, the source's choice.** No rule at another node needs either setting: a
peer takes an offer whenever it comes, and one whose ask the source does not answer in time parks it
for the group and asks another announcer, if it has one (§6.1). Like any default, the setting
changes how the payload spreads (§8.3), and so what the other nodes see. At `PUBLISH` each mesh
peer is offered the chunks not pushed to it before most have left the source, so it may ask the
source sooner, and park it if it does not answer in time. At `ACK` the source's HAVE names a chunk
only once it is acknowledged, so its mesh peers push some of its chunks back to it meanwhile. What
the setting trades is the source's own:

- *Its uplink.* Offers at publish draw asks on top of the source's pushes. Where the writer keeps
  §7.3's rule and the queue admits them, they wait behind the pushes queued before them to the same
  peer (an offer a full queue refuses is owed, and rides with the next write, §7.2); where the
  transport takes a writer's entries at once, they can leave while pushes still wait. In the toy at
  60 nodes (degree 30, three payloads, the median of ten seeds), measured on `seacast.md`
  when it took this rule as written (`toy/README.md`, 2026-11-11), with writes that complete
  at once: against announcing at publish, a 50 Mbps builder announcing at the acknowledgement was
  asked 61 % less and uploaded 2.07 copies of the payload instead of 2.50, and a 1 Gbps builder 5.9
  instead of 10.0; the payload's median completion moved by −8 to 0 ms over four cells, and by −19
  to +6 ms over their seeds. At 500 nodes, at one seed, the source was asked 22 % less and uploaded
  3.06 copies instead of 3.24. With §7.3's rule kept, the timing changed nothing measurable at 60
  nodes (40 asks against 45, the medians within 4 ms). A fast source can gain where its peers pull
  chunks from it while its uplink has room: SEACAST's 1 Gbps proposer of many column groups
  completes 44 ms sooner at 60 nodes and 9 ms sooner at 500 when it offers at publish, and its
  50 Mbps proposer 26 ms later at 500 (`seacast-figures.md`, §4.7).

- *Its privacy.* Every chunk announced at once, by the one node that holds them all, names the
  source to its mesh, and the paced HAVE [P4] then hides nothing from it. A source that wants P4's
  cover announces at the acknowledgement.

The reference value is `ACK`. A client may key the choice on the source's configured uplink, as
striping is (`STRIPE_UPLINK`); this document does not, since a fast source may still want P4's
cover.

**The paced HAVE.** A HAVE that names every chunk before any chunk has left can come only from the
source, so it would tell each mesh peer who published the payload. The paced HAVE still keeps the
other nodes from pushing the source's chunks back to it, a chunk at a time. It removes the one sign
certain to its mesh, unless the source announces at publish, which is another (above). Others remain
at either setting: the source's HAVE tends to grow faster than any other node's; it announces the
group's chunks at once to a peer that joins its mesh (§5.4), and, since `publish` puts every chunk in
the gossip history, to the peers it samples outside its mesh at each of its next three heartbeats
(§6.4), at `ACK` without waiting for any chunk's acknowledgement; and it is usually everyone's first
sender. They are the subject of separate work on the
source's privacy, where P4 is this measure's name.

### 5.2 A node forwards [c3, c4, c11, c17]

#### Rationale

**A push that does not happen is not counted.** Counted, such a push would leave its peer neither
pushed nor offered the chunk. Where no other peer offers it, as in a triangle, a ring or at a node
with one peer, that peer would never complete.

### 5.3 Whom to push to: furthest behind first [c16]

#### Rationale

**Furthest behind first.** The peers that hold the fewest chunks are the ones for which a push is
least likely to be a duplicate, and the ones that would otherwise have to ask.

**A draw, not the single furthest behind.** The count trusts what each peer says about itself. Taking
the single peer furthest behind, an under-reporter would always look furthest behind and win every
contested push; a node that tells each pusher it holds only what that pusher sent it would draw
most of its neighbours' pushes and pass none on. Drawn within the lower half, it no
longer wins every contested push.

**The guard** is for a peer that takes pushes and never reports at all.
`GUARD_GRACE` allows for the first push to leave the node and the peer's first HAVE to come back,
about one round trip where queues are short (§8.3). An honest peer can still be demoted while its
copies wait for their block, or if its HAVE is dropped at a full queue, until its first HAVE comes.
At the source the plain ranking is what spreads card 13's stripes evenly over its connections
(§5.1).
*Segmented payload diffusion, card by card* (2026, card 16) gives what each form costs against
under-reporters, as measured.

### 5.4 A peer joins the mesh

- **Its cost** is one IHAVE bitmap per stored group and join (the bitmap 16 bytes at N = 128, up to
  1 KiB at `MAX_PLAIN_CHUNKS`, plus the group id and framing), several groups' bitmaps in one frame
  where they fit, and the asks they draw. At the receiver they count as any IHAVE does: its IHAVE
  limits delay the asks, not the reading of the bitmaps nor the retries (§4.4), and its offers are
  kept within §8.2's limits on admitted groups.

#### Rationale

**Why announce at a join.** Offers come from announcements, and a node announces a chunk when it
forwards it, which follows the chunk's arrival. Without the announcement at a join, nothing would
ensure that a peer that joins the mesh after a chunk was forwarded is offered it, nor that a peer
whose connection closed is offered on the new connection what the old one lost: a closed connection
takes with it what was queued, owed or in flight on it (§8.1). Heartbeat gossip may announce a chunk
on a connection outside the mesh, and a later copy may be forwarded, but neither need happen: the
gossip goes to a sample of the peers outside the mesh and names only the last three heartbeats'
chunks (§6.4).

**The join's announcement goes to the mesh.** On connections outside it, the source's announcement
of every chunk at once would tell more peers who published. Heartbeat gossip tells some of them all
the same: `publish` puts every chunk in the gossip history, so each of the source's next three
heartbeats announces them to its sample outside the mesh (§6.4), at `SOURCE_OFFERS = ACK` without
waiting for any chunk's acknowledgement. Keeping a source's chunks out of the gossip history until
they are acknowledged is left to the work on the source's privacy (§5.1's Rationale).

## 6. Asking

### 6.1 One ask per chunk at a time, move on, park [c5]

#### Rationale

**One announcer at a time, then the next.** Some gossipsub implementations, go-libp2p's among them,
ask every peer that announces a message they lack, which is what a node without card 5 does (§0).
With an announcement per chunk (card 3), that brings back through the pull path the duplicates the
push path saved. Asking one announcer at a time needs a window after which the node moves on:
waiting on a single peer would let a peer that announces and never serves hold the chunk up. An
answer that comes after the window is still taken.

**Promises and the park.** The park bounds what a peer that announces and does not serve can
capture: once parked, it is asked for the group's chunks only by the last resort. The park is
scoped to the group, so that one payload's broken promise does not cost the next: a busy peer, the
builder included, can break a promise on one payload, and a park across groups would then pass it
over on the payloads that follow. *Segmented payload diffusion, card by card* (2026, card 5) gives
what card 5 costs and saves in the measured networks.

**A promise starts at the write**, not at the decision to ask, so that no peer is parked for an ask
it never received.

**Every offer is kept; the list is only an order.** As at gossipsub's IHAVE limits (§4.4), nothing
ensures that an announcement is repeated, so an offer the node forgot could be its only offer of
the chunk. The list, and the bound on how many lists an announcer is in, therefore bound only the
state that orders the asks: a full list forgets no announcer, nor does the bound on lists, and
`offered` keeps every offer within §8.2's bound per peer.

**An order of the node's own, beyond the list.** An order that a peer can arrange, by when it
connects or by its id, would let it stand ahead of every other announcer beyond the list, for every
chunk and at every node. So would a rank under a key that is public: a peer that can compute it can
connect under the id that ranks first. Under a secret rank, of two announcers beyond the list each
is ahead of the other about half the time, and nodes rank them independently of one another. This
covers the announcers beyond the list only. The list keeps announcement order, which the first to
announce still decides, and a sender with several peer ids beyond the list has one of them ahead
more often. Whatever the order, among the announcers it may ask, the retry takes one it has not
asked before one it has.

**No second ask while one is outstanding.** On a live connection an answer does not overtake the
ask before it, so a second ask of the same peer could only draw a second answer. That matters while
the answers cannot be validated yet. A provider answers a peer at most `GOSSIP_RETRANSMISSION` (3)
times per chunk and connection (§4.5). With the rule, while its park and the last resort's count
last, a provider is asked for a chunk at most twice before the root its copies name installs: once,
and once more by the last resort. Its third answer is left for after a switch to that block.
Without the rule, asks decided while the first answer is on its way (the retry after the window, an
ask held in the queue, the last resort's ask) can spend all three answers on copies that cannot
validate, and the node stalls after it switches.

**An ask goes with its announcer's offers.** Kept, the ask would leave the announcer outstanding,
with nothing to look at it again. Once its offers are gone, a retry that finds no other announcer
to ask ends. The announcer's next offer is only recorded, since an ask of the chunk to it is
outstanding (§4.4). While that lasts, a parked announcer that offers the chunk draws no last
resort, since this one is not parked. Once the promise falls due and parks this one too, nothing
asks either of them again, and the node can stall although a parked honest announcer was never
asked once more. An announcer can bring this about: it keeps the ask queued by not reading, and
chooses when it last offers.

**The last resort.** Without it, one slow answer parks a node's only provider for the group, and
the node stalls. The count is per announcer: with one count per chunk, a withholding announcer that
announced first would spend it, and an honest provider parked later for one slow answer would get
none. The count and the timer are per chunk, by group and index, so a parked peer that announces one
index under many ids gets one last resort for it.

### 6.4 Heartbeat gossip and pacing [c15]

#### Rationale

**Paced gossip.** Stock gossipsub announces new messages to its sample of peers outside the mesh all
at once, at the heartbeat. Those peers then ask the source for what they lack while the source's
uplink is still busy with its first copies (*Segmented payload diffusion, card by card*, 2026, card
15).

## 7. Sending: the per-peer queue and the window

### 7.1 The window [c14]

#### Rationale

**First come, first served over the peers.** One window serves all of a node's peers, and the line
decides whose writer takes a slot that frees. In the order they came, no writer that can write waits
behind one that came after it. A writer keeps its place when an urgent entry wakes it (§7.2), so the
control it writes while it waits does not send it to the back.

**A writer that cannot write does not hold the line.** The queues are per peer; only the window is
shared. A writer whose write has not completed cannot use a slot until its transport takes more
(§7.3). If only the first writer in line could take a slot, such a writer at the front would hold
every writer behind it: with a peer that stops reading, once the chunks in flight were acknowledged
or timed out, the node would send no chunk to any other peer, though control would still flow.
Passing it over changes only who takes a free slot; among the writers that can write, the order is
still first come, first served. Taking such a writer out of the line while it writes, and back in
at the end, would free the line too, but a writer that writes control whenever an urgent entry
wakes it would then go to the back each time. `toy/line_stall_known.py` builds the case. Nothing in
this version drops a peer for not reading; the same gap lets an announcer hold the last resort off
(§6.1, "Open: an announcer that is never parked holds the last resort off").

**The next writer is woken when a write starts to wait.** A slot that frees wakes the first writer
in line that can write. If that writer writes control instead, and the write does not complete at
once, the writer can no longer write, and the slot could stay unused while the write waits, though
another writer in line could use it. `write_waits` wakes that other writer. The wake comes when the
write starts to wait, not before the write: a write that completes at once leaves the writer able
to write, and a wake before it would change the schedule of the node's writers where nothing else
changes. A client that cannot tell when its write starts to wait may still wake before the write.
Its cost is that change of schedule: the woken writer takes a slot only if no writer ahead of it
in line can write (`front`) and a slot is free. `toy/write_wait_known.py` checks five cases on each
of the two paths, with p the writer that writes control and q the other writer in line: q has no
run queued when `next_to_send` returns p's control; q has one after p's write starts to wait, and
only after the control reached the transport and `write_waits(p)` was called with the write
pending; q has none when p is not in line or when no slot is free; and a write that completes at
once calls no `write_waits`. In the first, the second and the fourth, p keeps its place at the
head of the line.

### 7.3 Below the writer: what the transport holds

The rules above act on a chunk while it is in the node's own queue. Once the writer hands it to the
transport, nothing here reaches it: the library's buffer, the socket, the host's queue and the access
link's queue hold it until it leaves, and a chunk the peer has meanwhile claimed is sent all the same.
This document decides at the moment of sending, so it needs the backlog to be in the queue.

- **Not met,** nothing breaks and no peer can tell. The backlog sits below the queue, where cancel and
  projection cannot drop it, and the node sends copies its peers no longer need. The node itself can
  tell: a chunk's write that returns at once on a slow link, or asks for chunks whose pushes it has
  not yet sent.

## 8. State, limits and constants

### 8.1 State and its lifetime

#### Rationale

**Why an expired group stays expired.** A node's claims of a group outlive the group's expiry: a
HAVE still queued leaves after it, and a peer keeps the claim for `HAVE_TTL`. A node that took the
group up again could ask a peer for a chunk the peer still holds as its claim, and be penalised for
an honest ask (§4.5). The window rules this out without a bound on queues, the transport or clocks.
Nodes need not agree on `LIVE_WINDOW` or on the current slot: each node's own window keeps it from
taking a group up again, and a group expired at one node and not at another is expiry at different
times, which §4.5 already allows. The claim rule needs no value of `LIVE_WINDOW`, only a window that
moves forward.

**A group's slot fixed by its key.** The window needs a group's slot to be fixed, and the key fixes
it (§1). Named by its group id alone, a group could come back: a bid of a later slot could commit its
descriptor, which only a dishonest builder does, and the group would be live again until its payload
failed level 3.

### 8.3 Constants

`GOSSIP_RETRANSMISSION`'s bound counts on the first and the third, while a park and the last
resort's count last.

#### Rationale

**Three kinds, not one table.** In one table, a node's own choice, measured on one network, reads
as a rule of the protocol, as a limit does. Apart, a limit says what every node accepts, a bound
says how far a node may go and what needs the bound, and a default says where a node is free and
gives a reference value. A bound in place of a value also lets an argument hold for every value
within it, each property needing only its side: reaching every honest node needs `LIVE_WINDOW`'s
lower bound, bounded state its upper one, and the claim rule neither, only a window that moves
forward (§8.1).

**What makes a bound.** A constant is a bound when a guarantee of this document needs its value in a
range. A peer's outcome can depend on it: `GUARD_GRACE` decides when a peer that has sent no HAVE is
pushed last, and a peer's asks need the answers `GOSSIP_RETRANSMISSION` allows. So can the group's
diffusion (`R` at the source, `GROUP_TTL`, `LIVE_WINDOW`), or the node's own state and standing
with its peers (`LIVE_WINDOW`, `TOMBSTONE_TTL`). `PROMISE` and `PARK_TTL` are defaults, although
they decide how a node treats a peer: a parked peer is only not asked, except once more per chunk
by the last resort, and its pushes and the node's answers to it go on (§6.1). A promise that falls
due too soon costs the node that sets it a provider for the group, and can bring the last resort's
ask while the first answer is still on its way; `promise_due` penalises no one. A client that also
scored peers by this promise would make it a bound.

## 9. As measured: where the research implementation differs

The measurements in the posts this document accompanies come from a research harness. This section
lists where the harness does something this document does not specify, and what that means for the
numbers. Figures 4 and 5 of
[*SEACAST: fast, lean, sampled broadcast for Ethereum, with an executable spec and a formal model*](https://ethresear.ch/t/seacast-fast-lean-sampled-broadcast-for-ethereum-with-an-executable-spec-and-a-formal-model/26167)
(2026) were rerun on an implementation with v0.5's rules and the source's paced HAVE; that
post's other figures, and the earlier posts', come from the implementation before them. Where the
rerun does as this document does, the entry says so.

**Harness shortcuts, not part of the protocol.**

- *No validation.* Chunks were accepted, claimed and forwarded on arrival, with no proof check and no
  block gate (section 3); the simulated slot has no blocks. The measurements therefore exclude block
  propagation, gated forwarding and proof validation, and do not quantify what those add. With the block
  installed, the proof check before a claim adds microseconds; a chunk ahead of its block waits for
  it.

- *The wire format.* The measured chunks used a 101-byte structured id (slot, a synthetic block
  root, group, index, content id) and a custom segment encoding inside an SSZ byte field. Their
  descriptor had no `encoding` field, compress-first being configured outside, so their group ids
  differ from §1's. The payload was generated bytes, not a serialised
  `ExecutionPayloadSegmentBody`. The longer id inflates control bytes against the 56-byte id of
  section 2; HAVE and WANT strings have their own lengths. Each chunk carried the descriptor
  (design A). The harness writes the index of a WANT string big-endian, in versions 1 and 4 of its
  strings, where section 2 has it little-endian; the index takes four bytes in either order.

- *K was fixed at 64* rather than derived from `UNIT`. At 1 MiB and the default `UNIT` both give 64.
  The codec allowed up to 16384 chunks, more than a HAVE bitmap can name; §1 caps a group at 8192.

- *No decode.* Completion was counted at K distinct received chunks, where the decode claim went
  out, as in this document (§4.6). Decoding, re-encoding, decompression and the application's checks
  did not run, so delivery's latency is not in the numbers; optimised implementations decode and
  check in a few milliseconds. No chunk was rebuilt, so the measured runs did not repair (§4.6): a
  decoded node pushed, served and announced only chunks it had received. Repair was measured in
  separate runs, on top of tier 4, with each node handed the chunks its decode would rebuild 5 ms
  after its K-th chunk (*What a forwarding node checks, and when it decodes*, 2026). On the post's clean
  networks it should have little to act on, since every chunk is released and a rebuilt chunk is
  one more copy of a plentiful one; on thin links with every chunk released it changed nothing
  measurable.

- *Stop-pull* ran as a harness gate that flips at completion. The decode claim already makes every
  index of the group non-askable, so the effect is the one in §6.2.

- *The fast class* was read from the simulator's link settings, and the window's round trip and
  chunk size from the cell's configuration. A node would configure its uplink.

- *Striping* was set on or off per cell; this document selects it by the configured uplink
  (`STRIPE_UPLINK`).

- *Per-peer dispatch state* existed from the first send only because a measurement option set it
  up. Without it, a peer's first chunks would have skipped rarest-first, projection and the window.
  This document creates it with the connection.

- *The random heartbeat phase* was overwritten on the segmented arms, so every node's first
  heartbeat fell at the same offset from its start. Paced gossip's ticks follow the heartbeat.

- *Random draws* (the lower-half draw, shuffles) used the process-global generator, with no seed
  the harness controlled, and the source enqueued its targets in the order of a Go map's iteration;
  §5.1 keeps the selector's order.

- *The guard and the window.* The measured implementation required the window for card 16's guard,
  so the runs without card 14 also ran without the guard. The guard needs only HAVEs (§0).

**Behaviours that shaped the numbers, as measured, and where this document departs.**

- *Announcing on arrival.* With no validation, a node claimed a chunk as it arrived. This document
  claims it after level 1 (§4.2).

- *Announcing after the decode claim.* A measured node announced every new chunk to its mesh, as
  stock IDONTWANT does for every new message, also after its decode claim had named every chunk of
  the group. This document acknowledges such a chunk to its sender only (§4.2): the mesh learns
  nothing from the HAVE. The extra HAVEs are about a fifth of the honest nodes' HAVEs at about 70
  connections, and more with a datacenter builder, whose fast nodes deliver more chunks after the
  decode. With the measured rule, the toy sends as many HAVEs as the implementation, and its tail
  does not change. The rerun of Figures 4 and 5 still announces these chunks.

- *The source's HAVE* went out once per chunk as each was added to the batch: N cumulative HAVEs to
  each mesh peer, all before the data, which names the source to its mesh. This document paces it
  instead (§5.1, [P4]). A change of 2026-10-07 makes the implementation send one HAVE before the
  data by default, and pace it as an option (`SEGMENT_SRC_HAVE=paced`), measured at no cost in
  delivery. The rerun of Figures 4 and 5
  paces it at the write; this document's HAVE grows at the acknowledgement by default (§5.1), about a
  round trip later, and at the write at `SOURCE_OFFERS = PUBLISH`.

- *The source announced at publish.* The implementation queues a chunk's offers to the mesh peers it
  does not push it to in the same step as the pushes; this document queues them at the chunk's
  acknowledgement by default, and as the implementation does at `SOURCE_OFFERS = PUBLISH` (§5.1).
  Over quic-go, whose stream write blocks until all but one packet is packed, the offers waited
  behind the pushes in each peer's queue and drew few asks. Over a transport that takes the whole
  batch at once, offers made at publish drew asks for chunks whose pushes were still queued, an
  order of magnitude more asks at the source than the harness saw (the cross-check of 2026-10-07,
  on the toy).

- *The transport below the writer* was quic-go's: the measured runs kept §7.3's rule by the
  library's behaviour, not by a rule, and the harness's per-peer queue held the backlog.

- *The push degree by payload size.* The measured tier 4 runs at R = 2 at 1 MiB, and was swept over
  sizes with R = 4, 3, 2 by size (4 at 128 KiB). This document fixes no rule by size (§8.3).

- *The sender counts as a holder* in a forwarding node's budget (§5.2), so R = 2 means one further push per
  received chunk. This is what was measured. The sender is also excluded from the candidates here;
  in the code it could take a budget slot and then be skipped, which is rare.

- *Control waits behind the window.* While chunks are queued to a peer, that peer's IHAVE, IWANT,
  GRAFT and PRUNE on the normal lane wait for a slot, though they do not keep it. A writer waiting
  for a slot also lost its place in line whenever an urgent message arrived for it; this document
  keeps its place, and lets the writers behind it take free slots while its write has not completed
  (§7.1). Whether control should bypass the window is open. At home only the
  source's window filled in the measured cells, so the other nodes were not affected.

- *A slot frees when the peer holds the chunk from anyone,* not when our copy arrives. A decode
  claim frees all of that peer's slots at once.

- *Holder counts for rarest-first* only ever increased: a departed peer's claims were dropped, but
  not its share of the counts, and a peer whose HAVE expired and was re-sent was counted twice. This
  document counts distinct live holders.

- *An ask by index for a chunk the asker had claimed* was answered: the measured node cleared that
  claim in the asker's send queue, for cancel and projection only, and kept it everywhere else. This
  document drops such an ask (§4.5), and the asker drops queued asks for chunks it holds (§7.2). The
  asker's queue kept such asks, and its HAVE, on the urgent lane, overtook them: the answers arrived
  as duplicates, 0.1 % of them at home and 2 to 3 % with a datacenter builder. A change of 2026-10-07
  makes the implementation do as this document does; the rerun of Figures 4 and 5 has it.

- *Promises were not closed on decode* for the park. Asks still open when a node decoded broke at
  400 ms and parked the asked peers for the completed group only, which changed no later decision.
  This document closes them.

- *The offer-table retry* picked untried announcers in peer-id order; this document takes the
  earliest to have announced among the announcers admitted to a chunk's ordered list (at most 16,
  and an announcer in at most 256 lists, §8.2), and the others after them in the node's own order
  (§6.1). A retry that found every announcer parked stopped, and the chunk
  waited for a fresh announcement; this document asks each parked announcer once more, later, and
  keeps every offer (§6.1). The rerun of Figures 4 and 5 does as this document does, but for the
  order beyond the list, which is newer than the rerun.

- *An ask dropped at a full queue* was lost, and its promise still fell due. This document starts
  the promise when the ask is written (§7.2), as the rerun of Figures 4 and 5 does.

- *A push that did not happen.* A push that projection skipped was not announced in its place: the
  implementation's comment has the peer pull the chunk from others that announced it, and where
  none did, the peer stayed short. This document offers it (§5.2). A push, offer or answer that a
  full queue refused was dropped, as an ask was; this document owes it (§7.2). The rerun of
  Figures 4 and 5 does both.

- *Rules added after v0.4,* from a model of this document's rules: the three above; no ask before
  the block (§3, §4.4) and a refused deferred copy counted as its sender's offer (§4.2; since
  replaced by ties, below), which need blocks, and the measured runs had none; promises that close with their connection (§6.1); and
  expiry checked by the retry, the writer's ask filter and a returning decode (§6.1, §7.2, §4.6).
  The implementation behind the earlier figures predates them. The rerun of Figures 4 and 5 has
  each of them that has a counterpart in the implementation. Two have none: the implementation keeps
  no deferred copies, and it does not decode, so the expiry check of a returning decode falls to its
  rebuild step, which the measured runs do not reach. Of the rest, three act in those runs: the
  promise from the write, the offer of a skipped push, and the second ask of parked announcers. The
  runs have no blocks, no expiry within a payload's lifetime and no disconnects, so the others do
  nothing there. Against the same runs without these rules, the times and bytes stayed within the
  spread between runs, and honest nodes parked honest peers less often.

- *The IHAVE limits.* The measured handler allowed 4096 control-bearing frames per peer per
  heartbeat, a counter that also counts frames carrying other control, and asked a peer for at most
  the stock 5000 ids a heartbeat; as in stock gossipsub, an IHAVE that arrived over either limit was
  ignored, and so were the ids of one IHAVE after its 5000th. This document counts only
  IHAVE-bearing frames, reads every entry, and records an IHAVE over either limit and retries its
  asks at the next heartbeat (§4.4), so the two differ only in a heartbeat in which a peer reaches a
  limit, or for an IHAVE of more than 5000 ids. Within its mesh, the rerun's source announces a chunk
  only to the peers it did not choose for a push, as §5.1 does.

- *The live window and the group's key* (§8.1, §1) came after the implementation measured, its
  rerun included. The measured runs have no blocks and no expiry within a payload's lifetime, so
  neither would act there: in those runs the key only renames groups, which in the toy moves the
  recorded cells as any renaming does (`toy/README.md`).

- *A peer that joins the mesh* (§5.4) came after the implementation measured, its rerun included.
  No connection closes in the measured runs, and their meshes settle before the first publish (the
  harness waits for the grafting to finish), so the rule would act there only where gossipsub's
  upkeep grafts a peer during a payload's lifetime, which the runs did not count.

- *Ties, no second ask of a peer at once, and asks that go with their announcer's offers* (§4.2,
  §6.1), came after the implementation measured, its rerun included; ties replace v0.5's offer of a
  refused copy. The measured runs have no blocks, so no copy waits there and nothing is tied, and
  their groups complete long before an offer's 30 s, so no ask goes with dropped offers there or in
  the toy. The rule against a second ask acts in ordinary runs:
  in the toy's twelve cells at seeds 7 to 9 it changes the events of 31 of the 36 runs, and moves
  the warm medians by −8 to +6 ms at p50, −15 to +34 ms at p99 and −0.04 to +0.03 copies, where a
  change that alters no rule moves them by −1 to +5 ms, −13 to +10 ms and −0.05 to +0.01.

- *Clearing promises on decode* in the stock gossip tracer had no effect in the measured cells,
  because the harness runs no peer scoring. In a client that scores peers it keeps honest peers from
  being penalised for asks the decode made unnecessary.

- *No block evidence.* Neither push selector checked that its target holds the block (§3); the
  measured runs had no blocks.

- *Serving.* A measured node served chunks from its message cache, six heartbeats long. This
  document serves a group's chunks for the group's active lifetime (§8.1).

- *The pacer* skipped a job within the same tick when per-id holding evidence had removed all its
  ids; only a job emptied while its ids became bitmaps consumed the tick. This document consumes
  the tick in both cases.

- *Per-peer tables:* offers, retries and answer counts were keyed by peer id and survived a
  reconnection. §8.1 resets them with the connection. In the rerun of Figures 4 and 5 a closed
  connection's promises, offers and tried asks go with it; its answer counts still survive.
