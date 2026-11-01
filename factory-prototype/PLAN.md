# マチコバ！ — first playable slice

Confirmed public title: マチコバ！ / tagline: 小さな工場、大きな夢。 User decision: 2026-10-31. Previous working title: FORGE / 町工場. See `NAMING_DECISION_2026-10-31.md`.
Title-local, 2026-10-29. User-approved new concept; old FLOTRA development is superseded for this task, preserved unchanged.

Goal: touch-first factory placement, orders, actual worker routing/production, dispatch, reinvestment and worker training, with two investment directions. iPhone remains intended production target. This dependency-free Canvas/DOM build is a bounded engineering/gameplay prototype, not a production engine decision or a native iOS build. Production decision UNDECIDED; release approval NOT_REQUESTED. Existing repository and development Pages only.

Scope: docs/forge-preview; factory-prototype; scoped CI. No legacy save, economics, branch or source changes. Revert added files to roll back. Independent save namespace, validation and export/import; no offline billing. Saved state never overwritten on invalid data. Web Locks exclusive writer where supported, storage revision conflict guard otherwise.

Acceptance: two simultaneous orders share finite machine capacity; routing/layout and skill affect completion time; materials cost on acceptance; dispatch pays once; purchases cannot overspend; expansion and training alter capability; unsuitable placements reject; interrupted jobs restore consistently; no mutation in background; mobile controls usable. Domain tests plus actual browser journey/visual review. Native iPhone performance/fun remain unverified.

Initial slice: plates and precision shafts, cutter/drill/inspection and purchasable lathe, three workers, expandable floor. Quality rework is deterministic and explained. Training/mentoring included; external contracting, breakdowns, brands and multiple buildings deferred. Numbers are fictional balance parameters.

## 第1版の完成条件（決定・2026-11-01）

**ゲームのクリア**　短納期プレート28個を200秒以内、または高精度シャフト10本を150秒以内に実際に出荷したら最初のエンディング。受注や製作完了だけでは達成にならない。同じ工場で続行でき、他方の初達成はクリア後の目標。設備投資と紹介のどちらを使ってもよい。

**開発の範囲**　第1版の機能範囲はここで締める。残工程を (1) 初達成の記録と出荷票、(2) 初見プレイとiPhone実機の確認、(3) そこで観測した迷い・待ち・操作ミスの修正と再確認、に限る。App Storeに向けた製品化は別の判断。

| v1.0プレイアブルの判定項目 | 確認すること |
|---|---|
| 初達成 | 両ルートで最初の納期内出荷を保存。再起動、再受注、もう一方の達成、履歴12件超えでも最初の記録が残る |
| 初見の人（未確認） | 口頭説明なしで初出荷。仮置きを自分で選び、選んだ理由を本人が説明できる |
| iPhone実機（未確認） | 初出荷からいずれかの初達成まで。文字・床タップ・所要時間・早送り・中断復帰・資金と出荷記録を確認 |

2026-10-30 / v0.4 extension: two growth contracts reuse the existing products and investment systems. Drill upgrade/addition opens short-deadline volume work; a lathe plus one skill-3 worker opens quality-3 shafts. Both routes stay available. Requirements, fictional parameters and save-rollback limitation are recorded in README.md and CHANGE_v04_2026-10-30.md. No native production or art-target decision.

2026-10-31 / v0.6: selected growth contract, preparation/material budget, and state-based next action. See CHANGE_PACKET_v06.md. This completes the bounded guidance pass; before expanding content further, prioritize a short iPhone play session of accept → invest → deliver and collect concrete feedback on readability, decisions and waiting. No actual-device or fun greenlight yet.

2026-10-31 / v0.7: direct user feedback reported too much waiting. Added an opt-in completion skip with real costs and automatic pause at the next ready order. See CHANGE_PACKET_v07.md. No new game systems/content; this addresses the wait before the next decision.

2026-10-31 / v0.8: investment feedback shows actual per-piece processing and inspection effects before upgrade/training, remaining cash/shortfalls, and visible machine levels. See CHANGE_PACKET_v08.md. This is a decision/readability pass, not new content or a claim of proven fun.

2026-10-31 / v0.9: explicit player feedback rejected the placeholder graphics. Implement the approved stylized workshop direction in the playable development build: recognisable machinery, working people, light/materials, visible upgrades, and more mobile scene space. See CHANGE_PACKET_v09.md. This is the next visual iteration, not a native release or a claim that visual appeal has been validated by the player.

2026-10-31 / v0.10: connect the existing shipment loop to investment and growth goals. Highlight the first affordable order and give result-screen guidance based on remaining commitments, current goals and actual delivery status. Keep detailed accounting available without placing it before the next decision. See CHANGE_PACKET_v010.md. This is a bounded guidance pass with no new systems, rewards or saved state; device/fun validation remains open.

2026-10-31 / v0.11: the player liked the graphics and explicitly requested further polish. Keep the current miniature-workshop direction and refine material separation, window/contact lighting and real pickup/carry/working poses. See CHANGE_PACKET_v011.md. This locks the existing direction as the reference for refinement; it does not authorize an unrelated redesign or change the game model, native-production decision or device-validation status.


v0.12: The player reported too many places to look. One ticket on the floor now handles the common order, work, shipment and next-step journey. Optional controls and management live behind two named entries. Keep the approved workshop renderer and existing saves. Evaluate the next player impression on iPhone.

v0.13: Build a more legible, material-rich workshop around the v0.12 single work ticket. Use north-light roof bays, directional light on the slab, distinct machine silhouettes and a warm workbench behind the interactive miniature. Evaluate the scene at normal phone scale and after enlargement.

v0.14: Continue the visual pass by making workers, machine controls and material handoffs readable in motion. The walking direction and pose follow the existing job. In-process stock remains at its actual service cell until pickup. Verify mixed orders, reloads and equipment moves, alongside the normal mobile ticket.

v0.15: A commercial-quality art target for the main workshop. Bake original three-dimensional tool bodies, moving assemblies, crew, truck and rooms with a single lighting setup. Validate against the same shift in v0.14, including existing save paths, reduced motion and direct control selection. Physical iPhone review remains open.

v0.16: Finish the visual loop at dispatch with order-specific packed cargo and an interruptible departure. Then improve the floor interaction: pinch around the fingers, pan during placement, preview/commit or cancel, and preserve management navigation. Normal play still has one bottom ticket.

v0.17: Refine the approved daylight miniature at normal phone scale and close range. Frame the physical plinth and preserve the size of the crew and tools. Stage-specific workpieces, local work lights and material wear carry the visual story through production. See CHANGE_PACKET_v017.md.

v0.18: Turn the first paid shipment into an optional repeat order. Contrast a free layout change with a paid drill upgrade, show the actual service-cell trip in placement, and measure the next delivery against the player’s own previous receipt. The growth contracts remain directly accessible.

v0.19: Compare physical transfer distance with whole-order time, and compare the two 28-piece contracts before spending. Simulate the current factory on a disposable copy, support layout what-ifs, and carry the accepted estimate into the receipt for review.

v0.20: Make the precision path accessible through its first standard shaft contract. Let a factory name the inspector for one order, invest in training or inspection capacity, and check actual adjustments, earnings and skill growth at dispatch.

v0.21: Make simultaneous orders a concrete dispatch decision. A customer offers six supplied-material plates during a regular production run. Compare shared capacity, hold the decision until halfway, choose or revise the order of future tasks and assess both real shipments against the original single-order estimate.

v0.22: Let the player compose and undo several moves or swaps before charging for the repeat order. Compare legal locations for one selected tool under the same contract and show when shorter walking and earlier delivery lead to different choices.

v0.23: Turn time and travel into two distinct repeat-order commitments. Settle each against the real receipt. Completing both earns a continuing customer referral for the existing rush job, offering a layout-based alternative to equipment investment.

v0.24: Record the first on-time dispatch of each specialty and show the first as the ending. Both routes and the existing factory continue after the ending. Human and physical-device acceptance gates remain open.

v0.25: Address the reported tap-through loop. In delegated mode an accepted order plays through production and dispatch, stopping for a real inquiry or a new contract. No automatic purchasing, ordering or changes to production rules. Physical iPhone and first-time human tests remain open.

v0.26: Repair cached-page resume and transfer the writer lock when leaving or returning. Verify navigation/back during actual production, review and unconfirmed layout, another tab shipping while away, and a fresh automatic first-ending run. Physical iPhone and first-time human testing remain pending.
