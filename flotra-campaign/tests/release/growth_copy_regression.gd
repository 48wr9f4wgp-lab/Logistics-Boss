extends SceneTree
## Player-facing copy across fresh, active, paused, complete and mature states.
## IDs and historical save data remain unchanged; this checks displayed wording.
const HUD = preload("res://prototype/growth_hud.gd")
const SIM = preload("res://prototype/growth_sim.gd")
var failures: Array[String] = []
var checks := 0
var hud
var sim

func _initialize() -> void:
    _run.call_deferred()

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures.append(message)
        push_error(message)

func settle() -> void:
    await process_frame
    await process_frame
    await process_frame

func inspect_copy(node: Node, context: String) -> void:
    if (node is Label or node is Button) and node.is_visible_in_tree():
        var copy: String = node.text
        for stale in ["ミックス便", "を増築を", "迎えるを", "結果へ", "引き換え", "大型棚48個", "1x", "2x", "4x", "試作", "本編のセーブ", "観測を再開"]:
            check(not copy.contains(stale), "%s/%s avoids stale copy: %s" % [context, node.name, stale])
        if not copy.is_empty():
            check(node.get_theme_font_size("font_size") >= 18, "%s/%s retains readable text" % [context, node.name])
    for child in node.get_children():
        inspect_copy(child, context)

func inspect_sheets(context: String) -> void:
    hud.show_entry()
    await settle()
    inspect_copy(hud._root, context + "/help")
    hud._open_contracts()
    await settle()
    inspect_copy(hud._root, context + "/jobs")
    hud._open_upgrades()
    await settle()
    inspect_copy(hud._root, context + "/equipment")
    for pair in [["ToggleFutureUpgrades", "future"], ["ToggleOwnedUpgrades", "owned"]]:
        if hud._content.has_node(pair[0]):
            hud._toggle_upgrades_group(pair[1])
            await settle()
            inspect_copy(hud._root, context + "/equipment/" + pair[1])
    if hud._content.has_node("ToggleOperations"):
        hud._toggle_operations()
        await settle()
        inspect_copy(hud._root, context + "/operations")
    hud.show_conditions()
    await settle()
    inspect_copy(hud._root, context + "/results")
    hud._toggle_history()
    await settle()
    inspect_copy(hud._root, context + "/history")
    hud.show_layout_editor()
    await settle()
    inspect_copy(hud._root, context + "/layout")
    if hud.has_method("show_controls"):
        hud.show_controls()
        await settle()
        inspect_copy(hud._root, context + "/controls")

func finish_job(id: String) -> void:
    var result: Dictionary = sim.accept_contract(id)
    check(bool(result.get("ok", false)), id + " starts for copy journey")
    for tick in 10000:
        if sim.finished:
            break
        sim.step(0.5)
    check(sim.finished, id + " completes for copy journey")
    hud._notice = ""
    hud.refresh()

func _run() -> void:
    root.size = Vector2i(375, 667)
    sim = SIM.new()
    hud = HUD.new()
    hud.bind_sim(sim)
    root.add_child(hud)
    await settle()
    await inspect_sheets("fresh")
    for code in ["contract_in_progress", "locked_contract", "unshipped_cargo", "unknown_contract", "unknown_upgrade", "busy", "contract_running", "active_contract", "locked", "insufficient_funds", "funds", "owned", "already_owned", "unavailable", "contract_mix_fixed", "future_error", "mystery", ""]:
        var translated: String = hud._locked_text(code)
        check(not translated.is_empty() and translated != code, "Domain code becomes actionable Japanese: " + code)
        check(not translated.contains("結果") and not translated.contains("条件」"), "Error has no obsolete navigation: " + code)
    check(hud._locked_text("資金があと100必要です") == "資金があと100必要です", "Specific Japanese requirement remains intact")
    for warning in ["保存容量を超えました", "保存停止・他のタブを閉じて再読込", "他の画面で進行更新・上書き停止", "予備保存を保護中・上書き停止", "この画面の進行は保存されません", "保存できませんでした"]:
        hud.set_save_status(warning)
        check(hud._short_save_status() == "保存注意・成果へ", "Every save failure points to the visible results destination: " + warning)
    hud.set_save_status("自動保存済み")
    check(hud._short_save_status() == "自動保存済み", "Successful saves are not warnings")
    check(sim.accept_contract("growth_1").ok, "First active job starts")
    sim.step(3.0)
    hud.set_trial_running(true)
    hud.refresh()
    await inspect_sheets("running")
    hud.set_trial_running(false)
    hud.show_play()
    hud._notice = ""
    hud.refresh()
    check(hud._reason_title.text.contains("停止"), "Paused work is described as paused")
    inspect_copy(hud._root, "paused")
    hud.show_conditions()
    check(hud._content.get_node("ReleaseRecordSummary").text == "一時停止中", "Paused results do not claim that shipping is running")
    for tick in 10000:
        if sim.finished:
            break
        sim.step(0.5)
    hud._notice = ""
    hud.refresh()
    await inspect_sheets("first_complete")
    check(not sim._next_goal().contains("を増築を"), "Affordable expansion goal is grammatical")
    sim.campaign_wallet = 0
    hud.refresh()
    await inspect_sheets("zero_wallet")
    for number in range(2, 7):
        finish_job("growth_%d" % number)
    sim.campaign_wallet = 10000
    for option in sim.GROWTH_UPGRADES:
        check(sim.buy_upgrade(str(option.id)).ok, "Mature copy fixture purchases " + str(option.id))
    hud.refresh()
    await inspect_sheets("mature")
    finish_job("growth_1")
    await inspect_sheets("repeat_complete")
    print("GROWTH_COPY_REGRESSION %d checks, %d failures" % [checks, failures.size()])
    hud.free()
    quit(0 if failures.is_empty() else 1)
