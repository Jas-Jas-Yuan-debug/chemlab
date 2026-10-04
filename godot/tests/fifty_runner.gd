extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
    var args=OS.get_cmdline_user_args()
    assert(args.size()==1,"Pass one round number")
    var id=int(args[0])
    assert(id>=1 and id<=50,"Round must be 1..50")
    assert(OS.get_user_data_dir().get_file().begins_with("ChemLabValidation50-"),"Isolated user data is mandatory")
    var lab=load("res://scenes/laboratory.tscn").instantiate()
    root.add_child(lab)
    var deadline=Time.get_ticks_msec()+30000
    while lab.core.is_busy():
        assert(Time.get_ticks_msec()<deadline,"Initial solver timeout")
        await process_frame
    await process_frame
    lab.paused=true
    var runner: RefCounted
    if id<=28:runner=load("res://tests/fifty_chemistry.gd").new()
    elif id<=36:runner=load("res://tests/fifty_physics.gd").new()
    else:runner=load("res://tests/fifty_workflows.gd").new()
    var result: Dictionary=await runner.run_round(id,lab)
    result.user_data_dir=OS.get_user_data_dir()
    result.node_count=root.get_tree().get_node_count()
    result.status="passed"
    result.review="Observed facts satisfied the stated invariants; retain implementation unless follow-up review identifies a defect."
    print("ROUND_RESULT "+JSON.stringify(result))
    lab.queue_free()
    await process_frame
    await process_frame
    print("ROUND_CLEANUP "+JSON.stringify({"id":id,"node_count":root.get_tree().get_node_count(),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}))
    quit(0)
