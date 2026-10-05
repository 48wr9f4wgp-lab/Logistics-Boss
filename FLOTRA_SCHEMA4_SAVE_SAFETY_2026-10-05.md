# Local schema-4 save store and immutable archive

Status: local implementation and acceptance evidence only; no publication, live-save reads, or device-performance claim. The approved immutable archive is additional to the existing rolling backup. All acceptance profiles are disposable synthetic data.

## Stable namespace and compatible envelope

- Native primary: `user://campaign-v1.json`; rolling backup: `user://campaign-v1.backup.json`
- Browser primary: `flotra.campaign.release.v1`; rolling backup: the same key plus `.backup`
- Immutable native original: `user://campaign-v1.pre-v4.json`; browser original: primary key plus `.pre-v4`
- Envelope remains `format="flotra-campaign", version=1`. Domain schema becomes 4. Web persistence continues to use the existing localStorage namespace and existing exclusive Web Lock `flotra.campaign.release.v1.writer`; no IndexedDB/userfs mount or external access is added
- New linked schema-4 envelopes carry optional `pre_v4_sha256`: lowercase SHA-256 of the complete exact original archive text, including its whitespace. The original four-field envelopes remain supported. This additive field is outside the domain payload, so schema-3→4 domain migration still changes only the schema number and adds the hall dictionary

Existing envelope readers ignore the new optional field, but the old runtime cannot interpret a schema-4 domain. This is format compatibility, not permission to run an old version over newer progress.

## Source selection and precedence

Loading does zero writes. A valid primary is the active checkpoint, even when the archive or backup prevents further saving. The exact primary text is retained in memory; validation does not replace it with normalized/re-exported text.

Before the first schema-4 write:

1. A valid schema-1/2/3 primary is the archive source
2. If the primary is already valid unlinked schema 4 and its rolling backup is valid schema 1/2/3, that exact old backup may supply the source. This supports a mixed-version checkpoint without guessing or rebuilding old progress
3. If an archive already exists, validate it through the matching frozen `release_sim.gd`, `growth_v2_sim.gd`, or `growth_v3_sim.gd`. Its schema must be an exact supported integer 1–3. If an old source is identifiable, its bytes must equal the archive exactly
4. An existing schema-4 binding requires that exact valid archive. A missing archive or a different but individually valid old archive blocks all writes, including after both rolling slots become schema 4. If no binding and no identifiable old source can establish the connection, an existing archive also blocks writes
5. A completely new installation has no pre-v4 checkpoint. Its schema-4 envelopes stay unlinked and no archive is invented

The first successful migration write pins the original and binds the new envelope to it. Every later schema-4 save carries the same digest. The rolling backup continues advancing normally; the immutable archive is never overwritten, deleted, or rotated by the store.

The binding detects replacement or absence; it is not authentication, a user/account identity, or cryptographic proof of historical ancestry. Someone with direct write access to all storage could replace both an archive and its bindings. Cooperative writers are serialized; arbitrary outside processes are not controlled by this application.

## Protection, failure, and recovery limits

Unknown/corrupt/future/oversized primary, backup, archive, invalid checksum, invalid old domain, or conflicting binding is protected. Empty-but-present storage is also protected. A valid backup may be loaded when the primary is missing or invalid, but that session stays read-only. The archive is never selected automatically for gameplay, and archive-only storage never becomes a fresh warehouse.

Archive creation failure, including quota, leaves old progress readable and disables new writes. No reset or mandatory manual-export step is introduced. A visible Japanese save status explains when saving is blocked. Existing valid data can be inspected/played in memory, but unsaved progress is not claimed durable.

The archive contains the last validated old checkpoint, not later schema-4 play. Restoring it externally would discard all later progress and may conflict with newer rolling slots. There is no automatic rollback UI in this implementation and no promise that an old release can open schema 4.

Native writes stage complete temporary files, verify bytes, then commit archive, rolling backup, and primary in that order using same-directory renames. A failed temp write cannot truncate a live slot. A failed primary commit can leave the backup advanced to the unchanged old primary; both remain valid. A successful archive creation survives a later failure unchanged. Failed native transactions require a new validated session rather than continuing from uncertain observations. A write lock directory serializes cooperating native instances; an unresolved/crash-left lock is not automatically taken over or deleted. Such a lock keeps writes disabled while reads remain possible.

Browser writes compare all three observed slots, including absent versus empty, under the original Web Lock. Each successful owned mutation updates the expected snapshot; a concurrent change prevents the next mutation. The archive is created before either rolling slot changes. BFCache return reacquires ownership but preserves the prior observation, so another page's changes fail closed. A lock admitted after pagehide cannot silently revive the hidden writer. localStorage has no multi-key transaction, so quota after backup advancement can leave the backup equal to the unchanged primary; it cannot erase the archive or primary. Failed/uncertain transactions require a fresh validated load.

## Reproduction

Use official Godot 4.7.2, an explicitly disposable HOME/XDG directory and `FLOTRA_REVIEW_USER_ROOT` pointing at their parent. The native test refuses writes outside that declared root. Never reuse an actual user's browser profile or native data directory.

- `node flotra-campaign/tests/release/postcap_storage_archive.cjs`: in-memory browser archive/quota/concurrency/BFCache tests
- `FLOTRA_STORAGE_BRIDGE="$PWD/flotra-campaign/campaign-storage.js" node flotra-campaign/tests/release/review_storage_test.cjs`: original bridge adversarial suite
- With disposable HOME/XDG: `Godot --headless --path flotra-campaign --script res://tests/release/postcap_save_archive.gd`: actual schema4 + frozen-schema migration and native failure matrix
- Existing `save_store_test.gd`, `review_save_safety.gd`, `growth_save_regression.gd`, `integration_save.gd` remain regression gates; the old release-scene integration alone does not establish new growth-scene integration

Real Chromium storage checks use the existing loopback-only `review_browser_storage.cjs` and a fresh browser context. They are storage tests, not WebGL/phone performance evidence.

## Recorded local acceptance (2026-10-05)

Evidence under `integration-evidence/`:

- `postcap-save-archive.log`: 510 passing assertions against real schema4/frozen models, byte-exact old originals, source selection/binding, synthetic malformed data, transaction fault injection, and actual disposable native files
- `postcap-storage-archive.json`: 15 passing browser-bridge scenario checks; includes 50 autosaves, quota at every slot, conflicting archive, binding preservation, all-slot concurrent changes, Web Lock contention, BFCache and delayed lock admission
- `original-storage-review.json`: original 12 bridge scenario checks pass
- `save_store_test.log`, `review_save_safety.log`, `integration_save.log`: original 18, 22, and 8 assertions pass. The intentionally malformed Variant/object attacks produce expected Godot diagnostics while all safety assertions pass. The 8-assertion scene test targets the old release scene, not the production growth scene
- `postcap-save-cost.log`: all checks pass in an actual earned 480-unit active hall state. Full synchronous `save_from`, including export, serialization, strict import validation, and native filesystem operations: first archive creation 207.257 ms; 24 later five-second autosaves median 210.790 ms, p95 223.399 ms, maximum 227.929 ms. Output envelopes were approximately 399–407 KB. This run overlapped resumed regression workers, so CPU scheduling contention is included; it is a stall diagnostic, not a quiet performance baseline or phone/browser measurement. The stress case deliberately delays first migration persistence until active480; the real scene normally archives earlier on its first committed action
- `original-chromium-storage.log`: shell-launched real Chromium could not start because runtime `socket()` is denied. An approved escalation retry with a disposable profile met the same restriction; no browser assertions executed through that path. Map-based results must not be represented as real-browser storage acceptance

The measured synchronous save stalls are an open production performance consideration. No validator is weakened or bypassed to improve timing. The separate production-scene, real-browser, full regression and device gates remain owned by the integration review.

### Bounded direct-validation optimization

`save_from` now validates the exact freshly exported Dictionary using the same complete strict importer before committing its encoded envelope. It avoids decoding its own newly created envelope; stored or foreign text still takes the full checksum/codec path. The envelope bytes and archive binding are unchanged. `postcap-save-archive-direct.log` passes 878 assertions, including schema-1/2/3/4 direct-versus-codec acceptance/rejection, input nonmutation, and exact imported/output parity. Final original focused native and browser-bridge regressions also pass; see `*-direct.log`.

Five profiled active480 samples before this change identified export 2.9–7.5 ms, encode 10.6–18.3 ms, redundant decode 14.1–23.7 ms, candidate construction 3.0–4.4 ms, and strict import 128–206 ms. Typical native commit cost was 19–30 ms. The complete strict importer is the dominant cost. After the bounded change, the same 24-sample diagnostic reports later-save median 191.445 ms, p95 232.758 ms, maximum 239.591 ms, and first archive creation 250.831 ms. These overlapped regression work and are not a controlled A/B comparison; the removed codec operation is confirmed, but a stable speedup is not claimed. Save stalls remain an open gate. `storage-acceptance-summary.json` links the final focused evidence.

### Final shared-core preflight acceptance

Final focused results supersede the earlier counts/timings above. Schema4 now exposes `validate_release_state(data)` and `import_release_state(data)` through the same schema dispatch, historical validation, shape checks, and physical staging core. Preflight omits only preparing a destination for subsequent play; no domain acceptance checks are skipped. Normal import still commits and prepares all playable route caches. The store uses that acceptance-only method when available and preserves the complete frozen importer fallback. Immutable expected-geometry caching is implemented and tested by the domain integration.

`postcap-save-archive-shared.log`: **1,382 passing assertions**, including exact accepted/rejected flags and error details versus full import, no preflight state commit, direct-versus-codec acceptance and exact output parity, frozen fallback, and all immutable archive/failure protections. Final original native suites pass 18/22/8 assertions and Node bridge suites pass 15/12 cases. Visible Japanese statuses now say 「更新前の保存データ」 while preserving separate conflict, creation-failure, and validation-failure explanations.

`postcap-save-shared-paired.log`: actual earned active480 state, real disposable native store, all saves/reloads/archive checks pass. First archive creation **72.037 ms**; 24 subsequent five-second autosaves **81.274 ms median, 94.486 ms p95, 104.282 ms maximum**. Ten same-state alternating-order pairs measure shared acceptance **77.791 ms median** versus full importer **115.434 ms median**. Both use the same complete acceptance core and immutable geometry cache; the full importer additionally warms playable destination routes. These are local Linux measurements with other regressions running, not device/browser frame evidence. Synchronous save pauses remain relevant. No further optimization was made in this pass.

The real-browser companion harness is `flotra-campaign/tests/release/postcap_browser_storage.cjs`. It uses a loopback server, fresh Chromium contexts, actual localStorage/Web Locks, and explicit mock envelopes to exercise 30 autosaves, reload, a competing tab, quota injection at every slot, changed backup/archive, binding protection, and unknown archives. It must be run through an authorized working browser route; merely syntax-checking it or passing the Map suite is not browser acceptance. It explicitly does not claim actual BFCache or production-scene coverage.
