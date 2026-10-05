extends RefCounted
## Shared native/actual-Web checks. Only explicitly disposable profiles may run.
const Save = preload("res://prototype/release_save.gd")
const Sim = preload("res://prototype/growth_sim.gd")
var checks := 0
var failures: Array[String] = []
var boundaries: Array = []
var current_label := ""

class EncodeSpy extends Save:
    var encodes := 0
    func _encode_bytes(bytes: PackedByteArray) -> String:
        encodes += 1
        return super._encode_bytes(bytes)

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(current_label + ": " + label)

func allowed() -> bool:
    if OS.has_feature("web"):
        return str(JavaScriptBridge.eval("JSON.stringify(window.flotraDisposableSizeTest === true)", true)) == "true"
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    return not sandbox.is_empty() and ProjectSettings.globalize_path("user://").begins_with(sandbox)

func reset_slots() -> void:
    if OS.has_feature("web"):
        JavaScriptBridge.eval("localStorage.removeItem('flotra.campaign.release.v1'); localStorage.removeItem('flotra.campaign.release.v1.backup'); window.flotraSizeWrites = 0;", true)
    else:
        for path in [Save.PATH, Save.BACKUP, Save.PATH + ".tmp"]:
            if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func pair() -> Dictionary:
    if OS.has_feature("web"):
        return JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify({primary:localStorage.getItem('flotra.campaign.release.v1')||'',backup:localStorage.getItem('flotra.campaign.release.v1.backup')||''})", true)))
    return {"primary":FileAccess.get_file_as_string(Save.PATH) if FileAccess.file_exists(Save.PATH) else "", "backup":FileAccess.get_file_as_string(Save.BACKUP) if FileAccess.file_exists(Save.BACKUP) else ""}

func envelope(bytes: PackedByteArray) -> String:
    # Frozen pre-fix formula, including SHA256 of lowercase hex text.
    return JSON.stringify({"format":"flotra-campaign","version":1,"sha256":bytes.hex_encode().sha256_text(),"payload":Marshalls.raw_to_base64(bytes)})

func padded(seed: Dictionary, target: int) -> Dictionary:
    var state := seed.duplicate(true)
    var chunks: Array = []
    state.sim.comparison = {"size_test": chunks}
    var remaining := target - var_to_bytes(state).size()
    # Exactly 1000 UTF-8 bytes, but only 334 Unicode characters.
    var chunk := "倉".repeat(333) + "a"
    var stride := var_to_bytes(chunk).size()
    while remaining >= stride:
        chunks.append(chunk)
        remaining -= stride
    if remaining < 8 and remaining > 0:
        chunks.pop_back()
        remaining += stride
    if remaining > 0: chunks.append("x".repeat(remaining - 8))
    check(var_to_bytes(state).size() == target, "exact emitted Variant byte count " + str(target))
    return state

func seed_pair(store, sim) -> Dictionary:
    check(store.load_into(sim).get("fresh", false), "fresh isolated store")
    check(store.save_from(sim).get("ok", false), "first small checkpoint")
    var older: String = pair().primary
    check(sim.set_preference("preferred_speed", 4).get("ok", false), "legal checkpoint change")
    check(store.save_from(sim).get("ok", false), "second small checkpoint")
    check(pair().backup == older and pair().primary != older, "distinct exact old backup")
    return pair()

func codec_boundaries(seed: Dictionary) -> void:
    current_label = "raw reader boundary"
    var store = Save.new()
    var original := var_to_bytes(seed)
    # These are reader inputs with ignored trailing bytes, NOT outputs of
    # var_to_bytes. Emitted dictionaries are aligned to multiples of four.
    for count in [1999999, 2000000, 2000001]:
        var bytes := original.duplicate()
        bytes.resize(count)
        var result: Dictionary = store.decode(envelope(bytes))
        check(result.get("ok",false) == (count <= 2000000), "reader exact raw count " + str(count))
        if result.get("ok",false): check(result.data == seed, "reader retains dictionary at " + str(count))
        else: check(result.get("reason") == "invalid_payload", "reader size reason")

func run() -> Dictionary:
    check(allowed(), "explicit disposable storage required")
    if not failures.is_empty(): return report()
    check(Save.MAX_PAYLOAD_BYTES == 2000000, "reader/writer contract remains exactly 2,000,000 bytes")
    var seed: Dictionary = Sim.new().export_release_state()
    codec_boundaries(seed)
    for count in [1999996, 2000000, 2000004, 2010000]:
        current_label = "writer " + str(count)
        reset_slots()
        var store = EncodeSpy.new()
        var sim = Sim.new()
        var before := seed_pair(store, sim)
        var old_good: String = store._last_good
        var large := padded(sim.export_release_state(), count)
        var imported: Dictionary = sim.import_release_state(large)
        check(imported.get("ok",false), "domain-valid Unicode fixture")
        check(sim.export_release_state() == large, "domain re-export exact")
        var bytes := var_to_bytes(large)
        var old_text := envelope(bytes)
        check(store.encode(large) == old_text, "public encode matches frozen successful codec")
        check(old_text.length() == old_text.to_utf8_buffer().size(), "ASCII envelope characters equal UTF-8 bytes")
        check(old_text.length() < Save.MAX_TEXT, "separate text bound does not detect raw overflow")
        var encodes_before: int = store.encodes
        var writes_before := int(str(JavaScriptBridge.eval("String(window.flotraSizeWrites)",true))) if OS.has_feature("web") else 0
        if OS.has_feature("web"): check(writes_before == 3, "real setItem spy sees all three seed writes")
        if not OS.has_feature("web"):
            var sentinel := FileAccess.open(Save.PATH+".tmp", FileAccess.WRITE)
            sentinel.store_string("untouched temporary sentinel")
            sentinel.close()
        var result: Dictionary = store.save_from(sim)
        var attempt_status: String = store.status
        if count <= Save.MAX_PAYLOAD_BYTES:
            check(result.get("ok",false), "accepted checkpoint commits")
            check(pair().primary == old_text and pair().backup == before.primary, "accepted bytes and backup exact")
            check(store.encodes == encodes_before + 1, "one encoding of accepted capture")
            check(store.status == "自動保存済み", "success status only after commit")
            var restored = Sim.new()
            var loaded: Dictionary = Save.new().load_into(restored)
            check(loaded.get("ok",false) and not loaded.get("blocked",false), "accepted bound reloads normally")
            check(restored.export_release_state() == large, "accepted bound restores exact 54-field state")
        else:
            check(not result.get("ok",true) and result.get("reason") == "too_large", "oversize rejected at save")
            check(store.encodes == encodes_before, "oversize rejected before hash/base64/envelope")
            check(pair() == before and store._last_good == old_good, "both slots and last-good unchanged")
            check(not store.blocked, "size failure does not mark valid old slots corrupt")
            check(store.status.contains("未保存の進行が失われます") and store.status != "自動保存済み", "clear Japanese unsaved warning")
            check(store.save_from(sim).get("reason") == "too_large" and pair() == before, "repeat rejected without rotation")
            if OS.has_feature("web"):
                check(int(str(JavaScriptBridge.eval("String(window.flotraSizeWrites)",true))) == writes_before, "zero browser storage writes on rejection")
            else:
                check(FileAccess.get_file_as_string(Save.PATH+".tmp") == "untouched temporary sentinel", "temp untouched on rejection")
            var restored = Sim.new()
            var loaded: Dictionary = Save.new().load_into(restored)
            check(loaded.get("ok",false) and not loaded.get("backup",false) and not loaded.get("blocked",false), "old primary reloads without fallback or block")
            check(envelope(var_to_bytes(restored.export_release_state())) == before.primary, "old primary state exact")
            check(sim.import_release_state(restored.export_release_state()).get("ok",false), "small valid fixture restored for retry")
            check(store.save_from(sim).get("ok",false), "valid retry after oversize still saves")
        boundaries.append({"raw_bytes":count,"envelope_chars":old_text.length(),"result":result,"status":attempt_status})
    current_label = "fresh oversize"
    reset_slots()
    var fresh = EncodeSpy.new()
    var sim = Sim.new()
    check(fresh.load_into(sim).get("fresh",false), "fresh load")
    check(sim.import_release_state(padded(seed, 2000004)).get("ok",false), "fresh large valid")
    check(fresh.save_from(sim).get("reason") == "too_large", "fresh too large rejected")
    check(pair() == {"primary":"","backup":""} and fresh._last_good.is_empty() and fresh.encodes == 0, "fresh rejection creates nothing")
    if not OS.has_feature("web"): check(not FileAccess.file_exists(Save.PATH+".tmp"), "fresh rejection creates no temp")
    check(sim.import_release_state(seed).get("ok",false), "return to small model")
    check(fresh.save_from(sim).get("ok",false), "fresh valid first write still works")
    check(pair().backup.is_empty(), "fresh write has no invented backup")
    return report()

func report() -> Dictionary:
    return {"suite":"save_size_preflight","platform":"web" if OS.has_feature("web") else "native","checks":checks,"failures":failures,"boundaries":boundaries}

func web_storage_failure() -> Dictionary:
    current_label = "browser quota"
    check(OS.has_feature("web") and allowed(), "explicit disposable Web context")
    if not failures.is_empty(): return report()
    reset_slots()
    var store = Save.new()
    var sim = Sim.new()
    var before := seed_pair(store, sim)
    var old_good: String = store._last_good
    check(sim.import_release_state(padded(sim.export_release_state(),1999996)).get("ok",false), "under-limit quota fixture valid")
    var quota: Variant = JavaScriptBridge.eval("(()=>{let n=0;try{for(;n<100;n++)localStorage.setItem('disposable-size-filler-'+n,'x'.repeat(100000));}catch(e){return JSON.stringify({name:e.name,chunks:n});}return '{}';})()", true)
    var exhausted: Dictionary = JSON.parse_string(str(quota))
    check(exhausted.get("name") == "QuotaExceededError", "actual browser quota exhausted")
    var result: Dictionary = store.save_from(sim)
    check(not result.get("ok",true) and result.get("reason") == "storage_write_failed", "below raw bound can still fail actual quota")
    check(pair().primary == before.primary and store._last_good == old_good, "quota failure preserves previous primary and last-good")
    check(store.status.contains("未保存の進行が失われます") and store.status != "自動保存済み", "quota retains unsaved feedback")
    check(store.decode(pair().backup).get("ok",false), "backup still decodes after quota failure")
    var output := report()
    output.quota = exhausted
    output.result = result
    return output
