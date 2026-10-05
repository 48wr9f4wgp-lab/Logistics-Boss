extends SceneTree
const Main=preload("res://prototype/growth_main.gd")
const Sim=preload("res://prototype/growth_sim.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);push_error(label)
func finish(sim)->void:
    while not sim.finished and sim.sim_time<1800:sim.step(1.0)
    check(sim.finished,"earned fixture finishes actual work")
func earned()->Dictionary:
    var sim=Sim.new()
    for number in range(1,7):sim.accept_contract("growth_%d"%number);finish(sim)
    for upgrade in sim.GROWTH_UPGRADES:
        while sim.campaign_wallet<int(upgrade.cost):sim.accept_contract("growth_1");finish(sim)
        check(sim.buy_upgrade(upgrade.id).ok,"actual original equipment purchase")
    while not sim.contract_results.has("route_hub") or sim.campaign_wallet<1800:
        sim.accept_contract("route_hub");finish(sim)
    return sim.export_release_state()
func settle()->void:
    for frame in 3:await process_frame
func _initialize()->void:run.call_deferred()
func run()->void:
    var fixture:=earned()
    for size in [Vector2i(375,567),Vector2i(390,844),Vector2i(667,375)]:
        root.size=size
        var app=Main.new()
        app.persistence_enabled=false
        root.add_child(app)
        await settle()
        check(app.sim.import_release_state(fixture).ok,"scene imports earned schema4 fixture")
        app.hud.refresh()
        app.world.refresh()
        app.hud._open_upgrades()
        await settle()
        var buy=app.hud._upgrade_buttons.get("regional_hall")
        check(buy!=null and not buy.disabled and buy.get_theme_font_size("font_size")>=18 and buy.size.y>=56,"real hall purchase is readable and enabled")
        app.hud._request_upgrade("regional_hall")
        await settle()
        check(app.sim.hall_owned and app.hud._sheet_kind.is_empty(),"purchase reveals real hall floor")
        check(app.world._growth_floors.size()==5,"rendered hall is added to four existing wings")
        check(app.hud._notice_title.contains("広域配送棟"),"completion names the new hall")
        app.hud._open_upgrades()
        await settle()
        var before:Dictionary=app.sim.export_release_state()
        app.hud._request_hall_plan("express")
        await settle()
        check(app.sim.hall_plan=="express" and app.sim.bulk_capacity()==54,"real hall action opens corridor and sacrifices sixteen bays")
        check(app.sim.campaign_wallet==before.campaign.wallet,"switch remains free")
        var hall_button=app.hud._content.get_node_or_null("HallPlan_storage")
        check(hall_button!=null and hall_button.size.y>=56 and hall_button.get_theme_font_size("font_size")>=18,"hall choice retains touch and text size")
        app.hud._open_contracts()
        app.hud._show_preparation("route_regional")
        await settle()
        check(app.hud._preparation_start!=null and app.hud._preparation_start.size.y>=56,"existing pinned start remains full-size")
        if size.y>=567:
            for mode in ["balanced","parcel","pallet"]:
                var control=app.hud._content.get_node("ChooseOperation_"+mode)
                var rect:Rect2=control.get_global_rect()
                check(app.hud._scroll.get_global_rect().encloses(rect),"three modes remain above fold after hall integration")
        app.hud._start_prepared_contract()
        await settle()
        check(app.sim.current_contract_id=="route_regional" and app.running,"existing pinned action accepts the real regional job")
        app.sim.step(15.0)
        before=app.sim.export_release_state()
        var rejected:Dictionary=app.sim.set_hall_plan("storage")
        check(not rejected.ok and app.sim.export_release_state()==before,"active hall switching leaves every live field unchanged")
        app._pause_trial(true)
        app.hud._open_upgrades()
        await settle()
        for plan in ["storage","express"]:
            check(app.hud._content.get_node("HallPlan_"+plan).disabled,"hall mode cannot change during incomplete work")
        check(app.sim.check_invariants().ok,"actual scene actions retain full cargo conservation")
        root.remove_child(app);app.queue_free();await settle()
    print(JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
