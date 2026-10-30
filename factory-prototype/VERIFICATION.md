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
