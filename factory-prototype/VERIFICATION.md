# Verification — 2026-10-29

- Node domain suite: 10/10 passed; app syntax check passed.
- Cloud Chromium: first plate order accepted via UI; 12/12 parts finished; dispatch increased cash from displayed 4,816 to 7,616 and shipments to 1. Lathe placement by floor pointer reduced cash to 1,816; shaft order accepted for 1,400, displayed cash 414 after resumed wages. Actual worker animation and progress observed.
- Display reviewed at desktop and a 390×844 embedded viewport. Controls, order sheet and equipment placement checked. This is desktop Chromium at phone dimensions, NOT physical iPhone or touch hardware validation.
- Reload/navigation restored first-order progress mid-production. Model suite separately proves exact serialized continuation.
- Console review: observed browser-extension metadata errors; no application-origin errors in inspected log entries. This is not an exhaustive runtime-error guarantee.
- First-order duration differs slightly between .1-second domain stepping and browser frame stepping due to discrete worker handovers. No claim of byte-identical simulation between arbitrary frame rates.
- Native iOS, Safari, device heat/FPS/battery and user fun remain unverified. Initial visual design is provisional; old FLOTRA target is not inherited.

Scope remains the first playable factory. No existing game state modified. Repository commit and CI identify the delivered code; subsequent modifications require appropriately scoped checks.

## v0.2 — 2026-10-30

- Reproduced v0.1 inability to move the drill during an active order.
- 14/14 Node tests passed, including bounded drain of assigned stages, mid-order rearrangement followed by all 28 parts completing, material collision rejection, conserved per-stage counts and ready-second-order dispatch priority.
- Cloud Chromium at 390×844: reloaded a v0.1 in-flight save; requested drill movement with 0/12 complete; two assigned stages finished and the order paused at 00:18 with 12 remaining parts distributed across stages. Clicked highlighted floor, drill moved, production resumed. Accepted a second 6-part order: sheet closed automatically and work continued. At screenshot capture the first order reached 4/12 with 3× active.
- Screenshot: evidence/forge-v02-mobile-20261030.jpg. Desktop Chromium at phone dimensions; not physical iPhone validation.
- Save schema, namespace, prices and payouts unchanged. Additional no-new-assignment option defaults to original simulation behavior.

## v0.3 — 2026-10-30

- 21/21 Node model tests passed; app and model syntax checks passed. New coverage: receipt reconciles actual cash/payroll and excludes investment; finished orders stop accruing wages; two orders split payroll once; zero funds; idempotent shipment; legacy in-flight continuation; immutable bounded history; same-offer matching; invalid optional accounting data rejection. Existing serialized-mid-job test also covers new measurements.
- Controlled model comparison (same fresh state, 28-part bulk order, dt=.1): initial layout 250.2 seconds / 722 tiles / ¥175.14 wages / ¥4,424.86 contribution; drill moved to (3,1), inspection to (4,1): 205.9 seconds / 338 tiles / ¥144.13 wages / ¥4,455.87 contribution. No price, wage rate, routing or skill formula change. These are model measurements, not real-device timings or evidence of player fun.
- Cloud Chromium at 390×844: resumed the earlier v0.2 save and shipped both old orders. Their receipts showed actual payment/material and explicit unmeasured history, without invented profit. Accepted a new measured order through the ordinary order sheet.
- Backed up the ongoing local QA state via the existing export control (forge-save.json, validator passed). Loaded a deterministic model-generated fixture via the ordinary import chooser: one shipped 12-part order and a second at 11/12 after layout improvement. Browser completed the last part and dispatched: +¥2,133 displayed contribution, ¥67.2 wages, 96.0 seconds, 152 tiles, 0 rework; previous-result comparison 18.6 seconds and 154.0 tiles shorter, +¥13 contribution. The earlier portion of this comparison was model-produced; it is not an end-to-end real-device playthrough.
- Reloaded and opened 経営: both history records persisted, and the latest result reopened with the same amounts. Result → 設備に投資 opened equipment correctly. Screenshot evidence/forge-v03-results-20261030.jpg shows all three next-action controls within 390×844 after increasing only the result sheet height.
- Observed and fixed the existing fractional-deadline display mismatch: Math.ceil could display 0 seconds remaining and full pay while actual dispatch applied the 15% deduction. UI and dispatch now share the same quote; a boundary test covers the exact due time and .01 seconds late.
- Existing save version/key and all economic rules remain unchanged; optional order accounting/results are added. Native iPhone/Safari, heat/FPS, player fun and production greenlight remain unverified.

## v0.4 — 2026-10-30

- 27/27 Node model tests passed; app syntax passed. New tests cover non-mutating rejection/read-only qualification, upgrade OR extra-drill volume eligibility, both lathe AND skill-3 precision eligibility, natural-experience qualification, insufficient materials/full slots, accepted-contract continuation after a qualifying drill is sold, both new orders serialized mid-job and paid exactly once, and investment effect on actual deadlines/rework.
- Controlled .1-second model runs, fresh workers and original layout: rush with only drill Lv.2 took 209.8 seconds (late, ¥6,120 payout); adding cutter/inspection Lv.2 and drill Lv.3 took 197.2 seconds (on time, ¥7,200 payout). Eligibility alone is deliberately not a guarantee. Fictional challenge balance, not a physical-device timing claim.
- Precision with a lathe at (4,3), one skill-3 inspection-priority worker: 126.5 seconds, 7 reworks. All three at skill 3: 100.6 seconds, 0 reworks. Both fit the 150-second deadline when dispatched promptly. No skill/processing/wage formula or existing offer changed.
- A saved v0.3 QA state with 2 orders/2 receipts validated without mutation. Browser resumed the v0.3 save at ¥9,752 and two shipments. 成長案件 initially showed both routes unavailable. The volume equipment link opened equipment, drill Lv.1 → Lv.2 displayed the qualification notice, and the 28-part rush contract accepted for ¥1,800 and started production. Progress reached 16/28 through normal browser simulation. Reload preserved the in-flight contract and volume qualification; the precision contract remained locked with its missing requirements shown. Full dispatch/save and precision eligibility/outcome are covered by the model tests above.
- A leftover local QA tab triggered the existing storage-conflict guard during the first upgrade attempt. Closed that prior agent-created tab and reloaded; the guarded attempt had not purchased the upgrade, then the single-writer upgrade succeeded. No user production data was reset.
- Physical iPhone/Safari and player fun remain unverified. Browser checks are desktop Chromium at 390×844; screenshot evidence/forge-v04-growth-20261030.jpg.

## v0.5 — 2026-10-30

- 31/31 Node tests passed (27 existing model tests, 4 screen-geometry regressions); app syntax and diff whitespace checks passed. New cases cover raised machine faces missed by floor-only picking, pan/zoom, label and foreground overlap, bounded edge tolerance and distant misses. No model, economy or save-format changes.
- Cloud Chromium at 390×844 resumed the v0.4 QA save. A stage button selected the drill without opening a modal; tapping the visible inspection-table body switched the card to inspection. Direct upgrade changed inspection Lv.1 → Lv.2, reducing displayed cash from ¥6,344 to ¥4,844. Details showed that selected inspection table first.
- The selected cutter displayed its actual assigned worker and remaining dotted walking route. Quick Move finished only assigned stages, exposed valid floor cells and disabled speed/stage controls. Clicking a valid cell moved the cutter from (2,1) to (3,3), resumed production and recentered it above the card. Cancel also resumed, and details retained (3,3).
- Purchased a second cutter through normal placement (¥2,600). The card identified it as 2/2; repeated stage selection cycled to 1/2, with the corresponding worker and outline. After zooming and dragging, tapping the other cutter’s label selected 2/2 correctly. Enter on the stage button switched back to 1/2. Stage DOM buttons persist across periodic updates so focus is retained.
- Screenshot evidence/forge-v05-machine-20261030.jpg shows the selected cutter, actual remaining route, shared stage counts and direct actions. Captured while manually paused for legibility; selecting a machine itself does not pause simulation. Initial waiting/carrying/working counts are explicitly for the machine kind, not a claim that this particular machine is the throughput bottleneck.
- Inspected warning/error entries were browser-extension metadata errors, not application-origin errors; this is not an exhaustive runtime-error guarantee. This is Chromium at phone dimensions, not physical iPhone/Safari/touch performance or player-fun validation.
