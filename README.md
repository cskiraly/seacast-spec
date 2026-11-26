# SEACAST

SEACAST (Segmented, Encoded, Availability-sampled broadCAST) is a protocol for getting Ethereum's
large objects to many nodes fast. The source of an object cuts it into chunks and commits to them;
it can also compress the object and add coded chunks. A node that forwards passes a chunk on once it
has checked it, without waiting for the whole object: it pushes the chunk to some of its peers and
announces it to others. A node asks its peers for the chunks it misses. The same protocol serves
broadcast, where every node needs the whole object, and sampled diffusion, where a node needs only
its columns, rows or cells.

This repository holds SEACAST's specification, written as Python-like code in the style of
Ethereum's consensus specs; a small simulator, the toy, runs that code as written. The
specification defines two protocols:

- **SEACAST**, in [`seacast.md`](seacast.md), is the main one. The toy runs its code, and the Lean
  twin replays the toy's traces of it.
- **SEACAST Lite**, in [`seacast-lite.md`](seacast-lite.md), diffuses an execution payload over
  gossipsub. It is the one that was measured and proved: the measurements ran a research
  implementation of it, and the proofs are of models of its rules. SEACAST contains it as one of
  its settings, tier 4, with the differences that `seacast.md` §6.1 lists.

The toy runs SEACAST with `--doc seacast`. Up to v0.11.1 the files had older names: `protocol.md`
for SEACAST Lite, `protocol-v2.md` and `protocol-v2-*.md` for SEACAST, and `--doc v2`.
Release numbers are this repository's, not either protocol's; `seacast-lite.md` shows at its top the
release it belongs to.

## Why SEACAST

- **Fast.** In simulations of 500 nodes, each with 16 connections, 50 Mbps up and 100 down, 99 % of
  the nodes held enough chunks to rebuild a 1 MiB payload after 0.64 s with SEACAST Lite,
  against 0.76 s with FullDAS (every node sampling every cell) and 0.97 s with ECBroadcast's
  Reed–Solomon mode; with today's gossipsub, 99 % held the whole payload after 4.5 s. Each time is
  the median over ten simulated networks; checking proofs, waiting for the block and decoding are
  outside the times.
- **Lean.** In the same runs, a node received about 1.3 MiB on the wire (the nodes' average, at the
  median over the networks): about 60 % of what it received with FullDAS, and about a third of what
  it received with ECBroadcast or today's gossipsub.
- **Elastic.** With every node's links cut to a fifth (10 Mbps up, 20 down), SEACAST Lite
  took 1.8 s instead of 0.64 s to reach 99 % of the nodes, with about the same bytes. Today's
  gossipsub took 25 s.
- **Broadcast and sampling in one protocol.** SEACAST treats execution payloads, PeerDAS columns and
  RowDAS rows as object types of one protocol. It keeps what a node receives of each (the whole
  object, its custody columns or the cells it samples) apart from what the node forwards for others.
- **Not tied to one transport.** SEACAST is defined on its own messages. Its bindings carry them on
  a libp2p stream of their own, on Waggle, on gossipsub's wire with or without its Partial Messages
  Extension, and, as a draft, on native QUIC. The toy models two of them, the gossipsub and libp2p
  stream bindings.
- **A specification that runs, and is checked.** The toy runs both documents' code as written,
  against recorded runs and known answers. For SEACAST Lite, there are proofs in Veil of
  models of its rules written by hand. Under the assumptions they state, they show for any number
  of nodes that an honest node is never penalised, and that, for one object, once nothing is left
  to happen, every honest node reachable from the source along the mesh of that moment has
  completed. The models have v0.8's rules and four later changes. A Lean transcription of both
  documents' code, function by function, replays traces of the toy's runs.

The numbers come from the announcement post, which calls SEACAST Lite simply SEACAST. The
four protocols ran in one simulator, on a virtual clock. SEACAST Lite ran there as its
research implementation (Prysm with a modified gossipsub library), and `seacast-lite-rationale.md` §9 lists where
that implementation differs from the text.

## What to read

| To | Read |
|---|---|
| learn SEACAST, the main protocol | [`seacast.md`](seacast.md); its §0 says how to read it |
| carry it on a transport | [`seacast-bindings.md`](seacast-bindings.md) |
| see why the rules are as they are, and their history | [`seacast-rationale.md`](seacast-rationale.md) and [`seacast-lite-rationale.md`](seacast-lite-rationale.md) |
| see SEACAST's decisions and the figures behind them | [`seacast-decisions.md`](seacast-decisions.md) and [`seacast-figures.md`](seacast-figures.md) |
| read SEACAST Lite, which the measurements and the proofs are about | [`seacast-lite.md`](seacast-lite.md); its §0 says how to read it |
| run either protocol, or try a rule before implementing it | [`toy/`](toy/) |
| know what is checked, and how far | [`formal/README.md`](formal/README.md) |
| see what each release changed | [`CHANGELOG.md`](CHANGELOG.md) |

## Where it stands

- **The latest release is [v0.13.0-rc.1](https://github.com/cskiraly/seacast-spec/tree/v0.13.0-rc.1)**,
  2026-11-25. [`CHANGELOG.md`](CHANGELOG.md) says what each release changed; changes after the
  latest tag are on `main`, and the changelog's first entry names them.
- **SEACAST Lite** (`seacast-lite.md`) was measured on a research implementation, and each
  results record names the code it ran. [`formal/README.md`](formal/README.md) says what each check
  of it shows: the proofs, the Lean twin with its record, and the first piece of a refinement.
- **SEACAST** (`seacast.md`) is checked by running its code: the toy runs it, and the Lean twin
  replays the toy's traces of it. The research implementation's simulations ran only designs that
  SEACAST contains as settings.
- **Results.** The announcement post, *[SEACAST: fast, lean, sampled broadcast for Ethereum, with an
  executable spec and a formal model](https://ethresear.ch/t/seacast-fast-lean-sampled-broadcast-for-ethereum-with-an-executable-spec-and-a-formal-model/26167)*
  (2026), stays as published. Its text is kept current, with the latest results and the data and
  scripts behind them, in [eth-networking-studies](https://github.com/cskiraly/eth-networking-studies/tree/main/seacast),
  and news is posted as replies to the post.

## Running it

```
cd toy
python3 run.py --nodes 100 --msgs 4    # tier 4, 100 nodes on 50/100 Mbps links, four payloads
python3 check.py                       # the document still runs as recorded
```

These run SEACAST Lite; with `--doc seacast`, either runs SEACAST. The toy needs only Python 3
and its standard library (tested with 3.12).
[`toy/README.md`](toy/README.md) describes the options, the network model and what the toy adds to
the documents.

## Background

Up to v0.5, the protocol that is now SEACAST Lite was published as *Informed Diffusion*, a
design of segmented payload diffusion studied for
[EIP-8411](https://eips.ethereum.org/EIPS/eip-8411) (Fast Execution Payload Broadcast).
*Informed Diffusion* was also `seacast-lite.md`'s title up to v0.10.3, and now names how SEACAST
diffuses.

- [Wen fast payload broadcast? Segment, code, push, pull, and everything in between](https://ethresear.ch/t/wen-fast-payload-broadcast-segment-code-push-pull-and-everything-in-between/25913)
  (2026): the design space and the commitment;
- [EIP-8411: what segmented payload diffusion is made of](https://ethresear.ch/t/eip-8411-what-segmented-payload-diffusion-is-made-of/26025)
  (2026): tiers 1 to 3;
- [*Informed Diffusion: making home builders publish fast*](https://ethresear.ch/t/informed-diffusion-making-home-builders-publish-fast/26151) (2026): tier 4 and its
  measurements;
- [Segmented payload diffusion, card by card](https://notes.ethereum.org/@cskiraly/segmented-stack-cards)
  (2026): each mechanism in prose, what it costs and when it matters;
- [Who decides that a payload is revealed?](https://notes.ethereum.org/@cskiraly/eip-8411-envelope-signature)
  (2026): how the envelope's signature travels;
- [*What a forwarding node checks, and when it decodes*](https://notes.ethereum.org/@cskiraly/informed-diffusion-decoding) (2026): the validation levels, the decode claim
  and repair.

## License

[CC0 1.0](LICENSE): public domain, like the EIPs and the consensus specs.
