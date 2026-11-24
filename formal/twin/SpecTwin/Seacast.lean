import SpecTwin.Seacast.Types
import SpecTwin.Seacast.Basic
import SpecTwin.Seacast.Codecs
import SpecTwin.Seacast.Relations
import SpecTwin.Seacast.Announce
import SpecTwin.Seacast.Probe
import SpecTwin.Seacast.Serve
import SpecTwin.Seacast.Upkeep
import SpecTwin.Seacast.Decode
import SpecTwin.Seacast.Receive
import SpecTwin.Seacast.Sample
import SpecTwin.Seacast.Kept
import SpecTwin.Seacast.Replay
import SpecTwin.Seacast.ReplayKnown
import SpecTwin.Seacast.KeptKnown
import SpecTwin.Seacast.FormsKnown
import SpecTwin.Seacast.Manifest
import SpecTwin.Seacast.DispatchKnown
import SpecTwin.Seacast.FuelKnown
import SpecTwin.Seacast.FormsRows
import SpecTwin.Seacast.NarrowKnown
import SpecTwin.Seacast.SyncKnown

/-! # The twin of seacast.md: its modules

`lake build SpecTwin.Seacast` builds them all. `SpecTwin.lean`, `seacast-lite.md`'s root, does not import them, so a build
of `seacast-lite.md`'s twin is as it was. -/
