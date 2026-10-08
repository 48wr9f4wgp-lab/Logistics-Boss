# FLOTRA: warehouse space and direct navigation

## Scope

This draft starts at `main@0f39e620634d2c7d48a4d3620c0489ea3b45bb09`. It does not merge the diagnostic branch or publish to main.

- Wide desktop uses a compact header and bottom status/camera strip. Text remains at least18 logical pixels; camera range, resolution and material quality are unchanged.
- Separate direct destinations: 仕事, 設備・増築, 配置. Jobs and equipment no longer share tabs. Mobile retains three56px primary targets; results are under 操作 → 成果と記録.
- One consistent 仕事 entry in idle/completed gameplay. During unfinished work, the separate pause/resume control remains visible. Desktop 一時停止 fits its108px control; restored cargo still requires explicit 再開.
- Save protection, ordinary modal guards, input cancellation, purchases/prices/availability, domain behavior and save format remain unchanged. Header padding fits the existing protection labels without shrinking type.

## Accepted actual pixels and input

The exact product scripts were rendered and reviewed in [capture run37743676402](https://github.com/48wr9f4wgp-lab/Logistics-Boss/actions/runs/37743676402), head `58f3be41de08c07c1f3d495803f67874126fc71a`.

Core cases:1280×720/DPR1,1920×1080/DPR1,375×667/DPR2 and390×844/DPR3, using the identical domain-earned mature save. Each covers actual jobs/equipment navigation and fresh warehouse/jobs/equipment screenshots. Real mouse/touch restored-paused → running → paused captures passed at1280 and375. Explicit pause stopped progression.

- 1280×720 warehouse height:360→532px (50.00%→73.89% of window height).
- 1920×1080:720→892px (66.67%→82.59%).
- 375×667:307px unchanged;390×844:484px unchanged.

The immutable visual baseline is `0f39e620`, captured in [run37739915938](https://github.com/48wr9f4wgp-lab/Logistics-Boss/actions/runs/37739915938). Baseline reuse verified identical encoded fixture SHA256 `08902ee2598040a4f89159bdaf8eaa004c9d23fc287ff86da36de474827debfd`.

Capture artifacts: [core pixels](https://github.com/48wr9f4wgp-lab/Logistics-Boss/actions/runs/37743676402/artifacts/11534464408), [core plus active/paused headers](https://github.com/48wr9f4wgp-lab/Logistics-Boss/actions/runs/37743676402/artifacts/11535276948). Artifact retention is seven days. Source/asset hashes and provenance are in `FLOTRA_NAVIGATION_ARTIFACTS_2026-10-08.json`.

## Product freeze and prospective qualification

- growth_hud.gd SHA256: `484355ef55341f42ab6cbfc80a61889e846efd7f090f0246a930b2018cb59f97`
- jobs_hud.gd SHA256: `11655fa895213f11f787f0a7c6dfe987cc98fb4b501cacb3679a6c912f4bd60c`

Focused native header/navigation proof passed7,931 checks with no warnings/errors, including1000px desktop minimum, mobile text/hit sizes, focus, held/canceled input, running/paused purchase locks and protected controls. It is separate from browser and physical-device qualification.

The final official local aggregate passed end-to-end:46 Godot suites and9 Node checks, plus import/fixture generation. Both readiness corrections passed within that same run. The earlier failed runs remain retained; exact-head browser, renderer and git-history CI are separate pending gates.

The PR preserves all existing13 expanded CI jobs and adds the full real navigation matrix as its own bounded qualification job. The preview-only matrix is not substituted for that full matrix. ABBA Results navigation selects the actually visible old or new UI path; original thresholds, fixed ordering and no-retry behavior remain unchanged.

Fresh official Godot4.7.2 export bytes are committed for browser testing. The new prospective manifest selects those bytes without modifying the historical readiness manifest. Export coherence retains the exact four-scene generated-node-ID allowlist, exact other resources, source/engine checks and strict non-PCK equality. No broader mismatch exception was added.

## Retained failed evidence and limits

- Run37739725548 failed diagnostic workflow validation before jobs. Its runner-local environment assignment was moved into a runner step.
- Run37739915938 stopped on a capture-only substring assertion: the visible fresh status is correctly 新しい倉庫. Exact source-owned text, typography and header bounds replaced the incorrect assertion.
- Run37741208897 captured baseline and desktop candidate screens, then exposed stale intro metrics in the harness. It now waits for the real expected next sheet before one actual click; no timeout increase or product workaround.
- Two local aggregate runs exposed test-time versus wall-clock waits in growth_hud_smoke at568×320 and review_phone_scale at390/430 DPR2/3. Their single-touch tests now wait for the existing dismissal guard to expire; product guards and input behavior were not changed. Both focused corrections passed; failed logs remain retained.
- Existing BFCache coverage remains genuinely unverified unless the original desktop harness observes trusted `pageshow.persisted=true`. Exit2 remains blocked coverage, not a pass. Prior12 baseline/14 desktop hotfix results do not qualify this new PR.
- Chromium emulation does not establish physical Windows or iPhone/Safari behavior. Main merge/deployment requires separate approval after exact-head qualification.
