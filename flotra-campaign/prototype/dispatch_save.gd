extends RefCounted

# The old campaign files are read-only. The native user directory stays the
# same so old installations can be found, but every write uses new v5 paths.
const LegacyCodec = preload("res://prototype/release_save.gd")
const FORMAT := "flotra-campaign"
const VERSION := 5
const MAX_TEXT := 2800000
const MAX_PAYLOAD_BYTES := 2000000
const PATH := "user://campaign-dispatch-v5.json"
const BACKUP := "user://campaign-dispatch-v5.backup.json"
const WRITER_LOCK := "user://campaign-dispatch-v5.writer.lock"
const OLD_PATH := "user://campaign-v1.json"
const OLD_BACKUP := "user://campaign-v1.backup.json"
var blocked := false
var status := "未保存"
var _read_ready := false
var _observed: Dictionary = {}
var _source := ""

func encode(data: Dictionary) -> String:
    var bytes := var_to_bytes(data)
    if bytes.is_empty() or bytes.size() > MAX_PAYLOAD_BYTES: return ""
    return _encode_bytes(bytes)

func _encode_bytes(bytes: PackedByteArray) -> String:
    return JSON.stringify({"format":FORMAT,"version":VERSION,"sha256":bytes.hex_encode().sha256_text(),"payload":Marshalls.raw_to_base64(bytes)})

func decode(text: String) -> Dictionary:
    if text.is_empty(): return {"ok":false,"reason":"missing"}
    if text.length() > MAX_TEXT: return {"ok":false,"reason":"too_large"}
    var json := JSON.new()
    if json.parse(text) != OK: return {"ok":false,"reason":"invalid_json"}
    var parsed: Variant = json.data
    if not parsed is Dictionary: return {"ok":false,"reason":"invalid_json"}
    if parsed.get("format") != FORMAT: return {"ok":false,"reason":"foreign_format"}
    if parsed.get("version") != VERSION: return {"ok":false,"reason":"unsupported_version"}
    if parsed.size() != 4 or not parsed.get("payload") is String or not parsed.get("sha256") is String:
        return {"ok":false,"reason":"invalid_envelope"}
    var bytes := Marshalls.base64_to_raw(parsed.payload)
    if bytes.is_empty() or bytes.size() > MAX_PAYLOAD_BYTES: return {"ok":false,"reason":"invalid_payload"}
    if Marshalls.raw_to_base64(bytes) != parsed.payload: return {"ok":false,"reason":"invalid_payload"}
    if bytes.hex_encode().sha256_text() != parsed.sha256: return {"ok":false,"reason":"checksum"}
    var data: Variant = bytes_to_var(bytes) # Never deserialize Objects.
    if not data is Dictionary: return {"ok":false,"reason":"invalid_data"}
    return {"ok":true,"data":data}

func _read_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        if DirAccess.dir_exists_absolute(path): return {"ok":false,"reason":"not_a_file"}
        return {"ok":true,"present":false,"text":""}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {"ok":false,"reason":"storage_unavailable"}
    if file.get_length() > MAX_TEXT: return {"ok":false,"reason":"too_large"}
    var text := file.get_as_text()
    var error := file.get_error()
    file.close()
    return {"ok":error in [OK, ERR_FILE_EOF],"present":true,"text":text}

func _native_snapshot() -> Dictionary:
    var primary := _read_file(PATH)
    var backup := _read_file(BACKUP)
    if not primary.ok or not backup.ok: return {"ok":false,"reason":"storage_unavailable"}
    var pair := {"ok":true,"source":"v5","primary":primary.text,"backup":backup.text,"primary_present":primary.present,"backup_present":backup.present}
    if not primary.present and not backup.present:
        var old_primary := _read_file(OLD_PATH)
        var old_backup := _read_file(OLD_BACKUP)
        if not old_primary.ok or not old_backup.ok: return {"ok":false,"reason":"storage_unavailable"}
        pair.source = "legacy"
        pair.primary = old_primary.text
        pair.backup = old_backup.text
        pair.primary_present = old_primary.present
        pair.backup_present = old_backup.present
    return pair

func _read_pair() -> Dictionary:
    if OS.has_feature("web"):
        var response: Variant = JavaScriptBridge.eval("JSON.stringify(window.FlotraDispatchStore.read())", true)
        var parsed: Variant = JSON.parse_string(str(response))
        return parsed if parsed is Dictionary else {"ok":false,"reason":"bridge"}
    return _native_snapshot()

func _decode_source(text: String) -> Dictionary:
    return LegacyCodec.new().decode(text) if _source == "legacy" else decode(text)

func _unsupported(decoded: Dictionary) -> bool:
    if decoded.get("reason") == "unsupported_version": return true
    if not decoded.get("ok",false): return false
    var schema: Variant = decoded.data.get("schema")
    return not schema is int or schema not in ([1,2,3] if _source == "legacy" else [5])

func _valid_for_sim(decoded: Dictionary, sim) -> bool:
    if not decoded.get("ok",false) or _unsupported(decoded): return false
    var candidate = sim.get_script().new()
    return candidate.import_release_state(decoded.data).get("ok",false)

func load_into(sim) -> Dictionary:
    # A blocked store is terminal for this session. Reopening is explicit.
    if blocked: return {"ok":false,"reason":"blocked","blocked":true,"fresh":false}
    var pair := _read_pair()
    if not pair.get("ok",false): return _stop("storage_unavailable", "保存機能を利用できません。以前のデータを守るため、進行を停止しました")
    _observed = pair.duplicate(true)
    _source = str(pair.source)
    _read_ready = true
    if not pair.primary_present and not pair.backup_present:
        status = "新しい倉庫"
        return {"ok":true,"fresh":true}
    var primary := _decode_source(str(pair.primary))
    var backup := _decode_source(str(pair.backup))
    if (pair.primary_present and _unsupported(primary)) or (pair.backup_present and _unsupported(backup)):
        return _stop("unsupported_schema", "別の版の保存データがあります。上書きせず進行を停止しました。対応する版で開いてください")
    if pair.primary_present and _valid_for_sim(primary,sim):
        var imported: Dictionary = sim.import_release_state(primary.data)
        if not imported.get("ok",false): return _stop("invalid_save", "保存データを確認できません。元のデータを保護して進行を停止しました")
        if pair.backup_present and not _valid_for_sim(backup,sim):
            blocked = true
            status = "バックアップの確認が必要です。元のデータを保護して進行を停止しました"
            return {"ok":true,"fresh":false,"restored":true,"blocked":true}
        status = "旧保存を読み込みました。旧データを残して新版専用に保存します" if _source == "legacy" else "保存データを読み込みました"
        return {"ok":true,"fresh":false,"restored":true,"migrated":_source=="legacy","source_schema":primary.data.schema}
    # Recovery stays in the selected generation and is always read-only.
    # Never silently fall back from existing v5 data to an older campaign.
    if pair.backup_present and _valid_for_sim(backup,sim):
        sim.import_release_state(backup.data)
        blocked = true
        status = "バックアップを読み込みました。元のデータを保護して進行を停止しました"
        return {"ok":true,"fresh":false,"restored":true,"backup":true,"blocked":true}
    return _stop("unrecognized_save", "保存データを読み込めません。元のデータを保護して進行を停止しました")

func _stop(reason: String, message: String) -> Dictionary:
    blocked = true
    status = message
    return {"ok":false,"reason":reason,"blocked":true,"fresh":false}

func save_from(sim) -> Dictionary:
    if blocked: return {"ok":false,"reason":"blocked"}
    if not _read_ready: return {"ok":false,"reason":"load_required"}
    var data: Dictionary = sim.export_release_state()
    # Preserve the released 2 MB preflight: serialize once and reject before
    # hashing/base64/encoding or touching any primary, backup or temporary file.
    var bytes := var_to_bytes(data)
    if bytes.size() > MAX_PAYLOAD_BYTES:
        status = "保存データが大きすぎるため保存できません。画面を閉じると未保存の進行が失われます"
        return {"ok":false,"reason":"too_large"}
    var candidate = sim.get_script().new()
    if data.get("schema") != 5 or not candidate.import_release_state(data).get("ok",false):
        return _stop("invalid_state", "現在の状態を検証できません。以前の保存を保護して進行を停止しました")
    var text := _encode_bytes(bytes)
    if text.is_empty() or text.length() > MAX_TEXT:
        status = "保存データが大きすぎるため保存できません。画面を閉じると未保存の進行が失われます"
        return {"ok":false,"reason":"too_large"}
    var result: Dictionary = _write(text)
    if result.get("ok",false):
        _source = "v5"
        status = "自動保存済み"
    else:
        status = "保存できませんでした。画面を閉じると未保存の進行が失われます"
        if result.get("reason") in ["writer_unavailable","legacy_writer_unavailable"]:
            return _stop(str(result.reason), "保存を安全に開始できないため、データを保護して進行を停止しました。旧版を含む他のタブを閉じて再読み込みしてください。解消しない場合はブラウザーの保存対応を確認してください。未保存の進行は失われます")
        elif result.get("reason") == "native_writer_unavailable":
            status = "別の画面が保存中、または前回の保存が中断されました。元の保存は保護しています。未保存の進行は画面を閉じると失われます"
        elif result.get("reason") in ["concurrent_change","write_uncertain"]:
            return _stop(str(result.reason), "別の画面の更新または書込み結果を確認できません。データを保護して進行を停止しました")
    return result

func _write(text: String) -> Dictionary:
    if OS.has_feature("web"):
        var response: Variant = JavaScriptBridge.eval("JSON.stringify(window.FlotraDispatchStore.write(%s))" % JSON.stringify(text),true)
        var parsed: Variant = JSON.parse_string(str(response))
        return parsed if parsed is Dictionary else {"ok":false,"reason":"bridge"}
    return _write_native(text)

func _atomic_replace(path: String, text: String) -> Dictionary:
    var temp := path + ".tmp"
    var file := FileAccess.open(temp,FileAccess.WRITE)
    if file == null: return {"ok":false,"reason":"write"}
    file.store_string(text)
    file.flush()
    var error := file.get_error()
    file.close()
    if error != OK: return {"ok":false,"reason":"write"}
    var checked := _read_file(temp)
    if not checked.get("ok",false) or checked.get("text") != text: return {"ok":false,"reason":"write"}
    error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
    return {"ok":error==OK,"reason":"" if error==OK else "rename"}

func _write_native(text: String) -> Dictionary:
    # Atomic directory creation serializes cooperating native v5 writers.
    # A crash can leave this marker behind; fail closed rather than guessing
    # that an existing writer is dead and removing its lock automatically.
    var lock_path := ProjectSettings.globalize_path(WRITER_LOCK)
    if DirAccess.make_dir_absolute(lock_path) != OK:
        return {"ok":false,"reason":"native_writer_unavailable"}
    var result := _commit_native(text)
    if DirAccess.remove_absolute(lock_path) != OK:
        return {"ok":false,"reason":"write_uncertain"}
    return result

func _commit_native(text: String) -> Dictionary:
    var current := _native_snapshot()
    if not current.get("ok",false): return current
    if current != _observed: return {"ok":false,"reason":"concurrent_change"}
    if current.source == "v5" and current.primary_present:
        var rotated := _atomic_replace(BACKUP,str(current.primary))
        if not rotated.ok: return rotated
        _observed.backup = current.primary
        _observed.backup_present = true
    var written := _atomic_replace(PATH,text)
    if not written.ok: return written
    _observed = {"ok":true,"source":"v5","primary":text,"backup":str(current.primary) if current.source=="v5" and current.primary_present else "","primary_present":true,"backup_present":current.source=="v5" and current.primary_present}
    return {"ok":true,"migrated":current.source=="legacy"}
