extends SceneTree
var lab: Node3D
const SESSION = "user://verification-session.json"
const CSV = "user://verification-data.csv"
func _initialize() -> void:
    call_deferred("run")
func idle() -> void:
    var deadline := Time.get_ticks_msec()+30000
    while lab.core.is_busy():
        assert(Time.get_ticks_msec()<deadline,"Solver timeout")
        await process_frame
    await process_frame
func click(name: String) -> void:
    var b := root.find_child(name,true,false)
    assert(b is Button)
    b.pressed.emit()
    await idle()
func run() -> void:
    lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    await idle()
    lab.select_vessel(1)
    lab.target_id = 3
    lab.amount.value = 25
    await click("TransferAliquot")
    lab.select_vessel(2)
    await click("TransferAliquot")
    lab.add_vessel("滴管")
    await idle()
    lab.indicator_by_vessel[3] = 3
    lab.views[3].position.x += 0.01
    lab.switch_batch(true)
    await click("RunBatch")
    await click("ExtractBatch")
    lab.switch_experiment(true)
    lab.fall_experiment.height_input.value = 1.5
    lab.fall_experiment.gravity_input.value = 2
    lab.fall_experiment.configure()
    lab.fall_experiment.release()
    for i in range(12):
        await process_frame
    lab.core.pause_fall()
    lab.switch_bench()
    lab.bench_experiment.select_model(2)
    lab.bench_experiment.start()
    # Process frames can run much faster than rendered frames when occluded.
    # Allow actual simulation time for the 0.05 s measurement sampler.
    await create_timer(0.25).timeout
    lab.bench_experiment.pause()
    var before: Dictionary = lab.core.snapshot()
    var time_before: float = lab.core.bench_snapshot().time_s
    var samples_before: int = lab.bench_experiment.samples.size()
    assert(samples_before>1)
    await click("SaveSession")
    assert(lab.file_dialog.visible)
    lab.file_dialog.hide()
    lab.file_dialog.file_selected.emit(ProjectSettings.globalize_path(SESSION))
    assert(FileAccess.file_exists(SESSION))
    assert(lab.export_to_path(CSV))
    var original_csv := FileAccess.get_file_as_string(CSV)
    assert("solid_mmol" in original_csv and "temperature1_c" in original_csv)
    assert("free_fall" in original_csv and "heat" in original_csv)
    lab.reset_lab()
    await idle()
    assert(lab.states.size()==4)
    assert(lab.load_from_path(SESSION),lab.status.text)
    await idle()
    assert(lab.pending_session.is_empty(),lab.status.text)
    assert(lab.states.size()==6,lab.status.text)
    assert(lab.bench_mode and lab.bench_experiment.kind_index==2)
    assert(lab.paused and not lab.core.bench_snapshot().running)
    assert(abs(lab.core.bench_snapshot().time_s-time_before)<1e-10)
    assert(lab.bench_experiment.samples.size()==samples_before)
    assert(lab.indicator_by_vessel[3]==3)
    assert(abs(lab.views[3].position.x-0.07)<0.000001)
    assert(lab.views[5].kind=="滴管")
    assert(lab.curves[3].size()==2)
    for i in before.vessels.size():
        var expected: Dictionary = before.vessels[i]
        assert(abs(lab.states[int(expected.id)].volume_ml-expected.volume_ml)<1e-7)
    assert(lab.export_to_path(CSV))
    # Canonical event/curve readings and CSV column order survive a load.
    assert(FileAccess.get_file_as_string(CSV)==original_csv)
    var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SESSION))
    invalid.view.equipment[0].position = [10,0.89,0]
    var f := FileAccess.open("user://invalid-session.json",FileAccess.WRITE)
    f.store_string(JSON.stringify(invalid))
    f.close()
    assert(not lab.load_from_path("user://invalid-session.json"))
    assert(lab.states.size()==6 and lab.indicator_by_vessel[3]==3)
    lab.bench_experiment.start()
    for i in range(5):
        await process_frame
    lab.bench_experiment.pause()
    assert(lab.core.bench_snapshot().time_s>time_before)
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/session-restored.png"))
    print("PASS: session file picker wiring, atomic JSON save/load, equipment/indicator/camera/curve restoration, CSV identity, corrupt file rejection, paused physics resume")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
