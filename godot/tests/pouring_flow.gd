extends SceneTree
const Indicators = preload("res://scripts/indicators.gd")
var lab: Node3D
func _initialize() -> void:
    call_deferred("run")
func idle() -> void:
    while lab.core.is_busy():
        await process_frame
    await process_frame
func rendered_volume(v: Node3D) -> float:
    var arrays: Array = v.liquid.mesh.surface_get_arrays(0)
    var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var total := 0.0
    for i in range(0,points.size(),3):
        if normals[i].y<0.5:
            continue
        var a := points[i]
        var b := points[i+1]
        var c := points[i+2]
        var area := absf((b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x))/2
        var sum := 0.0
        for p in [a,b,c]:
            sum += clampf(v.plane_center+v.liquid_slope.dot(Vector2(p.x,p.z)),0,v.height-0.006)
        total += area*sum/3
    return total*1000000
func run() -> void:
    lab = load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    await idle()
    var v = lab.views[1]
    # Independent triangle integration of the actual shader-deformed cap.
    for amount in [5.0,50.0,200.0]:
        v.update_state({"volume_ml":amount,"ph":7})
        for angle in [0.0,0.5,1.0,1.4]:
            v.update_liquid_plane(Vector2(tan(angle),0),true)
            assert(abs(rendered_volume(v)-amount)<maxf(0.5,amount*0.025),"Visual fill disagrees with canonical volume")
    v.update_state(lab.states[1])
    var clear: Color = Indicators.color_for(0,7)
    assert(Indicators.color_for(1,8.3).is_equal_approx(clear))
    assert(Indicators.color_for(1,9.8).r>0.9)
    assert(Indicators.color_for(1,12).is_equal_approx(clear))
    assert(Indicators.color_for(2,3.1).r>0.9 and Indicators.color_for(2,4.4).g>0.7)
    assert(Indicators.color_for(3,6.0).r>0.9 and Indicators.color_for(3,7.6).b>0.8)
    assert(Indicators.color_for(3,6.8).g>0.6)
    lab.select_vessel(1)
    lab.target_id = 3
    lab.rate.value = 20
    lab.pour_button.button_down.emit()
    var deadline := Time.get_ticks_msec()+12000
    var photographed := false
    while lab.pouring:
        assert(Time.get_ticks_msec()<deadline,"Continuous pour failed to stop at empty")
        if lab.stream.visible and not photographed and lab.states[3].volume_ml>15:
            var normal: Vector3 = v.visual.basis*Vector3(-v.liquid_slope.x,1,-v.liquid_slope.y).normalized()
            assert(normal.dot(Vector3.UP)>0.99,"Free surface not horizontal")
            RenderingServer.force_draw(false)
            RenderingServer.force_sync()
            root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/continuous-pour.png"))
            photographed = true
        await process_frame
    await idle()
    assert(photographed)
    assert(lab.states[1].volume_ml==0)
    assert(abs(lab.states[3].volume_ml-50)<0.00001)
    assert(abs(lab.states[3].elements_mol.Cl-0.00005)<1e-10)
    # Release stops new requests, retaining a previously accepted in-flight aliquot.
    lab.select_vessel(2)
    lab.pour_button.button_down.emit()
    for i in range(90):
        await process_frame
    lab.pour_button.button_up.emit()
    await idle()
    var stopped: float = lab.states[2].volume_ml
    for i in range(20):
        await process_frame
    assert(lab.states[2].volume_ml==stopped and not lab.stream.visible)
    print("PASS: actual held-button transfer, horizontal bounded liquid mesh, verified rendered-volume approximation, empty stop, release stop, chloride conservation and indicator boundaries")
    lab.queue_free()
    await process_frame
    await process_frame
    quit(0)
