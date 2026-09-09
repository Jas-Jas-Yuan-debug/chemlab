extends SceneTree

var core: LabCore
var start_ms: int
var stage := 0

func _initialize() -> void:
    start_ms = Time.get_ticks_msec()
    core = LabCore.new()
    core.initialize(ProjectSettings.globalize_path("res://data/phreeqc.dat"))

func _process(_delta: float) -> bool:
    if Time.get_ticks_msec() - start_ms > 30000:
        push_error("Native extension smoke timed out")
        quit(1)
        return true
    var result: Dictionary = core.poll()
    if not result.get("ready", false):
        return false
    if result.get("error", "") != "":
        push_error(result.error)
        quit(1)
        return true
    if stage == 0:
        assert(result.state.vessels.size() == 4)
        assert(core.pour(1, 3, 50.0))
        stage = 1
    elif stage == 1:
        assert(core.pour(2, 3, 50.0))
        stage = 2
    elif stage == 2:
        for v in result.state.vessels:
            if v.id == 3:
                assert(abs(v.ph - 7.0) < 0.03)
                assert(abs(v.elements_mol.Na - 0.00005) < 1e-10)
                assert(abs(v.elements_mol.Cl - 0.00005) < 1e-10)
        # A pending result becomes obsolete when reset is requested.
        assert(core.pour(4, 3, 10.0))
        assert(core.reset_lab())
        stage = 3
    elif stage == 3:
        assert(result.operation == "reset")
        assert(result.state.vessels[2].volume_ml == 0)
        print("PASS: Godot native extension, prepare, pour, pH, conservation, stale-result reset")
        quit(0)
        return true
    return false
