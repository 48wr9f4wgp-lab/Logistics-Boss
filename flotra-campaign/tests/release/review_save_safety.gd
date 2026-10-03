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
func envelope(bytes: PackedByteArray) -> String:
    return JSON.stringify({"format":"flotra-campaign","version":1,"sha256":bytes.hex_encode().sha256_text(),"payload":Marshalls.raw_to_base64(bytes)})
func _init() -> void:
    var store := MemoryStore.new()
    var sim := FakeSim.new()
    check(store.decode(envelope(var_to_bytes([1,2,3]))).get("reason") == "invalid_data", "non-dictionary decoded payload rejected")
    check(store.decode(envelope(PackedByteArray([1,2,3]))).get("ok") == false, "malformed variant rejected")
    check(store.decode("x".repeat(Save.MAX_TEXT+1)).get("reason") == "too_large", "oversized envelope rejected before parse")
    var object := Resource.new()
    object.resource_name = "untrusted marker"
    var object_payload := envelope(var_to_bytes_with_objects({"schema":1,"object":object}))
    var object_result := store.decode(object_payload)
    check(not object_result.get("ok",false) or not object_result.data.get("object") is Object, "object reconstruction disabled")
    var future := {"schema":2}
    store.pair.primary = store.encode(future)
    store.pair.backup = store.encode(sim.value)
    var result := store.load_into(sim)
    check(result.get("ok",false) and result.get("backup",false), "future domain schema falls back to valid backup")
    check(store.blocked and not store.save_from(sim).ok, "future domain primary is never overwritten")
    check(store.pair.primary == store.encode(future), "future domain bytes preserved")
    for bad_backup in ["{broken", store.encode({"schema":2}), store.encode(sim.value).replace('"version":1','"version":2')]:
        var backup_guard := MemoryStore.new()
        backup_guard.pair = {"ok":true,"primary":backup_guard.encode(sim.value),"backup":bad_backup}
        var saved_pair: Dictionary = backup_guard.pair.duplicate(true)
        var primary_resumed: Dictionary = backup_guard.load_into(sim)
        check(primary_resumed.get("ok",false) and primary_resumed.get("restored",false), "valid primary still loads with unknown backup")
        check(backup_guard.blocked and not backup_guard.save_from(sim).ok, "unknown backup blocks all saving")
        check(backup_guard.pair == saved_pair, "unknown backup and primary stay byte-for-byte unchanged")
    check(OS.get_user_data_dir().ends_with("FLOTRA-campaign-release-v1"), "dedicated native user directory")
    var native := Save.new()
    var path := ProjectSettings.globalize_path(Save.PATH)
    var review_root := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    if review_root.is_empty(): review_root = "/tmp/flotra-release-review/"
    check(path.begins_with(review_root), "test native writes limited to private temp directory")
    if path.begins_with(review_root):
        check(native.save_from(sim).ok, "native first atomic write succeeds")
        sim.value.time = 99.0
        check(native.save_from(sim).ok, "native update atomic write succeeds")
        var fresh_store := Save.new()
        var fresh_sim := FakeSim.new()
        check(fresh_store.load_into(fresh_sim).get("restored",false) and fresh_sim.value.time == 99.0, "native new session resumes latest progress")
        check(fresh_store.decode(FileAccess.get_file_as_string(Save.BACKUP)).get("ok",false), "native backup decodes after update")
    print(JSON.stringify({"suite":"independent_save_safety","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
