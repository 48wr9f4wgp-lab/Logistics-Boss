extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")
const WarehouseViewScript = preload("res://view/warehouse_view_mobile.gd")
const ZoneInteractionScript = preload("res://view/zone_interaction_view.gd")
const CoachScript = preload("res://ui/v2_rank1_coach.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not await _verify_rank1_management_navigation():
        return
    if not await _verify_rank2_policy_controls_hidden():
        return
    if not await _verify_zone_affordance_and_ftue_guidance():
        return

    print("Godot v2 discoverability/navigation smoke passed")
    quit(0)


func _verify_rank1_management_navigation() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000

    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await process_frame
    hud._process(0.0)

    if hud._flow_button.visible or hud._inbound_button.visible or hud._outbound_button.visible:
        _fail("Rank 1 must hide unexplained legacy logistics-policy buttons")
        return false
    if hud._manage_button.text != "経営管理":
        _fail("closed Rank 1 management control must identify itself as 経営管理")
        return false

    if hud._v2_zone_nav_buttons.size() != 5:
        _fail("Management Overview must expose all five Zone navigation buttons")
        return false
    for zone_key in ["inbound", "storage", "picking", "packing", "shipping"]:
        var button := hud._v2_zone_nav_buttons.get(zone_key) as Button
        if button == null or not button.text.contains("タップして確認"):
            _fail("Management Zone button must clearly advertise tap-to-open: %s" % zone_key)
            return false

    var requested := {"zone": ""}
    var on_nav := func(zone_key: String) -> void:
        requested["zone"] = zone_key
    hud.zone_navigation_requested.connect(on_nav)

    hud._sheet.visible = true
    hud._apply_v2_primary_hud()
    var storage_button := hud._v2_zone_nav_buttons.get("storage") as Button
    storage_button.emit_signal("pressed")
    await process_frame
    if String(requested["zone"]) != "storage":
        _fail("Management STORAGE button must request the STORAGE Zone Panel")
        return false
    if hud._sheet.visible:
        _fail("Management must close before handing the player to the selected Zone")
        return false

    if hud._v2_rank1_project_nav_buttons.size() != 4:
        _fail("Rank 1 expansion must keep all four structural project routes visible")
        return false
    var rack_button := hud._v2_rank1_project_nav_buttons.get("rack_wing") as Button
    if rack_button == null or not rack_button.visible or rack_button.disabled or not rack_button.text.contains("Rack Wing") or not rack_button.text.contains("STORAGE"):
        _fail("Rack Wing must remain a visible actionable Project → STORAGE route")
        return false

    var purchase := sim.purchase_rank1_project(&"rack_wing")
    if not bool(purchase.get("ok", false)):
        _fail("discoverability smoke must be able to complete Rack Wing")
        return false
    hud._process(0.0)
    if not rack_button.visible or not rack_button.disabled or not rack_button.text.contains("完了"):
        _fail("completed Project route must remain visible as completed instead of disappearing")
        return false

    if hud.zone_navigation_requested.is_connected(on_nav):
        hud.zone_navigation_requested.disconnect(on_nav)
    hud.queue_free()
    await process_frame
    return true


func _verify_rank2_policy_controls_hidden() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 250000
    for kind in sim.rank1_project_kinds():
        var result: Dictionary = sim.purchase_rank1_project(kind)
        if not bool(result.get("ok", false)):
            _fail("Rank 2 policy-control seed must complete Rank 1 project: %s" % String(kind))
            return false
    sim.logistics_rating = LogisticsProgression.RANK2_RATING
    if not bool(sim.purchase_warehouse_expansion().get("ok", false)):
        _fail("Rank 2 policy-control seed must expand to Rank 2")
        return false

    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await process_frame
    hud._process(0.0)

    if hud._flow_button.visible or hud._inbound_button.visible or hud._outbound_button.visible:
        _fail("Rank 2 v2 must hide legacy policy controls that do not affect direct staffing")
        return false

    hud.queue_free()
    await process_frame
    return true


func _verify_zone_affordance_and_ftue_guidance() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000
    sim.inbound_queue = 8

    var view: MobileWarehouseView = WarehouseViewScript.new()
    get_root().add_child(view)
    view.bind_sim(sim)

    var interaction: WarehouseZoneInteractionView = ZoneInteractionScript.new()
    view.add_child(interaction)
    interaction.bind(view, sim)
    interaction._process(0.25)
    await process_frame

    var inbound_label := interaction._zone_labels.get("inbound") as Label3D
    var storage_label := interaction._zone_labels.get("storage") as Label3D
    if inbound_label == null or not inbound_label.text.contains("混雑・タップ"):
        _fail("congested INBOUND label must advertise that the Zone is tappable")
        return false
    if storage_label == null or not storage_label.text.contains("タップ"):
        _fail("normal Zone labels must still advertise tap affordance")
        return false

    var coach: V2Rank1Coach = CoachScript.new()
    get_root().add_child(coach)
    await process_frame
    coach.bind_context(sim, interaction, false)
    coach._process(0.1)

    if coach.current_step_key() != "inspect":
        _fail("a visible Rank 1 bottleneck must advance onboarding to inspect")
        return false
    if coach.guidance_zone() != "inbound" or interaction.guidance_zone() != "inbound":
        _fail("FTUE must highlight the actual bottleneck Zone instead of only describing Zone Panel")
        return false
    if not inbound_label.text.contains("ここをタップ"):
        _fail("guided bottleneck Zone must explicitly say ここをタップ")
        return false
    if not coach.body_text().contains("INBOUND") or not coach.body_text().contains("ここをタップ"):
        _fail("FTUE copy must point to the same physical Zone label")
        return false

    interaction.zone_selected.emit("inbound")
    if coach.current_step_key() != "act":
        _fail("tapping the guided Zone must advance to decision step")
        return false
    if not interaction.guidance_zone().is_empty():
        _fail("FTUE guidance must clear after the player opens the Zone")
        return false

    coach.queue_free()
    view.queue_free()
    await process_frame
    return true
