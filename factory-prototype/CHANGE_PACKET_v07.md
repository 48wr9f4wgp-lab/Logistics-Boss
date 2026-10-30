# FORGE v0.7 — 待ち時間を飛ばす
Title-local / 2026-10-31 / engineering preview

User feedback: 「テンポは悪いかな。待ちが多いな」。受注後に判断できることが少なく、生産を眺める時間が長い。
Goal: 工場の生産ボードから「完成まで進める」を選び、次の出荷・投資判断へすぐ移れる。
Scope: forge-preview model/app/style/index, scoped tests/docs/evidence. Existing development Pages only. No new offers, prices, save fields, art or native-release decision.

Acceptance:
- 生産中のボードに完成まで進める主操作、通常注文への副操作。人件費・納期も進むことを押す前に表示。
- 通常再生/早送りとも同じ固定時間刻みで実際の移動・加工・技能・人件費を計算。設備/配置/品質の差を保つ。従来のフレーム依存による所要時間の差は解消する。
- どれか1件が完成した時点で停止し、手動出荷へ。完成済みなら時間を進めない。自動報酬や重複支払いなし。
- 処理をフレームごとに小分けし、停止操作を残す。上限に達したら途中状態で停止。非表示・メニュー・配置・保存異常/閲覧専用では進めない。
- 既存セーブから継続可能。途中停止/再読込も通常の保存を使う。

Checks: normal-vs-fast identical state, stop at first ready/idle, payroll/conservation/payout, two orders, mid-job reload, zero funds and efficiency differences; full existing tests and syntax; Chromium 390×844 accept → skip → ship → receipt and reload. Current visual baseline evidence/forge-v06-goal-20261031.jpg viewed. Review actual factory board before finishing UI.
Rollback: revert this PR and redeploy existing development Pages. Save schema/key unchanged. v0.6 resumes these saves, with its previous frame-dependent timing. Physical iPhone and fun are not verified by the automated/browser checks.
