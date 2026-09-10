extends SceneTree
var lab: Node3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:push_error(message);quit(1)
    assert(ok,message)
func idle() -> void:
    while lab.core.is_busy():await process_frame
    await process_frame
func capture(name: String) -> void:
    await process_frame;await process_frame
    RenderingServer.force_draw(false);RenderingServer.force_sync()
    check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+name+".png"))==OK,"Screenshot output")
func run() -> void:
    lab=load("res://scenes/laboratory.tscn").instantiate();root.add_child(lab)
    await idle()
    check(lab.states.size()==4,"Initial science state")
    lab.paused=true
    var beaker=lab.views[1];var bottle=lab.views[4]
    check(beaker.form=="beaker" and bottle.form=="bottle" and bottle.stopper!=null,"Distinct bottle geometry and stopper")
    check(bottle.mouth_radius<bottle.radius*0.45 and beaker.pour_lip().x>beaker.radius,"Narrow neck and beaker spout")
    # Independent radial slicing quadrature checks the mL-to-height conversion.
    for v in [beaker,bottle]:
        for ml in [10.0,100.0,240.0]:
            v.update_state({"volume_ml":ml,"ph":7})
            var sum:=0.0
            var dy: float=(v.liquid_height-v.cavity[0].y)/1000
            for i in range(1000):
                var y: float=v.cavity[0].y+(i+0.5)*dy
                for j in range(v.cavity.size()-1):
                    var a: Vector2=v.cavity[j];var b: Vector2=v.cavity[j+1]
                    if y>=a.y and y<=b.y:
                        var r: float=a.x+(b.x-a.x)*(y-a.y)/(b.y-a.y)
                        sum+=PI*r*r*dy
                        break
            check(abs(sum*1e6-ml)<0.05,"Shaped vessel volume/height disagrees with independent quadrature")
        v.update_state(lab.states[v.vessel_id])
    await create_timer(0.4).timeout
    await capture("glassware-corrected")
    lab.choose_reagent(5);lab.concentration.value=1;lab.volume.value=50;lab.select_vessel(4);lab.prepare_selected();await idle()
    check(lab.states[4].activity_model=="Pitzer" and lab.states[4].ph>13.8,"1 M KOH from actual UI")
    lab.core.advance_kinetics(0.1,5)
    check(lab.save_to_path("user://reaction-dynamics-flow.json"),"Save Pitzer + kinetics")
    check(lab.load_from_path("user://reaction-dynamics-flow.json"),"Load accepted")
    await idle()
    check(lab.status.text.begins_with("实验已恢复"),"Dynamic session restored: "+lab.status.text)
    check(lab.states[4].activity_model=="Pitzer","Pitzer model restored")
    lab.select_vessel(1);lab.target_id=3;lab.request_pour(25);await idle()
    lab.select_vessel(2);lab.request_pour(25);await idle()
    check(lab.curve_sources[3]==2 and abs(lab.total_added[3]-25)<1e-7,"Source change starts new titration series")
    check(lab.curves[3].size()==2 and lab.curves[3][0].x==0,"New titration has initial equilibrium point")
    var start: Dictionary=lab.core.kinetics_snapshot()[3]
    for i in range(200):
        lab.elapsed+=0.05
        var r: Dictionary=lab.core.advance_kinetics(0.05,20)[3]
        if not lab.kinetic_history.has(3):lab.kinetic_history[3]=[]
        lab.kinetic_history[3].append({"time_s":lab.elapsed,"ph":r.ph,"upper_ph":r.upper_ph,"rate_mol_s":r.rate_mol_s})
    lab.kinetic_readings=lab.core.kinetics_snapshot()
    var end: Dictionary=lab.kinetic_readings[3]
    check(abs(start.ph-end.ph)>0.5 and abs(end.ph-lab.states[3].ph)<0.1,"pH evolves through finite mixing rather than instant equilibrium")
    check(abs(end.equivalent_error_mol)<1e-10,"Reaction equivalent conservation")
    lab.select_vessel(3);lab.plot_mode.selected=0;lab.update_readout()
    check(lab.plot.x_unit=="s" and lab.plot.points.size()>=200,"Time graph shows sampled kinetics")
    await capture("reaction-ph-time")
    lab.plot_mode.selected=1;lab.update_readout();await capture("reaction-rate-time")
    check(lab.save_to_path("user://reaction-history.json"),"Save reaction history")
    check(lab.export_to_path("user://reaction-before.csv"),"Export sampled rates")
    check(lab.load_from_path("user://reaction-history.json"),"Reload sampled history");await idle()
    check(lab.status.text.begins_with("实验已恢复"),"History load completed")
    check(lab.kinetic_history[3].size()>=200 and lab.curve_sources[3]==2,"History and titrant restored")
    check(lab.export_to_path("user://reaction-after.csv"),"Export restored history")
    check(FileAccess.get_file_as_string("user://reaction-before.csv")==FileAccess.get_file_as_string("user://reaction-after.csv"),"Rate CSV roundtrip")
    lab.switch_beginner();lab.beginner.choose("reagent5");lab.beginner.solution_concentration.value=0.1
    lab.beginner.select_object("v4");lab.beginner.dose.value=50;lab.beginner.prepare_liquid();await idle()
    check(lab.states[4].activity_model=="Pitzer" and abs(lab.states[4].elements_mol.K-0.005)<1e-10,"Beginner concentration is adjustable")
    await capture("beginner-glassware-corrected")
    print("PASS: differentiated 3D glassware, independently integrated liquid volume, 1 M KOH, finite-rate time plots, source-isolated titration, dynamic save/CSV and beginner concentration")
    lab.queue_free();await process_frame;await process_frame;quit(0)
