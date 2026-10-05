extends SceneTree
const V3=preload("res://prototype/growth_v3_sim.gd")
const V4=preload("res://prototype/growth_sim.gd")
const Store=preload("res://prototype/release_save.gd")
func finish(sim)->void:
    while not sim.finished and sim.sim_time<1800:sim.step(1.0)
    if not sim.finished:push_error("Earned fixture did not finish");quit(1)
func write(directory:String,name:String,sim)->void:
    var data:Dictionary=sim.export_release_state()
    var verified=sim.get_script().new()
    if not verified.import_release_state(data).ok:push_error("Invalid earned fixture");quit(1);return
    # Preserve deliberately noncanonical whitespace through immutable archiving.
    var encoded:=JSON.stringify(JSON.parse_string(Store.new().encode(data)),"\t")+"\n"
    FileAccess.open(directory+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify({"encoded":encoded,"sha256":encoded.sha256_text(),"wallet":sim.campaign_wallet,"time":sim.sim_time,"shipped":sim.shipped,"offered":sim.offered_units,"status":sim.campaign_status,"schema":data.schema,"hall":data.get("hall",{"owned":false,"plan":"storage"})},"  "))
func _initialize()->void:
    var directory:=OS.get_environment("FLOTRA_REGIONAL_FIXTURES")
    if directory.is_empty():push_error("Set FLOTRA_REGIONAL_FIXTURES");quit(1);return
    DirAccess.make_dir_recursive_absolute(directory)
    var sim=V3.new()
    for number in range(1,7):sim.accept_contract("growth_%d"%number);finish(sim)
    for upgrade in V3.GROWTH_UPGRADES:
        while sim.campaign_wallet<upgrade.cost:sim.accept_contract("growth_1");finish(sim)
        sim.buy_upgrade(upgrade.id)
    while not sim.contract_results.has("route_hub") or sim.campaign_wallet<1800:
        sim.accept_contract("route_hub");finish(sim)
    write(directory,"mature-v3",sim)
    var mature:Dictionary=sim.export_release_state()
    sim.accept_contract("route_hub")
    sim.step(180.0)
    write(directory,"active-v3",sim)
    for plan in ["storage","express"]:
        var hall=V4.new()
        var imported:Dictionary=hall.import_release_state(mature)
        if not imported.ok:push_error(str(imported));quit(1);return
        var purchased:Dictionary=hall.buy_upgrade("regional_hall")
        if not purchased.ok:push_error(str(purchased));quit(1);return
        hall.set_hall_plan(plan)
        hall.accept_contract("route_regional")
        hall.step(180.0)
        write(directory,"hall-"+plan+"-v4",hall)
    print("REGIONAL_BROWSER_FIXTURES_CREATED")
    quit()
