extends SceneTree
const Hud = preload("res://prototype/release_hud.gd")
const Fixture = preload("res://tests/release/release_hud_fixture.gd")
var failures := 0
var checks := 0
var events: Array = []
func _init() -> void:
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle() -> void:
    for i in 4:
        await process_frame
func guard() -> void:
    await settle()
    await create_timer(0.21).timeout
func click(button: Button) -> void:
    var point := button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = point
    motion.global_position = point
    root.push_input(motion)
    var down := InputEventMouseButton.new()
    down.position = point
    down.global_position = point
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    root.push_input(down)
    var up := down.duplicate() as InputEventMouseButton
    up.pressed = false
    root.push_input(up)
    await settle()
func reveal(hud: Node, control: Control) -> void:
    hud._scroll.ensure_control_visible(control)
    await settle()
func descendants(node: Node) -> Array:
    var result: Array = []
    for child in node.get_children():
        result.append(child)
        result.append_array(descendants(child))
    return result
func geometry(hud: Node, dimensions: Vector2i) -> void:
    var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
    if hud._sheet_kind.is_empty():
        for button in [hud._back,hud._pause,hud._compare,hud._primary,hud._conditions]:
            check(screen.encloses(button.get_global_rect()), "Main button is onscreen: " + str(button.name))
            check(button.size.x >= 48 and button.size.y >= 48, "Main touch target: " + str(button.name))
        for label in [hud._reason_title,hud._reason_detail,hud._shipped,hud._travel,hud._waiting,hud._observed_note]:
            check(label.get_parent().get_global_rect().encloses(label.get_global_rect()), "Main label stays in panel: " + label.text)
            var line_height: float = label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))
            check(label.get_line_count() * line_height <= label.size.y + 3, "Main text does not clip: " + label.text)
    else:
        check(screen.encloses(hud._sheet.get_global_rect()), "Sheet fits screen at " + str(dimensions))
        check(screen.encloses(hud._close.get_global_rect()), "Close stays visible")
        if is_instance_valid(hud._scroll):
            check(hud._body.get_global_rect().encloses(hud._scroll.get_global_rect()), "Scroll is contained by body")
            check(hud._content.size.x <= hud._scroll.size.x + 1, "Content never overflows horizontally")
            for child in descendants(hud._content):
                if child is Button:
                    check(child.size.x >= 48 and child.size.y >= 48, "Scrollable button has 48px touch target")
                    check(child.get_global_rect().position.x >= hud._scroll.get_global_rect().position.x - 1 and child.get_global_rect().end.x <= hud._scroll.get_global_rect().end.x + 1, "Scrollable button horizontal containment")
                if child is Label:
                    var line_height: float = child.get_theme_font("font").get_height(child.get_theme_font_size("font_size"))
                    check(child.get_line_count() * line_height <= child.size.y + 3, "Scrollable label has full natural text height: " + child.text)
func interrupted(hud: Node, button: Button) -> void:
    for notification in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        var before := events.size()
        var down := InputEventMouseButton.new()
        down.position = button.get_global_rect().get_center()
        down.global_position = down.position
        down.button_index = MOUSE_BUTTON_LEFT
        down.pressed = true
        root.push_input(down)
        root.propagate_notification(notification)
        var up := down.duplicate() as InputEventMouseButton
        up.pressed = false
        root.push_input(up)
        await settle()
        check(events.size() == before, "Interrupted contract press never mutates")
        root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
        root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
        root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    for dimensions in [Vector2i(375,667),Vector2i(390,844),Vector2i(430,932)]:
        root.size = dimensions
        var sim = Fixture.new()
        var hud = Hud.new()
        hud.bind_sim(sim)
        root.add_child(hud)
        hud.contract_requested.connect(func(id: String): events.append(["contract",id]))
        hud.upgrade_requested.connect(func(id: String): events.append(["upgrade",id]))
        hud.speed_requested.connect(func(value: float): events.append(["speed",value]))
        hud.reset_requested.connect(func(): events.append(["reset"]))
        hud.pause_requested.connect(func(value: bool): events.append(["pause",value]))
        hud.trial_started.connect(func(): events.append(["start"]))
        await settle()
        check(hud._sheet_kind == "entry", "Starts with brief introduction")
        hud.set_save_status("保存を読み込めませんでした。以前のデータを保護しています。このプレイは保存されません。")
        await settle()
        check(hud._content.get_node("EntrySaveStatus").text.contains("保護"), "Full save warning is available in intro")
        geometry(hud,dimensions)
        var start := hud._content.get_node("StartTrial") as Button
        await reveal(hud,start)
        await click(start)
        check(hud._sheet_kind == "jobs", "First start opens contract selection directly")
        geometry(hud,dimensions)
        var accept := hud._contract_buttons["first"] as Button
        await reveal(hud,accept)
        await interrupted(hud,accept)
        var before := events.size()
        await click(accept)
        check(events.size() == before + 1 and events[-1] == ["contract","first"], "Accept emits exact contract once")
        check(hud._sheet_kind.is_empty(), "Contract request safely dismisses sheet")
        hud._request_contract("first")
        check(events.size() == before + 1, "Dismissed contract cannot fire twice")
        sim.active = "first"
        sim.status = "running"
        hud.refresh()
        await guard()
        geometry(hud,dimensions)
        sim.wallet = 1000000
        hud.refresh()
        await settle()
        geometry(hud,dimensions)
        check(hud._shipped.text.contains("100.0万"), "Large live wallet uses readable compact units")
        sim.wallet = 420
        hud.refresh()
        check(hud._reason_title.text.begins_with("目標"), "Goal is visible when there is no bottleneck")
        sim.bottleneck = "まとめ保管の床が満杯"
        hud.refresh()
        check(hud._reason_title.text.contains("満杯"), "Real bottleneck remains above goal")
        await click(hud._pause)
        check(events[-1] == ["pause",true], "Independent pause works")
        await guard()
        await click(hud._primary)
        check(hud._sheet_kind == "editor" and not hud._trial_running, "Layout editor never resumes paused game")
        hud.close_sheet()
        await guard()
        await click(hud._compare)
        check(hud._sheet_kind == "jobs", "Bottom direct navigation opens campaign")
        await click(hud._tabs.get_node("Tab_upgrades"))
        geometry(hud,dimensions)
        check(hud._upgrade_buttons["worker"].disabled, "Upgrades are blocked during accepted contract")
        await click(hud._tabs.get_node("Tab_demand"))
        geometry(hud,dimensions)
        check(hud._release_tab == "demand", "Contract demand is directly discoverable")
        check(hud._content.find_child("MixApply",true,false) == null, "Fixed contracts do not expose changing demand")
        root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
        await settle()
        check(hud._sheet_kind.is_empty(), "Hardware Back dismisses exactly once")
        await guard()
        await click(hud._conditions)
        geometry(hud,dimensions)
        check(hud._content.find_child("RestartTrial",true,false) == null, "Records contain no destructive restart")
        check(hud._content.get_node("RecordSaveStatus").text.contains("保護"), "Full save warning is readable in records")
        var speed_button := hud._content.find_child("Speed2x",true,false) as Button
        await reveal(hud,speed_button)
        await click(speed_button)
        check(events[-1] == ["speed",2.0], "Speed2x emits explicit intent")
        check(not hud._trial_running, "Changing speed does not resume pause")
        hud.close_sheet()
        sim.status = "contract_complete"
        sim.completed = 1
        hud.refresh()
        await guard()
        check(hud._reason_title.text == "契約を達成！", "Completion visibly points to next contract")
        check(not hud._compare.disabled, "Campaign navigation remains enabled after completion")
        await click(hud._compare)
        await click(hud._tabs.get_node("Tab_contracts"))
        geometry(hud,dimensions)
        check(not hud._contract_buttons["contract2"].disabled, "Next contract is available")
        check(hud._contract_buttons["first"].text.contains("再挑戦"), "Completed contract clearly offers replay")
        await click(hud._tabs.get_node("Tab_upgrades"))
        var upgrade := hud._upgrade_buttons["worker"] as Button
        await reveal(hud,upgrade)
        await click(upgrade)
        check(events[-1] == ["upgrade","worker"], "Upgrade emits exact intent")
        check(hud._sheet_kind == "jobs", "Buying upgrade keeps player in equipment section")
        sim.owned.append("worker")
        sim.wallet -= 180
        hud.show_upgrade_result({"ok":true})
        await settle()
        check(hud._upgrade_buttons["worker"].disabled, "Purchased upgrade locks immediately after domain response")
        geometry(hud,dimensions)
        hud.close_sheet()
        await guard()
        hud.show_entry()
        await settle()
        hud.close_sheet()
        check(not hud._trial_running, "Help close preserves independent pause")
        check(not events.any(func(item): return item[0] == "reset"), "No release flow can emit destructive reset")
        hud.queue_free()
        await settle()
    print("RELEASE_HUD_SMOKE %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
