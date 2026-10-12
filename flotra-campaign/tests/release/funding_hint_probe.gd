extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
var app
var failures: Array[String] = []
var checks := 0
var examples: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message); push_error(message)
func finish(id: String) -> void:
    check(app.sim.accept_contract(id).ok, "accept " + id)
    for tick in 10000:
        if app.sim.finished: break
        app.sim.step(.25)
    check(app.sim.finished and app.sim.check_invariants().ok, "real deliveries complete " + id)
func option(id: String) -> Dictionary:
    for item in app.sim.upgrade_options():
        if item.id == id: return item
    return {}
func copy_for(id: String) -> String:
    app.hud._read_release()
    var before := var_to_bytes(app.sim.export_release_state())
    var text: String = app.hud._upgrade_funding_copy(option(id))
    check(before == var_to_bytes(app.sim.export_release_state()), "hint is read-only")
    examples.append({"equipment":id,"wallet":app.sim.campaign_wallet,"before":option(id).locked_reason,"after":text})
    return text
func settle() -> void:
    for i in 5: await process_frame
func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    app = Main.new(); app.persistence_enabled = false
    root.add_child(app); app.set_process(false)
    finish("growth_1"); finish("growth_2")
    check(app.sim.buy_upgrade("auto_pack").ok and app.sim.campaign_wallet == 200, "earned line purchase leaves200")
    var checkpoint: Dictionary = app.sim.export_release_state().duplicate(true)
    var fixture_directory := OS.get_environment("FLOTRA_FUNDING_FIXTURES")
    if not fixture_directory.is_empty():
        DirAccess.make_dir_recursive_absolute(fixture_directory)
        var file := FileAccess.open(fixture_directory.path_join("before-expansion.txt"), FileAccess.WRITE)
        file.store_string(preload("res://prototype/dispatch_save.gd").new().encode(checkpoint))
        file.close()
    check(copy_for("robot_2") == "資金があと60必要です\n例：仕事01をあと1回\n報酬140/回（他の購入なし）", "robot gap60 covered by one completed12-unit job")
    check(not copy_for("wing_1").contains("例："), "affordable choice not presented as locked")
    check(not copy_for("wing_3").contains("例："), "progression locked option does not promise purchase")
    for size in [Vector2i(375,567),Vector2i(390,844)]:
        root.size = size; app.hud._open_upgrades(); await settle()
        var label: Label = app.hud._root.find_child("UpgradeFunding_robot_2",true,false)
        var button: Button = app.hud._root.find_child("BuyUpgrade_robot_2",true,false)
        app.hud._scroll.ensure_control_visible(label); await settle()
        check(label.text.contains("あと1回") and button.disabled, "rendered explanation preserves unavailable purchase")
        check(label.get_line_count() == label.get_visible_line_count(), "all explanation lines visible")
        check(label.size.x <= app.hud._scroll.size.x, "phone card width fits")
        check(app.hud._scroll.get_global_rect().grow(2).encloses(label.get_global_rect()), "explanation reachable in short phone scroll")
    app.hud.close_sheet()
    finish("growth_1")
    check(app.sim.campaign_wallet == 340 and app.sim.buy_upgrade("robot_2").ok, "one actual job funds robot")
    check(app.sim.campaign_wallet == 80 and app.sim.release_state().growth.robot_count == 2, "robot branch preserves prices and adds two robots")
    check(app.sim.import_release_state(checkpoint).ok, "return to synthetic branch point")
    check(app.sim.buy_upgrade("wing_1").ok and app.sim.campaign_wallet == 50, "alternative expansion now")
    check(app.sim.release_state().growth.wing_count == 1, "warehouse expands via existing rules")
    check(copy_for("robot_2").contains("あと2回"), "another purchase recalculates example")
    finish("growth_1")
    check(not option("robot_2").available and app.sim.campaign_wallet == 190, "one repeat genuinely insufficient")
    finish("growth_1")
    check(app.sim.campaign_wallet == 330 and app.sim.buy_upgrade("robot_2").ok, "two repeats genuinely sufficient")
    check(app.sim.import_release_state(checkpoint).ok and app.sim.accept_contract("growth_1").ok, "synthetic running branch")
    check(not copy_for("robot_2").contains("例："), "paused unfinished job keeps job-completion reason")
    print("FUNDING_PROBE " + JSON.stringify({"checks":checks,"failures":failures,"examples":examples}))
    app.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)
