# Save-readiness hotfix qualification

Draft only. No production merge or deployment. Base: a7c60e8c86785137a90b517227b5def8b329c1bc.

## Problem and fix

A pending Web Locks callback was indistinguishable from denied ownership during saving. Production Main + Save in Godot 4.7.2 reproduced permanent protection after focus-loss or accept-contract saves for both current and legacy pending locks. This demonstrates the code consequence, not the frequency of a real browser race or the cause of an individual user report.

The loader now waits for required ownership before launching the engine. Existing v5 warehouses do not need legacy ownership; fresh or legacy warehouses do. Waiting, occupied, unavailable, cancellation and timeout are distinguished. Failure releases acquired locks and late grants cannot resume a cancelled startup. Browser Back/Forward cache restoration requests an explicit reload rather than resuming a stale heap. Protected Back/Work controls visibly communicate their disabled state.

Save keys, schemas, legacy decoding, transaction comparisons, economy and machine visuals are unchanged. Existing unknown/corrupt/newer saves stay protected. No storage deletion, forced takeover or automatic reset is introduced.

## Local evidence

- Godot 4.7.2 source and rebuilt PCK: migration216, staged-save105, autosave-clock250 and expanded scene safety passed.
- Scene safety covers actual native mouse down/up at1280×720, protection refresh/resize, normal modal guards, and restored-page protection.
- Synthetic JavaScript tests: existing storage14, readiness12, exact loader3. Loader geometry144, viewport104 and Japanese startup/error mock passed.
- Independent review verified failed-startup release, late BFCache registration, mixed-version error handling and normal modal guards.

These are synthetic/local checks, not actual desktop Chrome qualification. The checked-in candidate Web set initially contains a locally rebuilt4.7.2 PCK and assembled shell; engine JS/WASM match the base. The new desktop-save-readiness CI job performs official4.7.2 full Web export, records exact comparisons, and requires source/engine/export coherence. A byte mismatch remains a failing gate until reviewed and reconciled; no generated artifact is assumed equivalent merely because tests pass.

## Required real-browser evidence

The added job uses isolated CI Chromium contexts with synthetic saves only. It covers desktop startup and mouse save/reload, delayed true exclusive grants, real competing pages, existing-v5 independence from legacy locks, API failures/timeout, and navigation lifecycle. BFCache is only claimed verified when actual pageshow.persisted=true is observed. Otherwise it remains explicitly unverified.

The existing required workflow remains enabled. Its unchanged performance harness is pinned to the current released machine-view base and this hotfix's dedicated source/export manifest. Thresholds and failure semantics are not relaxed. This is not physical Windows validation or public-origin UI proof.
