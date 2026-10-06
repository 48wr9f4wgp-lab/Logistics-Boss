extends SceneTree
## Presentation-only summaries. No simulation, saved data or completed jobs.
const Hud = preload("res://prototype/dispatch_hud.gd")
class ComparisonFixture extends RefCounted:
    var comparison: Dictionary = {}
    func job_comparison() -> Dictionary: return comparison.duplicate(true)

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func _initialize() -> void:
    var fixture := ComparisonFixture.new()
    var hud := Hud.new()
    hud.sim = fixture
    check(not hud._comparison_copy().contains("集品指示量"), "No comparison invents no dispatch condition")
    var summary := {"elapsed":100.0, "units_per_minute":72.0,
        "aisle_wait_seconds":20.0, "operation_label":"バランス重視",
        "layout_label":"初期配置", "upgrades":[], "relocation_seconds":0.0}
    fixture.comparison = {"previous":summary.duplicate(true), "current":summary.duplicate(true)}
    var original := hud._comparison_copy()
    check(not original.contains("集品指示量"), "Older summaries retain original text")
    fixture.comparison.previous.dispatch_window = 6
    check(hud._comparison_copy() == original, "Unknown current cap is not inferred")
    fixture.comparison.current.dispatch_window = 12
    check(hud._comparison_copy() == original + "\n集品指示量：6枠 → 12枠", "Known6-to12 is appended without replacing base comparison")
    fixture.comparison.previous.dispatch_window = 12
    fixture.comparison.current.dispatch_window = 6
    check(hud._comparison_copy().ends_with("集品指示量：12枠 → 6枠"), "Known12-to6 is disclosed")
    fixture.comparison.previous.dispatch_window = 6
    check(hud._comparison_copy().ends_with("集品指示量：6枠 → 6枠"), "Known unchanged cap remains explicit")
    fixture.comparison.previous.erase("dispatch_window")
    check(hud._comparison_copy() == original, "Unknown previous cap is not inferred")
    for unknown in [0, "6", null]:
        fixture.comparison.previous.dispatch_window = unknown
        check(hud._comparison_copy() == original, "Invalid cap is not presented as known: " + str(unknown))
    hud.free()
    print("DISPATCH_COMPARISON_COPY ", JSON.stringify({"checks":checks, "failures":failures}))
    quit(0 if failures.is_empty() else 1)
