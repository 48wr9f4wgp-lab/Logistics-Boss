extends SceneTree
const Main=preload("res://prototype/growth_main.gd")
var errors:Array[String]=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
    checks+=1
    if not ok:errors.append(label);push_error(label)
func run():
    var app=Main.new()
    app.persistence_enabled=false
    root.add_child(app)
    app.set_process(false)
    app.hud.show_play()
    for id in ["growth_1","growth_2"]:
        check(app.sim.accept_contract(id).ok,"earn "+id)
        while not app.sim.finished and app.sim.sim_time<800:app.sim.step(.25)
        check(app.sim.finished,"finished "+id)
    check(app.sim.buy_upgrade("auto_pack").ok,"real auto_pack purchase")
    check(app.sim.accept_contract("growth_3").ok,"real active contract")
    app.world.refresh()
    check(app.sim.apply_layout("pack_annex").ok,"queue real packing relocation")
    app.hud._open_upgrades()
    app.hud.refresh()
    var button:Button=app.hud._content.find_child("InspectOwnedAutoPack",true,false)
    check(button!=null,"owned inspection entry exists")
    if button==null:quit(1);return
    check(button.disabled and button.text.contains("配置変更"),"queued relocation gives explicit disabled entry")
    var state:=var_to_bytes(app.sim.export_release_state())
    check(not app.world.begin_equipment_inspection("packing"),"backend rejects queued relocation even with stale enabled UI")
    check(state==var_to_bytes(app.sim.export_release_state()),"rejected inspection leaves domain unchanged")
    check(app.sim.cancel_layout().ok,"cancel real pending relocation")
    app.hud.refresh()
    button=app.hud._content.find_child("InspectOwnedAutoPack",true,false)
    check(not button.disabled,"cancel re-enables entry without reopening menu")
    check(app.sim.apply_layout("pack_annex").ok,"queue relocation again")
    for tick in 4000:
        app.sim.step(.05)
        if app.sim._move_remaining>0:break
    check(app.sim._move_remaining>0,"fixture reaches real equipment movement")
    app.world.refresh();app.hud.refresh()
    button=app.hud._content.find_child("InspectOwnedAutoPack",true,false)
    check(button.disabled,"moving equipment disables entry")
    state=var_to_bytes(app.sim.export_release_state())
    check(not app.world.begin_equipment_inspection("packing"),"backend rejects moving equipment")
    check(state==var_to_bytes(app.sim.export_release_state()),"moving guard is read only")
    for tick in 4000:
        app.sim.step(.05)
        if app.sim.pending_layout_id.is_empty() and app.sim._move_remaining<=0:break
    check(app.sim.layout_id=="pack_annex" and app.sim.pending_layout_id.is_empty(),"real movement completes")
    # Leave the hidden world stale, matching a relocation that completes while
    # the upgrades sheet is open. The real close/entry signal chain must refresh it.
    app.hud.refresh()
    button=app.hud._content.find_child("InspectOwnedAutoPack",true,false)
    check(not button.disabled,"completion re-enables entry in open menu")
    var expected_position:Vector3=app.sim.snapshot().equipment.filter(func(e):return e.id=="packing")[0].position
    button.pressed.emit()
    check(app.world._inspection_slot=="packing","real UI entry can inspect after movement completes")
    check(app.world._slots.packing.position==expected_position,"UI entry refreshes the stale hidden world before framing")
    check(app.sim.check_invariants().ok,"cargo invariants unchanged")
    check(not app.persistence_enabled,"all checks use no-save app")
    print("INSPECTION_RELOCATION_GUARD "+JSON.stringify({"checks":checks,"failures":errors}))
    quit(0 if errors.is_empty() else 1)
