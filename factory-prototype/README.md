# 町工場 / FORGE — v0.4

New title-local gameplay prototype, approved 2026-10-29. Current task replaces the FLOTRA concept; historical FLOTRA code and saves remain untouched. Production target remains iPhone/iOS. This browser build is an engineering preview, not a native release or production-engine decision.

## Play

Existing development Pages: `/Logistics-Boss/forge-preview/`.

1. Open 受注 and accept 町の金物店 (12 plates).
2. Accepting closes the sheet and starts production. Use 3× if desired.
3. Tap 出荷する to collect payment and view a receipt: material, actual wages, profit before investment, production time, travel and rework. Money is paid only once. The result screen pauses time and links to the next order, equipment or workers.
4. Choose more machinery, worker training, expansion, or a lathe to unlock shafts. 成長案件 shows two next contracts and links to missing equipment/training.
5. Move/install equipment during an order: select 設備 → 移動/設置場所. Workers finish only their assigned stages, then pause. Tap a highlighted empty floor tile; production resumes automatically. Cancel also resumes. The 工程待ち row shows waiting parts by next stage; tap it for carrying/working counts.

Menus pause time. Drag the floor to pan; use +/- to zoom. Repeated low-value customer-material jobs allow recovery without material funding. A late order loses 15% of its payout, with no escalating penalty. Work and costs stop while the page is hidden. No offline earnings.

## Implemented

Two products/three stages, shared finite machines, three persistent workers, routed movement, deterministic skill/quality adjustment, simultaneous contracts, material purchase, wages, dispatch, machine purchase/upgrade/move/sale, training/experience/mentoring, 8×6 → 10×8 expansion. Independent `forge.factory.v1` saves with validation, export/import and an exclusive Web Lock where supported. Fallback revision guard cannot provide atomic cross-tab guarantees on browsers without Web Locks.

## Growth orders

Both investment paths remain open. Eligibility is checked against the current factory every time a new order is accepted; no irreversible specialization.

| Contract | Prerequisites | Batch / quality | Material → payout | Deadline |
| --- | --- | --- | --- | --- |
| 短納期プレート | Drill level 2+, or two drills | 28 plates / 1 | ¥1,800 → ¥7,200 | 200 seconds |
| 高精度シャフト | Lathe and one worker at skill 3+ | 10 shafts / 3 | ¥2,200 → ¥8,800 | 150 seconds |

The quantity of the rush order matches ordinary bulk orders, but the deadline is 90 seconds shorter. Invest beyond the minimum and improve routing for more delivery margin. Quality-3 shafts reward skilled inspection; insufficient skill plus inspection-machine level causes the existing 2.5× rework duration. Natural experience or paid training can meet the skill condition. Current equipment and concurrent jobs still affect actual results; qualification is not a delivery guarantee.

The home-screen entry and order menu open 成長案件. Fulfilled requirements receive checkmarks, missing requirements link to equipment/workers, and the accept button stays disabled for unmet requirements, insufficient material funds or full order slots. Selling a qualifying drill closes future acceptance but does not remove an already accepted contract. Existing four offers and zero-cost recovery work are unchanged.

v0.1–v0.3 saves continue unchanged. Saves containing new offer IDs/quality 3 require v0.4 or later; export before any rollback and retain a pre-update backup for older versions.

## Order results

Repeat the same offer to compare with its previous measured result. 経営 keeps the last 12 receipts. Actual payroll is split equally among unfinished orders each tick; no additional wages are charged for the receipt. Production time ends at completion, while the existing deadline still applies at dispatch. Investment costs are reported separately in cumulative expenses. Comparisons reflect all conditions, including concurrent orders and worker growth, and do not prove a specific investment caused the change.

Existing saves continue. Orders accepted before v0.3 show payment/material but explicitly lack measured wages, profit and production statistics. The next accepted order is measured from the beginning. Optional accounting fields retain schema 1 and the save namespace.

## Verification

Run `node --test factory-prototype/tests/model.test.mjs` and `node --check docs/forge-preview/app.mjs`. Twenty-seven tests cover payouts, competing orders, actual efficiency changes, insolvency recovery, placement rejection, mid-job serialized continuation, purchases/expansion/sale and malformed saves.

Initial simulated order: 114.6 game seconds, 12 completed parts, cash 4,819.78 before 2,800 payout (starting 5,500, material 600). This is deterministic model evidence, not a measured iPhone session. Cloud-browser interaction evidence is recorded separately in VERIFICATION.md.

## Limits

Early procedural isometric graphics. No native iPhone/Safari performance validation, no user fun/retention validation, no market qualification or production greenlight. No breakdowns, outsourcing, multiple buildings or custom brands yet. Native iOS engine/build route and art target remain subsequent decisions, not inferred from the old game. All graphics are original code-generated geometry; no third-party art or CDN dependencies.
