extends SceneTree
var lab: Node3D
func _initialize() -> void:
    call_deferred("run")
func click(name: String) -> void:
    var b := root.find_child(name,true,false)
    assert(b is Button,"Missing button "+name)
    b.pressed.emit()
    await process_frame
func capture(name: String) -> void:
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/physics-"+name+".png"))==OK)
func run() -> void:
    lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    while lab.core.is_busy():
        await process_frame
    await click("PhysicsBenchTab")
    var experiment = lab.bench_experiment
    assert(experiment.active)
    for index in range(5):
        experiment.picker.selected = index
        experiment.picker.item_selected.emit(index)
        await process_frame
        assert(lab.core.bench_snapshot().kind==experiment.KINDS[index])
        await click("StartBench")
        await create_timer(0.35).timeout
        var r: Dictionary = lab.core.bench_snapshot()
        assert(r.time_s>0)
        if index==0:
            assert(abs(experiment.moving.position.x-r.position_m)<0.000001)
            assert(abs(r.energy_j-0.04)<1e-10)
        elif index==1:
            assert(abs(experiment.moving.position.distance_to(Vector3(0,2.44,0))-experiment.applied.length_m)<1e-6)
        elif index==2:
            assert(r.temperature1_c<70 and r.temperature2_c>20)
            assert(abs(r.temperature1_c+r.temperature2_c-90)<1e-8)
        elif index==3:
            assert(abs(r.current_a-0.02)<1e-10)
        else:
            assert(abs(r.image_m-1.0/3)<1e-10)
        await click("PauseBench")
        var paused: Dictionary = lab.core.bench_snapshot()
        await create_timer(0.10).timeout
        assert(lab.core.bench_snapshot().time_s==paused.time_s)
        await capture(experiment.KINDS[index])
        if index<4:
            assert(experiment.samples.size()>2)
        await click("RepeatBench")
        assert(lab.core.bench_snapshot().time_s<0.10)
        await click("PauseBench")
    experiment.fields.focal_m.value = -0.2
    await click("ConfigureBench")
    assert(lab.core.bench_snapshot().virtual>0)
    experiment.fields.focal_m.value = 0.2
    experiment.fields.object_m.value = 0.2
    await click("ConfigureBench")
    assert(lab.core.bench_snapshot().at_infinity>0)
    assert("无穷远" in experiment.measurements.text)
    experiment.fields.focal_m.value = 0
    await click("ConfigureBench")
    assert("焦距" in experiment.status.text,experiment.status.text)
    assert(abs(lab.core.bench_snapshot().parameters.focal_m-0.2)<1e-10)
    experiment.picker.item_selected.emit(3)
    experiment.topology.selected = 1
    await click("ConfigureBench")
    await click("StartBench")
    assert(abs(lab.core.bench_snapshot().current_a-0.09)<1e-10)
    await click("ChemistryTab")
    assert(not experiment.active)
    assert(lab.states.size()==4)
    print("PASS: all five rendered physics controls, native readings, body transforms, curves, pause/repeat, parallel circuit, real/virtual/infinite lens and invalid-parameter preservation")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
