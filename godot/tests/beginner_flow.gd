extends SceneTree
var lab: Node3D
func _initialize() -> void:call_deferred("run")
func idle() -> void:
    while lab.core.is_busy():await process_frame
    await process_frame
func click(name: String) -> void:
    var b:=root.find_child(name,true,false)
    assert(b is Button,"Missing "+name)
    b.pressed.emit()
    await process_frame
func capture(name: String) -> void:
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+name+".png"))==OK)
func run() -> void:
    lab=load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    await idle()
    await click("BeginnerMode")
    var mode=lab.beginner
    assert(mode.active and not lab.main_ui.visible)
    assert(mode.catalog.size()==346,"173 apparatus + 143 solid packages + 30 original reagents")
    await create_timer(0.5).timeout
    capture("beginner-initial")
    mode.select_object("v1")
    mode.chosen_target="v2"
    mode.dose.value=25
    await click("BeginnerUse")
    await idle()
    assert(abs(lab.states[1].volume_ml-25)<0.001)
    assert(lab.states[2].ph>7)
    mode.select_object("v2")
    await click("BeginnerIndicator")
    assert(lab.indicator_by_vessel[2]==1)
    mode.search.text="圆底烧瓶"
    mode.search.text_changed.emit(mode.search.text)
    assert(mode.cards.get_child_count()==1)
    mode.cards.get_child(0).pressed.emit()
    await idle()
    mode.sync_vessels()
    assert(lab.views[5].kind=="圆底烧瓶")
    assert(mode.objects.v5.model.fill_profile.size()>10)
    mode.choose("solid001")
    var solid_id: String=mode.selected
    mode.chosen_target="v5"
    mode.dose.value=2
    await click("BeginnerUse")
    assert(mode.objects[solid_id].state.mass_g==8)
    assert(mode.objects.v5.state.contents.solid001==2)
    mode.search.text="九十度"
    mode.search.text_changed.emit(mode.search.text)
    assert(mode.cards.get_child_count()==3)
    mode.cards.get_child(0).pressed.emit()
    await process_frame
    var tube_id: String=mode.selected
    mode.chosen_target="v5"
    await click("BeginnerConnect")
    assert(mode.links.size()==1)
    capture("beginner-apparatus")
    assert(lab.save_to_path("user://beginner-flow.json"))
    lab.switch_experiment(false)
    var loaded: bool=lab.load_from_path("user://beginner-flow.json")
    print("LOAD: ",loaded," ",lab.status.text)
    if not loaded:quit(1);return
    await idle()
    assert(mode.active and mode.objects.v5.state.contents.solid001==2 and mode.links.size()==1)
    mode.select_guide(2)
    mode.temperature.value=45;mode.rpm.value=120
    await click("BeginnerHeat")
    await click("BeginnerStir")
    await create_timer(0.3).timeout
    var r: Dictionary=lab.core.bench_snapshot()
    assert(r.fuel_consumed_mol>0 and r.chemical_energy_j>0 and r.stir_turns>0)
    mode.toggle_flame(true)
    await create_timer(1.0).timeout
    var f: Dictionary=lab.core.flame_snapshot()
    assert(f.enabled and f.time_s>0 and f.peak_temperature_k>298.15)
    capture("beginner-combustion")
    lab.core.pause_bench()
    assert(lab.save_to_path("user://beginner-flame.json"))
    var time: float=f.time_s
    assert(lab.load_from_path("user://beginner-flame.json"))
    await idle()
    assert(lab.core.flame_snapshot().time_s>=time)
    mode.toggle_flame(false)
    assert(not lab.core.flame_snapshot().enabled)
    await click("AdvancedMode")
    assert(not mode.active and lab.main_ui.visible)
    lab.switch_bench()
    lab.bench_experiment.select_model(0)
    assert(lab.save_to_path("user://beginner-after-professional.json"))
    assert(lab.load_from_path("user://beginner-after-professional.json"))
    await idle()
    assert(not mode.heater_mode and lab.core.bench_snapshot().kind=="spring")
    print("PASS: beginner catalog/search, native transfer, indicator, real flask geometry, dry mass conservation, interface connection, save/load, combustion + switchable field, return to advanced")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
