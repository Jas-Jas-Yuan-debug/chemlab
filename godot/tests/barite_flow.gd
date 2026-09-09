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
    assert(b is Button)
    b.pressed.emit()
    await idle()
func run() -> void:
    lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    await idle()
    await click("PrecipitationTab")
    var experiment = lab.batch_experiment
    assert(experiment.precip_controls.visible)
    assert(not experiment.regular_controls.visible)
    await click("RunBatch")
    var r: Dictionary = lab.core.batch_snapshot()
    assert(r.mineral=="Barite")
    assert(r.solid_remaining_mmol>0.045 and r.solid_remaining_mmol<0.05)
    assert(experiment.solid.visible)
    for i in range(20):
        await process_frame
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/barite-precipitation.png"))
    await click("ExtractBatch")
    assert(lab.states.has(5))
    assert(abs(lab.states[5].elements_mol.Ba-r.elements_mol.Ba)<1e-12)
    await click("ChemistryTab")
    lab.select_vessel(5)
    lab.target_id = 3
    lab.amount.value = 5
    await click("TransferAliquot")
    assert(abs(lab.states[3].ph-r.ph)<1e-6)
    await click("PrecipitationTab")
    experiment.ba_concentration.value = 0.00001
    experiment.sulfate_concentration.value = 0.00001
    await click("RunBatch")
    var dilute: Dictionary = lab.core.batch_snapshot()
    assert(dilute.solid_remaining_mmol<1e-9)
    assert(not experiment.solid.visible)
    experiment.ba_concentration.value = 0.001
    experiment.sulfate_concentration.value = 0.001
    experiment.sulfate_volume.value = 100
    await click("RunBatch")
    var excess: Dictionary = lab.core.batch_snapshot()
    assert(excess.elements_mol.S>excess.elements_mol.Ba)
    assert(excess.solid_remaining_mmol>0.049)
    print("PASS: rendered Barite precipitation/undersaturation/excess, phase amount, liquid extraction and aliquot transfer")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
