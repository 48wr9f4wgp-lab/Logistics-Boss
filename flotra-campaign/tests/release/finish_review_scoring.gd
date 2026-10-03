extends SceneTree
const Sim = preload("res://prototype/release_sim.gd")
const Hud = preload("res://prototype/release_hud.gd")
const Save = preload("res://prototype/release_save.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func _initialize() -> void:
    var sim = Sim.new()
    var hud = Hud.new()
    check(hud._record_clock(145.05) == "2:25.05", "result displays first tick past gold")
    check(hud._record_clock(184.45) != hud._record_clock(184.50), "successive record ticks remain distinct")
    var clock_sum := 0.0
    for tick in 1440: clock_sum += .05
    check(hud._clock(clock_sum)=="1:12", "live clock normalizes 72-second tick accumulation")
    check(hud._clock(71.95)=="1:11", "live clock does not advance before next whole second")
    var boundary_report: Array = []
    for contract in Sim.CONTRACTS:
        for target in ["gold_seconds", "silver_seconds"]:
            var expected: float = contract[target]
            var elapsed := 0.0
            for tick in int(round(expected/.05)): elapsed += .05
            var actual: String = sim._medal(contract, elapsed)
            var expected_medal := "gold" if target == "gold_seconds" else "silver"
            boundary_report.append({"contract":contract.id,"target":expected,"actual_tick_sum":elapsed,"display":hud._record_clock(elapsed),"awarded":actual,"expected":expected_medal})
            check(actual == expected_medal,"inclusive medal boundary remains correct after fixed-step sum: "+str(contract.id)+" "+target)
            check(hud._live_target(contract,elapsed).begins_with("金目標" if target=="gold_seconds" else "銀目標"),"live medal target matches inclusive score boundary: "+str(contract.id)+" "+target)
            check(hud._live_target(contract,expected+.05).begins_with("銀目標" if target=="gold_seconds" else "完走で銅"),"live target changes after first tick past boundary: "+str(contract.id)+" "+target)
            check(sim._medal(contract,expected+.05) == ("silver" if target=="gold_seconds" else "bronze"),"first tick past boundary misses medal: "+str(contract.id)+" "+target)
    var legacy: Dictionary = {}
    var source := OS.get_environment("FLOTRA_LEGACY_BOUNDARY_SAVE")
    if not source.is_empty():
        var decoded: Dictionary = Save.new().decode(FileAccess.get_file_as_string(source))
        check(decoded.ok, "original-PCK legacy fixture decodes")
        if decoded.ok: legacy = decoded.data
    else:
        # Same shape/values as the original-PCK-validated fixture. Keep the
        # regression self-contained when the optional release evidence is absent.
        sim.accept_contract("first_shift")
        sim.step(1200)
        legacy = sim.export_release_state()
        var elapsed := 0.0
        for tick in 4200: elapsed += .05
        legacy.sim.sim_time = elapsed
        legacy.campaign.results.first_shift.best_time = elapsed
        legacy.campaign.results.first_shift.best_medal = "bronze"
        legacy.campaign.last_result.elapsed = elapsed
        legacy.campaign.last_result.best_time = elapsed
        legacy.campaign.last_result.medal = "bronze"
    if not legacy.is_empty():
        var restored = Sim.new()
        var result: Dictionary = restored.import_release_state(legacy)
        check(result.ok, "original raw-boundary medal remains importable")
        var expected: Dictionary = legacy.duplicate(true)
        expected.campaign.results.first_shift.best_medal = "silver"
        expected.campaign.last_result.medal = "silver"
        if result.ok:
            check(restored.export_release_state() == expected, "legacy import normalizes only derived medal fields")
            var again = Sim.new()
            check(again.import_release_state(restored.export_release_state()).ok, "normalized boundary save imports again")
        for change in ["forged_gold", "early_bronze", "late_silver", "last_medal_forged"]:
            var invalid: Dictionary = legacy.duplicate(true)
            if change == "forged_gold":
                invalid.campaign.results.first_shift.best_medal = "gold"
                invalid.campaign.last_result.medal = "gold"
            elif change == "last_medal_forged":
                invalid.campaign.last_result.medal = "gold"
            else:
                var elapsed := 209.95 if change == "early_bronze" else 210.05
                invalid.sim.sim_time = elapsed
                invalid.campaign.results.first_shift.best_time = elapsed
                invalid.campaign.last_result.elapsed = elapsed
                invalid.campaign.last_result.best_time = elapsed
                var wrong := "bronze" if change == "early_bronze" else "silver"
                invalid.campaign.results.first_shift.best_medal = wrong
                invalid.campaign.last_result.medal = wrong
            var fresh = Sim.new()
            var before: Dictionary = fresh.export_release_state()
            check(not fresh.import_release_state(invalid).ok, "wrong medal outside legacy boundary is rejected: "+change)
            check(fresh.export_release_state() == before, "rejected medal import is atomic: "+change)
    print(JSON.stringify({"checks":checks,"failures":failures,"boundaries":boundary_report}))
    hud.free()
    quit(0 if failures.is_empty() else 1)
