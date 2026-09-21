extends "res://tests/growth_first_smoke.gd"

func inventory(sim: FlotraV2Sim) -> int:
    var count := super.inventory(sim)
    for remaining in sim._cell_jobs:
        if remaining > 0: count += 1
    for job in sim._lane_jobs:
        count += int(job["cargo"])
    return count

func fixture() -> FlotraV2Sim:
    var s := SimScript.new() as FlotraV2Sim
    s.money = 250000 # Explicit boundary fixture, not pacing evidence.
    s.purchase_rank1_project(&"rack_wing")
    s.purchase_rank1_project(&"forklift_project")
    s.shipped = 20
    s.purchase_warehouse_expansion()
    s.purchase_growth_automation(&"transfer_conveyor")
    s.purchase_growth_automation(&"extra_forklift")
    return s

func run() -> void:
    test_boundaries()
    test_processing()
    test_batch_and_saves()
    test_natural_capacity()
    print("Capacity growth checks finished; failures=%d" % failures)
    quit(1 if failures else 0)

func test_boundaries() -> void:
    var s := fixture()
    var money := s.money
    expect(not s.purchase_capacity(&"dispatch_lane",0)["ok"],"Dispatch requires corresponding packing investment")
    expect(s.money == money,"Rejected purchase doesn't spend")
    for index in 3:
        money = s.money
        var cost := int(s.capacity_info(&"packing_cell")["cost"])
        expect(s.purchase_capacity(&"packing_cell",index)["ok"] and s.money == money-cost,"Packing purchase bills exactly once")
        money = s.money
        expect(not s.purchase_capacity(&"packing_cell",index)["ok"] and s.money == money,"Stale or duplicated intent cannot purchase next unit")
    for index in 2:
        expect(s.purchase_capacity(&"dispatch_lane",index)["ok"],"Dispatch unit is additive")
    money = s.money
    expect(not s.purchase_capacity(&"packing_cell",3)["ok"] and not s.purchase_capacity(&"dispatch_lane",2)["ok"] and s.money == money,"Bounded cap protected")
    s.purchase_facility(&"parallel_pack")
    s.purchase_facility(&"fast_pack_cell")
    expect(s.packing_cells == 3 and s.dispatch_lanes == 2,"Original equipment-mode replacement cannot delete added capacity")

func test_processing() -> void:
    var base := fixture()
    var upgraded := fixture()
    upgraded.purchase_capacity(&"packing_cell",0)
    upgraded.purchase_capacity(&"packing_cell",1)
    upgraded.purchase_capacity(&"packing_cell",2)
    base.packing_queue = 100
    upgraded.packing_queue = 100
    for i in 120:
        base.sim_time += 0.1; upgraded.sim_time += 0.1
        base._update_packing(0.1); upgraded._update_packing(0.1)
    expect(upgraded.packed_queue > base.packed_queue and upgraded.capacity_packed > 0,"Added cells process real backlog, not decorative work")
    print("PACKING_PRESSURE_12S base=%d added=%d added_cell_completions=%d" % [base.packed_queue,upgraded.packed_queue,upgraded.capacity_packed])
    for index in 2:
        upgraded.purchase_capacity(&"dispatch_lane",index)
    var money := upgraded.money
    var shipped := upgraded.shipped
    var n := inventory(upgraded)
    for i in 200:
        upgraded.sim_time += 0.1
        upgraded._update_packing(0.1)
        expect(inventory(upgraded) == n,"Packing and dispatch retain every real parcel")
    expect(upgraded.money-money == (upgraded.shipped-shipped)*500,"Auto dispatch revenue uses actual parcels at standard value")
    expect(upgraded.capacity_shipped > 0,"Dispatch unit completes actual deliveries")
    print("DISPATCH_PRESSURE completed=%d revenue=%d conserved=%d" % [upgraded.shipped-shipped,upgraded.money-money,n])

func test_batch_and_saves() -> void:
    var s := fixture()
    s.purchase_capacity(&"packing_cell",0); s.purchase_capacity(&"packing_cell",1)
    s.purchase_capacity(&"dispatch_lane",0)
    s.inbound_queue = 80; s.open_orders = 90; s.rack_capacity = 96
    s._inbound_timer = 10000; s._order_timer = 10000
    s.packing_queue = 15; s.packed_queue = 10
    var total := inventory(s)
    for i in 400:
        s.step(0.1)
        expect(inventory(s) == total,"Full flow including workers, belt, both forklifts and cells conserves cargo")
        if i % 41 == 0:
            var before_live := s.snapshot()
            var saved := s.save_data()
            var restored := SimScript.new() as FlotraV2Sim
            expect(restored.load_data(saved),"Schema11 load")
            expect(inventory(restored) == total and restored.money == s.money and restored.shipped == s.shipped,"Save projection keeps cargo and earnings")
            expect(s.snapshot() == before_live,"Save generation never mutates live simulation")
            expect(restored.packing_cells == 2 and restored.dispatch_lanes == 1,"Capacity ownership persists")
            expect(restored.save_data() == saved,"Projected save is idempotent across loads")
    var previous := s.zone_staffing.duplicate(true)
    var task_snapshot := s.workers.duplicate(true)
    var money := s.money
    var result := s.apply_staffing_distribution({"inbound":1,"picking":3,"shipping":1},previous)
    expect(result["ok"] and s.staffing_cooldown == 30.0,"One batch commit starts one existing observation cooldown")
    for i in s.workers.size():
        for field in ["task","progress","remaining","source","target"]:
            expect(s.workers[i][field] == task_snapshot[i][field],"Reassignment preserves current cargo job and progress")
    expect(s.money == money and inventory(s) == total,"Staffing never consumes funds or cargo")
    var committed := s.zone_staffing.duplicate()
    expect(not s.apply_staffing_distribution(previous,committed)["ok"],"Cooldown guards apply")
    s.staffing_cooldown = 0
    expect(not s.apply_staffing_distribution(previous,previous)["ok"] and s.zone_staffing == committed,"Stale draft rejected without partial mutation")
    for bad in [{"inbound":0,"picking":4,"shipping":1},{"inbound":1.0,"picking":3,"shipping":1},{"inbound":1,"picking":5,"shipping":1}]:
        expect(not s.apply_staffing_distribution(bad,committed)["ok"] and s.zone_staffing == committed,"Invalid count/type/total rejected atomically")
    var old := s.save_data()
    old["schema_version"] = 10
    old.erase("capacity_growth")
    var loaded := SimScript.new() as FlotraV2Sim
    expect(loaded.load_data(old) and loaded.money == s.money and loaded.zone_staffing == s.zone_staffing,"Old schema10 retains cash and staffing")
    expect(loaded.extra_forklift_owned and loaded.conveyor_owned and loaded.packing_cells == 0 and loaded.dispatch_lanes == 0,"Migration retains purchased machines and grants no new ones")
    var store := LogisticsSaveStore.new()
    expect(store.save_sim(s) and store.save_sim(s),"Write primary plus backup in isolated test directory")
    var file := FileAccess.open(LogisticsSaveStore.SAVE_PATH,FileAccess.WRITE)
    file.store_string("[]");file.close()
    var restored := SimScript.new() as FlotraV2Sim
    expect(store.load_into(restored) and inventory(restored) == total and restored.packing_cells == 2,"Real disk backup recovers capacity plus cargo")

func test_natural_capacity() -> void:
    var s := SimScript.new() as FlotraV2Sim
    var order: Array[StringName] = [&"packing_cell",&"dispatch_lane",&"packing_cell",&"dispatch_lane",&"packing_cell"]
    var index := 0
    var times: Array[float] = []
    while s.sim_time < 1200.0:
        if not s.forklift_unlocked and s.money >= s.FORKLIFT_PROJECT_COST:
            s.purchase_rank1_project(&"forklift_project")
        elif s.forklift_unlocked and not s.rank1_project_owned(&"rack_wing") and s.money >= s.RACK_WING_COST:
            s.purchase_rank1_project(&"rack_wing")
        elif s.facility_rank == 1 and s.rank1_expansion_readiness()["ready"]:
            s.purchase_warehouse_expansion()
        elif s.facility_rank >= 2 and not s.conveyor_owned and s.money >= s.CONVEYOR_COST:
            s.purchase_growth_automation(&"transfer_conveyor")
        elif s.conveyor_owned and not s.extra_forklift_owned and s.money >= s.EXTRA_FORKLIFT_COST:
            s.purchase_growth_automation(&"extra_forklift")
        elif s.extra_forklift_owned and index < order.size():
            var info := s.capacity_info(order[index])
            if s.money >= int(info["cost"]):
                expect(s.purchase_capacity(order[index],int(info["count"]))["ok"],"Natural earned capacity")
                times.append(s.sim_time);index += 1
        if index == order.size(): break
        s.step(0.1)
    expect(index == 5 and s.completed_contracts == 0 and s.logistics_rating == 0,"Five new stages reachable using only ordinary earned income")
    print("NATURAL_CAPACITY_1X_TIMES %s shipped=%d funds=%d" % [str(times),s.shipped,s.money])
