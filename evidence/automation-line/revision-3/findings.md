# FLOTRA 性能ブロッカー追跡（追加診断）

ゲームコードとexportは変更していない。採用済み3機構と実荷物連動を維持。Libraryアップロード、外部転送、GitHub公開は実施していない。以前の成果物は保持し、本書は追補とする。

## 条件と計測の限界

既存16runに、事前宣言した通常プレイA1→B1→B2→A2の4runのみ追加。AはPR160、Bは改訂2。各runで新規Chromium/context、同じ合成fixture、CSS390×844、DPR3、1170×2532 backing、既存Chromium151＋SwiftShader。既存の準備待機・idle6秒・UI-only6秒・active12秒・idleAfter6秒・assertionを変更していない。通常試験のJSコピーだけが既存uiMetricsをRAFごとに保存する。アプリ側のexportを再生成・計測用改変していない。1秒ごとのcgroup/proc計測は全run共通。失敗runを含め4回で終了する。

通常CPUはGodot Performance.TIME_PROCESSを既存phone_qa経由で読む値。RAFごとの直接CPU計測ではなく、同じ値が繰り返される。固定viewはview.refreshの実時間、固定MainはMain._processの実時間であり、通常CPUとの絶対値比較はできない。RAFはCPU・描画・ブラウザの待ちを含むフレーム間隔でGPU時間ではない。GPUタイマー拡張の可否も確認するが、過去16runにはGPU時間測定はない。

## 実状態・イベント更新

- 過去改訂B1のfailure.lastには時刻115.25、出荷43、最終node1365が残る。対照A1/A2は117.15、出荷45、node1380。初期状態は全て時刻85、出荷31で一致するが、途中と最終状態は一致しない。
- growth_main.gdのMAX_FOREGROUND_FRAME_SECONDS=0.25とspeed=2により、250msを超す実フレームでは1frameあたりの正規進行が上限に達する。B1の状態差は遅いRAFの結果でもあり、状態差を遅延の原因と断定はできない。この時計処理は公開版と同じ。
- 固定Mainの保存phase2中央値はA1/B1/B2/A2=44.25/46.60/43.70/44.55ms、phase0=25.95/26.05/25.85/25.80ms（phase0はcommit後の行も含む）。保存や荷物イベントの出現位置がCPU分布を変え得る証拠。各phase2は4行なので大きな統計的推論はしない。
- 固定Mainで実際に梱包中の12行の対応CPU差平均はB1-A1=-1.717ms、B2-A2=+1.825ms。符号は一定しない。通常試験のtelemetryはMain処理前に公開され、以前のCPU値も含むため、rawの保存phaseと同じRAFのCPUを直接因果対応させない。

## 描画submissionとコード確認

- 固定Main96行のdraw数はA1対B1、A2対B2で全行一致。最大82。固定viewでも各run最大78。通常の86〜88の差は状態を揃えた差ではない。
- 機械の箱meshは公開版と同じ20個、追加は親node1個。再構築は初回のみ。motion_key（実荷物IDと処理率）が変わらなければ機構transform/material更新を省く。独立したタイマー、常時パーティクル、追加ライトはない。
- 既存_refresh_box_batchesは全boxを分類するが、instanceのtransform/colorが同じならsubmissionを省く。機構が動く場合の追加transform更新は存在する。draw数の一致だけでGPU負荷が同じとは断定しない。固定viewの計測にはこのbatch処理も含まれる。
- _materialは色と発光設定をキーにキャッシュし、毎frame新規materialを作る処理ではない。今回のB1失敗に直接結び付く再構築・無限更新・出荷イベント増加は見つかっていない。

## ローカル環境

/sys/fs/cgroup/cpu.maxは400000 100000（4コア相当のquota）、cpuset.cpus.effectiveは0-4。SwiftShader描画用Chromiumプロセスの観測時CPU使用率は約337%。cgroupのthrottle増分は追加run中に実測して保存した。これはcgroup全体のkernel counterで、GPU単体時間や各frameの待ち時間ではない。過去B1にはこの記録がなく、今回のthrottleから過去の直接原因を確定できない。CPU pressureファイルはこの環境に存在せず、pressure値は未取得。

## 判断と次の検証場所

実装回帰と環境変動を区別し切れていない。通常B1失敗を固定状態診断の合格で置き換えない。具体的なコード原因がないため、根拠のない機構削減・経済変更・品質低下・閾値変更はしない。性能採用は保留。

次は、CPU quotaの競合がなくハードウェアGPUが使える専用ブラウザ実行環境で、同一artifact・fixture・DPR・既存閾値の通常ABBAを1系列、固定状態Main＋保存ABBAを1系列、事前固定して実施する。GPU timestampまたはブラウザprofiler、Main/view/保存のCPU区間、実荷物状態、draw/submission、ホスト負荷を同時記録する。対象phone実機でも購入後の稼働・停止・再開を確認する。GitHub CIや別環境の実行は親の調整待ちで、このタスクでは開始しない。BFCacheの既知未検証は別件。

## 過去レポートの訂正

改訂通常A2のdraw最大はJSON上88であり、前回レポート表の86は転記誤り。本追補の全ABBA表は生JSONから生成する。過去の画像・ログ・配布ZIPは改変せず保持する。
