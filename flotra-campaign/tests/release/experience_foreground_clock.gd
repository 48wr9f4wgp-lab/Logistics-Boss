extends SceneTree
## Real scene clock tests. A fake monotonic source models slow foreground
## frames independently of Godot's capped process delta. The final probe also
## stalls actual engine frames to exercise the default monotonic clock.
const Main = preload("res://prototype/growth_main.gd")
var checks := 0
var failures: Array[String] = []
var clock := {"now":1000000}
var app
var real_probe: Dictionary = {}

class SlowFrames extends Node:
    var app
    var samples: Array = []
    var prior_usec := 0
    var baseline_sim := 0.0
    func _process(delta: float) -> void:
        var now := Time.get_ticks_usec()
        if prior_usec > 0:
            samples.append({"delta":delta,"wall":float(now-prior_usec)/1000000.0})
        prior_usec = now
        app._process(delta)
        if samples.is_empty(): baseline_sim = app.sim.sim_time
        if samples.size() >= 4:
            set_process(false)
            return
        OS.delay_msec(200)

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func check_time(expected: float, label: String) -> void:
    check(absf(float(app.sim.sim_time)-expected) <= 0.050001, "%s (actual %.3f, expected %.3f)" % [label,app.sim.sim_time,expected])

func make_app(fake: bool = true) -> void:
    clock.now = 1000000
    app = Main.new()
    app.persistence_enabled = false
    if fake:
        app.frame_clock = func() -> int: return int(clock.now)
    root.add_child(app)
    app.set_process(false)
    app.hud.set_process(false)
    app.world.set_process(false)
    app.hud.show_play()

func dispose() -> void:
    app.free()
    app = null
    for frame in 2: await process_frame

func frame(seconds: float, reported_delta: float = 0.133333333333333) -> void:
    clock.now += roundi(seconds * 1000000.0)
    app._process(reported_delta)

func start(speed: float = 2.0) -> void:
    app._accept_contract("growth_1")
    app._set_speed(speed)

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(390,844)
    check(Main.MAX_FOREGROUND_FRAME_SECONDS == 0.25, "Foreground catch-up stays within the original quarter-second frame budget")
    for speed in [1.0,2.0,4.0]:
        make_app()
        start(speed)
        for index in 12:
            frame(0.2)
            check_time(float(index+1)*0.2*speed, "%.0fx follows 200ms foreground wall time despite capped engine delta" % speed)
            check(app.sim.check_invariants().ok, "Slow foreground frame preserves physical cargo and reservations")
        var before: float = app.sim.sim_time
        frame(0.0,0.9)
        check_time(before, "An engine delta with no monotonic elapsed time never invents progress")
        frame(0.35)
        check_time(before+0.25*speed, "A 350ms foreground stall credits at most 250ms")
        frame(0.2)
        check_time(before+0.45*speed, "Excess from a 350ms stall never becomes a catch-up backlog")
        frame(10.0)
        check_time(before+0.7*speed, "A stale ten-second foreground interval credits only the 250ms budget")
        frame(0.2)
        check_time(before+0.9*speed, "Discarded ten-second stale time never becomes a catch-up backlog")
        await dispose()

    make_app()
    frame(120.0)
    check(not app.running and app.sim.sim_time == 0.0, "Reading the initial screen does not accumulate offline work")
    start()
    frame(0.2)
    check_time(0.4, "Accepting a first job discards all pre-start time")
    for index in 8: frame(0.2)
    check(app.sim.workers.any(func(worker): return worker.phase != "idle"), "Pause fixture contains real in-flight work")
    app._pause_trial(true)
    var paused: Dictionary = app.sim.export_release_state()
    frame(60.0)
    check(app.sim.export_release_state() == paused, "Manual pause preserves every cargo clock, reservation and coordinate")
    app._pause_trial(false)
    frame(0.2)
    check_time(float(paused.sim.sim_time)+0.4, "Manual Resume counts only new foreground time")
    check(app.sim.check_invariants().ok, "Resume leaves in-flight logistics valid")
    await dispose()

    for notification in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED]:
        make_app()
        start()
        for index in 8: frame(0.2)
        app._notification(notification)
        paused = app.sim.export_release_state()
        frame(600.0)
        check(not app.running and not app.hud._trial_running, "Window/application interruption pauses visible and actual playback")
        check(app.sim.export_release_state() == paused, "Window focus loss or app suspension preserves in-flight state without offline credit")
        app._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
        app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
        frame(30.0)
        check(app.sim.export_release_state() == paused, "Returning from a minimized/backgrounded app never resumes implicitly")
        app._pause_trial(false)
        frame(0.2)
        check_time(float(paused.sim.sim_time)+0.4, "Explicit Resume discards the background interval")
        check(app.sim.check_invariants().ok, "Interrupted cargo remains physically valid")
        await dispose()

    make_app()
    start()
    for index in 8: frame(0.2)
    app._set_preference("pause_on_menus",true)
    app.hud.show_controls()
    paused = app.sim.export_release_state()
    frame(60.0)
    check(app.running and app._menu_paused, "Automatic menu pause preserves explicit running intent")
    check(app.sim.export_release_state() == paused, "Automatic menu pause preserves all simulation state")
    app.hud.close_sheet()
    frame(0.2)
    check_time(float(paused.sim.sim_time)+0.4, "Closing a menu resumes without granting reading-time progress")
    app._pause_trial(true)
    app.hud.show_controls()
    frame(30.0)
    app.hud.close_sheet()
    paused = app.sim.export_release_state()
    frame(30.0)
    check(not app.running and app.sim.export_release_state() == paused, "Closing menus never undoes manual pause")
    await dispose()

    make_app()
    start()
    for index in 8: frame(0.2)
    var saved: Dictionary = app.sim.export_release_state()
    await dispose()
    make_app()
    check(app.sim.import_release_state(saved).ok, "In-flight save is accepted by a fresh scene")
    app._apply_preferences()
    frame(600.0)
    check(not app.running and app.sim.export_release_state() == saved, "Restored active cargo stays paused with no elapsed-clock windfall")
    app._start_trial()
    frame(0.2)
    check_time(float(saved.sim.sim_time)+0.4, "Starting restored cargo uses only new foreground time")
    check(app.sim.check_invariants().ok, "Clock-independent save/resume preserves route conservation")
    await dispose()

    make_app(false)
    app._accept_contract("growth_1")
    app._set_speed(2.0)
    var driver := SlowFrames.new()
    driver.app = app
    root.add_child(driver)
    while driver.samples.size() < 4: await process_frame
    var wall := 0.0
    var credited := 0.0
    var capped := false
    for sample in driver.samples:
        wall += float(sample.wall)
        credited += minf(float(sample.wall), 0.25)
        capped = capped or float(sample.delta) < float(sample.wall)*0.75
    real_probe = {"samples":driver.samples.duplicate(true),"wall_seconds":wall,"credited_wall_seconds":credited,"simulation_seconds":app.sim.sim_time-driver.baseline_sim}
    check(capped, "Actual 200ms engine frames exhibit the independently confirmed process-delta cap")
    check_time(driver.baseline_sim+credited*2.0, "Default monotonic clock preserves 2x speed within the quarter-second foreground budget")
    check(app.sim.check_invariants().ok, "Actual stalled-frame simulation conserves cargo")
    driver.free()
    await dispose()
    print(JSON.stringify({"suite":"experience_foreground_clock","checks":checks,"failures":failures,"actual_engine_probe":real_probe}))
    quit(0 if failures.is_empty() else 1)
