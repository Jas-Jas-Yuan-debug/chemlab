extends SceneTree
var core: LabCore
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:push_error(message);quit(1)
    assert(ok,message)
func ready_result() -> Dictionary:
    var deadline:=Time.get_ticks_msec()+15000
    while Time.get_ticks_msec()<deadline:
        var r: Dictionary=core.poll()
        if r.get("ready",false):
            check(r.get("error","")=="","Science error: "+str(r.get("error")))
            return r
        await process_frame
    check(false,"Worker timeout")
    return {}
func run() -> void:
    core=LabCore.new();core.initialize("res://data/phreeqc.dat");await ready_result()
    check(core.prepare(1,5,14.96,1,250),"Prepare 1 mL max KOH");await ready_result()
    check(core.prepare(2,1,0,200,250),"Prepare dilution water");await ready_result()
    check(core.pour(2,1,200),"Water into stock");await ready_result()
    var kinetics: Dictionary=core.kinetics_snapshot()
    check(kinetics.has(1) and kinetics[1].ph!=null,"Reverse dilution failed to restart kinetics")
    check(core.load_session(core.save_session())=="","Reverse dilution reload");await ready_result()
    check(core.prepare(1,2,13.09,1,250),"Prepare acid stock");await ready_result()
    check(core.pour(1,2,1),"Empty stock into empty vessel");await ready_result()
    check(core.kinetics_snapshot().has(1) and core.kinetics_snapshot()[1].ph==null,"Empty stock source lacks canonical empty kinetic state")
    check(core.load_session(core.save_session())=="","Depleted stock reload");await ready_result()
    print("PASS: water-into-stock dilution and fully depleted stock source both preserve loadable kinetic boundaries")
    core=null;quit(0)
