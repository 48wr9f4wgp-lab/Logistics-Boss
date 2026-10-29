# 町工場 / FORGE — v0.1

New title-local gameplay prototype, approved 2026-10-29. Current task replaces the FLOTRA concept; historical FLOTRA code and saves remain untouched. Production target remains iPhone/iOS. This browser build is an engineering preview, not a native release or production-engine decision.

## Play

Existing development Pages: `/Logistics-Boss/forge-preview/`.

1. Open 受注 and accept 町の金物店 (12 plates).
2. Close the sheet; staff automatically carry and process parts. Use 3× if desired.
3. Tap 出荷する to collect payment. Money is paid only once.
4. Choose more machinery, worker training, expansion, or a lathe to unlock shafts.
5. Equipment installation/moving requires all workers to finish current work. Select 設備 → 設置場所, then tap a highlighted empty floor tile. Resume time with 1× or 3× after placement.

Menus pause time. Drag the floor to pan; use +/- to zoom. Repeated low-value customer-material jobs allow recovery without material funding. A late order loses 15% of its payout, with no escalating penalty. Work and costs stop while the page is hidden. No offline earnings.

## Implemented

Two products/three stages, shared finite machines, three persistent workers, routed movement, deterministic skill/quality adjustment, simultaneous contracts, material purchase, wages, dispatch, machine purchase/upgrade/move/sale, training/experience/mentoring, 8×6 → 10×8 expansion. Independent `forge.factory.v1` saves with validation, export/import and an exclusive Web Lock where supported. Fallback revision guard cannot provide atomic cross-tab guarantees on browsers without Web Locks.

## Verification

Run `node --test factory-prototype/tests/model.test.mjs` and `node --check docs/forge-preview/app.mjs`. Ten tests cover payouts, competing orders, actual efficiency changes, insolvency recovery, placement rejection, mid-job serialized continuation, purchases/expansion/sale and malformed saves.

Initial simulated order: 114.6 game seconds, 12 completed parts, cash 4,819.78 before 2,800 payout (starting 5,500, material 600). This is deterministic model evidence, not a measured iPhone session. Cloud-browser interaction evidence is recorded separately in VERIFICATION.md.

## Limits

Early procedural isometric graphics. No native iPhone/Safari performance validation, no user fun/retention validation, no market qualification or production greenlight. No breakdowns, outsourcing, multiple buildings or custom brands yet. Native iOS engine/build route and art target remain subsequent decisions, not inferred from the old game. All graphics are original code-generated geometry; no third-party art or CDN dependencies.
