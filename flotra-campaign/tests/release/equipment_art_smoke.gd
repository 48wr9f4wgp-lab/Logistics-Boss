extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
const Store = preload("res://prototype/release_save.gd")
const Growth = preload("res://prototype/growth_sim.gd")
const Legacy = preload("res://prototype/release_sim.gd")
var errors: Array[String] = []
var checks := 0
func check(ok: bool, text: String):
    checks += 1
    if not ok: errors.append(text); push_error(text)
func _init(): run.call_deferred()
func geometry(mesh: ArrayMesh, size: Vector3, label: String):
    check(mesh.get_surface_count() == 1,label+" uses one opaque shared surface")
    for surface in mesh.get_surface_count():
        var material := mesh.surface_get_material(surface) as StandardMaterial3D
        check(material != null,label+" has an explicit standard material")
        if material != null:
            check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,label+" material is opaque")
            check(material.vertex_color_use_as_albedo,label+" material retains authored vertex colours")
    var bounds := mesh.get_aabb()
    check(bounds.position.x >= -size.x*.5-.0001 and bounds.end.x <= size.x*.5+.0001,label+" within declared width")
    check(bounds.position.z >= -size.z*.5-.0001 and bounds.end.z <= size.z*.5+.0001,label+" within declared depth")
    check(bounds.position.y >= -.0001 and bounds.end.y <= size.y+.0001,label+" within declared height")
func finish_contract(sim, id: String) -> bool:
    var accepted: Dictionary = sim.accept_contract(id)
    check(accepted.ok,"Art fixture accepts real contract "+id)
    if not accepted.ok: return false
    for second in 1800:
        sim.step(1.0)
        if sim.finished:
            check(sim.check_invariants().ok,"Earned art fixture conserves cargo "+id)
            return true
    check(false,"Art fixture completes within bounded horizon "+id)
    return false
func installed_art(view, parent: Node3D, kind: String, label: String):
    var artwork := parent.get_node_or_null("EquipmentArtwork") as MeshInstance3D
    check(artwork != null,label+" has its one equipment artwork node")
    if artwork == null: return
    check(artwork.is_visible_in_tree() and artwork.layers != 0,label+" owned artwork is actually rendered")
    check(artwork.mesh == view._art_mesh(kind),label+" installs the expected owned "+kind+" shared mesh")
    check(artwork.material_override == null,label+" does not override the shared opaque material")
    var artworks := 0
    for child in parent.get_children():
        if child == artwork: artworks += 1
        elif child is Node3D:
            check(not child.is_visible_in_tree(),label+" retired artwork stays hidden: "+str(child.name))
    check(artworks == 1,label+" has exactly one active artwork child")
func inspect_owned_art(app, rack_kind: String, packing_kind: String, label: String):
    var world = app.world
    installed_art(world,world._slots.shelf.get_node("RackEquipment"),rack_kind,label+" rack")
    installed_art(world,world._slots.packing.get_node("PackingEquipment"),packing_kind,label+" packing")
    var inserts: Node3D = world._slots.shelf.get_node("RackEquipment/CapacityInserts")
    var tool: Node3D = world._slots.packing.get_node("PackingUpgrade")
    check(not inserts.is_visible_in_tree(),label+" retired capacity inserts are hidden")
    check(not tool.is_visible_in_tree(),label+" retired packing upgrade is hidden")
    var robots := 0
    for actor in world._actors.values():
        if str(actor.get_meta("growth_actor_kind","human")) != "robot":
            check(not actor.has_node("EquipmentArtwork"),label+" human never gains robot artwork")
            continue
        robots += 1
        var artwork: MeshInstance3D = actor.get_node("EquipmentArtwork")
        check(artwork.is_visible_in_tree() and artwork.mesh == world._art_mesh("robot"),label+" real robot shares its rendered mesh")
        for title in ["RobotChassis","SafetyVest","RobotHead","RobotEyes","RobotBeacon","LeftLeg","RightLeg"]:
            check(not actor.get_node(title).is_visible_in_tree(),label+" retired robot part stays hidden: "+title)
    check(robots == app.sim.snapshot().robot_count,label+" artwork count follows actual robot ownership")
    check(world._actors.size() == app.sim.workers.size(),label+" reload leaves no stale actors")
func reload_owned_art(app, state: Dictionary, rack_kind: String, packing_kind: String, label: String):
    var store := Store.new()
    var decoded: Dictionary = store.decode(store.encode(state))
    check(decoded.ok,label+" earned state decodes")
    if not decoded.ok: return
    var imported: Dictionary = app.sim.import_release_state(decoded.data)
    check(imported.ok,label+" earned state imports")
    if not imported.ok: return
    var before: Dictionary = app.sim.export_release_state()
    app.world.bind_sim(app.sim)
    for frame in 3: await process_frame
    inspect_owned_art(app,rack_kind,packing_kind,label)
    for frame in 4: app.world.refresh()
    check(app.sim.export_release_state() == before,label+" presentation preserves the exact imported state")
    check(app.sim.check_invariants().ok,label+" imported cargo remains conserved")
func ownership_transitions(app):
    # All ownership comes from completed contracts and public purchases. In
    # particular packing_2 is earned in the original campaign, then migrated.
    var legacy := Legacy.new()
    var original_manual: Dictionary = legacy.export_release_state()
    await reload_owned_art(app,original_manual,"rack","packing_manual","Original manual reload")
    if not finish_contract(legacy,"first_shift"): return
    check(legacy.buy_upgrade("rack_24").ok,"Legacy rack upgrade is actually purchased")
    await reload_owned_art(app,legacy.export_release_state(),"rack_upgraded","packing_manual","Earned rack_24")
    if not finish_contract(legacy,"small_orders"): return
    check(legacy.buy_upgrade("packing_2").ok,"Legacy packing_2 is actually purchased")
    var improved_manual: Dictionary = legacy.export_release_state()
    await reload_owned_art(app,improved_manual,"rack_upgraded","packing_manual","Earned packing_2 remains manual")
    check("packing_2" in app.sim.purchased_upgrades and "auto_pack" not in app.sim.purchased_upgrades,"Migrated improved bench does not invent automatic ownership")
    var growth := Growth.new()
    await reload_owned_art(app,growth.export_release_state(),"rack","packing_manual","Fresh current manual reload")
    for id in ["growth_1","growth_2"]:
        if not finish_contract(growth,id): return
    check(growth.buy_upgrade("rack_48").ok,"Current rack_48 is actually purchased")
    await reload_owned_art(app,growth.export_release_state(),"rack_upgraded","packing_manual","Earned rack_48")
    check(growth.buy_upgrade("auto_pack").ok,"Current auto_pack is actually purchased")
    await reload_owned_art(app,growth.export_release_state(),"rack_upgraded","packing_auto","Earned automatic packer")
    await reload_owned_art(app,improved_manual,"rack_upgraded","packing_manual","Automatic to older packing_2 reload")
    await reload_owned_art(app,original_manual,"rack","packing_manual","Upgraded to original manual reload")
func run():
    var app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FLOTRA_GROWTH_FIXTURES")+"/late.json"))
    var decoded: Dictionary = Store.new().decode(data.encoded)
    check(decoded.ok,"Mature earned fixture decodes")
    check(app.sim.import_release_state(decoded.data).ok,"Mature fixture imports")
    var before = app.sim.export_release_state()
    app.world.bind_sim(app.sim)
    for i in 4: await process_frame
    inspect_owned_art(app,"rack_upgraded","packing_auto","Mature earned fixture")
    for kind in ["rack","rack_upgraded"]: geometry(app.world._art_mesh(kind),Vector3(2.22,1.85,1.25),kind)
    for kind in ["packing_manual","packing_auto"]: geometry(app.world._art_mesh(kind),Vector3(1.6,.95,1),kind)
    var robot_mesh: ArrayMesh = app.world._art_mesh("robot")
    geometry(robot_mesh,Vector3(.36,.5,.36),"robot")
    var max_radius := 0.0
    for vertex in robot_mesh.get_faces(): max_radius = maxf(max_radius,Vector2(vertex.x,vertex.z).length())
    check(max_radius <= .18001,"Robot actual vertices stay within reserved .18m radius")
    check(app.world._equipment_mesh_cache.size() == 5,"Only five once-built shared variants")
    var shared_robot := robot_mesh.get_rid()
    var robots := 0
    for node in app.world._actors.values():
        if str(node.get_meta("growth_actor_kind","human")) != "robot": continue
        robots += 1
        check(node.get_node("EquipmentArtwork").mesh.get_rid() == shared_robot,"Every actual robot reuses same mesh")
    check(robots == app.sim.snapshot().robot_count,"No extra decorative robot actors")
    for i in 15: app.world.refresh()
    check(app.sim.export_release_state() == before,"Art and repeated refresh do not alter saved state")
    var cache_ids := {}
    for kind in app.world._equipment_mesh_cache: cache_ids[kind] = app.world._equipment_mesh_cache[kind].get_rid().get_id()
    app.sim.step(5)
    app.world.refresh()
    for kind in cache_ids: check(app.world._equipment_mesh_cache[kind].get_rid().get_id() == cache_ids[kind],"Moving warehouse never rebuilds equipment mesh")
    check(app.sim.check_invariants().ok,"Actual moving cargo remains conserved")
    await ownership_transitions(app)
    check(app.world._equipment_mesh_cache.size() == 5,"Ownership transitions retain only five shared variants")
    for kind in cache_ids: check(app.world._equipment_mesh_cache[kind].get_rid().get_id() == cache_ids[kind],"Ownership transitions and older reloads reuse each existing mesh")
    print(JSON.stringify({"suite":"equipment_art_smoke","checks":checks,"failures":errors,"robot_max_radius":max_radius,"mesh_ids":cache_ids,"scope":"Equipment geometry/shared resources, earned ownership and older/manual reloads, opacity/retired artwork, domain invariance; not device performance"}))
    quit(0 if errors.is_empty() else 1)
