extends SceneTree

const SimScript := preload("res://domain/flotra_v2_sim.gd")
const HudScript := preload("res://ui/game_hud_mobile.gd")
const ZoneScript := preload("res://ui/warehouse_zone_panel.gd")
const ClarityScript := preload("res://ui/mobile_interaction_clarity.gd")
const Palette := preload("res://ui/hud_palette.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
    call_deferred("_run")


func _check(ok: bool, message: String) -> void:
    _checks += 1
    if not ok:
        _failures += 1
        push_error(message)


func _settle() -> void:
    for _index in 6:
        await process_frame


func _run() -> void:
    for dimensions in [Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932)]:
        get_root().size = dimensions
        var sim: FlotraV2Sim = SimScript.new()
        var hud: MobileGameHud = HudScript.new()
        hud.bind_sim(sim)
        get_root().add_child(hud)
        var zone: WarehouseZonePanel = ZoneScript.new()
        hud.add_child(zone)
        zone.bind_sim(sim)
        var clarity: MobileInteractionClarity = ClarityScript.new()
        hud.add_child(clarity)
        clarity.bind(hud, zone)
        await _settle()

        for funds in [5000, 250000, 9999999]:
            sim.money = funds
            await _settle()
            var metrics := hud._find_metric_row()
            # The phone window stretches a portrait canvas. Compare layout in
            # that canvas's coordinates, not against physical output pixels.
            var canvas := hud.get_viewport().get_visible_rect()
            _check(metrics.get_global_rect().end.x <= canvas.end.x - 11.0, "Metrics remain within portrait width at %s, funds %d" % [dimensions, funds])
            for value in [hud._money, hud._throughput, hud._orders]:
                var box := value.get_parent() as VBoxContainer
                var panel := box.get_parent() as PanelContainer
                var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
                var caption := box.get_child(0) as Label
                _check(panel.get_global_rect().encloses(value.get_global_rect()), "Metric values stay inside their card")
                _check(panel.get_global_rect().encloses(caption.get_global_rect()), "Metric captions stay inside their card")
                _check(style.bg_color == Palette.SURFACE and style.border_color == Palette.KEYLINE_SOFT, "All metrics use the same navy surface and quiet keyline")
                _check(value.get_theme_font_size("font_size") > caption.get_theme_font_size("font_size"), "Metric values retain primary text hierarchy")
                _check(_contrast(value.get_theme_color("font_color"), style.bg_color) >= 4.5, "Metric value contrast stays readable")
                _check(_contrast(caption.get_theme_color("font_color"), style.bg_color) >= 4.5, "Metric caption contrast stays readable")

        var goal := hud._v2_growth_goal
        var goal_style := goal.get_theme_stylebox("normal") as StyleBoxFlat
        _check(goal_style.border_width_left == 3 and goal_style.border_width_right == 0, "Growth uses a single amber cue instead of a neon outline")
        _check(goal_style.bg_color == Palette.SURFACE_RAISED, "Growth action belongs to the navy surface system")
        _check(goal.get_global_rect().size.y >= 44.0, "Growth keeps its phone touch target")
        _check(not goal.get_global_rect().intersects(hud._bottleneck_panel.get_global_rect()), "Growth stays clear of the pressure summary")
        for button in [hud._speed_button, hud._manage_button]:
            _check(button.get_global_rect().size.x >= 44.0 and button.get_global_rect().size.y >= 44.0, "Dock actions retain minimum touch size")

        clarity.open_section("field")
        await _settle()
        var field := clarity._tabs["field"] as Button
        var selected_style := field.get_theme_stylebox("normal") as StyleBoxFlat
        _check(selected_style.bg_color == Palette.SELECTED_SURFACE, "Selected management tab remains distinct")
        _check(selected_style.bg_color != clarity._normal.bg_color, "Selection is communicated by fill as well as text")
        _check(_contrast(Palette.DISABLED_TEXT, Palette.DISABLED_SURFACE) >= 4.5, "Disabled action copy remains readable")

        hud._request_reset_confirmation()
        await _settle()
        var reset_style := hud._reset_confirm_button.get_theme_stylebox("normal") as StyleBoxFlat
        _check(reset_style.bg_color.r > reset_style.bg_color.g * 2.0, "Destructive reset retains its separate warning treatment")
        hud._cancel_reset_confirmation()
        hud.queue_free()
        await _settle()

    print("HUD cohesion checks=%d failures=%d" % [_checks, _failures])
    quit(0 if _failures == 0 else 1)


func _contrast(a: Color, b: Color) -> float:
    var la := _luminance(a)
    var lb := _luminance(b)
    return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(color: Color) -> float:
    var linear := color.srgb_to_linear()
    return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722
