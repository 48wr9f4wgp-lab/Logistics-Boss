extends "res://tests/release/release_hud_smoke.gd"
## Human-readable logical pixels, including Safari's short visible viewport.
## Uses inherited real input helpers so a visually larger UI keeps safe actions.

func readable_controls(hud: Node) -> void:
    for child in descendants(hud._root):
        if not child is Control or not child.is_visible_in_tree():
            continue
        if child is Label or child is Button:
            check(child.get_theme_font_size("font_size") >= 18, "Visible text is at least 18 logical pixels: " + str(child.name))
        if child is Button:
            check(child.size.y >= 56 and child.size.x >= 56, "Touch controls remain at least 56px: " + str(child.name))
    if is_instance_valid(hud._scroll) and not hud._sheet_kind.is_empty():
        for child in descendants(hud._content):
            if child is Label and child.visible:
                var line_height: float = child.get_theme_font("font").get_height(child.get_theme_font_size("font_size"))
                check(child.get_line_count() * line_height <= child.size.y + 3, "Readable text retains its full natural height: " + child.text)

func reveal_every_action(hud: Node, buttons: Array) -> void:
    for button in buttons:
        await reveal(hud, button)
        check(hud._scroll.get_global_rect().encloses(button.get_global_rect()), "Every scroll action can be revealed completely: %s %s / %s" % [button.name, button.get_global_rect(), hud._scroll.get_global_rect()])

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    for dimensions in [Vector2i(375,567), Vector2i(375,667), Vector2i(390,844), Vector2i(430,932), Vector2i(844,390), Vector2i(667,375), Vector2i(667,354), Vector2i(667,337), Vector2i(667,320)]:
        root.size = dimensions
        var sim = Fixture.new()
        var hud = Hud.new()
        hud.bind_sim(sim)
        root.add_child(hud)
        hud.slot_action_requested.connect(func(slot: String, choice: String): events.append([slot, choice]))
        await settle()
        geometry(hud, dimensions)
        readable_controls(hud)
        check(hud._sheet.position.y == 80, "Reading sheets use full available phone height")
        await reveal_every_action(hud, [hud._content.get_node("StartTrial")])
        hud.show_play()
        await guard()
        geometry(hud, dimensions)
        readable_controls(hud)
        check(not hud._reason_detail.visible and not hud._observed_note.visible, "Play prioritizes one live status over duplicate detail")
        check(hud.world_insets() == Vector2(140, 156), "Play preserves room for a large warehouse")
        var available_width: float = hud._compare.size.x - hud._compare.get_theme_stylebox("normal").get_minimum_size().x
        check(hud.FONT.get_string_size(hud._compare.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= available_width, "Contract navigation stays on one readable line")
        hud.show_job_choices()
        await settle()
        geometry(hud, dimensions)
        readable_controls(hud)
        check(hud._contract_buttons.size() == 6, "All six contracts remain available to inspect")
        await reveal_every_action(hud, hud._contract_buttons.values())
        hud._switch_release_tab("upgrades")
        await settle()
        readable_controls(hud)
        await reveal_every_action(hud, hud._upgrade_buttons.values())
        hud._switch_release_tab("demand")
        await settle()
        geometry(hud, dimensions)
        readable_controls(hud)
        hud.show_conditions()
        await settle()
        geometry(hud, dimensions)
        readable_controls(hud)
        await reveal_every_action(hud, [hud._content.get_node("NextContract"), hud._speed_buttons[1], hud._speed_buttons[2], hud._content.get_node("TogglePause")])
        for slot in ["shelf", "packing"]:
            hud.select_slot(slot)
            await settle()
            geometry(hud, dimensions)
            readable_controls(hud)
            check(hud._sheet.get_global_rect().encloses(hud._apply.get_global_rect()), "Editor action stays pinned inside its sheet")
            check(not hud._scroll.get_global_rect().intersects(hud._apply.get_global_rect()), "Pinned editor action never overlaps scrolling content")
            check(hud._scroll.size.y >= 56, "Short phone editor retains a full readable action in its scroll region")
            check(hud._sheet.position.y >= 80, "Editor never overlaps header after orientation change")
            if hud._tabs.get_parent() == hud._content:
                await reveal_every_action(hud, [hud._previous, hud._next])
            # Resize the same open editor both ways. Its fixed/scrolling tab row
            # must return without orphaned controls, clipped targets or overlap.
            root.size = Vector2i(390,844) if dimensions.y < 368 else Vector2i(667,320)
            await settle()
            readable_controls(hud)
            check(not hud._scroll.get_global_rect().intersects(hud._apply.get_global_rect()), "Orientation change preserves pinned footer separation")
            root.size = dimensions
            await settle()
            readable_controls(hud)
            check(hud._sheet.get_global_rect().encloses(hud._apply.get_global_rect()), "Returning orientation preserves pinned Apply")
            await reveal_every_action(hud, hud._choice_buttons)
            var candidate := hud._choice_buttons[-1] as Button
            await click(candidate)
            await settle()
            check(not hud._apply.disabled, "A revealed alternate placement enables the pinned action")
            var before := events.size()
            await click(hud._apply)
            check(events.size() == before + 1, "Pinned Apply emits the chosen action exactly once")
            check(hud._sheet_kind.is_empty(), "Apply safely returns to the warehouse")
            await guard()
        hud.queue_free()
        await settle()
    print("PHONE_HUD_READABILITY %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
