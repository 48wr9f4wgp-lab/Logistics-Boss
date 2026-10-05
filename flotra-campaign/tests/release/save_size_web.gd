extends Node
## Test scene, selected only by the isolated test server. No production hook.
const Checks = preload("res://tests/release/save_size_checks.gd")
var callback: JavaScriptObject
func _ready() -> void:
    if OS.has_feature("web"): JavaScriptBridge.eval("window.flotraSizeEntered = true",true)
    if not OS.has_feature("web") or str(JavaScriptBridge.eval("JSON.stringify(window.flotraDisposableSizeTest === true)",true)) != "true":
        return
    callback = JavaScriptBridge.create_callback(invoke)
    JavaScriptBridge.get_interface("window").FlotraSizeTestInvoke = callback
    JavaScriptBridge.eval("window.flotraSizeReady = true",true)
func invoke(args: Array) -> void:
    var checks = Checks.new()
    var result: Dictionary = checks.web_storage_failure() if str(args[0]) == "quota" else checks.run()
    JavaScriptBridge.eval("window.flotraSizeReport = " + JSON.stringify(result),true)
