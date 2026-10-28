# CI repair candidate

Date: 2026-10-27 JST / status: pending exact-head CI

Run 40146228501 passed 12 jobs and failed two. The renderer measured all ABBA
samples but strict equality included intentionally changed caption/projection
coordinates. Both builds retained identical physical camera scale/control,
progress, wallet and growth. A prospective exact camera contract is pinned by
each immutable PCK hash, based on artifact 12581337185. It checks every camera
and caption field; original domain/unknown-field comparison still applies.
Wrong pack, changed coordinates, zoom, domain values and unknown fields are
covered by negative tests. Timing/draw/node thresholds and ABBA order are intact.
The failed run remains failed.

The writer suite passed 14 cases; real BFCache restoration was blocked. Its
artifact reported a new JS realm and a genuine non-persisted back_forward load
with masked not-restored reasons. Playwright documents BFCache testing as
unsupported: https://playwright.dev/docs/api/class-page. The shared observation
code is preserved while the genuine restoration case now uses a fresh native
Chromium CDP pipe with no Playwright Page and no cache-forcing flags.
It requires trusted persisted pageshow, same heap/engine, no reacquired locks,
no save writes, old-state protection, trusted mouse and keyboard actions,
resize protection, then explicit reload of the newest real UI-earned save.
Non-restoration remains blocked, never passed. CDP reasons are preserved.

No campaign simulation, save bridge, model or export bytes are changed.
The new manifest records every project file; historical manifests are unchanged.
This is not iPhone/Safari qualification and does not authorize production release.
