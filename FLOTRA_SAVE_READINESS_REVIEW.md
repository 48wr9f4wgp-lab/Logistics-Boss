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

These are synthetic/local checks, not actual desktop Chrome qualification. The checked-in candidate Web set initially contains a locally rebuilt4.7.2 PCK and assembled shell; engine JS/WASM match the base. The new desktop-save-readiness CI job performs official4.7.2 full Web export, records exact comparisons, and requires source/engine/export coherence. The initial strict byte gate failed and is preserved below. The prospective rule now accepts only the specifically reviewed generated-node-ID differences; every other mismatch still fails. Browser testing uses the exact committed Web bytes, never substitutes the fresh export.

## Required real-browser evidence

The added job uses isolated CI Chromium contexts with synthetic saves only. It covers desktop startup and mouse save/reload, delayed true exclusive grants, real competing pages, existing-v5 independence from legacy locks, API failures/timeout, and navigation lifecycle. BFCache is only claimed verified when actual pageshow.persisted=true is observed. Otherwise it remains explicitly unverified.

The existing required workflow remains enabled. Its unchanged performance harness is pinned to the current released machine-view base and this hotfix's dedicated source/export manifest. Thresholds and failure semantics are not relaxed. This is not physical Windows validation or public-origin UI proof.


## Prospective diagnostic revision after first failed qualification

First head f398d82dc61d2308d82df4009e18301be20ad3ee, run37728822623 remains failed. It recorded6 desktop cases passing and9 failing/unqualified, including earned-fixture-dependent cases. Its PCK-only full-export hash mismatch is not retroactively a pass. Prior artifact materialization was unavailable; this revision does not retrieve or republish that artifact.

An independent fresh4.7.2 import from authorized tracked source produced a different local PCK. Validated resource parsing found176 entries in each local pack,172 byte-identical. Four scene resources differed only in20 uncompressed bytes of generated node_ids arrays. Godot4.7.2 SceneState generates absent/clashing unique scene IDs through ResourceUID::create_id, which uses random bytes. These IDs are runtime identity values, not disposable padding: inherited/moved-node recovery can use them.

Primary source: [PackedScene ID generation](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/resources/packed_scene.cpp#L1017-L1040), [serialization](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/resources/packed_scene.cpp#L1705-L1706), [random creation](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/resource_uid.cpp#L104-L121).

The new, separately approved prospective coherence rule is deliberately narrow:

- Every other Web asset and PCK resource must remain byte/hash identical.
- Only the four explicitly named scene resources may differ, solely inside one recognized node_ids array. Bytes before/after that array must be identical, including all property/material representations.
- Independent Godot inspection must show identical node count/order/names/types/paths/properties, positive locally unique IDs, and no scene inheritance, instances, ID paths, node paths or connections. Project code must not access these ID fields.
- Any extra resource, field, structure or reference difference fails. IDs are not zeroed, rewritten, or normalized in either artifact.
- Actual desktop tests serve and hash-check the exact committed PCK and Web set. Full source export is a separate coherence proof. No fresh pack is substituted into the qualification subject.

Local negative tests reject a compiled script-byte mutation, a non-ID scene-field mutation, and inherited-scene structure. The permitted local generated-ID-only difference passes; future CI emits its own per-resource details directly to logs. Existing failed evidence remains failed.

Future browser failures now print named phases, sanitized stacks and selected loader/lock/UI/input diagnostics without raw save payload. Cold-start assertions remain unchanged pending actual first-error evidence. The load-failure fixture now fails PCK fetches with real HTTP503: the loader directly propagates PCK preload rejection, whereas its WASM initialization wrapper can leave a rejected download pending. Rejection/no-write/lock-release assertions are retained.


Second head5d4be1c6141a133060a871cdd54413c6db38f826, run37730571591, produced the first exact desktop failure diagnosis. All four cold/delayed startup cases reached trusted mouse start/pause and a real saved checkpoint, then the new test incorrectly expected wallet0. The established growth_sim.gd constant is100; the assertion is corrected to exactly100, with all other startup/save/reload/lock checks retained. Four dependent cases had no verified fixture and therefore did not run. This is a harness correction, not a product change or retroactive pass. The PCK503 failure/lock-release gate passed. The separately approved scene-ID coherence rule passed and the browser job logged the unchanged committed PCK hash.
