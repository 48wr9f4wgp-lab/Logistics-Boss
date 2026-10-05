extends SceneTree

# Reproduce the original synthetic checkpoint from public frozen-v3 actions.
# No game source, existing campaign data, or ignored build input is consulted.
const Frozen = preload("res://prototype/growth_v3_sim.gd")
const Fixture = preload("res://tests/release/regional_hall_fixture.gd")
var completed_jobs := 0
var funding_replays := 0

func _bad(message: String) -> Dictionary:
    return {"ok":false,"error":message}

func _run_job(sim, id: String) -> Dictionary:
    var accepted: Dictionary = sim.accept_contract(id)
    if not accepted.get("ok",false): return _bad("Cannot start "+id+": "+str(accepted))
    # The original recipe uses 1.0-second caller steps. Keep those exact steps,
    # including the completed frame's accumulator; they determine fixture bytes.
    var ticks := 0
    while not sim.finished and sim.sim_time < 1800.0 and ticks < 1801:
        sim.step(1.0)
        ticks += 1
    if not sim.finished: return _bad("Frozen job did not finish within its fixed bound: "+id)
    if not sim.check_invariants().get("ok",false): return _bad("Cargo invariant failed: "+id)
    completed_jobs += 1
    return {"ok":true}

func _earn() -> Dictionary:
    var sim = Frozen.new()
    for n in range(1,7):
        var result := _run_job(sim,"growth_%d"%n)
        if not result.ok: return result
    for option in Frozen.GROWTH_UPGRADES:
        while sim.campaign_wallet < int(option.cost):
            if funding_replays >= 100: return _bad("Funding replay bound exceeded")
            var result := _run_job(sim,"growth_1")
            if not result.ok: return result
            funding_replays += 1
        var purchased: Dictionary = sim.buy_upgrade(option.id)
        if not purchased.get("ok",false): return _bad("Cannot buy "+str(option.id)+": "+str(purchased))
    var hub := _run_job(sim,"route_hub")
    if not hub.ok: return hub
    if sim.campaign_wallet != 970: return _bad("Expected earned wallet970, got "+str(sim.campaign_wallet))
    return {"ok":true,"data":sim.export_release_state()}

func _generate() -> Dictionary:
    var output := OS.get_environment(Fixture.ENV)
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    if output.is_empty() or sandbox.is_empty(): return _bad("Set FLOTRA_REVIEW_USER_ROOT and "+Fixture.ENV+" to a fresh disposable test directory")
    sandbox=sandbox.simplify_path().trim_suffix("/")+"/"
    if not output.is_absolute_path() or output.begins_with("res://") or output.begins_with("user://") or not output.simplify_path().begins_with(sandbox):
        return _bad("Generated fixture must remain inside the explicit disposable test directory")
    if FileAccess.file_exists(output) or FileAccess.file_exists(output+".tmp"):
        return _bad("Refusing to overwrite an existing fixture or temporary output")
    if FileAccess.get_file_as_string("res://prototype/growth_v3_sim.gd").replace("class_name FlotraGrowthV3Sim","class_name FlotraGrowthSim").sha256_text() != "f3394819b34d6dcfba011db2f5953562871df6c2d0c40519f6074657c459b904":
        return _bad("Frozen schema3 source pin changed")
    if FileAccess.get_sha256("res://prototype/jobs_sim.gd") != "cfe35051566561dcd21d4b021b19118a66afdd6d9e3f9847fbf32e8066d4dfeb":
        return _bad("Frozen physical dependency pin changed")
    var earned := _earn()
    if not earned.ok: return earned
    var file := FileAccess.open(output+".tmp",FileAccess.WRITE)
    if file == null: return _bad("Cannot open disposable fixture output")
    file.store_var(earned.data,false)
    file.close()
    var actual := FileAccess.get_sha256(output+".tmp")
    if actual != Fixture.SHA256: return _bad("Generated fixture SHA256 mismatch: "+actual)
    if DirAccess.rename_absolute(output+".tmp",output) != OK: return _bad("Cannot publish generated disposable fixture")
    var verified := Fixture.read_required()
    if not verified.ok: return verified
    return {"ok":true,"path":output,"sha256":actual,"wallet":earned.data.campaign.wallet,"jobs":completed_jobs,"funding_replays":funding_replays}

func _initialize() -> void:
    var start := Time.get_ticks_usec()
    var result := _generate()
    result.suite="generate_regional_hall_fixture"
    result.elapsed_ms=(Time.get_ticks_usec()-start)/1000.0
    print(JSON.stringify(result))
    if not result.ok: push_error(str(result.error))
    quit(0 if result.ok else 1)
