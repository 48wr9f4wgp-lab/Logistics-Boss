# 町工場 / FORGE — v0.9

New title-local gameplay prototype, approved 2026-10-29. Current task replaces the FLOTRA concept; historical FLOTRA code and saves remain untouched. Production target remains iPhone/iOS. This browser build is an engineering preview, not a native release or production-engine decision.

## Play

Existing development Pages: `/Logistics-Boss/forge-preview/`.

1. Open 受注 and accept 町の金物店 (12 plates).
2. Accepting closes the sheet and starts production. Tap 完成まで進める on the factory board to skip the waiting, or watch at 1×/3×. Wages and deadlines still advance; the button warns about both. The next completed order automatically pauses time and offers 出荷する. 注文一覧 remains available beside it.
3. Tap 出荷する to collect payment and view a receipt: material, actual wages, profit before investment, production time, travel and rework. Money is paid only once. The result screen pauses time and links to the next order, equipment or workers.
4. Choose more machinery, worker training, expansion, or a lathe to unlock shafts. 成長案件 shows two next contracts and links to missing equipment/training.
5. Move/install equipment during an order: select 設備 → 移動/設置場所. Workers finish only their assigned stages, then pause. Tap a highlighted empty floor tile; production resumes automatically. Cancel also resumes. The 工程待ち buttons select machinery directly. The floating card shows its worker plus shared waiting/carrying/working counts for the machine kind; the floor highlights the assigned worker’s actual remaining route. Move, upgrade or open details from that card. Repeat the same stage button to cycle through multiple machines of that kind. Selection alone does not pause production.

Menus pause time. Drag the floor to pan; use +/- to zoom. Repeated low-value customer-material jobs allow recovery without material funding. A late order loses 15% of its payout, with no escalating penalty. Work and costs stop while the page is hidden. No offline earnings.

## Implemented

Two products/three stages, shared finite machines, three persistent workers, routed movement, deterministic skill/quality adjustment, simultaneous contracts, material purchase, wages, dispatch, machine purchase/upgrade/move/sale, training/experience/mentoring, 8×6 → 10×8 expansion. Independent `forge.factory.v1` saves with validation, export/import and an exclusive Web Lock where supported. Fallback revision guard cannot provide atomic cross-tab guarantees on browsers without Web Locks.

## Workshop visuals (v0.9)

The factory now uses an original illustrated workshop renderer: high cutaway walls, steel columns, windows and window light, concrete joints, wear, cast shadows, a tool cabinet, material pallets and a small delivery truck. The cutter, drill press, lathe and inspection bench have distinct mechanical shapes and materials. Levels 2/3 add guards, panels and hardware to the actual equipment. Workers share a depth-sorted drawing pass with machinery; walking, carrying, machining, drill feed and cutting sparks follow the real simulation state. Paused play and the system reduced-motion preference freeze the animated details.

The mobile shell gives more space to the factory and uses compact controls and consistent drawn icons. Equipment labels are optional through the tag button and remain visible for the selected machine. The frame button restores the overview and clears the selection. Stage buttons remain an alternative to touching the small machine drawings. Label hit testing follows the final overlay order, so a visible label selects its own machine even when it overlaps another body.

Rendering reads the existing state without changing it. Static surroundings are cached, drawing is capped at 30 frames/second, and the existing fixed simulation ticks run independently. No art/CDN downloads or additional runtime dependencies. The save schema, key, model, prices and scheduling are unchanged. Existing v0.8 in-flight saves remain supported.

## Growth orders

Both investment paths remain open. Eligibility is checked against the current factory every time a new order is accepted; no irreversible specialization.

| Contract | Prerequisites | Batch / quality | Material → payout | Deadline |
| --- | --- | --- | --- | --- |
| 短納期プレート | Drill level 2+, or two drills | 28 plates / 1 | ¥1,800 → ¥7,200 | 200 seconds |
| 高精度シャフト | Lathe and one worker at skill 3+ | 10 shafts / 3 | ¥2,200 → ¥8,800 | 150 seconds |

The quantity of the rush order matches ordinary bulk orders, but the deadline is 90 seconds shorter. Invest beyond the minimum and improve routing for more delivery margin. Quality-3 shafts reward skilled inspection; insufficient skill plus inspection-machine level causes the existing 2.5× rework duration. Natural experience or paid training can meet the skill condition. Current equipment and concurrent jobs still affect actual results; qualification is not a delivery guarantee.

The home-screen entry and order menu open 成長案件. Fulfilled requirements receive checkmarks, missing requirements link to equipment/workers, and the accept button stays disabled for unmet requirements, insufficient material funds or full order slots. Selling a qualifying drill closes future acceptance but does not remove an already accepted contract. Existing four offers and zero-cost recovery work are unchanged.

v0.1–v0.3 saves continue unchanged. Saves containing new offer IDs/quality 3 require v0.4 or later; export before any rollback and retain a pre-update backup for older versions.

## Growth goal and preparation plan (v0.6)

成長案件 → この目標を追う pins either contract to the factory HUD and persists it across reloads. It is a guide, not an exclusive specialization; all other contracts and normal equipment/worker controls stay available. The selected goal sorts first when reopened.

Plans show remaining equipment/training costs plus the separate material cost. Rush uses the cheaper qualifying drill upgrade when needed; precision uses a missing lathe and paid training for the currently highest-skilled worker. Natural skill growth or an alternative qualifying second drill reduces the remaining budget. Fresh-state totals: rush ¥1,500 preparation + ¥1,800 material = ¥3,300; precision ¥5,800 lathe + ¥2,400 training + ¥2,200 material = ¥10,400. These exclude ongoing wages and additional throughput investment; eligibility does not guarantee on-time delivery.

If funds are insufficient, the next action opens ordinary orders (including zero-material recovery work). Otherwise it offers the next priced upgrade, placement or training, then acceptance. No money is automatically reserved or spent by the guide. Every transaction uses the existing validation. Two occupied order slots direct to current orders. An active target contract takes priority over preparing another: show production, or ship the ready order and open its actual receipt. If two target orders are active, a finished one takes precedence. After dispatch, the same goal remains available for another run; there is no invented permanent achievement or bonus.

The optional `goalOffer` accepts only `rush`, `master`, null or absence. Old saves continue; v0.5 ignores the field and remains compatible. Existing v0.4 restrictions for newer contract IDs still apply to earlier rollback targets.

## Skip waiting (v0.7)

The production board's primary action changes with the order: 注文を見る → 完成まで進める → 出荷する. Skipping processes the actual workers, travel, machinery, quality, payroll and experience; it neither grants free production nor dispatches automatically. It stops at the first ready order, even with two contracts running. A ready order prevents further skipping, including after reloading, when playback starts paused. Ship it to continue the other order.

Normal playback and skipping now share fixed 0.05-second simulation ticks. The normal frame loop carries sub-tick remainder; the skip loop executes at most 100 ticks per frame so input can be handled between chunks. Pause/stop, a menu, placement, hiding the page or a save/writer problem ends skipping. A 1,200-game-second ceiling stops a stalled job with a message; partial work is retained. No offline work or new save fields. Reopening an unfinished order resumes ordinary playback, never an unattended skip.

The scheduling algorithm is unchanged; using one timestep removes the old frame-rate-dependent outcome differences. Historical .1-second model benchmarks and pre-v0.7 browser receipts are therefore not exact comparisons against v0.7. Qualification alone still does not guarantee delivery; equipment and layout interact through shared worker scheduling.

## Investment feedback (v0.8)

設備 shows the current and next-level per-piece processing times, plus the cash remaining after the priced upgrade or the funding shortfall. Reference times use skill 1, no quality adjustment, and exclude transport and waiting for a worker. Inspection upgrades also show the supported quality at skill 1. New-machine cards show the reference time and actual purchase cost. At the level cap there is no invented next price or upgrade.

職人 shows the current and next-skill times against one existing machine of each kind, with that machine's level shown. Mentoring's processing penalty is included when enabled; quality adjustment is excluded and the supported inspection quality is shown separately (up to current contract quality 3). When several machines of a kind exist, the first installed machine is the reference; this is not a forecast of the worker's next assignment. The skill cap and insufficient funds disable training. Upgrades, training and new placements also keep their existing model-side validation.

Both previews call the exact processing calculation used for actual job assignment. Improvements take effect at the next assignment; an already assigned job retains its stored processing duration. This does not guarantee faster total-order completion: travel, work allocation, quality and concurrent orders remain relevant.

The factory floor labels each machine's level and adds one/two gold reinforcement marks at levels 2/3. Its direct card keeps a short processing comparison; full funding/quality details live in the equipment panel. Stage selection recenters the machine above the card after layout settles. At 390×844, the selected-card floor minimum is 326px so the footer and bottom controls remain within the viewport. All save fields and economic/production rules remain unchanged.

## Order results

Repeat the same offer to compare with its previous measured result. 経営 keeps the last 12 receipts. Actual payroll is split equally among unfinished orders each tick; no additional wages are charged for the receipt. Production time ends at completion, while the existing deadline still applies at dispatch. Investment costs are reported separately in cumulative expenses. Comparisons reflect all conditions, including concurrent orders and worker growth, and do not prove a specific investment caused the change.

Existing saves continue. Orders accepted before v0.3 show payment/material but explicitly lack measured wages, profit and production statistics. The next accepted order is measured from the beginning. Optional accounting fields retain schema 1 and the save namespace.

## Verification

Run `node --test factory-prototype/tests/*.test.mjs` and syntax-check `app.mjs`, `workshop.mjs` and `view.mjs`. Forty-seven tests cover shared processing calculations, investment costs/in-flight work, completion skipping, fixed-tick equivalence, bounded interruption/resumption, growth budgets, goal persistence, active-order guidance, screen-space picking and label overlays, payouts, competing orders, actual efficiency changes, insolvency recovery, placement rejection, mid-job serialized continuation, purchases/expansion/sale and malformed saves. Local v0.9 verification also rendered fresh, working, upgraded and expanded factories through NAPI Canvas, comparing paused/reduced-motion frames and confirming that rendering leaves state unchanged.

Initial simulated order at the shared v0.7 tick: 115.4 game seconds, 12 completed parts, cash ¥4,819.22 before ¥2,800 payout (starting ¥5,500, material ¥600). This is deterministic model evidence, not a measured iPhone session. Cloud-browser interaction evidence is recorded separately in VERIFICATION.md.

## Limits

Original procedural isometric workshop graphics. No native iPhone/Safari performance validation, no user fun/retention validation, no market qualification or production greenlight. No breakdowns, outsourcing, multiple buildings or custom brands yet. Native iOS engine/build route remains a subsequent decision, not inferred from the old game. All graphics are original code-generated geometry; no third-party art or CDN dependencies.

