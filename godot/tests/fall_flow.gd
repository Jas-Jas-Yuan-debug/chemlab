extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func press(name: String) -> void:
    var button := root.find_child(name,true,false)
    assert(button is Button,"Missing button: "+name)
    button.pressed.emit()
    await process_frame

func run() -> void:
    var lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    while lab.core.is_busy():
        await process_frame
    await press("FreeFallTab")
    assert(lab.physics_mode)
    var fall = lab.fall_experiment
    fall.height_input.value = 1.5
    fall.gravity_input.value = 2.0
    await press("ConfigureFall")
    assert(abs(lab.core.fall_snapshot().height_m-1.5)<1e-12)
    await press("ReleaseBall")
    for i in range(10):
        await physics_frame
    await press("PauseFall")
    var frozen: float = lab.core.fall_snapshot().time_s
    for i in range(10):
        await physics_frame
    assert(lab.core.fall_snapshot().time_s==frozen)
    await press("PauseFall")
    var deadline := Time.get_ticks_msec()+10000
    while not lab.core.fall_snapshot().landed:
        assert(Time.get_ticks_msec()<deadline,"Landing timeout")
        await physics_frame
    var r: Dictionary = lab.core.fall_snapshot()
    assert(abs(r.time_s-sqrt(1.5))<1e-12)
    assert(abs(r.impact_speed_m_s-sqrt(6.0))<1e-12)
    assert(r.velocity_m_s==0)
    await process_frame
    # Godot transforms use float32; the scientific state above is checked in float64.
    assert(abs(fall.ball.position.y-0.908)<1e-6)
    assert(fall.height_plot.points.size()>2)
    await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/free-fall.png"))==OK)
    await press("RepeatFall")
    assert(lab.core.fall_snapshot().height_m>1.4)
    await press("ChemistryTab")
    assert(not lab.physics_mode)
    assert(lab.states.size()==4)
    print("PASS: rendered free-fall flow, configure/release/pause/resume/impact/repeat, curves, chemistry preservation")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
