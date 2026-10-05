extends SceneTree
## Earn the opening through real deliveries, then exercise the existing scene
## action boundary. No wallet, equipment, cargo or save-schema edits are fixtures.
const Main = preload("res://prototype/growth_main.gd")
const Sim = preload("res://prototype/growth_sim.gd")
const Store = preload("res://prototype/release_save.gd")
var app
var checks := 0
var failures: Array[String] = []
var purchases: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)
func settle() -> void:
    for frame in 4: await process_frame
func finish_job(sim, id: String) -> void:
    check(sim.accept_contract(id).ok, "Accept real job " + id)
    for tick in 5000:
        if sim.finished: break
        sim.step(0.25)
    check(sim.finished and sim.check_invariants().ok, "Finish real cargo " + id)
func node(key: String) -> Control:
    return app.hud._root.find_child(key, true, false) as Control
func touch(point: Vector2, down: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = point
    event.pressed = down
    event.canceled = canceled
    Input.parse_input_event(event)
func reveal(key: String) -> Button:
    var button := node(key) as Button
    app.hud._scroll.ensure_control_visible(button)
    await settle()
    check(app.hud._scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Reachable whole button " + key)
    return button
func held_touch(button: Button, canceled: bool = false) -> void:
    await create_timer(0.22).timeout
    var point := button.get_global_rect().get_center()
    touch(point, true)
    for frame in 5:
        app.hud.refresh()
        await process_frame
    touch(point, false, canceled)
    await settle()
func card_text(id: String) -> String:
    var result := ""
    for child in node("UpgradeCard_" + id).get_children():
        if child is Label: result += child.text + "\n"
    return result
func write_fixture(sim, label: String) -> void:
    var directory := OS.get_environment("FLOTRA_UPGRADE_FIXTURES")
    if directory.is_empty(): return
    DirAccess.make_dir_recursive_absolute(directory)
    var saved: Dictionary = sim.export_release_state()
    var restored = Sim.new()
    check(restored.import_release_state(saved).ok and restored.export_release_state() == saved, "Exact fixture roundtrip " + label)
    var file := FileAccess.open(directory.path_join(label + ".json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"encoded":Store.new().encode(saved), "wallet":sim.campaign_wallet,"upgrades":sim.purchased_upgrades,"status":sim.campaign_status,"simTime":sim.sim_time}))
func geometry(label: String) -> void:
    var pending: Array[Node] = [app.hud._content]
    while not pending.is_empty():
        var child: Node = pending.pop_back()
        for item in child.get_children(): pending.append(item)
        if not child is Control or not child.is_visible_in_tree(): continue
        if child is Button:
            check(child.get_theme_font_size("font_size") >= 18 and child.size.y >= 56, label + " readable touch " + str(child.name))
        elif child is Label:
            check(child.get_theme_font_size("font_size") >= 18 and child.size.y + 1 >= child.get_minimum_size().y, label + " readable label " + str(child.name))

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(375, 567)
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    var sim = app.sim
    finish_job(sim, "growth_1")
    check(sim.buy_upgrade("wing_1").ok and sim.buy_upgrade("crew_4").ok and sim.campaign_wallet == 0, "Earn and buy first wing and fourth worker")
    finish_job(sim, "growth_2")
    check(sim.campaign_wallet == 200 and sim.operation_mode == "balanced", "Natural two-job state has wallet 200")
    var opening: Dictionary = sim.export_release_state()
    write_fixture(sim, "wallet200")
    app.hud.refresh()
    app.hud.upgrade_requested.connect(func(id): purchases.append(id))
    for dimensions in [Vector2i(375,567), Vector2i(390,844), Vector2i(430,932), Vector2i(568,320)]:
        root.size = dimensions
        app.hud._open_upgrades()
        await settle()
        check(not node("FutureUpgrades").visible and not node("OwnedUpgrades").visible, "Only future and owned folded " + str(dimensions))
        var shelf := node("BuyUpgrade_rack_48") as Button
        check(shelf.is_visible_in_tree() and not shelf.disabled, "Affordable shelf exposed first")
        var group := node("UnlockedUpgrades")
        check(group.visible and group.get_child_count() == 3, "Three unlocked unaffordable choices exposed")
        check(node("UnlockedUpgradesHeading").text == "資金をためて導入", "Between-job heading describes saving")
        check(node("ToggleOperations").get_global_rect().end.y <= node("UnlockedUpgradesHeading").get_global_rect().position.y, "Free operation selector keeps its original scroll depth")
        var expected := ["auto_pack", "robot_2", "wing_2"]
        for i in expected.size():
            var id: String = expected[i]
            check(group.get_child(i).is_ancestor_of(node("UpgradeCard_" + id)), "Nearest price first " + id)
            var button := node("BuyUpgrade_" + id) as Button
            check(button.is_visible_in_tree() and button.disabled, "Unlocked purchase stays disabled " + id)
            check(shelf.get_global_rect().position.y < button.get_global_rect().position.y, "Affordable before saving choice " + id)
        check(card_text("auto_pack").contains("資金があと40必要です"), "Automatic packing shortfall 40")
        check(card_text("robot_2").contains("資金があと60必要です"), "Two robots shortfall 60")
        check(card_text("wing_2").contains("資金があと150必要です"), "Second wing shortfall 150")
        for id in ["crew_6", "wing_3", "robot_4", "wing_4"]:
            check(not node("BuyUpgrade_" + id).is_visible_in_tree(), "Locked choice remains folded " + id)
        geometry(str(dimensions))
        for id in ["auto_pack", "robot_2", "wing_2"]:
            await held_touch(await reveal("BuyUpgrade_" + id))
        check(sim.export_release_state() == opening and purchases.is_empty(), "Open, scroll and disabled touches preserve whole state")
        app.hud._toggle_upgrades_group("future")
        app.hud._toggle_upgrades_group("future")
        await held_touch(await reveal("ToggleOperations"))
        check(node("OperationChoices").visible, "Existing free operation controls remain reachable")
        for id in ["balanced", "parcel", "pallet"]:
            check(node("ChooseOperation_" + id).is_visible_in_tree(), "Existing operation choice " + id)
        app.hud._toggle_operations()
        await held_touch(await reveal("BuyUpgrade_rack_48"), true)
        check(sim.export_release_state() == opening and purchases.is_empty(), "Canceled enabled purchase preserves whole state")
        app.hud.close_sheet()
        check(sim.export_release_state() == opening, "Closing sheet preserves whole state")
    root.size = Vector2i(375,567)
    check(sim.accept_contract("growth_1").ok, "Replay begins for running-state check")
    app.hud.refresh()
    app.hud._open_upgrades()
    await settle()
    check(node("UnlockedUpgradesHeading").text == "仕事の後に導入", "Running heading does not incorrectly claim insufficient funds")
    for id in ["rack_48", "auto_pack", "robot_2", "wing_2"]:
        var button := node("BuyUpgrade_" + id) as Button
        check(button.is_visible_in_tree() and button.disabled and card_text(id).contains("仕事が終わると購入できます"), "Running unlocked choice is visible but purchase blocked " + id)
    for tick in 5000:
        if sim.finished: break
        sim.step(0.25)
    check(sim.finished and sim.campaign_wallet == 340 and sim.check_invariants().ok, "Replay earns funds without changing prices")
    var funded: Dictionary = sim.export_release_state()
    write_fixture(sim, "funded340")
    for id in ["rack_48", "auto_pack", "robot_2"]:
        check(sim.import_release_state(funded).ok, "Restore independently earned purchase state " + id)
        app.hud.refresh()
        app.hud._open_upgrades()
        await settle()
        purchases.clear()
        var button := await reveal("BuyUpgrade_" + id)
        check(not button.disabled and button.is_visible_in_tree(), "Funded choice exposed " + id)
        await held_touch(button)
        var cost := int(sim._upgrade(id).cost)
        check(sim.campaign_wallet == 340 - cost and purchases == [id] and sim.purchased_upgrades.count(id) == 1, "Held purchase charges exactly once " + id)
        var purchased: Dictionary = sim.export_release_state()
        if not node("OwnedUpgrades").visible:
            await held_touch(await reveal("ToggleOwnedUpgrades"))
        await held_touch(await reveal("BuyUpgrade_" + id))
        check(sim.export_release_state() == purchased and purchases == [id], "Owned purchase cannot charge again " + id)
        if id == "rack_48": check(sim.rack_capacity == 48, "Original shelf effect")
        elif id == "auto_pack": check(is_equal_approx(sim.pack_seconds, 0.7), "Original automatic packing effect")
        else: check(sim._robot_count() == 2 and sim.workers.size() == 6, "Original two-robot effect")
        check(sim.check_invariants().ok, "Purchase conserves completed cargo " + id)
    var no_wing = Sim.new()
    finish_job(no_wing, "growth_1")
    finish_job(no_wing, "growth_2")
    check(no_wing.campaign_wallet >= 350, "Prerequisite check has enough money for second wing")
    check(sim.import_release_state(no_wing.export_release_state()).ok, "Restore earned no-wing state")
    app.hud.refresh()
    app.hud._open_upgrades()
    await settle()
    check(not node("BuyUpgrade_wing_2").is_visible_in_tree(), "Second wing remains folded after step 2 when first wing is missing")
    app.hud._toggle_upgrades_group("future")
    check(node("BuyUpgrade_wing_2").is_visible_in_tree() and node("BuyUpgrade_wing_2").disabled and card_text("wing_2").contains("先に第1棟"), "Prerequisite-locked choice retains its exact explanation")
    app.free()
    print("UPGRADE_VISIBILITY ", JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
