# マチコバ！ v0.10 — 出荷から次の成長へ

Title-local / 2026-10-31 / existing development Pages / bounded gameplay guidance pass

## Goal and observed gap

Connect the existing first order, shipment, investment and growth contracts. The current result screen sends every shipment to ordinary orders and does not identify a growth-contract delivery. The first order is also not distinguished from other offers. Improve this transition before adding more game systems.

## Scope

`docs/forge-preview/guidance.mjs` (read-only guidance), `app.mjs`, `style.css`, `index.html`, focused guidance tests and current prototype documentation. Preserve the current v0.9.2 workshop art and main-screen dimensions. Current visual inspected: `machikoba-v092-mobile.jpg`; no new art target or native production decision.

No new products, rewards, permanent achievements, automatic purchases, save fields, economic or scheduling changes. Existing title, save key, JSON format and import/export behavior continue.

## Acceptance

- Before the first shipment and with no active order, highlight the available 12-piece order. If its material cost is unaffordable, recommend existing zero-material recovery work instead. Do not offer a new job ahead of an active one.
- The result screen identifies first ordinary shipment or growth-contract delivery and distinguishes on-time shipment from the existing 15% late deduction. Do not infer a first-ever growth achievement from the rolling 12-report history.
- Show the next action near the profit summary, before optional detailed accounting. Guide ordinary shipments toward existing growth plans; respect a selected goal and current preparation/material budget.
- An unfinished or ready second order takes priority over starting another job. Skipping remains an explicit button with the normal wage/deadline explanation; dispatch continues to use model validation.
- Growth results offer another attempt at that contract and a route to choose the next goal. Opening a plan changes neither the selected goal nor money. Late growth results first offer equipment/layout review.
- Existing reports without a recognized offer and old saves remain usable. Read-only guidance changes no simulation or saved state. Result views can be reopened after reload.
- At 320/390px and short mobile heights, primary result actions remain visible/reachable and no horizontal overflow is introduced. Existing receipt details and ordinary menu access remain available.

## Verification and recovery

Test meaningful state transitions: first-order/recovery recommendations; selected goal with/without funds; second order producing/ready; on-time/late growth delivery; missing/legacy history; serialized continuation and read-only behavior. Run existing regression tests and module syntax checks. Verify the public mobile journey after CI, merge and the established development Pages deployment. Physical iPhone/Safari and enjoyment validation remain separate.

Base: `bd6da3c3d1ac85ed8c91e1106ddc8b911f84f641` (v0.9.2). Revert this UI/guidance change and redeploy to recover; saves require no conversion. The local API-materialized baseline has only harmless extra terminal newlines in several unchanged files; preserve them locally and exclude those files from this change.

## Pre-deployment verification

All 58 tests pass locally, including 11 new guidance cases. Changed browser modules pass syntax checks. Independent code review found no blocking issue in action re-evaluation, duplicate-payment protection, remaining-order priority, temporary plan focus, legacy reports or save compatibility. The simulation model, renderer, saved-state format and existing test files are unchanged. Public mobile verification follows the normal CI/merge/Pages workflow and is not claimed by these local checks.

## Public verification and progress

- Code delivered through PR #181; verified code commit `f9683d1be3569623e6c03cd2ab01faaf01fbd8c1`. PR CI, main CI and development Pages deployment succeeded.
- A fresh isolated public-browser session completed the actual opening order, skip, dispatch, growth-goal selection, drill upgrade, growth acceptance, completion and dispatch. First profit was displayed as +¥2,119.
- Result primary actions were visible at scroll position zero at 390×844, 320×740 and 375×667. No horizontal overflow. Root also inspected the captured first-result image.
- The natural first rush attempt was late under the unchanged model and correctly displayed the 15% deduction, equipment/layout review and retry. A separate isolated state built with the public model confirmed the on-time growth result. Retrying a delivered rush contract while the selected goal was precision opened rush first without spending or changing the selected goal.
- With another order active, the result offered explicit completion skipping. The remaining 28 pieces finished and stopped awaiting shipment; no automatic dispatch occurred. Page errors were zero; the normal journey also had zero console errors.
- Evidence: `evidence/machikoba-v010-first-result-20261031.jpg` and `evidence/machikoba-v010-browser-20261031.json`. These are public Chromium observations, not a physical iPhone/Safari session.

ACTIVE_PHASE: VERTICAL_SLICE / device feedback pending. LAST_VERIFIED_DONE: v0.10 shipment-to-growth guidance and the bounded public journeys above. BLOCKED: none for this change. NEXT: use the current first-shipment-to-growth loop for a short iPhone play session and assess whether the investment choice is clear and worth repeating before expanding game content. Production decision remains UNDECIDED; no native release or enjoyment validation is implied.
