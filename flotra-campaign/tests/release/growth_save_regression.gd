extends SceneTree

const Sim = preload("res://prototype/growth_sim.gd")
const Legacy = preload("res://prototype/release_sim.gd")
const Save = preload("res://prototype/release_save.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func finish(sim, label: String) -> void:
    for second in 3000:
        sim.step(1.0)
        if sim.finished: break
    check(sim.finished and sim.check_invariants().ok,label+" completes with conserved cargo")

func roundtrip(sim, label: String) -> void:
    var store = Save.new()
    var saved: Dictionary = sim.export_release_state()
    var decoded: Dictionary = store.decode(store.encode(saved))
    check(decoded.ok,label+" storage codec roundtrip")
    if not decoded.ok: return
    var restored = Sim.new()
    var imported: Dictionary = restored.import_release_state(decoded.data)
    check(imported.ok,label+" import accepted: "+str(imported))
    if not imported.ok: return
    check(restored.export_release_state()==saved,label+" exact complete state preserved")
    for tick in 90:
        var dt := .037 if tick%3==0 else .113
        sim.step(dt)
        restored.step(dt)
    check(restored.export_release_state()==sim.export_release_state(),label+" deterministic continuation")

func migrate(legacy, label: String) -> void:
    var original: Dictionary = legacy.export_release_state()
    var sim = Sim.new()
    var imported: Dictionary = sim.import_release_state(bytes_to_var(var_to_bytes(original)))
    check(imported.ok and imported.get("migrated",false),label+" v1 migration accepted")
    if not imported.ok: return
    var migrated: Dictionary = sim.export_release_state()
    check(migrated.sim==original.sim and migrated.campaign==original.campaign,label+" migration preserves exact cargo, wallet, purchases and history")
    check(sim.legacy_profile,label+" active legacy physics preserved")
    for tick in 150:
        var dt := .017 if tick%3==0 else .083
        legacy.step(dt)
        sim.step(dt)
    check(sim.export_release_state().sim==legacy.export_release_state().sim,label+" legacy movement continues identically")
    roundtrip(sim,label+" subsequent schema2 save")
    finish(sim,label+" legacy drain")
    var wallet: int = sim.campaign_wallet
    var upgrades: Array = sim.purchased_upgrades.duplicate()
    check(sim.accept_contract("growth_1").ok,label+" can enter new growth after old cargo is delivered")
    check(not sim.legacy_profile and sim.campaign_wallet==wallet and sim.purchased_upgrades==upgrades,label+" new profile does not discard legacy funds or upgrades")
    roundtrip(sim,label+" transitioned growth save")

func rejects(data: Dictionary, label: String) -> void:
    var target = Sim.new()
    target.accept_contract("growth_1")
    target.step(5.0)
    var before: Dictionary = target.export_release_state()
    var result: Dictionary = target.import_release_state(data)
    check(not result.get("ok",false),label+" rejected")
    check(target.export_release_state()==before,label+" never mutates a live run")

func native_store_migration() -> void:
    # Never access a normal user's campaign path when this script is run directly.
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    var storage_path := ProjectSettings.globalize_path("user://")
    var isolated := not sandbox.is_empty() and storage_path.begins_with(sandbox)
    check(isolated,"native migration test has an explicitly isolated user directory")
    if not isolated: return
    var legacy = Legacy.new()
    legacy.accept_contract("first_shift")
    legacy.step(20.0)
    var writer = Save.new()
    check(writer.save_from(legacy).ok,"native legacy checkpoint written")
    var original_text := FileAccess.get_file_as_string(Save.PATH)
    var new_store = Save.new()
    var migrated = Sim.new()
    var load_result: Dictionary = new_store.load_into(migrated)
    check(load_result.ok and load_result.get("restored",false),"native store migrates an active v1 checkpoint")
    check(FileAccess.get_file_as_string(Save.PATH)==original_text,"loading migration does not overwrite the legacy checkpoint")
    migrated.step(.375)
    check(new_store.save_from(migrated).ok,"native migrated schema2 checkpoint written")
    check(FileAccess.get_file_as_string(Save.BACKUP)==original_text,"native migration retains exact original v1 backup")
    var reloaded = Sim.new()
    var reload_store = Save.new()
    var reload_result: Dictionary = reload_store.load_into(reloaded)
    check(reload_result.ok and not reload_store.blocked,"schema2 primary plus v1 backup stays writable")
    check(reloaded.export_release_state()==migrated.export_release_state(),"native mixed-version storage preserves exact active state")

func _initialize() -> void:
    native_store_migration()
    migrate(Legacy.new(),"legacy ready")
    var moving = Legacy.new()
    moving.accept_contract("first_shift")
    moving.step(17.375)
    migrate(moving,"legacy active transport")
    var paused = Legacy.new()
    paused.accept_contract("first_shift")
    paused.step(17.375)
    paused.time_scale = 0.0
    var saved_paused: Dictionary = paused.export_release_state()
    var paused_copy = Sim.new()
    check(paused_copy.import_release_state(saved_paused).ok,"legacy paused state imports")
    paused_copy.step(200.0)
    check(paused_copy.sim_time==paused.sim_time and paused_copy.time_scale==0.0,"paused migration never advances cargo")
    roundtrip(paused_copy,"legacy paused")
    var relocating = Legacy.new()
    relocating.accept_contract("first_shift")
    relocating.step(1.0)
    relocating.apply_layout("clear_aisle")
    relocating.step(.05)
    check(relocating._move_remaining>0.0,"legacy relocation fixture is physically relocating")
    migrate(relocating,"legacy active relocation")
    var pending = Legacy.new()
    pending.accept_contract("first_shift")
    pending.step(20.0)
    pending.apply_layout("pack_annex")
    migrate(pending,"legacy pending relocation")
    var completed = Legacy.new()
    for definition in Legacy.CONTRACTS:
        completed.accept_contract(definition.id)
        finish(completed,"legacy historical "+str(definition.id))
    for definition in Legacy.UPGRADES:
        check(completed.buy_upgrade(definition.id).ok,"legacy fixture owns "+str(definition.id))
    migrate(completed,"legacy completed with every upgrade")

    var sim = Sim.new()
    roundtrip(sim,"growth ready")
    sim.accept_contract("growth_1")
    sim.step(6.375)
    roundtrip(sim,"growth active movement")
    finish(sim,"growth first")
    check(sim.buy_upgrade("wing_1").ok,"growth wing fixture purchased")
    check(sim.buy_upgrade("crew_4").ok,"growth crew fixture purchased")
    roundtrip(sim,"growth purchased wing")
    sim.accept_contract("growth_2")
    sim.step(14.0)
    roundtrip(sim,"growth expanded live routes")
    sim.apply_layout("clear_aisle")
    roundtrip(sim,"growth expanded pending relocation")
    finish(sim,"growth second")
    sim.accept_contract("growth_1")
    finish(sim,"paid growth replay")
    roundtrip(sim,"repeat reward saved exactly")
    check(sim.buy_upgrade("robot_2").ok,"physical robot fixture purchased")
    sim.accept_contract("growth_3")
    sim.step(15.0)
    roundtrip(sim,"robots carrying cargo on expanded routes")
    finish(sim,"robot-equipped third milestone")

    var valid: Dictionary = sim.export_release_state()
    var bad := valid.duplicate(true)
    bad.schema = 99
    rejects(bad,"future schema")
    bad = valid.duplicate(true)
    bad.erase("growth")
    rejects(bad,"missing growth profile")
    bad = valid.duplicate(true)
    bad.growth.legacy_profile = "false"
    rejects(bad,"profile wrong type")
    var mismatched = Sim.new()
    mismatched.accept_contract("growth_1")
    mismatched.step(5.0)
    bad = mismatched.export_release_state()
    bad.growth.legacy_profile = true
    bad.sim.walk_speed = 2.4
    bad.sim.pack_seconds = 3.0
    rejects(bad,"legacy physics cannot masquerade as an active growth job")
    bad = valid.duplicate(true)
    bad.campaign.wallet += 1
    rejects(bad,"unearned wallet credit")
    bad = valid.duplicate(true)
    bad.campaign.results.growth_1.earned += 140
    bad.campaign.wallet += 140
    rejects(bad,"repeat payout without corresponding attempt")
    bad = valid.duplicate(true)
    bad.campaign.upgrades.append("wing_1")
    rejects(bad,"duplicate purchase")
    bad = valid.duplicate(true)
    bad.sim.workers[0].path = ["inbound","outside_graph"]
    rejects(bad,"worker outside physical graph")
    bad = valid.duplicate(true)
    bad.sim.bulk_bays[-1].position.x += 1.0
    rejects(bad,"forged expansion geometry")
    bad = valid.duplicate(true)
    bad.sim.bulk_bays[-1].reserved_by = 100
    rejects(bad,"invalid bay reservation owner")
    bad = valid.duplicate(true)
    bad.sim._edges.values()[0].owners = [100]
    rejects(bad,"invalid route reservation owner")
    bad = valid.duplicate(true)
    bad.sim._edges.values()[0].capacity = 200
    rejects(bad,"forged route capacity")
    bad = valid.duplicate(true)
    bad.sim.walk_speed = INF
    rejects(bad,"nonfinite physics")
    var hold_fixture = Sim.new()
    hold_fixture.accept_contract("growth_1")
    hold_fixture.step(20.0)
    bad = hold_fixture.export_release_state()
    var held_manifest_id := -1
    for manifest in bad.sim.manifests.values():
        if manifest.kind=="bulk" and manifest.stored_at>=0.0:
            held_manifest_id = manifest.id
            break
    check(held_manifest_id>=0,"bulk release-clock fixture has physically stored cargo")
    if held_manifest_id>=0:
        bad.sim.manifests[held_manifest_id].release_at += 1000000.0
        rejects(bad,"forged bulk release time cannot introduce a days-long softlock")
        bad = hold_fixture.export_release_state()
        bad.sim.manifests[held_manifest_id].stored_at = bad.sim.sim_time+1.0
        bad.sim.manifests[held_manifest_id].release_at = bad.sim.manifests[held_manifest_id].stored_at+bad.sim.manifests[held_manifest_id].hold_seconds
        rejects(bad,"bulk cargo cannot claim it was stored in the future")
    var early_bulk = Sim.new()
    early_bulk.accept_contract("growth_1")
    early_bulk.step(3.1)
    bad = early_bulk.export_release_state()
    bad.sim.manifests[2].release_at = 0.0
    rejects(bad,"unstored bulk cargo cannot invent a release clock")
    bad = valid.duplicate(true)
    bad.campaign.results["unknown_contract"] = bad.campaign.results.growth_1.duplicate(true)
    rejects(bad,"unknown historical contract")
    bad = completed.export_release_state()
    bad.campaign.wallet += 1
    rejects(bad,"invalid legacy save cannot migrate around validation")
    print(JSON.stringify({"suite":"growth_save_regression","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
