extends SceneTree
## Engine geometry/input test at device-pixel backing sizes. Not browser rendering.
const Main = preload("res://prototype/release_main.gd")
var checks := 0
var failures: Array[String] = []
var measurements: Array = []
var app

func _init() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        push_error(message)

func settle() -> void:
    for _i in 8:
        await process_frame
    app.hud.refresh()
    app.world.refresh()

func tap(button: Button) -> void:
    var point: Vector2 = root.get_screen_transform() * button.get_global_rect().get_center()
    var down := InputEventScreenTouch.new()
    down.index = 0
    down.position = point
    down.pressed = true
    root.push_input(down)
    var up := down.duplicate() as InputEventScreenTouch
    up.pressed = false
    root.push_input(up)
    await settle()

func verify_screen(css: Vector2i, dpr: int, label: String) -> void:
    var logical := root.get_visible_rect().size
    check(logical.is_equal_approx(Vector2(css)), label + ": logical viewport equals CSS size")
    check(app.hud._root.size.is_equal_approx(Vector2(css)), label + ": actual HUD root equals CSS size")
    var transform := root.get_screen_transform()
    check(is_equal_approx(transform.x.length(), float(dpr)), label + ": X scales by DPR")
    check(is_equal_approx(transform.y.length(), float(dpr)), label + ": Y scales by DPR")
    var screen := Rect2(Vector2.ZERO, Vector2(css))
    for button in [app.hud._back, app.hud._pause, app.hud._primary, app.hud._compare, app.hud._conditions]:
        var rect: Rect2 = button.get_global_rect()
        check(screen.encloses(rect), label + ": main target inside CSS viewport: " + button.name)
        var css_height: float = rect.size.y * transform.y.length() / float(dpr)
        var css_font: float = float(button.get_theme_font_size("font_size")) * transform.y.length() / float(dpr)
        check(css_height >= 48, label + ": actual CSS touch height >=48: " + button.name)
        check(css_font >= 18, label + ": actual CSS text >=18: " + button.name)
    check(app.viewport.size.x == css.x, label + ": 3D subviewport width remains CSS space")
    for item in app.world._callouts.values():
        var caption: Label = item.label
        if not caption.visible:
            continue
        check(caption.get_theme_font_size("font_size") >= 18, label + ": world caption >=18 logical/CSS pixels")
        check(Rect2(Vector2.ZERO, Vector2(app.viewport.size)).encloses(caption.get_rect()), label + ": world caption is inside subviewport")
    measurements.append({"label": label, "css_width": css.x, "css_height": css.y, "dpr": dpr, "physical_width": root.size.x, "physical_height": root.size.y, "logical_width": logical.x, "logical_height": logical.y, "scale_x": transform.x.length(), "scale_y": transform.y.length(), "primary_css_font": app.hud._primary.get_theme_font_size("font_size"), "primary_css_height": app.hud._primary.size.y})

func run() -> void:
    for css in [Vector2i(375,567), Vector2i(375,667), Vector2i(390,844), Vector2i(430,932)]:
        for dpr in [1,2,3]:
            var label := "%dx%d DPR%d" % [css.x, css.y, dpr]
            root.size = css * dpr
            app = Main.new()
            app.persistence_enabled = false
            root.add_child(app)
            app.set_process(false)
            app._apply_logical_viewport(css)
            app.hud.show_play()
            await settle()
            verify_screen(css, dpr, label)
            # The dismissal guard uses wall time; SceneTreeTimer may finish
            # sooner after a slow frame. Wait for readiness before one tap.
            var deadline := Time.get_ticks_msec() + 2000
            while app.hud._background_input_blocked() and Time.get_ticks_msec() < deadline:
                await process_frame
            check(not app.hud._background_input_blocked(), label + ": dismissal guard expires before fresh navigation")
            await tap(app.hud._compare)
            check(app.hud._sheet_kind == "jobs", label + ": physical-pixel touch opens contracts once")
            check(Rect2(Vector2.ZERO, Vector2(css)).encloses(app.hud._sheet.get_global_rect()), label + ": contract sheet remains inside CSS screen")
            app.hud.close_sheet()
            var short_css := Vector2i(css.x, maxi(420, css.y - 120))
            root.size = short_css * dpr
            app._apply_logical_viewport(short_css)
            await settle()
            verify_screen(short_css, dpr, label + " shorter height")
            # Return to full height without replacing the scene or its state.
            root.size = css * dpr
            app._apply_logical_viewport(css)
            await settle()
            verify_screen(css, dpr, label + " restored height")
            app.queue_free()
            await process_frame
    print(JSON.stringify({"suite": "review_phone_scale", "scope": "Godot headless DPR-equivalent window geometry and touch, not browser rendering", "checks": checks, "failures": failures, "measurements": measurements}))
    quit(0 if failures.is_empty() else 1)
