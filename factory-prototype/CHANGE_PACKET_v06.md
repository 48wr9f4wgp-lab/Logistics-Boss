# FORGE v0.6 — 成長目標と投資計画
Title-local / 2026-10-31 / engineering preview

Goal: 成長案件の条件表示から、必要資金を把握して設備・職人に投資し、受注・納品する流れへつなぐ。
Existing: 条件と受注可否だけを表示。設備/研修費と材料費を合わせた準備資金や、選んだ目標の追跡はない。
Scope: forge-preview model/app/style/index; tests; title-local docs/evidence。価格・納期・技能効果・旧FLOTRAは変更しない。

Acceptance:
- 量産/精密を任意に目標へ設定でき、再読込しても保持。他ルートを閉じない。
- 現在の設備・技能から準備費を算出。量産は受注資格を満たす安価な改良、精密は旋盤と最も研修費が少ない職人を案内。実務成長も反映する。
- 材料費を別に表示し、準備費との合計/不足額を計算。人件費・効率化への追加投資を含まない目安と明示。納期達成を保証しない。
- 足りない場合は通常受注、足りる場合は改良/設置/研修、条件達成後は受注を案内。実際の資金消費は既存操作を利用。
- 対象注文が進行中なら追加投資の案内より生産/出荷を優先。出荷済み・未受注を完了扱いしない。
- optional goalOfferのみ保存に追加。旧セーブを受入れ、不正な目標値を拒否。

Checks: model budget/action/save/order-state regression; existing model/view suite; Chromium 390×844 for goal selection, action, insufficient funds, acceptance, persistence. Current visual baseline: evidence/forge-v05-machine-20261030.jpg (viewed this turn). No new art target.
Rollback: revert this PR and redeploy existing dev Pages. v0.5 ignores the optional goal field; game progress remains readable. No native release authorization implied.
