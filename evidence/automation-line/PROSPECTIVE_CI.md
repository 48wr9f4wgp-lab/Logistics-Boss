# Prospective source-export comparison (PR161)

This correction makes `combined-renderer-control` measure the intended generated packs. It does not qualify the new equipment's performance or publish a game build.

- A remains historical control `a7c60e8c86785137a90b517227b5def8b329c1bc`; B is the exact PR head. Both are archived from full immutable refs and exported separately using official Godot 4.7.2. Source hashes must remain unchanged across import/export.
- Regenerated A must match its immutable public assets under the existing verifier's four-scene node-ID exception only. The local export check passed with exactly those four differences. B receives a new prospective manifest; the old public manifest is never overwritten.
- Manifest records commits, full source maps, exact generated asset sets and harness hashes. Its digest is fixed in the completed export step's output BEFORE a separate fixture step. The runner checks that digest before parsing the same bytes and again after measurement; source/assets are checked before/after and the browser checks served bytes.
- ABBA order, durations, thresholds and classification remain unchanged. Historical frozen-public mode remains available and strict. No other CI job switches to the new candidate. The desktop public-export coherence gate remains separate and unresolved.

Independent review found a pre-read PCK+manifest joint-rewrite gap in the initial version. The fixed step-output digest closes that gap in a trusted CI procedure. Focused 28 tests passed and independently passed again, including joint rewrite before initial read, post-read changes and missing digest rejection. Existing Node9 regressions, workflow syntax/order and diff checks passed. This is not independent signed attestation against malicious workflow changes.

A separate comparison against immediate public PR160 `027cb20d0bcd34fde6f944f4b3e7e63e21dc9b09` is still needed to isolate new-equipment incremental cost. The historical A control must not be relabelled as PR160. Earlier local performance failures remain unqualified. Real BFCache uncertainty and desktop failure details remain separate; forbidden log retrieval is not retried.

No game source, save schema, public docs export, Pages target or performance threshold changes. No new performance measurements were used to approve this correction. The iPhone comparison plan remains unpublished and requires separate origin approval.
