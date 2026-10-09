# Desktop BFCache browser selection

At c00bb93ffe386e931b2e5a92d73d234487ef2139, user-provided candidate CI diagnostics confirm **14 passed / 0 failed / 1 blocked, exit2**. The only recorded returned lifecycle event is a trusted, non-persisted pageshow in a fresh realm. Current writer ownership is held, one engine boot fulfilled, writes/console/page/request errors are empty, and the ordinary history reload's latest-checkpoint comparison passed. Actual persisted restoration and its protection assertions were not exercised by that CI run. The GitHub job's nonzero result remains valid.

## Evidence-backed environment hypothesis

- Successful local runs explicitly selected `/usr/bin/chromium`, version151.0.7922.173, with Playwright1.62.1, headless=true.
- Existing CI installs Playwright1.62.1 and its browsers, but supplies neither an executable override nor a channel. `xvfb-run` alone does not set `FLOTRA_BROWSER_HEADED`; the runner still requests headless=true.
- Installed Playwright1.62.1 `coreBundle.js` `getExecutableName` selects `chromium-headless-shell` for headless without a channel, and `chromium` for the chromium channel. Its browsers.json expects revision1234/version151.0.7922.34. This is the expected CI selection, not a directly observed CI binary/version from the pasted diagnostic.
- [Playwright's browser documentation](https://playwright.dev/docs/browsers#chromium-new-headless-mode) distinguishes the default headless shell from full Chromium's new headless mode selected by channel `chromium`.
- [Chromium headless implementation at immutable source aaa5ca21](https://chromium.googlesource.com/chromium/src/%2B/aaa5ca21ac213cc0a868a387868764f63dc5e45f/headless/lib/browser/headless_web_contents_impl.cc) gates IsBackForwardCacheSupported on the enable-back-forward-cache switch. Removing Playwright's disable-back-forward-cache argument alone does not supply that shell opt-in. This supports the selection difference as a concrete mechanism; the exact old CI binary and a same-binary negative reproduction have not been obtained.
- The local successful trace's index and away-document responses were HTTP200 text/html from SimpleHTTP/0.6 Python/3.12.14, with Content-Length/Last-Modified and no Cache-Control. CI uses the same standard `python3 -m http.server` command with no custom header configuration. Actual old CI headers/Python version remain unavailable; no header difference is established.

No bundled full Chromium or headless shell exists in the local Playwright cache. No prohibited browser download, CI log/artifact fetch, proxy or alternate retrieval was attempted.

## Minimal change

The desktop runner selects `channel: 'chromium'`, retaining an explicit CHROMIUM_EXECUTABLE when provided. CI's existing browser install already installs the regular Chromium build. No BFCache eligibility-forcing flag is added. Existing trusted-event requirement, same-realm/no-restart/no-reacquisition/no-write/protected-controls/latest-checkpoint assertions, console gate, timeout, tracing and passive asset observation remain unchanged. Fallback remains blocked/exit2.

Startup output now records the requested browser selection and actual browser.version(). Failure diagnostics include navigation/notRestoredReasons and before/returned realms. The executable value is the selected path, not an independent observation of the spawned process. A null notRestoredReasons field must not be treated as proof of a specific cause.

## Bounded validation

One complete local desktop15 run was predeclared, using immutable c00bb93 game sources and a separately hashed local test-harness change; no performance scenario or timing threshold was added. Source/export manifests are pinned before fixtures. The local full-browser run is positive-path verification; it is not a negative reproduction using the missing shell. Final results are recorded below.

Related JavaScript50 tests passed. Independent read-only review found no weakening or blocking code issue and retained the causal-uncertainty caveat.

Normal PR push would automatically execute the existing historical renderer performance job. Because this follow-up explicitly forbids additional performance measurement, any review-only push uses `[skip ci]`; no new exact-head CI qualification is claimed. Existing c00bb93 CI results and all prior performance failures remain preserved. No workflow/job gate was removed or altered.

Final local result: **15 passed / 0 failed / 0 blocked, exit0**, exactly one run. Actual version151.0.7922.173, headless full system Chromium with channelchromium. Trusted persisted pageshow and the same before/returned realm were observed. All existing restoration protection/no-extra-engine/no-reacquisition/no-write/latest-checkpoint assertions passed; console/page/request errors empty. Source/export/manifest post-verification passed. This verifies the full-browser positive path, not the missing shell negative path or a new CI run. Raw evidence is retained at `/workspace/flotra-automation-delivery/bfcache-browser-selection/`.

Pinned local export manifest SHA256: `5c8627d9950aadd840ecb87bd902e0fdafa230fd8ace2dea019d2845aaa7a042`. A review-only skip-ci commit is **CI not run / unverified**, not running or successful.
