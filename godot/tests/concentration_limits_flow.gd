extends SceneTree
var lab: Node3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:push_error(message);quit(1)
    assert(ok,message)
func idle() -> void:
    var deadline:=Time.get_ticks_msec()+15000
    while lab.core.is_busy() and Time.get_ticks_msec()<deadline:await process_frame
    check(not lab.core.is_busy(),"Science worker timeout")
    await process_frame
func prepare(id: int,reagent: int,c: float,ml: float) -> void:
    lab.select_vessel(id);lab.choose_reagent(reagent)
    lab.concentration.value=c;lab.volume.value=ml;lab.prepare_selected();await idle()
    check(lab.status.text.begins_with("已配制"),"Preparation failed: "+lab.status.text)
func run() -> void:
    lab=load("res://scenes/laboratory.tscn").instantiate();root.add_child(lab);await idle()
    lab.paused=true
    check(lab.concentration.max_value>13,"Initial professional control still capped at 1 M")
    for id in [2,3,4,5,6]:
        var maximum: float=lab.catalog[id-1].preparation_limit.maximum_mol_l
        lab.choose_reagent(id);lab.beginner.choose("reagent%d"%id)
        check(lab.concentration.max_value==maximum and lab.beginner.solution_concentration.max_value==maximum,"Two UI caps disagree with per-reagent catalog")
        check("25°C" in lab.concentration_note.text and "25°C" in lab.beginner.solution_limit_note.text,"Missing temperature/physical-limit explanation")
        lab.concentration_max_button.pressed.emit()
        check(abs(lab.concentration.value-maximum)<1e-8,"Maximum preset was rounded above/below native limit")
    lab.choose_reagent(1)
    check(lab.concentration.value==0 and not lab.concentration.editable,"Water must not retain solute concentration")
    lab.choose_reagent(7)
    check(lab.concentration.max_value==0.01 and "尚未建立" in lab.concentration_note.text,"Unimplemented solubility mislabeled as physical maximum")
    await prepare(1,5,14.96,50)
    check(lab.states[1].ph==null and lab.states[1].empirical_stock,"Fake pH shown for concentrated KOH")
    check(lab.states[1].h_molar==null and not lab.core.kinetics_snapshot().has(1),"Uncalibrated species/kinetics exposed")
    check("14.96000 mol/L" in lab.readout.text and "未校准" in lab.readout.text,"Stock concentration and model boundary missing from readout")
    await prepare(3,1,0,200)
    lab.select_vessel(1);lab.target_id=3;lab.request_pour(2);await idle()
    check(lab.states[1].empirical_stock and abs(lab.states[1].volume_ml-48)<1e-7,"Stock aliquot lost volume/model")
    check(not lab.states[3].empirical_stock and lab.states[3].ph>12,"Dilution did not restore pH")
    check(lab.core.kinetics_snapshot().has(3),"Dilution did not restore finite-rate model")
    check(abs(lab.states[3].elements_mol.K-0.02992)<1e-10,"Dilution changed K inventory")
    check(lab.save_to_path("user://concentration-limits.json"),"Stock/dilute save")
    check(lab.export_to_path("user://concentration-limits-before.csv"),"Stock/dilute CSV export")
    var saved: Dictionary=lab.core.save_session()
    check(not saved.events[0].readings.has("ph"),"Stock event exported invented pH")
    check(lab.load_from_path("user://concentration-limits.json"),"Stock/dilute reload started");await idle()
    check(lab.status.text.begins_with("实验已恢复"),"Stock/dilute reload failed: "+lab.status.text)
    check(lab.states[1].empirical_stock and lab.states[1].ph==null and lab.states[3].ph>12,"Restored wrong scientific mode")
    check(not lab.core.kinetics_snapshot().has(1) and lab.core.kinetics_snapshot().has(3),"Restored false/missing kinetic state")
    check(lab.export_to_path("user://concentration-limits-after.csv"),"Restored export")
    check(FileAccess.get_file_as_string("user://concentration-limits-before.csv")==FileAccess.get_file_as_string("user://concentration-limits-after.csv"),"Stock CSV changed across save/load")
    lab.switch_beginner();lab.beginner.choose("reagent3");lab.beginner.select_object("v4")
    lab.beginner.ui.find_child("BeginnerMaximumConcentration",true,false).pressed.emit()
    lab.beginner.dose.value=50;lab.beginner.prepare_liquid();await idle()
    check(lab.states[4].empirical_stock and abs(lab.states[4].ingredients_mol[3]-1.023)<1e-9,"Beginner max NaOH preparation failed")
    check("未校准" in lab.beginner.reading.text,"Beginner stock readout misleading")
    await process_frame;await process_frame
    if DisplayServer.get_name()!="headless":
        RenderingServer.force_draw(false);RenderingServer.force_sync()
        check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/concentration-limits-ui.png"))==OK,"Concentration UI screenshot")
    print("PASS: both UI limits/presets, max stock preparation, no fictitious pH/kinetics, dilution recovery, native session and identical CSV roundtrip")
    lab.queue_free();await process_frame;await process_frame;quit(0)
