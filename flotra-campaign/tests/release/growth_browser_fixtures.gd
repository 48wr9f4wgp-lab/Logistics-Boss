extends SceneTree
# Test-only fixtures made exclusively through real domain actions. Browser tests
# install them in fresh profiles, never in any user's existing saved warehouse.
const Growth=preload("res://prototype/growth_sim.gd")
const Legacy=preload("res://prototype/release_sim.gd")
const GrowthV2=preload("res://prototype/growth_v2_sim.gd")
const Store=preload("res://prototype/release_save.gd")
func _initialize():
    var directory=OS.get_environment("FLOTRA_GROWTH_FIXTURES")
    if directory.is_empty(): push_error("Set FLOTRA_GROWTH_FIXTURES");quit(1);return
    DirAccess.make_dir_recursive_absolute(directory)
    var legacy=Legacy.new()
    legacy.accept_contract("first_shift")
    legacy.step(20.0)
    legacy.apply_layout("pack_annex")
    write_fixture(directory,"legacy",legacy)
    var previous=GrowthV2.new()
    previous.accept_contract("growth_1")
    while not previous.finished:previous.step(10.0)
    previous.buy_upgrade("wing_1")
    previous.buy_upgrade("crew_4")
    previous.accept_contract("growth_2")
    previous.step(17.375)
    write_fixture(directory,"growth_v2",previous)
    var growth=Growth.new()
    for number in range(1,7):
        growth.accept_contract("growth_%d"%number)
        while not growth.finished:growth.step(10.0)
    for definition in Growth.GROWTH_UPGRADES:
        while growth.campaign_wallet < definition.cost:
            growth.accept_contract("growth_1")
            while not growth.finished:growth.step(10.0)
        if not growth.buy_upgrade(definition.id).ok:push_error("Purchase fixture failed");quit(1);return
    growth.accept_contract("route_hub")
    growth.step(85.0)
    write_fixture(directory,"late",growth)
    while not growth.finished:growth.step(10.0)
    write_fixture(directory,"complete",growth)
    growth.set_operation("parcel")
    growth.accept_contract("route_pick")
    growth.step(10.0)
    write_fixture(directory,"parcel",growth)
    quit()
func write_fixture(directory:String,name:String,sim):
    var encoded=Store.new().encode(sim.export_release_state())
    var imported=sim.get_script().new().import_release_state(sim.export_release_state())
    if not imported.ok:push_error(str(imported));quit(1);return
    var file=FileAccess.open(directory+"/"+name+".json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"encoded":encoded,"wallet":sim.campaign_wallet,"shipped":sim.shipped,"offered":sim.offered_units,"status":sim.campaign_status,"upgrades":sim.purchased_upgrades,"time":sim.sim_time}))
