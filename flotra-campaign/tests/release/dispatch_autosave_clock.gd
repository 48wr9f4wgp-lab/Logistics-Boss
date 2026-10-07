extends SceneTree
## Real main/scene integration with deterministic foreground time and memory
## writes. Every capture still uses the real schema5 codec and save pipeline.
const Main = preload("res://prototype/growth_main.gd")
const Save = preload("res://prototype/dispatch_save.gd")
var checks := 0
var failures: Array[String] = []

class MemoryStore extends Save:
    var live_sim
    var captures: Array = []
    var writes: Array = []
    var write_live_states: Array = []
    var advances := 0
    var flushes := 0
    var synchronous_saves := 0
    var fail_write := ""
    func _read_pair() -> Dictionary:
        return {"ok":true,"source":"v5","primary":"","backup":"","primary_present":false,"backup_present":false}
    func begin_autosave(sim) -> Dictionary:
        var result: Dictionary = super.begin_autosave(sim)
        if result.get("started", false):
            captures.append({"state":sim.export_release_state(),"generation":result.get("generation",-1)})
        return result
    func advance_autosave(expected_generation: int = -1) -> Dictionary:
        advances += 1
        return super.advance_autosave(expected_generation)
    func flush_autosave(expected_generation: int = -1) -> Dictionary:
        flushes += 1
        return super.flush_autosave(expected_generation)
    func save_from(sim) -> Dictionary:
        synchronous_saves += 1
        return super.save_from(sim)
    func _write(text: String) -> Dictionary:
        if not fail_write.is_empty(): return {"ok":false,"reason":fail_write}
        writes.append(decode(text).data)
        write_live_states.append(live_sim.export_release_state())
        return {"ok":true}
    func clear_observations() -> void:
        captures.clear()
        writes.clear()
        write_live_states.clear()
        advances = 0
        flushes = 0
        synchronous_saves = 0

class SynchronousStore extends RefCounted:
    var blocked := false
    var status := "未保存"
    var writes: Array = []
    func load_into(_sim) -> Dictionary: return {"ok":true,"fresh":true}
    func save_from(sim) -> Dictionary:
        writes.append(sim.export_release_state())
        status = "自動保存済み"
        return {"ok":true}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func make_app(store = null, persistent: bool = true) -> Dictionary:
    var clock := {"now":1000000}
    var app = Main.new()
    if store == null: store = MemoryStore.new()
    app.save_store = store
    app.persistence_enabled = persistent
    app.frame_clock = func() -> int: return int(clock.now)
    root.add_child(app)
    app.set_process(false)
    app.hud.set_process(false)
    app.world.set_process(false)
    if store is MemoryStore: store.live_sim = app.sim
    app.hud.show_play()
    app._accept_contract("growth_1")
    app._last_status = app.sim.campaign_status
    if store is MemoryStore: store.clear_observations()
    else: store.writes.clear()
    return {"app":app,"clock":clock,"store":store}

func frame(fixture: Dictionary, seconds: float, reported_delta: float = 0.1333333333) -> void:
    fixture.clock.now += roundi(seconds * 1000000.0)
    fixture.app._process(reported_delta)

func begin_capture(fixture: Dictionary) -> void:
    fixture.app._save_elapsed = 4.75
    frame(fixture, 0.25)
    check(fixture.store.has_pending_autosave(), "Five foreground seconds begin a pending capture")

func dispose(fixture: Dictionary) -> void:
    fixture.app.free()

func cadence_and_snapshot() -> void:
    var fixture := make_app()
    var app = fixture.app
    var store = fixture.store
    for tick in 19: frame(fixture, 0.25)
    check(store.captures.is_empty() and store.writes.is_empty(), "No autosave before five active foreground seconds")
    frame(fixture, 0.25)
    check(store.captures.size() == 1 and store.has_pending_autosave(), "Capture begins at five foreground seconds")
    check(store.advances == 0 and store.writes.is_empty(), "Capture frame executes no later phase or commit")
    check(app.hud._save_status == "自動保存中", "HUD reports pending rather than saved at capture")
    var captured: Dictionary = app.sim.export_release_state()
    frame(fixture, 0.25)
    check(store.advances == 1 and store.has_pending_autosave() and store.writes.is_empty(), "First following frame executes phase two only")
    check(app.hud._save_status == "自動保存中", "HUD remains pending during shape validation")
    frame(fixture, 0.25)
    check(store.advances == 2 and store.has_pending_autosave() and store.writes.is_empty(), "Second following frame executes phase three only")
    check(app.hud._save_status == "自動保存中", "HUD remains pending after domain validation")
    var before_commit: Dictionary = app.sim.export_release_state()
    frame(fixture, 0.25)
    check(store.flushes == 1 and store.writes.size() == 1 and not store.has_pending_autosave(), "Third following frame drains remaining phases and commits")
    check(store.writes[0] == captured and store.write_live_states[0] == before_commit, "Commit writes immutable capture before the third later simulation step")
    check(app.hud._save_status == "自動保存済み", "HUD reports saved only after actual successful commit")
    check(is_equal_approx(app._save_elapsed, 0.75), "Commit does not reset five-second capture cadence")
    for tick in 16: frame(fixture, 0.25)
    check(store.captures.size() == 1, "Next capture still waits for five seconds from previous capture")
    frame(fixture, 0.25)
    check(store.captures.size() == 2 and store.has_pending_autosave(), "Next capture occurs five seconds after capture rather than commit")
    var generation: int = store.captures[-1].generation
    var elapsed: float = app._save_elapsed
    app._begin_autosave()
    check(store.captures.size() == 2 and store.captures[-1].generation == generation and app._save_elapsed == elapsed, "Repeated begin preserves pending generation and capture clock")
    dispose(fixture)

func synchronous_boundaries() -> void:
    for action in ["speed","preference","pause","intro","window_focus","application_focus","application_pause","close"]:
        var fixture := make_app()
        var app = fixture.app
        var store = fixture.store
        begin_capture(fixture)
        frame(fixture, 0.2)
        var old_capture: Dictionary = store.captures[0].state
        var old_generation: int = store.captures[0].generation
        match action:
            "speed": app._set_speed(4.0)
            "preference": app._set_preference("reduced_motion", true)
            "pause": app._pause_trial(true)
            "intro": app._return_to_intro()
            "window_focus": app._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
            "application_focus": app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
            "application_pause": app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
            "close": app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
        var current: Dictionary = app.sim.export_release_state()
        check(store.synchronous_saves == 1 and store.writes.size() == 1, "Explicit boundary saves synchronously: " + action)
        check(not store.has_pending_autosave() and store.writes[-1] == current and current != old_capture, "Explicit boundary cancels old generation and captures newest state: " + action)
        var diagnostics: Dictionary = store.autosave_status()
        check(diagnostics.last_superseded_generation == old_generation and diagnostics.last_saved_generation != old_generation, "Read-only diagnostics identify the exact superseded capture: " + action)
        for tick in 3: frame(fixture, 0.1)
        check(store.writes.size() == 1, "Canceled generation never commits later: " + action)
        dispose(fixture)

func phase_and_clock_bounds() -> void:
    var fixture := make_app()
    begin_capture(fixture)
    var app = fixture.app
    var store = fixture.store
    # This defensive age boundary is normally stronger than needed: three
    # quarter-second-capped render frames cannot accumulate a whole second.
    app._autosave_foreground_elapsed = 0.9
    var before: Dictionary = app.sim.export_release_state()
    frame(fixture, 0.2)
    check(store.flushes == 1 and not store.has_pending_autosave(), "Prospective foreground progress above one second drains before the next step")
    check(store.write_live_states[-1] == before, "Foreground-limit drain precedes any new live simulation progress")
    check(is_equal_approx(app.sim.sim_time, float(before.sim.sim_time) + 0.4), "Foreground drain never skips or slows the regular simulation step")
    dispose(fixture)

    fixture = make_app()
    begin_capture(fixture)
    app = fixture.app
    store = fixture.store
    var capture: Dictionary = app.sim.export_release_state()
    # No rendered callback means no wall-clock commit promise. On return,
    # the existing foreground cap remains unchanged and excess is discarded.
    frame(fixture, 30.0)
    check(store.has_pending_autosave() and store.writes.is_empty(), "A long render gap does not pretend that pending storage already committed")
    check(is_equal_approx(app.sim.sim_time, float(capture.sim.sim_time) + 0.5), "Thirty-second render gap still grants only the original quarter-second budget at 2x")
    frame(fixture, 0.25)
    frame(fixture, 0.25)
    check(not store.has_pending_autosave() and store.writes[-1] == capture, "Long-gap capture still commits on the third later rendered frame")
    dispose(fixture)

    fixture = make_app()
    begin_capture(fixture)
    app = fixture.app
    store = fixture.store
    app._preferences.pause_on_menus = true
    app.hud.show_controls()
    var paused: Dictionary = app.sim.export_release_state()
    for tick in 3: frame(fixture, 20.0)
    check(not store.has_pending_autosave() and store.writes[-1] == paused, "Paused render frames can finish a capture without further foreground progress")
    check(app.sim.export_release_state() == paused and app._save_elapsed == 0.0, "Menu reading adds neither cargo progress nor autosave capture time")
    dispose(fixture)

func blocked_and_warning_paths() -> void:
    for failure in ["invalid_state", "concurrent_change", "write_uncertain", "writer_unavailable"]:
        var fixture := make_app()
        var app = fixture.app
        var store = fixture.store
        if failure == "invalid_state": app.sim.campaign_wallet = -1
        else: store.fail_write = failure
        begin_capture(fixture)
        for phase in 3:
            var before: Dictionary = app.sim.export_release_state()
            frame(fixture, 0.25)
            if store.blocked:
                check(app.sim.export_release_state() == before, "Known blocked phase prevents that frame's simulation step: " + failure)
                break
        check(store.blocked and not store.has_pending_autosave() and not app.running, "Blocked phase cancels pending work and stops foreground play: " + failure)
        check(app.hud._sheet_kind == "save_protection" and app.hud._save_status == store.status, "Blocked phase shows protection and its exact reason: " + failure)
        var stopped: Dictionary = app.sim.export_release_state()
        frame(fixture, 0.25)
        app._set_speed(4.0)
        app._pause_trial(false)
        check(app.sim.export_release_state() == stopped and not app.running, "No later time or explicit mutation passes blocked protection: " + failure)
        dispose(fixture)

    var fixture := make_app()
    fixture.store.fail_write = "quota"
    begin_capture(fixture)
    for phase in 3: frame(fixture, 0.25)
    check(not fixture.store.blocked and fixture.app.running and not fixture.store.has_pending_autosave(), "Ordinary write failure retains the existing nonterminal warning semantics")
    check(fixture.app.hud._save_status == fixture.store.status and fixture.app.hud._save_status.contains("保存できません"), "Ordinary failure publishes its unsaved warning immediately")
    dispose(fixture)

    fixture = make_app()
    fixture.app.sim.contract_results["growth_1"] = {"attempts":1,"best_time":100.0,"best_medal":"silver","earned":0,"padding":"x".repeat(Save.MAX_PAYLOAD_BYTES)}
    fixture.app._save_elapsed = 4.75
    frame(fixture, 0.25)
    check(fixture.store.captures.size() == 1 and not fixture.store.has_pending_autosave(), "Phase-one oversize rejection counts as one attempted capture")
    check(not fixture.store.blocked and fixture.app.running and fixture.app._save_elapsed == 0.0, "Oversize warning retains play and resets capture cadence once")
    check(fixture.app.hud._save_status == fixture.store.status and fixture.store.status.contains("大きすぎる"), "Oversize preflight shows the existing unsaved warning")
    for tick in 19: frame(fixture, 0.25)
    check(fixture.store.captures.size() == 1 and fixture.store.writes.is_empty(), "Oversize rejection cannot trigger a capture retry every rendered frame")
    frame(fixture, 0.25)
    check(fixture.store.captures.size() == 2 and fixture.store.writes.is_empty(), "Oversize retry waits for the next five active foreground seconds")
    dispose(fixture)

    for boundary in ["intro", "exit"]:
        fixture = make_app()
        begin_capture(fixture)
        fixture.store.fail_write = "concurrent_change"
        if boundary == "intro": fixture.app._return_to_intro()
        else: fixture.app._exit_trial()
        check(fixture.store.blocked and not fixture.app.running and fixture.app.hud._sheet_kind == "save_protection", "Failed synchronous boundary preserves the protection screen: " + boundary)
        dispose(fixture)

func deterministic_parity_and_completion() -> void:
    var staged := make_app()
    var no_save := make_app(null, false)
    var saw_completion := false
    var before_completion: Dictionary = {}
    var completion_interval := 0.0
    for tick in 1500:
        if tick in [25,70]:
            staged.app._set_speed(4.0 if tick == 25 else 2.0)
            no_save.app._set_speed(4.0 if tick == 25 else 2.0)
        if tick == 40:
            staged.app._set_preference("reduced_motion", true)
            no_save.app._set_preference("reduced_motion", true)
        if tick == 50:
            staged.app._pause_trial(true)
            no_save.app._pause_trial(true)
            frame(staged, 60.0)
            frame(no_save, 60.0)
            staged.app._pause_trial(false)
            no_save.app._pause_trial(false)
        var interval: float = [0.1,0.2,0.25,0.35][tick % 4]
        before_completion = staged.app.sim.export_release_state()
        completion_interval = interval
        frame(staged, interval)
        frame(no_save, interval)
        check(staged.app.sim.export_release_state() == no_save.app.sim.export_release_state(), "Same input sequence preserves exact money, cargo and time at frame %d" % tick)
        check(staged.app.sim.check_invariants().ok, "Staged saving preserves cargo/route invariants at frame %d" % tick)
        if staged.app.sim.finished:
            saw_completion = true
            check(not staged.store.has_pending_autosave() and staged.store.writes[-1] == staged.app.sim.export_release_state(), "Real contract completion synchronously writes its newest reward and full cargo state")
            break
    check(saw_completion, "Deterministic parity sequence completes a real contract")
    check(no_save.store.captures.is_empty() and no_save.store.writes.is_empty(), "No-save route performs no capture or write even through actions, autosaves and completion")
    dispose(staged)
    dispose(no_save)

    var completing := make_app()
    check(completing.app.sim.import_release_state(before_completion).ok, "Last pre-completion checkpoint restores exactly")
    completing.app._apply_preferences()
    completing.app._begin_autosave()
    check(completing.store.has_pending_autosave(), "Completion boundary fixture has a pending older capture")
    var old_generation: int = completing.store.captures[-1].generation
    frame(completing, completion_interval)
    check(completing.app.sim.finished and completing.store.synchronous_saves == 1 and not completing.store.has_pending_autosave(), "Actual completion supersedes and synchronously drains the older pending capture")
    check(completing.store.writes.size() == 1 and completing.store.writes[0] == completing.app.sim.export_release_state() and completing.store.last_saved_generation != old_generation, "Only the newest completed state and reward reach storage")
    dispose(completing)

    var legacy := make_app(SynchronousStore.new())
    for tick in 20: frame(legacy, 0.25)
    check(legacy.store.writes.size() == 1 and legacy.store.writes[-1] == legacy.app.sim.export_release_state(), "Existing synchronous-only test adapters retain five-second saves")
    dispose(legacy)

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(390,844)
    check(Main.MAX_FOREGROUND_FRAME_SECONDS == 0.25, "Original simulation catch-up budget is unchanged")
    cadence_and_snapshot()
    synchronous_boundaries()
    phase_and_clock_bounds()
    blocked_and_warning_paths()
    deterministic_parity_and_completion()
    print(JSON.stringify({"suite":"dispatch_autosave_clock","checks":checks,"failures":failures,"scope":"Real main/scene; deterministic foreground clock; real codec with memory writes; no wall-clock durability claim"}))
    quit(0 if failures.is_empty() else 1)
