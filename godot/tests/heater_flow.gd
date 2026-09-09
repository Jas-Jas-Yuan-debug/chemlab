extends SceneTree
var lab: Node3D
func _initialize() -> void:
    call_deferred("run")
func idle() -> void:
    while lab.core.is_busy():
        await process_frame
    await process_frame
func click(name: String) -> void:
    var button := root.find_child(name,true,false)
    assert(button is Button,"Missing heater control "+name)
    button.pressed.emit()
    await process_frame
func run() -> void:
    lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    await idle()
    await click("PhysicsBenchTab")
    var e = lab.bench_experiment
    e.picker.item_selected.emit(5)
    assert(e.heater_controls.visible)
    e.fields.target_c.value = 45
    e.fields.power_w.value = 1000
    e.fields.stir_rpm.value = 120
    await click("ApplyHeaterControl")
    await click("ToggleHeater")
    await click("ToggleStirrer")
    await create_timer(0.25).timeout
    var r: Dictionary = lab.core.bench_snapshot()
    assert(r.temperature_c>20 and r.power_w==1000)
    assert(r.stir_rpm==120 and r.stir_turns>0)
    assert(abs(e.heater_view.rotor.rotation.y-fmod(r.stir_turns,1)*TAU)<1e-5)
    lab.core.advance_bench(30)
    await process_frame
    r = lab.core.bench_snapshot()
    assert(abs(r.temperature_c-45)<1e-8 and r.power_w==15)
    var original_time: float = r.time_s
    var energy: float = r.input_energy_j
    e.fields.target_c.value = 30
    await click("ApplyHeaterControl")
    r = lab.core.bench_snapshot()
    assert(r.target_c==30 and r.time_s>=original_time and r.input_energy_j>=energy)
    assert(r.temperature_c>44.9 and r.power_w==0)
    await click("ToggleStirrer")
    var turns: float = lab.core.bench_snapshot().stir_turns
    await create_timer(0.1).timeout
    assert(lab.core.bench_snapshot().stir_turns==turns)
    # All six real UI choices retain the current thermal inventory.
    for source in range(6):
        e.heat_source.selected = source
        e.fields.target_c.value = 60
        await click("ApplyHeaterControl")
        await create_timer(0.12).timeout
        r = lab.core.bench_snapshot()
        assert(r.source==source and e.heater_view.source_id==source)
        assert(r.temperature_c<60 and abs(r.energy_residual_j)<1e-7)
        if source>0:
            assert(e.heater_view.flame.visible)
        RenderingServer.force_draw(false)
        RenderingServer.force_sync()
        assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/heater-%d.png"%source))==OK)
    await click("ToggleHeater")
    assert(lab.core.bench_snapshot().power_w==0)
    assert(not e.heater_view.flame.visible)
    await click("PauseBench")
    r = lab.core.bench_snapshot()
    await create_timer(0.1).timeout
    assert(lab.core.bench_snapshot().time_s==r.time_s)
    assert(lab.save_to_path("user://heater-flow.json"))
    assert(lab.export_to_path("user://heater-before.csv"))
    var before: String = FileAccess.get_file_as_string("user://heater-before.csv")
    assert("input_energy_j" in before and "stir_rpm" in before)
    e.select_model(0)
    assert(lab.load_from_path("user://heater-flow.json"))
    await idle()
    var restored: Dictionary = lab.core.bench_snapshot()
    assert(restored.kind=="heater" and restored.running==0)
    assert(abs(restored.temperature_c-r.temperature_c)<1e-8)
    assert(abs(restored.input_energy_j-r.input_energy_j)<1e-7)
    assert(e.fields.target_c.value==60 and e.heat_source.selected==5)
    assert(lab.export_to_path("user://heater-after.csv"))
    assert(before==FileAccess.get_file_as_string("user://heater-after.csv"),"Heater control history CSV round trip")
    var invalid: Dictionary = lab.core.save_session()
    invalid.bench.heater_controls[-1].target_c = 200
    assert(not lab.core.load_session(invalid).is_empty())
    assert(lab.core.bench_snapshot().temperature_c==restored.temperature_c)
    assert(not lab.core.control_heater({"target_c":100}).is_empty())
    await click("ToggleStirrer")
    await create_timer(0.1).timeout
    assert(lab.core.bench_snapshot().stir_turns>r.stir_turns)
    lab.switch_experiment(false)
    await physics_frame
    await physics_frame
    var query := PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,0,0))
    var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
    assert(hit.is_empty() or not hit.collider.has_meta("vessel_id") or hit.collider.get_meta("vessel_id")!=0,"Fixed experiment vessels must not intercept chemistry selection")
    print("PASS: six rendered heat sources, live target/power/RPM controls, independent switches, thermostat/energy/cooling, rotor motion, paused save/load and identical CSV, invalid control preservation")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
