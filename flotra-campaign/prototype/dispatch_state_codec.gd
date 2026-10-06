extends RefCounted

# Schema 5 owns the dispatch feature. Schema 4 belongs to an unrelated draft
# and is NEVER reinterpreted. Legacy validation is isolated from new rules.
const SCHEMA := 5
const FrozenV3 = preload("res://prototype/legacy_dispatch/growth_sim.gd")
const BOARD := "pick_dispatch_board"

static func export_state(sim, base: Dictionary) -> Dictionary:
    var state := base.duplicate(true)
    state.schema = SCHEMA
    state.dispatch = {"dispatch_window": sim.dispatch_window}
    return state

static func import_state(sim, source: Dictionary) -> Dictionary:
    if not source.get("schema") is int or source.schema not in [1, 2, 3, SCHEMA]:
        return _bad("unsupported_schema")
    var frozen = FrozenV3.new()
    if not frozen._safe_variant(source):
        return _bad("unsafe_variant")
    var state := source.duplicate(true)
    var migrated: bool = source.schema != SCHEMA
    if migrated:
        # Validate a disposable copy; do not export its normalized medal labels.
        var old_result: Dictionary = frozen.import_release_state(state.duplicate(true))
        if not old_result.get("ok", false): return old_result
        if source.schema == 1: state.growth = {"legacy_profile": true}
        if source.schema in [1, 2]:
            state.experience = {"operating_profile":false,"operation_mode":"balanced","preferences":{"preferred_speed":2,"pause_on_menus":false,"reduced_motion":false}}
        state.schema = SCHEMA
        state.dispatch = {"dispatch_window":6}

    if not frozen._keys_and_types(state, {"schema":5,"experience":{},"growth":{},"campaign":{},"sim":{},"dispatch":{}}):
        return _bad("schema5_shape")
    if not frozen._keys_and_types(state.dispatch, {"dispatch_window":6}) or state.dispatch.dispatch_window not in [6, 12]:
        return _bad("dispatch_window")

    # This projection is INTERNAL validation input, never a legacy save/export.
    # The candidate is still the new model, so its contract/upgrade definitions
    # enforce the complete new wallet ledger and new job's physical rules.
    var projected := state.duplicate(true)
    projected.erase("dispatch")
    projected.schema = 3
    var candidate = sim.get_script().new()
    var shape: Dictionary = candidate._validate_save_shape(projected)
    if not shape.get("ok",false): return shape
    candidate.dispatch_window = state.dispatch.dispatch_window
    candidate._load_release_unchecked(projected)
    var validation: Dictionary = candidate._validate_loaded_release()
    if not validation.get("ok",false): return validation

    var owned: bool = BOARD in candidate.purchased_upgrades
    if candidate.dispatch_window == 12 and not owned:
        return _bad("dispatch_board_required")
    if owned and (not candidate.contract_results.has("growth_4") or not ["crew_6","robot_4","auto_pack"].all(func(id): return id in candidate.purchased_upgrades)):
        return _bad("dispatch_prerequisites")
    # These are work-admission slots, not cargo/storage capacity. Never trim,
    # reassign or rebuild in-flight cargo in order to make a state fit.
    var admitted: int = candidate.packing.size() + candidate.pack_jobs.size() + candidate._pick_units_in_transit()
    if admitted > candidate._pick_admission_limit():
        return _bad("dispatch_admission_overflow")

    # Commit only after every check. Preserve source/history exactly, including
    # old valid medal boundary labels. No load-time equipment application.
    sim._load_release_unchecked(projected)
    sim.dispatch_window = candidate.dispatch_window
    sim._snapshot_dirty = true
    return {"ok":true,"schema":SCHEMA,"migrated":migrated,"source_schema":source.schema}

static func _bad(detail: String) -> Dictionary:
    return {"ok":false,"reason":"invalid_save","detail":detail}
