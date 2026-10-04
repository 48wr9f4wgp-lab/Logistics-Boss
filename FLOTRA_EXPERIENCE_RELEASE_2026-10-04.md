# FLOTRA: player-experience polish

This iteration preserves the quick, forgiving four-wing warehouse-growth game and its existing paid jobs. It improves the choices and the journey around that game, without adding entry fees, timer failure, a longer upgrade grind, or unrestricted placement that would invalidate the physical routes.

## Easier to use

- First-use guidance puts the first-job button before the instructions, including on a 375×567 CSS-pixel viewport.
- The top-left **操作** menu puts pause/resume and 1×/2×/4× speed at the top. Speed, menu auto-pause and reduced walking animation are remembered.
- Manual pause stays paused when a menu closes. Reloaded work starts paused. Backgrounding the app pauses it; returning requires an explicit resume.
- Completed work has direct next-job and replay actions. Affordable equipment appears before folded future/owned equipment, rather than beneath every locked expansion.
- Equipment and operating choices show real capacities, handling limits, packing time and tradeoffs. Purchase/configuration feedback remains visible inside the sheet.
- Placement previews remain free and reversible. A queued move can be cancelled before the physical movement begins; once movement starts it finishes safely with its cargo.
- Player-facing Japanese, lock explanations, save warnings, loading failures and labels are consistent. The original annex is called 別館, distinct from the four new wings. The Japanese [player guide](docs/guides/FLOTRA_PLAYER_GUIDE_JA.md) explains the complete loop.

The 18 CSS-pixel text floor, 56 CSS-pixel controls, full-DPR drawing buffer, scrollable reading sheets, pinned placement action and held-touch/dismissal guards remain.

## Real choices and equipment synergy

Three free operating choices are available between jobs:

1. **バランス重視** keeps the previous single-parcel dispatch behavior.
2. **小口をまとめて運ぶ** picks and dispatches up to three parcels from the same order on a real cart. Handling time is charged per item; the cart uses the existing exclusive trolley routes. Packing remains one physical item at a time.
3. **まとめ便を優先** handles ready pallets and inbound pallets before small-parcel work. It can improve a pallet-heavy workflow while delaying parcels.

No cargo is manufactured, removed or teleported for a throughput multiplier. All load reservations, rack occupancy, packing queues and delivered units remain in the ledger. Different modes/layouts can win under different conditions.

Measured domain examples, in game-time seconds, on the same paid parcel demand and starting compact layout:

| Configuration | Completion time |
| --- | ---: |
| Balanced, starter equipment | 140.35s |
| Parcel cart, starter equipment | 99.55s |
| Parcel cart plus automatic packing | 82.20s |
| Parcel cart plus 48-unit shelving | 91.95s |

Automatic packing was not a useful speed purchase for this workload under the previous single-parcel pattern (140.35→140.65s); the real cart creates packing bursts and makes it useful without slowing the default game. Shelving similarly improves from a small 140.35→138.25s difference to 99.55→91.95s with the cart. These are examples, not promised gains for every warehouse. A fully equipped short-pick layout favors balanced operation (49.65s versus cart 50.25s), while a mid-level expanded bulk setup improves from 83.75s to 67.90s under pallet priority.

## Foreground playback clock

Godot 4.7.2 caps the engine process delta under very slow rendering. A measured 350ms foreground frame reported only about 133ms, so the old displayed 2× speed could run below real time. The campaign now feeds its existing fixed 0.05s domain ticks from a monotonic foreground clock. At most 0.25 seconds of wall time is accepted per rendered frame; excess stall time is discarded, not queued as a debt. Pause, focus loss, menu auto-pause, new work and speed changes re-anchor that clock. Background time is never turned into offline progress.

Independent clock tests cover 1×/2×/4×, long stalls, pause/resume, menu boundaries and imported active saves. The original per-frame work budget is retained: at 4×, at most 20 fixed simulation ticks are processed per frame. Slow frames up to 250ms now preserve the selected rate; longer stalls deliberately slow playback to protect responsiveness. This fixes capped-delta pacing, not GPU FPS.

## Save continuity and validation

Payload schema 3 adds the operating profile and comfort preferences. Schema 1 and schema 2 saves are validated by their preserved original implementations before migration. Wallet, purchases, records and the entire active cargo/clock/route/reservation state are retained byte-for-byte. An imported job continues under the original operating profile until a fresh job is accepted. New comfort preferences do not change its domain clock.

The existing localStorage primary/backup keys, exclusive writer lock, native directory and `persistentPaths: []` are retained. Invalid, foreign, future or conflicting saves do not authorize overwrite. The original `/godot-preview/` application and its saves are untouched. Downgrading an existing profile to an older application that cannot read schema 3 is unsupported.

Independent corruption tests cover batch sizes and references, route endpoints and reservations, clocks, mode/profile types, atomic rejection, and preservation of the primary and backup bytes. Save warnings explicitly explain when further progress is not being saved and avoid suggesting that a reload preserves unsaved work.

## Reproduce

Use official Godot 4.7.2:

- `GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/test.sh`
- `GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/tests/release/run_experience_adversarial.sh`
- `GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/export_web.sh`
- Generate isolated fixtures with `FLOTRA_GROWTH_FIXTURES=/absolute/output godot --headless --path flotra-campaign --script res://tests/release/growth_browser_fixtures.gd`
- Serve the exact export, then run `node flotra-campaign/tests/release/browser_growth_geometry.cjs URL OUTPUT_DIR`
- Run `node flotra-campaign/tests/release/browser_growth_journey.cjs URL OUTPUT_DIR FIXTURE_DIR`

The independent historical-source check uses pinned commit `0a5a71ee3e88100373fcb77aae685bd4f52a7c24`, separate from the shipped migration validator. A shallow checkout must fetch that commit first. All tests use isolated save directories and fresh browser profiles.

## Verification boundary

Actual Chromium WebGL phone emulation, CSS sizes and DPR 1/2/3 are distinct from physical iPhone/Safari testing. Cloud software-renderer frame timings are not physical-phone FPS. Renderer batching, low-poly actors, immutable snapshots, topology-only static rebuilds and hidden-world suspension remain; the mature warehouse retains explicit draw-call, CPU, relative frame-cost and stable-node budgets.

A live-origin TLS warning must never be bypassed. Where that environment limitation remains, exact deployed asset identity over normally verified HTTPS plus gameplay on that exact export is reported separately from live-origin interaction.
