extends SceneTree
var core: LabCore
var latest := {}
func _initialize() -> void:
    call_deferred("run")
func idle() -> void:
    var deadline := Time.get_ticks_msec()+30000
    while core.is_busy():
        assert(Time.get_ticks_msec()<deadline,"Solver timeout")
        var result := core.poll()
        if result.get("ready",false):
            latest = result
        await process_frame
func run() -> void:
    core = LabCore.new()
    core.initialize("res://data/phreeqc.dat")
    await idle()
    assert(latest.error.is_empty())
    core.pour(1,3,25)
    await idle()
    core.pour(2,3,25)
    await idle()
    core.run_batch({"barite":true,"volume_ml":50,"concentration":0.001,"sulfate_ml":50,"sulfate_concentration":0.001})
    await idle()
    core.extract_batch(5)
    await idle()
    assert(latest.error.is_empty())
    core.configure_bench("heat",{})
    core.start_bench()
    core.advance_bench(12.5)
    core.pause_bench()
    core.configure_fall(1.5,2)
    core.start_fall()
    core.advance_fall(5)
    var before := core.snapshot()
    var batch := core.batch_snapshot()
    var document := core.save_session()
    assert(document.commands.size()==4 and document.events.size()==4)
    var encoded := JSON.stringify(document,"",true,true)
    var decoded: Dictionary = JSON.parse_string(encoded)
    core.reset_lab()
    await idle()
    assert(core.snapshot().vessels.size()==4)
    assert(core.load_session(decoded).is_empty())
    await idle()
    assert(latest.error.is_empty(),latest.error)
    var after := core.snapshot()
    assert(after.vessels.size()==5)
    for i in before.vessels.size():
        assert(abs(before.vessels[i].volume_ml-after.vessels[i].volume_ml)<1e-7)
        if before.vessels[i].ph!=null:
            assert(abs(before.vessels[i].ph-after.vessels[i].ph)<1e-6)
        for element in before.vessels[i].elements_mol:
            assert(abs(before.vessels[i].elements_mol[element]-after.vessels[i].elements_mol[element])<1e-10)
    assert(abs(core.batch_snapshot().solid_remaining_mmol-batch.solid_remaining_mmol)<1e-8)
    assert(core.fall_snapshot().landed and not core.fall_snapshot().running)
    assert(abs(core.bench_snapshot().time_s-12.5)<1e-10)
    var incompatible := decoded.duplicate(true)
    incompatible.database_sha256 = "bad"
    assert("版本" in core.load_session(incompatible))
    var bad := decoded.duplicate(true)
    bad.commands.append({"operation":"pour","parameters":{"from":55,"to":3,"amount_ml":10}})
    assert(core.load_session(bad).is_empty())
    await idle()
    assert(not latest.error.is_empty())
    assert(core.snapshot().revision==after.revision)
    assert(core.snapshot().vessels.size()==5)
    assert(core.save_session().commands.size()==4)
    print("PASS: JSON session replay restores solution/solid inventories, operation events and paused physics; incompatible and failed replay preserve valid state")
    core = null
    quit(0)
