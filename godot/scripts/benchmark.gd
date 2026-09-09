extends Node
# Opt-in, bounded delivery test. No file/network activity during ordinary use.
var lab: Node3D
var output := ""
var segment := ""
var previous_frame := 0
var segments := {}
var failures: Array[String] = []
var response_ms: Array[float] = []
var compute_ms: Array[float] = []
var observations: Array = []
var stress_seconds := 180.0
var phase_seconds := 10.0
var started := 0
var render_size := Vector2i.ZERO
var smoke_only := false
var finishing := false
func _ready() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--chemlab-stress-seconds="):
            stress_seconds = clampf(float(arg.trim_prefix("--chemlab-stress-seconds=")),0,600)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--chemlab-phase-seconds="):
            phase_seconds = clampf(float(arg.trim_prefix("--chemlab-phase-seconds=")),0.2,60)
    RenderingServer.frame_post_draw.connect(rendered)
    smoke_only = "--chemlab-smoke-only" in OS.get_cmdline_user_args()
    call_deferred("run_smoke" if smoke_only else "run")
func check(condition: bool,message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("FAIL: "+message)
        if not finishing:
            call_deferred("finish")
func rendered() -> void:
    var now := Time.get_ticks_usec()
    if not segment.is_empty() and previous_frame>0:
        segments[segment].append((now-previous_frame)/1000.0)
    previous_frame = now
func idle(measure: bool = true) -> void:
    var start := Time.get_ticks_usec()
    while lab.core.is_busy():
        if Time.get_ticks_usec()-start>30000000:
            check(false,"Background solver timeout")
            finish()
            return
        await get_tree().process_frame
    await get_tree().process_frame
    if measure:
        response_ms.append((Time.get_ticks_usec()-start)/1000.0)
        compute_ms.append(lab.last_compute_ms)
func observe(label: String) -> void:
    observations.append({"label":label,"wall_s":(Time.get_ticks_usec()-started)/1e6,
        "static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),
        "resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
        "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
func begin(name: String) -> void:
    print("Benchmark segment: "+name)
    segment = name
    if not segments.has(name):
        segments[name] = []
    previous_frame = Time.get_ticks_usec()
    DisplayServer.window_move_to_foreground()
func wait_seconds(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout
func run() -> void:
    started = Time.get_ticks_usec()
    await idle(false)
    check(lab.states.size()==4,"Native database initialization")
    if lab.states.size()!=4:
        finish()
        return
    DisplayServer.window_move_to_foreground()
    RenderingServer.force_draw(false)
    RenderingServer.force_sync()
    render_size = get_viewport().get_texture().get_image().get_size()
    print("Benchmark rendered image: ",render_size)
    check(render_size==Vector2i(1920,1080),"Actual rendered viewport must be 1920x1080")
    lab.set_status("正在执行交付验证，期间会自动切换实验与记录性能。")
    # Warm all model geometry and shaders before recording stable frame times.
    lab.switch_bench()
    for index in range(lab.bench_experiment.KINDS.size()):
        print("Benchmark model ",index)
        lab.bench_experiment.select_model(index)
        lab.bench_experiment.start()
        if lab.bench_experiment.kind_index==5:
            lab.core.control_heater({"heat_enabled":1,"stir_enabled":1})
        await wait_seconds(0.6)
    lab.switch_batch()
    lab.batch_experiment.run_trial()
    await idle()
    await wait_seconds(1)
    lab.switch_experiment(false)
    await wait_seconds(2)
    begin("chemistry_four_vessels")
    await wait_seconds(phase_seconds)
    segment = ""
    for i in range(8):
        lab.add_vessel("烧杯")
        await idle()
    lab.select_vessel(1)
    lab.target_id = 3
    lab.rate.value = 10
    begin("chemistry_twelve_vessels_and_pour")
    lab.pour_button.button_down.emit()
    await wait_seconds(maxf(8,phase_seconds))
    lab.pour_button.button_up.emit()
    await idle()
    check(abs(lab.states[3].volume_ml-50)<0.00001,"Held pour delivered full source")
    check(abs(lab.states[3].elements_mol.Cl-0.00005)<1e-10,"Packaged transfer chloride conservation")
    segment = ""
    check(lab.save_to_path("user://benchmark-session.json"),"Save full session")
    check(lab.export_to_path("user://benchmark-before.csv"),"Export full measurements")
    lab.reset_lab()
    await idle()
    check(lab.load_from_path("user://benchmark-session.json"),"Load full session")
    await idle()
    check(lab.states.size()==12,"Restore full equipment list")
    check(abs(lab.states[3].volume_ml-50)<0.00001,"Restore canonical liquid inventory")
    check(lab.export_to_path("user://benchmark-after.csv"),"Export restored measurements")
    check(FileAccess.get_file_as_string("user://benchmark-before.csv")==FileAccess.get_file_as_string("user://benchmark-after.csv"),"Saved CSV identity")
    lab.switch_batch(true)
    lab.batch_experiment.run_trial()
    await idle()
    var batch: Dictionary = lab.core.batch_snapshot()
    check(batch.solid_remaining_mmol>0.045 and batch.solid_remaining_mmol<0.05,"Packaged Barite equilibrium")
    begin("precipitation")
    await wait_seconds(phase_seconds)
    segment = ""
    lab.switch_experiment(true)
    lab.fall_experiment.configure()
    begin("free_fall_repeat")
    for i in range(5):
        lab.fall_experiment.repeat_trial()
        await wait_seconds(phase_seconds/5)
    segment = ""
    lab.switch_bench()
    for index in range(lab.bench_experiment.KINDS.size()):
        print("Benchmark model ",index)
        lab.bench_experiment.select_model(index)
        lab.bench_experiment.start()
        if lab.bench_experiment.kind_index==5:
            lab.core.control_heater({"heat_enabled":1,"stir_enabled":1})
        begin(lab.bench_experiment.KINDS[index])
        await wait_seconds(phase_seconds)
        segment = ""
        lab.bench_experiment.pause()
        observe(lab.bench_experiment.KINDS[index])
    # Observe each flame/electric apparatus without changing its thermal history.
    for source in range(6):
        lab.core.control_heater({"source":source})
        lab.bench_experiment.start()
        await wait_seconds(0.5)
        begin("heater_source_%d"%source)
        await wait_seconds(maxf(3,phase_seconds/2))
        segment = ""
        check(abs(lab.core.bench_snapshot().energy_residual_j)<1e-7,"Heater energy during source switches")
    # Bounded repeated lifecycle exercise: chemistry -> save/load -> physical model.
    var stress_start := Time.get_ticks_msec()
    var cycle := 0
    while Time.get_ticks_msec()-stress_start<stress_seconds*1000:
        lab.switch_experiment(false)
        lab.reset_lab()
        await idle()
        lab.select_vessel(1)
        lab.target_id = 3
        lab.request_pour(25)
        await idle()
        lab.select_vessel(2)
        lab.request_pour(25)
        await idle()
        check(abs(lab.states[3].ph-7)<0.03,"Repeated neutralization")
        var before_restore: Dictionary = lab.states[3].duplicate(true)
        check(abs(before_restore.elements_mol.Cl-0.000025)<1e-10 and abs(before_restore.elements_mol.Na-0.000025)<1e-10,"Repeated neutralization element inventories")
        check(lab.save_to_path("user://benchmark-repeat.json"),"Repeated save")
        check(lab.load_from_path("user://benchmark-repeat.json"),"Repeated load")
        await idle()
        # Solution volumes are not strictly additive across an actual reaction.
        # Compare the solved state before/after replay, not nominal aliquot sum.
        check(abs(lab.states[3].volume_ml-before_restore.volume_ml)<1e-8,"Repeated restore solved volume")
        for element in before_restore.elements_mol:
            check(abs(lab.states[3].elements_mol[element]-before_restore.elements_mol[element])<1e-12,"Repeated restore element inventory: "+element)
        lab.switch_bench()
        lab.bench_experiment.select_model(cycle%lab.bench_experiment.KINDS.size())
        lab.bench_experiment.start()
        if lab.bench_experiment.kind_index==5:
            lab.core.control_heater({"heat_enabled":1,"stir_enabled":1})
        begin("stress_cycles")
        await wait_seconds(3)
        segment = ""
        observe("cycle_%d"%cycle)
        cycle += 1
    finish()
func stats(values: Array) -> Dictionary:
    if values.is_empty():
        return {"count":0}
    var ordered := values.duplicate()
    ordered.sort()
    var sum := 0.0
    var slow := 0
    for x in values:
        sum += x
        if x>33.334:
            slow += 1
    return {"count":values.size(),"mean_ms":sum/values.size(),"p50_ms":ordered[int((values.size()-1)*0.50)],
        "p95_ms":ordered[int((values.size()-1)*0.95)],"p99_ms":ordered[int((values.size()-1)*0.99)],
        "max_ms":ordered[-1],"over_33_334_ms_percent":100.0*slow/values.size()}
func finish() -> void:
    if finishing:
        return
    finishing = true
    segment = ""
    var frame_stats := {}
    for key in segments:
        var s := stats(segments[key])
        if s.count>0:
            s.mean_fps = 1000.0/s.mean_ms
            var bins := {}
            var elapsed_ms := 0.0
            for frame_ms in segments[key]:
                elapsed_ms += frame_ms
                var bucket := int(elapsed_ms/1000)
                bins[bucket] = bins.get(bucket,0)+1
            var min_frames := 100000
            for bucket in range(int(elapsed_ms/1000)):
                min_frames = mini(min_frames,bins.get(bucket,0))
            s.minimum_complete_second_fps = min_frames if min_frames!=100000 else null
            s.meets_30fps_p99 = s.p99_ms<=33.334 and min_frames>=30
        check(s.count>=100,"Insufficient rendered frame callbacks: "+key)
        frame_stats[key] = s
    var receipt := {"schema":1,"engine":Engine.get_version_info().string,"editor_binary":OS.has_feature("editor"),"phase_seconds":phase_seconds,
        "viewport_size":[render_size.x,render_size.y],"smoke_only":smoke_only,
        "renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
        "adapter":RenderingServer.get_video_adapter_name(),"wall_seconds":(Time.get_ticks_usec()-started)/1e6,
        "database_sha256":lab.core.save_session().database_sha256,"failures":failures,
        "frames":frame_stats,"request_to_commit":stats(response_ms),"solver_compute":stats(compute_ms),"observations":observations}
    var f := FileAccess.open(output,FileAccess.WRITE)
    if f==null:
        push_error("FAIL: Cannot write benchmark receipt")
        get_tree().quit(1)
        return
    f.store_string(JSON.stringify(receipt,"\t",true,true))
    f.close()
    print("PASS: packaged/project runtime lifecycle, conservation, session roundtrip and measured frame receipts" if failures.is_empty() else "FAIL: delivery benchmark")
    get_tree().quit(0 if failures.is_empty() else 1)

func run_smoke() -> void:
    started = Time.get_ticks_usec()
    await idle(false)
    check(not OS.has_feature("editor"),"Must run exported release binary")
    check(lab.states.size()==4,"Packaged PCK database and native initial vessels")
    if lab.states.size()!=4:
        finish()
        return
    lab.select_vessel(1)
    lab.target_id = 3
    lab.request_pour(50)
    await idle()
    lab.select_vessel(2)
    lab.request_pour(50)
    await idle()
    check(abs(lab.states[3].ph-7)<0.03,"Packaged neutralization pH")
    check(abs(lab.states[3].elements_mol.Cl-0.00005)<1e-10,"Packaged chloride conservation")
    lab.switch_batch(true)
    lab.batch_experiment.run_trial()
    await idle()
    check(lab.core.batch_snapshot().solid_remaining_mmol>0.045,"Packaged Barite precipitation")
    lab.switch_bench()
    lab.bench_experiment.select_model(2)
    lab.core.start_bench()
    lab.core.advance_bench(10)
    lab.core.pause_bench()
    var heat: Dictionary = lab.core.bench_snapshot()
    check(heat.temperature1_c<70 and heat.temperature2_c>20,"Packaged heat exchange")
    check(abs(heat.energy_j-37674)<1e-8,"Packaged thermal energy")
    check(lab.save_to_path("user://packaged-smoke-session.json"),"Packaged session save")
    lab.reset_lab()
    await idle()
    check(lab.load_from_path("user://packaged-smoke-session.json"),"Packaged session load accepted")
    await idle()
    check(abs(lab.states[3].ph-7)<0.03,"Packaged restored pH")
    check(abs(lab.core.bench_snapshot().time_s-10)<1e-10,"Packaged restored physics")
    check(lab.core.bench_snapshot().running==0,"Packaged paused restoration")
    lab.bench_experiment.select_model(5)
    lab.core.control_heater({"heat_enabled":1,"stir_enabled":1,"target_c":45,"power_w":1000})
    lab.core.start_bench()
    lab.core.advance_bench(30)
    check(abs(lab.core.bench_snapshot().temperature_c-45)<1e-8,"Packaged heater target")
    lab.core.control_heater({"source":5,"target_c":30})
    lab.core.advance_bench(10)
    check(lab.core.bench_snapshot().temperature_c<45,"Packaged live target cooling")
    check(abs(lab.core.bench_snapshot().energy_residual_j)<1e-7,"Packaged heater energy budget")
    lab.core.pause_bench()
    check(lab.save_to_path("user://packaged-heater.json"),"Packaged heater save")
    check(lab.load_from_path("user://packaged-heater.json"),"Packaged heater load")
    await idle()
    check(lab.core.bench_snapshot().source==5 and lab.core.bench_snapshot().running==0,"Packaged heater restored paused")
    finish()
