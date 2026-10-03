# FLOTRA campaign release

The existing two-job preview becomes a complete, finite six-contract campaign. The original main game at `/godot-preview/`, its source, and its saves remain unchanged.

## What is playable

- Accept a finite contract, deliver every box, earn first-completion capital, buy real upgrades, then choose the next job
- Bulk and small-order branches offer different layout problems; accepted cargo never disappears when editing
- Grow the crew from 3 to 5, expand shelf capacity, improve packing handling and add two actual pallet bays
- Reach a clear ending, then replay unlocked contracts for medals and measured best times
- Persistent phone navigation, pause independent of editing, scroll-safe purchases, clear results and 1×/2× speed
- Dedicated autosave with exact in-flight resume, backup and explicit failure status

## Measured pacing and tradeoffs

An adaptive progression run completed the campaign in 1,715 simulation seconds, about 14.3 real minutes at 2× (excluding time spent choosing/reading). The unupgraded compact-layout run took 2,290 simulation seconds. The first contract took 181 seconds in the default layout; its reward permits one early hire or shelf choice.

The small-order contract took 298 seconds with the shorter-pick layout versus 327 seconds compact. The storage-heavy contract took 389 seconds compact versus 769 seconds with the shorter-pick layout. Added floor bays are used by actual cargo and reduced a fully equipped narrow-floor bulk replay from 752 to 390 seconds. Upgrades affect actual work; congestion can offset individual improvements, so faster handling is not presented as a universal throughput multiplier.

## Verification

Godot 4.7.2 source and compiled exported-PCK tests cover the campaign, conservation, purchases, replay, in-flight save/resume and malformed saves. UI tests cover 375×667, 390×844 and 430×932 using engine mouse/touch input, scroll and drag cancellation, repeated taps, Back and focus interruption. Native Linux visual captures use the exported candidate; manual native interaction additionally checked acceptance, pause, layout preview and cancellation.

Independent review covers persistence isolation, strict import validation, all-contract save/resume, exact candidate identity and protected legacy files. Reproducible source and a narrowly scoped regression workflow live in `flotra-campaign/`.

## Storage and remaining device gate

The web loader keeps `persistentPaths: []` and never mounts the old Godot `/userfs` database. Only dedicated campaign localStorage keys are used, with a browser-exclusive writer lock. Existing corrupt, foreign, future-version or conflicting saves are preserved and saving is visibly blocked. A separate browser storage QA page uses only disposable QA keys, including its backup and lock.

Cloud Chrome cannot currently run this game's WebGL2 prerequisite. Native rendering and engine input are not evidence of actual iPhone/Safari gameplay or performance. That physical-device acceptance remains unverified and must be reported separately.
