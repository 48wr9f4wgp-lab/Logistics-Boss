extends SceneTree

# Independent reviewer: old executable fixtures come from a pinned pre-change git
# commit via run_experience_adversarial.sh, never from the migration validator.
const Sim = preload("res://prototype/growth_sim.gd")
const Save = preload("res://prototype/release_save.gd")
var checks := 0
var failures: Array[String] = []
var captured := {}
var batch_stages := {}
var migration_stages := {}
var parcel_ship_batch := false
var mature_seed: Dictionary = {}
var legacy_validator_boundary := {}

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func same_bytes(a: Variant, b: Variant) -> bool:
    return var_to_bytes(a) == var_to_bytes(b)

func finish(sim, label: String) -> void:
    for tick in 30000:
        sim.step(.2)
        if sim.finished: break
    check(sim.finished,label+" drains to completion")
    if sim.finished: ledger(sim,label+" complete independent ledger")

func ledger(sim, label: String) -> void:
    # Do not use the production check_invariants() as the test oracle.
    var counts := {}
    var represented: Array = []
    for queue in [sim.inbound,sim.external_backlog,sim.bulk_storage]:
        for id in queue: represented.append_array(sim.manifests[id].unit_ids)
    for queue in [sim.storage,sim.packing,sim.ready,sim.shipped_ids]: represented.append_array(queue)
    for job in sim.pack_jobs: represented.append(job.cargo_id)
    for worker in sim.workers: represented.append_array(worker.cargo_ids)
    for id in represented: counts[id] = int(counts.get(id,0))+1
    var correct: bool = represented.size()==sim.cargo.size() and sim.cargo.size()==sim.offered_units and sim.offered_units==sim.manifest_cursor*6
    for id in sim.cargo:
        correct = correct and int(counts.get(id,0))==1
    check(correct,label+" each unit has exactly one owner")
    check(sim.shipped_ids.size()==sim.shipped and sim.bulk_shipped+sim.pick_shipped==sim.shipped,label+" shipment counts agree")
    check(sim.money==5000+sim.shipped*500 and sim.revenue==sim.shipped*500,label+" accounting agrees")
    var stages := true
    for id in sim.shipped_ids:
        var item: Dictionary = sim.cargo[id]
        stages = stages and item.stage=="shipped" and item.worker_id==-1 and item.node=="outbound" and item.stored_at>=item.created_at
        if item.kind=="pick": stages = stages and item.picked_at>=item.stored_at and item.packed_at>=item.picked_at and item.shipped_at>=item.packed_at
        else: stages = stages and item.picked_at==-1.0 and item.packed_at==-1.0 and item.shipped_at>=sim.manifests[item.manifest_id].release_at
    check(stages,label+" every shipment traversed the proper physical stages")

func independent_copy(sim):
    var copy=Sim.new()
    var fields: Array=Sim.SIM_FIELDS.duplicate()
    fields.append_array(["operating_profile","operation_mode","preferences","legacy_profile","campaign_wallet","completed_count","purchased_upgrades","current_contract_id","campaign_status","manifest_cursor","contract_results","last_result"])
    for field in fields:
        var value=sim.get(field)
        copy.set(field,value.duplicate(true) if value is Array or value is Dictionary else value)
    return copy

func roundtrip(sim, label: String, continuation := 60) -> void:
    var original: Dictionary = sim.export_release_state()
    # The control path copies live properties without invoking any import or
    # validation method, so matching continuation cannot hide importer changes.
    var control=independent_copy(sim)
    check(same_bytes(original,control.export_release_state()),label+" independent control starts identical")
    var encoded := Save.new().encode(original)
    var decoded: Dictionary = Save.new().decode(encoded)
    var restored = Sim.new()
    var result: Dictionary = restored.import_release_state(decoded.data)
    check(result.get("ok",false),label+" imports: "+str(result))
    if not result.get("ok",false): return
    check(same_bytes(original,restored.export_release_state()),label+" byte-exact state survives codec/import")
    for tick in maxi(60,continuation):
        var dt := .017 if tick%3==0 else .113
        restored.step(dt)
        control.step(dt)
    check(same_bytes(control.export_release_state(),restored.export_release_state()),label+" exact deterministic continuation")

func migrate(old, label: String, advance := true) -> void:
    var old_state: Dictionary = old.export_release_state()
    var current = Sim.new()
    var result: Dictionary = current.import_release_state(bytes_to_var(var_to_bytes(old_state)))
    check(result.get("ok",false) and result.get("migrated",false),label+" migration accepted: "+str(result))
    if not result.get("ok",false): return
    var migrated: Dictionary = current.export_release_state()
    check(same_bytes(old_state.sim,migrated.sim),label+" every physics field preserved byte-for-byte")
    check(same_bytes(old_state.campaign,migrated.campaign),label+" wallet purchases records preserved byte-for-byte")
    check(not current.operating_profile and current.operation_mode=="balanced",label+" frozen job operating rules retained")
    if advance:
        for tick in 80:
            var dt := .037 if tick%3==0 else .113
            old.step(dt)
            current.step(dt)
        check(same_bytes(old.export_release_state().sim,current.export_release_state().sim),label+" independent original physics continuation")
        check(same_bytes(old.export_release_state().campaign,current.export_release_state().campaign),label+" independent original rewards continuation")
    roundtrip(current,label+" schema3 checkpoint",0)

func rejects(data: Dictionary, label: String) -> void:
    var target = Sim.new()
    target.set_operation("pallet")
    target.accept_contract("growth_1")
    target.step(3.375)
    var before: Dictionary = target.export_release_state()
    var outcome: Dictionary = target.import_release_state(data)
    check(not outcome.get("ok",false),label+" rejected: "+str(outcome))
    check(same_bytes(before,target.export_release_state()),label+" failure is atomic")

func clone(data: Dictionary) -> Dictionary:
    return bytes_to_var(var_to_bytes(data))

func old_fixtures(old_class, version: String) -> void:
    var first := "first_shift" if version=="v1" else "growth_1"
    migrate(old_class.new(),version+" pristine")
    var active = old_class.new()
    active.accept_contract(first)
    for tick in 1800:
        active.step(.05)
        for worker in active.workers:
            var key := version+"_"+str(worker.task)+"_"+str(worker.phase)
            if worker.task!="idle" and not migration_stages.has(key):
                migration_stages[key]=true
                var fixture = old_class.new()
                check(fixture.import_release_state(active.export_release_state()).ok,key+" old fixture import")
                migrate(fixture,key)
        if active.finished: break
    var paused = old_class.new()
    paused.accept_contract(first)
    paused.step(10.375)
    paused.time_scale=0.0
    migrate(paused,version+" paused")
    var relocating = old_class.new()
    relocating.accept_contract(first)
    relocating.step(.25)
    relocating.apply_layout("clear_aisle")
    relocating.step(.05)
    check(relocating._move_remaining>0.0,version+" active relocation fixture")
    migrate(relocating,version+" active relocation")
    var pending = old_class.new()
    pending.accept_contract(first)
    pending.step(8.0)
    pending.apply_layout("pack_annex")
    check(not pending.pending_layout_id.is_empty(),version+" pending layout fixture")
    migrate(pending,version+" pending layout")
    var mature = old_class.new()
    var ids := ["first_shift","small_orders","pallet_wave","packing_rush","storage_peak","final_dispatch"] if version=="v1" else ["growth_1","growth_2","growth_3","growth_4","growth_5","growth_6"]
    for id in ids:
        check(mature.accept_contract(id).ok,version+" historical accept "+id)
        finish(mature,version+" historical "+id)
    var upgrades := ["worker_4","rack_24","packing_2","floor_2","worker_5"] if version=="v1" else ["wing_1","crew_4","robot_2","auto_pack","wing_2","rack_48","crew_6","wing_3","robot_4","wing_4"]
    for id in upgrades:
        if version=="v2":
            while mature.campaign_wallet < int(mature._upgrade(id).cost):
                mature.accept_contract("growth_6")
                finish(mature,version+" earned upgrade funding "+id)
        check(mature.buy_upgrade(id).ok,version+" earned purchase "+id)
    if version=="v2": mature_seed=mature.export_release_state()
    migrate(mature,version+" mature all records purchases")
    check(mature.accept_contract(first).ok,version+" replay accepted")
    mature.step(17.375)
    migrate(mature,version+" purchased active replay")
    if version=="v2":
        finish(mature,"v2 mature replay drained")
        mature.accept_contract("route_hub")
        mature.step(53.375)
        migrate(mature,"v2 all four wings ten workers active hub routes")

func new_modes() -> void:
    for mode in ["balanced","parcel","pallet"]:
        for layout in ["compact","clear_aisle","pack_annex","split"]:
            if OS.get_environment("FLOTRA_QA_FAST")=="1" and (mode!="parcel" or layout!="compact"): continue
            var sim = Sim.new()
            var original: Dictionary = sim.export_release_state()
            check(sim.set_operation(mode).get("cost",-1)==0,mode+" selection free")
            check(same_bytes(original.sim,sim.export_release_state().sim) and same_bytes(original.campaign,sim.export_release_state().campaign),mode+" does not alter money or physics before a job")
            sim.apply_layout(layout)
            sim.accept_contract("growth_1")
            finish(sim,mode+" "+layout+" first")
            check(sim.campaign_wallet==240,mode+" first exact earned wallet")
            sim.accept_contract("route_pick")
            var initial: Dictionary = sim.export_release_state()
            check(not sim.set_operation("pallet" if mode!="pallet" else "parcel").ok,mode+" mid-job mode change refused")
            check(same_bytes(initial,sim.export_release_state()),mode+" refused switch changes nothing")
            for tick in 12000:
                sim.step(.05)
                if tick%100==0: ledger(sim,mode+" "+layout+" live")
                for worker in sim.workers:
                    if worker.task in ["pick","ship"] and worker.cargo_ids.size()>1:
                        check(mode=="parcel",mode+" only parcel mode batches picks or dispatch")
                        var ids: Array = worker.cargo_ids
                        var coherent := ids.size()<=3
                        for id in ids: coherent = coherent and sim.cargo[id].manifest_id==worker.manifest_id
                        check(coherent,mode+" batch <=3 units from one manifest")
                        var key := str(worker.task)+"_"+str(worker.phase)
                        if not batch_stages.has(key):
                            batch_stages[key]=true
                            captured[key]=sim.export_release_state()
                            roundtrip(sim,"parcel "+key+" "+layout,0)
                        if worker.task=="ship": parcel_ship_batch=true
                        if worker.carrying and not worker.edge_id.is_empty():
                            if worker.task=="pick" and not captured.has("pick_loaded_edge"):
                                captured["pick_loaded_edge"]=sim.export_release_state()
                                roundtrip(sim,"parcel loaded active-edge checkpoint")
                            var edge: Dictionary = sim._edges[worker.edge_id]
                            check(edge.owners==[worker.id] and worker.lane in edge.bulk_lanes,"loaded parcel cart exclusively owns an actual trolley-safe edge")
                            check(worker.path[-1]==worker.target,"loaded parcel cart route ends at actual task target")
                if sim.finished: break
            check(sim.finished,mode+" "+layout+" parcel route finishes without starvation")
            ledger(sim,mode+" "+layout+" final")
            check(sim.shipped==36 and sim.cargo.size()==36 and sim.campaign_wallet==540,mode+" complete manifest and reward counts")
            check(sim.set_operation("balanced").ok and sim.campaign_wallet==540,mode+" free reversible switch between jobs")
            roundtrip(sim,mode+" "+layout+" completed",0)
    for task in ["pick","ship"]:
        for phase in ["to_source","work","to_target"]:
            check(batch_stages.has(task+"_"+phase),"parcel batch observed at "+task+"_"+phase)
    check(parcel_ship_batch,"dispatch really batches packed cargo as well as picking")

func mature_parcel() -> void:
    check(not mature_seed.is_empty(),"mature earned schema2 fixture available")
    if mature_seed.is_empty(): return
    var sim=Sim.new()
    check(sim.import_release_state(mature_seed).get("ok",false),"mature existing warehouse migrates")
    check(sim.set_operation("parcel").ok,"mature warehouse freely selects new parcel mode")
    check(sim.accept_contract("route_hub").ok,"mature warehouse accepts 288-unit hub")
    check(sim.workers.size()==10 and sim._wing_count()==4 and sim.rack_capacity==48 and sim.pack_seconds==.7,"all earned equipment remains physically active")
    var phases := {}
    var robot_edge := false
    for tick in 20000:
        sim.step(.05)
        if tick%200==0: ledger(sim,"mature robotic parcel hub live")
        for worker in sim.workers:
            if int(worker.id)>=6 and worker.task in ["pick","ship"] and worker.cargo_ids.size()>1:
                if not phases.has(worker.phase):
                    phases[worker.phase]=true
                    roundtrip(sim,"mature robot cart "+str(worker.phase))
                if worker.carrying and not worker.edge_id.is_empty():
                    var edge: Dictionary=sim._edges[worker.edge_id]
                    check(edge.owners==[worker.id] and worker.lane in edge.bulk_lanes,"mature robot cart exclusive physical edge")
                    if not robot_edge:
                        robot_edge=true
                        roundtrip(sim,"mature robot cart live edge")
        if sim.finished: break
    for phase in ["to_source","work","to_target"]: check(phases.has(phase),"mature robot parcel phase observed "+phase)
    check(robot_edge,"mature robot transports a real loaded cart")
    check(sim.finished and sim.shipped==288,"mature parcel hub fully completes")
    ledger(sim,"mature robotic parcel hub complete")
    roundtrip(sim,"mature robotic parcel final records")

func mutations() -> void:
    var sim = Sim.new()
    sim.set_operation("parcel")
    sim.accept_contract("growth_1")
    sim.step(4.0)
    var base: Dictionary = sim.export_release_state()
    var bad := clone(base)
    bad.schema=4
    rejects(bad,"unsupported future schema")
    for value in ["turbo","",1,null]:
        bad=clone(base)
        bad.experience.operation_mode=value
        rejects(bad,"forged operation mode "+str(value))
    bad=clone(base)
    bad.experience.operating_profile=false
    rejects(bad,"legacy profile cannot select parcel")
    for key in ["preferred_speed","pause_on_menus","reduced_motion"]:
        bad=clone(base)
        bad.experience.preferences.erase(key)
        rejects(bad,"missing preference "+key)
    for value in [0,3,12,2.0,"2"]:
        bad=clone(base)
        bad.experience.preferences.preferred_speed=value
        rejects(bad,"invalid speed preference "+str(value))
    bad=clone(base)
    bad.experience.preferences.pause_on_menus=1
    rejects(bad,"nonboolean pause preference")
    bad=clone(base)
    bad.sim.pack_seconds=0.7
    rejects(bad,"unowned automatic packing effect")
    bad=clone(base)
    bad.sim.rack_capacity=48
    rejects(bad,"unowned shelf capacity effect")
    bad=clone(base)
    bad.sim.walk_speed=6.0
    rejects(bad,"unowned movement speed effect")
    bad=clone(base)
    bad.campaign.wallet+=1
    rejects(bad,"unearned wallet")
    for stage in captured:
        var state: Dictionary = captured[stage]
        var index := -1
        for worker in state.sim.workers:
            if worker.task+"_"+worker.phase==stage and worker.cargo_ids.size()>1: index=worker.id; break
        if index<0: continue
        bad=clone(state)
        bad.experience.operation_mode="balanced"
        rejects(bad,stage+" batched cargo forged into balanced mode")
        bad=clone(state)
        bad.sim.workers[index].cargo_ids.append(bad.sim.workers[index].cargo_ids[0])
        rejects(bad,stage+" duplicated batch unit")
        bad=clone(state)
        bad.sim.workers[index].source="outbound"
        rejects(bad,stage+" forged source")
        bad=clone(state)
        bad.sim.workers[index].target="inbound"
        rejects(bad,stage+" forged target")
        bad=clone(state)
        bad.sim.workers[index].work_remaining=10000.0
        rejects(bad,stage+" forged handling clock")
        if stage.ends_with("to_target"):
            # All references/reservations remain consistent. A truncated path
            # must not let delivery teleport cargo to an unvisited endpoint.
            bad=clone(state)
            var worker: Dictionary = bad.sim.workers[index]
            for edge in bad.sim._edges.values():
                edge.owners.erase(index)
                edge.queue.erase(index)
            worker.edge_id=""
            worker.edge_from=""
            worker.edge_to=""
            worker.edge_progress=0.0
            worker.path=[worker.node]
            worker.path_index=0
            rejects(bad,stage+" truncated route cannot teleport delivery")
    # New schema3 saves must not accept physically impossible clocks or routes.
    for stage in ["pick_to_source","pick_work","ship_to_source","ship_work"]:
        if not captured.has(stage): continue
        var state: Dictionary=captured[stage]
        var index: int=-1
        for worker in state.sim.workers:
            if worker.task+"_"+worker.phase==stage and worker.cargo_ids.size()>1: index=worker.id; break
        if index<0: continue
        bad=clone(state)
        var worker: Dictionary=bad.sim.workers[index]
        if stage.ends_with("to_source"):
            for edge in bad.sim._edges.values():
                edge.owners.erase(index)
                edge.queue.erase(index)
            worker.edge_id=""
            worker.edge_from=""
            worker.edge_to=""
            worker.edge_progress=0.0
            worker.node="inbound"
            worker.position=Vector3(-8,0,-2)
            worker.path=[worker.node]
            worker.path_index=0
            rejects(bad,stage+" truncated route cannot pick up remotely")
        else:
            worker.node="inbound"
            rejects(bad,stage+" handling must occur at the physical source")
    if captured.has("pick_to_target"):
        bad=clone(captured.pick_to_target)
        var carrier: Dictionary={}
        for worker in bad.sim.workers:
            if worker.task=="pick" and worker.phase=="to_target" and worker.cargo_ids.size()>1: carrier=worker; break
        if not carrier.is_empty():
            bad.sim.cargo[carrier.cargo_ids[0]].stored_at=bad.sim.sim_time+100000.0
            rejects(bad,"in-flight parcel cannot claim a future storage timestamp")
            bad=clone(captured.pick_to_target)
            bad.sim.cargo[carrier.cargo_ids[0]].created_at=-100000.0
            rejects(bad,"parcel cannot invent a creation clock before the job")
    if captured.has("pick_loaded_edge"):
        bad=clone(captured.pick_loaded_edge)
        for worker in bad.sim.workers:
            if worker.task=="pick" and worker.carrying and not worker.edge_id.is_empty():
                worker.position+=Vector3(1000,0,1000)
                break
        rejects(bad,"moving parcel must remain on its reserved physical lane")
        bad=clone(captured.pick_loaded_edge)
        for worker in bad.sim.workers:
            if worker.task=="pick" and worker.carrying and not worker.edge_id.is_empty():
                worker.edge_progress=1.0
                break
        rejects(bad,"route progress cannot disagree with carrier position")
    var relocation=Sim.new()
    relocation.accept_contract("growth_1")
    relocation.step(.25)
    relocation.apply_layout("clear_aisle")
    relocation.step(.05)
    check(relocation._move_remaining>0.0,"schema3 relocation corruption fixture")
    bad=relocation.export_release_state()
    bad.sim._move_duration=1000000.0
    bad.sim._move_remaining=999999.0
    bad.sim.relocation_history[-1].downtime=1000000.0
    rejects(bad,"forged relocation duration cannot introduce a days-long softlock")
    var inherited=Sim.new()
    inherited.accept_contract("growth_1")
    var inherited_state: Dictionary={}
    var inherited_worker: int=-1
    for tick in 300:
        inherited.step(.05)
        for worker in inherited.workers:
            if worker.task=="pick" and worker.phase=="to_target" and worker.node!=worker.target:
                inherited_state=inherited.export_release_state()
                inherited_worker=worker.id
                break
        if inherited_worker>=0: break
    check(inherited_worker>=0,"balanced legacy-profile flag-bypass fixture")
    if inherited_worker>=0:
        bad=clone(inherited_state)
        bad.experience.operating_profile=false
        var worker: Dictionary=bad.sim.workers[inherited_worker]
        for edge in bad.sim._edges.values():
            edge.owners.erase(inherited_worker)
            edge.queue.erase(inherited_worker)
        worker.edge_id=""
        worker.edge_from=""
        worker.edge_to=""
        worker.edge_progress=0.0
        worker.path=[worker.node]
        worker.path_index=0
        rejects(bad,"forged legacy operating flag cannot bypass schema3 physical route validation")
        # A forged endpoint can agree with the path and still skip a required
        # shelf -> packing stage. The frozen flag cannot legalize that route.
        worker.target=worker.node
        rejects(bad,"forged legacy operating flag cannot reroute parcel away from its required worksite")
        var old_shape=clone(bad)
        old_shape.schema=2
        old_shape.erase("experience")
        var original_v2=load(OS.get_environment("FLOTRA_QA_BASELINE_DIR")+"growth_sim.gd").new()
        legacy_validator_boundary["schema2_wrong_worksite_accepted"]=original_v2.import_release_state(old_shape).get("ok",false)
        bad=clone(inherited_state)
        bad.experience.operating_profile=false
        bad.sim.cargo[bad.sim.workers[inherited_worker].cargo_ids[0]].stored_at=bad.sim.sim_time+100000.0
        rejects(bad,"forged legacy operating flag cannot bypass cargo timestamp validation")
    var preferences_sim=Sim.new()
    preferences_sim.accept_contract("growth_1")
    preferences_sim.step(4.375)
    var physics: Dictionary=preferences_sim.export_release_state().sim
    for preference in [["preferred_speed",4],["pause_on_menus",true],["reduced_motion",true]]:
        check(preferences_sim.set_preference(preference[0],preference[1]).ok,"valid comfort preference "+str(preference[0]))
        check(same_bytes(physics,preferences_sim.export_release_state().sim),"comfort preference preserves active cargo clocks routes and reservations")
    roundtrip(preferences_sim,"active comfort preferences")
    var invalid = Sim.new()
    var state: Dictionary = invalid.export_release_state()
    check(not invalid.set_operation("turbo").ok and same_bytes(state,invalid.export_release_state()),"unknown runtime mode rejected atomically")

func cancel_evacuation() -> void:
    # Minimal legal ledger at the end of a shipment, before reward settlement:
    # one idle colleague is still at a bay access face that the new shelf needs.
    var sim=Sim.new()
    sim.accept_contract("growth_1")
    finish(sim,"evacuation fixture shipments")
    sim.campaign_status="running"
    sim.finished=false
    sim.campaign_wallet=100
    sim.completed_count=0
    sim.contract_results={}
    sim.last_result={}
    sim.workers[0].node="bulk_left"
    sim.workers[0].position=sim._points().bulk_left
    check(sim.apply_layout("clear_aisle").get("ok",false),"evacuation fixture queued layout")
    var validate=Sim.new()
    check(validate.import_release_state(sim.export_release_state()).get("ok",false),"minimal evacuation fixture is a legal complete physical ledger")
    sim.step(.05)
    check(sim.workers[0].task=="evacuate" and sim._move_remaining==0.0,"queued layout creates a real evacuation path")
    var cargo_before: Dictionary=sim.cargo.duplicate(true)
    var wallet_before: int=sim.campaign_wallet
    check(sim.cancel_layout().ok,"queued move cancels while colleague evacuates")
    check(same_bytes(cargo_before,sim.cargo) and wallet_before==sim.campaign_wallet,"cancelling evacuation move preserves every delivered unit and wallet")
    roundtrip(sim,"cancelled relocation during evacuation")
    sim.step(.05)
    check(not sim.finished and sim.workers[0].task=="evacuate","settlement waits for colleague to clear physical route")
    finish(sim,"cancelled evacuation drains")
    var idle := true
    for worker in sim.workers: idle=idle and worker.phase=="idle" and worker.edge_id.is_empty()
    check(idle and sim.campaign_wallet==240,"cancelled evacuation settles reward once with no stranded route ownership")
    roundtrip(sim,"cancelled evacuation complete")

func write_text(path: String, content: String) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(content)
    file.close()

func storage() -> void:
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    check(not sandbox.is_empty() and ProjectSettings.globalize_path("user://").begins_with(sandbox),"storage tests explicitly isolated from user progress")
    if sandbox.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(sandbox): return
    var sim = Sim.new()
    sim.accept_contract("growth_1")
    sim.step(3.375)
    var valid := Save.new().encode(sim.export_release_state())
    for corrupt in ["{corrupt",Save.new().encode({"schema":99}),valid.replace('"version":1','"version":2')]:
        write_text(Save.PATH,corrupt)
        write_text(Save.BACKUP,valid)
        var store = Save.new()
        var restored = Sim.new()
        var outcome: Dictionary = store.load_into(restored)
        check(outcome.get("ok",false) and outcome.get("backup",false) and store.blocked,"bad primary recovers backup read-only")
        restored.step(.3)
        check(not store.save_from(restored).ok,"bad primary prevents implicit repair overwrite")
        check(FileAccess.get_file_as_string(Save.PATH)==corrupt and FileAccess.get_file_as_string(Save.BACKUP)==valid,"primary and backup bytes protected")
        write_text(Save.PATH,valid)
        write_text(Save.BACKUP,corrupt)
        store=Save.new()
        restored=Sim.new()
        outcome=store.load_into(restored)
        check(outcome.get("ok",false) and store.blocked and not store.save_from(restored).ok,"unrecognized backup also blocks writes")
        check(FileAccess.get_file_as_string(Save.PATH)==valid and FileAccess.get_file_as_string(Save.BACKUP)==corrupt,"unknown backup is never overwritten")
    for name in ["release_sim","growth_sim"]:
        var old_class=load(OS.get_environment("FLOTRA_QA_BASELINE_DIR")+name+".gd")
        var old=old_class.new()
        old.accept_contract("first_shift" if name=="release_sim" else "growth_1")
        old.step(8.375)
        var original := Save.new().encode(old.export_release_state())
        write_text(Save.PATH,original)
        write_text(Save.BACKUP,original)
        var store=Save.new()
        var upgraded=Sim.new()
        check(store.load_into(upgraded).get("ok",false),name+" native checkpoint migration")
        check(FileAccess.get_file_as_string(Save.PATH)==original,name+" loading never changes original bytes")
        upgraded.step(.2)
        check(store.save_from(upgraded).ok,name+" explicit new checkpoint accepted")
        check(FileAccess.get_file_as_string(Save.BACKUP)==original,name+" old checkpoint remains byte-exact backup")
        var restored=Sim.new()
        check(Save.new().load_into(restored).get("ok",false) and same_bytes(upgraded.export_release_state(),restored.export_release_state()),name+" mixed version primary backup reload exact")

func _initialize() -> void:
    if OS.get_environment("FLOTRA_QA_BASELINE_DIR").is_empty():
        push_error("Use run_experience_adversarial.sh: independent git baselines and isolated storage are mandatory")
        quit(2)
        return
    var old1=load(OS.get_environment("FLOTRA_QA_BASELINE_DIR")+"release_sim.gd")
    var old2=load(OS.get_environment("FLOTRA_QA_BASELINE_DIR")+"growth_sim.gd")
    if OS.get_environment("FLOTRA_QA_FAST")!="1":
        print("START schema1 pinned baseline migration")
        old_fixtures(old1,"v1")
        print("START schema2 pinned baseline migration")
        old_fixtures(old2,"v2")
    print("START operational mode transport matrix")
    new_modes()
    if OS.get_environment("FLOTRA_QA_FAST")!="1":
        print("START mature robotic cart checkpoint coverage")
        mature_parcel()
    print("START adversarial state corruption")
    mutations()
    cancel_evacuation()
    if OS.get_environment("FLOTRA_QA_FAST")!="1": storage()
    print(JSON.stringify({"scope":"focused" if OS.get_environment("FLOTRA_QA_FAST")=="1" else "full","suite":"independent_experience_adversarial","checks":checks,"failures":failures,"old_stages":migration_stages.keys(),"batch_stages":batch_stages.keys(),"legacy_validator_boundary":legacy_validator_boundary}))
    quit(0 if failures.is_empty() else 1)
