extends "res://prototype/jobs_sim.gd"
var status := "ready"
var wallet := 420
var completed := 0
var owned: Array = []
var active := ""
var bottleneck := ""
func snapshot() -> Dictionary:
    var state := super.snapshot()
    state["jobs_by_type"] = {"bulk":{"shipped_units":24,"queued_jobs":3},"small":{"shipped_units":18,"queued_jobs":7}}
    state["bottleneck"] = bottleneck
    state["finished"] = status == "contract_complete"
    return state
func release_state() -> Dictionary:
    return {"schema":1,"status":status,"wallet":wallet,"completed_count":completed,"total_contracts":6,"campaign_complete":completed == 6,"current_contract":{} if active.is_empty() else contract_options()[0],"progress":{"shipped":8,"total":18,"remaining":10,"fraction":8.0/18.0},"elapsed":42.5,"best_time":0.0,"last_earnings":120,"last_result":{},"objective":"18箱をすべて出荷。残り10箱","available":["first"],"upgrades":owned,"worker_count":2}
func contract_options() -> Array:
    var options: Array = []
    for i in 6:
        options.append({"id":"first" if i == 0 else "contract%d" % (i+1),"label":["はじめての便","まとめ保管便","小口梱包便","混載便の挑戦","大型契約","倉庫の集大成"][i],"description":"まとめ保管と小口梱包の動線を工夫して、決まった荷物をすべて出荷しよう。","manifest_quota":5,"bulk_manifests":3,"pick_manifests":2,"total_units":18,"reward":120,"gold_seconds":160,"silver_seconds":210,"available":i <= completed and status != "running","locked_reason":"contract_running" if status == "running" else "locked","completed":i < completed,"is_replay":i < completed,"best_time":133.0 if i < completed else 0.0,"best_medal":"gold" if i < completed else ""})
    return options
func upgrade_options() -> Array:
    return [{"id":"worker","label":"作業員を1人増員","description":"3人目が運搬を手伝います。通路が混むこともあるので、配置と合わせて改善しよう。","cost":180,"unlock_after":1,"owned":owned.has("worker"),"available":status != "running" and not owned.has("worker"),"locked_reason":"contract_running"},{"id":"packing","label":"梱包台を効率化","description":"1箱の梱包時間を短縮します。小口梱包の多い契約で役立ちます。","cost":240,"unlock_after":2,"owned":false,"available":false,"locked_reason":"2契約の達成で解放"}]
