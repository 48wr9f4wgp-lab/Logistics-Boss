extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
var failures: Array[String] = []
var checks := 0
var evidence: Array[Dictionary] = []
var app

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func settle() -> void:
    for frame in 4: await process_frame

func key(code: Key, backwards := false) -> void:
    for pressed in [true, false]:
        var event := InputEventKey.new()
        event.keycode = code
        event.pressed = pressed
        event.shift_pressed = backwards
        Input.parse_input_event(event)
        Input.flush_buffered_events()
        await process_frame

func audit(node: Node, label: String) -> void:
    if node is Button:
        for property in ["focus_next", "focus_previous", "focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom"]:
            var path: NodePath = node.get(property)
            if path.is_empty(): continue
            var target := node.get_node_or_null(path) as Button
            evidence.append({"stage":label,"button":str(node.name),"property":property,"path":str(path),"valid":is_instance_valid(target)})
            check(is_instance_valid(target), label + ": focus target exists for " + str(node.name) + "/" + property)
            if is_instance_valid(target):
                check(target.is_visible_in_tree() and not target.disabled and target.focus_mode == Control.FOCUS_ALL, label + ": focus target is keyboard-eligible")
    for child in node.get_children(): audit(child, label)

func run() -> void:
    for dimensions in [Vector2i(1280, 720), Vector2i(390, 844)]:
        root.size = dimensions
        app = Main.new()
        app.persistence_enabled = false
        root.add_child(app)
        app.set_process(false)
        await settle()
        var hud = app.hud
        var before: Dictionary = app.sim.export_release_state()
        hud.show_intro()
        await settle()
        var start := hud._content.get_node("StartTrial") as Button
        check(hud._close.get_node_or_null(hud._close.focus_next) == start, "Entry close links to the real StartTrial")
        hud._close.grab_focus()
        await key(KEY_TAB)
        check(root.gui_get_focus_owner() == start, "Tab reaches StartTrial")
        await key(KEY_TAB, true)
        check(root.gui_get_focus_owner() == hud._close, "Shift+Tab returns to CloseSheet")
        audit(hud._root, "entry")
        var foreign_focus := SubViewportContainer.new()
        foreign_focus.focus_mode = Control.FOCUS_ALL
        root.add_child(foreign_focus)
        foreign_focus.grab_focus()
        check(root.gui_get_focus_owner() == foreign_focus, "Non-button control owns focus before modal resync")
        hud._sync_focus()
        check(root.gui_get_focus_owner() == hud._close, "Modal resync moves non-button focus to an eligible button without typed-array lookup")
        foreign_focus.free()
        # Eligibility changes must retire paths on the formerly eligible node.
        start.hide()
        hud._sync_focus()
        check(start.focus_next.is_empty() and start.focus_previous.is_empty(), "Hidden button has no old ring links")
        audit(hud._root, "hidden")
        start.show()
        start.grab_focus()
        start.disabled = true
        hud._sync_focus()
        check(root.gui_get_focus_owner() == hud._close, "Disabling focused action moves focus to an eligible button")
        audit(hud._root, "disabled")
        start.disabled = false
        start.focus_mode = Control.FOCUS_NONE
        hud._sync_focus()
        audit(hud._root, "focus-none")
        start.focus_mode = Control.FOCUS_ALL
        hud._sync_focus()
        # Replacement destroys StartTrial; audit synchronously before deferred sync.
        hud.show_controls()
        audit(hud._root, "replace-before-deferred")
        await settle()
        audit(hud._root, "controls")
        await key(KEY_TAB)
        check(hud._sheet.is_ancestor_of(root.gui_get_focus_owner()), "Keyboard remains inside ordinary modal")
        hud.close_sheet()
        audit(hud._root, "closed")
        check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(), "Closing returns focus to a visible warehouse action")
        hud.show_intro()
        await settle()
        hud._close.grab_focus()
        hud.show_save_protection("Synthetic focus regression; no user storage")
        audit(hud._root, "protection-before-deferred")
        await settle()
        audit(hud._root, "protection")
        check(hud._close.focus_next.is_empty() and hud._close.focus_previous.is_empty(), "Protected CloseSheet releases destroyed StartTrial paths")
        for backwards in [false, true]:
            for attempt in 3: await key(KEY_TAB, backwards)
        await key(KEY_ESCAPE)
        check(hud._sheet_kind == "save_protection", "Keyboard cannot escape save protection")
        check(app.sim.export_release_state() == before, "Focus transitions do not mutate domain state")
        app.free()
        await settle()
    print("FOCUS_TRANSITION_REGRESSION ", JSON.stringify({"checks":checks,"failures":failures,"paths":evidence}))
    quit(0 if failures.is_empty() else 1)
