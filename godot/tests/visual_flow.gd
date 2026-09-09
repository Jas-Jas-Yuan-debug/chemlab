extends SceneTree

var lab: Node3D

func _initialize() -> void:
    call_deferred("run")

func wait_idle() -> void:
    var deadline := Time.get_ticks_msec()+30000
    while lab.core.is_busy():
        assert(Time.get_ticks_msec()<deadline,"Solver timeout")
        await process_frame
    await process_frame

func click(name: String) -> void:
    var node := root.find_child(name,true,false)
    assert(node is Button,"Missing UI button: "+name)
    node.pressed.emit()
    await wait_idle()

func run() -> void:
    lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    await wait_idle()
    assert(lab.states.size()==4)
    lab.select_vessel(1)
    lab.target_id = 3
    lab.amount.value = 50
    await click("TransferAliquot")
    assert(lab.states[1].volume_ml<0.000001)
    lab.select_vessel(2)
    await click("TransferAliquot")
    assert(abs(lab.states[3].ph-7)<0.03)
    lab.select_vessel(3)
    lab.search.text = "HCl"
    lab.refresh_reagents()
    assert(lab.reagent_list.get_child_count()==1)
    assert(lab.reagent_list.get_child(0).name=="Reagent2")
    lab.search.text = ""
    lab.refresh_reagents()
    for i in range(30):
        await process_frame
    await RenderingServer.frame_post_draw
    var output := ProjectSettings.globalize_path("res://../artifacts/laboratory-neutralization.png")
    assert(root.get_texture().get_image().save_png(output)==OK)
    print("PASS: rendered UI prepare/reset defaults, aliquot buttons, acid/base neutralization, readout, search, screenshot")
    await click("ResetExperiment")
    assert(lab.states[3].volume_ml==0)
    for i in range(10):
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/laboratory-initial.png"))
    for reagent in range(1,10):
        lab.select_vessel(1)
        lab.chosen_reagent = reagent
        lab.volume.value = 25
        lab.concentration.value = 0.001
        await click("PrepareSolution")
        assert(abs(lab.states[1].volume_ml-25)<0.00001)
        lab.target_id = 3
        lab.amount.value = 5
        await click("TransferAliquot")
        assert(abs(lab.states[3].volume_ml-5)<0.00001)
        assert(abs(lab.states[3].ph-lab.states[1].ph)<0.00001)
        await click("ResetExperiment")
    print("PASS: all 9 aqueous reagent forms prepared, transferred and measured through UI handlers")
    quit(0)
