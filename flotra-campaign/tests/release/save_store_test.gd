extends SceneTree
const Save = preload("res://prototype/release_save.gd")
var failures: Array = []
var checks := 0
class FakeSim extends RefCounted:
    var value := {"schema":1,"vector":Vector3(2,0,1),"time":2.3,"list":[1,2]}
    func export_release_state() -> Dictionary: return value
    func import_release_state(data: Dictionary) -> Dictionary:
        if data.get("schema") != 1: return {"ok":false}
        value = data
        return {"ok":true}
class MemoryStore extends Save:
    var pair := {"ok":true,"primary":"","backup":""}
    func _read_pair() -> Dictionary: return pair
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
func _init() -> void:
    var sim := FakeSim.new()
    var store := MemoryStore.new()
    var encoded: String = store.encode(sim.value)
    check(store.decode(encoded).data == sim.value,"variant safe roundtrip")
    check(store.load_into(sim).fresh,"empty storage fresh")
    store.pair.primary = encoded
    check(store.load_into(sim).restored,"valid restores")
    for bad in ["broken", "{}", encoded.replace('"version":1','"version":2'), encoded.replace('"sha256":"','"sha256":"bad')]:
        var broken := MemoryStore.new()
        broken.pair.primary = bad
        check(not broken.load_into(sim).ok,"reject malformed")
        check(broken.blocked and not broken.save_from(sim).ok,"preserve malformed")
        check(broken.pair.primary == bad,"never overwrite malformed")
    var recovery := MemoryStore.new()
    recovery.pair = {"ok":true,"primary":"broken","backup":encoded}
    check(recovery.load_into(sim).get("backup",false),"backup recover")
    check(recovery.blocked,"backup rescue never destroys primary")
    var unavailable := MemoryStore.new()
    unavailable.pair = {"ok":false}
    check(not unavailable.load_into(sim).ok and unavailable.blocked,"unavailable explicit")
    print(JSON.stringify({"suite":"save_store","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
