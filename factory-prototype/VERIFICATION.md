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
