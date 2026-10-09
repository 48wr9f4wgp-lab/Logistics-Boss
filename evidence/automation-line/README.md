# Connected automation line: draft review evidence

**Performance qualification is FAILED / cause unresolved. Do not merge or deploy based on this draft.**

Existing `auto_pack` (240, unlock after two jobs, 0.7 seconds) connects conveyor, sealing machine and transfer arm. The existing cargo node follows actual pack job progress; no additional shipment, simulation clock, economy, save key or schema change. Runtime changes are limited to `growth_view.gd` and the purchase description in `growth_sim.gd`. PR160 navigation, DPR, HUD and touch sizing remain unchanged.

## Review map

- `../../flotra-campaign/prototype/growth_view.gd`: connected geometry and actual cargo placement; cached mechanism updates; same 20 machine box meshes, one additional parent node.
- `../../flotra-campaign/tests/release/automation_line.gd`: 7,535 checks for actual purchase/progress, geometry, pause, reduced motion, four layouts and save compatibility; part of test.sh.
- `../../flotra-campaign/tests/release/browser_automation_line.cjs`: earned synthetic fixtures, 18 browser cases at 375/390/1280; source only, local screenshots excluded from this PR.
- `revision-2/aggregate-result.json`, `aggregate.log`, `source-before.json`, `source-after.json`: final single aggregate, 47 Godot suites + 9 Node checks, exit 0, unchanged source hashes.
- `revision-3/performance-blocker-followup.md`: authoritative follow-up, all 20 ABBA results and limitations, including correction of earlier A2 draw count (88).
- `performance-abba.json`, `revision-2/normal-abba/`, `revision-2/same-state-view/`, `revision-2/same-state-main/`, `revision-3/`: all successful and failed measurements, raw samples, fixed-state hashes, cgroup counters, runners and predeclared four-run plan. Historic runners intentionally retain original local paths; adapt them using the commands below.

## Reproduction

Use Godot **4.7.2**, confirmed with `"$GODOT" --version`. The saved environment's executable was `/workspace/.flotra-tools/bin/godot`; its default PATH Godot was 4.6.3. Use installed browser tooling; do not retry blocked downloads or bypass network restrictions.

```bash
export GODOT=/path/to/godot-4.7.2
bash flotra-campaign/test.sh
review_root=$(mktemp -d)
mkdir -p "$review_root/data" "$review_root/config" "$review_root/cache" "$review_root/line-fixtures" "$review_root/growth-fixtures"
XDG_DATA_HOME="$review_root/data" XDG_CONFIG_HOME="$review_root/config" XDG_CACHE_HOME="$review_root/cache" FLOTRA_LINE_FIXTURES="$review_root/line-fixtures" "$GODOT" --headless --path flotra-campaign --script res://tests/release/automation_line.gd
XDG_DATA_HOME="$review_root/data" XDG_CONFIG_HOME="$review_root/config" XDG_CACHE_HOME="$review_root/cache" FLOTRA_GROWTH_FIXTURES="$review_root/growth-fixtures" "$GODOT" --headless --path flotra-campaign --script res://tests/release/growth_browser_fixtures.gd
bash flotra-campaign/export_web.sh "$review_root/candidate"
python3 -m http.server 8765 --bind 127.0.0.1 --directory "$review_root"
```

Keep the server running; in a second shell use the same `review_root`, installed Playwright 1.62.1 (`NODE_PATH`) and existing Chromium (`CHROMIUM_EXECUTABLE`):

```bash
node flotra-campaign/tests/release/browser_automation_line.cjs http://127.0.0.1:8765/candidate/ "$review_root/line-fixtures" "$review_root/line-captures"
FLOTRA_JOURNEY_CASES=mature-performance FLOTRA_EXPORTED_DIRECTORY="$review_root/candidate" node flotra-campaign/tests/release/browser_growth_journey.cjs http://127.0.0.1:8765/candidate/ "$review_root/performance-B1" "$review_root/growth-fixtures"
```

For a new qualification series, separately check out immutable PR160 `027cb20d0bcd34fde6f944f4b3e7e63e21dc9b09`, export it to the temporary `control` directory using its own export script, then run the same mature-performance command in **A1/B1/B2/A2 order once**, changing URL/export directory and output label only. Predeclare environment and count; keep every failure; do not change thresholds. Never export into public docs for this review. Fixed-state diagnostic scene/runners are available in the source/evidence; they use the same synthetic late.json fixture (`benchmark-fixture.json` in isolated temporary project copies), and do not replace the production main scene.

## Results and distinct limitations

| Normal active run | CPU median/p95 ms | RAF median/p95 ms | Result |
|---|---:|---:|---|
| Revision 2 A1 | 37.7/55.6 | 233.3/283.3 | pass |
| Revision 2 B1 | 39.7/54.2 | 283.3/316.7 | **fail** |
| Revision 2 B2 | 35.4/77.0 | 233.3/283.2 | pass |
| Revision 2 A2 | 38.8/51.1 | 233.3/266.6 | pass |
| Follow-up A1 | 37.6/47.4 | 233.3/266.7 | pass |
| Follow-up B1 | 36.3/54.4 | 249.9/283.4 | **fail** |
| Follow-up B2 | 36.0/56.3 | 233.3/266.7 | pass |
| Follow-up A2 | 37.3/62.2 | 249.9/316.7 | pass |

390×844 DPR3, existing Chromium151, SwiftShader; fresh synthetic contexts. GPU timer unavailable. Failed median gate: revision2 B1 283.3 > max(75,150×1.75)=262.5; follow-up B1 249.9 > max(75,133.4×1.75)=233.45. CPU/draw and RAF-p95 gates passed. Fixed-state Main+autosave p95 A1/B1/B2/A2=45.1/45.2/43.8/43.3ms with matching ledger/save phases and draw counts. Those diagnostics do not override normal failures. CPU quota throttling and control variance were observed; implementation regression versus environment noise remains unresolved. Next qualification needs a dedicated hardware-GPU browser environment and target phone testing.

- New feature functional checks: local 47 suites + Node9 and 18 browser cases passed. CI results must be reported separately at this draft's exact head.
- New feature performance: two B1 failures remain unqualified; no threshold relaxation or success selection.
- Known PR160 limitation: real BFCache restoration remained unverified despite 13 jobs and desktop14 functional cases passing; historical aggregate CI was failure. No synthetic BFCache event is accepted as proof.
- Existing CI jobs reading `docs/godot-jobs-preview` test the unchanged public export, not this candidate's newly rendered line. Source aggregate tests exercise the candidate. No public export or workflow change is included.

Images, ZIPs and Library-transfer substitutes are deliberately excluded. All committed logs/data are synthetic test evidence. Real user saves were not accessed.
