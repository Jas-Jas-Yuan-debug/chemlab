extends SceneTree
var lab: Node3D
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
    assert(b is Button,"Missing button "+name)
    b.pressed.emit()
    await idle()
func run() -> void:
    lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    await idle()
    await click("Reagent18")
    var experiment = lab.batch_experiment
    assert(experiment.active and not lab.fall_experiment.active)
    await click("RunBatch")
    var closed: Dictionary = lab.core.batch_snapshot()
    assert(closed.solid_remaining_mmol>1.9)
    experiment.boundary_picker.selected = 2
    await click("RunBatch")
    var opened: Dictionary = lab.core.batch_snapshot()
    assert(opened.ph<closed.ph)
    assert(opened.co2_to_environment_mmol<0)
    experiment.solid_picker.selected = 1
    experiment.boundary_picker.selected = 0
    await click("RunBatch")
    var gypsum: Dictionary = lab.core.batch_snapshot()
    assert(gypsum.solid_remaining_mmol>0.4 and gypsum.solid_remaining_mmol<0.6)
    assert(experiment.solid.visible)
    assert(experiment.samples.size()==3)
    for i in range(30):
        await process_frame
    await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/solid-equilibrium.png"))==OK)
    await click("ExtractBatch")
    assert(lab.states.has(5))
    assert(abs(lab.states[5].volume_ml-gypsum.volume_ml)<1e-9)
    assert(lab.core.batch_snapshot().volume_ml==0)
    await click("ChemistryTab")
    lab.select_vessel(5)
    lab.target_id = 3
    lab.amount.value = 5
    await click("TransferAliquot")
    assert(abs(lab.states[3].ph-gypsum.ph)<0.000001)
    assert(abs(lab.states[3].volume_ml-5)<0.000001)
    await click("BatchTab")
    experiment.solid_picker.selected = 2
    experiment.boundary_picker.selected = 1
    experiment.gas_amount.value = 0.1
    await click("RunBatch")
    var co2: Dictionary = lab.core.batch_snapshot()
    assert(co2.gas_co2_mmol>0 and co2.gas_co2_mmol<0.1)
    assert(abs(co2.gas_pressure_atm*0.1-co2.gas_co2_mmol/1000*0.082057366*298.15)<0.0000002)
    for i in range(20):
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/co2-equilibrium.png"))
    await click("ResetExperiment")
    assert(lab.core.batch_snapshot().is_empty())
    print("PASS: rendered calcite closed/open, gypsum finite solid, CO2 headspace, liquid separation and aliquot transfer, readout/curve/reset flows")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
