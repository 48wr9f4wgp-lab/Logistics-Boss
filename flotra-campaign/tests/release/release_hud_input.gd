extends "res://tests/release/release_hud_smoke.gd"
const RealSim = preload("res://prototype/release_sim.gd")
func event_at(point: Vector2, pressed: bool, kind: String) -> InputEvent:
    if kind == "touch":
        var touch := InputEventScreenTouch.new()
        touch.index = 0
        touch.position = point
        touch.pressed = pressed
        return touch
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.position = point
    mouse.global_position = point
    mouse.pressed = pressed
    return mouse
func tap(button: Control, kind: String, repeats: int = 1) -> void:
    var point := button.get_global_rect().get_center()
    for i in repeats:
        root.push_input(event_at(point,true,kind))
        root.push_input(event_at(point,false,kind))
    await guard()
func keypress(code: Key, backwards: bool = false) -> void:
    var key := InputEventKey.new()
    key.keycode = code
    key.physical_keycode = code
    key.shift_pressed = backwards
    key.pressed = true
    root.push_input(key)
    var up := key.duplicate() as InputEventKey
    up.pressed = false
    root.push_input(up)
    await settle()
func scroll_touch(control: Control) -> void:
    var point := control.get_global_rect().get_center()
    root.push_input(event_at(point,true,"touch"))
    for i in 8:
        var drag := InputEventScreenDrag.new()
        drag.index = 0
        drag.relative = Vector2(0,-14)
        drag.position = point + Vector2(0,-14*(i+1))
        drag.velocity = Vector2(0,-840)
        root.push_input(drag)
        await process_frame
    root.push_input(event_at(point + Vector2(0,-112),false,"touch"))
    await guard()
func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    for dimensions in [Vector2i(375,667),Vector2i(390,844),Vector2i(430,932)]:
        root.size = dimensions
        for kind in ["mouse","touch"]:
            var sim = RealSim.new()
            var hud = Hud.new()
            hud.bind_sim(sim)
            root.add_child(hud)
            hud.contract_requested.connect(func(id: String):
                events.append(["contract",id])
                hud.show_contract_result(sim.accept_contract(id))
            )
            hud.upgrade_requested.connect(func(id: String):
                events.append(["upgrade",id])
                hud.show_upgrade_result(sim.buy_upgrade(id))
            )
            hud.pause_requested.connect(func(value: bool): events.append(["pause",value]))
            await settle()
            await reveal(hud,hud._content.get_node("StartTrial"))
            await tap(hud._content.get_node("StartTrial"),kind)
            check(hud._sheet_kind == "jobs", "%s: First start opens contracts" % kind)
            geometry(hud,dimensions)
            var accept := hud._contract_buttons["first_shift"] as Button
            await reveal(hud,accept)
            if kind == "touch":
                var before := events.size()
                await scroll_touch(accept)
                check(events.size() == before and sim.campaign_status == "ready", "Touch scroll from contract button cannot accept contract")
                await reveal(hud,accept)
            await tap(accept,kind,5)
            check(sim.current_contract_id == "first_shift" and sim.campaign_status == "running", "Repeated %s contract accept starts exact job" % kind)
            check(hud._sheet_kind.is_empty(), "Repeated accept never opens underlying sheet")
            hud._notice = ""
            sim.step(20)
            hud.refresh()
            await settle()
            geometry(hud,dimensions)
            check(hud._shipped.text.contains("36"), "Real contract quota is visible")
            for exit_mode in ["close","escape","hardware_back"]:
                await tap(hud._compare,kind)
                await tap(hud._tabs.get_node("Tab_demand"),kind)
                check(hud._content.get_children().any(func(child): return child is Label and child.text.contains("合計 36個")), "Demand uses real36unit quota")
                geometry(hud,dimensions)
                if exit_mode == "close":
                    await tap(hud._close,kind,5)
                elif exit_mode == "escape":
                    await keypress(KEY_ESCAPE)
                    await guard()
                else:
                    root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
                    await guard()
                check(hud._sheet_kind.is_empty() and hud._trial_running, "%s dismissal preserves running state" % exit_mode)
            await tap(hud._compare,kind)
            await tap(hud._tabs.get_node("Tab_contracts"),kind)
            hud._close.grab_focus()
            for backwards in [false,true]:
                for i in 9:
                    await keypress(KEY_TAB,backwards)
                    var focused := root.gui_get_focus_owner()
                    check(focused != null and hud._sheet.is_ancestor_of(focused), "Keyboard focus stays inside modal")
            hud.close_sheet()
            await guard()
            while sim.campaign_status == "running" and sim.sim_time < 900:
                sim.step(0.25)
            check(sim.campaign_status == "contract_complete", "Actual first contract completes")
            hud.refresh()
            await settle()
            geometry(hud,dimensions)
            await tap(hud._conditions,kind)
            geometry(hud,dimensions)
            check(hud._content.get_node("ReleaseRecordOutcome").text.contains("報酬 180"), "Actual completion reward visible in results")
            check(hud._content.find_child("CompareJobs",true,false) == null, "No unsupported prototype comparison in release")
            await tap(hud._content.get_node("NextContract"),kind)
            check(not hud._contract_buttons["small_orders"].disabled and not hud._contract_buttons["pallet_wave"].disabled, "Distinct work-type contracts unlock together")
            await tap(hud._tabs.get_node("Tab_upgrades"),kind)
            var buy := hud._upgrade_buttons["worker_4"] as Button
            await reveal(hud,buy)
            await tap(buy,kind,5)
            check(sim.purchased_upgrades.has("worker_4") and sim.campaign_wallet == 60, "Repeated %s purchase applies exact cost once" % kind)
            check(hud._upgrade_buttons["worker_4"].disabled, "Owned purchase disabled")
            geometry(hud,dimensions)
            hud.close_sheet()
            await guard()
            await tap(hud._pause,kind)
            check(not hud._trial_running, "Pause remains accessible after contract complete")
            await tap(hud._primary,kind)
            check(hud._sheet_kind == "editor" and not hud._trial_running, "Paused warehouse layout remains independent")
            hud._choose("annex")
            await settle()
            check(hud._cost.text == "仕事の合間は無料で変更できます。待ち時間もありません", "Between-contract layout previews show zero stoppage")
            hud.show_action_result({"ok":true,"pending":false})
            check(hud._notice_title == "配置を変更しました", "Immediate layout feedback does not claim deferred relocation")
            hud.close_sheet()
            await guard()
            hud.show_entry()
            await settle()
            await tap(hud._close,kind,5)
            check(hud._sheet_kind.is_empty() and not hud._trial_running, "Repeated help dismissal does not resume or fall through")
            hud.queue_free()
            await settle()
    print("RELEASE_HUD_INPUT %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
