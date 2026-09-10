extends SceneTree
var lab: Node3D
func _initialize() -> void:call_deferred("run")
func idle() -> void:
    while lab.core.is_busy():await process_frame
    await process_frame
func run() -> void:
    lab=load("res://scenes/laboratory.tscn").instantiate();root.add_child(lab)
    await idle()
    lab.paused=true;lab.set_process(false)
    var saved: Dictionary=lab.core.save_session()
    saved.pitzer_sha256="different-database"
    assert(not lab.core.load_session(saved).is_empty(),"Reject changed Pitzer identity before changing state")
    assert(lab.core.snapshot().model_version==lab.core.save_session().model_version,"Snapshot and saved model identities match")
    lab.kinetic_history.clear();lab.kinetics_clock=0
    lab.elapsed+=100
    lab.paused=false;lab.refresh_kinetics(0.05)
    var point: Dictionary=lab.kinetic_history[1][-1]
    assert(abs(point.time_s-lab.core.kinetics_snapshot()[1].time_s)<1e-9,"Rate graph uses integrated chemistry time")
    assert(point.time_s<lab.elapsed-90,"Wall-clock wait is absent from reaction time")
    var before_empty: Array=lab.core.save_session().kinetics[1].duplicate()
    lab.core.pour(3,1,5)
    while lab.core.is_busy():
        var result: Dictionary=lab.core.poll()
        if result.get("ready",false):lab.apply_result(result)
        await process_frame
    assert(lab.core.save_session().kinetics[1]==before_empty,"Empty pour must preserve existing reaction progress")
    var count: int=lab.kinetic_history[1].size()
    var time: float=point.time_s
    lab.core.prepare(4,5,0.1,50,250)
    lab.refresh_kinetics(0.1)
    assert(lab.kinetic_history[1].size()==count and lab.core.kinetics_snapshot()[1].time_s==time,"Busy solver adds no fictitious reaction samples")
    while lab.core.is_busy():
        var result: Dictionary=lab.core.poll()
        if result.get("ready",false):lab.apply_result(result)
        await process_frame
    lab.paused=true;lab.set_process(true)
    lab.switch_beginner();lab.beginner.choose("reagent5");lab.beginner.solution_concentration.value=0.1
    lab.beginner.select_object("v4");lab.beginner.dose.value=50;lab.beginner.prepare_liquid();await idle()
    assert(abs(lab.kinetic_readings[4].ph-lab.states[4].ph)<1e-7,"Repreparation refreshes probe")
    assert("12.90" in lab.beginner.reading.text and "Pitzer" in lab.beginner.reading.text,"Completed beginner preparation displays new concentration state immediately")
    await process_frame;await process_frame
    RenderingServer.force_draw(false);RenderingServer.force_sync()
    assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/beginner-glassware-corrected.png"))==OK)
    print("PASS: integrated reaction clock, no samples while busy, Pitzer save identity, and immediate paused beginner reprepare readout")
    lab.queue_free();await process_frame;await process_frame;quit(0)
