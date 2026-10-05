extends RefCounted

# Explicit, disposable test input. Never fall back to ignored build artifacts or
# a campaign save. The hash pins the original frozen-v3 earned checkpoint bytes.
const ENV := "FLOTRA_EARNED_FIXTURE"
const SHA256 := "f701c20bca04f7578fad3850ec02a36c6ccfc256a3f0a6c9a5917acca8819265"

static func read_required() -> Dictionary:
    var path := OS.get_environment(ENV)
    if path.is_empty(): return _bad("Set "+ENV+" to the generated disposable earned fixture")
    if not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):
        return _bad(ENV+" must be an explicit absolute filesystem path")
    if not FileAccess.file_exists(path): return _bad("Earned fixture is missing: "+path)
    var file := FileAccess.open(path,FileAccess.READ)
    if file == null: return _bad("Cannot open earned fixture: "+path)
    if file.get_length() < 4 or file.get_length() > 2097152:
        file.close()
        return _bad("Earned fixture has an invalid size")
    var actual := FileAccess.get_sha256(path)
    if actual != SHA256:
        file.close()
        return _bad("Earned fixture SHA256 mismatch: "+actual)
    var data: Variant = file.get_var(false)
    file.close()
    if not data is Dictionary: return _bad("Earned fixture is null or is not a Dictionary")
    if data.get("schema") != 3 or not data.get("schema") is int:
        return _bad("Earned fixture is not frozen schema3")
    return {"ok":true,"data":data,"path":path,"sha256":actual}

static func _bad(message: String) -> Dictionary:
    return {"ok":false,"error":message}
