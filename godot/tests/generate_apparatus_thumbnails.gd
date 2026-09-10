extends SceneTree
const Model = preload("res://scripts/apparatus_model.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var viewport := SubViewport.new()
    viewport.size=Vector2i(256,192)
    viewport.own_world_3d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var camera := Camera3D.new()
    viewport.add_child(camera)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=0.26
    camera.position=Vector3(0.14,0.22,0.60)
    camera.look_at(Vector3(0,0.09,0))
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode=Environment.BG_COLOR;e.background_color=Color("343d46")
    e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("d6e4ed");e.ambient_light_energy=0.8
    env.environment=e
    viewport.add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.8
    viewport.add_child(light)
    var directory := "res://assets/apparatus"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    var seen := {}
    var only: PackedStringArray=[]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--models="):only=argument.trim_prefix("--models=").split(",")
    var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/apparatus.json")).items
    for d in catalog:
        if not only.is_empty() and d.model not in only:continue
        if seen.has(d.model):continue
        seen[d.model]=true
        var model := Model.new()
        viewport.add_child(model)
        model.build(d)
        model.caption.hide()
        camera.size=0.40 if d.model in ["stand","generator","condenserstand"] else 0.29
        await process_frame
        RenderingServer.force_draw(false)
        RenderingServer.force_sync()
        var img := viewport.get_texture().get_image()
        assert(img.save_png(ProjectSettings.globalize_path(directory+"/"+d.model+".png"))==OK)
        viewport.remove_child(model);model.queue_free()
        await process_frame
    print("PASS: ",seen.size()," original 3D apparatus thumbnails")
    viewport.queue_free()
    await process_frame
    quit(0)
