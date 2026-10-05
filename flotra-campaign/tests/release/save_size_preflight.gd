extends SceneTree
const Checks = preload("res://tests/release/save_size_checks.gd")
func _init() -> void:
    var result: Dictionary = Checks.new().run()
    print(JSON.stringify(result))
    quit(0 if result.failures.is_empty() else 1)
