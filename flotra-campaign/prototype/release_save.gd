extends RefCounted
## Dedicated campaign store. Never opens production /userfs or production keys.
const FORMAT := "flotra-campaign"
const VERSION := 1
const MAX_TEXT := 2800000
const PATH := "user://campaign-v1.json"
const BACKUP := "user://campaign-v1.backup.json"
var blocked := false
var status := "未保存"
var _last_good := ""

func encode(data: Dictionary) -> String:
    var bytes := var_to_bytes(data)
    return JSON.stringify({"format":FORMAT,"version":VERSION,"sha256":bytes.hex_encode().sha256_text(),"payload":Marshalls.raw_to_base64(bytes)})

func decode(text: String) -> Dictionary:
    if text.is_empty(): return {"ok":false,"reason":"missing"}
    if text.length() > MAX_TEXT: return {"ok":false,"reason":"too_large"}
    var json := JSON.new()
    if json.parse(text) != OK: return {"ok":false,"reason":"invalid_json"}
    var envelope: Variant = json.data
    if not envelope is Dictionary: return {"ok":false,"reason":"invalid_json"}
    if envelope.get("format") != FORMAT: return {"ok":false,"reason":"foreign_format"}
    if envelope.get("version") != VERSION: return {"ok":false,"reason":"unsupported_version"}
    if not envelope.get("payload") is String or not envelope.get("sha256") is String: return {"ok":false,"reason":"invalid_envelope"}
    var bytes := Marshalls.base64_to_raw(envelope.payload)
    if bytes.is_empty() or bytes.size() > 2000000: return {"ok":false,"reason":"invalid_payload"}
    if bytes.hex_encode().sha256_text() != envelope.sha256: return {"ok":false,"reason":"checksum"}
    # bytes_to_var deliberately excludes object deserialization.
    var data: Variant = bytes_to_var(bytes)
    if not data is Dictionary: return {"ok":false,"reason":"invalid_data"}
    return {"ok":true,"data":data}

func _read_pair() -> Dictionary:
    if OS.has_feature("web"):
        var result: Variant = JavaScriptBridge.eval("JSON.stringify(window.FlotraCampaignStore.read())", true)
        var parsed: Variant = JSON.parse_string(str(result))
        return parsed if parsed is Dictionary else {"ok":false,"reason":"bridge"}
    return {"ok":true,"primary":FileAccess.get_file_as_string(PATH) if FileAccess.file_exists(PATH) else "","backup":FileAccess.get_file_as_string(BACKUP) if FileAccess.file_exists(BACKUP) else ""}

func load_into(sim) -> Dictionary:
    var pair := _read_pair()
    if not pair.get("ok",false):
        blocked = true
        status = "保存を利用できません"
        return {"ok":false,"reason":"storage_unavailable","fresh":false}
    var primary := str(pair.get("primary",""))
    var backup := str(pair.get("backup",""))
    if primary.is_empty() and backup.is_empty():
        status = "新しい倉庫"
        return {"ok":true,"fresh":true}
    var decoded := decode(primary)
    if decoded.ok:
        var imported: Dictionary = sim.import_release_state(decoded.data)
        if imported.get("ok",false):
            _last_good = primary
            status = "保存から再開"
            if not backup.is_empty() and not _valid_for_sim(backup,sim):
                blocked = true
                status = "予備保存を保護中・上書き停止"
                return {"ok":true,"fresh":false,"restored":true,"blocked":true}
            return {"ok":true,"fresh":false,"restored":true}
    # Never replace unrecognized/corrupt data automatically, including a future version.
    blocked = true
    decoded = decode(backup)
    if decoded.ok:
        var imported: Dictionary = sim.import_release_state(decoded.data)
        if imported.get("ok",false):
            status = "予備から再開・保存停止中"
            return {"ok":true,"fresh":false,"restored":true,"backup":true,"blocked":true}
    status = "保存を読めません・上書き停止"
    return {"ok":false,"fresh":false,"reason":"unrecognized_save","blocked":true}

func _valid_for_sim(text: String, sim) -> bool:
    var decoded := decode(text)
    if not decoded.get("ok",false): return false
    var candidate = sim.get_script().new()
    var imported: Dictionary = candidate.import_release_state(decoded.data)
    return imported.get("ok",false)

func save_from(sim) -> Dictionary:
    if blocked: return {"ok":false,"reason":"blocked"}
    var data: Dictionary = sim.export_release_state()
    var text := encode(data)
    if text.length() > MAX_TEXT:
        status = "保存容量を超えました"
        return {"ok":false,"reason":"too_large"}
    var result: Dictionary
    if OS.has_feature("web"):
        var response: Variant = JavaScriptBridge.eval("JSON.stringify(window.FlotraCampaignStore.write(%s))" % JSON.stringify(text), true)
        var parsed: Variant = JSON.parse_string(str(response))
        result = parsed if parsed is Dictionary else {"ok":false,"reason":"bridge"}
    else:
        result = _write_native(text)
    if result.get("ok",false):
        _last_good = text
        status = "自動保存済み"
    else:
        status = "保存失敗・閉じると進行を失います"
        if result.get("reason","") == "writer_unavailable": status = "保存停止・他のタブを閉じて再読込"
        elif result.get("reason","") == "concurrent_change":
            blocked = true
            status = "他の画面で進行更新・上書き停止"
    return result

func _write_native(text: String) -> Dictionary:
    if not _last_good.is_empty():
        var backup := FileAccess.open(BACKUP,FileAccess.WRITE)
        if backup == null: return {"ok":false,"reason":"backup_write"}
        backup.store_string(_last_good)
        backup.flush()
        if backup.get_error() != OK: return {"ok":false,"reason":"backup_write"}
    var temp := PATH+".tmp"
    var file := FileAccess.open(temp,FileAccess.WRITE)
    if file == null: return {"ok":false,"reason":"write"}
    file.store_string(text)
    file.flush()
    if file.get_error() != OK: return {"ok":false,"reason":"write"}
    file.close()
    var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(PATH))
    return {"ok":error==OK,"reason":"" if error==OK else "rename"}
