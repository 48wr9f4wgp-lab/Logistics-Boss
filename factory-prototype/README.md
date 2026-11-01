# マチコバ！ — v0.22

**小さな工場、大きな夢。**

Official title **マチコバ！** and tagline **小さな工場、大きな夢。** confirmed by the user on 2026-10-31. See `NAMING_DECISION_2026-10-31.md`. FORGE / 町工場 were working titles; historical files and technical identifiers retain their previous names for continuity.

New title-local gameplay prototype, approved 2026-10-29. Current task replaces the FLOTRA concept; historical FLOTRA code and saves remain untouched. Production target remains iPhone/iOS. This browser build is an engineering preview, not a native release or production-engine decision.

## Play

Existing development Pages: `/Logistics-Boss/forge-preview/`.

1. The ticket beneath the workshop shows the first job (12 plates), the payout and the material cost on the accept button. It starts the job here. If funds are short, the ticket offers the existing zero-material recovery job.
2. Watch the workers, or tap 完成まで進める to advance real work, wages and deadlines. The skip stops at the first completed order. Tap 出荷する on the same ticket to collect payment.
3. Shipment pauses playback and shows the actual profit and next step on the ticket. After the first measured 12-plate delivery, rearrange any installed machines or upgrade the drill and accept the same job again. The ticket compares actual time and travel after dispatch. A second unfinished order takes priority. 管理 → 経営と出荷記録 retains the detailed receipt, including legacy reports.
4. 管理 holds the order list, both growth paths, investments, training, finances and save tools. 操作 opens floor controls for playback, zoom, labels and stage selection. A machine can also be selected by tapping the floor directly. For a move, finish the current stages, tap a highlighted tile to preview the actual equipment, and confirm with the bottom button or cancel.
5. In a growth plan open 条件と費用の内訳 for the full budget and requirements. Both routes remain available.

Management sheets pause time. The floor controls and direct selection allow work to continue. Drag the floor to pan, or pinch with two fingers to zoom at their midpoint. These gestures also work during placement. Repeated low-value customer-material jobs allow recovery without material funding. A late order loses 15% of its payout, with no escalating penalty. Work and costs stop while the page is hidden. No offline earnings.

## Implemented

Two products/three stages, shared finite machines, three persistent workers, routed movement, deterministic skill/quality adjustment, simultaneous contracts, material purchase, wages, dispatch, machine purchase/upgrade/move/sale, training/experience/mentoring, 8×6 → 10×8 expansion. Independent `forge.factory.v1` saves with validation, export/import and an exclusive Web Lock where supported. Fallback revision guard cannot provide atomic cross-tab guarantees on browsers without Web Locks.

## 工場の配置を試す（v0.22）

初出荷の後に「工場の改善を選ぶ → 置き場所を試す」を開く。設備を選んで床をタップすると、同じ注文で現状と仮案の完成時間・総歩数・工程別の変化が出る。設備を切り替えて案を組み合わせたり、設備同士を入れ替えたりできる。「完成が最短」「歩数が最少」の候補は、その設備を動かせる床を実際の生産ルールで比較して選ぶ。[計算条件と実測例](CHANGE_PACKET_v022.md)

## 小口6個の相談（v0.21）

2件以上出荷した工場で、28個のプレートか10本のシャフトを単独で製作中に「＋6個の相談」が届く。先約だけの場合と二つの作業順を同じ開始状態から比べる。通常の早送りはそのまま使える。両方の出荷後は、単独見積に対する実際の利益差と両方の納期を出荷票で振り返る。[条件と実測例](CHANGE_PACKET_v021.md)

## シャフト10本の段取り（v0.20）

成長目標の精密ルートから、旋盤の仮置き、標準品での育成、高精度品への挑戦を進められる。仕事ごとに検品担当を指名し、現状・研修・検品台改良の見込と準備費を確認する。出荷記録には、その仕事で生じた品質調整と職人の昇級が残る。[実測例・確認範囲](CHANGE_PACKET_v020.md)

## 受注する前の見積（v0.19）

仮置きしたボール盤で、片道と12個全体の所要時間・移動を別々に見られる。28個の仕事は同じ工場から通常便と短納期便を見積もり、納期余裕と受注利益を比べて受ける。見積画面から移設を試して、確定後も受注条件を選び直せる。[実測例・計算条件](CHANGE_PACKET_v019.md)

## 初出荷後の工夫（v0.18）

最初の取付プレート12個を出荷したら「工場の改善を選ぶ」。ボール盤を仮置きして切断からの片道を見たり、改良で1個の加工時間を縮めたりできる。再受注時には材料費と選んだ投資をまとめて確認する。出荷票には前回の同じ注文との時間・移動差を表示する。進んだセーブは管理 → 注文一覧 → 前回の12個で改善を試すから利用できる（比較できる記録がある場合）。[実測例と確認範囲](CHANGE_PACKET_v018.md)

## 工場の昼光と加工の手元（v0.17）

工場の全景を台座まで表示する。穴あけ済みのプレートと段付きのシャフトは、トレーから手元に運んでも同じ形で追える。加工中の手元灯、窓越しの町並み、設備の鋳肌と職人の作業着を更新した。[同じ生産時刻の比較と確認範囲](CHANGE_PACKET_v017.md)

## Shipping and direct manipulation (v0.16)

The dock shows separate packaging for plates and shafts. A successful shipment immediately updates the account and briefly shows that order on the departing truck. [Four-second shipping view](evidence/machikoba-v016-shipping.mp4).

During placement you can try several cells before confirming the arrangement or purchase. The original location and cash are retained until confirmation. The bottom strip includes cancel and price. A two-finger pinch never selects a machine or a destination. With the floor focused, arrow keys cycle permitted locations and Enter focuses the confirm button. Inside 管理, ‹ 戻る returns to the preceding sheet and 工場へ戻る closes it.

## Lit workshop models (v0.15)

The initial and expanded shop, truck, three crew busts and all four machine types use original offline-rendered artwork. Static tool bodies cover levels 1–3. The 24 active poses per tool share a phase with the worker's hands. The live part is composited between the bed and the foreground mechanism. Only the currently needed floor size is fetched. [Same-shift visual comparison](evidence/machikoba-v015-production.jpg) · [Art pipeline and validation](CHANGE_PACKET_v015.md).

## Crew at work (v0.14)

Workers turn towards their next path cell, carry the actual blank after collection, and use the controls on the operator side of the machine. Idle parts between stages appear in small totes at their saved pickup cells. This applies to plates and shafts, including simultaneous orders and restored saves. The work ticket remains the same. [Ten seconds of production](evidence/machikoba-v014-work.mp4) show the ordinary plate order at 1× simulation speed and 1.75× camera zoom.

## The workbench miniature (v0.13)

The workshop sits on a walnut display base in a window-lit atelier. A single bundled WebP provides the workbench behind the transparent canvas. The navigable factory, roof bays, steelwork, lighting, stock, four kinds of machinery, crew and truck are painted from the game in real time or cached as static scenery. The raised drill, saw guard, people and machines use the same floor anchors as before. The renderer uses the enlarged machine projection for tap targets and labels. See [the visual change record](CHANGE_PACKET_v013.md).

## Workshop visuals (v0.9)

The factory now uses an original illustrated workshop renderer: high cutaway walls, steel columns, windows and window light, concrete joints, wear, cast shadows, a tool cabinet, material pallets and a small delivery truck. The cutter, drill press, lathe and inspection bench have distinct mechanical shapes and materials. Levels 2/3 add guards, panels and hardware to the actual equipment. Workers share a depth-sorted drawing pass with machinery; walking, carrying, machining, drill feed and cutting sparks follow the real simulation state. Paused play and the system reduced-motion preference freeze the animated details.

The mobile shell gives more space to the factory and uses compact controls and consistent drawn icons. Equipment labels are optional through the tag button and remain visible for the selected machine. The frame button restores the overview and clears the selection. Stage buttons remain an alternative to touching the small machine drawings. Label hit testing follows the final overlay order, so a visible label selects its own machine even when it overlaps another body.

Rendering reads the existing state without changing it. Static surroundings are cached, drawing is capped at 30 frames/second, and the existing fixed simulation ticks run independently. No art/CDN downloads or additional runtime dependencies. The save schema, key, model, prices and scheduling are unchanged. Existing v0.8 in-flight saves remain supported.

## Workshop finish and real work poses (v0.11)

The player approved the existing miniature-workshop direction and requested more refinement. The scene now uses broader metal reflections and paint edges, restrained wood grain, window-light panes and mullion shadows, wall contact shading and layered shadows under machinery and people. The existing machine colors, factory framing, floor cells and interaction regions remain in place.

Workers have clearer proportions and short bent-arm poses toward their assigned machine. Their existing job path distinguishes walking to collect material from carrying it to the machine: hands stay empty before pickup, then show the actual plate or shaft. Work surfaces also show the assigned part only during processing, including drilled holes after the plate's drilling stage. The incoming pallet represents actual pending material; it is empty with no order and retains a reserved part until its worker reaches it.

`workerVisualState()` reads existing jobs and part positions without writing state or introducing a save field. Eight focused tests verify actual pickup/service arrival, consecutive stages, plate/shaft references, serialized continuation and safe fallback. Model, prices, scheduling, save format/key and gameplay guidance are unchanged. Same-state paused/reduced-motion render comparisons remain still, active work animates, and static scenery continues to reuse its cache. See `CHANGE_PACKET_v011.md` for the bounded visual comparison and verification scope.

## From shipment to the next goal (v0.10)

Before the first shipment, the available 12-piece order is highlighted above the other offers. The existing zero-material recovery order takes its place if the first order's material cost is unaffordable. Existing commitments always take priority.

The result screen identifies a first ordinary shipment or a growth-contract delivery, shows on-time/late status and actual profit, and places its next-action button before the optional accounting details. It uses current factory state: a remaining completed order is offered for dispatch; an unfinished order gets an explicit completion-skip button with the existing wage/deadline notice. Otherwise ordinary orders lead to choosing a growth goal or continuing the current goal's preparation/funding. Growth-contract results offer the next goal and a repeat attempt; late deliveries first point to equipment/layout review and clearly show the 15% deduction.

Repeat opens the actual delivered contract's preparation card without accepting it or changing the selected goal. Plans, receipts and ordinary menus remain available after reload. Reports without a known offer use ordinary guidance. No bonus, permanent achievement, new save field, automatic investment or new economic rule is introduced; the rolling receipt history is not treated as a permanent achievement ledger.

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

Run `node --test factory-prototype/tests/*.test.mjs` and syntax-check `app.mjs`, `guidance.mjs`, `workshop.mjs` and `view.mjs`. Sixty-six tests cover actual worker pickup/carry/work boundaries, read-only shipment guidance and legacy reports, first-order/recovery recommendations, shared processing calculations, investment costs/in-flight work, completion skipping, fixed-tick equivalence, bounded interruption/resumption, growth budgets, goal persistence, active-order guidance, screen-space picking and label overlays, payouts, competing orders, actual efficiency changes, insolvency recovery, placement rejection, mid-job serialized continuation, purchases/expansion/sale and malformed saves. Local v0.9/v0.11 verification also rendered fresh, working, upgraded and expanded factories through NAPI Canvas, comparing paused/reduced-motion frames and confirming that rendering leaves state unchanged.

Initial simulated order at the shared v0.7 tick: 115.4 game seconds, 12 completed parts, cash ¥4,819.22 before ¥2,800 payout (starting ¥5,500, material ¥600). This is deterministic model evidence, not a measured iPhone session. Cloud-browser interaction evidence is recorded separately in VERIFICATION.md.

v0.10 public verification is recorded in `CHANGE_PACKET_v010.md` and `evidence/machikoba-v010-browser-20261031.json`, with the first-result image in `evidence/machikoba-v010-first-result-20261031.jpg`. It covers the normal first-shipment-to-growth journey, on-time/late result guidance, retry without spending/changing goals, a remaining order's explicit skip, and narrow/short mobile result layouts. The tested code commit is `f9683d1be3569623e6c03cd2ab01faaf01fbd8c1`; physical iPhone/Safari remains unverified.

v0.11 public visual/interaction verification is in `CHANGE_PACKET_v011.md` and `evidence/machikoba-v011-browser-20261031.json`. Same-condition before/after and working images accompany that record. Tested code commit: `300b67c3457f79007c8320ead2025d596bfcf67b`. Pausing, reduced-motion settings, labels, direct selection, zoom/reset, relocation, skip and dispatch passed in isolated Chromium at 390×844. Local fixed-state renderer probes and eight pickup/carry boundary tests complement this; they do not establish physical iPhone performance.

## Limits

Original procedural isometric workshop graphics. No native iPhone/Safari performance validation, no user fun/retention validation, no market qualification or production greenlight. No breakdowns, outsourcing, multiple buildings or custom brands yet. Native iOS engine/build route remains a subsequent decision, not inferred from the old game. The factory uses code-generated geometry and the locally bundled, generated atelier backdrop.

