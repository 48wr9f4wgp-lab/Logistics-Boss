extends RefCounted
## One campaign namespace, a rolling backup, and a write-once pre-schema-4 archive.
## No archive is created during loading, and no protected slot is repaired/reset.
const FORMAT := "flotra-campaign"
const VERSION := 1
const MAX_TEXT := 2800000
const PATH := "user://campaign-v1.json"
const BACKUP := "user://campaign-v1.backup.json"
const ARCHIVE := "user://campaign-v1.pre-v4.json"
const WRITER_LOCK := "user://campaign-v1.writer.lock"
var blocked := false
var status := "未保存"
var _last_good := ""
var _observed: Dictionary = {}
var _archive_source := ""
var _archive_validated := ""
var _archive_digest := ""

func encode(data: Dictionary, pre_v4_sha256: String = "") -> String:
    var bytes := var_to_bytes(data)
    var envelope := {"format":FORMAT,"version":VERSION,"sha256":bytes.hex_encode().sha256_text(),"payload":Marshalls.raw_to_base64(bytes)}
    if not pre_v4_sha256.is_empty(): envelope.pre_v4_sha256 = pre_v4_sha256
    return JSON.stringify(envelope)

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
    for key in envelope:
        if not key in ["format","version","sha256","payload","pre_v4_sha256"]: return {"ok":false,"reason":"invalid_envelope"}
    var digest: Variant = envelope.get("pre_v4_sha256", "")
    if envelope.has("pre_v4_sha256") and not _valid_digest(digest): return {"ok":false,"reason":"invalid_archive_binding"}
    var bytes := Marshalls.base64_to_raw(envelope.payload)
    if bytes.is_empty() or bytes.size() > 2000000: return {"ok":false,"reason":"invalid_payload"}
    if bytes.hex_encode().sha256_text() != envelope.sha256: return {"ok":false,"reason":"checksum"}
    # bytes_to_var deliberately excludes object deserialization.
    var data: Variant = bytes_to_var(bytes)
    if not data is Dictionary: return {"ok":false,"reason":"invalid_data"}
    if not digest.is_empty() and (not data.get("schema") is int or data.schema != 4): return {"ok":false,"reason":"invalid_archive_binding"}
    return {"ok":true,"data":data,"pre_v4_sha256":digest}

func _valid_digest(value: Variant) -> bool:
    if not value is String or value.length() != 64: return false
    for character in value:
        if not character in "0123456789abcdef": return false
    return true

func _read_pair() -> Dictionary:
    if OS.has_feature("web"):
        var result: Variant = JavaScriptBridge.eval("JSON.stringify(window.FlotraCampaignStore.read())", true)
        var parsed: Variant = JSON.parse_string(str(result))
        return parsed if parsed is Dictionary else {"ok":false,"reason":"bridge"}
    var pair := {"ok":true}
    for entry in [["primary",PATH],["backup",BACKUP],["archive",ARCHIVE]]:
        var exists := FileAccess.file_exists(entry[1]) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(entry[1]))
        pair[entry[0]+"_exists"] = exists
        pair[entry[0]] = ""
        if exists:
            var file := FileAccess.open(entry[1],FileAccess.READ)
            # An unreadable slot still exists and must remain protected, but
            # must not prevent a different validated slot from being inspected.
            if file == null or file.get_length() > MAX_TEXT: continue
            var bytes := file.get_buffer(file.get_length())
            if file.get_error() != OK: continue
            var text := bytes.get_string_from_utf8()
            # Reject undecodable/non-round-tripping bytes rather than archive a
            # lossy Unicode replacement of somebody's original file.
            if text.to_utf8_buffer() != bytes: continue
            pair[entry[0]] = text
    return pair

func _has_slot(pair: Dictionary, key: String) -> bool:
    return bool(pair.get(key+"_exists",not str(pair.get(key,"")).is_empty()))

func _snapshot(pair: Dictionary) -> Dictionary:
    var result := {}
    for key in ["primary","backup","archive"]:
        result[key] = str(pair.get(key,""))
        result[key+"_exists"] = _has_slot(pair,key)
    return result

func load_into(sim) -> Dictionary:
    var pair := _read_pair()
    if not pair.get("ok",false):
        blocked = true
        status = "保存機能を利用できません。以前のデータは保護しています。この画面の進行は保存されません"
        return {"ok":false,"reason":"storage_unavailable","fresh":false,"blocked":true}
    _observed = _snapshot(pair)
    blocked = false
    _last_good = ""
    _archive_source = ""
    _archive_validated = ""
    _archive_digest = ""
    if not _has_slot(pair,"primary") and not _has_slot(pair,"backup") and not _has_slot(pair,"archive"):
        status = "新しい倉庫"
        return {"ok":true,"fresh":true}
    var primary := str(pair.get("primary",""))
    var backup := str(pair.get("backup",""))
    var decoded := decode(primary)
    if decoded.get("ok",false):
        var imported: Dictionary = sim.import_release_state(decoded.data)
        if imported.get("ok",false):
            _last_good = primary
            var result := {"ok":true,"fresh":false,"restored":true,"migrated":imported.get("migrated",false),"source_schema":decoded.data.get("schema")}
            var reason := _inspect_protection(pair,sim)
            if not reason.is_empty():
                _block(reason)
                result.merge({"blocked":true,"reason":reason})
            else:
                status = "保存データを読み込みました"
            return result
    # The archive is never an automatic recovery source or a reason to reset.
    blocked = true
    decoded = decode(backup)
    if decoded.get("ok",false):
        var imported: Dictionary = sim.import_release_state(decoded.data)
        if imported.get("ok",false):
            status = "バックアップを読み込みました。元のデータを保護しているため、この先の進行は保存されません"
            return {"ok":true,"fresh":false,"restored":true,"backup":true,"blocked":true,"migrated":imported.get("migrated",false),"source_schema":decoded.data.get("schema")}
    status = "保存データを読み込めません。更新前の保存データも保護しています。この画面の進行は保存されません"
    return {"ok":false,"fresh":false,"reason":"unrecognized_save","blocked":true}

func _valid_for_sim(text: String, sim) -> bool:
    var decoded := decode(text)
    if not decoded.get("ok",false): return false
    return _valid_data_for_sim(decoded.data,sim)

func _valid_data_for_sim(data: Dictionary, sim) -> bool:
    var schema: Variant = data.get("schema")
    if not schema is int or schema < 1 or schema > 4: return false
    var candidate = sim.get_script().new()
    # Schema4 exposes the same strict acceptance core without preparing unused
    # playable route caches. Frozen models retain their full importer fallback.
    var imported: Dictionary = candidate.validate_release_state(data) if candidate.has_method("validate_release_state") else candidate.import_release_state(data)
    return imported.get("ok",false)

func _old_schema(decoded: Dictionary) -> bool:
    if not decoded.get("ok",false): return false
    var schema: Variant = decoded.data.get("schema")
    return schema is int and schema >= 1 and schema <= 3

func _valid_archive(text: String) -> bool:
    var decoded := decode(text)
    if not _old_schema(decoded): return false
    # Explicit frozen dispatch: never validate an old archive with permissive
    # field stripping or the changing production model's dynamic catalog.
    var scripts := {1:"res://prototype/release_sim.gd",2:"res://prototype/growth_v2_sim.gd",3:"res://prototype/growth_v3_sim.gd"}
    var script = load(scripts[decoded.data.schema])
    if script == null: return false
    var candidate = script.new()
    var imported: Dictionary = candidate.import_release_state(decoded.data)
    return imported.get("ok",false)

func _inspect_protection(pair: Dictionary, sim) -> String:
    var primary := decode(str(pair.get("primary","")))
    var backup := decode(str(pair.get("backup","")))
    if _has_slot(pair,"backup") and not _valid_for_sim(str(pair.backup),sim): return "backup_unrecognized"
    var archive := str(pair.get("archive",""))
    if _has_slot(pair,"archive"):
        if not _valid_archive(archive): return "archive_unrecognized"
        _archive_validated = archive
        _archive_digest = archive.sha256_text()
    # The primary wins. A mixed-version rolling backup is eligible only if the
    # primary is already schema4 and has no previously established binding.
    if _old_schema(primary):
        _archive_source = str(pair.primary)
    elif primary.get("ok",false) and primary.data.get("schema") == 4 and _old_schema(backup):
        _archive_source = str(pair.backup)
    if not _archive_source.is_empty():
        if not _valid_archive(_archive_source): return "archive_source_invalid"
        if not _archive_validated.is_empty() and _archive_source != _archive_validated: return "archive_conflict"
    var primary_binding := str(primary.get("pre_v4_sha256",""))
    var backup_binding := str(backup.get("pre_v4_sha256",""))
    for binding in [primary_binding,backup_binding]:
        if not binding.is_empty() and (archive.is_empty() or binding != _archive_digest): return "archive_conflict"
    if not _archive_validated.is_empty() and _archive_source.is_empty() and primary_binding.is_empty(): return "archive_conflict"
    if _archive_validated.is_empty() and not _archive_source.is_empty(): _archive_digest = _archive_source.sha256_text()
    return ""

func _block(reason: String) -> void:
    blocked = true
    if reason == "archive_conflict":
        status = "更新前の保存データが記録と一致しません。元のデータを保護するため、この先の進行は保存されません"
    elif reason == "archive_write_failed":
        status = "更新前の保存データを別に保管できません。以前の進行は保持していますが、この先の進行は保存されません"
    elif reason.begins_with("archive"):
        status = "更新前の保存データを確認できません。以前のデータを保護するため、この先の進行は保存されません"
    elif reason == "storage_unavailable":
        status = "保存機能を利用できません。以前のデータは保護しています。この画面の進行は保存されません"
    elif reason == "validation_required":
        status = "保存データを安全に読み直す必要があります。以前のデータを保護するため、この画面の進行は保存されません"
    elif reason == "backup_unrecognized":
        status = "バックアップの確認が必要です。データ保護のため、この先の進行は保存されません"
    else:
        status = "別の画面または保存領域でデータが変更されました。そのデータを保護するため、この画面の進行は保存されません"

func save_from(sim) -> Dictionary:
    if blocked: return {"ok":false,"reason":"blocked"}
    # A direct first save is allowed only into verified empty storage. Existing
    # progress must first have gone through load_into and full domain validation.
    if _observed.is_empty():
        var pair := _read_pair()
        if not pair.get("ok",false):
            _block("storage_unavailable")
            return {"ok":false,"reason":"storage_unavailable"}
        if _has_slot(pair,"primary") or _has_slot(pair,"backup") or _has_slot(pair,"archive"):
            _block("validation_required")
            return {"ok":false,"reason":"validation_required"}
        _observed = _snapshot(pair)
    var data: Dictionary = sim.export_release_state()
    var schema: Variant = data.get("schema")
    if not schema is int or schema < 1 or schema > 4:
        status = "進行データの確認に失敗したため保存できません。以前のデータは保護しています"
        return {"ok":false,"reason":"invalid_export"}
    # Older scenes remain usable in isolated compatibility tests. The production
    # schema4 exporter must pass its complete strict importer before any write.
    var digest := _archive_digest if schema == 4 else ""
    var text := encode(data,digest)
    if text.length() > MAX_TEXT:
        status = "保存データが大きすぎるため保存できません。画面を閉じると未保存の進行が失われます"
        return {"ok":false,"reason":"too_large"}
    # The exact exported Dictionary goes through the identical strict importer.
    # Avoid decoding our own fresh envelope just to recover those same values.
    # Stored/foreign text still always takes the checksum+decode path above.
    if not _valid_data_for_sim(data,sim):
        status = "進行データの確認に失敗したため保存できません。以前のデータは保護しています"
        return {"ok":false,"reason":"invalid_export"}
    var source := _archive_source
    # Do not pin an old checkpoint until an actual schema4 save is attempted.
    if schema != 4: _archive_source = ""
    var result: Dictionary
    if OS.has_feature("web"):
        var protection := {"archiveSource":_archive_source,"validatedArchive":_archive_validated,"archiveDigest":digest}
        var response: Variant = JavaScriptBridge.eval("JSON.stringify(window.FlotraCampaignStore.write(%s,%s))" % [JSON.stringify(text),JSON.stringify(protection)],true)
        var parsed: Variant = JSON.parse_string(str(response))
        result = parsed if parsed is Dictionary else {"ok":false,"reason":"bridge"}
    else:
        result = _write_native(text)
    if result.get("ok",false):
        _last_good = text
        if not _archive_source.is_empty(): _archive_validated = _archive_source
        _archive_source = ""
        status = "自動保存済み"
    else:
        _archive_source = source
        var reason := str(result.get("reason",""))
        status = "保存できませんでした。画面を閉じると未保存の進行が失われます"
        if reason == "writer_unavailable": status = "保存できません。他のタブや画面で開いていないか確認してください。読み込み直すと未保存の進行は失われます"
        elif reason.begins_with("archive") or reason in ["concurrent_change","existing_unrecognized","backup_unrecognized","validation_required"]:
            _block(reason)
        elif not OS.has_feature("web") or reason in ["storage_write_failed","bridge"]:
            # A failed filesystem commit may have advanced only the backup.
            # Require a fresh validated load instead of guessing about its state.
            blocked = true
    return result

func _native_matches() -> bool:
    var current := _read_pair()
    return current.get("ok",false) and _snapshot(current) == _observed

func _write_file(path: String, text: String) -> bool:
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null: return false
    file.store_string(text)
    file.flush()
    var ok := file.get_error() == OK
    file.close()
    return ok and FileAccess.get_file_as_string(path) == text

func _rename_file(from: String, to: String) -> bool:
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(from),ProjectSettings.globalize_path(to)) == OK

func _write_native(text: String) -> Dictionary:
    # Atomic directory creation serializes cooperating native instances. A lock
    # left by a crash fails closed; it is never silently deleted or taken over.
    if DirAccess.make_dir_absolute(ProjectSettings.globalize_path(WRITER_LOCK)) != OK:
        return {"ok":false,"reason":"writer_unavailable"}
    var result := _write_native_locked(text)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(WRITER_LOCK))
    return result

func _native_archive_exists() -> bool:
    return FileAccess.file_exists(ARCHIVE) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ARCHIVE))

func _write_native_locked(text: String) -> Dictionary:
    if not _native_matches(): return {"ok":false,"reason":"concurrent_change"}
    # Stage complete files before replacing either live slot. Partial writes and
    # failed renames cannot truncate a valid primary/backup/archive.
    if not _write_file(PATH+".tmp",text): return {"ok":false,"reason":"write"}
    if not _last_good.is_empty() and not _write_file(BACKUP+".tmp",_last_good): return {"ok":false,"reason":"backup_write"}
    if not _archive_source.is_empty() and not _observed.archive_exists:
        if not _write_file(ARCHIVE+".tmp",_archive_source): return {"ok":false,"reason":"archive_write_failed"}
        if not _native_matches(): return {"ok":false,"reason":"concurrent_change"}
        if _native_archive_exists(): return {"ok":false,"reason":"archive_conflict"}
        if not _rename_file(ARCHIVE+".tmp",ARCHIVE): return {"ok":false,"reason":"archive_write_failed"}
        _observed.archive = _archive_source
        _observed.archive_exists = true
    if not _native_matches(): return {"ok":false,"reason":"concurrent_change"}
    if not _last_good.is_empty():
        if not _rename_file(BACKUP+".tmp",BACKUP): return {"ok":false,"reason":"backup_rename"}
        _observed.backup = _last_good
        _observed.backup_exists = true
    if not _native_matches(): return {"ok":false,"reason":"concurrent_change"}
    if not _rename_file(PATH+".tmp",PATH): return {"ok":false,"reason":"rename"}
    _observed.primary = text
    _observed.primary_exists = true
    if not _native_matches(): return {"ok":false,"reason":"concurrent_change"}
    return {"ok":true}
